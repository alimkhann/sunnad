"use client";

import { useState, useEffect, useRef } from "react";
import { motion, useInView } from "framer-motion";
import Link from "next/link";
import { Turnstile } from "@/components/turnstile";
import { submitWaitlist, type WaitlistResult } from "@/lib/waitlist-submit";
import { landingConfig } from "@/lib/config";

interface Props {
  locale: string;
  variant: string;
}

/* ── Animated counter ── */
function AnimNumber({
  value,
  suffix = "",
}: {
  value: number;
  suffix?: string;
}) {
  const ref = useRef<HTMLSpanElement>(null);
  const inView = useInView(ref, { once: true });
  const [display, setDisplay] = useState(0);

  useEffect(() => {
    if (!inView) return;
    let frame: number;
    const start = performance.now();
    const duration = 1200;
    function tick(now: number) {
      const t = Math.min((now - start) / duration, 1);
      const eased = 1 - Math.pow(1 - t, 3);
      setDisplay(Math.floor(eased * value));
      if (t < 1) frame = requestAnimationFrame(tick);
    }
    frame = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frame);
  }, [inView, value]);

  return (
    <span ref={ref}>
      {display}
      {suffix}
    </span>
  );
}

/* ── Marquee ── */
function Marquee() {
  const items = [
    "HABIT TRACKING",
    "●",
    "DHIKR COUNTER",
    "●",
    "GROUP ACCOUNTABILITY",
    "●",
    "OFFLINE FIRST",
    "●",
    "DAILY QUOTES",
    "●",
    "STREAK TRACKING",
    "●",
    "iOS APP",
    "●",
    "COMING SOON",
    "●",
  ];
  return (
    <div className="border-y-2 border-[#0a0a0a] py-3 overflow-hidden">
      <div className="flex whitespace-nowrap animate-[marquee_25s_linear_infinite]">
        {[...items, ...items].map((item, i) => (
          <span
            key={i}
            className={`mx-4 text-sm tracking-[0.15em] ${item === "●" ? "text-[#00e87b]" : "text-[#0a0a0a]"}`}
            style={{
              fontFamily: "'JetBrains Mono', monospace",
              fontWeight: 500,
            }}
          >
            {item}
          </span>
        ))}
      </div>
      <style jsx>{`
        @keyframes marquee {
          0% {
            transform: translateX(0);
          }
          100% {
            transform: translateX(-50%);
          }
        }
      `}</style>
    </div>
  );
}

