#!/usr/bin/env bash

set -euo pipefail

MAILPIT_URL="${MAILPIT_URL:-http://127.0.0.1:54324}"
MODE="${1:-reset}" # confirm|reset|any

case "$MODE" in
  confirm|reset|any) ;;
  *)
    echo "Usage: $0 [confirm|reset|any]"
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
  echo "No matching Mailpit message found (mode=${MODE})."
  exit 0
fi

message_json="$(curl -fsS "${MAILPIT_URL}/api/v1/message/${message_id}")"
subject="$(echo "$message_json" | jq -r '.Subject // "unknown"')"
to_email="$(echo "$message_json" | jq -r '.To[0].Address // "unknown"')"

body="$(echo "$message_json" | jq -r '.HTML // .Text // ""')"
verify_link="$(
  echo "$body" | rg -o 'http://127\.0\.0\.1:55421/auth/v1/verify[^"'"'"'[:space:]<)]*' -m 1 || true
)"
verify_link="${verify_link//&amp;/&}"

if [[ -z "$verify_link" ]]; then
  echo "Could not find local verify link in email body."
  exit 1
fi

if ! xcrun simctl list devices booted | rg -q "Booted"; then
  echo "No booted iOS simulator found."
  echo "Boot one first, e.g. open Simulator app or run your app from Xcode."
  exit 1
fi

echo "Opening link in booted simulator Safari..."
echo "Subject: ${subject}"
echo "To: ${to_email}"
echo "URL: ${verify_link}"
xcrun simctl openurl booted "$verify_link"

echo "Done. Safari in simulator should redirect to sunnad://auth-callback and return to app."
