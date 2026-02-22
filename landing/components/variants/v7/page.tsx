"use client";

import { useState } from "react";
import { motion } from "framer-motion";
import Link from "next/link";
import { submitWaitlist } from "@/lib/waitlist-submit";
import { Turnstile } from "@/components/turnstile";

/* ── Types ── */
interface Props {
  locale: string;
  variant: string;
}

/* ── Content ── */
const content = {
  hero: {
    badge: "Vol. 1 — The Foundation",
    title: "A return to intentional living.",
    subtitle:
      "Sunnad is an offline-first Islamic habit tracker designed for focus, consistency, and spiritual growth. No distractions, just your deen.",
  },
  features: [
    {
      id: "today",
      title: "Focus on Today",
      desc: "A clean, distraction-free checklist of what matters right now. No overwhelming backlogs.",
      img: "/app-screenshots/en_today_light.PNG",
    },
    {
      id: "dhikr",
      title: "Seamless Dhikr",
      desc: "Built-in counters for your daily adhkar. Tap anywhere, stay focused.",
      img: "/app-screenshots/en_dhikr_light.PNG",
    },
    {
      id: "groups",
      title: "Grow Together",
      desc: "Join private groups. Keep each other accountable with gentle nudges.",
      img: "/app-screenshots/en_groups_light.PNG",
    },
    {
      id: "analytics",
      title: "See Your Progress",
      desc: "Beautiful charts and streaks that motivate without inducing guilt.",
      img: "/app-screenshots/en_analytics_light.PNG",
    },
  ],
  waitlist: {
    title: "Join the Waitlist",
    subtitle: "Be among the first to experience Sunnad when we launch.",
    placeholder: "Enter your email address",
    button: "Request Access",
    success: "Alhamdulillah, you're on the list.",
    error: "Something went wrong. Please try again.",
  },
};

/* ── Components ── */

function PhoneMockup({ src, alt, className = "" }: { src: string; alt: string; className?: string }) {
  return (
    <div className={`relative w-[280px] h-[572px] md:w-[320px] md:h-[654px] shrink-0 ${className}`}>
      {/* The Screenshot */}
      <div className="absolute inset-[12px] md:inset-[14px] rounded-[32px] md:rounded-[40px] overflow-hidden bg-white shadow-inner">
        <img
          src={src}
          alt={alt}
          className="w-full h-full object-cover"
          loading="lazy"
        />
      </div>
      {/* The Bezel Overlay */}
      <img
        src="/app-screenshots/iphone_bezels.png"
        alt="iPhone Bezel"
        className="absolute inset-0 w-full h-full object-contain pointer-events-none z-10 drop-shadow-xl"
      />
    </div>
  );
}

