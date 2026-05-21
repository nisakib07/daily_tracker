"use client";

import React, { useMemo, useState, useRef, useCallback } from "react";
import type { Account, Investment, Transaction } from "@/lib/types";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { TrendingUp, Plus, ArrowUpRight, ArrowDownLeft, Coins, ArrowRight, Trash2, MoreVertical, Loader2 } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
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

// Swipeable card component for mobile touch gestures (left swipe to delete)
interface SwipeableCardProps {
  children: React.ReactNode;
  onSwipeLeft: () => void;
  leftLabel?: string;
}

function SwipeableCard({
  children,
  onSwipeLeft,
  leftLabel = "Delete",
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

    // Only allow swiping left (negative translateX)
    let newTranslate = currentXRef.current + diffX;
    if (newTranslate > 0) {
      newTranslate = newTranslate * 0.2; // Resist swiping right
    } else if (newTranslate < -MAX_SWIPE) {
      newTranslate = -MAX_SWIPE + (newTranslate + MAX_SWIPE) * 0.2; // Resist past max swipe
    }

    setTranslateX(newTranslate);
  }, [isDragging]);

  const handleTouchEnd = useCallback(() => {
    setIsDragging(false);
    isHorizontalSwipeRef.current = null;

    if (translateX < -SWIPE_THRESHOLD) {
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
  }, [translateX, onSwipeLeft]);

  // Calculate action opacity based on swipe distance
  const leftOpacity = Math.min(1, Math.abs(Math.min(0, translateX)) / SWIPE_THRESHOLD);

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

interface InvestmentTrackerProps {
  investments: Investment[];
  transactions: Transaction[];
  accounts: Account[];
  onNewInvestment: () => void;
  onRecordReturn: (investment: Investment) => void;
  onAddFunds: (investment: Investment) => void;
  onSuccess: () => void;
}

export function InvestmentTracker({
  investments,
  transactions,
  accounts,
  onNewInvestment,
  onRecordReturn,
  onAddFunds,
  onSuccess,
}: InvestmentTrackerProps) {
  const [deleteId, setDeleteId] = useState<string | null>(null);
  const [deleting, setDeleting] = useState(false);

  const handleDelete = async () => {
    if (!deleteId) return;

    setDeleting(true);
    const supabase = createClient();

    try {
      // 1. Delete all transactions associated with this investment
      const { error: txError } = await supabase
        .from("transactions")
        .delete()
        .eq("investment_id", deleteId);
      if (txError) throw txError;

      // 2. Delete the investment
      const { error: invError } = await supabase
        .from("investments")
        .delete()
        .eq("id", deleteId);
      if (invError) throw invError;

      onSuccess();
    } catch (error) {
      console.error("Error deleting investment:", error);
    } finally {
      setDeleting(false);
      setDeleteId(null);
    }
  };

  // 1. Memoized Portfolio Summary Calculations
  const portfolioSummary = useMemo(() => {
    const activeInvestmentsCount = investments.filter(
      (inv) => inv.status === "active"
    ).length;

    // Filter transactions to only include invest/invest_return
    const investTransactions = transactions.filter((tx) => tx.type === "invest");
    const returnTransactions = transactions.filter(
      (tx) => tx.type === "invest_return"
    );

    const totalInvested = investTransactions.reduce(
      (sum, tx) => sum + Number(tx.amount),
      0
    );
    const totalReturns = returnTransactions.reduce(
      (sum, tx) => sum + Number(tx.amount),
      0
    );

    const netPL = totalReturns - totalInvested;
    const roi = totalInvested > 0 ? (netPL / totalInvested) * 100 : 0;

    return {
      activeCount: activeInvestmentsCount,
      totalInvested,
      totalReturns,
      netPL,
      roi,
    };
  }, [investments, transactions]);

  // 2. Memoized Investment Cards Calculations & Sorting
  const processedInvestments = useMemo(() => {
    const list = investments.map((inv) => {
      // Find transactions specific to this investment
      const invTransactions = transactions.filter(
        (tx) => tx.investment_id === inv.id
      );

      const totalInvested = invTransactions
        .filter((tx) => tx.type === "invest")
        .reduce((sum, tx) => sum + Number(tx.amount), 0);

      const totalReturns = invTransactions
        .filter((tx) => tx.type === "invest_return")
        .reduce((sum, tx) => sum + Number(tx.amount), 0);

      const profitLoss = totalReturns - totalInvested;
      const roi = totalInvested > 0 ? (profitLoss / totalInvested) * 100 : 0;

      return {
        ...inv,
        totalInvested,
        totalReturns,
        profitLoss,
        roi,
      };
    });

    // Sort: active investments first, then closed.
    // Within each group, sort by created_at descending.
    return list.sort((a, b) => {
      if (a.status === "active" && b.status !== "active") return -1;
      if (a.status !== "active" && b.status === "active") return 1;

      const dateA = new Date(a.created_at).getTime();
      const dateB = new Date(b.created_at).getTime();
      return dateB - dateA;
    });
  }, [investments, transactions]);

  // Render Empty State if no investments
  if (investments.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center p-8 text-center rounded-2xl border border-dashed border-violet-200 dark:border-violet-800/50 bg-gradient-to-br from-violet-50/30 to-purple-50/10 dark:from-violet-950/10 dark:to-purple-950/5 min-h-[300px] animate-fade-in">
        <div className="relative mb-4">
          <div className="absolute inset-0 rounded-full bg-violet-100 dark:bg-violet-950/50 blur-xl animate-pulse" />
          <div className="relative flex h-14 w-14 items-center justify-center rounded-2xl bg-gradient-to-br from-violet-500 to-purple-600 text-white shadow-lg shadow-violet-500/30 animate-bounce-subtle">
            <TrendingUp className="h-7 w-7" />
          </div>
        </div>
        <h3 className="text-base font-bold text-slate-800 dark:text-slate-200">
          No investments yet
        </h3>
        <p className="text-xs text-muted-foreground max-w-[280px] mt-1 mb-5">
          Start tracking your investments to see profit & loss analytics. Keep your business and personal expenses clean!
        </p>
        <Button
          onClick={onNewInvestment}
          className="h-10 rounded-xl bg-gradient-to-r from-violet-500 to-purple-600 hover:from-violet-600 hover:to-purple-700 shadow-md shadow-violet-500/20 active:scale-95 transition-transform"
        >
          <Plus className="mr-1.5 h-4 w-4" />
          Add First Investment
        </Button>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {/* 💳 PORTFOLIO SUMMARY CARD */}
      <div className="rounded-2xl p-4 sm:p-5 bg-gradient-to-br from-violet-50 to-purple-100/50 dark:from-violet-950/50 dark:to-purple-900/30 border border-violet-100 dark:border-violet-800/50 relative overflow-hidden">
        <div className="absolute right-0 top-0 translate-x-4 -translate-y-4 opacity-5 pointer-events-none">
          <Coins className="h-32 w-32 text-violet-500" />
        </div>

        <div className="flex justify-between items-center mb-3">
          <div className="flex items-center gap-1.5">
            <span className="text-base">📊</span>
            <h3 className="text-xs font-semibold text-violet-700 dark:text-violet-300 uppercase tracking-wider">
              Investment Portfolio
            </h3>
          </div>

          {portfolioSummary.totalInvested > 0 && (
            <span
              className={cn(
                "rounded-full px-2 py-0.5 text-xs font-bold flex items-center gap-0.5",
                portfolioSummary.netPL >= 0
                  ? "bg-emerald-100 text-emerald-800 dark:bg-emerald-900/30 dark:text-emerald-300"
                  : "bg-rose-100 text-rose-800 dark:bg-rose-900/30 dark:text-rose-300"
              )}
            >
              {portfolioSummary.netPL >= 0 ? "+" : ""}
              {portfolioSummary.roi.toFixed(1)}% ROI
            </span>
          )}
        </div>

        {/* 2x2 Stats Grid */}
        <div className="grid grid-cols-2 gap-3 mt-3">
          <div className="space-y-0.5">
            <span className="text-[10px] sm:text-xs font-medium text-muted-foreground uppercase tracking-wider block">
              Active Investments
            </span>
            <p className="text-base sm:text-lg font-bold text-slate-800 dark:text-slate-200">
              {portfolioSummary.activeCount}
            </p>
          </div>

          <div className="space-y-0.5">
            <span className="text-[10px] sm:text-xs font-medium text-muted-foreground uppercase tracking-wider block">
              Total Invested
            </span>
            <p className="text-base sm:text-lg font-bold text-slate-800 dark:text-slate-200">
              ৳{portfolioSummary.totalInvested.toLocaleString()}
            </p>
          </div>

          <div className="space-y-0.5">
            <span className="text-[10px] sm:text-xs font-medium text-muted-foreground uppercase tracking-wider block">
              Total Returns
            </span>
            <p className="text-base sm:text-lg font-bold text-slate-800 dark:text-slate-200">
              ৳{portfolioSummary.totalReturns.toLocaleString()}
            </p>
          </div>

          <div className="space-y-0.5">
            <span className="text-[10px] sm:text-xs font-medium text-muted-foreground uppercase tracking-wider block">
              Net Profit / Loss
            </span>
            <p
              className={cn(
                "text-base sm:text-lg font-bold flex items-center gap-0.5",
                portfolioSummary.netPL >= 0
                  ? "text-emerald-600 dark:text-emerald-400"
                  : "text-rose-600 dark:text-rose-400"
              )}
            >
              {portfolioSummary.netPL >= 0 ? "+" : ""}৳
              {portfolioSummary.netPL.toLocaleString()}
            </p>
          </div>
        </div>
      </div>

      {/* 🚀 ACTION BUTTON */}
      <Button
        onClick={onNewInvestment}
        className="w-full h-11 rounded-xl bg-gradient-to-r from-violet-500 to-purple-600 hover:from-violet-600 hover:to-purple-700 text-white font-semibold shadow-md shadow-violet-500/10 active:scale-[0.99] transition-all flex items-center justify-center gap-1.5"
      >
        <Plus className="h-4 w-4" />
        New Investment
      </Button>

      {/* 📁 INVESTMENT CARDS LIST */}
      <div className="space-y-2.5">
        {processedInvestments.map((inv, index) => {
          const isActive = inv.status === "active";
          const isProfit = inv.profitLoss >= 0;

          return (
            <SwipeableCard
              key={inv.id}
              onSwipeLeft={() => setDeleteId(inv.id)}
            >
              <div
                className={cn(
                  "opacity-0 animate-fade-in-up rounded-xl bg-card border p-3 sm:p-4 hover:shadow-md transition-all relative",
                  "border-l-[3.5px]",
                  isActive
                    ? "border-l-violet-500"
                    : isProfit
                    ? "border-l-emerald-500"
                    : "border-l-rose-500"
                )}
                style={{
                  animationDelay: `${index * 80}ms`,
                  animationFillMode: "forwards",
                }}
              >
                {/* Header: Name and Status Badge */}
                <div className="flex justify-between items-start gap-2">
                  <div className="space-y-0.5">
                    <h4 className="font-bold text-sm text-slate-800 dark:text-slate-200">
                      {inv.name}
                    </h4>
                    {inv.description && (
                      <p className="text-xs text-muted-foreground line-clamp-1">
                        {inv.description}
                      </p>
                    )}
                  </div>

                  <div className="flex gap-1.5 items-center shrink-0">
                    <span
                      className={cn(
                        "rounded-full px-2 py-0.5 text-[9px] font-bold uppercase tracking-wider",
                        isActive
                          ? "bg-violet-100 text-violet-700 dark:bg-violet-900/30 dark:text-violet-300"
                          : "bg-slate-100 text-slate-600 dark:bg-slate-850 dark:text-slate-400"
                      )}
                    >
                      {inv.status}
                    </span>

                    {inv.totalInvested > 0 && (
                      <span
                        className={cn(
                          "rounded-full px-1.5 py-0.5 text-[9px] font-bold",
                          isProfit
                            ? "bg-emerald-50 text-emerald-700 dark:bg-emerald-950/20 dark:text-emerald-400"
                            : "bg-rose-50 text-rose-700 dark:bg-rose-950/20 dark:text-rose-400"
                        )}
                      >
                        {isProfit ? "+" : ""}
                        {inv.roi.toFixed(1)}% ROI
                      </span>
                    )}

                    {/* Desktop/Trigger Dropdown Menu */}
                    <DropdownMenu>
                      <DropdownMenuTrigger asChild>
                        <Button
                          variant="ghost"
                          size="icon"
                          className="h-6 w-6 rounded-full hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
                        >
                          <MoreVertical className="h-3.5 w-3.5 text-muted-foreground" />
                        </Button>
                      </DropdownMenuTrigger>
                      <DropdownMenuContent align="end">
                        <DropdownMenuItem
                          onClick={() => setDeleteId(inv.id)}
                          className="text-rose-600 dark:text-rose-400 focus:text-rose-600 dark:focus:text-rose-400 cursor-pointer"
                        >
                          <Trash2 className="mr-2 h-4 w-4" />
                          Delete Investment
                        </DropdownMenuItem>
                      </DropdownMenuContent>
                    </DropdownMenu>
                  </div>
                </div>

                {/* Stats Grid */}
                <div className="grid grid-cols-3 gap-2 mt-3 p-2 bg-slate-50/50 dark:bg-slate-900/30 rounded-lg border border-slate-100/50 dark:border-slate-800/30">
                  <div className="space-y-0.5">
                    <span className="text-[9px] font-semibold text-muted-foreground uppercase tracking-wider block">
                      Invested
                    </span>
                    <p className="text-xs font-bold text-slate-700 dark:text-slate-300">
                      ৳{inv.totalInvested.toLocaleString()}
                    </p>
                  </div>

                  <div className="space-y-0.5">
                    <span className="text-[9px] font-semibold text-muted-foreground uppercase tracking-wider block">
                      Returns
                    </span>
                    <p className="text-xs font-bold text-slate-700 dark:text-slate-300">
                      ৳{inv.totalReturns.toLocaleString()}
                    </p>
                  </div>

                  <div className="space-y-0.5">
                    <span className="text-[9px] font-semibold text-muted-foreground uppercase tracking-wider block">
                      Profit / Loss
                    </span>
                    <p
                      className={cn(
                        "text-xs font-bold",
                        isProfit
                          ? "text-emerald-600 dark:text-emerald-400"
                          : "text-rose-600 dark:text-rose-400"
                      )}
                    >
                      {isProfit ? "+" : ""}৳{inv.profitLoss.toLocaleString()}
                    </p>
                  </div>
                </div>

                {/* Action Buttons: Only shown if Active */}
                {isActive ? (
                  <div className="flex gap-2 mt-3 pt-1 border-t border-slate-100 dark:border-slate-800/50">
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => onAddFunds(inv)}
                      className="flex-1 h-8 rounded-lg text-xs font-semibold bg-transparent border-violet-200 dark:border-violet-800 text-violet-600 dark:text-violet-400 hover:bg-violet-50 dark:hover:bg-violet-950/30 hover:border-violet-300 active:scale-[0.98] transition-transform"
                    >
                      <Plus className="mr-1 h-3.5 w-3.5" />
                      Add Funds
                    </Button>
                    <Button
                      size="sm"
                      onClick={() => onRecordReturn(inv)}
                      className="flex-1 h-8 rounded-lg text-xs font-semibold bg-gradient-to-r from-violet-500 to-purple-600 hover:from-violet-600 hover:to-purple-700 text-white shadow-sm shadow-violet-500/10 active:scale-[0.98] transition-transform"
                    >
                      <ArrowDownLeft className="mr-1 h-3.5 w-3.5" />
                      Record Return
                    </Button>
                  </div>
                ) : (
                  <div className="flex items-center gap-1.5 mt-3 pt-2 text-[10px] text-muted-foreground border-t border-slate-100 dark:border-slate-800/50">
                    <span>🔒</span> This investment is closed. Final profit/loss is locked.
                  </div>
                )}

                {/* Mobile: swipe hint on first item */}
                {index === 0 && (
                  <div className="sm:hidden absolute -bottom-0.5 left-1/2 -translate-x-1/2 text-[8px] text-muted-foreground opacity-40 select-none">
                    ← swipe left to delete
                  </div>
                )}
              </div>
            </SwipeableCard>
          );
        })}
      </div>

      {/* Delete Confirmation Dialog */}
      <AlertDialog
        open={!!deleteId}
        onOpenChange={(open) => !open && setDeleteId(null)}
      >
        <AlertDialogContent className="mx-4 sm:mx-auto max-w-md">
          <AlertDialogHeader>
            <AlertDialogTitle>Delete Investment</AlertDialogTitle>
            <AlertDialogDescription>
              Are you sure you want to delete this investment? This action
              cannot be undone. It will also permanently delete all transactions linked to it
              and restore your account balances.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter className="flex-col sm:flex-row gap-2">
            <AlertDialogCancel disabled={deleting} className="bg-transparent">
              Cancel
            </AlertDialogCancel>
            <AlertDialogAction
              onClick={handleDelete}
              className="bg-rose-600 hover:bg-rose-700 text-white"
              disabled={deleting}
            >
              {deleting && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
              Delete
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
