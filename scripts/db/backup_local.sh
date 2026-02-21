#!/usr/bin/env bash
set -euo pipefail

OUTPUT_DIR="${1:-backups/local}"
mkdir -p "$OUTPUT_DIR"

if ! command -v supabase >/dev/null 2>&1; then
  echo "supabase CLI is required." >&2
  exit 1
fi

timestamp="$(date +%Y%m%d-%H%M%S)"
outfile="$OUTPUT_DIR/local-${timestamp}.sql"

supabase db dump --local --file "$outfile"

echo "Local backup written: $outfile"

if [[ -n "${BACKUP_ENCRYPTION_PASSPHRASE:-}" ]]; then
  encfile="${outfile}.enc"
  openssl enc -aes-256-cbc -pbkdf2 -salt -in "$outfile" -out "$encfile" -pass env:BACKUP_ENCRYPTION_PASSPHRASE
  rm -f "$outfile"
  echo "Encrypted backup written: $encfile"
fi
