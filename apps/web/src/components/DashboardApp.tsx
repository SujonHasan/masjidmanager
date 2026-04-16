"use client";

import Link from "next/link";
import { FormEvent, useState } from "react";
import { useAuth } from "@/lib/auth/AuthProvider";
import { useMasjidData } from "@/lib/firebase/DataProvider";
import { formatMoney, today } from "@/lib/formatters/money";
import type { TransactionType } from "@/types/domain";

type Tab =
  | "overview"
  | "income"
  | "expenses"
  | "categories"
  | "members"
  | "documents"
  | "announcements"
  | "prayer"
  | "reports"
  | "settings";

const tabs: Array<{ id: Tab; label: string }> = [
  { id: "overview", label: "Overview" },
  { id: "income", label: "Income" },
  { id: "expenses", label: "Expenses" },
  { id: "categories", label: "Categories" },
  { id: "members", label: "Members" },
  { id: "documents", label: "Documents" },
  { id: "announcements", label: "Announcements" },
  { id: "prayer", label: "Prayer Times" },
  { id: "reports", label: "Reports" },
  { id: "settings", label: "Settings" }
];

export function DashboardApp() {
  const { user, mosque, pendingEmail, emailVerified, logout, loading: authLoading, demoMode } =
    useAuth();
  const data = useMasjidData();
  const [activeTab, setActiveTab] = useState<Tab>("overview");
  const currency = mosque?.currency ?? "BDT";

  if (authLoading) {
    return <CenteredMessage title="Loading dashboard" body="Preparing your mosque workspace..." />;
  }

  if (!demoMode && pendingEmail && !emailVerified) {
    return (
      <CenteredMessage
        title="Verify email first"
        body={`The admin account ${pendingEmail} must verify email before dashboard data can open.`}
        action={<Link className="btn-primary" href="/auth">Open verification screen</Link>}
      />
    );
  }

  if (!user || !mosque) {
    return (
      <CenteredMessage
        title="Login required"
        body="Create or login to a mosque workspace to use the SaaS dashboard."
        action={<Link className="btn-primary" href="/auth">Go to auth</Link>}
      />
    );
  }

  return (
    <main className="dashboard-grid bg-[var(--background)]">
      <aside className="border-r border-[var(--line)] bg-white p-4 max-[900px]:border-b max-[900px]:border-r-0">
        <div className="mb-6">
          <Link href="/dashboard" className="text-xl font-black">
            Masjid<span className="text-[var(--brand)]">Manager</span>
          </Link>
          <p className="mt-2 text-sm font-semibold text-[var(--muted)]">
            {demoMode ? "Demo workspace" : "Firebase workspace"}
          </p>
        </div>
        <nav className="grid gap-2 max-[900px]:grid-cols-2 sm:max-[900px]:grid-cols-5">
          {tabs.map((tab) => (
            <button
              key={tab.id}
              className={`px-3 py-2 text-left text-sm font-bold ${
                activeTab === tab.id
                  ? "bg-[var(--brand)] text-white"
                  : "bg-[var(--surface-soft)] text-[var(--ink)]"
              }`}
              onClick={() => setActiveTab(tab.id)}
              type="button"
            >
              {tab.label}
            </button>
          ))}
        </nav>
      </aside>

      <section className="min-w-0">
        <header className="sticky top-0 z-10 border-b border-[var(--line)] bg-white/95 px-5 py-4 backdrop-blur">
          <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
            <div>
              <p className="text-sm font-black uppercase text-[var(--brand)]">{user.role}</p>
              <h1 className="text-2xl font-black tracking-normal">{mosque.name}</h1>
              <p className="text-sm text-[var(--muted)]">{mosque.address}</p>
            </div>
            <div className="flex flex-wrap gap-2">
              <button className="btn-secondary" onClick={() => setActiveTab("income")}>
                Add Income
              </button>
              <button className="btn-secondary" onClick={() => setActiveTab("expenses")}>
                Add Expense
              </button>
              <button className="btn-primary" onClick={logout}>
                Logout
              </button>
            </div>
          </div>
        </header>

        <div className="p-5">
          {data.loading ? (
            <CenteredMessage title="Syncing records" body="Listening for realtime Firestore changes." />
          ) : (
            <>
              {activeTab === "overview" && <Overview currency={currency} />}
              {activeTab === "income" && <TransactionModule type="income" currency={currency} />}
              {activeTab === "expenses" && <TransactionModule type="expense" currency={currency} />}
              {activeTab === "categories" && <CategoryModule />}
              {activeTab === "members" && <MemberModule currency={currency} />}
              {activeTab === "documents" && <DocumentModule currency={currency} />}
              {activeTab === "announcements" && <AnnouncementModule />}
              {activeTab === "prayer" && <PrayerModule />}
              {activeTab === "reports" && <ReportsModule currency={currency} />}
              {activeTab === "settings" && <SettingsModule />}
            </>
          )}
        </div>
      </section>
    </main>
  );
}

