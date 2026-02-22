"use client";

import { useEffect, useRef, useState } from "react";
import { motion, useScroll, useTransform, AnimatePresence } from "framer-motion";
import Link from "next/link";
import { submitWaitlist } from "@/lib/waitlist-submit";
import { Turnstile } from "@/components/turnstile";
import { landingConfig } from "@/lib/config";

/* ── Content ── */
const copy = {
  hero: "Your sanctuary for daily habits.",
  sub: "A quiet space to focus on your deen. Without the noise of the modern web.",
  chapters: [
    { id: "today", text: "The day begins quietly.", sub: "Only what is due today. A clean, distraction-free checklist.", img: "/app-screenshots/en_today_dark.PNG" },
    { id: "dhikr", text: "Keep count, stay present.", sub: "Built-in seamlessly for your daily adhkar.", img: "/app-screenshots/en_dhikr_dark.PNG" },
    { id: "groups", text: "Walk the path together.", sub: "Private accountability with people you trust.", img: "/app-screenshots/en_groups_dark.PNG" },
  ]
};

/* ── Waitlist Counter & Form ── */
function PoeticCounter() {
  const [count, setCount] = useState(1342);
  useEffect(() => {
    const int = setInterval(() => { if(Math.random() > 0.5) setCount(c => c + 1) }, 6000);
    return () => clearInterval(int);
  }, []);
  return (
    <div className="text-xs uppercase tracking-widest text-white/40 mb-8 font-sans">
      <span className="text-white/80">{count.toLocaleString()}</span> souls seeking consistency
    </div>
  );
}

function PoeticWaitlistForm({ locale }: { locale: string }) {
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<"idle"|"loading"|"success"|"error">("idle");
  const [token, setToken] = useState<string|null>(null);
  const hasTurnstile = Boolean(landingConfig.turnstileSiteKey);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!email || status === "loading") return;
    setStatus("loading");
    const res = await submitWaitlist({ email, turnstileToken: token || "demo", locale, variant: "11" });
    setStatus(res.status === "subscribed" || res.status === "already_subscribed" ? "success" : "error");
  }

  return (
    <div className="w-full max-w-md mx-auto flex flex-col items-center">
      <PoeticCounter />

      {status === "success" ? (
         <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="text-white/80 italic text-xl">
           "Peace be upon you. You have joined the sanctuary."
         </motion.div>
      ) : (
        <form onSubmit={onSubmit} className="flex flex-col gap-6 w-full items-center">
          <input
            type="email" required value={email} onChange={e => setEmail(e.target.value)}
            placeholder="Your email address"
            className="w-full bg-transparent border-b border-white/20 px-4 py-3 text-center text-white placeholder:text-white/20 focus:outline-none focus:border-white/60 transition-colors font-sans text-lg"
          />
          {hasTurnstile && <Turnstile siteKey={landingConfig.turnstileSiteKey} onToken={setToken} theme="dark" />}
          <button type="submit" disabled={status === "loading" || (hasTurnstile && !token)} className="uppercase tracking-[0.3em] text-xs px-10 py-4 border border-white/20 text-white/60 hover:text-white hover:border-white/60 transition-all font-sans">
            {status === "loading" ? "Entering..." : "Request Access"}
          </button>
        </form>
      )}
    </div>
  );
}

