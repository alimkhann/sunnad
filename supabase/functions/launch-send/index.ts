import { createClient } from "npm:@supabase/supabase-js@2";

/**
 * launch-send — Admin-only edge function for sending launch/campaign emails.
 *
 * Endpoints:
 *   POST /campaigns        — Create a campaign + enqueue sends for all active subs
 *   POST /campaigns/:id/send  — Start sending (Resend batch)
 *   GET  /campaigns        — List campaigns
 *   GET  /campaigns/:id    — Campaign detail with send stats
 *
 * Auth: requires is_allowlisted_admin().
 * Sends via Resend API.
 */

const corsHeaders = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

type CreateCampaignInput = {
  subject: string;
  body_html: string;
  body_text?: string;
  locale?: string;
};

type AuthContext = {
  userID: string;
  admin: ReturnType<typeof createClient>;
};

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const resendAPIKey = Deno.env.get("RESEND_API_KEY");
  const fromEmail = Deno.env.get("FROM_EMAIL") ?? "Sunnad <noreply@sunnad.com>";

  if (!supabaseURL || !serviceRoleKey || !supabaseAnonKey || !resendAPIKey) {
    return json({ error: "Function is not configured" }, 500);
  }

  // Authenticate admin
  const auth = await requireAdmin(
    req,
    supabaseURL,
    supabaseAnonKey,
    serviceRoleKey,
  );
  if (auth instanceof Response) return auth;

  const path = getFunctionPath(req.url, "launch-send");

  try {
    // GET /campaigns — list all
    if (req.method === "GET" && path === "/campaigns") {
      return await handleListCampaigns(auth);
    }

    // GET /campaigns/:id — detail
    if (
      req.method === "GET" &&
      path.startsWith("/campaigns/") &&
      !path.includes("/send")
    ) {
      const id = path.replace("/campaigns/", "").trim();
      if (!looksLikeUUID(id))
        return json({ error: "Invalid campaign ID" }, 400);
      return await handleGetCampaign(auth, id);
    }

    // POST /campaigns — create
    if (req.method === "POST" && path === "/campaigns") {
      return await handleCreateCampaign(req, auth);
    }

    // POST /campaigns/:id/send — trigger send
    if (req.method === "POST" && path.endsWith("/send")) {
      const id = path.replace("/campaigns/", "").replace("/send", "").trim();
      if (!looksLikeUUID(id))
        return json({ error: "Invalid campaign ID" }, 400);
      return await handleSendCampaign(auth, id, resendAPIKey, fromEmail);
    }

    return json({ error: "Not found" }, 404);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unexpected error";
    return json({ error: message }, 500);
  }
});

// ---- Handlers ----

async function handleListCampaigns(auth: AuthContext): Promise<Response> {
  const { data, error } = await auth.admin
    .from("launch_campaigns")
    .select(
      "id, subject, locale, status, total_recipients, total_sent, total_failed, created_at",
    )
    .order("created_at", { ascending: false });

  if (error) return json({ error: error.message }, 500);
  return json({ campaigns: data });
}

async function handleGetCampaign(
  auth: AuthContext,
  id: string,
): Promise<Response> {
  const { data: campaign, error: campErr } = await auth.admin
    .from("launch_campaigns")
    .select("*")
    .eq("id", id)
    .single();

  if (campErr || !campaign) return json({ error: "Campaign not found" }, 404);

  const { data: sends, error: sendsErr } = await auth.admin
    .from("launch_sends")
    .select("id, email, status, sent_at, error_message")
    .eq("campaign_id", id)
    .order("created_at", { ascending: true });

  if (sendsErr) return json({ error: sendsErr.message }, 500);

  return json({ campaign, sends: sends ?? [] });
}

async function handleCreateCampaign(
  req: Request,
  auth: AuthContext,
): Promise<Response> {
  let body: CreateCampaignInput;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  if (!body.subject?.trim() || !body.body_html?.trim()) {
    return json({ error: "subject and body_html are required" }, 400);
  }

  const locale = normalizeLocale(body.locale);

  // Count active subscribers for this locale
  const { count, error: countErr } = await auth.admin
    .from("waitlist_subscribers")
    .select("id", { count: "exact", head: true })
    .is("unsubscribed_at", null)
    .eq("locale", locale);

  if (countErr) return json({ error: countErr.message }, 500);

  // Create campaign
  const { data: campaign, error: createErr } = await auth.admin
    .from("launch_campaigns")
    .insert({
      subject: body.subject.trim(),
      body_html: body.body_html.trim(),
      body_text: body.body_text?.trim() ?? null,
      locale,
      status: "draft",
      total_recipients: count ?? 0,
      created_by: auth.userID,
    })
    .select("id, subject, locale, status, total_recipients, created_at")
    .single();

  if (createErr || !campaign) {
    return json(
      { error: createErr?.message ?? "Failed to create campaign" },
      500,
    );
  }

  // Enqueue sends for all active subscribers of this locale
  const { data: subscribers, error: subErr } = await auth.admin
    .from("waitlist_subscribers")
    .select("id, email")
    .is("unsubscribed_at", null)
    .eq("locale", locale);

  if (subErr) return json({ error: subErr.message }, 500);

  if (subscribers && subscribers.length > 0) {
    const sendRows = subscribers.map((sub) => ({
      campaign_id: campaign.id,
      subscriber_id: sub.id,
      email: sub.email,
      status: "pending",
    }));

    const { error: insertErr } = await auth.admin
      .from("launch_sends")
      .insert(sendRows);

    if (insertErr) {
      return json(
        {
          error: `Campaign created but failed to enqueue sends: ${insertErr.message}`,
        },
        500,
      );
    }
  }

  return json({ campaign, enqueued: subscribers?.length ?? 0 }, 201);
}

