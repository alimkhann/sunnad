"use client";

import Link from "next/link";
import { useCallback, useEffect, useMemo, useState } from "react";
import type { Session } from "@supabase/supabase-js";
import { getSupabaseBrowserClient } from "@/lib/supabase-browser";
import {
  approveQuoteSet,
  createQuoteSet,
  generateDraftTranslations,
  listQuoteSets,
  pinQuoteDay,
  unpinQuoteDay,
  updateQuoteSet,
} from "@/lib/admin-api";
import type { QuoteLocale, QuoteSet, QuoteStatus } from "@/lib/admin-types";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import type { Dictionary, Locale } from "@/lib/i18n";

type Props = {
  locale: Locale;
  t: Dictionary;
};

type TranslationDraft = {
  locale: QuoteLocale;
  text: string;
  source: string;
  active: boolean;
  draft: boolean;
};

const localeOrder: QuoteLocale[] = ["kk", "ru", "en"];

export function QuotesAdminClient({ locale, t }: Props): React.JSX.Element {
  const supabase = useMemo(() => getSupabaseBrowserClient(), []);
  const [session, setSession] = useState<Session | null>(null);
  const [loginEmail, setLoginEmail] = useState("");
  const [loading, setLoading] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [sets, setSets] = useState<QuoteSet[]>([]);
  const [selectedSetID, setSelectedSetID] = useState<string | null>(null);
  const [status, setStatus] = useState<QuoteStatus>("draft");
  const [translations, setTranslations] = useState<Record<QuoteLocale, TranslationDraft>>(() => emptyTranslations());
  const [pinDay, setPinDay] = useState("");

  const selected = sets.find((item) => item.id === selectedSetID) ?? null;

  const resetForm = useCallback(() => {
    setSelectedSetID(null);
    setStatus("draft");
    setTranslations(emptyTranslations());
  }, []);

  const syncFormFromSet = useCallback((setRow: QuoteSet | null) => {
    if (!setRow) {
      resetForm();
      return;
    }

    const next = emptyTranslations();
    for (const row of setRow.translations) {
      next[row.locale] = {
        locale: row.locale,
        text: row.text,
        source: row.source ?? "",
        active: row.active,
        draft: row.draft,
      };
    }

    setSelectedSetID(setRow.id);
    setStatus(setRow.status);
    setTranslations(next);
  }, [resetForm]);

  const accessToken = session?.access_token;

  const reload = useCallback(async () => {
    if (!accessToken) return;
    setLoading(true);
    setError(null);
    try {
      const payload = await listQuoteSets({ accessToken });
      setSets(payload.data ?? []);
      if (selectedSetID) {
        const refreshed = (payload.data ?? []).find((item) => item.id === selectedSetID) ?? null;
        syncFormFromSet(refreshed);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : t.errors.loadFailed);
    } finally {
      setLoading(false);
    }
  }, [accessToken, selectedSetID, syncFormFromSet, t.errors.loadFailed]);

  useEffect(() => {
    const bootstrap = async (): Promise<void> => {
      const { data } = await supabase.auth.getSession();
      setSession(data.session);
    };

    void bootstrap();

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      setSession(nextSession);
    });

    return () => subscription.unsubscribe();
  }, [supabase]);

  useEffect(() => {
    if (accessToken) {
      void reload();
    } else {
      setSets([]);
      resetForm();
    }
  }, [accessToken, reload, resetForm]);

  const save = useCallback(async () => {
    if (!accessToken) return;

    const payloadTranslations = localeOrder.map((lang) => ({
      locale: lang,
      text: translations[lang].text,
      source: translations[lang].source || null,
      active: translations[lang].active,
      draft: translations[lang].draft,
    }));

    if (!payloadTranslations.find((item) => item.locale === "kk")?.text.trim()) {
      setError(t.errors.kazakhRequired);
      return;
    }

    setBusy(true);
    setError(null);

    try {
      if (selectedSetID) {
        await updateQuoteSet({ accessToken }, selectedSetID, {
          status,
          translations: payloadTranslations,
        });
        setNotice(t.messages.saved);
      } else {
        await createQuoteSet({ accessToken }, {
          status,
          translations: payloadTranslations,
        });
        setNotice(t.messages.created);
      }
      await reload();
      if (!selectedSetID) {
        resetForm();
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : t.errors.saveFailed);
    } finally {
      setBusy(false);
    }
  }, [accessToken, selectedSetID, status, t.errors.kazakhRequired, t.errors.saveFailed, t.messages.created, t.messages.saved, reload, resetForm, translations]);

  const signIn = useCallback(async () => {
    setBusy(true);
    setError(null);
    try {
      const { error: signInError } = await supabase.auth.signInWithOtp({
        email: loginEmail.trim(),
        options: {
          emailRedirectTo: typeof window !== "undefined" ? window.location.href : undefined,
        },
      });

      if (signInError) {
        throw signInError;
      }
      setNotice(t.messages.magicLinkSent);
    } catch (err) {
      setError(err instanceof Error ? err.message : t.errors.signInFailed);
    } finally {
      setBusy(false);
    }
  }, [loginEmail, supabase, t.errors.signInFailed, t.messages.magicLinkSent]);

  const signOut = useCallback(async () => {
    setBusy(true);
    setError(null);
    try {
      const { error: signOutError } = await supabase.auth.signOut();
      if (signOutError) {
        throw signOutError;
      }
      setNotice(t.messages.signedOut);
    } catch (err) {
      setError(err instanceof Error ? err.message : t.errors.signOutFailed);
    } finally {
      setBusy(false);
    }
  }, [supabase, t.errors.signOutFailed, t.messages.signedOut]);

  const generateDrafts = useCallback(async () => {
    if (!accessToken) return;
    const kazakh = translations.kk.text.trim();
    if (!kazakh) {
      setError(t.errors.kazakhRequired);
      return;
    }

    setBusy(true);
    setError(null);
    try {
      const result = await generateDraftTranslations(
        { accessToken },
        {
          text_kk: kazakh,
          source: translations.kk.source,
          context: t.translationContext,
        },
      );

      setTranslations((current) => ({
        ...current,
        en: { ...current.en, text: result.en },
        ru: { ...current.ru, text: result.ru },
      }));

      setNotice(t.messages.translated);
    } catch (err) {
      setError(err instanceof Error ? err.message : t.errors.translationFailed);
    } finally {
      setBusy(false);
    }
  }, [accessToken, t.errors.kazakhRequired, t.errors.translationFailed, t.messages.translated, t.translationContext, translations.kk.source, translations.kk.text]);

  const approve = useCallback(async () => {
    if (!accessToken || !selectedSetID) return;

    setBusy(true);
    setError(null);
    try {
      await approveQuoteSet({ accessToken }, selectedSetID);
      await reload();
      setNotice(t.messages.approved);
    } catch (err) {
      setError(err instanceof Error ? err.message : t.errors.approveFailed);
    } finally {
      setBusy(false);
    }
  }, [accessToken, reload, selectedSetID, t.errors.approveFailed, t.messages.approved]);

  const pinSelectedDay = useCallback(async () => {
    if (!accessToken || !selectedSetID) {
      setError(t.errors.selectSetFirst);
      return;
    }

    if (!pinDay) {
      setError(t.errors.dayRequired);
      return;
    }

    setBusy(true);
    setError(null);
    try {
      await pinQuoteDay({ accessToken }, pinDay, selectedSetID);
      await reload();
      setNotice(t.messages.dayPinned);
    } catch (err) {
      setError(err instanceof Error ? err.message : t.errors.pinFailed);
    } finally {
      setBusy(false);
    }
  }, [accessToken, pinDay, reload, selectedSetID, t.errors.dayRequired, t.errors.pinFailed, t.errors.selectSetFirst, t.messages.dayPinned]);

  const unpinSelectedDay = useCallback(async () => {
    if (!accessToken || !pinDay) {
      setError(t.errors.dayRequired);
      return;
    }

    setBusy(true);
    setError(null);
    try {
      await unpinQuoteDay({ accessToken }, pinDay);
      await reload();
      setNotice(t.messages.dayUnpinned);
    } catch (err) {
      setError(err instanceof Error ? err.message : t.errors.unpinFailed);
    } finally {
      setBusy(false);
    }
  }, [accessToken, pinDay, reload, t.errors.dayRequired, t.errors.unpinFailed, t.messages.dayUnpinned]);

  const updateTranslation = (lang: QuoteLocale, patch: Partial<TranslationDraft>): void => {
    setTranslations((current) => ({
      ...current,
      [lang]: {
        ...current[lang],
        ...patch,
      },
    }));
  };

  const localeRouteBase = `/${locale}`;

  if (!session) {
    return (
      <main className="mx-auto flex min-h-screen max-w-xl flex-col justify-center px-5 py-10 sm:px-8">
        <Card className="border-primary/25">
          <CardHeader>
            <CardTitle>{t.auth.title}</CardTitle>
            <CardDescription>{t.auth.hint}</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="email">{t.auth.emailLabel}</Label>
              <Input
                id="email"
                type="email"
                value={loginEmail}
                onChange={(event) => setLoginEmail(event.target.value)}
                placeholder={t.auth.emailPlaceholder}
              />
            </div>
            <Button disabled={busy || !loginEmail.trim()} onClick={() => void signIn()}>
              {t.auth.sendMagicLink}
            </Button>
            {notice ? <p className="text-sm text-primary">{notice}</p> : null}
            {error ? <p className="text-sm text-red-400">{error}</p> : null}
          </CardContent>
        </Card>
      </main>
    );
  }

  return (
    <main className="mx-auto flex min-h-screen max-w-7xl flex-col gap-6 px-5 py-8 sm:px-8">
      <header className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <p className="text-xs uppercase tracking-wide text-muted-foreground">{t.header.badge}</p>
          <h1 className="font-heading text-2xl font-semibold">{t.header.title}</h1>
          <p className="text-sm text-muted-foreground">{t.header.subtitle}</p>
        </div>
        <div className="flex items-center gap-2">
          <LocaleSwitch base={localeRouteBase} current={locale} />
          <Button variant="secondary" onClick={() => void reload()} disabled={loading || busy}>
            {t.actions.refresh}
          </Button>
          <Button variant="ghost" onClick={() => void signOut()} disabled={busy}>
            {t.actions.signOut}
          </Button>
        </div>
      </header>

      <section className="grid gap-5 lg:grid-cols-[0.9fr_1.1fr]">
        <Card>
          <CardHeader>
            <CardTitle>{t.list.title}</CardTitle>
            <CardDescription>{t.list.hint}</CardDescription>
          </CardHeader>
          <CardContent className="space-y-3">
            <Button variant="secondary" onClick={resetForm}>
              {t.actions.newSet}
            </Button>
            <div className="max-h-[560px] space-y-2 overflow-auto pr-1">
              {sets.length === 0 ? <p className="text-sm text-muted-foreground">{t.list.empty}</p> : null}
              {sets.map((setRow) => (
                <button
                  type="button"
                  key={setRow.id}
                  onClick={() => syncFormFromSet(setRow)}
                  className={`w-full rounded-md border px-3 py-3 text-left transition ${
                    selectedSetID === setRow.id
                      ? "border-primary/60 bg-primary/10"
                      : "border-border/80 bg-muted/15 hover:border-primary/40"
                  }`}
                >
                  <div className="flex items-center justify-between gap-3">
                    <p className="font-medium">{setRow.id.slice(0, 8).toUpperCase()}</p>
                    <span className="text-xs uppercase tracking-wide text-muted-foreground">{t.status[setRow.status]}</span>
                  </div>
                  <p className="mt-1 line-clamp-2 text-sm text-muted-foreground">{previewText(setRow)}</p>
                  {setRow.override_days.length > 0 ? (
                    <p className="mt-1 text-xs text-primary">{t.list.pinnedDays}: {setRow.override_days.join(", ")}</p>
                  ) : null}
                </button>
              ))}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>{selectedSetID ? t.editor.editTitle : t.editor.createTitle}</CardTitle>
            <CardDescription>{t.editor.hint}</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="status">{t.editor.statusLabel}</Label>
              <select
                id="status"
                className="flex h-10 w-full rounded-md border border-border/80 bg-background px-3 py-2 text-sm"
                value={status}
                onChange={(event) => setStatus(event.target.value as QuoteStatus)}
              >
                <option value="draft">{t.status.draft}</option>
                <option value="approved">{t.status.approved}</option>
                <option value="archived">{t.status.archived}</option>
              </select>
            </div>

            {localeOrder.map((lang) => (
              <div key={lang} className="rounded-md border border-border/70 p-3">
                <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground">{t.locales[lang]}</p>
                <div className="space-y-2">
                  <Textarea
                    value={translations[lang].text}
                    onChange={(event) => updateTranslation(lang, { text: event.target.value })}
                    placeholder={t.editor.quotePlaceholder}
                  />
                  <Input
                    value={translations[lang].source}
                    onChange={(event) => updateTranslation(lang, { source: event.target.value })}
                    placeholder={t.editor.sourcePlaceholder}
                  />
                </div>
              </div>
            ))}

            <div className="flex flex-wrap gap-2">
              <Button onClick={() => void generateDrafts()} disabled={busy} variant="secondary">
                {t.actions.generateDrafts}
              </Button>
              <Button onClick={() => void save()} disabled={busy}>
                {selectedSetID ? t.actions.saveChanges : t.actions.createSet}
              </Button>
              <Button onClick={() => void approve()} disabled={busy || !selectedSetID} variant="secondary">
                {t.actions.approve}
              </Button>
            </div>

            <div className="rounded-md border border-border/70 p-3">
              <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground">{t.editor.dayOverrideTitle}</p>
              <div className="flex flex-wrap items-center gap-2">
                <Input type="date" value={pinDay} onChange={(event) => setPinDay(event.target.value)} className="w-[220px]" />
                <Button onClick={() => void pinSelectedDay()} disabled={busy || !selectedSetID}>
                  {t.actions.pinDay}
                </Button>
                <Button onClick={() => void unpinSelectedDay()} disabled={busy} variant="secondary">
                  {t.actions.unpinDay}
                </Button>
              </div>
              {selected?.override_days?.length ? (
                <p className="mt-2 text-xs text-primary">{t.list.pinnedDays}: {selected.override_days.join(", ")}</p>
              ) : null}
            </div>

            {notice ? <p className="text-sm text-primary">{notice}</p> : null}
            {error ? <p className="text-sm text-red-400">{error}</p> : null}
          </CardContent>
        </Card>
      </section>
    </main>
  );
}

