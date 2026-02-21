import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

type QuoteTranslationInput = {
  locale: "en" | "ru" | "kk";
  text: string;
  source?: string | null;
  active?: boolean;
  draft?: boolean;
};

type CreateQuoteSetInput = {
  status?: "draft" | "approved" | "archived";
  translations: QuoteTranslationInput[];
};

type UpdateQuoteSetInput = {
  status?: "draft" | "approved" | "archived";
  translations?: QuoteTranslationInput[];
};

type DayOverrideInput = {
  day_date: string;
  quote_set_id: string;
};

type AuthContext = {
  userID: string;
  email: string | null;
  admin: SupabaseClient;
};

type QuoteSetRow = {
  id: string;
  status: "draft" | "approved" | "archived";
  created_by: string | null;
  approved_by: string | null;
  approved_at: string | null;
  created_at: string;
  updated_at: string;
};

type QuoteRow = {
  id: string;
  quote_set_id: string;
  locale: "en" | "ru" | "kk";
  text: string;
  source: string | null;
  active: boolean;
  draft: boolean;
  updated_at: string;
};

type QuoteOverrideRow = {
  day_date: string;
  quote_set_id: string;
};

const jsonHeaders = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET,POST,PATCH,DELETE,OPTIONS",
};

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: jsonHeaders });
  }

  const path = getFunctionPath(req.url, "admin-quotes");

  const auth = await requireAdmin(req);
  if (auth instanceof Response) {
    return auth;
  }

  try {
    if (req.method === "GET" && path === "/quotes") {
      return await handleGetQuotes(auth);
    }

    if (req.method === "POST" && path === "/quotes") {
      return await handleCreateQuoteSet(req, auth);
    }

    if (req.method === "PATCH" && path.startsWith("/quotes/")) {
      const setID = path.replace("/quotes/", "").trim();
      if (!setID) return json({ error: "Missing set id" }, 400);
      return await handlePatchQuoteSet(req, auth, setID);
    }

    if (req.method === "POST" && path.startsWith("/quotes/") && path.endsWith("/approve")) {
      const setID = path.replace("/quotes/", "").replace("/approve", "").trim();
      if (!setID) return json({ error: "Missing set id" }, 400);
      return await handleApproveQuoteSet(auth, setID);
    }

    if (req.method === "DELETE" && path.startsWith("/quotes/") && !path.includes("day-override")) {
      const setID = path.replace("/quotes/", "").trim();
      if (!setID) return json({ error: "Missing set id" }, 400);
      return await handleDeleteQuoteSet(auth, setID);
    }

    if (req.method === "POST" && path === "/quotes/verify-source") {
      return await handleVerifySource(req);
    }

    if (req.method === "POST" && path === "/quotes/day-override") {
      return await handleUpsertDayOverride(req, auth);
    }

    if (req.method === "DELETE" && path.startsWith("/quotes/day-override/")) {
      const day = path.replace("/quotes/day-override/", "").trim();
      if (!day) return json({ error: "Missing day" }, 400);
      return await handleDeleteDayOverride(auth, day);
    }

    return json({ error: "Not found" }, 404);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unexpected error";
    return json({ error: message }, 500);
  }
});

