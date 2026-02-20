#!/usr/bin/env bash

set -euo pipefail

MAILPIT_URL="${MAILPIT_URL:-http://127.0.0.1:54324}"
MODE="${1:-any}" # any|confirm|reset

case "$MODE" in
  any|confirm|reset) ;;
  *)
    echo "Usage: $0 [any|confirm|reset]"
    exit 1
    ;;
esac

messages_json="$(curl -fsS "${MAILPIT_URL}/api/v1/messages")"

message_id="$(
  echo "$messages_json" | jq -r --arg mode "$MODE" '
    .messages
    | map(
        if $mode == "confirm" then
          select(.Subject == "Confirm Your Email")
        elif $mode == "reset" then
          select(.Subject == "Reset Your Password")
        else
          .
        end
      )
    | .[0].ID // empty
  '
)"

if [[ -z "$message_id" ]]; then
  echo "No matching message found (mode=${MODE})."
  exit 0
fi

message_json="$(curl -fsS "${MAILPIT_URL}/api/v1/message/${message_id}")"

to_email="$(echo "$message_json" | jq -r '.To[0].Address // "unknown"')"
subject="$(echo "$message_json" | jq -r '.Subject // "unknown"')"
created="$(echo "$message_json" | jq -r '.Created // "unknown"')"

body="$(echo "$message_json" | jq -r '.HTML // .Text // ""')"

deep_link="$(
  echo "$body" | rg -o 'sunnad://auth-callback[^"'"'"'[:space:]<)]*' -m 1 || true
)"

otp_code="$(
  echo "$body" | rg -o '\b[0-9]{6}\b' -m 1 || true
)"

echo "Mailpit: ${MAILPIT_URL}"
echo "Mode: ${MODE}"
echo "To: ${to_email}"
echo "Subject: ${subject}"
echo "Created: ${created}"
echo "Message ID: ${message_id}"
if [[ -n "${deep_link}" ]]; then
  echo "Deep link: ${deep_link}"
fi
if [[ -n "${otp_code}" ]]; then
  echo "OTP: ${otp_code}"
fi

echo
echo "Preview:"
echo "----------------------------------------"
echo "$body" | sed -E 's/<[^>]+>/ /g' | tr -s ' ' | fold -s -w 120 | head -n 20
echo "----------------------------------------"
