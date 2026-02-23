import type { NextRequest } from "next/server";
import { NextResponse } from "next/server";
import { isLocale } from "@/lib/i18n";

const defaultLocale = "en";

export function proxy(request: NextRequest): NextResponse {
  const pathname = request.nextUrl.pathname;

  // Skip static assets, API routes, and Next internals
  if (
    pathname.startsWith("/_next") ||
    pathname.startsWith("/api") ||
    pathname.includes(".")
  ) {
    return NextResponse.next();
  }

  const segments = pathname.split("/").filter(Boolean);

  // If first segment is a locale, continue
  if (segments.length > 0 && isLocale(segments[0])) {
    return NextResponse.next();
  }

  // Otherwise redirect to default locale prefix
  const url = request.nextUrl.clone();
  url.pathname = `/${defaultLocale}${pathname === "/" ? "" : pathname}`;
  return NextResponse.redirect(url);
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|screenshots|fonts).*)"],
};