async function handleGetQuotes(auth: AuthContext): Promise<Response> {
  const quoteSetsResult = await auth.admin
    .from("quote_sets")
    .select("id,status,created_by,approved_by,approved_at,created_at,updated_at")
    .order("updated_at", { ascending: false })
    .returns<QuoteSetRow[]>();

  if (quoteSetsResult.error) {
    return json({ error: quoteSetsResult.error.message }, 500);
  }

  const quoteSetIDs = (quoteSetsResult.data ?? []).map((item) => item.id);

  let quotes: QuoteRow[] = [];
  if (quoteSetIDs.length > 0) {
    const quotesResult = await auth.admin
      .from("quotes")
      .select("id,quote_set_id,locale,text,source,active,draft,updated_at")
      .in("quote_set_id", quoteSetIDs)
      .order("updated_at", { ascending: false })
      .returns<QuoteRow[]>();

    if (quotesResult.error) {
      return json({ error: quotesResult.error.message }, 500);
    }
    quotes = quotesResult.data ?? [];
  }

  const overridesResult = await auth.admin
    .from("quote_day_overrides")
    .select("day_date,quote_set_id")
    .order("day_date", { ascending: true })
    .returns<QuoteOverrideRow[]>();

  if (overridesResult.error) {
    return json({ error: overridesResult.error.message }, 500);
  }

  const groupedQuotes = new Map<string, QuoteRow[]>();
  for (const row of quotes) {
    const current = groupedQuotes.get(row.quote_set_id) ?? [];
    current.push(row);
    groupedQuotes.set(row.quote_set_id, current);
  }

  const groupedOverrides = new Map<string, string[]>();
  for (const row of overridesResult.data ?? []) {
    const current = groupedOverrides.get(row.quote_set_id) ?? [];
    current.push(row.day_date);
    groupedOverrides.set(row.quote_set_id, current);
  }

  const payload = (quoteSetsResult.data ?? []).map((setRow) => ({
    ...setRow,
    translations: (groupedQuotes.get(setRow.id) ?? []).sort((a, b) => a.locale.localeCompare(b.locale)),
    override_days: groupedOverrides.get(setRow.id) ?? [],
  }));

  return json({ data: payload }, 200);
}

async function handleCreateQuoteSet(req: Request, auth: AuthContext): Promise<Response> {
  const body = (await req.json()) as CreateQuoteSetInput;
  const translations = normalizeTranslations(body.translations);

  if (translations.length === 0) {
    return json({ error: "At least one translation is required" }, 400);
  }

  const status = normalizeStatus(body.status) ?? "draft";

  const insertSet = await auth.admin
    .from("quote_sets")
    .insert({ status, created_by: auth.userID })
    .select("id,status,created_by,approved_by,approved_at,created_at,updated_at")
    .single<QuoteSetRow>();

  if (insertSet.error || !insertSet.data) {
    return json({ error: insertSet.error?.message ?? "Failed to create quote set" }, 500);
  }

  const quoteRows = translations.map((item) => ({
    quote_set_id: insertSet.data.id,
    locale: item.locale,
    text: item.text,
    source: item.source,
    active: item.active,
    draft: item.draft,
  }));

  const insertQuotes = await auth.admin.from("quotes").insert(quoteRows);
  if (insertQuotes.error) {
    return json({ error: insertQuotes.error.message }, 500);
  }

  return json({ data: insertSet.data }, 201);
}

async function handlePatchQuoteSet(req: Request, auth: AuthContext, setID: string): Promise<Response> {
  const body = (await req.json()) as UpdateQuoteSetInput;
  const patch: Record<string, unknown> = {};
  const normalizedStatus = normalizeStatus(body.status);
  if (normalizedStatus) {
    patch.status = normalizedStatus;
  }

  if (Object.keys(patch).length > 0) {
    const setUpdate = await auth.admin.from("quote_sets").update(patch).eq("id", setID);
    if (setUpdate.error) {
      return json({ error: setUpdate.error.message }, 500);
    }
  }

  if (body.translations) {
    const translations = normalizeTranslations(body.translations);
    for (const item of translations) {
      const upsert = await auth.admin.from("quotes").upsert(
        {
          quote_set_id: setID,
          locale: item.locale,
          text: item.text,
          source: item.source,
          active: item.active,
          draft: item.draft,
        },
        { onConflict: "quote_set_id,locale" },
      );

      if (upsert.error) {
        return json({ error: upsert.error.message }, 500);
      }
    }
  }

  return json({ ok: true }, 200);
}

