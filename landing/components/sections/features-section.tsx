import type { ReactNode } from "react";
import type { Dictionary, VariantId } from "@/lib/i18n";
import { cn } from "@/lib/utils";

/* SVG icon components for features */
function HabitsIcon({ className }: { className?: string }): ReactNode {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M9 11l3 3L22 4" />
      <path d="M21 12v7a2 2 0 01-2 2H5a2 2 0 01-2-2V5a2 2 0 012-2h11" />
    </svg>
  );
}

function QuotesIcon({ className }: { className?: string }): ReactNode {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M3 21c3 0 7-1 7-8V5c0-1.25-.756-2.017-2-2H4c-1.25 0-2 .75-2 1.972V11c0 1.25.75 2 2 2 1 0 1 0 1 1v1c0 1-1 2-2 2s-1 .008-1 1.031V21z" />
      <path d="M15 21c3 0 7-1 7-8V5c0-1.25-.757-2.017-2-2h-4c-1.25 0-2 .75-2 1.972V11c0 1.25.75 2 2 2h.75c0 2.25.25 4-2.75 4v3c0 1 0 1 1 1z" />
    </svg>
  );
}

function GroupsIcon({ className }: { className?: string }): ReactNode {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2" />
      <circle cx="9" cy="7" r="4" />
      <path d="M23 21v-2a4 4 0 00-3-3.87M16 3.13a4 4 0 010 7.75" />
    </svg>
  );
}

function OfflineIcon({ className }: { className?: string }): ReactNode {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
    </svg>
  );
}

const featureIcons = {
  habits: HabitsIcon,
  quotes: QuotesIcon,
  groups: GroupsIcon,
  offline: OfflineIcon,
};

const featureKeys = ["habits", "quotes", "groups", "offline"] as const;

interface FeaturesSectionProps {
  variant: VariantId;
  t: Dictionary;
}

export function FeaturesSection({ variant, t }: FeaturesSectionProps): ReactNode {
  return (
    <section id="features" className="scroll-mt-20 py-20 sm:py-28">
      <div className="mx-auto max-w-6xl px-4 sm:px-6">
        {/* Section header */}
        <div className="mx-auto max-w-2xl text-center">
          {variant === "2" && <div className="editorial-rule mx-auto mb-8 w-24" />}
          <h2
            className={cn(
              "text-3xl font-bold tracking-tight text-foreground sm:text-4xl",
              variant === "2" && "italic",
              variant === "3" && "uppercase tracking-tighter font-black",
            )}
          >
            {t.features.title}
          </h2>
          <p className="mt-3 text-lg text-muted-foreground">
            {t.features.subtitle}
          </p>
        </div>

        {/* Feature grid */}
        <div className="mt-16 grid grid-cols-1 gap-6 sm:grid-cols-2 lg:gap-8">
          {featureKeys.map((key, i) => {
            const Icon = featureIcons[key];
            const item = t.features.items[key];
            return (
              <div
                key={key}
                className={cn(
                  "group relative rounded-lg border p-6 sm:p-8 transition-all duration-300",
                  "hover:-translate-y-1",
                  variant === "1" && "glass-card hover:shadow-lg hover:shadow-primary/5",
                  variant === "2" && "border-border bg-card hover:border-primary/30 hover:shadow-sm",
                  variant === "3" && "rounded-sm border-border bg-card hover:bg-muted/50 hover:border-primary/40",
                  variant === "4" && "rounded-2xl border-border bg-card shadow-sm hover:shadow-md hover:shadow-primary/5 paper-texture",
                  variant === "5" && "border-border/50 bg-card/50 backdrop-blur hover:border-primary/30 hover:bg-card/70",
                )}
              >
                <div
                  className={cn(
                    "mb-4 flex h-12 w-12 items-center justify-center rounded-lg",
                    variant === "5" ? "bg-primary/15" : "bg-primary/10",
                  )}
                >
                  <Icon className="h-6 w-6 text-primary" />
                </div>
                <h3
                  className={cn(
                    "text-lg font-semibold text-foreground",
                    variant === "3" && "uppercase tracking-wide text-base",
                  )}
                >
                  {item.title}
                </h3>
                <p className="mt-2 text-sm leading-relaxed text-muted-foreground sm:text-base">
                  {item.description}
                </p>
                {variant === "2" && (
                  <div className="editorial-rule mt-6 w-12 opacity-0 transition-opacity group-hover:opacity-100" />
                )}
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
}
