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
    passwordLabel: string;
    passwordPlaceholder: string;
    signInWithPassword: string;
    orUseMagicLink: string;
    orUsePassword: string;
    setPasswordTitle: string;
    newPassword: string;
    newPasswordPlaceholder: string;
    confirmPassword: string;
    confirmPasswordPlaceholder: string;
    setPassword: string;
    passwordSet: string;
    passwordMismatch: string;
    passwordTooShort: string;
    setPasswordFailed: string;
    sessionExpired: string;
  };
  list: {
    title: string;
    hint: string;
    empty: string;
    pinnedDays: string;
    missing: string;
    filterAll: string;
    filterDraft: string;
    filterApproved: string;
    filterArchived: string;
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
    delete: string;
    archive: string;
    verifySource: string;
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
    deleted: string;
    confirmDelete: string;
    confirmDeleteHint: string;
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
    deleteFailed: string;
    verifyFailed: string;
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
      configError:
        "Missing NEXT_PUBLIC_SUPABASE_URL or NEXT_PUBLIC_SUPABASE_ANON_KEY. Configure env vars first.",
      emailLabel: "Admin email",
      emailPlaceholder: "editor@example.com",
      sendMagicLink: "Send magic link",
      passwordLabel: "Password",
      passwordPlaceholder: "Enter password",
      signInWithPassword: "Sign in with password",
      orUseMagicLink: "or use magic link",
      orUsePassword: "or use password",
      setPasswordTitle: "Set password",
      newPassword: "New password",
      newPasswordPlaceholder: "At least 8 characters",
      confirmPassword: "Confirm password",
      confirmPasswordPlaceholder: "Re-enter password",
      setPassword: "Set password",
      passwordSet: "Password set successfully. You can now sign in with password.",
      passwordMismatch: "Passwords do not match.",
      passwordTooShort: "Password must be at least 8 characters.",
      setPasswordFailed: "Could not set password.",
      sessionExpired: "Session expired. Please sign in again.",
    },
    list: {
      title: "Quote Sets",
      hint: "Select an existing set or create a new one.",
      empty: "No quote sets yet.",
      pinnedDays: "Pinned days",
      missing: "(missing)",
      filterAll: "All",
      filterDraft: "Drafts",
      filterApproved: "Approved",
      filterArchived: "Archived",
    },
    editor: {
      createTitle: "Create quote set",
      editTitle: "Edit quote set",
      hint: "Enter any language first. Other translations can be auto-generated.",
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
      generateDrafts: "Generate translations",
      createSet: "Create",
      saveChanges: "Save",
      approve: "Approve",
      pinDay: "Pin day",
      unpinDay: "Unpin day",
      delete: "Delete",
      archive: "Archive",
      verifySource: "Verify source",
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
      deleted: "Quote set permanently deleted.",
      confirmDelete: "Permanently delete this quote set?",
      confirmDeleteHint:
        "This cannot be undone. The quote and all translations will be removed from the database.",
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
      kazakhRequired: "At least one translation is required.",
      deleteFailed: "Could not delete quote set.",
      verifyFailed: "Could not verify source.",
    },
    translationContext:
      "Translate for a respectful Islamic habits app. Keep meaning faithful.",
  },
  ru: {
    appName: "Sunnad Quotes Admin",
    header: {
      badge: "Внутренний",
      title: "Редакция цитат",
      subtitle:
        "Создание, перевод, утверждение и закрепление одной глобальной цитаты на день.",
    },
    auth: {
      title: "Вход",
      hint: "Доступ только для администраторов из allowlist.",
      configError:
        "Отсутствуют NEXT_PUBLIC_SUPABASE_URL или NEXT_PUBLIC_SUPABASE_ANON_KEY. Сначала настройте env.",
      emailLabel: "Email администратора",
      emailPlaceholder: "editor@example.com",
      sendMagicLink: "Отправить magic link",
      passwordLabel: "Пароль",
      passwordPlaceholder: "Введите пароль",
      signInWithPassword: "Войти с паролем",
      orUseMagicLink: "или через magic link",
      orUsePassword: "или через пароль",
      setPasswordTitle: "Установить пароль",
      newPassword: "Новый пароль",
      newPasswordPlaceholder: "Минимум 8 символов",
      confirmPassword: "Подтвердите пароль",
      confirmPasswordPlaceholder: "Повторите пароль",
      setPassword: "Установить пароль",
      passwordSet: "Пароль установлен. Теперь можно входить по паролю.",
      passwordMismatch: "Пароли не совпадают.",
      passwordTooShort: "Пароль должен быть не менее 8 символов.",
      setPasswordFailed: "Не удалось установить пароль.",
      sessionExpired: "Сессия истекла. Войдите снова.",
    },
    list: {
      title: "Наборы цитат",
      hint: "Выберите существующий набор или создайте новый.",
      empty: "Наборов пока нет.",
      pinnedDays: "Закреплённые дни",
      missing: "(отсутствует)",
      filterAll: "Все",
      filterDraft: "Черновики",
      filterApproved: "Утверждённые",
      filterArchived: "Архив",
    },
    editor: {
      createTitle: "Создать набор цитат",
      editTitle: "Редактировать набор цитат",
      hint: "Введите текст на любом языке. Остальные можно сгенерировать.",
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
      generateDrafts: "Сгенерировать переводы",
      createSet: "Создать",
      saveChanges: "Сохранить",
      approve: "Утвердить",
      pinDay: "Закрепить день",
      unpinDay: "Снять закрепление",
      delete: "Удалить",
      archive: "Архивировать",
      verifySource: "Проверить источник",
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
      deleted: "Набор цитат удалён навсегда.",
      confirmDelete: "Удалить этот набор цитат навсегда?",
      confirmDeleteHint:
        "Это действие нельзя отменить. Цитата и все переводы будут удалены из базы данных.",
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
      kazakhRequired: "Нужна хотя бы одна цитата на любом языке.",
      deleteFailed: "Не удалось удалить набор цитат.",
      verifyFailed: "Не удалось проверить источник.",
    },
    translationContext:
      "Перевод для исламского приложения привычек. Сохраняй точный смысл.",
  },
  kk: {
    appName: "Sunnad Quotes Admin",
    header: {
      badge: "Ішкі",
      title: "Дәйексөз редакция панелі",
      subtitle:
        "Бір күнге ортақ дәйексөзді жасау, аудару, бекіту және күнге бекіту.",
    },
    auth: {
      title: "Кіру",
      hint: "Қолжетімділік тек allowlist-тегі әкімшілерге берілген.",
      configError:
        "NEXT_PUBLIC_SUPABASE_URL немесе NEXT_PUBLIC_SUPABASE_ANON_KEY жоқ. Алдымен env баптаңыз.",
      emailLabel: "Әкімші email",
      emailPlaceholder: "editor@example.com",
      sendMagicLink: "Magic link жіберу",
      passwordLabel: "Құпия сөз",
      passwordPlaceholder: "Құпия сөзді енгізіңіз",
      signInWithPassword: "Құпия сөзбен кіру",
      orUseMagicLink: "немесе magic link арқылы",
      orUsePassword: "немесе құпия сөз арқылы",
      setPasswordTitle: "Құпия сөз орнату",
      newPassword: "Жаңа құпия сөз",
      newPasswordPlaceholder: "Кемінде 8 таңба",
      confirmPassword: "Құпия сөзді растау",
      confirmPasswordPlaceholder: "Құпия сөзді қайта енгізіңіз",
      setPassword: "Құпия сөзді орнату",
      passwordSet: "Құпия сөз орнатылды. Енді құпия сөзбен кіруге болады.",
      passwordMismatch: "Құпия сөздер сәйкес келмейді.",
      passwordTooShort: "Құпия сөз кемінде 8 таңба болуы керек.",
      setPasswordFailed: "Құпия сөзді орнату мүмкін болмады.",
      sessionExpired: "Сессия мерзімі аяқталды. Қайта кіріңіз.",
    },
    list: {
      title: "Дәйексөз жиындары",
      hint: "Бар жиынды таңдаңыз немесе жаңасын жасаңыз.",
      empty: "Әзірге жиын жоқ.",
      pinnedDays: "Бекітілген күндер",
      missing: "(жоқ)",
      filterAll: "Барлығы",
      filterDraft: "Нобайлар",
      filterApproved: "Бекітілгендер",
      filterArchived: "Мұрағат",
    },
    editor: {
      createTitle: "Дәйексөз жиынын құру",
      editTitle: "Дәйексөз жиынын өңдеу",
      hint: "Кез келген тілде мәтін енгізіңіз. Қалғандарын автоматты жасауға болады.",
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
      generateDrafts: "Аудармалар жасау",
      createSet: "Құру",
      saveChanges: "Сақтау",
      approve: "Бекіту",
      pinDay: "Күнді бекіту",
      unpinDay: "Бекітуді алу",
      delete: "Жою",
      archive: "Мұрағатқа",
      verifySource: "Дереккөзді тексеру",
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
      deleted: "Дәйексөз жиыны біржола жойылды.",
      confirmDelete: "Бұл дәйексөз жиынын біржола жою керек пе?",
      confirmDeleteHint:
        "Бұл әрекетті қайтару мүмкін емес. Дәйексөз бен барлық аудармалар деректер базасынан жойылады.",
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
      kazakhRequired: "Кемінде бір тілде мәтін керек.",
      deleteFailed: "Дәйексөз жиынын жою мүмкін болмады.",
      verifyFailed: "Дереккөзді тексеру мүмкін болмады.",
    },
    translationContext:
      "Исламдық әдеттер қосымшасына арналған аударма. Мағынасын дәл сақта.",
  },
};

export function getDictionary(locale: Locale): Dictionary {
  return dictionaries[locale];
}
