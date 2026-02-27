"use client";

import { useState, useRef, useEffect } from "react";
import { motion, useScroll, useTransform, AnimatePresence } from "framer-motion";
import Link from "next/link";
import { submitWaitlist } from "@/lib/waitlist-submit";
import { captureLandingEvent } from "@/lib/analytics";
import { Turnstile } from "@/components/turnstile";
import { landingConfig } from "@/lib/config";
import { Sun, Moon, Globe, ChevronDown } from "lucide-react";
import CountUp from "@/components/count-up";

type Theme = "dark" | "light";
type SupportedLocale = "en" | "ru" | "kk";
type WaitlistSuccessStatus = "subscribed" | "already_subscribed";

const screenshotLocaleByLocale: Record<SupportedLocale, "en" | "ru" | "kz"> = {
  en: "en",
  ru: "ru",
  kk: "kz",
};

const translations = {
  en: {
    heroTitle: "One habit.\nEndless peace.",
    heroSubtitle:
      "Seamless Islamic habit tracking stripped of all visual noise.",
    waitlistCount: "people joined",
    waitlistBtn: "Join Waitlist",
    waitlistJoining: "Joining...",
    waitlistSuccess: "You have been added.",
    waitlistPlaceholder: "Email address",
    bottomTitle: "Glad you asked.",
    bottomSubtitle: "Experience premium simplicity across the entire app.",
    features: [
      {
        id: "today",
        title: "Focus on Today",
        desc: "A singular view of what matters right now. No timeline anxiety, no endless scrolling. Just your immediate daily habits.",
      },
      {
        id: "dhikr",
        title: "Tactile Dhikr",
        desc: "A beautifully haptic counter that feels like a physical object. Count your tasbih anywhere with effortless screen taps.",
      },
      {
        id: "groups",
        title: "Private Circles",
        desc: "Stay accountable without the noise. Create small groups with close friends to quietly support each other's consistency.",
      },
      {
        id: "analytics",
        title: "See Your Progress",
        desc: "Beautiful, private charts and streaks that motivate consistent practice without guilt.",
      },
    ],
    faqTitle: "Frequently asked questions",
    faqSubtitle:
      "We are here to help you with any questions you may have. If you don't find what you need, please contact us at",
    faqs: [
      {
        q: "Is Sunnad fully free to use?",
        a: "Yes, the core tracking features will always remain free. We plan to introduce optional premium themes later to support development.",
      },
      {
        q: "Can I create private groups with my friends?",
        a: "Absolutely. You can invite friends to your circle to share streaks and hold each other accountable.",
      },
      {
        q: "How does the analytics tracking work?",
        a: "We quietly log your daily completions and generate a beautiful, private timeline mapping your consistency over weeks and months.",
      },
      {
        q: "Is my data secure?",
        a: "Your habitual data is completely private. We do not sell tracking data or use it for targeted advertising ever.",
      },
    ],
    legal: {
      terms: "Terms of Service",
      privacy: "Privacy Policy",
    },
  },
  ru: {
    heroTitle: "Одна привычка.\nБесконечный покой.",
    heroSubtitle:
      "Понятный трекер исламских привычек без лишнего визуального шума.",
    waitlistCount: "уже присоединились",
    waitlistBtn: "Присоединиться",
    waitlistJoining: "Идёт отправка...",
    waitlistSuccess: "Вы добавлены в список.",
    waitlistPlaceholder: "Ваш email",
    bottomTitle: "Рады, что вы спросили.",
    bottomSubtitle: "Премиальная простота на всём протяжении приложения.",
    features: [
      {
        id: "today",
        title: "Фокус на Сегодня",
        desc: "Единый взгляд на то, что важно прямо сейчас. Никакой тревоги из-за таймлайнов, никакого бесконечного скроллинга. Только ваши ежедневные привычки.",
      },
      {
        id: "dhikr",
        title: "Тактильный Зикр",
        desc: "Красивый тактильный счетчик, который ощущается как физический объект. Считайте тасбих где угодно с легкими касаниями экрана.",
      },
      {
        id: "groups",
        title: "Приватные Круги",
        desc: "Оставайтесь ответственными без лишнего шума. Создавайте небольшие группы с близкими друзьями, чтобы тихо поддерживать постоянство друг друга.",
      },
      {
        id: "analytics",
        title: "Прогресс",
        desc: "Красивые приватные графики и серии дней, которые мотивируют к постоянству без давления.",
      },
    ],
    faqTitle: "Часто задаваемые вопросы",
    faqSubtitle:
      "Мы здесь, чтобы помочь вам с любыми вопросами. Если вы не нашли ответ, свяжитесь с нами:",
    faqs: [
      {
        q: "Полностью ли бесплатно использование Sunnad?",
        a: "Да, основные функции трекинга всегда будут бесплатными. Позже мы планируем добавить премиальные темы для поддержки разработки.",
      },
      {
        q: "Могу ли я создавать приватные группы с друзьями?",
        a: "Конечно. Вы можете приглашать друзей в свой круг, чтобы делиться сериями и поддерживать друг друга.",
      },
      {
        q: "Как работает отслеживание аналитики?",
        a: "Мы тихо записываем ваши ежедневные выполнения и создаем красивый, приватный таймлайн, отображающий вашу стабильность.",
      },
      {
        q: "В безопасности ли мои данные?",
        a: "Ваши данные о привычках полностью приватны. Мы никогда не продаем данные о трекинге и не используем их для таргетированной рекламы.",
      },
    ],
    legal: {
      terms: "Условия использования",
      privacy: "Политика конфиденциальности",
    },
  },
  kk: {
    heroTitle: "Бір әдет.\nШексіз тыныштық.",
    heroSubtitle: "Ешқандай визуалды шусыз, мінсіз исламдық әдет трекері.",
    waitlistCount: "адам қосылды",
    waitlistBtn: "Тізімге қосылу",
    waitlistJoining: "Қосылуда...",
    waitlistSuccess: "Сіз тізімге қосылдыңыз.",
    waitlistPlaceholder: "Email мекенжайы",
    bottomTitle: "Сұрағаныңызға қуаныштымыз.",
    bottomSubtitle:
      "Қосымшаның барлық жеріндегі премиум қарапайымдылықты сезініңіз.",
    features: [
      {
        id: "today",
        title: "Бүгінге назар аудару",
        desc: "Дәл қазір маңызды нәрсеге жалғыз көзқарас. Уақыт шкаласы туралы уайым жоқ, шексіз айналдыру жоқ. Тек сіздің күнделікті әдеттеріңіз.",
      },
      {
        id: "dhikr",
        title: "Тактильді Зікір",
        desc: "Физикалық нысан сияқты сезілетін әдемі тактильді есептегіш. Экранды жеңіл түрту арқылы кез келген жерде тасбих санаңыз.",
      },
      {
        id: "groups",
        title: "Жеке Топтар",
        desc: "Артық шусыз жауапкершілікті сақтаңыз. Жақын достарыңызбен шағын топтар құрып, бір-біріңіздің тұрақтылығыңызды үнсіз қолдаңыз.",
      },
      {
        id: "analytics",
        title: "Прогресс",
        desc: "Әдемі жеке графиктер мен сериялар арқылы тұрақтылығыңызды көріңіз әрі ынталаныңыз.",
      },
    ],
    faqTitle: "Жиі қойылатын сұрақтар",
    faqSubtitle:
      "Біз сізге кез келген сұрақтар бойынша көмектесуге дайынбыз. Егер сіз өзіңізге қажетті жауапты таппасаңыз, бізге хабарласыңыз:",
    faqs: [
      {
        q: "Sunnad қолданбасын пайдалану толығымен тегін бе?",
        a: "Иә, негізгі бақылау мүмкіндіктері әрқашан тегін болып қалады. Кейінірек дамытуды қолдау үшін қосымша премиум тақырыптарды енгізуді жоспарлап отырмыз.",
      },
      {
        q: "Достарыммен жеке топтар құра аламын ба?",
        a: "Әрине. Достарыңызды өз ортаңызға шақырып, жетістіктеріңізбен бөлісе аласыз.",
      },
      {
        q: "Аналитика қалай жұмыс істейді?",
        a: "Біз сіздің күнделікті орындауларыңызды үнсіз тіркейміз және тұрақтылығыңызды көрсететін әдемі, жеке таймлайн жасаймыз.",
      },
      {
        q: "Менің деректерім қауіпсіз бе?",
        a: "Сіздің әдеттеріңіз туралы деректер толығымен құпия. Біз бақылау деректерін ешқашан сатпаймыз және оларды мақсатты жарнама үшін пайдаланбаймыз.",
      },
    ],
    legal: {
      terms: "Пайдалану шарттары",
      privacy: "Құпиялылық саясаты",
    },
  },
};

