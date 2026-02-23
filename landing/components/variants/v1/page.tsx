"use client";

import { useState, useRef } from "react";
import { motion, useScroll, useTransform } from "framer-motion";
import Link from "next/link";
import { Turnstile } from "@/components/turnstile";
import { submitWaitlist, type WaitlistResult } from "@/lib/waitlist-submit";
import { landingConfig } from "@/lib/config";

/* ── Types ── */
interface Props {
  locale: string;
  variant: string;
}

/* ── Islamic geometric pattern SVG ── */
function GeometricPattern({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      viewBox="0 0 200 200"
      xmlns="http://www.w3.org/2000/svg"
      opacity="0.07"
    >
      <defs>
        <pattern
          id="geo"
          x="0"
          y="0"
          width="50"
          height="50"
          patternUnits="userSpaceOnUse"
        >
          {/* 8-pointed star tessellation */}
          <path
            d="M25 0 L31.5 18.5 L50 25 L31.5 31.5 L25 50 L18.5 31.5 L0 25 L18.5 18.5Z"
            fill="none"
            stroke="currentColor"
            strokeWidth="0.6"
          />
          <circle
            cx="25"
            cy="25"
            r="4"
            fill="none"
            stroke="currentColor"
            strokeWidth="0.4"
          />
          <path
            d="M0 0 L18.5 18.5 M50 0 L31.5 18.5 M50 50 L31.5 31.5 M0 50 L18.5 31.5"
            stroke="currentColor"
            strokeWidth="0.3"
          />
        </pattern>
      </defs>
      <rect width="200" height="200" fill="url(#geo)" />
    </svg>
  );
}

/* ── Divider ── */
function GoldRule() {
  return (
    <div className="mx-auto max-w-[120px] h-px bg-gradient-to-r from-transparent via-[#c4a265] to-transparent my-16 md:my-24" />
  );
}

