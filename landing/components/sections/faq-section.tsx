"use client";

import { type ReactNode, useState } from "react";
import type { Dictionary, VariantId } from "@/lib/i18n";
import { cn } from "@/lib/utils";

interface FAQSectionProps {
  variant: VariantId;
  t: Dictionary;
}

export function FAQSection({ variant, t }: FAQSectionProps): ReactNode {
  return (
    <section id="faq" className="scroll-mt-20 py-20 sm:py-28">
      <div className="mx-auto max-w-3xl px-4 sm:px-6">
        {/* Header */}
        <div className="text-center">
          {variant === "2" && <div className="editorial-rule mx-auto mb-8 w-24" />}
          <h2
            className={cn(
              "text-3xl font-bold tracking-tight text-foreground sm:text-4xl",
              variant === "2" && "italic",
              variant === "3" && "uppercase tracking-tighter font-black",
            )}
          >
            {t.faq.title}
          </h2>
        </div>

        {/* Accordion */}
        <div className="mt-12 space-y-3">
          {t.faq.items.map((item, i) => (
            <AccordionItem
              key={i}
              question={item.q}
              answer={item.a}
              variant={variant}
            />
          ))}
        </div>
      </div>
    </section>
  );
}

function AccordionItem({
  question,
  answer,
  variant,
}: {
  question: string;
  answer: string;
  variant: VariantId;
}): ReactNode {
  const [open, setOpen] = useState(false);

  return (
    <div
      className={cn(
        "overflow-hidden rounded-lg border transition-colors",
        open ? "border-primary/30 bg-card" : "border-border bg-card/50",
        variant === "3" && "rounded-sm",
        variant === "4" && "rounded-2xl",
      )}
    >
      <button
        onClick={() => setOpen(!open)}
        className="flex w-full items-center justify-between px-5 py-4 text-left sm:px-6 sm:py-5"
      >
        <span
          className={cn(
            "text-base font-medium text-foreground pr-4",
            variant === "3" && "uppercase tracking-wide text-sm",
          )}
        >
          {question}
        </span>
        <svg
          className={cn(
            "h-5 w-5 flex-shrink-0 text-muted-foreground transition-transform duration-200",
            open && "rotate-180",
          )}
          viewBox="0 0 20 20"
          fill="currentColor"
        >
          <path
            fillRule="evenodd"
            d="M5.23 7.21a.75.75 0 011.06.02L10 11.168l3.71-3.938a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z"
            clipRule="evenodd"
          />
        </svg>
      </button>
      <div
        className={cn(
          "grid transition-all duration-200",
          open ? "grid-rows-[1fr] opacity-100" : "grid-rows-[0fr] opacity-0",
        )}
      >
        <div className="overflow-hidden">
          <p className="px-5 pb-5 text-sm leading-relaxed text-muted-foreground sm:px-6 sm:text-base">
            {answer}
          </p>
        </div>
      </div>
    </div>
  );
}
