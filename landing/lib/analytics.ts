import posthog from "posthog-js";

const LANDING_SURFACE = "landing";
const LANDING_SCHEMA_VERSION = 2;

function appEnvironment(): string {
  const explicit = process.env.NEXT_PUBLIC_APP_ENV?.trim();
  if (explicit) {
    return explicit;
  }
  return process.env.NODE_ENV === "production" ? "production" : "development";
}

function isTrackingEnabled(): boolean {
  if (typeof window === "undefined") return false;
  return Boolean(process.env.NEXT_PUBLIC_POSTHOG_KEY);
}

export function captureLandingEvent(
  event: string,
  properties: Record<string, unknown> = {},
): void {
  if (!isTrackingEnabled()) return;

  posthog.capture(event, {
    environment: appEnvironment(),
    schema_version: LANDING_SCHEMA_VERSION,
    surface: LANDING_SURFACE,
    ...properties,
  });
}