async function handleSendCampaign(
  auth: AuthContext,
  campaignId: string,
  resendAPIKey: string,
  fromEmail: string,
): Promise<Response> {
  // Load campaign
  const { data: campaign, error: campErr } = await auth.admin
    .from("launch_campaigns")
    .select("*")
    .eq("id", campaignId)
    .single();

  if (campErr || !campaign) return json({ error: "Campaign not found" }, 404);

  if (campaign.status === "sent") {
    return json({ error: "Campaign already sent" }, 409);
  }

  if (campaign.status === "sending") {
    return json({ error: "Campaign is currently sending" }, 409);
  }

  // Mark as sending
  await auth.admin
    .from("launch_campaigns")
    .update({ status: "sending", started_at: new Date().toISOString() })
    .eq("id", campaignId);

  // Load pending sends
  const { data: sends, error: sendsErr } = await auth.admin
    .from("launch_sends")
    .select("id, email")
    .eq("campaign_id", campaignId)
    .eq("status", "pending");

  if (sendsErr || !sends) {
    await auth.admin
      .from("launch_campaigns")
      .update({ status: "failed" })
      .eq("id", campaignId);
    return json({ error: sendsErr?.message ?? "No pending sends" }, 500);
  }

  let sentCount = 0;
  let failedCount = 0;

  // Send emails one by one (Resend free tier: 100/day, 1/sec)
  for (const send of sends) {
    try {
      const resendRes = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${resendAPIKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: fromEmail,
          to: [send.email],
          subject: campaign.subject,
          html: campaign.body_html,
          text: campaign.body_text ?? undefined,
        }),
      });

      if (resendRes.ok) {
        const resendData = await resendRes.json();
        await auth.admin
          .from("launch_sends")
          .update({
            status: "sent",
            sent_at: new Date().toISOString(),
            resend_message_id: resendData.id ?? null,
          })
          .eq("id", send.id);
        sentCount++;
      } else {
        const errText = await resendRes.text();
        await auth.admin
          .from("launch_sends")
          .update({
            status: "failed",
            error_message: errText.slice(0, 500),
          })
          .eq("id", send.id);
        failedCount++;
      }

      // Rate limit: ~1 email/sec to respect Resend limits
      await sleep(1100);
    } catch (err) {
      const errMsg = err instanceof Error ? err.message : "Unknown error";
      await auth.admin
        .from("launch_sends")
        .update({
          status: "failed",
          error_message: errMsg.slice(0, 500),
        })
        .eq("id", send.id);
      failedCount++;
    }
  }

  // Update campaign status
  const finalStatus = failedCount === sends.length ? "failed" : "sent";
  await auth.admin
    .from("launch_campaigns")
    .update({
      status: finalStatus,
      total_sent: sentCount,
      total_failed: failedCount,
      completed_at: new Date().toISOString(),
    })
    .eq("id", campaignId);

  return json({
    status: finalStatus,
    total: sends.length,
    sent: sentCount,
    failed: failedCount,
  });
}

// ---- Auth ----

async function requireAdmin(
  req: Request,
  supabaseURL: string,
  supabaseAnonKey: string,
  serviceRoleKey: string,
): Promise<AuthContext | Response> {
  const authorization = req.headers.get("Authorization");
  if (!authorization) {
    return json({ error: "Missing authorization" }, 401);
  }

  const authClient = createClient(supabaseURL, supabaseAnonKey, {
    global: { headers: { Authorization: authorization } },
  });

  const {
    data: { user },
    error: userError,
  } = await authClient.auth.getUser();
  if (userError || !user) {
    return json({ error: "Unauthorized" }, 401);
  }

  const admin = createClient(supabaseURL, serviceRoleKey);
  const allowResult = await admin.rpc("is_allowlisted_admin", {
    p_user_id: user.id,
  });

  if (allowResult.error || allowResult.data !== true) {
    return json({ error: "Forbidden" }, 403);
  }

  return { userID: user.id, admin };
}

// ---- Helpers ----

function normalizeLocale(input: unknown): string {
  if (input === "en" || input === "ru" || input === "kk") return input;
  return "en";
}

function looksLikeUUID(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
    value,
  );
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function getFunctionPath(url: string, fnName: string): string {
  const pathname = new URL(url).pathname;
  const marker = `/${fnName}`;
  const index = pathname.indexOf(marker);
  if (index === -1) return "/";
  const suffix = pathname.slice(index + marker.length);
  return suffix.length > 0 ? suffix : "/";
}

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: corsHeaders,
  });
}
