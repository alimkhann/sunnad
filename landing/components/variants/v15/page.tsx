"use client";

import Link from "next/link";
import { FormEvent, useState } from "react";
import { motion, useReducedMotion } from "framer-motion";
import { submitWaitlist } from "@/lib/waitlist-submit";
import { Turnstile } from "@/components/turnstile";
import { landingConfig } from "@/lib/config";

type Props = { locale: string; variant: string };

const timeline = [
  {
    time: "Morning",
    title: "Open Today",
    body: "See only the habits due right now and start with a clear first action.",
    image: "/app-screenshots/en_today_light.PNG",
    tone: "light",
  },
  {
    time: "During the day",
    title: "Keep count with dhikr habits",
    body: "Use counter-style habit detail for adhkar without breaking your routine flow.",
    image: "/app-screenshots/en_dhikr_dark.PNG",
    tone: "dark",
  },
  {
    time: "Check-in",
    title: "Groups for accountability",
    body: "Share progress with trusted people and send gentle reminders when it helps.",
    image: "/app-screenshots/en_groups_dark.PNG",
    tone: "dark",
  },
] as const;

function AtlasWaitlist({ locale }: { locale: string }): React.JSX.Element {
  const [email, setEmail] = useState("");
  const [token, setToken] = useState("");
  const [status, setStatus] = useState<"idle" | "loading" | "success" | "error">(
    "idle",
  );
  const [message, setMessage] = useState("");
  const hasTurnstile = Boolean(landingConfig.turnstileSiteKey);

  async function onSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (!email || !token || status === "loading") return;
    setStatus("loading");
    setMessage("");
    const res = await submitWaitlist({
      email,
      turnstileToken: token,
      locale,
      variant: "15",
    });
    if (res.status === "subscribed" || res.status === "already_subscribed") {
      setStatus("success");
      setMessage(
        res.status === "subscribed"
          ? "Thanks. We’ll send launch updates."
          : "You’re already on the waitlist.",
      );
      return;
    }
    setStatus("error");
    setMessage(res.status === "rate_limited" ? "Please try again soon." : "Could not submit right now.");
  }

  return (
    <form onSubmit={onSubmit} className="space-y-4">
      <div className="grid gap-3 md:grid-cols-[1fr_auto]">
        <input
          type="email"
          required
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          disabled={status === "loading"}
          placeholder="Enter your email"
          className="h-12 rounded-full border border-[#ddd8cf] bg-white px-5 text-sm text-[#201b15] placeholder:text-[#8f877a] focus:outline-none focus:ring-2 focus:ring-[#1b1b1b]/15"
        />
        <button
          type="submit"
          disabled={status === "loading" || !token || !hasTurnstile}
          className="h-12 rounded-full bg-[#171515] px-6 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-50"
        >
          {status === "loading" ? "Joining..." : "Join waitlist"}
        </button>
      </div>
      {hasTurnstile ? (
        <div className="overflow-hidden rounded-2xl border border-[#e3ddd3] bg-white p-2">
          <Turnstile
            siteKey={landingConfig.turnstileSiteKey}
            theme="light"
            onToken={setToken}
            onExpired={() => setToken("")}
            onError={() => setToken("")}
          />
        </div>
      ) : (
        <p className="rounded-2xl border border-[#e5dfd7] bg-white px-4 py-3 text-xs text-[#6f675c]">
          Turnstile is not configured for this preview.
        </p>
      )}
      {message ? (
        <p className={`text-sm ${status === "success" ? "text-[#244e2d]" : "text-[#a44d4d]"}`}>{message}</p>
      ) : null}
    </form>
  );
}