function LocaleSwitch({ base, current }: { base: string; current: Locale }): React.JSX.Element {
  return (
    <div className="inline-flex rounded-md border border-border/80 bg-muted/10 p-1 text-xs font-semibold uppercase tracking-wide">
      {([
        ["en", "EN"],
        ["ru", "RU"],
        ["kk", "KZ"],
      ] as const).map(([code, label]) => (
        <Link
          key={code}
          href={base.replace(/^\/(en|ru|kk)/, `/${code}`)}
          className={`rounded px-2 py-1 ${current === code ? "bg-card text-foreground" : "text-muted-foreground hover:text-foreground"}`}
        >
          {label}
        </Link>
      ))}
    </div>
  );
}

function previewText(setRow: QuoteSet): string {
  const ordered = [...setRow.translations].sort((a, b) => localeOrder.indexOf(a.locale) - localeOrder.indexOf(b.locale));
  return ordered.find((item) => item.text.trim())?.text ?? "-";
}

function emptyTranslations(): Record<QuoteLocale, TranslationDraft> {
  return {
    kk: { locale: "kk", text: "", source: "", active: true, draft: true },
    ru: { locale: "ru", text: "", source: "", active: true, draft: true },
    en: { locale: "en", text: "", source: "", active: true, draft: true },
  };
}
