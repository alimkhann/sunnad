import { getSharedDict, isLocale, type Locale } from "@/lib/i18n";
import Link from "next/link";
import { getTermsContent } from "@/lib/legal";

export default async function TermsPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<React.JSX.Element> {
  const { locale: rawLocale } = await params;
  const locale: Locale = isLocale(rawLocale) ? rawLocale : "en";
  const t = getSharedDict(locale);
  const content = getTermsContent(locale);

  return (
    <div className="min-h-screen bg-[#faf7f2]" style={{ fontFamily: "'Source Serif 4', Georgia, serif" }}>
      <nav className="border-b border-gray-200/60 bg-[#faf7f2]/80 backdrop-blur-xl">
        <div className="mx-auto flex h-16 max-w-3xl items-center justify-between px-4 sm:px-6">
          <Link href={`/${locale}`} className="text-lg font-bold text-gray-900" style={{ fontFamily: "'Sora', sans-serif" }}>
            Sunnad
          </Link>
          <Link href={`/${locale}`} className="text-sm text-gray-500 hover:text-gray-800 transition-colors">
            ← {t.legal.back}
          </Link>
        </div>
      </nav>
      <main className="mx-auto max-w-3xl px-4 py-12 sm:px-6 sm:py-16">
        <h1 className="text-3xl font-bold text-gray-900">{t.legal.terms}</h1>
        <div
          className="prose prose-gray mt-8 max-w-none [&_h2]:text-xl [&_h2]:font-semibold [&_h2]:mt-8 [&_h2]:mb-3 [&_p]:text-gray-600 [&_p]:leading-relaxed [&_ul]:text-gray-600 [&_li]:text-gray-600"
          dangerouslySetInnerHTML={{ __html: content }}
        />
      </main>
    </div>
  );
}
