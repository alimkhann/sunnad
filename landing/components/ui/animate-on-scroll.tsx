"use client";

import { useEffect, useRef, type ReactNode } from "react";
import { cn } from "@/lib/utils";

interface AnimateOnScrollProps {
  children: ReactNode;
  className?: string;
  /** Animation variant */
  animation?: "fade-up" | "fade-in" | "slide-left";
  /** Extra delay in ms on top of base animation delay */
  delay?: number;
  /** IntersectionObserver threshold (0-1) */
  threshold?: number;
}

/**
 * Wraps children in a container that animates in when scrolled into view.
 * Uses IntersectionObserver — zero JS animation runtime.
 */
export function AnimateOnScroll({
  children,
  className,
  animation = "fade-up",
  delay = 0,
  threshold = 0.15,
}: AnimateOnScrollProps): ReactNode {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;

    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          el.classList.add("scroll-visible");
          observer.unobserve(el);
        }
      },
      { threshold, rootMargin: "0px 0px -40px 0px" },
    );

    observer.observe(el);
    return () => observer.disconnect();
  }, [threshold]);

  const animationClass = {
    "fade-up": "scroll-fade-up",
    "fade-in": "scroll-fade-in",
    "slide-left": "scroll-slide-left",
  }[animation];

  return (
    <div
      ref={ref}
      className={cn(animationClass, className)}
      style={delay ? { transitionDelay: `${delay}ms` } : undefined}
    >
      {children}
    </div>
  );
}