function parseReferrerDomain(): string | null {
  if (typeof document === "undefined") return null;
  if (!document.referrer) return null;
  try {
    const url = new URL(document.referrer);
    return url.hostname || null;
  } catch {
    return null;
  }
}

function parseUtmParams(): Record<string, string> {
  if (typeof window === "undefined") return {};
  const params = new URLSearchParams(window.location.search);
  const result: Record<string, string> = {};

  const mappings: Array<[string, string]> = [
    ["utm_source", "utm_source"],
    ["utm_medium", "utm_medium"],
    ["utm_campaign", "utm_campaign"],
    ["utm_content", "utm_content"],
    ["utm_term", "utm_term"],
  ];

  for (const [param, key] of mappings) {
    const value = params.get(param);
    if (value) {
      result[key] = value;
    }
  }

  return result;
}

// --- Form ---
function MinimalWaitlist({
  locale,
  isDark,
  t,
  onSuccess,
}: {
  locale: SupportedLocale;
  isDark?: boolean;
  t: any;
  onSuccess?: (status: WaitlistSuccessStatus) => void;
}) {
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
    if (res.status === "subscribed" || res.status === "already_subscribed") {
      setStatus("success");
      onSuccess?.(res.status);
      return;
    }
    setStatus("error");
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
            <div
              className={`rounded-xl overflow-hidden ${token ? "hidden" : ""}`}
            >
              <Turnstile
                siteKey={landingConfig.turnstileSiteKey}
                onToken={setToken}
                onExpired={() => {
                  setToken(null);
                }}
                onError={() => {
                  setToken(null);
                }}
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

function FeaturesScroll({
  screenshotLocale,
  theme,
  t,
  isDark,
  sectionRef,
}: {
  screenshotLocale: "en" | "ru" | "kz";
  theme: string;
  t: any;
  isDark: boolean;
  sectionRef: React.MutableRefObject<HTMLElement | null>;
}) {
  const containerRef = useRef<HTMLElement | null>(null);
  const { scrollYProgress } = useScroll({
    target: containerRef,
    offset: ["start start", "end end"],
  });

  const activeIndex = useTransform(scrollYProgress, (v) => {
    if (v < 0.25) return 0;
    if (v < 0.5) return 1;
    if (v < 0.75) return 2;
    return 3;
  });

  const [index, setIndex] = useState(0);
  useEffect(() => {
    return activeIndex.on("change", (v) => setIndex(v));
  }, [activeIndex]);

  const images = ["today", "dhikr", "groups", "analytics"];

  // Alternating positions: 0=left, 1=right, 2=left, 3=right
  const positions = [
    "md:left-[0%] md:-translate-x-0",
    "md:left-[70%] md:-translate-x-0",
    "md:left-[0%] md:-translate-x-0",
    "md:left-[70%] md:-translate-x-0",
  ];

  return (
    <section
      ref={(node) => {
        containerRef.current = node;
        sectionRef.current = node;
      }}
      className="relative w-full h-[300vh] z-30"
    >
      <div className="sticky top-0 h-screen w-full overflow-hidden flex flex-col items-center justify-center px-6">
        {/* Text Content — AnimatePresence with blur+slide */}
        <div className="absolute inset-0 max-w-6xl mx-auto w-full h-full pointer-events-none">
          <AnimatePresence mode="wait">
            <motion.div
              key={index}
              initial={{ opacity: 0, y: 24, filter: "blur(10px)" }}
              animate={{ opacity: 1, y: 0, filter: "blur(0px)" }}
              exit={{ opacity: 0, y: -24, filter: "blur(10px)" }}
              transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
              className={`absolute top-[10%] left-0 right-0 mx-auto w-full max-w-[280px] text-center md:top-1/3 md:right-auto md:mx-0 md:-translate-y-1/2 md:max-w-[420px] md:text-left ${positions[index]}`}
            >
              <div
                className={`text-[10px] md:text-xs tracking-[0.2em] font-medium mb-2 md:mb-4 uppercase ${isDark ? "text-gray-400" : "text-gray-500"}`}
              >
                0{index + 1} / 0{t.features.length}
              </div>
              <h3 className="text-2xl md:text-4xl font-bold mb-2 md:mb-4 tracking-tight">
                {t.features[index].title}
              </h3>
              <p
                className={`text-sm md:text-lg leading-relaxed ${isDark ? "text-gray-400" : "text-gray-500"}`}
              >
                {t.features[index].desc}
              </p>
            </motion.div>
          </AnimatePresence>
        </div>

        {/* Central Sticky Phone */}
        <div className="relative w-[280px] md:w-[320px] aspect-[450/920] drop-shadow-[0_25px_50px_rgba(0,0,0,0.15)] z-10 md:absolute md:left-1/2 md:-translate-x-1/2 absolute top-1/2 -translate-y-[60%] md:-translate-y-1/2">
          <div className="absolute inset-[13px] md:inset-[15px] rounded-[30px] md:rounded-[36px] overflow-hidden bg-black shadow-inner">
            <AnimatePresence mode="wait">
              <motion.img
                key={index}
                initial={{ opacity: 0, scale: 1 }}
                animate={{ opacity: 1, scale: 1 }}
                exit={{ opacity: 0 }}
                transition={{ duration: 0.5, ease: "easeOut" }}
                src={`/app-screenshots/${screenshotLocale}_${images[index]}_${theme}.PNG`}
                className="absolute inset-0 w-full h-full object-cover"
                alt="Feature"
              />
            </AnimatePresence>
          </div>
          <img
            src="/app-screenshots/iphone_bezels_16_pro.png"
            className="absolute inset-0 w-full h-full object-contain pointer-events-none z-20"
            alt=""
          />
        </div>
      </div>
    </section>
  );
}

function FAQSection({
  t,
  isDark,
  sectionRef,
}: {
  t: any;
  isDark: boolean;
  sectionRef: React.MutableRefObject<HTMLElement | null>;
}) {
  const [openIndex, setOpenIndex] = useState<number | null>(null);

  return (
    <section
      ref={sectionRef}
      className={`relative z-40 w-full py-32 px-6 ${isDark ? "bg-[#0A0A0A]/50" : "bg-gray-50/50"} border-y ${isDark ? "border-white/5" : "border-black/5"}`}
    >
      <div className="max-w-4xl mx-auto">
        <div className="text-center mb-16">
          <h2 className="text-4xl md:text-5xl font-bold tracking-tight mb-4">
            {t.faqTitle}
          </h2>
          <p className="text-gray-500 max-w-xl mx-auto">
            {t.faqSubtitle}{" "}
            <a
              href="mailto:support@sunnad.app"
              className="underline hover:text-gray-800 dark:hover:text-gray-200 transition-colors"
            >
              support@sunnad.app
            </a>
          </p>
        </div>

        <div className="flex flex-col gap-4">
          {t.faqs.map((faq: any, i: number) => {
            const isOpen = openIndex === i;
            return (
              <div
                key={i}
                className={`overflow-hidden rounded-2xl border transition-colors ${
                  isDark
                    ? "bg-[#111] border-white/5"
                    : "bg-white border-black/5 hover:border-black/10"
                }`}
              >
                <button
                  onClick={() => setOpenIndex(isOpen ? null : i)}
                  className="w-full flex items-center justify-between p-6 text-left"
                >
                  <span className="text-lg font-medium">{faq.q}</span>
                  <motion.div
                    animate={{ rotate: isOpen ? 180 : 0 }}
                    transition={{ duration: 0.2 }}
                    className={`flex-shrink-0 p-1 rounded-full ${isDark ? "bg-white/10" : "bg-black/5"}`}
                  >
                    <ChevronDown
                      size={20}
                      className={isDark ? "text-gray-400" : "text-gray-500"}
                    />
                  </motion.div>
                </button>
                <AnimatePresence initial={false}>
                  {isOpen && (
                    <motion.div
                      key="content"
                      initial="collapsed"
                      animate="open"
                      exit="collapsed"
                      variants={{
                        open: { opacity: 1, height: "auto" },
                        collapsed: { opacity: 0, height: 0 },
                      }}
                      transition={{
                        duration: 0.3,
                        ease: [0.04, 0.62, 0.23, 0.98],
                      }}
                    >
                      <div
                        className={`px-6 pb-6 pr-12 text-base leading-relaxed ${isDark ? "text-gray-400" : "text-gray-500"}`}
                      >
                        {faq.a.split(" ").map((word: string, wi: number) => (
                          <motion.span
                            key={wi}
                            initial={{ opacity: 0, filter: "blur(4px)" }}
                            animate={{ opacity: 1, filter: "blur(0px)" }}
                            transition={{
                              delay: wi * 0.025,
                              duration: 0.3,
                              ease: "easeOut",
                            }}
                            className="inline-block mr-[0.25em]"
                          >
                            {word}
                          </motion.span>
                        ))}
                      </div>
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
}

async function fetchWaitlistCount(): Promise<number> {
  try {
    const res = await fetch("/api/waitlist-count", { cache: "no-store" });
    const data = await res.json();
    return typeof data.count === "number" ? data.count : 0;
  } catch {
    return 0;
  }
}

// --- Page ---
export default function LandingPage({
  locale: initialLocale,
}: {
  locale: string;
}) {
  const [theme, setTheme] = useState<Theme>("dark");
  const [activeLocale, setActiveLocale] = useState<SupportedLocale>(
    initialLocale === "ru" || initialLocale === "kk"
      ? (initialLocale as SupportedLocale)
      : "en",
  );
  const isDark = theme === "dark";
  const t = translations[activeLocale];
  const screenshotLocale = screenshotLocaleByLocale[activeLocale];
  const heroSectionRef = useRef<HTMLElement | null>(null);
  const featuresSectionRef = useRef<HTMLElement | null>(null);
  const faqSectionRef = useRef<HTMLElement | null>(null);
  const bottomCTASectionRef = useRef<HTMLElement | null>(null);
  const viewedSectionsRef = useRef<Set<string>>(new Set());
  const hasTrackedAllSectionsRef = useRef(false);

  // Fetch real waitlist count
  const [count, setCount] = useState(0);
  useEffect(() => {
    void fetchWaitlistCount().then(setCount);
  }, []);

  // Track landing page view (manual, privacy-safe)
  useEffect(() => {
    if (typeof window === "undefined") return;

    const referrerDomain = parseReferrerDomain();
    const utm = parseUtmParams();

    const props: Record<string, unknown> = {
      locale: activeLocale,
      theme,
      path: window.location.pathname,
    };

    if (referrerDomain) {
      props.referrer_domain = referrerDomain;
    }

    Object.assign(props, utm);

    captureLandingEvent("landing_page_viewed", props);
    // Run once on mount; dependency array intentionally empty
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (typeof window === "undefined") return;

    const sectionEntries: Array<{ id: string; element: HTMLElement | null }> = [
      { id: "hero", element: heroSectionRef.current },
      { id: "feature_scroll", element: featuresSectionRef.current },
      { id: "faq", element: faqSectionRef.current },
      { id: "bottom_cta", element: bottomCTASectionRef.current },
    ];

    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (!entry.isIntersecting) continue;
          const sectionId = entry.target.getAttribute("data-section-id");
          if (!sectionId) continue;
          if (viewedSectionsRef.current.has(sectionId)) continue;

          viewedSectionsRef.current.add(sectionId);
          captureLandingEvent("landing_section_viewed", {
            locale: activeLocale,
            theme,
            path: window.location.pathname,
            section_id: sectionId,
          });

          if (
            viewedSectionsRef.current.size === 4 &&
            !hasTrackedAllSectionsRef.current
          ) {
            hasTrackedAllSectionsRef.current = true;
            captureLandingEvent("landing_all_sections_viewed", {
              locale: activeLocale,
              theme,
              path: window.location.pathname,
              sections_total: 4,
            });
          }
        }
      },
      { threshold: 0.45 },
    );

    for (const item of sectionEntries) {
      if (!item.element) continue;
      item.element.setAttribute("data-section-id", item.id);
      observer.observe(item.element);
    }

    return () => observer.disconnect();
  }, [activeLocale, theme]);

  function handleWaitlistSuccess(status: WaitlistSuccessStatus): void {
    if (status === "subscribed") {
      setCount((prev) => prev + 1);
    }
    void fetchWaitlistCount().then(setCount);
  }

  const containerRef = useRef<HTMLElement | null>(null);
  const { scrollYProgress } = useScroll({
    target: containerRef,
    offset: ["start end", "end start"],
  });
  const y1 = useTransform(scrollYProgress, [0, 1], [100, -200]);
  const y2 = useTransform(scrollYProgress, [0, 1], [250, -350]);
  const y3 = useTransform(scrollYProgress, [0, 1], [150, -100]);
  const y4 = useTransform(scrollYProgress, [0, 1], [300, -250]);

  const bgClass = isDark
    ? "bg-[#050505] text-[#FAFAFA]"
    : "bg-[#FFFFFF] text-[#0A0A0A]";

  return (
    <div
      className={`min-h-screen font-sans scroll-smooth selection:bg-gray-500 selection:text-white ${bgClass}`}
    >
      {/* Absolute Fog / Gradients */}
      <div
        className={`fixed bottom-0 left-0 w-full h-[25vh] md:h-[50vh] bg-gradient-to-t to-transparent pointer-events-none z-30 ${isDark ? "from-[#050505] via-[#050505]/80" : "from-white via-white/80"}`}
      />
      <div
        className={`fixed top-[-15%] left-[-10%] w-[500px] h-[500px] rounded-full blur-[100px] pointer-events-none z-0 ${isDark ? "bg-white/5" : "bg-gray-100"}`}
      />
      <div
        className={`fixed bottom-[-10%] right-[-10%] w-[600px] h-[600px] rounded-full blur-[120px] pointer-events-none z-0 ${isDark ? "bg-white/5" : "bg-slate-50"}`}
      />

      {/* Header */}
      <header
        className={`fixed top-0 w-full z-40 p-6 md:p-8 flex justify-between items-center transition-colors ${isDark ? "text-white" : "text-black"}`}
      >
        <div className="flex items-center gap-3">
          <img
            src="/logo.png"
            alt="Sunnad Logo"
            className="w-6 h-6 object-contain"
          />
          <span className="font-semibold text-[10px] md:text-sm tracking-tight hidden sm:block">
            Sunnad
          </span>
        </div>

        <div className="flex items-center gap-3 md:gap-4">
          <button
            onClick={() => setTheme(isDark ? "light" : "dark")}
            className={`flex items-center justify-center p-2 rounded-full transition-colors ${isDark ? "hover:bg-white/10" : "hover:bg-black/5"}`}
          >
            {isDark ? <Sun size={18} /> : <Moon size={18} />}
          </button>

          <button
            onClick={() => {
              const next =
                activeLocale === "en"
                  ? "ru"
                  : activeLocale === "ru"
                    ? "kk"
                    : "en";
              setActiveLocale(next);
            }}
            className={`flex items-center gap-1.5 md:gap-2 px-3 py-1.5 rounded-full transition-colors ${isDark ? "hover:bg-white/10" : "hover:bg-black/5"}`}
          >
            <Globe size={16} />
            <span className="text-[10px] md:text-xs font-semibold uppercase">
              {activeLocale}
            </span>
          </button>
        </div>
      </header>

      {/* Hero */}
      <main
        ref={heroSectionRef}
        className="relative z-10 flex flex-col items-center pt-[20vh] pb-[10vh] px-6 text-center"
      >
        <div className="w-full max-w-3xl">
          <motion.h1
            initial={{ opacity: 0, filter: "blur(10px)", y: 20 }}
            animate={{ opacity: 1, filter: "blur(0px)", y: 0 }}
            transition={{ duration: 1, ease: "easeOut" }}
            className="text-6xl md:text-[5.5rem] font-bold tracking-tighter leading-[1.05] mb-6 whitespace-pre-line"
          >
            {t.heroTitle}
          </motion.h1>
          <motion.p
            initial={{ opacity: 0, filter: "blur(10px)", y: 20 }}
            animate={{ opacity: 1, filter: "blur(0px)", y: 0 }}
            transition={{ duration: 1, delay: 0.2, ease: "easeOut" }}
            className="text-xl md:text-2xl text-gray-500 font-medium mb-12 max-w-2xl mx-auto whitespace-pre-line"
          >
            {t.heroSubtitle}
          </motion.p>

          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 1, delay: 0.4, ease: "easeOut" }}
          >
            <MinimalWaitlist
              locale={activeLocale}
              isDark={isDark}
              t={t}
              onSuccess={handleWaitlistSuccess}
            />

            <div className="mt-8 text-sm font-medium text-gray-400 flex items-center justify-center gap-2">
              <span className="relative flex h-2 w-2">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-green-400 opacity-75"></span>
                <span className="relative inline-flex rounded-full h-2 w-2 bg-green-500"></span>
              </span>
              <span className={isDark ? "text-white" : "text-black"}>
                {count > 0 ? (
                  <CountUp to={count} separator="," duration={2} />
                ) : (
                  "0"
                )}
              </span>{" "}
              {t.waitlistCount}
            </div>
          </motion.div>
        </div>
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
            <div className="absolute inset-[12px] md:inset-[18px] rounded-[24px] md:rounded-[36px] overflow-hidden bg-black z-10">
              <img
                src={`/app-screenshots/${screenshotLocale}_today_${theme}.PNG`}
                className="absolute inset-0 w-full h-full object-cover"
                alt="Today"
              />
            </div>
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
            <div className="absolute inset-[8px] md:inset-[13px] rounded-[16px] md:rounded-[26px] overflow-hidden bg-black z-10">
              <img
                src={`/app-screenshots/${screenshotLocale}_analytics_${theme}.PNG`}
                className="absolute inset-0 w-full h-full object-cover"
                alt="Analytics"
              />
            </div>
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
            <div className="absolute inset-[7px] md:inset-[11px] rounded-[14px] md:rounded-[22px] overflow-hidden bg-black z-10">
              <img
                src={`/app-screenshots/${screenshotLocale}_dhikr_${theme}.PNG`}
                className="absolute inset-0 w-full h-full object-cover"
                alt="Dhikr"
              />
            </div>
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
            <div className="absolute inset-[9px] md:inset-[14px] rounded-[18px] md:rounded-[28px] overflow-hidden bg-black z-10">
              <img
                src={`/app-screenshots/${screenshotLocale}_groups_${theme}.PNG`}
                className="absolute inset-0 w-full h-full object-cover"
                alt="Groups"
              />
            </div>
            <img
              src="/app-screenshots/iphone_bezels_16_pro.png"
              className="absolute inset-0 w-full h-full object-contain pointer-events-none z-20"
              alt=""
            />
          </div>
        </motion.div>
      </section>

      <FeaturesScroll
        screenshotLocale={screenshotLocale}
        theme={theme}
        isDark={isDark}
        t={t}
        sectionRef={featuresSectionRef}
      />

      <FAQSection isDark={isDark} t={t} sectionRef={faqSectionRef} />

      {/* Bottom Waitlist Section */}
      <section
        ref={bottomCTASectionRef}
        className="relative z-40 bg-transparent pb-20 pt-32 px-6 md:h-[80vh] flex md:items-center"
      >
        <div className="max-w-3xl mx-auto flex flex-col items-center text-center w-full">
          <h2 className="text-4xl md:text-5xl font-bold tracking-tighter mb-6">
            {t.bottomTitle}
          </h2>
          <p className="text-gray-500 mb-12 text-lg">{t.bottomSubtitle}</p>
          <MinimalWaitlist
            locale={activeLocale}
            isDark={isDark}
            t={t}
            onSuccess={handleWaitlistSuccess}
          />
          <div className="mt-8 text-sm font-medium text-gray-400 flex items-center justify-center gap-2">
            <span className="relative flex h-2 w-2">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-green-400 opacity-75"></span>
              <span className="relative inline-flex rounded-full h-2 w-2 bg-green-500"></span>
            </span>
            <span className={isDark ? "text-white" : "text-black"}>
              {count > 0 ? (
                <CountUp to={count} separator="," duration={2} />
              ) : (
                "0"
              )}
            </span>{" "}
            {t.waitlistCount}
          </div>
        </div>
      </section>

      {/* Footer with Terms/Privacy */}
      <footer className="relative z-40 w-full flex justify-center gap-8 py-8 text-sm font-medium text-gray-500 bg-transparent">
        <Link
          href={`/${activeLocale}/terms?theme=${theme}`}
          className={`transition-colors ${isDark ? "hover:text-white" : "hover:text-black"}`}
        >
          {t.legal.terms}
        </Link>
        <Link
          href={`/${activeLocale}/privacy?theme=${theme}`}
          className={`transition-colors ${isDark ? "hover:text-white" : "hover:text-black"}`}
        >
          {t.legal.privacy}
        </Link>
      </footer>
    </div>
  );
}
