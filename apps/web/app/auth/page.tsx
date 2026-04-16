"use client";

import { Suspense } from "react";
import { AuthScreen } from "@/components/AuthScreen";

export default function AuthPage() {
  return (
    <Suspense fallback={<div className="p-8 font-bold">Loading auth...</div>}>
      <AuthScreen />
    </Suspense>
  );
}
