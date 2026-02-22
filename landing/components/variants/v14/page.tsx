"use client";

import { useState, useRef, useEffect } from "react";
import { motion, useScroll, useTransform } from "framer-motion";
import Link from "next/link";
import { submitWaitlist } from "@/lib/waitlist-submit";
import { Turnstile } from "@/components/turnstile";
import { landingConfig } from "@/lib/config";
import { Sun, Moon, Globe } from "lucide-react";

type Theme = "dark" | "light";
type SupportedLocale = "en" | "ru" | "kz";

const translations = {
  en: {
    heroTitle: "One habit.\nEndless peace.",
    heroSubtitle: "Seamless Islamic habit tracking stripped of all visual noise.",
    waitlistCount: "people joined",
    waitlistBtn: "Join Waitlist",
    waitlistJoining: "Joining...",
    waitlistSuccess: "You have been added.",
    waitlistPlaceholder: "Email address",
    bottomTitle: "Glad you asked.",
    bottomSubtitle: "Experience premium simplicity across the entire app.",
  },
  ru: {
    heroTitle: "Одна привычка.\nБесконечный покой.",
    heroSubtitle: "Понятный трекер исламских привычек без лишнего визуального шума.",
    waitlistCount: "уже присоединились",
    waitlistBtn: "Присоединиться",
    waitlistJoining: "Идёт отправка...",
    waitlistSuccess: "Вы добавлены в список.",
    waitlistPlaceholder: "Ваш email",
    bottomTitle: "Рады, что вы спросили.",
    bottomSubtitle: "Премиальная простота на всём протяжении приложения.",
  },
  kz: {
    heroTitle: "Бір әдет.\nШексіз тыныштық.",
    heroSubtitle: "Ешқандай визуалды шусыз, мінсіз исламдық әдет трекері.",
    waitlistCount: "адам қосылды",
    waitlistBtn: "Тізімге қосылу",
    waitlistJoining: "Қосылуда...",
    waitlistSuccess: "Сіз тізімге қосылдыңыз.",
    waitlistPlaceholder: "Email мекенжайы",
    bottomTitle: "Сұрағаныңызға қуаныштымыз.",
    bottomSubtitle: "Қосымшаның барлық жеріндегі премиум қарапайымдылықты сезініңіз.",
  },
};

// Removed obsolete PhoneMockup
// --- Form ---
function MinimalWaitlist({ locale, isDark, t }: { locale: string; isDark?: boolean; t: any }) {
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
      variant: "14",
    });
    setStatus(
      res.status === "subscribed" || res.status === "already_subscribed"
        ? "success"
        : "error",
    );
  }

  return (
    <div className="w-full max-w-sm mx-auto">
      {status === "success" ? (
        <div className="bg-[#1A1A1A] text-white p-4 rounded-xl text-center text-sm font-medium tracking-wide">
          {t.waitlistSuccess}
        </div>
      ) : (
        <form onSubmit={onSubmit} className="flex flex-col gap-3">
          <input
            type="email"
            required
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder={t.waitlistPlaceholder}
            className={`w-full border-none px-5 py-4 rounded-xl placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-gray-500 transition-all shadow-inner text-sm ${isDark ? "bg-[#1A1A1A] text-white" : "bg-[#F5F5F5] text-black"}`}
          />
          {hasTurnstile && (
            <div className="rounded-xl overflow-hidden">
              <Turnstile
                siteKey={landingConfig.turnstileSiteKey}
                onToken={setToken}
                theme={isDark ? "dark" : "light"}
              />
            </div>
          )}
          <button
            type="submit"
            disabled={status === "loading" || (hasTurnstile && !token)}
            className={`font-semibold py-4 rounded-xl transition-colors disabled:opacity-50 text-sm tracking-wide ${isDark ? "bg-white text-black hover:bg-gray-200" : "bg-black text-white hover:bg-gray-800"}`}
          >
            {status === "loading" ? t.waitlistJoining : t.waitlistBtn}
          </button>
        </form>
      )}
    </div>
  );
}

