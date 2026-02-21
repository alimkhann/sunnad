import { adminConfig } from "@/lib/config";
import type { QuoteCollectionResponse, QuoteStatus, QuoteTranslation, TranslateResponse, VerifySourceResponse } from "@/lib/admin-types";

const baseFunctionURL = `${adminConfig.supabaseURL.replace(/\/$/, "")}/functions/v1`;

type AuthHeaderParams = {
  accessToken: string;
};

type QuoteMutationInput = {
  status: QuoteStatus;
  translations: Array<Pick<QuoteTranslation, "locale" | "text" | "source" | "active" | "draft">>;
};

export async function listQuoteSets(params: AuthHeaderParams): Promise<QuoteCollectionResponse> {
  return request<QuoteCollectionResponse>("GET", "/admin-quotes/quotes", params);
}

export async function createQuoteSet(params: AuthHeaderParams, input: QuoteMutationInput): Promise<void> {
  await request("POST", "/admin-quotes/quotes", params, input);
}

export async function updateQuoteSet(params: AuthHeaderParams, setID: string, input: QuoteMutationInput): Promise<void> {
  await request("PATCH", `/admin-quotes/quotes/${setID}`, params, input);
}

export async function approveQuoteSet(params: AuthHeaderParams, setID: string): Promise<void> {
  await request("POST", `/admin-quotes/quotes/${setID}/approve`, params);
}

export async function deleteQuoteSet(params: AuthHeaderParams, setID: string): Promise<void> {
  await request("DELETE", `/admin-quotes/quotes/${setID}`, params);
}

export async function verifyQuoteSource(
  params: AuthHeaderParams,
  payload: { quote_text: string; source?: string },
): Promise<VerifySourceResponse> {
  return request<VerifySourceResponse>("POST", "/admin-quotes/quotes/verify-source", params, payload);
}

export async function pinQuoteDay(params: AuthHeaderParams, day: string, quoteSetID: string): Promise<void> {
  await request("POST", "/admin-quotes/quotes/day-override", params, {
    day_date: day,
    quote_set_id: quoteSetID,
  });
}

export async function unpinQuoteDay(params: AuthHeaderParams, day: string): Promise<void> {
  await request("DELETE", `/admin-quotes/quotes/day-override/${day}`, params);
}

export async function generateDraftTranslations(
  params: AuthHeaderParams,
  payload: { text_kk?: string; text?: string; source_locale?: string; target_locales?: string[]; source?: string; source_text?: string; context?: string },
): Promise<TranslateResponse> {
  return request<TranslateResponse>("POST", "/translate-quote", params, payload);
}

async function request<T = Record<string, unknown>>(
  method: "GET" | "POST" | "PATCH" | "DELETE",
  path: string,
  params: AuthHeaderParams,
  body?: unknown,
): Promise<T> {
  const response = await fetch(`${baseFunctionURL}${path}`, {
    method,
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${params.accessToken}`,
      apikey: adminConfig.supabaseAnonKey,
    },
    body: body ? JSON.stringify(body) : undefined,
  });

  const json = (await response.json().catch(() => ({}))) as Record<string, unknown>;

  if (!response.ok) {
    const message = typeof json.error === "string" ? json.error : `Request failed (${response.status})`;
    throw new Error(message);
  }

  return json as T;
}
