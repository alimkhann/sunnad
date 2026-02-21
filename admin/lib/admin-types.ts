export type QuoteLocale = "en" | "ru" | "kk";

export type QuoteStatus = "draft" | "approved" | "archived";

export type QuoteTranslation = {
  id: string;
  quote_set_id: string;
  locale: QuoteLocale;
  text: string;
  source: string | null;
  active: boolean;
  draft: boolean;
  updated_at: string;
};

export type QuoteSet = {
  id: string;
  status: QuoteStatus;
  created_by: string | null;
  approved_by: string | null;
  approved_at: string | null;
  created_at: string;
  updated_at: string;
  translations: QuoteTranslation[];
  override_days: string[];
};

export type QuoteCollectionResponse = {
  data: QuoteSet[];
};

export type TranslateResponse = {
  en?: string;
  ru?: string;
  kk?: string;
  model: string;
};

export type TranslatePayload = {
  /** @deprecated use text + source_locale */
  text_kk?: string;
  text?: string;
  source_locale?: QuoteLocale;
  target_locales?: QuoteLocale[];
  source?: string;
  context?: string;
};
