"use client";

import { useState, useRef, useEffect } from "react";
import { motion, useScroll, AnimatePresence } from "framer-motion";
import Link from "next/link";
import { submitWaitlist } from "@/lib/waitlist-submit";
import { Turnstile } from "@/components/turnstile";
import { landingConfig } from "@/lib/config";

// --- Form ---
function StoryWaitlist({ locale }: { locale: string }) {
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<"idle"|"loading"|"success"|"error">("idle");
  const [token, setToken] = useState<string|null>(null);
  const hasTurnstile = Boolean(landingConfig.turnstileSiteKey);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!email || status === "loading") return;
    setStatus("loading");
    const res = await submitWaitlist({ email, turnstileToken: token || "demo", locale, variant: "15" });
    setStatus(res.status === "subscribed" || res.status === "already_subscribed" ? "success" : "error");
  }

  return (
    <div className="w-full max-w-sm mx-auto">
      {status === "success" ? (
         <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} className="text-purple-300 font-serif italic text-xl text-center">
           Your journey has been recorded in the stars.
         </motion.div>
      ) : (
        <form onSubmit={onSubmit} className="flex flex-col gap-4">
          <input
            type="email" required value={email} onChange={e => setEmail(e.target.value)}
            placeholder="Whisper your email..."
            className="w-full bg-white/5 border border-white/20 px-6 py-4 rounded-full text-white placeholder:text-white/40 focus:outline-none focus:border-purple-400 focus:bg-white/10 transition-all font-sans"
          />
          {hasTurnstile && <div className="rounded-2xl overflow-hidden flex justify-center"><Turnstile siteKey={landingConfig.turnstileSiteKey} onToken={setToken} theme="dark" /></div>}
          <button type="submit" disabled={status === "loading" || (hasTurnstile && !token)} className="bg-gradient-to-r from-purple-500 to-indigo-600 text-white font-semibold py-4 rounded-full hover:opacity-90 transition-opacity disabled:opacity-50 font-sans tracking-wide shadow-[0_0_20px_rgba(168,85,247,0.3)]">
            {status === "loading" ? "Entering the veil..." : "Awaken"}
          </button>
        </form>
      )}
    </div>
  );
}

// --- Content ---
const story = [
  { id: "chapter-1", title: "Never forget your dreams.", text: "When the day starts, the noise of the world tries to bury what matters. Sunnad clears the fog.", image: "/app-screenshots/en_today_dark.PNG" },
  { id: "chapter-2", title: "A quiet heartbeat in the digital space.", text: "Keep count of your dhikr. No gamification, no loud notifications. Just you and your remembrance.", image: "/app-screenshots/en_dhikr_dark.PNG" },
  { id: "chapter-3", title: "Constellations of trust.", text: "Connect only with those who matter. Small groups to keep the light burning together.", image: "/app-screenshots/en_groups_dark.PNG" },
];

