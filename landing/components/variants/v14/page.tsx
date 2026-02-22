"use client";

import Link from "next/link";
import { FormEvent, useMemo, useState } from "react";
import { motion, useReducedMotion } from "framer-motion";
import { submitWaitlist } from "@/lib/waitlist-submit";
import { Turnstile } from "@/components/turnstile";
import { landingConfig } from "@/lib/config";

type Props = { locale: string; variant: string };

function FieldWaitlist({ locale }: { locale: string }): React.JSX.Element {
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
      variant: "14",
    });
    if (res.status === "subscribed" || res.status === "already_subscribed") {
      setStatus("success");
      setMessage(
        res.status === "subscribed"
          ? "You are on the list."
          : "Already on the waitlist with this email.",
      );
      return;
    }
    setStatus("error");
    setMessage(res.status === "rate_limited" ? "Please wait before retrying." : "Could not submit.");
  }

  return (
    <form onSubmit={onSubmit} className="space-y-3">
      <div className="rounded-2xl border border-[#233723]/15 bg-white/65 p-3 backdrop-blur-md">
        <input
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
          placeholder="Email for early access"
          disabled={status === "loading"}
          className="h-11 w-full rounded-xl border border-[#d8e3d5] bg-white/90 px-4 text-sm text-[#19301d] placeholder:text-[#6f8270] focus:outline-none focus:ring-2 focus:ring-[#67c267]/40"
        />
      </div>
      {hasTurnstile ? (
        <div className="overflow-hidden rounded-2xl border border-[#d8e4d6] bg-white/70 p-2">
          <Turnstile
            siteKey={landingConfig.turnstileSiteKey}
            theme="light"
            onToken={setToken}
            onExpired={() => setToken("")}
            onError={() => setToken("")}
          />
        </div>
      ) : (
        <div className="rounded-2xl border border-[#dbe7d9] bg-white/70 px-4 py-3 text-xs text-[#607161]">
          Turnstile is not configured in this preview.
        </div>
      )}
      <button
        type="submit"
        disabled={status === "loading" || !token || !hasTurnstile}
        className="h-11 w-full rounded-xl bg-[#1a2f1d] text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-50"
      >
        {status === "loading" ? "Joining..." : "Join waitlist"}
      </button>
      {message ? (
        <p className={`text-xs ${status === "success" ? "text-[#2f6536]" : "text-[#9f5151]"}`}>{message}</p>
      ) : null}
    </form>
  );
}

function ContourBackground(): React.JSX.Element {
  return (
    <div
      className="absolute inset-0 opacity-[0.12]"
      style={{
        backgroundImage:
          "radial-gradient(circle at 20% 18%, #7ee46e, transparent 28%), radial-gradient(circle at 80% 20%, #a8f0c1, transparent 28%), radial-gradient(circle at 50% 72%, #c6f5b7, transparent 34%), url(\"data:image/svg+xml,%3Csvg width='240' height='240' viewBox='0 0 240 240' xmlns='http://www.w3.org/2000/svg'%3E%3Cg fill='none' stroke='%231b4d1f' stroke-opacity='0.33'%3E%3Cpath d='M20 160c20-30 55-55 95-46 46 10 62-27 110-17'/%3E%3Cpath d='M-5 185c25-36 60-63 111-51 43 10 57-21 111-15'/%3E%3Cpath d='M15 92c29-26 63-39 106-28 37 9 59-14 104-8'/%3E%3C/g%3E%3C/svg%3E\")",
      }}
    />
  );
}

