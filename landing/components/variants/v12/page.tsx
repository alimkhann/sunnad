"use client";

import { useState, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import Link from "next/link";
import { submitWaitlist } from "@/lib/waitlist-submit";
import { Turnstile } from "@/components/turnstile";
import { landingConfig } from "@/lib/config";

function DigitalCounter() {
  const [count, setCount] = useState(1342);
  useEffect(() => {
    const int = setInterval(() => { if(Math.random() > 0.5) setCount(c => c + 1) }, 3000);
    return () => clearInterval(int);
  }, []);
  return (
    <div className="flex items-center gap-3 text-cyan-400 font-mono text-xs uppercase tracking-widest mb-6">
      <span className="relative flex h-2 w-2">
        <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-cyan-400 opacity-75"></span>
        <span className="relative inline-flex rounded-full h-2 w-2 bg-cyan-500"></span>
      </span>
      {count.toLocaleString()} ACTIVE USERS RESERVED
    </div>
  );
}

function TerminalWaitlist({ locale }: { locale: string }) {
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<"idle"|"loading"|"success"|"error">("idle");
  const [token, setToken] = useState<string|null>(null);
  const hasTurnstile = Boolean(landingConfig.turnstileSiteKey);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!email || status === "loading") return;
    setStatus("loading");
    const res = await submitWaitlist({ email, turnstileToken: token || "demo", locale, variant: "12" });
    setStatus(res.status === "subscribed" || res.status === "already_subscribed" ? "success" : "error");
  }

  return (
    <div className="w-full max-w-sm">
      <DigitalCounter />

      {status === "success" ? (
         <div className="border border-cyan-500/30 bg-cyan-500/10 text-cyan-400 p-4 font-mono text-sm uppercase">
           [ACCESS GRANTED] You are in the queue.
         </div>
      ) : (
        <form onSubmit={onSubmit} className="flex flex-col gap-4">
          <div className="relative">
            <span className="absolute left-4 top-1/2 -translate-y-1/2 text-cyan-500/50 font-mono">{">"}</span>
            <input
              type="email" required value={email} onChange={e => setEmail(e.target.value)}
              placeholder="INITIALIZE_EMAIL"
              className="w-full bg-[#050B14] border border-cyan-900/50 pl-10 pr-4 py-3 text-cyan-50 placeholder:text-cyan-900 focus:outline-none focus:border-cyan-400 transition-colors font-mono text-sm"
            />
          </div>
          {hasTurnstile && <Turnstile siteKey={landingConfig.turnstileSiteKey} onToken={setToken} theme="dark" />}
          <button type="submit" disabled={status === "loading" || (hasTurnstile && !token)} className="bg-cyan-500 text-[#050B14] font-bold uppercase tracking-widest text-xs py-3 hover:bg-cyan-400 transition-colors font-mono group relative overflow-hidden">
            <span className="relative z-10">{status === "loading" ? "PROCESSING..." : "ACTIVATE"}</span>
            <div className="absolute inset-0 bg-white/20 -translate-x-full group-hover:translate-x-full transition-transform duration-500 skew-x-12" />
          </button>
        </form>
      )}
    </div>
  );
}

const floatingCards = [
  { id: 1, top: "10%", left: "-15%", delay: 0, title: "DHIKR_SYNC", val: "100%", color: "text-emerald-400", border: "border-emerald-500/20", glow: "shadow-[0_0_15px_rgba(52,211,153,0.1)]" },
  { id: 2, top: "40%", right: "-20%", delay: 1, title: "STREAK", val: "14_DAYS", color: "text-amber-400", border: "border-amber-500/20",  glow: "shadow-[0_0_15px_rgba(251,191,36,0.1)]" },
  { id: 3, bottom: "20%", left: "-10%", delay: 0.5,title: "GROUP_PING", val: "ACTIVE", color: "text-indigo-400", border: "border-indigo-500/20", glow: "shadow-[0_0_15px_rgba(99,102,241,0.1)]" },
];

