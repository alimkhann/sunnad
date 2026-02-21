export const landingConfig = {
  supabaseURL: process.env.NEXT_PUBLIC_SUPABASE_URL ?? "",
  supabaseAnonKey: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? "",
  turnstileSiteKey: process.env.NEXT_PUBLIC_TURNSTILE_SITE_KEY ?? "",
  defaultVariant: process.env.NEXT_PUBLIC_LANDING_DEFAULT_VARIANT ?? "picker",
};

export function hasSupabaseConfig(): boolean {
  return Boolean(landingConfig.supabaseURL && landingConfig.supabaseAnonKey);
}
