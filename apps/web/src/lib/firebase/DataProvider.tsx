"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState
} from "react";
import {
  addDoc,
  collection,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  doc
} from "firebase/firestore";
import { getFirebase, isFirebaseConfigured } from "@/lib/firebase/client";
import { defaultCategories } from "@/lib/firebase/defaults";
import { slugify, today } from "@/lib/formatters/money";
import { useAuth } from "@/lib/auth/AuthProvider";
import type {
  Announcement,
  Category,
  DashboardSummary,
  DocumentItem,
  Member,
  PrayerTime,
  Transaction
} from "@/types/domain";

type NewCategory = Pick<Category, "type" | "name" | "color" | "icon">;
type NewTransaction = Pick<
  Transaction,
  "type" | "categoryId" | "amount" | "date" | "paymentMethod" | "notes"
>;
type NewMember = Pick<Member, "name" | "phone" | "address" | "monthlyAmount">;
type NewDocument = Pick<DocumentItem, "name" | "type" | "amount" | "notes" | "fileUrl">;
type NewAnnouncement = Pick<Announcement, "title" | "body" | "audience">;
type NewPrayerTime = Omit<PrayerTime, "id" | "mosqueId" | "createdAt">;

type DataContextValue = {
  categories: Category[];
  transactions: Transaction[];
  members: Member[];
  documents: DocumentItem[];
  announcements: Announcement[];
  prayerTimes: PrayerTime[];
  summary: DashboardSummary;
  loading: boolean;
  addCategory: (input: NewCategory) => Promise<void>;
  addTransaction: (input: NewTransaction) => Promise<void>;
  addMember: (input: NewMember) => Promise<void>;
  addDocument: (input: NewDocument) => Promise<void>;
  addAnnouncement: (input: NewAnnouncement) => Promise<void>;
  addPrayerTime: (input: NewPrayerTime) => Promise<void>;
};

const DataContext = createContext<DataContextValue | null>(null);

function storageKey(mosqueId: string, collectionName: string) {
  return `mm:${mosqueId}:${collectionName}`;
}

function readLocal<T>(mosqueId: string, collectionName: string): T[] {
  if (typeof window === "undefined") return [];
  const raw = window.localStorage.getItem(storageKey(mosqueId, collectionName));
  return raw ? (JSON.parse(raw) as T[]) : [];
}

function writeLocal<T>(mosqueId: string, collectionName: string, values: T[]) {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(storageKey(mosqueId, collectionName), JSON.stringify(values));
}

function snapToItems<T>(snapshot: { docs: Array<{ id: string; data: () => object }> }) {
  return snapshot.docs.map((item) => ({ id: item.id, ...item.data() }) as T);
}

