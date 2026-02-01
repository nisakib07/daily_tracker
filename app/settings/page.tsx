"use client";

import { useState, useEffect, useRef, useCallback } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useTheme } from "next-themes";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { useAuth } from "@/lib/auth-context";
import { createClient } from "@/lib/supabase/client";
import {
  ArrowLeft,
  Loader2,
  Mail,
  Lock,
  Check,
  AlertCircle,
  Wallet,
  Sun,
  Moon,
  Monitor,
  Download,
  Upload,
  Tag,
  Plus,
  Trash2,
  X,
} from "lucide-react";
import { cn } from "@/lib/utils";

// Local storage keys for custom categories
const CUSTOM_INCOME_CATEGORIES_KEY = "dmt_custom_income_categories";
const CUSTOM_EXPENSE_CATEGORIES_KEY = "dmt_custom_expense_categories";

export default function SettingsPage() {
  const { user, loading: authLoading } = useAuth();
  const router = useRouter();
  const { theme, setTheme } = useTheme();
  const [mounted, setMounted] = useState(false);

  // Email change state
  const [newEmail, setNewEmail] = useState("");
  const [emailLoading, setEmailLoading] = useState(false);
  const [emailSuccess, setEmailSuccess] = useState(false);
  const [emailError, setEmailError] = useState("");

  // Password change state
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [passwordLoading, setPasswordLoading] = useState(false);
  const [passwordSuccess, setPasswordSuccess] = useState(false);
  const [passwordError, setPasswordError] = useState("");

  // Backup/Restore state
  const [exportLoading, setExportLoading] = useState(false);
  const [exportCSVLoading, setExportCSVLoading] = useState(false);
  const [importLoading, setImportLoading] = useState(false);
  const [importSuccess, setImportSuccess] = useState(false);
  const [importError, setImportError] = useState("");
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Custom categories state
  const [incomeCategories, setIncomeCategories] = useState<string[]>([]);
  const [expenseCategories, setExpenseCategories] = useState<string[]>([]);
  const [newIncomeCategory, setNewIncomeCategory] = useState("");
  const [newExpenseCategory, setNewExpenseCategory] = useState("");
  const [categoryToDelete, setCategoryToDelete] = useState<{
    name: string;
    type: "income" | "expense";
  } | null>(null);

  // Handle hydration
  useEffect(() => {
    setMounted(true);
  }, []);

  // Load custom categories from localStorage
  useEffect(() => {
    const savedIncome = localStorage.getItem(CUSTOM_INCOME_CATEGORIES_KEY);
    const savedExpense = localStorage.getItem(CUSTOM_EXPENSE_CATEGORIES_KEY);

    if (savedIncome) {
      try {
        setIncomeCategories(JSON.parse(savedIncome));
      } catch {
        setIncomeCategories([]);
      }
    }

    if (savedExpense) {
      try {
        setExpenseCategories(JSON.parse(savedExpense));
      } catch {
        setExpenseCategories([]);
      }
    }
  }, []);

  // Redirect if not logged in
  useEffect(() => {
    if (!authLoading && !user) {
      router.push("/auth/login");
    }
  }, [authLoading, user, router]);

  const handleEmailChange = async (e: React.FormEvent) => {
    e.preventDefault();
    setEmailError("");
    setEmailSuccess(false);

    if (!newEmail.trim()) {
      setEmailError("Please enter a new email address");
      return;
    }

    if (newEmail === user?.email) {
      setEmailError("New email must be different from current email");
      return;
    }

    setEmailLoading(true);

    try {
      const supabase = createClient();
      const { error } = await supabase.auth.updateUser({ email: newEmail });

      if (error) throw error;

      setEmailSuccess(true);
      setNewEmail("");
    } catch (error) {
      console.error("Error updating email:", error);
      setEmailError(
        error instanceof Error ? error.message : "Failed to update email"
      );
    } finally {
      setEmailLoading(false);
    }
  };

  const handlePasswordChange = async (e: React.FormEvent) => {
    e.preventDefault();
    setPasswordError("");
    setPasswordSuccess(false);

    if (!newPassword || !confirmPassword) {
      setPasswordError("Please fill in all password fields");
      return;
    }

    if (newPassword.length < 6) {
      setPasswordError("Password must be at least 6 characters");
      return;
    }

    if (newPassword !== confirmPassword) {
      setPasswordError("Passwords do not match");
      return;
    }

    setPasswordLoading(true);

    try {
      const supabase = createClient();
      const { error } = await supabase.auth.updateUser({
        password: newPassword,
      });

      if (error) throw error;

      setPasswordSuccess(true);
      setNewPassword("");
      setConfirmPassword("");
    } catch (error) {
      console.error("Error updating password:", error);
      setPasswordError(
        error instanceof Error ? error.message : "Failed to update password"
      );
    } finally {
      setPasswordLoading(false);
    }
  };

  // Export all data as JSON
  const handleExportData = useCallback(async () => {
    setExportLoading(true);

    try {
      const supabase = createClient();

      // Fetch all user data
      const [accountsRes, peopleRes, transactionsRes, budgetsRes] =
        await Promise.all([
          supabase.from("accounts").select("*"),
          supabase.from("people").select("*"),
          supabase.from("transactions").select("*"),
          supabase.from("budgets").select("*"),
        ]);

      const exportData = {
        version: 1,
        exportedAt: new Date().toISOString(),
        data: {
          accounts: accountsRes.data || [],
          people: peopleRes.data || [],
          transactions: transactionsRes.data || [],
          budgets: budgetsRes.data || [],
          customCategories: {
            income: incomeCategories,
            expense: expenseCategories,
          },
        },
      };

      // Download as JSON file
      const blob = new Blob([JSON.stringify(exportData, null, 2)], {
        type: "application/json",
      });
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = `money-master-backup-${new Date().toISOString().split("T")[0]}.json`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
    } catch (error) {
      console.error("Error exporting data:", error);
      alert("Failed to export data. Please try again.");
    } finally {
      setExportLoading(false);
    }
  }, [incomeCategories, expenseCategories]);

  // Export transactions as CSV
  const handleExportCSV = useCallback(async () => {
    setExportCSVLoading(true);

    try {
      const supabase = createClient();

      // Fetch all user data
      const [accountsRes, peopleRes, transactionsRes] = await Promise.all([
        supabase.from("accounts").select("*"),
        supabase.from("people").select("*"),
        supabase.from("transactions").select("*").order("date", { ascending: false }),
      ]);

      const accounts = accountsRes.data || [];
      const people = peopleRes.data || [];
      const transactions = transactionsRes.data || [];

      // Helper to get account name
      const getAccountName = (id: string | null) => {
        if (!id) return "";
        return accounts.find((a: { id: string; name: string }) => a.id === id)?.name || "";
      };

      // Helper to get person name
      const getPersonName = (id: string | null) => {
        if (!id) return "";
        return people.find((p: { id: string; name: string }) => p.id === id)?.name || "";
      };

      // CSV header
      const headers = [
        "Date",
        "Type",
        "Amount",
        "Category",
        "From Account",
        "To Account",
        "Person",
        "Note",
      ];

      // Build CSV rows
      const rows = transactions.map((tx: {
        date: string;
        type: string;
        amount: number;
        category: string | null;
        from_account_id: string | null;
        to_account_id: string | null;
        person_id: string | null;
        note: string | null;
      }) => {
        const date = new Date(tx.date).toLocaleDateString();
        const type = tx.type.charAt(0).toUpperCase() + tx.type.slice(1);
        const amount = tx.amount.toString();
        const category = tx.category || "";
        const fromAccount = getAccountName(tx.from_account_id);
        const toAccount = getAccountName(tx.to_account_id);
        const person = getPersonName(tx.person_id);
        const note = tx.note || "";

        // Escape fields that may contain commas or quotes
        const escapeField = (field: string) => {
          if (field.includes(',') || field.includes('"') || field.includes('\n')) {
            return `"${field.replace(/"/g, '""')}"`;
          }
          return field;
        };

        return [
          escapeField(date),
          escapeField(type),
          escapeField(amount),
          escapeField(category),
          escapeField(fromAccount),
          escapeField(toAccount),
          escapeField(person),
          escapeField(note),
        ].join(",");
      });

      // Combine header and rows
      const csvContent = [headers.join(","), ...rows].join("\n");

      // Download as CSV file
      const blob = new Blob([csvContent], { type: "text/csv;charset=utf-8;" });
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = `money-master-transactions-${new Date().toISOString().split("T")[0]}.csv`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
    } catch (error) {
      console.error("Error exporting CSV:", error);
      alert("Failed to export CSV. Please try again.");
    } finally {
      setExportCSVLoading(false);
    }
  }, []);

  // Import data from JSON
  const handleImportData = useCallback(
    async (e: React.ChangeEvent<HTMLInputElement>) => {
      const file = e.target.files?.[0];
      if (!file) return;

      setImportLoading(true);
      setImportError("");
      setImportSuccess(false);

      try {
        const text = await file.text();
        const importData = JSON.parse(text);

        // Validate structure
        if (
          !importData.data ||
          !Array.isArray(importData.data.accounts) ||
          !Array.isArray(importData.data.transactions)
        ) {
          throw new Error("Invalid backup file format");
        }

        const supabase = createClient();

        // Import custom categories first (local storage)
        if (importData.data.customCategories) {
          if (Array.isArray(importData.data.customCategories.income)) {
            localStorage.setItem(
              CUSTOM_INCOME_CATEGORIES_KEY,
              JSON.stringify(importData.data.customCategories.income)
            );
            setIncomeCategories(importData.data.customCategories.income);
          }
          if (Array.isArray(importData.data.customCategories.expense)) {
            localStorage.setItem(
              CUSTOM_EXPENSE_CATEGORIES_KEY,
              JSON.stringify(importData.data.customCategories.expense)
            );
            setExpenseCategories(importData.data.customCategories.expense);
          }
        }

        // Note: For safety, we won't auto-import database data
        // Users should be aware this will replace their data
        const confirmed = window.confirm(
          `This will import:\n- ${importData.data.accounts.length} accounts\n- ${importData.data.people.length} people\n- ${importData.data.transactions.length} transactions\n- ${importData.data.budgets?.length || 0} budgets\n\nExisting data with the same IDs will be updated. Continue?`
        );

        if (!confirmed) {
          setImportLoading(false);
          return;
        }

        // Import accounts
        if (importData.data.accounts.length > 0) {
          for (const account of importData.data.accounts) {
            await supabase.from("accounts").upsert(account);
          }
        }

        // Import people
        if (importData.data.people.length > 0) {
          for (const person of importData.data.people) {
            await supabase.from("people").upsert(person);
          }
        }

        // Import transactions
        if (importData.data.transactions.length > 0) {
          for (const tx of importData.data.transactions) {
            await supabase.from("transactions").upsert(tx);
          }
        }

        // Import budgets
        if (importData.data.budgets?.length > 0) {
          for (const budget of importData.data.budgets) {
            await supabase.from("budgets").upsert(budget);
          }
        }

        setImportSuccess(true);
      } catch (error) {
        console.error("Error importing data:", error);
        setImportError(
          error instanceof Error ? error.message : "Failed to import data"
        );
      } finally {
        setImportLoading(false);
        // Reset file input
        if (fileInputRef.current) {
          fileInputRef.current.value = "";
        }
      }
    },
    []
  );

  // Add custom category
  const handleAddCategory = (type: "income" | "expense") => {
    const name =
      type === "income"
        ? newIncomeCategory.trim()
        : newExpenseCategory.trim();

    if (!name) return;

    const categories =
      type === "income" ? incomeCategories : expenseCategories;

    if (categories.includes(name)) {
      return; // Already exists
    }

    const updated = [...categories, name];
    const storageKey =
      type === "income"
        ? CUSTOM_INCOME_CATEGORIES_KEY
        : CUSTOM_EXPENSE_CATEGORIES_KEY;

    localStorage.setItem(storageKey, JSON.stringify(updated));

    if (type === "income") {
      setIncomeCategories(updated);
      setNewIncomeCategory("");
    } else {
      setExpenseCategories(updated);
      setNewExpenseCategory("");
    }
  };

  // Delete custom category
  const handleDeleteCategory = () => {
    if (!categoryToDelete) return;

    const { name, type } = categoryToDelete;
    const categories =
      type === "income" ? incomeCategories : expenseCategories;

    const updated = categories.filter((c) => c !== name);
    const storageKey =
      type === "income"
        ? CUSTOM_INCOME_CATEGORIES_KEY
        : CUSTOM_EXPENSE_CATEGORIES_KEY;

    localStorage.setItem(storageKey, JSON.stringify(updated));

    if (type === "income") {
      setIncomeCategories(updated);
    } else {
      setExpenseCategories(updated);
    }

    setCategoryToDelete(null);
  };

  if (authLoading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-background">
        <div className="flex flex-col items-center gap-3">
          <Loader2 className="h-8 w-8 animate-spin text-primary" />
          <p className="text-sm text-muted-foreground">Loading...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-50 via-white to-slate-50 dark:from-slate-950 dark:via-slate-900 dark:to-slate-950">
      {/* Header */}
      <header className="sticky top-0 z-20 border-b bg-white/90 dark:bg-slate-900/90 backdrop-blur-md">
        <div className="mx-auto max-w-2xl px-3 sm:px-4 py-3 sm:py-4">
          <div className="flex items-center gap-3">
            <Link href="/">
              <Button
                variant="outline"
                size="icon"
                className="h-9 w-9 bg-transparent"
              >
                <ArrowLeft className="h-4 w-4" />
              </Button>
            </Link>
            <div className="flex items-center gap-2">
              <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-gradient-to-br from-emerald-500 to-teal-600 text-white shadow-lg shadow-emerald-500/20">
                <Wallet className="h-4 w-4" />
              </div>
              <div>
                <h1 className="text-base sm:text-lg font-bold text-foreground">
                  Settings
                </h1>
                <p className="text-[10px] sm:text-xs text-muted-foreground">
                  Manage your account
                </p>
              </div>
            </div>
          </div>
        </div>
      </header>

      <main className="mx-auto max-w-2xl px-3 sm:px-4 py-4 sm:py-6 space-y-4 sm:space-y-6 pb-20">
        {/* Account Info */}
        <Card>
          <CardHeader className="pb-3">
            <CardTitle className="text-base sm:text-lg">
              Account Information
            </CardTitle>
            <CardDescription className="text-xs sm:text-sm">
              Your current account details
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-2">
              <p className="text-xs text-muted-foreground">Email</p>
              <p className="text-sm font-medium">{user?.email}</p>
            </div>
          </CardContent>
        </Card>

        {/* Theme */}
        <Card>
          <CardHeader className="pb-3">
            <CardTitle className="flex items-center gap-2 text-base sm:text-lg">
              {mounted && theme === "dark" ? (
                <Moon className="h-4 w-4 text-emerald-600" />
              ) : (
                <Sun className="h-4 w-4 text-emerald-600" />
              )}
              Appearance
            </CardTitle>
            <CardDescription className="text-xs sm:text-sm">
              Customize how Money Master looks
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-2">
              <Label htmlFor="theme" className="text-sm">
                Theme
              </Label>
              {mounted && (
                <Select value={theme} onValueChange={setTheme}>
                  <SelectTrigger id="theme" className="w-full sm:w-[200px] h-11">
                    <SelectValue placeholder="Select theme" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="light">
                      <div className="flex items-center gap-2">
                        <Sun className="h-4 w-4" />
                        Light
                      </div>
                    </SelectItem>
                    <SelectItem value="dark">
                      <div className="flex items-center gap-2">
                        <Moon className="h-4 w-4" />
                        Dark
                      </div>
                    </SelectItem>
                    <SelectItem value="system">
                      <div className="flex items-center gap-2">
                        <Monitor className="h-4 w-4" />
                        System
                      </div>
                    </SelectItem>
                  </SelectContent>
                </Select>
              )}
            </div>
          </CardContent>
        </Card>

        {/* Change Email */}
        <Card>
          <CardHeader className="pb-3">
            <CardTitle className="flex items-center gap-2 text-base sm:text-lg">
              <Mail className="h-4 w-4 text-emerald-600" />
              Change Email
            </CardTitle>
            <CardDescription className="text-xs sm:text-sm">
              Update your email address. A confirmation link will be sent to
              your new email.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleEmailChange} className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="newEmail" className="text-sm">
                  New Email Address
                </Label>
                <Input
                  id="newEmail"
                  type="email"
                  value={newEmail}
                  onChange={(e) => setNewEmail(e.target.value)}
                  placeholder="Enter new email"
                  className="h-11"
                />
              </div>

              {emailError && (
                <div className="flex items-center gap-2 text-sm text-rose-600 bg-rose-50 dark:bg-rose-950/50 p-3 rounded-lg">
                  <AlertCircle className="h-4 w-4 shrink-0" />
                  {emailError}
                </div>
              )}

              {emailSuccess && (
                <div className="flex items-center gap-2 text-sm text-emerald-600 bg-emerald-50 dark:bg-emerald-950/50 p-3 rounded-lg">
                  <Check className="h-4 w-4 shrink-0" />
                  Confirmation email sent. Please check your new email to
                  confirm the change.
                </div>
              )}

              <Button
                type="submit"
                disabled={emailLoading || !newEmail}
                className="w-full sm:w-auto bg-emerald-600 hover:bg-emerald-700"
              >
                {emailLoading ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    Updating...
                  </>
                ) : (
                  "Update Email"
                )}
              </Button>
            </form>
          </CardContent>
        </Card>

        {/* Change Password */}
        <Card>
          <CardHeader className="pb-3">
            <CardTitle className="flex items-center gap-2 text-base sm:text-lg">
              <Lock className="h-4 w-4 text-emerald-600" />
              Change Password
            </CardTitle>
            <CardDescription className="text-xs sm:text-sm">
              Update your password. Must be at least 6 characters.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handlePasswordChange} className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="newPassword" className="text-sm">
                  New Password
                </Label>
                <Input
                  id="newPassword"
                  type="password"
                  value={newPassword}
                  onChange={(e) => setNewPassword(e.target.value)}
                  placeholder="Enter new password"
                  className="h-11"
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="confirmPassword" className="text-sm">
                  Confirm New Password
                </Label>
                <Input
                  id="confirmPassword"
                  type="password"
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  placeholder="Confirm new password"
                  className="h-11"
                />
              </div>

              {passwordError && (
                <div className="flex items-center gap-2 text-sm text-rose-600 bg-rose-50 dark:bg-rose-950/50 p-3 rounded-lg">
                  <AlertCircle className="h-4 w-4 shrink-0" />
                  {passwordError}
                </div>
              )}

              {passwordSuccess && (
                <div className="flex items-center gap-2 text-sm text-emerald-600 bg-emerald-50 dark:bg-emerald-950/50 p-3 rounded-lg">
                  <Check className="h-4 w-4 shrink-0" />
                  Password updated successfully!
                </div>
              )}

              <Button
                type="submit"
                disabled={passwordLoading || !newPassword || !confirmPassword}
                className="w-full sm:w-auto bg-emerald-600 hover:bg-emerald-700"
              >
                {passwordLoading ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    Updating...
                  </>
                ) : (
                  "Update Password"
                )}
              </Button>
            </form>
          </CardContent>
        </Card>

        {/* Custom Categories */}
        <Card>
          <CardHeader className="pb-3">
            <CardTitle className="flex items-center gap-2 text-base sm:text-lg">
              <Tag className="h-4 w-4 text-emerald-600" />
              Custom Categories
            </CardTitle>
            <CardDescription className="text-xs sm:text-sm">
              Manage your custom income and expense categories
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-6">
            {/* Income Categories */}
            <div className="space-y-3">
              <Label className="text-sm font-medium text-emerald-600">
                Income Categories
              </Label>
              <div className="flex gap-2">
                <Input
                  value={newIncomeCategory}
                  onChange={(e) => setNewIncomeCategory(e.target.value)}
                  placeholder="Add new income category"
                  className="h-10"
                  onKeyDown={(e) => {
                    if (e.key === "Enter") {
                      e.preventDefault();
                      handleAddCategory("income");
                    }
                  }}
                />
                <Button
                  type="button"
                  size="icon"
                  onClick={() => handleAddCategory("income")}
                  disabled={!newIncomeCategory.trim()}
                  className="h-10 w-10 bg-emerald-600 hover:bg-emerald-700"
                >
                  <Plus className="h-4 w-4" />
                </Button>
              </div>
              {incomeCategories.length > 0 ? (
                <div className="flex flex-wrap gap-2">
                  {incomeCategories.map((cat) => (
                    <div
                      key={cat}
                      className="flex items-center gap-1 px-3 py-1.5 bg-emerald-50 dark:bg-emerald-950/50 text-emerald-700 dark:text-emerald-400 rounded-full text-sm"
                    >
                      <span>{cat}</span>
                      <button
                        type="button"
                        onClick={() =>
                          setCategoryToDelete({ name: cat, type: "income" })
                        }
                        className="ml-1 hover:bg-emerald-200 dark:hover:bg-emerald-800 rounded-full p-0.5"
                      >
                        <X className="h-3 w-3" />
                      </button>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="text-xs text-muted-foreground">
                  No custom income categories yet
                </p>
              )}
            </div>

            {/* Expense Categories */}
            <div className="space-y-3">
              <Label className="text-sm font-medium text-rose-600">
                Expense Categories
              </Label>
              <div className="flex gap-2">
                <Input
                  value={newExpenseCategory}
                  onChange={(e) => setNewExpenseCategory(e.target.value)}
                  placeholder="Add new expense category"
                  className="h-10"
                  onKeyDown={(e) => {
                    if (e.key === "Enter") {
                      e.preventDefault();
                      handleAddCategory("expense");
                    }
                  }}
                />
                <Button
                  type="button"
                  size="icon"
                  onClick={() => handleAddCategory("expense")}
                  disabled={!newExpenseCategory.trim()}
                  className="h-10 w-10 bg-rose-600 hover:bg-rose-700"
                >
                  <Plus className="h-4 w-4" />
                </Button>
              </div>
              {expenseCategories.length > 0 ? (
                <div className="flex flex-wrap gap-2">
                  {expenseCategories.map((cat) => (
                    <div
                      key={cat}
                      className="flex items-center gap-1 px-3 py-1.5 bg-rose-50 dark:bg-rose-950/50 text-rose-700 dark:text-rose-400 rounded-full text-sm"
                    >
                      <span>{cat}</span>
                      <button
                        type="button"
                        onClick={() =>
                          setCategoryToDelete({ name: cat, type: "expense" })
                        }
                        className="ml-1 hover:bg-rose-200 dark:hover:bg-rose-800 rounded-full p-0.5"
                      >
                        <X className="h-3 w-3" />
                      </button>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="text-xs text-muted-foreground">
                  No custom expense categories yet
                </p>
              )}
            </div>
          </CardContent>
        </Card>

        {/* Data Backup & Restore */}
        <Card>
          <CardHeader className="pb-3">
            <CardTitle className="flex items-center gap-2 text-base sm:text-lg">
              <Download className="h-4 w-4 text-emerald-600" />
              Data Backup & Restore
            </CardTitle>
            <CardDescription className="text-xs sm:text-sm">
              Export your data for backup or import from a previous backup
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            {/* Export Options */}
            <div className="space-y-3">
              <Label className="text-sm font-medium">Export Options</Label>
              <div className="flex flex-col sm:flex-row gap-2">
                <Button
                  onClick={handleExportData}
                  disabled={exportLoading}
                  variant="outline"
                  className="flex-1 h-11 bg-transparent"
                >
                  {exportLoading ? (
                    <>
                      <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                      Exporting...
                    </>
                  ) : (
                    <>
                      <Download className="mr-2 h-4 w-4" />
                      Export JSON (Full Backup)
                    </>
                  )}
                </Button>

                <Button
                  onClick={handleExportCSV}
                  disabled={exportCSVLoading}
                  variant="outline"
                  className="flex-1 h-11 bg-transparent"
                >
                  {exportCSVLoading ? (
                    <>
                      <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                      Exporting...
                    </>
                  ) : (
                    <>
                      <Download className="mr-2 h-4 w-4" />
                      Export CSV (Spreadsheet)
                    </>
                  )}
                </Button>
              </div>
              <p className="text-xs text-muted-foreground">
                JSON includes all data for backup/restore. CSV is for viewing transactions in Excel or Google Sheets.
              </p>
            </div>

            {/* Import Option */}
            <div className="space-y-3 pt-2 border-t">
              <Label className="text-sm font-medium">Import Data</Label>
              <Button
                onClick={() => fileInputRef.current?.click()}
                disabled={importLoading}
                variant="outline"
                className="w-full sm:w-auto h-11 bg-transparent"
              >
                {importLoading ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    Importing...
                  </>
                ) : (
                  <>
                    <Upload className="mr-2 h-4 w-4" />
                    Import from JSON Backup
                  </>
                )}
              </Button>

              <input
                ref={fileInputRef}
                type="file"
                accept=".json"
                onChange={handleImportData}
                className="hidden"
              />
            </div>

            {importError && (
              <div className="flex items-center gap-2 text-sm text-rose-600 bg-rose-50 dark:bg-rose-950/50 p-3 rounded-lg">
                <AlertCircle className="h-4 w-4 shrink-0" />
                {importError}
              </div>
            )}

            {importSuccess && (
              <div className="flex items-center gap-2 text-sm text-emerald-600 bg-emerald-50 dark:bg-emerald-950/50 p-3 rounded-lg">
                <Check className="h-4 w-4 shrink-0" />
                Data imported successfully! Refresh the page to see changes.
              </div>
            )}


          </CardContent>
        </Card>
      </main>

      {/* Delete Category Confirmation */}
      <AlertDialog
        open={!!categoryToDelete}
        onOpenChange={(open) => !open && setCategoryToDelete(null)}
      >
        <AlertDialogContent className="mx-4 sm:mx-auto max-w-md">
          <AlertDialogHeader>
            <AlertDialogTitle>Delete Category</AlertDialogTitle>
            <AlertDialogDescription>
              Are you sure you want to delete &quot;{categoryToDelete?.name}
              &quot;? This won&apos;t affect existing transactions using this
              category.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter className="flex-col sm:flex-row gap-2">
            <AlertDialogCancel className="bg-transparent">
              Cancel
            </AlertDialogCancel>
            <AlertDialogAction
              onClick={handleDeleteCategory}
              className="bg-rose-600 hover:bg-rose-700"
            >
              Delete
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
