import { isLocale } from "@/lib/i18n";
import LandingPage from "@/features/landing/page";

export default async function LocalePage({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<React.JSX.Element> {
  const { locale: rawLocale } = await params;
  const locale = isLocale(rawLocale) ? rawLocale : "en";

  return <LandingPage locale={locale} />;
}
