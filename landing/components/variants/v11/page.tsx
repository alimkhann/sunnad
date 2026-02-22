"use client";

import { useEffect, useRef, useState } from "react";
import { motion, useScroll, AnimatePresence } from "framer-motion";
import Link from "next/link";
import { submitWaitlist } from "@/lib/waitlist-submit";
import { Turnstile } from "@/components/turnstile";
import { landingConfig } from "@/lib/config";

/* ── Content ── */
const copy = {
  hero: "Your sanctuary for daily habits.",
  sub: "A quiet space to focus on your deen. Without the noise of the modern web.",
  chapters: [
    {
      id: "today",
      text: "The day begins quietly.",
      sub: "Only what is due today. A clean, distraction-free checklist.",
      img: "/app-screenshots/en_today_dark.PNG",
    },
    {
      id: "dhikr",
      text: "Keep count, stay present.",
      sub: "Built-in seamlessly for your daily adhkar.",
      img: "/app-screenshots/en_dhikr_dark.PNG",
    },
    {
      id: "groups",
      text: "Walk the path together.",
      sub: "Private accountability with people you trust.",
      img: "/app-screenshots/en_groups_dark.PNG",
    },
    {
      id: "analytics",
      text: "See your progress.",
      sub: "Gentle insights to keep your momentum without guilt.",
      img: "/app-screenshots/en_analytics_dark.PNG",
    },
  ],
};

/* ── Waitlist Counter & Form ── */
function PoeticCounter() {
  const [count, setCount] = useState(1342);
  useEffect(() => {
    const int = setInterval(() => {
      if (Math.random() > 0.5) setCount((c) => c + 1);
    }, 6000);
    return () => clearInterval(int);
  }, []);
  return (
    <div className="text-xs uppercase tracking-widest text-white/40 mb-8 font-sans">
      <span className="text-white/80">{count.toLocaleString()}</span> souls
      seeking consistency
    </div>
  );
}

function PoeticWaitlistForm({ locale }: { locale: string }) {
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<
    "idle" | "loading" | "success" | "error"
  >("idle");
  const [token, setToken] = useState<string | null>(null);
  const hasTurnstile = Boolean(landingConfig.turnstileSiteKey);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!email || status === "loading") return;
    setStatus("loading");
    const res = await submitWaitlist({
      email,
      turnstileToken: token || "demo",
      locale,
      variant: "11",
    });
    setStatus(
      res.status === "subscribed" || res.status === "already_subscribed"
        ? "success"
        : "error",
    );
  }

  return (
    <div className="w-full max-w-sm mx-auto flex flex-col items-center gap-4">
      <PoeticCounter />
      {status === "success" ? (
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          className="bg-[#181818] text-[#00ffbb] p-4 rounded-2xl text-center text-base font-medium tracking-wide border border-[#00ffbb]/20 shadow-lg shadow-[#00ffbb]/5"
        >
          You have joined the sanctuary.
        </motion.div>
      ) : (
        <form onSubmit={onSubmit} className="flex flex-col gap-3 w-full">
          <input
            type="email"
            required
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="Email address"
            className="w-full bg-[#181818] border-none px-5 py-4 rounded-xl text-white placeholder:text-white/40 focus:outline-none focus:ring-2 focus:ring-white transition-all shadow-inner text-base"
          />
          {hasTurnstile && (
            <div className="rounded-xl overflow-hidden">
              <Turnstile
                siteKey={landingConfig.turnstileSiteKey}
                onToken={setToken}
                theme="dark"
              />
            </div>
          )}
          <button
            type="submit"
            disabled={status === "loading" || (hasTurnstile && !token)}
            className="bg-[#FAFAFA] text-[#181818] font-semibold py-4 rounded-xl shadow-md shadow-black/10 transition-all disabled:opacity-50 text-base tracking-wide hover:shadow-lg hover:shadow-black/20 hover:opacity-90"
          >
            {status === "loading" ? "Joining..." : "Join Waitlist"}
          </button>
        </form>
      )}
    </div>
  );
}

