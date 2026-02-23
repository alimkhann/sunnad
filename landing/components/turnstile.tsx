"use client";

import { useEffect, useRef, useCallback } from "react";

declare global {
  interface Window {
    turnstile?: {
      render: (
        container: HTMLElement,
        options: Record<string, unknown>,
      ) => string;
      reset: (widgetId: string) => void;
      remove: (widgetId: string) => void;
    };
    onTurnstileLoad?: () => void;
  }
}

interface TurnstileProps {
  siteKey: string;
  theme?: "light" | "dark";
  onToken: (token: string) => void;
  onExpired?: () => void;
  onError?: () => void;
  className?: string;
}

let scriptLoaded = false;
let scriptLoading = false;
const loadCallbacks: (() => void)[] = [];

function loadTurnstileScript(): Promise<void> {
  if (scriptLoaded) return Promise.resolve();

  return new Promise((resolve) => {
    if (scriptLoading) {
      loadCallbacks.push(resolve);
      return;
    }

    scriptLoading = true;
    loadCallbacks.push(resolve);

    (window as unknown as Record<string, unknown>).onTurnstileLoad = () => {
      scriptLoaded = true;
      scriptLoading = false;
      loadCallbacks.forEach((cb) => cb());
      loadCallbacks.length = 0;
    };

    const script = document.createElement("script");
    script.src =
      "https://challenges.cloudflare.com/turnstile/v0/api.js?onload=onTurnstileLoad&render=explicit";
    script.async = true;
    document.head.appendChild(script);
  });
}

export function Turnstile({
  siteKey,
  theme = "light",
  onToken,
  onExpired,
  onError,
  className,
}: TurnstileProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const widgetIdRef = useRef<string | null>(null);
  const callbacksRef = useRef({ onToken, onExpired, onError });

  // Keep callbacks ref up to date without triggering re-renders
  useEffect(() => {
    callbacksRef.current = { onToken, onExpired, onError };
  });

  useEffect(() => {
    let mounted = true;

    loadTurnstileScript().then(() => {
      if (!mounted || !containerRef.current || !window.turnstile) return;

      // Clear any previous widget
      if (widgetIdRef.current) {
        try {
          window.turnstile.remove(widgetIdRef.current);
        } catch {}
      }
      containerRef.current.innerHTML = "";

      widgetIdRef.current = window.turnstile.render(containerRef.current, {
        sitekey: siteKey,
        theme,
        retry: "never",
        "refresh-expired": "manual",
        "refresh-timeout": "manual",
        callback: (token: string) => callbacksRef.current.onToken(token),
        "expired-callback": () => callbacksRef.current.onExpired?.(),
        "error-callback": () => callbacksRef.current.onError?.(),
      });
    });

    return () => {
      mounted = false;
      if (widgetIdRef.current && window.turnstile) {
        try {
          window.turnstile.remove(widgetIdRef.current);
        } catch {}
      }
    };
  }, [siteKey, theme]);

  return <div ref={containerRef} className={className} />;
}

export function resetTurnstile(widgetElement: HTMLElement | null) {
  if (!widgetElement || !window.turnstile) return;
  const widgetId = widgetElement.getAttribute("data-turnstile-id");
  if (widgetId) window.turnstile.reset(widgetId);
}
