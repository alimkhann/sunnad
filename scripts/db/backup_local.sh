#!/usr/bin/env bash
set -euo pipefail

if ! command -v supabase >/dev/null 2>&1; then
  echo "supabase CLI is required." >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required." >&2
  exit 1
fi

output_root="${1:-backups/local}"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup_id="local-${timestamp}"
backup_dir="${output_root}/${backup_id}"
mkdir -p "$backup_dir"

schema_file="${backup_dir}/${backup_id}-schema.sql"
data_file="${backup_dir}/${backup_id}-data.sql"
roles_file="${backup_dir}/${backup_id}-roles.sql"

supabase db dump --local --file "$schema_file"
supabase db dump --local --data-only --use-copy --file "$data_file"
supabase db dump --local --role-only --file "$roles_file"

artifact_files=("$schema_file" "$data_file" "$roles_file")
encrypted=false
if [[ -n "${BACKUP_ENCRYPTION_PASSPHRASE:-}" ]]; then
  encrypted=true
  encrypted_files=()
  for file in "${artifact_files[@]}"; do
    encfile="${file}.enc"
    openssl enc -aes-256-cbc -pbkdf2 -salt -in "$file" -out "$encfile" -pass env:BACKUP_ENCRYPTION_PASSPHRASE
    rm -f "$file"
    encrypted_files+=("$encfile")
  done
  artifact_files=("${encrypted_files[@]}")
fi

manifest_artifacts='[]'
for file in "${artifact_files[@]}"; do
  filename="$(basename "$file")"
  sha256="$(shasum -a 256 "$file" | awk '{print $1}')"
  size_bytes="$(wc -c < "$file" | tr -d '[:space:]')"
  kind="schema"
  case "$filename" in
    *-data.sql|*-data.sql.enc) kind="data" ;;
    *-roles.sql|*-roles.sql.enc) kind="roles" ;;
  esac

  manifest_artifacts="$(
    jq -c \
      --arg kind "$kind" \
      --arg filename "$filename" \
      --arg sha256 "$sha256" \
      --argjson size_bytes "$size_bytes" \
      '. + [{kind: $kind, file: $filename, sha256: $sha256, size_bytes: $size_bytes}]' \
      <<<"$manifest_artifacts"
  )"
done

manifest_path="${backup_dir}/manifest.json"
jq -n \
  --arg backup_id "$backup_id" \
  --arg created_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson encrypted "$encrypted" \
  --argjson artifacts "$manifest_artifacts" \
  '{
    backup_id: $backup_id,
    environment: "local",
    created_at_utc: $created_at,
    encrypted: $encrypted,
    artifacts: $artifacts
  }' > "$manifest_path"

echo "Local backup complete: $manifest_path"
