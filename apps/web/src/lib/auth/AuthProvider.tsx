"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState
} from "react";
import {
  createUserWithEmailAndPassword,
  onAuthStateChanged,
  sendEmailVerification,
  signInWithEmailAndPassword,
  signOut
} from "firebase/auth";
import {
  collection,
  doc,
  getDoc,
  serverTimestamp,
  writeBatch
} from "firebase/firestore";
import { getFirebase, isFirebaseConfigured } from "@/lib/firebase/client";
import type { AppUser, Mosque } from "@/types/domain";

type RegisterInput = {
  mosqueName: string;
  email: string;
  password: string;
  address: string;
  country: string;
  currency: string;
};

type AuthContextValue = {
  user: AppUser | null;
  mosque: Mosque | null;
  pendingEmail: string | null;
  emailVerified: boolean;
  loading: boolean;
  demoMode: boolean;
  firebaseReady: boolean;
  register: (input: RegisterInput) => Promise<void>;
  login: (email: string, password: string) => Promise<boolean>;
  resendVerificationEmail: () => Promise<void>;
  checkEmailVerification: () => Promise<boolean>;
  logout: () => Promise<void>;
};

const AuthContext = createContext<AuthContextValue | null>(null);
const demoUserKey = "mm:demo:user";
const demoMosqueKey = "mm:demo:mosque";

function readDemoSession() {
  if (typeof window === "undefined") return { user: null, mosque: null };
  const user = window.localStorage.getItem(demoUserKey);
  const mosque = window.localStorage.getItem(demoMosqueKey);
  return {
    user: user ? (JSON.parse(user) as AppUser) : null,
    mosque: mosque ? (JSON.parse(mosque) as Mosque) : null
  };
}

