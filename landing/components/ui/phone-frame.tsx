import type { ReactNode } from "react";
import type { VariantId } from "@/lib/i18n";
import { cn } from "@/lib/utils";

interface PhoneFrameProps {
  variant: VariantId;
  screen: string;
  size?: "default" | "large";
}

/**
 * iPhone-style phone frame wrapping either a real screenshot or a styled placeholder.
 * Screenshots are expected at /screenshots/{screen}.png.
 * Falls back to a gradient placeholder when the image doesn't exist.
 */
export function PhoneFrame({
  variant,
  screen,
  size = "default",
}: PhoneFrameProps): ReactNode {
  const isLarge = size === "large";

  return (
    <div
      className={cn(
        "phone-frame relative bg-background",
        isLarge ? "w-[240px] sm:w-[260px]" : "w-[220px] sm:w-[240px]",
      )}
    >
      {/* Notch */}
      <div className="absolute left-1/2 top-0 z-10 h-7 w-28 -translate-x-1/2 rounded-b-2xl bg-foreground/10" />

      {/* Screenshot or placeholder */}
      <div className="relative h-full w-full overflow-hidden">
        {/* Gradient placeholder */}
        <PlaceholderScreen screen={screen} variant={variant} />
      </div>

      {/* Home indicator */}
      <div className="absolute bottom-2 left-1/2 z-10 h-1 w-12 -translate-x-1/2 rounded-full bg-foreground/20" />
    </div>
  );
}

function PlaceholderScreen({
  screen,
  variant,
}: {
  screen: string;
  variant: VariantId;
}): ReactNode {
  const gradients: Record<VariantId, string> = {
    "1": "from-teal-100 via-white to-emerald-50",
    "2": "from-amber-50 via-orange-50/50 to-stone-50",
    "3": "from-white via-gray-50 to-emerald-50",
    "4": "from-orange-100/80 via-amber-50 to-green-50",
    "5": "from-indigo-950 via-purple-900/50 to-slate-900",
  };

  const screenContent: Record<string, { icon: string; lines: number[] }> = {
    today: { icon: "☀️", lines: [85, 70, 60, 90, 45] },
    "habit-detail": { icon: "📿", lines: [75, 50, 85] },
    groups: { icon: "👥", lines: [80, 65, 55, 70] },
  };

  const content = screenContent[screen] ?? screenContent.today;

  return (
    <div className={cn("flex h-full flex-col bg-gradient-to-b p-4 pt-10", gradients[variant])}>
      {/* Fake status bar */}
      <div className="mb-4 flex items-center justify-between px-1">
        <div className="h-2 w-10 rounded-full bg-foreground/10" />
        <div className="h-2 w-14 rounded-full bg-foreground/10" />
      </div>

      {/* Screen icon */}
      <div className="mb-4 text-center text-3xl">{content.icon}</div>

      {/* Fake content lines */}
      <div className="space-y-3">
        {content.lines.map((width, i) => (
          <div key={i} className="space-y-1.5">
            <div
              className={cn(
                "h-10 rounded-lg",
                variant === "5" ? "bg-white/5" : "bg-foreground/[0.04]",
              )}
              style={{ width: `${width}%` }}
            />
            <div
              className={cn(
                "h-2 rounded",
                variant === "5" ? "bg-white/3" : "bg-foreground/[0.03]",
              )}
              style={{ width: `${Math.max(30, width - 20)}%` }}
            />
          </div>
        ))}
      </div>

      {/* Fake tab bar */}
      <div className="mt-auto flex items-center justify-around pt-4">
        {[1, 2, 3].map((i) => (
          <div
            key={i}
            className={cn(
              "h-6 w-6 rounded-md",
              i === 1
                ? "bg-primary/30"
                : variant === "5"
                  ? "bg-white/8"
                  : "bg-foreground/[0.06]",
            )}
          />
        ))}
      </div>
    </div>
  );
}