// --- Page ---
export default function V14Page({ locale: initialLocale }: { locale: string }) {
  const [theme, setTheme] = useState<Theme>("dark");
  const [activeLocale, setActiveLocale] = useState<SupportedLocale>(
    initialLocale === "ru" || initialLocale === "kz" ? (initialLocale as SupportedLocale) : "en"
  );
  const isDark = theme === "dark";
  const t = translations[activeLocale];

  const [count, setCount] = useState(1342);
  useEffect(() => {
    const int = setInterval(() => {
      if (Math.random() > 0.5) setCount((c) => c + 1);
    }, 5000);
    return () => clearInterval(int);
  }, []);

  const containerRef = useRef(null);
  const { scrollYProgress } = useScroll({
    target: containerRef,
    offset: ["start end", "end start"],
  });
  const y1 = useTransform(scrollYProgress, [0, 1], [100, -200]);
  const y2 = useTransform(scrollYProgress, [0, 1], [250, -350]);
  const y3 = useTransform(scrollYProgress, [0, 1], [150, -100]);
  const y4 = useTransform(scrollYProgress, [0, 1], [300, -250]);

  const bgClass = isDark ? "bg-[#050505] text-[#FAFAFA]" : "bg-[#FFFFFF] text-[#0A0A0A]";

  return (
    <div className={`min-h-screen font-sans scroll-smooth selection:bg-gray-500 selection:text-white ${bgClass}`}>
      {/* Absolute Fog / Gradients */}
      <div className={`fixed bottom-0 left-0 w-full h-[25vh] md:h-[50vh] bg-gradient-to-t to-transparent pointer-events-none z-30 ${isDark ? "from-[#050505] via-[#050505]/80" : "from-white via-white/80"}`} />
      <div className={`fixed top-[-15%] left-[-10%] w-[500px] h-[500px] rounded-full blur-[100px] pointer-events-none z-0 ${isDark ? "bg-white/5" : "bg-gray-100"}`} />
      <div className={`fixed bottom-[-10%] right-[-10%] w-[600px] h-[600px] rounded-full blur-[120px] pointer-events-none z-0 ${isDark ? "bg-white/5" : "bg-slate-50"}`} />

      {/* Header */}
      <header className={`fixed top-0 w-full z-40 p-6 md:p-8 flex justify-between items-center transition-colors ${isDark ? "text-white" : "text-black"}`}>
        <div className="flex items-center gap-3">
          <img src="/logo.png" alt="Sunnad Logo" className={`w-6 h-6 object-contain`} />
          <span className="font-semibold text-[10px] md:text-sm tracking-tight hidden sm:block">
            Sunnad
          </span>
        </div>

        <div className="flex items-center gap-3 md:gap-4">
          <button
            onClick={() => setTheme(isDark ? 'light' : 'dark')}
            className={`flex items-center justify-center p-2 rounded-full transition-colors ${isDark ? "hover:bg-white/10" : "hover:bg-black/5"}`}
          >
            {isDark ? <Sun size={18} /> : <Moon size={18} />}
          </button>

          <button
            onClick={() => {
              const next = activeLocale === "en" ? "ru" : activeLocale === "ru" ? "kz" : "en";
              setActiveLocale(next);
            }}
            className={`flex items-center gap-1.5 md:gap-2 px-3 py-1.5 rounded-full transition-colors ${isDark ? "hover:bg-white/10" : "hover:bg-black/5"}`}
          >
            <Globe size={16} />
            <span className="text-[10px] md:text-xs font-semibold uppercase">{activeLocale}</span>
          </button>

          <Link
            href={`/${activeLocale}`}
            className={`text-[10px] md:text-sm font-medium transition-colors ${isDark ? "hover:text-gray-400" : "hover:text-gray-500"}`}
          >
            Back
          </Link>
        </div>
      </header>

      {/* Hero */}
      <main className="relative z-10 flex flex-col items-center pt-[20vh] pb-[10vh] px-6 text-center">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 1, ease: "easeOut" }}
          className="w-full max-w-3xl"
        >
          <h1 className="text-6xl md:text-[5.5rem] font-bold tracking-tighter leading-[1.05] mb-6 whitespace-pre-line">
            {t.heroTitle}
          </h1>
          <p className="text-xl md:text-2xl text-gray-500 font-medium mb-12 max-w-2xl mx-auto whitespace-pre-line">
            {t.heroSubtitle}
          </p>

          <MinimalWaitlist locale={activeLocale} isDark={isDark} t={t} />

          <div className="mt-8 text-sm font-medium text-gray-400">
            <span className={isDark ? "text-white" : "text-black"}>{count.toLocaleString()}</span> {t.waitlistCount}
          </div>
        </motion.div>
      </main>

      {/* Spatial Canvas (Detached 3D elements) */}
      <section
        ref={containerRef}
        className="relative z-10 w-full h-[120vh] md:h-[85vh] overflow-hidden mt-10"
      >
        {/* Today */}
        <motion.div
          style={{ y: y1 }}
          className="absolute left-1/2 -translate-x-1/2 top-[4%] md:top-[8%] w-[240px] md:w-[360px] z-20"
        >
          <div className="relative w-full aspect-[450/920] rotate-[-10deg] md:rotate-[0deg] drop-shadow-2xl">
            {/* Inner Screenshot */}
            <div className="absolute inset-[12px] md:inset-[18px] rounded-[24px] md:rounded-[36px] overflow-hidden bg-black z-10">
              <img
                src={`/app-screenshots/${activeLocale}_today_${theme}.PNG`}
                className="absolute inset-0 w-full h-full object-cover"
                alt="Today"
              />
            </div>
            {/* Bezel Overlay */}
            <img
              src="/app-screenshots/iphone_bezels_16_pro.png"
              className="absolute inset-0 w-full h-full object-contain pointer-events-none z-20"
              alt=""
            />
          </div>
        </motion.div>

        {/* Analytics */}
        <motion.div
          style={{ y: y3 }}
          className="absolute right-[65%] md:right-[22%] top-[50%] md:top-[21%] w-[160px] md:w-[260px] z-20 md:z-10"
        >
          <div className="relative w-full aspect-[450/920] rotate-[10deg] md:rotate-[4deg] drop-shadow-xl">
            {/* Inner Screenshot */}
            <div className="absolute inset-[8px] md:inset-[13px] rounded-[16px] md:rounded-[26px] overflow-hidden bg-black z-10">
              <img
                src={`/app-screenshots/${activeLocale}_analytics_${theme}.PNG`}
                className="absolute inset-0 w-full h-full object-cover"
                alt="Analytics"
              />
            </div>
            {/* Bezel Overlay */}
            <img
              src="/app-screenshots/iphone_bezels_16_pro.png"
              className="absolute inset-0 w-full h-full object-contain pointer-events-none z-20"
              alt=""
            />
          </div>
        </motion.div>

        {/* Dhikr */}
        <motion.div
          style={{ y: y2 }}
          className="absolute left-[-5%] md:left-[25%] top-[40%] md:top-[36%] w-[150px] md:w-[220px] z-10 md:z-20"
        >
          <div className="relative w-full aspect-[450/920] rotate-[12deg] md:rotate-[-8deg] drop-shadow-xl">
            {/* Inner Screenshot */}
            <div className="absolute inset-[7px] md:inset-[11px] rounded-[14px] md:rounded-[22px] overflow-hidden bg-black z-10">
              <img
                src={`/app-screenshots/${activeLocale}_dhikr_${theme}.PNG`}
                className="absolute inset-0 w-full h-full object-cover"
                alt="Dhikr"
              />
            </div>
            {/* Bezel Overlay */}
            <img
              src="/app-screenshots/iphone_bezels_16_pro.png"
              className="absolute inset-0 w-full h-full object-contain pointer-events-none z-20"
              alt=""
            />
          </div>
        </motion.div>

        {/* Groups */}
        <motion.div
          style={{ y: y4 }}
          className="absolute right-[-5%] md:right-[53%] top-[30%] md:top-[16%] w-[180px] md:w-[280px] z-20"
        >
          <div className="relative w-full aspect-[450/920] rotate-[-10deg] md:rotate-[-4deg] drop-shadow-2xl">
            {/* Inner Screenshot */}
            <div className="absolute inset-[9px] md:inset-[14px] rounded-[18px] md:rounded-[28px] overflow-hidden bg-black z-10">
              <img
                src={`/app-screenshots/${activeLocale}_groups_${theme}.PNG`}
                className="absolute inset-0 w-full h-full object-cover"
                alt="Groups"
              />
            </div>
            {/* Bezel Overlay */}
            <img
              src="/app-screenshots/iphone_bezels_16_pro.png"
              className="absolute inset-0 w-full h-full object-contain pointer-events-none z-20"
              alt=""
            />
          </div>
        </motion.div>
      </section>

      {/* Bottom Waitlist Section */}
      <section className="relative z-40 bg-transparent pb-20 pt-32 px-6 md:h-[80vh] flex md:items-center">
        <div className="max-w-3xl mx-auto flex flex-col items-center text-center w-full">
          <h2 className="text-4xl md:text-5xl font-bold tracking-tighter mb-6">
            {t.bottomTitle}
          </h2>
          <p className="text-gray-500 mb-12 text-lg">
            {t.bottomSubtitle}
          </p>
          <MinimalWaitlist locale={activeLocale} isDark={isDark} t={t} />
          <div className="mt-8 text-sm font-medium text-gray-400">
            <span className={isDark ? "text-white" : "text-black"}>{count.toLocaleString()}</span> {t.waitlistCount}
          </div>
        </div>
      </section>

      {/* Footer with Terms/Privacy */}
      <footer className="relative z-40 w-full flex justify-center gap-8 py-8 text-sm font-medium text-gray-500 bg-transparent">
        <Link
          href={`/${activeLocale}/terms`}
          className={`transition-colors ${isDark ? "hover:text-white" : "hover:text-black"}`}
        >
          Terms of Service
        </Link>
        <Link
          href={`/${activeLocale}/privacy`}
          className={`transition-colors ${isDark ? "hover:text-white" : "hover:text-black"}`}
        >
          Privacy Policy
        </Link>
      </footer>
    </div>
  );
}
