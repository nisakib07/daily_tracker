"use client";

import { useEffect, useState, useCallback, useMemo, useRef } from "react";
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
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
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
import { ThemeToggle } from "@/components/theme-toggle";
import { createClient } from "@/lib/supabase/client";
import { BudgetPlanner } from "@/components/budget-planner";
import { SpendingHeatmap } from "@/components/spending-heatmap";
import { FinancialHealthScore } from "@/components/financial-health-score";
import { AIInsights } from "@/components/ai-insights";
import { InvestmentTracker } from "@/components/investment-tracker";
import { InvestmentModal } from "@/components/investment-modal";
import { InvestmentReturnModal } from "@/components/investment-return-modal";
import { InvestmentAddFundsModal } from "@/components/investment-add-funds-modal";
import { useAuth } from "@/lib/auth-context";
import { DashboardSkeleton } from "@/components/skeleton-loader";
import { WelcomeSection } from "@/components/welcome-section";
import { Confetti } from "@/components/confetti";
import { QuickAddShortcuts } from "@/components/quick-add-shortcuts";


import type { Account, Person, Transaction, Investment } from "@/lib/types";
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
  TrendingUp,
  Plus,
  LogOut,
  User,
  Settings,
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
  const { user, signOut } = useAuth();
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [people, setPeople] = useState<Person[]>([]);
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [allTransactions, setAllTransactions] = useState<Transaction[]>([]);
  const [investments, setInvestments] = useState<Investment[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedDate, setSelectedDate] = useState<Date>(new Date());
  const [activeTab, setActiveTab] = useState<"activity" | "ledger" | "budget" | "investments">(
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

  // Investment modal states
  const [investmentOpen, setInvestmentOpen] = useState(false);
  const [investmentReturnOpen, setInvestmentReturnOpen] = useState(false);
  const [investmentAddFundsOpen, setInvestmentAddFundsOpen] = useState(false);
  const [selectedInvestment, setSelectedInvestment] = useState<Investment | null>(null);

  // Confetti state for celebrations
  const [showConfetti, setShowConfetti] = useState(false);

  // Track previous balance for comparison
  const [previousBalance, setPreviousBalance] = useState<number | undefined>(undefined);

  // Pull-to-refresh state
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [pullDistance, setPullDistance] = useState(0);
  const touchStartY = useRef(0);
  const isPulling = useRef(false);
  const PULL_THRESHOLD = 60;

  const fetchData = useCallback(async () => {
    const supabase = createClient();

    const [accountsRes, peopleRes, transactionsRes, investmentsRes] = await Promise.all([
      supabase.from("accounts").select("*").order("created_at"),
      supabase.from("people").select("*").order("name"),
      supabase
        .from("transactions")
        .select("*")
        .order("date", { ascending: false })
        .limit(1000),
      supabase.from("investments").select("*").order("created_at", { ascending: false }),
    ]);

    if (accountsRes.data) setAccounts(accountsRes.data);
    if (peopleRes.data) setPeople(peopleRes.data);
    if (transactionsRes.data) {
      setAllTransactions(transactionsRes.data);
      setTransactions(transactionsRes.data);
    }
    if (investmentsRes.data) setInvestments(investmentsRes.data);
    setLoading(false);
  }, []);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  // Pull-to-refresh handlers
  const handleTouchStart = useCallback((e: React.TouchEvent) => {
    if (window.scrollY === 0) {
      touchStartY.current = e.touches[0].clientY;
      isPulling.current = true;
    }
  }, []);

  const handleTouchMove = useCallback((e: React.TouchEvent) => {
    if (!isPulling.current) return;
    const delta = e.touches[0].clientY - touchStartY.current;
    if (delta > 0 && window.scrollY === 0) {
      setPullDistance(Math.min(delta * 0.4, 80));
    }
  }, []);

  const handleTouchEnd = useCallback(async () => {
    if (!isPulling.current) return;
    isPulling.current = false;
    if (pullDistance >= PULL_THRESHOLD) {
      setIsRefreshing(true);
      setPullDistance(PULL_THRESHOLD);
      await fetchData();
      setIsRefreshing(false);
    }
    setPullDistance(0);
  }, [pullDistance, fetchData]);

  // Calculate balances from ALL transactions (not filtered) - memoized
  const accountsWithBalance = useMemo(() => {
    const mapped = accounts.map((acc) => {
      const balance = allTransactions.reduce((bal, tx) => {
        if (tx.to_account_id === acc.id) bal += Number(tx.amount);
        if (tx.from_account_id === acc.id) bal -= Number(tx.amount);
        return bal;
      }, 0);
      return { ...acc, balance };
    });

    // Sort accounts: cash -> wallet -> card -> others
    return mapped.sort((a, b) => {
      const typeOrder: Record<string, number> = { cash: 0, wallet: 1, card: 2 };
      const orderA = typeOrder[a.type] ?? 99;
      const orderB = typeOrder[b.type] ?? 99;
      return orderA - orderB;
    });
  }, [accounts, allTransactions]);

  const totalBalance = useMemo(() => {
    return accountsWithBalance.reduce((sum, acc) => sum + (acc.balance || 0), 0);
  }, [accountsWithBalance]);

  // ✅ Selected person object for PersonLedgerSheet
  const selectedPerson = useMemo(() => {
    if (!selectedPersonId) return null;
    return people.find((p) => p.id === selectedPersonId) || null;
  }, [people, selectedPersonId]);

  // Filter transactions by selected date/month and type - memoized
  const filteredTransactions = useMemo(() => {
    return allTransactions.filter((tx) => {
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
  }, [allTransactions, viewMode, selectedDate, selectedMonth, typeFilter]);

  // Calculate today's summary - memoized (excludes invest/invest_return from income/expense)
  const todaySummary = useMemo(() => {
    return filteredTransactions.reduce(
      (acc, tx) => {
        const amount = Number(tx.amount);
        if (tx.type === "income") acc.income += amount;
        else if (tx.type === "expense") acc.expense += amount;
        // invest and invest_return are asset reallocations, not income/expense
        return acc;
      },
      { income: 0, expense: 0 },
    );
  }, [filteredTransactions]);

  const goToPreviousDay = () => setSelectedDate(subDays(selectedDate, 1));
  const goToNextDay = () => setSelectedDate(addDays(selectedDate, 1));
  const goToToday = () => setSelectedDate(new Date());

  // Helper to get account name by ID - memoized callback
  const getAccountName = useCallback((accountId: string | null) => {
    if (!accountId) return null;
    return accounts.find((a) => a.id === accountId)?.name || null;
  }, [accounts]);

  // Helper to get person name by ID - memoized callback
  const getPersonName = useCallback((personId: string | null) => {
    if (!personId) return null;
    return people.find((p) => p.id === personId)?.name || null;
  }, [people]);

  // Helper to get last transaction for an account (most recent by occurred_at) - memoized callback
  const getLastTransactionForAccount = useCallback((accountId: string) => {
    const accountTxs = allTransactions.filter(
      (tx) => tx.from_account_id === accountId || tx.to_account_id === accountId
    );
    if (accountTxs.length === 0) return null;
    // Sort by occurred_at descending and return the first (most recent)
    return accountTxs.sort((a, b) => {
      const aTime = new Date(a.occurred_at || a.date).getTime();
      const bTime = new Date(b.occurred_at || b.date).getTime();
      return bTime - aTime;
    })[0];
  }, [allTransactions]);

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
    return <DashboardSkeleton />;
  }

  return (
    <div
      className="min-h-screen bg-gradient-to-b from-slate-50 via-white to-slate-50 dark:from-slate-950 dark:via-slate-900 dark:to-slate-950"
      onTouchStart={handleTouchStart}
      onTouchMove={handleTouchMove}
      onTouchEnd={handleTouchEnd}
    >
      {/* Pull-to-refresh indicator */}
      {(pullDistance > 0 || isRefreshing) && (
        <div
          className="flex items-center justify-center overflow-hidden transition-all duration-200"
          style={{ height: isRefreshing ? PULL_THRESHOLD : pullDistance }}
        >
          <Loader2
            className={cn(
              "h-5 w-5 text-emerald-500 transition-transform",
              isRefreshing && "animate-spin",
              pullDistance >= PULL_THRESHOLD && !isRefreshing && "text-emerald-600"
            )}
            style={{ transform: `rotate(${pullDistance * 3}deg)` }}
          />
          <span className="ml-2 text-xs text-muted-foreground">
            {isRefreshing ? "Refreshing..." : pullDistance >= PULL_THRESHOLD ? "Release to refresh" : "Pull to refresh"}
          </span>
        </div>
      )}

      {/* Confetti celebration */}
      {showConfetti && <Confetti />}
      
      {/* Header */}
      <header className="sticky top-0 z-20 border-b bg-white/90 dark:bg-slate-900/90 backdrop-blur-md">
        <div className="mx-auto max-w-2xl px-3 sm:px-4 py-3 sm:py-4">
          <div className="flex items-center justify-between gap-2">
            <div className="flex items-center gap-2 sm:gap-3">
              <div className="flex h-9 w-9 sm:h-10 sm:w-10 items-center justify-center rounded-xl bg-gradient-to-br from-emerald-500 to-teal-600 text-white shadow-lg shadow-emerald-500/20">
                <Wallet className="h-4 w-4 sm:h-5 sm:w-5" />
              </div>
              <h1 className="text-base sm:text-lg font-bold text-foreground">
                Money Master
              </h1>
            </div>



            <div className="flex items-center gap-2 sm:gap-3">
              <ThemeToggle />
              <Link href="/analytics">
                <Button
                  variant="outline"
                  size="icon"
                  className="h-9 w-9 sm:h-10 sm:w-10 bg-transparent border-indigo-200 dark:border-indigo-800 text-indigo-600 dark:text-indigo-400 hover:bg-indigo-50 dark:hover:bg-indigo-950 hover:border-indigo-300 dark:hover:border-indigo-700"
                >
                  <BarChart3 className="h-4 w-4 sm:h-5 sm:w-5" />
                </Button>
              </Link>
              
              {/* User Menu */}
              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <Button
                    variant="outline"
                    size="icon"
                    className="h-9 w-9 sm:h-10 sm:w-10 bg-transparent border-slate-200 dark:border-slate-700 text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-800 hover:border-slate-300 dark:hover:border-slate-600"
                  >
                    <User className="h-4 w-4 sm:h-5 sm:w-5" />
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end" className="w-56">
                  <DropdownMenuLabel className="font-normal">
                    <div className="flex flex-col space-y-1">
                      <p className="text-sm font-medium leading-none">Account</p>
                      <p className="text-xs leading-none text-muted-foreground truncate">
                        {user?.email}
                      </p>
                    </div>
                  </DropdownMenuLabel>
                  <DropdownMenuSeparator />
                  <DropdownMenuItem asChild className="cursor-pointer">
                    <Link href="/settings">
                      <Settings className="mr-2 h-4 w-4" />
                      Settings
                    </Link>
                  </DropdownMenuItem>
                  <DropdownMenuSeparator />
                  <DropdownMenuItem
                    onClick={signOut}
                    className="text-rose-600 focus:text-rose-600 focus:bg-rose-50 cursor-pointer"
                  >
                    <LogOut className="mr-2 h-4 w-4" />
                    Sign out
                  </DropdownMenuItem>
                </DropdownMenuContent>
              </DropdownMenu>
            </div>
          </div>
        </div>
      </header>

      <main className="mx-auto max-w-2xl px-3 sm:px-4 py-4 sm:py-6 space-y-4 sm:space-y-6 pb-32 sm:pb-6">
        {/* Welcome Section with Animated Balance */}
        <WelcomeSection 
          userName={user?.email}
          totalBalance={totalBalance}
          previousBalance={previousBalance}
        />

        {/* Account Cards */}
        <section>
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-2 sm:gap-3 auto-rows-fr">
            {accountsWithBalance.map((account, index) => (
              <div 
                key={account.id}
                className={cn(
                  "opacity-0 animate-fade-in-up h-full",
                  account.type === "card" ? "col-span-2 sm:col-span-1" : "col-span-1"
                )}
                style={{ animationDelay: `${index * 100}ms`, animationFillMode: "forwards" }}
              >
                <AccountCard
                  account={account}
                  lastTransaction={getLastTransactionForAccount(account.id)}
                  recentTransactions={allTransactions}
                  onEdit={handleEditAccount}
                />
              </div>
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
        <div className="swipe-container">

          
          <Tabs
            value={activeTab}
            onValueChange={(v) =>
              setActiveTab(v as "activity" | "ledger" | "budget" | "investments")
            }
          >
            <TabsList className="grid w-full grid-cols-4 mb-4 h-auto p-1">
              <TabsTrigger
                value="activity"
                className="flex items-center gap-1 sm:gap-1.5 py-2 text-[11px] sm:text-sm"
              >
                <Activity className="h-3.5 w-3.5 sm:h-4 sm:w-4 flex-shrink-0" />
                <span className="hidden min-[360px]:inline">Activity</span>
              </TabsTrigger>
              <TabsTrigger
                value="ledger"
                className="flex items-center gap-1 sm:gap-1.5 py-2 text-[11px] sm:text-sm"
              >
                <BookOpen className="h-3.5 w-3.5 sm:h-4 sm:w-4 flex-shrink-0" />
                <span className="hidden min-[360px]:inline">Ledger</span>
              </TabsTrigger>
              <TabsTrigger
                value="budget"
                className="flex items-center gap-1 sm:gap-1.5 py-2 text-[11px] sm:text-sm"
              >
                <BarChart3 className="h-3.5 w-3.5 sm:h-4 sm:w-4 flex-shrink-0" />
                <span className="hidden min-[360px]:inline">Budget</span>
              </TabsTrigger>
              <TabsTrigger
                value="investments"
                className="flex items-center gap-1 sm:gap-1.5 py-2 text-[11px] sm:text-sm"
              >
                <TrendingUp className="h-3.5 w-3.5 sm:h-4 sm:w-4 flex-shrink-0" />
                <span className="hidden min-[360px]:inline">Invest</span>
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
                  viewMode === "daily" ? "bg-slate-900 dark:bg-slate-100 dark:text-slate-900" : "bg-transparent",
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
                  viewMode === "monthly" ? "bg-slate-900 dark:bg-slate-100 dark:text-slate-900" : "bg-transparent",
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
                      <PopoverContent className="w-auto p-0" align="start" sideOffset={4} collisionPadding={12}>
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
                        className="text-emerald-600 dark:text-emerald-400 hover:text-emerald-700 dark:hover:text-emerald-300 hover:bg-emerald-50 dark:hover:bg-emerald-950 text-xs h-8"
                      >
                        Today
                      </Button>
                    )}
                  </div>
                </div>
              )}

              {/* Day/Month Summary */}
              <div className="grid grid-cols-2 gap-2 sm:gap-3">
                <div className="rounded-xl bg-gradient-to-br from-emerald-50 to-emerald-100/50 dark:from-emerald-950/50 dark:to-emerald-900/30 p-3 sm:p-4 border border-emerald-100 dark:border-emerald-800/50">
                  <p className="text-[10px] sm:text-xs font-medium text-emerald-600 dark:text-emerald-400 uppercase tracking-wide mb-0.5 sm:mb-1">
                    Money In
                  </p>
                  <p className="text-lg sm:text-xl font-bold text-emerald-700 dark:text-emerald-300">
                    +৳{todaySummary.income.toLocaleString()}
                  </p>
                </div>
                <div className="rounded-xl bg-gradient-to-br from-rose-50 to-rose-100/50 dark:from-rose-950/50 dark:to-rose-900/30 p-3 sm:p-4 border border-rose-100 dark:border-rose-800/50">
                  <p className="text-[10px] sm:text-xs font-medium text-rose-600 dark:text-rose-400 uppercase tracking-wide mb-0.5 sm:mb-1">
                    Money Out
                  </p>
                  <p className="text-lg sm:text-xl font-bold text-rose-700 dark:text-rose-300">
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
                    typeFilter === "all" ? "bg-slate-900 dark:bg-slate-100 dark:text-slate-900" : "bg-transparent",
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
                      : "bg-transparent text-emerald-600 dark:text-emerald-400 border-emerald-200 dark:border-emerald-800 hover:bg-emerald-50 dark:hover:bg-emerald-950",
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
                      : "bg-transparent text-rose-600 dark:text-rose-400 border-rose-200 dark:border-rose-800 hover:bg-rose-50 dark:hover:bg-rose-950",
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
                      : "bg-transparent text-blue-600 dark:text-blue-400 border-blue-200 dark:border-blue-800 hover:bg-blue-50 dark:hover:bg-blue-950",
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
                transactions={allTransactions}
                getAccountName={getAccountName}
                getPersonName={getPersonName}
                onEdit={handleEditTransaction}
                onDelete={fetchData}
                onAddTransaction={() => {
                  setMoneyInDefaults({});
                  setMoneyInOpen(true);
                }}
                defaultDateRange={
                  viewMode === "daily"
                    ? { from: startOfDay(selectedDate), to: endOfDay(selectedDate) }
                    : { from: startOfMonth(selectedMonth), to: endOfMonth(selectedMonth) }
                }
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
            {/* AI Features Section */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
              <FinancialHealthScore
                transactions={allTransactions}
              />
              <AIInsights
                transactions={allTransactions}
              />
            </div>
            
            <BudgetPlanner
              selectedMonth={selectedMonth}
              transactions={allTransactions}
            />
            <SpendingHeatmap
              transactions={allTransactions}
            />
          </TabsContent>
          <TabsContent value="investments" className="space-y-4 mt-0">
            <InvestmentTracker
              investments={investments}
              transactions={allTransactions}
              accounts={accounts}
              onNewInvestment={() => setInvestmentOpen(true)}
              onRecordReturn={(inv) => {
                setSelectedInvestment(inv);
                setInvestmentReturnOpen(true);
              }}
              onAddFunds={(inv) => {
                setSelectedInvestment(inv);
                setInvestmentAddFundsOpen(true);
              }}
              onSuccess={fetchData}
            />
          </TabsContent>
        </Tabs>
        </div>
      </main>

      {/* MOBILE: Floating Action Button + Quick Actions Drawer */}
      <div className="sm:hidden">
        {/* FAB with pulse animation when no transactions */}
        <button
          type="button"
          onClick={() => setQuickActionsOpen(true)}
          aria-label="Quick actions"
          className={cn(
            "fixed right-4 z-50 flex h-14 w-14 items-center justify-center rounded-full",
            "bg-slate-900 dark:bg-slate-100 text-white dark:text-slate-900 shadow-lg shadow-black/20 dark:shadow-black/40",
            "active:scale-90 transition-transform duration-150",
            allTransactions.length === 0 && "fab-pulse",
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
                onClick={() => {
                  setQuickActionsOpen(false);
                  setInvestmentOpen(true);
                }}
                className="h-12 justify-start bg-gradient-to-r from-violet-500 to-purple-600 hover:from-violet-600 hover:to-purple-700"
              >
                <TrendingUp className="mr-2 h-5 w-5" />
                New Investment
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
      <InvestmentModal
        open={investmentOpen}
        onOpenChange={setInvestmentOpen}
        accounts={accounts}
        onSuccess={fetchData}
      />
      <InvestmentReturnModal
        open={investmentReturnOpen}
        onOpenChange={setInvestmentReturnOpen}
        accounts={accounts}
        investments={investments.filter(i => i.status === 'active')}
        selectedInvestment={selectedInvestment}
        onSuccess={fetchData}
      />
      <InvestmentAddFundsModal
        open={investmentAddFundsOpen}
        onOpenChange={setInvestmentAddFundsOpen}
        accounts={accounts}
        investment={selectedInvestment}
        onSuccess={fetchData}
      />
    </div>
  );
}
