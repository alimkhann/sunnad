#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <target_db_url> <manifest_path>" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required." >&2
  exit 1
fi

target_db_url="$1"
manifest_path="$2"

if [[ ! -f "$manifest_path" ]]; then
  echo "Manifest file not found: $manifest_path" >&2
  exit 1
fi

manifest_dir="$(cd "$(dirname "$manifest_path")" && pwd)"

schema_file="$(jq -r '.artifacts[] | select(.kind == "schema") | .file' "$manifest_path" | head -n 1)"
data_file="$(jq -r '.artifacts[] | select(.kind == "data") | .file' "$manifest_path" | head -n 1)"
roles_file="$(jq -r '.artifacts[] | select(.kind == "roles") | .file // empty' "$manifest_path" | head -n 1)"

if [[ -z "$schema_file" || -z "$data_file" ]]; then
  echo "Manifest must include schema and data artifacts." >&2
  exit 1
fi

schema_path="${manifest_dir}/${schema_file}"
data_path="${manifest_dir}/${data_file}"
roles_path=""
if [[ -n "$roles_file" ]]; then
  roles_path="${manifest_dir}/${roles_file}"
fi

if [[ -n "$roles_path" ]]; then
  scripts/db/restore_verify.sh "$target_db_url" "$schema_path" "$data_path" "$roles_path"
else
  scripts/db/restore_verify.sh "$target_db_url" "$schema_path" "$data_path"
fi
