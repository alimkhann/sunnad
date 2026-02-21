import type { ReactNode } from "react";
import type { Dictionary, Locale, VariantId } from "@/lib/i18n";
import { NavBar } from "@/components/sections/nav-bar";
import { HeroSection } from "@/components/sections/hero-section";
import { FeaturesSection } from "@/components/sections/features-section";
import { ScreenshotCarousel } from "@/components/sections/screenshot-carousel";
import { FAQSection } from "@/components/sections/faq-section";
import { WaitlistSection } from "@/components/sections/waitlist-section";
import { FooterSection } from "@/components/sections/footer-section";

interface VariantShellProps {
  variant: VariantId;
  locale: Locale;
  t: Dictionary;
}

export function VariantShell({ variant, locale, t }: VariantShellProps): ReactNode {
  return (
    <div data-variant={variant} className="relative min-h-screen">
      {/* Variant-specific background effects */}
      {variant === "1" && <div className="frost-bg" />}
      {variant === "5" && <div className="star-field" />}

      {/* Content */}
      <div className="relative z-10">
        <NavBar variant={variant} locale={locale} t={t} />
        <main>
          <HeroSection variant={variant} t={t} />
          <FeaturesSection variant={variant} t={t} />
          <ScreenshotCarousel variant={variant} t={t} />
          <FAQSection variant={variant} t={t} />
          <WaitlistSection variant={variant} locale={locale} t={t} />
        </main>
        <FooterSection variant={variant} locale={locale} t={t} />
      </div>
    </div>
  );
}