/* ── Phone Mockup ── */
function PhoneMockup() {
  return (
    <div className="relative w-[260px] h-[520px] md:w-[300px] md:h-[600px]">
      {/* Shadow layers */}
      <div className="absolute inset-0 rounded-[40px] bg-[#c4a265]/10 blur-2xl translate-y-4" />
      <div className="absolute inset-0 rounded-[40px] border border-[#c4a265]/20 bg-[#1a3a2a] overflow-hidden">
        {/* Status bar */}
        <div className="h-12 flex items-center justify-center">
          <div className="w-20 h-5 rounded-full bg-black/30" />
        </div>
        {/* Screen content mockup */}
        <div className="px-5 pt-2">
          <div
            className="text-[#c4a265]/60 text-[10px] tracking-[0.2em] uppercase"
            style={{ fontFamily: "'Cormorant Garamond', serif" }}
          >
            Today
          </div>
          <div className="mt-3 space-y-2.5">
            {[
              "Fajr Prayer",
              "Morning Adhkar",
              "Quran Reading",
              "Dhikr — SubhanAllah",
            ].map((label, i) => (
              <div
                key={i}
                className="flex items-center gap-3 rounded-xl bg-white/5 px-3 py-2.5"
              >
                <div
                  className={`w-5 h-5 rounded-full border-2 ${i < 2 ? "bg-[#c4a265]/80 border-[#c4a265]" : "border-[#c4a265]/30"}`}
                />
                <span
                  className="text-white/70 text-xs"
                  style={{ fontFamily: "'Source Serif 4', serif" }}
                >
                  {label}
                </span>
              </div>
            ))}
          </div>
          <div className="mt-5 rounded-xl bg-white/5 p-3">
            <p className="text-[10px] text-[#c4a265]/50 tracking-wider uppercase">
              Quote of the Day
            </p>
            <p
              className="mt-1 text-[11px] text-white/60 leading-relaxed italic"
              style={{ fontFamily: "'Cormorant Garamond', serif" }}
            >
              &ldquo;Verily, with hardship comes ease.&rdquo;
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}

/* ══════════════════════════════════════════════════════════════ */
/*  V1 — Sacred Geometry: Editorial Luxury Landing Page         */
/* ══════════════════════════════════════════════════════════════ */
export default function V1Page({ locale, variant }: Props) {
  const containerRef = useRef<HTMLDivElement>(null);
  const { scrollYProgress } = useScroll({ target: containerRef });
  const patternRotate = useTransform(scrollYProgress, [0, 1], [0, 45]);

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
    <div
      ref={containerRef}
      className="relative min-h-screen bg-[#faf7f2] text-[#2a2a2a] overflow-hidden"
      style={{ fontFamily: "'Source Serif 4', Georgia, serif" }}
    >
      {/* ── Geometric pattern overlay ── */}
      <motion.div
        className="fixed inset-0 pointer-events-none text-[#1a3a2a] z-0"
        style={{ rotate: patternRotate }}
      >
        <GeometricPattern className="w-[200%] h-[200%] -translate-x-1/4 -translate-y-1/4" />
      </motion.div>

      {/* ── NAV ── */}
      <nav className="relative z-20 border-b border-[#c4a265]/15">
        <div className="mx-auto max-w-6xl flex items-center justify-between px-6 py-5">
          <span
            className="text-xl tracking-[0.15em] text-[#1a3a2a]"
            style={{ fontFamily: "'Playfair Display', serif", fontWeight: 700 }}
          >
            SUNNAD
          </span>
          <div className="flex items-center gap-6">
            <div className="hidden md:flex items-center gap-4 text-xs tracking-[0.1em] text-[#1a3a2a]/60">
              {locales.map((l) => (
                <Link
                  key={l.code}
                  href={`/${l.code}/${variant}`}
                  className={`hover:text-[#1a3a2a] transition-colors ${l.code === locale ? "text-[#1a3a2a] font-semibold" : ""}`}
                >
                  {l.label}
                </Link>
              ))}
            </div>
            <a
              href="#waitlist"
              className="text-xs tracking-[0.15em] uppercase px-5 py-2.5 border border-[#c4a265] text-[#c4a265] hover:bg-[#c4a265] hover:text-white transition-all duration-300"
            >
              Join Waitlist
            </a>
          </div>
        </div>
      </nav>

      {/* ── HERO ── */}
      <section className="relative z-10 min-h-[85vh] flex items-center">
        <div className="mx-auto max-w-6xl w-full px-6 py-20 md:py-0">
          <div className="grid md:grid-cols-[1.1fr_0.9fr] gap-12 md:gap-8 items-center">
            {/* Left column — Editorial copy */}
            <motion.div
              initial={{ opacity: 0, y: 30 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.8, ease: [0.22, 1, 0.36, 1] }}
            >
              <div className="inline-block mb-6">
                <span
                  className="text-[11px] tracking-[0.3em] uppercase text-[#c4a265] border-b border-[#c4a265]/30 pb-1"
                  style={{
                    fontFamily: "'Cormorant Garamond', serif",
                    fontWeight: 600,
                  }}
                >
                  Coming Soon — iOS
                </span>
              </div>

              <h1
                className="text-[clamp(2.5rem,6vw,4.5rem)] leading-[1.05] text-[#1a3a2a] mb-6"
                style={{
                  fontFamily: "'Playfair Display', serif",
                  fontWeight: 700,
                }}
              >
                Your worship,
                <br />
                <span
                  className="italic"
                  style={{
                    fontFamily: "'Cormorant Garamond', serif",
                    fontWeight: 300,
                  }}
                >
                  beautifully
                </span>{" "}
                consistent
              </h1>

              <p className="text-lg md:text-xl leading-relaxed text-[#2a2a2a]/70 max-w-lg mb-8">
                Sunnad helps you stay rooted in your deen — track daily worship,
                build streaks, and keep each other accountable in small trusted
                groups.
              </p>

              <a
                href="#waitlist"
                className="inline-flex items-center gap-3 bg-[#1a3a2a] text-[#faf7f2] px-8 py-4 text-sm tracking-[0.12em] uppercase hover:bg-[#264a38] transition-colors duration-300"
                style={{
                  fontFamily: "'Cormorant Garamond', serif",
                  fontWeight: 600,
                }}
              >
                Reserve Your Spot
                <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
                  <path
                    d="M3 8h10M9 4l4 4-4 4"
                    stroke="currentColor"
                    strokeWidth="1.5"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />
                </svg>
              </a>
            </motion.div>

            {/* Right column — Phone mockup */}
            <motion.div
              className="flex justify-center md:justify-end"
              initial={{ opacity: 0, y: 50 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 1, delay: 0.3, ease: [0.22, 1, 0.36, 1] }}
            >
              <PhoneMockup />
            </motion.div>
          </div>
        </div>
      </section>

      <GoldRule />

      {/* ── THE STORY ── */}
      <section className="relative z-10 py-8">
        <div className="mx-auto max-w-6xl px-6">
          <motion.div
            className="max-w-2xl"
            initial={{ opacity: 0 }}
            whileInView={{ opacity: 1 }}
            viewport={{ once: true, margin: "-100px" }}
            transition={{ duration: 0.8 }}
          >
            <span
              className="text-[11px] tracking-[0.3em] uppercase text-[#c4a265] block mb-6"
              style={{
                fontFamily: "'Cormorant Garamond', serif",
                fontWeight: 600,
              }}
            >
              The Vision
            </span>
            <h2
              className="text-3xl md:text-4xl leading-snug text-[#1a3a2a] mb-8"
              style={{
                fontFamily: "'Playfair Display', serif",
                fontWeight: 600,
              }}
            >
              Consistency is the most beloved deed to Allah
            </h2>
          </motion.div>

          <div className="grid md:grid-cols-2 gap-12 mt-4">
            <motion.p
              className="text-base md:text-lg leading-[1.85] text-[#2a2a2a]/65 first-letter:text-5xl first-letter:font-semibold first-letter:float-left first-letter:mr-2 first-letter:mt-1 first-letter:text-[#1a3a2a]"
              style={{ fontFamily: "'Source Serif 4', serif" }}
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: "-80px" }}
              transition={{ duration: 0.6 }}
            >
              The Prophet ﷺ said:{" "}
              <em>
                &ldquo;The most beloved of deeds to Allah are those that are
                most consistent, even if they are small.&rdquo;
              </em>{" "}
              Yet in a world of endless distractions, staying consistent with
              our ibadah is harder than ever. Sunnad was made for this — a calm,
              focused space to nurture your daily worship.
            </motion.p>
            <motion.p
              className="text-base md:text-lg leading-[1.85] text-[#2a2a2a]/65"
              style={{ fontFamily: "'Source Serif 4', serif" }}
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: "-80px" }}
              transition={{ duration: 0.6, delay: 0.15 }}
            >
              No social feeds. No gamification tricks. Just a clean checklist
              that shows you what matters today, a counter for your dhikr, and
              small private groups where friends hold each other accountable —
              because the path is easier walked together. Works offline-first,
              because your deen doesn&apos;t need WiFi.
            </motion.p>
          </div>
        </div>
      </section>

      <GoldRule />

      {/* ── FEATURES ── */}
      <section className="relative z-10 py-8">
        <div className="mx-auto max-w-6xl px-6">
          <motion.span
            className="text-[11px] tracking-[0.3em] uppercase text-[#c4a265] block mb-6"
            style={{
              fontFamily: "'Cormorant Garamond', serif",
              fontWeight: 600,
            }}
            initial={{ opacity: 0 }}
            whileInView={{ opacity: 1 }}
            viewport={{ once: true }}
          >
            What Awaits You
          </motion.span>

          <div className="grid md:grid-cols-3 gap-8">
            {[
              {
                num: "01",
                title: "Today Checklist",
                desc: "See only the habits scheduled for today. Check them off, build streaks, and watch your consistency grow day by day.",
              },
              {
                num: "02",
                title: "Dhikr Counter",
                desc: "Tap-based counting for your tasbeeh — SubhanAllah, Alhamdulillah, Allahu Akbar. Track totals across days.",
              },
              {
                num: "03",
                title: "Daily Wisdom",
                desc: "Start each day with a beautiful quote from the Quran or Sunnah. Save the ones that move you. Share them easily.",
              },
              {
                num: "04",
                title: "Group Accountability",
                desc: "Create private groups of 3-7 friends. See who completed their habits. Send gentle nudges when someone falls behind.",
              },
              {
                num: "05",
                title: "Works Offline",
                desc: "Your data lives on your device first. No account needed for solo use. Sync only if you choose to join groups.",
              },
              {
                num: "06",
                title: "Multilingual",
                desc: "Full support for English, Russian, and Kazakh — right from launch. Your deen, in your language.",
              },
            ].map((f, i) => (
              <motion.div
                key={f.num}
                className="group py-8 border-t border-[#1a3a2a]/10"
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true, margin: "-60px" }}
                transition={{ duration: 0.5, delay: i * 0.08 }}
              >
                <span
                  className="text-[11px] tracking-[0.2em] text-[#c4a265]/60 block mb-3"
                  style={{ fontFamily: "'Cormorant Garamond', serif" }}
                >
                  {f.num}
                </span>
                <h3
                  className="text-xl text-[#1a3a2a] mb-3"
                  style={{
                    fontFamily: "'Playfair Display', serif",
                    fontWeight: 600,
                  }}
                >
                  {f.title}
                </h3>
                <p className="text-sm leading-relaxed text-[#2a2a2a]/55">
                  {f.desc}
                </p>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      <GoldRule />

      {/* ── PULL QUOTE ── */}
      <section className="relative z-10 py-8">
        <div className="mx-auto max-w-4xl px-6 text-center">
          <motion.blockquote
            className="text-2xl md:text-4xl leading-relaxed text-[#1a3a2a]"
            style={{
              fontFamily: "'Cormorant Garamond', serif",
              fontWeight: 300,
              fontStyle: "italic",
            }}
            initial={{ opacity: 0, scale: 0.97 }}
            whileInView={{ opacity: 1, scale: 1 }}
            viewport={{ once: true, margin: "-80px" }}
            transition={{ duration: 0.8 }}
          >
            &ldquo;Take up good deeds only as much as you are able, for the best
            deeds are those done consistently even if they are few.&rdquo;
          </motion.blockquote>
          <p
            className="mt-6 text-sm tracking-[0.15em] uppercase text-[#c4a265]"
            style={{
              fontFamily: "'Cormorant Garamond', serif",
              fontWeight: 600,
            }}
          >
            — Prophet Muhammad ﷺ (Ibn Majah)
          </p>
        </div>
      </section>

      <GoldRule />

      {/* ── WAITLIST ── */}
      <section id="waitlist" className="relative z-10 py-12 md:py-20">
        <div className="mx-auto max-w-xl px-6 text-center">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: "-60px" }}
            transition={{ duration: 0.6 }}
          >
            <span
              className="text-[11px] tracking-[0.3em] uppercase text-[#c4a265] block mb-6"
              style={{
                fontFamily: "'Cormorant Garamond', serif",
                fontWeight: 600,
              }}
            >
              Be Among the First
            </span>
            <h2
              className="text-3xl md:text-4xl text-[#1a3a2a] mb-4"
              style={{
                fontFamily: "'Playfair Display', serif",
                fontWeight: 600,
              }}
            >
              Join the Waitlist
            </h2>
            <p className="text-base text-[#2a2a2a]/60 mb-10">
              We&apos;ll let you know the moment Sunnad is ready for download.
              No spam — just one email when it&apos;s time.
            </p>

            {result?.status === "subscribed" ||
            result?.status === "already_subscribed" ? (
              <div className="py-8">
                <div className="w-12 h-12 mx-auto mb-4 rounded-full border-2 border-[#c4a265] flex items-center justify-center">
                  <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
                    <path
                      d="M5 10l3.5 3.5L15 7"
                      stroke="#c4a265"
                      strokeWidth="2"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                    />
                  </svg>
                </div>
                <p
                  className="text-xl text-[#1a3a2a]"
                  style={{ fontFamily: "'Playfair Display', serif" }}
                >
                  {result.status === "subscribed"
                    ? "You're on the list"
                    : "You're already on the list"}
                </p>
                <p className="mt-2 text-sm text-[#2a2a2a]/50">
                  {result.status === "subscribed"
                    ? "May Allah bless your consistency. We'll reach out soon."
                    : "We already have your email. Stay patient — launch is near."}
                </p>
              </div>
            ) : (
              <form onSubmit={handleSubmit} className="space-y-5">
                <div className="relative">
                  <input
                    type="email"
                    required
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="your@email.com"
                    className="w-full bg-transparent border-b-2 border-[#1a3a2a]/15 focus:border-[#c4a265] text-[#1a3a2a] placeholder:text-[#1a3a2a]/25 text-center text-lg py-4 outline-none transition-colors duration-300"
                    style={{ fontFamily: "'Source Serif 4', serif" }}
                  />
                </div>

                <div className="flex justify-center">
                  <Turnstile
                    siteKey={landingConfig.turnstileSiteKey}
                    theme="light"
                    onToken={setToken}
                    onExpired={() => setToken(null)}
                    onError={() => setToken(null)}
                  />
                </div>

                <button
                  type="submit"
                  disabled={!token || submitting}
                  className="w-full max-w-xs mx-auto block bg-[#1a3a2a] text-[#faf7f2] py-4 text-sm tracking-[0.15em] uppercase disabled:opacity-40 hover:bg-[#264a38] transition-all duration-300"
                  style={{
                    fontFamily: "'Cormorant Garamond', serif",
                    fontWeight: 600,
                  }}
                >
                  {submitting ? "Reserving…" : "Reserve My Spot"}
                </button>

                {result?.status === "error" && (
                  <p className="text-sm text-red-700/70 mt-2">
                    {result.message ||
                      "Something went wrong. Please try again."}
                  </p>
                )}
                {result?.status === "rate_limited" && (
                  <p className="text-sm text-amber-700/70 mt-2">
                    Too many attempts. Please wait a moment and try again.
                  </p>
                )}
              </form>
            )}
          </motion.div>
        </div>
      </section>

      {/* ── FOOTER ── */}
      <footer className="relative z-10 border-t border-[#c4a265]/15 py-10">
        <div className="mx-auto max-w-6xl px-6 flex flex-col md:flex-row items-center justify-between gap-4 text-xs text-[#2a2a2a]/40">
          <span style={{ fontFamily: "'Playfair Display', serif" }}>
            © 2026 Sunnad
          </span>
          <div className="flex items-center gap-6">
            <Link
              href={`/${locale}/terms`}
              className="hover:text-[#2a2a2a]/70 transition-colors"
            >
              Terms
            </Link>
            <Link
              href={`/${locale}/privacy`}
              className="hover:text-[#2a2a2a]/70 transition-colors"
            >
              Privacy
            </Link>
            <span className="text-[#2a2a2a]/20">|</span>
            {locales.map((l) => (
              <Link
                key={l.code}
                href={`/${l.code}/${variant}`}
                className={`hover:text-[#2a2a2a]/70 transition-colors ${l.code === locale ? "text-[#2a2a2a]/70" : ""}`}
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
