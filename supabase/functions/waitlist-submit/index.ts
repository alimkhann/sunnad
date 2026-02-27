import { createClient } from "npm:@supabase/supabase-js@2";

/**
 * waitlist-submit — Public edge function for landing page waitlist signups.
 *
 * Flow:
 *   1. Verify Cloudflare Turnstile token
 *   2. Rate-limit by IP hash (lenient window)
 *   3. Insert/update subscriber into waitlist_subscribers
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
  turnstile_token?: string;
  turnstileToken?: string;
  platform?: string;
  locale?: string;
  timezone?: string;
  referral_source?: string;
  source?: string;
};

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const turnstileSecret = Deno.env.get("TURNSTILE_SECRET_KEY");
  const hashSalt = Deno.env.get("WAITLIST_RATE_LIMIT_SALT") ?? "";

  if (!supabaseURL || !serviceRoleKey || !turnstileSecret) {
    return json({ error: "Function is not configured" }, 500);
  }

  let body: WaitlistRequest;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const email = normalizeEmail(body.email);
  if (!email) {
    return json({ error: "Invalid email" }, 400);
  }

  const turnstileToken =
    typeof body.turnstile_token === "string"
      ? body.turnstile_token
      : typeof body.turnstileToken === "string"
        ? body.turnstileToken
        : null;

  if (!turnstileToken) {
    return json({ error: "Missing Turnstile token" }, 400);
  }

  const clientIP = getClientIP(req);
  const turnstileOk = await verifyTurnstile(turnstileSecret, turnstileToken, clientIP);
  if (!turnstileOk) {
    return json({ error: "Turnstile verification failed" }, 403);
  }

  const ipHash = clientIP
    ? await hashSHA256(hashSalt ? `${hashSalt}:${clientIP}` : clientIP)
    : null;
  const admin = createClient(supabaseURL, serviceRoleKey);

  if (ipHash) {
    const tenMinutesAgo = new Date(Date.now() - 10 * 60 * 1000).toISOString();
    const { count, error: countErr } = await admin
      .from("waitlist_subscribers")
      .select("id", { count: "exact", head: true })
      .eq("ip_hash", ipHash)
      .gte("created_at", tenMinutesAgo);

    if (!countErr && (count ?? 0) >= 10) {
      return json(
        {
          error: "Too many signups from this network. Try again later.",
          code: "rate_limited",
        },
        429,
      );
    }
  }

  const platform = normalizePlatform(body.platform, req.headers.get("user-agent"));
  const locale = normalizeLocale(body.locale);
  const timezone =
    typeof body.timezone === "string" ? body.timezone.slice(0, 64) : null;
  const referralSource =
    typeof body.referral_source === "string"
      ? body.referral_source.slice(0, 128)
      : typeof body.source === "string"
        ? body.source.slice(0, 128)
        : null;

  const { data: existing, error: existingErr } = await admin
    .from("waitlist_subscribers")
    .select("id, unsubscribed_at")
    .ilike("email", email)
    .maybeSingle();

  if (existingErr) {
    return json({ error: "Failed to check subscription" }, 500);
  }

  if (existing) {
    const updatePayload: Record<string, unknown> = {
      platform,
      locale,
      timezone,
      referral_source: referralSource,
      ip_hash: ipHash,
      unsubscribed_at: null,
    };

    if (existing.unsubscribed_at) {
      updatePayload.subscribed_at = new Date().toISOString();
    }

    const { error: updateErr } = await admin
      .from("waitlist_subscribers")
      .update(updatePayload)
      .eq("id", existing.id);

    if (updateErr) {
      return json({ error: "Failed to update subscription" }, 500);
    }

    const resubscribed = Boolean(existing.unsubscribed_at);
    return json(
      { status: resubscribed ? "subscribed" : "already_subscribed", id: existing.id },
      resubscribed ? 201 : 200,
    );
  }

  const { data, error: insertErr } = await admin
    .from("waitlist_subscribers")
    .insert({
      email,
      platform,
      locale,
      timezone,
      referral_source: referralSource,
      ip_hash: ipHash,
      unsubscribed_at: null,
    })
    .select("id")
    .single();

  if (insertErr) {
    if (insertErr.code === "23505" || insertErr.message?.includes("unique")) {
      return json({ status: "already_subscribed" }, 200);
    }
    return json({ error: "Failed to create subscription" }, 500);
  }

  return json({ status: "subscribed", id: data.id }, 201);
});

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
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmed)) return null;
  if (trimmed.length > 320) return null;
  return trimmed;
}

function normalizePlatform(input: unknown, ua: string | null): string {
  if (typeof input === "string") {
    const normalized = input.trim().toLowerCase();
    if (
      normalized === "ios" ||
      normalized === "android" ||
      normalized === "macos" ||
      normalized === "windows" ||
      normalized === "linux" ||
      normalized === "unknown"
    ) {
      return normalized;
    }
  }

  const userAgent = (ua ?? "").toLowerCase();
  if (userAgent === "") return "unknown";
  if (/iphone|ipad|ipod|ios/.test(userAgent)) return "ios";
  if (/android/.test(userAgent)) return "android";
  if (/windows nt|win64|win32/.test(userAgent)) return "windows";
  if (/macintosh|mac os x/.test(userAgent)) return "macos";
  if (/linux|x11|cros/.test(userAgent)) return "linux";
  return "unknown";
}

function normalizeLocale(input: unknown): string {
  if (input === "en" || input === "ru" || input === "kk") return input;
  return "en";
}

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: corsHeaders,
  });
}
