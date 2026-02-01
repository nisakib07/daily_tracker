"use client";

// Category icon mappings with colors
export const CATEGORY_ICONS: Record<string, { emoji: string; bg: string; color: string }> = {
  // Expense categories
  Transport: { emoji: "🚗", bg: "bg-blue-100 dark:bg-blue-900/30", color: "text-blue-600" },
  Food: { emoji: "🍔", bg: "bg-orange-100 dark:bg-orange-900/30", color: "text-orange-600" },
  Groceries: { emoji: "🛒", bg: "bg-green-100 dark:bg-green-900/30", color: "text-green-600" },
  Shopping: { emoji: "🛍️", bg: "bg-pink-100 dark:bg-pink-900/30", color: "text-pink-600" },
  Bills: { emoji: "📄", bg: "bg-purple-100 dark:bg-purple-900/30", color: "text-purple-600" },
  Healthcare: { emoji: "💊", bg: "bg-red-100 dark:bg-red-900/30", color: "text-red-600" },
  Entertainment: { emoji: "🎮", bg: "bg-indigo-100 dark:bg-indigo-900/30", color: "text-indigo-600" },
  Education: { emoji: "📚", bg: "bg-cyan-100 dark:bg-cyan-900/30", color: "text-cyan-600" },
  Rent: { emoji: "🏠", bg: "bg-amber-100 dark:bg-amber-900/30", color: "text-amber-600" },
  Personal_Care: { emoji: "💅", bg: "bg-rose-100 dark:bg-rose-900/30", color: "text-rose-600" },
  Family: { emoji: "👨‍👩‍👧", bg: "bg-sky-100 dark:bg-sky-900/30", color: "text-sky-600" },
  Charity: { emoji: "🤲", bg: "bg-teal-100 dark:bg-teal-900/30", color: "text-teal-600" },
  Health: { emoji: "❤️", bg: "bg-red-100 dark:bg-red-900/30", color: "text-red-600" },
  "Other Expense": { emoji: "💸", bg: "bg-slate-100 dark:bg-slate-800", color: "text-slate-600" },
  
  // Income categories
  Salary: { emoji: "💰", bg: "bg-emerald-100 dark:bg-emerald-900/30", color: "text-emerald-600" },
  Freelance: { emoji: "💻", bg: "bg-violet-100 dark:bg-violet-900/30", color: "text-violet-600" },
  Investment: { emoji: "📈", bg: "bg-yellow-100 dark:bg-yellow-900/30", color: "text-yellow-600" },
  Gift: { emoji: "🎁", bg: "bg-pink-100 dark:bg-pink-900/30", color: "text-pink-600" },
  Bonus: { emoji: "🎉", bg: "bg-amber-100 dark:bg-amber-900/30", color: "text-amber-600" },
  "Other Income": { emoji: "💵", bg: "bg-green-100 dark:bg-green-900/30", color: "text-green-600" },
  
  // Transaction types
  income: { emoji: "📥", bg: "bg-emerald-100 dark:bg-emerald-900/30", color: "text-emerald-600" },
  expense: { emoji: "📤", bg: "bg-rose-100 dark:bg-rose-900/30", color: "text-rose-600" },
  transfer: { emoji: "🔄", bg: "bg-blue-100 dark:bg-blue-900/30", color: "text-blue-600" },
  borrow: { emoji: "🤝", bg: "bg-amber-100 dark:bg-amber-900/30", color: "text-amber-600" },
  lend: { emoji: "🤲", bg: "bg-orange-100 dark:bg-orange-900/30", color: "text-orange-600" },
  repay: { emoji: "↩️", bg: "bg-teal-100 dark:bg-teal-900/30", color: "text-teal-600" },
  receive: { emoji: "↪️", bg: "bg-cyan-100 dark:bg-cyan-900/30", color: "text-cyan-600" },
  
  // Default
  default: { emoji: "💳", bg: "bg-slate-100 dark:bg-slate-800", color: "text-slate-600" },
};

export function getCategoryIcon(category: string | undefined | null): { emoji: string; bg: string; color: string } {
  if (!category) return CATEGORY_ICONS.default;
  return CATEGORY_ICONS[category] || CATEGORY_ICONS.default;
}
