#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage:
  $0 --iteration <name> --screen <screen> --theme <dark|light> --locale <en|ru|kk> [--font-scale <value>] [--device <serial>] [--package <applicationId>]

Example:
  $0 --iteration iteration-01 --screen today --theme dark --locale ru --font-scale 1.0
USAGE
}

iteration=""
screen=""
theme=""
locale=""
font_scale="1.0"
device=""
package_name="com.arystan.almasuly.sunnadandroid"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --iteration)
      iteration="$2"; shift 2 ;;
    --screen)
      screen="$2"; shift 2 ;;
    --theme)
      theme="$2"; shift 2 ;;
    --locale)
      locale="$2"; shift 2 ;;
    --font-scale)
      font_scale="$2"; shift 2 ;;
    --device)
      device="$2"; shift 2 ;;
    --package)
      package_name="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1 ;;
  esac
done

if [[ -z "$iteration" || -z "$screen" || -z "$theme" || -z "$locale" ]]; then
  usage
  exit 1
fi

if [[ "$theme" != "dark" && "$theme" != "light" ]]; then
  echo "Theme must be dark or light" >&2
  exit 1
fi

if ! command -v adb >/dev/null 2>&1; then
  echo "adb is required but not found in PATH" >&2
  exit 1
fi

adb_cmd=(adb)
if [[ -n "$device" ]]; then
  adb_cmd+=( -s "$device" )
fi

"${adb_cmd[@]}" wait-for-device

# Theme and font-scale normalization for deterministic captures.
if [[ "$theme" == "dark" ]]; then
  "${adb_cmd[@]}" shell cmd uimode night yes >/dev/null
else
  "${adb_cmd[@]}" shell cmd uimode night no >/dev/null
fi
"${adb_cmd[@]}" shell settings put system font_scale "$font_scale" >/dev/null

# Prefer per-app locale command when available. Fallback to default locale if unsupported.
if "${adb_cmd[@]}" shell cmd activity help 2>/dev/null | grep -q "set-app-locale"; then
  "${adb_cmd[@]}" shell cmd activity set-app-locale "$package_name" "$locale" >/dev/null || true
else
  echo "set-app-locale command unavailable on this device. Set locale manually to $locale before capture."
fi

output_dir="docs/android/parity/${iteration}/${screen}/${theme}"
mkdir -p "$output_dir"
output_file="${output_dir}/${locale}.png"

"${adb_cmd[@]}" exec-out screencap -p > "$output_file"

echo "Captured: $output_file"
