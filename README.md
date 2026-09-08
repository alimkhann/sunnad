# Sunnad

Offline-first habit tracker for Muslims. SwiftUI iOS, Compose Android, Supabase sync. English, Russian, and Kazakh.

On the App Store as [Adat, Islamic habit tracker](https://apps.apple.com/kz/app/adat-islamic-habit-tracker/id6761636021).

Today shows only habits scheduled today. Streaks, one reminder per habit, quote of the day with save and share. Dhikr habits use a built-in counter. Groups add light accountability. Three tabs only: Today, Groups, Profile.

## Why I built this

I kept quitting habit apps because they needed internet to check a box and pushed features I never asked for. Sunnad works on a plane. Sync is an add-on, not a requirement.

## How it works

Input: you create a habit with a weekly schedule. The phone stores everything locally (SwiftData on iOS, Room on Android) and shows it on Today when due.

Sync: logged-in users sync habits, completions, and group snapshots through Supabase Postgres with row-level security. Guests never touch the network.

Human control: reminders are local, one per habit. Friend reminders send a real push through an Edge Function with rate limits, never an in-app banner you can fake.

Risk I designed around: someone reading or writing another user's habits. The guardrail is Postgres RLS on every user table with `auth.uid()` ownership. The client never decides access.

## Quickstart

```sh
# iOS: open sunnad-ios/sunnad-ios.xcodeproj in Xcode and run

# Android (from repo root)
cd sunnad-android && ./gradlew assembleDebug

# Backend (needs Supabase CLI)
supabase start
supabase db reset

# Landing page
cd landing && npm install && npm run dev
```

Copy `landing/.env.local.example` to `.env.local` for local web config. Never commit service role keys, JWT secrets, or APNS keys.

## Layout

```
sunnad-ios/       SwiftUI app, the behavioral reference
sunnad-android/   Compose + Material 3, parity with iOS
supabase/         local config, migrations, seed, Edge Functions
landing/          Next.js marketing page (waitlist, links, terms)
admin/            tiny web admin (added when needed)
docs/             PRD, UX notes, schema notes, translation glossary
```

See `AGENTS.md` for working rules. iOS is the reference build. Android follows it.

## Roadmap

- Android parity with the iOS feature set
- Group accountability polish once sync proves itself
- Whatever the store reviews complain about loudest

## Contact

Alimkhan Yergebayev — alimkhan.yergebayev@gmail.com

Project link: [https://github.com/alimkhann/sunnad](https://github.com/alimkhann/sunnad)
