"use client";

import { motion } from "framer-motion";
import Link from "next/link";
import type { SharedDict } from "@/lib/i18n";
import { locales, type Locale } from "@/lib/i18n";

/* ── Types ── */
interface Props {
  locale: string;
  dict: SharedDict;
}

/* ── Variant metadata ── */
const cards = [
  {
    id: "1",
    name: "Sacred Geometry",
    subtitle: "Where tradition meets editorial elegance",
    gradient: "linear-gradient(145deg, #1a3a2a 0%, #2d5a3f 50%, #1a3a2a 100%)",
    text: "#faf7f2",
    accent: "#c4a265",
    font: "'Playfair Display', serif",
    numberFont: "'Cormorant Garamond', serif",
    decoration: "geometric",
  },
  {
    id: "2",
    name: "Dawn to Dusk",
    subtitle: "A journey from sunrise to starlight",
    gradient:
      "linear-gradient(135deg, #fce4e4 0%, #93c5fd 40%, #6366f1 70%, #1e1b4b 100%)",
    text: "#ffffff",
    accent: "#fce4e4",
    font: "'Plus Jakarta Sans', sans-serif",
    numberFont: "'Crimson Pro', serif",
    decoration: "dawn",
  },
  {
    id: "3",
    name: "Brutalist Grid",
    subtitle: "Bold structure. Raw energy.",
    gradient: "#f5f5f0",
    text: "#0a0a0a",
    accent: "#00e87b",
    font: "'Syne', sans-serif",
    numberFont: "'JetBrains Mono', monospace",
    decoration: "brutalist",
  },
  {
    id: "4",
    name: "Night Devotion",
    subtitle: "Premium darkness. Inner light.",
    gradient: "linear-gradient(160deg, #0a0e1a 0%, #131740 50%, #0a0e1a 100%)",
    text: "#e0e0ff",
    accent: "#ffd700",
    font: "'Unbounded', sans-serif",
    numberFont: "'Space Mono', monospace",
    decoration: "night",
  },
  {
    id: "5",
    name: "Handcrafted Warmth",
    subtitle: "Organic, friendly, human-centered",
    gradient: "linear-gradient(145deg, #faf3eb 0%, #f5ece0 100%)",
    text: "#3d2c1e",
    accent: "#e8917a",
    font: "'Fraunces', serif",
    numberFont: "'Caveat', cursive",
    decoration: "warm",
  },
] as const;

/* ── Animations ── */
const stagger = { hidden: {}, show: { transition: { staggerChildren: 0.08 } } };
const fadeUp = {
  hidden: { opacity: 0, y: 24 },
  show: {
    opacity: 1,
    y: 0,
    transition: { duration: 0.6, ease: [0.22, 1, 0.36, 1] as const },
  },
};
const cardAnim = {
  hidden: { opacity: 0, y: 32, scale: 0.97 },
  show: {
    opacity: 1,
    y: 0,
    scale: 1,
    transition: { duration: 0.55, ease: [0.22, 1, 0.36, 1] as const },
  },
};

/* ── Card decoration overlays (subtle) ── */
function CardDecoration({ type }: { type: string }) {
  if (type === "geometric") {
    return (
      <svg
        className="absolute top-4 right-4 w-24 h-24 opacity-[0.12]"
        viewBox="0 0 100 100"
      >
        <path
          d="M50 0L100 50L50 100L0 50Z"
          fill="none"
          stroke="#c4a265"
          strokeWidth="1"
        />
        <circle
          cx="50"
          cy="50"
          r="20"
          fill="none"
          stroke="#c4a265"
          strokeWidth="0.8"
        />
        <path d="M50 0L50 100M0 50L100 50" stroke="#c4a265" strokeWidth="0.4" />
      </svg>
    );
  }
  if (type === "brutalist") {
    return (
      <>
        <div
          className="absolute top-0 right-0 w-12 h-12"
          style={{ background: "#00e87b" }}
        />
        <div className="absolute inset-[3px] border-2 border-black/80 pointer-events-none rounded-xl" />
      </>
    );
  }
  if (type === "night") {
    return (
      <div
        className="absolute inset-0 pointer-events-none"
        style={{
          background:
            "radial-gradient(ellipse at 60% 30%, rgba(99,102,241,0.2) 0%, transparent 50%)",
        }}
      />
    );
  }
  if (type === "warm") {
    return (
      <svg
        className="absolute bottom-3 right-3 w-16 h-16 opacity-20"
        viewBox="0 0 100 100"
      >
        <circle cx="50" cy="50" r="40" fill="#e8917a" />
      </svg>
    );
  }
  return null; /* dawn: gradient IS the decoration */
}

