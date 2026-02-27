#!/usr/bin/env bash
set -euo pipefail

required_vars=(R2_BUCKET R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY)
for var in "${required_vars[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    echo "Missing required variable: ${var}" >&2
    exit 1
  fi
done

endpoint="${R2_ENDPOINT:-}"
if [[ -z "$endpoint" ]]; then
  if [[ -z "${R2_ACCOUNT_ID:-}" ]]; then
    echo "Set R2_ENDPOINT or R2_ACCOUNT_ID." >&2
    exit 1
  fi
  endpoint="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required." >&2
  exit 1
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI is required." >&2
  exit 1
fi

prefix="${R2_PREFIX:-db-backups}"
tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

jq -n --arg p "$prefix" '{
  Rules: [
    {ID: "dev-daily-retention", Status: "Enabled", Filter: {Prefix: ($p + "/dev/daily/")}, Expiration: {Days: 7}},
    {ID: "dev-weekly-retention", Status: "Enabled", Filter: {Prefix: ($p + "/dev/weekly/")}, Expiration: {Days: 28}},
    {ID: "dev-monthly-retention", Status: "Enabled", Filter: {Prefix: ($p + "/dev/monthly/")}, Expiration: {Days: 90}},
    {ID: "prod-daily-retention", Status: "Enabled", Filter: {Prefix: ($p + "/prod/daily/")}, Expiration: {Days: 7}},
    {ID: "prod-weekly-retention", Status: "Enabled", Filter: {Prefix: ($p + "/prod/weekly/")}, Expiration: {Days: 28}},
    {ID: "prod-monthly-retention", Status: "Enabled", Filter: {Prefix: ($p + "/prod/monthly/")}, Expiration: {Days: 90}},
    {ID: "abort-incomplete-multipart", Status: "Enabled", AbortIncompleteMultipartUpload: {DaysAfterInitiation: 7}}
  ]
}' > "$tmp_file"

export AWS_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID}"
export AWS_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY}"
export AWS_DEFAULT_REGION="auto"

aws s3api put-bucket-lifecycle-configuration \
  --bucket "$R2_BUCKET" \
  --lifecycle-configuration "file://${tmp_file}" \
  --endpoint-url "$endpoint"

echo "Lifecycle policy configured for bucket: ${R2_BUCKET}"
