import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  apnsTopicForEnvironment,
  isInvalidAPNsTokenResponse,
  localDay,
  normalizeAPNsEnvironment,
  normalizeAPNsToken,
  normalizeLocale,
  nudgeBody,
  parseNudgeRequest,
} from "./logic.ts";

Deno.test("validates and normalizes nudge identifiers", () => {
  assertEquals(
    parseNudgeRequest({
      group_id: "A0E947A0-40D9-4AA4-9A0B-CA8AB4D21A02",
      to_user_id: "58b58c3e-6d45-4ec6-ac55-c710563e84d2",
      habit_id: "73e5021b-2caf-4e31-bcaf-38ba68717f4c",
    }),
    {
      group_id: "a0e947a0-40d9-4aa4-9a0b-ca8ab4d21a02",
      to_user_id: "58b58c3e-6d45-4ec6-ac55-c710563e84d2",
      habit_id: "73e5021b-2caf-4e31-bcaf-38ba68717f4c",
    },
  );
  assertEquals(parseNudgeRequest({ group_id: "nope" }), null);
});

Deno.test("uses an IANA local day instead of UTC", () => {
  const instant = new Date("2026-08-28T20:30:00.000Z");
  assertEquals(localDay(instant, "Asia/Almaty"), "2026-08-29");
  assertEquals(localDay(instant, "UTC"), "2026-08-28");
});

Deno.test("accepts only canonical APNs device tokens", () => {
  assertEquals(normalizeAPNsToken(`  ${"A".repeat(64)}  `), "a".repeat(64));
  assertEquals(normalizeAPNsToken("f".repeat(64)), "f".repeat(64));
  assertEquals(normalizeAPNsToken("legacy-provider-id"), null);
  assertEquals(normalizeAPNsToken("not-a-device-token"), null);
});

Deno.test("normalizes APNs environment and invalid-token responses", () => {
  assertEquals(normalizeAPNsEnvironment("development"), "development");
  assertEquals(normalizeAPNsEnvironment("production"), "production");
  assertEquals(normalizeAPNsEnvironment("unknown"), "production");
  assertEquals(isInvalidAPNsTokenResponse(400, "BadDeviceToken"), true);
  assertEquals(isInvalidAPNsTokenResponse(410, "Unregistered"), true);
  assertEquals(isInvalidAPNsTokenResponse(500, "InternalServerError"), false);
});

Deno.test("selects the APNs topic per environment", () => {
  const topics = {
    development: "com.arystan.almasuly.sunnad.dev",
    production: "com.arystan.almasuly.sunnad",
  };
  assertEquals(
    apnsTopicForEnvironment("development", topics),
    "com.arystan.almasuly.sunnad.dev",
  );
  assertEquals(
    apnsTopicForEnvironment("production", topics),
    "com.arystan.almasuly.sunnad",
  );
});

Deno.test("localizes recipient-facing copy", () => {
  assertEquals(normalizeLocale("ru"), "ru");
  assertEquals(normalizeLocale("unknown"), "en");
  assertEquals(nudgeBody("kk", "  Кітап оқу  ").includes("Кітап оқу"), true);
});
