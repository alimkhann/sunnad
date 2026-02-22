/* ── Minimal i18n: types + utilities ── */

export const locales = ["en", "ru", "kk"] as const;
export type Locale = (typeof locales)[number];

export const variantIds = [
  "1",
  "2",
  "3",
  "4",
  "5",
  "6",
  "7",
  "8",
  "9",
  "10",
  "11",
  "12",
  "13",
  "14",
  "15",
] as const;
export type VariantId = (typeof variantIds)[number];

export function isLocale(v: string): v is Locale {
  return (locales as readonly string[]).includes(v);
}

export function isVariantId(v: string): v is VariantId {
  return (variantIds as readonly string[]).includes(v);
}

/* Minimal shared translations — only for picker + legal page shells */
const shared = {
  en: {
    picker: {
      title: "Sunnad — Choose Your Experience",
      subtitle:
        "Five unique designs, one mission. Pick the one that speaks to you.",
      explore: "Explore",
    },
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
    picker: {
      title: "Sunnad — Выберите свой стиль",
      subtitle:
        "Пять уникальных дизайнов, одна миссия. Выберите тот, что вам ближе.",
      explore: "Смотреть",
    },
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
    picker: {
      title: "Sunnad — Өз тәжірибеңізді таңдаңыз",
      subtitle: "Бес бірегей дизайн, бір мақсат. Өзіңізге жақынын таңдаңыз.",
      explore: "Көру",
    },
    legal: {
      terms: "Пайдалану шарттары",
      privacy: "Құпиялылық саясаты",
      back: "Артқа",
    },
    locale: { switchLabel: "Тіл", en: "English", ru: "Русский", kk: "Қазақша" },
  },
} as const;

export interface SharedDict {
  picker: { title: string; subtitle: string; explore: string };
  legal: { terms: string; privacy: string; back: string };
  locale: { switchLabel: string; en: string; ru: string; kk: string };
}

export function getSharedDict(locale: string): SharedDict {
  if (locale in shared) return shared[locale as Locale];
  return shared.en;
}
