"use client";

import Link from "next/link";
import { FormEvent, useState } from "react";
import { motion, useReducedMotion } from "framer-motion";
import { submitWaitlist } from "@/lib/waitlist-submit";
import { Turnstile } from "@/components/turnstile";
import { landingConfig } from "@/lib/config";

type Props = { locale: string; variant: string };

const transcript = [
  {
    speaker: "Sunnad",
    tone: "system",
    text: "Today keeps only what is due. No clutter.",
  },
  {
    speaker: "Dhikr habits",
    tone: "feature",
    text: "Counter-style habits stay simple and intentional.",
  },
  {
    speaker: "Groups",
    tone: "feature",
    text: "Share progress and send gentle reminders to trusted people.",
  },
  {
    speaker: "Offline mode",
    tone: "system",
    text: "Your personal routine still works when the internet does not.",
  },
] as const;

const faqs = [
  {
    q: "Is this a social app?",
    a: "No. Groups are lightweight accountability spaces, not a public feed. The main experience is still your personal daily routine.",
  },
  {
    q: "Can I use it without signing in?",
    a: "Yes. Guest mode keeps core habit tracking offline-first. Sign in when you want groups or sync-enabled features.",
  },
  {
    q: "What devices are supported first?",
    a: "iOS is the first launch focus. The waitlist helps prioritize rollout timing and languages.",
  },
] as const;

function MajlisWaitlist({ locale }: { locale: string }): React.JSX.Element {
  const [email, setEmail] = useState("");
  const [token, setToken] = useState("");
  const [state, setState] = useState<"idle" | "loading" | "success" | "error">(
    "idle",
  );
  const [feedback, setFeedback] = useState("");
  const hasTurnstile = Boolean(landingConfig.turnstileSiteKey);

  async function onSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (!email || !token || state === "loading") return;
    setState("loading");
    setFeedback("");

    const res = await submitWaitlist({
      email,
      turnstileToken: token,
      locale,
      variant: "12",
    });

    if (res.status === "subscribed") {
      setState("success");
      setFeedback("You are in. We will email you when access opens.");
      return;
    }
    if (res.status === "already_subscribed") {
      setState("success");
      setFeedback("This email is already on the list.");
      return;
    }
    if (res.status === "rate_limited") {
      setState("error");
      setFeedback("Too many attempts. Try again shortly.");
      return;
    }
    setState("error");
    setFeedback("Submission failed. Please retry.");
  }

  return (
    <form onSubmit={onSubmit} className="space-y-3">
      <label htmlFor="v12-email" className="text-xs tracking-[0.18em] text-white/55">
        EARLY ACCESS
      </label>
      <input
        id="v12-email"
        type="email"
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        placeholder="you@example.com"
        required
        disabled={state === "loading"}
        className="h-12 w-full rounded-xl border border-white/10 bg-[#080b14] px-4 text-sm text-white placeholder:text-white/30 focus:outline-none focus:ring-2 focus:ring-[#6ca8ff]/50"
      />
      {hasTurnstile ? (
        <div className="overflow-hidden rounded-xl border border-white/10 bg-black/20 p-2">
          <Turnstile
            siteKey={landingConfig.turnstileSiteKey}
            theme="dark"
            onToken={setToken}
            onExpired={() => setToken("")}
            onError={() => setToken("")}
          />
        </div>
      ) : (
        <div className="rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-xs text-white/70">
          Turnstile not configured for this preview.
        </div>
      )}
      <button
        type="submit"
        disabled={state === "loading" || !token || !hasTurnstile}
        className="h-11 w-full rounded-xl bg-[#8f95ff] text-sm font-semibold text-[#0c1024] transition hover:bg-[#a3a7ff] disabled:cursor-not-allowed disabled:opacity-50"
      >
        {state === "loading" ? "Joining..." : "Join waitlist"}
      </button>
      {feedback ? (
        <p
          className={`text-xs ${
            state === "success" ? "text-[#b8d7ff]" : "text-[#ffb0c4]"
          }`}
        >
          {feedback}
        </p>
      ) : null}
    </form>
  );
}

