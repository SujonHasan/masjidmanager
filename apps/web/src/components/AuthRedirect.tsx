"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth/AuthProvider";

export function AuthRedirect({ children }: { children: React.ReactNode }) {
  const { user, mosque, pendingEmail, emailVerified, loading, demoMode } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (loading) return;
    if (user && mosque && (demoMode || emailVerified)) {
      router.replace("/dashboard");
    }
  }, [demoMode, emailVerified, loading, mosque, router, user]);

  if (loading) {
    return <CenteredRouteMessage title="Loading" body="Checking your login session..." />;
  }

  if (user && mosque && (demoMode || emailVerified)) {
    return <CenteredRouteMessage title="Opening dashboard" body="You are already logged in." />;
  }

  if (!demoMode && pendingEmail && !emailVerified) {
    return <>{children}</>;
  }

  return <>{children}</>;
}

export function CenteredRouteMessage({ title, body }: { title: string; body: string }) {
  return (
    <div className="flex min-h-screen items-center justify-center bg-[var(--background)] p-6">
      <div className="card max-w-md p-7 text-center">
        <h1 className="text-2xl font-black">{title}</h1>
        <p className="mt-3 leading-7 text-[var(--muted)]">{body}</p>
      </div>
    </div>
  );
}