async function handleDeleteQuoteSet(auth: AuthContext, setID: string): Promise<Response> {
  // Check that the set exists
  const existing = await auth.admin
    .from("quote_sets")
    .select("id")
    .eq("id", setID)
    .maybeSingle();

  if (existing.error) {
    return json({ error: existing.error.message }, 500);
  }
  if (!existing.data) {
    return json({ error: "Quote set not found" }, 404);
  }

  // Delete the set – child quotes are cascade-deleted via FK
  const deleteResult = await auth.admin.from("quote_sets").delete().eq("id", setID);
  if (deleteResult.error) {
    return json({ error: deleteResult.error.message }, 500);
  }

  return json({ ok: true }, 200);
}

async function handleVerifySource(req: Request): Promise<Response> {
  let body: { quote_text: string; source: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const quoteText = body.quote_text?.trim();
  const source = body.source?.trim();

  if (!quoteText) {
    return json({ error: "quote_text is required" }, 400);
  }

  const apiKey = Deno.env.get("GEMINI_API_KEY");
  const model = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash";

  if (!apiKey) {
    return json({ error: "GEMINI_API_KEY is not configured" }, 500);
  }

  const prompt = [
    "You are a scholarly fact-checker for Islamic quotes.",
    "Verify whether the following quote is authentic and correctly attributed.",
    "Search the web for reliable Islamic scholarship sources.",
    "Provide: 1) Whether the attribution is likely CORRECT, INCORRECT, or UNCERTAIN",
    "2) The most likely correct source if different",
    "3) Brief evidence from web sources",
    "Be concise (max 200 words).",
    "",
    `Quote: "${quoteText}"`,
    source ? `Claimed source: ${source}` : "Source: not provided — try to identify the correct source",
  ].join("\n");

  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;

  const geminiBody = {
    contents: [{ role: "user", parts: [{ text: prompt }] }],
    tools: [{ google_search: {} }],
    generationConfig: {
      temperature: 0.2,
      maxOutputTokens: 1024,
    },
  };

  try {
    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(geminiBody),
    });

    if (!response.ok) {
      const errText = await response.text();
      return json({ error: `Gemini request failed: ${errText.substring(0, 300)}` }, 502);
    }

    const raw = await response.json();
    const candidates = raw?.candidates;
    if (!Array.isArray(candidates) || candidates.length === 0) {
      return json({ error: "No response from Gemini" }, 502);
    }

    const first = candidates[0];
    const parts = first?.content?.parts;
    let text = "";
    if (Array.isArray(parts)) {
      text = parts.map((p: { text?: string }) => p.text ?? "").join("\n").trim();
    }

    // Extract grounding metadata if present
    const groundingMetadata = first?.groundingMetadata;
    const searchQueries = groundingMetadata?.searchEntryPoint?.renderedContent ? true : false;
    const groundingSupports = groundingMetadata?.groundingSupports ?? [];
    const webSearchQueries = groundingMetadata?.webSearchQueries ?? [];

    return json({
      verification: text,
      grounded: searchQueries || groundingSupports.length > 0,
      search_queries: webSearchQueries,
    }, 200);

  } catch (err) {
    const message = err instanceof Error ? err.message : "Unexpected error";
    return json({ error: `Verification failed: ${message}` }, 502);
  }
}

async function handleApproveQuoteSet(auth: AuthContext, setID: string): Promise<Response> {
  const updateSet = await auth.admin
    .from("quote_sets")
    .update({ status: "approved", approved_by: auth.userID, approved_at: new Date().toISOString() })
    .eq("id", setID);

  if (updateSet.error) {
    return json({ error: updateSet.error.message }, 500);
  }

  const updateQuotes = await auth.admin.from("quotes").update({ draft: false, active: true }).eq("quote_set_id", setID);
  if (updateQuotes.error) {
    return json({ error: updateQuotes.error.message }, 500);
  }

  return json({ ok: true }, 200);
}

