# Android Visual Parity Artifacts

This folder stores iterative Android parity captures against iOS reference shots.

## Source of Truth
- iOS references: `landing/public/app-screenshots`
- Android output schema: `docs/android/parity/<iteration>/<screen>/<theme>/<locale>.png`

Example:
- `docs/android/parity/iteration-01/today/dark/ru.png`
- `docs/android/parity/iteration-01/profile_signed_in/light/en.png`

## Required Screen Set per Iteration
- `today`
- `groups_guest`
- `groups_signed_in`
- `profile_guest`
- `profile_signed_in`
- `onboarding_welcome`
- `onboarding_templates`
- `onboarding_notifications`
- `onboarding_join_groups`
- `auth_sign_in`
- `auth_sign_up`
- `auth_otp`

## Required Variants
- Themes: `dark`, `light`
- Locales: `en`, `ru`, `kk`
- Font scale: at least `1.0` and `1.15` spot checks for major screens

## Capture Scripts
- Single shot: `scripts/dev/android_parity_capture.sh`
- Full matrix (interactive): `scripts/dev/android_parity_capture_matrix.sh`

## Notes
- Use one physical device baseline for each iteration to avoid density drift.
- Keep screenshots edge-to-edge and status-bar visible for hierarchy/inset verification.
