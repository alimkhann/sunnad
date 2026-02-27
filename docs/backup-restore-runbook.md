# Backup and Restore Runbook

## Goals
- Keep backups free/low-cost.
- Support local and hosted project restore workflows.
- Avoid committing raw SQL dumps into git.
- Maintain encrypted, restorable backups for schema + data + roles.

## Backup commands
- Local (schema + data + roles + manifest):
  - `scripts/db/backup_local.sh [output_dir]`
- Remote dev/prod (schema + data + roles + manifest):
  - `SUPABASE_DB_URL=... scripts/db/backup_remote.sh [env_name] [output_dir]`

## Scripted workflow
- Set `BACKUP_ENCRYPTION_PASSPHRASE` to encrypt backup artifacts (`.sql.enc`).
- `backup_remote.sh` auto-classifies backups as `daily`, `weekly`, `monthly` in UTC:
  - day 1 of month -> monthly
  - Sunday -> weekly
  - everything else -> daily
- A `manifest.json` is generated per backup and includes:
  - backup ID and timestamp
  - git SHA + migration head
  - artifact list (`schema`, `data`, `roles`) + checksum + optional R2 keys

## Cloudflare R2 setup (free/low-cost target)
Required secrets/vars:
- `R2_BUCKET`
- `R2_ACCESS_KEY_ID`
- `R2_SECRET_ACCESS_KEY`
- `R2_ACCOUNT_ID` (or `R2_ENDPOINT`)
- `R2_PREFIX` (optional, defaults to `db-backups`)

GitHub Actions secrets for automated backups:
- `SUPABASE_DEV_DB_URL`
- `SUPABASE_PROD_DB_URL`
- `BACKUP_ENCRYPTION_PASSPHRASE`
- `R2_BUCKET`
- `R2_ACCESS_KEY_ID`
- `R2_SECRET_ACCESS_KEY`
- `R2_ACCOUNT_ID`

GitHub Actions secrets for restore drills:
- `SUPABASE_RESTORE_DEV_DB_URL`
- `SUPABASE_RESTORE_PROD_DB_URL`

Apply lifecycle retention policy:
- `scripts/db/configure_r2_lifecycle.sh`
- Retention rules:
  - daily: 7 days
  - weekly: 28 days
  - monthly: 90 days

List backup inventory (searchable by key):
- `scripts/db/list_r2_backups.sh [dev|prod]`

## Recommended schedule
- Local: ad-hoc before risky migrations.
- Hosted dev/prod: nightly via GitHub Actions `backup-nightly.yml`.
- Restore drill: weekly via GitHub Actions `restore-drill.yml`.

## Storage
- Encrypt backup artifacts.
- Upload encrypted artifacts to Cloudflare R2.
- Keep encryption passphrase only in:
  - GitHub environment secrets
  - offline password manager

## Restore steps
1. Create a fresh disposable target database.
2. Download a backup manifest and all listed artifacts.
3. Run:
   - `scripts/db/restore_from_manifest.sh <target_db_url> <manifest_path>`
4. Verify baseline counts and smoke checks.
5. Record restore duration/outcome.

## Scripted restore verification
- `scripts/db/restore_verify.sh <target_db_url> <schema_dump> <data_dump> [roles_dump]`
- `scripts/db/restore_from_manifest.sh <target_db_url> <manifest_path>`
- Decryption is automatic for `.enc` files when `BACKUP_ENCRYPTION_PASSPHRASE` is set.

## Recovery drill
- Run weekly restore drill against disposable dev/prod restore targets.
- Smoke checks currently include:
  - baseline restore table checks
  - `supabase/tests/stage4_smoke.sql`
- Document restore duration and issues after each drill.

## Promotion helper
- `scripts/db/promote_checklist.sh` prints the required local->dev->prod checklist.
- `scripts/db/promote_checklist.sh execute` runs `supabase db push` for both:
  - `DEV_DB_URL`
  - `PROD_DB_URL`
