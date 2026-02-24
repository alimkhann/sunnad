import posthog from "posthog-js";
import { landingConfig } from "./config";

export type WaitlistStatus =
  | "subscribed"
  | "already_subscribed"
  | "rate_limited"
  | "error";

export interface WaitlistResult {
  status: WaitlistStatus;
  message?: string;
}

function detectPlatform(): string {
  if (typeof navigator === "undefined") return "unknown";
  const ua = navigator.userAgent;
  if (/iPhone|iPad|iPod/.test(ua)) return "ios";
  if (/Android/.test(ua)) return "android";
  return "unknown";
}

function trackWaitlistSubmitted(
  status: Extract<WaitlistStatus, "subscribed" | "already_subscribed">,
  locale: string,
  variant: string,
) {
  if (typeof window === "undefined") return;

  posthog.capture("waitlist_submitted", {
    status,
    locale,
    variant,
    platform: detectPlatform(),
    referral_source: "landing",
  });
}

function trackWaitlistFailed(
  status: Extract<WaitlistStatus, "rate_limited" | "error">,
  locale: string,
  variant: string,
  errorType: string,
) {
  if (typeof window === "undefined") return;

  posthog.capture("waitlist_submit_failed", {
    status,
    locale,
    variant,
    platform: detectPlatform(),
    referral_source: "landing",
    error_type: errorType,
  });
}

export async function submitWaitlist(params: {
  email: string;
  turnstileToken: string;
  locale: string;
  variant: string;
}): Promise<WaitlistResult> {
  const { email, turnstileToken, locale, variant } = params;

  try {
    const res = await fetch(
      `${landingConfig.supabaseURL}/functions/v1/waitlist-submit`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          apikey: landingConfig.supabaseAnonKey,
        },
        body: JSON.stringify({
          email,
          turnstile_token: turnstileToken,
          locale,
          platform: detectPlatform(),
          variant,
          timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
          referral_source: "landing",
        }),
      },
    );

    if (res.status === 429) {
      trackWaitlistFailed("rate_limited", locale, variant, "rate_limited");
      return { status: "rate_limited" };
    }

    if (!res.ok) {
      const text = await res.text().catch(() => "");
      trackWaitlistFailed(
        "error",
        locale,
        variant,
        `http_${res.status.toString()}`,
      );
      return { status: "error", message: text || `HTTP ${res.status}` };
    }

    const data = await res.json();

    if (data.status === "already_subscribed") {
      trackWaitlistSubmitted("already_subscribed", locale, variant);
      return { status: "already_subscribed" };
    }
    if (data.status === "subscribed") {
      trackWaitlistSubmitted("subscribed", locale, variant);
      return { status: "subscribed" };
    }

    trackWaitlistFailed("error", locale, variant, "unexpected_response");
    return { status: "error", message: "Unexpected response" };
  } catch (err) {
    trackWaitlistFailed("error", locale, variant, "network");
    return {
      status: "error",
      message: err instanceof Error ? err.message : "Network error",
    };
  }
}
