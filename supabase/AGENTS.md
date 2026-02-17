# AGENTS.md — /supabase (DB/Auth/RLS/Edge Functions)

This file applies to work inside /supabase (and /functions if you decide to scope it here). Follow the root AGENTS.md too; if there’s a conflict, this file wins for Supabase changes. Agents generally read the nearest AGENTS.md for the area being edited.

## Scope
- Supabase Postgres schema, migrations, RLS policies, seed data.
- Optional: Edge Functions for server-side secret work (push notifications, admin actions, rate limiting).
- Treat Postgres + RLS as the primary authorization boundary.

## Local dev workflow (preferred)
- Use Supabase CLI with migrations as source of truth.
- Common commands:
  - Start stack: `supabase start`
  - Create migration: `supabase migration new <name>`
  - Apply + verify from scratch: `supabase db reset` (replays migrations + seed)
  - Deploy migrations to a remote project: `supabase db push`

Rule: If `supabase db reset` succeeds on a clean local DB, migrations are much more likely to succeed elsewhere.

## RLS requirements (must)
- Enable RLS on all user data tables.
- Write explicit policies:
  - Owner read/write via `auth.uid()`.
  - Group membership checks for group-shared data.
- Never rely on “client checks” for permissions.
- Document policies briefly in the migration or /docs.

## When to use Data API vs Edge Functions
Default: use Data API + RLS for standard CRUD.

Use Edge Functions when:
- You need secrets (APNS keys for push, admin panel auth secrets).
- You need non-bypassable rate limiting for sensitive actions (e.g., “remind friend”).
- You need server-side validation that must not run on clients.

## Migrations / seed / environments
- All schema changes go through migrations (SQL).
- Seed data (templates, initial quotes) goes into `supabase/seed.sql` or your repo’s chosen seed mechanism.
- Keep “template habits” and “quotes” structured so admin can manage them (but MVP can ship with static seeded content).

## Logging / safety
- Never commit secrets (service role key, JWT secret, APNS private keys).
- Prefer structured logs in Edge Functions (request id, user id, action, status).
- Keep admin operations behind service role / Edge Function; do not expose privileged actions via client.

## Output format for DB changes
When proposing DB changes:
- List new/changed tables
- List RLS policies added/changed (plain English summary)
- Provide migration file names + what changed
- Provide how to test locally (supabase start/reset + sample queries)
