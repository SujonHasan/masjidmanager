export type Role = "owner" | "admin" | "cashier" | "imam" | "member" | "guest";

export type TransactionType = "income" | "expense";

export type Mosque = {
  id: string;
  name: string;
  address: string;
  country: string;
  currency: string;
  ownerId: string;
  status: "active" | "trial" | "suspended";
  createdAt?: unknown;
  updatedAt?: unknown;
};

export type AppUser = {
  uid: string;
  email: string | null;
  displayName?: string | null;
  mosqueId: string;
  role: Role;
};

export type Category = {
  id: string;
  mosqueId: string;
  type: TransactionType;
  name: string;
  slug: string;
  color: string;
  icon: string;
  isDefault: boolean;
  isActive: boolean;
  sortOrder: number;
  createdBy: string;
  createdAt?: unknown;
  updatedAt?: unknown;
};

export type Transaction = {
  id: string;
  mosqueId: string;
  type: TransactionType;
  categoryId: string;
  categoryNameSnapshot: string;
  amount: number;
  date: string;
  paymentMethod: "Cash" | "Bank" | "bKash" | "Nagad" | "Other";
  notes: string;
  createdBy: string;
  createdAt?: unknown;
  updatedAt?: unknown;
};

export type Member = {
  id: string;
  mosqueId: string;
  name: string;
  phone: string;
  address: string;
  monthlyAmount: number;
  status: "active" | "inactive";
  createdAt?: unknown;
};

export type DocumentItem = {
  id: string;
  mosqueId: string;
  name: string;
  type: string;
  amount?: number;
  fileUrl?: string;
  notes: string;
  createdAt?: unknown;
};

export type Announcement = {
  id: string;
  mosqueId: string;
  title: string;
  body: string;
  audience: "public" | "members" | "admins";
  createdAt?: unknown;
};

export type PrayerTime = {
  id: string;
  mosqueId: string;
  label: string;
  fajr: string;
  dhuhr: string;
  asr: string;
  maghrib: string;
  isha: string;
  jummah: string;
  createdAt?: unknown;
};

export type DashboardSummary = {
  income: number;
  expense: number;
  balance: number;
  members: number;
  pendingDues: number;
};
