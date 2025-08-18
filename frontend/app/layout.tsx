import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import { Providers } from "@/components/Providers";
import { Navigation } from "@/components/Navigation";

const inter = Inter({ subsets: ["latin"] });

export const metadata: Metadata = {
  title: "stSOVABTC - Multi-Collateral Bitcoin Vault",
  description: "Deposit multiple BTC variants, earn sustainable yield with stSOVABTC",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className={`${inter.className} antialiased min-h-screen`}>
        <Providers>
          <div className="relative">
            <Navigation />
            {children}
          </div>
        </Providers>
      </body>
    </html>
  );
}
