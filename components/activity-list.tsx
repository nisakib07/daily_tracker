"use client";

import { useMemo, useState, useRef, useCallback, useEffect } from "react";
import type { Transaction } from "@/lib/types";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
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
import { EmptyState } from "@/components/empty-state";
import {
  ArrowDownLeft,
  ArrowUpRight,
  ArrowRightLeft,
  MoreVertical,
  Pencil,
  Trash2,
  HandCoins,
  Handshake,
  Loader2,
  Search,
  X,
  CalendarIcon,
} from "lucide-react";
import { Calendar } from "@/components/ui/calendar";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";
import {
  format,
  parseISO,
  startOfDay,
  endOfDay,
  differenceInCalendarDays,
  subDays,
  isAfter,
  isBefore,
  isSameDay,
} from "date-fns";
import { cn } from "@/lib/utils";
import { createClient } from "@/lib/supabase/client";
import { getCategoryIcon } from "@/lib/category-icons";

interface ActivityListProps {
  transactions: Transaction[];
  getAccountName: (id: string | null) => string | null;
  getPersonName: (id: string | null) => string | null;
  onEdit: (transaction: Transaction) => void;
  onDelete: () => void;
  onAddTransaction?: () => void;
  defaultDateRange?: { from: Date | undefined; to: Date | undefined };
}

type Group = {
  key: string;
  title: string;
  dateLabel: string;
  items: Transaction[];
};

type QuickFilter = "all" | "in" | "out" | "transfer" | "loans";

// Swipeable card component for mobile touch gestures
interface SwipeableCardProps {
  children: React.ReactNode;
  onSwipeLeft: () => void;
  onSwipeRight: () => void;
  leftLabel?: string;
  rightLabel?: string;
}

