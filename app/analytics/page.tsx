"use client";

import { useEffect, useState, useCallback, useMemo } from "react";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  CardDescription,
} from "@/components/ui/card";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { createClient } from "@/lib/supabase/client";
import { ThemeToggle } from "@/components/theme-toggle";
import { AnalyticsSkeleton } from "@/components/skeleton-loader";
import { AnimatedCounter } from "@/components/animated-counter";
import type { Account, Transaction, Person } from "@/lib/types";
import {
  ArrowLeft,
  TrendingUp,
  TrendingDown,
  Wallet,
  Download,
  PieChart as PieChartIcon,
  BarChart3,
  ArrowUpRight,
  ArrowDownLeft,
  ChevronLeft,
  ChevronRight,
} from "lucide-react";
import {
  format,
  startOfMonth,
  endOfMonth,
  subMonths,
  addMonths,
  isSameMonth,
} from "date-fns";
import { cn } from "@/lib/utils";
import {
  PieChart,
  Pie,
  Cell,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Legend,
  LineChart,
  Line,
} from "recharts";

// Colors for charts
const EXPENSE_COLORS = [
  "#ef4444",
  "#f97316",
  "#f59e0b",
  "#eab308",
  "#84cc16",
  "#22c55e",
  "#14b8a6",
  "#06b6d4",
  "#0ea5e9",
  "#3b82f6",
  "#6366f1",
  "#8b5cf6",
];

const INCOME_COLORS = [
  "#10b981",
  "#059669",
  "#047857",
  "#065f46",
  "#0d9488",
  "#0891b2",
  "#0284c7",
  "#2563eb",
];

const MONTHS = [
  { value: "0", label: "January" },
  { value: "1", label: "February" },
  { value: "2", label: "March" },
  { value: "3", label: "April" },
  { value: "4", label: "May" },
  { value: "5", label: "June" },
  { value: "6", label: "July" },
  { value: "7", label: "August" },
  { value: "8", label: "September" },
  { value: "9", label: "October" },
  { value: "10", label: "November" },
  { value: "11", label: "December" },
];

function exportTransactionsToCSV(params: {
  transactions: Transaction[];
  accounts: Account[];
  people: Person[];
  selectedMonth: Date;
}) {
  const { transactions, accounts, people, selectedMonth } = params;

  const accountMap: Record<string, string> = {};
  for (const a of accounts) accountMap[a.id] = a.name;

  const personMap: Record<string, string> = {};
  for (const p of people) personMap[p.id] = p.name;

  const headers = [
    "Date",
    "Type",
    "Amount",
    "From Account",
    "To Account",
    "Person",
    "Category",
    "Note",
  ];

  const rows = transactions.map((tx) => {
    const fromId = (tx as any).from_account_id as string | null | undefined;
    const toId = (tx as any).to_account_id as string | null | undefined;
    const personId = (tx as any).person_id as string | null | undefined;

    return [
      tx.date ? format(new Date(tx.date), "yyyy-MM-dd") : "",
      tx.type || "",
      tx.amount ?? "",
      fromId ? accountMap[fromId] || fromId : "",
      toId ? accountMap[toId] || toId : "",
      personId ? personMap[personId] || personId : "",
      tx.category || "",
      tx.note || "",
    ];
  });

  const csv = [headers, ...rows]
    .map((row) =>
      row
        .map((value) => `"${String(value ?? "").replace(/"/g, '""')}"`)
        .join(","),
    )
    .join("\n");

  const filename = `transactions_${format(selectedMonth, "yyyy-MM")}.csv`;
  const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
  const url = URL.createObjectURL(blob);

  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);

  URL.revokeObjectURL(url);
}

