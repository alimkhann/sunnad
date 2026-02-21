import { createClient } from "@supabase/supabase-js";
import { adminConfig, hasAdminConfig } from "@/lib/config";

let browserClient: ReturnType<typeof createClient> | null = null;

export function getSupabaseBrowserClient(): ReturnType<
  typeof createClient
> | null {
  if (browserClient) {
    return browserClient;
  }

  if (!hasAdminConfig()) {
    return null;
  }

  browserClient = createClient(
    adminConfig.supabaseURL,
    adminConfig.supabaseAnonKey,
    {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true,
      },
    },
  );

  return browserClient;
}