function CenteredMessage({
  title,
  body,
  action
}: {
  title: string;
  body: string;
  action?: React.ReactNode;
}) {
  return (
    <div className="flex min-h-screen items-center justify-center p-6">
      <div className="card max-w-md p-7 text-center">
        <h1 className="text-2xl font-black">{title}</h1>
        <p className="mt-3 leading-7 text-[var(--muted)]">{body}</p>
        {action && <div className="mt-5 flex justify-center">{action}</div>}
      </div>
    </div>
  );
}

function Overview({ currency }: { currency: string }) {
  const { summary, transactions, categories, announcements, prayerTimes } = useMasjidData();
  const stats = [
    ["Total income", formatMoney(summary.income, currency)],
    ["Total expenses", formatMoney(summary.expense, currency)],
    ["Current balance", formatMoney(summary.balance, currency)],
    ["Pending dues", formatMoney(summary.pendingDues, currency)],
    ["Members", String(summary.members)],
    ["Categories", String(categories.length)]
  ];

  return (
    <div className="grid gap-5">
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
        {stats.map(([label, value]) => (
          <article className="card accent-card p-5 pl-6" key={label}>
            <p className="text-sm font-black uppercase text-[var(--brand)]">{label}</p>
            <h2 className="mt-2 text-3xl font-black tracking-normal">{value}</h2>
          </article>
        ))}
      </div>

      <div className="grid gap-5 lg:grid-cols-[1.2fr_0.8fr]">
        <section className="card p-5">
          <h2 className="text-xl font-black">Recent activity</h2>
          <ListEmpty show={!transactions.length} label="No income or expense recorded yet." />
          <div className="mt-4 grid gap-2">
            {transactions.slice(0, 8).map((transaction) => (
              <div
                className="grid gap-2 border border-[var(--line)] p-3 sm:grid-cols-[1fr_auto_auto]"
                key={transaction.id}
              >
                <div>
                  <p className="font-black">{transaction.categoryNameSnapshot}</p>
                  <p className="text-sm text-[var(--muted)]">{transaction.notes || transaction.date}</p>
                </div>
                <span className="font-bold capitalize">{transaction.type}</span>
                <span className="font-black">{formatMoney(transaction.amount, currency)}</span>
              </div>
            ))}
          </div>
        </section>

        <section className="card p-5">
          <h2 className="text-xl font-black">Community board</h2>
          <div className="mt-4 space-y-4">
            <div>
              <p className="text-sm font-black text-[var(--brand)]">Latest announcement</p>
              <p className="mt-1 font-semibold">
                {announcements[0]?.title ?? "No announcement published yet."}
              </p>
            </div>
            <div>
              <p className="text-sm font-black text-[var(--brand)]">Prayer schedule</p>
              <p className="mt-1 font-semibold">
                {prayerTimes[0]
                  ? `${prayerTimes[0].label}: Fajr ${prayerTimes[0].fajr}, Isha ${prayerTimes[0].isha}`
                  : "No prayer schedule added yet."}
              </p>
            </div>
          </div>
        </section>
      </div>
    </div>
  );
}

