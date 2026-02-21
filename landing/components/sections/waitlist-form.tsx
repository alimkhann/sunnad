"use client";

import { type ReactNode, useCallback, useEffect, useRef, useState } from "react";
import type { Dictionary, VariantId } from "@/lib/i18n";
import { cn } from "@/lib/utils";
import { landingConfig } from "@/lib/config";

type FormStatus =
  | "idle"
  | "submitting"
  | "success"
  | "already_subscribed"
  | "error"
  | "rate_limited"
  | "turnstile_expired";

interface WaitlistFormProps {
  variant: VariantId;
  locale: string;
  t: Dictionary;
}

export function WaitlistForm({ variant, locale, t }: WaitlistFormProps): ReactNode {
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<FormStatus>("idle");
  const [token, setToken] = useState<string | null>(null);
  const turnstileRef = useRef<HTMLDivElement>(null);
  const widgetIdRef = useRef<string | null>(null);

  /* Load Turnstile script */
  useEffect(() => {
    if (typeof window === "undefined") return;
    if (document.getElementById("cf-turnstile-script")) return;

    const script = document.createElement("script");
    script.id = "cf-turnstile-script";
    script.src = "https://challenges.cloudflare.com/turnstile/v0/api.js?onload=onTurnstileLoad&render=explicit";
    script.async = true;
    script.defer = true;

    (window as unknown as Record<string, unknown>).onTurnstileLoad = () => {
      if (turnstileRef.current && !widgetIdRef.current) {
        const turnstile = (window as unknown as Record<string, unknown>).turnstile as {
          render: (el: HTMLElement, opts: Record<string, unknown>) => string;
          reset: (id: string) => void;
        } | undefined;
        if (turnstile) {
          widgetIdRef.current = turnstile.render(turnstileRef.current, {
            sitekey: landingConfig.turnstileSiteKey,
            callback: (t: string) => setToken(t),
            "expired-callback": () => {
              setToken(null);
              setStatus("turnstile_expired");
            },
            theme: variant === "5" ? "dark" : "light",
            size: "normal",
          });
        }
      }
    };

    document.head.appendChild(script);
  }, [variant]);

  const resetTurnstile = useCallback(() => {
    const turnstile = (window as unknown as Record<string, unknown>).turnstile as {
      reset: (id: string) => void;
    } | undefined;
    if (turnstile && widgetIdRef.current) {
      turnstile.reset(widgetIdRef.current);
      setToken(null);
    }
  }, []);

  const handleSubmit = useCallback(
    async (e: React.FormEvent) => {
      e.preventDefault();
      if (!email || !token || status === "submitting") return;

      setStatus("submitting");

      try {
        const platform = detectPlatform();
        const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone;

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
              locale,
              platform,
              source: "landing",
              timezone,
              turnstileToken: token,
            }),
          },
        );

        if (res.status === 429) {
          setStatus("rate_limited");
          resetTurnstile();
          return;
        }

        if (!res.ok) {
          setStatus("error");
          resetTurnstile();
          return;
        }

        const data = (await res.json()) as { ok: boolean; status: string };

        if (data.ok && data.status === "already_subscribed") {
          setStatus("already_subscribed");
        } else if (data.ok) {
          setStatus("success");
        } else {
          setStatus("error");
          resetTurnstile();
        }
      } catch {
        setStatus("error");
        resetTurnstile();
      }
    },
    [email, token, status, locale, resetTurnstile],
  );

  /* Success / already subscribed states */
  if (status === "success" || status === "already_subscribed") {
    const isAlready = status === "already_subscribed";
    return (
      <div className="text-center py-4">
        <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-primary/10">
          <svg className="h-8 w-8 text-primary" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M20 6L9 17l-5-5" />
          </svg>
        </div>
        <h3 className="text-xl font-semibold text-foreground">
          {isAlready ? t.waitlist.alreadyTitle : t.waitlist.successTitle}
        </h3>
        <p className="mt-2 text-muted-foreground">
          {isAlready ? t.waitlist.alreadyMessage : t.waitlist.successMessage}
        </p>
      </div>
    );
  }

  const isSubmitting = status === "submitting";

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      {/* Email input */}
      <div className="flex flex-col gap-3 sm:flex-row">
        <input
          type="email"
          required
          value={email}
          onChange={(e) => {
            setEmail(e.target.value);
            if (status === "error" || status === "rate_limited" || status === "turnstile_expired") {
              setStatus("idle");
            }
          }}
          placeholder={t.waitlist.emailPlaceholder}
          disabled={isSubmitting}
          className={cn(
            "h-12 flex-1 rounded-lg border bg-background px-4 text-base text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-primary/50 disabled:opacity-60 sm:h-14",
            variant === "3" && "rounded-sm",
            variant === "4" && "rounded-xl",
          )}
        />
        <button
          type="submit"
          disabled={isSubmitting || !token}
          className={cn(
            "h-12 rounded-lg bg-primary px-6 text-base font-semibold text-primary-foreground transition-all hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed sm:h-14 sm:px-8",
            variant === "3" && "rounded-sm uppercase tracking-wider text-sm",
            variant === "4" && "rounded-xl",
          )}
        >
          {isSubmitting ? (
            <span className="flex items-center gap-2">
              <svg className="h-4 w-4 animate-spin" viewBox="0 0 24 24" fill="none">
                <circle cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="3" strokeDasharray="31.4 31.4" strokeLinecap="round" />
              </svg>
              {t.waitlist.submitting}
            </span>
          ) : (
            t.waitlist.submit
          )}
        </button>
      </div>

      {/* Turnstile widget */}
      <div ref={turnstileRef} className="flex justify-center" />

      {/* Error / rate limit messages */}
      {status === "error" && (
        <p className="text-center text-sm text-destructive">
          {t.waitlist.errorTitle}: {t.waitlist.errorMessage}
        </p>
      )}
      {status === "rate_limited" && (
        <p className="text-center text-sm text-destructive">
          {t.waitlist.rateLimitTitle}: {t.waitlist.rateLimitMessage}
        </p>
      )}
      {status === "turnstile_expired" && (
        <p className="text-center text-sm text-destructive">
          {t.waitlist.turnstileExpired}
        </p>
      )}
    </form>
  );
}

function detectPlatform(): string {
  if (typeof navigator === "undefined") return "unknown";
  const ua = navigator.userAgent;
  if (/iPhone|iPad|iPod/.test(ua)) return "ios";
  if (/Android/.test(ua)) return "android";
  return "web";
}
