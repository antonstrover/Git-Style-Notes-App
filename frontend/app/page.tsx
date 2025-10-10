"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { LandingPage } from "@/components/landing/landing-page";
import { LoadingState } from "@/components/feedback/loading-state";

export default function HomePage() {
  const router = useRouter();
  const [isAuthenticated, setIsAuthenticated] = useState<boolean | null>(null);

  useEffect(() => {
    // Check authentication status
    const checkAuth = async () => {
      try {
        const response = await fetch("/api/auth/me");

        if (response.ok) {
          // User is authenticated, redirect to dashboard
          router.push("/dashboard");
        } else {
          // User is not authenticated, show landing page
          setIsAuthenticated(false);
        }
      } catch (error) {
        // On error, assume not authenticated and show landing page
        setIsAuthenticated(false);
      }
    };

    checkAuth();
  }, [router]);

  // Show loading state while checking authentication
  if (isAuthenticated === null) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <LoadingState />
      </div>
    );
  }

  // Show landing page for unauthenticated users
  return <LandingPage />;
}
