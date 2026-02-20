# Profile Username and Avatar (Stage 6A)

## Scope
- Signed-in users can edit username and avatar from the profile account card.
- Guest users cannot open profile editing.
- Username policy: `^[a-z0-9_]{3,20}$`.
- Avatar storage bucket: `avatars` (public).

## Data Model
- `public.profiles.avatar_path text null`.
- `public.profiles.username` format constrained with `profiles_username_format_check`.
- `public.claim_oauth_username(base text)` claims a collision-safe username for OAuth-first users.

## Storage Layout
- Bucket: `avatars`
- Object path: `profiles/<user_uuid>/avatar.<ext>`
- Policies:
  - public read for `avatars`
  - authenticated users can insert/update/delete only inside `profiles/<auth.uid()>/*`

## iOS Behavior
- Account card tap opens edit profile screen.
- Username is lowercased on submit and validated before save.
- Avatar pick uses `PhotosPicker`, client compresses to jpeg payload, then uploads.
- Avatar URL is cache-busted via `?v=<updated_at_epoch>` when profile is fetched.
- Removing avatar clears `profiles.avatar_path` and deletes owned storage object when applicable.

## OAuth Defaults
- On first Google/Apple sign-in, if username is missing:
  - app derives a base from provider metadata/email prefix
  - calls `claim_oauth_username(base)` to get unique username
- If provider avatar is present and `avatar_path` is empty:
  - provider avatar URL is persisted into `avatar_path`

## Manual Verification
1. Sign in with email account, edit username, verify immediate UI update.
2. Try invalid usernames and verify client/server validation behavior.
3. Upload avatar, relaunch app, verify avatar persists.
4. Remove avatar, relaunch app, verify default avatar icon.
5. Sign in with Google, verify username auto-claimed when missing/colliding.
