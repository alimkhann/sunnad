import { getDictionary, isLocale, variantIds, variantNames, type Locale } from "@/lib/i18n";
import Link from "next/link";

const variantPreviews: Record<string, { gradient: string; label: string }> = {
  "1": {
    gradient: "from-teal-100 via-white to-sky-50",
    label: "Soft Glass",
  },
  "2": {
    gradient: "from-amber-50 via-orange-50 to-yellow-50",
    label: "Editorial Serif",
  },
  "3": {
    gradient: "from-white via-gray-50 to-emerald-50",
    label: "Geometric Clean",
  },
  "4": {
    gradient: "from-orange-100 via-amber-50 to-lime-50",
    label: "Warm Tactile",
  },
  "5": {
    gradient: "from-indigo-950 via-purple-950 to-slate-900",
    label: "Dark Cosmic",
  },
};

export default async function PickerPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<React.JSX.Element> {
  const { locale: rawLocale } = await params;
  const locale: Locale = isLocale(rawLocale) ? rawLocale : "en";
  const t = getDictionary(locale);

  return (
    <div className="min-h-screen bg-gradient-to-b from-gray-50 to-white">
      <div className="mx-auto max-w-5xl px-4 py-16 sm:px-6 lg:px-8">
        {/* Header */}
        <div className="mb-16 text-center">
          <h1 className="mb-2 text-4xl font-bold tracking-tight text-gray-900 sm:text-5xl font-heading">
            {t.nav.logo}
          </h1>
          <p className="mt-4 text-xl text-gray-600">
            {t.picker.title}
          </p>
          <p className="mt-2 text-base text-gray-500">
            {t.picker.subtitle}
          </p>
        </div>

        {/* Variant Grid */}
        <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {variantIds.map((id) => {
            const preview = variantPreviews[id];
            return (
              <Link
                key={id}
                href={`/${locale}/${id}`}
                className="group relative overflow-hidden rounded-2xl border border-gray-200 bg-white shadow-sm transition-all duration-300 hover:shadow-xl hover:scale-[1.02] hover:-translate-y-1"
              >
                {/* Preview gradient */}
                <div
                  className={`h-48 bg-gradient-to-br ${preview.gradient} flex items-center justify-center transition-transform duration-500 group-hover:scale-105`}
                >
                  <span className={`text-6xl font-bold ${id === "5" ? "text-white/30" : "text-gray-900/10"} font-heading`}>
                    {id}
                  </span>
                </div>

                {/* Info */}
                <div className="p-5">
                  <div className="flex items-center justify-between">
                    <div>
                      <h2 className="text-lg font-semibold text-gray-900 font-heading">
                        {variantNames[id]}
                      </h2>
                      <p className="mt-1 text-sm text-gray-500">
                        {t.picker.explore} →
                      </p>
                    </div>
                    <div className="flex h-10 w-10 items-center justify-center rounded-full bg-gray-100 text-sm font-medium text-gray-600 transition-colors group-hover:bg-primary group-hover:text-primary-foreground">
                      {id}
                    </div>
                  </div>
                </div>
              </Link>
            );
          })}
        </div>

        {/* Language Switcher */}
        <div className="mt-16 flex items-center justify-center gap-3">
          <span className="text-sm text-gray-500">{t.locale.switchLabel}:</span>
          {(["en", "ru", "kk"] as const).map((l) => (
            <Link
              key={l}
              href={`/${l}`}
              className={`rounded-full px-4 py-1.5 text-sm font-medium transition-colors ${
                l === locale
                  ? "bg-gray-900 text-white"
                  : "bg-gray-100 text-gray-600 hover:bg-gray-200"
              }`}
            >
              {t.locale[l]}
            </Link>
          ))}
        </div>
      </div>
    </div>
  );
}
