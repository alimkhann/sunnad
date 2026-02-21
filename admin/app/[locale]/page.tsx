import Link from "next/link";
import { Languages, Sparkles } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { getDictionary, isLocale } from "@/lib/i18n";

export default function LocaleHome({ params }: { params: { locale: string } }): React.JSX.Element {
  const locale = isLocale(params.locale) ? params.locale : "en";
  const t = getDictionary(locale);

  return (
    <main className="mx-auto flex min-h-screen max-w-5xl flex-col justify-center px-5 py-10 sm:px-8">
      <div className="mb-8 flex items-center justify-between">
        <Badge>{t.badge}</Badge>
        <div className="flex items-center gap-2 text-xs text-muted-foreground">
          <Languages className="h-4 w-4" />
          <span>EN / RU / KZ</span>
        </div>
      </div>

      <div className="grid gap-5 lg:grid-cols-[1.2fr_1fr]">
        <Card className="border-primary/25">
          <CardHeader>
            <CardTitle className="text-2xl">{t.title}</CardTitle>
            <CardDescription>{t.subtitle}</CardDescription>
          </CardHeader>
          <CardContent className="flex flex-wrap gap-3">
            <Button>{t.actions.signIn}</Button>
            <Button variant="secondary">{t.actions.openDashboard}</Button>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>{t.loginTitle}</CardTitle>
            <CardDescription>{t.loginHint}</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="rounded-md border border-border/80 bg-muted/20 p-4">
              <p className="font-medium">{t.editorCardTitle}</p>
              <p className="mt-1 text-sm text-muted-foreground">{t.editorCardHint}</p>
            </div>
            <div className="rounded-md border border-border/80 bg-muted/20 p-4">
              <p className="font-medium">{t.quotesCardTitle}</p>
              <p className="mt-1 text-sm text-muted-foreground">{t.quotesCardHint}</p>
            </div>
          </CardContent>
        </Card>
      </div>

      <div className="mt-8 flex items-center justify-between text-xs text-muted-foreground">
        <span>{t.appName}</span>
        <Link className="inline-flex items-center gap-1 hover:text-foreground" href={`/${locale}`}>
          <Sparkles className="h-3.5 w-3.5" />
          v0 shell
        </Link>
      </div>
    </main>
  );
}
