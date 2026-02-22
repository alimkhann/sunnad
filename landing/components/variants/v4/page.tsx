"use client";

import { useState, useEffect, useRef } from "react";
import { motion, useScroll, useTransform } from "framer-motion";
import Link from "next/link";
import { Turnstile } from "@/components/turnstile";
import { submitWaitlist, type WaitlistResult } from "@/lib/waitlist-submit";
import { landingConfig } from "@/lib/config";

interface Props {
  locale: string;
  variant: string;
}

/* ── Floating particles ── */
function Particles({ count = 40 }: { count?: number }) {
  const [particles, setParticles] = useState<
    { x: number; y: number; size: number; delay: number; duration: number }[]
  >([]);

  useEffect(() => {
    setParticles(
      Array.from({ length: count }, () => ({
        x: Math.random() * 100,
        y: Math.random() * 100,
        size: 1 + Math.random() * 2,
        delay: Math.random() * 5,
        duration: 4 + Math.random() * 6,
      })),
    );
  }, [count]);

  return (
    <div className="fixed inset-0 pointer-events-none z-0 overflow-hidden">
      {particles.map((p, i) => (
        <div
          key={i}
          className="absolute rounded-full bg-white/20"
          style={{
            left: `${p.x}%`,
            top: `${p.y}%`,
            width: p.size,
            height: p.size,
            animation: `float-particle ${p.duration}s ease-in-out ${p.delay}s infinite alternate`,
          }}
        />
      ))}
      <style jsx>{`
        @keyframes float-particle {
          0% {
            transform: translateY(0) translateX(0);
            opacity: 0.15;
          }
          50% {
            opacity: 0.5;
          }
          100% {
            transform: translateY(-30px) translateX(15px);
            opacity: 0.1;
          }
        }
      `}</style>
    </div>
  );
}