export default function V12Page({ locale }: { locale: string }) {
  const [activeScreen, setActiveScreen] = useState(0);
  const screens = ["today", "dhikr", "groups", "analytics"];

  useEffect(() => {
    const int = setInterval(() => {
      setActiveScreen(s => (s + 1) % screens.length);
    }, 4000);
    return () => clearInterval(int);
  }, []);

  return (
    <div className="bg-[#03060C] text-slate-200 min-h-screen selection:bg-cyan-500/30 selection:text-cyan-50 font-sans overflow-hidden">

      {/* Grid Background */}
      <div className="fixed inset-0 pointer-events-none opacity-[0.03]" style={{ backgroundImage: "linear-gradient(#00f 1px, transparent 1px), linear-gradient(90deg, #00f 1px, transparent 1px)", backgroundSize: "40px 40px" }} />
      {/* Glare effects */}
      <div className="fixed top-[-10%] left-[-10%] w-[500px] h-[500px] bg-cyan-600/20 blur-[150px] rounded-full pointer-events-none" />
      <div className="fixed bottom-[-10%] right-[-10%] w-[400px] h-[400px] bg-indigo-600/20 blur-[150px] rounded-full pointer-events-none" />

      {/* Nav */}
      <header className="absolute top-0 w-full z-40 p-6 flex justify-between items-center text-xs font-mono text-cyan-600 uppercase tracking-widest">
        <span>[SYS.SUNNAD]</span>
        <Link href={`/${locale}`} className="hover:text-cyan-400 transition-colors">[RETURN_TO_BASE]</Link>
      </header>

      {/* Main Orchestration Hero */}
      <main className="relative min-h-screen flex flex-col xl:flex-row items-center justify-center p-6 xl:p-20 gap-20">

        {/* Left: Command Console (Text & Form) */}
        <div className="relative z-10 max-w-lg w-full mt-20 xl:mt-0 xl:flex-1">
          <motion.div initial={{ opacity: 0, x: -30 }} animate={{ opacity: 1, x: 0 }} transition={{ duration: 1 }}>
            <div className="inline-block border border-cyan-800 bg-cyan-950/30 text-cyan-400 px-3 py-1 font-mono text-[10px] tracking-widest mb-6 uppercase">
              // Offline-First Logic Core
            </div>
            <h1 className="text-5xl md:text-7xl font-bold tracking-tighter text-white mb-6 leading-[1.1]">
              Engineered for <br/>
              <span className="text-transparent bg-clip-text bg-gradient-to-r from-cyan-400 to-indigo-500">
                Consistency.
              </span>
            </h1>
            <p className="text-slate-400 text-lg md:text-xl mb-12 font-light max-w-md">
              A high-precision habit tracker for your daily deen. Remove the noise and execute your routines.
            </p>

            <div className="bg-[#050A14] border border-slate-800 p-6 shadow-2xl relative">
              {/* Corner Accents */}
              <div className="absolute top-0 left-0 w-2 h-2 border-t-2 border-l-2 border-cyan-500" />
              <div className="absolute top-0 right-0 w-2 h-2 border-t-2 border-r-2 border-cyan-500" />
              <div className="absolute bottom-0 left-0 w-2 h-2 border-b-2 border-l-2 border-cyan-500" />
              <div className="absolute bottom-0 right-0 w-2 h-2 border-b-2 border-r-2 border-cyan-500" />

              <TerminalWaitlist locale={locale} />
            </div>
          </motion.div>
        </div>

        {/* Right: Orbiting Asymmetric Phone Setup */}
        <div className="relative z-10 w-full max-w-md xl:flex-1 flex justify-center items-center h-[700px]">

          <div className="relative w-[280px] h-[572px] md:w-[320px] md:h-[654px]">
            {/* The Phone */}
            <motion.div
               animate={{ y: [-10, 10, -10] }}
               transition={{ duration: 6, repeat: Infinity, ease: "easeInOut" }}
               className="relative w-full h-full rounded-[40px] shadow-[0_0_80px_rgba(6,182,212,0.15)] z-20"
            >
              <div className="absolute inset-[14px] rounded-[36px] overflow-hidden bg-black z-10">
                <AnimatePresence mode="wait">
                  <motion.img
                    key={activeScreen}
                    src={`/app-screenshots/en_${screens[activeScreen]}_dark.PNG`}
                    initial={{ opacity: 0, scale: 1.1 }}
                    animate={{ opacity: 1, scale: 1 }}
                    exit={{ opacity: 0 }}
                    transition={{ duration: 0.5 }}
                    className="absolute inset-0 w-full h-full object-cover"
                  />
                </AnimatePresence>
              </div>
              <img
                 src="/app-screenshots/iphone_bezels_16_pro.png"
                 className="absolute inset-0 w-full h-full object-contain pointer-events-none z-20"
                 alt=""
              />
            </motion.div>

            {/* Orbiting Cards */}
            {floatingCards.map((card) => (
              <motion.div
                key={card.id}
                animate={{ y: [-15, 15, -15], x: [-5, 5, -5] }}
                transition={{ duration: 5 + card.id, repeat: Infinity, ease: "easeInOut", delay: card.delay }}
                className={`absolute z-30 bg-[#0A101C]/90 backdrop-blur-md border ${card.border} ${card.glow} p-4 hidden md:block`}
                style={{ top: card.top, left: card.left, right: card.right, bottom: card.bottom }}
              >
                <div className="font-mono text-[10px] text-slate-500 mb-1 leading-none">{card.title}</div>
                <div className={`font-mono text-lg font-bold ${card.color}`}>{card.val}</div>
              </motion.div>
            ))}

            {/* Rendered Rings behind phone */}
            <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[400px] h-[400px] border border-cyan-500/10 rounded-full z-0" />
            <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[550px] h-[550px] border border-indigo-500/10 rounded-full z-0" />
            <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[700px] h-[700px] border border-slate-500/10 rounded-full z-0 border-dashed" />

          </div>
        </div>
      </main>

      {/* Footer Block */}
      <footer className="relative z-10 border-t border-slate-800/50 bg-[#02040A] py-12 px-6">
        <div className="max-w-4xl mx-auto flex flex-col items-center">
          <TerminalWaitlist locale={locale} />
          <div className="flex gap-6 mt-12 font-mono text-[10px] text-slate-600 uppercase tracking-widest">
            <Link href={`/${locale}/terms`} className="hover:text-cyan-400 transition-colors">Legal_Terms</Link>
            <Link href={`/${locale}/privacy`} className="hover:text-cyan-400 transition-colors">Privacy_Def</Link>
          </div>
        </div>
      </footer>
    </div>
  );
}
