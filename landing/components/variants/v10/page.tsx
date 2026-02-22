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
    badge: "SUNNAD",
    title: "PURE FOCUS.",
    subtitle:
      "AN OFFLINE-FIRST ISLAMIC HABIT TRACKER DESIGNED FOR CONSISTENCY AND SPIRITUAL GROWTH. NO DISTRACTIONS.",
  },
  features: [
    {
      id: "today",
      title: "TODAY",
      desc: "A CLEAN CHECKLIST OF WHAT MATTERS RIGHT NOW.",
      img: "/app-screenshots/en_today_light.PNG",
    },
    {
      id: "dhikr",
      title: "DHIKR",
      desc: "BUILT-IN COUNTERS FOR YOUR DAILY ADHKAR.",
      img: "/app-screenshots/en_dhikr_light.PNG",
    },
    {
      id: "groups",
      title: "GROUPS",
      desc: "KEEP EACH OTHER ACCOUNTABLE WITH GENTLE NUDGES.",
      img: "/app-screenshots/en_groups_light.PNG",
    },
    {
      id: "analytics",
      title: "STATS",
      desc: "BEAUTIFUL CHARTS THAT MOTIVATE WITHOUT GUILT.",
      img: "/app-screenshots/en_analytics_light.PNG",
    },
  ],
  waitlist: {
    title: "JOIN THE WAITLIST",
    subtitle: "BE AMONG THE FIRST TO EXPERIENCE SUNNAD.",
    placeholder: "ENTER YOUR EMAIL",
    button: "REQUEST ACCESS",
    success: "ALHAMDULILLAH, YOU'RE ON THE LIST.",
    error: "SOMETHING WENT WRONG. TRY AGAIN.",
  },
};

/* ── Components ── */