export default function V15Page({ locale }: Props): React.JSX.Element {
  const reducedMotion = useReducedMotion();

  return (
    <div
      className="min-h-screen bg-[#f4f1ea] text-[#171411] selection:bg-[#f0d3aa]"
      style={{ fontFamily: "'Newsreader', serif" }}
    >
      <header className="mx-auto flex max-w-6xl items-center justify-between px-5 py-6 sm:px-8">
        <div>
          <p className="text-xs tracking-[0.24em] text-[#7c7366]">LONGFORM EDITORIAL ATLAS</p>
          <p className="text-lg text-[#181511]">Sunnad</p>
        </div>
        <div className="flex items-center gap-4 text-xs tracking-[0.18em] text-[#726a5f]">
          <a href="#timeline" className="hidden sm:block hover:text-[#181511]">
            DAY
          </a>
          <a href="#faq" className="hidden sm:block hover:text-[#181511]">
            FAQ
          </a>
          <Link href={`/${locale}`} className="hover:text-[#181511]">
            INDEX
          </Link>
        </div>
      </header>

      <main>
        <section className="mx-auto grid max-w-6xl gap-8 px-5 pb-10 pt-2 sm:px-8 lg:grid-cols-[1.05fr_minmax(0,1fr)] lg:items-center">
          <div>
            <p className="text-xs tracking-[0.22em] text-[#7c7366]">A QUIETER DAILY SYSTEM</p>
            <h1 className="mt-3 text-4xl leading-[0.94] text-[#181511] sm:text-6xl md:text-7xl">
              Sunnad helps you stay steady,
              <br />
              one day at a time.
            </h1>
            <p className="mt-5 max-w-xl text-base leading-relaxed text-[#5f584d] sm:text-lg">
              Habit tracking for Muslims with dhikr counters, daily quotes, streaks,
              and group accountability. Offline-first for personal consistency,
              connected when you need support.
            </p>

            <div className="mt-6 rounded-[1.5rem] border border-[#ddd8cf] bg-[#faf8f3] p-4 sm:p-5">
              <AtlasWaitlist locale={locale} />
            </div>
          </div>

          <div className="grid gap-4 sm:grid-cols-2 sm:grid-rows-[auto_auto]">
            <div className="rounded-[1.35rem] border border-[#ddd8cf] bg-white p-3 shadow-[0_16px_40px_rgba(42,32,18,0.05)] sm:col-span-2">
              <div className="grid gap-3 sm:grid-cols-[0.95fr_1.05fr]">
                <div className="relative mx-auto aspect-[450/920] w-[11.7rem] sm:w-[12.4rem]">
                  <div className="absolute inset-[4.5%] overflow-hidden rounded-[1.8rem] bg-white">
                    <img
                      src="/app-screenshots/en_today_light.PNG"
                      alt="Today screen"
                      className="h-full w-full object-cover"
                    />
                  </div>
                  <img
                    src="/app-screenshots/iphone_bezels.png"
                    alt=""
                    className="pointer-events-none absolute inset-0 h-full w-full object-contain"
                  />
                </div>
                <div className="flex flex-col justify-between rounded-2xl border border-[#ebe5db] bg-[#fbfaf6] p-4">
                  <div>
                    <p className="text-xs tracking-[0.18em] text-[#7a7266]">TODAY VIEW</p>
                    <h2 className="mt-2 text-2xl text-[#1b1712]">Start with what is due.</h2>
                    <p className="mt-2 text-sm leading-relaxed text-[#655d51]">
                      Focus narrows to today. Complete habits, save a quote, and move
                      on with your day.
                    </p>
                  </div>
                  <p className="mt-4 text-xs tracking-[0.16em] text-[#8a8174]">
                    MOBILE-FIRST • EN PROTOTYPE
                  </p>
                </div>
              </div>
            </div>

            <div className="rounded-[1.35rem] border border-[#ddd8cf] bg-[#191717] p-3 text-white shadow-[0_16px_40px_rgba(25,20,17,0.18)]">
              <div className="overflow-hidden rounded-[1rem] border border-white/10">
                <img
                  src="/app-screenshots/en_groups_dark.PNG"
                  alt="Groups dark screen"
                  className="h-48 w-full object-cover object-top"
                />
              </div>
              <p className="mt-3 text-xs tracking-[0.18em] text-white/50">GROUPS-LITE</p>
              <p className="mt-1 text-sm leading-relaxed text-white/75">
                Trusted accountability, not a public feed.
              </p>
            </div>

            <div className="rounded-[1.35rem] border border-[#ddd8cf] bg-[#fffdf8] p-4">
              <p className="text-xs tracking-[0.18em] text-[#7a7266]">FEATURE MIX</p>
              <ul className="mt-3 space-y-2 text-sm leading-relaxed text-[#5d564c]">
                <li>• Dhikr counters and binary habits</li>
                <li>• Weekly scheduling and reminders</li>
                <li>• Daily quote and save/share actions</li>
                <li>• Streaks and progress visibility</li>
              </ul>
            </div>
          </div>
        </section>

        <section id="timeline" className="mx-auto max-w-6xl px-5 py-4 sm:px-8">
          <div className="rounded-[2rem] border border-[#ddd8cf] bg-white/70 p-5 sm:p-7">
            <div className="mb-5 flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between">
              <div>
                <p className="text-xs tracking-[0.22em] text-[#7a7266]">A DAY WITH SUNNAD</p>
                <h2 className="mt-2 text-3xl sm:text-4xl">A small timeline, not a productivity circus</h2>
              </div>
              <p className="max-w-md text-sm leading-relaxed text-[#60594f]">
                This variant tells the story across moments in a day to show how the
                app fits real routines.
              </p>
            </div>
            <div className="space-y-4">
              {timeline.map((step, index) => (
                <motion.article
                  key={step.title}
                  initial={reducedMotion ? false : { opacity: 0, y: 20 }}
                  whileInView={{ opacity: 1, y: 0 }}
                  viewport={{ once: true, margin: "-60px" }}
                  transition={{ duration: 0.42, delay: reducedMotion ? 0 : index * 0.05 }}
                  className={`grid gap-4 rounded-[1.4rem] border p-4 sm:grid-cols-[130px_1fr_210px] sm:items-center ${
                    step.tone === "dark"
                      ? "border-[#262222] bg-[#191717] text-white"
                      : "border-[#e2ddd4] bg-[#fbfaf6] text-[#1b1712]"
                  }`}
                >
                  <div className={`${step.tone === "dark" ? "text-white/55" : "text-[#7b7367]"} text-xs tracking-[0.18em]`}>
                    {step.time.toUpperCase()}
                  </div>
                  <div>
                    <h3 className="text-2xl">{step.title}</h3>
                    <p className={`mt-2 text-sm leading-relaxed ${step.tone === "dark" ? "text-white/75" : "text-[#615a50]"}`}>
                      {step.body}
                    </p>
                  </div>
                  <div className={`overflow-hidden rounded-xl border ${step.tone === "dark" ? "border-white/10" : "border-[#ebe5db]"}`}>
                    <img src={step.image} alt={step.title} className="h-28 w-full object-cover object-top" />
                  </div>
                </motion.article>
              ))}
            </div>
          </div>
        </section>

        <section className="mx-auto max-w-6xl px-5 py-4 sm:px-8">
          <div className="grid gap-5 lg:grid-cols-[1.05fr_minmax(0,1fr)]">
            <div className="rounded-[1.6rem] border border-[#ddd8cf] bg-white/70 p-6">
              <p className="text-xs tracking-[0.22em] text-[#7a7266]">DEMO SPACE</p>
              <h3 className="mt-3 text-2xl">Reserved for a short product walkthrough video</h3>
              <p className="mt-2 text-sm leading-relaxed text-[#60594f]">
                This block will later hold an in-page video showing the full flow from
                Today to Dhikr to Groups.
              </p>
              <div className="mt-4 grid h-40 place-items-center rounded-2xl border border-dashed border-[#d8d2c8] bg-[#faf8f2] text-xs tracking-[0.18em] text-[#8d8579]">
                VIDEO PLACEHOLDER
              </div>
            </div>

            <div id="faq" className="rounded-[1.6rem] border border-[#ddd8cf] bg-white/70 p-6">
              <p className="text-xs tracking-[0.22em] text-[#7a7266]">FAQ + TRUST</p>
              <div className="mt-4 space-y-3">
                {[
                  [
                    "Is this page final copy?",
                    "No. This is a design exploration variant. It is intentionally EN-only and optimized for layout testing.",
                  ],
                  [
                    "Will the app require internet every day?",
                    "No. Core personal habit tracking is offline-first. Internet is mainly for account and group features.",
                  ],
                  [
                    "How do I get access?",
                    "Join the waitlist and we’ll notify you when access opens.",
                  ],
                ].map(([q, a]) => (
                  <details key={q} className="rounded-xl border border-[#e5dfd6] bg-[#faf8f3] p-4">
                    <summary className="cursor-pointer text-sm font-medium text-[#1d1914]">
                      {q}
                    </summary>
                    <p className="mt-2 text-sm leading-relaxed text-[#615a50]">{a}</p>
                  </details>
                ))}
              </div>
            </div>
          </div>
        </section>
      </main>

      <footer className="mt-8 bg-[#161413] text-white">
        <div className="mx-auto grid max-w-6xl gap-6 px-5 py-10 sm:px-8 lg:grid-cols-[1.2fr_1fr]">
          <div>
            <p className="text-xs tracking-[0.24em] text-white/45">FINAL CALL</p>
            <h2 className="mt-3 text-4xl leading-[0.95] sm:text-5xl">
              Join early, and help shape a calmer daily habit experience.
            </h2>
            <p className="mt-3 max-w-xl text-sm leading-relaxed text-white/65">
              This concept is the longform editorial direction. It keeps the story
              practical and gives the waitlist a clear place in the page flow.
            </p>
          </div>
          <div className="rounded-[1.5rem] border border-white/10 bg-white/[0.03] p-4">
            <AtlasWaitlist locale={locale} />
            <div className="mt-4 flex flex-wrap gap-4 text-sm text-white/65">
              <Link href={`/${locale}/terms`} className="hover:text-white">
                Terms
              </Link>
              <Link href={`/${locale}/privacy`} className="hover:text-white">
                Privacy
              </Link>
              <Link href={`/${locale}`} className="hover:text-white">
                Index
              </Link>
            </div>
          </div>
        </div>
      </footer>
    </div>
  );
}
