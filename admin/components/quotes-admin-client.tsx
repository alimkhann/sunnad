"use client";

import Link from "next/link";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { Session } from "@supabase/supabase-js";
import { getSupabaseBrowserClient } from "@/lib/supabase-browser";
import {
  approveQuoteSet,
  createQuoteSet,
  deleteQuoteSet,
  generateDraftTranslations,
  listQuoteSets,
  pinQuoteDay,
  unpinQuoteDay,
  updateQuoteSet,
  verifyQuoteSource,
} from "@/lib/admin-api";
import type { QuoteLocale, QuoteSet, QuoteStatus } from "@/lib/admin-types";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
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

type StatusFilter = "all" | QuoteStatus;

const localeOrder: QuoteLocale[] = ["kk", "ru", "en"];

const CACHE_KEY = "sunnad_admin_quote_sets";
const CACHE_TTL_MS = 10 * 60 * 1000; // 10 min

// ---------------------------------------------------------------------------
// localStorage cache helpers
// ---------------------------------------------------------------------------

function readCache(): QuoteSet[] | null {
  try {
    const raw = localStorage.getItem(CACHE_KEY);
    if (!raw) return null;
    const { data, ts } = JSON.parse(raw) as { data: QuoteSet[]; ts: number };
    if (Date.now() - ts > CACHE_TTL_MS) {
      localStorage.removeItem(CACHE_KEY);
      return null;
    }
    return data;
  } catch {
    return null;
  }
}

function writeCache(data: QuoteSet[]): void {
  try {
    localStorage.setItem(CACHE_KEY, JSON.stringify({ data, ts: Date.now() }));
  } catch {
    // quota exceeded – silently ignore
  }
}

function clearCache(): void {
  try {
    localStorage.removeItem(CACHE_KEY);
  } catch {
    // no-op
  }
}

// ---------------------------------------------------------------------------
// Main component
// ---------------------------------------------------------------------------

