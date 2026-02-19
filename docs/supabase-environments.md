# Supabase Environments (No-Pro Workflow)

## Environments
- `local`: daily development with Supabase CLI (`supabase start`).
- `sunnad-dev`: hosted free project for integration testing.
- `sunnad-prod`: hosted free project for production data.

## Branching policy
- Do not rely on paid hosted preview branches for routine workflow.
- Validate schema locally first, then promote to dev, then prod.

## Schema promotion flow
1. Create migration SQL in `supabase/migrations/`.
2. Verify from scratch locally:
   - `supabase db reset`
   - `psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/stage4_smoke.sql`
3. Push to dev project and smoke test.
4. Push the same migration set to prod.

## Data safety rules
- Never commit secrets or service keys.
- Keep RLS as the authorization layer.
- All schema changes are migration-driven.

## Stage-4 contract checklist
- Group create path uses `public.create_group_with_owner(...)`.
- Group join by invite code is case-insensitive and trimmed.
- `habits.schedule` accepts only `daily|weekly`.
- Ownership FKs are in place for completions/shared-habits to habits.
- `group_members` and `saved_quotes` include `updated_at` for sync windows.
