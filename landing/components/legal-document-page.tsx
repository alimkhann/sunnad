import Link from "next/link";

interface LegalDocumentPageProps {
  locale: string;
  isDark: boolean;
  backLabel: string;
  title: string;
  contentHtml: string;
}

export default function LegalDocumentPage({
  locale,
  isDark,
  backLabel,
  title,
  contentHtml,
}: LegalDocumentPageProps): React.JSX.Element {
  const bgClass = isDark ? "bg-[#050505] text-[#FAFAFA]" : "bg-[#FFFFFF] text-[#0A0A0A]";
  const navBg = isDark ? "bg-[#050505]/80 border-white/5" : "bg-white/80 border-black/5";
  const proseClass = isDark
    ? "[&_h2]:text-gray-100 [&_p]:text-gray-400 [&_ul]:text-gray-400 [&_li]:text-gray-400"
    : "[&_h2]:text-gray-900 [&_p]:text-gray-600 [&_ul]:text-gray-600 [&_li]:text-gray-600";

  return (
    <div className={`min-h-screen ${bgClass}`} style={{ fontFamily: "'Outfit', sans-serif" }}>
      <nav className={`border-b backdrop-blur-xl ${navBg}`}>
        <div className="mx-auto flex h-16 max-w-3xl items-center justify-between px-4 sm:px-6">
          <Link href={`/${locale}`} className="text-lg font-bold">
            Sunnad
          </Link>
          <Link
            href={`/${locale}`}
            className={`text-sm transition-colors ${isDark ? "text-gray-400 hover:text-white" : "text-gray-500 hover:text-black"}`}
          >
            ← {backLabel}
          </Link>
        </div>
      </nav>
      <main className="mx-auto max-w-3xl px-4 py-12 sm:px-6 sm:py-16">
        <h1 className="text-3xl font-bold">{title}</h1>
        <div
          className={`prose mt-8 max-w-none [&_h2]:text-xl [&_h2]:font-semibold [&_h2]:mt-8 [&_h2]:mb-3 [&_p]:leading-relaxed ${proseClass}`}
          dangerouslySetInnerHTML={{ __html: contentHtml }}
        />
      </main>
    </div>
  );
}
