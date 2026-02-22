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
    title: "Your deen, beautifully tracked.",
    subtitle:
      "An offline-first Islamic habit tracker designed for focus, consistency, and spiritual growth.",
  },
  features: [
    {
      id: "today",
      title: "Focus on Today",
      desc: "A clean, distraction-free checklist of what matters right now. No overwhelming backlogs.",
      img: "/app-screenshots/en_today_light.PNG",
      color: "bg-[#e0f2fe]", // Light blue
      textColor: "text-[#0369a1]",
    },
    {
      id: "dhikr",
      title: "Seamless Dhikr",
      desc: "Built-in counters for your daily adhkar. Tap anywhere, stay focused.",
      img: "/app-screenshots/en_dhikr_light.PNG",
      color: "bg-[#fce7f3]", // Light pink
      textColor: "text-[#be185d]",
    },
    {
      id: "groups",
      title: "Grow Together",
      desc: "Join private groups. Keep each other accountable with gentle nudges.",
      img: "/app-screenshots/en_groups_light.PNG",
      color: "bg-[#ffedd5]", // Light orange
      textColor: "text-[#c2410c]",
    },
    {
      id: "analytics",
      title: "See Your Progress",
      desc: "Beautiful charts and streaks that motivate without inducing guilt.",
      img: "/app-screenshots/en_analytics_light.PNG",
      color: "bg-[#dcfce7]", // Light green
      textColor: "text-[#15803d]",
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
    <div className={`relative w-[240px] h-[490px] md:w-[280px] md:h-[572px] shrink-0 ${className}`}>
      {/* The Screenshot */}
      <div className="absolute inset-[10px] md:inset-[12px] rounded-[28px] md:rounded-[32px] overflow-hidden bg-white shadow-sm">
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
        className="absolute inset-0 w-full h-full object-contain pointer-events-none z-10 drop-shadow-md"
      />
    </div>
  );
}

