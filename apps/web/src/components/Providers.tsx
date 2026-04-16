"use client";

import { AuthProvider } from "@/lib/auth/AuthProvider";
import { DataProvider } from "@/lib/firebase/DataProvider";

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <AuthProvider>
      <DataProvider>{children}</DataProvider>
    </AuthProvider>
  );
}
