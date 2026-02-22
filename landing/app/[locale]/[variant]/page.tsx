import { notFound } from "next/navigation";
import { isLocale, isVariantId, type Locale, type VariantId } from "@/lib/i18n";
import V1Page from "@/components/variants/v1/page";
import V2Page from "@/components/variants/v2/page";
import V3Page from "@/components/variants/v3/page";
import V4Page from "@/components/variants/v4/page";
import V5Page from "@/components/variants/v5/page";

const variantMap: Record<
  VariantId,
  React.ComponentType<{ locale: string; variant: string }>
> = {
  "1": V1Page,
  "2": V2Page,
  "3": V3Page,
  "4": V4Page,
  "5": V5Page,
};

export default async function VariantPage({
  params,
}: {
  params: Promise<{ locale: string; variant: string }>;
}): Promise<React.JSX.Element> {
  const { locale: rawLocale, variant: rawVariant } = await params;

  if (!isVariantId(rawVariant)) notFound();

  const locale: Locale = isLocale(rawLocale) ? rawLocale : "en";
  const variant: VariantId = rawVariant;
  const Page = variantMap[variant];

  return <Page locale={locale} variant={variant} />;
}
