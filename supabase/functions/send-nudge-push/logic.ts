export type SupportedLocale = "en" | "ru" | "kk";

export type NudgeRequest = {
  group_id: string;
  to_user_id: string;
  habit_id: string;
};

export function parseNudgeRequest(value: unknown): NudgeRequest | null {
  if (!value || typeof value !== "object") return null;
  const candidate = value as Record<string, unknown>;
  const groupID = normalizedUUID(candidate.group_id);
  const recipientID = normalizedUUID(candidate.to_user_id);
  const habitID = normalizedUUID(candidate.habit_id);
  if (!groupID || !recipientID || !habitID) return null;
  return { group_id: groupID, to_user_id: recipientID, habit_id: habitID };
}

export function normalizeLocale(value: unknown): SupportedLocale {
  return value === "ru" || value === "kk" ? value : "en";
}

export function normalizeTimeZone(value: unknown): string {
  const candidate = typeof value === "string" && value.trim()
    ? value.trim()
    : "UTC";
  try {
    new Intl.DateTimeFormat("en", { timeZone: candidate }).format(new Date());
    return candidate;
  } catch {
    return "UTC";
  }
}

export function localDay(date: Date, timeZone: string): string {
  const parts = new Intl.DateTimeFormat("en", {
    timeZone: normalizeTimeZone(timeZone),
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(date);
  const part = (type: Intl.DateTimeFormatPartTypes): string =>
    parts.find((item) => item.type === type)?.value ?? "00";
  return `${part("year")}-${part("month")}-${part("day")}`;
}

export type APNsEnvironment = "development" | "production";

export function normalizeAPNsToken(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const normalized = value.trim().toLowerCase();
  return /^[0-9a-f]{64}$/.test(normalized) ? normalized : null;
}

export function normalizeAPNsEnvironment(value: unknown): APNsEnvironment {
  return value === "development" ? "development" : "production";
}

export function isInvalidAPNsTokenResponse(
  status: number,
  reason: unknown,
): boolean {
  return status === 410 ||
    (status === 400 &&
      (reason === "BadDeviceToken" || reason === "DeviceTokenNotForTopic"));
}

export function nudgeBody(locale: SupportedLocale, habitName: string): string {
  const safeName = sanitizeHabitName(habitName, locale);
  switch (locale) {
    case "ru":
      return `Небольшое напоминание от вашей группы Adat: ${safeName}.`;
    case "kk":
      return `Adat тобыңыздан жылы еске салу: ${safeName}.`;
    case "en":
      return `A gentle reminder from your Adat group: ${safeName}.`;
  }
}

function sanitizeHabitName(name: string, locale: SupportedLocale): string {
  const trimmed = name.trim().replace(/\s+/g, " ");
  if (!trimmed) {
    return locale === "ru"
      ? "ваша привычка"
      : locale === "kk"
      ? "әдетіңіз"
      : "your habit";
  }
  return trimmed.length > 80 ? `${trimmed.slice(0, 77)}...` : trimmed;
}

function normalizedUUID(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const normalized = value.trim().toLowerCase();
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/
      .test(normalized)
    ? normalized
    : null;
}
