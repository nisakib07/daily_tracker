export interface Account {
  id: string;
  name: string;
  type: string;
  balance?: number; // Calculated dynamically, not stored
  created_at: string;
}

export interface Person {
  id: string;
  name: string;
  phone?: string;
  note?: string;
  created_at: string;
}

export interface Transaction {
  id: string;
  type: "income" | "expense" | "transfer" | "lend" | "borrow" | "repay" | "receive";
  amount: number;
  from_account_id: string | null;
  to_account_id: string | null;
  person_id: string | null;
  category: string | null;
  note: string | null;
  date: string;
  created_at: string;
}

// Ledger entry for loan tracking
export interface LedgerEntry {
  personId: string;
  personName: string;
  youOwe: number;      // Money you borrowed from them
  theyOwe: number;     // Money they borrowed from you (loans given)
  netBalance: number;  // Positive = they owe you, Negative = you owe them
}

export type TransactionType = "in" | "out" | "transfer";

// Default categories for regular income
export const DEFAULT_CATEGORIES_IN = [
  "Salary",
  "Freelance",
  "Gift",
  "Investment Return",
  "Business",
  "Other Income",
] as const;

// Default categories for regular expense
export const DEFAULT_CATEGORIES_OUT = [
  "Food",
  "Transport",
  "Shopping",
  "Bills",
  "Entertainment",
  "Health",
  "Education",
  "Rent",
  "Other Expense",
] as const;

// For backward compatibility
export const CATEGORIES_IN = DEFAULT_CATEGORIES_IN;
export const CATEGORIES_OUT = DEFAULT_CATEGORIES_OUT;

// Custom category interface
export interface CustomCategory {
  id: string;
  name: string;
  type: "income" | "expense";
  created_at: string;
}

// Loan/Borrow related transaction types
export const LOAN_TYPES = {
  LEND: "lend",           // You give loan to someone (money out)
  BORROW: "borrow",       // You borrow from someone (money in)
  REPAY: "repay",         // You repay borrowed money (money out)
  RECEIVE: "receive",     // You receive loan repayment (money in)
} as const;
