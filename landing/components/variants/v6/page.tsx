"use client";

import { useState, useEffect, useRef } from "react";
import { motion, useScroll, AnimatePresence } from "framer-motion";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { submitWaitlist } from "@/lib/waitlist-submit";
import { Turnstile } from "@/components/turnstile";
import { landingConfig } from "@/lib/config";

/* ── Types ── */
interface Props {
  locale: string;
  variant: string;
}

type Theme = "dark" | "light";
type SupportedLocale = "en" | "ru" | "kz";

/* ── Content Dictionary ── */
const translations: Record<SupportedLocale, any> = {
  en: {
    hero: {
      badge: "Sunnad iOS",
      title: "Your deen,\nbeautifully tracked.",
      subtitle: "An offline-first Islamic habit tracker designed for focus, consistency, and spiritual growth.",
    },
    features: [
      {
        id: "today",
        title: "Focus on Today",
        desc: "A clean, distraction-free checklist of what matters right now. No overwhelming backlogs.",
      },
      {
        id: "dhikr",
        title: "Seamless Dhikr",
        desc: "Built-in counters for your daily adhkar. Tap anywhere, stay focused.",
      },
      {
        id: "groups",
        title: "Grow Together",
        desc: "Join private groups. Keep each other accountable with gentle nudges.",
      },
      {
        id: "analytics",
        title: "See Your Progress",
        desc: "Beautiful charts and streaks that motivate without inducing guilt.",
      },
    ],
    waitlist: {
      title: "Join the Waitlist",
      subtitle: "Be among the first to experience Sunnad when we launch.",
      placeholder: "Enter your email address",
      button: "Request Access",
      joining: "Joining...",
      success: "Alhamdulillah, you're on the list.",
      error: "Something went wrong. Please try again.",
      joined: "people joined",
    },
    nav: {
      back: "Back to Gallery",
      theme: "Theme",
      lang: "Language"
    }
  },
  ru: {
    hero: {
      badge: "Sunnad iOS",
      title: "Ваша религия\nв фокусе.",
      subtitle: "Офлайн-трекер исламских привычек. Создан для регулярности и духовного роста.",
    },
    features: [
      {
        id: "today",
        title: "Внимание на Сегодня",
        desc: "Чистый список того, что важно именно сейчас. Никакого визуального шума.",
      },
      {
        id: "dhikr",
        title: "Удобный Зикр",
        desc: "Встроенные счетчики для ежедневных азкаров. Простое касание в любом месте экрана.",
      },
      {
        id: "groups",
        title: "Расти Вместе",
        desc: "Создавайте закрытые группы с близкими. Поддерживайте друг друга мягкими напоминаниями.",
      },
      {
        id: "analytics",
        title: "Прогресс",
        desc: "Красивые графики и серии дней, которые мотивируют без лишнего давления.",
      },
    ],
    waitlist: {
      title: "Присоединиться",
      subtitle: "Станьте одними из первых, кто попробует Sunnad.",
      placeholder: "Ваш email",
      button: "Получить доступ",
      joining: "Отправка...",
      success: "Альхамдулиллях, вы в списке.",
      error: "Что-то пошло не так. Попробуйте еще раз.",
      joined: "человек присоединилось",
    },
    nav: {
      back: "В Галерею",
      theme: "Тема",
      lang: "Язык"
    }
  },
  kz: {
    hero: {
      badge: "Sunnad iOS",
      title: "Дініңіз,\nәдемі қадағаланады.",
      subtitle: "Назар аударуға, тұрақтылыққа және рухани дамуға арналған офлайн исламдық әдет трекері.",
    },
    features: [
      {
        id: "today",
        title: "Бүгінгі күнге назар",
        desc: "Дәл қазір маңызды істердің таза тізімі. Артық жүктемесіз.",
      },
      {
        id: "dhikr",
        title: "Ыңғайлы Зікір",
        desc: "Күнделікті азкарларға арналған кірістірілген есептегіштер. Кез келген жерді басыңыз.",
      },
      {
        id: "groups",
        title: "Бірге дамыңыз",
        desc: "Жабық топтар құрыңыз. Жұмсақ еске салғыштар арқылы бір-біріңізді қолдаңыз.",
      },
      {
        id: "analytics",
        title: "Прогресс",
        desc: "Кінәсіз ынталандыратын әдемі графиктер мен сериялар.",
      },
    ],
    waitlist: {
      title: "Күту тізіміне қосылу",
      subtitle: "Іске қосылған кезде Sunnad-ты бірінші болып байқап көріңіз.",
      placeholder: "Электрондық пошта",
      button: "Қосылу",
      joining: "Жіберілуде...",
      success: "Альхамдулиллях, сіз тізімдесіз.",
      error: "Қате кетті. Қайталап көріңіз.",
      joined: "адам қосылды",
    },
    nav: {
      back: "Галереяға қайту",
      theme: "Тақырып",
      lang: "Тіл"
    }
  }
};

