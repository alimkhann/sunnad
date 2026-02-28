# Android Visual Parity + Onboarding/Auth Recovery Plan

## Goal
Ship Android MVP with iOS-parity information architecture and interaction rhythm while staying native Material 3.

## Execution Defaults
- Backend target for this execution batch: `sunnad-dev`.
- Screenshot loop: `adb` scripts are authoritative now.
- `mobile-mcp` is enabled when available in the active Codex session, but does not block implementation.

## Iteration Order
1. Root routing + onboarding/auth recovery.
2. Design primitives and token normalization.
3. Today IA parity.
4. Groups IA parity.
5. Profile IA parity.
6. Insets/motion/accessibility polish.
7. Parity matrix capture and regression gates.

## Locked Constraints
- Exactly 3 tabs: Today, Groups, Profile.
- Auth is full-screen flow, not inline Profile form.
- Onboarding is first-class route graph.
- EN/RU/KK parity each iteration.
- Dark and light parity each iteration.

## QA Gate per Iteration
- `./gradlew assembleDebug`
- `./gradlew testDebugUnitTest`
- Screenshot capture to `docs/android/parity/<iteration>/...`
- Checklist pass from `docs/android/parity/checklist.md`
