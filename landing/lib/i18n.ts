export const locales = ["en", "ru", "kk"] as const;
export type Locale = (typeof locales)[number];
export const defaultLocale: Locale = "en";

export function isLocale(value: string): value is Locale {
  return locales.includes(value as Locale);
}

export const variantIds = ["1", "2", "3", "4", "5"] as const;
export type VariantId = (typeof variantIds)[number];

export function isVariantId(value: string): value is VariantId {
  return variantIds.includes(value as VariantId);
}

export const variantNames: Record<VariantId, string> = {
  "1": "Soft Glass",
  "2": "Editorial Serif",
  "3": "Geometric Clean",
  "4": "Warm Tactile",
  "5": "Dark Cosmic",
};

/* ------------------------------------------------------------------ */
/*  Dictionary type                                                    */
/* ------------------------------------------------------------------ */
export type Dictionary = {
  meta: { title: string; description: string };
  nav: { logo: string; waitlist: string; features: string; faq: string };
  hero: {
    badge: string;
    title: string;
    subtitle: string;
    cta: string;
  };
  features: {
    title: string;
    subtitle: string;
    items: {
      habits: { title: string; description: string };
      quotes: { title: string; description: string };
      groups: { title: string; description: string };
      offline: { title: string; description: string };
    };
  };
  screenshots: { title: string; subtitle: string };
  faq: {
    title: string;
    items: { q: string; a: string }[];
  };
  waitlist: {
    title: string;
    subtitle: string;
    emailPlaceholder: string;
    submit: string;
    submitting: string;
    successTitle: string;
    successMessage: string;
    alreadyTitle: string;
    alreadyMessage: string;
    errorTitle: string;
    errorMessage: string;
    rateLimitTitle: string;
    rateLimitMessage: string;
    turnstileExpired: string;
  };
  footer: {
    tagline: string;
    terms: string;
    privacy: string;
    madeWith: string;
  };
  picker: {
    title: string;
    subtitle: string;
    explore: string;
  };
  locale: {
    switchLabel: string;
    en: string;
    ru: string;
    kk: string;
  };
};

/* ------------------------------------------------------------------ */
/*  English                                                            */
/* ------------------------------------------------------------------ */
const en: Dictionary = {
  meta: {
    title: "Sunnad — Build better habits, together",
    description:
      "An offline-first Islamic habit tracker with daily quotes, streaks, and group accountability. Available for iOS and Android.",
  },
  nav: {
    logo: "Sunnad",
    waitlist: "Join Waitlist",
    features: "Features",
    faq: "FAQ",
  },
  hero: {
    badge: "Coming soon to iOS & Android",
    title: "Build better habits,\ntogether.",
    subtitle:
      "Track daily sunnahs, build streaks, share accountability with friends — all offline-first with a beautiful quote every morning.",
    cta: "Join the Waitlist",
  },
  features: {
    title: "Everything you need",
    subtitle: "Simple, focused, and built for your daily routine.",
    items: {
      habits: {
        title: "Habits & Streaks",
        description:
          "Create habits for each day of the week. Track completions with satisfying streaks. Dhikr counter built right in.",
      },
      quotes: {
        title: "Quote of the Day",
        description:
          "Start every morning with an inspiring hadith or wisdom quote. Save your favorites and share them with friends.",
      },
      groups: {
        title: "Group Accountability",
        description:
          "Create or join a group with friends. See who completed their habits today. Send gentle reminders to stay on track.",
      },
      offline: {
        title: "Offline First",
        description:
          "Works without internet. Your data stays on-device. Sync only when you want to join a group — no account required otherwise.",
      },
    },
  },
  screenshots: {
    title: "Designed for focus",
    subtitle: "Clean, distraction-free interface that helps you stay consistent.",
  },
  faq: {
    title: "Frequently asked questions",
    items: [
      {
        q: "What is Sunnad?",
        a: "Sunnad is a habit tracker designed for Muslims who want to build consistent daily habits. It focuses on simplicity, offline access, and accountability through groups.",
      },
      {
        q: "Is Sunnad free?",
        a: "Yes! The core habit tracking features are completely free. We may add optional premium features in the future, but the essentials will always remain free.",
      },
      {
        q: "Do I need an account?",
        a: "No — Sunnad works entirely offline without an account. You only need to sign up if you want to join or create a group with friends.",
      },
      {
        q: "What languages are supported?",
        a: "Sunnad is available in English, Russian, and Kazakh. We plan to add more languages based on community interest.",
      },
      {
        q: "Which platforms are supported?",
        a: "We're launching first on iOS with Android coming shortly after. Join the waitlist above to be the first to know.",
      },
      {
        q: "What features are coming next?",
        a: "We have an exciting roadmap that includes additional habit types, widgets, and community features. Stay tuned for updates after launch!",
      },
    ],
  },
  waitlist: {
    title: "Be the first to know",
    subtitle: "Join the waitlist and we'll notify you when Sunnad launches.",
    emailPlaceholder: "your@email.com",
    submit: "Join Waitlist",
    submitting: "Joining...",
    successTitle: "You're on the list! 🎉",
    successMessage:
      "We'll send you an email when Sunnad is ready to download.",
    alreadyTitle: "Already signed up!",
    alreadyMessage:
      "This email is already on our waitlist. We'll be in touch soon.",
    errorTitle: "Something went wrong",
    errorMessage: "Please try again in a moment.",
    rateLimitTitle: "Slow down",
    rateLimitMessage: "Please wait a few minutes before trying again.",
    turnstileExpired: "Security check expired. Please try again.",
  },
  footer: {
    tagline: "Build better habits, together.",
    terms: "Terms of Service",
    privacy: "Privacy Policy",
    madeWith: "Made with care for the ummah",
  },
  picker: {
    title: "Choose a vibe",
    subtitle: "Explore five distinct design styles for the Sunnad landing page.",
    explore: "Explore",
  },
  locale: {
    switchLabel: "Language",
    en: "English",
    ru: "Русский",
    kk: "Қазақша",
  },
};

