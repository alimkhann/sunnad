"use client";

import { useState } from "react";
import { motion } from "framer-motion";
import Link from "next/link";
import { Turnstile } from "@/components/turnstile";
import { submitWaitlist, type WaitlistResult } from "@/lib/waitlist-submit";
import { landingConfig } from "@/lib/config";

interface Props {
  locale: string;
  variant: string;
}

/* ── Wavy SVG divider ── */
function WaveDivider({
  flip,
  color = "#7a9e7e",
}: {
  flip?: boolean;
  color?: string;
}) {
  return (
    <div
      className={`w-full overflow-hidden leading-[0] ${flip ? "rotate-180" : ""}`}
    >
      <svg
        viewBox="0 0 1200 120"
        preserveAspectRatio="none"
        className="w-full h-16 md:h-24"
      >
        <path
          d="M0,40 C150,100 350,0 500,50 C650,100 800,20 1000,60 C1100,80 1150,30 1200,50 L1200,120 L0,120 Z"
          fill={color}
          fillOpacity="0.08"
        />
        <path
          d="M0,60 C200,20 400,90 600,40 C800,-10 1000,80 1200,30 L1200,120 L0,120 Z"
          fill={color}
          fillOpacity="0.05"
        />
      </svg>
    </div>
  );
}

/* ── Decorative blob ── */
function Blob({ className, color }: { className?: string; color: string }) {
  return (
    <div
      className={`absolute rounded-full blur-3xl pointer-events-none ${className}`}
      style={{ background: color }}
    />
  );
}

/* ── Phone Mockup (tilted, layered shadow) ── */
function TiltedPhone() {
  return (
    <motion.div
      className="relative w-[240px] h-[480px] md:w-[270px] md:h-[540px]"
      initial={{ rotate: -3 }}
      whileHover={{ rotate: 0 }}
      transition={{ type: "spring", stiffness: 200, damping: 20 }}
    >
      {/* Layered paper shadows */}
      <div className="absolute inset-0 rounded-[36px] bg-[#3d2c1e]/5 translate-x-3 translate-y-3 rotate-2" />
      <div className="absolute inset-0 rounded-[36px] bg-[#3d2c1e]/8 translate-x-1.5 translate-y-1.5 rotate-1" />

      {/* Phone */}
      <div className="relative w-full h-full rounded-[36px] bg-[#faf3eb] border-2 border-[#3d2c1e]/10 overflow-hidden shadow-xl">
        {/* Notch */}
        <div className="absolute top-0 inset-x-0 flex justify-center pt-2.5">
          <div className="w-[80px] h-[24px] rounded-full bg-[#3d2c1e]/10" />
        </div>
        {/* Screen */}
        <div
          className="pt-14 px-4 space-y-2.5"
          style={{ fontFamily: "'Nunito Sans', sans-serif" }}
        >
          <div
            className="text-[10px] font-bold text-[#7a9e7e] tracking-wider uppercase"
            style={{ fontFamily: "'Caveat', cursive" }}
          >
            Today&apos;s habits ✨
          </div>
          {["Fajr Prayer", "Morning Adhkar", "Read Quran", "Gratitude"].map(
            (label, i) => (
              <div
                key={i}
                className="flex items-center gap-2.5 rounded-2xl bg-white/80 px-3 py-2.5 border border-[#3d2c1e]/5"
              >
                <div
                  className={`w-5 h-5 rounded-full border-2 ${i < 2 ? "bg-[#e8917a] border-[#e8917a]" : "border-[#3d2c1e]/15"}`}
                >
                  {i < 2 && (
                    <svg className="w-5 h-5 text-white" viewBox="0 0 20 20">
                      <path
                        d="M6 10l2.5 2.5L14 7"
                        stroke="currentColor"
                        fill="none"
                        strokeWidth="2"
                        strokeLinecap="round"
                      />
                    </svg>
                  )}
                </div>
                <span className="text-xs text-[#3d2c1e]/70">{label}</span>
              </div>
            ),
          )}
          <div className="rounded-2xl bg-[#e8917a]/10 p-3 mt-1">
            <p
              className="text-[10px] text-[#e8917a] font-bold"
              style={{ fontFamily: "'Caveat', cursive" }}
            >
              Quote of the day
            </p>
            <p
              className="text-[11px] text-[#3d2c1e]/50 italic leading-relaxed mt-0.5"
              style={{ fontFamily: "'Nunito Sans', sans-serif" }}
            >
              &ldquo;Be in this world as if you were a stranger or a
              traveler.&rdquo;
            </p>
          </div>
        </div>
      </div>
    </motion.div>
  );
}

