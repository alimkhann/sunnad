import { Locale, isLocale } from "@/lib/i18n";

export default async function LocaleLayout({
  children,
  params
}: {
  children: React.ReactNode;
  params: Promise<{ locale: string }>;
}): Promise<React.JSX.Element> {
  const resolvedParams = await params;
  const locale: Locale = isLocale(resolvedParams.locale) ? resolvedParams.locale : "en";
  return <section data-locale={locale}>{children}</section>;
}