export default function V7Page({ locale }: Props) {
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<"idle" | "loading" | "success" | "error">("idle");
  const [token, setToken] = useState<string | null>(null);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!email || !token) return;
    setStatus("loading");
    const res = await submitWaitlist({ email, turnstileToken: token, locale, variant: "7" });
    setStatus(res.status === "subscribed" || res.status === "already_subscribed" ? "success" : "error");
  }

  return (
    <div
      className="min-h-screen bg-[#F7F5F0] text-[#111111] selection:bg-[#d9381e] selection:text-white"
      style={{ fontFamily: "'Newsreader', serif" }}
    >
      {/* Header */}
      <header className="fixed top-0 left-0 right-0 z-50 flex items-center justify-between px-6 py-6 bg-[#F7F5F0]/80 backdrop-blur-md border-b border-black/10">
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 rounded-sm bg-black flex items-center justify-center">
            <span className="text-white font-bold text-sm" style={{ fontFamily: "'JetBrains Mono', monospace" }}>S</span>
          </div>
          <span className="font-semibold tracking-tight text-lg uppercase">Sunnad</span>
        </div>
        <Link
          href={`/${locale}`}
          className="text-sm font-medium text-black/60 hover:text-black transition-colors uppercase tracking-widest"
          style={{ fontFamily: "'JetBrains Mono', monospace" }}
        >
          Index
        </Link>
      </header>

      {/* Hero Section */}
      <section className="pt-32 pb-20 px-6 md:px-12 lg:px-24 max-w-7xl mx-auto">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 items-center">
          <motion.div
            initial={{ opacity: 0, x: -20 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ duration: 0.8, ease: "easeOut" }}
            className="lg:col-span-5"
          >
            <div className="inline-block border border-black/20 px-3 py-1 mb-8 text-xs uppercase tracking-widest" style={{ fontFamily: "'JetBrains Mono', monospace" }}>
              {content.hero.badge}
            </div>
            <h1 className="text-5xl md:text-7xl font-medium tracking-tight leading-[1.05] mb-6">
              {content.hero.title}
            </h1>
            <p className="text-lg md:text-xl text-black/70 leading-relaxed max-w-md">
              {content.hero.subtitle}
            </p>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, scale: 0.95, rotate: -2 }}
            animate={{ opacity: 1, scale: 1, rotate: 0 }}
            transition={{ duration: 1, delay: 0.2, ease: [0.16, 1, 0.3, 1] }}
            className="lg:col-span-7 relative flex justify-center lg:justify-end"
          >
            <div className="relative">
              <PhoneMockup src={content.features[0].img} alt="Today View" className="rotate-[-4deg] origin-bottom-left z-20" />
              <PhoneMockup src={content.features[2].img} alt="Groups View" className="absolute top-10 left-20 rotate-[6deg] origin-bottom-right z-10 opacity-80 blur-[2px] scale-95 hidden md:block" />
            </div>
          </motion.div>
        </div>
      </section>

      {/* Features Grid (Editorial Style) */}
      <section className="py-20 px-6 md:px-12 lg:px-24 max-w-7xl mx-auto border-t border-black/10">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-x-16 gap-y-24">
          {content.features.slice(1).map((feature, i) => (
            <motion.div
              key={feature.id}
              initial={{ opacity: 0, y: 40 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: "-100px" }}
              transition={{ duration: 0.8, delay: i * 0.1 }}
              className="flex flex-col gap-8"
            >
              <div className="relative aspect-[3/4] w-full max-w-[400px] mx-auto bg-black/5 p-8 flex items-center justify-center overflow-hidden">
                <PhoneMockup src={feature.img} alt={feature.title} className="scale-90" />
                <div className="absolute top-4 left-4 text-xs uppercase tracking-widest text-black/40" style={{ fontFamily: "'JetBrains Mono', monospace" }}>
                  Fig. 0{i + 1}
                </div>
              </div>
              <div>
                <h3 className="text-3xl font-medium mb-3">{feature.title}</h3>
                <p className="text-lg text-black/70 leading-relaxed">{feature.desc}</p>
              </div>
            </motion.div>
          ))}
        </div>
      </section>

      {/* Waitlist Section */}
      <section className="py-32 px-6 border-t border-black/10 bg-white">
        <div className="max-w-xl mx-auto text-center">
          <h2 className="text-4xl md:text-5xl font-medium mb-4">
            {content.waitlist.title}
          </h2>
          <p className="text-black/60 mb-10 text-lg">
            {content.waitlist.subtitle}
          </p>

          {status === "success" ? (
            <motion.div
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              className="p-6 border border-[#d9381e] text-[#d9381e] bg-[#d9381e]/5"
            >
              {content.waitlist.success}
            </motion.div>
          ) : (
            <form onSubmit={onSubmit} className="flex flex-col gap-4">
              <div className="relative">
                <input
                  type="email"
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder={content.waitlist.placeholder}
                  className="w-full bg-transparent border-b-2 border-black/20 px-0 py-4 text-black placeholder:text-black/30 focus:outline-none focus:border-black transition-colors text-lg"
                  disabled={status === "loading"}
                />
              </div>
              <div className="mt-4 flex justify-center">
                <Turnstile siteKey={process.env.NEXT_PUBLIC_TURNSTILE_SITE_KEY || ""} onToken={setToken} />
              </div>
              <button
                type="submit"
                disabled={status === "loading" || !token}
                className="w-full bg-black text-white uppercase tracking-widest text-sm py-5 hover:bg-[#d9381e] transition-colors disabled:opacity-50 disabled:cursor-not-allowed mt-4"
                style={{ fontFamily: "'JetBrains Mono', monospace" }}
              >
                {status === "loading" ? "Joining..." : content.waitlist.button}
              </button>
              {status === "error" && (
                <p className="text-[#d9381e] text-sm mt-2">{content.waitlist.error}</p>
              )}
            </form>
          )}
        </div>
      </section>

      {/* Footer */}
      <footer className="py-12 text-center border-t border-black/10 bg-[#F7F5F0]">
        <div className="flex items-center justify-center gap-8 text-xs uppercase tracking-widest text-black/40" style={{ fontFamily: "'JetBrains Mono', monospace" }}>
          <Link href={`/${locale}/terms`} className="hover:text-black transition-colors">Terms</Link>
          <Link href={`/${locale}/privacy`} className="hover:text-black transition-colors">Privacy</Link>
        </div>
      </footer>
    </div>
  );
}
