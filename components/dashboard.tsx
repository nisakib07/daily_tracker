"use client";

import { useEffect, useState, useCallback, useMemo } from "react";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Calendar } from "@/components/ui/calendar";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  Drawer,
  DrawerContent,
  DrawerHeader,
  DrawerTitle,
} from "@/components/ui/drawer";
import { AccountCard } from "@/components/account-card";
import { TransactionModal } from "@/components/transaction-modal";
import { TransferModal } from "@/components/transfer-modal";
import { PersonModal } from "@/components/person-modal";
import { EditAccountModal } from "@/components/edit-account-modal";
import { EditTransactionModal } from "@/components/edit-transaction-modal";
import { ActivityList } from "@/components/activity-list";
import { Ledger } from "@/components/ledger";
import { MonthlyStats } from "@/components/monthly-stats";
import { PersonLedgerSheet } from "@/components/person-ledger-sheet";
import { createClient } from "@/lib/supabase/client";
import { BudgetPlanner } from "@/components/budget-planner";
import type { Account, Person, Transaction } from "@/lib/types";
import {
  ArrowDownLeft,
  ArrowUpRight,
  ArrowRightLeft,
  CalendarIcon,
  ChevronLeft,
  ChevronRight,
  Loader2,
  Wallet,
  BookOpen,
  Activity,
  BarChart3,
  Plus,
} from "lucide-react";
import {
  format,
  startOfDay,
  endOfDay,
  isToday,
  subDays,
  addDays,
  startOfMonth,
  endOfMonth,
} from "date-fns";
import { cn } from "@/lib/utils";

type LoanQuickDefaults = {
  subType?: "regular" | "loan";
  personId?: string | null;
  loanAction?: "receive" | "repay" | "borrow" | "lend" | null;
};

