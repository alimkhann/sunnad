# Android Strategy Risk/Cost Matrix

## Options

| Path | Time to full Android parity | Upfront cost | Ongoing risk | Primary risk | Decision |
|---|---:|---:|---:|---|---|
| KMP extraction for domain first | 12-16 weeks | High | Medium | migration/tooling complexity and iOS integration churn | Not now |
| Shared backend contract + duplicated Kotlin domain | 8-10 weeks | Medium | Medium | logic drift across platforms | Recommended |
| API-first schema generation as primary strategy | 10-13 weeks | Medium-High | Medium-High | generator drift and model mismatch | Selective only |

## Cost controls for selected path
- Port iOS domain logic into Kotlin with direct parity tests.
- Keep contracts stable through migration-driven schema and checked OpenAPI artifact.
- Isolate sync/auth/notifications behind interfaces to allow iterative rollout.

## Exit criteria to revisit KMP
Revisit KMP only when:
1. Domain fixes are repeatedly duplicated across iOS and Android in multiple sprints.
2. Kotlin/Swift rule divergence becomes a recurring production risk.
3. Team capacity can absorb migration overhead without blocking parity roadmap.

## Delivery risk register
- `R1` Domain drift:
  Mitigation: parity tests for schedule, streak, completion clamping, quote day key.
- `R2` Sync complexity:
  Mitigation: local-first writes, outbox queue, explicit retry/backoff, no-op safe fallback.
- `R3` Auth provider variance:
  Mitigation: Apple auth scaffolded but not launch-blocking.
- `R4` Localization regressions:
  Mitigation: EN/RU/KK from start, pseudo-locale pass, strict no-hardcoded-strings rule.
- `R5` UI quality regression:
  Mitigation: Material 3 tokens, adaptive nav, accessibility checks in acceptance matrix.
