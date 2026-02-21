import { createClient } from "npm:@supabase/supabase-js@2";

type DeleteAccountResponse = {
  ok: boolean;
  user_id?: string;
  error?: string;
};

type ProfileRow = {
  avatar_path?: string | null;
};

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") {
    return json({ ok: false, error: "Method not allowed" }, 405);
  }

  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const authorization = req.headers.get("Authorization");

  if (!supabaseURL || !supabaseAnonKey || !serviceRoleKey) {
    return json({ ok: false, error: "Function is not configured" }, 500);
  }

  if (!authorization) {
    return json({ ok: false, error: "Missing authorization" }, 401);
  }

  const authClient = createClient(supabaseURL, supabaseAnonKey, {
    global: {
      headers: {
        Authorization: authorization,
      },
    },
  });

  const {
    data: { user },
    error: userError,
  } = await authClient.auth.getUser();

  if (userError || !user) {
    return json({ ok: false, error: "Unauthorized" }, 401);
  }

  const adminClient = createClient(supabaseURL, serviceRoleKey);

  const profileResult = await adminClient
    .from("profiles")
    .select("avatar_path")
    .eq("id", user.id)
    .maybeSingle<ProfileRow>();

  if (profileResult.error && profileResult.error.code !== "PGRST116") {
    return json({ ok: false, error: profileResult.error.message }, 500);
  }

  const avatarPathsToDelete = new Set<string>();
  const avatarPath = profileResult.data?.avatar_path?.trim();
  if (avatarPath && !isExternalAvatarPath(avatarPath)) {
    avatarPathsToDelete.add(avatarPath);
  }

  const avatarFolder = `profiles/${user.id.toLowerCase()}`;
  const folderList = await adminClient.storage
    .from("avatars")
    .list(avatarFolder, { limit: 100, offset: 0 });

  if (folderList.error) {
    return json({ ok: false, error: folderList.error.message }, 500);
  }

  for (const object of folderList.data ?? []) {
    const objectName = object.name?.trim();
    if (!objectName) continue;
    avatarPathsToDelete.add(`${avatarFolder}/${objectName}`);
  }

  if (avatarPathsToDelete.size > 0) {
    const removeResult = await adminClient.storage
      .from("avatars")
      .remove(Array.from(avatarPathsToDelete));

    if (removeResult.error) {
      return json({ ok: false, error: removeResult.error.message }, 500);
    }
  }

  const { error: deleteError } = await adminClient.auth.admin.deleteUser(user.id);

  if (deleteError) {
    return json({ ok: false, error: deleteError.message }, 500);
  }

  return json({ ok: true, user_id: user.id }, 200);
});

function json(body: DeleteAccountResponse, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
    },
  });
}

function isExternalAvatarPath(value: string): boolean {
  const normalized = value.toLowerCase();
  return normalized.startsWith("http://") || normalized.startsWith("https://");
}
