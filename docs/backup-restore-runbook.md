# Backup and Restore Runbook

## Goals
- Keep backups free/low-cost.
- Support local and hosted project restore workflows.

## Backup commands
- Local DB dump:
  - `supabase db dump --local --file backups/local-$(date +%Y%m%d-%H%M%S).sql`
- Remote dev/prod dump:
  - `supabase db dump --db-url "$SUPABASE_DB_URL" --file backups/remote-$(date +%Y%m%d-%H%M%S).sql`

## Recommended schedule
- Local: daily snapshot during active development.
- Hosted dev: daily snapshot.
- Hosted prod: daily snapshot plus pre-release snapshot.

## Storage
- Encrypt backup artifacts.
- Store in low-cost object storage or private artifact bucket.
- Keep at least:
  - 7 daily backups
  - 4 weekly backups
  - 3 monthly backups

## Restore steps
1. Create a fresh target database/project.
2. Validate migration baseline on target.
3. Import SQL dump into target.
4. Verify table counts, indexes, and RLS behavior.
5. Run smoke tests for sign-in, habits CRUD, and quotes.

## Recovery drill
- Perform a full restore test at least once per month.
- Document restore duration and issues after each drill.