/* ══════════════════════════════════════════════════════════════ */
/*  V3 — Brutalist Grid: Bold, Confident, Tech-Forward         */
/* ══════════════════════════════════════════════════════════════ */
export default function V3Page({ locale, variant }: Props) {
  const [email, setEmail] = useState("");
  const [token, setToken] = useState<string | null>(null);
  const [result, setResult] = useState<WaitlistResult | null>(null);
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!token || !email) return;
    setSubmitting(true);
    const res = await submitWaitlist({
      email,
      turnstileToken: token,
      locale,
      variant,
    });
    setResult(res);
    setSubmitting(false);
  }

  const locales = [
    { code: "en", label: "EN" },
    { code: "ru", label: "RU" },
    { code: "kk", label: "KK" },
  ];

  return (
    <div
      className="min-h-screen bg-[#f5f5f0] text-[#0a0a0a] selection:bg-[#00e87b]/30"
      style={{ fontFamily: "'Manrope', sans-serif" }}
    >
      {/* ── NAV ── */}
      <nav className="border-b-2 border-[#0a0a0a]">
        <div className="flex items-center justify-between px-6 md:px-10 py-4">
          <span
            className="text-xl tracking-tight font-extrabold"
            style={{ fontFamily: "'Syne', sans-serif" }}
          >
            SUNNAD
          </span>
          <div className="flex items-center gap-5">
            <div
              className="hidden md:flex items-center gap-3 text-xs"
              style={{ fontFamily: "'JetBrains Mono', monospace" }}
            >
              {locales.map((l) => (
                <Link
                  key={l.code}
                  href={`/${l.code}/${variant}`}
                  className={`hover:text-[#00e87b] transition-colors ${l.code === locale ? "text-[#00e87b]" : "text-[#0a0a0a]/50"}`}
                >
                  [{l.label}]
                </Link>
              ))}
            </div>
            <a
              href="#join"
              className="bg-[#0a0a0a] text-[#f5f5f0] px-5 py-2.5 text-xs font-bold tracking-wider uppercase hover:bg-[#00e87b] hover:text-[#0a0a0a] transition-all duration-200"
              style={{ fontFamily: "'Syne', sans-serif" }}
            >
              Join →
            </a>
          </div>
        </div>
      </nav>

      {/* ── HERO ── */}
      <section className="border-b-2 border-[#0a0a0a] relative">
        <div className="px-6 md:px-10 py-16 md:py-24">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5, ease: "easeOut" }}
          >
            <div className="flex items-start gap-4 mb-6">
              <span
                className="text-[11px] tracking-wider text-[#0a0a0a]/40 mt-5"
                style={{ fontFamily: "'JetBrains Mono', monospace" }}
              >
                001
              </span>
              <h1
                className="text-[clamp(3rem,10vw,9rem)] leading-[0.88] font-extrabold tracking-tight"
                style={{ fontFamily: "'Syne', sans-serif" }}
              >
                Track your
                <br />
                worship<span className="text-[#00e87b]">.</span>
                <br />
                Stay consistent<span className="text-[#00e87b]">.</span>
              </h1>
            </div>
            <p className="max-w-lg text-base md:text-lg text-[#0a0a0a]/55 leading-relaxed ml-0 md:ml-12">
              An offline-first habit tracker built for Muslims who take their
              daily worship seriously. No distractions. No feeds. Just
              accountability.
            </p>
          </motion.div>

          {/* Phone mockup — overlaps into features section */}
          <motion.div
            className="absolute right-6 md:right-16 -bottom-36 md:-bottom-48 z-20"
            initial={{ opacity: 0, y: 60 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.7, delay: 0.3 }}
          >
            <div className="w-[180px] h-[360px] md:w-[240px] md:h-[480px] border-[3px] border-[#0a0a0a] bg-[#0a0a0a] rounded-[24px] md:rounded-[32px] overflow-hidden shadow-[8px_8px_0px_#00e87b]">
              <div className="h-full bg-[#f5f5f0] p-3 md:p-4 space-y-2">
                <div
                  className="text-[8px] md:text-[10px] font-bold uppercase tracking-widest text-[#0a0a0a]/40"
                  style={{ fontFamily: "'JetBrains Mono', monospace" }}
                >
                  TODAY
                </div>
                {[
                  "Fajr Prayer",
                  "Morning Adhkar",
                  "Quran Reading",
                  "Dhikr ×33",
                ].map((label, i) => (
                  <div
                    key={i}
                    className="flex items-center gap-2 border border-[#0a0a0a]/15 px-2 py-1.5 md:px-3 md:py-2"
                  >
                    <div
                      className={`w-3.5 h-3.5 md:w-4 md:h-4 border-2 border-[#0a0a0a] ${i < 2 ? "bg-[#00e87b]" : ""}`}
                    />
                    <span
                      className="text-[9px] md:text-[11px] font-medium text-[#0a0a0a]"
                      style={{ fontFamily: "'Manrope', sans-serif" }}
                    >
                      {label}
                    </span>
                  </div>
                ))}
                <div className="border border-[#0a0a0a]/15 p-2 mt-1">
                  <div
                    className="text-[7px] md:text-[8px] uppercase tracking-widest text-[#0a0a0a]/30"
                    style={{ fontFamily: "'JetBrains Mono', monospace" }}
                  >
                    STREAK
                  </div>
                  <div
                    className="text-xl md:text-2xl font-extrabold text-[#00e87b]"
                    style={{ fontFamily: "'Syne', sans-serif" }}
                  >
                    14
                  </div>
                </div>
              </div>
            </div>
          </motion.div>
        </div>
      </section>

      {/* ── MARQUEE ── */}
      <Marquee />

      {/* ── FEATURES GRID ── */}
      <section className="border-b-2 border-[#0a0a0a] pt-40 md:pt-56">
        <div className="grid md:grid-cols-2">
          {[
            {
              num: "01",
              title: "TODAY CHECKLIST",
              desc: "Only habits scheduled for today. Check them off. See your daily progress. The simplest, most effective approach.",
            },
            {
              num: "02",
              title: "DHIKR COUNTER",
              desc: "Tap-to-count for tasbeeh. SubhanAllah. Alhamdulillah. Allahu Akbar. Set targets and track completion over weeks.",
            },
            {
              num: "03",
              title: "GROUP ACCOUNTABILITY",
              desc: "Private groups of 3-7 friends. See who completed what. Send nudges. No public feed. No surveillance. Just support.",
            },
            {
              num: "04",
              title: "OFFLINE-FIRST",
              desc: "All data lives on your device. No account needed for personal use. No internet required. Ever. Sync only when you want groups.",
            },
          ].map((f, i) => (
            <motion.div
              key={f.num}
              className={`p-8 md:p-12 ${i < 2 ? "border-b-2" : ""} ${i % 2 === 0 ? "md:border-r-2" : ""} border-[#0a0a0a]`}
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: "-60px" }}
              transition={{ duration: 0.4, delay: i * 0.08 }}
            >
              <span
                className="text-5xl md:text-7xl font-extrabold text-[#0a0a0a]/[0.06] block mb-4"
                style={{ fontFamily: "'Syne', sans-serif" }}
              >
                {f.num}
              </span>
              <h3
                className="text-lg md:text-xl font-extrabold tracking-tight mb-3"
                style={{ fontFamily: "'Syne', sans-serif" }}
              >
                {f.title}
              </h3>
              <p className="text-sm text-[#0a0a0a]/50 leading-relaxed max-w-sm">
                {f.desc}
              </p>
            </motion.div>
          ))}
        </div>
      </section>

      {/* ── STATS ── */}
      <section className="border-b-2 border-[#0a0a0a]">
        <div className="grid grid-cols-3 divide-x-2 divide-[#0a0a0a]">
          {[
            { value: 3, suffix: "", label: "Languages" },
            { value: 100, suffix: "%", label: "Offline" },
            { value: 7, suffix: "", label: "Max Group Size" },
          ].map((stat, i) => (
            <motion.div
              key={i}
              className="py-10 md:py-16 text-center"
              initial={{ opacity: 0 }}
              whileInView={{ opacity: 1 }}
              viewport={{ once: true }}
              transition={{ duration: 0.4, delay: i * 0.1 }}
            >
              <div
                className="text-4xl md:text-6xl font-extrabold text-[#00e87b]"
                style={{ fontFamily: "'Syne', sans-serif" }}
              >
                <AnimNumber value={stat.value} suffix={stat.suffix} />
              </div>
              <div
                className="text-[10px] md:text-xs tracking-[0.2em] text-[#0a0a0a]/40 mt-2 uppercase"
                style={{ fontFamily: "'JetBrains Mono', monospace" }}
              >
                {stat.label}
              </div>
            </motion.div>
          ))}
        </div>
      </section>

      {/* ── MARQUEE 2 ── */}
      <Marquee />

      {/* ── WAITLIST ── */}
      <section id="join" className="py-20 md:py-32 px-6 md:px-10">
        <div className="max-w-4xl mx-auto">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: "-60px" }}
            transition={{ duration: 0.5 }}
          >
            <span
              className="text-[11px] tracking-wider text-[#0a0a0a]/30 block mb-3"
              style={{ fontFamily: "'JetBrains Mono', monospace" }}
            >
              005
            </span>
            <h2
              className="text-4xl md:text-6xl font-extrabold tracking-tight mb-4"
              style={{ fontFamily: "'Syne', sans-serif" }}
            >
              Get early access<span className="text-[#00e87b]">.</span>
            </h2>
            <p className="text-base text-[#0a0a0a]/45 mb-10 max-w-lg">
              Drop your email. We&apos;ll notify you when Sunnad launches on
              iOS. One email only. No spam. No newsletter.
            </p>

            {result?.status === "subscribed" ||
            result?.status === "already_subscribed" ? (
              <div className="border-2 border-[#00e87b] p-8 inline-block">
                <span
                  className="text-[#00e87b] text-3xl font-extrabold"
                  style={{ fontFamily: "'Syne', sans-serif" }}
                >
                  {result.status === "subscribed"
                    ? "YOU'RE IN ✓"
                    : "ALREADY IN ✓"}
                </span>
                <p className="text-sm text-[#0a0a0a]/40 mt-2">
                  {result.status === "subscribed"
                    ? "We'll send one email when it's time."
                    : "Your email is already on the list."}
                </p>
              </div>
            ) : (
              <form onSubmit={handleSubmit} className="space-y-5">
                <div className="flex flex-col sm:flex-row gap-0">
                  <input
                    type="email"
                    required
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="YOUR@EMAIL.COM"
                    className="flex-1 bg-transparent border-2 border-[#0a0a0a] px-5 py-4 text-[#0a0a0a] placeholder:text-[#0a0a0a]/20 text-sm tracking-wider uppercase outline-none focus:border-[#00e87b] transition-colors"
                    style={{ fontFamily: "'JetBrains Mono', monospace" }}
                  />
                  <button
                    type="submit"
                    disabled={!token || submitting}
                    className="bg-[#0a0a0a] text-[#f5f5f0] px-8 py-4 text-sm font-extrabold tracking-wider uppercase border-2 border-[#0a0a0a] disabled:opacity-30 hover:bg-[#00e87b] hover:text-[#0a0a0a] transition-all duration-200 sm:border-l-0"
                    style={{ fontFamily: "'Syne', sans-serif" }}
                  >
                    {submitting ? "..." : "JOIN →"}
                  </button>
                </div>

                <Turnstile
                  siteKey={landingConfig.turnstileSiteKey}
                  theme="light"
                  onToken={setToken}
                  onExpired={() => setToken(null)}
                  onError={() => setToken(null)}
                />

                {result?.status === "error" && (
                  <p className="text-sm text-red-600">
                    {result.message || "Error. Try again."}
                  </p>
                )}
                {result?.status === "rate_limited" && (
                  <p className="text-sm text-amber-600">
                    Rate limited. Wait a moment.
                  </p>
                )}
              </form>
            )}
          </motion.div>
        </div>
      </section>

      {/* ── FOOTER ── */}
      <footer className="border-t-2 border-[#0a0a0a] py-6 px-6 md:px-10">
        <div
          className="flex flex-col md:flex-row items-center justify-between gap-3 text-[11px] text-[#0a0a0a]/30"
          style={{ fontFamily: "'JetBrains Mono', monospace" }}
        >
          <span>© 2026 SUNNAD</span>
          <div className="flex items-center gap-5">
            <Link
              href={`/${locale}/terms`}
              className="hover:text-[#0a0a0a]/60 transition-colors"
            >
              TERMS
            </Link>
            <Link
              href={`/${locale}/privacy`}
              className="hover:text-[#0a0a0a]/60 transition-colors"
            >
              PRIVACY
            </Link>
            <span className="text-[#0a0a0a]/15">|</span>
            {locales.map((l) => (
              <Link
                key={l.code}
                href={`/${l.code}/${variant}`}
                className={`hover:text-[#0a0a0a]/60 transition-colors ${l.code === locale ? "text-[#00e87b]" : ""}`}
              >
                [{l.label}]
              </Link>
            ))}
          </div>
        </div>
      </footer>
    </div>
  );
}
