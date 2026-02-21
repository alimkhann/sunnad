export const locales = ["en", "ru", "kk"] as const;

export type Locale = (typeof locales)[number];

export const defaultLocale: Locale = "en";

export function isLocale(value: string): value is Locale {
  return locales.includes(value as Locale);
}

export type Dictionary = {
  appName: string;
  header: {
    badge: string;
    title: string;
    subtitle: string;
  };
  auth: {
    title: string;
    hint: string;
    configError: string;
    emailLabel: string;
    emailPlaceholder: string;
    sendMagicLink: string;
  };
  list: {
    title: string;
    hint: string;
    empty: string;
    pinnedDays: string;
  };
  editor: {
    createTitle: string;
    editTitle: string;
    hint: string;
    statusLabel: string;
    quotePlaceholder: string;
    sourcePlaceholder: string;
    dayOverrideTitle: string;
  };
  locales: {
    en: string;
    ru: string;
    kk: string;
  };
  status: {
    draft: string;
    approved: string;
    archived: string;
  };
  actions: {
    refresh: string;
    signOut: string;
    newSet: string;
    generateDrafts: string;
    createSet: string;
    saveChanges: string;
    approve: string;
    pinDay: string;
    unpinDay: string;
  };
  messages: {
    magicLinkSent: string;
    signedOut: string;
    translated: string;
    created: string;
    saved: string;
    approved: string;
    dayPinned: string;
    dayUnpinned: string;
  };
  errors: {
    signInFailed: string;
    signOutFailed: string;
    loadFailed: string;
    saveFailed: string;
    translationFailed: string;
    approveFailed: string;
    pinFailed: string;
    unpinFailed: string;
    selectSetFirst: string;
    dayRequired: string;
    kazakhRequired: string;
  };
  translationContext: string;
};

