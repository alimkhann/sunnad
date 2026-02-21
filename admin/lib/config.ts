export const adminConfig = {
  supabaseURL: process.env.NEXT_PUBLIC_SUPABASE_URL ?? "",
  supabaseAnonKey: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? "",
};

export function hasAdminConfig(): boolean {
  return Boolean(adminConfig.supabaseURL && adminConfig.supabaseAnonKey);
}

export function assertAdminConfig(): void {
  if (!adminConfig.supabaseURL || !adminConfig.supabaseAnonKey) {
    throw new Error("Missing NEXT_PUBLIC_SUPABASE_URL or NEXT_PUBLIC_SUPABASE_ANON_KEY");
  }
}
