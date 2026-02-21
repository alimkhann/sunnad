import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Sunnad Admin",
  description: "Sunnad internal multilingual quote admin panel"
};

export default function RootLayout({ children }: { children: React.ReactNode }): React.JSX.Element {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
