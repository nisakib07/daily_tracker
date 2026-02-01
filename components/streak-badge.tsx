"use client";

import { useMemo } from "react";
import { cn } from "@/lib/utils";
import type { Transaction } from "@/lib/types";
import { Flame, Zap, Trophy, Star } from "lucide-react";
import { format, differenceInDays, startOfDay, subDays } from "date-fns";

interface StreakBadgeProps {
  transactions: Transaction[];
  className?: string;
}

/**
 * Calculate the current tracking streak
 * A streak is the number of consecutive days with at least one transaction
 */
function calculateStreak(transactions: Transaction[]): {
  currentStreak: number;
  longestStreak: number;
  isActiveToday: boolean;
} {
  if (transactions.length === 0) {
    return { currentStreak: 0, longestStreak: 0, isActiveToday: false };
  }

  // Get unique dates with transactions
  const datesWithTx = new Set<string>();
  transactions.forEach((tx) => {
    const dateKey = format(new Date(tx.date), "yyyy-MM-dd");
    datesWithTx.add(dateKey);
  });

  const sortedDates = Array.from(datesWithTx).sort().reverse(); // Most recent first
  const today = format(startOfDay(new Date()), "yyyy-MM-dd");
  const yesterday = format(subDays(startOfDay(new Date()), 1), "yyyy-MM-dd");

  // Check if active today
  const isActiveToday = sortedDates[0] === today;
  
  // Calculate current streak
  let currentStreak = 0;
  let checkDate = isActiveToday ? today : yesterday;
  
  // If neither today nor yesterday has activity, streak is broken
  if (!isActiveToday && sortedDates[0] !== yesterday) {
    currentStreak = 0;
  } else {
    // Count consecutive days
    for (let i = 0; i < 365; i++) { // Max 365 days
      const dateToCheck = format(subDays(startOfDay(new Date()), isActiveToday ? i : i + 1), "yyyy-MM-dd");
      if (datesWithTx.has(dateToCheck)) {
        currentStreak++;
      } else {
        break;
      }
    }
  }

  // Calculate longest streak (simplified)
  let longestStreak = currentStreak;
  let tempStreak = 0;
  const allDates = Array.from(datesWithTx).sort();
  
  for (let i = 0; i < allDates.length; i++) {
    if (i === 0) {
      tempStreak = 1;
    } else {
      const prevDate = new Date(allDates[i - 1]);
      const currDate = new Date(allDates[i]);
      if (differenceInDays(currDate, prevDate) === 1) {
        tempStreak++;
      } else {
        longestStreak = Math.max(longestStreak, tempStreak);
        tempStreak = 1;
      }
    }
  }
  longestStreak = Math.max(longestStreak, tempStreak);

  return { currentStreak, longestStreak, isActiveToday };
}

function getStreakInfo(streak: number) {
  if (streak >= 30) {
    return {
      icon: Trophy,
      label: "Champion",
      color: "from-yellow-400 to-amber-500",
      textColor: "text-yellow-600 dark:text-yellow-400",
      bgColor: "bg-yellow-100 dark:bg-yellow-900/30",
    };
  } else if (streak >= 14) {
    return {
      icon: Star,
      label: "Star",
      color: "from-purple-400 to-violet-500",
      textColor: "text-purple-600 dark:text-purple-400",
      bgColor: "bg-purple-100 dark:bg-purple-900/30",
    };
  } else if (streak >= 7) {
    return {
      icon: Zap,
      label: "On Fire",
      color: "from-orange-400 to-red-500",
      textColor: "text-orange-600 dark:text-orange-400",
      bgColor: "bg-orange-100 dark:bg-orange-900/30",
    };
  } else {
    return {
      icon: Flame,
      label: "Building",
      color: "from-emerald-400 to-teal-500",
      textColor: "text-emerald-600 dark:text-emerald-400",
      bgColor: "bg-emerald-100 dark:bg-emerald-900/30",
    };
  }
}

export function StreakBadge({ transactions, className }: StreakBadgeProps) {
  const streakData = useMemo(() => calculateStreak(transactions), [transactions]);
  const streakInfo = getStreakInfo(streakData.currentStreak);
  const Icon = streakInfo.icon;

  if (streakData.currentStreak === 0) {
    return (
      <div className={cn(
        "flex items-center gap-2 px-4 py-2 rounded-full border",
        "bg-gradient-to-r from-slate-100 to-slate-50 dark:from-slate-800 dark:to-slate-900",
        "border-slate-200 dark:border-slate-700",
        "text-slate-600 dark:text-slate-300 text-sm font-medium",
        "shadow-sm",
        className
      )}>
        <Flame className="h-4 w-4 text-orange-400" />
        <span>🔥 Start your streak!</span>
      </div>
    );
  }

  return (
    <div className={cn(
      "group relative flex items-center gap-2 px-3 py-1.5 rounded-full cursor-pointer",
      "transition-all duration-300 hover:scale-105",
      streakInfo.bgColor,
      streakData.currentStreak >= 7 && "streak-glow",
      className
    )}>
      {/* Animated icon */}
      <div className={cn(
        "flex items-center justify-center",
        streakData.currentStreak >= 3 && "animate-flame"
      )}>
        <Icon className={cn("h-4 w-4", streakInfo.textColor)} />
      </div>
      
      {/* Streak count */}
      <div className="flex items-center gap-1">
        <span className={cn("font-bold text-sm", streakInfo.textColor)}>
          {streakData.currentStreak}
        </span>
        <span className={cn("text-xs font-medium", streakInfo.textColor)}>
          day{streakData.currentStreak > 1 ? "s" : ""}
        </span>
      </div>

      {/* Tooltip on hover */}
      <div className={cn(
        "absolute bottom-full left-1/2 -translate-x-1/2 mb-2 px-3 py-2 rounded-lg",
        "bg-popover text-popover-foreground border shadow-lg",
        "opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none",
        "whitespace-nowrap text-xs z-50"
      )}>
        <div className="text-center">
          <p className="font-semibold">{streakInfo.label} Streak! 🔥</p>
          <p className="text-muted-foreground mt-0.5">
            {streakData.isActiveToday ? "Active today" : "Log a transaction to continue!"}
          </p>
          {streakData.longestStreak > streakData.currentStreak && (
            <p className="text-muted-foreground">
              Best: {streakData.longestStreak} days
            </p>
          )}
        </div>
        {/* Arrow */}
        <div className="absolute top-full left-1/2 -translate-x-1/2 border-4 border-transparent border-t-popover" />
      </div>

      {/* Today indicator dot */}
      {streakData.isActiveToday && (
        <div className="absolute -top-0.5 -right-0.5 h-2 w-2 rounded-full bg-emerald-500 animate-pulse" />
      )}
    </div>
  );
}