/* ── Components ── */

function WaitlistCounter({ text, isDark }: { text: string; isDark: boolean }) {
  const [count, setCount] = useState(1248);

  useEffect(() => {
    const interval = setInterval(() => {
      if (Math.random() > 0.6) setCount(c => c + 1);
    }, 3500);
    return () => clearInterval(interval);
  }, []);

  return (
    <div className={`flex items-center gap-3 text-sm justify-center mb-6 transition-colors duration-500 ${isDark ? "text-white/70" : "text-black/60"}`}>
      <div className="flex -space-x-2">
        <div className={`w-7 h-7 rounded-full bg-gradient-to-br from-blue-400 to-indigo-500 border-2 z-30 ${isDark ? "border-black" : "border-[#FAFAFA]"}`} />
        <div className={`w-7 h-7 rounded-full bg-gradient-to-br from-emerald-400 to-teal-500 border-2 z-20 ${isDark ? "border-black" : "border-[#FAFAFA]"}`} />
        <div className={`w-7 h-7 rounded-full bg-gradient-to-br from-amber-400 to-orange-500 border-2 z-10 ${isDark ? "border-black" : "border-[#FAFAFA]"}`} />
      </div>
      <span className="font-medium tracking-wide">
        <strong className={`transition-colors duration-500 ${isDark ? "text-white" : "text-black"}`}>{count.toLocaleString()}</strong> {text}
      </span>
    </div>
  );
}

