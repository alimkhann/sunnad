import { createClient } from "npm:@supabase/supabase-js@2";

type NudgeRequest = {
  group_id?: string;
  to_user_id?: string;
  habit_id?: string;
};

type NudgeResponse =
  | { status: "sent"; nudge_id: string; delivered: boolean }
  | { status: "duplicate"; nudge_id?: string }
  | { status: "forbidden"; error: string }
  | { status: "error"; error: string };

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") {
    return json({ status: "error", error: "Method not allowed" }, 405);
  }

  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const oneSignalAppID = Deno.env.get("ONESIGNAL_APP_ID");
  const oneSignalRESTAPIKey = Deno.env.get("ONESIGNAL_REST_API_KEY");
  const authorization = req.headers.get("Authorization");

  if (!supabaseURL || !supabaseAnonKey || !serviceRoleKey) {
    return json({ status: "error", error: "Function is not configured" }, 500);
  }

  if (!oneSignalAppID || !oneSignalRESTAPIKey) {
    return json({ status: "error", error: "Push credentials are not configured" }, 500);
  }

  if (!authorization) {
    return json({ status: "error", error: "Missing authorization" }, 401);
  }

  let payload: NudgeRequest;
  try {
    payload = await req.json();
  } catch {
    return json({ status: "error", error: "Invalid request body" }, 400);
  }

  const { group_id, to_user_id, habit_id } = payload;
  if (!group_id || !to_user_id || !habit_id) {
    return json({ status: "error", error: "group_id, to_user_id, habit_id are required" }, 400);
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
    return json({ status: "error", error: "Unauthorized" }, 401);
  }

  const senderID = user.id;
  const admin = createClient(supabaseURL, serviceRoleKey);

  const senderMembership = await admin
    .from("group_members")
    .select("group_id")
    .eq("group_id", group_id)
    .eq("user_id", senderID)
    .maybeSingle();

  if (senderMembership.error || !senderMembership.data) {
    return json({ status: "forbidden", error: "Sender is not a group member" }, 403);
  }

  const recipientMembership = await admin
    .from("group_members")
    .select("group_id")
    .eq("group_id", group_id)
    .eq("user_id", to_user_id)
    .maybeSingle();

  if (recipientMembership.error || !recipientMembership.data) {
    return json({ status: "forbidden", error: "Recipient is not a group member" }, 403);
  }

  const sharedHabit = await admin
    .from("group_shared_habits")
    .select("group_id")
    .eq("group_id", group_id)
    .eq("user_id", to_user_id)
    .eq("habit_id", habit_id)
    .eq("shared", true)
    .maybeSingle();

  if (sharedHabit.error || !sharedHabit.data) {
    return json({ status: "forbidden", error: "Habit is not shared by recipient in this group" }, 403);
  }

  const todayUTC = new Date().toISOString().slice(0, 10);
  const nudgeInsert = await admin
    .from("nudges")
    .insert({
      group_id,
      from_user_id: senderID,
      to_user_id,
      habit_id,
      day: todayUTC,
    })
    .select("id")
    .single();

  if (nudgeInsert.error) {
    if (nudgeInsert.error.code === "23505") {
      return json({ status: "duplicate" }, 200);
    }
    return json({ status: "error", error: nudgeInsert.error.message }, 500);
  }

  const habitResult = await admin
    .from("habits")
    .select("name")
    .eq("id", habit_id)
    .maybeSingle();

  const habitName = habitResult.data?.name ?? "your habit";
  const notificationBody = pickFriendlyNudgeBody({
    habitName,
    groupID: group_id,
    senderID,
    recipientID: to_user_id,
    dayUTC: todayUTC,
  });

  const tokensResult = await admin
    .from("device_tokens")
    .select("onesignal_subscription_id")
    .eq("user_id", to_user_id)
    .not("onesignal_subscription_id", "is", null);

  if (tokensResult.error) {
    return json({ status: "error", error: tokensResult.error.message }, 500);
  }

  const subscriptionIDs = Array.from(
    new Set(
      (tokensResult.data ?? [])
        .map((row) => row.onesignal_subscription_id)
        .filter((value): value is string => typeof value === "string" && value.length > 0),
    ),
  );

  if (subscriptionIDs.length === 0) {
    return json({ status: "sent", nudge_id: nudgeInsert.data.id, delivered: false }, 200);
  }

  const pushResponse = await fetch("https://api.onesignal.com/notifications", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Basic ${oneSignalRESTAPIKey}`,
    },
    body: JSON.stringify({
      app_id: oneSignalAppID,
      include_subscription_ids: subscriptionIDs,
      headings: { en: "Sunnad" },
      contents: { en: notificationBody },
      data: {
        type: "group_nudge",
        group_id,
        habit_id,
      },
    }),
  });

  if (!pushResponse.ok) {
    const message = await pushResponse.text();
    return json({ status: "error", error: `Push send failed: ${message}` }, 502);
  }

  return json({ status: "sent", nudge_id: nudgeInsert.data.id, delivered: true }, 200);
});

function json(body: NudgeResponse, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
    },
  });
}

type NudgeMessageSeed = {
  habitName: string;
  groupID: string;
  senderID: string;
  recipientID: string;
  dayUTC: string;
};

function pickFriendlyNudgeBody(seed: NudgeMessageSeed): string {
  const safeHabitName = sanitizeHabitName(seed.habitName);
  const variants = [
    `A gentle reminder from your Sunnad group: ${safeHabitName}.`,
    `Your group is cheering you on. Time for: ${safeHabitName}.`,
    `Quick nudge from your Sunnad group: ${safeHabitName}.`,
    `Kind reminder from a friend: ${safeHabitName}.`,
    `Small step, big barakah inshaAllah: ${safeHabitName}.`,
  ];

  const key = `${seed.groupID}|${seed.senderID}|${seed.recipientID}|${seed.dayUTC}|${safeHabitName.toLowerCase()}`;
  const index = stableIndex(key, variants.length);
  return variants[index];
}

function sanitizeHabitName(name: string): string {
  const trimmed = name.trim().replace(/\s+/g, " ");
  if (!trimmed) {
    return "your habit";
  }

  return trimmed.length > 80 ? `${trimmed.slice(0, 77)}...` : trimmed;
}

function stableIndex(seed: string, modulo: number): number {
  let hash = 0;
  for (let i = 0; i < seed.length; i += 1) {
    hash = (hash * 31 + seed.charCodeAt(i)) >>> 0;
  }
  return modulo > 0 ? hash % modulo : 0;
}