export function QuotesAdminClient({ locale, t }: Props): React.JSX.Element {
  const supabase = useMemo(() => getSupabaseBrowserClient(), []);
  const hasConfig = supabase !== null;
  const [session, setSession] = useState<Session | null>(null);

  // Auth form
  const [loginEmail, setLoginEmail] = useState("");
  const [loginPassword, setLoginPassword] = useState("");
  const [authMode, setAuthMode] = useState<"magic" | "password">("password");

  // Loading / feedback
  const [loading, setLoading] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  // Data
  const [sets, setSets] = useState<QuoteSet[]>([]);
  const [statusFilter, setStatusFilter] = useState<StatusFilter>("all");
  const [selectedSetID, setSelectedSetID] = useState<string | null>(null);

  // Editor
  const [status, setStatus] = useState<QuoteStatus>("draft");
  const [translations, setTranslations] = useState<
    Record<QuoteLocale, TranslationDraft>
  >(() => emptyTranslations());
  const [pinDay, setPinDay] = useState("");

  // Verify source
  const [verifyResult, setVerifyResult] = useState<string | null>(null);
  const [verifying, setVerifying] = useState(false);

  // Delete confirm
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);

  const selected = sets.find((item) => item.id === selectedSetID) ?? null;

  // Auto-clear notice after 4s
  const noticeTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const showNotice = useCallback((msg: string) => {
    setNotice(msg);
    if (noticeTimer.current) clearTimeout(noticeTimer.current);
    noticeTimer.current = setTimeout(() => setNotice(null), 4000);
  }, []);

  const resetForm = useCallback(() => {
    setSelectedSetID(null);
    setStatus("draft");
    setTranslations(emptyTranslations());
    setVerifyResult(null);
    setShowDeleteConfirm(false);
  }, []);

  const syncFormFromSet = useCallback(
    (setRow: QuoteSet | null) => {
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
      setVerifyResult(null);
      setShowDeleteConfirm(false);
    },
    [resetForm],
  );

  const accessToken = session?.access_token;

  const reload = useCallback(
    async (opts?: { skipCache?: boolean }) => {
      if (!accessToken) return;
      setLoading(true);
      setError(null);

      // Try cache first (unless skipCache)
      if (!opts?.skipCache) {
        const cached = readCache();
        if (cached) {
          setSets(cached);
          setLoading(false);
          // Still fetch fresh in background
          listQuoteSets({ accessToken })
            .then((payload) => {
              const data = payload.data ?? [];
              setSets(data);
              writeCache(data);
            })
            .catch(() => {});
          return;
        }
      }

      try {
        const payload = await listQuoteSets({ accessToken });
        const data = payload.data ?? [];
        setSets(data);
        writeCache(data);
      } catch (err) {
        setError(err instanceof Error ? err.message : t.errors.loadFailed);
      } finally {
        setLoading(false);
      }
    },
    [accessToken, t.errors.loadFailed],
  );

  // Bootstrap auth
  useEffect(() => {
    if (!supabase) return;
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

  // Load data on auth
  useEffect(() => {
    if (accessToken) {
      void reload();
    } else {
      setSets([]);
      resetForm();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [accessToken]);

  // -----------------------------------------------------------------------
  // Actions
  // -----------------------------------------------------------------------

  const save = useCallback(async () => {
    if (!accessToken) return;
    const payloadTranslations = localeOrder.map((lang) => ({
      locale: lang,
      text: translations[lang].text,
      source: translations[lang].source || null,
      active: translations[lang].active,
      draft: translations[lang].draft,
    }));
    if (!payloadTranslations.some((item) => item.text.trim())) {
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
        showNotice(t.messages.saved);
      } else {
        await createQuoteSet(
          { accessToken },
          { status, translations: payloadTranslations },
        );
        showNotice(t.messages.created);
      }
      clearCache();
      await reload({ skipCache: true });
      if (!selectedSetID) resetForm();
    } catch (err) {
      setError(err instanceof Error ? err.message : t.errors.saveFailed);
    } finally {
      setBusy(false);
    }
  }, [
    accessToken,
    selectedSetID,
    status,
    translations,
    t,
    showNotice,
    reload,
    resetForm,
  ]);

  const signIn = useCallback(async () => {
    if (!supabase) {
      setError(t.auth.configError);
      return;
    }
    setBusy(true);
    setError(null);
    try {
      if (authMode === "password") {
        const { error: signInError } = await supabase.auth.signInWithPassword({
          email: loginEmail.trim(),
          password: loginPassword,
        });
        if (signInError) throw signInError;
      } else {
        const { error: signInError } = await supabase.auth.signInWithOtp({
          email: loginEmail.trim(),
          options: {
            emailRedirectTo:
              typeof window !== "undefined"
                ? window.location.origin
                : undefined,
          },
        });
        if (signInError) throw signInError;
        showNotice(t.messages.magicLinkSent);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : t.errors.signInFailed);
    } finally {
      setBusy(false);
    }
  }, [loginEmail, loginPassword, authMode, supabase, t, showNotice]);

  const signOut = useCallback(async () => {
    if (!supabase) return;
    setBusy(true);
    setError(null);
    try {
      const { error: signOutError } = await supabase.auth.signOut();
      if (signOutError) throw signOutError;
      clearCache();
      showNotice(t.messages.signedOut);
    } catch (err) {
      setError(err instanceof Error ? err.message : t.errors.signOutFailed);
    } finally {
      setBusy(false);
    }
  }, [supabase, t, showNotice]);

  const generateDrafts = useCallback(async () => {
    if (!accessToken) return;
    let sourceLocale: QuoteLocale | null = null;
    let sourceText = "";
    for (const lang of localeOrder) {
      const text = translations[lang].text.trim();
      if (text) {
        sourceLocale = lang;
        sourceText = text;
        break;
      }
    }
    if (!sourceLocale || !sourceText) {
      setError(t.errors.kazakhRequired);
      return;
    }
    const targetLocales = localeOrder.filter((l) => l !== sourceLocale);
    const sourceAttribution =
      translations[sourceLocale].source?.trim() || undefined;

    setBusy(true);
    setError(null);
    try {
      const result = await generateDraftTranslations(
        { accessToken },
        {
          text: sourceText,
          source_locale: sourceLocale,
          target_locales: targetLocales,
          source: sourceAttribution,
          source_text: sourceAttribution,
          context: t.translationContext,
        },
      );

      setTranslations((current) => {
        const next = { ...current };
        for (const lang of targetLocales) {
          const value = result[lang];
          if (value) {
            next[lang] = { ...current[lang], text: value };
          }
          const sourceValue = result.sources?.[lang];
          if (sourceValue) {
            next[lang] = { ...next[lang], source: sourceValue };
          }
        }
        return next;
      });
      showNotice(t.messages.translated);
    } catch (err) {
      setError(err instanceof Error ? err.message : t.errors.translationFailed);
    } finally {
      setBusy(false);
    }
  }, [accessToken, translations, t, showNotice]);

  const approve = useCallback(async () => {
    if (!accessToken || !selectedSetID) return;
    setBusy(true);
    setError(null);
    try {
      await approveQuoteSet({ accessToken }, selectedSetID);
      clearCache();
      await reload({ skipCache: true });
      showNotice(t.messages.approved);
    } catch (err) {
      setError(err instanceof Error ? err.message : t.errors.approveFailed);
    } finally {
      setBusy(false);
    }
  }, [accessToken, reload, selectedSetID, t, showNotice]);

  const handleDelete = useCallback(async () => {
    if (!accessToken || !selectedSetID) return;
    setBusy(true);
    setError(null);
    try {
      await deleteQuoteSet({ accessToken }, selectedSetID);
      clearCache();
      resetForm();
      await reload({ skipCache: true });
      showNotice(t.messages.deleted);
    } catch (err) {
      setError(err instanceof Error ? err.message : t.errors.deleteFailed);
    } finally {
      setBusy(false);
      setShowDeleteConfirm(false);
    }
  }, [accessToken, selectedSetID, t, showNotice, reload, resetForm]);

  const handleArchive = useCallback(async () => {
    if (!accessToken || !selectedSetID) return;
    setBusy(true);
    setError(null);
    try {
      await updateQuoteSet({ accessToken }, selectedSetID, {
        status: "archived",
        translations: localeOrder.map((lang) => ({
          locale: lang,
          text: translations[lang].text,
          source: translations[lang].source || null,
          active: translations[lang].active,
          draft: translations[lang].draft,
        })),
      });
      clearCache();
      await reload({ skipCache: true });
      showNotice(t.messages.saved);
    } catch (err) {
      setError(err instanceof Error ? err.message : t.errors.saveFailed);
    } finally {
      setBusy(false);
    }
  }, [accessToken, selectedSetID, translations, t, showNotice, reload]);

  const handleVerifySource = useCallback(async () => {
    if (!accessToken) return;
    let quoteText = "";
    for (const lang of localeOrder) {
      if (translations[lang].text.trim()) {
        quoteText = translations[lang].text.trim();
        break;
      }
    }
    if (!quoteText) {
      setError(t.errors.kazakhRequired);
      return;
    }
    let source = "";
    for (const lang of localeOrder) {
      if (translations[lang].source.trim()) {
        source = translations[lang].source.trim();
        break;
      }
    }
    setVerifying(true);
    setVerifyResult(null);
    setError(null);
    try {
      const result = await verifyQuoteSource(
        { accessToken },
        { quote_text: quoteText, source: source || undefined },
      );
      setVerifyResult(result.verification);
    } catch (err) {
      setError(err instanceof Error ? err.message : t.errors.verifyFailed);
    } finally {
      setVerifying(false);
    }
  }, [accessToken, translations, t]);

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
      clearCache();
      await reload({ skipCache: true });
      showNotice(t.messages.dayPinned);
    } catch (err) {
      setError(err instanceof Error ? err.message : t.errors.pinFailed);
    } finally {
      setBusy(false);
    }
  }, [accessToken, pinDay, reload, selectedSetID, t, showNotice]);

  const unpinSelectedDay = useCallback(async () => {
    if (!accessToken || !pinDay) {
      setError(t.errors.dayRequired);
      return;
    }
    setBusy(true);
    setError(null);
    try {
      await unpinQuoteDay({ accessToken }, pinDay);
      clearCache();
      await reload({ skipCache: true });
      showNotice(t.messages.dayUnpinned);
    } catch (err) {
      setError(err instanceof Error ? err.message : t.errors.unpinFailed);
    } finally {
      setBusy(false);
    }
  }, [accessToken, pinDay, reload, t, showNotice]);

  const updateTranslation = (
    lang: QuoteLocale,
    patch: Partial<TranslationDraft>,
  ): void => {
    setTranslations((current) => ({
      ...current,
      [lang]: { ...current[lang], ...patch },
    }));
  };

  // -----------------------------------------------------------------------
  // Filtered list
  // -----------------------------------------------------------------------

  const filteredSets = useMemo(() => {
    if (statusFilter === "all") return sets;
    return sets.filter((s) => s.status === statusFilter);
  }, [sets, statusFilter]);

  const counts = useMemo(() => {
    const c = { all: sets.length, draft: 0, approved: 0, archived: 0 };
    for (const s of sets) c[s.status]++;
    return c;
  }, [sets]);

  const localeRouteBase = `/${locale}`;

  // -----------------------------------------------------------------------
  // LOGIN SCREEN
  // -----------------------------------------------------------------------

  if (!session) {
    return (
      <main className="mx-auto flex min-h-screen max-w-md flex-col justify-center px-5 py-10 sm:px-8">
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
                onChange={(e) => setLoginEmail(e.target.value)}
                placeholder={t.auth.emailPlaceholder}
                disabled={!hasConfig}
                onKeyDown={(e) => {
                  if (e.key === "Enter" && authMode === "password") {
                    document.getElementById("password")?.focus();
                  }
                }}
              />
            </div>

            {authMode === "password" ? (
              <>
                <div className="space-y-2">
                  <Label htmlFor="password">{t.auth.passwordLabel}</Label>
                  <Input
                    id="password"
                    type="password"
                    value={loginPassword}
                    onChange={(e) => setLoginPassword(e.target.value)}
                    placeholder={t.auth.passwordPlaceholder}
                    disabled={!hasConfig}
                    onKeyDown={(e) => {
                      if (e.key === "Enter") void signIn();
                    }}
                  />
                </div>
                <Button
                  className="w-full"
                  disabled={
                    busy || !loginEmail.trim() || !loginPassword || !hasConfig
                  }
                  onClick={() => void signIn()}
                >
                  {t.auth.signInWithPassword}
                </Button>
                <button
                  type="button"
                  className="w-full text-center text-xs text-muted-foreground hover:text-foreground"
                  onClick={() => setAuthMode("magic")}
                >
                  {t.auth.orUseMagicLink}
                </button>
              </>
            ) : (
              <>
                <Button
                  className="w-full"
                  disabled={busy || !loginEmail.trim() || !hasConfig}
                  onClick={() => void signIn()}
                >
                  {t.auth.sendMagicLink}
                </Button>
                <button
                  type="button"
                  className="w-full text-center text-xs text-muted-foreground hover:text-foreground"
                  onClick={() => setAuthMode("password")}
                >
                  {t.auth.orUsePassword}
                </button>
              </>
            )}

            {!hasConfig ? (
              <p className="text-sm text-red-400">{t.auth.configError}</p>
            ) : null}
            {notice ? <p className="text-sm text-primary">{notice}</p> : null}
            {error ? <p className="text-sm text-red-400">{error}</p> : null}
          </CardContent>
        </Card>
      </main>
    );
  }

  // -----------------------------------------------------------------------
  // MAIN PANEL
  // -----------------------------------------------------------------------

  return (
    <main className="mx-auto flex min-h-screen max-w-7xl flex-col gap-5 px-4 py-6 sm:px-8">
      {/* Header */}
      <header className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <p className="text-xs uppercase tracking-wide text-muted-foreground">
            {t.header.badge}
          </p>
          <h1 className="font-heading text-2xl font-semibold">
            {t.header.title}
          </h1>
          <p className="text-sm text-muted-foreground">{t.header.subtitle}</p>
        </div>
        <div className="flex items-center gap-2">
          <LocaleSwitch base={localeRouteBase} current={locale} />
          <Button
            variant="secondary"
            size="sm"
            onClick={() => {
              clearCache();
              void reload({ skipCache: true });
            }}
            disabled={loading || busy}
          >
            {t.actions.refresh}
          </Button>
          <Button
            variant="ghost"
            size="sm"
            onClick={() => void signOut()}
            disabled={busy}
          >
            {t.actions.signOut}
          </Button>
        </div>
      </header>

      {/* Content grid */}
      <section className="grid gap-5 lg:grid-cols-[1fr_1.2fr]">
        {/* LEFT: Quote list */}
        <Card className="flex flex-col">
          <CardHeader className="pb-3">
            <div className="flex items-center justify-between">
              <div>
                <CardTitle>{t.list.title}</CardTitle>
                <CardDescription>{t.list.hint}</CardDescription>
              </div>
              <Button variant="secondary" size="sm" onClick={resetForm}>
                {t.actions.newSet}
              </Button>
            </div>
            {/* Status filter tabs */}
            <div className="mt-3 flex gap-1">
              {(["all", "draft", "approved", "archived"] as StatusFilter[]).map(
                (f) => {
                  const label =
                    f === "all"
                      ? t.list.filterAll
                      : f === "draft"
                        ? t.list.filterDraft
                        : f === "approved"
                          ? t.list.filterApproved
                          : t.list.filterArchived;
                  return (
                    <button
                      type="button"
                      key={f}
                      onClick={() => setStatusFilter(f)}
                      className={`rounded-md px-2.5 py-1 text-xs font-medium transition ${
                        statusFilter === f
                          ? "bg-primary/15 text-primary"
                          : "text-muted-foreground hover:text-foreground"
                      }`}
                    >
                      {label} ({counts[f]})
                    </button>
                  );
                },
              )}
            </div>
          </CardHeader>
          <CardContent className="flex-1 overflow-hidden pb-4">
            <div className="max-h-[calc(100vh-16rem)] space-y-2 overflow-auto pr-1">
              {filteredSets.length === 0 ? (
                <p className="py-6 text-center text-sm text-muted-foreground">
                  {t.list.empty}
                </p>
              ) : null}
              {filteredSets.map((setRow) => (
                <button
                  type="button"
                  key={setRow.id}
                  onClick={() => syncFormFromSet(setRow)}
                  className={`w-full rounded-md border px-3 py-2.5 text-left transition ${
                    selectedSetID === setRow.id
                      ? "border-primary/60 bg-primary/10"
                      : "border-border/80 bg-muted/15 hover:border-primary/40"
                  }`}
                >
                  <div className="flex items-center justify-between gap-2">
                    <p className="font-mono text-xs font-medium">
                      {setRow.id.slice(0, 8)}
                    </p>
                    <StatusBadge status={setRow.status} t={t} />
                  </div>
                  <div className="mt-1.5 space-y-0.5">
                    {localeOrder.map((lang) => {
                      const tr = setRow.translations.find(
                        (item) => item.locale === lang,
                      );
                      const text = tr?.text?.trim();
                      return (
                        <div
                          key={lang}
                          className="flex items-start gap-1.5 text-xs"
                        >
                          <span
                            className={`shrink-0 font-semibold uppercase ${text ? "text-muted-foreground" : "text-red-400/70"}`}
                          >
                            {lang}
                          </span>
                          <p
                            className={`line-clamp-1 ${text ? "text-muted-foreground" : "italic text-red-400/50"}`}
                          >
                            {text || t.list.missing}
                          </p>
                        </div>
                      );
                    })}
                  </div>
                  {setRow.override_days.length > 0 ? (
                    <p className="mt-1 text-[10px] text-primary">
                      {t.list.pinnedDays}: {setRow.override_days.join(", ")}
                    </p>
                  ) : null}
                </button>
              ))}
            </div>
          </CardContent>
        </Card>

        {/* RIGHT: Editor */}
        <Card>
          <CardHeader className="pb-3">
            <div className="flex items-center justify-between">
              <div>
                <CardTitle>
                  {selectedSetID ? t.editor.editTitle : t.editor.createTitle}
                </CardTitle>
                <CardDescription>{t.editor.hint}</CardDescription>
              </div>
              {selectedSetID && <StatusBadge status={status} t={t} />}
            </div>
          </CardHeader>
          <CardContent className="space-y-4">
            {/* Status selector */}
            <div className="space-y-1.5">
              <Label htmlFor="status">{t.editor.statusLabel}</Label>
              <select
                id="status"
                className="flex h-9 w-full rounded-md border border-border/80 bg-background px-3 py-1.5 text-sm"
                value={status}
                onChange={(e) => setStatus(e.target.value as QuoteStatus)}
              >
                <option value="draft">{t.status.draft}</option>
                <option value="approved">{t.status.approved}</option>
                <option value="archived">{t.status.archived}</option>
              </select>
            </div>

            {/* Translation fields */}
            {localeOrder.map((lang) => (
              <div
                key={lang}
                className="rounded-md border border-border/70 p-3"
              >
                <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                  {t.locales[lang]}
                </p>
                <div className="space-y-2">
                  <Textarea
                    value={translations[lang].text}
                    onChange={(e) =>
                      updateTranslation(lang, { text: e.target.value })
                    }
                    placeholder={t.editor.quotePlaceholder}
                    rows={2}
                  />
                  <Input
                    value={translations[lang].source}
                    onChange={(e) =>
                      updateTranslation(lang, { source: e.target.value })
                    }
                    placeholder={t.editor.sourcePlaceholder}
                  />
                </div>
              </div>
            ))}

            {/* Action buttons */}
            <div className="flex flex-wrap gap-2">
              <Button
                onClick={() => void generateDrafts()}
                disabled={busy}
                variant="secondary"
                size="sm"
              >
                {t.actions.generateDrafts}
              </Button>
              <Button onClick={() => void save()} disabled={busy} size="sm">
                {selectedSetID ? t.actions.saveChanges : t.actions.createSet}
              </Button>
              {selectedSetID && status !== "approved" && (
                <Button
                  onClick={() => void approve()}
                  disabled={busy}
                  variant="secondary"
                  size="sm"
                >
                  {t.actions.approve}
                </Button>
              )}
              {selectedSetID && status !== "archived" && (
                <Button
                  onClick={() => void handleArchive()}
                  disabled={busy}
                  variant="secondary"
                  size="sm"
                >
                  {t.actions.archive}
                </Button>
              )}
            </div>

            {/* Verify source */}
            <div className="rounded-md border border-border/70 p-3">
              <div className="flex items-center gap-2">
                <Button
                  onClick={() => void handleVerifySource()}
                  disabled={verifying || busy}
                  variant="secondary"
                  size="sm"
                >
                  {verifying ? "..." : t.actions.verifySource}
                </Button>
                <span className="text-xs text-muted-foreground">
                  Gemini + Web Search
                </span>
              </div>
              {verifyResult && (
                <div className="mt-2 max-h-48 overflow-auto rounded bg-muted/20 p-2 text-xs whitespace-pre-wrap">
                  {verifyResult}
                </div>
              )}
            </div>

            {/* Day override */}
            <div className="rounded-md border border-border/70 p-3">
              <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                {t.editor.dayOverrideTitle}
              </p>
              <div className="flex flex-wrap items-center gap-2">
                <Input
                  type="date"
                  value={pinDay}
                  onChange={(e) => setPinDay(e.target.value)}
                  className="w-[180px]"
                />
                <Button
                  onClick={() => void pinSelectedDay()}
                  disabled={busy || !selectedSetID}
                  size="sm"
                >
                  {t.actions.pinDay}
                </Button>
                <Button
                  onClick={() => void unpinSelectedDay()}
                  disabled={busy}
                  variant="secondary"
                  size="sm"
                >
                  {t.actions.unpinDay}
                </Button>
              </div>
              {selected?.override_days?.length ? (
                <p className="mt-2 text-xs text-primary">
                  {t.list.pinnedDays}: {selected.override_days.join(", ")}
                </p>
              ) : null}
            </div>

            {/* Danger zone: Delete */}
            {selectedSetID && (
              <div className="rounded-md border border-red-400/30 bg-red-400/5 p-3">
                {showDeleteConfirm ? (
                  <div className="space-y-2">
                    <p className="text-sm font-medium text-red-400">
                      {t.messages.confirmDelete}
                    </p>
                    <p className="text-xs text-muted-foreground">
                      {t.messages.confirmDeleteHint}
                    </p>
                    <div className="flex gap-2">
                      <Button
                        size="sm"
                        className="bg-red-600 text-white hover:bg-red-700"
                        onClick={() => void handleDelete()}
                        disabled={busy}
                      >
                        {t.actions.delete}
                      </Button>
                      <Button
                        variant="secondary"
                        size="sm"
                        onClick={() => setShowDeleteConfirm(false)}
                      >
                        Cancel
                      </Button>
                    </div>
                  </div>
                ) : (
                  <Button
                    variant="ghost"
                    size="sm"
                    className="text-red-400 hover:bg-red-400/10 hover:text-red-400"
                    onClick={() => setShowDeleteConfirm(true)}
                  >
                    {t.actions.delete}
                  </Button>
                )}
              </div>
            )}

            {/* Feedback */}
            {notice ? <p className="text-sm text-primary">{notice}</p> : null}
            {error ? <p className="text-sm text-red-400">{error}</p> : null}
          </CardContent>
        </Card>
      </section>
    </main>
  );
}

