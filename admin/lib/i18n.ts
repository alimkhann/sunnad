export const locales = ["en", "ru", "kk"] as const;

export type Locale = (typeof locales)[number];

export const defaultLocale: Locale = "en";

export function isLocale(value: string): value is Locale {
  return locales.includes(value as Locale);
}

export type Dictionary = {
  appName: string;
  badge: string;
  title: string;
  subtitle: string;
  loginTitle: string;
  loginHint: string;
  editorCardTitle: string;
  editorCardHint: string;
  quotesCardTitle: string;
  quotesCardHint: string;
  actions: {
    signIn: string;
    openDashboard: string;
  };
};

const dictionaries: Record<Locale, Dictionary> = {
  en: {
    appName: "Sunnad Quotes Admin",
    badge: "Internal",
    title: "Daily quote control for everyone",
    subtitle: "Secure panel for editors. Draft, approve and pin quote sets by date.",
    loginTitle: "Sign in to continue",
    loginHint: "Access is restricted to allowlisted admins.",
    editorCardTitle: "Multilingual editing",
    editorCardHint: "Kazakh-first workflow with English and Russian drafts.",
    quotesCardTitle: "Global day control",
    quotesCardHint: "One quote set per day for all users in Asia/Almaty timezone.",
    actions: {
      signIn: "Sign in",
      openDashboard: "Open dashboard"
    }
  },
  ru: {
    appName: "Sunnad Quotes Admin",
    badge: "Внутренний",
    title: "Управление цитатой дня для всех",
    subtitle: "Безопасная панель для редакторов: черновики, утверждение и закрепление по дате.",
    loginTitle: "Войдите, чтобы продолжить",
    loginHint: "Доступ только для администраторов из allowlist.",
    editorCardTitle: "Редактирование на 3 языках",
    editorCardHint: "Основной язык — казахский, черновики для английского и русского.",
    quotesCardTitle: "Глобальный контроль дня",
    quotesCardHint: "Один набор цитат на день для всех пользователей (Asia/Almaty).",
    actions: {
      signIn: "Войти",
      openDashboard: "Открыть панель"
    }
  },
  kk: {
    appName: "Sunnad Quotes Admin",
    badge: "Ішкі",
    title: "Барлық қолданушыға күн дәйексөзін басқару",
    subtitle: "Редакторларға арналған қауіпсіз панель: нобай, бекіту және күнге бекіту.",
    loginTitle: "Жалғастыру үшін кіріңіз",
    loginHint: "Қолжетімділік тек allowlist-тегі әкімшілерге ашық.",
    editorCardTitle: "3 тілде редакциялау",
    editorCardHint: "Негізгі тіл — қазақша, ағылшын және орысша нобайлар автоматты жасалады.",
    quotesCardTitle: "Күндік жаһандық басқару",
    quotesCardHint: "Asia/Almaty бойынша барлық қолданушыға бір күнде бір дәйексөз жиыны.",
    actions: {
      signIn: "Кіру",
      openDashboard: "Панельді ашу"
    }
  }
};

export function getDictionary(locale: Locale): Dictionary {
  return dictionaries[locale];
}