export default function V15Page({ locale }: { locale: string }) {
  const [activeStory, setActiveStory] = useState(0);

  const containerRef = useRef<HTMLDivElement>(null);
  const { scrollYProgress } = useScroll({ target: containerRef, offset: ["start start", "end end"] });

  useEffect(() => {
    return scrollYProgress.on("change", (v) => {
      const idx = Math.min(Math.floor(v * story.length), story.length - 1);
      setActiveStory(Math.max(0, idx));
    });
  }, [scrollYProgress]);

  return (
    <div className="bg-[#0A0C14] text-[#F3F4F6] min-h-screen selection:bg-purple-900/50 selection:text-white" style={{ fontFamily: "'Playfair Display', serif" }}>

      {/* Night Sky Background */}
      <div className="fixed inset-0 pointer-events-none z-0">
        <div className="absolute inset-0 bg-[#0A0C14]" />
        {/* Synthetic Stars using CSS background */}
        <div className="absolute inset-0 opacity-40 mix-blend-screen" style={{ backgroundImage: "radial-gradient(1px 1px at 10% 10%, #fff, transparent), radial-gradient(1px 1px at 20% 30%, #fff, transparent), radial-gradient(1.5px 1.5px at 30% 60%, rgba(200,200,255,0.8), transparent), radial-gradient(2px 2px at 80% 80%, rgba(200,200,255,0.8), transparent), radial-gradient(1px 1px at 90% 40%, #fff, transparent), radial-gradient(1px 1px at 70% 20%, #fff, transparent)", backgroundSize: "300px 300px" }} />
        {/* Magical Nebula Glow */}
        <div className="absolute top-[-20%] left-[-10%] w-[800px] h-[800px] bg-purple-900/20 rounded-full blur-[150px]" />
        <div className="absolute bottom-[-10%] right-[-10%] w-[600px] h-[600px] bg-blue-900/20 rounded-full blur-[120px]" />
      </div>

      <header className="fixed w-full z-40 p-8 flex justify-between items-center font-sans">
        <div className="text-xl font-serif italic text-white/90 drop-shadow-md">Sunnad</div>
        <Link href={`/${locale}`} className="text-xs font-semibold tracking-widest uppercase text-white/50 hover:text-white transition-colors">Return</Link>
      </header>

      {/* Hero Opening */}
      <main className="relative z-10 min-h-screen flex flex-col items-center justify-center px-6 text-center">
        <motion.div initial={{ opacity: 0, y: 30 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 2, ease: "easeOut" }} className="w-full max-w-4xl flex flex-col items-center">
          <p className="text-purple-300 italic text-xl md:text-2xl mb-6 tracking-wide drop-shadow-lg">A story of consistency</p>
          <h1 className="text-5xl md:text-7xl lg:text-8xl font-medium leading-[1.1] mb-12 drop-shadow-2xl">
            In the dark, <br/> your habits are stars.
          </h1>

          <StoryWaitlist locale={locale} />
          <div className="mt-8 text-sm font-sans tracking-widest text-white/40 uppercase">1,342 Dreamers Awakened</div>
        </motion.div>

        <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 2, duration: 2 }} className="absolute bottom-16 flex flex-col items-center gap-4 text-white/30">
          <div className="text-[10px] font-sans tracking-[0.3em] uppercase">Scroll to Dream</div>
          <div className="w-[1px] h-20 bg-gradient-to-b from-white/30 to-transparent" />
        </motion.div>
      </main>

      {/* Narrative Scroll */}
      <section ref={containerRef} className="relative h-[300vh] z-10 bg-[#0A0C14]/50">
        <div className="sticky top-0 h-screen flex flex-col md:flex-row items-center justify-center px-6 gap-12 md:gap-24 overflow-hidden">

          {/* Left: Text Story */}
          <div className="w-full md:w-1/2 flex justify-center md:justify-end text-center md:text-left z-20">
             <AnimatePresence mode="wait">
               <motion.div
                  key={activeStory}
                  initial={{ opacity: 0, x: -30, filter: "blur(10px)" }}
                  animate={{ opacity: 1, x: 0, filter: "blur(0px)" }}
                  exit={{ opacity: 0, x: 30, filter: "blur(10px)" }}
                  transition={{ duration: 1, ease: "easeInOut" }}
                  className="max-w-md"
               >
                 <h2 className="text-4xl md:text-5xl font-medium mb-6 leading-tight drop-shadow-lg text-white">
                   {story[activeStory].title}
                 </h2>
                 <p className="text-lg md:text-xl text-purple-200/80 italic font-light leading-relaxed">
                   {story[activeStory].text}
                 </p>
               </motion.div>
             </AnimatePresence>
          </div>

          {/* Right: Phone Reveal via Hover / Scroll */}
          <div className="w-full md:w-1/2 flex justify-center md:justify-start z-20">
            <div className="relative group perspective-[1000px]">

              <div className="relative w-[280px] h-[582px] md:w-[320px] md:h-[654px] transition-transform duration-1000 group-hover:rotate-y-12 group-hover:-rotate-x-12 transform-gpu">
                <div className="absolute inset-[14px] rounded-[36px] overflow-hidden bg-black z-10 shadow-[0_0_60px_rgba(168,85,247,0.4)]">
                  <AnimatePresence mode="wait">
                    <motion.img
                      key={activeStory}
                      src={story[activeStory].image}
                      initial={{ opacity: 0, scale: 1.1, filter: "brightness(0.2) contrast(1.5)" }}
                      animate={{ opacity: 1, scale: 1, filter: "brightness(1) contrast(1)" }}
                      exit={{ opacity: 0, scale: 0.9, filter: "brightness(0.2) contrast(0.8)" }}
                      transition={{ duration: 1.2, ease: "easeOut" }}
                      className="absolute inset-0 w-full h-full object-cover mix-blend-lighten"
                    />
                  </AnimatePresence>
                </div>

                <img
                   src="/app-screenshots/iphone_bezels_16_pro.png"
                   className="absolute inset-0 w-full h-full object-contain pointer-events-none z-20 mix-blend-screen opacity-50 drop-shadow-2xl"
                   alt=""
                />
              </div>

            </div>
          </div>

        </div>
      </section>

      {/* Epilogue */}
      <section className="relative min-h-screen flex flex-col items-center justify-center px-6 z-10 text-center pb-20">
        <h2 className="text-5xl md:text-7xl font-medium mb-8 drop-shadow-2xl text-white">
          Morning comes.
        </h2>
        <p className="text-xl md:text-2xl text-purple-300/80 mb-16 italic font-light max-w-2xl">
          We invite you to experience the clarity.
        </p>
        <StoryWaitlist locale={locale} />

        <footer className="mt-32 flex gap-10 font-sans tracking-[0.2em] text-[10px] uppercase text-white/30">
          <Link href={`/${locale}/terms`} className="hover:text-white transition-colors">Terms of Magic</Link>
          <Link href={`/${locale}/privacy`} className="hover:text-white transition-colors">Privacy</Link>
        </footer>
      </section>

    </div>
  );
}