async function handleUpsertDayOverride(req: Request, auth: AuthContext): Promise<Response> {
  const body = (await req.json()) as DayOverrideInput;
  const day = normalizeDay(body.day_date);
  if (!day) {
    return json({ error: "Invalid day_date. Use YYYY-MM-DD" }, 400);
  }

  if (!body.quote_set_id || !looksLikeUUID(body.quote_set_id)) {
    return json({ error: "Invalid quote_set_id" }, 400);
  }

  const overrideResult = await auth.admin
    .from("quote_day_overrides")
    .upsert(
      {
        day_date: day,
        quote_set_id: body.quote_set_id,
        created_by: auth.userID,
      },
      { onConflict: "day_date" },
    )
    .select("day_date,quote_set_id")
    .single<QuoteOverrideRow>();

  if (overrideResult.error || !overrideResult.data) {
    return json({ error: overrideResult.error?.message ?? "Failed to save override" }, 500);
  }

  return json({ data: overrideResult.data }, 200);
}

async function handleDeleteDayOverride(auth: AuthContext, day: string): Promise<Response> {
  const normalizedDay = normalizeDay(day);
  if (!normalizedDay) {
    return json({ error: "Invalid day. Use YYYY-MM-DD" }, 400);
  }

  const deleteResult = await auth.admin.from("quote_day_overrides").delete().eq("day_date", normalizedDay);
  if (deleteResult.error) {
    return json({ error: deleteResult.error.message }, 500);
  }

  return json({ ok: true }, 200);
}

async function requireAdmin(req: Request): Promise<AuthContext | Response> {
  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const authorization = req.headers.get("Authorization");

  if (!supabaseURL || !supabaseAnonKey || !serviceRoleKey) {
    return json({ error: "Function is not configured" }, 500);
  }

  if (!authorization) {
    return json({ error: "Missing authorization" }, 401);
  }

  const authClient = createClient(supabaseURL, supabaseAnonKey, {
    global: {
      headers: {
        Authorization: authorization,
      },
    },
  });

  const {
    data: { user },
    error: userError,
  } = await authClient.auth.getUser();

  if (userError || !user) {
    return json({ error: "Unauthorized" }, 401);
  }

  const admin = createClient(supabaseURL, serviceRoleKey);
  const allowResult = await admin.rpc("is_allowlisted_admin", { p_user_id: user.id });

  if (allowResult.error) {
    return json({ error: allowResult.error.message }, 500);
  }

  if (allowResult.data !== true) {
    return json({ error: "Forbidden" }, 403);
  }

  return {
    userID: user.id,
    email: user.email ?? null,
    admin,
  };
}

function normalizeTranslations(input: QuoteTranslationInput[] | undefined): Required<QuoteTranslationInput>[] {
  if (!Array.isArray(input)) {
    return [];
  }

  const map = new Map<QuoteTranslationInput["locale"], Required<QuoteTranslationInput>>();

  for (const row of input) {
    if (!row?.locale || !["en", "ru", "kk"].includes(row.locale)) {
      continue;
    }

    const normalizedText = normalizeText(row.text);
    if (!normalizedText) {
      continue;
    }

    map.set(row.locale, {
      locale: row.locale,
      text: normalizedText,
      source: normalizeNullableText(row.source),
      active: row.active ?? true,
      draft: row.draft ?? true,
    });
  }

  return Array.from(map.values());
}

function normalizeText(input: unknown): string | null {
  if (typeof input !== "string") {
    return null;
  }
  const value = input.trim();
  return value.length > 0 ? value : null;
}

function normalizeNullableText(input: unknown): string | null {
  if (typeof input !== "string") {
    return null;
  }
  const value = input.trim();
  return value.length > 0 ? value : null;
}

function normalizeStatus(input: unknown): "draft" | "approved" | "archived" | null {
  if (input === "draft" || input === "approved" || input === "archived") {
    return input;
  }
  return null;
}

function normalizeDay(input: string): string | null {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(input)) {
    return null;
  }
  return input;
}

function looksLikeUUID(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

function getFunctionPath(url: string, fnName: string): string {
  const pathname = new URL(url).pathname;
  const marker = `/${fnName}`;
  const index = pathname.indexOf(marker);
  if (index === -1) return "/";
  const suffix = pathname.slice(index + marker.length);
  return suffix.length > 0 ? suffix : "/";
}

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: jsonHeaders,
  });
}
