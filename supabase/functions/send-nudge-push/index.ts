import { createClient } from "npm:@supabase/supabase-js@2";
import { importPKCS8, SignJWT } from "npm:jose@5.10.0";
import {
  isInvalidAPNsTokenResponse,
  localDay,
  normalizeAPNsEnvironment,
  normalizeAPNsToken,
  normalizeLocale,
  normalizeTimeZone,
  nudgeBody,
  parseNudgeRequest,
} from "./logic.ts";

type AdminClient = ReturnType<typeof createClient<any>>;

type NudgeResponse =
  | { status: "sent"; nudge_id: string; delivered: true }
  | { status: "duplicate"; nudge_id?: string; delivered: false }
  | { status: "recipient_not_registered"; delivered: false }
  | { status: "forbidden"; error: string; delivered: false }
  | { status: "error"; error: string; delivered: false };

type APNsResult = {
  accepted: boolean;
  invalidToken: boolean;
  status: number;
};

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method !== "POST") {
    return respond({
      status: "error",
      error: "Method not allowed",
      delivered: false,
    }, 405);
  }

  const config = readConfig();
  if (!config) {
    return respond({
      status: "error",
      error: "Function is not configured",
      delivered: false,
    }, 500);
  }

  const authorization = request.headers.get("Authorization");
  if (!authorization) {
    return respond(
      { status: "error", error: "Unauthorized", delivered: false },
      401,
    );
  }

  let rawPayload: unknown;
  try {
    rawPayload = await request.json();
  } catch {
    return respond({
      status: "error",
      error: "Invalid request body",
      delivered: false,
    }, 400);
  }
  const payload = parseNudgeRequest(rawPayload);
  if (!payload) {
    return respond({
      status: "error",
      error: "Invalid group, recipient, or habit identifier",
      delivered: false,
    }, 400);
  }

  const authClient = createClient(config.supabaseURL, config.supabaseAnonKey, {
    global: { headers: { Authorization: authorization } },
  });
  const { data: authData, error: authError } = await authClient.auth.getUser();
  if (authError || !authData.user) {
    return respond(
      { status: "error", error: "Unauthorized", delivered: false },
      401,
    );
  }

  const senderID = authData.user.id;
  const admin = createClient(config.supabaseURL, config.serviceRoleKey);

  const authorizationResult = await authorizeNudge(
    admin,
    payload.group_id,
    senderID,
    payload.to_user_id,
    payload.habit_id,
  );
  if (!authorizationResult.ok) {
    if (authorizationResult.kind === "service") {
      return internalFailure("authorization_lookup_failed");
    }
    console.warn("send-nudge-push:forbidden", {
      reason: authorizationResult.reason,
    });
    return respond({
      status: "forbidden",
      error: authorizationResult.reason,
      delivered: false,
    }, 403);
  }

  const profileResult = await admin
    .from("profiles")
    .select("id,time_zone,locale,group_nudges_enabled")
    .in("id", [senderID, payload.to_user_id]);
  if (profileResult.error) {
    return internalFailure("profile_lookup_failed");
  }
  const profiles = profileResult.data ?? [];
  const senderProfile = profiles.find((profile) => profile.id === senderID);
  const recipientProfile = profiles.find((profile) =>
    profile.id === payload.to_user_id
  );
  if (recipientProfile?.group_nudges_enabled === false) {
    return respond(
      { status: "recipient_not_registered", delivered: false },
      200,
    );
  }

  const tokenResult = await admin
    .from("device_tokens")
    .select("token,apns_environment")
    .eq("user_id", payload.to_user_id);
  if (tokenResult.error) {
    return internalFailure("token_lookup_failed");
  }
  const registrations = Array.from(
    new Map(
      (tokenResult.data ?? []).flatMap((row) => {
        const token = normalizeAPNsToken(row.token);
        return token
          ? [
            [token, {
              token,
              environment: normalizeAPNsEnvironment(row.apns_environment),
            }] as const,
          ]
          : [];
      }),
    ).values(),
  );
  if (registrations.length === 0) {
    return respond(
      { status: "recipient_not_registered", delivered: false },
      200,
    );
  }

  const senderDay = localDay(
    new Date(),
    normalizeTimeZone(senderProfile?.time_zone),
  );
  const reservation = await reserveNudge(
    admin,
    payload.group_id,
    senderID,
    payload.to_user_id,
    payload.habit_id,
    senderDay,
  );
  if (!reservation) {
    return internalFailure("reservation_failed");
  }
  if (!reservation.should_send) {
    return respond(
      { status: "duplicate", nudge_id: reservation.nudge_id, delivered: false },
      200,
    );
  }

  const habitResult = await admin
    .from("habits")
    .select("name")
    .eq("id", payload.habit_id)
    .maybeSingle();
  const locale = normalizeLocale(recipientProfile?.locale);
  const content = nudgeBody(locale, habitResult.data?.name ?? "");
  const pushPayload = {
    aps: {
      alert: { title: "Adat", body: content },
      sound: "default",
      "thread-id": `group.${payload.group_id}`,
    },
    type: "group_nudge",
    group_id: payload.group_id,
    habit_id: payload.habit_id,
  };

  let providerToken: string;
  try {
    providerToken = await makeAPNsProviderToken(config);
  } catch {
    return internalFailure("apns_provider_token_failed");
  }

  const deliveryResults = await Promise.all(
    registrations.map(async (registration) => ({
      token: registration.token,
      result: await sendAPNs(
        config,
        providerToken,
        registration,
        pushPayload,
        reservation.nudge_id,
      ),
    })),
  );
  const acceptedCount = deliveryResults.filter((delivery) =>
    delivery.result.accepted
  ).length;
  const invalidTokens = deliveryResults
    .filter((delivery) => delivery.result.invalidToken)
    .map((delivery) => delivery.token);
  if (invalidTokens.length > 0) {
    const cleanup = await admin
      .from("device_tokens")
      .delete()
      .eq("user_id", payload.to_user_id)
      .in("token", invalidTokens);
    if (cleanup.error) {
      console.warn("send-nudge-push:stale_token_cleanup_failed", {
        count: invalidTokens.length,
      });
    }
  }

  if (acceptedCount > 0) {
    await markDelivery(admin, reservation.nudge_id, "delivered", null);
    console.info("send-nudge-push:delivered", { recipients: acceptedCount });
    return respond(
      { status: "sent", nudge_id: reservation.nudge_id, delivered: true },
      200,
    );
  }

  const providerFailed = deliveryResults.some((delivery) =>
    !delivery.result.invalidToken
  );
  const failureCode = providerFailed ? "apns_error" : "no_recipients";
  await markDelivery(admin, reservation.nudge_id, "failed", failureCode);
  console.warn("send-nudge-push:not_delivered", { reason: failureCode });
  if (!providerFailed) {
    return respond(
      { status: "recipient_not_registered", delivered: false },
      200,
    );
  }
  return respond({
    status: "error",
    error: "Push delivery failed",
    delivered: false,
  }, 502);
});

