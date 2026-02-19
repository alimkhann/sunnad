#!/usr/bin/env bash
set -euo pipefail

if ! command -v supabase >/dev/null 2>&1; then
  echo "supabase CLI is required." >&2
  exit 1
fi

echo "== Sunnad dev->prod promotion checklist =="
echo "1) Ensure migrations are committed under supabase/migrations/."
echo "2) Validate locally: supabase db reset"
echo "3) Run smoke SQL locally."
echo "4) Push migrations to dev and verify app flows."
echo "5) Take pre-release dev/prod backups."
echo "6) Push same migration set to prod."
echo "7) Run post-deploy smoke checks against prod."

echo
echo "Set these environment variables to execute now:"
echo "  DEV_DB_URL, PROD_DB_URL"

action="${1:-dry-run}"
if [[ "$action" != "execute" ]]; then
  echo "Dry-run only. Use: $0 execute"
  exit 0
fi

if [[ -z "${DEV_DB_URL:-}" || -z "${PROD_DB_URL:-}" ]]; then
  echo "DEV_DB_URL and PROD_DB_URL must be set for execute mode." >&2
  exit 1
fi

echo "Pushing migrations to dev..."
supabase db push --db-url "$DEV_DB_URL"

echo "Pushing migrations to prod..."
supabase db push --db-url "$PROD_DB_URL"

echo "Promotion completed."