export default function AnalyticsPage() {
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [people, setPeople] = useState<Person[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedMonth, setSelectedMonth] = useState<Date>(new Date());
  const [exporting, setExporting] = useState(false);

  // ✅ NEW: Analytics mode (Cashflow includes loans; Profit excludes loans)
  const [includeLoans, setIncludeLoans] = useState(true);

  const incomeTypes = useMemo(() => {
    return includeLoans ? ["income", "borrow", "receive"] : ["income"];
  }, [includeLoans]);

  const expenseTypes = useMemo(() => {
    return includeLoans ? ["expense", "lend", "repay"] : ["expense"];
  }, [includeLoans]);

  const fetchData = useCallback(async () => {
    const supabase = createClient();

    const [transactionsRes, accountsRes, peopleRes] = await Promise.all([
      supabase
        .from("transactions")
        .select("*")
        .order("date", { ascending: false })
        .limit(5000),
      supabase.from("accounts").select("*"),
      supabase.from("people").select("*"),
    ]);

    if (transactionsRes.data) setTransactions(transactionsRes.data);
    if (accountsRes.data) setAccounts(accountsRes.data);
    if (peopleRes.data) setPeople(peopleRes.data);

    setLoading(false);
  }, []);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  // ✅ Month selector (dropdown) helpers
  const availableYears = useMemo(() => {
    const years = new Set<number>();
    years.add(new Date().getFullYear());
    for (const tx of transactions) {
      const d = new Date(tx.date);
      if (!isNaN(d.getTime())) years.add(d.getFullYear());
    }
    return Array.from(years).sort((a, b) => b - a);
  }, [transactions]);

  const selectedMonthValue = String(selectedMonth.getMonth());
  const selectedYearValue = String(selectedMonth.getFullYear());

  const setMonthYear = (monthIndex: number, year: number) => {
    const next = new Date(year, monthIndex, 1);
    setSelectedMonth(next);
  };

  const goToPreviousMonth = () => setSelectedMonth(subMonths(selectedMonth, 1));
  const goToNextMonth = () => setSelectedMonth(addMonths(selectedMonth, 1));
  const isCurrentMonth = isSameMonth(selectedMonth, new Date());

  // Filter transactions for selected month
  const monthTransactions = useMemo(() => {
    const start = startOfMonth(selectedMonth);
    const end = endOfMonth(selectedMonth);
    return transactions.filter((tx) => {
      const txDate = new Date(tx.date);
      return txDate >= start && txDate <= end;
    });
  }, [transactions, selectedMonth]);

  // ✅ Monthly summary respects mode
  const monthlySummary = useMemo(() => {
    return monthTransactions.reduce(
      (acc, tx) => {
        const amount = Number(tx.amount);
        if (incomeTypes.includes(tx.type)) acc.income += amount;
        else if (expenseTypes.includes(tx.type)) acc.expense += amount;
        return acc;
      },
      { income: 0, expense: 0 },
    );
  }, [monthTransactions, incomeTypes, expenseTypes]);

  // ✅ Expense by category respects mode
  const expenseByCategory = useMemo(() => {
    const categoryMap = new Map<string, number>();
    monthTransactions
      .filter((tx) => expenseTypes.includes(tx.type))
      .forEach((tx) => {
        const category = tx.category || "Uncategorized";
        categoryMap.set(
          category,
          (categoryMap.get(category) || 0) + Number(tx.amount),
        );
      });

    return Array.from(categoryMap.entries())
      .map(([name, value]) => ({ name, value }))
      .sort((a, b) => b.value - a.value);
  }, [monthTransactions, expenseTypes]);

  // ✅ Income by category respects mode
  const incomeByCategory = useMemo(() => {
    const categoryMap = new Map<string, number>();
    monthTransactions
      .filter((tx) => incomeTypes.includes(tx.type))
      .forEach((tx) => {
        const category = tx.category || "Uncategorized";
        categoryMap.set(
          category,
          (categoryMap.get(category) || 0) + Number(tx.amount),
        );
      });

    return Array.from(categoryMap.entries())
      .map(([name, value]) => ({ name, value }))
      .sort((a, b) => b.value - a.value);
  }, [monthTransactions, incomeTypes]);

  // ✅ Performance improvement: bucket transactions by month once
  const monthBuckets = useMemo(() => {
    // key => { income, expense }
    const map = new Map<string, { income: number; expense: number }>();

    for (const tx of transactions) {
      const d = new Date(tx.date);
      if (isNaN(d.getTime())) continue;
      const key = format(d, "yyyy-MM");

      const bucket = map.get(key) || { income: 0, expense: 0 };
      const amt = Number(tx.amount);

      if (incomeTypes.includes(tx.type)) bucket.income += amt;
      else if (expenseTypes.includes(tx.type)) bucket.expense += amt;

      map.set(key, bucket);
    }

    return map;
  }, [transactions, incomeTypes, expenseTypes]);

  // ✅ Last 6 months trend respects mode + uses buckets
  const monthlyTrend = useMemo(() => {
    const months = [];
    for (let i = 5; i >= 0; i--) {
      const month = subMonths(new Date(), i);
      const key = format(month, "yyyy-MM");
      const bucket = monthBuckets.get(key) || { income: 0, expense: 0 };
      const income = bucket.income;
      const expense = bucket.expense;

      months.push({
        month: format(month, "MMM"),
        income,
        expense,
        net: income - expense,
      });
    }
    return months;
  }, [monthBuckets]);

  // ✅ Daily spending respects mode
  const dailySpending = useMemo(() => {
    const daysInMonth = endOfMonth(selectedMonth).getDate();
    const dailyMap = new Map<number, { income: number; expense: number }>();

    for (let i = 1; i <= daysInMonth; i++)
      dailyMap.set(i, { income: 0, expense: 0 });

    monthTransactions.forEach((tx) => {
      const day = new Date(tx.date).getDate();
      const current = dailyMap.get(day) || { income: 0, expense: 0 };
      const amount = Number(tx.amount);

      if (incomeTypes.includes(tx.type)) current.income += amount;
      else if (expenseTypes.includes(tx.type)) current.expense += amount;

      dailyMap.set(day, current);
    });

    return Array.from(dailyMap.entries()).map(([day, data]) => ({
      day: day.toString(),
      ...data,
    }));
  }, [monthTransactions, selectedMonth, incomeTypes, expenseTypes]);

  // ✅ FIXED: Total Balance matches Dashboard (account-based, from/to)
  const totalBalance = useMemo(() => {
    const map = new Map<string, number>();
    for (const acc of accounts) map.set(acc.id, 0);

    for (const tx of transactions) {
      const amt = Number(tx.amount);

      const toId = (tx as any).to_account_id as string | null | undefined;
      const fromId = (tx as any).from_account_id as string | null | undefined;

      if (toId) map.set(toId, (map.get(toId) || 0) + amt);
      if (fromId) map.set(fromId, (map.get(fromId) || 0) - amt);
    }

    return Array.from(map.values()).reduce((s, v) => s + v, 0);
  }, [transactions, accounts]);

  const exportCSV = async () => {
    setExporting(true);
    try {
      exportTransactionsToCSV({
        transactions: monthTransactions,
        accounts,
        people,
        selectedMonth,
      });
    } catch (error) {
      console.error("[v0] Error exporting CSV:", error);
    } finally {
      setExporting(false);
    }
  };

  if (loading) {
    return <AnalyticsSkeleton />;
  }

  const net = monthlySummary.income - monthlySummary.expense;

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-50 via-white to-slate-50 dark:from-slate-950 dark:via-slate-900 dark:to-slate-950">
      {/* Header */}
      <header className="sticky top-0 z-20 border-b bg-white/90 dark:bg-slate-900/90 backdrop-blur-md glass">
        <div className="mx-auto max-w-4xl px-3 sm:px-4 py-3 sm:py-4">
          <div className="flex items-center justify-between gap-2">
            <div className="flex items-center gap-2 sm:gap-3">
              <Link href="/">
                <Button
                  variant="ghost"
                  size="icon"
                  className="h-9 w-9 sm:h-10 sm:w-10"
                >
                  <ArrowLeft className="h-4 w-4 sm:h-5 sm:w-5" />
                </Button>
              </Link>
              <div className="flex h-9 w-9 sm:h-10 sm:w-10 items-center justify-center rounded-xl bg-gradient-to-br from-indigo-500 to-purple-600 text-white shadow-lg shadow-indigo-500/20">
                <BarChart3 className="h-4 w-4 sm:h-5 sm:w-5" />
              </div>
              <div>
                <h1 className="text-base sm:text-lg font-bold text-foreground">
                  Analytics
                </h1>
                <p className="text-[10px] sm:text-xs text-muted-foreground hidden sm:block">
                  Track your spending
                </p>
              </div>
            </div>

            <div className="flex items-center gap-2">
              <ThemeToggle />
              <Button
                onClick={exportCSV}
                disabled={exporting || monthTransactions.length === 0}
                className="h-9 sm:h-10 text-xs sm:text-sm bg-gradient-to-r from-indigo-500 to-purple-600 hover:from-indigo-600 hover:to-purple-700"
                title={
                  monthTransactions.length === 0
                    ? "No transactions to export for this month"
                    : "Export CSV"
                }
              >
                {exporting ? (
                  <Loader2 className="mr-1.5 h-3.5 w-3.5 sm:mr-2 sm:h-4 sm:w-4 animate-spin" />
                ) : (
                  <Download className="mr-1.5 h-3.5 w-3.5 sm:mr-2 sm:h-4 sm:w-4" />
                )}
                <span className="hidden sm:inline">Export</span> CSV
              </Button>
            </div>
          </div>
        </div>
      </header>

      <main className="mx-auto max-w-4xl px-3 sm:px-4 py-4 sm:py-6 space-y-4 sm:space-y-6">
        {/* Mode toggle + Month selector (month/year dropdown) */}
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          {/* Mode */}
          <div className="flex items-center gap-2">
            <Button
              size="sm"
              variant={includeLoans ? "default" : "outline"}
              onClick={() => setIncludeLoans(true)}
              className={cn(
                "h-9 text-xs sm:text-sm",
                includeLoans ? "bg-slate-900 dark:bg-slate-100 dark:text-slate-900" : "bg-transparent",
              )}
              title="Include borrow/lend/repay/receive (cash movement)"
            >
              Cashflow
            </Button>
            <Button
              size="sm"
              variant={!includeLoans ? "default" : "outline"}
              onClick={() => setIncludeLoans(false)}
              className={cn(
                "h-9 text-xs sm:text-sm",
                !includeLoans ? "bg-slate-900 dark:bg-slate-100 dark:text-slate-900" : "bg-transparent",
              )}
              title="Only income/expense (exclude loans)"
            >
              Profit
            </Button>
          </div>

          {/* Month navigation + dropdowns */}
          <div className="flex items-center justify-between gap-2">
            <Button
              variant="outline"
              size="icon"
              onClick={goToPreviousMonth}
              className="h-9 w-9 sm:h-10 sm:w-10 bg-transparent"
              aria-label="Previous month"
            >
              <ChevronLeft className="h-4 w-4" />
            </Button>

            <div className="flex items-center gap-2">
              <Select
                value={selectedMonthValue}
                onValueChange={(v) =>
                  setMonthYear(Number(v), selectedMonth.getFullYear())
                }
              >
                <SelectTrigger className="h-9 sm:h-10 min-w-[150px] bg-transparent">
                  <SelectValue placeholder="Month" />
                </SelectTrigger>
                <SelectContent>
                  {MONTHS.map((m) => (
                    <SelectItem key={m.value} value={m.value}>
                      {m.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>

              <Select
                value={selectedYearValue}
                onValueChange={(v) =>
                  setMonthYear(selectedMonth.getMonth(), Number(v))
                }
              >
                <SelectTrigger className="h-9 sm:h-10 w-[110px] bg-transparent">
                  <SelectValue placeholder="Year" />
                </SelectTrigger>
                <SelectContent>
                  {availableYears.map((y) => (
                    <SelectItem key={y} value={String(y)}>
                      {y}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <Button
              variant="outline"
              size="icon"
              onClick={goToNextMonth}
              className="h-9 w-9 sm:h-10 sm:w-10 bg-transparent"
              disabled={isCurrentMonth}
              aria-label="Next month"
              title={
                isCurrentMonth
                  ? "You're viewing the current month"
                  : "Next month"
              }
            >
              <ChevronRight className="h-4 w-4" />
            </Button>
          </div>
        </div>

        {/* Summary Cards */}
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 sm:gap-3">
          <Card className="bg-gradient-to-br from-emerald-50 to-emerald-100/50 border-emerald-200 dark:from-emerald-950/50 dark:to-emerald-900/30 dark:border-emerald-800/50 animate-fade-in-up">
            <CardContent className="p-3 sm:p-4">
              <div className="flex items-center gap-2 mb-1">
                <ArrowDownLeft className="h-4 w-4 text-emerald-600 dark:text-emerald-400" />
                <span className="text-[10px] sm:text-xs font-medium text-emerald-600 dark:text-emerald-400 uppercase tracking-wide">
                  Income
                </span>
              </div>
              <p className="text-lg sm:text-2xl font-bold text-emerald-700 dark:text-emerald-300">
                <AnimatedCounter value={monthlySummary.income} prefix="৳" duration={800} />
              </p>
              <p className="mt-1 text-[10px] sm:text-xs text-emerald-700/70 dark:text-emerald-400/70">
                {includeLoans ? "Incl. loans" : "Income only"}
              </p>
            </CardContent>
          </Card>

          <Card className="bg-gradient-to-br from-rose-50 to-rose-100/50 border-rose-200 dark:from-rose-950/50 dark:to-rose-900/30 dark:border-rose-800/50 animate-fade-in-up animation-delay-100">
            <CardContent className="p-3 sm:p-4">
              <div className="flex items-center gap-2 mb-1">
                <ArrowUpRight className="h-4 w-4 text-rose-600 dark:text-rose-400" />
                <span className="text-[10px] sm:text-xs font-medium text-rose-600 dark:text-rose-400 uppercase tracking-wide">
                  Expenses
                </span>
              </div>
              <p className="text-lg sm:text-2xl font-bold text-rose-700 dark:text-rose-300">
                <AnimatedCounter value={monthlySummary.expense} prefix="৳" duration={800} />
              </p>
              <p className="mt-1 text-[10px] sm:text-xs text-rose-700/70 dark:text-rose-400/70">
                {includeLoans ? "Incl. loans" : "Expense only"}
              </p>
            </CardContent>
          </Card>

          <Card
            className={cn(
              "bg-gradient-to-br border animate-fade-in-up animation-delay-200",
              net >= 0
                ? "from-blue-50 to-blue-100/50 border-blue-200 dark:from-blue-950/50 dark:to-blue-900/30 dark:border-blue-800/50"
                : "from-orange-50 to-orange-100/50 border-orange-200 dark:from-orange-950/50 dark:to-orange-900/30 dark:border-orange-800/50",
            )}
          >
            <CardContent className="p-3 sm:p-4">
              <div className="flex items-center gap-2 mb-1">
                {net >= 0 ? (
                  <TrendingUp className="h-4 w-4 text-blue-600 dark:text-blue-400" />
                ) : (
                  <TrendingDown className="h-4 w-4 text-orange-600 dark:text-orange-400" />
                )}
                <span
                  className={cn(
                    "text-[10px] sm:text-xs font-medium uppercase tracking-wide",
                    net >= 0 ? "text-blue-600 dark:text-blue-400" : "text-orange-600 dark:text-orange-400",
                  )}
                >
                  Net
                </span>
              </div>
              <p
                className={cn(
                  "text-lg sm:text-2xl font-bold",
                  net >= 0 ? "text-blue-700 dark:text-blue-300" : "text-orange-700 dark:text-orange-300",
                )}
              >
                <AnimatedCounter value={net} prefix="৳" duration={800} />
              </p>
              <p className="mt-1 text-[10px] sm:text-xs text-muted-foreground">
                {format(selectedMonth, "MMMM yyyy")}
              </p>
            </CardContent>
          </Card>

          <Card className="bg-gradient-to-br from-slate-50 to-slate-100/50 dark:from-slate-800 dark:to-slate-900/50 border-slate-200 dark:border-slate-700 animate-fade-in-up animation-delay-300">
            <CardContent className="p-3 sm:p-4">
              <div className="flex items-center gap-2 mb-1">
                <Wallet className="h-4 w-4 text-slate-600 dark:text-slate-400" />
                <span className="text-[10px] sm:text-xs font-medium text-slate-600 dark:text-slate-400 uppercase tracking-wide">
                  Total
                </span>
              </div>
              <p
                className={cn(
                  "text-lg sm:text-2xl font-bold",
                  totalBalance >= 0 ? "text-emerald-700 dark:text-emerald-400" : "text-rose-700 dark:text-rose-400",
                )}
              >
                <AnimatedCounter value={totalBalance} prefix="৳" duration={800} />
              </p>
              <p className="mt-1 text-[10px] sm:text-xs text-muted-foreground">
                Matches Dashboard
              </p>
            </CardContent>
          </Card>
        </div>

        {/* Charts Row */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
          {/* Expense Pie Chart */}
          <Card className="animate-fade-in-up animation-delay-400">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm sm:text-base flex items-center gap-2">
                <PieChartIcon className="h-4 w-4 text-rose-500" />
                Expense Breakdown
              </CardTitle>
              <CardDescription className="text-xs">
                Where your money goes
              </CardDescription>
            </CardHeader>
            <CardContent>
              {expenseByCategory.length > 0 ? (
                <div className="h-[250px] sm:h-[300px]">
                  <ResponsiveContainer width="100%" height="100%">
                    <PieChart>
                      {/* ✅ Removed labels to prevent mobile overflow */}
                      <Pie
                        data={expenseByCategory}
                        cx="50%"
                        cy="50%"
                        innerRadius={55}
                        outerRadius={90}
                        paddingAngle={2}
                        dataKey="value"
                      >
                        {expenseByCategory.map((_, index) => (
                          <Cell
                            key={`cell-exp-${index}`}
                            fill={EXPENSE_COLORS[index % EXPENSE_COLORS.length]}
                          />
                        ))}
                      </Pie>
                      <Tooltip
                        formatter={(value: number) => [
                          `৳${value.toLocaleString()}`,
                          "Amount",
                        ]}
                      />
                      <Legend />
                    </PieChart>
                  </ResponsiveContainer>
                </div>
              ) : (
                <div className="h-[250px] sm:h-[300px] flex items-center justify-center text-muted-foreground">
                  No expense data for this month
                </div>
              )}
            </CardContent>
          </Card>

          {/* Income Pie Chart */}
          <Card className="animate-fade-in-up animation-delay-500">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm sm:text-base flex items-center gap-2">
                <PieChartIcon className="h-4 w-4 text-emerald-500" />
                Income Breakdown
              </CardTitle>
              <CardDescription className="text-xs">
                Where your money comes from
              </CardDescription>
            </CardHeader>
            <CardContent>
              {incomeByCategory.length > 0 ? (
                <div className="h-[250px] sm:h-[300px]">
                  <ResponsiveContainer width="100%" height="100%">
                    <PieChart>
                      {/* ✅ Removed labels to prevent mobile overflow */}
                      <Pie
                        data={incomeByCategory}
                        cx="50%"
                        cy="50%"
                        innerRadius={55}
                        outerRadius={90}
                        paddingAngle={2}
                        dataKey="value"
                      >
                        {incomeByCategory.map((_, index) => (
                          <Cell
                            key={`cell-inc-${index}`}
                            fill={INCOME_COLORS[index % INCOME_COLORS.length]}
                          />
                        ))}
                      </Pie>
                      <Tooltip
                        formatter={(value: number) => [
                          `৳${value.toLocaleString()}`,
                          "Amount",
                        ]}
                      />
                      <Legend />
                    </PieChart>
                  </ResponsiveContainer>
                </div>
              ) : (
                <div className="h-[250px] sm:h-[300px] flex items-center justify-center text-muted-foreground">
                  No income data for this month
                </div>
              )}
            </CardContent>
          </Card>
        </div>

        {/* 6-Month Trend */}
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm sm:text-base flex items-center gap-2">
              <TrendingUp className="h-4 w-4 text-indigo-500" />
              6-Month Trend
            </CardTitle>
            <CardDescription className="text-xs">
              {includeLoans
                ? "Cashflow (incl. loans)"
                : "Profit (income/expense only)"}
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="h-[250px] sm:h-[300px]">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={monthlyTrend}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
                  <XAxis dataKey="month" tick={{ fontSize: 12 }} />
                  <YAxis
                    tick={{ fontSize: 12 }}
                    tickFormatter={(value) => `৳${(value / 1000).toFixed(0)}k`}
                  />
                  <Tooltip
                    formatter={(value: number) => [
                      `৳${value.toLocaleString()}`,
                      "",
                    ]}
                    labelStyle={{ fontWeight: 600 }}
                  />
                  <Legend />
                  <Bar
                    dataKey="income"
                    name="Income"
                    fill="#10b981"
                    radius={[4, 4, 0, 0]}
                  />
                  <Bar
                    dataKey="expense"
                    name="Expense"
                    fill="#ef4444"
                    radius={[4, 4, 0, 0]}
                  />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </CardContent>
        </Card>

        {/* Daily Spending Line Chart */}
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm sm:text-base flex items-center gap-2">
              <BarChart3 className="h-4 w-4 text-blue-500" />
              Daily Activity - {format(selectedMonth, "MMMM yyyy")}
            </CardTitle>
            <CardDescription className="text-xs">
              Daily income and expenses
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="h-[250px] sm:h-[300px]">
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={dailySpending}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
                  <XAxis dataKey="day" tick={{ fontSize: 10 }} />
                  <YAxis
                    tick={{ fontSize: 12 }}
                    tickFormatter={(value) => `৳${value.toLocaleString()}`}
                  />
                  <Tooltip
                    formatter={(value: number) => [
                      `৳${value.toLocaleString()}`,
                      "",
                    ]}
                    labelFormatter={(label) => `Day ${label}`}
                  />
                  <Legend />
                  <Line
                    type="monotone"
                    dataKey="income"
                    name="Income"
                    stroke="#10b981"
                    strokeWidth={2}
                    dot={{ fill: "#10b981", strokeWidth: 0, r: 3 }}
                  />
                  <Line
                    type="monotone"
                    dataKey="expense"
                    name="Expense"
                    stroke="#ef4444"
                    strokeWidth={2}
                    dot={{ fill: "#ef4444", strokeWidth: 0, r: 3 }}
                  />
                </LineChart>
              </ResponsiveContainer>
            </div>
          </CardContent>
        </Card>

        {/* Category Details */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
          {/* Top Expenses */}
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm sm:text-base">
                Top Expenses
              </CardTitle>
            </CardHeader>
            <CardContent>
              {expenseByCategory.length > 0 ? (
                <div className="space-y-3">
                  {expenseByCategory.slice(0, 5).map((cat, index) => (
                    <div key={cat.name} className="flex items-center gap-3">
                      <div
                        className="w-3 h-3 rounded-full flex-shrink-0"
                        style={{
                          backgroundColor:
                            EXPENSE_COLORS[index % EXPENSE_COLORS.length],
                        }}
                      />
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center justify-between">
                          <span className="text-sm font-medium truncate">
                            {cat.name}
                          </span>
                          <span className="text-sm font-semibold text-rose-600 ml-2">
                            ৳{cat.value.toLocaleString()}
                          </span>
                        </div>
                        <div className="mt-1 h-1.5 bg-slate-100 rounded-full overflow-hidden">
                          <div
                            className="h-full rounded-full transition-all"
                            style={{
                              width: `${monthlySummary.expense > 0 ? (cat.value / monthlySummary.expense) * 100 : 0}%`,
                              backgroundColor:
                                EXPENSE_COLORS[index % EXPENSE_COLORS.length],
                            }}
                          />
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="text-sm text-muted-foreground text-center py-4">
                  No expenses this month
                </p>
              )}
            </CardContent>
          </Card>

          {/* Top Income Sources */}
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm sm:text-base">
                Top Income Sources
              </CardTitle>
            </CardHeader>
            <CardContent>
              {incomeByCategory.length > 0 ? (
                <div className="space-y-3">
                  {incomeByCategory.slice(0, 5).map((cat, index) => (
                    <div key={cat.name} className="flex items-center gap-3">
                      <div
                        className="w-3 h-3 rounded-full flex-shrink-0"
                        style={{
                          backgroundColor:
                            INCOME_COLORS[index % INCOME_COLORS.length],
                        }}
                      />
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center justify-between">
                          <span className="text-sm font-medium truncate">
                            {cat.name}
                          </span>
                          <span className="text-sm font-semibold text-emerald-600 ml-2">
                            ৳{cat.value.toLocaleString()}
                          </span>
                        </div>
                        <div className="mt-1 h-1.5 bg-slate-100 rounded-full overflow-hidden">
                          <div
                            className="h-full rounded-full transition-all"
                            style={{
                              width: `${monthlySummary.income > 0 ? (cat.value / monthlySummary.income) * 100 : 0}%`,
                              backgroundColor:
                                INCOME_COLORS[index % INCOME_COLORS.length],
                            }}
                          />
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="text-sm text-muted-foreground text-center py-4">
                  No income this month
                </p>
              )}
            </CardContent>
          </Card>
        </div>
      </main>
    </div>
  );
}
