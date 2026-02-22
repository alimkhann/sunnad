"use client";

import { useState } from "react";
import { motion } from "framer-motion";
import Link from "next/link";
import { submitWaitlist } from "@/lib/waitlist-submit";
import { Turnstile } from "@/components/turnstile";
import { landingConfig } from "@/lib/config";

// --- Waitlist Forms ---
function BotanicalWaitlist({ locale }: { locale: string }) {
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<"idle"|"loading"|"success"|"error">("idle");
  const [token, setToken] = useState<string|null>(null);
  const hasTurnstile = Boolean(landingConfig.turnstileSiteKey);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!email || status === "loading") return;
    setStatus("loading");
    const res = await submitWaitlist({ email, turnstileToken: token || "demo", locale, variant: "13" });
    setStatus(res.status === "subscribed" || res.status === "already_subscribed" ? "success" : "error");
  }

  return (
    <div className="w-full max-w-sm mx-auto bg-white/40 backdrop-blur-xl border border-white/60 p-6 rounded-[2rem] shadow-[0_8px_32px_rgba(100,130,100,0.08)]">
      <div className="text-center mb-6">
        <h3 className="text-[#3A4D39] text-xl font-medium mb-1">Plant the Seed</h3>
        <p className="text-[#5B6D5A] text-sm">Join the waitlist to cultivate your daily routine.</p>
      </div>

      {status === "success" ? (
         <div className="bg-[#E4F2E4] text-[#2F4F2F] p-4 rounded-xl text-center text-sm font-medium">
           Your place in the garden is reserved.
         </div>
      ) : (
        <form onSubmit={onSubmit} className="flex flex-col gap-3">
          <input
            type="email" required value={email} onChange={e => setEmail(e.target.value)}
            placeholder="Email address"
            className="w-full bg-white/80 border border-[#D0DDD0]/50 px-5 py-4 rounded-xl text-[#3A4D39] placeholder:text-[#8CA08B] focus:outline-none focus:border-[#739072] focus:bg-white transition-all shadow-inner"
          />
          {hasTurnstile && <div className="overflow-hidden rounded-xl border border-white bg-white/50 w-fit mx-auto"><Turnstile siteKey={landingConfig.turnstileSiteKey} onToken={setToken} theme="light" /></div>}
          <button type="submit" disabled={status === "loading" || (hasTurnstile && !token)} className="bg-[#4F6F52] text-white font-medium py-4 rounded-xl hover:bg-[#3A4D39] transition-colors disabled:opacity-50 mt-2 shadow-[0_4px_14px_rgba(79,111,82,0.3)]">
            {status === "loading" ? "Watering..." : "Join Waitlist"}
          </button>
        </form>
      )}

      <div className="mt-6 flex items-center justify-center gap-2 text-xs text-[#739072] font-medium">
        <span className="w-2 h-2 rounded-full bg-[#739072] animate-pulse" />
        8,231 PEOPLE JOINED
      </div>
    </div>
  );
}

