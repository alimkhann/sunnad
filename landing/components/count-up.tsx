"use client";

import { useEffect, useRef } from "react";
import { useInView, useMotionValue, useSpring } from "framer-motion";

interface CountUpProps {
  to: number;
  from?: number;
  direction?: "up" | "down";
  delay?: number;
  duration?: number;
  className?: string;
  startWhen?: boolean;
  separator?: string;
  onStart?: () => void;
  onEnd?: () => void;
}

export default function CountUp({
  to,
  from = 0,
  direction = "up",
  delay = 0,
  duration = 2,
  className = "",
  startWhen = true,
  separator = "",
  onStart,
  onEnd,
}: CountUpProps) {
  const ref = useRef<HTMLSpanElement>(null);
  const motionValue = useMotionValue(direction === "down" ? to : from);

  // Use a spring with custom bounce and damping for fluid, Reactbits-style counting
  const springValue = useSpring(motionValue, {
    damping: 30, // Higher damping for less oscillation
    stiffness: 100, // Speed of the spring
    restDelta: 0.001,
  });

  const isInView = useInView(ref, { once: true, margin: "0px" });

  // Update text content reactively
  useEffect(() => {
    const unsub = springValue.on("change", (latest: number) => {
      if (ref.current) {
        const formatted = Intl.NumberFormat("en-US", {
          useGrouping: !!separator,
        })
          .format(Math.floor(latest))
          .replace(/,/g, separator); // Use custom separator if provided, though Intl covers common cases
        ref.current.textContent = formatted;
      }
    });
    return () => unsub();
  }, [springValue, separator]);

  // Trigger animation
  useEffect(() => {
    if (isInView && startWhen) {
      if (typeof onStart === "function") {
        const timeout = setTimeout(onStart, delay * 1000);
        return () => clearTimeout(timeout);
      }
      setTimeout(() => {
        motionValue.set(direction === "down" ? from : to);
      }, delay * 1000);

      const cleanup = springValue.on("change", (latest) => {
        if (latest === (direction === "down" ? from : to) && typeof onEnd === "function") {
          onEnd();
        }
      });
      return () => cleanup();
    }
  }, [isInView, startWhen, motionValue, direction, from, to, delay, onStart, onEnd, springValue]);

  return <span className={className} ref={ref} />;
}
