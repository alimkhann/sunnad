import { getDictionary, isLocale, type Locale } from "@/lib/i18n";
import Link from "next/link";
import { getPrivacyContent } from "@/lib/legal";

export default async function PrivacyPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<React.JSX.Element> {
  const { locale: rawLocale } = await params;
  const locale: Locale = isLocale(rawLocale) ? rawLocale : "en";
  const t = getDictionary(locale);
  const content = getPrivacyContent(locale);

  return (
    <div className="min-h-screen bg-background">
      <nav className="border-b border-border/50 bg-background/80 backdrop-blur-xl">
        <div className="mx-auto flex h-16 max-w-3xl items-center px-4 sm:px-6">
          <Link href={`/${locale}`} className="text-lg font-bold font-heading text-foreground">
            {t.nav.logo}
          </Link>
        </div>
      </nav>
      <main className="mx-auto max-w-3xl px-4 py-12 sm:px-6 sm:py-16">
        <h1 className="text-3xl font-bold text-foreground font-heading">{t.footer.privacy}</h1>
        <div
          className="prose prose-gray mt-8 max-w-none dark:prose-invert [&_h2]:text-xl [&_h2]:font-semibold [&_h2]:mt-8 [&_h2]:mb-3 [&_p]:text-muted-foreground [&_p]:leading-relaxed [&_ul]:text-muted-foreground [&_li]:text-muted-foreground"
          dangerouslySetInnerHTML={{ __html: content }}
        />
      </main>
    </div>
  );
}
