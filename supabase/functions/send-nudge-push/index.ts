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
    .select("onesignal_subscription_id,token")
    .eq("user_id", to_user_id);

  if (tokensResult.error) {
    return json({ status: "error", error: tokensResult.error.message }, 500);
  }

  const tokenRows = tokensResult.data ?? [];
  if (tokenRows.length === 0) {
    return json({ status: "sent", nudge_id: nudgeInsert.data.id, delivered: false }, 200);
  }

  const subscriptionIDs = Array.from(
    new Set(
      tokenRows
        .map((row) => normalizeSubscriptionID(row.onesignal_subscription_id, row.token))
        .filter((value): value is string => typeof value === "string" && value.length > 0),
    ),
  );

  const basePushPayload = {
    app_id: oneSignalAppID,
    headings: { en: "Adat" },
    contents: { en: notificationBody },
    data: {
      type: "group_nudge",
      group_id,
      habit_id,
    },
  };

  // Primary path: OneSignal User model via external_id alias targeting.
  const aliasSend = await sendOneSignalNotification({
    apiKey: oneSignalRESTAPIKey,
    payload: {
      ...basePushPayload,
      include_aliases: {
        external_id: [to_user_id],
      },
      target_channel: "push",
    },
  });

  if (aliasSend.ok) {
    const aliasRecipients = extractRecipientCount(aliasSend.jsonBody);
    if (aliasRecipients > 0 || subscriptionIDs.length === 0) {
      return json(
        { status: "sent", nudge_id: nudgeInsert.data.id, delivered: aliasRecipients > 0 },
        200,
      );
    }
  }

  // Legacy fallback during transition: subscription IDs from device_tokens table.
  if (subscriptionIDs.length === 0) {
    return json({ status: "sent", nudge_id: nudgeInsert.data.id, delivered: false }, 200);
  }

  const legacySend = await sendOneSignalNotification({
    apiKey: oneSignalRESTAPIKey,
    payload: {
      ...basePushPayload,
      include_subscription_ids: subscriptionIDs,
    },
  });

  if (!legacySend.ok) {
    const aliasError = aliasSend.ok ? "alias send accepted but recipients=0" : aliasSend.rawBody;
    return json(
      {
        status: "error",
        error: `Push send failed. alias=${aliasError}; legacy=${legacySend.rawBody}`,
      },
      502,
    );
  }

  const legacyRecipients = extractRecipientCount(legacySend.jsonBody);
  return json(
    { status: "sent", nudge_id: nudgeInsert.data.id, delivered: legacyRecipients > 0 },
    200,
  );
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
    `A gentle reminder from your Adat group: ${safeHabitName}.`,
    `Your group is cheering you on. Time for: ${safeHabitName}.`,
    `Quick nudge from your Adat group: ${safeHabitName}.`,
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

function normalizeSubscriptionID(
  oneSignalSubscriptionID: unknown,
  token: unknown,
): string | null {
  const direct = typeof oneSignalSubscriptionID === "string" ? oneSignalSubscriptionID.trim() : "";
  if (direct.length > 0) {
    return direct;
  }

  if (typeof token !== "string") {
    return null;
  }

  const trimmedToken = token.trim();
  if (!trimmedToken) {
    return null;
  }

  const prefixed = "onesignal-subscription:";
  if (trimmedToken.startsWith(prefixed)) {
    const extracted = trimmedToken.slice(prefixed.length).trim();
    return extracted.length > 0 ? extracted : null;
  }

  // Backward compatibility: allow raw token payloads already storing OneSignal subscription ids.
  return trimmedToken;
}

type OneSignalSendArgs = {
  apiKey: string;
  payload: Record<string, unknown>;
};

type OneSignalSendResult = {
  ok: boolean;
  rawBody: string;
  jsonBody: unknown;
};

async function sendOneSignalNotification(args: OneSignalSendArgs): Promise<OneSignalSendResult> {
  const response = await fetch("https://api.onesignal.com/notifications", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Basic ${args.apiKey}`,
    },
    body: JSON.stringify(args.payload),
  });

  const rawBody = await response.text();
  let jsonBody: unknown = null;
  try {
    jsonBody = rawBody.length > 0 ? JSON.parse(rawBody) : null;
  } catch {
    jsonBody = null;
  }

  return {
    ok: response.ok,
    rawBody,
    jsonBody,
  };
}

function extractRecipientCount(payload: unknown): number {
  if (!payload || typeof payload !== "object") return 0;
  const candidates = payload as Record<string, unknown>;
  const recipients = candidates["recipients"];
  if (typeof recipients === "number" && Number.isFinite(recipients)) {
    return Math.max(0, Math.trunc(recipients));
  }
  const total = candidates["total_count"];
  if (typeof total === "number" && Number.isFinite(total)) {
    return Math.max(0, Math.trunc(total));
  }
  return 0;
}