async function authorizeNudge(
  admin: AdminClient,
  groupID: string,
  senderID: string,
  recipientID: string,
  habitID: string,
): Promise<
  | { ok: true }
  | { ok: false; kind: "forbidden" | "service"; reason: string }
> {
  const memberships = await admin
    .from("group_members")
    .select("user_id")
    .eq("group_id", groupID)
    .in("user_id", [senderID, recipientID]);
  if (memberships.error) {
    return { ok: false, kind: "service", reason: "Membership lookup failed" };
  }
  if (new Set((memberships.data ?? []).map((row) => row.user_id)).size !== 2) {
    return {
      ok: false,
      kind: "forbidden",
      reason: "Sender and recipient must be group members",
    };
  }

  const sharing = await admin
    .from("group_shared_habits")
    .select("habit_id")
    .eq("group_id", groupID)
    .eq("user_id", recipientID)
    .eq("habit_id", habitID)
    .eq("shared", true)
    .maybeSingle();
  if (sharing.error) {
    return {
      ok: false,
      kind: "service",
      reason: "Habit authorization lookup failed",
    };
  }
  if (!sharing.data) {
    return {
      ok: false,
      kind: "forbidden",
      reason: "Habit is not shared by recipient",
    };
  }
  return { ok: true };
}

async function reserveNudge(
  admin: AdminClient,
  groupID: string,
  senderID: string,
  recipientID: string,
  habitID: string,
  day: string,
): Promise<{ nudge_id: string; should_send: boolean } | null> {
  const result = await admin.rpc("reserve_group_nudge", {
    p_group_id: groupID,
    p_from_user_id: senderID,
    p_to_user_id: recipientID,
    p_habit_id: habitID,
    p_day: day,
  });
  if (result.error) {
    console.error("send-nudge-push:reservation_failed", {
      code: result.error.code ?? "unknown",
    });
    return null;
  }
  const row = Array.isArray(result.data) ? result.data[0] : result.data;
  return row && typeof row.nudge_id === "string"
    ? { nudge_id: row.nudge_id, should_send: row.should_send === true }
    : null;
}

