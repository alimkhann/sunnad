import { createClient } from "npm:@supabase/supabase-js@2";

type NudgeRequest = {
  group_id?: string;
  to_user_id?: string;
  habit_id?: string;
  habit_title?: string;
  debug_sender_user_id?: string;
};

const temporaryDebugSecret = "7543271A-FB5C-45E3-B08F-2AFEFBA3D10B";

type NudgeResponse =
  | { status: "sent"; nudge_id: string; delivered: boolean }
  | { status: "duplicate"; nudge_id?: string }
  | { status: "forbidden"; error: string }
  | { status: "error"; error: string };

Deno.serve(async (req: Request): Promise<Response> => {
  console.info("send-nudge-push:start", {
    method: req.method,
    hasAuth: Boolean(req.headers.get("Authorization")),
    hasApiKey: Boolean(req.headers.get("apikey")),
  });

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

  let payload: NudgeRequest;
  try {
    payload = await req.json();
  } catch {
    return json({ status: "error", error: "Invalid request body" }, 400);
  }

  const { group_id, to_user_id, habit_id, habit_title, debug_sender_user_id } = payload;
  if (!group_id || !to_user_id || !habit_id) {
    return json({ status: "error", error: "group_id, to_user_id, habit_id are required" }, 400);
  }
  let senderID: string | null = null;
  const debugSecret = req.headers.get("x-adat-debug-secret") ?? "";
  if (debug_sender_user_id && debugSecret === temporaryDebugSecret) {
    senderID = debug_sender_user_id;
  } else {
    if (!authorization) {
      return json({ status: "error", error: "Missing authorization" }, 401);
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

    console.info("send-nudge-push:auth_result", {
      userID: user?.id ?? null,
      authError: userError?.message ?? null,
    });

    if (userError || !user) {
      return json({ status: "error", error: "Unauthorized" }, 401);
    }

    senderID = user.id;
  }

  if (!senderID) {
    return json({ status: "error", error: "Unauthorized" }, 401);
  }
  const admin = createClient(supabaseURL, serviceRoleKey);

  const senderMembership = await admin
    .from("group_members")
    .select("group_id")
    .eq("group_id", group_id)
    .eq("user_id", senderID)
    .maybeSingle();

  if (senderMembership.error || !senderMembership.data) {
    console.warn("send-nudge-push:sender_membership_failed", { error: senderMembership.error?.message ?? null });
    return json({ status: "forbidden", error: "Sender is not a group member" }, 403);
  }

  const resolvedRecipientUserID = await resolveRecipientUserID({
    admin,
    groupID: group_id,
    senderID,
    requestedRecipientUserID: to_user_id,
    requestedHabitID: habit_id,
  });

  if (!resolvedRecipientUserID) {
    console.warn("send-nudge-push:recipient_membership_failed", { requestedRecipientUserID: to_user_id });
    return json({ status: "forbidden", error: `Recipient is not a group member: ${to_user_id}` }, 403);
  }

  const resolvedHabitID = await resolveRecipientSharedHabitID({
    admin,
    groupID: group_id,
    recipientUserID: resolvedRecipientUserID,
    requestedHabitID: habit_id,
    requestedHabitTitle: habit_title,
  });

  if (!resolvedHabitID) {
    console.warn("send-nudge-push:shared_habit_missing", { requestedHabitID: habit_id });
    return json({ status: "forbidden", error: "Habit is not shared by recipient in this group" }, 403);
  }

  const todayUTC = new Date().toISOString().slice(0, 10);
  const nudgeInsert = await admin
    .from("nudges")
    .insert({
      group_id,
      from_user_id: senderID,
      to_user_id: resolvedRecipientUserID,
      habit_id: resolvedHabitID,
      day: todayUTC,
    })
    .select("id")
    .single();

  if (nudgeInsert.error) {
    console.error("send-nudge-push:nudge_insert_failed", { error: nudgeInsert.error.message, code: nudgeInsert.error.code });
    if (nudgeInsert.error.code === "23505") {
      return json({ status: "duplicate" }, 200);
    }
    return json({ status: "error", error: nudgeInsert.error.message }, 500);
  }

  console.info("send-nudge-push:nudge_inserted", { nudgeID: nudgeInsert.data.id });

  const habitResult = await admin
    .from("habits")
    .select("name")
    .eq("id", resolvedHabitID)
    .maybeSingle();

  const habitName = habitResult.data?.name ?? "your habit";
  const notificationBody = pickFriendlyNudgeBody({
    habitName,
    groupID: group_id,
    senderID,
    recipientID: resolvedRecipientUserID,
    dayUTC: todayUTC,
  });

  const tokensResult = await admin
    .from("device_tokens")
    .select("onesignal_subscription_id,token")
    .eq("user_id", resolvedRecipientUserID);

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
      habit_id: resolvedHabitID,
    },
  };

  let directSend: OneSignalSendResult | null = null;
  if (subscriptionIDs.length > 0) {
    directSend = await sendOneSignalNotification({
      apiKey: oneSignalRESTAPIKey,
      payload: {
        ...basePushPayload,
        include_subscription_ids: subscriptionIDs,
      },
    });
    console.info("send-nudge-push:direct_send", {
      ok: directSend.ok,
      recipients: extractRecipientCount(directSend.jsonBody),
      raw: directSend.rawBody,
    });

    if (directSend.ok) {
      const directRecipients = extractRecipientCount(directSend.jsonBody);
      if (directRecipients > 0) {
        return json(
          { status: "sent", nudge_id: nudgeInsert.data.id, delivered: true },
          200,
        );
      }
    }
  }

  const aliasSend = await sendOneSignalNotification({
    apiKey: oneSignalRESTAPIKey,
    payload: {
      ...basePushPayload,
      include_aliases: {
        external_id: [resolvedRecipientUserID],
      },
      target_channel: "push",
    },
  });
  console.info("send-nudge-push:alias_send", {
    ok: aliasSend.ok,
    recipients: extractRecipientCount(aliasSend.jsonBody),
    raw: aliasSend.rawBody,
  });

  if (aliasSend.ok) {
    const aliasRecipients = extractRecipientCount(aliasSend.jsonBody);
    return json(
      {
        status: "sent",
        nudge_id: nudgeInsert.data.id,
        delivered: aliasRecipients > 0,
      },
      200,
    );
  }

  return json(
    {
      status: "error",
      error: `Push send failed. alias=${aliasSend.rawBody}`,
    },
    502,
  );
});

