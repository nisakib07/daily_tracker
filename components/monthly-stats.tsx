"use client";

import { useState, useMemo } from "react";
import { Button } from "@/components/ui/button";
import { Calendar } from "@/components/ui/calendar";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";
import type { Transaction } from "@/lib/types";
import { CalendarIcon, TrendingUp, TrendingDown, CreditCard, ChevronLeft, ChevronRight, ArrowUpRight, ArrowDownRight } from "lucide-react";
import { format, startOfMonth, endOfMonth, subMonths, addMonths } from "date-fns";
import { cn } from "@/lib/utils";

interface MonthlyStatsProps {
  transactions: Transaction[];
  onMonthChange?: (month: Date) => void;
}

// Animated ring chart component
function RingChart({ 
  percentage, 
  color, 
  size = 60,
  strokeWidth = 6,
  showPulse = false 
}: { 
  percentage: number; 
  color: string; 
  size?: number;
  strokeWidth?: number;
  showPulse?: boolean;
}) {
  const radius = (size - strokeWidth) / 2;
  const circumference = 2 * Math.PI * radius;
  const offset = circumference - (percentage / 100) * circumference;
  
  return (
    <div className="relative" style={{ width: size, height: size }}>
      <svg 
        width={size} 
        height={size} 
        className="transform -rotate-90"
      >
        {/* Background ring */}
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke="currentColor"
          strokeWidth={strokeWidth}
          className="text-muted/30"
        />
        {/* Animated foreground ring */}
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke={color}
          strokeWidth={strokeWidth}
          strokeLinecap="round"
          strokeDasharray={circumference}
          strokeDashoffset={offset}
          className="animate-ring transition-all duration-1000"
          style={{ 
            strokeDashoffset: offset,
            filter: showPulse ? `drop-shadow(0 0 6px ${color})` : undefined
          }}
        />
      </svg>
      {/* Center percentage */}
      <div className="absolute inset-0 flex items-center justify-center">
        <span 
          className="text-xs font-bold tabular-nums"
          style={{ color }}
        >
          {Math.round(percentage)}%
        </span>
      </div>
      {/* Pulse ring for near-limit */}
      {showPulse && (
        <div 
          className="absolute inset-0 rounded-full animate-pulse-ring opacity-30"
          style={{ 
            boxShadow: `0 0 0 2px ${color}`,
          }}
        />
      )}
    </div>
  );
}

