import { Locale, isLocale } from "@/lib/i18n";

export default function LocaleLayout({
  children,
  params
}: {
  children: React.ReactNode;
  params: { locale: string };
}): React.JSX.Element {
  const locale: Locale = isLocale(params.locale) ? params.locale : "en";
  return <section data-locale={locale}>{children}</section>;
}