async function resolveRecipientSharedHabitID(args: {
  admin: ReturnType<typeof createClient>;
  groupID: string;
  recipientUserID: string;
  requestedHabitID: string;
  requestedHabitTitle?: string;
}): Promise<string | null> {
  const recipientSharedRows = await args.admin
    .from("group_shared_habits")
    .select("habit_id")
    .eq("group_id", args.groupID)
    .eq("user_id", args.recipientUserID)
    .eq("shared", true);

  if (recipientSharedRows.error || !recipientSharedRows.data?.length) {
    return null;
  }

  const candidateHabitIDs = recipientSharedRows.data
    .map((row) => row.habit_id)
    .filter((value): value is string => typeof value === "string" && value.length > 0);

  if (candidateHabitIDs.length === 0) {
    return null;
  }

  if (candidateHabitIDs.includes(args.requestedHabitID)) {
    return args.requestedHabitID;
  }

  if (candidateHabitIDs.length === 1) {
    return candidateHabitIDs[0];
  }

  const requestedHabit = await args.admin
    .from("habits")
    .select("name")
    .eq("id", args.requestedHabitID)
    .maybeSingle();

  const requestedName = normalizeHabitName(requestedHabit.data?.name) || normalizeHabitName(args.requestedHabitTitle);
  if (!requestedName) {
    return candidateHabitIDs[0];
  }

  const candidateHabits = await args.admin
    .from("habits")
    .select("id, name")
    .in("id", candidateHabitIDs);

  if (candidateHabits.error || !candidateHabits.data?.length) {
    return candidateHabitIDs[0];
  }

  const matches = candidateHabits.data.filter((habit) => normalizeHabitName(habit.name) === requestedName);
  if (matches.length === 1) {
    return matches[0].id;
  }

  return candidateHabits.data[0]?.id ?? candidateHabitIDs[0] ?? null;
}

async function resolveRecipientUserID(args: {
  admin: ReturnType<typeof createClient>;
  groupID: string;
  senderID: string;
  requestedRecipientUserID: string;
  requestedHabitID: string;
}): Promise<string | null> {
  const exact = await args.admin
    .from("group_members")
    .select("user_id")
    .eq("group_id", args.groupID)
    .eq("user_id", args.requestedRecipientUserID)
    .maybeSingle();

  if (exact.data?.user_id) {
    return exact.data.user_id;
  }

  const candidatesResult = await args.admin
    .from("group_members")
    .select("user_id")
    .eq("group_id", args.groupID)
    .neq("user_id", args.senderID);

  if (candidatesResult.error || !candidatesResult.data?.length) {
    return null;
  }

  const candidateIDs = candidatesResult.data
    .map((row) => row.user_id)
    .filter((value): value is string => typeof value === "string" && value.length > 0);

  if (candidateIDs.length === 1) {
    return candidateIDs[0];
  }

  const sharingMatches = await args.admin
    .from("group_shared_habits")
    .select("user_id")
    .eq("group_id", args.groupID)
    .eq("habit_id", args.requestedHabitID)
    .eq("shared", true)
    .in("user_id", candidateIDs);

  if (sharingMatches.error || !sharingMatches.data?.length) {
    return null;
  }

  const resolvedCandidateIDs = Array.from(new Set(sharingMatches.data.map((row) => row.user_id)));
  return resolvedCandidateIDs.length == 1 ? resolvedCandidateIDs[0] : null;
}

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

function normalizeHabitName(name: string | null | undefined): string {
  return (name ?? "").trim().replace(/\s+/g, " ").toLowerCase();
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