export function MonthlyStats({ transactions, onMonthChange }: MonthlyStatsProps) {
  const [selectedMonth, setSelectedMonth] = useState<Date>(new Date());
  const [calendarOpen, setCalendarOpen] = useState(false);

  const handleMonthChange = (newMonth: Date) => {
    setSelectedMonth(newMonth);
    onMonthChange?.(newMonth);
  };

  const goToPreviousMonth = () => handleMonthChange(subMonths(selectedMonth, 1));
  const goToNextMonth = () => handleMonthChange(addMonths(selectedMonth, 1));
  const goToCurrentMonth = () => handleMonthChange(new Date());

  const isCurrentMonth = 
    format(selectedMonth, "yyyy-MM") === format(new Date(), "yyyy-MM");

  // Filter transactions for selected month
  const monthStart = startOfMonth(selectedMonth);
  const monthEnd = endOfMonth(selectedMonth);

  const monthlyTransactions = transactions.filter((tx) => {
    const txDate = new Date(tx.date);
    return txDate >= monthStart && txDate <= monthEnd;
  });

  // Calculate monthly summary
  const monthlySummary = monthlyTransactions.reduce(
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

  const netBalance = monthlySummary.income - monthlySummary.expense;

  // Calculate previous month for comparison
  const prevMonthStart = startOfMonth(subMonths(selectedMonth, 1));
  const prevMonthEnd = endOfMonth(subMonths(selectedMonth, 1));
  
  const prevMonthSummary = useMemo(() => {
    const prevTxs = transactions.filter((tx) => {
      const txDate = new Date(tx.date);
      return txDate >= prevMonthStart && txDate <= prevMonthEnd;
    });
    
    return prevTxs.reduce(
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
  }, [transactions, prevMonthStart, prevMonthEnd]);

  // Calculate percentage changes
  const incomeChange = prevMonthSummary.income > 0 
    ? ((monthlySummary.income - prevMonthSummary.income) / prevMonthSummary.income) * 100 
    : 0;
  const expenseChange = prevMonthSummary.expense > 0 
    ? ((monthlySummary.expense - prevMonthSummary.expense) / prevMonthSummary.expense) * 100 
    : 0;

  // Calculate category-wise expenses for the month with ring chart data
  const categoryData = useMemo(() => {
    const categoryExpenses = monthlyTransactions
      .filter(tx => tx.type === "expense" && tx.category)
      .reduce((acc, tx) => {
        const category = tx.category || "Other";
        acc[category] = (acc[category] || 0) + Number(tx.amount);
        return acc;
      }, {} as Record<string, number>);

    const total = monthlySummary.expense || 1;
    
    return Object.entries(categoryExpenses)
      .sort(([, a], [, b]) => b - a)
      .slice(0, 4)
      .map(([name, value], index) => ({
        name,
        value,
        percentage: (value / total) * 100,
        color: ["#10b981", "#3b82f6", "#f59e0b", "#ec4899"][index % 4],
      }));
  }, [monthlyTransactions, monthlySummary.expense]);

  // Calculate savings rate
  const savingsRate = monthlySummary.income > 0 
    ? ((monthlySummary.income - monthlySummary.expense) / monthlySummary.income) * 100 
    : 0;

  return (
    <div className="rounded-xl border bg-card p-4 sm:p-6 space-y-4 animate-fade-in-up glass">
      {/* Header with Month Selector */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <h3 className="text-xs sm:text-sm font-semibold text-muted-foreground uppercase tracking-wide">
          Monthly Summary
        </h3>
        
        <div className="flex items-center gap-1 sm:gap-2">
          <Button
            variant="outline"
            size="icon"
            onClick={goToPreviousMonth}
            className="h-7 w-7 sm:h-8 sm:w-8 shrink-0 bg-transparent"
          >
            <ChevronLeft className="h-4 w-4" />
            <span className="sr-only">Previous month</span>
          </Button>
          
          <Popover open={calendarOpen} onOpenChange={setCalendarOpen}>
            <PopoverTrigger asChild>
              <Button
                variant="outline"
                className={cn(
                  "min-w-[100px] sm:min-w-[140px] justify-start text-left font-medium text-xs sm:text-sm h-7 sm:h-8 bg-transparent",
                  isCurrentMonth && "border-emerald-500 text-emerald-600"
                )}
              >
                <CalendarIcon className="mr-1.5 sm:mr-2 h-3 w-3 sm:h-3.5 sm:w-3.5" />
                {format(selectedMonth, "MMM yyyy")}
              </Button>
            </PopoverTrigger>
            <PopoverContent className="w-auto p-0" align="end">
              <Calendar
                mode="single"
                selected={selectedMonth}
                onSelect={(date) => {
                  if (date) {
                    handleMonthChange(date);
                    setCalendarOpen(false);
                  }
                }}
                initialFocus
              />
            </PopoverContent>
          </Popover>

          <Button
            variant="outline"
            size="icon"
            onClick={goToNextMonth}
            disabled={isCurrentMonth}
            className="h-7 w-7 sm:h-8 sm:w-8 shrink-0 bg-transparent"
          >
            <ChevronRight className="h-4 w-4" />
            <span className="sr-only">Next month</span>
          </Button>

          {!isCurrentMonth && (
            <Button
              variant="ghost"
              size="sm"
              onClick={goToCurrentMonth}
              className="text-emerald-600 hover:text-emerald-700 hover:bg-emerald-50 hidden sm:flex h-8 text-xs"
            >
              This Month
            </Button>
          )}
        </div>
      </div>

      {/* Monthly Stats Grid with Comparison */}
      <div className="grid grid-cols-3 gap-2 sm:gap-3">
        {/* Income Card */}
        <div className="rounded-lg bg-gradient-to-br from-emerald-50 to-emerald-100/50 dark:from-emerald-950/50 dark:to-emerald-900/30 p-3 sm:p-4 border border-emerald-100 dark:border-emerald-800/50">
          <div className="flex items-center justify-between mb-1 sm:mb-2">
            <p className="text-[10px] sm:text-xs font-medium text-emerald-600 dark:text-emerald-400 uppercase tracking-wide">
              Income
            </p>
            <TrendingUp className="h-3 w-3 sm:h-4 sm:w-4 text-emerald-600 dark:text-emerald-400" />
          </div>
          <p className="text-lg sm:text-2xl font-bold text-emerald-700 dark:text-emerald-300">
            +৳{monthlySummary.income.toLocaleString()}
          </p>
          <div className="flex items-center gap-1 mt-0.5 sm:mt-1">
            <span className="text-[10px] sm:text-xs text-emerald-600 dark:text-emerald-400">
              {monthlyTransactions.filter(tx => ["income", "borrow", "receive"].includes(tx.type)).length} txns
            </span>
            {incomeChange !== 0 && (
              <span className={cn(
                "flex items-center text-[9px] sm:text-[10px] font-medium",
                incomeChange > 0 ? "text-emerald-600" : "text-rose-600"
              )}>
                {incomeChange > 0 ? <ArrowUpRight className="h-2.5 w-2.5" /> : <ArrowDownRight className="h-2.5 w-2.5" />}
                {Math.abs(incomeChange).toFixed(0)}%
              </span>
            )}
          </div>
        </div>

        {/* Expense Card */}
        <div className="rounded-lg bg-gradient-to-br from-rose-50 to-rose-100/50 dark:from-rose-950/50 dark:to-rose-900/30 p-3 sm:p-4 border border-rose-100 dark:border-rose-800/50">
          <div className="flex items-center justify-between mb-1 sm:mb-2">
            <p className="text-[10px] sm:text-xs font-medium text-rose-600 dark:text-rose-400 uppercase tracking-wide">
              Expense
            </p>
            <TrendingDown className="h-3 w-3 sm:h-4 sm:w-4 text-rose-600 dark:text-rose-400" />
          </div>
          <p className="text-lg sm:text-2xl font-bold text-rose-700 dark:text-rose-300">
            -৳{monthlySummary.expense.toLocaleString()}
          </p>
          <div className="flex items-center gap-1 mt-0.5 sm:mt-1">
            <span className="text-[10px] sm:text-xs text-rose-600 dark:text-rose-400">
              {monthlyTransactions.filter(tx => ["expense", "lend", "repay"].includes(tx.type)).length} txns
            </span>
            {expenseChange !== 0 && (
              <span className={cn(
                "flex items-center text-[9px] sm:text-[10px] font-medium",
                expenseChange < 0 ? "text-emerald-600" : "text-rose-600"
              )}>
                {expenseChange > 0 ? <ArrowUpRight className="h-2.5 w-2.5" /> : <ArrowDownRight className="h-2.5 w-2.5" />}
                {Math.abs(expenseChange).toFixed(0)}%
              </span>
            )}
          </div>
        </div>

        {/* Net Balance Card */}
        <div className={cn(
          "rounded-lg p-3 sm:p-4 border",
          netBalance >= 0 
            ? "bg-gradient-to-br from-blue-50 to-indigo-100/50 dark:from-blue-950/50 dark:to-indigo-900/30 border-blue-100 dark:border-blue-800/50"
            : "bg-gradient-to-br from-amber-50 to-amber-100/50 dark:from-amber-950/50 dark:to-amber-900/30 border-amber-100 dark:border-amber-800/50"
        )}>
          <div className="flex items-center justify-between mb-1 sm:mb-2">
            <p className={cn(
              "text-[10px] sm:text-xs font-medium uppercase tracking-wide",
              netBalance >= 0 ? "text-blue-600 dark:text-blue-400" : "text-amber-600 dark:text-amber-400"
            )}>
              Net
            </p>
            <CreditCard className={cn(
              "h-3 w-3 sm:h-4 sm:w-4",
              netBalance >= 0 ? "text-blue-600 dark:text-blue-400" : "text-amber-600 dark:text-amber-400"
            )} />
          </div>
          <p className={cn(
            "text-lg sm:text-2xl font-bold",
            netBalance >= 0 ? "text-blue-700 dark:text-blue-300" : "text-amber-700 dark:text-amber-300"
          )}>
            {netBalance >= 0 ? "+" : ""}৳{netBalance.toLocaleString()}
          </p>
          <p className={cn(
            "text-[10px] sm:text-xs mt-0.5 sm:mt-1",
            netBalance >= 0 ? "text-blue-600 dark:text-blue-400" : "text-amber-600 dark:text-amber-400"
          )}>
            {netBalance >= 0 ? "Surplus" : "Deficit"}
          </p>
        </div>
      </div>

      {/* Category Ring Charts */}
      {categoryData.length > 0 && (
        <div className="pt-2 sm:pt-4 border-t border-border">
          <div className="flex items-center justify-between mb-3">
            <h4 className="text-xs font-medium text-muted-foreground">
              Top Expenses
            </h4>
            {savingsRate > 0 && (
              <div className="flex items-center gap-1.5 text-[10px] sm:text-xs text-emerald-600 dark:text-emerald-400 font-medium">
                <span>Savings Rate:</span>
                <span className="font-bold">{savingsRate.toFixed(0)}%</span>
              </div>
            )}
          </div>
          
          <div className="grid grid-cols-4 gap-2 sm:gap-3">
            {categoryData.map((category, index) => (
              <div 
                key={category.name} 
                className={cn(
                  "flex flex-col items-center gap-1 opacity-0 animate-scale-in"
                )}
                style={{ animationDelay: `${index * 100}ms`, animationFillMode: "forwards" }}
              >
                <RingChart 
                  percentage={category.percentage} 
                  color={category.color}
                  size={48}
                  strokeWidth={5}
                  showPulse={category.percentage > 30}
                />
                <p className="text-[9px] sm:text-[10px] text-muted-foreground text-center truncate w-full">
                  {category.name}
                </p>
                <p className="text-[9px] sm:text-[10px] font-medium text-foreground">
                  ৳{category.value.toLocaleString()}
                </p>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
