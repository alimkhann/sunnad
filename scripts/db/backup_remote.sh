#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${SUPABASE_DB_URL:-}" ]]; then
  echo "SUPABASE_DB_URL must be set." >&2
  exit 1
fi

env_name="${1:-remote}"
output_dir="${2:-backups/remote}"
mkdir -p "$output_dir"

timestamp="$(date +%Y%m%d-%H%M%S)"
outfile="$output_dir/${env_name}-${timestamp}.sql"

supabase db dump --db-url "$SUPABASE_DB_URL" --file "$outfile"

echo "Remote backup written: $outfile"

if [[ -n "${BACKUP_ENCRYPTION_PASSPHRASE:-}" ]]; then
  encfile="${outfile}.enc"
  openssl enc -aes-256-cbc -pbkdf2 -salt -in "$outfile" -out "$encfile" -pass env:BACKUP_ENCRYPTION_PASSPHRASE
  rm -f "$outfile"
  echo "Encrypted backup written: $encfile"
fi
