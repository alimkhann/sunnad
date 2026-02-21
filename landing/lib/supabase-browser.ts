import { createClient } from "@supabase/supabase-js";
import { landingConfig, hasSupabaseConfig } from "@/lib/config";

let browserClient: ReturnType<typeof createClient> | null = null;

export function getSupabaseBrowserClient(): ReturnType<typeof createClient> | null {
  if (browserClient) return browserClient;
  if (!hasSupabaseConfig()) return null;

  browserClient = createClient(
    landingConfig.supabaseURL,
    landingConfig.supabaseAnonKey,
    {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
        detectSessionInUrl: false,
      },
    },
  );

  return browserClient;
}
