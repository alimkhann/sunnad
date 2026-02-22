import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Sunnad — Build better habits, together",
  description:
    "An offline-first Islamic habit tracker with daily quotes, streaks, and group accountability.",
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  maximumScale: 5,
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#f8f8f8" },
    { media: "(prefers-color-scheme: dark)", color: "#0a0e27" },
  ],
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}): React.JSX.Element {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link
          rel="preconnect"
          href="https://fonts.gstatic.com"
          crossOrigin="anonymous"
        />
        {/* V1: Playfair Display + Cormorant Garamond + Source Serif 4 */}
        {/* V2: Plus Jakarta Sans + Crimson Pro + DM Sans */}
        {/* V3: Syne + JetBrains Mono + Manrope */}
        {/* V4: Unbounded + Outfit + Space Mono */}
        {/* V5: Fraunces + Nunito Sans + Caveat */}
        {/* V6: Outfit + Cormorant Garamond */}
        {/* V7: Newsreader + JetBrains Mono */}
        {/* V8: Bricolage Grotesque */}
        {/* V9: Plus Jakarta Sans */}
        {/* V10: Syne + Inter */}
        {/* Picker: Sora */}
        <link
          href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@400;600;700;900&family=Cormorant+Garamond:ital,wght@0,300;0,400;0,600;1,400&family=Source+Serif+4:ital,opsz,wght@0,8..60,300;0,8..60,400;0,8..60,600;1,8..60,400&family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&family=Crimson+Pro:ital,wght@0,300;0,400;0,600;1,400&family=DM+Sans:wght@300;400;500;700&family=Syne:wght@400;600;700;800&family=JetBrains+Mono:wght@400;500;700&family=Manrope:wght@300;400;500;600;700;800&family=Unbounded:wght@300;400;600;700;900&family=Outfit:wght@300;400;500;600;700&family=Space+Mono:wght@400;700&family=Fraunces:ital,opsz,wght@0,9..144,300;0,9..144,400;0,9..144,600;0,9..144,700;0,9..144,900;1,9..144,400;1,9..144,700&family=Nunito+Sans:wght@300;400;600;700&family=Caveat:wght@400;500;600;700&family=Sora:wght@300;400;500;600;700&family=Newsreader:ital,opsz,wght@0,6..72,300;0,6..72,400;0,6..72,500;0,6..72,600;0,6..72,700;1,6..72,400;1,6..72,500&family=Bricolage+Grotesque:opsz,wght@12..96,300;12..96,400;12..96,500;12..96,600;12..96,700;12..96,800&family=Inter:wght@300;400;500;600;700;800;900&display=swap"
          rel="stylesheet"
        />
      </head>
      <body>{children}</body>
    </html>
  );
}
