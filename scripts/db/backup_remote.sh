#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${SUPABASE_DB_URL:-}" ]]; then
  echo "SUPABASE_DB_URL must be set." >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required." >&2
  exit 1
fi

env_name="${1:-remote}"
output_root="${2:-backups/remote}"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup_id="${env_name}-${timestamp}"
backup_dir="${output_root}/${backup_id}"
mkdir -p "$backup_dir"

day_of_month="$(date -u +%d)"
day_of_week="$(date -u +%u)"
if [[ "$day_of_month" == "01" ]]; then
  backup_class="monthly"
elif [[ "$day_of_week" == "7" ]]; then
  backup_class="weekly"
else
  backup_class="daily"
fi
backup_class="${BACKUP_CLASS:-$backup_class}"

schema_file="${backup_dir}/${backup_id}-schema.sql"
data_file="${backup_dir}/${backup_id}-data.sql"
roles_file="${backup_dir}/${backup_id}-roles.sql"

supabase db dump --db-url "$SUPABASE_DB_URL" --file "$schema_file"
supabase db dump --db-url "$SUPABASE_DB_URL" --data-only --use-copy --file "$data_file"
supabase db dump --db-url "$SUPABASE_DB_URL" --role-only --file "$roles_file"

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

endpoint="${R2_ENDPOINT:-}"
if [[ -z "$endpoint" && -n "${R2_ACCOUNT_ID:-}" ]]; then
  endpoint="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"
fi

upload_enabled=false
if [[ -n "${R2_BUCKET:-}" && -n "$endpoint" && -n "${R2_ACCESS_KEY_ID:-}" && -n "${R2_SECRET_ACCESS_KEY:-}" ]]; then
  upload_enabled=true
fi

r2_prefix="${R2_PREFIX:-db-backups}/${env_name}/${backup_class}/${backup_id}"
manifest_artifacts='[]'

if [[ "$upload_enabled" == "true" ]]; then
  if ! command -v aws >/dev/null 2>&1; then
    echo "aws CLI is required for R2 upload." >&2
    exit 1
  fi
  export AWS_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID}"
  export AWS_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY}"
  export AWS_DEFAULT_REGION="auto"
fi

for file in "${artifact_files[@]}"; do
  filename="$(basename "$file")"
  sha256="$(shasum -a 256 "$file" | awk '{print $1}')"
  size_bytes="$(wc -c < "$file" | tr -d '[:space:]')"
  kind="schema"
  case "$filename" in
    *-data.sql|*-data.sql.enc) kind="data" ;;
    *-roles.sql|*-roles.sql.enc) kind="roles" ;;
  esac

  r2_key=""
  if [[ "$upload_enabled" == "true" ]]; then
    r2_key="${r2_prefix}/${filename}"
    aws s3 cp "$file" "s3://${R2_BUCKET}/${r2_key}" --endpoint-url "$endpoint"
  fi

  manifest_artifacts="$(
    jq -c \
      --arg kind "$kind" \
      --arg filename "$filename" \
      --arg sha256 "$sha256" \
      --arg r2_key "$r2_key" \
      --argjson size_bytes "$size_bytes" \
      '. + [{kind: $kind, file: $filename, sha256: $sha256, size_bytes: $size_bytes, r2_key: (if $r2_key == "" then null else $r2_key end)}]' \
      <<<"$manifest_artifacts"
  )"
done

migration_head="$(ls -1 supabase/migrations/*.sql 2>/dev/null | xargs -n1 basename | sort | tail -n1 || true)"
git_sha="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
manifest_path="${backup_dir}/manifest.json"

jq -n \
  --arg backup_id "$backup_id" \
  --arg env "$env_name" \
  --arg created_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg backup_class "$backup_class" \
  --arg git_sha "$git_sha" \
  --arg migration_head "$migration_head" \
  --argjson encrypted "$encrypted" \
  --arg upload_enabled "$upload_enabled" \
  --arg r2_bucket "${R2_BUCKET:-}" \
  --arg r2_prefix "$r2_prefix" \
  --argjson artifacts "$manifest_artifacts" \
  '{
    backup_id: $backup_id,
    environment: $env,
    backup_class: $backup_class,
    created_at_utc: $created_at,
    git_sha: $git_sha,
    migration_head: (if $migration_head == "" then null else $migration_head end),
    encrypted: $encrypted,
    uploaded_to_r2: ($upload_enabled == "true"),
    r2_bucket: (if $r2_bucket == "" then null else $r2_bucket end),
    r2_prefix: (if $upload_enabled == "true" then $r2_prefix else null end),
    artifacts: $artifacts
  }' > "$manifest_path"

if [[ "$upload_enabled" == "true" ]]; then
  aws s3 cp "$manifest_path" "s3://${R2_BUCKET}/${r2_prefix}/manifest.json" --endpoint-url "$endpoint"
fi

echo "Backup complete: $manifest_path"
