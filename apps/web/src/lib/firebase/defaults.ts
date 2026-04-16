import type { Category, TransactionType } from "@/types/domain";
import { slugify } from "@/lib/formatters/money";

const incomeNames = [
  "Zakat",
  "Sadaqah",
  "Fitra",
  "Jummah Collection",
  "Monthly Collection",
  "Building Fund",
  "Madrasa Fee",
  "Other"
];

const expenseNames = [
  "Imam Salary",
  "Muazzin Salary",
  "Electricity Bill",
  "Water Bill",
  "Cleaning",
  "Maintenance",
  "Construction",
  "Madrasa Expense",
  "Other"
];

const colors = ["#13896f", "#1f9ba5", "#c7a450", "#3d7c62", "#536b48"];

export function defaultCategories(mosqueId: string, uid: string): Category[] {
  const make = (name: string, type: TransactionType, index: number): Category => ({
    id: `${type}-${slugify(name)}`,
    mosqueId,
    type,
    name,
    slug: slugify(name),
    color: colors[index % colors.length],
    icon: type === "income" ? "receipt" : "voucher",
    isDefault: true,
    isActive: true,
    sortOrder: index + 1,
    createdBy: uid
  });

  return [
    ...incomeNames.map((name, index) => make(name, "income", index)),
    ...expenseNames.map((name, index) => make(name, "expense", index))
  ];
}
