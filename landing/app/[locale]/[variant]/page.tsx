import { notFound } from "next/navigation";
import { isLocale, isVariantId, type Locale, type VariantId } from "@/lib/i18n";
import V1Page from "@/components/variants/v1/page";
import V2Page from "@/components/variants/v2/page";
import V3Page from "@/components/variants/v3/page";
import V4Page from "@/components/variants/v4/page";
import V5Page from "@/components/variants/v5/page";
import V6Page from "@/components/variants/v6/page";
import V7Page from "@/components/variants/v7/page";
import V8Page from "@/components/variants/v8/page";
import V9Page from "@/components/variants/v9/page";
import V10Page from "@/components/variants/v10/page";
import V11Page from "@/components/variants/v11/page";
import V12Page from "@/components/variants/v12/page";
import V13Page from "@/components/variants/v13/page";
import V14Page from "@/components/variants/v14/page";
import V15Page from "@/components/variants/v15/page";

const variantMap: Record<
  VariantId,
  React.ComponentType<{ locale: string; variant: string }>
> = {
  "1": V1Page,
  "2": V2Page,
  "3": V3Page,
  "4": V4Page,
  "5": V5Page,
  "6": V6Page,
  "7": V7Page,
  "8": V8Page,
  "9": V9Page,
  "10": V10Page,
  "11": V11Page,
  "12": V12Page,
  "13": V13Page,
  "14": V14Page,
  "15": V15Page,
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
