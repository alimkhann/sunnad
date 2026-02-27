### Analytics tracking map (v2)

This document defines the PostHog v2 event taxonomy used by Sunnad landing + iOS.

Rules:
- Event names are snake_case.
- We do not dual-write old names.
- No PII in properties (no emails, names, quote text, habit names, invite codes).
- Common properties are attached on every event.

---

### Common properties

#### Landing events
- `environment` (`development` | `production`)
- `schema_version` (`2`)
- `surface` (`landing`)

#### iOS events
- `environment` (`development` | `production`)
- `schema_version` (`2`)
- `surface` (`ios`)
- `app_version`
- `build_number`
- `platform` (`ios`)
- `locale`

---

### Landing events

- `landing_page_viewed`
  - `locale`, `theme`, `path`, optional `referrer_domain`, optional UTM fields.

- `landing_section_viewed`
  - `locale`, `theme`, `path`, `section_id` (`hero`, `feature_scroll`, `faq`, `bottom_cta`).

- `landing_all_sections_viewed`
  - `locale`, `theme`, `path`, `sections_total` (`4`).

- `landing_waitlist_submit_started`
  - `locale`, `variant`, `platform`, `referral_source`.

- `landing_waitlist_submit_succeeded`
  - `locale`, `variant`, `platform`, `referral_source`, `status` (`subscribed` | `already_subscribed`).

- `landing_waitlist_submit_failed`
  - `locale`, `variant`, `platform`, `referral_source`, `status` (`rate_limited` | `error`), `error_type`.

---

### iOS events

- `screen_viewed`
  - `screen_name` (`today` | `groups` | `profile` | `insights` | `onboarding`).

- `onboarding_step_completed`
  - `step_name` (`welcome`, `templates`, `notifications`, `join_groups`, `sign_in`, `sign_up`, `otp`).

- `auth_result`
  - `kind` (`sign_in` | `sign_up`), `provider` (`email` | `google` | `apple`), `status` (`success` | `failure`), optional `reason`.

- `habit_created`
  - `type`, `schedule_type`, `has_reminder`.

- `habit_updated`
  - `changed_fields` (array).

- `habit_deleted`
  - `type`.

- `habit_completion_toggled`
  - `type`, `status` (`completed` | `uncompleted`), `source`.

- `habit_counter_incremented`
  - `delta`, `count`, `target`.

- `habit_reminder_toggled`
  - `status` (`enabled` | `disabled`).

- `quote_opened`

- `quote_saved`

- `quote_shared`
  - optional `channel`.

- `group_opened`

- `group_created`

- `group_join_result`
  - `status` (`success` | `failure`), optional `reason`.

- `group_left`

- `group_sharing_updated`
  - `delta`, `total_shared`.

- `group_nudge_result`
  - `status` (`sent` | `duplicate` | `forbidden` | `error`), `habit_type`.

- `sync_cycle_result`
  - `trigger`, `status` (`success` | `failed`), `duration_ms`, `pulled_count`, `pushed_count`, optional `stage`, optional `error_code`.

---

### How to use PostHog in Sunnad

Use dashboard global filters first:
- `environment` to split dev vs prod.
- `surface` to separate landing vs iOS.
- `locale` and `theme` for content segmentation.

Recommended insight mapping:
- Conversion funnel: `landing_page_viewed -> landing_all_sections_viewed -> landing_waitlist_submit_succeeded`.
- Activation funnel: `screen_viewed(today) -> habit_created -> habit_completion_toggled(status=completed)`.
- Engagement trends: `quote_opened`, `quote_saved`, `quote_shared`, `group_created`, `group_join_result(status=success)`.
- Reliability trend: `sync_cycle_result(status=failed)` and failure-rate formula.

Operational guidance:
- Prefer trends/funnels/retention over raw live events for decisions.
- Keep dashboard cards grouped by conversion, activation, engagement, reliability.
- Do not create new events for simple label tweaks; add stable properties instead.
