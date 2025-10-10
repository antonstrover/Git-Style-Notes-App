"use client";

import { usePathname } from "next/navigation";
import { Header } from "./header";

export function ConditionalHeader() {
  const pathname = usePathname();

  // Hide header on landing page and auth pages
  const hideHeader = pathname === "/" || pathname?.startsWith("/auth");

  if (hideHeader) {
    return null;
  }

  return <Header />;
}