// ---------------------------------------------------------------------------
// Sub-components
// ---------------------------------------------------------------------------

function StatusBadge({
  status,
  t,
}: {
  status: QuoteStatus;
  t: Dictionary;
}): React.JSX.Element {
  const colors: Record<QuoteStatus, string> = {
    draft: "bg-yellow-400/15 text-yellow-600",
    approved: "bg-green-400/15 text-green-600",
    archived: "bg-muted text-muted-foreground",
  };
  return (
    <span
      className={`inline-block rounded-full px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide ${colors[status]}`}
    >
      {t.status[status]}
    </span>
  );
}

function LocaleSwitch({
  base,
  current,
}: {
  base: string;
  current: Locale;
}): React.JSX.Element {
  return (
    <div className="inline-flex rounded-md border border-border/80 bg-muted/10 p-0.5 text-xs font-semibold uppercase tracking-wide">
      {(
        [
          ["en", "EN"],
          ["ru", "RU"],
          ["kk", "KZ"],
        ] as const
      ).map(([code, label]) => (
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

function emptyTranslations(): Record<QuoteLocale, TranslationDraft> {
  return {
    kk: { locale: "kk", text: "", source: "", active: true, draft: true },
    ru: { locale: "ru", text: "", source: "", active: true, draft: true },
    en: { locale: "en", text: "", source: "", active: true, draft: true },
  };
}
