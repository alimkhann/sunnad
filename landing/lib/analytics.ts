/**
 * Analytics stub — captures are no-ops until a provider is wired in.
 */
export function captureLandingEvent(
  _event: string,
  _properties: Record<string, unknown> = {},
): void {
  // No-op: analytics provider removed.
}
