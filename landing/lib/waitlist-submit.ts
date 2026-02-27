import { landingConfig } from "./config";
import { captureLandingEvent } from "./analytics";

export type WaitlistStatus =
  | "subscribed"
  | "already_subscribed"
  | "rate_limited"
  | "error";

export interface WaitlistResult {
  status: WaitlistStatus;
  message?: string;
}

const WAITLIST_VARIANT = "14";

function detectPlatform(): string {
  if (typeof navigator === "undefined") return "unknown";
  const ua = navigator.userAgent.toLowerCase();
  if (/iphone|ipad|ipod|ios/.test(ua)) return "ios";
  if (/android/.test(ua)) return "android";
  if (/windows nt|win64|win32/.test(ua)) return "windows";
  if (/macintosh|mac os x/.test(ua)) return "macos";
  if (/linux|x11|cros/.test(ua)) return "linux";
  return "unknown";
}

function trackWaitlistSubmitted(
  status: Extract<WaitlistStatus, "subscribed" | "already_subscribed">,
  locale: string,
) {
  captureLandingEvent("landing_waitlist_submit_succeeded", {
    status,
    locale,
    variant: WAITLIST_VARIANT,
    platform: detectPlatform(),
    referral_source: "landing",
  });
}

function trackWaitlistFailed(
  status: Extract<WaitlistStatus, "rate_limited" | "error">,
  locale: string,
  errorType: string,
) {
  captureLandingEvent("landing_waitlist_submit_failed", {
    status,
    locale,
    variant: WAITLIST_VARIANT,
    platform: detectPlatform(),
    referral_source: "landing",
    error_type: errorType,
  });
}

export async function submitWaitlist(params: {
  email: string;
  turnstileToken: string;
  locale: string;
}): Promise<WaitlistResult> {
  const { email, turnstileToken, locale } = params;
  const platform = detectPlatform();

  captureLandingEvent("landing_waitlist_submit_started", {
    locale,
    variant: WAITLIST_VARIANT,
    platform,
    referral_source: "landing",
  });

  try {
    const res = await fetch(
      `${landingConfig.supabaseURL}/functions/v1/waitlist-submit`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          apikey: landingConfig.supabaseAnonKey,
          Authorization: `Bearer ${landingConfig.supabaseAnonKey}`,
        },
        body: JSON.stringify({
          email,
          turnstile_token: turnstileToken,
          locale,
          platform,
          timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
          referral_source: "landing",
        }),
      },
    );

    if (res.status === 429) {
      trackWaitlistFailed("rate_limited", locale, "rate_limited");
      return { status: "rate_limited" };
    }

    if (!res.ok) {
      const text = await res.text().catch(() => "");
      trackWaitlistFailed("error", locale, `http_${res.status.toString()}`);
      return { status: "error", message: text || `HTTP ${res.status}` };
    }

    const data = await res.json();

    if (data.status === "already_subscribed") {
      trackWaitlistSubmitted("already_subscribed", locale);
      return { status: "already_subscribed" };
    }
    if (data.status === "subscribed") {
      trackWaitlistSubmitted("subscribed", locale);
      return { status: "subscribed" };
    }

    trackWaitlistFailed("error", locale, "unexpected_response");
    return { status: "error", message: "Unexpected response" };
  } catch (err) {
    trackWaitlistFailed("error", locale, "network");
    return {
      status: "error",
      message: err instanceof Error ? err.message : "Network error",
    };
  }
}