export default function V8Page({ locale }: Props) {
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<"idle" | "loading" | "success" | "error">("idle");
  const [token, setToken] = useState<string | null>(null);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!email || !token) return;
    setStatus("loading");
    const res = await submitWaitlist({ email, turnstileToken: token, locale, variant: "8" });
    setStatus(res.status === "subscribed" || res.status === "already_subscribed" ? "success" : "error");
  }

  return (
    <div
      className="min-h-screen bg-[#f8fafc] text-[#0f172a] selection:bg-[#8b5cf6] selection:text-white"
      style={{ fontFamily: "'Bricolage Grotesque', sans-serif" }}
    >
      {/* Header */}
      <header className="fixed top-0 left-0 right-0 z-50 flex items-center justify-between px-4 py-4 md:px-8 md:py-6">
        <div className="flex items-center gap-3 bg-white/80 backdrop-blur-md px-4 py-2 rounded-full shadow-sm border border-black/5">
          <div className="w-6 h-6 rounded-full bg-gradient-to-br from-[#8b5cf6] to-[#d946ef] flex items-center justify-center">
            <span className="text-white font-bold text-xs">S</span>
          </div>
          <span className="font-bold tracking-tight text-sm">Sunnad</span>
        </div>
        <Link
          href={`/${locale}`}
          className="text-sm font-semibold text-black/50 hover:text-black transition-colors bg-white/80 backdrop-blur-md px-4 py-2 rounded-full shadow-sm border border-black/5"
        >
          Back
        </Link>
      </header>

      {/* Bento Grid Layout */}
      <main className="pt-24 pb-20 px-4 md:px-8 max-w-[1400px] mx-auto">
        <div className="grid grid-cols-1 md:grid-cols-12 gap-4 md:gap-6 auto-rows-[minmax(180px,auto)]">
          
          {/* Hero Cell (Large) */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5 }}
            className="md:col-span-8 md:row-span-2 bg-white rounded-[32px] p-8 md:p-12 flex flex-col justify-center shadow-sm border border-black/5 relative overflow-hidden"
          >
            <div className="absolute top-0 right-0 w-64 h-64 bg-gradient-to-br from-[#8b5cf6]/20 to-transparent rounded-bl-full blur-3xl -z-10" />
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-[#f1f5f9] text-[#475569] text-xs font-bold uppercase tracking-wider w-fit mb-6">
              {content.hero.badge}
            </div>
            <h1 className="text-5xl md:text-7xl font-extrabold tracking-tight leading-[1.05] mb-6 text-balance">
              {content.hero.title}
            </h1>
            <p className="text-lg md:text-xl text-[#64748b] font-medium max-w-lg leading-relaxed">
              {content.hero.subtitle}
            </p>
          </motion.div>

          {/* Feature 1 Cell (Tall) */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5, delay: 0.1 }}
            className={`md:col-span-4 md:row-span-3 ${content.features[0].color} rounded-[32px] p-8 flex flex-col items-center text-center shadow-sm border border-black/5 overflow-hidden relative`}
          >
            <h3 className={`text-2xl font-bold mb-2 ${content.features[0].textColor}`}>{content.features[0].title}</h3>
            <p className={`${content.features[0].textColor} opacity-80 font-medium mb-8`}>{content.features[0].desc}</p>
            <div className="mt-auto translate-y-12 group-hover:translate-y-8 transition-transform duration-500">
              <PhoneMockup src={content.features[0].img} alt={content.features[0].title} />
            </div>
          </motion.div>

          {/* Waitlist Cell */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5, delay: 0.2 }}
            className="md:col-span-8 md:row-span-2 bg-[#0f172a] text-white rounded-[32px] p-8 md:p-12 flex flex-col justify-center shadow-xl relative overflow-hidden"
          >
            <div className="absolute inset-0 bg-[url('https://grainy-gradients.vercel.app/noise.svg')] opacity-20 mix-blend-overlay pointer-events-none" />
            <div className="relative z-10 max-w-xl">
              <h2 className="text-3xl md:text-4xl font-bold mb-3">{content.waitlist.title}</h2>
              <p className="text-white/60 font-medium mb-8">{content.waitlist.subtitle}</p>
              
              {status === "success" ? (
                <div className="p-4 rounded-2xl bg-[#10b981]/20 text-[#34d399] font-bold border border-[#10b981]/30">
                  {content.waitlist.success}
                </div>
              ) : (
                <form onSubmit={onSubmit} className="flex flex-col sm:flex-row gap-3">
                  <input
                    type="email"
                    required
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder={content.waitlist.placeholder}
                    className="flex-1 bg-white/10 border border-white/20 rounded-2xl px-6 py-4 text-white placeholder:text-white/40 focus:outline-none focus:border-[#8b5cf6] focus:bg-white/20 transition-all font-medium"
                    disabled={status === "loading"}
                  />
                  <button
                    type="submit"
                    disabled={status === "loading" || !token}
                    className="bg-gradient-to-r from-[#8b5cf6] to-[#d946ef] text-white font-bold rounded-2xl px-8 py-4 hover:opacity-90 transition-opacity disabled:opacity-50 disabled:cursor-not-allowed whitespace-nowrap shadow-lg shadow-[#8b5cf6]/20"
                  >
                    {status === "loading" ? "Joining..." : content.waitlist.button}
                  </button>
                </form>
              )}
              {status === "error" && (
                <p className="text-red-400 text-sm mt-3 font-medium">{content.waitlist.error}</p>
              )}
              {status !== "success" && (
                <div className="mt-4">
                  <Turnstile siteKey={process.env.NEXT_PUBLIC_TURNSTILE_SITE_KEY || ""} onToken={setToken} />
                </div>
              )}
            </div>
          </motion.div>

          {/* Feature 2 Cell */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5, delay: 0.3 }}
            className={`md:col-span-4 md:row-span-2 ${content.features[1].color} rounded-[32px] p-8 flex flex-col shadow-sm border border-black/5 overflow-hidden relative`}
          >
            <h3 className={`text-2xl font-bold mb-2 ${content.features[1].textColor}`}>{content.features[1].title}</h3>
            <p className={`${content.features[1].textColor} opacity-80 font-medium mb-6`}>{content.features[1].desc}</p>
            <div className="absolute -bottom-20 -right-10 rotate-[-15deg]">
              <PhoneMockup src={content.features[1].img} alt={content.features[1].title} className="scale-75" />
            </div>
          </motion.div>

          {/* Feature 3 Cell */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5, delay: 0.4 }}
            className={`md:col-span-4 md:row-span-2 ${content.features[2].color} rounded-[32px] p-8 flex flex-col shadow-sm border border-black/5 overflow-hidden relative`}
          >
            <h3 className={`text-2xl font-bold mb-2 ${content.features[2].textColor}`}>{content.features[2].title}</h3>
            <p className={`${content.features[2].textColor} opacity-80 font-medium mb-6`}>{content.features[2].desc}</p>
            <div className="absolute -bottom-20 -right-10 rotate-[15deg]">
              <PhoneMockup src={content.features[2].img} alt={content.features[2].title} className="scale-75" />
            </div>
          </motion.div>

          {/* Feature 4 Cell */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5, delay: 0.5 }}
            className={`md:col-span-4 md:row-span-2 ${content.features[3].color} rounded-[32px] p-8 flex flex-col shadow-sm border border-black/5 overflow-hidden relative`}
          >
            <h3 className={`text-2xl font-bold mb-2 ${content.features[3].textColor}`}>{content.features[3].title}</h3>
            <p className={`${content.features[3].textColor} opacity-80 font-medium mb-6`}>{content.features[3].desc}</p>
            <div className="absolute -bottom-20 -right-10 rotate-[-5deg]">
              <PhoneMockup src={content.features[3].img} alt={content.features[3].title} className="scale-75" />
            </div>
          </motion.div>

        </div>
      </main>

      {/* Footer */}
      <footer className="py-8 text-center">
        <div className="flex items-center justify-center gap-6 text-sm font-bold text-[#64748b]">
          <Link href={`/${locale}/terms`} className="hover:text-[#0f172a] transition-colors">Terms</Link>
          <Link href={`/${locale}/privacy`} className="hover:text-[#0f172a] transition-colors">Privacy</Link>
        </div>
      </footer>
    </div>
  );
}
