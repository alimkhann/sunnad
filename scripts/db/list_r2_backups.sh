#!/usr/bin/env bash
set -euo pipefail

environment="${1:-prod}"

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

export AWS_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID}"
export AWS_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY}"
export AWS_DEFAULT_REGION="auto"

prefix="${R2_PREFIX:-db-backups}/${environment}/"

aws s3api list-objects-v2 \
  --bucket "$R2_BUCKET" \
  --prefix "$prefix" \
  --endpoint-url "$endpoint" \
  --output json |
  jq -r '
    .Contents // []
    | map(select(.Key | endswith("/manifest.json")))
    | sort_by(.LastModified)
    | reverse
    | .[]
    | [.LastModified, .Size, .Key]
    | @tsv
  '
