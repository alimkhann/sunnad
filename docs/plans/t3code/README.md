# t3code Handoff — Run Doc (2026-09-04)

You are an autonomous agent executing three work streams in the Sunnad repo. The human only
signs in when you ask; everything else is yours to do. Work streams **sequentially: A → B → C**.

## Read first (in this order)

1. `/AGENTS.md` (root) — project rules
2. `/sunnad-ios/AGENTS.md` — iOS rules (wins for iOS changes)
3. The stream docs in this folder:
   - `A-yesterday-late-checkin.md`
   - `B-friend-reminder-fix.md`
   - `C-widgets.md`

## Repo map

```
/sunnad-ios/            iOS app (SwiftUI, MVVM-ish, SwiftData local store)
  sunnad-ios/           app source (App/, Features/, Domain/, Data/, Services/, Shared/)
  sunnad-iosTests/      unit tests (Swift Testing, #expect)
  sunnad-iosUITests/    UI tests
/sunnad-android/        Android (out of scope for this run)
/supabase/
  migrations/           Postgres migrations (canonical backend contract)
  functions/            Edge Functions (TypeScript): send-nudge-push, delete-account, ...
/configs, /docs, /scripts, /landing, /admin
```

## Key facts (verified 2026-09-04)

| Fact | Value |
|---|---|
| Supabase project used by BOTH Debug & Release | `https://artwfvypcdacdpqhciqt.supabase.co` |
| Bundle IDs | Debug `com.arystan.almasuly.sunnad.dev` (APNs development), Release `com.arystan.almasuly.sunnad` (APNs production), Local `com.arystan.almasuly.sunnad.local` |
| Deployment target | iOS 17.6 (interactive widgets / AppIntents available) |
| Schemes | `sunnad-ios`, `sunnad-ios-dev`, `sunnad-ios-prod` (see `sunnad-ios/sunnad-ios.xcodeproj/xcshareddata/xcschemes/`) |
| Supabase config in app | build settings `SUNNAD_SUPABASE_URL_BUNDLE`, anon key in `project.pbxproj` (already committed — do not copy it anywhere new) |
| Push | Native APNs, sent by Edge Function `send-nudge-push` (supabase/functions/send-nudge-push/) |
| i18n | EN default + RU + KK (Cyrillic). All strings via `L10n.t(key)` from `sunnad-ios/sunnad-ios/Resources/Localizable.xcstrings`. No hardcoded user-facing strings anywhere (including widgets). |

Known drift (fixed in stream B): `docs/supabase-environments.md` references other project refs
(`wejnrzlxnesqhbtvgdga` as dev) and OneSignal secrets that the function no longer reads.
The app does not use them. Treat `artwfvypcdacdpqhciqt` as canonical unless the human says otherwise.

## Access & sign-in points (ask the human; they sign in, you continue)

- **`supabase login`** (CLI) — stream B: secrets, deploy, migration list. Check `supabase --version` first.
- **developer.apple.com** (browser) — stream B: obtain APNs auth key (`.p8`), Key ID, Team ID.
- **Supabase dashboard** (browser) — stream B: service_role key only if `supabase secrets list`
  shows `SUPABASE_SERVICE_ROLE_KEY` missing.
- **App Store Connect / Apple Developer portal** — stream C: only if automatic signing
  (`xcodebuild -allowProvisioningUpdates`) cannot add the App Group capability.

## Rules for this run (hard)

- **One commit per completed stream**, using the commit message given in each stream doc.
  Do not commit anything else; do not amend/rebase.
- **Never commit or print secrets.** APNS private key / service_role key go only into
  `supabase secrets set`. Store any downloaded `.p8` outside the repo (e.g. `~/secrets/`) and
  confirm it is not under the repo path.
- **Destructive backend actions require asking the human first**: `supabase db push`,
  deleting rows (device_tokens/nudges), changing RLS, anything on other projects.
- Verify every `file:line` reference in the stream docs with Grep before editing — lines may have drifted.
- Minimal diffs. No new tools (SwiftLint/SwiftFormat), no new dependencies, no new tabs/flows.
- iOS 6 concurrency: async/await, `@MainActor` for UI state, `Sendable` where needed.
- If you touch domain logic, add/adjust unit tests.
- Liquid Glass policy: system bar/sheet appearance only; no `glassEffect` / material modifiers in content.

## Build & test (per stream, before committing)

```bash
# pick an available sim
xcrun simctl list devices available | grep -m1 iPhone

# build
xcodebuild -project sunnad-ios/sunnad-ios.xcodeproj -scheme sunnad-ios \
  -destination 'platform=iOS Simulator,name=iPhone 16' build

# unit tests
xcodebuild -project sunnad-ios/sunnad-ios.xcodeproj -scheme sunnad-ios \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:sunnad-iosTests test
```

Backend tests for stream B: `supabase/functions/send-nudge-push/logic_test.ts` — run with
`deno test` if Deno is available; otherwise state explicitly it was not run and verify via
function logs after deploy.

## Report-back format (after each stream)

1. What changed (files + one-line why)
2. Verification performed (commands + results)
3. Open risks / decisions deferred
4. Commit hash + message
5. Any sign-in steps the human performed

Then move to the next stream.
