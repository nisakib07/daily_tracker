import React from "react";
import type { Metadata, Viewport } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import { Analytics } from "@vercel/analytics/next";
import "./globals.css";
import { DevServiceWorkerReset } from "@/components/dev-service-worker-reset";
import { PwaUpdateToast } from "@/components/pwa-update-toast";
import { AuthProvider } from "@/lib/auth-context";
import { ThemeProvider } from "@/components/theme-provider";

const _geist = Geist({ subsets: ["latin"] });
const _geistMono = Geist_Mono({ subsets: ["latin"] });

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  themeColor: "#10b981",
  interactiveWidget: "resizes-content",
};

export const metadata: Metadata = {
  title: {
    default: "Money Master",
    template: "%s · Money Master",
  },
  description:
    "Track your daily income and expenses across Cash, bKash, and Card accounts with ease",
  manifest: "/manifest.webmanifest",
  icons: {
    icon: [
      { url: "/icon.svg", type: "image/svg+xml" },
    ],
    apple: "/apple-icon.png",
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head />
      <body className={`${_geist.className} font-sans antialiased`} suppressHydrationWarning>
        <ThemeProvider
          attribute="class"
          defaultTheme="system"
          enableSystem
          disableTransitionOnChange
        >
          <AuthProvider>
            {children}
            <Analytics />
            <DevServiceWorkerReset />
            <PwaUpdateToast />
          </AuthProvider>
        </ThemeProvider>
      </body>
    </html>
  );
}
