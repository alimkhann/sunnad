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
      return { status: "rate_limited" };
    }

    if (!res.ok) {
      const text = await res.text().catch(() => "");
      return { status: "error", message: text || `HTTP ${res.status}` };
    }

    const data = await res.json();

    if (data.status === "already_subscribed") {
      return { status: "already_subscribed" };
    }
    if (data.status === "subscribed") {
      return { status: "subscribed" };
    }

    return { status: "error", message: "Unexpected response" };
  } catch (err) {
    return {
      status: "error",
      message: err instanceof Error ? err.message : "Network error",
    };
  }
}