/* ── PickerPage ── */
export function PickerPage({ locale, dict }: Props) {
  return (
    <div
      className="min-h-screen relative"
      style={{ fontFamily: "'Sora', sans-serif", background: "#07070a" }}
    >
      {/* Ambient glow */}
      <div
        className="fixed inset-0 pointer-events-none"
        style={{
          background:
            "radial-gradient(ellipse at 25% 0%, rgba(212,168,83,0.05) 0%, transparent 50%), radial-gradient(ellipse at 75% 100%, rgba(139,92,246,0.03) 0%, transparent 50%)",
        }}
      />

      {/* Header */}
      <header className="relative z-30 flex items-center justify-between px-6 lg:px-16 py-5">
        <Link href={`/${locale}`} className="flex items-center gap-2.5 group">
          <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-amber-400 to-amber-600 flex items-center justify-center shadow-lg shadow-amber-500/20">
            <span className="text-black font-bold text-sm">S</span>
          </div>
          <span className="text-white/90 font-semibold tracking-tight text-[15px]">
            Sunnad
          </span>
        </Link>
        <div className="flex items-center gap-1 text-[13px] text-white/40">
          {locales.map((l) => (
            <Link
              key={l}
              href={`/${l}`}
              className={`px-2.5 py-1 rounded-md transition-all ${
                l === locale
                  ? "text-white bg-white/10"
                  : "hover:text-white/70 hover:bg-white/5"
              }`}
            >
              {dict.locale[l as Locale]}
            </Link>
          ))}
        </div>
      </header>

      {/* Hero */}
      <motion.section
        className="relative z-10 px-6 lg:px-16 pt-16 pb-14 lg:pt-24 lg:pb-20 max-w-7xl mx-auto"
        variants={stagger}
        initial="hidden"
        animate="show"
      >
        <motion.div variants={fadeUp} className="flex items-center gap-3 mb-5">
          <div className="h-px w-8 bg-amber-400/60" />
          <span className="text-amber-400/70 text-xs tracking-[0.3em] uppercase font-medium">
            Coming 2025
          </span>
        </motion.div>
        <motion.h1
          variants={fadeUp}
          className="text-white text-[clamp(2.2rem,5.5vw,4.5rem)] font-bold tracking-tight leading-[1.08] mb-5"
        >
          Five visions.{" "}
          <span className="text-transparent bg-clip-text bg-gradient-to-r from-amber-300 via-amber-400 to-orange-400">
            One calling.
          </span>
        </motion.h1>
        <motion.p
          variants={fadeUp}
          className="text-white/40 text-base lg:text-[17px] max-w-md leading-relaxed"
        >
          {dict.picker.subtitle}
        </motion.p>
      </motion.section>

      {/* Gallery Grid */}
      <motion.section
        className="relative z-10 px-6 lg:px-16 pb-20 max-w-7xl mx-auto"
        variants={stagger}
        initial="hidden"
        whileInView="show"
        viewport={{ once: true, amount: 0.05 }}
      >
        <div className="grid grid-cols-1 md:grid-cols-12 gap-4">
          {cards.map((card, i) => {
            const span =
              i === 0
                ? "md:col-span-7"
                : i === 1
                  ? "md:col-span-5"
                  : "md:col-span-4";
            const h =
              i < 2 ? "h-[260px] lg:h-[320px]" : "h-[220px] lg:h-[260px]";

            return (
              <motion.div key={card.id} variants={cardAnim} className={span}>
                <Link href={`/${locale}/${card.id}`} className="block group">
                  <div
                    className={`relative ${h} rounded-2xl overflow-hidden transition-all duration-300 group-hover:scale-[1.015] group-hover:shadow-2xl`}
                    style={{ background: card.gradient }}
                  >
                    <CardDecoration type={card.decoration} />

                    {/* Bottom gradient for text legibility */}
                    <div
                      className="absolute inset-0 z-10"
                      style={{
                        background:
                          card.decoration === "brutalist"
                            ? "none"
                            : "linear-gradient(to top, rgba(0,0,0,0.35) 0%, transparent 55%)",
                      }}
                    />

                    {/* Content */}
                    <div className="relative z-20 h-full flex flex-col justify-between p-5 lg:p-7">
                      <span
                        className="text-[2.5rem] lg:text-[3rem] font-light leading-none opacity-25"
                        style={{
                          fontFamily: card.numberFont,
                          color: card.text,
                        }}
                      >
                        0{card.id}
                      </span>

                      <div>
                        <h2
                          className="text-lg lg:text-xl font-semibold mb-0.5 tracking-tight"
                          style={{ fontFamily: card.font, color: card.text }}
                        >
                          {card.name}
                        </h2>
                        <p
                          className="text-[13px] opacity-50 mb-3"
                          style={{ color: card.text }}
                        >
                          {card.subtitle}
                        </p>
                        <span
                          className="inline-flex items-center gap-1.5 text-[11px] font-semibold tracking-widest uppercase opacity-60 group-hover:opacity-100 transition-opacity"
                          style={{ color: card.accent }}
                        >
                          {dict.picker.explore}
                          <svg
                            width="14"
                            height="14"
                            viewBox="0 0 16 16"
                            fill="none"
                          >
                            <path
                              d="M3 8h10M9 4l4 4-4 4"
                              stroke="currentColor"
                              strokeWidth="1.5"
                              strokeLinecap="round"
                              strokeLinejoin="round"
                            />
                          </svg>
                        </span>
                      </div>
                    </div>
                  </div>
                </Link>
              </motion.div>
            );
          })}
        </div>
      </motion.section>

      {/* Footer */}
      <footer className="relative z-10 border-t border-white/[0.06] px-6 lg:px-16 py-7">
        <div className="max-w-7xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-4 text-[13px] text-white/25">
          <p>&copy; {new Date().getFullYear()} Sunnad</p>
          <div className="flex gap-6">
            <Link
              href={`/${locale}/terms`}
              className="hover:text-white/50 transition-colors"
            >
              {dict.legal.terms}
            </Link>
            <Link
              href={`/${locale}/privacy`}
              className="hover:text-white/50 transition-colors"
            >
              {dict.legal.privacy}
            </Link>
          </div>
        </div>
      </footer>
    </div>
  );
}
