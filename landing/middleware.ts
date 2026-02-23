import type { NextRequest } from "next/server";
import { NextResponse } from "next/server";
import { isLocale, isVariantId } from "@/lib/i18n";

const defaultLocale = "en";

export function middleware(request: NextRequest): NextResponse {
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

  // If first segment is a variant number (e.g. /3), rewrite to /en/3
  if (segments.length === 1 && isVariantId(segments[0])) {
    const url = request.nextUrl.clone();
    url.pathname = `/${defaultLocale}/${segments[0]}`;
    return NextResponse.redirect(url);
  }

  // Otherwise redirect to default locale prefix
  const url = request.nextUrl.clone();
  url.pathname = `/${defaultLocale}${pathname === "/" ? "" : pathname}`;
  return NextResponse.redirect(url);
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|screenshots|fonts).*)"],
};
