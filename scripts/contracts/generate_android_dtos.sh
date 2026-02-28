#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SPEC="$ROOT_DIR/docs/contracts/postgrest.openapi.json"
OUT_DIR="$ROOT_DIR/sunnad-android/app/src/main/java/com/arystan/almasuly/sunnadandroid/data/remote/generated"
PACKAGE="com.arystan.almasuly.sunnadandroid.data.remote.generated"

if [[ ! -f "$SPEC" ]]; then
  echo "Spec not found: $SPEC" >&2
  echo "Run scripts/contracts/generate_postgrest_openapi.sh first." >&2
  exit 1
fi

if ! command -v openapi-generator-cli >/dev/null 2>&1; then
  echo "openapi-generator-cli is required. Install it and rerun." >&2
  exit 1
fi

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

openapi-generator-cli generate \
  -i "$SPEC" \
  -g kotlin \
  -o "$ROOT_DIR/.artifacts/openapi-kotlin" \
  --global-property models \
  --additional-properties packageName="$PACKAGE",serializationLibrary=kotlinx_serialization

echo "Generated Kotlin models under $ROOT_DIR/.artifacts/openapi-kotlin (copy selected DTOs into app source as needed)."
