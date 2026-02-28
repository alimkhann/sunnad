# Analytics Tracking Map (v2 + Stage E)

This document is the source of truth for Sunnad PostHog tracking across landing + iOS.

Rules:
- Strict snake_case event names.
- No dual-write aliases.
- No PII in payloads (no emails, names, quote text, habit names, invite codes).
- Error tracking uses sanitized hashes only.

---

## Common properties

### Landing events
- `environment` (`development` | `production`)
- `schema_version` (`2`)
- `surface` (`landing`)

### iOS events
- `environment` (`development` | `production`)
- `schema_version` (`2`)
- `surface` (`ios`)
- `platform` (`ios`)
- `app_version`
- `build_number`
- `locale`

---

## Landing events

- `landing_page_viewed`
  - `locale`, `theme`, `path`
  - optional `referrer_domain`
  - optional UTM properties: `utm_source`, `utm_medium`, `utm_campaign`, `utm_content`, `utm_term`

- `landing_section_viewed`
  - `locale`, `theme`, `path`, `section_id` (`hero`, `feature_scroll`, `faq`, `bottom_cta`)

- `landing_all_sections_viewed`
  - `locale`, `theme`, `path`, `sections_total` (`4`)

- `landing_cta_clicked`
  - `locale`, `theme`, `path`, `cta_location` (`hero`, `bottom_cta`)

- `landing_waitlist_form_started`
  - `locale`, `theme`, `path`, `cta_location` (`hero`, `bottom_cta`)

- `landing_waitlist_submit_started`
  - `locale`, `variant`, `platform`, `referral_source`, `cta_location`

- `landing_waitlist_submit_succeeded`
  - `locale`, `variant`, `platform`, `referral_source`, `cta_location`
  - `status` (`subscribed` | `already_subscribed`)

- `landing_waitlist_submit_failed`
  - `locale`, `variant`, `platform`, `referral_source`, `cta_location`
  - `status` (`rate_limited` | `error`)
  - `error_type`

- `landing_scroll_depth`
  - `locale`, `theme`, `path`, `depth_percent` (`25` | `50` | `75` | `100`)

- `landing_page_exited`
  - `locale`, `theme`, `path`, `time_on_page_seconds`, `last_section_viewed`

- `landing_faq_expanded`
  - `locale`, `theme`, `path`, `question_id`

- `landing_error_captured`
  - `error_type`, `source`, `message_hash`

---

## iOS events

- `screen_viewed`
  - `screen_name` (`today`, `groups`, `profile`, `insights`, `onboarding`)

- `onboarding_step_completed`
  - `step_name` (`welcome`, `templates`, `notifications`, `join_groups`, `sign_in`, `sign_up`, `otp`)

- `auth_result`
  - `kind` (`sign_in`, `sign_up`), `provider` (`email`, `google`, `apple`)
  - `status` (`success`, `failure`)
  - optional `reason`

- `habit_created`
  - `type`, `schedule_type`, `has_reminder`, `target_count`

- `habit_updated`
  - `changed_fields` (array)

- `habit_deleted`
  - `type`

- `habit_completion_toggled`
  - `type`, `status` (`completed`, `uncompleted`), `source`

- `habit_counter_incremented`
  - `delta`, `count`, `target`

- `habit_reminder_toggled`
  - `status` (`enabled`, `disabled`)

- `habit_streak_achieved`
  - `habit_type`, `streak_length`, `milestone` (`3`, `7`, `14`, `30`, `60`, `100`)

- `habit_streak_broken`
  - `habit_type`, `previous_streak_length`

- `quote_opened`
- `quote_saved`
- `quote_shared`
  - optional `channel`

- `group_opened`
- `group_created`
- `group_join_result`
  - `status` (`success`, `failure`)
  - optional `reason`
- `group_left`
- `group_sharing_updated`
  - `delta`, `total_shared`
- `group_nudge_result`
  - `status` (`sent`, `duplicate`, `forbidden`, `error`), `habit_type`
- `group_member_progress_viewed`
  - `member_scope` (`self`, `other`), `shared_habits_count`

- `sync_cycle_result`
  - `trigger`, `status` (`success`, `failed`), `duration_ms`, `pulled_count`, `pushed_count`
  - optional `stage`, optional `error_code`

- `app_opened`
  - `source` (`organic`, `notification`, `deep_link`, `unknown`)

- `app_backgrounded`
  - `session_duration_seconds`

- `offline_session_completed`
  - `session_duration_seconds`, `offline_duration_seconds`

- `notification_received`
  - `notification_type` (`habit`, `quote`, `group`, `unknown`), `source` (`local`)

- `notification_tapped`
  - `notification_type` (`habit`, `quote`, `group`, `unknown`), `source` (`local`)

- `ios_error_captured`
  - `scope`, `error_kind` (`storage_failure`, `sync_failure`, `network_failure`, `unknown`)
  - optional `error_code`
  - `message_hash`

---

## Person properties

Set/update on signed-in iOS users:
- `habit_count` (number)
- `is_group_member` (bool)
- `notifications_enabled` (bool)
- `days_since_signup` (number)
- `is_test_account` (bool)
- `first_seen_at` (set-once ISO timestamp)
- plus existing identify props: `is_guest`, `language`, `locale`

---

## Replay and error privacy rules

- Session replay sampling:
  - development: 100%
  - production: 20% deterministic sampling
- Replay privacy:
  - mask text inputs enabled
  - network telemetry disabled
- Error capture:
  - only sanitized fields (`scope`, `error_kind`, `error_code?`, `message_hash`)
  - no raw error body/stack in events
  - duplicate throttling enabled in iOS error bridge

---

## PostHog ops conventions

- `filterTestAccounts` is enabled on decision insights.
- Project test-account filters include:
  - non-localhost host gate
  - `is_test_account is_not true` (person property)
- Dashboard global filter: `environment`.

Created operational cohorts:
- `Activated Users (7d)`
- `Group Engaged Users`
- `Notifications Enabled Users`

Created alerts:
- `Alert - Waitlist success dropped to zero (prod)`
- `Alert - Sync failures above threshold (prod)`

---

## How to read dashboards

Primary dashboard:
- `Sunnad - Product Funnel v2`

Use this mapping:
- Conversion:
  - landing funnel
  - CTA click by location
  - form start -> waitlist success funnel
  - waitlist success vs failure trend
- Activation:
  - iOS activation funnel
  - app opened by source
  - streak achieved vs broken
- Engagement:
  - quote engagement trend
  - groups engagement trend
  - notification received vs tapped
  - offline session trend
  - FAQ expansion + scroll depth trends
- Reliability:
  - sync failures and failure rate
