"use client";

import Link from "next/link";
import { FormEvent, useState } from "react";
import { motion, useReducedMotion } from "framer-motion";
import { submitWaitlist } from "@/lib/waitlist-submit";
import { Turnstile } from "@/components/turnstile";
import { landingConfig } from "@/lib/config";

type Props = { locale: string; variant: string };

const exhibits = [
  {
    title: "Today",
    caption: "A calm checklist of what is due now.",
    img: "/app-screenshots/en_today_light.PNG",
  },
  {
    title: "Dhikr",
    caption: "Counter-style habits for daily adhkar.",
    img: "/app-screenshots/en_dhikr_light.PNG",
  },
  {
    title: "Groups",
    caption: "Gentle accountability with trusted people.",
    img: "/app-screenshots/en_groups_light.PNG",
  },
] as const;

const plaques = [
  {
    title: "Offline-first by design",
    body: "Personal habit tracking stays useful without internet. Network features are additive, not a dependency.",
  },
  {
    title: "Built for consistency",
    body: "Streaks, reminders, and habit detail flows are designed to support rhythm rather than guilt.",
  },
  {
    title: "Multilingual foundation",
    body: "Sunnad supports multilingual UI and is built to grow carefully across languages.",
  },
] as const;

function GalleryWaitlist({ locale }: { locale: string }): React.JSX.Element {
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
      variant: "13",
    });

    if (res.status === "subscribed" || res.status === "already_subscribed") {
      setStatus("success");
      setMessage(
        res.status === "subscribed"
          ? "Your invite request is recorded."
          : "This email is already on the waitlist.",
      );
      return;
    }
    setStatus("error");
    setMessage(
      res.status === "rate_limited"
        ? "Please wait and try again."
        : "Submission failed. Please retry.",
    );
  }

  return (
    <form onSubmit={onSubmit} className="space-y-4">
      <div className="grid gap-3 md:grid-cols-[1fr_auto]">
        <input
          type="email"
          required
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          placeholder="Email for early access"
          className="h-12 rounded-xl border border-[#d8ddd2] bg-white px-4 text-sm text-[#1f241f] placeholder:text-[#8b9288] focus:outline-none focus:ring-2 focus:ring-[#9cc48a]/60"
          disabled={status === "loading"}
        />
        <button
          type="submit"
          disabled={status === "loading" || !token || !hasTurnstile}
          className="h-12 rounded-xl border border-[#20261f] bg-[#20261f] px-5 text-sm font-medium text-white disabled:cursor-not-allowed disabled:opacity-50"
        >
          {status === "loading" ? "Sending..." : "Join waitlist"}
        </button>
      </div>
      {hasTurnstile ? (
        <div className="overflow-hidden rounded-xl border border-[#dfe5da] bg-white p-2">
          <Turnstile
            siteKey={landingConfig.turnstileSiteKey}
            theme="light"
            onToken={setToken}
            onExpired={() => setToken("")}
            onError={() => setToken("")}
          />
        </div>
      ) : (
        <p className="rounded-xl border border-[#e5eadf] bg-[#f8faf6] px-3 py-2 text-xs text-[#647066]">
          Turnstile is not configured for this preview build.
        </p>
      )}
      {message ? (
        <p className={`text-sm ${status === "success" ? "text-[#375a3b]" : "text-[#a14b51]"}`}>
          {message}
        </p>
      ) : null}
    </form>
  );
}

