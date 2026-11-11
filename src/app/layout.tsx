import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "BOKAN ERP",
  description: "Commercial operations workspace for Prime Investment Group and BlackRock Investment PLC."
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}