/* ------------------------------------------------------------------ */
/*  Russian                                                            */
/* ------------------------------------------------------------------ */
const ru: Dictionary = {
  meta: {
    title: "Sunnad — Создавайте полезные привычки вместе",
    description:
      "Офлайн-трекер исламских привычек с ежедневными цитатами, сериями и групповой ответственностью. Доступен для iOS и Android.",
  },
  nav: {
    logo: "Sunnad",
    waitlist: "Записаться",
    features: "Функции",
    faq: "Вопросы",
  },
  hero: {
    badge: "Скоро на iOS и Android",
    title: "Создавайте полезные\nпривычки вместе.",
    subtitle:
      "Отслеживайте ежедневные сунны, накапливайте серии, делитесь прогрессом с друзьями — всё работает офлайн с вдохновляющей цитатой каждое утро.",
    cta: "Присоединиться к списку ожидания",
  },
  features: {
    title: "Всё необходимое",
    subtitle: "Просто, сфокусировано и создано для вашего распорядка дня.",
    items: {
      habits: {
        title: "Привычки и серии",
        description:
          "Создавайте привычки на каждый день недели. Отслеживайте выполнение с мотивирующими сериями. Встроенный счётчик зикра.",
      },
      quotes: {
        title: "Цитата дня",
        description:
          "Начинайте каждое утро с вдохновляющего хадиса или мудрой цитаты. Сохраняйте избранные и делитесь ими с друзьями.",
      },
      groups: {
        title: "Групповая ответственность",
        description:
          "Создайте или присоединитесь к группе друзей. Смотрите, кто выполнил свои привычки сегодня. Отправляйте мягкие напоминания.",
      },
      offline: {
        title: "Сначала офлайн",
        description:
          "Работает без интернета. Данные хранятся на устройстве. Синхронизация только для групп — аккаунт не нужен.",
      },
    },
  },
  screenshots: {
    title: "Создан для концентрации",
    subtitle: "Чистый интерфейс без отвлечений, который помогает сохранять постоянство.",
  },
  faq: {
    title: "Часто задаваемые вопросы",
    items: [
      {
        q: "Что такое Sunnad?",
        a: "Sunnad — это трекер привычек для мусульман, которые хотят выработать ежедневные привычки. Он фокусируется на простоте, офлайн-доступе и ответственности через группы.",
      },
      {
        q: "Sunnad бесплатный?",
        a: "Да! Основные функции отслеживания привычек полностью бесплатны. В будущем мы можем добавить премиум-функции, но базовые возможности останутся бесплатными.",
      },
      {
        q: "Нужен ли аккаунт?",
        a: "Нет — Sunnad работает полностью офлайн без аккаунта. Регистрация нужна только если вы хотите присоединиться к группе друзей.",
      },
      {
        q: "Какие языки поддерживаются?",
        a: "Sunnad доступен на английском, русском и казахском языках. Мы планируем добавить больше языков по запросам сообщества.",
      },
      {
        q: "На каких платформах доступен?",
        a: "Мы запускаемся сначала на iOS, Android появится вскоре после. Присоединяйтесь к списку ожидания, чтобы узнать первыми.",
      },
      {
        q: "Какие функции будут дальше?",
        a: "У нас есть интересный план развития, включающий дополнительные типы привычек, виджеты и социальные функции. Следите за обновлениями после запуска!",
      },
    ],
  },
  waitlist: {
    title: "Узнайте первыми",
    subtitle: "Присоединяйтесь к списку ожидания — мы уведомим вас о запуске Sunnad.",
    emailPlaceholder: "ваш@email.com",
    submit: "Записаться",
    submitting: "Записываем...",
    successTitle: "Вы в списке! 🎉",
    successMessage: "Мы отправим вам письмо, когда Sunnad будет готов к загрузке.",
    alreadyTitle: "Вы уже записаны!",
    alreadyMessage: "Этот email уже в нашем списке ожидания. Мы скоро свяжемся.",
    errorTitle: "Что-то пошло не так",
    errorMessage: "Пожалуйста, попробуйте через минуту.",
    rateLimitTitle: "Подождите",
    rateLimitMessage: "Пожалуйста, подождите несколько минут перед повторной попыткой.",
    turnstileExpired: "Проверка безопасности истекла. Попробуйте ещё раз.",
  },
  footer: {
    tagline: "Создавайте полезные привычки вместе.",
    terms: "Условия использования",
    privacy: "Политика конфиденциальности",
    madeWith: "Сделано с заботой для уммы",
  },
  picker: {
    title: "Выберите стиль",
    subtitle: "Исследуйте пять уникальных дизайнов лендинга Sunnad.",
    explore: "Открыть",
  },
  locale: {
    switchLabel: "Язык",
    en: "English",
    ru: "Русский",
    kk: "Қазақша",
  },
};

