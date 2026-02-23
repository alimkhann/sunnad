"use client";

import { useState, useRef } from "react";
import { motion, useScroll, useTransform } from "framer-motion";
import Link from "next/link";
import { Turnstile } from "@/components/turnstile";
import { submitWaitlist, type WaitlistResult } from "@/lib/waitlist-submit";
import { landingConfig } from "@/lib/config";

interface Props {
  locale: string;
  variant: string;
}

/* ── Phone Mockup (soft pastel screen) ── */
function PhoneMockup({ phase }: { phase: "morning" | "evening" }) {
  const bg =
    phase === "morning"
      ? "bg-gradient-to-b from-sky-100 to-white"
      : "bg-gradient-to-b from-amber-50 to-orange-50";
  return (
    <div className="relative mx-auto w-[240px] h-[480px] md:w-[280px] md:h-[560px]">
      <div className="absolute inset-0 rounded-[36px] bg-black/5 blur-xl translate-y-3" />
      <div
        className={`relative w-full h-full rounded-[36px] ${bg} border border-black/[0.06] overflow-hidden shadow-lg`}
      >
        {/* Notch */}
        <div className="absolute top-0 inset-x-0 flex justify-center pt-2.5">
          <div className="w-[90px] h-[26px] rounded-full bg-black/80" />
        </div>
        {/* Content */}
        <div
          className="pt-14 px-5 space-y-3"
          style={{ fontFamily: "'DM Sans', sans-serif" }}
        >
          <div className="text-[10px] font-medium text-gray-400 tracking-wider uppercase">
            Today&apos;s Habits
          </div>
          {(phase === "morning"
            ? ["Fajr Prayer", "Morning Adhkar", "Quran — 1 page"]
            : ["Asr Prayer", "Evening Adhkar", "Gratitude Journal"]
          ).map((label, i) => (
            <div
              key={i}
              className="flex items-center gap-2.5 rounded-2xl bg-white/70 px-3.5 py-3 backdrop-blur-sm"
            >
              <div
                className={`w-5 h-5 rounded-full border-2 ${i === 0 ? "bg-sky-400 border-sky-400" : "border-gray-300"}`}
              />
              <span className="text-xs text-gray-600">{label}</span>
            </div>
          ))}
          <div className="mt-3 rounded-2xl bg-white/60 p-3 backdrop-blur-sm">
            <div className="text-[9px] text-gray-400 uppercase tracking-wider mb-1">
              Daily Quote
            </div>
            <div
              className="text-[11px] text-gray-500 italic leading-relaxed"
              style={{ fontFamily: "'Crimson Pro', serif" }}
            >
              &ldquo;And whoever relies upon Allah — then He is sufficient for
              him.&rdquo;
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

/* ══════════════════════════════════════════════════════════════ */
/*  V2 — Dawn to Dusk: Full-Viewport Scroll Story              */
/* ══════════════════════════════════════════════════════════════ */
export default function V2Page({ locale, variant }: Props) {
  const containerRef = useRef<HTMLDivElement>(null);
  const { scrollYProgress } = useScroll({ target: containerRef });

  /* Interpolate background color across scroll */
  const bgColor = useTransform(
    scrollYProgress,
    [0, 0.2, 0.4, 0.6, 0.8, 1],
    [
      "#fce4e4" /* dawn rose */,
      "#e8f4fc" /* morning blue */,
      "#fef3c7" /* midday gold */,
      "#fed7aa" /* evening amber */,
      "#1e1b4b" /* night indigo */,
      "#0f0d2e" /* deep night */,
    ],
  );

  const textColor = useTransform(
    scrollYProgress,
    [0, 0.6, 0.75, 1],
    ["#1a1a2e", "#1a1a2e", "#e2e0f0", "#e2e0f0"],
  );

  /* ── Form state ── */
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
    <motion.div
      ref={containerRef}
      className="relative"
      style={{
        background: bgColor,
        color: textColor,
        fontFamily: "'DM Sans', sans-serif",
      }}
    >
      {/* ── STICKY NAV ── */}
      <nav className="fixed top-0 left-0 right-0 z-50 backdrop-blur-md bg-white/10">
        <div className="mx-auto max-w-6xl flex items-center justify-between px-6 py-4">
          <span
            className="text-lg font-bold tracking-wide"
            style={{
              fontFamily: "'Plus Jakarta Sans', sans-serif",
              fontWeight: 800,
            }}
          >
            sunnad
          </span>
          <div className="flex items-center gap-5">
            <div className="hidden md:flex items-center gap-3 text-xs opacity-60">
              {locales.map((l) => (
                <Link
                  key={l.code}
                  href={`/${l.code}/${variant}`}
                  className={`hover:opacity-100 transition ${l.code === locale ? "opacity-100 font-semibold" : ""}`}
                >
                  {l.label}
                </Link>
              ))}
            </div>
            <a
              href="#night"
              className="text-xs font-semibold px-4 py-2 rounded-full border border-current/20 hover:bg-white/10 transition"
              style={{ fontFamily: "'Plus Jakarta Sans', sans-serif" }}
            >
              Join Waitlist
            </a>
          </div>
        </div>
      </nav>

      {/* ═══ SECTION 1: DAWN — Hero ═══ */}
      <section className="min-h-screen flex items-center justify-center px-6 pt-20">
        <motion.div
          className="text-center max-w-3xl"
          initial={{ opacity: 0, y: 40 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 1, ease: [0.22, 1, 0.36, 1] }}
        >
          <div
            className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-white/20 backdrop-blur-sm text-xs mb-8"
            style={{ fontFamily: "'Plus Jakarta Sans', sans-serif" }}
          >
            <span className="w-1.5 h-1.5 rounded-full bg-rose-400 animate-pulse" />
            From Fajr to Isha
          </div>
          <h1
            className="text-[clamp(2.8rem,8vw,6rem)] leading-[0.95] font-extrabold tracking-tight mb-6"
            style={{ fontFamily: "'Plus Jakarta Sans', sans-serif" }}
          >
            Your Deen,
            <br />
            <span
              className="italic font-light"
              style={{ fontFamily: "'Crimson Pro', serif" }}
            >
              every single
            </span>{" "}
            day.
          </h1>
          <p className="text-lg md:text-xl opacity-60 max-w-xl mx-auto leading-relaxed">
            A calm companion for building consistent worship habits. Track,
            reflect, and grow together — from dawn to dusk.
          </p>
          <motion.div
            className="mt-12"
            initial={{ opacity: 0, y: 30 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8, delay: 0.5 }}
          >
            <svg
              className="mx-auto opacity-30 animate-bounce"
              width="24"
              height="24"
              viewBox="0 0 24 24"
              fill="none"
            >
              <path
                d="M12 5v14M5 12l7 7 7-7"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
          </motion.div>
        </motion.div>
      </section>

      {/* ═══ SECTION 2: MORNING — Habits ═══ */}
      <section className="min-h-screen flex items-center px-6 py-20">
        <div className="mx-auto max-w-6xl w-full grid md:grid-cols-2 gap-12 items-center">
          <motion.div
            initial={{ opacity: 0, x: -40 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true, margin: "-100px" }}
            transition={{ duration: 0.7 }}
          >
            <PhoneMockup phase="morning" />
          </motion.div>
          <motion.div
            initial={{ opacity: 0, x: 40 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true, margin: "-100px" }}
            transition={{ duration: 0.7, delay: 0.2 }}
          >
            <span
              className="text-xs font-bold uppercase tracking-[0.2em] opacity-40"
              style={{ fontFamily: "'Plus Jakarta Sans', sans-serif" }}
            >
              Morning ☀
            </span>
            <h2
              className="text-3xl md:text-5xl font-bold mt-3 mb-6"
              style={{ fontFamily: "'Plus Jakarta Sans', sans-serif" }}
            >
              Start each day
              <br />
              with purpose
            </h2>
            <div className="space-y-5">
              {[
                {
                  title: "Smart Today View",
                  desc: "Only see habits scheduled for today. No clutter. Complete Fajr → Morning Adhkar → one page of Quran.",
                },
                {
                  title: "Beautiful Streaks",
                  desc: "Watch your consistency grow. Every day you show up, your streak gets stronger. Miss a day? Start fresh with no guilt.",
                },
                {
                  title: "Daily Wisdom",
                  desc: "A handpicked quote from the Quran or Sunnah greets you each morning. Save the ones that touch your heart.",
                },
              ].map((item, i) => (
                <div key={i} className="flex gap-4">
                  <div className="w-8 h-8 rounded-full bg-white/15 backdrop-blur-sm flex items-center justify-center flex-shrink-0 mt-0.5">
                    <span className="text-xs font-bold opacity-70">
                      {i + 1}
                    </span>
                  </div>
                  <div>
                    <h3
                      className="font-semibold text-sm mb-1"
                      style={{ fontFamily: "'Plus Jakarta Sans', sans-serif" }}
                    >
                      {item.title}
                    </h3>
                    <p className="text-sm opacity-55 leading-relaxed">
                      {item.desc}
                    </p>
                  </div>
                </div>
              ))}
            </div>
          </motion.div>
        </div>
      </section>

      {/* ═══ SECTION 3: MIDDAY — Reflection ═══ */}
      <section className="min-h-screen flex items-center px-6 py-20">
        <div className="mx-auto max-w-4xl w-full text-center">
          <motion.div
            initial={{ opacity: 0, scale: 0.95 }}
            whileInView={{ opacity: 1, scale: 1 }}
            viewport={{ once: true, margin: "-100px" }}
            transition={{ duration: 0.8 }}
          >
            <span
              className="text-xs font-bold uppercase tracking-[0.2em] opacity-40"
              style={{ fontFamily: "'Plus Jakarta Sans', sans-serif" }}
            >
              Midday ✦
            </span>
            <blockquote
              className="text-3xl md:text-5xl leading-snug font-light mt-6 mb-8"
              style={{
                fontFamily: "'Crimson Pro', serif",
                fontStyle: "italic",
              }}
            >
              &ldquo;And He found you lost and guided [you].&rdquo;
            </blockquote>
            <p
              className="text-sm uppercase tracking-[0.15em] opacity-40"
              style={{ fontFamily: "'Plus Jakarta Sans', sans-serif" }}
            >
              Surah Ad-Duha (93:7)
            </p>
          </motion.div>

          <motion.div
            className="mt-20 grid md:grid-cols-3 gap-8 text-left"
            initial={{ opacity: 0, y: 30 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: "-80px" }}
            transition={{ duration: 0.6 }}
          >
            {[
              {
                title: "Dhikr Counter",
                desc: "Tap to count your SubhanAllah, Alhamdulillah, Allahu Akbar. Set daily targets. See your totals grow.",
              },
              {
                title: "Offline First",
                desc: "Everything is stored on your phone. No internet? No problem. Your worship tracking never stops.",
              },
              {
                title: "Multilingual",
                desc: "Full support for English, Russian, and Kazakh from day one. Worship in the language of your heart.",
              },
            ].map((item, i) => (
              <motion.div
                key={i}
                className="py-6 px-1"
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ duration: 0.4, delay: i * 0.1 }}
              >
                <h3
                  className="font-bold text-lg mb-2"
                  style={{ fontFamily: "'Plus Jakarta Sans', sans-serif" }}
                >
                  {item.title}
                </h3>
                <p className="text-sm opacity-50 leading-relaxed">
                  {item.desc}
                </p>
              </motion.div>
            ))}
          </motion.div>
        </div>
      </section>

      {/* ═══ SECTION 4: EVENING — Community ═══ */}
      <section className="min-h-screen flex items-center px-6 py-20">
        <div className="mx-auto max-w-6xl w-full grid md:grid-cols-2 gap-16 items-center">
          <motion.div
            className="order-2 md:order-1"
            initial={{ opacity: 0, x: -30 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true, margin: "-80px" }}
            transition={{ duration: 0.6 }}
          >
            <span
              className="text-xs font-bold uppercase tracking-[0.2em] opacity-40"
              style={{ fontFamily: "'Plus Jakarta Sans', sans-serif" }}
            >
              Evening 🌅
            </span>
            <h2
              className="text-3xl md:text-5xl font-bold mt-3 mb-6"
              style={{ fontFamily: "'Plus Jakarta Sans', sans-serif" }}
            >
              Walk the path
              <br />
              together
            </h2>
            <p className="text-base opacity-55 leading-relaxed mb-8 max-w-md">
              Create a private group with 3-7 close friends. See each
              other&apos;s progress. Send a gentle nudge when someone misses a
              day. No public feeds, no judgment — just sincere mutual support on
              the path to consistency.
            </p>
            <div className="flex gap-3">
              {["A", "B", "C", "D"].map((_, i) => (
                <div
                  key={i}
                  className="w-12 h-12 rounded-full bg-gradient-to-br from-white/20 to-white/5 backdrop-blur-sm border border-white/10 flex items-center justify-center"
                  style={{ marginLeft: i > 0 ? "-10px" : "0" }}
                >
                  <span className="text-xs font-bold opacity-60">
                    {["👤", "👤", "👤", "+"][i]}
                  </span>
                </div>
              ))}
            </div>
          </motion.div>
          <motion.div
            className="order-1 md:order-2"
            initial={{ opacity: 0, x: 30 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true, margin: "-80px" }}
            transition={{ duration: 0.6, delay: 0.2 }}
          >
            <PhoneMockup phase="evening" />
          </motion.div>
        </div>
      </section>

      {/* ═══ SECTION 5: NIGHT — Waitlist ═══ */}
      <section
        id="night"
        className="min-h-screen flex items-center justify-center px-6 py-20 relative"
      >
        {/* Stars */}
        <div className="absolute inset-0 overflow-hidden pointer-events-none">
          {Array.from({ length: 30 }).map((_, i) => (
            <div
              key={i}
              className="absolute w-1 h-1 rounded-full bg-white/40"
              style={{
                top: `${Math.random() * 100}%`,
                left: `${Math.random() * 100}%`,
                animationDelay: `${Math.random() * 3}s`,
                animation: `twinkle ${2 + Math.random() * 3}s ease-in-out infinite`,
              }}
            />
          ))}
        </div>

        <style jsx>{`
          @keyframes twinkle {
            0%,
            100% {
              opacity: 0.2;
            }
            50% {
              opacity: 1;
            }
          }
        `}</style>

        <motion.div
          className="relative z-10 max-w-lg w-full text-center"
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: "-80px" }}
          transition={{ duration: 0.7 }}
        >
          <span
            className="text-xs font-bold uppercase tracking-[0.2em] text-indigo-300/50"
            style={{ fontFamily: "'Plus Jakarta Sans', sans-serif" }}
          >
            Night 🌙
          </span>
          <h2
            className="text-3xl md:text-5xl font-bold text-white mt-4 mb-4"
            style={{ fontFamily: "'Plus Jakarta Sans', sans-serif" }}
          >
            Be the first to know
          </h2>
          <p className="text-base text-indigo-200/50 mb-10 leading-relaxed">
            Sunnad is coming to iOS. Drop your email and we&apos;ll send exactly
            one message when it launches.
          </p>

          {result?.status === "subscribed" ||
          result?.status === "already_subscribed" ? (
            <div className="py-8">
              <div className="text-4xl mb-3">🌙</div>
              <p
                className="text-xl text-white font-semibold"
                style={{ fontFamily: "'Plus Jakarta Sans', sans-serif" }}
              >
                {result.status === "subscribed"
                  ? "Jazak Allah Khair"
                  : "Already registered"}
              </p>
              <p className="mt-2 text-sm text-indigo-200/40">
                {result.status === "subscribed"
                  ? "You're on the list. We'll reach out when Sunnad is ready."
                  : "Your email is already saved. Sit tight — it's coming."}
              </p>
            </div>
          ) : (
            <form onSubmit={handleSubmit} className="space-y-5">
              <div className="flex flex-col sm:flex-row gap-3">
                <input
                  type="email"
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="your@email.com"
                  className="flex-1 bg-white/[0.07] backdrop-blur-sm border border-white/[0.12] rounded-xl px-5 py-4 text-white placeholder:text-white/25 outline-none focus:border-indigo-400/50 transition text-sm"
                  style={{ fontFamily: "'DM Sans', sans-serif" }}
                />
                <button
                  type="submit"
                  disabled={!token || submitting}
                  className="px-8 py-4 bg-white text-indigo-950 font-bold text-sm rounded-xl disabled:opacity-40 hover:bg-indigo-100 transition-colors"
                  style={{ fontFamily: "'Plus Jakarta Sans', sans-serif" }}
                >
                  {submitting ? "Joining…" : "Join"}
                </button>
              </div>

              <div className="flex justify-center">
                <Turnstile
                  siteKey={landingConfig.turnstileSiteKey}
                  theme="dark"
                  onToken={setToken}
                  onExpired={() => setToken(null)}
                  onError={() => setToken(null)}
                />
              </div>

              {result?.status === "error" && (
                <p className="text-sm text-red-300/80">
                  {result.message || "Something went wrong."}
                </p>
              )}
              {result?.status === "rate_limited" && (
                <p className="text-sm text-amber-300/80">
                  Too many attempts. Please wait a moment.
                </p>
              )}
            </form>
          )}
        </motion.div>
      </section>

      {/* ── FOOTER ── */}
      <footer className="relative z-10 py-10 px-6">
        <div className="mx-auto max-w-6xl flex flex-col md:flex-row items-center justify-between gap-4 text-xs text-white/25">
          <span style={{ fontFamily: "'Plus Jakarta Sans', sans-serif" }}>
            © 2026 Sunnad
          </span>
          <div className="flex items-center gap-5">
            <Link
              href={`/${locale}/terms`}
              className="hover:text-white/50 transition-colors"
            >
              Terms
            </Link>
            <Link
              href={`/${locale}/privacy`}
              className="hover:text-white/50 transition-colors"
            >
              Privacy
            </Link>
            <span className="opacity-30">·</span>
            {locales.map((l) => (
              <Link
                key={l.code}
                href={`/${l.code}/${variant}`}
                className={`hover:text-white/50 transition-colors ${l.code === locale ? "text-white/50" : ""}`}
              >
                {l.label}
              </Link>
            ))}
          </div>
        </div>
      </footer>
    </motion.div>
  );
}