async function markDelivery(
  admin: AdminClient,
  nudgeID: string,
  status: "delivered" | "failed",
  failureCode: string | null,
): Promise<void> {
  const update = await admin
    .from("nudges")
    .update({
      delivery_status: status,
      failure_code: failureCode,
      delivered_at: status === "delivered" ? new Date().toISOString() : null,
    })
    .eq("id", nudgeID);
  if (update.error) {
    console.error("send-nudge-push:delivery_state_failed", {
      code: update.error.code ?? "unknown",
    });
  }
}

async function makeAPNsProviderToken(config: APNsConfig): Promise<string> {
  const privateKey = await importPKCS8(config.apnsPrivateKey, "ES256");
  return await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: config.apnsKeyID })
    .setIssuer(config.apnsTeamID)
    .setIssuedAt()
    .sign(privateKey);
}

async function sendAPNs(
  config: APNsConfig,
  providerToken: string,
  registration: { token: string; environment: "development" | "production" },
  payload: Record<string, unknown>,
  collapseID: string,
): Promise<APNsResult> {
  const host = registration.environment === "development"
    ? "api.sandbox.push.apple.com"
    : "api.push.apple.com";
  try {
    const response = await fetch(
      `https://${host}/3/device/${registration.token}`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `bearer ${providerToken}`,
          "apns-topic": config.apnsBundleID,
          "apns-push-type": "alert",
          "apns-priority": "10",
          "apns-expiration": String(Math.floor(Date.now() / 1000) + 3600),
          "apns-collapse-id": collapseID,
        },
        body: JSON.stringify(payload),
      },
    );
    const body = await response.json().catch(() => null) as
      | { reason?: unknown }
      | null;
    return {
      accepted: response.status === 200,
      invalidToken: isInvalidAPNsTokenResponse(response.status, body?.reason),
      status: response.status,
    };
  } catch {
    return { accepted: false, invalidToken: false, status: 0 };
  }
}

type APNsConfig = {
  supabaseURL: string;
  supabaseAnonKey: string;
  serviceRoleKey: string;
  apnsTeamID: string;
  apnsKeyID: string;
  apnsPrivateKey: string;
  apnsBundleID: string;
};

function readConfig(): APNsConfig | null {
  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const apnsTeamID = Deno.env.get("APNS_TEAM_ID");
  const apnsKeyID = Deno.env.get("APNS_KEY_ID");
  const apnsPrivateKey = Deno.env.get("APNS_PRIVATE_KEY")?.replaceAll(
    "\\n",
    "\n",
  );
  const apnsBundleID = Deno.env.get("APNS_BUNDLE_ID");
  return supabaseURL && supabaseAnonKey && serviceRoleKey &&
      apnsTeamID && apnsKeyID && apnsPrivateKey && apnsBundleID
    ? {
      supabaseURL,
      supabaseAnonKey,
      serviceRoleKey,
      apnsTeamID,
      apnsKeyID,
      apnsPrivateKey,
      apnsBundleID,
    }
    : null;
}

function respond(body: NudgeResponse, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function internalFailure(code: string): Response {
  console.error("send-nudge-push:internal_failure", { code });
  return respond({
    status: "error",
    error: "Could not send reminder",
    delivered: false,
  }, 500);
}
