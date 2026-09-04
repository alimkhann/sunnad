# Stream B — Fix "remind a friend" (group nudge push) delivery

## Symptom

Tapping the bell → "Send" on a member's incomplete shared habit in a group shows
"Could not send reminder. Try again." (generic error) — the recipient gets no push.

## Architecture map (verify with Grep before editing)

### iOS call chain

| Step | Location |
|---|---|
| Bell button (only when `!sharedHabit.completedToday`) | `sunnad-ios/sunnad-ios/Features/Groups/Views/GroupDetailView.swift` (~:592-616) |
| `ReminderPromptSheet` ("Send Reminder" / "Send") | `GroupDetailView.swift` (~:168-180, ~:813-834) |
| `sendReminder(to:)` + toast mapping + 2.2s auto-dismiss | `GroupDetailView.swift` (~:725-764) |
| GroupsView closure | `Features/Groups/Views/GroupsView.swift` (~:107-109) |
| Wiring `onSendReminder: state.sendGroupNudge` | `App/SunnadRootView.swift` (~:108) |
| `AppRouteState.sendGroupNudge` | `App/AppRouteState.swift` (~:1311-1321) |
| `GroupsViewModel.sendNudge` — **catches all errors**, maps to `.error` | `Features/Groups/ViewModels/GroupsViewModel.swift` (~:302-330) |
| Repo pass-throughs | `Services/Sync/SyncingRepositories.swift` (~:179-181) → `Data/Local/Repositories/GroupsLocalRepository.swift` (~:256-258; offline no-config fallback ~:134-137 returns `.recipientNotRegistered`) |
| Supabase call | `Data/Remote/Repositories/SupabaseGroupsRepository.swift` (~:546-583 sendNudge with 401 retry; ~:1191-1207 `invokeNudgeFunction` → `client.functions.invoke("send-nudge-push", body {group_id, to_user_id, habit_id})`; ~:1213-1218 **requires `delivered == true`** in the response, else coerces to `.recipientNotRegistered`) |

### Backend (`supabase/functions/send-nudge-push/`: `index.ts`, `logic.ts`, `logic_test.ts`)

1. Config gate (~:421-444): requires `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
   `SUPABASE_SERVICE_ROLE_KEY`, `APNS_TEAM_ID`, `APNS_KEY_ID`, `APNS_PRIVATE_KEY`,
   `APNS_BUNDLE_ID`. Any missing → **500 `{"status":"error","error":"Function is not configured"}`**.
2. Auth: manual Authorization check + `auth.getUser()`.
3. Membership: both users in `group_members`, recipient shares the habit in
   `group_shared_habits` → else 403 `forbidden`.
4. Recipient `profiles.group_nudges_enabled == false` → `recipient_not_registered`.
5. `device_tokens` rows for recipient; tokens normalized to 64-hex; none → `recipient_not_registered`.
6. Idempotency via RPC `reserve_group_nudge` (1 nudge per sender per recipient-local day;
   pending <5min = duplicate; failed = retryable).
7. APNs: ES256 JWT from `APNS_*`, POST to sandbox or prod host **per token row's
   `apns_environment` column**, header `apns-topic: $APNS_BUNDLE_ID`.
8. Invalid-token cleanup **deletes token rows** on APNs 400/410; 0 accepted → 502 or
   `recipient_not_registered`.

### DB support (all in `/supabase/migrations/`)

- `device_tokens` table + RLS: `20260217000001_schema.sql` (~:288-304), RLS in `20260217000002_security.sql`
- `installation_id`, `profiles.time_zone/locale/group_nudges_enabled`, `nudges` delivery
  columns + `reserve_group_nudge` RPC (service_role only): `20260829000019_adat_1_1_reliability.sql`
- `apns_environment` column: `20260830000021_native_apns_delivery.sql`

### Device-token registration (recipient side)

- Token → UserDefaults `sunnad.device.push-token` → `.adatDeviceTokenDidChange`:
  `sunnad_iosApp.swift` (~:5-33), bridge `AppRouteState.swift` (~:2684-2730).
  **Registers only if notification authorization granted** (~:2693-2722).
- Token→Supabase upsert on token-change (~:1715-1725) and sign-in (~:2093-2109);
  `SupabaseAuthService.swift` (~:762-935) — **silently skips with log `skipped_no_token` if no
  token yet (~:815-820); errors only logged, never retried**.
- APNs env: `App/AppEnvironment.swift` (~:130-146) via Info.plist `SunnadAPNsEnvironment` ←
  build setting `SUNNAD_APNS_ENVIRONMENT_BUNDLE` (Debug=development, Release=production).

## Ranked suspected failure points

1. **Missing `APNS_*` runtime secrets on the deployed project.** CD
   (`.github/workflows/cd-manual.yml` ~:49-68) deploys functions but never sets secrets; docs
   still instruct the retired OneSignal vars. Result: every call → 500 "not configured" →
   generic error toast. ← most likely
2. **Single `APNS_BUNDLE_ID` topic vs two bundle IDs.** A recipient registered from the dev
   build (`.sunnad.dev`, sandbox) receives a push with the prod topic → 400
   `DeviceTokenNotForTopic` → **token row deleted by cleanup** → permanent
   `recipient_not_registered` until the token is re-registered (and re-registration is skipped
   when the APNs token is unchanged — see B3).
3. **Project-ref drift / stale deploy.** App (both configs) → `artwfvypcdacdpqhciqt`; docs say
   dev=`wejnrzlxnesqhbtvgdga`; a CI log references a third ref. If the app's project lacks
   migrations `20260829000019`/`20260830000021` or the function build, calls fail.
4. **Recipient has no usable token row** (permission denied → never registered; sync silently
   skipped; Android/FCM token failing the 64-hex check; group nudges disabled).
5. Legacy API key disablement would 401 everything (iOS retry path catches some of it).
6. Old function build without `delivered` in the response → iOS downgrades 200 to
   `recipient_not_registered`.

## Part 1 — Triage runbook (CLI first; browser only where noted)

Ask the human to complete any interactive sign-in. Never print secret values.

```bash
supabase --version          # install/update if missing (brew install supabase/tap/supabase)
supabase login              # interactive → human signs in

