import type { ReactNode } from "react";
import type { Dictionary, VariantId } from "@/lib/i18n";
import { cn } from "@/lib/utils";
import { PhoneFrame } from "@/components/ui/phone-frame";

const screens = ["today", "habit-detail", "groups"] as const;

interface ScreenshotCarouselProps {
  variant: VariantId;
  t: Dictionary;
}

export function ScreenshotCarousel({ variant, t }: ScreenshotCarouselProps): ReactNode {
  return (
    <section className="py-20 sm:py-28">
      <div className="mx-auto max-w-6xl px-4 sm:px-6">
        {/* Header */}
        <div className="mx-auto max-w-2xl text-center">
          {variant === "2" && <div className="editorial-rule mx-auto mb-8 w-24" />}
          <h2
            className={cn(
              "text-3xl font-bold tracking-tight text-foreground sm:text-4xl",
              variant === "2" && "italic",
              variant === "3" && "uppercase tracking-tighter font-black",
            )}
          >
            {t.screenshots.title}
          </h2>
          <p className="mt-3 text-lg text-muted-foreground">
            {t.screenshots.subtitle}
          </p>
        </div>

        {/* Carousel */}
        <div className="mt-14 flex gap-6 overflow-x-auto pb-8 hide-scrollbar snap-x snap-mandatory scroll-px-4">
          {screens.map((screen, i) => (
            <div
              key={screen}
              className={cn(
                "flex-shrink-0 snap-center opacity-0 animate-fade-up",
                `stagger-${i + 2}`,
              )}
            >
              <PhoneFrame variant={variant} screen={screen} size="large" />
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
