"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Calendar } from "@/components/ui/calendar";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";
import type { Transaction } from "@/lib/types";
import { CalendarIcon, TrendingUp, TrendingDown, CreditCard, ChevronLeft, ChevronRight } from "lucide-react";
import { format, startOfMonth, endOfMonth, subMonths, addMonths } from "date-fns";
import { cn } from "@/lib/utils";

interface MonthlyStatsProps {
  transactions: Transaction[];
  onMonthChange?: (month: Date) => void;
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

  // Calculate category-wise expenses for the month
  const categoryExpenses = monthlyTransactions
    .filter(tx => tx.type === "expense" && tx.category)
    .reduce((acc, tx) => {
      const category = tx.category || "Other";
      acc[category] = (acc[category] || 0) + Number(tx.amount);
      return acc;
    }, {} as Record<string, number>);

  const sortedCategories = Object.entries(categoryExpenses)
    .sort(([, a], [, b]) => b - a)
    .slice(0, 5);

  return (
    <div className="rounded-xl border bg-card p-4 sm:p-6 space-y-4">
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

      {/* Monthly Stats Grid */}
      <div className="grid grid-cols-3 gap-2 sm:gap-3">
        {/* Income Card */}
        <div className="rounded-lg bg-gradient-to-br from-emerald-50 to-emerald-100/50 p-3 sm:p-4 border border-emerald-100">
          <div className="flex items-center justify-between mb-1 sm:mb-2">
            <p className="text-[10px] sm:text-xs font-medium text-emerald-600 uppercase tracking-wide">
              Income
            </p>
            <TrendingUp className="h-3 w-3 sm:h-4 sm:w-4 text-emerald-600" />
          </div>
          <p className="text-lg sm:text-2xl font-bold text-emerald-700">
            +৳{monthlySummary.income.toLocaleString()}
          </p>
          <p className="text-[10px] sm:text-xs text-emerald-600 mt-0.5 sm:mt-1">
            {monthlyTransactions.filter(tx => ["income", "borrow", "receive"].includes(tx.type)).length} txns
          </p>
        </div>

        {/* Expense Card */}
        <div className="rounded-lg bg-gradient-to-br from-rose-50 to-rose-100/50 p-3 sm:p-4 border border-rose-100">
          <div className="flex items-center justify-between mb-1 sm:mb-2">
            <p className="text-[10px] sm:text-xs font-medium text-rose-600 uppercase tracking-wide">
              Expense
            </p>
            <TrendingDown className="h-3 w-3 sm:h-4 sm:w-4 text-rose-600" />
          </div>
          <p className="text-lg sm:text-2xl font-bold text-rose-700">
            -৳{monthlySummary.expense.toLocaleString()}
          </p>
          <p className="text-[10px] sm:text-xs text-rose-600 mt-0.5 sm:mt-1">
            {monthlyTransactions.filter(tx => ["expense", "lend", "repay"].includes(tx.type)).length} txns
          </p>
        </div>

        {/* Net Balance Card */}
        <div className={cn(
          "rounded-lg p-3 sm:p-4 border",
          netBalance >= 0 
            ? "bg-gradient-to-br from-blue-50 to-indigo-100/50 border-blue-100"
            : "bg-gradient-to-br from-amber-50 to-amber-100/50 border-amber-100"
        )}>
          <div className="flex items-center justify-between mb-1 sm:mb-2">
            <p className={cn(
              "text-[10px] sm:text-xs font-medium uppercase tracking-wide",
              netBalance >= 0 ? "text-blue-600" : "text-amber-600"
            )}>
              Net
            </p>
            <CreditCard className={cn(
              "h-3 w-3 sm:h-4 sm:w-4",
              netBalance >= 0 ? "text-blue-600" : "text-amber-600"
            )} />
          </div>
          <p className={cn(
            "text-lg sm:text-2xl font-bold",
            netBalance >= 0 ? "text-blue-700" : "text-amber-700"
          )}>
            {netBalance >= 0 ? "+" : ""}৳{netBalance.toLocaleString()}
          </p>
          <p className={cn(
            "text-[10px] sm:text-xs mt-0.5 sm:mt-1",
            netBalance >= 0 ? "text-blue-600" : "text-amber-600"
          )}>
            {netBalance >= 0 ? "Surplus" : "Deficit"}
          </p>
        </div>
      </div>

      {/* Top Expense Categories */}
      {sortedCategories.length > 0 && (
        <div className="pt-2 sm:pt-4 border-t">
          <h4 className="text-xs font-medium text-muted-foreground mb-2 sm:mb-3">
            Top Expenses This Month
          </h4>
          <div className="space-y-2">
            {sortedCategories.map(([category, amount]) => {
              const percentage = (amount / monthlySummary.expense) * 100;
              return (
                <div key={category} className="space-y-1">
                  <div className="flex items-center justify-between text-xs sm:text-sm">
                    <span className="text-foreground font-medium truncate">{category}</span>
                    <span className="text-muted-foreground ml-2">৳{amount.toLocaleString()}</span>
                  </div>
                  <div className="h-1.5 sm:h-2 bg-slate-100 rounded-full overflow-hidden">
                    <div 
                      className="h-full bg-gradient-to-r from-rose-400 to-rose-500 rounded-full transition-all duration-500"
                      style={{ width: `${percentage}%` }}
                    />
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
}
