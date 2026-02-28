# Backend Contract Artifacts

This folder stores checked API contract artifacts consumed by mobile clients.

## Files
- `postgrest.openapi.json`: OpenAPI snapshot for PostgREST surface.

## Refresh workflow
1. Start local Supabase stack:
   - `supabase start`
2. Export OpenAPI spec:
   - `scripts/contracts/generate_postgrest_openapi.sh`
3. Regenerate Android DTOs (optional scaffold):
   - `scripts/contracts/generate_android_dtos.sh`
4. Optional drift check helper (manual, non-CI-blocking):
   - `scripts/contracts/check_android_contract_drift.sh`

Use these artifacts for drift detection in CI and cross-platform contract review.