/* ── Main Page ── */
export default function V11Page({ locale }: { locale: string }) {
  const containerRef = useRef<HTMLDivElement>(null);
  const { scrollYProgress } = useScroll({
    target: containerRef,
    offset: ["start start", "end end"],
  });

  const [activeChapter, setActiveChapter] = useState(0);

  useEffect(() => {
    return scrollYProgress.on("change", (v) => {
      const idx = Math.min(
        Math.floor(v * copy.chapters.length),
        copy.chapters.length - 1,
      );
      setActiveChapter(Math.max(0, idx));
    });
  }, [scrollYProgress]);

  return (
    <div
      className="bg-[#020202] text-[#E5E5E5] min-h-screen selection:bg-white/20 selection:text-white relative"
      style={{ fontFamily: "'Cormorant Garamond', serif" }}
    >
      {/* Navigation */}
      <header className="fixed top-0 w-full z-40 p-6 md:p-8 flex justify-between items-center mix-blend-difference font-sans">
        <span className="uppercase tracking-[0.4em] text-[10px] md:text-xs text-white/50">
          Sunnad
        </span>
        <Link
          href={`/${locale}`}
          className="uppercase tracking-[0.2em] text-[8px] md:text-[10px] text-white/30 hover:text-white transition-colors"
        >
          Return
        </Link>
      </header>

      {/* Hero */}
      <section className="relative h-screen flex flex-col items-center justify-center px-4 overflow-hidden">
        {/* Ethereal Glow */}
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-full h-[600px] blur-[120px] pointer-events-none rounded-full" />

        <motion.h1
          className="text-6xl md:text-8xl lg:text-9xl font-light tracking-tight text-center leading-none z-10"
          initial={{ opacity: 0, filter: "blur(20px)", y: 20 }}
          animate={{ opacity: 1, filter: "blur(0px)", y: 0 }}
          transition={{ duration: 2, ease: "easeOut" }}
        >
          {copy.hero}
        </motion.h1>
        <motion.p
          className="mt-8 text-xl md:text-2xl text-white/40 italic text-center max-w-2xl z-10"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 2, delay: 1 }}
        >
          {copy.sub}
        </motion.p>

        <motion.div
          className="mt-20 w-full max-w-lg z-10 relative"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 2, delay: 1.5 }}
        >
          <div className="absolute inset-0 rounded-full" />
          <PoeticWaitlistForm locale={locale} />
        </motion.div>

        {/* Removed Descend and vertical bar for a cleaner hero */}
      </section>

      {/* Cinematic Scroll */}
      <section ref={containerRef} className="relative h-[400vh] bg-[#020202]">
        <div className="sticky top-0 h-screen flex items-center justify-center overflow-hidden">
          {/* Enhanced Layered Ambient Background */}
          <div className="absolute inset-0 z-0 pointer-events-none">
            {/* Soft radial glow center */}
            <motion.div
              key={`glow-${activeChapter}`}
              initial={{ opacity: 0 }}
              animate={{ opacity: 0.18 }}
              exit={{ opacity: 0 }}
              transition={{ duration: 1.5 }}
              className="absolute inset-0 bg-[radial-gradient(circle_at_center,rgba(0,255,187,0.10)_0%,transparent_60%)] blur-[120px]"
            />
            {/* Subtle white radial */}
            <motion.div
              key={`white-${activeChapter}`}
              initial={{ opacity: 0 }}
              animate={{ opacity: 0.1 }}
              exit={{ opacity: 0 }}
              transition={{ duration: 1.5, delay: 0.2 }}
              className="absolute inset-0 bg-[radial-gradient(circle_at_60%_40%,rgba(255,255,255,0.12)_0%,transparent_70%)] blur-[160px]"
            />
            {/* Faint vignette edges */}
            <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_center,transparent_60%,#000_100%)] opacity-60" />
          </div>

          <div className="relative w-full max-w-7xl mx-auto px-6 grid grid-cols-1 lg:grid-cols-2 lg:gap-20 items-center">
            {/* The Text Poetics */}
            <div className="order-2 lg:order-1 flex flex-col justify-center items-center lg:items-start text-center lg:text-left h-[30vh] lg:h-auto z-20">
              <AnimatePresence mode="wait">
                <motion.div
                  key={activeChapter}
                  initial={{ opacity: 0, y: 30, filter: "blur(12px)" }}
                  animate={{ opacity: 1, y: 0, filter: "blur(0px)" }}
                  exit={{ opacity: 0, y: -30, filter: "blur(12px)" }}
                  transition={{ duration: 1, ease: [0.2, 0.65, 0.3, 0.9] }}
                >
                  <h2 className="text-4xl md:text-5xl lg:text-7xl mb-4 md:mb-6 font-medium leading-[1.1] text-white/90">
                    {copy.chapters[activeChapter].text}
                  </h2>
                  <p className="text-lg md:text-2xl text-white/40 italic font-light">
                    {copy.chapters[activeChapter].sub}
                  </p>
                </motion.div>
              </AnimatePresence>
            </div>

            {/* The Floating Artefact (Phone) */}
            <div className="order-1 lg:order-2 flex justify-center z-20 relative lg:-top-10 mb-8 lg:mb-0 mt-20 lg:mt-0">
              <div className="relative w-[280px] h-[582px] md:w-[320px] md:h-[654px] rounded-[40px]">
                {/* Background ambient light matching screen content */}
                <AnimatePresence mode="wait">
                  <motion.div
                     key={activeChapter}
                     initial={{ opacity: 0 }}
                     animate={{ opacity: 1 }}
                     exit={{ opacity: 0 }}
                     transition={{ duration: 1.5 }}
                     className="absolute inset-0 bg-white/5 blur-[100px] rounded-full z-0"
                  />
                </AnimatePresence>

                {/* Image Container (screenshots) */}
                <div className="absolute inset-[13px] md:inset-[15px] rounded-[34px] md:rounded-[42px] overflow-hidden bg-black z-10 shadow-[0_0_80px_rgba(0,0,0,0.6)]">
                  <AnimatePresence mode="wait">
                    <motion.img
                      key={activeChapter}
                      src={copy.chapters[activeChapter].img}
                      initial={{
                        opacity: 0,
                        filter: "brightness(0.5) contrast(1.2)",
                      }}
                      animate={{
                        opacity: 1,
                        filter: "brightness(1) contrast(1)",
                      }}
                      exit={{ opacity: 0 }}
                      transition={{ duration: 1.2 }}
                      className="absolute inset-0 w-full h-full object-cover z-10"
                    />
                  </AnimatePresence>
                </div>

                {/* Bezel Overlay (always above screenshot) */}
                <img
                  src="/app-screenshots/iphone_bezels_16_pro.png"
                  className="absolute inset-0 w-full h-full object-contain pointer-events-none z-30 mix-blend-screen opacity-40"
                  alt=""
                />
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Footer Finale */}
      <section className="relative min-h-[80vh] flex flex-col items-center justify-center px-6">
        <div className="absolute inset-0 pointer-events-none" />

        <h2 className="text-5xl md:text-7xl font-light mb-16 text-center z-10 text-white/90">
          The end of noise.
        </h2>

        <div className="w-full relative z-10">
          <PoeticWaitlistForm locale={locale} />
        </div>

        <footer className="absolute bottom-10 flex gap-12 font-sans uppercase tracking-[0.2em] text-[10px] text-white/30">
          <Link
            href={`/${locale}/terms`}
            className="hover:text-white transition-colors"
          >
            Terms
          </Link>
          <Link
            href={`/${locale}/privacy`}
            className="hover:text-white transition-colors"
          >
            Privacy
          </Link>
        </footer>
      </section>
    </div>
  );
}