function WaitlistForm({ locale, variant, t, isDark }: { locale: string; variant: string; t: any; isDark: boolean }) {
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<"idle" | "loading" | "success" | "error">("idle");
  const [token, setToken] = useState<string | null>(null);
  const hasTurnstile = Boolean(landingConfig.turnstileSiteKey);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!email || status === "loading") return;
    setStatus("loading");

    // In environments without turnstile configured, we bypass it for the sake of demo,
    // but the submitWaitlist function might expect it.
    // We provide a fallback 'demo-token' if turnstile is missing but environment allows it.
    const res = await submitWaitlist({ email, turnstileToken: token || "demo-token", locale, variant });
    setStatus(res.status === "subscribed" || res.status === "already_subscribed" ? "success" : "error");
  }

  const inputBg = isDark ? "bg-white/5 border-white/10 text-white placeholder:text-white/30 focus:border-[#00ff88]/50 focus:bg-white/10" : "bg-black/5 border-black/10 text-black placeholder:text-black/40 focus:border-[#00aa55]/50 focus:bg-black/10";
  const btnBg = isDark ? "bg-white text-black hover:bg-[#00ff88]" : "bg-black text-white hover:bg-[#00aa55]";
  const successBg = isDark ? "bg-[#00ff88]/10 border-[#00ff88]/20 text-[#00ff88]" : "bg-[#00aa55]/10 border-[#00aa55]/20 text-[#00aa55]";

  return (
    <div className="w-full max-w-md mx-auto">
      <WaitlistCounter text={t.waitlist.joined} isDark={isDark} />

      {status === "success" ? (
        <motion.div
          initial={{ opacity: 0, scale: 0.95, y: 10 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          className={`p-6 rounded-2xl border text-center font-medium ${successBg}`}
        >
          {t.waitlist.success}
        </motion.div>
      ) : (
        <form onSubmit={onSubmit} className="flex flex-col gap-4">
          <input
            type="email"
            required
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder={t.waitlist.placeholder}
            className={`w-full rounded-2xl border px-6 py-4 transition-all focus:outline-none ${inputBg}`}
            disabled={status === "loading"}
          />
          {hasTurnstile && (
             <div className="flex justify-center overflow-hidden rounded-2xl">
               <Turnstile siteKey={landingConfig.turnstileSiteKey} onToken={setToken} theme={isDark ? "dark" : "light"} />
             </div>
          )}
          <button
            type="submit"
            disabled={status === "loading" || (hasTurnstile && !token)}
            className={`w-full font-semibold rounded-2xl px-6 py-4 transition-colors disabled:opacity-50 disabled:cursor-not-allowed ${btnBg}`}
          >
            {status === "loading" ? t.waitlist.joining : t.waitlist.button}
          </button>

          {status === "error" && (
            <p className="text-red-500 text-sm mt-2 text-center">{t.waitlist.error}</p>
          )}
        </form>
      )}
    </div>
  );
}

export default function V6Page({ locale: initialLocale, variant }: Props) {
  const router = useRouter();

  // State
  const [theme, setTheme] = useState<Theme>("dark");
  const [activeLocale, setActiveLocale] = useState<SupportedLocale>(
    (initialLocale === "ru" || initialLocale === "kz") ? initialLocale : "en"
  );

  const [activeFeature, setActiveFeature] = useState(0);
  const containerRef = useRef<HTMLDivElement>(null);
  const { scrollYProgress } = useScroll({ target: containerRef, offset: ["start start", "end end"] });

  const t = translations[activeLocale];
  const isDark = theme === "dark";

  // Map scroll to feature index
  useEffect(() => {
    return scrollYProgress.on("change", (latest) => {
      const index = Math.min(
        Math.floor(latest * t.features.length),
        t.features.length - 1
      );
      setActiveFeature(Math.max(0, index));
    });
  }, [scrollYProgress, t.features.length]);

  const toggleTheme = () => setTheme(isDark ? "light" : "dark");

  const switchLocale = () => {
    const next = activeLocale === "en" ? "ru" : activeLocale === "ru" ? "kz" : "en";
    setActiveLocale(next);
    // optionally shallow push route, but keeping it simple state based for preview
    router.replace(`/${next}/6`);
  };

  const getScreenshot = (featureId: string) => {
    return `/app-screenshots/${activeLocale}_${featureId}_${theme}.PNG`;
  };

  // Styles dynamically based on theme
  const rootClass = isDark
    ? "bg-[#050505] text-[#FAFAFA] selection:bg-[#00ff88] selection:text-black"
    : "bg-[#FAFAFA] text-[#050505] selection:bg-[#00aa55] selection:text-white";

  const accentColor = isDark ? "#00ff88" : "#00aa55";
  const mutedTextClass = isDark ? "text-white/50" : "text-black/50";
  const borderClass = isDark ? "border-white/10" : "border-black/10";
  const headerBgClass = isDark ? "bg-[#050505]/80" : "bg-[#FAFAFA]/80";

  return (
    <div className={`min-h-screen transition-colors duration-700 ease-in-out font-sans ${rootClass}`} style={{ fontFamily: "'Outfit', sans-serif" }}>

      {/* Header */}
      <header className={`fixed top-0 left-0 right-0 z-50 flex items-center justify-between px-6 py-4 backdrop-blur-xl border-b transition-colors duration-500 ${borderClass} ${headerBgClass}`}>
        <div className="flex items-center gap-3">
          <div className={`w-8 h-8 rounded-full flex items-center justify-center transition-colors ${isDark ? 'bg-white text-black' : 'bg-black text-white'}`}>
            <span className="font-bold text-sm">S</span>
          </div>
          <span className="font-semibold tracking-wide text-lg hidden sm:block">Sunnad</span>
        </div>

        <div className="flex items-center gap-4 sm:gap-6">
          <button
            onClick={toggleTheme}
            className={`text-sm font-medium transition-colors hover:opacity-70 flex items-center gap-2 ${mutedTextClass}`}
          >
            <span className="w-2 h-2 rounded-full" style={{ backgroundColor: accentColor }} />
            {isDark ? 'Light' : 'Dark'}
          </button>

          <button
            onClick={switchLocale}
            className={`text-sm font-medium uppercase tracking-wider transition-colors hover:opacity-70 ${mutedTextClass}`}
          >
            {activeLocale}
          </button>

          <Link href={`/${activeLocale}`} className={`text-sm font-medium transition-colors hover:opacity-70 hidden md:block ${mutedTextClass}`}>
            {t.nav.back}
          </Link>
        </div>
      </header>

      {/* Hero Section */}
      <section className="relative min-h-[100dvh] flex flex-col items-center justify-center px-6 pt-32 pb-20 overflow-hidden">
        {/* Glow */}
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[800px] h-[800px] pointer-events-none opacity-40 mix-blend-screen transition-opacity duration-1000" style={{ background: `radial-gradient(circle at center, ${isDark ? 'rgba(0,255,136,0.12)' : 'rgba(0,170,85,0.06)'} 0%, transparent 60%)`}} />

        <motion.div
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 1, ease: [0.16, 1, 0.3, 1] }}
          className="text-center z-10 max-w-4xl mx-auto flex flex-col items-center w-full"
        >
          <div className={`inline-flex items-center gap-2 px-4 py-1.5 rounded-full border mb-8 transition-colors ${isDark ? 'bg-white/5 border-white/10' : 'bg-black/5 border-black/10'}`}>
            <span className="w-2 h-2 rounded-full animate-pulse" style={{ backgroundColor: accentColor }} />
            <span className={`text-xs font-semibold tracking-widest uppercase ${mutedTextClass}`}>
              {t.hero.badge}
            </span>
          </div>

          <h1 className="text-6xl sm:text-7xl md:text-8xl lg:text-[7.5rem] font-light tracking-tight leading-[1.05] mb-8 whitespace-pre-line" style={{ fontFamily: "'Cormorant Garamond', serif" }}>
            {t.hero.title}
          </h1>

          <p className={`text-lg md:text-2xl max-w-2xl mx-auto font-light leading-relaxed mb-16 ${mutedTextClass}`}>
            {t.hero.subtitle}
          </p>

          <WaitlistForm locale={activeLocale} variant="6" t={t} isDark={isDark} />
        </motion.div>
      </section>

      {/* Cinematic Scroll Section */}
      <section ref={containerRef} className="relative h-[400vh]">
        <div className={`sticky top-0 h-screen flex items-center justify-center overflow-hidden border-t transition-colors ${borderClass}`}>

          {/* Background Ambient Glow moving with features */}
          <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[600px] pointer-events-none transition-all duration-1000" style={{ opacity: isDark ? 0.1 : 0.05, filter: 'blur(120px)', backgroundColor: accentColor, transform: `translate(-50%, -50%) scale(${1 + activeFeature * 0.1})`}} />

          {/* Text Content */}
          <div className="absolute left-6 md:left-16 lg:left-32 top-32 md:top-1/2 md:-translate-y-1/2 w-[calc(100%-48px)] md:w-[340px] lg:w-[420px] z-20 text-center md:text-left">
            <AnimatePresence mode="wait">
              <motion.div
                key={activeFeature}
                initial={{ opacity: 0, y: 20, filter: "blur(10px)" }}
                animate={{ opacity: 1, y: 0, filter: "blur(0px)" }}
                exit={{ opacity: 0, y: -20, filter: "blur(10px)" }}
                transition={{ duration: 0.6, ease: "easeInOut" }}
              >
                <div className={`text-xs tracking-[0.2em] font-medium mb-4 transition-colors uppercase`} style={{ color: accentColor }}>
                  0{activeFeature + 1} / 0{t.features.length}
                </div>
                <h2 className="text-4xl md:text-5xl lg:text-6xl font-light mb-6 leading-tight" style={{ fontFamily: "'Cormorant Garamond', serif" }}>
                  {t.features[activeFeature].title}
                </h2>
                <p className={`text-lg md:text-xl font-light leading-relaxed ${mutedTextClass}`}>
                  {t.features[activeFeature].desc}
                </p>
              </motion.div>
            </AnimatePresence>
          </div>

          {/* Phone Device */}
          <div className="relative z-10 mt-[28vh] md:mt-0 md:ml-[30vw]">
            <div className="relative w-[300px] h-[612px] md:w-[340px] md:h-[694px] lg:w-[360px] lg:h-[735px] mx-auto shadow-2xl rounded-[44px]">

              {/* Screenshots Crossfade */}
              <div className="absolute inset-[13px] md:inset-[15px] rounded-[34px] md:rounded-[42px] overflow-hidden bg-black isolation-auto z-10">
                <AnimatePresence mode="wait">
                  <motion.img
                    key={`${activeFeature}-${theme}-${activeLocale}`}
                    src={getScreenshot(t.features[activeFeature].id)}
                    alt={t.features[activeFeature].title}
                    initial={{ opacity: 0, scale: 1.05 }}
                    animate={{ opacity: 1, scale: 1 }}
                    exit={{ opacity: 0 }}
                    transition={{ duration: 0.8, ease: "easeOut" }}
                    className="absolute inset-0 w-full h-full object-cover"
                  />
                </AnimatePresence>
              </div>

              {/* Bezel */}
              <img
                src="/app-screenshots/iphone_bezels_16_pro.png"
                alt="iPhone 16 Pro Bezel"
                className="absolute inset-0 w-full h-full object-contain pointer-events-none z-20"
                style={{ filter: isDark ? 'drop-shadow(0 40px 80px rgba(0,0,0,0.8))' : 'drop-shadow(0 40px 80px rgba(0,0,0,0.2))' }}
              />

            </div>
          </div>

        </div>
      </section>

      {/* Footer Waitlist CTA */}
      <section className={`relative py-32 px-6 border-t transition-colors ${borderClass}`}>
        <div className="max-w-3xl mx-auto text-center">
          <h2 className="text-5xl md:text-6xl lg:text-7xl font-light mb-6" style={{ fontFamily: "'Cormorant Garamond', serif" }}>
            {t.waitlist.title}
          </h2>
          <p className={`text-xl mb-12 font-light ${mutedTextClass}`}>
            {t.waitlist.subtitle}
          </p>

          <WaitlistForm locale={activeLocale} variant="6" t={t} isDark={isDark} />
        </div>
      </section>

      {/* Footer */}
      <footer className={`py-10 text-center border-t transition-colors ${borderClass}`}>
        <div className={`flex flex-col md:flex-row items-center justify-center gap-6 md:gap-12 text-sm ${mutedTextClass}`}>
          <Link href={`/${activeLocale}/terms`} className="hover:opacity-100 transition-opacity">Terms</Link>
          <Link href={`/${activeLocale}/privacy`} className="hover:opacity-100 transition-opacity">Privacy</Link>
          <p className="tracking-wide uppercase text-[11px] opacity-60">
            Sunnad • iOS App • Elevate Baseline V6
          </p>
        </div>
      </footer>
    </div>
  );
}
