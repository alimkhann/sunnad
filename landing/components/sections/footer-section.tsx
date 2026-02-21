import type { ReactNode } from "react";
import Link from "next/link";
import type { Dictionary, Locale, VariantId } from "@/lib/i18n";
import { cn } from "@/lib/utils";

interface FooterSectionProps {
  variant: VariantId;
  locale: Locale;
  t: Dictionary;
}

export function FooterSection({ variant, locale, t }: FooterSectionProps): ReactNode {
  return (
    <footer className="border-t border-border/50 py-12 sm:py-16">
      <div className="mx-auto max-w-6xl px-4 sm:px-6">
        <div className="flex flex-col items-center gap-6 text-center">
          {/* Logo + tagline */}
          <div>
            <p className="text-xl font-bold font-heading text-foreground">
              {t.nav.logo}
            </p>
            <p className="mt-1 text-sm text-muted-foreground">
              {t.footer.tagline}
            </p>
          </div>

          {/* Links */}
          <div className="flex items-center gap-6">
            <Link
              href={`/${locale}/terms`}
              className="text-sm text-muted-foreground hover:text-foreground transition-colors"
            >
              {t.footer.terms}
            </Link>
            <span className="text-muted-foreground/30">·</span>
            <Link
              href={`/${locale}/privacy`}
              className="text-sm text-muted-foreground hover:text-foreground transition-colors"
            >
              {t.footer.privacy}
            </Link>
          </div>

          {/* Language switcher */}
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
                {t.locale[l]}
              </Link>
            ))}
          </div>

          {/* Made with */}
          <p className="text-xs text-muted-foreground/60">
            {t.footer.madeWith}
          </p>
        </div>
      </div>
    </footer>
  );
}
