"use client";

import Link from "next/link";
import { FormEvent, useRef, useState } from "react";
import {
  AnimatePresence,
  motion,
  useMotionValueEvent,
  useReducedMotion,
  useScroll,
  useTransform,
} from "framer-motion";
import { submitWaitlist } from "@/lib/waitlist-submit";
import { Turnstile } from "@/components/turnstile";
import { landingConfig } from "@/lib/config";

type Props = { locale: string; variant: string };

const screens = [
  {
    src: "/app-screenshots/en_today_dark.PNG",
    title: "Daily rhythm",
    blurb: "Only what is due today, so your focus stays quiet.",
  },
  {
    src: "/app-screenshots/en_dhikr_dark.PNG",
    title: "Intentional dhikr",
    blurb: "Counter-style habits without turning worship into noise.",
  },
  {
    src: "/app-screenshots/en_groups_dark.PNG",
    title: "Trusted accountability",
    blurb: "Gentle group reminders for people you actually care about.",
  },
] as const;

const faq = [
  {
    q: "Does Sunnad work offline?",
    a: "Yes. Your personal habits, completions, and quote flow are designed to remain useful without internet. Groups and account features require network access.",
  },
  {
    q: "What kind of habits can I track?",
    a: "Binary habits, dhikr-style counter habits, and weekly scheduled routines. The app is focused on spiritual consistency, not endless customization.",
  },
  {
    q: "Will there be more languages?",
    a: "The app already supports multilingual UI and is being expanded carefully. This landing variant is English-only for design testing.",
  },
] as const;

function NocturneWaitlist({
  locale,
}: {
  locale: string;
}): React.JSX.Element {
  const [email, setEmail] = useState("");
  const [token, setToken] = useState("");
  const [status, setStatus] = useState<"idle" | "loading" | "success" | "error">(
    "idle",
  );
  const [message, setMessage] = useState<string>("");
  const hasTurnstile = Boolean(landingConfig.turnstileSiteKey);

  async function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!email || !token || status === "loading") return;
    setStatus("loading");
    setMessage("");

    const result = await submitWaitlist({
      email,
      turnstileToken: token,
      locale,
      variant: "11",
    });

    if (result.status === "subscribed") {
      setStatus("success");
      setMessage("You are on the Sunnad waitlist.");
      return;
    }
    if (result.status === "already_subscribed") {
      setStatus("success");
      setMessage("This email is already on the waitlist.");
      return;
    }
    if (result.status === "rate_limited") {
      setStatus("error");
      setMessage("Please wait a moment before trying again.");
      return;
    }

    setStatus("error");
    setMessage("Could not submit right now. Please try again.");
  }

  return (
    <form onSubmit={onSubmit} className="space-y-3">
      <div className="grid grid-cols-1 md:grid-cols-[1fr_auto] gap-3">
        <label className="sr-only" htmlFor="v11-email">
          Email
        </label>
        <input
          id="v11-email"
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
          placeholder="Enter your email for early access"
          disabled={status === "loading"}
          className="h-12 rounded-full border border-white/15 bg-black/40 px-5 text-sm text-white placeholder:text-white/35 focus:outline-none focus:ring-2 focus:ring-[#b39aff]/60"
        />
        <button
          type="submit"
          disabled={status === "loading" || !token || !hasTurnstile}
          className="h-12 rounded-full bg-gradient-to-r from-[#d0c4ff] to-[#8aa7ff] px-6 text-sm font-semibold text-[#0d1022] disabled:cursor-not-allowed disabled:opacity-50"
        >
          {status === "loading" ? "Joining..." : "Join waitlist"}
        </button>
      </div>

      {hasTurnstile ? (
        <div className="overflow-hidden rounded-2xl border border-white/10 bg-black/20 p-2">
          <Turnstile
            siteKey={landingConfig.turnstileSiteKey}
            theme="dark"
            onToken={setToken}
            onExpired={() => setToken("")}
            onError={() => setToken("")}
          />
        </div>
      ) : (
        <p className="rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-xs text-white/70">
          Turnstile is not configured in this environment. Waitlist submission is
          disabled for this preview.
        </p>
      )}

      {message ? (
        <p
          className={`text-sm ${
            status === "success" ? "text-[#c8d4ff]" : "text-[#ffb7c7]"
          }`}
        >
          {message}
        </p>
      ) : null}
    </form>
  );
}