function SwipeableCard({
  children,
  onSwipeLeft,
  onSwipeRight,
  leftLabel = "Delete",
  rightLabel = "Edit",
}: SwipeableCardProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const [translateX, setTranslateX] = useState(0);
  const [isDragging, setIsDragging] = useState(false);
  const startXRef = useRef(0);
  const startYRef = useRef(0);
  const currentXRef = useRef(0);
  const isHorizontalSwipeRef = useRef<boolean | null>(null);

  const SWIPE_THRESHOLD = 80;
  const MAX_SWIPE = 100;

  const handleTouchStart = useCallback((e: React.TouchEvent) => {
    startXRef.current = e.touches[0].clientX;
    startYRef.current = e.touches[0].clientY;
    currentXRef.current = translateX;
    isHorizontalSwipeRef.current = null;
    setIsDragging(true);
  }, [translateX]);

  const handleTouchMove = useCallback((e: React.TouchEvent) => {
    if (!isDragging) return;

    const currentX = e.touches[0].clientX;
    const currentY = e.touches[0].clientY;
    const diffX = currentX - startXRef.current;
    const diffY = currentY - startYRef.current;

    // Determine if this is a horizontal or vertical swipe (only once per gesture)
    if (isHorizontalSwipeRef.current === null) {
      if (Math.abs(diffX) > 10 || Math.abs(diffY) > 10) {
        isHorizontalSwipeRef.current = Math.abs(diffX) > Math.abs(diffY);
      }
      return;
    }

    // If it's a vertical swipe, don't interfere with scrolling
    if (!isHorizontalSwipeRef.current) {
      return;
    }

    // Prevent page scroll during horizontal swipe
    e.preventDefault();

    let newTranslate = currentXRef.current + diffX;
    
    // Add resistance at the edges
    if (newTranslate > MAX_SWIPE) {
      newTranslate = MAX_SWIPE + (newTranslate - MAX_SWIPE) * 0.2;
    } else if (newTranslate < -MAX_SWIPE) {
      newTranslate = -MAX_SWIPE + (newTranslate + MAX_SWIPE) * 0.2;
    }

    setTranslateX(newTranslate);
  }, [isDragging]);

  const handleTouchEnd = useCallback(() => {
    setIsDragging(false);
    isHorizontalSwipeRef.current = null;

    if (translateX > SWIPE_THRESHOLD) {
      // Swiped right - Edit
      setTranslateX(MAX_SWIPE);
      setTimeout(() => {
        onSwipeRight();
        setTranslateX(0);
      }, 150);
    } else if (translateX < -SWIPE_THRESHOLD) {
      // Swiped left - Delete
      setTranslateX(-MAX_SWIPE);
      setTimeout(() => {
        onSwipeLeft();
        setTranslateX(0);
      }, 150);
    } else {
      // Snap back
      setTranslateX(0);
    }
  }, [translateX, onSwipeLeft, onSwipeRight]);

  // Calculate action opacity based on swipe distance
  const leftOpacity = Math.min(1, Math.abs(Math.min(0, translateX)) / SWIPE_THRESHOLD);
  const rightOpacity = Math.min(1, Math.max(0, translateX) / SWIPE_THRESHOLD);

  return (
    <div className="relative overflow-hidden rounded-xl sm:overflow-visible">
      {/* Left action (Delete) - revealed when swiping left */}
      <div 
        className="absolute inset-y-0 right-0 w-24 flex items-center justify-center bg-gradient-to-l from-rose-500 to-rose-600 rounded-r-xl sm:hidden"
        style={{ opacity: leftOpacity }}
      >
        <div className="flex flex-col items-center text-white">
          <Trash2 className="h-5 w-5 mb-1" />
          <span className="text-xs font-medium">{leftLabel}</span>
        </div>
      </div>

      {/* Right action (Edit) - revealed when swiping right */}
      <div 
        className="absolute inset-y-0 left-0 w-24 flex items-center justify-center bg-gradient-to-r from-emerald-500 to-emerald-600 rounded-l-xl sm:hidden"
        style={{ opacity: rightOpacity }}
      >
        <div className="flex flex-col items-center text-white">
          <Pencil className="h-5 w-5 mb-1" />
          <span className="text-xs font-medium">{rightLabel}</span>
        </div>
      </div>

      {/* Main content */}
      <div
        ref={containerRef}
        className="relative bg-card touch-pan-y"
        style={{
          transform: `translateX(${translateX}px)`,
          transition: isDragging ? 'none' : 'transform 0.3s cubic-bezier(0.25, 0.46, 0.45, 0.94)',
        }}
        onTouchStart={handleTouchStart}
        onTouchMove={handleTouchMove}
        onTouchEnd={handleTouchEnd}
      >
        {children}
      </div>
    </div>
  );
}