/* ── Main Page ── */
export default function V11Page({ locale }: { locale: string }) {
  const containerRef = useRef<HTMLDivElement>(null);
  const { scrollYProgress } = useScroll({ target: containerRef, offset: ["start start", "end end"] });

  const [activeChapter, setActiveChapter] = useState(0);

  useEffect(() => {
    return scrollYProgress.on("change", (v) => {
      const idx = Math.min(Math.floor(v * copy.chapters.length), copy.chapters.length - 1);
      setActiveChapter(Math.max(0, idx));
    });
  }, [scrollYProgress]);

  return (
    <div className="bg-[#020202] text-[#E5E5E5] min-h-screen selection:bg-white/20 selection:text-white" style={{ fontFamily: "'Cormorant Garamond', serif" }}>

      {/* Subtle Grain / Noise Overlay */}
      <div className="pointer-events-none fixed inset-0 z-50 opacity-[0.03]" style={{ backgroundImage: "url('https://upload.wikimedia.org/wikipedia/commons/7/76/1k_Dissolve_Noise_Texture.png')" }} />

      {/* Navigation */}
      <header className="fixed top-0 w-full z-40 p-8 flex justify-between items-center mix-blend-difference font-sans">
        <span className="uppercase tracking-[0.4em] text-xs text-white/50">Sunnad</span>
        <Link href={`/${locale}`} className="uppercase tracking-[0.2em] text-[10px] text-white/30 hover:text-white transition-colors">Return</Link>
      </header>

      {/* Hero */}
      <section className="relative h-screen flex flex-col items-center justify-center px-4 overflow-hidden">
        {/* Ethereal Glow */}
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-full h-[600px] bg-gradient-to-b from-white/[0.04] to-transparent blur-[120px] pointer-events-none rounded-full" />

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
          initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ duration: 2, delay: 1.5 }}
        >
          <div className="absolute inset-0 bg-white/[0.02] blur-xl rounded-full" />
          <PoeticWaitlistForm locale={locale} />
        </motion.div>

        <motion.div
          className="absolute bottom-12 flex flex-col items-center gap-4 text-white/20"
          initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 3, duration: 2 }}
        >
          <div className="w-[1px] h-16 bg-gradient-to-b from-white/20 to-transparent" />
          <span className="uppercase tracking-widest text-[9px] font-sans">Descend</span>
        </motion.div>
      </section>

      {/* Cinematic Scroll */}
      <section ref={containerRef} className="relative h-[400vh] bg-[#020202]">
        <div className="sticky top-0 h-screen flex items-center justify-center overflow-hidden">

          {/* Background Ambient Shift */}
          <AnimatePresence>
             <motion.div
               key={activeChapter}
               initial={{ opacity: 0 }}
               animate={{ opacity: 0.15 }}
               exit={{ opacity: 0 }}
               transition={{ duration: 1.5 }}
               className="absolute inset-0 bg-[radial-gradient(circle_at_center,rgba(255,255,255,0.8)_0%,transparent_50%)] pointer-events-none blur-[150px]"
             />
          </AnimatePresence>

          <div className="relative w-full max-w-7xl mx-auto px-6 grid grid-cols-1 lg:grid-cols-2 lg:gap-20 items-center">

            {/* The Text Poetics */}
            <div className="order-2 lg:order-1 flex flex-col justify-center items-center lg:items-start text-center lg:text-left h-[40vh] lg:h-auto z-20">
              <AnimatePresence mode="wait">
                <motion.div
                  key={activeChapter}
                  initial={{ opacity: 0, y: 30, filter: "blur(12px)" }}
                  animate={{ opacity: 1, y: 0, filter: "blur(0px)" }}
                  exit={{ opacity: 0, y: -30, filter: "blur(12px)" }}
                  transition={{ duration: 1, ease: [0.2, 0.65, 0.3, 0.9] }}
                >
                  <h2 className="text-5xl md:text-6xl lg:text-7xl mb-6 font-medium leading-[1.1] text-white/90">
                    {copy.chapters[activeChapter].text}
                  </h2>
                  <p className="text-xl md:text-2xl text-white/40 italic font-light">
                    {copy.chapters[activeChapter].sub}
                  </p>
                </motion.div>
              </AnimatePresence>
            </div>

            {/* The Floating Artefact (Phone) */}
            <div className="order-1 lg:order-2 flex justify-center z-20 relative lg:-top-10">
              <div className="relative w-[280px] h-[582px] md:w-[320px] md:h-[654px] rounded-[40px]">

                {/* Image Container */}
                <div className="absolute inset-[14px] rounded-[36px] overflow-hidden bg-black z-10 shadow-[0_0_80px_rgba(0,0,0,1)]">
                  <AnimatePresence mode="wait">
                    <motion.img
                      key={activeChapter}
                      src={copy.chapters[activeChapter].img}
                      initial={{ opacity: 0, filter: "brightness(0.5) contrast(1.2)" }}
                      animate={{ opacity: 1, filter: "brightness(1) contrast(1)" }}
                      exit={{ opacity: 0 }}
                      transition={{ duration: 1.2 }}
                      className="absolute inset-0 w-full h-full object-cover"
                    />
                  </AnimatePresence>
                </div>

                {/* Bezel Overlay */}
                <img
                   src="/app-screenshots/iphone_bezels_16_pro.png"
                   className="absolute inset-0 w-full h-full object-contain pointer-events-none z-20 mix-blend-screen opacity-40"
                   alt=""
                />

                {/* Deep Shadowing to make it blend into darkness */}
                <div className="absolute inset-0 z-30 pointer-events-none rounded-[40px] shadow-[inset_0_0_100px_rgba(0,0,0,0.8)]" />
              </div>
            </div>

          </div>
        </div>
      </section>

      {/* Footer Finale */}
      <section className="relative min-h-[80vh] flex flex-col items-center justify-center px-6">
        <div className="absolute inset-0 bg-gradient-to-t from-[rgba(20,20,20,0.5)] to-transparent pointer-events-none" />

        <h2 className="text-5xl md:text-7xl font-light mb-16 text-center z-10 text-white/90">
          The end of noise.
        </h2>

        <div className="w-full relative z-10">
          <PoeticWaitlistForm locale={locale} />
        </div>

        <footer className="absolute bottom-10 flex gap-12 font-sans uppercase tracking-[0.2em] text-[10px] text-white/30">
          <Link href={`/${locale}/terms`} className="hover:text-white transition-colors">Terms</Link>
          <Link href={`/${locale}/privacy`} className="hover:text-white transition-colors">Privacy</Link>
        </footer>
      </section>

    </div>
  );
}
