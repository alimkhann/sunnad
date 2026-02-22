import { isLocale } from "@/lib/i18n";
import { getSharedDict } from "@/lib/i18n";
import { PickerPage } from "@/components/picker";

export default async function Picker({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<React.JSX.Element> {
  const { locale: rawLocale } = await params;
  const locale = isLocale(rawLocale) ? rawLocale : "en";
  const dict = getSharedDict(locale);

  return <PickerPage locale={locale} dict={dict} />;
}