export function ActivityList({
  transactions,
  getAccountName,
  getPersonName,
  onEdit,
  onDelete,
  onAddTransaction,
  defaultDateRange,
}: ActivityListProps) {
  const [deleteId, setDeleteId] = useState<string | null>(null);
  const [deleting, setDeleting] = useState(false);

  // Search + quick filter + date range
  const [query, setQuery] = useState("");
  const [quickFilter, setQuickFilter] = useState<QuickFilter>("all");
  const [dateRange, setDateRange] = useState<{ from: Date | undefined; to: Date | undefined }>(
    defaultDateRange || { from: undefined, to: undefined }
  );
  
  // Sync with defaultDateRange when it changes
  useEffect(() => {
    if (defaultDateRange) {
      setDateRange(defaultDateRange);
    }
  }, [defaultDateRange]);

  const isDefaultRange = useMemo(() => {
    if (!defaultDateRange || !defaultDateRange.from || !defaultDateRange.to || !dateRange.from || !dateRange.to) return false;
    return isSameDay(dateRange.from, defaultDateRange.from) && isSameDay(dateRange.to, defaultDateRange.to);
  }, [dateRange, defaultDateRange]);

  const [datePickerOpen, setDatePickerOpen] = useState(false);

  const handleDelete = async () => {
    if (!deleteId) return;

    setDeleting(true);
    const supabase = createClient();

    try {
      const { error } = await supabase
        .from("transactions")
        .delete()
        .eq("id", deleteId);
      if (error) throw error;
      onDelete();
    } catch (error) {
      console.error("[v0] Error deleting transaction:", error);
    } finally {
      setDeleting(false);
      setDeleteId(null);
    }
  };

  const getIcon = (type: string) => {
    switch (type) {
      case "income":
        return <ArrowDownLeft className="h-4 w-4 sm:h-5 sm:w-5" />;
      case "expense":
        return <ArrowUpRight className="h-4 w-4 sm:h-5 sm:w-5" />;
      case "transfer":
        return <ArrowRightLeft className="h-4 w-4 sm:h-5 sm:w-5" />;
      case "lend":
        return <HandCoins className="h-4 w-4 sm:h-5 sm:w-5" />;
      case "borrow":
        return <Handshake className="h-4 w-4 sm:h-5 sm:w-5" />;
      case "repay":
        return <ArrowUpRight className="h-4 w-4 sm:h-5 sm:w-5" />;
      case "receive":
        return <ArrowDownLeft className="h-4 w-4 sm:h-5 sm:w-5" />;
      default:
        return <ArrowDownLeft className="h-4 w-4 sm:h-5 sm:w-5" />;
    }
  };

  const getIconStyle = (type: string) => {
    switch (type) {
      case "income":
      case "receive":
        return "bg-gradient-to-br from-emerald-100 to-emerald-200 dark:from-emerald-900/50 dark:to-emerald-800/50 text-emerald-600 dark:text-emerald-400";
      case "expense":
      case "repay":
        return "bg-gradient-to-br from-rose-100 to-rose-200 dark:from-rose-900/50 dark:to-rose-800/50 text-rose-600 dark:text-rose-400";
      case "transfer":
        return "bg-gradient-to-br from-blue-100 to-blue-200 dark:from-blue-900/50 dark:to-blue-800/50 text-blue-600 dark:text-blue-400";
      case "lend":
        return "bg-gradient-to-br from-indigo-100 to-indigo-200 dark:from-indigo-900/50 dark:to-indigo-800/50 text-indigo-600 dark:text-indigo-400";
      case "borrow":
        return "bg-gradient-to-br from-amber-100 to-amber-200 dark:from-amber-900/50 dark:to-amber-800/50 text-amber-600 dark:text-amber-400";
      default:
        return "bg-gradient-to-br from-slate-100 to-slate-200 dark:from-slate-800 dark:to-slate-700 text-slate-600 dark:text-slate-400";
    }
  };

  const getAmountStyle = (type: string) => {
    switch (type) {
      case "income":
      case "borrow":
      case "receive":
        return "text-emerald-600 dark:text-emerald-400";
      case "expense":
      case "lend":
      case "repay":
        return "text-rose-600 dark:text-rose-400";
      case "transfer":
        return "text-blue-600 dark:text-blue-400";
      default:
        return "text-muted-foreground";
    }
  };

  const isMoneyIn = (type: string) =>
    ["income", "borrow", "receive"].includes(type);
  const isLoan = (type: string) =>
    ["lend", "borrow", "repay", "receive"].includes(type);

  const getTypeLabel = (type: string) => {
    switch (type) {
      case "income":
        return "Income";
      case "expense":
        return "Expense";
      case "transfer":
        return "Transfer";
      case "lend":
        return "Loan Given";
      case "borrow":
        return "Borrowed";
      case "repay":
        return "Loan Repaid";
      case "receive":
        return "Loan Received";
      default:
        return type;
    }
  };

  // Filter first (search + chips + date range), then group
  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();

    const matchesQuickFilter = (tx: Transaction) => {
      if (quickFilter === "all") return true;
      if (quickFilter === "in")
        return ["income", "borrow", "receive"].includes(tx.type);
      if (quickFilter === "out")
        return ["expense", "lend", "repay"].includes(tx.type);
      if (quickFilter === "transfer") return tx.type === "transfer";
      if (quickFilter === "loans") return isLoan(tx.type);
      return true;
    };

    const matchesDateRange = (tx: Transaction) => {
      if (!dateRange.from && !dateRange.to) return true;
      const txDate = startOfDay(parseISO(String(tx.date)));
      const fromDate = dateRange.from ? startOfDay(dateRange.from) : null;
      const toDate = dateRange.to ? endOfDay(dateRange.to) : null;
      
      if (fromDate && isBefore(txDate, fromDate)) return false;
      if (toDate && isAfter(txDate, toDate)) return false;
      return true;
    };

    const matchesSearch = (tx: Transaction) => {
      if (!q) return true;

      const isTransferTx = tx.type === "transfer";
      const accountName = isTransferTx
        ? `${getAccountName(tx.from_account_id)} → ${getAccountName(tx.to_account_id)}`
        : getAccountName(
            isMoneyIn(tx.type) ? tx.to_account_id : tx.from_account_id,
          );

      const personName = getPersonName(tx.person_id);

      const haystack = [
        tx.type,
        getTypeLabel(tx.type),
        tx.category ?? "",
        tx.note ?? "",
        accountName ?? "",
        personName ?? "",
        String(tx.amount ?? ""),
      ]
        .join(" ")
        .toLowerCase();

      return haystack.includes(q);
    };

    return (transactions ?? []).filter(
      (tx) => matchesQuickFilter(tx) && matchesSearch(tx) && matchesDateRange(tx),
    );
  }, [transactions, query, quickFilter, dateRange, getAccountName, getPersonName]);

  // ✅ Group by date (timezone-safe Today/Yesterday)
  const groups: Group[] = useMemo(() => {
    if (!filtered.length) return [];

    const nowStart = startOfDay(new Date());
    const map = new Map<string, Transaction[]>();

    for (const tx of filtered) {
      const d = parseISO(String(tx.date));
      const key = format(d, "yyyy-MM-dd");
      const list = map.get(key) ?? [];
      list.push(tx);
      map.set(key, list);
    }

    const sortedKeys = Array.from(map.keys()).sort((a, b) => (a > b ? -1 : 1));

    return sortedKeys.map((key) => {
      const items = map.get(key)!;
      // Sort items within each day by occurred_at descending (most recent first)
      items.sort((a, b) => {
        const aTime = new Date(a.occurred_at || a.date).getTime();
        const bTime = new Date(b.occurred_at || b.date).getTime();
        return bTime - aTime;
      });
      
      const first = items[0];
      const dateObj = parseISO(String(first.date));
      const dayStart = startOfDay(dateObj);

      const diff = differenceInCalendarDays(nowStart, dayStart);

      let title = format(dateObj, "EEEE");
      if (diff === 0) title = "Today";
      else if (diff === 1) title = "Yesterday";

      const dateLabel = format(dateObj, "MMM d, yyyy");

      return {
        key,
        title,
        dateLabel,
        items,
      };
    });
  }, [filtered]);

  if (!transactions || transactions.length === 0) {
    return (
      <EmptyState 
        type="transactions"
        onAction={onAddTransaction}
        actionLabel="Add Transaction"
      />
    );
  }

  return (
    <>
      {/* Sticky search + quick filters + date range (mobile-friendly) */}
      <div className="sticky top-0 z-10 -mx-3 sm:mx-0 px-3 sm:px-0 py-2 bg-background/80 backdrop-blur-md border-b border-border">
        <div className="flex items-center gap-2">
          <div className="relative flex-1">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
            <Input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Search amount, note, person, account…"
              className="pl-9 h-10 bg-background"
            />
            {query.trim() && (
              <button
                type="button"
                aria-label="Clear search"
                onClick={() => setQuery("")}
                className="absolute right-2 top-1/2 -translate-y-1/2 p-1 rounded hover:bg-muted"
              >
                <X className="h-4 w-4 text-muted-foreground" />
              </button>
            )}
          </div>
          
          {/* Date Range Picker */}
          <Popover open={datePickerOpen} onOpenChange={setDatePickerOpen}>
            <PopoverTrigger asChild>
              <Button
                variant="outline"
                size="icon"
                className={cn(
                  "h-10 w-10 shrink-0 bg-background",
                  (dateRange.from || dateRange.to) && "border-emerald-500 text-emerald-600"
                )}
              >
                <CalendarIcon className="h-4 w-4" />
              </Button>
            </PopoverTrigger>
            <PopoverContent className="w-auto p-0" align="end">
              <div className="p-3 space-y-3">
                <div className="flex items-center justify-between">
                  <p className="text-sm font-medium">Date Range</p>
                  {(dateRange.from || dateRange.to) && (
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => {
                        setDateRange({ from: undefined, to: undefined });
                        setDatePickerOpen(false);
                      }}
                      className="h-7 text-xs text-muted-foreground hover:text-foreground"
                    >
                      Clear
                    </Button>
                  )}
                </div>
                
                {/* Quick presets */}
                <div className="flex flex-wrap gap-1.5">
                  <Button
                    variant="outline"
                    size="sm"
                    className="h-8 text-xs"
                    onClick={() => {
                      setDateRange({ from: subDays(new Date(), 7), to: new Date() });
                      setDatePickerOpen(false);
                    }}
                  >
                    Last 7 days
                  </Button>
                  <Button
                    variant="outline"
                    size="sm"
                    className="h-8 text-xs"
                    onClick={() => {
                      setDateRange({ from: subDays(new Date(), 30), to: new Date() });
                      setDatePickerOpen(false);
                    }}
                  >
                    Last 30 days
                  </Button>
                  <Button
                    variant="outline"
                    size="sm"
                    className="h-8 text-xs"
                    onClick={() => {
                      setDateRange({ from: subDays(new Date(), 90), to: new Date() });
                      setDatePickerOpen(false);
                    }}
                  >
                    Last 90 days
                  </Button>
                </div>
                
                <Calendar
                  mode="range"
                  selected={{ from: dateRange.from, to: dateRange.to }}
                  onSelect={(range) => {
                    setDateRange({ from: range?.from, to: range?.to });
                    if (range?.from && range?.to) {
                      setDatePickerOpen(false);
                    }
                  }}
                  numberOfMonths={1}
                  initialFocus
                />
              </div>
            </PopoverContent>
          </Popover>
        </div>

        {/* Active date range indicator - only show if customized from default */}
        {(dateRange.from || dateRange.to) && !isDefaultRange && (
          <div className="mt-2 flex items-center gap-2 px-3 py-2 rounded-lg bg-emerald-50 dark:bg-emerald-950/50 border border-emerald-200 dark:border-emerald-800">
            <CalendarIcon className="h-4 w-4 text-emerald-600 dark:text-emerald-400 flex-shrink-0" />
            <span className="text-xs font-medium text-emerald-700 dark:text-emerald-300 flex-1">
              {dateRange.from ? format(dateRange.from, "MMM d") : "Start"} 
              {" - "}
              {dateRange.to ? format(dateRange.to, "MMM d, yyyy") : "End"}
            </span>
            <button
              type="button"
              onClick={() => setDateRange({ from: undefined, to: undefined })}
              className="p-1.5 rounded-full hover:bg-emerald-100 dark:hover:bg-emerald-900 active:scale-95 transition-transform"
              aria-label="Clear date filter"
            >
              <X className="h-4 w-4 text-emerald-600 dark:text-emerald-400" />
            </button>
          </div>
        )}

        <div className="mt-2 flex gap-2 overflow-x-auto pb-1">
          <Chip
            active={quickFilter === "all"}
            onClick={() => setQuickFilter("all")}
          >
            All
          </Chip>
          <Chip
            active={quickFilter === "in"}
            onClick={() => setQuickFilter("in")}
          >
            In
          </Chip>
          <Chip
            active={quickFilter === "out"}
            onClick={() => setQuickFilter("out")}
          >
            Out
          </Chip>
          <Chip
            active={quickFilter === "transfer"}
            onClick={() => setQuickFilter("transfer")}
          >
            Transfer
          </Chip>
          <Chip
            active={quickFilter === "loans"}
            onClick={() => setQuickFilter("loans")}
          >
            Loans
          </Chip>
        </div>

        {filtered.length !== transactions.length && (
          <p className="mt-1 text-[11px] text-muted-foreground">
            Showing {filtered.length} of {transactions.length}
          </p>
        )}
      </div>

      {filtered.length === 0 ? (
        <EmptyState 
          type="transactions"
          onAction={onAddTransaction}
          actionLabel="Add Transaction"
        />
      ) : (
        <div className="space-y-5 mt-3">
          {groups.map((group, groupIndex) => (
            <div key={group.key} className="space-y-2 animate-fade-in-up" style={{ animationDelay: `${groupIndex * 50}ms` }}>
              {/* Date Header with timeline connector */}
              <div className="flex items-center gap-3 px-1">
                <div className="flex h-8 w-8 items-center justify-center rounded-full bg-muted text-muted-foreground text-xs font-semibold">
                  {group.items.length}
                </div>
                <div className="flex-1 flex items-baseline justify-between">
                  <div className="flex items-baseline gap-2">
                    <p className="text-sm font-semibold text-foreground">
                      {group.title}
                    </p>
                    <p className="text-xs text-muted-foreground">
                      {group.dateLabel}
                    </p>
                  </div>
                </div>
              </div>

              {/* Timeline connector and items */}
              <div className="relative ml-4 border-l-2 border-border pl-6 space-y-2">
                {group.items.map((tx, txIndex) => {
                  const isTransferTx = tx.type === "transfer";
                  const accountName = isTransferTx
                    ? `${getAccountName(tx.from_account_id)} → ${getAccountName(tx.to_account_id)}`
                    : getAccountName(
                        isMoneyIn(tx.type)
                          ? tx.to_account_id
                          : tx.from_account_id,
                      );

                  const personName = getPersonName(tx.person_id);

                  return (
                    <SwipeableCard
                      key={tx.id}
                      onSwipeLeft={() => setDeleteId(tx.id)}
                      onSwipeRight={() => onEdit(tx)}
                    >
                      <div
                        className="group relative rounded-xl bg-card border border-border p-3 sm:p-4 transition-all hover:shadow-md hover:border-muted-foreground/20 animate-slide-in-right"
                        style={{ animationDelay: `${txIndex * 50}ms` }}
                      >
                        {/* Timeline dot */}
                        <div className={cn(
                          "absolute -left-[30px] top-4 h-3 w-3 rounded-full border-2 border-background hidden sm:block",
                          isMoneyIn(tx.type) ? "bg-emerald-500" : tx.type === "transfer" ? "bg-blue-500" : "bg-rose-500"
                        )} />
                        <div className="flex items-start justify-between gap-3">
                          <div className="flex items-start gap-3 flex-1 min-w-0">
                            {/* Category emoji avatar or type icon */}
                            {tx.category && tx.type !== "transfer" ? (
                              <div
                                className={cn(
                                  "category-avatar flex-shrink-0",
                                  getCategoryIcon(tx.category).bg,
                                )}
                              >
                                <span className="text-xl">{getCategoryIcon(tx.category).emoji}</span>
                              </div>
                            ) : (
                              <div
                                className={cn(
                                  "flex h-10 w-10 sm:h-11 sm:w-11 flex-shrink-0 items-center justify-center rounded-xl",
                                  getIconStyle(tx.type),
                                )}
                              >
                                {getIcon(tx.type)}
                              </div>
                            )}

                            <div className="min-w-0 flex-1">
                              <div className="flex items-center gap-2 flex-wrap">
                                <p className="font-semibold text-foreground text-sm sm:text-base truncate">
                                  {tx.category || getTypeLabel(tx.type)}
                                </p>

                                {isLoan(tx.type) && (
                                  <span
                                    className={cn(
                                      "text-[10px] sm:text-xs px-2 py-0.5 rounded-full font-medium flex-shrink-0",
                                      tx.type === "lend" || tx.type === "repay"
                                        ? "bg-rose-100 dark:bg-rose-900/50 text-rose-700 dark:text-rose-300"
                                        : "bg-emerald-100 dark:bg-emerald-900/50 text-emerald-700 dark:text-emerald-300",
                                    )}
                                  >
                                    {getTypeLabel(tx.type)}
                                  </span>
                                )}
                              </div>

                              <p className="text-xs sm:text-sm text-muted-foreground truncate">
                                {accountName}
                                {personName && (
                                  <span className="opacity-60">
                                    {" "}
                                    • {personName}
                                  </span>
                                )}
                              </p>

                              {tx.note && (
                                <p className="text-[11px] sm:text-xs text-muted-foreground mt-0.5 line-clamp-1 opacity-70">
                                  {tx.note}
                                </p>
                              )}
                            </div>
                          </div>

                          <div className="text-right flex-shrink-0">
                            <p
                              className={cn(
                                "text-base sm:text-lg font-bold",
                                getAmountStyle(tx.type),
                              )}
                            >
                              {isMoneyIn(tx.type) ? "+" : "-"}৳
                              {Number(tx.amount).toLocaleString()}
                            </p>
                            <p className="text-[10px] sm:text-xs text-muted-foreground">
                              {format(parseISO(String(tx.occurred_at)), "h:mm a")}
                            </p>
                          </div>
                        </div>

                        {/* Desktop only: dropdown on hover */}
                        <div className="hidden sm:block absolute top-3 right-3">
                          <DropdownMenu>
                            <DropdownMenuTrigger asChild>
                              <Button
                                variant="ghost"
                                size="icon"
                                className="h-8 w-8 opacity-0 group-hover:opacity-100 transition-opacity"
                              >
                                <MoreVertical className="h-4 w-4" />
                              </Button>
                            </DropdownMenuTrigger>
                            <DropdownMenuContent align="end">
                              <DropdownMenuItem onClick={() => onEdit(tx)}>
                                <Pencil className="mr-2 h-4 w-4" />
                                Edit
                              </DropdownMenuItem>
                              <DropdownMenuItem
                                onClick={() => setDeleteId(tx.id)}
                                className="text-rose-600 dark:text-rose-400 focus:text-rose-600 dark:focus:text-rose-400"
                              >
                                <Trash2 className="mr-2 h-4 w-4" />
                                Delete
                              </DropdownMenuItem>
                            </DropdownMenuContent>
                          </DropdownMenu>
                        </div>

                        {/* Mobile: swipe hint on first item */}
                        {txIndex === 0 && groupIndex === 0 && (
                          <div className="sm:hidden absolute -bottom-1 left-1/2 -translate-x-1/2 text-[10px] text-muted-foreground opacity-50">
                            ← swipe →
                          </div>
                        )}
                      </div>
                    </SwipeableCard>
                  );
                })}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Delete Confirmation Dialog */}
      <AlertDialog
        open={!!deleteId}
        onOpenChange={(open) => !open && setDeleteId(null)}
      >
        <AlertDialogContent className="mx-4 sm:mx-auto max-w-md">
          <AlertDialogHeader>
            <AlertDialogTitle>Delete Transaction</AlertDialogTitle>
            <AlertDialogDescription>
              Are you sure you want to delete this transaction? This action
              cannot be undone and will affect your account balance.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter className="flex-col sm:flex-row gap-2">
            <AlertDialogCancel disabled={deleting} className="bg-transparent">
              Cancel
            </AlertDialogCancel>
            <AlertDialogAction
              onClick={handleDelete}
              className="bg-rose-600 hover:bg-rose-700"
              disabled={deleting}
            >
              {deleting && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
              Delete
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  );
}

function Chip({
  active,
  children,
  onClick,
}: {
  active: boolean;
  children: React.ReactNode;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        "h-9 px-4 rounded-full text-sm font-medium border whitespace-nowrap transition-all active:scale-95",
        active
          ? "bg-foreground text-background border-foreground shadow-sm"
          : "bg-card text-foreground border-border hover:bg-muted active:bg-muted",
      )}
    >
      {children}
    </button>
  );
}