# 1) Secrets — the #1 suspect
supabase secrets list --project-ref artwfvypcdacdpqhciqt
#   Expect all of: SUPABASE_URL SUPABASE_ANON_KEY SUPABASE_SERVICE_ROLE_KEY
#                  APNS_TEAM_ID APNS_KEY_ID APNS_PRIVATE_KEY APNS_BUNDLE_ID
#   (list shows names; that is enough)

# 2) Live function logs right after a test tap in the app (ask the human to tap, or skip if no device)
supabase functions logs send-nudge-push --project-ref artwfvypcdacdpqhciqt

# 3) Migrations applied on the hosted project
supabase migration list --project-ref artwfvypcdacdpqhciqt
#   Must include: 20260217000001, 20260217000002, 20260829000019, 20260830000021

# 4) DB inspection — prefer the dashboard SQL editor via browser (human signs in),
#    or a psql one-liner if a connection string is available.
#    Before writing SQL, read the migration files for exact column names.
```

SQL checks (dashboard SQL editor or psql):

```sql
-- recipient token rows: platform, 64-hex token, environment, freshness
select user_id, platform, token, apns_environment, updated_at
from device_tokens order by updated_at desc limit 20;

-- nudges delivery outcomes
select group_id, to_user_id, delivery_status, failure_code, created_at
from nudges order by created_at desc limit 10;

-- recipient nudge opt-in
select id, group_nudges_enabled from profiles;
```

### Decision tree

| Observation | Cause | Action |
|---|---|---|
| Secrets missing `APNS_*` or logs say "Function is not configured" | #1 | Set secrets (Part 2 step S), deploy, retest |
| Function URL 404 / logs empty | Function not deployed | `supabase functions deploy send-nudge-push --project-ref artwfvypcdacdpqhciqt` |
| `recipient_not_registered` + no `device_tokens` row | #4 | Recipient side: check permission + fix B3 retry; then recipient opens app once |
| `recipient_not_registered` + token row exists + nudge `failure_code` indicates APNs 400 topic / token deleted | #2 | Per-env topics (Part 2 code change) + B3 forced re-upsert |
| Response missing `delivered` but 200 | #6 | Redeploy current function code |
| `forbidden` | Data issue: not members / habit not shared | Report to human; no code fix |
| RPC error mentioning `reserve_group_nudge` | Migrations missing | **Ask human** before `supabase db push` |
| Anything referencing `wejnrzlxnesqhbtvgdga` / a third ref | #3 drift | Confirm canonical ref with human; app's ref (`artwfvypcdacdpqhciqt`) is default truth |

Also verify the app↔project pairing: both Debug and Release point at `artwfvypcdacdpqhciqt`
(`project.pbxproj`, build settings `SUNNAD_SUPABASE_URL_BUNDLE`). Do not change them.

## Part 2 — Backend changes

### B2.1 Per-environment APNS topic

Problem: one `APNS_BUNDLE_ID` secret serves both `.sunnad.dev` (sandbox) and `.sunnad`
(production) registrations in the same DB → topic mismatch → token deletion.

Changes in `supabase/functions/send-nudge-push/`:

- Config gate: require `APNS_BUNDLE_ID_DEV` **and** `APNS_BUNDLE_ID_PROD`. Keep `APNS_BUNDLE_ID`
  as an optional legacy fallback: if only it is present, use it for both environments and log a
  warning.
- Topic selection: for each token row, `apns_environment == "development"` → `APNS_BUNDLE_ID_DEV`,
  `"production"` (or null → production) → `APNS_BUNDLE_ID_PROD`.
- Update `logic.ts` signatures and extend `logic_test.ts` with a topic-per-environment case.
- Add the new secret names to the config-gate error message so triage is obvious.

### B2.2 Set secrets (S — requires human-provided values)

Only set what is missing or changing (checked in Part 1). Values the human must provide:

- **APNS key**: developer.apple.com → Certificates, IDs & Profiles → Keys → use an existing key
  with APNs enabled (Key ID visible) or create one — **download the `.p8` immediately, it can be
  downloaded only once**. Save to `~/secrets/` (outside the repo). Team ID is on the Membership page.
- **service_role key**: Supabase dashboard → Project Settings → API (browser), only if missing.

```bash
supabase secrets set --project-ref artwfvypcdacdpqhciqt \
  APNS_TEAM_ID=<TEAMID10> \
  APNS_KEY_ID=<KEYID10> \
  APNS_PRIVATE_KEY="$(cat ~/secrets/AuthKey_<KEYID10>.p8)" \
  APNS_BUNDLE_ID_DEV=com.arystan.almasuly.sunnad.dev \
  APNS_BUNDLE_ID_PROD=com.arystan.almasuly.sunnad
