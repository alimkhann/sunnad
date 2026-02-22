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
    badge: "Sunnad iOS",
    title: "Clarity in devotion.",
    subtitle:
      "An offline-first Islamic habit tracker designed for focus, consistency, and spiritual growth.",
  },
  features: [
    {
      id: "today",
      title: "Focus on Today",
      desc: "A clean, distraction-free checklist of what matters right now. No overwhelming backlogs.",
      img: "/app-screenshots/en_today_dark.PNG",
    },
    {
      id: "dhikr",
      title: "Seamless Dhikr",
      desc: "Built-in counters for your daily adhkar. Tap anywhere, stay focused.",
      img: "/app-screenshots/en_dhikr_dark.PNG",
    },
    {
      id: "groups",
      title: "Grow Together",
      desc: "Join private groups. Keep each other accountable with gentle nudges.",
      img: "/app-screenshots/en_groups_dark.PNG",
    },
    {
      id: "analytics",
      title: "See Your Progress",
      desc: "Beautiful charts and streaks that motivate without inducing guilt.",
      img: "/app-screenshots/en_analytics_dark.PNG",
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
    <div className={`relative w-[260px] h-[530px] md:w-[300px] md:h-[612px] shrink-0 ${className}`}>
      {/* The Screenshot */}
      <div className="absolute inset-[12px] md:inset-[14px] rounded-[30px] md:rounded-[36px] overflow-hidden bg-[#0B0F19]">
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
        className="absolute inset-0 w-full h-full object-contain pointer-events-none z-10 drop-shadow-2xl"
      />
    </div>
  );
}