function PhoneMockup({ src, alt, className = "" }: { src: string; alt: string; className?: string }) {
  return (
    <div className={`relative w-[300px] h-[612px] md:w-[400px] md:h-[816px] shrink-0 ${className}`}>
      {/* The Screenshot */}
      <div className="absolute inset-[14px] md:inset-[18px] rounded-[36px] md:rounded-[48px] overflow-hidden bg-black border-4 border-black">
        <img
          src={src}
          alt={alt}
          className="w-full h-full object-cover grayscale contrast-125"
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

export default function V10Page({ locale }: Props) {
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<"idle" | "loading" | "success" | "error">("idle");
  const [token, setToken] = useState<string | null>(null);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!email || !token) return;
    setStatus("loading");
    const res = await submitWaitlist({ email, turnstileToken: token, locale, variant: "10" });
    setStatus(res.status === "subscribed" || res.status === "already_subscribed" ? "success" : "error");
  }

  return (
    <div
      className="min-h-screen bg-white text-black selection:bg-black selection:text-white overflow-x-hidden"
      style={{ fontFamily: "'Inter', sans-serif" }}
    >
      {/* Header */}
      <header className="fixed top-0 left-0 right-0 z-50 flex items-center justify-between px-6 py-6 mix-blend-difference text-white">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 bg-white flex items-center justify-center">
            <span className="text-black font-black text-xl" style={{ fontFamily: "'Syne', sans-serif" }}>S</span>
          </div>
          <span className="font-black tracking-tighter text-2xl uppercase" style={{ fontFamily: "'Syne', sans-serif" }}>Sunnad</span>
        </div>
        <Link
          href={`/${locale}`}
          className="text-sm font-bold hover:underline uppercase tracking-widest"
        >
          INDEX
        </Link>
      </header>

      {/* Hero Section */}
      <section className="relative min-h-screen flex flex-col justify-center px-6 md:px-12 lg:px-24 pt-32 pb-20 border-b-8 border-black">
        <motion.div
          initial={{ opacity: 0, y: 50 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, ease: [0.16, 1, 0.3, 1] }}
          className="max-w-5xl"
        >
          <div className="inline-block bg-black text-white px-4 py-2 mb-8 text-sm font-black uppercase tracking-widest">
            {content.hero.badge}
          </div>
          <h1
            className="text-[12vw] leading-[0.85] font-black tracking-tighter uppercase mb-8"
            style={{ fontFamily: "'Syne', sans-serif" }}
          >
            {content.hero.title}
          </h1>
          <p className="text-2xl md:text-4xl font-bold max-w-3xl leading-tight uppercase tracking-tight">
            {content.hero.subtitle}
          </p>
        </motion.div>
      </section>

      {/* Features (Horizontal Scroll Illusion) */}
      <section className="relative py-32 px-6 md:px-12 lg:px-24 border-b-8 border-black overflow-hidden">
        <div className="flex flex-col gap-32">
          {content.features.map((feature, i) => (
            <motion.div
              key={feature.id}
              initial={{ opacity: 0, x: i % 2 === 0 ? -100 : 100 }}
              whileInView={{ opacity: 1, x: 0 }}
              viewport={{ once: true, margin: "-100px" }}
              transition={{ duration: 0.8, ease: [0.16, 1, 0.3, 1] }}
              className={`flex flex-col ${i % 2 === 0 ? "md:flex-row" : "md:flex-row-reverse"} items-center gap-12 md:gap-24`}
            >
              <div className="flex-1">
                <h2
                  className="text-[8vw] md:text-[6vw] leading-[0.85] font-black tracking-tighter uppercase mb-6"
                  style={{ fontFamily: "'Syne', sans-serif" }}
                >
                  {feature.title}
                </h2>
                <p className="text-xl md:text-3xl font-bold uppercase tracking-tight max-w-xl">
                  {feature.desc}
                </p>
              </div>
              <div className="flex-1 flex justify-center relative">
                {/* Brutalist shadow */}
                <div className="absolute inset-0 bg-black translate-x-4 translate-y-4 md:translate-x-8 md:translate-y-8" />
                <PhoneMockup src={feature.img} alt={feature.title} className="relative z-10" />
              </div>
            </motion.div>
          ))}
        </div>
      </section>

      {/* Waitlist Section */}
      <section className="relative py-32 px-6 md:px-12 lg:px-24 bg-black text-white">
        <div className="max-w-4xl mx-auto">
          <h2
            className="text-[10vw] md:text-[8vw] leading-[0.85] font-black tracking-tighter uppercase mb-8"
            style={{ fontFamily: "'Syne', sans-serif" }}
          >
            {content.waitlist.title}
          </h2>
          <p className="text-2xl md:text-4xl font-bold uppercase tracking-tight mb-16">
            {content.waitlist.subtitle}
          </p>

          {status === "success" ? (
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              className="p-8 bg-white text-black font-black text-2xl uppercase tracking-tight border-4 border-white"
            >
              {content.waitlist.success}
            </motion.div>
          ) : (
            <form onSubmit={onSubmit} className="flex flex-col gap-8">
              <div className="relative">
                <input
                  type="email"
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder={content.waitlist.placeholder}
                  className="w-full bg-transparent border-b-8 border-white px-0 py-6 text-white placeholder:text-white/30 focus:outline-none focus:border-white/50 transition-colors text-3xl md:text-5xl font-black uppercase tracking-tighter"
                  disabled={status === "loading"}
                />
              </div>
              <Turnstile siteKey={process.env.NEXT_PUBLIC_TURNSTILE_SITE_KEY || ""} onToken={setToken} />
              <button
                type="submit"
                disabled={status === "loading" || !token}
                className="w-full bg-white text-black font-black text-3xl md:text-5xl uppercase tracking-tighter py-8 hover:bg-black hover:text-white hover:border-white border-8 border-transparent transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                style={{ fontFamily: "'Syne', sans-serif" }}
              >
                {status === "loading" ? "JOINING..." : content.waitlist.button}
              </button>
              {status === "error" && (
                <p className="text-red-500 text-xl font-bold uppercase mt-4">{content.waitlist.error}</p>
              )}
            </form>
          )}
        </div>
      </section>

      {/* Footer */}
      <footer className="py-12 px-6 md:px-12 lg:px-24 border-t-8 border-black bg-white text-black flex flex-col md:flex-row justify-between items-center gap-6">
        <div className="font-black text-2xl uppercase tracking-tighter" style={{ fontFamily: "'Syne', sans-serif" }}>
          SUNNAD © 2026
        </div>
        <div className="flex items-center gap-8 text-lg font-bold uppercase tracking-tight">
          <Link href={`/${locale}/terms`} className="hover:underline">TERMS</Link>
          <Link href={`/${locale}/privacy`} className="hover:underline">PRIVACY</Link>
        </div>
      </footer>
    </div>
  );
}
