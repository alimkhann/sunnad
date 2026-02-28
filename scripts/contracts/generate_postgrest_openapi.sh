#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_FILE="$ROOT_DIR/docs/contracts/postgrest.openapi.json"

API_URL="${SUNNAD_SUPABASE_API_URL:-http://127.0.0.1:55421}"
ANON_KEY="${SUNNAD_SUPABASE_ANON_KEY:-}"

if [[ -z "$ANON_KEY" ]]; then
  echo "SUNNAD_SUPABASE_ANON_KEY is required to fetch PostgREST OpenAPI." >&2
  echo "Set it from your local Supabase config or environment." >&2
  exit 1
fi

curl --fail --silent --show-error \
  -H "apikey: $ANON_KEY" \
  "$API_URL/rest/v1/" \
  | jq . > "$OUT_FILE"

echo "Wrote $OUT_FILE"
