"use client";

import { useEffect, useRef } from "react";
import { useRouter } from "next/navigation";
import { getSupabaseBrowserClient } from "@/lib/supabase-browser";

/**
 * Auth callback page — handles both auth flows:
 *
 * 1. PKCE flow: Supabase redirects here with `?code=AUTH_CODE`.
 *    The Supabase JS client (with flowType=pkce + detectSessionInUrl)
 *    automatically exchanges the code using the code_verifier from localStorage.
 *
 * 2. Implicit flow fallback: Admin-generated links redirect here with
 *    `#access_token=...&refresh_token=...`. We parse the hash and call setSession().
 */
export default function AuthCallbackPage(): React.JSX.Element {
  const router = useRouter();
  const handled = useRef(false);

  useEffect(() => {
    if (handled.current) return;
    handled.current = true;

    const supabase = getSupabaseBrowserClient();
    if (!supabase) {
      router.replace("/en");
      return;
    }

    async function handleCallback(): Promise<void> {
      // Case 1: PKCE — ?code= in query string
      // The Supabase JS client handles this automatically via detectSessionInUrl
      const url = new URL(window.location.href);
      const code = url.searchParams.get("code");

      if (code) {
        // PKCE flow: exchangeCodeForSession is handled by Supabase client internally
        // Just wait for the auth state to settle, then redirect
        const { data: { session } } = await supabase!.auth.getSession();
        if (session) {
          router.replace("/en");
          return;
        }

        // If getSession didn't work immediately, try exchangeCodeForSession
        const { error } = await supabase!.auth.exchangeCodeForSession(code);
        if (!error) {
          router.replace("/en");
          return;
        }
        console.error("PKCE code exchange failed:", error.message);
        router.replace("/en");
        return;
      }

      // Case 2: Implicit — #access_token= in hash fragment
      const hash = window.location.hash.substring(1);
      if (hash) {
        const params = new URLSearchParams(hash);
        const accessToken = params.get("access_token");
        const refreshToken = params.get("refresh_token");

        if (accessToken && refreshToken) {
          const { error } = await supabase!.auth.setSession({
            access_token: accessToken,
            refresh_token: refreshToken,
          });
          if (error) {
            console.error("Session set failed:", error.message);
          }
          router.replace("/en");
          return;
        }
      }

      // No auth params found — redirect home
      router.replace("/en");
    }

    void handleCallback();
  }, [router]);

  return (
    <main className="flex min-h-screen items-center justify-center">
      <p className="text-muted-foreground animate-pulse">Signing in…</p>
    </main>
  );
}
