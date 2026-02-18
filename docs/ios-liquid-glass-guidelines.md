# iOS Liquid Glass Guidelines (Sunnad)

This project follows a **system-only** Liquid Glass policy.

## Policy
- Use the system's native appearance for tab bars, navigation bars/toolbars, and sheets/modals.
- Keep content surfaces (list rows, cards, forms, full-screen backgrounds) opaque and readable.
- Do not add custom Liquid Glass/material effects in the content layer.

## Allowed
- Standard `TabView` tab bar appearance.
- Standard `NavigationStack`/toolbar appearance.
- Standard `sheet`/`fullScreenCover` chrome.

## Disallowed
- `glassEffect(...)` on custom app content.
- `GlassEffectContainer` for content rows/cards.
- SwiftUI material backgrounds in content surfaces:
  - `.ultraThinMaterial`
  - `.thinMaterial`
  - `.regularMaterial`
  - `.thickMaterial`
- “Floating/glassy” card treatment that weakens control-vs-content hierarchy.

## Exception rule
- Any exception needs explicit product/design review and must be documented in the PR description.

## Audit checklist
Run these checks before merge:

```bash
rg -n "glassEffect\\(|GlassEffectContainer|\\.ultraThinMaterial|\\.thinMaterial|\\.regularMaterial|\\.thickMaterial" sunnad-ios/sunnad-ios -g '*.swift'
```

Expected result: **no matches**.

Manual reviewer checklist:
- No custom glass in content layer.
- Primary controls remain visually distinct from content.
- Readability remains strong at larger Dynamic Type sizes.
- UI remains clear with Reduce Transparency enabled.