export function DataProvider({ children }: { children: React.ReactNode }) {
  const { user, mosque } = useAuth();
  const [categories, setCategories] = useState<Category[]>([]);
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [members, setMembers] = useState<Member[]>([]);
  const [documents, setDocuments] = useState<DocumentItem[]>([]);
  const [announcements, setAnnouncements] = useState<Announcement[]>([]);
  const [prayerTimes, setPrayerTimes] = useState<PrayerTime[]>([]);
  const [loading, setLoading] = useState(false);
  const seededDefaultsRef = useRef<string | null>(null);

  useEffect(() => {
    if (!mosque || !user) {
      setCategories([]);
      setTransactions([]);
      setMembers([]);
      setDocuments([]);
      setAnnouncements([]);
      setPrayerTimes([]);
      return;
    }

    const firebase = getFirebase();
    setLoading(true);

    if (!isFirebaseConfigured || !firebase.db) {
      const seeded = readLocal<Category>(mosque.id, "categories");
      if (!seeded.length) {
        const defaults = defaultCategories(mosque.id, user.uid);
        writeLocal(mosque.id, "categories", defaults);
        setCategories(defaults);
      } else {
        setCategories(seeded);
      }
      setTransactions(readLocal<Transaction>(mosque.id, "transactions"));
      setMembers(readLocal<Member>(mosque.id, "members"));
      setDocuments(readLocal<DocumentItem>(mosque.id, "documents"));
      setAnnouncements(readLocal<Announcement>(mosque.id, "announcements"));
      setPrayerTimes(readLocal<PrayerTime>(mosque.id, "prayerTimes"));
      setLoading(false);
      return;
    }

    const base = (name: string) => collection(firebase.db!, "mosques", mosque.id, name);
    const unsubscribers = [
      onSnapshot(query(base("categories"), orderBy("sortOrder", "asc")), (snap) => {
        if (snap.empty && seededDefaultsRef.current !== mosque.id) {
          seededDefaultsRef.current = mosque.id;
          void Promise.all(
            defaultCategories(mosque.id, user.uid).map((category) =>
              setDoc(doc(firebase.db!, "mosques", mosque.id, "categories", category.id), {
                ...category,
                createdAt: serverTimestamp(),
                updatedAt: serverTimestamp()
              })
            )
          ).catch((error) => {
            console.error("Failed to seed default categories", error);
          });
        }
        setCategories(snapToItems<Category>(snap));
      }),
      onSnapshot(query(base("transactions"), orderBy("date", "desc")), (snap) =>
        setTransactions(snapToItems<Transaction>(snap))
      ),
      onSnapshot(query(base("members"), orderBy("createdAt", "desc")), (snap) =>
        setMembers(snapToItems<Member>(snap))
      ),
      onSnapshot(query(base("documents"), orderBy("createdAt", "desc")), (snap) =>
        setDocuments(snapToItems<DocumentItem>(snap))
      ),
      onSnapshot(query(base("announcements"), orderBy("createdAt", "desc")), (snap) =>
        setAnnouncements(snapToItems<Announcement>(snap))
      ),
      onSnapshot(query(base("prayerTimes"), orderBy("createdAt", "desc")), (snap) =>
        setPrayerTimes(snapToItems<PrayerTime>(snap))
      )
    ];
    setLoading(false);

    return () => unsubscribers.forEach((unsubscribe) => unsubscribe());
  }, [mosque, user]);

  const addLocal = useCallback(
    <T extends { id: string }>(
      collectionName: string,
      setter: React.Dispatch<React.SetStateAction<T[]>>,
      item: T
    ) => {
      if (!mosque) return;
      setter((current) => {
        const next = [item, ...current];
        writeLocal(mosque.id, collectionName, next);
        return next;
      });
    },
    [mosque]
  );

  const addCategory = useCallback(
    async (input: NewCategory) => {
      if (!mosque || !user) return;
      const category: Category = {
        id: `${input.type}-${slugify(input.name)}-${Date.now()}`,
        mosqueId: mosque.id,
        type: input.type,
        name: input.name,
        slug: slugify(input.name),
        color: input.color,
        icon: input.icon,
        isDefault: false,
        isActive: true,
        sortOrder: categories.length + 1,
        createdBy: user.uid
      };
      const firebase = getFirebase();
      if (isFirebaseConfigured && firebase.db) {
        await setDoc(doc(firebase.db, "mosques", mosque.id, "categories", category.id), {
          ...category,
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp()
        });
      } else {
        addLocal("categories", setCategories, category);
      }
    },
    [addLocal, categories.length, mosque, user]
  );

  const addTransaction = useCallback(
    async (input: NewTransaction) => {
      if (!mosque || !user) return;
      const category = categories.find((item) => item.id === input.categoryId);
      const transaction: Transaction = {
        id: `txn-${Date.now()}`,
        mosqueId: mosque.id,
        type: input.type,
        categoryId: input.categoryId,
        categoryNameSnapshot: category?.name ?? "Uncategorized",
        amount: Number(input.amount),
        date: input.date || today(),
        paymentMethod: input.paymentMethod,
        notes: input.notes,
        createdBy: user.uid
      };
      const firebase = getFirebase();
      if (isFirebaseConfigured && firebase.db) {
        await addDoc(collection(firebase.db, "mosques", mosque.id, "transactions"), {
          ...transaction,
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp()
        });
      } else {
        addLocal("transactions", setTransactions, transaction);
      }
    },
    [addLocal, categories, mosque, user]
  );

  const addMember = useCallback(
    async (input: NewMember) => {
      if (!mosque) return;
      const member: Member = {
        id: `member-${Date.now()}`,
        mosqueId: mosque.id,
        ...input,
        monthlyAmount: Number(input.monthlyAmount),
        status: "active"
      };
      const firebase = getFirebase();
      if (isFirebaseConfigured && firebase.db) {
        await addDoc(collection(firebase.db, "mosques", mosque.id, "members"), {
          ...member,
          createdAt: serverTimestamp()
        });
      } else {
        addLocal("members", setMembers, member);
      }
    },
    [addLocal, mosque]
  );

  const addDocument = useCallback(
    async (input: NewDocument) => {
      if (!mosque) return;
      const documentItem: DocumentItem = {
        id: `doc-${Date.now()}`,
        mosqueId: mosque.id,
        ...input
      };
      const firebase = getFirebase();
      if (isFirebaseConfigured && firebase.db) {
        await addDoc(collection(firebase.db, "mosques", mosque.id, "documents"), {
          ...documentItem,
          createdAt: serverTimestamp()
        });
      } else {
        addLocal("documents", setDocuments, documentItem);
      }
    },
    [addLocal, mosque]
  );

  const addAnnouncement = useCallback(
    async (input: NewAnnouncement) => {
      if (!mosque) return;
      const announcement: Announcement = {
        id: `ann-${Date.now()}`,
        mosqueId: mosque.id,
        ...input
      };
      const firebase = getFirebase();
      if (isFirebaseConfigured && firebase.db) {
        await addDoc(collection(firebase.db, "mosques", mosque.id, "announcements"), {
          ...announcement,
          createdAt: serverTimestamp()
        });
      } else {
        addLocal("announcements", setAnnouncements, announcement);
      }
    },
    [addLocal, mosque]
  );

  const addPrayerTime = useCallback(
    async (input: NewPrayerTime) => {
      if (!mosque) return;
      const prayerTime: PrayerTime = {
        id: `prayer-${Date.now()}`,
        mosqueId: mosque.id,
        ...input
      };
      const firebase = getFirebase();
      if (isFirebaseConfigured && firebase.db) {
        await addDoc(collection(firebase.db, "mosques", mosque.id, "prayerTimes"), {
          ...prayerTime,
          createdAt: serverTimestamp()
        });
      } else {
        addLocal("prayerTimes", setPrayerTimes, prayerTime);
      }
    },
    [addLocal, mosque]
  );

  const summary = useMemo<DashboardSummary>(() => {
    const income = transactions
      .filter((item) => item.type === "income")
      .reduce((sum, item) => sum + Number(item.amount || 0), 0);
    const expense = transactions
      .filter((item) => item.type === "expense")
      .reduce((sum, item) => sum + Number(item.amount || 0), 0);
    const monthlyExpected = members.reduce(
      (sum, member) => sum + Number(member.monthlyAmount || 0),
      0
    );
    const monthlyCollected = transactions
      .filter((item) => item.categoryNameSnapshot.toLowerCase().includes("monthly"))
      .reduce((sum, item) => sum + Number(item.amount || 0), 0);

    return {
      income,
      expense,
      balance: income - expense,
      members: members.length,
      pendingDues: Math.max(monthlyExpected - monthlyCollected, 0)
    };
  }, [members, transactions]);

  const value = useMemo<DataContextValue>(
    () => ({
      categories,
      transactions,
      members,
      documents,
      announcements,
      prayerTimes,
      summary,
      loading,
      addCategory,
      addTransaction,
      addMember,
      addDocument,
      addAnnouncement,
      addPrayerTime
    }),
    [
      addAnnouncement,
      addCategory,
      addDocument,
      addMember,
      addPrayerTime,
      addTransaction,
      announcements,
      categories,
      documents,
      loading,
      members,
      prayerTimes,
      summary,
      transactions
    ]
  );

  return <DataContext.Provider value={value}>{children}</DataContext.Provider>;
}

export function useMasjidData() {
  const context = useContext(DataContext);
  if (!context) {
    throw new Error("useMasjidData must be used inside DataProvider");
  }
  return context;
}