/* ------------------------------------------------------------------ */
/*  Kazakh                                                             */
/* ------------------------------------------------------------------ */
const kk: Dictionary = {
  meta: {
    title: "Sunnad — Пайдалы әдеттерді бірге қалыптастырыңыз",
    description:
      "Күнделікті дәйексөздермен, серияларымен және топтық жауапкершілікпен жұмыс істейтін офлайн ислами әдет трекері. iOS және Android үшін қолжетімді.",
  },
  nav: {
    logo: "Sunnad",
    waitlist: "Тіркелу",
    features: "Мүмкіндіктер",
    faq: "Сұрақтар",
  },
  hero: {
    badge: "Жақында iOS және Android-та",
    title: "Пайдалы әдеттерді\nбірге қалыптастырыңыз.",
    subtitle:
      "Күнделікті сүннеттерді бақылаңыз, серияларды жинаңыз, достарыңызбен жауапкершілікті бөлісіңіз — бәрі офлайн жұмыс істейді, әр таңда шабыттандыратын дәйексөзбен.",
    cta: "Күту тізіміне қосылу",
  },
  features: {
    title: "Барлық қажетті нәрсе",
    subtitle: "Қарапайым, нақты және күнделікті тәртібіңізге арналған.",
    items: {
      habits: {
        title: "Әдеттер мен сериялар",
        description:
          "Аптаның әр күніне әдеттер жасаңыз. Орындалуын мотивациялық сериялармен бақылаңыз. Кіріктірілген зікір есептегіші.",
      },
      quotes: {
        title: "Күннің дәйексөзі",
        description:
          "Әр таңды шабыттандыратын хадиспен немесе даналық сөзбен бастаңыз. Таңдаулыларды сақтап, достарыңызбен бөлісіңіз.",
      },
      groups: {
        title: "Топтық жауапкершілік",
        description:
          "Достарыңызбен топ құрыңыз немесе қосылыңыз. Бүгін кім әдеттерін орындағанын көріңіз. Жұмсақ еске салулар жіберіңіз.",
      },
      offline: {
        title: "Алдымен офлайн",
        description:
          "Интернетсіз жұмыс істейді. Деректер құрылғыда сақталады. Синхрондау тек топтар үшін — аккаунт қажет емес.",
      },
    },
  },
  screenshots: {
    title: "Зейінге арналған дизайн",
    subtitle: "Таза, алаңдататын нәрсесіз интерфейс, тұрақтылықты сақтауға көмектеседі.",
  },
  faq: {
    title: "Жиі қойылатын сұрақтар",
    items: [
      {
        q: "Sunnad дегеніміз не?",
        a: "Sunnad — күнделікті әдеттерді қалыптастырғысы келетін мұсылмандарға арналған әдет трекері. Ол қарапайымдылыққа, офлайн қолжетімділікке және топтық жауапкершілікке бағытталған.",
      },
      {
        q: "Sunnad тегін бе?",
        a: "Иә! Әдеттерді бақылаудың негізгі функциялары толығымен тегін. Болашақта премиум мүмкіндіктер қосылуы мүмкін, бірақ негізгі мүмкіндіктер әрқашан тегін болады.",
      },
      {
        q: "Аккаунт қажет пе?",
        a: "Жоқ — Sunnad аккаунтсыз толығымен офлайн жұмыс істейді. Тіркелу тек достар тобына қосылу немесе құру үшін қажет.",
      },
      {
        q: "Қандай тілдер қолдау көрсетіледі?",
        a: "Sunnad ағылшын, орыс және қазақ тілдерінде қолжетімді. Қауымдастық сұрауы бойынша көбірек тілдер қосуды жоспарлап отырмыз.",
      },
      {
        q: "Қандай платформаларда қолжетімді?",
        a: "Біз алдымен iOS-та іске қосамыз, Android көп ұзамай қосылады. Бірінші болып білу үшін күту тізіміне қосылыңыз.",
      },
      {
        q: "Келесі қандай мүмкіндіктер болады?",
        a: "Бізде қосымша әдет түрлерін, виджеттерді және әлеуметтік мүмкіндіктерді қамтитын қызықты даму жоспары бар. Іске қосылғаннан кейін жаңартуларды қадағалаңыз!",
      },
    ],
  },
  waitlist: {
    title: "Бірінші болып біліңіз",
    subtitle: "Күту тізіміне қосылыңыз — Sunnad іске қосылғанда хабарлаймыз.",
    emailPlaceholder: "сіздің@email.com",
    submit: "Тіркелу",
    submitting: "Тіркелуде...",
    successTitle: "Сіз тізімдесіз! 🎉",
    successMessage: "Sunnad жүктеуге дайын болғанда сізге хат жібереміз.",
    alreadyTitle: "Сіз бұрыннан тіркелгенсіз!",
    alreadyMessage: "Бұл email біздің күту тізімінде бар. Жақында хабарласамыз.",
    errorTitle: "Бір нәрсе дұрыс болмады",
    errorMessage: "Бір минуттан кейін қайталап көріңіз.",
    rateLimitTitle: "Баяулатыңыз",
    rateLimitMessage: "Қайта көріспес бұрын бірнеше минут күтіңіз.",
    turnstileExpired: "Қауіпсіздік тексерісі аяқталды. Қайталап көріңіз.",
  },
  footer: {
    tagline: "Пайдалы әдеттерді бірге қалыптастырыңыз.",
    terms: "Қызмет көрсету шарттары",
    privacy: "Құпиялылық саясаты",
    madeWith: "Үмметке қамқорлықпен жасалған",
  },
  picker: {
    title: "Стильді таңдаңыз",
    subtitle: "Sunnad лендинг бетінің бес бірегей дизайнын зерттеңіз.",
    explore: "Ашу",
  },
  locale: {
    switchLabel: "Тіл",
    en: "English",
    ru: "Русский",
    kk: "Қазақша",
  },
};

/* ------------------------------------------------------------------ */
/*  Export                                                             */
/* ------------------------------------------------------------------ */
const dictionaries: Record<Locale, Dictionary> = { en, ru, kk };

export function getDictionary(locale: Locale): Dictionary {
  return dictionaries[locale] ?? dictionaries.en;
}