export default function V14Page({ locale }: Props): React.JSX.Element {
  const reducedMotion = useReducedMotion();
  const tilt = useMemo(() => (reducedMotion ? 0 : -5), [reducedMotion]);

  return (
    <div
      className="min-h-screen overflow-x-clip bg-[#ecf6e9] text-[#152317] selection:bg-[#94ea7f]/35"
      style={{ fontFamily: "'Fraunces', serif" }}
    >
      <div className="pointer-events-none fixed inset-0">
        <ContourBackground />
        <div className="absolute left-[-10%] top-[8%] h-72 w-72 rounded-full bg-[#74f66f]/20 blur-[90px]" />
        <div className="absolute right-[-8%] top-[28%] h-64 w-72 rounded-full bg-[#b9f7c0]/28 blur-[90px]" />
      </div>

      <header className="relative z-20 mx-auto flex max-w-7xl items-center justify-between px-5 py-6 sm:px-8">
        <div className="flex items-center gap-3">
          <div className="h-8 w-8 rounded-full border border-[#1e3321]/15 bg-white/70" />
          <div>
            <p className="text-sm text-[#1a291b]">Sunnad</p>
            <p className="text-[10px] tracking-[0.24em] text-[#59705b]">TILTED FIELD</p>
          </div>
        </div>
        <div className="flex items-center gap-4 text-xs tracking-[0.18em] text-[#5f715f]">
          <a href="#field-notes" className="hidden sm:block hover:text-[#1a291b]">
            NOTES
          </a>
          <a href="#faq" className="hidden sm:block hover:text-[#1a291b]">
            FAQ
          </a>
          <Link href={`/${locale}`} className="hover:text-[#1a291b]">
            INDEX
          </Link>
        </div>
      </header>

      <main className="relative z-10 mx-auto max-w-7xl px-4 pb-12 sm:px-8">
        <section className="relative pt-2">
          <motion.div
            initial={reducedMotion ? false : { opacity: 0, y: 18 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.55 }}
            className="mx-auto max-w-6xl"
          >
            <div className="relative rounded-[2.2rem] border border-[#d5e4d2] bg-white/70 p-4 shadow-[0_35px_90px_rgba(34,72,30,0.14)] backdrop-blur-xl sm:p-6 md:p-8">
              <motion.div
                style={{
                  rotate: tilt,
                  transformOrigin: "center center",
                }}
                className="relative rounded-[1.8rem] border border-[#d2e3cf] bg-[#f7fcf3] p-4 shadow-[0_30px_60px_rgba(38,78,33,0.12)] sm:p-5 md:p-6"
              >
                <ContourBackground />
                <div className="relative z-10 grid gap-5 lg:grid-cols-[1.1fr_1fr]">
                  <div className="space-y-4">
                    <div className="inline-flex items-center gap-2 rounded-full border border-[#203723]/10 bg-white/70 px-3 py-1 text-xs tracking-[0.2em] text-[#4c6150]">
                      <span className="h-1.5 w-1.5 rounded-full bg-[#5ac755]" />
                      FIELD VIEW
                    </div>
                    <h1 className="max-w-2xl text-4xl leading-[0.95] text-[#16261a] sm:text-6xl">
                      Build a grounded
                      <br />
                      routine that holds
                      <br />
                      through real life.
                    </h1>
                    <p className="max-w-xl text-sm leading-relaxed text-[#4f6453] sm:text-base">
                      Sunnad helps you keep worship habits steady with quiet reminders,
                      dhikr counters, streaks, daily quotes, and trusted group support.
                    </p>

                    <div className="grid gap-3 sm:grid-cols-2">
                      <div className="rounded-2xl border border-[#d9e8d7] bg-white/80 p-4">
                        <p className="text-[11px] tracking-[0.18em] text-[#67806a]">FOCUS</p>
                        <p className="mt-2 text-xl text-[#1c2d1f]">Today only</p>
                        <p className="mt-1 text-xs text-[#5c725f]">
                          Show only habits scheduled for the current day.
                        </p>
                      </div>
                      <div className="rounded-2xl border border-[#d9e8d7] bg-white/80 p-4">
                        <p className="text-[11px] tracking-[0.18em] text-[#67806a]">COMMUNITY</p>
                        <p className="mt-2 text-xl text-[#1c2d1f]">Groups-lite</p>
                        <p className="mt-1 text-xs text-[#5c725f]">
                          Accountability without a noisy social feed.
                        </p>
                      </div>
                    </div>
                  </div>

                  <div className="grid gap-4 md:grid-cols-2 md:grid-rows-[auto_auto]">
                    <div className="rounded-2xl border border-[#d7e5d4] bg-white/80 p-3 md:col-span-2">
                      <p className="mb-2 text-[11px] tracking-[0.18em] text-[#67806a]">
                        INSET · TODAY
                      </p>
                      <div className="grid gap-3 sm:grid-cols-[1fr_1fr]">
                        <div className="relative overflow-hidden rounded-[1.2rem] border border-[#dbe7d8] bg-white">
                          <img
                            src="/app-screenshots/en_today_light.PNG"
                            alt="Today"
                            className="h-48 w-full object-cover object-top sm:h-56"
                          />
                        </div>
                        <div className="relative overflow-hidden rounded-[1.2rem] border border-[#dbe7d8] bg-white">
                          <img
                            src="/app-screenshots/en_analytics_light.PNG"
                            alt="Analytics"
                            className="h-48 w-full object-cover object-top sm:h-56"
                          />
                        </div>
                      </div>
                    </div>

                    <div className="rounded-2xl border border-[#d7e5d4] bg-white/80 p-3">
                      <p className="mb-2 text-[11px] tracking-[0.18em] text-[#67806a]">
                        DETACHED MODULE
                      </p>
                      <div className="relative mx-auto aspect-[450/920] w-[10.5rem]">
                        <div className="absolute inset-[4.6%] overflow-hidden rounded-[1.55rem] bg-white">
                          <img
                            src="/app-screenshots/en_dhikr_light.PNG"
                            alt="Dhikr screenshot"
                            className="h-full w-full object-cover"
                          />
                        </div>
                        <img
                          src="/app-screenshots/iphone_bezels.png"
                          alt=""
                          className="pointer-events-none absolute inset-0 h-full w-full object-contain"
                        />
                      </div>
                    </div>

                    <div className="rounded-2xl border border-[#d7e5d4] bg-white/80 p-3">
                      <p className="mb-2 text-[11px] tracking-[0.18em] text-[#67806a]">
                        WAITLIST
                      </p>
                      <FieldWaitlist locale={locale} />
                    </div>
                  </div>
                </div>
              </motion.div>
            </div>
          </motion.div>
        </section>

        <section
          id="field-notes"
          className="mx-auto mt-8 grid max-w-6xl gap-5 lg:grid-cols-[1.1fr_minmax(0,1fr)]"
        >
          <div className="rounded-[1.7rem] border border-[#d5e4d2] bg-white/70 p-6 backdrop-blur-xl">
            <p className="text-xs tracking-[0.22em] text-[#6b806c]">FIELD NOTES</p>
            <h2 className="mt-3 text-3xl leading-tight text-[#152317] sm:text-4xl">
              A tactile layout for a calm product.
            </h2>
            <p className="mt-3 text-sm leading-relaxed text-[#556a57]">
              This concept uses embedded panels instead of a standard marketing stack.
              The page behaves like a workspace surface: notes, modules, and inset app
              views arranged together.
            </p>
            <div className="mt-5 grid gap-3 sm:grid-cols-2">
              <div className="rounded-2xl border border-[#d9e8d7] bg-[#f9fcf6] p-4">
                <p className="text-sm text-[#1d3020]">Future in-page demo</p>
                <div className="mt-3 grid h-28 place-items-center rounded-xl border border-dashed border-[#cfe0cd] bg-white text-[11px] tracking-[0.18em] text-[#7b8f7d]">
                  VIDEO SLOT
                </div>
              </div>
              <div className="rounded-2xl border border-[#d9e8d7] bg-[#f9fcf6] p-4">
                <p className="text-sm text-[#1d3020]">MVP feature scope</p>
                <ul className="mt-2 space-y-1 text-xs text-[#596f5b]">
                  <li>• Habit tracking and reminders</li>
                  <li>• Dhikr counters and streaks</li>
                  <li>• Quotes and groups accountability</li>
                </ul>
              </div>
            </div>
          </div>

          <div id="faq" className="rounded-[1.7rem] border border-[#d5e4d2] bg-white/75 p-6 backdrop-blur-xl">
            <p className="text-xs tracking-[0.22em] text-[#6b806c]">FAQ FOLDS</p>
            <div className="mt-4 space-y-3">
              {[
                [
                  "Why this bright concept for a spiritual app?",
                  "To explore a grounded, morning-energy visual direction while keeping the tone calm and respectful.",
                ],
                [
                  "Will the final landing use this exact layout?",
                  "Not necessarily. This is a prototype variant meant to test a distinct composition style.",
                ],
                [
                  "Are terms and privacy still available?",
                  "Yes. They remain linked in the footer of every variant.",
                ],
              ].map(([q, a]) => (
                <details key={q} className="rounded-xl border border-[#dbe8d8] bg-[#f9fcf7] p-4">
                  <summary className="cursor-pointer text-sm font-medium text-[#1d2f20]">
                    {q}
                  </summary>
                  <p className="mt-2 text-sm leading-relaxed text-[#5b705d]">{a}</p>
                </details>
              ))}
            </div>
          </div>
        </section>
      </main>

      <footer className="mx-auto mt-8 flex max-w-7xl flex-col gap-4 px-5 pb-12 text-sm text-[#5c6f5d] sm:flex-row sm:items-center sm:justify-between sm:px-8">
        <p>Tilted Tablet Field • EN prototype</p>
        <div className="flex items-center gap-4">
          <Link href={`/${locale}/terms`} className="hover:text-[#16261a]">
            Terms
          </Link>
          <Link href={`/${locale}/privacy`} className="hover:text-[#16261a]">
            Privacy
          </Link>
          <Link href={`/${locale}`} className="hover:text-[#16261a]">
            Index
          </Link>
        </div>
      </footer>
    </div>
  );
}
