import { createClient } from "@supabase/supabase-js";
import { adminConfig, assertAdminConfig } from "@/lib/config";

let browserClient: ReturnType<typeof createClient> | null = null;

export function getSupabaseBrowserClient(): ReturnType<typeof createClient> {
  if (browserClient) {
    return browserClient;
  }

  assertAdminConfig();
  browserClient = createClient(adminConfig.supabaseURL, adminConfig.supabaseAnonKey, {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true,
    },
  });

  return browserClient;
}
