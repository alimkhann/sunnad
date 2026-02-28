#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SPEC_FILE="$ROOT_DIR/docs/contracts/postgrest.openapi.json"

echo "Generating PostgREST OpenAPI snapshot..."
"$ROOT_DIR/scripts/contracts/generate_postgrest_openapi.sh"

if git -C "$ROOT_DIR" diff --quiet -- "$SPEC_FILE"; then
  echo "No contract drift detected in $SPEC_FILE"
  exit 0
fi

echo "Contract drift detected in $SPEC_FILE"
echo "Review changes and regenerate DTOs if needed:"
echo "  $ROOT_DIR/scripts/contracts/generate_android_dtos.sh"
exit 1
