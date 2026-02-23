/* ── Minimal i18n: types + utilities ── */

export const locales = ["en", "ru", "kk"] as const;
export type Locale = (typeof locales)[number];

export function isLocale(v: string): v is Locale {
  return (locales as readonly string[]).includes(v);
}

/* Minimal shared translations — only for legal page shells */
const shared = {
  en: {
    legal: {
      terms: "Terms of Service",
      privacy: "Privacy Policy",
      back: "Back",
    },
    locale: {
      switchLabel: "Language",
      en: "English",
      ru: "Русский",
      kk: "Қазақша",
    },
  },
  ru: {
    legal: {
      terms: "Условия использования",
      privacy: "Политика конфиденциальности",
      back: "Назад",
    },
    locale: {
      switchLabel: "Язык",
      en: "English",
      ru: "Русский",
      kk: "Қазақша",
    },
  },
  kk: {
    legal: {
      terms: "Пайдалану шарттары",
      privacy: "Құпиялылық саясаты",
      back: "Артқа",
    },
    locale: { switchLabel: "Тіл", en: "English", ru: "Русский", kk: "Қазақша" },
  },
} as const;

export interface SharedDict {
  legal: { terms: string; privacy: string; back: string };
  locale: { switchLabel: string; en: string; ru: string; kk: string };
}

export function getSharedDict(locale: string): SharedDict {
  if (locale in shared) return shared[locale as Locale];
  return shared.en;
}
