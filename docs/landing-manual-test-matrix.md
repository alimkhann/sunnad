# Landing Page — Manual QA Test Matrix

## Overview

The Sunnad landing page has **5 visual variants × 3 locales × 2 device sizes**, requiring systematic testing of each combination.

---

## Test Dimensions

### Variants

| ID | Name | Key Visual Traits |
|---|---|---|
| 1 | Soft Glass | iOS-style blur, green accent, frosted bg |
| 2 | Editorial Serif | Playfair Display, cream tones, grain texture, horizontal rules |
| 3 | Geometric Clean | Uppercase headings, mint/teal, sharp containers |
| 4 | Warm Tactile | DM Serif Display, coral/peach, grain texture, rounded cards |
| 5 | Dark Cosmic | Dark bg, purple/violet gradients, animated star-dots |

### Locales

| Code | Language | Script | Concerns |
|---|---|---|---|
| `en` | English | Latin | Baseline |
| `ru` | Russian | Cyrillic | Longer words, wider text blocks |
| `kk` | Kazakh | Cyrillic | Longest words, potential text overflow |

### Device Sizes

| Size | Viewport | Notes |
|---|---|---|
| Mobile | 375×812 | iPhone-class, single column |
| Desktop | 1440×900 | Wide layout, multi-column features |

---

## Core Checklist (per combination)

### Navigation

- [ ] Nav bar renders with logo and CTA
- [ ] Mobile hamburger menu opens/closes
- [ ] Language links switch locale correctly
- [ ] Waitlist CTA in nav scrolls to form
- [ ] Nav blur/sticky works on scroll

### Hero Section

- [ ] Title renders in correct variant style (serif/uppercase/italic)
- [ ] Subtitle displays full text without truncation
- [ ] CTA button visible and styled per variant
- [ ] Phone frame renders with placeholder screen
- [ ] Phone frame screen glare overlay visible

### Features Section

- [ ] 4 feature cards render with icons
- [ ] Cards have hover lift effect (desktop)
- [ ] Card styling matches variant theme
- [ ] Text fully visible (no overflow in RU/KK)

### Screenshot Carousel

- [ ] 3 phone frames in horizontal scroll
- [ ] Scroll-snap works on mobile touch
- [ ] Placeholder screens show variant-appropriate colors

### FAQ Section

- [ ] All FAQ items render
- [ ] Accordion expand/collapse works
- [ ] No text truncation in expanded state (check KK)

### Waitlist Form

- [ ] Turnstile widget loads and renders checkbox
- [ ] Form submits successfully (test with real backend)
- [ ] Success state displays confirmation message
- [ ] "Already subscribed" state works for duplicate emails
- [ ] Error states display correctly
- [ ] Form validates email before submit
- [ ] Platform detection sends correct value

### Footer

- [ ] Links to Terms and Privacy work
- [ ] Language switcher works
- [ ] Year displays correctly

### Legal Pages

- [ ] `/en/terms` renders full Terms of Service
- [ ] `/en/privacy` renders full Privacy Policy
- [ ] Both pages render in all 3 locales
- [ ] Back navigation works

### Scroll Animations

- [ ] Sections fade in on scroll
- [ ] Stagger delays visible on feature cards
- [ ] Animations don't cause layout shift

### Variant-Specific Visual Checks

- [ ] V1: Frosted glass background visible behind hero
- [ ] V2: Grain texture overlay visible, italic serif title
- [ ] V3: Uppercase heading, sharp geometric containers
- [ ] V4: Grain texture, rounded card corners, coral accent
- [ ] V5: Star-dots sparkle animation, dark background, glow effects

---

## Test Matrix (30 combinations)

| # | Variant | Locale | Device | Nav | Hero | Features | Carousel | FAQ | Waitlist | Footer | Legal | Animations | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | V1 | en | Mobile | | | | | | | | | | |
| 2 | V1 | en | Desktop | | | | | | | | | | |
| 3 | V1 | ru | Mobile | | | | | | | | | | |
| 4 | V1 | ru | Desktop | | | | | | | | | | |
| 5 | V1 | kk | Mobile | | | | | | | | | | |
| 6 | V1 | kk | Desktop | | | | | | | | | | |
| 7 | V2 | en | Mobile | | | | | | | | | | |
| 8 | V2 | en | Desktop | | | | | | | | | | |
| 9 | V2 | ru | Mobile | | | | | | | | | | |
| 10 | V2 | ru | Desktop | | | | | | | | | | |
| 11 | V2 | kk | Mobile | | | | | | | | | | |
| 12 | V2 | kk | Desktop | | | | | | | | | | |
| 13 | V3 | en | Mobile | | | | | | | | | | |
| 14 | V3 | en | Desktop | | | | | | | | | | |
| 15 | V3 | ru | Mobile | | | | | | | | | | |
| 16 | V3 | ru | Desktop | | | | | | | | | | |
| 17 | V3 | kk | Mobile | | | | | | | | | | |
| 18 | V3 | kk | Desktop | | | | | | | | | | |
| 19 | V4 | en | Mobile | | | | | | | | | | |
| 20 | V4 | en | Desktop | | | | | | | | | | |
| 21 | V4 | ru | Mobile | | | | | | | | | | |
| 22 | V4 | ru | Desktop | | | | | | | | | | |
| 23 | V4 | kk | Mobile | | | | | | | | | | |
| 24 | V4 | kk | Desktop | | | | | | | | | | |
| 25 | V5 | en | Mobile | | | | | | | | | | |
| 26 | V5 | en | Desktop | | | | | | | | | | |
| 27 | V5 | ru | Mobile | | | | | | | | | | |
| 28 | V5 | ru | Desktop | | | | | | | | | | |
| 29 | V5 | kk | Mobile | | | | | | | | | | |
| 30 | V5 | kk | Desktop | | | | | | | | | | |

---

## Known Issues / Notes

- Turnstile widget requires a valid site key — in local dev, expect console errors if env var is not set.
- KK (Kazakh) has the longest words; watch for overflow in feature card titles and FAQ answers.
- V5 star-dots animation may be subtle on low-contrast displays.
- Phone frame placeholder screens are temporary — replace with real screenshots before launch.
