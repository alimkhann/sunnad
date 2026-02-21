import { createClient } from "npm:@supabase/supabase-js@2";

/**
 * waitlist-submit — Public edge function for landing page waitlist signups.
 *
 * Flow:
 *   1. Verify Cloudflare Turnstile token
 *   2. Rate-limit by IP hash (max 5 signups per IP per hour)
 *   3. Upsert subscriber into waitlist_subscribers
 *   4. Return success / already_subscribed / rate_limited / error
 */

const corsHeaders = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type WaitlistRequest = {
  email: string;
  turnstile_token: string;
  platform?: string;
  locale?: string;
  variant?: string;
  timezone?: string;
  referral_source?: string;
};

Deno.serve(async (req: Request): Promise<Response> => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const turnstileSecret = Deno.env.get("TURNSTILE_SECRET_KEY");

  if (!supabaseURL || !serviceRoleKey || !turnstileSecret) {
    return json({ error: "Function is not configured" }, 500);
  }

  let body: WaitlistRequest;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  // ---- Validate required fields ----
  const email = normalizeEmail(body.email);
  if (!email) {
    return json({ error: "Invalid email" }, 400);
  }

  if (!body.turnstile_token || typeof body.turnstile_token !== "string") {
    return json({ error: "Missing Turnstile token" }, 400);
  }

  // ---- Verify Turnstile ----
  const turnstileOk = await verifyTurnstile(
    turnstileSecret,
    body.turnstile_token,
    getClientIP(req),
  );
  if (!turnstileOk) {
    return json({ error: "Turnstile verification failed" }, 403);
  }

  // ---- Rate-limit by IP hash ----
  const clientIP = getClientIP(req);
  const ipHash = clientIP ? await hashSHA256(clientIP) : null;
  const admin = createClient(supabaseURL, serviceRoleKey);

  if (ipHash) {
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString();
    const { count, error: countErr } = await admin
      .from("waitlist_subscribers")
      .select("id", { count: "exact", head: true })
      .eq("ip_hash", ipHash)
      .gte("created_at", oneHourAgo);

    if (!countErr && (count ?? 0) >= 5) {
      return json(
        { error: "Too many signups from this network. Try again later.", code: "rate_limited" },
        429,
      );
    }
  }

  // ---- Normalize optional fields ----
  const platform = normalizePlatform(body.platform);
  const locale = normalizeLocale(body.locale);
  const variant = normalizeVariant(body.variant);
  const timezone = typeof body.timezone === "string" ? body.timezone.slice(0, 64) : null;
  const referralSource = typeof body.referral_source === "string" ? body.referral_source.slice(0, 128) : null;

  // ---- Upsert subscriber ----
  // ON CONFLICT on lower(email) → update platform/locale if changed
  const { data, error: upsertErr } = await admin
    .from("waitlist_subscribers")
    .upsert(
      {
        email: email.toLowerCase(),
        platform,
        locale,
        variant,
        timezone,
        referral_source: referralSource,
        ip_hash: ipHash,
        unsubscribed_at: null, // re-subscribe if previously unsubscribed
      },
      { onConflict: "lower(email)" }, // partial unique index
    )
    .select("id, subscribed_at, created_at")
    .single();

  if (upsertErr) {
    // If the upsert fails due to the unique index, try an update instead
    if (upsertErr.code === "23505" || upsertErr.message?.includes("unique")) {
      // Already exists — update instead
      const { error: updateErr } = await admin
        .from("waitlist_subscribers")
        .update({
          platform,
          locale,
          variant,
          timezone,
          referral_source: referralSource,
          unsubscribed_at: null,
        })
        .ilike("email", email);

      if (updateErr) {
        return json({ error: "Failed to update subscription" }, 500);
      }
      return json({ status: "already_subscribed" }, 200);
    }
    return json({ error: "Failed to create subscription" }, 500);
  }

  // Detect if this was an insert or an update by comparing timestamps
  const isNew = data.created_at === data.subscribed_at ||
    new Date(data.created_at).getTime() > Date.now() - 2000;

  return json(
    { status: isNew ? "subscribed" : "already_subscribed", id: data.id },
    isNew ? 201 : 200,
  );
});

// ---- Helpers ----

async function verifyTurnstile(
  secret: string,
  token: string,
  ip: string | null,
): Promise<boolean> {
  const formData = new URLSearchParams();
  formData.append("secret", secret);
  formData.append("response", token);
  if (ip) formData.append("remoteip", ip);

  try {
    const res = await fetch(
      "https://challenges.cloudflare.com/turnstile/v0/siteverify",
      {
        method: "POST",
        body: formData,
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
      },
    );
    const result = await res.json();
    return result.success === true;
  } catch {
    return false;
  }
}

function getClientIP(req: Request): string | null {
  return (
    req.headers.get("cf-connecting-ip") ??
    req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ??
    req.headers.get("x-real-ip") ??
    null
  );
}

async function hashSHA256(input: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(input);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}

function normalizeEmail(input: unknown): string | null {
  if (typeof input !== "string") return null;
  const trimmed = input.trim().toLowerCase();
  // Basic email format check
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmed)) return null;
  if (trimmed.length > 320) return null; // RFC 5321 max length
  return trimmed;
}

function normalizePlatform(input: unknown): string {
  if (input === "ios" || input === "android" || input === "both") return input;
  return "unknown";
}

function normalizeLocale(input: unknown): string {
  if (input === "en" || input === "ru" || input === "kk") return input;
  return "en";
}

function normalizeVariant(input: unknown): string | null {
  if (input === "1" || input === "2" || input === "3" || input === "4" || input === "5") {
    return input;
  }
  return null;
}

function json(
  body: Record<string, unknown>,
  status = 200,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: corsHeaders,
  });
}