function TransactionModule({ type, currency }: { type: TransactionType; currency: string }) {
  const { categories, transactions, addTransaction } = useMasjidData();
  const filteredCategories = categories.filter((category) => category.type === type && category.isActive);
  const filteredTransactions = transactions.filter((transaction) => transaction.type === type);
  const [form, setForm] = useState({
    categoryId: filteredCategories[0]?.id ?? "",
    amount: "",
    date: today(),
    paymentMethod: "Cash" as const,
    notes: ""
  });

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const categoryId = form.categoryId || filteredCategories[0]?.id;
    if (!categoryId) return;
    await addTransaction({
      type,
      categoryId,
      amount: Number(form.amount),
      date: form.date,
      paymentMethod: form.paymentMethod,
      notes: form.notes
    });
    setForm({ ...form, amount: "", notes: "" });
  }

  return (
    <div className="grid gap-5 lg:grid-cols-[380px_1fr]">
      <section className="card p-5">
        <p className="text-sm font-black uppercase text-[var(--brand)]">
          {type === "income" ? "Income management" : "Expense management"}
        </p>
        <h2 className="mt-2 text-2xl font-black">
          {type === "income" ? "Add income" : "Add expense"}
        </h2>
        <form className="mt-5 space-y-4" onSubmit={submit}>
          <div className="field">
            <label>Category</label>
            <select
              className="input"
              required
              value={form.categoryId || filteredCategories[0]?.id || ""}
              onChange={(event) => setForm({ ...form, categoryId: event.target.value })}
            >
              {filteredCategories.map((category) => (
                <option value={category.id} key={category.id}>
                  {category.name}
                </option>
              ))}
            </select>
          </div>
          <div className="field">
            <label>Amount</label>
            <input
              className="input"
              required
              min="1"
              type="number"
              value={form.amount}
              onChange={(event) => setForm({ ...form, amount: event.target.value })}
            />
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="field">
              <label>Date</label>
              <input
                className="input"
                required
                type="date"
                value={form.date}
                onChange={(event) => setForm({ ...form, date: event.target.value })}
              />
            </div>
            <div className="field">
              <label>Payment method</label>
              <select
                className="input"
                value={form.paymentMethod}
                onChange={(event) =>
                  setForm({ ...form, paymentMethod: event.target.value as typeof form.paymentMethod })
                }
              >
                <option>Cash</option>
                <option>Bank</option>
                <option>bKash</option>
                <option>Nagad</option>
                <option>Other</option>
              </select>
            </div>
          </div>
          <div className="field">
            <label>Notes</label>
            <textarea
              className="input min-h-24"
              value={form.notes}
              onChange={(event) => setForm({ ...form, notes: event.target.value })}
            />
          </div>
          <button className="btn-primary w-full">
            {type === "income" ? "Save income" : "Save expense"}
          </button>
        </form>
      </section>

      <section className="card p-5">
        <h2 className="text-xl font-black">
          {type === "income" ? "Income records" : "Expense records"}
        </h2>
        <ListEmpty show={!filteredTransactions.length} label={`No ${type} records yet.`} />
        <div className="mt-4 grid gap-2">
          {filteredTransactions.map((transaction) => (
            <div
              className="grid gap-2 border border-[var(--line)] p-3 sm:grid-cols-[1fr_auto_auto]"
              key={transaction.id}
            >
              <div>
                <p className="font-black">{transaction.categoryNameSnapshot}</p>
                <p className="text-sm text-[var(--muted)]">{transaction.date} · {transaction.paymentMethod}</p>
              </div>
              <span className="text-sm text-[var(--muted)]">{transaction.notes || "No notes"}</span>
              <span className="font-black">{formatMoney(transaction.amount, currency)}</span>
            </div>
          ))}
        </div>
      </section>
    </div>
  );
}

