"use client";

import { useState, useRef, useEffect } from "react";
import { motion, useScroll, useTransform } from "framer-motion";
import Link from "next/link";
import { submitWaitlist } from "@/lib/waitlist-submit";
import { Turnstile } from "@/components/turnstile";
import { landingConfig } from "@/lib/config";

// --- Form ---
function MinimalWaitlist({ locale }: { locale: string }) {
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<"idle"|"loading"|"success"|"error">("idle");
  const [token, setToken] = useState<string|null>(null);
  const hasTurnstile = Boolean(landingConfig.turnstileSiteKey);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!email || status === "loading") return;
    setStatus("loading");
    const res = await submitWaitlist({ email, turnstileToken: token || "demo", locale, variant: "14" });
    setStatus(res.status === "subscribed" || res.status === "already_subscribed" ? "success" : "error");
  }

  return (
    <div className="w-full max-w-sm mx-auto">
      {status === "success" ? (
         <div className="bg-black text-white p-4 rounded-xl text-center text-sm font-medium tracking-wide">
           You have been added.
         </div>
      ) : (
        <form onSubmit={onSubmit} className="flex flex-col gap-3">
          <input
            type="email" required value={email} onChange={e => setEmail(e.target.value)}
            placeholder="Email address"
            className="w-full bg-[#F5F5F5] border-none px-5 py-4 rounded-xl text-black placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-black transition-all shadow-inner text-sm"
          />
          {hasTurnstile && <div className="rounded-xl overflow-hidden"><Turnstile siteKey={landingConfig.turnstileSiteKey} onToken={setToken} theme="light" /></div>}
          <button type="submit" disabled={status === "loading" || (hasTurnstile && !token)} className="bg-black text-white font-semibold py-4 rounded-xl hover:bg-gray-800 transition-colors disabled:opacity-50 text-sm tracking-wide">
            {status === "loading" ? "Joining..." : "Join Waitlist"}
          </button>
        </form>
      )}
    </div>
  );
}

