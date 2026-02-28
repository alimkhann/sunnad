# Android Parity Tooling

Use an iterative capture stack that works even when MCP servers are unavailable in the current session.

## Recommended Tooling
- `@mobilenext/mobile-mcp`: structured mobile automation and screenshots when server is active.
- `adb`: deterministic fallback for screenshot capture and device state controls.

## Preflight (Required each iteration)
1. Verify Android device is visible:
   - `adb devices`
2. Verify MCP server is active in session:
   - `list_mcp_resources` should include `mobile-mcp`.
3. If MCP is unavailable, continue with script fallback:
   - `scripts/dev/android_parity_capture.sh`
   - `scripts/dev/android_parity_capture_matrix.sh`

## Current Session Note (2026-02-28)
- `mobile-mcp` is not exposed in the active Codex MCP resource list.
- `adb devices` currently reports no attached Android device.
- Until both are available, parity capture is blocked and implementation changes should be verified via local build/unit tests only.

## Why Two Paths
- MCP path: richer structured interaction and repeatable flows.
- ADB path: always-available deterministic capture baseline.

## Minimum Automation Goals
- Automate startup routing checks.
- Automate onboarding/auth happy paths.
- Keep screenshot capture deterministic through ADB scripts in `scripts/dev`.
