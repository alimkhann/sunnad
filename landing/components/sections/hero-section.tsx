import type { ReactNode } from "react";
import type { Dictionary, VariantId } from "@/lib/i18n";
import { cn } from "@/lib/utils";
import { PhoneFrame } from "@/components/ui/phone-frame";

interface HeroSectionProps {
  variant: VariantId;
  t: Dictionary;
}

export function HeroSection({ variant, t }: HeroSectionProps): ReactNode {
  return (
    <section className="relative overflow-hidden">
      <div className="mx-auto max-w-6xl px-4 sm:px-6">
        <div
          className={cn(
            "flex flex-col items-center gap-10 py-16 sm:py-24",
            "lg:flex-row lg:items-center lg:gap-16 lg:py-32",
          )}
        >
          {/* Text column */}
          <div className="flex-1 text-center lg:text-left">
            {/* Badge */}
            <div
              className={cn(
                "mb-6 inline-flex items-center gap-2 rounded-full px-4 py-1.5 text-xs font-semibold opacity-0 animate-fade-up",
                variant === "5"
                  ? "bg-primary/15 text-primary"
                  : "bg-primary/10 text-primary",
              )}
            >
              <span className="relative flex h-2 w-2">
                <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-primary opacity-75" />
                <span className="relative inline-flex h-2 w-2 rounded-full bg-primary" />
              </span>
              {t.hero.badge}
            </div>

            {/* Title */}
            <h1
              className={cn(
                "text-4xl font-bold tracking-tight text-foreground opacity-0 animate-fade-up stagger-1 sm:text-5xl lg:text-6xl",
                variant === "2" && "font-heading italic",
                variant === "3" && "font-heading font-black uppercase tracking-tighter",
              )}
            >
              {t.hero.title.split("\n").map((line, i) => (
                <span key={i}>
                  {line}
                  {i === 0 && <br />}
                </span>
              ))}
            </h1>

            {/* Subtitle */}
            <p className="mt-6 max-w-xl text-lg leading-relaxed text-muted-foreground opacity-0 animate-fade-up stagger-2 lg:text-xl">
              {t.hero.subtitle}
            </p>

            {/* CTA */}
            <div className="mt-8 opacity-0 animate-fade-up stagger-3">
              <a
                href="#waitlist"
                className={cn(
                  "inline-flex h-12 items-center justify-center rounded-lg bg-primary px-8 text-base font-semibold text-primary-foreground shadow-lg transition-all hover:opacity-90 hover:shadow-xl sm:h-14 sm:px-10 sm:text-lg",
                  variant === "4" && "rounded-2xl",
                  variant === "3" && "rounded-sm uppercase tracking-wider text-sm",
                )}
              >
                {t.hero.cta}
              </a>
            </div>
          </div>

          {/* Phone mockup column */}
          <div className="relative flex-shrink-0 opacity-0 animate-fade-up stagger-4">
            <div className={cn(variant !== "3" && "animate-float")}>
              <PhoneFrame variant={variant} screen="today" />
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
