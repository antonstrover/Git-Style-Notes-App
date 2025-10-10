import type { Metadata } from "next";
import { Inter, JetBrains_Mono } from "next/font/google";
import "./globals.css";
import { QueryProvider } from "@/lib/providers/query-provider";
import { ThemeProvider } from "@/lib/providers/theme-provider";
import { ConditionalHeader } from "@/components/layout/conditional-header";
import { Toaster } from "@/components/ui/toaster";
import { CommandPaletteProvider } from "@/components/search/command-palette-provider";

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
  display: "swap",
});

const jetbrainsMono = JetBrains_Mono({
  subsets: ["latin"],
  variable: "--font-jetbrains-mono",
  display: "swap",
});

export const metadata: Metadata = {
  title: process.env.NEXT_PUBLIC_APP_NAME || "Versioned Notes",
  description: "Collaborative note-taking with immutable version history",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className={`${inter.variable} ${jetbrainsMono.variable} font-sans`}>
        <ThemeProvider attribute="class" defaultTheme="dark" enableSystem>
          <QueryProvider>
            <CommandPaletteProvider>
              <div className="flex min-h-screen flex-col">
                <ConditionalHeader />
                <main className="flex-1">{children}</main>
              </div>
              <Toaster />
            </CommandPaletteProvider>
          </QueryProvider>
        </ThemeProvider>
      </body>
    </html>
  );
}