// --- Page ---
export default function V14Page({ locale }: { locale: string }) {
  const [count, setCount] = useState(1342);
  useEffect(() => {
    const int = setInterval(() => { if(Math.random() > 0.5) setCount(c => c + 1) }, 5000);
    return () => clearInterval(int);
  }, []);

  const containerRef = useRef(null);
  const { scrollYProgress } = useScroll({ target: containerRef, offset: ["start end", "end start"] });
  const y1 = useTransform(scrollYProgress, [0, 1], [100, -200]);
  const y2 = useTransform(scrollYProgress, [0, 1], [250, -350]);
  const y3 = useTransform(scrollYProgress, [0, 1], [150, -100]);
  const y4 = useTransform(scrollYProgress, [0, 1], [300, -250]);

  return (
    <div className="bg-[#FFFFFF] text-[#0A0A0A] min-h-screen selection:bg-gray-200 selection:text-black font-sans scroll-smooth">

      {/* Absolute Fog / Gradients */}
      <div className="fixed bottom-0 left-0 w-full h-[50vh] bg-gradient-to-t from-white via-white/80 to-transparent pointer-events-none z-30" />
      <div className="fixed top-[-20%] left-[-10%] w-[500px] h-[500px] bg-gray-100 rounded-full blur-[100px] pointer-events-none z-0" />
      <div className="fixed bottom-[-10%] right-[-10%] w-[600px] h-[600px] bg-slate-50 rounded-full blur-[120px] pointer-events-none z-0" />

      {/* Header */}
      <header className="fixed top-0 w-full z-40 p-8 flex justify-between items-center mix-blend-difference text-black">
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 bg-black rounded-lg flex items-center justify-center text-white font-bold text-xs">S</div>
          <span className="font-semibold text-sm tracking-tight hidden sm:block">Sunnad</span>
        </div>
        <Link href={`/${locale}`} className="text-sm font-medium hover:text-gray-500 transition-colors">Back</Link>
      </header>

      {/* Hero */}
      <main className="relative z-10 flex flex-col items-center pt-[20vh] pb-[10vh] px-6 text-center">
        <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 1, ease: "easeOut" }} className="w-full max-w-3xl">
          <h1 className="text-6xl md:text-[5.5rem] font-bold tracking-tighter leading-[1.05] mb-6">
            One habit.<br/> Endless peace.
          </h1>
          <p className="text-xl md:text-2xl text-gray-500 font-medium mb-12 max-w-2xl mx-auto">
            Seamless Islamic habit tracking stripped of all visual noise.
          </p>

          <MinimalWaitlist locale={locale} />

          <div className="mt-8 text-sm font-medium text-gray-400">
            <span className="text-black">{count.toLocaleString()}</span> people joined
          </div>
        </motion.div>
      </main>

      {/* Spatial Canvas (Detached 3D elements) */}
      <section ref={containerRef} className="relative z-10 w-full h-[120vh] overflow-hidden mt-10">

        {/* Center Main Device */}
        <motion.div style={{ y: y1 }} className="absolute left-1/2 -translate-x-1/2 top-[10%] w-[300px] md:w-[360px] z-20">
          <div className="relative w-full aspect-[450/920] rounded-[44px] shadow-[0_40px_100px_rgba(0,0,0,0.1)] bg-white border border-gray-100 p-3">
             <div className="relative w-full h-full rounded-[34px] overflow-hidden">
                <img src="/app-screenshots/en_today_light.PNG" className="w-full h-full object-cover" alt="Today" />
             </div>
          </div>
        </motion.div>

        {/* Orbiting Detached UI Cards */}
        <motion.div style={{ y: y2 }} className="absolute left-[5%] md:left-[15%] top-[40%] w-[180px] md:w-[220px] z-10">
          <div className="relative w-full aspect-[450/920] rounded-[32px] shadow-[0_30px_80px_rgba(0,0,0,0.08)] bg-white p-2 md:p-3 rotate-[-8deg]">
             <div className="relative w-full h-full rounded-[24px] overflow-hidden border border-gray-100">
                <img src="/app-screenshots/en_dhikr_light.PNG" className="w-full h-full object-cover" alt="Dhikr" />
             </div>
          </div>
        </motion.div>

        <motion.div style={{ y: y3 }} className="absolute right-[5%] md:right-[15%] top-[20%] w-[200px] md:w-[260px] z-10 hidden sm:block">
          <div className="relative w-full aspect-[450/920] rounded-[36px] shadow-[0_40px_90px_rgba(0,0,0,0.12)] bg-white p-3 rotate-[6deg]">
             <div className="relative w-full h-full rounded-[28px] overflow-hidden border border-gray-100">
                <img src="/app-screenshots/en_groups_light.PNG" className="w-full h-full object-cover" alt="Groups" />
             </div>
          </div>
        </motion.div>

        <motion.div style={{ y: y4 }} className="absolute right-[20%] md:right-[30%] top-[60%] w-[150px] md:w-[200px] z-20 hidden md:block">
          <div className="relative w-full aspect-[450/920] rounded-[30px] shadow-[0_20px_60px_rgba(0,0,0,0.05)] bg-white p-2 rotate-[12deg] opacity-80 backdrop-blur-md">
             <div className="relative w-full h-full rounded-[22px] overflow-hidden border border-gray-100">
                <img src="/app-screenshots/en_analytics_light.PNG" className="w-full h-full object-cover" alt="Analytics" />
             </div>
          </div>
        </motion.div>

      </section>

      {/* Footer Area */}
      <footer className="relative z-40 bg-white/80 backdrop-blur-xl border-t border-gray-100 pb-20 pt-32 px-6">
        <div className="max-w-3xl mx-auto flex flex-col items-center text-center">
          <h2 className="text-4xl md:text-5xl font-bold tracking-tighter mb-6">Glad you asked.</h2>
          <p className="text-gray-500 mb-12 text-lg">Experience premium simplicity across the entire app.</p>
          <MinimalWaitlist locale={locale} />

          <div className="flex gap-8 mt-16 text-sm font-medium text-gray-400">
            <Link href={`/${locale}/terms`} className="hover:text-black transition-colors">Terms of Service</Link>
            <Link href={`/${locale}/privacy`} className="hover:text-black transition-colors">Privacy Policy</Link>
          </div>
        </div>
      </footer>

    </div>
  );
}
