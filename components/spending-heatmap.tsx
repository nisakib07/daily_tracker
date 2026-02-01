"use client";

import { useMemo, useState } from "react";
import { format, startOfMonth, endOfMonth, eachDayOfInterval, isSameDay, subMonths, addMonths, getDay } from "date-fns";
import { cn } from "@/lib/utils";
import type { Transaction } from "@/lib/types";
import { ChevronLeft, ChevronRight, Flame } from "lucide-react";
import { Button } from "@/components/ui/button";

interface SpendingHeatmapProps {
  transactions: Transaction[];
  className?: string;
}

export function SpendingHeatmap({ transactions, className }: SpendingHeatmapProps) {
  const [currentMonth, setCurrentMonth] = useState(new Date());
  const [selectedDay, setSelectedDay] = useState<string | null>(null);

  const monthStart = startOfMonth(currentMonth);
  const monthEnd = endOfMonth(currentMonth);
  const daysInMonth = eachDayOfInterval({ start: monthStart, end: monthEnd });

  // Calculate daily spending totals
  const dailySpending = useMemo(() => {
    const spending: Record<string, number> = {};
    
    transactions.forEach((tx) => {
      if (["expense", "lend", "repay"].includes(tx.type)) {
        const dateKey = format(new Date(tx.date), "yyyy-MM-dd");
        spending[dateKey] = (spending[dateKey] || 0) + Number(tx.amount);
      }
    });
    
    return spending;
  }, [transactions]);

  // Find max spending for color scaling
  const maxSpending = useMemo(() => {
    const values = Object.values(dailySpending);
    return values.length > 0 ? Math.max(...values) : 1000;
  }, [dailySpending]);

  // Get color intensity based on spending level
  const getIntensityClass = (amount: number) => {
    if (amount === 0) return "bg-muted/30";
    const ratio = amount / maxSpending;
    
    if (ratio < 0.2) return "bg-emerald-200 dark:bg-emerald-900/50";
    if (ratio < 0.4) return "bg-yellow-200 dark:bg-yellow-900/50";
    if (ratio < 0.6) return "bg-orange-300 dark:bg-orange-800/50";
    if (ratio < 0.8) return "bg-rose-400 dark:bg-rose-700/50";
    return "bg-rose-600 dark:bg-rose-600 animate-pulse";
  };

  // Get first day offset (for calendar alignment)
  const firstDayOffset = getDay(monthStart);
  
  // Get month totals
  const monthTotal = useMemo(() => {
    return daysInMonth.reduce((sum, day) => {
      const key = format(day, "yyyy-MM-dd");
      return sum + (dailySpending[key] || 0);
    }, 0);
  }, [daysInMonth, dailySpending]);

  const dailyAverage = monthTotal / daysInMonth.length;

  const isCurrentMonth = format(currentMonth, "yyyy-MM") === format(new Date(), "yyyy-MM");

  return (
    <div className={cn("rounded-xl border bg-card p-4 sm:p-5 space-y-4 animate-fade-in-up", className)}>
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-gradient-to-br from-orange-100 to-rose-100 dark:from-orange-900/30 dark:to-rose-900/30">
            <Flame className="h-4 w-4 text-orange-600 dark:text-orange-400" />
          </div>
          <div>
            <h3 className="text-sm font-semibold text-foreground">Spending Heatmap</h3>
            <p className="text-[10px] text-muted-foreground">Daily spending intensity</p>
          </div>
        </div>

        <div className="flex items-center gap-1">
          <Button
            variant="ghost"
            size="icon"
            className="h-7 w-7"
            onClick={() => setCurrentMonth(subMonths(currentMonth, 1))}
          >
            <ChevronLeft className="h-4 w-4" />
          </Button>
          <span className="text-xs font-medium min-w-[80px] text-center">
            {format(currentMonth, "MMM yyyy")}
          </span>
          <Button
            variant="ghost"
            size="icon"
            className="h-7 w-7"
            onClick={() => setCurrentMonth(addMonths(currentMonth, 1))}
            disabled={isCurrentMonth}
          >
            <ChevronRight className="h-4 w-4" />
          </Button>
        </div>
      </div>

      {/* Day labels */}
      <div className="grid grid-cols-7 gap-1 text-center">
        {["S", "M", "T", "W", "T", "F", "S"].map((day, i) => (
          <div key={i} className="text-[10px] font-medium text-muted-foreground py-1">
            {day}
          </div>
        ))}
      </div>

      {/* Calendar grid */}
      <div className="grid grid-cols-7 gap-1">
        {/* Empty cells for offset */}
        {Array.from({ length: firstDayOffset }).map((_, i) => (
          <div key={`empty-${i}`} className="aspect-square" />
        ))}

        {/* Day cells */}
        {daysInMonth.map((day, index) => {
          const dateKey = format(day, "yyyy-MM-dd");
          const amount = dailySpending[dateKey] || 0;
          const isToday = isSameDay(day, new Date());
          const isSelected = selectedDay === dateKey;

          return (
            <button
              key={dateKey}
              onClick={() => setSelectedDay(isSelected ? null : dateKey)}
              className={cn(
                "aspect-square rounded-md flex flex-col items-center justify-center transition-all duration-300 relative group outline-none focus:ring-2 focus:ring-offset-1 focus:ring-primary/50",
                getIntensityClass(amount),
                isToday && "ring-2 ring-primary ring-offset-2",
                "hover:scale-110 hover:z-10",
                isSelected && "z-20 scale-110 ring-2 ring-primary ring-offset-1"
              )}
              style={{ animationDelay: `${index * 20}ms` }}
              title={`${format(day, "MMM d")}: ৳${amount.toLocaleString()}`}
            >
              <span className={cn(
                "text-[10px] font-medium",
                amount > 0 ? "text-foreground" : "text-muted-foreground"
              )}>
                {format(day, "d")}
              </span>
              
              {/* Tooltip on hover or selected */}
              <div className={cn(
                "absolute -bottom-8 left-1/2 -translate-x-1/2 z-20 pointer-events-none transition-opacity duration-200",
                isSelected ? "opacity-100 block" : "opacity-0 group-hover:opacity-100 hidden group-hover:block"
              )}>
                <div className="bg-popover text-popover-foreground text-[10px] px-2 py-1 rounded shadow-lg whitespace-nowrap border font-medium">
                  ৳{amount.toLocaleString()}
                </div>
                {/* Connector triangle */}
                <div className="absolute -top-1 left-1/2 -translate-x-1/2 w-2 h-2 bg-popover border-t border-l border-popover/50 rotate-45 transform" />
              </div>
            </button>
          );
        })}
      </div>

      {/* Legend and stats */}
      <div className="flex items-center justify-between pt-2 border-t border-border">
        {/* Color legend */}
        <div className="flex items-center gap-1">
          <span className="text-[10px] text-muted-foreground mr-1">Less</span>
          <div className="w-3 h-3 rounded-sm bg-muted/30" />
          <div className="w-3 h-3 rounded-sm bg-emerald-200 dark:bg-emerald-900/50" />
          <div className="w-3 h-3 rounded-sm bg-yellow-200 dark:bg-yellow-900/50" />
          <div className="w-3 h-3 rounded-sm bg-orange-300 dark:bg-orange-800/50" />
          <div className="w-3 h-3 rounded-sm bg-rose-400 dark:bg-rose-700/50" />
          <div className="w-3 h-3 rounded-sm bg-rose-600" />
          <span className="text-[10px] text-muted-foreground ml-1">More</span>
        </div>

        {/* Monthly stats */}
        <div className="text-right">
          <p className="text-[10px] text-muted-foreground">
            Avg: <span className="font-medium text-foreground">৳{Math.round(dailyAverage).toLocaleString()}/day</span>
          </p>
        </div>
      </div>
    </div>
  );
}
