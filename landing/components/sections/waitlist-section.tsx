import type { ReactNode } from "react";
import type { Dictionary, VariantId } from "@/lib/i18n";
import { cn } from "@/lib/utils";
import { WaitlistForm } from "@/components/sections/waitlist-form";

interface WaitlistSectionProps {
  variant: VariantId;
  locale: string;
  t: Dictionary;
}

export function WaitlistSection({ variant, locale, t }: WaitlistSectionProps): ReactNode {
  return (
    <section id="waitlist" className="scroll-mt-20 py-20 sm:py-28">
      <div className="mx-auto max-w-2xl px-4 sm:px-6">
        <div
          className={cn(
            "rounded-xl border p-8 sm:p-12",
            variant === "1" && "glass-card",
            variant === "2" && "border-border bg-card",
            variant === "3" && "rounded-sm border-border bg-card",
            variant === "4" && "rounded-3xl border-border bg-card paper-texture shadow-md",
            variant === "5" && "border-border/50 bg-card/50 backdrop-blur-xl",
          )}
        >
          <div className="text-center">
            {variant === "2" && <div className="editorial-rule mx-auto mb-8 w-24" />}
            <h2
              className={cn(
                "text-2xl font-bold text-foreground sm:text-3xl",
                variant === "2" && "italic",
                variant === "3" && "uppercase tracking-tighter font-black",
              )}
            >
              {t.waitlist.title}
            </h2>
            <p className="mt-3 text-muted-foreground">
              {t.waitlist.subtitle}
            </p>
          </div>

          <div className="mt-8">
            <WaitlistForm variant={variant} locale={locale} t={t} />
          </div>
        </div>
      </div>
    </section>
  );
}