/* Card spring config */
const springPop = { type: "spring" as const, stiffness: 300, damping: 20 };

/* ══════════════════════════════════════════════════════════════ */
/*  V5 — Handcrafted Warmth: Organic, Approachable, Human      */
/* ══════════════════════════════════════════════════════════════ */
export default function V5Page({ locale, variant }: Props) {
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
    { code: "en", label: "English" },
    { code: "ru", label: "Русский" },
    { code: "kk", label: "Қазақша" },
  ];

  return (
    <div
      className="min-h-screen bg-[#faf3eb] text-[#3d2c1e] overflow-hidden selection:bg-[#e8917a]/30"
      style={{ fontFamily: "'Nunito Sans', sans-serif" }}
    >
      {/* Decorative blobs */}
      <Blob
        className="w-[400px] h-[400px] top-[-100px] right-[-100px] opacity-40"
        color="#7a9e7e22"
      />
      <Blob
        className="w-[300px] h-[300px] top-[30%] left-[-80px] opacity-30"
        color="#e8917a18"
      />
      <Blob
        className="w-[350px] h-[350px] bottom-[20%] right-[-60px] opacity-30"
        color="#7a9e7e15"
      />

      {/* ── NAV ── */}
      <nav className="relative z-20 px-6 py-5">
        <div className="mx-auto max-w-6xl flex items-center justify-between">
          <span
            className="text-2xl text-[#3d2c1e]"
            style={{
              fontFamily: "'Fraunces', serif",
              fontWeight: 700,
              fontOpticalSizing: "auto",
            }}
          >
            sunnad
          </span>
          <div className="flex items-center gap-4">
            <div className="hidden md:flex items-center gap-2 text-sm text-[#3d2c1e]/40">
              {locales.map((l, i) => (
                <span key={l.code}>
                  {i > 0 && <span className="mr-2">·</span>}
                  <Link
                    href={`/${l.code}/${variant}`}
                    className={`hover:text-[#3d2c1e]/70 transition ${l.code === locale ? "text-[#e8917a] font-semibold" : ""}`}
                  >
                    {l.label}
                  </Link>
                </span>
              ))}
            </div>
            <a
              href="#waitlist"
              className="px-5 py-2.5 rounded-full bg-[#e8917a] text-white text-sm font-semibold hover:bg-[#d4785e] transition-colors shadow-md shadow-[#e8917a]/20"
            >
              Join Waitlist 🌱
            </a>
          </div>
        </div>
      </nav>

      {/* ── HERO ── */}
      <section className="relative z-10 px-6 pt-10 md:pt-20 pb-4">
        <div className="mx-auto max-w-6xl grid md:grid-cols-2 gap-12 items-center">
          <motion.div
            initial={{ opacity: 0, y: 30 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.7, ease: [0.22, 1, 0.36, 1] }}
          >
            <span
              className="text-lg text-[#e8917a] block mb-3"
              style={{ fontFamily: "'Caveat', cursive", fontWeight: 600 }}
            >
              A gentle companion for your deen ✨
            </span>

            <h1
              className="text-[clamp(2.4rem,6vw,4.2rem)] leading-[1.1] mb-6"
              style={{
                fontFamily: "'Fraunces', serif",
                fontWeight: 900,
                fontOpticalSizing: "auto",
              }}
            >
              Small habits,{" "}
              <span
                className="text-[#7a9e7e] italic"
                style={{ fontWeight: 400 }}
              >
                big
              </span>
              <br />
              barakah
            </h1>

            <p className="text-base md:text-lg text-[#3d2c1e]/55 leading-relaxed max-w-md mb-8">
              Sunnad helps you stay consistent with daily worship — prayer,
              dhikr, Quran, and more — with the warmth of friends cheering you
              on. No pressure. Just love and accountability.
            </p>

            <div className="flex flex-wrap gap-3">
              <a
                href="#waitlist"
                className="px-7 py-3.5 rounded-full bg-[#3d2c1e] text-[#faf3eb] text-sm font-semibold hover:bg-[#5a4030] transition-colors shadow-lg shadow-[#3d2c1e]/15"
              >
                Get Early Access
              </a>
              <a
                href="#how"
                className="px-7 py-3.5 rounded-full border-2 border-[#3d2c1e]/15 text-[#3d2c1e]/60 text-sm font-semibold hover:border-[#3d2c1e]/30 transition-colors"
              >
                See How It Works
              </a>
            </div>
          </motion.div>

          <motion.div
            className="flex justify-center"
            initial={{ opacity: 0, y: 40, rotate: -5 }}
            animate={{ opacity: 1, y: 0, rotate: -3 }}
            transition={{ duration: 0.8, delay: 0.2, ease: [0.22, 1, 0.36, 1] }}
          >
            <TiltedPhone />
          </motion.div>
        </div>
      </section>

      <WaveDivider color="#7a9e7e" />

      {/* ── FEATURES — Rotated masonry cards ── */}
      <section className="relative z-10 py-12 md:py-20 px-6 bg-[#7a9e7e]/[0.04]">
        <div className="mx-auto max-w-5xl">
          <motion.div
            className="text-center mb-14"
            initial={{ opacity: 0 }}
            whileInView={{ opacity: 1 }}
            viewport={{ once: true }}
          >
            <span
              style={{ fontFamily: "'Caveat', cursive", fontWeight: 600 }}
              className="text-[#e8917a] text-lg"
            >
              Everything you need
            </span>
            <h2
              className="text-3xl md:text-4xl mt-2"
              style={{ fontFamily: "'Fraunces', serif", fontWeight: 700 }}
            >
              Simple by design
            </h2>
          </motion.div>

          <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-6">
            {[
              {
                icon: "🌅",
                title: "Today View",
                desc: "Only your habits for today. A clean checklist you can actually finish. Builds streaks automatically.",
                rot: -1.5,
                bg: "#e8917a",
              },
              {
                icon: "📿",
                title: "Dhikr Counter",
                desc: "Tap to count dhikr. Set daily goals. Feel the calm rhythm of remembrance.",
                rot: 1,
                bg: "#7a9e7e",
              },
              {
                icon: "💬",
                title: "Daily Quotes",
                desc: "Beautiful wisdom from the Quran and Sunnah every morning. Save your favorites.",
                rot: -0.8,
                bg: "#c4985a",
              },
              {
                icon: "👫",
                title: "Friend Groups",
                desc: "Small private circles (3-7) where you support each other. See progress. Send gentle nudges.",
                rot: 1.5,
                bg: "#7a9e7e",
              },
              {
                icon: "✈️",
                title: "Works Offline",
                desc: "All data on your phone. No internet needed. Your habits go everywhere with you.",
                rot: -1.2,
                bg: "#e8917a",
              },
              {
                icon: "🌍",
                title: "Your Language",
                desc: "Full English, Russian, and Kazakh support. Every word, translated with care.",
                rot: 0.8,
                bg: "#c4985a",
              },
            ].map((card, i) => (
              <motion.div
                key={i}
                className="relative bg-white rounded-3xl p-6 shadow-sm border border-[#3d2c1e]/5 cursor-default"
                style={{ rotate: `${card.rot}deg` }}
                initial={{ opacity: 0, y: 30, rotate: card.rot * 2 }}
                whileInView={{ opacity: 1, y: 0, rotate: card.rot }}
                viewport={{ once: true, margin: "-40px" }}
                transition={{ ...springPop, delay: i * 0.06 }}
                whileHover={{ rotate: 0, y: -6, scale: 1.02 }}
              >
                <div
                  className="w-11 h-11 rounded-2xl flex items-center justify-center text-xl mb-4"
                  style={{ backgroundColor: `${card.bg}18` }}
                >
                  {card.icon}
                </div>
                <h3 className="font-bold text-base mb-1.5">{card.title}</h3>
                <p className="text-sm text-[#3d2c1e]/45 leading-relaxed">
                  {card.desc}
                </p>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      <WaveDivider flip color="#7a9e7e" />

      {/* ── HOW IT WORKS — 3 steps with curved path ── */}
      <section id="how" className="relative z-10 py-16 md:py-24 px-6">
        <div className="mx-auto max-w-4xl">
          <motion.div
            className="text-center mb-16"
            initial={{ opacity: 0 }}
            whileInView={{ opacity: 1 }}
            viewport={{ once: true }}
          >
            <span
              style={{ fontFamily: "'Caveat', cursive", fontWeight: 600 }}
              className="text-[#e8917a] text-lg"
            >
              Three simple steps
            </span>
            <h2
              className="text-3xl md:text-4xl mt-2"
              style={{ fontFamily: "'Fraunces', serif", fontWeight: 700 }}
            >
              How Sunnad works
            </h2>
          </motion.div>

          <div className="grid md:grid-cols-3 gap-12 md:gap-8 relative">
            {/* Connecting line (desktop only) */}
            <svg
              className="hidden md:block absolute top-16 left-[calc(16.67%+20px)] right-[calc(16.67%+20px)] h-2 overflow-visible"
              viewBox="0 0 100 10"
            >
              <path
                d="M0,5 C30,0 70,10 100,5"
                fill="none"
                stroke="#3d2c1e"
                strokeWidth="0.5"
                strokeDasharray="3,3"
                opacity="0.15"
              />
            </svg>

            {[
              {
                step: "1",
                title: "Choose your habits",
                desc: "Pick from templates or create your own. Set the days of the week. Choose your reminder time.",
              },
              {
                step: "2",
                title: "Show up daily",
                desc: "Open Sunnad each day. See what's due. Check things off. Watch your streak grow with each consistent day.",
              },
              {
                step: "3",
                title: "Grow together",
                desc: "Invite close friends to a group. See each other's streaks. Send a nudge when someone needs encouragement.",
              },
            ].map((s, i) => (
              <motion.div
                key={i}
                className="text-center"
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ ...springPop, delay: i * 0.15 }}
              >
                <div
                  className="w-14 h-14 rounded-full bg-[#e8917a] text-white text-xl font-bold flex items-center justify-center mx-auto mb-5 shadow-lg shadow-[#e8917a]/20"
                  style={{ fontFamily: "'Fraunces', serif" }}
                >
                  {s.step}
                </div>
                <h3 className="font-bold text-lg mb-2">{s.title}</h3>
                <p className="text-sm text-[#3d2c1e]/45 leading-relaxed max-w-xs mx-auto">
                  {s.desc}
                </p>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      <WaveDivider color="#e8917a" />

      {/* ── QUOTE ── */}
      <section className="relative z-10 py-12 md:py-16 px-6 bg-[#e8917a]/[0.04]">
        <motion.div
          className="mx-auto max-w-2xl text-center"
          initial={{ opacity: 0, y: 15 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
        >
          <blockquote
            className="text-2xl md:text-3xl leading-relaxed text-[#3d2c1e]/80"
            style={{
              fontFamily: "'Fraunces', serif",
              fontWeight: 400,
              fontStyle: "italic",
            }}
          >
            &ldquo;Verily, with hardship comes ease.&rdquo;
          </blockquote>
          <p
            className="mt-4 text-sm text-[#e8917a]"
            style={{ fontFamily: "'Caveat', cursive", fontWeight: 600 }}
          >
            — Quran 94:6
          </p>
        </motion.div>
      </section>

      <WaveDivider flip color="#e8917a" />

      {/* ── WAITLIST ── */}
      <section id="waitlist" className="relative z-10 py-16 md:py-24 px-6">
        <motion.div
          className="mx-auto max-w-md text-center"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: "-60px" }}
          transition={{ duration: 0.6 }}
        >
          <span
            style={{ fontFamily: "'Caveat', cursive", fontWeight: 600 }}
            className="text-[#e8917a] text-lg"
          >
            Coming soon to iOS
          </span>
          <h2
            className="text-3xl md:text-4xl mt-2 mb-4"
            style={{ fontFamily: "'Fraunces', serif", fontWeight: 700 }}
          >
            Join the family 🌿
          </h2>
          <p className="text-base text-[#3d2c1e]/45 mb-10 leading-relaxed">
            Be the first to try Sunnad when it launches. We&apos;ll send you one
            friendly email. That&apos;s it. Promise.
          </p>

          {result?.status === "subscribed" ||
          result?.status === "already_subscribed" ? (
            <motion.div
              className="bg-[#7a9e7e]/10 rounded-3xl p-8 border border-[#7a9e7e]/15"
              initial={{ scale: 0.95 }}
              animate={{ scale: 1 }}
              transition={springPop}
            >
              <div className="text-3xl mb-3">🌱</div>
              <p
                className="text-xl text-[#3d2c1e]"
                style={{ fontFamily: "'Fraunces', serif", fontWeight: 700 }}
              >
                {result.status === "subscribed"
                  ? "Welcome to the family!"
                  : "You're already in! 💚"}
              </p>
              <p className="mt-2 text-sm text-[#3d2c1e]/40">
                {result.status === "subscribed"
                  ? "Jazak Allah Khair. We'll reach out when Sunnad is ready."
                  : "We have your email. Sit tight — good things take time."}
              </p>
            </motion.div>
          ) : (
            <form onSubmit={handleSubmit} className="space-y-4">
              <input
                type="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="your@email.com"
                className="w-full bg-white border-2 border-[#3d2c1e]/8 rounded-full px-6 py-4 text-[#3d2c1e] placeholder:text-[#3d2c1e]/20 outline-none focus:border-[#e8917a]/40 transition-colors text-sm shadow-sm"
              />

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
                className="w-full py-4 rounded-full bg-[#e8917a] text-white font-semibold text-sm disabled:opacity-40 hover:bg-[#d4785e] transition-colors shadow-lg shadow-[#e8917a]/20"
              >
                {submitting ? "Joining…" : "Count Me In 🌱"}
              </button>

              {result?.status === "error" && (
                <p className="text-sm text-red-600/70">
                  {result.message || "Oops! Something went wrong."}
                </p>
              )}
              {result?.status === "rate_limited" && (
                <p className="text-sm text-amber-600/70">
                  Easy there — too many attempts. Try again in a bit.
                </p>
              )}
            </form>
          )}
        </motion.div>
      </section>

      {/* ── FOOTER ── */}
      <footer className="relative z-10 py-10 px-6 text-center">
        <div className="mx-auto max-w-6xl">
          <span
            className="text-xl text-[#3d2c1e]/20"
            style={{ fontFamily: "'Fraunces', serif", fontWeight: 700 }}
          >
            sunnad
          </span>
          <p className="text-xs text-[#3d2c1e]/25 mt-2 mb-4">
            Build better habits, together. 🤲
          </p>
          <div className="flex items-center justify-center gap-4 text-xs text-[#3d2c1e]/30">
            <Link
              href={`/${locale}/terms`}
              className="hover:text-[#3d2c1e]/50 transition-colors"
            >
              Terms
            </Link>
            <span>·</span>
            <Link
              href={`/${locale}/privacy`}
              className="hover:text-[#3d2c1e]/50 transition-colors"
            >
              Privacy
            </Link>
            <span>·</span>
            {locales.map((l, i) => (
              <span key={l.code}>
                {i > 0 && <span className="mr-1">·</span>}
                <Link
                  href={`/${l.code}/${variant}`}
                  className={`hover:text-[#3d2c1e]/50 transition-colors ${l.code === locale ? "text-[#e8917a]" : ""}`}
                >
                  {l.label}
                </Link>
              </span>
            ))}
          </div>
          <p className="text-[10px] text-[#3d2c1e]/15 mt-6">© 2026 Sunnad</p>
        </div>
      </footer>
    </div>
  );
}
