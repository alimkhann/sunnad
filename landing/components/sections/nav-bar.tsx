"use client";

import { type ReactNode, useState } from "react";
import Link from "next/link";
import type { Dictionary, Locale, VariantId } from "@/lib/i18n";
import { cn } from "@/lib/utils";

interface NavBarProps {
  variant: VariantId;
  locale: Locale;
  t: Dictionary;
}

export function NavBar({ variant, locale, t }: NavBarProps): ReactNode {
  const [menuOpen, setMenuOpen] = useState(false);

  return (
    <nav
      className={cn(
        "sticky top-0 z-50 w-full border-b border-border/50 backdrop-blur-xl",
        variant === "5" ? "bg-background/80" : "bg-background/70",
      )}
    >
      <div className="mx-auto flex h-16 max-w-6xl items-center justify-between px-4 sm:px-6">
        {/* Logo */}
        <Link href={`/${locale}`} className="text-xl font-bold font-heading text-foreground">
          {t.nav.logo}
        </Link>

        {/* Desktop nav */}
        <div className="hidden items-center gap-6 md:flex">
          <a href="#features" className="text-sm font-medium text-muted-foreground hover:text-foreground transition-colors">
            {t.nav.features}
          </a>
          <a href="#faq" className="text-sm font-medium text-muted-foreground hover:text-foreground transition-colors">
            {t.nav.faq}
          </a>
          <LanguageLinks locale={locale} variant={variant} t={t} />
          <a
            href="#waitlist"
            className="rounded-lg bg-primary px-4 py-2 text-sm font-semibold text-primary-foreground transition-colors hover:opacity-90"
          >
            {t.nav.waitlist}
          </a>
        </div>

        {/* Mobile hamburger */}
        <button
          onClick={() => setMenuOpen(!menuOpen)}
          className="flex h-11 w-11 items-center justify-center rounded-lg md:hidden hover:bg-muted transition-colors"
          aria-label="Menu"
        >
          <svg width="20" height="20" viewBox="0 0 20 20" fill="none" className="text-foreground">
            {menuOpen ? (
              <path d="M5 5L15 15M15 5L5 15" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
            ) : (
              <>
                <path d="M3 5h14M3 10h14M3 15h14" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
              </>
            )}
          </svg>
        </button>
      </div>

      {/* Mobile menu */}
      {menuOpen && (
        <div className="border-t border-border/50 bg-background/95 backdrop-blur-xl px-4 py-4 md:hidden">
          <div className="flex flex-col gap-3">
            <a
              href="#features"
              onClick={() => setMenuOpen(false)}
              className="rounded-lg px-3 py-2 text-sm font-medium text-muted-foreground hover:bg-muted"
            >
              {t.nav.features}
            </a>
            <a
              href="#faq"
              onClick={() => setMenuOpen(false)}
              className="rounded-lg px-3 py-2 text-sm font-medium text-muted-foreground hover:bg-muted"
            >
              {t.nav.faq}
            </a>
            <a
              href="#waitlist"
              onClick={() => setMenuOpen(false)}
              className="rounded-lg bg-primary px-3 py-2 text-center text-sm font-semibold text-primary-foreground"
            >
              {t.nav.waitlist}
            </a>
            <div className="mt-2 border-t border-border/50 pt-3">
              <LanguageLinks locale={locale} variant={variant} t={t} />
            </div>
          </div>
        </div>
      )}
    </nav>
  );
}

function LanguageLinks({
  locale,
  variant,
  t,
}: {
  locale: Locale;
  variant: VariantId;
  t: Dictionary;
}): ReactNode {
  return (
    <div className="flex items-center gap-1.5">
      {(["en", "ru", "kk"] as const).map((l) => (
        <Link
          key={l}
          href={`/${l}/${variant}`}
          className={cn(
            "rounded-md px-2.5 py-1 text-xs font-medium transition-colors",
            l === locale
              ? "bg-primary/10 text-primary"
              : "text-muted-foreground hover:text-foreground hover:bg-muted",
          )}
        >
          {l.toUpperCase()}
        </Link>
      ))}
    </div>
  );
}
