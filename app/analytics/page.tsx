"use client";

import { useEffect, useState, useCallback, useMemo } from "react";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Calendar } from "@/components/ui/calendar";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { createClient } from "@/lib/supabase/client";
import type { Account, Transaction, Person } from "@/lib/types";
import {
  ArrowLeft,
  CalendarIcon,
  TrendingUp,
  TrendingDown,
  Wallet,
  Download,
  Loader2,
  PieChart as PieChartIcon,
  BarChart3,
  ArrowUpRight,
  ArrowDownLeft,
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

  // Note: your DB fields appear snake_case (from_account_id etc.)
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
        .join(",")
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

  const fetchData = useCallback(async () => {
    const supabase = createClient();

    const [transactionsRes, accountsRes, peopleRes] = await Promise.all([
      supabase.from("transactions").select("*").order("date", { ascending: false }).limit(2000),
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

  // Filter transactions for selected month
  const monthTransactions = useMemo(() => {
    const start = startOfMonth(selectedMonth);
    const end = endOfMonth(selectedMonth);
    return transactions.filter((tx) => {
      const txDate = new Date(tx.date);
      return txDate >= start && txDate <= end;
    });
  }, [transactions, selectedMonth]);

  // Calculate monthly summary
  const monthlySummary = useMemo(() => {
    return monthTransactions.reduce(
      (acc, tx) => {
        const amount = Number(tx.amount);
        if (["income", "borrow", "receive"].includes(tx.type)) {
          acc.income += amount;
        } else if (["expense", "lend", "repay"].includes(tx.type)) {
          acc.expense += amount;
        }
        return acc;
      },
      { income: 0, expense: 0 }
    );
  }, [monthTransactions]);

  // Calculate expense by category
  const expenseByCategory = useMemo(() => {
    const categoryMap = new Map<string, number>();
    monthTransactions
      .filter((tx) => ["expense", "lend", "repay"].includes(tx.type))
      .forEach((tx) => {
        const category = tx.category || "Uncategorized";
        const current = categoryMap.get(category) || 0;
        categoryMap.set(category, current + Number(tx.amount));
      });

    return Array.from(categoryMap.entries())
      .map(([name, value]) => ({ name, value }))
      .sort((a, b) => b.value - a.value);
  }, [monthTransactions]);

  // Calculate income by category
  const incomeByCategory = useMemo(() => {
    const categoryMap = new Map<string, number>();
    monthTransactions
      .filter((tx) => ["income", "borrow", "receive"].includes(tx.type))
      .forEach((tx) => {
        const category = tx.category || "Uncategorized";
        const current = categoryMap.get(category) || 0;
        categoryMap.set(category, current + Number(tx.amount));
      });

    return Array.from(categoryMap.entries())
      .map(([name, value]) => ({ name, value }))
      .sort((a, b) => b.value - a.value);
  }, [monthTransactions]);

  // Get last 6 months data for trend chart
  const monthlyTrend = useMemo(() => {
    const months = [];
    for (let i = 5; i >= 0; i--) {
      const month = subMonths(new Date(), i);
      const start = startOfMonth(month);
      const end = endOfMonth(month);

      const monthData = transactions.filter((tx) => {
        const txDate = new Date(tx.date);
        return txDate >= start && txDate <= end;
      });

      const income = monthData
        .filter((tx) => ["income", "borrow", "receive"].includes(tx.type))
        .reduce((sum, tx) => sum + Number(tx.amount), 0);

      const expense = monthData
        .filter((tx) => ["expense", "lend", "repay"].includes(tx.type))
        .reduce((sum, tx) => sum + Number(tx.amount), 0);

      months.push({
        month: format(month, "MMM"),
        income,
        expense,
        net: income - expense,
      });
    }
    return months;
  }, [transactions]);

  // Daily spending for the selected month
  const dailySpending = useMemo(() => {
    const daysInMonth = endOfMonth(selectedMonth).getDate();
    const dailyMap = new Map<number, { income: number; expense: number }>();

    for (let i = 1; i <= daysInMonth; i++) {
      dailyMap.set(i, { income: 0, expense: 0 });
    }

    monthTransactions.forEach((tx) => {
      const day = new Date(tx.date).getDate();
      const current = dailyMap.get(day) || { income: 0, expense: 0 };
      const amount = Number(tx.amount);

      if (["income", "borrow", "receive"].includes(tx.type)) {
        current.income += amount;
      } else if (["expense", "lend", "repay"].includes(tx.type)) {
        current.expense += amount;
      }

      dailyMap.set(day, current);
    });

    return Array.from(dailyMap.entries()).map(([day, data]) => ({
      day: day.toString(),
      ...data,
    }));
  }, [monthTransactions, selectedMonth]);

  // Calculate total balance (cashflow-style net across ALL time)
  const totalBalance = useMemo(() => {
    return transactions.reduce((balance, tx) => {
      const amount = Number(tx.amount);
      if (["income", "borrow", "receive"].includes(tx.type)) {
        return balance + amount;
      }
      if (["expense", "lend", "repay"].includes(tx.type)) {
        return balance - amount;
      }
      return balance;
    }, 0);
  }, [transactions]);

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

  const goToPreviousMonth = () => setSelectedMonth(subMonths(selectedMonth, 1));
  const goToNextMonth = () => setSelectedMonth(addMonths(selectedMonth, 1));
  const isCurrentMonth = isSameMonth(selectedMonth, new Date());

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-background">
        <div className="flex flex-col items-center gap-3">
          <Loader2 className="h-8 w-8 sm:h-10 sm:w-10 animate-spin text-primary" />
          <p className="text-sm sm:text-base text-muted-foreground">Loading analytics...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-50 via-white to-slate-50">
      {/* Header */}
      <header className="sticky top-0 z-20 border-b bg-white/90 backdrop-blur-md">
        <div className="mx-auto max-w-4xl px-3 sm:px-4 py-3 sm:py-4">
          <div className="flex items-center justify-between gap-2">
            <div className="flex items-center gap-2 sm:gap-3">
              <Link href="/">
                <Button variant="ghost" size="icon" className="h-9 w-9 sm:h-10 sm:w-10">
                  <ArrowLeft className="h-4 w-4 sm:h-5 sm:w-5" />
                </Button>
              </Link>
              <div className="flex h-9 w-9 sm:h-10 sm:w-10 items-center justify-center rounded-xl bg-gradient-to-br from-indigo-500 to-purple-600 text-white shadow-lg shadow-indigo-500/20">
                <BarChart3 className="h-4 w-4 sm:h-5 sm:w-5" />
              </div>
              <div>
                <h1 className="text-base sm:text-lg font-bold text-foreground">Analytics</h1>
                <p className="text-[10px] sm:text-xs text-muted-foreground hidden sm:block">
                  Track your spending
                </p>
              </div>
            </div>

            {/* UPDATED BUTTON: CSV export */}
            <Button
              onClick={exportCSV}
              disabled={exporting || monthTransactions.length === 0}
              className="h-9 sm:h-10 text-xs sm:text-sm bg-gradient-to-r from-indigo-500 to-purple-600 hover:from-indigo-600 hover:to-purple-700"
              title={monthTransactions.length === 0 ? "No transactions to export for this month" : "Export CSV"}
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
      </header>

      <main className="mx-auto max-w-4xl px-3 sm:px-4 py-4 sm:py-6 space-y-4 sm:space-y-6">
        {/* Month Selector */}
        <div className="flex items-center justify-between gap-2">
          <Button
            variant="outline"
            size="icon"
            onClick={goToPreviousMonth}
            className="h-9 w-9 sm:h-10 sm:w-10 bg-transparent"
          >
            <ArrowLeft className="h-4 w-4" />
          </Button>

          <Popover>
            <PopoverTrigger asChild>
              <Button
                variant="outline"
                className={cn(
                  "min-w-[160px] sm:min-w-[200px] justify-center font-semibold bg-transparent text-sm sm:text-base h-9 sm:h-10",
                  isCurrentMonth && "border-indigo-500 text-indigo-600"
                )}
              >
                <CalendarIcon className="mr-2 h-4 w-4" />
                {format(selectedMonth, "MMMM yyyy")}
              </Button>
            </PopoverTrigger>
            <PopoverContent className="w-auto p-0" align="center">
              <Calendar
                mode="single"
                selected={selectedMonth}
                onSelect={(date) => date && setSelectedMonth(date)}
                initialFocus
              />
            </PopoverContent>
          </Popover>

          <Button
            variant="outline"
            size="icon"
            onClick={goToNextMonth}
            className="h-9 w-9 sm:h-10 sm:w-10 bg-transparent"
            disabled={isCurrentMonth}
          >
            <ArrowLeft className="h-4 w-4 rotate-180" />
          </Button>
        </div>

        {/* Summary Cards */}
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 sm:gap-3">
          <Card className="bg-gradient-to-br from-emerald-50 to-emerald-100/50 border-emerald-200">
            <CardContent className="p-3 sm:p-4">
              <div className="flex items-center gap-2 mb-1">
                <ArrowDownLeft className="h-4 w-4 text-emerald-600" />
                <span className="text-[10px] sm:text-xs font-medium text-emerald-600 uppercase tracking-wide">
                  Income
                </span>
              </div>
              <p className="text-lg sm:text-2xl font-bold text-emerald-700">
                ৳{monthlySummary.income.toLocaleString()}
              </p>
            </CardContent>
          </Card>

          <Card className="bg-gradient-to-br from-rose-50 to-rose-100/50 border-rose-200">
            <CardContent className="p-3 sm:p-4">
              <div className="flex items-center gap-2 mb-1">
                <ArrowUpRight className="h-4 w-4 text-rose-600" />
                <span className="text-[10px] sm:text-xs font-medium text-rose-600 uppercase tracking-wide">
                  Expenses
                </span>
              </div>
              <p className="text-lg sm:text-2xl font-bold text-rose-700">
                ৳{monthlySummary.expense.toLocaleString()}
              </p>
            </CardContent>
          </Card>

          <Card
            className={cn(
              "bg-gradient-to-br border",
              monthlySummary.income - monthlySummary.expense >= 0
                ? "from-blue-50 to-blue-100/50 border-blue-200"
                : "from-orange-50 to-orange-100/50 border-orange-200"
            )}
          >
            <CardContent className="p-3 sm:p-4">
              <div className="flex items-center gap-2 mb-1">
                {monthlySummary.income - monthlySummary.expense >= 0 ? (
                  <TrendingUp className="h-4 w-4 text-blue-600" />
                ) : (
                  <TrendingDown className="h-4 w-4 text-orange-600" />
                )}
                <span
                  className={cn(
                    "text-[10px] sm:text-xs font-medium uppercase tracking-wide",
                    monthlySummary.income - monthlySummary.expense >= 0
                      ? "text-blue-600"
                      : "text-orange-600"
                  )}
                >
                  Net
                </span>
              </div>
              <p
                className={cn(
                  "text-lg sm:text-2xl font-bold",
                  monthlySummary.income - monthlySummary.expense >= 0
                    ? "text-blue-700"
                    : "text-orange-700"
                )}
              >
                ৳{(monthlySummary.income - monthlySummary.expense).toLocaleString()}
              </p>
            </CardContent>
          </Card>

          <Card className="bg-gradient-to-br from-slate-50 to-slate-100/50 border-slate-200">
            <CardContent className="p-3 sm:p-4">
              <div className="flex items-center gap-2 mb-1">
                <Wallet className="h-4 w-4 text-slate-600" />
                <span className="text-[10px] sm:text-xs font-medium text-slate-600 uppercase tracking-wide">
                  Total
                </span>
              </div>
              <p
                className={cn(
                  "text-lg sm:text-2xl font-bold",
                  totalBalance >= 0 ? "text-emerald-700" : "text-rose-700"
                )}
              >
                ৳{totalBalance.toLocaleString()}
              </p>
            </CardContent>
          </Card>
        </div>

        {/* Charts Row */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
          {/* Expense Pie Chart */}
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm sm:text-base flex items-center gap-2">
                <PieChartIcon className="h-4 w-4 text-rose-500" />
                Expense Breakdown
              </CardTitle>
              <CardDescription className="text-xs">Where your money goes</CardDescription>
            </CardHeader>
            <CardContent>
              {expenseByCategory.length > 0 ? (
                <div className="h-[250px] sm:h-[300px]">
                  <ResponsiveContainer width="100%" height="100%">
                    <PieChart>
                      <Pie
                        data={expenseByCategory}
                        cx="50%"
                        cy="50%"
                        innerRadius={50}
                        outerRadius={80}
                        paddingAngle={2}
                        dataKey="value"
                        label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}
                        labelLine={false}
                      >
                        {expenseByCategory.map((_, index) => (
                          <Cell
                            key={`cell-${index}`}
                            fill={EXPENSE_COLORS[index % EXPENSE_COLORS.length]}
                          />
                        ))}
                      </Pie>
                      <Tooltip formatter={(value: number) => [`৳${value.toLocaleString()}`, "Amount"]} />
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
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm sm:text-base flex items-center gap-2">
                <PieChartIcon className="h-4 w-4 text-emerald-500" />
                Income Breakdown
              </CardTitle>
              <CardDescription className="text-xs">Where your money comes from</CardDescription>
            </CardHeader>
            <CardContent>
              {incomeByCategory.length > 0 ? (
                <div className="h-[250px] sm:h-[300px]">
                  <ResponsiveContainer width="100%" height="100%">
                    <PieChart>
                      <Pie
                        data={incomeByCategory}
                        cx="50%"
                        cy="50%"
                        innerRadius={50}
                        outerRadius={80}
                        paddingAngle={2}
                        dataKey="value"
                        label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}
                        labelLine={false}
                      >
                        {incomeByCategory.map((_, index) => (
                          <Cell
                            key={`cell-${index}`}
                            fill={INCOME_COLORS[index % INCOME_COLORS.length]}
                          />
                        ))}
                      </Pie>
                      <Tooltip formatter={(value: number) => [`৳${value.toLocaleString()}`, "Amount"]} />
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
            <CardDescription className="text-xs">Income vs Expenses over time</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="h-[250px] sm:h-[300px]">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={monthlyTrend}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
                  <XAxis dataKey="month" tick={{ fontSize: 12 }} />
                  <YAxis tick={{ fontSize: 12 }} tickFormatter={(value) => `৳${(value / 1000).toFixed(0)}k`} />
                  <Tooltip
                    formatter={(value: number) => [`৳${value.toLocaleString()}`, ""]}
                    labelStyle={{ fontWeight: 600 }}
                  />
                  <Legend />
                  <Bar dataKey="income" name="Income" fill="#10b981" radius={[4, 4, 0, 0]} />
                  <Bar dataKey="expense" name="Expense" fill="#ef4444" radius={[4, 4, 0, 0]} />
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
            <CardDescription className="text-xs">Daily income and expenses</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="h-[250px] sm:h-[300px]">
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={dailySpending}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
                  <XAxis dataKey="day" tick={{ fontSize: 10 }} />
                  <YAxis tick={{ fontSize: 12 }} tickFormatter={(value) => `৳${value.toLocaleString()}`} />
                  <Tooltip
                    formatter={(value: number) => [`৳${value.toLocaleString()}`, ""]}
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
              <CardTitle className="text-sm sm:text-base">Top Expenses</CardTitle>
            </CardHeader>
            <CardContent>
              {expenseByCategory.length > 0 ? (
                <div className="space-y-3">
                  {expenseByCategory.slice(0, 5).map((cat, index) => (
                    <div key={cat.name} className="flex items-center gap-3">
                      <div
                        className="w-3 h-3 rounded-full flex-shrink-0"
                        style={{
                          backgroundColor: EXPENSE_COLORS[index % EXPENSE_COLORS.length],
                        }}
                      />
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center justify-between">
                          <span className="text-sm font-medium truncate">{cat.name}</span>
                          <span className="text-sm font-semibold text-rose-600 ml-2">
                            ৳{cat.value.toLocaleString()}
                          </span>
                        </div>
                        <div className="mt-1 h-1.5 bg-slate-100 rounded-full overflow-hidden">
                          <div
                            className="h-full rounded-full transition-all"
                            style={{
                              width: `${(cat.value / monthlySummary.expense) * 100}%`,
                              backgroundColor: EXPENSE_COLORS[index % EXPENSE_COLORS.length],
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
              <CardTitle className="text-sm sm:text-base">Top Income Sources</CardTitle>
            </CardHeader>
            <CardContent>
              {incomeByCategory.length > 0 ? (
                <div className="space-y-3">
                  {incomeByCategory.slice(0, 5).map((cat, index) => (
                    <div key={cat.name} className="flex items-center gap-3">
                      <div
                        className="w-3 h-3 rounded-full flex-shrink-0"
                        style={{
                          backgroundColor: INCOME_COLORS[index % INCOME_COLORS.length],
                        }}
                      />
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center justify-between">
                          <span className="text-sm font-medium truncate">{cat.name}</span>
                          <span className="text-sm font-semibold text-emerald-600 ml-2">
                            ৳{cat.value.toLocaleString()}
                          </span>
                        </div>
                        <div className="mt-1 h-1.5 bg-slate-100 rounded-full overflow-hidden">
                          <div
                            className="h-full rounded-full transition-all"
                            style={{
                              width: `${(cat.value / monthlySummary.income) * 100}%`,
                              backgroundColor: INCOME_COLORS[index % INCOME_COLORS.length],
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