function OrbitalCard({
  className,
  children,
  duration = 8,
  delay = 0,
}: {
  className: string;
  children: React.ReactNode;
  duration?: number;
  delay?: number;
}): React.JSX.Element {
  const reducedMotion = useReducedMotion();
  return (
    <motion.div
      initial={{ opacity: 0, y: 12, scale: 0.96 }}
      animate={{
        opacity: 1,
        y: 0,
        scale: 1,
        ...(reducedMotion
          ? {}
          : {
              translateY: [0, -8, 0, 8, 0],
            }),
      }}
      transition={{
        duration: reducedMotion ? 0.45 : duration,
        repeat: reducedMotion ? 0 : Infinity,
        ease: "easeInOut",
        delay,
      }}
      className={className}
    >
      {children}
    </motion.div>
  );
}

export default function V12Page({ locale }: Props): React.JSX.Element {
  const reducedMotion = useReducedMotion();

  return (
    <div
      className="min-h-screen bg-[#03050a] text-white selection:bg-[#8795ff]/30"
      style={{ fontFamily: "'Plus Jakarta Sans', sans-serif" }}
    >
      <div className="pointer-events-none fixed inset-0 overflow-hidden">
        <div
          className="absolute inset-0 opacity-[0.08]"
          style={{
            backgroundImage:
              "linear-gradient(to right, rgba(255,255,255,.08) 1px, transparent 1px), linear-gradient(to bottom, rgba(255,255,255,.08) 1px, transparent 1px)",
            backgroundSize: "80px 80px",
          }}
        />
        <div className="absolute left-[-12rem] top-[20%] h-[24rem] w-[24rem] rounded-full bg-[#5566ff]/14 blur-[120px]" />
        <div className="absolute right-[-6rem] top-[8%] h-[18rem] w-[20rem] rounded-full bg-[#6de7ff]/10 blur-[90px]" />
      </div>

      <header className="relative z-20 mx-auto flex max-w-7xl items-center justify-between px-5 py-5 sm:px-8">
        <div className="flex items-center gap-3">
          <div className="grid h-9 w-9 place-items-center rounded-xl border border-white/15 bg-white/[0.03]">
            <span className="text-sm font-bold text-[#9ac0ff]">S</span>
          </div>
          <div>
            <p className="text-sm font-semibold tracking-wide">Sunnad</p>
            <p className="text-[10px] tracking-[0.24em] text-white/45">MAJLIS NETWORK</p>
          </div>
        </div>
        <div className="flex items-center gap-3 text-xs tracking-[0.18em] text-white/60">
          <a href="#transcript" className="hidden hover:text-white sm:block">
            FLOW
          </a>
          <a href="#faq" className="hidden hover:text-white sm:block">
            FAQ
          </a>
          <Link href={`/${locale}`} className="rounded-full border border-white/15 px-3 py-2 hover:text-white">
            INDEX
          </Link>
        </div>
      </header>

      <main className="relative z-10 mx-auto max-w-7xl px-5 pb-12 sm:px-8">
        <section className="relative overflow-hidden rounded-[2rem] border border-white/10 bg-gradient-to-b from-white/[0.03] to-white/[0.01] p-5 shadow-[0_40px_120px_rgba(0,0,0,.45)] sm:p-7 lg:p-8">
          <div className="grid gap-7 lg:grid-cols-[1.1fr_1.2fr] lg:items-start">
            <div className="space-y-5">
              <div className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/[0.03] px-3 py-1.5 text-xs tracking-[0.2em] text-white/70">
                <span className="h-1.5 w-1.5 rounded-full bg-[#8f95ff]" />
                GROUP ACCOUNTABILITY
              </div>
              <h1 className="max-w-xl text-4xl font-semibold leading-[1] tracking-tight sm:text-6xl lg:text-7xl">
                Stay consistent
                <br />
                together,
                <br />
                <span className="text-[#9fc1ff]">without social noise.</span>
              </h1>
              <p className="max-w-xl text-sm leading-relaxed text-white/68 sm:text-base">
                Sunnad keeps your personal worship routine central, then adds small
                group accountability for trusted friends and family. Offline-first
                for your habits. Connected when you need support.
              </p>

              <div className="rounded-2xl border border-white/10 bg-[#060911] p-4">
                <MajlisWaitlist locale={locale} />
              </div>
            </div>

            <div className="relative min-h-[31rem] rounded-[1.4rem] border border-white/10 bg-[#04070f] p-4 sm:min-h-[34rem]">
              <div className="absolute left-4 top-4 rounded-lg border border-white/10 bg-white/[0.03] px-3 py-1 text-[11px] tracking-[0.18em] text-white/55">
                COMMAND CENTER
              </div>

              <div className="absolute left-1/2 top-[52%] w-[16.5rem] -translate-x-1/2 -translate-y-1/2 sm:w-[18rem]">
                <div className="relative aspect-[450/920]">
                  <div className="absolute inset-[4.5%] overflow-hidden rounded-[2.15rem] bg-black">
                    <img
                      src="/app-screenshots/en_groups_dark.PNG"
                      alt="Sunnad Groups screenshot"
                      className="h-full w-full object-cover"
                    />
                  </div>
                  <img
                    src="/app-screenshots/iphone_bezels.png"
                    alt=""
                    className="pointer-events-none absolute inset-0 h-full w-full object-contain drop-shadow-[0_20px_90px_rgba(0,0,0,.8)]"
                  />
                </div>
              </div>

              <OrbitalCard
                className="absolute right-3 top-12 w-[12rem] rounded-2xl border border-[#7d88ff]/25 bg-[#0b1020]/90 p-3 shadow-2xl sm:right-6 sm:w-[13rem]"
                duration={9}
              >
                <p className="text-[10px] tracking-[0.18em] text-white/45">REMINDER</p>
                <p className="mt-2 text-sm leading-snug">
                  Gentle nudge for
                  <span className="font-semibold text-[#b8c8ff]"> Evening dhikr</span>
                </p>
                <div className="mt-3 h-1.5 rounded-full bg-white/10">
                  <div className="h-full w-3/4 rounded-full bg-gradient-to-r from-[#7f86ff] to-[#6de7ff]" />
                </div>
              </OrbitalCard>

              <OrbitalCard
                className="absolute left-2 top-28 w-[10.5rem] rounded-2xl border border-white/10 bg-[#090d18]/95 p-3 sm:left-5 sm:w-[12rem]"
                duration={10}
                delay={0.3}
              >
                <p className="text-[10px] tracking-[0.18em] text-white/45">TODAY</p>
                <div className="mt-2 overflow-hidden rounded-xl border border-white/10">
                  <img
                    src="/app-screenshots/en_today_dark.PNG"
                    alt="Today crop"
                    className="h-20 w-full object-cover object-top"
                  />
                </div>
              </OrbitalCard>

              <OrbitalCard
                className="absolute left-4 bottom-5 w-[11.5rem] rounded-2xl border border-white/10 bg-[#080a12]/95 p-3 sm:left-8"
                duration={11}
                delay={0.6}
              >
                <p className="text-[10px] tracking-[0.18em] text-white/45">DHIKR</p>
                <div className="mt-2 overflow-hidden rounded-xl border border-white/10">
                  <img
                    src="/app-screenshots/en_dhikr_dark.PNG"
                    alt="Dhikr crop"
                    className="h-20 w-full object-cover object-top"
                  />
                </div>
              </OrbitalCard>

              <OrbitalCard
                className="absolute bottom-12 right-3 w-[12rem] rounded-2xl border border-white/10 bg-[#090d18]/95 p-3 sm:right-6"
                duration={8}
                delay={0.2}
              >
                <p className="text-[10px] tracking-[0.18em] text-white/45">PROGRESS</p>
                <div className="mt-3 space-y-2">
                  <div className="flex items-center justify-between text-xs">
                    <span className="text-white/70">Shared habits</span>
                    <span className="font-semibold text-white">7</span>
                  </div>
                  <div className="flex items-center justify-between text-xs">
                    <span className="text-white/70">Completed today</span>
                    <span className="font-semibold text-[#9fc1ff]">2/7</span>
                  </div>
                </div>
              </OrbitalCard>
            </div>
          </div>
        </section>

        <section
          id="transcript"
          className="mt-8 grid gap-8 lg:grid-cols-[1.1fr_minmax(0,1fr)]"
        >
          <div className="rounded-[1.6rem] border border-white/10 bg-white/[0.025] p-5 sm:p-6">
            <div className="mb-4 flex items-center justify-between">
              <h2 className="text-2xl font-semibold sm:text-3xl">How Sunnad fits the day</h2>
              <span className="rounded-full border border-white/10 px-2.5 py-1 text-[10px] tracking-[0.18em] text-white/45">
                TRANSCRIPT
              </span>
            </div>
            <div className="space-y-3">
              {transcript.map((line, index) => (
                <motion.div
                  key={`${line.speaker}-${index}`}
                  initial={reducedMotion ? false : { opacity: 0, x: index % 2 ? 12 : -12 }}
                  whileInView={{ opacity: 1, x: 0 }}
                  viewport={{ once: true, margin: "-40px" }}
                  transition={{ duration: 0.35, delay: reducedMotion ? 0 : index * 0.05 }}
                  className={`max-w-[92%] rounded-2xl border px-4 py-3 text-sm leading-relaxed ${
                    line.tone === "feature"
                      ? "ml-auto border-[#7185ff]/20 bg-[#0a0f23]"
                      : "border-white/10 bg-white/[0.03]"
                  }`}
                >
                  <div className="mb-1 text-[10px] tracking-[0.18em] text-white/45">
                    {line.speaker}
                  </div>
                  <p className={line.tone === "feature" ? "text-[#d9e3ff]" : "text-white/80"}>
                    {line.text}
                  </p>
                </motion.div>
              ))}
            </div>
          </div>

          <div className="space-y-4">
            <div className="rounded-[1.5rem] border border-white/10 bg-[#070a12] p-5">
              <p className="text-xs tracking-[0.18em] text-white/45">COMING SOON</p>
              <h3 className="mt-2 text-xl font-semibold">Live group demo window</h3>
              <p className="mt-2 text-sm leading-relaxed text-white/65">
                Reserved space for an in-page demo video showing shared habits, member
                progress, and respectful reminder flow.
              </p>
              <div className="mt-4 grid h-36 place-items-center rounded-2xl border border-dashed border-white/15 bg-black/20 text-xs tracking-[0.18em] text-white/40">
                VIDEO PLACEHOLDER
              </div>
            </div>

            <div id="faq" className="rounded-[1.5rem] border border-white/10 bg-[#05070d] p-5">
              <div className="mb-4 flex items-center justify-between">
                <h3 className="text-xl font-semibold">Help drawer</h3>
                <span className="text-[10px] tracking-[0.18em] text-white/40">FAQ</span>
              </div>
              <div className="space-y-3">
                {faqs.map((item) => (
                  <details
                    key={item.q}
                    className="rounded-xl border border-white/10 bg-white/[0.02] p-3 open:bg-white/[0.04]"
                  >
                    <summary className="cursor-pointer list-none text-sm font-medium text-white/90">
                      {item.q}
                    </summary>
                    <p className="mt-2 text-sm leading-relaxed text-white/65">{item.a}</p>
                  </details>
                ))}
              </div>
            </div>
          </div>
        </section>
      </main>

      <footer className="relative z-10 mx-auto mb-8 mt-2 flex max-w-7xl flex-col gap-4 rounded-[1.3rem] border border-white/10 bg-white/[0.02] px-5 py-4 text-sm text-white/60 sm:flex-row sm:items-center sm:justify-between sm:px-8">
        <p>Majlis Network concept • EN prototype</p>
        <div className="flex flex-wrap items-center gap-4">
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
      </footer>
    </div>
  );
}
