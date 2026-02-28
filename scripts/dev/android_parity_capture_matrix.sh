#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage:
  $0 --iteration <name> [--device <serial>] [--font-scale <value>] [--package <applicationId>]

This script is interactive. For each screen/theme/locale tuple:
1) Navigate app to the requested screen
2) Press Enter
3) Script captures screenshot to docs/android/parity/<iteration>/...
USAGE
}

iteration=""
device=""
font_scale="1.0"
package_name="com.arystan.almasuly.sunnadandroid"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --iteration)
      iteration="$2"; shift 2 ;;
    --device)
      device="$2"; shift 2 ;;
    --font-scale)
      font_scale="$2"; shift 2 ;;
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

if [[ -z "$iteration" ]]; then
  usage
  exit 1
fi

screens=(
  today
  groups_guest
  groups_signed_in
  profile_guest
  profile_signed_in
  onboarding_welcome
  onboarding_templates
  onboarding_notifications
  onboarding_join_groups
  auth_sign_in
  auth_sign_up
  auth_otp
)

themes=(dark light)
locales=(en ru kk)

for screen in "${screens[@]}"; do
  for theme in "${themes[@]}"; do
    for locale in "${locales[@]}"; do
      echo
      echo "Prepare screen='$screen' theme='$theme' locale='$locale' and press Enter to capture."
      read -r _

      args=(
        --iteration "$iteration"
        --screen "$screen"
        --theme "$theme"
        --locale "$locale"
        --font-scale "$font_scale"
        --package "$package_name"
      )
      if [[ -n "$device" ]]; then
        args+=( --device "$device" )
      fi

      ./scripts/dev/android_parity_capture.sh "${args[@]}"
    done
  done
done

echo "Parity matrix capture complete for iteration '$iteration'."