const dictionaries: Record<Locale, Dictionary> = {
  en: {
    appName: "Sunnad Quotes Admin",
    header: {
      badge: "Internal",
      title: "Quote Editorial Panel",
      subtitle: "Create, translate, approve and pin one global quote per day.",
    },
    auth: {
      title: "Sign in",
      hint: "This admin panel is restricted to allowlisted admins.",
      configError: "Missing NEXT_PUBLIC_SUPABASE_URL or NEXT_PUBLIC_SUPABASE_ANON_KEY. Configure env vars first.",
      emailLabel: "Admin email",
      emailPlaceholder: "editor@example.com",
      sendMagicLink: "Send magic link",
    },
    list: {
      title: "Quote Sets",
      hint: "Select an existing set or create a new one.",
      empty: "No quote sets yet.",
      pinnedDays: "Pinned days",
    },
    editor: {
      createTitle: "Create quote set",
      editTitle: "Edit quote set",
      hint: "Kazakh is primary. EN/RU can be generated then edited.",
      statusLabel: "Status",
      quotePlaceholder: "Quote text",
      sourcePlaceholder: "Source (optional)",
      dayOverrideTitle: "Day override (global)",
    },
    locales: {
      en: "English",
      ru: "Russian",
      kk: "Kazakh",
    },
    status: {
      draft: "Draft",
      approved: "Approved",
      archived: "Archived",
    },
    actions: {
      refresh: "Refresh",
      signOut: "Sign out",
      newSet: "New set",
      generateDrafts: "Generate EN/RU drafts",
      createSet: "Create",
      saveChanges: "Save",
      approve: "Approve",
      pinDay: "Pin day",
      unpinDay: "Unpin day",
    },
    messages: {
      magicLinkSent: "Magic link sent to your email.",
      signedOut: "Signed out.",
      translated: "Draft translations updated.",
      created: "Quote set created.",
      saved: "Changes saved.",
      approved: "Quote set approved.",
      dayPinned: "Day override saved.",
      dayUnpinned: "Day override removed.",
    },
    errors: {
      signInFailed: "Sign in failed.",
      signOutFailed: "Sign out failed.",
      loadFailed: "Could not load quote sets.",
      saveFailed: "Could not save quote set.",
      translationFailed: "Could not generate translations.",
      approveFailed: "Could not approve quote set.",
      pinFailed: "Could not pin day override.",
      unpinFailed: "Could not remove day override.",
      selectSetFirst: "Select or create a quote set first.",
      dayRequired: "Select a date first.",
      kazakhRequired: "Kazakh quote is required.",
    },
    translationContext: "Translate for a respectful Islamic habits app. Keep meaning faithful.",
  },
  ru: {
    appName: "Sunnad Quotes Admin",
    header: {
      badge: "Внутренний",
      title: "Редакция цитат",
      subtitle: "Создание, перевод, утверждение и закрепление одной глобальной цитаты на день.",
    },
    auth: {
      title: "Вход",
      hint: "Доступ только для администраторов из allowlist.",
      configError: "Отсутствуют NEXT_PUBLIC_SUPABASE_URL или NEXT_PUBLIC_SUPABASE_ANON_KEY. Сначала настройте env.",
      emailLabel: "Email администратора",
      emailPlaceholder: "editor@example.com",
      sendMagicLink: "Отправить magic link",
    },
    list: {
      title: "Наборы цитат",
      hint: "Выберите существующий набор или создайте новый.",
      empty: "Наборов пока нет.",
      pinnedDays: "Закреплённые дни",
    },
    editor: {
      createTitle: "Создать набор цитат",
      editTitle: "Редактировать набор цитат",
      hint: "Основной язык — казахский. EN/RU можно сгенерировать и править.",
      statusLabel: "Статус",
      quotePlaceholder: "Текст цитаты",
      sourcePlaceholder: "Источник (необязательно)",
      dayOverrideTitle: "Переопределение дня (глобально)",
    },
    locales: {
      en: "Английский",
      ru: "Русский",
      kk: "Казахский",
    },
    status: {
      draft: "Черновик",
      approved: "Утверждено",
      archived: "Архив",
    },
    actions: {
      refresh: "Обновить",
      signOut: "Выйти",
      newSet: "Новый набор",
      generateDrafts: "Сгенерировать EN/RU",
      createSet: "Создать",
      saveChanges: "Сохранить",
      approve: "Утвердить",
      pinDay: "Закрепить день",
      unpinDay: "Снять закрепление",
    },
    messages: {
      magicLinkSent: "Magic link отправлен на email.",
      signedOut: "Вы вышли из системы.",
      translated: "Черновые переводы обновлены.",
      created: "Набор цитат создан.",
      saved: "Изменения сохранены.",
      approved: "Набор цитат утверждён.",
      dayPinned: "Закрепление дня сохранено.",
      dayUnpinned: "Закрепление дня удалено.",
    },
    errors: {
      signInFailed: "Ошибка входа.",
      signOutFailed: "Ошибка выхода.",
      loadFailed: "Не удалось загрузить наборы цитат.",
      saveFailed: "Не удалось сохранить набор цитат.",
      translationFailed: "Не удалось сгенерировать переводы.",
      approveFailed: "Не удалось утвердить набор цитат.",
      pinFailed: "Не удалось закрепить день.",
      unpinFailed: "Не удалось снять закрепление дня.",
      selectSetFirst: "Сначала выберите или создайте набор.",
      dayRequired: "Сначала выберите дату.",
      kazakhRequired: "Текст на казахском обязателен.",
    },
    translationContext: "Перевод для исламского приложения привычек. Сохраняй точный смысл.",
  },
  kk: {
    appName: "Sunnad Quotes Admin",
    header: {
      badge: "Ішкі",
      title: "Дәйексөз редакция панелі",
      subtitle: "Бір күнге ортақ дәйексөзді жасау, аудару, бекіту және күнге бекіту.",
    },
    auth: {
      title: "Кіру",
      hint: "Қолжетімділік тек allowlist-тегі әкімшілерге берілген.",
      configError: "NEXT_PUBLIC_SUPABASE_URL немесе NEXT_PUBLIC_SUPABASE_ANON_KEY жоқ. Алдымен env баптаңыз.",
      emailLabel: "Әкімші email",
      emailPlaceholder: "editor@example.com",
      sendMagicLink: "Magic link жіберу",
    },
    list: {
      title: "Дәйексөз жиындары",
      hint: "Бар жиынды таңдаңыз немесе жаңасын жасаңыз.",
      empty: "Әзірге жиын жоқ.",
      pinnedDays: "Бекітілген күндер",
    },
    editor: {
      createTitle: "Дәйексөз жиынын құру",
      editTitle: "Дәйексөз жиынын өңдеу",
      hint: "Негізгі тіл — қазақша. EN/RU нобайларын жасап, өңдеуге болады.",
      statusLabel: "Күйі",
      quotePlaceholder: "Дәйексөз мәтіні",
      sourcePlaceholder: "Дереккөз (міндетті емес)",
      dayOverrideTitle: "Күнді бекіту (жалпы)",
    },
    locales: {
      en: "Ағылшын",
      ru: "Орыс",
      kk: "Қазақ",
    },
    status: {
      draft: "Нобай",
      approved: "Бекітілді",
      archived: "Мұрағат",
    },
    actions: {
      refresh: "Жаңарту",
      signOut: "Шығу",
      newSet: "Жаңа жиын",
      generateDrafts: "EN/RU нобайын жасау",
      createSet: "Құру",
      saveChanges: "Сақтау",
      approve: "Бекіту",
      pinDay: "Күнді бекіту",
      unpinDay: "Бекітуді алу",
    },
    messages: {
      magicLinkSent: "Magic link email-ге жіберілді.",
      signedOut: "Жүйеден шықтыңыз.",
      translated: "Аударма нобайлары жаңартылды.",
      created: "Дәйексөз жиыны құрылды.",
      saved: "Өзгерістер сақталды.",
      approved: "Дәйексөз жиыны бекітілді.",
      dayPinned: "Күнге бекіту сақталды.",
      dayUnpinned: "Күнге бекіту алынды.",
    },
    errors: {
      signInFailed: "Кіру қатесі.",
      signOutFailed: "Шығу қатесі.",
      loadFailed: "Дәйексөз жиындарын жүктеу мүмкін болмады.",
      saveFailed: "Дәйексөз жиынын сақтау мүмкін болмады.",
      translationFailed: "Аударманы жасау мүмкін болмады.",
      approveFailed: "Дәйексөз жиынын бекіту мүмкін болмады.",
      pinFailed: "Күнді бекіту мүмкін болмады.",
      unpinFailed: "Күн бекітуді алып тастау мүмкін болмады.",
      selectSetFirst: "Алдымен жиынды таңдаңыз немесе жасаңыз.",
      dayRequired: "Алдымен күнді таңдаңыз.",
      kazakhRequired: "Қазақша мәтін міндетті.",
    },
    translationContext: "Исламдық әдеттер қосымшасына арналған аударма. Мағынасын дәл сақта.",
  },
};

export function getDictionary(locale: Locale): Dictionary {
  return dictionaries[locale];
}
