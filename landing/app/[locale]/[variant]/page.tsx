import { notFound } from "next/navigation";
import { getDictionary, isLocale, isVariantId, type Locale, type VariantId } from "@/lib/i18n";
import { VariantShell } from "@/components/variants/variant-shell";

export default async function VariantPage({
  params,
}: {
  params: Promise<{ locale: string; variant: string }>;
}): Promise<React.JSX.Element> {
  const { locale: rawLocale, variant: rawVariant } = await params;

  if (!isVariantId(rawVariant)) notFound();

  const locale: Locale = isLocale(rawLocale) ? rawLocale : "en";
  const variant: VariantId = rawVariant;
  const t = getDictionary(locale);

  return <VariantShell variant={variant} locale={locale} t={t} />;
}
