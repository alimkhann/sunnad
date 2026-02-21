import { QuotesAdminClient } from "@/components/quotes-admin-client";
import { getDictionary, isLocale } from "@/lib/i18n";

export default async function LocaleHome({
  params
}: {
  params: Promise<{ locale: string }>;
}): Promise<React.JSX.Element> {
  const resolvedParams = await params;
  const locale = isLocale(resolvedParams.locale) ? resolvedParams.locale : "en";
  const dictionary = getDictionary(locale);

  return <QuotesAdminClient locale={locale} t={dictionary} />;
}