function CategoryModule() {
  const { categories, addCategory } = useMasjidData();
  const [form, setForm] = useState({
    type: "income" as TransactionType,
    name: "",
    color: "#13896f",
    icon: "receipt"
  });

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await addCategory(form);
    setForm({ ...form, name: "" });
  }

  return (
    <div className="grid gap-5 lg:grid-cols-[360px_1fr]">
      <section className="card p-5">
        <h2 className="text-2xl font-black">Add dynamic category</h2>
        <p className="mt-2 leading-7 text-[var(--muted)]">
          Add Zakat, Fitra, construction, utility bill, or any new mosque fund. It will appear in
          web and mobile forms.
        </p>
        <form className="mt-5 space-y-4" onSubmit={submit}>
          <div className="field">
            <label>Type</label>
            <select
              className="input"
              value={form.type}
              onChange={(event) => setForm({ ...form, type: event.target.value as TransactionType })}
            >
              <option value="income">Income</option>
              <option value="expense">Expense</option>
            </select>
          </div>
          <div className="field">
            <label>Name</label>
            <input
              className="input"
              required
              value={form.name}
              onChange={(event) => setForm({ ...form, name: event.target.value })}
              placeholder="Example: Zakat Fund"
            />
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="field">
              <label>Color</label>
              <input
                className="input h-12"
                type="color"
                value={form.color}
                onChange={(event) => setForm({ ...form, color: event.target.value })}
              />
            </div>
            <div className="field">
              <label>Icon label</label>
              <input
                className="input"
                value={form.icon}
                onChange={(event) => setForm({ ...form, icon: event.target.value })}
              />
            </div>
          </div>
          <button className="btn-primary w-full">Add category</button>
        </form>
      </section>
      <section className="card p-5">
        <h2 className="text-xl font-black">Categories</h2>
        <div className="mt-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
          {categories.map((category) => (
            <article className="border border-[var(--line)] p-4" key={category.id}>
              <span
                className="mb-3 block h-2 w-12"
                style={{ backgroundColor: category.color }}
              />
              <p className="font-black">{category.name}</p>
              <p className="text-sm font-semibold capitalize text-[var(--muted)]">
                {category.type} · {category.isDefault ? "Default" : "Custom"}
              </p>
            </article>
          ))}
        </div>
      </section>
    </div>
  );
}

function MemberModule({ currency }: { currency: string }) {
  const { members, addMember } = useMasjidData();
  const [form, setForm] = useState({ name: "", phone: "", address: "", monthlyAmount: "" });

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await addMember({ ...form, monthlyAmount: Number(form.monthlyAmount) });
    setForm({ name: "", phone: "", address: "", monthlyAmount: "" });
  }

  return (
    <SimpleCrudLayout
      title="Members"
      description="Track monthly members, contacts, addresses, and expected monthly collection."
      form={
        <form className="space-y-4" onSubmit={submit}>
          <TextField label="Name" value={form.name} onChange={(value) => setForm({ ...form, name: value })} />
          <TextField label="Phone" value={form.phone} onChange={(value) => setForm({ ...form, phone: value })} />
          <TextField label="Address" value={form.address} onChange={(value) => setForm({ ...form, address: value })} />
          <TextField
            label="Monthly amount"
            type="number"
            value={form.monthlyAmount}
            onChange={(value) => setForm({ ...form, monthlyAmount: value })}
          />
          <button className="btn-primary w-full">Add member</button>
        </form>
      }
      list={
        <>
          <ListEmpty show={!members.length} label="No members added yet." />
          <div className="grid gap-2">
            {members.map((member) => (
              <div className="border border-[var(--line)] p-3" key={member.id}>
                <p className="font-black">{member.name}</p>
                <p className="text-sm text-[var(--muted)]">{member.phone || "No phone"} · {member.address}</p>
                <p className="mt-1 font-bold">{formatMoney(member.monthlyAmount, currency)} monthly</p>
              </div>
            ))}
          </div>
        </>
      }
    />
  );
}