function PhoneScene({
  imageIndex,
  reducedMotion,
}: {
  imageIndex: number;
  reducedMotion: boolean;
}): React.JSX.Element {
  return (
    <div className="relative mx-auto w-[292px] sm:w-[326px] md:w-[362px]">
      <div className="absolute inset-[-12%] rounded-full bg-[#6d5fd3]/20 blur-[54px]" />
      <div className="absolute inset-x-[8%] top-[10%] h-[34%] rounded-full bg-[#a8d2ff]/20 blur-[42px]" />

      <div className="relative aspect-[450/920]">
        <div className="absolute inset-[4.5%] overflow-hidden rounded-[2.4rem] bg-black">
          <AnimatePresence mode="wait">
            <motion.img
              key={screens[imageIndex].src}
              src={screens[imageIndex].src}
              alt={screens[imageIndex].title}
              className="h-full w-full object-cover"
              initial={reducedMotion ? false : { opacity: 0.2, scale: 1.02 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={reducedMotion ? undefined : { opacity: 0.2, scale: 0.985 }}
              transition={{ duration: reducedMotion ? 0 : 0.55, ease: "easeOut" }}
            />
          </AnimatePresence>
        </div>
        <img
          src="/app-screenshots/iphone_bezels.png"
          alt=""
          className="pointer-events-none absolute inset-0 h-full w-full object-contain drop-shadow-[0_30px_80px_rgba(0,0,0,0.7)]"
        />
      </div>
    </div>
  );
}

export default function V11Page({ locale }: Props): React.JSX.Element {
  const reducedMotion = useReducedMotion();
  const scrollRef = useRef<HTMLDivElement>(null);
  const { scrollYProgress } = useScroll({
    target: scrollRef,
    offset: ["start start", "end end"],
  });
  const cinematicY = useTransform(
    scrollYProgress,
    [0, 1],
    reducedMotion ? [0, 0] : [0, -60],
  );
  const mistOpacity = useTransform(scrollYProgress, [0, 0.7, 1], [0.35, 0.7, 0.3]);

  const [manualImageIndex, setManualImageIndex] = useState(0);
  useMotionValueEvent(scrollYProgress, "change", (latest) => {
    const next = latest < 0.34 ? 0 : latest < 0.67 ? 1 : 2;
    setManualImageIndex((prev) => (prev === next ? prev : next));
  });

  return (
    <div
      ref={scrollRef}
      className="min-h-screen bg-[#04050a] text-white selection:bg-[#9e8cff]/30"
      style={{ fontFamily: "'Cormorant Garamond', serif" }}
    >
      <div className="pointer-events-none fixed inset-0 overflow-hidden">
        <div
          className="absolute inset-0 opacity-50"
          style={{
            backgroundImage:
              "radial-gradient(1px 1px at 12% 18%, rgba(255,255,255,.8), transparent),radial-gradient(1px 1px at 30% 42%, rgba(255,255,255,.5), transparent),radial-gradient(1px 1px at 56% 12%, rgba(255,255,255,.6), transparent),radial-gradient(1px 1px at 78% 34%, rgba(255,255,255,.45), transparent),radial-gradient(1px 1px at 86% 70%, rgba(255,255,255,.55), transparent),radial-gradient(1px 1px at 22% 80%, rgba(255,255,255,.4), transparent)",
          }}
        />
        <motion.div
          style={{ opacity: mistOpacity }}
          className="absolute -left-[15%] top-[8%] h-[36rem] w-[36rem] rounded-full bg-[#7c6cff]/16 blur-[110px]"
        />
        <motion.div
          style={{ opacity: mistOpacity }}
          className="absolute right-[-12%] top-[20%] h-[28rem] w-[30rem] rounded-full bg-[#78b6ff]/14 blur-[100px]"
        />
        <motion.div
          style={{ opacity: mistOpacity, y: cinematicY }}
          className="absolute inset-x-[12%] bottom-[4%] h-40 rounded-[999px] bg-gradient-to-r from-transparent via-white/8 to-transparent blur-3xl"
        />
      </div>

      <header className="relative z-20 mx-auto flex w-full max-w-6xl items-center justify-between px-5 py-6 sm:px-8">
        <Link
          href={`/${locale}`}
          className="text-xs tracking-[0.24em] text-white/70 transition hover:text-white"
        >
          SUNNAD INDEX
        </Link>
        <div className="hidden items-center gap-5 text-xs tracking-[0.22em] text-white/55 sm:flex">
          <a href="#story" className="hover:text-white">
            STORY
          </a>
          <a href="#faq" className="hover:text-white">
            FAQ
          </a>
          <a href="#waitlist" className="hover:text-white">
            WAITLIST
          </a>
        </div>
      </header>

      <section className="relative z-10 px-5 pt-6 sm:px-8">
        <div className="mx-auto grid min-h-[78svh] max-w-6xl content-start gap-8 rounded-[2rem] border border-white/10 bg-white/[0.03] p-6 backdrop-blur-xl sm:p-8 md:p-10">
          <div className="space-y-4 text-center">
            <p className="text-xs tracking-[0.3em] text-white/60">NOCTURNE SANCTUARY</p>
            <h1 className="mx-auto max-w-4xl text-[2.35rem] leading-[0.93] text-white sm:text-6xl md:text-7xl">
              Build a quieter
              <span className="mx-2 italic text-[#cbc1ff]">daily practice</span>
              before the day gets loud.
            </h1>
            <p className="mx-auto max-w-2xl text-base leading-relaxed text-white/70 sm:text-lg">
              Sunnad is an offline-first habit tracker for Muslims: daily checklists,
              dhikr counters, quotes, streaks, and group accountability that stays
              gentle.
            </p>
          </div>

          <div className="mx-auto w-full max-w-3xl rounded-[1.4rem] border border-white/10 bg-black/25 p-3 shadow-[0_30px_120px_rgba(0,0,0,0.5)]">
            <NocturneWaitlist locale={locale} />
          </div>

          <div className="text-center text-xs tracking-[0.22em] text-white/40">
            Scroll to move through the Sunnad night journey
          </div>
        </div>
      </section>

      <section
        id="story"
        className="relative z-10 mx-auto grid max-w-6xl grid-cols-1 gap-8 px-5 py-14 sm:px-8 md:grid-cols-[minmax(0,1fr)_380px]"
      >
        <div className="space-y-10">
          <article className="rounded-[1.75rem] border border-white/10 bg-white/[0.035] p-6 backdrop-blur-md sm:p-8">
            <p className="mb-3 text-xs tracking-[0.24em] text-white/55">
              CHAPTER I
            </p>
            <h2 className="text-4xl leading-tight text-white sm:text-5xl">
              A Today view that narrows your attention.
            </h2>
            <p className="mt-4 max-w-xl text-base leading-relaxed text-white/70">
              No giant dashboard. No noisy feed. Just the habits due now, your quote
              of the day, and room to finish what matters.
            </p>
          </article>

          <article className="rounded-[1.75rem] border border-white/10 bg-white/[0.03] p-6 backdrop-blur-md sm:p-8">
            <p className="mb-3 text-xs tracking-[0.24em] text-white/55">
              CHAPTER II
            </p>
            <h2 className="text-4xl leading-tight text-white sm:text-5xl">
              Dhikr habits that stay intentional, not gamified.
            </h2>
            <p className="mt-4 max-w-xl text-base leading-relaxed text-white/70">
              Use counter-style habits for adhkar while keeping the interaction calm,
              private, and consistent across your day.
            </p>
          </article>

          <article className="rounded-[1.75rem] border border-white/10 bg-white/[0.03] p-6 backdrop-blur-md sm:p-8">
            <p className="mb-3 text-xs tracking-[0.24em] text-white/55">
              CHAPTER III
            </p>
            <h2 className="text-4xl leading-tight text-white sm:text-5xl">
              Accountability with people you trust.
            </h2>
            <p className="mt-4 max-w-xl text-base leading-relaxed text-white/70">
              Small groups, shared habits, and respectful nudges. Enough to stay
              connected, not enough to turn worship into performative social media.
            </p>
          </article>

          <div className="rounded-[1.75rem] border border-white/10 bg-gradient-to-br from-white/[0.05] to-transparent p-6 sm:p-8">
            <h3 className="text-2xl tracking-wide text-white">Future demo space</h3>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-white/65">
              This chapter is reserved for a short in-page video trailer showing the
              Today, Dhikr, and Groups flow in motion.
            </p>
            <div className="mt-5 grid h-40 place-items-center rounded-2xl border border-dashed border-white/15 bg-black/25 text-sm tracking-[0.18em] text-white/40">
              VIDEO TRAILER PLACEHOLDER
            </div>
          </div>
        </div>

        <div className="md:sticky md:top-20 md:h-fit">
          <div className="rounded-[2rem] border border-white/10 bg-gradient-to-b from-white/[0.05] to-white/[0.02] p-5 shadow-[0_30px_100px_rgba(0,0,0,.45)] backdrop-blur-xl">
            <PhoneScene imageIndex={manualImageIndex} reducedMotion={Boolean(reducedMotion)} />
            <div className="mt-5 rounded-2xl border border-white/10 bg-black/25 p-4">
              <p className="text-xs tracking-[0.24em] text-white/50">NOW SHOWING</p>
              <h3 className="mt-2 text-2xl text-white">
                {screens[manualImageIndex].title}
              </h3>
              <p className="mt-2 text-sm leading-relaxed text-white/65">
                {screens[manualImageIndex].blurb}
              </p>
            </div>
          </div>
        </div>
      </section>

      <section id="faq" className="relative z-10 mx-auto max-w-6xl px-5 py-8 sm:px-8">
        <div className="rounded-[2rem] border border-white/10 bg-[#090b14]/80 p-6 backdrop-blur-xl sm:p-8">
          <div className="mb-6 flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between">
            <div>
              <p className="text-xs tracking-[0.24em] text-white/50">LIBRARY SHELF</p>
              <h2 className="text-4xl text-white sm:text-5xl">Questions before launch</h2>
            </div>
            <p className="max-w-md text-sm text-white/60">
              Straight answers. No inflated promises.
            </p>
          </div>
          <div className="space-y-3">
            {faq.map((item, idx) => (
              <details
                key={item.q}
                className="group rounded-2xl border border-white/10 bg-white/[0.03] p-4 open:bg-white/[0.05]"
                open={idx === 0}
              >
                <summary className="cursor-pointer list-none pr-7 text-lg text-white marker:content-none">
                  <span className="inline-flex items-center gap-3">
                    <span className="text-xs tracking-[0.2em] text-white/45">
                      {String(idx + 1).padStart(2, "0")}
                    </span>
                    {item.q}
                  </span>
                </summary>
                <p className="mt-3 pl-9 text-sm leading-relaxed text-white/70">{item.a}</p>
              </details>
            ))}
          </div>
        </div>
      </section>

      <section id="waitlist" className="relative z-10 mx-auto max-w-6xl px-5 py-10 sm:px-8">
        <div className="rounded-[2rem] border border-white/10 bg-gradient-to-br from-[#120f1f] to-[#090b12] p-6 shadow-[0_30px_120px_rgba(0,0,0,.4)] sm:p-8">
          <div className="grid gap-6 md:grid-cols-[1.1fr_minmax(0,1fr)] md:items-center">
            <div>
              <p className="text-xs tracking-[0.24em] text-white/45">EARLY ACCESS</p>
              <h2 className="mt-2 text-4xl leading-tight text-white sm:text-5xl">
                Join before launch, and start with a calmer habit system.
              </h2>
              <p className="mt-3 max-w-xl text-sm leading-relaxed text-white/65 sm:text-base">
                We are testing flows carefully. Join the list to get launch access
                and updates when Sunnad is ready for a wider release.
              </p>
            </div>
            <div className="rounded-2xl border border-white/10 bg-black/25 p-4">
              <NocturneWaitlist locale={locale} />
            </div>
          </div>
        </div>
      </section>

      <footer className="relative z-10 mx-auto flex max-w-6xl flex-col gap-4 px-5 pb-12 pt-6 text-sm text-white/55 sm:px-8 sm:flex-row sm:items-center sm:justify-between">
        <p>Sunnad • Nocturne Sanctuary concept (EN prototype)</p>
        <div className="flex flex-wrap items-center gap-4">
          <Link href={`/${locale}/terms`} className="hover:text-white">
            Terms
          </Link>
          <Link href={`/${locale}/privacy`} className="hover:text-white">
            Privacy
          </Link>
          <Link href={`/${locale}`} className="hover:text-white">
            Variant index
          </Link>
        </div>
      </footer>
    </div>
  );
}
