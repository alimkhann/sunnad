import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

type SupportedLocale = "en" | "ru" | "kk";

type TranslatePayload = {
  /** @deprecated use `text` + `source_locale` instead */
  text_kk?: string;
  /** Source text to translate from */
  text?: string;
  /** Locale of the source text (default: "kk") */
  source_locale?: SupportedLocale;
  /** Target locales to translate into (default: complement of source_locale) */
  target_locales?: SupportedLocale[];
  source?: string;
  context?: string;
};

type TranslateResponse = {
  [K in SupportedLocale]?: string;
} & { model: string };

type AuthContext = {
  userID: string;
  admin: SupabaseClient;
};

const ALL_LOCALES: SupportedLocale[] = ["en", "ru", "kk"];

const jsonHeaders = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST,OPTIONS",
};

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: jsonHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const auth = await requireAdmin(req);
  if (auth instanceof Response) {
    return auth;
  }

  let payload: TranslatePayload;
  try {
    payload = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  // Backwards-compat: text_kk → text + source_locale=kk
  const sourceLocale: SupportedLocale = payload.source_locale ?? "kk";
  const sourceText = normalizeText(payload.text ?? payload.text_kk);

  if (!sourceText) {
    return json({ error: "text (or text_kk) is required" }, 400);
  }

  if (!ALL_LOCALES.includes(sourceLocale)) {
    return json({ error: `source_locale must be one of: ${ALL_LOCALES.join(", ")}` }, 400);
  }

  const targetLocales: SupportedLocale[] = payload.target_locales?.length
    ? payload.target_locales.filter((l) => ALL_LOCALES.includes(l) && l !== sourceLocale)
    : ALL_LOCALES.filter((l) => l !== sourceLocale);

  if (targetLocales.length === 0) {
    return json({ error: "No valid target locales specified" }, 400);
  }

  const source = normalizeText(payload.source);
  const context = normalizeText(payload.context);

  const apiKey = Deno.env.get("GEMINI_API_KEY");
  const model = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash";

  if (!apiKey) {
    return json({ error: "GEMINI_API_KEY is not configured" }, 500);
  }

  const prompt = buildPrompt({ sourceText, sourceLocale, targetLocales, source, context });
  const result = await callGemini({ prompt, apiKey, model, targetLocales });

  if (result instanceof Response) {
    return result;
  }

  return json(result, 200);
});

const LOCALE_NAMES: Record<SupportedLocale, string> = {
  en: "English",
  ru: "Russian",
  kk: "Kazakh",
};

function buildPrompt(input: {
  sourceText: string;
  sourceLocale: SupportedLocale;
  targetLocales: SupportedLocale[];
  source: string | null;
  context: string | null;
}): string {
  const contextLine = input.context
    ? `Context from editor: ${input.context}`
    : "Context from editor: none";

  const sourceLine = input.source
    ? `Original source attribution: ${input.source}`
    : "Original source attribution: not provided";

  const targetNames = input.targetLocales.map((l) => `${LOCALE_NAMES[l]} (${l})`).join(", ");
  const outputKeys = input.targetLocales.join(", ");

  return [
    "You are translating Islamic motivational quotes for a mobile habit app.",
    "Preserve meaning, tone, and respectfulness. Avoid slang or loose paraphrasing.",
    "If the text has religious wording, keep faithful terms and avoid changing doctrinal meaning.",
    `Output strict JSON only with keys: ${outputKeys}.`,
    "No markdown, no explanations, no extra keys.",
    contextLine,
    sourceLine,
    `Source language: ${LOCALE_NAMES[input.sourceLocale]}`,
    `Target languages: ${targetNames}`,
    `Quote: ${input.sourceText}`,
  ].join("\n");
}

async function callGemini(args: {
  prompt: string;
  apiKey: string;
  model: string;
  targetLocales: SupportedLocale[];
}): Promise<TranslateResponse | Response> {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${args.model}:generateContent?key=${args.apiKey}`;

  const body = {
    contents: [
      {
        role: "user",
        parts: [{ text: args.prompt }],
      },
    ],
    generationConfig: {
      responseMimeType: "application/json",
      temperature: 0.2,
      maxOutputTokens: 512,
    },
  };

  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    const errorText = await response.text();
    return json({ error: `Gemini request failed: ${errorText}` }, 502);
  }

  const raw = await response.json();
  const text = extractGeminiText(raw);
  if (!text) {
    return json({ error: "Gemini response did not contain text" }, 502);
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch {
    return json({ error: "Gemini response is not valid JSON" }, 502);
  }

  if (!parsed || typeof parsed !== "object") {
    return json({ error: "Gemini response has invalid structure" }, 502);
  }

  const result: TranslateResponse = { model: args.model };
  for (const locale of args.targetLocales) {
    const value = normalizeText((parsed as Record<string, unknown>)[locale]);
    if (!value) {
      return json({ error: `Gemini response must include non-empty ${locale}` }, 502);
    }
    result[locale] = value;
  }

  return result;
}

function extractGeminiText(raw: unknown): string | null {
  if (!raw || typeof raw !== "object") return null;
  const candidates = (raw as Record<string, unknown>).candidates;
  if (!Array.isArray(candidates) || candidates.length === 0) return null;

  const first = candidates[0];
  if (!first || typeof first !== "object") return null;

  const content = (first as Record<string, unknown>).content;
  if (!content || typeof content !== "object") return null;

  const parts = (content as Record<string, unknown>).parts;
  if (!Array.isArray(parts) || parts.length === 0) return null;

  const text = (parts[0] as Record<string, unknown>)?.text;
  return typeof text === "string" ? text : null;
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
    admin,
  };
}

function normalizeText(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: jsonHeaders,
  });
}