export function Dashboard() {
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [people, setPeople] = useState<Person[]>([]);
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [allTransactions, setAllTransactions] = useState<Transaction[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedDate, setSelectedDate] = useState<Date>(new Date());
  const [activeTab, setActiveTab] = useState<"activity" | "ledger" | "budget">(
    "activity",
  );
  const [viewMode, setViewMode] = useState<"daily" | "monthly">("daily");
  const [selectedMonth, setSelectedMonth] = useState<Date>(new Date());

  // Modal states
  const [moneyInOpen, setMoneyInOpen] = useState(false);
  const [moneyOutOpen, setMoneyOutOpen] = useState(false);
  const [transferOpen, setTransferOpen] = useState(false);
  const [personOpen, setPersonOpen] = useState(false);
  const [editAccountOpen, setEditAccountOpen] = useState(false);
  const [editTransactionOpen, setEditTransactionOpen] = useState(false);
  const [selectedAccount, setSelectedAccount] = useState<
    (Account & { balance?: number }) | null
  >(null);
  const [selectedTransaction, setSelectedTransaction] =
    useState<Transaction | null>(null);

  const [typeFilter, setTypeFilter] = useState("all");

  // ✅ Person ledger drawer state
  const [personSheetOpen, setPersonSheetOpen] = useState(false);
  const [selectedPersonId, setSelectedPersonId] = useState<string | null>(null);

  // ✅ Mobile FAB quick actions drawer
  const [quickActionsOpen, setQuickActionsOpen] = useState(false);

  // ✅ NEW: Defaults to drive TransactionModal from PersonLedgerSheet quick actions
  const [moneyInDefaults, setMoneyInDefaults] = useState<LoanQuickDefaults>({});
  const [moneyOutDefaults, setMoneyOutDefaults] = useState<LoanQuickDefaults>(
    {},
  );

  const fetchData = useCallback(async () => {
    const supabase = createClient();

    const [accountsRes, peopleRes, transactionsRes] = await Promise.all([
      supabase.from("accounts").select("*").order("created_at"),
      supabase.from("people").select("*").order("name"),
      supabase
        .from("transactions")
        .select("*")
        .order("date", { ascending: false })
        .limit(1000),
    ]);

    if (accountsRes.data) setAccounts(accountsRes.data);
    if (peopleRes.data) setPeople(peopleRes.data);
    if (transactionsRes.data) {
      setAllTransactions(transactionsRes.data);
      setTransactions(transactionsRes.data);
    }
    setLoading(false);
  }, []);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  // Calculate balances from ALL transactions (not filtered)
  const calculateBalance = (accountId: string) => {
    return allTransactions.reduce((balance, tx) => {
      if (tx.to_account_id === accountId) balance += Number(tx.amount);
      if (tx.from_account_id === accountId) balance -= Number(tx.amount);
      return balance;
    }, 0);
  };

  const accountsWithBalance = accounts.map((acc) => ({
    ...acc,
    balance: calculateBalance(acc.id),
  }));

  const totalBalance = accountsWithBalance.reduce(
    (sum, acc) => sum + (acc.balance || 0),
    0,
  );

  // ✅ Selected person object for PersonLedgerSheet
  const selectedPerson = useMemo(() => {
    if (!selectedPersonId) return null;
    return people.find((p) => p.id === selectedPersonId) || null;
  }, [people, selectedPersonId]);

  // Filter transactions by selected date/month and type
  const filteredTransactions = allTransactions.filter((tx) => {
    const txDate = new Date(tx.date);

    if (viewMode === "daily") {
      const start = startOfDay(selectedDate);
      const end = endOfDay(selectedDate);
      if (txDate < start || txDate > end) return false;
    } else {
      const start = startOfMonth(selectedMonth);
      const end = endOfMonth(selectedMonth);
      if (txDate < start || txDate > end) return false;
    }

    if (typeFilter !== "all" && tx.type !== typeFilter) return false;
    return true;
  });

  // Calculate today's summary
  const todaySummary = filteredTransactions.reduce(
    (acc, tx) => {
      const amount = Number(tx.amount);
      if (["income", "borrow", "receive"].includes(tx.type))
        acc.income += amount;
      else if (["expense", "lend", "repay"].includes(tx.type))
        acc.expense += amount;
      return acc;
    },
    { income: 0, expense: 0 },
  );

  const goToPreviousDay = () => setSelectedDate(subDays(selectedDate, 1));
  const goToNextDay = () => setSelectedDate(addDays(selectedDate, 1));
  const goToToday = () => setSelectedDate(new Date());

  // Helper to get account name by ID
  const getAccountName = (accountId: string | null) => {
    if (!accountId) return null;
    return accounts.find((a) => a.id === accountId)?.name || null;
  };

  // Helper to get person name by ID
  const getPersonName = (personId: string | null) => {
    if (!personId) return null;
    return people.find((p) => p.id === personId)?.name || null;
  };

  // Handle edit account
  const handleEditAccount = (account: Account & { balance?: number }) => {
    setSelectedAccount(account);
    setEditAccountOpen(true);
  };

  // Handle edit transaction
  const handleEditTransaction = (transaction: Transaction) => {
    setSelectedTransaction(transaction);
    setEditTransactionOpen(true);
  };

  // Handle month change from MonthlyStats
  const handleMonthChange = (month: Date) => {
    setSelectedMonth(month);
  };

  // ✅ Open sheet from Ledger click
  const handleViewPerson = (personId: string) => {
    setSelectedPersonId(personId);
    setPersonSheetOpen(true);
  };

  // ✅ Mobile quick actions handlers (normal open — clear quick defaults)
  const openMoneyIn = () => {
    setQuickActionsOpen(false);
    setMoneyInDefaults({});
    setMoneyInOpen(true);
  };
  const openMoneyOut = () => {
    setQuickActionsOpen(false);
    setMoneyOutDefaults({});
    setMoneyOutOpen(true);
  };
  const openTransfer = () => {
    setQuickActionsOpen(false);
    setTransferOpen(true);
  };

  // ✅ NEW: Quick actions from PersonLedgerSheet
  // receive => open Money In modal on loan tab with person selected
  // repay   => open Money Out modal on loan tab with person selected
  const handlePersonQuickAction = (
    action: "repay" | "receive",
    personId: string,
  ) => {
    // close person sheet first for cleaner mobile UX
    setPersonSheetOpen(false);

    if (action === "receive") {
      setMoneyInDefaults({
        subType: "loan",
        personId,
        loanAction: "receive",
      });
      setMoneyInOpen(true);
      return;
    }

    setMoneyOutDefaults({
      subType: "loan",
      personId,
      loanAction: "repay",
    });
    setMoneyOutOpen(true);
  };

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-background">
        <div className="flex flex-col items-center gap-3">
          <Loader2 className="h-8 w-8 sm:h-10 sm:w-10 animate-spin text-primary" />
          <p className="text-sm sm:text-base text-muted-foreground">
            Loading your finances...
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-50 via-white to-slate-50">
      {/* Header */}
      <header className="sticky top-0 z-20 border-b bg-white/90 backdrop-blur-md">
        <div className="mx-auto max-w-2xl px-3 sm:px-4 py-3 sm:py-4">
          <div className="flex items-center justify-between gap-2">
            <Link
              href="/analytics"
              className="flex items-center gap-2 sm:gap-3 group"
            >
              <div className="flex h-9 w-9 sm:h-10 sm:w-10 items-center justify-center rounded-xl bg-gradient-to-br from-emerald-500 to-teal-600 text-white shadow-lg shadow-emerald-500/20 group-hover:shadow-emerald-500/40 transition-shadow">
                <Wallet className="h-4 w-4 sm:h-5 sm:w-5" />
              </div>
              <div>
                <h1 className="text-base sm:text-lg font-bold text-foreground group-hover:text-emerald-600 transition-colors">
                  Money Master
                </h1>
                <p className="text-[10px] sm:text-xs text-muted-foreground hidden sm:block">
                  Tap for Analytics
                </p>
              </div>
            </Link>

            <div className="flex items-center gap-2 sm:gap-3">
              <Link href="/analytics">
                <Button
                  variant="outline"
                  size="icon"
                  className="h-9 w-9 sm:h-10 sm:w-10 bg-transparent border-indigo-200 text-indigo-600 hover:bg-indigo-50 hover:border-indigo-300"
                >
                  <BarChart3 className="h-4 w-4 sm:h-5 sm:w-5" />
                </Button>
              </Link>
              <div className="text-right">
                <p className="text-[10px] sm:text-xs font-medium text-muted-foreground uppercase tracking-wide">
                  Balance
                </p>
                <p
                  className={cn(
                    "text-lg sm:text-2xl font-bold whitespace-nowrap",
                    totalBalance >= 0 ? "text-emerald-600" : "text-rose-600",
                  )}
                >
                  ৳{totalBalance.toLocaleString()}
                </p>
              </div>
            </div>
          </div>
        </div>
      </header>

      <main className="mx-auto max-w-2xl px-3 sm:px-4 py-4 sm:py-6 space-y-4 sm:space-y-6 pb-24 sm:pb-6">
        {/* Account Cards */}
        <section>
          <div className="grid grid-cols-3 gap-2 sm:gap-3">
            {accountsWithBalance.map((account) => (
              <AccountCard
                key={account.id}
                account={account}
                onEdit={handleEditAccount}
              />
            ))}
          </div>
        </section>

        {/* Action Buttons - Desktop */}
        <section className="hidden sm:flex flex-row gap-2">
          <Button
            onClick={() => {
              setMoneyInDefaults({});
              setMoneyInOpen(true);
            }}
            className="flex-1 h-12 text-sm font-semibold bg-gradient-to-r from-emerald-500 to-emerald-600 hover:from-emerald-600 hover:to-emerald-700 shadow-lg shadow-emerald-500/25 transition-all hover:shadow-emerald-500/40"
          >
            <ArrowDownLeft className="mr-1.5 h-4 w-4" />
            Money In
          </Button>
          <Button
            onClick={() => {
              setMoneyOutDefaults({});
              setMoneyOutOpen(true);
            }}
            className="flex-1 h-12 text-sm font-semibold bg-gradient-to-r from-rose-500 to-rose-600 hover:from-rose-600 hover:to-rose-700 shadow-lg shadow-rose-500/25 transition-all hover:shadow-rose-500/40"
          >
            <ArrowUpRight className="mr-1.5 h-4 w-4" />
            Money Out
          </Button>
          <Button
            onClick={() => setTransferOpen(true)}
            className="flex-1 h-12 text-sm font-semibold bg-gradient-to-r from-blue-500 to-indigo-600 hover:from-blue-600 hover:to-indigo-700 shadow-lg shadow-blue-500/25 transition-all hover:shadow-blue-500/40"
          >
            <ArrowRightLeft className="mr-1.5 h-4 w-4" />
            Transfer
          </Button>
        </section>

        {/* Monthly Statistics */}
        <MonthlyStats
          transactions={allTransactions}
          onMonthChange={handleMonthChange}
        />

        {/* Main Content Tabs */}
        <Tabs
          value={activeTab}
          onValueChange={(v) =>
            setActiveTab(v as "activity" | "ledger" | "budget")
          }
        >
          <TabsList className="grid w-full grid-cols-3 mb-4 h-auto p-1">
            <TabsTrigger
              value="activity"
              className="flex items-center gap-1.5 py-2 text-xs sm:text-sm"
            >
              <Activity className="h-3.5 w-3.5 sm:h-4 sm:w-4" />
              Activity
            </TabsTrigger>
            <TabsTrigger
              value="ledger"
              className="flex items-center gap-1.5 py-2 text-xs sm:text-sm"
            >
              <BookOpen className="h-3.5 w-3.5 sm:h-4 sm:w-4" />
              Loan Ledger
            </TabsTrigger>
            <TabsTrigger
              value="budget"
              className="flex items-center gap-1.5 py-2 text-xs sm:text-sm"
            >
              <BarChart3 className="h-3.5 w-3.5 sm:h-4 sm:w-4" />
              Budget
            </TabsTrigger>
          </TabsList>

          <TabsContent value="activity" className="space-y-4 mt-0">
            {/* View Mode Toggle */}
            <div className="flex items-center gap-2 mb-2">
              <Button
                variant={viewMode === "daily" ? "default" : "outline"}
                size="sm"
                onClick={() => setViewMode("daily")}
                className={cn(
                  "text-xs h-8",
                  viewMode === "daily" ? "bg-slate-900" : "bg-transparent",
                )}
              >
                Daily
              </Button>
              <Button
                variant={viewMode === "monthly" ? "default" : "outline"}
                size="sm"
                onClick={() => setViewMode("monthly")}
                className={cn(
                  "text-xs h-8",
                  viewMode === "monthly" ? "bg-slate-900" : "bg-transparent",
                )}
              >
                Monthly
              </Button>
            </div>

            {/* Date Navigator & Filters */}
            <div className="space-y-3 sm:space-y-4">
              {viewMode === "daily" && (
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-1 sm:gap-2">
                    <Button
                      variant="outline"
                      size="icon"
                      onClick={goToPreviousDay}
                      className="h-8 w-8 sm:h-9 sm:w-9 bg-transparent"
                    >
                      <ChevronLeft className="h-4 w-4" />
                    </Button>

                    <Popover>
                      <PopoverTrigger asChild>
                        <Button
                          variant="outline"
                          className={cn(
                            "min-w-[120px] sm:min-w-[160px] justify-start text-left font-medium bg-transparent text-xs sm:text-sm h-8 sm:h-9",
                            isToday(selectedDate) &&
                              "border-emerald-500 text-emerald-600",
                          )}
                        >
                          <CalendarIcon className="mr-1.5 sm:mr-2 h-3.5 w-3.5 sm:h-4 sm:w-4" />
                          {isToday(selectedDate)
                            ? "Today"
                            : format(selectedDate, "EEE, MMM d")}
                        </Button>
                      </PopoverTrigger>
                      <PopoverContent className="w-auto p-0" align="start">
                        <Calendar
                          mode="single"
                          selected={selectedDate}
                          onSelect={(date) => date && setSelectedDate(date)}
                          initialFocus
                        />
                      </PopoverContent>
                    </Popover>

                    <Button
                      variant="outline"
                      size="icon"
                      onClick={goToNextDay}
                      className="h-8 w-8 sm:h-9 sm:w-9 bg-transparent"
                      disabled={isToday(selectedDate)}
                    >
                      <ChevronRight className="h-4 w-4" />
                    </Button>

                    {!isToday(selectedDate) && (
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={goToToday}
                        className="text-emerald-600 hover:text-emerald-700 hover:bg-emerald-50 text-xs h-8"
                      >
                        Today
                      </Button>
                    )}
                  </div>
                </div>
              )}

              {/* Day/Month Summary */}
              <div className="grid grid-cols-2 gap-2 sm:gap-3">
                <div className="rounded-xl bg-gradient-to-br from-emerald-50 to-emerald-100/50 p-3 sm:p-4 border border-emerald-100">
                  <p className="text-[10px] sm:text-xs font-medium text-emerald-600 uppercase tracking-wide mb-0.5 sm:mb-1">
                    Money In
                  </p>
                  <p className="text-lg sm:text-xl font-bold text-emerald-700">
                    +৳{todaySummary.income.toLocaleString()}
                  </p>
                </div>
                <div className="rounded-xl bg-gradient-to-br from-rose-50 to-rose-100/50 p-3 sm:p-4 border border-rose-100">
                  <p className="text-[10px] sm:text-xs font-medium text-rose-600 uppercase tracking-wide mb-0.5 sm:mb-1">
                    Money Out
                  </p>
                  <p className="text-lg sm:text-xl font-bold text-rose-700">
                    -৳{todaySummary.expense.toLocaleString()}
                  </p>
                </div>
              </div>

              {/* Type Filter */}
              <div className="flex gap-1.5 sm:gap-2 flex-wrap">
                <Button
                  variant={typeFilter === "all" ? "default" : "outline"}
                  size="sm"
                  onClick={() => setTypeFilter("all")}
                  className={cn(
                    "rounded-full text-xs h-7 sm:h-8 px-2.5 sm:px-3",
                    typeFilter === "all" ? "bg-slate-900" : "bg-transparent",
                  )}
                >
                  All
                </Button>
                <Button
                  variant={typeFilter === "income" ? "default" : "outline"}
                  size="sm"
                  onClick={() => setTypeFilter("income")}
                  className={cn(
                    "rounded-full text-xs h-7 sm:h-8 px-2.5 sm:px-3",
                    typeFilter === "income"
                      ? "bg-emerald-600 hover:bg-emerald-700"
                      : "bg-transparent text-emerald-600 border-emerald-200 hover:bg-emerald-50",
                  )}
                >
                  Income
                </Button>
                <Button
                  variant={typeFilter === "expense" ? "default" : "outline"}
                  size="sm"
                  onClick={() => setTypeFilter("expense")}
                  className={cn(
                    "rounded-full text-xs h-7 sm:h-8 px-2.5 sm:px-3",
                    typeFilter === "expense"
                      ? "bg-rose-600 hover:bg-rose-700"
                      : "bg-transparent text-rose-600 border-rose-200 hover:bg-rose-50",
                  )}
                >
                  Expense
                </Button>
                <Button
                  variant={typeFilter === "transfer" ? "default" : "outline"}
                  size="sm"
                  onClick={() => setTypeFilter("transfer")}
                  className={cn(
                    "rounded-full text-xs h-7 sm:h-8 px-2.5 sm:px-3",
                    typeFilter === "transfer"
                      ? "bg-blue-600 hover:bg-blue-700"
                      : "bg-transparent text-blue-600 border-blue-200 hover:bg-blue-50",
                  )}
                >
                  Transfer
                </Button>
              </div>
            </div>

            {/* Activity List */}
            <section>
              <h2 className="text-xs sm:text-sm font-semibold text-muted-foreground uppercase tracking-wide mb-2 sm:mb-3">
                {viewMode === "daily"
                  ? isToday(selectedDate)
                    ? "Today's Activity"
                    : `Activity on ${format(selectedDate, "MMM d")}`
                  : `Activity in ${format(selectedMonth, "MMMM yyyy")}`}
                {filteredTransactions.length > 0 && (
                  <span className="ml-2 text-foreground">
                    ({filteredTransactions.length})
                  </span>
                )}
              </h2>

              <ActivityList
                transactions={filteredTransactions}
                getAccountName={getAccountName}
                getPersonName={getPersonName}
                onEdit={handleEditTransaction}
                onDelete={fetchData}
              />
            </section>
          </TabsContent>

          <TabsContent value="ledger" className="mt-0">
            <section>
              <h2 className="text-xs sm:text-sm font-semibold text-muted-foreground uppercase tracking-wide mb-2 sm:mb-3">
                Loan & Borrow Ledger
              </h2>

              <Ledger
                transactions={allTransactions}
                people={people}
                onViewPerson={handleViewPerson}
              />
            </section>
          </TabsContent>
          <TabsContent value="budget" className="space-y-4 mt-0">
            <BudgetPlanner
              selectedMonth={selectedMonth}
              transactions={allTransactions}
            />
          </TabsContent>
        </Tabs>
      </main>

      {/* ✅ MOBILE: Floating Action Button + Quick Actions Drawer */}
      <div className="sm:hidden">
        {/* FAB */}
        <button
          type="button"
          onClick={() => setQuickActionsOpen(true)}
          aria-label="Quick actions"
          className={cn(
            "fixed right-4 z-50 flex h-14 w-14 items-center justify-center rounded-full",
            "bg-slate-900 text-white shadow-lg shadow-black/20",
            "active:scale-95 transition-transform",
          )}
          style={{ bottom: "calc(1rem + env(safe-area-inset-bottom))" }}
        >
          <Plus className="h-6 w-6" />
        </button>

        {/* Quick Actions Bottom Sheet */}
        <Drawer open={quickActionsOpen} onOpenChange={setQuickActionsOpen}>
          <DrawerContent className="max-h-[85vh] px-4 pb-4">
            <DrawerHeader className="px-0">
              <DrawerTitle className="text-base">Quick actions</DrawerTitle>
            </DrawerHeader>

            <div className="grid gap-2 pb-[env(safe-area-inset-bottom)]">
              <Button
                onClick={openMoneyIn}
                className="h-12 justify-start bg-gradient-to-r from-emerald-500 to-emerald-600 hover:from-emerald-600 hover:to-emerald-700"
              >
                <ArrowDownLeft className="mr-2 h-5 w-5" />
                Money In
              </Button>

              <Button
                onClick={openMoneyOut}
                className="h-12 justify-start bg-gradient-to-r from-rose-500 to-rose-600 hover:from-rose-600 hover:to-rose-700"
              >
                <ArrowUpRight className="mr-2 h-5 w-5" />
                Money Out
              </Button>

              <Button
                onClick={openTransfer}
                className="h-12 justify-start bg-gradient-to-r from-blue-500 to-indigo-600 hover:from-blue-600 hover:to-indigo-700"
              >
                <ArrowRightLeft className="mr-2 h-5 w-5" />
                Transfer
              </Button>

              <Button
                variant="outline"
                className="h-12 bg-transparent"
                onClick={() => setQuickActionsOpen(false)}
              >
                Cancel
              </Button>
            </div>
          </DrawerContent>
        </Drawer>
      </div>

      {/* ✅ Person drawer (now wired to open TransactionModal quickly) */}
      <PersonLedgerSheet
        open={personSheetOpen}
        onOpenChange={setPersonSheetOpen}
        person={selectedPerson}
        transactions={allTransactions}
        accounts={accounts}
        onSuccess={fetchData}
        onQuickAction={handlePersonQuickAction} // ✅ add this
      />

      {/* Modals */}
      <TransactionModal
        open={moneyInOpen}
        onOpenChange={setMoneyInOpen}
        type="in"
        accounts={accounts}
        people={people}
        onSuccess={fetchData}
        onAddPerson={() => setPersonOpen(true)}
        defaultSubType={moneyInDefaults.subType}
        defaultPersonId={moneyInDefaults.personId ?? null}
        defaultLoanAction={moneyInDefaults.loanAction ?? null}
      />
      <TransactionModal
        open={moneyOutOpen}
        onOpenChange={setMoneyOutOpen}
        type="out"
        accounts={accounts}
        people={people}
        onSuccess={fetchData}
        onAddPerson={() => setPersonOpen(true)}
        defaultSubType={moneyOutDefaults.subType}
        defaultPersonId={moneyOutDefaults.personId ?? null}
        defaultLoanAction={moneyOutDefaults.loanAction ?? null}
      />
      <TransferModal
        open={transferOpen}
        onOpenChange={setTransferOpen}
        accounts={accounts}
        onSuccess={fetchData}
      />
      <PersonModal
        open={personOpen}
        onOpenChange={setPersonOpen}
        onSuccess={fetchData}
      />
      <EditAccountModal
        open={editAccountOpen}
        onOpenChange={setEditAccountOpen}
        account={selectedAccount}
        onSuccess={fetchData}
      />
      <EditTransactionModal
        open={editTransactionOpen}
        onOpenChange={setEditTransactionOpen}
        transaction={selectedTransaction}
        accounts={accounts}
        people={people}
        onSuccess={fetchData}
      />
    </div>
  );
}