export default function V13Page({ locale }: Props): React.JSX.Element {
  const reducedMotion = useReducedMotion();

  return (
    <div
      className="min-h-screen bg-[#f7f8f2] text-[#171a16] selection:bg-[#cbe8bf]"
      style={{ fontFamily: "'Newsreader', serif" }}
    >
      <div className="pointer-events-none fixed inset-0">
        <div className="absolute inset-0 opacity-[0.06]" style={{ backgroundImage: "radial-gradient(circle at 10% 10%, #8ecf7f 0, transparent 34%), radial-gradient(circle at 90% 20%, #f0d7a1 0, transparent 30%), radial-gradient(circle at 75% 80%, #8cb8ff 0, transparent 28%)" }} />
        <div
          className="absolute inset-0 opacity-[0.05]"
          style={{
            backgroundImage:
              "url(\"data:image/svg+xml,%3Csvg width='180' height='180' viewBox='0 0 180 180' xmlns='http://www.w3.org/2000/svg'%3E%3Cg fill='none' stroke='%238aa07e' stroke-opacity='0.35' stroke-width='1'%3E%3Cpath d='M10 110c30-40 70-40 100-10s50 30 60-10'/%3E%3Cpath d='M-10 140c30-40 70-40 100-10s50 30 60-10'/%3E%3C/g%3E%3C/svg%3E\")",
          }}
        />
      </div>

      <header className="relative z-10 mx-auto flex max-w-6xl items-center justify-between px-5 py-6 sm:px-8">
        <div>
          <p className="text-xs tracking-[0.22em] text-[#6c7567]">GALLERY OF PRACTICE</p>
          <p className="text-lg text-[#20251f]">Sunnad</p>
        </div>
        <div className="flex items-center gap-4 text-xs tracking-[0.18em] text-[#5f675a]">
          <a href="#exhibits" className="hidden hover:text-[#171a16] sm:block">
            EXHIBITS
          </a>
          <a href="#faq" className="hidden hover:text-[#171a16] sm:block">
            FAQ
          </a>
          <Link href={`/${locale}`} className="hover:text-[#171a16]">
            INDEX
          </Link>
        </div>
      </header>

      <main className="relative z-10">
        <section className="mx-auto grid max-w-6xl gap-8 px-5 pb-14 pt-3 sm:px-8">
          <div className="rounded-[2rem] border border-[#dde2d7] bg-white/70 p-6 backdrop-blur-xl shadow-[0_20px_60px_rgba(44,51,43,0.06)] sm:p-8 md:p-10">
            <div className="mx-auto max-w-4xl text-center">
              <p className="text-xs tracking-[0.24em] text-[#74806f]">ROOM I · ENTRANCE</p>
              <h1 className="mt-3 text-4xl leading-[0.96] text-[#171a16] sm:text-6xl md:text-7xl">
                A carefully made space
                <br />
                for daily worship habits.
              </h1>
              <p className="mx-auto mt-5 max-w-2xl text-base leading-relaxed text-[#576056] sm:text-lg">
                Sunnad helps you stay steady with habit tracking, dhikr counters,
                quotes, streaks, and group accountability, while keeping the interface
                quiet and respectful.
              </p>
            </div>

            <div className="mt-10 grid gap-5 md:grid-cols-3">
              {exhibits.map((exhibit, index) => (
                <motion.figure
                  key={exhibit.title}
                  initial={false}
                  whileInView={{ opacity: 1, y: 0 }}
                  viewport={{ once: true, margin: "-60px" }}
                  transition={{ duration: reducedMotion ? 0 : 0.45, delay: reducedMotion ? 0 : index * 0.08 }}
                  className={`rounded-[1.5rem] border border-[#dde2d7] bg-[#fbfcf8] p-4 shadow-[0_12px_30px_rgba(34,43,33,0.05)] ${
                    index === 1 ? "md:-mt-8" : ""
                  }`}
                >
                  <div className="relative mx-auto aspect-[450/920] w-[13.5rem]">
                    <div className="absolute inset-[4.5%] overflow-hidden rounded-[1.9rem] bg-white">
                      <img src={exhibit.img} alt={exhibit.title} className="h-full w-full object-cover" />
                    </div>
                    <img
                      src="/app-screenshots/iphone_bezels.png"
                      alt=""
                      className="pointer-events-none absolute inset-0 h-full w-full object-contain opacity-95"
                    />
                  </div>
                  <figcaption className="mt-4 text-center">
                    <p className="text-lg text-[#1f241f]">{exhibit.title}</p>
                    <p className="mt-1 text-sm leading-relaxed text-[#637062]">
                      {exhibit.caption}
                    </p>
                  </figcaption>
                </motion.figure>
              ))}
            </div>
          </div>
        </section>

        <section
          id="exhibits"
          className="mx-auto grid max-w-6xl gap-8 px-5 py-2 sm:px-8 xl:grid-cols-[1.05fr_minmax(0,1fr)]"
        >
          <div className="min-w-0 rounded-[1.8rem] border border-[#dfe5da] bg-white/70 p-6 sm:p-7">
            <p className="text-xs tracking-[0.24em] text-[#74806f]">ROOM II · STORYBOARD</p>
            <h2 className="mt-3 text-3xl leading-tight sm:text-4xl">
              One day, shown in a sequence of quiet screens.
            </h2>
            <p className="mt-3 max-w-xl text-sm leading-relaxed text-[#5c675b]">
              This gallery room is intentionally sparse. It shows the app as a
              companion, not a feed: open the day, complete what is due, keep count,
              and continue.
            </p>

            <div className="mt-6 flex gap-4 overflow-x-auto pb-2 [scrollbar-width:none] snap-x snap-mandatory">
              {[
                { title: "Morning start", img: "/app-screenshots/en_today_light.PNG" },
                { title: "Dhikr flow", img: "/app-screenshots/en_dhikr_light.PNG" },
                { title: "Group check-in", img: "/app-screenshots/en_groups_light.PNG" },
                { title: "Progress view", img: "/app-screenshots/en_analytics_light.PNG" },
              ].map((panel) => (
                <div
                  key={panel.title}
                  className="min-w-[16rem] snap-start rounded-2xl border border-[#e3e8dd] bg-[#fbfcf9] p-3"
                >
                  <div className="overflow-hidden rounded-[1.1rem] border border-[#e5eadf]">
                    <img src={panel.img} alt={panel.title} className="h-52 w-full object-cover object-top" />
                  </div>
                  <p className="mt-3 text-sm text-[#253025]">{panel.title}</p>
                </div>
              ))}
            </div>
          </div>

          <div className="min-w-0 space-y-5">
            <div className="rounded-[1.6rem] border border-[#dfe5da] bg-white/80 p-6">
              <p className="text-xs tracking-[0.22em] text-[#74806f]">ROOM III · PLAQUES</p>
              <div className="mt-4 space-y-4">
                {plaques.map((plaque) => (
                  <div
                    key={plaque.title}
                    className="rounded-2xl border border-[#e6ebdf] bg-[#fafbf7] p-4"
                  >
                    <h3 className="text-xl text-[#1e231d]">{plaque.title}</h3>
                    <p className="mt-2 text-sm leading-relaxed text-[#5e685c]">
                      {plaque.body}
                    </p>
                  </div>
                ))}
              </div>
            </div>

            <div className="rounded-[1.6rem] border border-[#dfe5da] bg-[#fbfcf8] p-6">
              <p className="text-xs tracking-[0.22em] text-[#74806f]">ROOM IV · FILM FRAME</p>
              <h3 className="mt-3 text-2xl">Reserved space for a future demo</h3>
              <div className="mt-4 grid h-40 place-items-center rounded-2xl border border-dashed border-[#ccd4c6] bg-white text-xs tracking-[0.2em] text-[#83907f]">
                VIDEO FRAME PLACEHOLDER
              </div>
            </div>
          </div>
        </section>

        <section className="mx-auto max-w-6xl px-5 py-8 sm:px-8">
          <div className="rounded-[2rem] border border-[#dbe2d5] bg-white/80 p-6 sm:p-8 lg:grid lg:grid-cols-[1.05fr_minmax(0,1fr)] lg:gap-8">
            <div>
              <p className="text-xs tracking-[0.24em] text-[#74806f]">ROOM V · INVITATION</p>
              <h2 className="mt-3 text-3xl leading-tight sm:text-4xl">
                Join the waitlist for an early look at Sunnad.
              </h2>
              <p className="mt-3 max-w-xl text-sm leading-relaxed text-[#596359]">
                We are refining details before launch. Add your email to receive access
                updates and release news.
              </p>
            </div>
            <div className="mt-6 rounded-2xl border border-[#e0e6db] bg-[#f8faf5] p-4 lg:mt-0">
              <GalleryWaitlist locale={locale} />
            </div>
          </div>
        </section>

        <section id="faq" className="mx-auto max-w-6xl px-5 py-2 sm:px-8">
          <div className="rounded-[1.8rem] border border-[#dfe5da] bg-white/75 p-6 sm:p-8">
            <p className="text-xs tracking-[0.22em] text-[#74806f]">ROOM VI · LABELS</p>
            <h2 className="mt-3 text-3xl sm:text-4xl">Common questions</h2>
            <div className="mt-5 space-y-3">
              {[
                [
                  "Will Sunnad replace my existing reminders app?",
                  "It is designed specifically for daily Islamic habit consistency. It can coexist with other tools, but it aims to become the place you return to for this routine.",
                ],
                [
                  "Do I need a group to use it well?",
                  "No. The app is useful as a personal tool first. Groups are optional and intentionally lightweight.",
                ],
                [
                  "Is this page final?",
                  "No. This is an EN-only design prototype variant used for layout exploration before final landing selection.",
                ],
              ].map(([q, a]) => (
                <details key={q} className="rounded-xl border border-[#e4eade] bg-[#fafbf8] p-4">
                  <summary className="cursor-pointer text-sm font-medium text-[#20261f]">
                    {q}
                  </summary>
                  <p className="mt-2 text-sm leading-relaxed text-[#5b665b]">{a}</p>
                </details>
              ))}
            </div>
          </div>
        </section>
      </main>

      <footer className="mx-auto mt-6 flex max-w-6xl flex-col gap-4 px-5 pb-12 pt-4 text-sm text-[#5f685d] sm:flex-row sm:items-center sm:justify-between sm:px-8">
        <p>Gallery of Practice • EN prototype</p>
        <div className="flex items-center gap-4">
          <Link href={`/${locale}/terms`} className="hover:text-[#20261f]">
            Terms
          </Link>
          <Link href={`/${locale}/privacy`} className="hover:text-[#20261f]">
            Privacy
          </Link>
          <Link href={`/${locale}`} className="hover:text-[#20261f]">
            Index
          </Link>
        </div>
      </footer>
    </div>
  );
}