function DocumentModule({ currency }: { currency: string }) {
  const { documents, addDocument } = useMasjidData();
  const [form, setForm] = useState({ name: "", type: "Bill", amount: "", fileUrl: "", notes: "" });

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await addDocument({ ...form, amount: form.amount ? Number(form.amount) : undefined });
    setForm({ name: "", type: "Bill", amount: "", fileUrl: "", notes: "" });
  }

  return (
    <SimpleCrudLayout
      title="Documents"
      description="Store bills, certificates, meeting notes, and file links. Firebase Storage upload can be connected next."
      form={
        <form className="space-y-4" onSubmit={submit}>
          <TextField label="Document name" value={form.name} onChange={(value) => setForm({ ...form, name: value })} />
          <TextField label="Type" value={form.type} onChange={(value) => setForm({ ...form, type: value })} />
          <TextField label="Amount" type="number" value={form.amount} onChange={(value) => setForm({ ...form, amount: value })} />
          <TextField label="File URL" required={false} value={form.fileUrl} onChange={(value) => setForm({ ...form, fileUrl: value })} />
          <TextArea label="Notes" value={form.notes} onChange={(value) => setForm({ ...form, notes: value })} />
          <button className="btn-primary w-full">Save document</button>
        </form>
      }
      list={
        <>
          <ListEmpty show={!documents.length} label="No documents saved yet." />
          <div className="grid gap-2">
            {documents.map((document) => (
              <div className="border border-[var(--line)] p-3" key={document.id}>
                <p className="font-black">{document.name}</p>
                <p className="text-sm text-[var(--muted)]">{document.type} · {document.notes || "No notes"}</p>
                {document.amount ? <p className="mt-1 font-bold">{formatMoney(document.amount, currency)}</p> : null}
              </div>
            ))}
          </div>
        </>
      }
    />
  );
}

function AnnouncementModule() {
  const { announcements, addAnnouncement } = useMasjidData();
  const [form, setForm] = useState({ title: "", body: "", audience: "public" as const });

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await addAnnouncement(form);
    setForm({ title: "", body: "", audience: "public" });
  }

  return (
    <SimpleCrudLayout
      title="Announcements"
      description="Publish mosque updates that the mobile app can show to members and guests."
      form={
        <form className="space-y-4" onSubmit={submit}>
          <TextField label="Title" value={form.title} onChange={(value) => setForm({ ...form, title: value })} />
          <TextArea label="Message" value={form.body} onChange={(value) => setForm({ ...form, body: value })} />
          <div className="field">
            <label>Audience</label>
            <select
              className="input"
              value={form.audience}
              onChange={(event) => setForm({ ...form, audience: event.target.value as typeof form.audience })}
            >
              <option value="public">Public</option>
              <option value="members">Members</option>
              <option value="admins">Admins</option>
            </select>
          </div>
          <button className="btn-primary w-full">Publish</button>
        </form>
      }
      list={
        <>
          <ListEmpty show={!announcements.length} label="No announcements yet." />
          <div className="grid gap-2">
            {announcements.map((announcement) => (
              <div className="border border-[var(--line)] p-3" key={announcement.id}>
                <p className="font-black">{announcement.title}</p>
                <p className="text-sm text-[var(--muted)]">{announcement.body}</p>
              </div>
            ))}
          </div>
        </>
      }
    />
  );
}

function PrayerModule() {
  const { prayerTimes, addPrayerTime } = useMasjidData();
  const [form, setForm] = useState({
    label: "Regular Schedule",
    fajr: "",
    dhuhr: "",
    asr: "",
    maghrib: "",
    isha: "",
    jummah: ""
  });

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await addPrayerTime(form);
  }

  return (
    <SimpleCrudLayout
      title="Prayer times"
      description="Maintain Salah and Jummah schedules for the web dashboard and Flutter app."
      form={
        <form className="space-y-4" onSubmit={submit}>
          <TextField label="Schedule label" value={form.label} onChange={(value) => setForm({ ...form, label: value })} />
          {(["fajr", "dhuhr", "asr", "maghrib", "isha", "jummah"] as const).map((key) => (
            <TextField
              key={key}
              label={key.toUpperCase()}
              type="time"
              value={form[key]}
              onChange={(value) => setForm({ ...form, [key]: value })}
            />
          ))}
          <button className="btn-primary w-full">Save schedule</button>
        </form>
      }
      list={
        <>
          <ListEmpty show={!prayerTimes.length} label="No prayer schedules yet." />
          <div className="grid gap-2">
            {prayerTimes.map((item) => (
              <div className="border border-[var(--line)] p-3" key={item.id}>
                <p className="font-black">{item.label}</p>
                <p className="text-sm text-[var(--muted)]">
                  Fajr {item.fajr} · Dhuhr {item.dhuhr} · Asr {item.asr} · Maghrib {item.maghrib} · Isha {item.isha} · Jummah {item.jummah}
                </p>
              </div>
            ))}
          </div>
        </>
      }
    />
  );
}

