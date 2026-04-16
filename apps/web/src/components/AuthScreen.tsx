"use client";

import { useSearchParams, useRouter } from "next/navigation";
import Link from "next/link";
import { FormEvent, useMemo, useState } from "react";
import { useAuth } from "@/lib/auth/AuthProvider";

export function AuthScreen() {
  const params = useSearchParams();
  const router = useRouter();
  const {
    login,
    register,
    logout,
    resendVerificationEmail,
    checkEmailVerification,
    pendingEmail,
    emailVerified,
    demoMode,
    firebaseReady
  } = useAuth();
  const initialMode = params.get("mode") === "register" ? "register" : "login";
  const [mode, setMode] = useState<"login" | "register">(initialMode);
  const [verificationPending, setVerificationPending] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [form, setForm] = useState({
    mosqueName: "",
    email: "",
    password: "",
    address: "",
    country: "Bangladesh",
    currency: "BDT"
  });

  function authErrorMessage(err: unknown, fallback: string) {
    if (!(err instanceof Error)) return fallback;

    if (
      err.message.includes("auth/configuration-not-found") ||
      err.message.includes("CONFIGURATION_NOT_FOUND")
    ) {
      return "Firebase Authentication is not initialized yet. Open Firebase Console > Authentication, click Get started, then enable Email/Password.";
    }

    if (err.message.includes("auth/operation-not-allowed")) {
      return "Email/Password sign-in is disabled. Enable it in Firebase Console > Authentication > Sign-in method.";
    }

    if (
      err.message.includes("auth/invalid-credential") ||
      err.message.includes("auth/wrong-password")
    ) {
      return "Email or password is not correct.";
    }

    if (err.message.includes("auth/email-already-in-use")) {
      return "This email already has an account. Try login instead.";
    }

    return err.message;
  }

  const title = useMemo(
    () => (mode === "register" ? "Create mosque workspace" : "Login to dashboard"),
    [mode]
  );

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setLoading(true);
    setError("");
    setNotice("");
    try {
      if (mode === "register") {
        await register(form);
        if (demoMode) {
          router.push("/dashboard");
          return;
        }
        setVerificationPending(true);
        setNotice("Verification email sent. Open your inbox and confirm the address.");
      } else {
        const verified = await login(form.email, form.password);
        if (verified) {
          router.push("/dashboard");
          return;
        }
        setVerificationPending(true);
        setNotice("Please verify your email before entering the admin dashboard.");
      }
    } catch (err) {
      setError(authErrorMessage(err, "Something went wrong"));
    } finally {
      setLoading(false);
    }
  }

  async function resendEmail() {
    setLoading(true);
    setError("");
    setNotice("");
    try {
      await resendVerificationEmail();
      setNotice("Verification email sent again. Please check inbox and spam folder.");
    } catch (err) {
      setError(authErrorMessage(err, "Could not send verification email"));
    } finally {
      setLoading(false);
    }
  }

  async function checkVerification() {
    setLoading(true);
    setError("");
    setNotice("");
    try {
      const verified = await checkEmailVerification();
      if (verified) {
        router.push("/dashboard");
      } else {
        setNotice("Still not verified. Please click the verification link from your email.");
      }
    } catch (err) {
      setError(authErrorMessage(err, "Could not check verification"));
    } finally {
      setLoading(false);
    }
  }

  async function resetAuth() {
    await logout();
    setVerificationPending(false);
    setNotice("");
    setError("");
  }

  const showVerification = !demoMode && (verificationPending || Boolean(pendingEmail && !emailVerified));

  return (
    <main className="grid min-h-screen bg-[var(--background)] lg:grid-cols-[0.9fr_1.1fr]">
      <section className="hero-photo hidden min-h-screen p-10 text-white lg:flex lg:flex-col lg:justify-between">
          <Link href="/" className="text-xl font-black">
            Masjid<span className="text-[#d7bd72]">Manager</span>
          </Link>
        <div className="max-w-xl">
          <p className="mb-4 text-sm font-black uppercase text-[#d7bd72]">SaaS control center</p>
          <h1 className="text-5xl font-black leading-tight tracking-normal">
            Verified admin access for trusted mosque records.
          </h1>
          <p className="mt-5 leading-8 text-white/82">
            Every admin account must verify email before managing donations, expenses, members,
            announcements, and prayer schedules.
          </p>
          <div className="mt-8 grid gap-3">
            {[
              "Email verification before dashboard access",
              "Firestore tenant rules for each mosque",
              "Realtime sync for web and Flutter app"
            ].map((item) => (
              <div className="border border-white/18 bg-white/10 p-3 font-bold" key={item}>
                {item}
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="flex items-center justify-center px-5 py-12">
        <div className="card w-full max-w-xl p-7">
          {showVerification ? (
            <div>
              <p className="text-sm font-black uppercase text-[var(--brand)]">
                Email verification required
              </p>
              <h1 className="mt-2 text-3xl font-black tracking-normal">Check your inbox</h1>
              <p className="mt-3 leading-7 text-[var(--muted)]">
                We sent a verification link to{" "}
                <strong className="text-[var(--ink)]">{pendingEmail ?? form.email}</strong>. Verify
                the email, then come back here to enter the admin dashboard.
              </p>
              <div className="mt-5 border border-[var(--line)] bg-[var(--surface-soft)] p-4">
                <p className="font-bold text-[var(--ink)]">What happens next?</p>
                <p className="mt-1 text-sm leading-6 text-[var(--muted)]">
                  Your mosque workspace and default categories are prepared, but Firestore rules
                  block operational data until Firebase marks this email as verified.
                </p>
              </div>
              {notice && (
                <div className="mt-4 border border-emerald-200 bg-emerald-50 p-3 text-sm font-semibold text-[var(--brand)]">
                  {notice}
                </div>
              )}
              {error && (
                <div className="mt-4 border border-red-200 bg-red-50 p-3 text-sm font-semibold text-[var(--danger)]">
                  {error}
                </div>
              )}
              <div className="mt-6 grid gap-3 sm:grid-cols-2">
                <button className="btn-primary" disabled={loading} onClick={checkVerification}>
                  {loading ? "Checking..." : "I verified, check again"}
                </button>
                <button className="btn-secondary" disabled={loading} onClick={resendEmail}>
                  Resend email
                </button>
              </div>
              <button className="mt-3 w-full text-sm font-bold text-[var(--muted)]" onClick={resetAuth}>
                Logout or change email
              </button>
            </div>
          ) : (
            <>
          <div className="mb-7">
            <p className="text-sm font-black uppercase text-[var(--brand)]">
              {demoMode ? "Demo mode enabled" : "Firebase connected"}
            </p>
            <h1 className="mt-2 text-3xl font-black tracking-normal">{title}</h1>
            <p className="mt-2 leading-7 text-[var(--muted)]">
              {mode === "register"
                ? "Create the first owner account for a mosque tenant."
                : "Use your mosque owner or admin account."}
            </p>
            {!firebaseReady && (
              <div className="mt-4 border border-amber-200 bg-amber-50 p-3 text-sm font-semibold text-amber-800">
                Firebase env vars are missing, so this is running in local demo mode. Add
                NEXT_PUBLIC_FIREBASE_* values to enable final email verification.
              </div>
            )}
          </div>

          <div className="mb-6 grid grid-cols-2 gap-2">
            <button
              className={mode === "login" ? "btn-primary" : "btn-secondary"}
              onClick={() => setMode("login")}
              type="button"
            >
              Login
            </button>
            <button
              className={mode === "register" ? "btn-primary" : "btn-secondary"}
              onClick={() => setMode("register")}
              type="button"
            >
              Register
            </button>
          </div>

          <form className="space-y-4" onSubmit={submit}>
            {mode === "register" && (
              <>
                <div className="field">
                  <label>Mosque name</label>
                  <input
                    className="input"
                    required
                    value={form.mosqueName}
                    onChange={(event) => setForm({ ...form, mosqueName: event.target.value })}
                    placeholder="Baitul Aman Masjid"
                  />
                </div>
                <div className="field">
                  <label>Address</label>
                  <input
                    className="input"
                    required
                    value={form.address}
                    onChange={(event) => setForm({ ...form, address: event.target.value })}
                    placeholder="Dhaka, Bangladesh"
                  />
                </div>
                <div className="grid gap-4 sm:grid-cols-2">
                  <div className="field">
                    <label>Country</label>
                    <input
                      className="input"
                      value={form.country}
                      onChange={(event) => setForm({ ...form, country: event.target.value })}
                    />
                  </div>
                  <div className="field">
                    <label>Currency</label>
                    <select
                      className="input"
                      value={form.currency}
                      onChange={(event) => setForm({ ...form, currency: event.target.value })}
                    >
                      <option value="BDT">BDT</option>
                      <option value="INR">INR</option>
                      <option value="USD">USD</option>
                      <option value="GBP">GBP</option>
                    </select>
                  </div>
                </div>
              </>
            )}

            <div className="field">
              <label>Email</label>
              <input
                className="input"
                required
                type="email"
                value={form.email}
                onChange={(event) => setForm({ ...form, email: event.target.value })}
                placeholder="admin@example.com"
              />
            </div>
            <div className="field">
              <label>Password</label>
              <input
                className="input"
                required
                minLength={6}
                type="password"
                value={form.password}
                onChange={(event) => setForm({ ...form, password: event.target.value })}
                placeholder="Minimum 6 characters"
              />
            </div>

            {error && (
              <div className="border border-red-200 bg-red-50 p-3 text-sm font-semibold text-[var(--danger)]">
                {error}
              </div>
            )}
            {notice && (
              <div className="border border-emerald-200 bg-emerald-50 p-3 text-sm font-semibold text-[var(--brand)]">
                {notice}
              </div>
            )}

            <button className="btn-primary w-full" disabled={loading}>
              {loading ? "Please wait..." : mode === "register" ? "Create workspace" : "Login"}
            </button>
          </form>
            </>
          )}
        </div>
      </section>
    </main>
  );
}
