import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { createServerClient } from "@supabase/ssr";
import { adminConfig, hasAdminConfig } from "@/lib/config";

export async function GET(request: NextRequest): Promise<NextResponse> {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get("code");

  if (!code || !hasAdminConfig()) {
    return NextResponse.redirect(`${origin}/en`);
  }

  const cookieStore = request.cookies;
  const response = NextResponse.redirect(`${origin}/en`);

  const supabase = createServerClient(
    adminConfig.supabaseURL,
    adminConfig.supabaseAnonKey,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          for (const { name, value, options } of cookiesToSet) {
            response.cookies.set(name, value, options);
          }
        },
      },
    },
  );

  const { error } = await supabase.auth.exchangeCodeForSession(code);

  if (error) {
    console.error("PKCE code exchange failed:", error.message);
    return NextResponse.redirect(`${origin}/en`);
  }

  return response;
}