function ReportsModule({ currency }: { currency: string }) {
  const { summary, transactions } = useMasjidData();
  const incomeCount = transactions.filter((item) => item.type === "income").length;
  const expenseCount = transactions.filter((item) => item.type === "expense").length;
  return (
    <div className="grid gap-5">
      <section className="card p-5">
        <p className="text-sm font-black uppercase text-[var(--brand)]">Reports</p>
        <h2 className="mt-2 text-2xl font-black">Financial summary</h2>
        <p className="mt-2 leading-7 text-[var(--muted)]">
          This module is ready for PDF and Excel export. Current cards are calculated from live
          Firestore transactions.
        </p>
      </section>
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <ReportCard label="Income total" value={formatMoney(summary.income, currency)} />
        <ReportCard label="Expense total" value={formatMoney(summary.expense, currency)} />
        <ReportCard label="Balance" value={formatMoney(summary.balance, currency)} />
        <ReportCard label="Entries" value={`${incomeCount + expenseCount} records`} />
      </div>
    </div>
  );
}

function SettingsModule() {
  const { mosque, user, demoMode } = useAuth();
  return (
    <section className="card max-w-3xl p-5">
      <p className="text-sm font-black uppercase text-[var(--brand)]">Settings</p>
      <h2 className="mt-2 text-2xl font-black">Mosque workspace</h2>
      <dl className="mt-5 grid gap-3">
        <SettingRow label="Mosque" value={mosque?.name ?? "-"} />
        <SettingRow label="Address" value={mosque?.address ?? "-"} />
        <SettingRow label="Country" value={mosque?.country ?? "-"} />
        <SettingRow label="Currency" value={mosque?.currency ?? "-"} />
        <SettingRow label="Current user" value={user?.email ?? "-"} />
        <SettingRow label="Mode" value={demoMode ? "Demo localStorage fallback" : "Firebase production"} />
      </dl>
    </section>
  );
}

function SimpleCrudLayout({
  title,
  description,
  form,
  list
}: {
  title: string;
  description: string;
  form: React.ReactNode;
  list: React.ReactNode;
}) {
  return (
    <div className="grid gap-5 lg:grid-cols-[360px_1fr]">
      <section className="card p-5">
        <h2 className="text-2xl font-black">{title}</h2>
        <p className="mt-2 leading-7 text-[var(--muted)]">{description}</p>
        <div className="mt-5">{form}</div>
      </section>
      <section className="card p-5">
        <h2 className="mb-4 text-xl font-black">Saved records</h2>
        {list}
      </section>
    </div>
  );
}

function TextField({
  label,
  value,
  onChange,
  type = "text",
  required = true
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  type?: string;
  required?: boolean;
}) {
  return (
    <div className="field">
      <label>{label}</label>
      <input
        className="input"
        required={required}
        type={type}
        value={value}
        onChange={(event) => onChange(event.target.value)}
      />
    </div>
  );
}

function TextArea({
  label,
  value,
  onChange
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
}) {
  return (
    <div className="field">
      <label>{label}</label>
      <textarea className="input min-h-24" required value={value} onChange={(event) => onChange(event.target.value)} />
    </div>
  );
}

function ListEmpty({ show, label }: { show: boolean; label: string }) {
  return show ? (
    <div className="mt-4 border border-dashed border-[var(--line)] bg-[var(--surface-soft)] p-6 text-center font-semibold text-[var(--muted)]">
      {label}
    </div>
  ) : null;
}

function ReportCard({ label, value }: { label: string; value: string }) {
  return (
    <article className="card accent-card p-5 pl-6">
      <p className="text-sm font-black uppercase text-[var(--brand)]">{label}</p>
      <h3 className="mt-2 text-2xl font-black">{value}</h3>
    </article>
  );
}

function SettingRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="grid gap-1 border border-[var(--line)] p-3 sm:grid-cols-[160px_1fr]">
      <dt className="font-black text-[var(--brand)]">{label}</dt>
      <dd className="font-semibold">{value}</dd>
    </div>
  );
}