// --- Organic Layout Comps ---
export default function V13Page({ locale }: { locale: string }) {
  return (
    <div className="bg-[#F4F6F0] text-[#1E2E1E] min-h-screen selection:bg-[#B3D0B0] selection:text-[#1E2E1E]" style={{ fontFamily: "'Outfit', sans-serif" }}>

      {/* Topographic Background Pattern - pure CSS / SVG */}
      <div className="fixed inset-0 pointer-events-none opacity-[0.06] z-0"
        style={{ backgroundImage: `url("data:image/svg+xml,%3Csvg width='100' height='100' viewBox='0 0 100 100' xmlns='http://www.w3.org/2000/svg'%3E%3Cpath d='M10 10 Q 50 20 90 10 T 90 90 T 10 90 T 10 10' fill='none' stroke='%233A4D39' stroke-width='1'/%3E%3Cpath d='M20 20 Q 50 30 80 20 T 80 80 T 20 80 T 20 20' fill='none' stroke='%233A4D39' stroke-width='1'/%3E%3Cpath d='M30 30 Q 50 40 70 30 T 70 70 T 30 70 T 30 30' fill='none' stroke='%233A4D39' stroke-width='1'/%3E%3C/svg%3E")`, backgroundSize: '200px 200px', backgroundRepeat: 'repeat' }}
      />

      {/* Soft Blobs */}
      <div className="fixed top-[-20%] right-[-10%] w-[60%] h-[60%] bg-gradient-to-br from-[#E2F0CB] to-[#B5EAD7] blur-[120px] rounded-full pointer-events-none opacity-60 z-0" />
      <div className="fixed bottom-[-10%] left-[-10%] w-[70%] h-[70%] bg-gradient-to-tr from-[#FFDAC1] to-[#FFB7B2] blur-[140px] rounded-full pointer-events-none opacity-30 z-0" />

      {/* Nav */}
      <header className="relative z-40 p-8 flex justify-between items-center text-[#5B6D5A] font-medium tracking-wide">
        <div className="flex items-center gap-2">
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
            <path d="M12 22C17.5228 22 22 17.5228 22 12C22 6.47715 17.5228 2 12 2C6.47715 2 2 6.47715 2 12C2 17.5228 6.47715 22 12 22Z" fill="#D3E4CD" stroke="#4F6F52" strokeWidth="2"/>
            <path d="M12 16C14.2091 16 16 14.2091 16 12C16 9.79086 14.2091 8 12 8C9.79086 8 8 9.79086 8 12C8 14.2091 9.79086 16 12 16Z" fill="#739072"/>
          </svg>
          Sunnad
        </div>
        <Link href={`/${locale}`} className="hover:text-[#3A4D39] transition-colors border-b border-transparent hover:border-[#3A4D39]">Return Home</Link>
      </header>

      {/* Hero */}
      <main className="relative z-10 max-w-7xl mx-auto px-6 pt-10 pb-32">

        <div className="flex flex-col lg:flex-row items-center justify-between gap-16">

          <div className="lg:w-1/2">
            <motion.div initial={{ opacity: 0, y: 30 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 1, ease: "easeOut" }}>
              <div className="inline-block bg-[#E8F1e6] border border-[#CCDCCB] text-[#4F6F52] px-4 py-1.5 rounded-full text-xs font-semibold uppercase tracking-wider mb-6">
                Cultivate Consistency
              </div>
              <h1 className="text-5xl md:text-7xl font-bold tracking-tight text-[#1E2E1E] mb-6 leading-[1.05]">
                A habit tracker that feels like a <span className="text-[#4F6F52] italic font-serif">garden.</span>
              </h1>
              <p className="text-xl text-[#5B6D5A] font-light leading-relaxed mb-10 max-w-lg">
                Grow your daily deen routines softly and naturally. Offline-first, distraction-free, and beautifully crafted for Muslims.
              </p>

              <div className="flex flex-col sm:flex-row gap-6">
                {/* Embedded Waitlist */}
                <div className="w-full">
                  <BotanicalWaitlist locale={locale} />
                </div>
              </div>
            </motion.div>
          </div>

          <div className="lg:w-1/2 flex justify-center lg:justify-end">
             {/* Diagonal 3-Phone Cascade Layout */}
             <div className="relative w-[300px] h-[750px] md:w-[450px]">

                 {/* Back Phone */}
                 <motion.div
                   initial={{ opacity: 0, x: 50, y: 50 }} animate={{ opacity: 1, x: 0, y: 0 }} transition={{ duration: 1.2, delay: 0.2 }}
                   className="absolute top-24 right-[-20%] md:right-0 w-[240px] md:w-[280px] rounded-[36px] shadow-[0_20px_50px_rgba(40,60,40,0.1)] rotate-6"
                 >
                    <div className="relative overflow-hidden bg-white rounded-[32px] p-[10px]">
                      <img src="/app-screenshots/en_analytics_light.PNG" className="w-full rounded-[24px] object-cover" alt="" />
                    </div>
                 </motion.div>

                 {/* Middle Phone */}
                 <motion.div
                   initial={{ opacity: 0, x: 30, y: 30 }} animate={{ opacity: 1, x: 0, y: 0 }} transition={{ duration: 1.2, delay: 0.4 }}
                   className="absolute top-12 left-[10%] w-[260px] md:w-[300px] rounded-[38px] shadow-[0_30px_60px_rgba(40,60,40,0.15)] -rotate-3 z-10"
                 >
                    <div className="relative overflow-hidden bg-white rounded-[34px] p-[12px]">
                      <img src="/app-screenshots/en_groups_light.PNG" className="w-full rounded-[26px] object-cover" alt="" />
                    </div>
                 </motion.div>

                 {/* Front Phone */}
                 <motion.div
                   initial={{ opacity: 0, scale: 0.95 }} animate={{ opacity: 1, scale: 1 }} transition={{ duration: 1.2, delay: 0.6 }}
                   className="absolute top-0 left-[-15%] md:left-[-10%] w-[280px] md:w-[320px] rounded-[42px] shadow-[0_40px_80px_rgba(40,60,40,0.2)] z-20"
                 >
                    <div className="relative overflow-hidden bg-white/60 backdrop-blur-md rounded-[40px] p-[14px]">
                      <img src="/app-screenshots/en_today_light.PNG" className="w-full rounded-[30px] object-cover border border-white/50" alt="" />
                    </div>
                 </motion.div>

             </div>
          </div>

        </div>

      </main>

      <section className="relative z-10 bg-[#E9EFE8] py-24 mb-10">
        <div className="max-w-4xl mx-auto px-6 flex flex-col items-center">
            <h2 className="text-3xl md:text-5xl font-bold text-[#1E2E1E] text-center mb-10 mb:mb-16 font-serif italic">
              Harvest what you sow.
            </h2>
            <BotanicalWaitlist locale={locale} />
        </div>
      </section>

      <footer className="relative z-10 pb-16 pt-8 flex justify-center gap-10 text-[#739072] text-sm uppercase font-semibold tracking-widest">
        <Link href={`/${locale}/terms`} className="hover:text-[#3A4D39]">Terms</Link>
        <Link href={`/${locale}/privacy`} className="hover:text-[#3A4D39]">Privacy</Link>
      </footer>
    </div>
  );
}
