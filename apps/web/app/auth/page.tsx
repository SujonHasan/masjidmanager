"use client";

import { Suspense } from "react";
import { AuthScreen } from "@/components/AuthScreen";
import { AuthRedirect } from "@/components/AuthRedirect";

export default function AuthPage() {
  return (
    <Suspense fallback={<div className="p-8 font-bold">Loading auth...</div>}>
      <AuthRedirect>
        <AuthScreen />
      </AuthRedirect>
    </Suspense>
  );
}
