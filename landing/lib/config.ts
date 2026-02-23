export const landingConfig = {
  supabaseURL: process.env.NEXT_PUBLIC_SUPABASE_URL ?? "",
  supabaseAnonKey: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? "",
  turnstileSiteKey: process.env.NEXT_PUBLIC_TURNSTILE_SITE_KEY ?? "",
};

export function hasSupabaseConfig(): boolean {
  return Boolean(landingConfig.supabaseURL && landingConfig.supabaseAnonKey);
}