export default function V9Page({ locale }: Props) {
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<"idle" | "loading" | "success" | "error">("idle");
  const [token, setToken] = useState<string | null>(null);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!email || !token) return;
    setStatus("loading");
    const res = await submitWaitlist({ email, turnstileToken: token, locale, variant: "9" });
    setStatus(res.status === "subscribed" || res.status === "already_subscribed" ? "success" : "error");
  }

  return (
    <div
      className="min-h-screen bg-[#0B0F19] text-[#e2e8f0] selection:bg-[#38bdf8] selection:text-[#0B0F19] overflow-hidden relative"
      style={{ fontFamily: "'Plus Jakarta Sans', sans-serif" }}
    >
      {/* Animated Auras (Background) */}
      <div className="fixed inset-0 pointer-events-none overflow-hidden">
        <motion.div
          animate={{
            x: [0, 100, 0],
            y: [0, -50, 0],
            scale: [1, 1.2, 1],
          }}
          transition={{ duration: 20, repeat: Infinity, ease: "linear" }}
          className="absolute top-[-10%] left-[-10%] w-[50vw] h-[50vw] rounded-full bg-[#38bdf8] opacity-[0.07] blur-[120px]"
        />
        <motion.div
          animate={{
            x: [0, -100, 0],
            y: [0, 100, 0],
            scale: [1, 1.5, 1],
          }}
          transition={{ duration: 25, repeat: Infinity, ease: "linear" }}
          className="absolute bottom-[-20%] right-[-10%] w-[60vw] h-[60vw] rounded-full bg-[#818cf8] opacity-[0.05] blur-[150px]"
        />
      </div>

      {/* Header */}
      <header className="fixed top-0 left-0 right-0 z-50 flex items-center justify-between px-6 py-6">
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 rounded-xl bg-white/10 backdrop-blur-md border border-white/20 flex items-center justify-center shadow-[0_0_15px_rgba(56,189,248,0.2)]">
            <span className="text-white font-bold text-sm">S</span>
          </div>
          <span className="font-semibold tracking-tight text-lg text-white">Sunnad</span>
        </div>
        <Link
          href={`/${locale}`}
          className="text-sm font-medium text-white/60 hover:text-white transition-colors"
        >
          Back to Gallery
        </Link>
      </header>

      {/* Hero Section */}
      <section className="relative pt-32 pb-20 px-6 md:px-12 lg:px-24 max-w-7xl mx-auto z-10">
        <div className="flex flex-col items-center text-center">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8, ease: "easeOut" }}
            className="max-w-3xl"
          >
            <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full border border-white/10 bg-white/5 backdrop-blur-md mb-8 shadow-[0_0_20px_rgba(255,255,255,0.05)]">
              <span className="w-2 h-2 rounded-full bg-[#38bdf8] shadow-[0_0_10px_#38bdf8]" />
              <span className="text-xs font-semibold tracking-widest uppercase text-white/80">
                {content.hero.badge}
              </span>
            </div>
            <h1 className="text-5xl md:text-7xl font-bold tracking-tight leading-[1.1] mb-6 text-white">
              {content.hero.title}
            </h1>
            <p className="text-lg md:text-xl text-[#94a3b8] leading-relaxed max-w-2xl mx-auto font-medium">
              {content.hero.subtitle}
            </p>
          </motion.div>

          {/* Floating Phones */}
          <div className="relative w-full max-w-5xl h-[600px] mt-20 flex justify-center items-center">
            <motion.div
              animate={{ y: [-10, 10, -10] }}
              transition={{ duration: 6, repeat: Infinity, ease: "easeInOut" }}
              className="absolute z-20"
            >
              <PhoneMockup src={content.features[0].img} alt="Today" />
            </motion.div>
            
            <motion.div
              animate={{ y: [10, -10, 10] }}
              transition={{ duration: 7, repeat: Infinity, ease: "easeInOut", delay: 1 }}
              className="absolute left-[10%] md:left-[20%] z-10 scale-90 opacity-60 blur-[2px] hidden md:block"
            >
              <PhoneMockup src={content.features[1].img} alt="Dhikr" className="rotate-[-10deg]" />
            </motion.div>

            <motion.div
              animate={{ y: [15, -15, 15] }}
              transition={{ duration: 8, repeat: Infinity, ease: "easeInOut", delay: 2 }}
              className="absolute right-[10%] md:right-[20%] z-10 scale-90 opacity-60 blur-[2px] hidden md:block"
            >
              <PhoneMockup src={content.features[2].img} alt="Groups" className="rotate-[10deg]" />
            </motion.div>
          </div>
        </div>
      </section>

      {/* Features (Glass Cards) */}
      <section className="relative py-20 px-6 md:px-12 lg:px-24 max-w-7xl mx-auto z-10">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {content.features.map((feature, i) => (
            <motion.div
              key={feature.id}
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: "-50px" }}
              transition={{ duration: 0.6, delay: i * 0.1 }}
              className="bg-white/[0.03] border border-white/[0.08] backdrop-blur-xl rounded-[32px] p-8 md:p-10 hover:bg-white/[0.05] transition-colors group"
            >
              <div className="w-12 h-12 rounded-2xl bg-gradient-to-br from-[#38bdf8]/20 to-[#818cf8]/20 border border-white/10 flex items-center justify-center mb-6 text-[#38bdf8] font-bold text-xl shadow-[inset_0_1px_1px_rgba(255,255,255,0.2)]">
                0{i + 1}
              </div>
              <h3 className="text-2xl font-bold text-white mb-3">{feature.title}</h3>
              <p className="text-[#94a3b8] font-medium leading-relaxed">{feature.desc}</p>
            </motion.div>
          ))}
        </div>
      </section>

      {/* Waitlist Section */}
      <section className="relative py-32 px-6 z-10">
        <div className="max-w-2xl mx-auto">
          <motion.div
            initial={{ opacity: 0, scale: 0.95 }}
            whileInView={{ opacity: 1, scale: 1 }}
            viewport={{ once: true }}
            transition={{ duration: 0.8 }}
            className="bg-white/[0.03] border border-white/[0.08] backdrop-blur-2xl rounded-[40px] p-10 md:p-16 text-center shadow-[0_0_50px_rgba(0,0,0,0.5)] relative overflow-hidden"
          >
            {/* Inner Glow */}
            <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[300px] h-[100px] bg-[#38bdf8] opacity-20 blur-[60px] pointer-events-none" />

            <h2 className="text-4xl md:text-5xl font-bold text-white mb-4 relative z-10">
              {content.waitlist.title}
            </h2>
            <p className="text-[#94a3b8] mb-10 text-lg font-medium relative z-10">
              {content.waitlist.subtitle}
            </p>

            {status === "success" ? (
              <motion.div
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                className="p-6 rounded-2xl bg-[#38bdf8]/10 border border-[#38bdf8]/30 text-[#38bdf8] font-semibold relative z-10"
              >
                {content.waitlist.success}
              </motion.div>
            ) : (
              <form onSubmit={onSubmit} className="flex flex-col gap-4 relative z-10">
                <div className="relative">
                  <input
                    type="email"
                    required
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder={content.waitlist.placeholder}
                    className="w-full bg-black/20 border border-white/10 rounded-2xl px-6 py-5 text-white placeholder:text-white/30 focus:outline-none focus:border-[#38bdf8]/50 focus:bg-black/40 transition-all font-medium shadow-inner"
                    disabled={status === "loading"}
                  />
                </div>
                <Turnstile siteKey={process.env.NEXT_PUBLIC_TURNSTILE_SITE_KEY || ""} onToken={setToken} />
                <button
                  type="submit"
                  disabled={status === "loading" || !token}
                  className="w-full bg-white text-[#0B0F19] font-bold rounded-2xl px-6 py-5 hover:bg-[#e2e8f0] transition-colors disabled:opacity-50 disabled:cursor-not-allowed shadow-[0_0_20px_rgba(255,255,255,0.2)]"
                >
                  {status === "loading" ? "Joining..." : content.waitlist.button}
                </button>
                {status === "error" && (
                  <p className="text-red-400 text-sm mt-2 font-medium">{content.waitlist.error}</p>
                )}
              </form>
            )}
          </motion.div>
        </div>
      </section>

      {/* Footer */}
      <footer className="py-8 text-center relative z-10 border-t border-white/5">
        <div className="flex items-center justify-center gap-6 text-sm font-medium text-[#64748b]">
          <Link href={`/${locale}/terms`} className="hover:text-white transition-colors">Terms</Link>
          <Link href={`/${locale}/privacy`} className="hover:text-white transition-colors">Privacy</Link>
        </div>
      </footer>
    </div>
  );
}