/* ── Glowing Phone Mockup ── */
function GlowPhone() {
  return (
    <div className="relative mx-auto w-[260px] h-[520px] md:w-[300px] md:h-[600px]">
      {/* Glow layers */}
      <div className="absolute -inset-6 rounded-[52px] bg-gradient-to-b from-[#ffd700]/10 via-purple-500/10 to-cyan-500/10 blur-3xl" />
      <div
        className="absolute -inset-3 rounded-[48px] bg-gradient-to-tr from-[#ffd700]/15 to-purple-500/15 blur-xl animate-pulse"
        style={{ animationDuration: "4s" }}
      />

      {/* Phone body */}
      <div className="relative w-full h-full rounded-[40px] bg-gradient-to-b from-gray-800 to-gray-900 border border-white/[0.08] overflow-hidden shadow-2xl">
        {/* Rim light */}
        <div className="absolute inset-0 rounded-[40px] border border-[#ffd700]/20" />
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-2/3 h-px bg-gradient-to-r from-transparent via-[#ffd700]/40 to-transparent" />

        {/* Notch */}
        <div className="absolute top-0 inset-x-0 flex justify-center pt-3">
          <div className="w-[100px] h-[28px] rounded-full bg-black" />
        </div>

        {/* Screen content */}
        <div
          className="pt-16 px-5 space-y-3"
          style={{ fontFamily: "'Outfit', sans-serif" }}
        >
          <div className="text-[10px] font-medium text-[#ffd700]/40 tracking-[0.2em] uppercase">
            Today
          </div>
          {[
            "Fajr Prayer",
            "Morning Adhkar",
            "Quran — Surah Al-Kahf",
            "Evening Dhikr",
          ].map((label, i) => (
            <div
              key={i}
              className="flex items-center gap-3 rounded-2xl bg-white/[0.04] border border-white/[0.06] px-4 py-3 backdrop-blur-sm"
            >
              <div
                className={`w-5 h-5 rounded-full border-2 ${i < 2 ? "bg-[#ffd700]/80 border-[#ffd700]/60" : "border-white/15"}`}
              />
              <span className="text-xs text-white/50">{label}</span>
              {i < 2 && (
                <span className="ml-auto text-[8px] text-[#ffd700]/50">✓</span>
              )}
            </div>
          ))}
          <div className="rounded-2xl bg-gradient-to-br from-purple-500/10 to-indigo-500/10 border border-white/[0.05] p-4 mt-2">
            <div className="text-[8px] text-[#ffd700]/30 uppercase tracking-wider">
              Quote
            </div>
            <p
              className="text-[11px] text-white/40 leading-relaxed mt-1 italic"
              style={{ fontFamily: "'Outfit', sans-serif" }}
            >
              &ldquo;Indeed, Allah is with the patient.&rdquo;
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}

/* ══════════════════════════════════════════════════════════════ */
/*  V4 — Night Devotion: Dark, Immersive, Premium               */
/* ══════════════════════════════════════════════════════════════ */
export default function V4Page({ locale, variant }: Props) {
  const heroRef = useRef<HTMLDivElement>(null);
  const { scrollYProgress } = useScroll();
  const heroOpacity = useTransform(scrollYProgress, [0, 0.15], [1, 0]);
  const heroScale = useTransform(scrollYProgress, [0, 0.15], [1, 0.95]);

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
      className="min-h-screen bg-[#0a0e1a] text-[#c8c8d0] selection:bg-[#ffd700]/20"
      style={{ fontFamily: "'Outfit', sans-serif" }}
    >
      <Particles />

      {/* Ambient radial gradients */}
      <div className="fixed inset-0 pointer-events-none z-0">
        <div className="absolute top-0 left-1/4 w-[600px] h-[600px] bg-purple-600/[0.04] rounded-full blur-[120px]" />
        <div className="absolute bottom-1/4 right-1/4 w-[500px] h-[500px] bg-indigo-500/[0.05] rounded-full blur-[100px]" />
        <div className="absolute top-1/3 right-1/6 w-[300px] h-[300px] bg-[#ffd700]/[0.03] rounded-full blur-[80px]" />
      </div>

      {/* ── NAV ── */}
      <nav className="fixed top-0 left-0 right-0 z-50 bg-[#0a0e1a]/60 backdrop-blur-xl border-b border-white/[0.04]">
        <div className="mx-auto max-w-6xl flex items-center justify-between px-6 py-4">
          <span
            className="text-lg font-bold tracking-wide text-white"
            style={{ fontFamily: "'Unbounded', sans-serif" }}
          >
            sunnad
          </span>
          <div className="flex items-center gap-5">
            <div
              className="hidden md:flex items-center gap-3 text-xs text-white/30"
              style={{ fontFamily: "'Space Mono', monospace" }}
            >
              {locales.map((l) => (
                <Link
                  key={l.code}
                  href={`/${l.code}/${variant}`}
                  className={`hover:text-white/60 transition ${l.code === locale ? "text-[#ffd700]/70" : ""}`}
                >
                  {l.label}
                </Link>
              ))}
            </div>
            <a
              href="#waitlist"
              className="text-xs font-semibold px-5 py-2 rounded-full bg-white/[0.06] border border-white/[0.08] text-white/70 hover:bg-white/[0.12] hover:text-white transition-all backdrop-blur-sm"
            >
              Join Waitlist
            </a>
          </div>
        </div>
      </nav>

      {/* ── HERO ── */}
      <motion.section
        ref={heroRef}
        className="relative z-10 min-h-screen flex items-center justify-center px-6 pt-20"
        style={{ opacity: heroOpacity, scale: heroScale }}
      >
        <div className="text-center max-w-3xl">
          <motion.div
            initial={{ opacity: 0, y: 30 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.9, ease: [0.22, 1, 0.36, 1] }}
          >
            <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-white/[0.04] border border-white/[0.06] text-xs text-white/40 mb-10 backdrop-blur-sm">
              <span className="w-1.5 h-1.5 rounded-full bg-[#ffd700]/60 animate-pulse" />
              iOS — Coming Soon
            </div>

            <h1
              className="text-[clamp(2.5rem,7vw,5rem)] leading-[1.05] font-bold text-white mb-6"
              style={{ fontFamily: "'Unbounded', sans-serif" }}
            >
              Worship in{" "}
              <span className="bg-gradient-to-r from-[#ffd700] via-amber-400 to-[#ffd700] bg-clip-text text-transparent">
                stillness
              </span>
            </h1>

            <p className="text-lg md:text-xl text-white/35 max-w-xl mx-auto leading-relaxed">
              A serene space to cultivate your daily ibadah. Track habits, count
              dhikr, and walk the path alongside those you trust.
            </p>
          </motion.div>

          <motion.div
            className="mt-16"
            initial={{ opacity: 0, y: 50 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 1, delay: 0.4 }}
          >
            <GlowPhone />
          </motion.div>
        </div>
      </motion.section>

      {/* ── WHY SUNNAD — Glass Cards ── */}
      <section className="relative z-10 py-24 md:py-36 px-6">
        <div className="mx-auto max-w-6xl">
          <motion.div
            className="text-center mb-16"
            initial={{ opacity: 0 }}
            whileInView={{ opacity: 1 }}
            viewport={{ once: true, margin: "-80px" }}
            transition={{ duration: 0.6 }}
          >
            <span
              className="text-[10px] tracking-[0.3em] uppercase text-[#ffd700]/30"
              style={{ fontFamily: "'Space Mono', monospace" }}
            >
              Why Sunnad
            </span>
            <h2
              className="text-3xl md:text-4xl font-bold text-white mt-4"
              style={{ fontFamily: "'Unbounded', sans-serif" }}
            >
              Built for focus
            </h2>
          </motion.div>

          <div className="grid md:grid-cols-3 gap-6">
            {[
              {
                icon: "☀",
                glow: "from-amber-500/10 to-yellow-500/5",
                title: "Today View",
                desc: "Only habits for today. Check them off one by one. No overwhelm, no clutter — just what matters right now.",
              },
              {
                icon: "📿",
                glow: "from-purple-500/10 to-indigo-500/5",
                title: "Dhikr Counter",
                desc: "Tap to count your tasbeeh. Track daily targets. Feel the rhythm of remembrance in a distraction-free interface.",
              },
              {
                icon: "🤝",
                glow: "from-emerald-500/10 to-teal-500/5",
                title: "Trusted Groups",
                desc: "Small circles of 3-7 friends. See each other's streaks. Send gentle reminders. No public feeds. No judgment.",
              },
              {
                icon: "📖",
                glow: "from-sky-500/10 to-blue-500/5",
                title: "Daily Wisdom",
                desc: "Start your morning with a quote from the Quran or Sunnah. Save favorites. Share with no effort.",
              },
              {
                icon: "📴",
                glow: "from-rose-500/10 to-pink-500/5",
                title: "Offline First",
                desc: "Everything stored on-device. No internet needed for personal use. Your worship tracking never depends on a server.",
              },
              {
                icon: "🌐",
                glow: "from-[#ffd700]/10 to-amber-500/5",
                title: "Your Language",
                desc: "Full English, Russian, and Kazakh support. Every screen, every label — in the language you think in.",
              },
            ].map((card, i) => (
              <motion.div
                key={i}
                className={`group relative rounded-2xl p-6 md:p-8 bg-white/[0.03] border border-white/[0.05] backdrop-blur-sm hover:bg-white/[0.06] transition-all duration-500`}
                initial={{ opacity: 0, y: 25 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true, margin: "-50px" }}
                transition={{ duration: 0.5, delay: i * 0.08 }}
                whileHover={{ y: -4 }}
              >
                {/* Aurora glow */}
                <div
                  className={`absolute inset-0 rounded-2xl bg-gradient-to-br ${card.glow} opacity-0 group-hover:opacity-100 transition-opacity duration-500`}
                />
                <div className="relative z-10">
                  <div className="text-2xl mb-4">{card.icon}</div>
                  <h3 className="text-white font-semibold text-base mb-2">
                    {card.title}
                  </h3>
                  <p className="text-sm text-white/30 leading-relaxed">
                    {card.desc}
                  </p>
                </div>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      {/* ── PULL QUOTE — Glass Panel ── */}
      <section className="relative z-10 py-16 md:py-24 px-6">
        <motion.div
          className="mx-auto max-w-3xl rounded-3xl bg-white/[0.03] border border-white/[0.05] backdrop-blur-sm p-10 md:p-16 text-center"
          initial={{ opacity: 0, scale: 0.98 }}
          whileInView={{ opacity: 1, scale: 1 }}
          viewport={{ once: true, margin: "-80px" }}
          transition={{ duration: 0.7 }}
        >
          <blockquote
            className="text-2xl md:text-3xl leading-relaxed text-white/70 font-light italic"
            style={{ fontFamily: "'Outfit', sans-serif" }}
          >
            &ldquo;Take up good deeds only as much as you are able, for the best
            deeds are those done consistently even if they are few.&rdquo;
          </blockquote>
          <p
            className="mt-6 text-xs tracking-[0.2em] uppercase text-[#ffd700]/40"
            style={{ fontFamily: "'Space Mono', monospace" }}
          >
            Prophet Muhammad ﷺ
          </p>
        </motion.div>
      </section>

      {/* ── WAITLIST ── */}
      <section id="waitlist" className="relative z-10 py-20 md:py-32 px-6">
        <motion.div
          className="mx-auto max-w-lg text-center"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: "-60px" }}
          transition={{ duration: 0.6 }}
        >
          <span
            className="text-[10px] tracking-[0.3em] uppercase text-[#ffd700]/30"
            style={{ fontFamily: "'Space Mono', monospace" }}
          >
            Early Access
          </span>
          <h2
            className="text-3xl md:text-4xl font-bold text-white mt-4 mb-4"
            style={{ fontFamily: "'Unbounded', sans-serif" }}
          >
            Be first in line
          </h2>
          <p className="text-base text-white/30 mb-10 leading-relaxed">
            One email when Sunnad launches. Nothing before. Nothing after. Just
            the signal.
          </p>

          {result?.status === "subscribed" ||
          result?.status === "already_subscribed" ? (
            <div className="rounded-2xl bg-white/[0.04] border border-[#ffd700]/20 p-8">
              <div className="text-3xl mb-3">🌙</div>
              <p
                className="text-xl text-white font-semibold"
                style={{ fontFamily: "'Unbounded', sans-serif" }}
              >
                {result.status === "subscribed"
                  ? "You're in"
                  : "Already registered"}
              </p>
              <p className="mt-2 text-sm text-white/30">
                {result.status === "subscribed"
                  ? "Jazak Allah Khair. We'll let you know when it's time."
                  : "Your email is already saved. Patience — it's coming."}
              </p>
            </div>
          ) : (
            <form onSubmit={handleSubmit} className="space-y-5">
              {/* Glowing input */}
              <div className="relative group">
                <div className="absolute -inset-0.5 rounded-xl bg-gradient-to-r from-[#ffd700]/20 via-purple-500/20 to-[#ffd700]/20 opacity-0 group-focus-within:opacity-100 transition-opacity duration-500 blur-sm" />
                <input
                  type="email"
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="your@email.com"
                  className="relative w-full bg-white/[0.04] border border-white/[0.08] rounded-xl px-5 py-4 text-white placeholder:text-white/20 outline-none focus:border-[#ffd700]/30 transition-colors text-sm backdrop-blur-sm"
                />
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

              <button
                type="submit"
                disabled={!token || submitting}
                className="w-full py-4 rounded-xl bg-gradient-to-r from-[#ffd700] to-amber-500 text-[#0a0e1a] font-bold text-sm tracking-wider uppercase disabled:opacity-30 hover:from-[#ffe44d] hover:to-amber-400 transition-all duration-300"
                style={{ fontFamily: "'Unbounded', sans-serif" }}
              >
                {submitting ? "Joining…" : "Reserve My Spot"}
              </button>

              {result?.status === "error" && (
                <p className="text-sm text-red-400/70">
                  {result.message || "Something went wrong."}
                </p>
              )}
              {result?.status === "rate_limited" && (
                <p className="text-sm text-amber-400/70">
                  Too many attempts. Please wait.
                </p>
              )}
            </form>
          )}
        </motion.div>
      </section>

      {/* ── FOOTER ── */}
      <footer className="relative z-10 border-t border-white/[0.04] py-10 px-6">
        <div className="mx-auto max-w-6xl flex flex-col md:flex-row items-center justify-between gap-4 text-xs text-white/20">
          <span
            style={{ fontFamily: "'Unbounded', sans-serif", fontSize: "10px" }}
          >
            © 2026 Sunnad
          </span>
          <div
            className="flex items-center gap-5"
            style={{ fontFamily: "'Space Mono', monospace" }}
          >
            <Link
              href={`/${locale}/terms`}
              className="hover:text-white/40 transition-colors"
            >
              Terms
            </Link>
            <Link
              href={`/${locale}/privacy`}
              className="hover:text-white/40 transition-colors"
            >
              Privacy
            </Link>
            <span className="opacity-30">·</span>
            {locales.map((l) => (
              <Link
                key={l.code}
                href={`/${l.code}/${variant}`}
                className={`hover:text-white/40 transition-colors ${l.code === locale ? "text-[#ffd700]/50" : ""}`}
              >
                {l.label}
              </Link>
            ))}
          </div>
        </div>
      </footer>
    </div>
  );
}