# plus any missing SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY
```

Then:

```bash
supabase functions deploy send-nudge-push --project-ref artwfvypcdacdpqhciqt
```

### B2.3 Docs rewrite (stale OneSignal content)

- `docs/supabase-environments.md` (~:198-215): replace OneSignal secret instructions with the
  current native-APNs secret list, the set command above, per-env topic mapping, and state that
  `artwfvypcdacdpqhciqt` is the project the iOS app points at (resolve the ref drift explicitly).
- `docs/apple-onesignal-setup.md`: replace OneSignal push setup with the native APNs flow
  (or mark superseded with a pointer to the environments doc).
- `.github/workflows/cd-manual.yml`: add a pre-deploy check step that verifies the required
  secret names exist (`supabase secrets list | grep ...`) and fails with a clear message. Do
  NOT store any secret values in GitHub.

## Part 3 — iOS changes

### B3.1 Device-token sync robustness (`SupabaseAuthService.swift` ~:762-935 + `AppRouteState.swift`)

Current behavior: skip silently when no token (`skipped_no_token` ~:815-820); log-only on
failure. Because server-side cleanup **deletes** token rows (bad topic, APNs 410), a device
whose row was deleted will never re-register if its APNs token is unchanged (the bridge only
posts `.adatDeviceTokenDidChange` on change).

Required:

- Make the token upsert **idempotent and unconditional**: on every app foreground
  (`willEnterForeground` reload path, `AppRouteState.swift` ~:1697-1713) and on every
  launch/sign-in restore, attempt the upsert when a token exists and notification authorization
  is granted — even if the token value is unchanged.
- Track last-sync failure in memory; retry on the next foreground. Keep failures logged.
- Do not change when registration is attempted (still gated on notification authorization —
  users who denied notifications cannot receive nudges; that is product reality, log clearly).

### B3.2 Nudge UI test fixes (`sunnad-iosUITests/sunnad_iosUITests.swift` ~:308-363)

`testReleaseSenderDeliversGroupNudge` (opt-in via `ADAT_RELEASE_NUDGE_SMOKE=1`) cannot pass:

- It queries member rows by identifier prefix `group.member.row.` — **no view sets it** (only
  `group.row.` exists, `GroupsView.swift` ~:158). Add `.accessibilityIdentifier("group.member.row." + memberID)`
  (or a stable suffix) to member rows in `GroupDetailView`.
- It queries `app.buttons["Send reminder"]` — the actual button label is "Send"
  (`groups.reminder.send`, `GroupDetailView.swift` ~:615/~:832). Fix the query (match by label
  from the localization table or add an accessibility identifier to the sheet's Send button —
  prefer the identifier).
- The success toast auto-dismisses after ~2.2s (`GroupDetailView.swift` ~:754-764). Keep the
  existing `waitForExistence` polling but start it immediately after the tap and add an
  accessibility identifier to the toast for robust matching.

### B3.3 Optional (only if trivial): clearer error surfacing

`GroupsViewModel.sendNudge` maps everything else to `.error` → generic toast. Leave as is
unless a one-line distinction for "function not configured" (HTTP 500 with that error string)
can be added via a new i18n key — if you add one, provide EN/RU/KK. Do not restructure.

## Verification

1. Backend: secrets list shows all required names; function deployed; `logic_test.ts` passes
   (Deno if available; otherwise verify via logs).
2. End-to-end (needs two signed-in test accounts in a group, on real/sim devices):
   sender taps bell → Send → toast "Reminder sent"; recipient device receives the push within
   seconds; `nudges` row shows delivered; duplicate within the window shows the rate-limit toast.
   If no second device is available, verify at least that the function returns
   `{"delivered":true}`-shaped success for a valid recipient token and say so in the report.
3. Token cleanup path: send to a deliberately invalid 64-hex token row → row deleted, function
   returns `recipient_not_registered` — confirms cleanup works without breaking others.
4. Unit tests green (README command).

## Commit

```
notifications: fix group nudge delivery

- send-nudge-push: per-environment APNS topic (APNS_BUNDLE_ID_DEV/PROD)
- secrets set + function deployed; CD secret preflight check
- docs: replace OneSignal instructions with native APNs setup
- iOS: idempotent device-token upsert on foreground/sign-in (survives server-side token cleanup)
- UI test: fix member-row identifiers, Send button matching, toast identifier
```
