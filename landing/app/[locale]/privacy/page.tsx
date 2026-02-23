import { isLocale, type Locale, getSharedDict } from "@/lib/i18n";
import { getPrivacyContent } from "@/lib/legal";
import LegalDocumentPage from "@/components/legal-document-page";

export default async function PrivacyRoute({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ theme?: string }>;
}): Promise<React.JSX.Element> {
  const { locale: rawLocale } = await params;
  const { theme: rawTheme } = await searchParams;
  const locale: Locale = isLocale(rawLocale) ? rawLocale : "en";
  const isDark = (rawTheme || "dark") === "dark";
  const t = getSharedDict(locale);
  const content = getPrivacyContent(locale);
  return (
    <LegalDocumentPage
      locale={locale}
      isDark={isDark}
      backLabel={t.legal.back}
      title={t.legal.privacy}
      contentHtml={content}
    />
  );
}