function writeDemoSession(user: AppUser | null, mosque: Mosque | null) {
  if (typeof window === "undefined") return;
  if (user && mosque) {
    window.localStorage.setItem(demoUserKey, JSON.stringify(user));
    window.localStorage.setItem(demoMosqueKey, JSON.stringify(mosque));
  } else {
    window.localStorage.removeItem(demoUserKey);
    window.localStorage.removeItem(demoMosqueKey);
  }
}

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<AppUser | null>(null);
  const [mosque, setMosque] = useState<Mosque | null>(null);
  const [pendingEmail, setPendingEmail] = useState<string | null>(null);
  const [emailVerified, setEmailVerified] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const firebase = getFirebase();

    if (!isFirebaseConfigured || !firebase.auth || !firebase.db) {
      const session = readDemoSession();
      setUser(session.user);
      setMosque(session.mosque);
      setPendingEmail(session.user?.email ?? null);
      setEmailVerified(Boolean(session.user));
      setLoading(false);
      return;
    }

    return onAuthStateChanged(firebase.auth, async (firebaseUser) => {
      setLoading(true);
      try {
        if (!firebaseUser || !firebase.db) {
          setUser(null);
          setMosque(null);
          setPendingEmail(null);
          setEmailVerified(false);
          return;
        }

        setPendingEmail(firebaseUser.email);
        setEmailVerified(firebaseUser.emailVerified);

        const profileSnap = await getDoc(doc(firebase.db, "users", firebaseUser.uid));
        if (!profileSnap.exists()) {
          setUser(null);
          setMosque(null);
          return;
        }

        const profile = profileSnap.data() as AppUser;
        const mosqueSnap = await getDoc(doc(firebase.db, "mosques", profile.mosqueId));
        const mosqueRecord = mosqueSnap.exists()
          ? ({ id: mosqueSnap.id, ...mosqueSnap.data() } as Mosque)
          : null;

        setUser(firebaseUser.emailVerified ? profile : null);
        setMosque(firebaseUser.emailVerified ? mosqueRecord : null);
      } finally {
        setLoading(false);
      }
    });
  }, []);

  const register = useCallback(async (input: RegisterInput) => {
    const firebase = getFirebase();

    if (!isFirebaseConfigured || !firebase.auth || !firebase.db) {
      const mosqueId = `demo-mosque`;
      const demoUser: AppUser = {
        uid: "demo-owner",
        email: input.email,
        displayName: input.mosqueName,
        mosqueId,
        role: "owner"
      };
      const demoMosque: Mosque = {
        id: mosqueId,
        name: input.mosqueName,
        address: input.address,
        country: input.country,
        currency: input.currency,
        ownerId: demoUser.uid,
        status: "trial"
      };
      writeDemoSession(demoUser, demoMosque);
      setUser(demoUser);
      setMosque(demoMosque);
      setPendingEmail(demoUser.email);
      setEmailVerified(true);
      return;
    }

    const credential = await createUserWithEmailAndPassword(
      firebase.auth,
      input.email,
      input.password
    );
    await sendEmailVerification(credential.user);
    const uid = credential.user.uid;
    const mosqueRef = doc(collection(firebase.db, "mosques"));
    const appUser: AppUser = {
      uid,
      email: credential.user.email,
      displayName: input.mosqueName,
      mosqueId: mosqueRef.id,
      role: "owner"
    };
    const mosqueRecord: Mosque = {
      id: mosqueRef.id,
      name: input.mosqueName,
      address: input.address,
      country: input.country,
      currency: input.currency,
      ownerId: uid,
      status: "trial"
    };

    const batch = writeBatch(firebase.db);
    batch.set(mosqueRef, {
      ...mosqueRecord,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp()
    });
    batch.set(doc(firebase.db, "users", uid), {
      ...appUser,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp()
    });
    batch.set(doc(firebase.db, "mosques", mosqueRef.id, "users", uid), {
      ...appUser,
      active: true,
      createdAt: serverTimestamp()
    });
    await batch.commit();
    setPendingEmail(credential.user.email);
    setEmailVerified(false);
    setUser(null);
    setMosque(null);
  }, []);

  const login = useCallback(async (email: string, password: string) => {
    const firebase = getFirebase();

    if (!isFirebaseConfigured || !firebase.auth || !firebase.db) {
      const session = readDemoSession();
      if (session.user && session.mosque) {
        setUser(session.user);
        setMosque(session.mosque);
        setPendingEmail(session.user.email);
        setEmailVerified(true);
        return true;
      }
      await register({
        mosqueName: "Demo Central Masjid",
        email,
        password,
        address: "Dhaka, Bangladesh",
        country: "Bangladesh",
        currency: "BDT"
      });
      return true;
    }

    const credential = await signInWithEmailAndPassword(firebase.auth, email, password);
    await credential.user.reload();
    const verified = credential.user.emailVerified;
    if (verified) {
      await credential.user.getIdToken(true);
    }
    setPendingEmail(credential.user.email);
    setEmailVerified(verified);
    if (!verified) {
      setUser(null);
      setMosque(null);
    }
    return verified;
  }, [register]);

  const resendVerificationEmail = useCallback(async () => {
    const firebase = getFirebase();
    if (!isFirebaseConfigured || !firebase.auth?.currentUser) return;
    await sendEmailVerification(firebase.auth.currentUser);
    setPendingEmail(firebase.auth.currentUser.email);
    setEmailVerified(firebase.auth.currentUser.emailVerified);
  }, []);

  const checkEmailVerification = useCallback(async () => {
    const firebase = getFirebase();
    if (!isFirebaseConfigured) {
      setEmailVerified(Boolean(user));
      return Boolean(user);
    }
    if (!firebase.auth?.currentUser || !firebase.db) return false;

    await firebase.auth.currentUser.reload();
    const verified = firebase.auth.currentUser.emailVerified;
    if (verified) {
      await firebase.auth.currentUser.getIdToken(true);
    }
    setPendingEmail(firebase.auth.currentUser.email);
    setEmailVerified(verified);

    if (!verified) {
      setUser(null);
      setMosque(null);
      return false;
    }

    const profileSnap = await getDoc(doc(firebase.db, "users", firebase.auth.currentUser.uid));
    if (!profileSnap.exists()) return false;

    const profile = profileSnap.data() as AppUser;
    const mosqueSnap = await getDoc(doc(firebase.db, "mosques", profile.mosqueId));
    if (!mosqueSnap.exists()) return false;

    setUser(profile);
    setMosque({ id: mosqueSnap.id, ...mosqueSnap.data() } as Mosque);
    return true;
  }, [user]);

  const logout = useCallback(async () => {
    const firebase = getFirebase();
    if (isFirebaseConfigured && firebase.auth) {
      await signOut(firebase.auth);
    }
    writeDemoSession(null, null);
    setUser(null);
    setMosque(null);
    setPendingEmail(null);
    setEmailVerified(false);
  }, []);

  const value = useMemo<AuthContextValue>(
    () => ({
      user,
      mosque,
      pendingEmail,
      emailVerified,
      loading,
      demoMode: !isFirebaseConfigured,
      firebaseReady: isFirebaseConfigured,
      register,
      login,
      resendVerificationEmail,
      checkEmailVerification,
      logout
    }),
    [
      checkEmailVerification,
      emailVerified,
      loading,
      login,
      logout,
      mosque,
      pendingEmail,
      register,
      resendVerificationEmail,
      user
    ]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error("useAuth must be used inside AuthProvider");
  }
  return context;
}
