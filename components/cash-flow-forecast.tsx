"use client";

import { useMemo } from "react";
import { cn } from "@/lib/utils";
import { calculateCashFlowForecast, type CashFlowStatus } from "@/lib/smart-insights";
import type { Transaction } from "@/lib/types";
import {
  TrendingUp,
  TrendingDown,
  Minus,
  AlertTriangle,
  Hourglass,
  Wallet,
} from "lucide-react";

interface CashFlowForecastProps {
  transactions: Transaction[];
  currentBalance: number;
  className?: string;
}

const STATUS_STYLES: Record<
  CashFlowStatus,
  { icon: typeof TrendingUp; iconClass: string; badgeClass: string }
> = {
  growing: {
    icon: TrendingUp,
    iconClass: "text-emerald-600 dark:text-emerald-400",
    badgeClass: "bg-emerald-100 dark:bg-emerald-900/30",
  },
  stable: {
    icon: Minus,
    iconClass: "text-emerald-600 dark:text-emerald-400",
    badgeClass: "bg-emerald-100 dark:bg-emerald-900/30",
  },
  declining: {
    icon: TrendingDown,
    iconClass: "text-amber-600 dark:text-amber-400",
    badgeClass: "bg-amber-100 dark:bg-amber-900/30",
  },
  critical: {
    icon: AlertTriangle,
    iconClass: "text-rose-600 dark:text-rose-400",
    badgeClass: "bg-rose-100 dark:bg-rose-900/30",
  },
  "insufficient-data": {
    icon: Hourglass,
    iconClass: "text-slate-500 dark:text-slate-400",
    badgeClass: "bg-slate-100 dark:bg-slate-800/50",
  },
};

export function CashFlowForecast({
  transactions,
  currentBalance,
  className,
}: CashFlowForecastProps) {
  const forecast = useMemo(() => {
    return calculateCashFlowForecast(transactions, currentBalance);
  }, [transactions, currentBalance]);

  const { icon: Icon, iconClass, badgeClass } = STATUS_STYLES[forecast.status];

  return (
    <div
      className={cn(
        "rounded-xl border bg-card p-4 sm:p-5 space-y-4 animate-fade-in-up",
        className,
      )}
    >
      <div className="flex items-center gap-2">
        <div className={cn("flex h-8 w-8 items-center justify-center rounded-lg", badgeClass)}>
          <Icon className={cn("h-4 w-4", iconClass)} />
        </div>
        <div>
          <h3 className="text-sm font-semibold text-foreground">Cash Flow Forecast</h3>
          <p className="text-[10px] text-muted-foreground">
            {forecast.status === "insufficient-data"
              ? "Not enough history yet"
              : `Based on the last ${forecast.daysOfHistory} days`}
          </p>
        </div>
      </div>

      <p className="text-sm text-foreground">{forecast.message}</p>

      {forecast.status !== "insufficient-data" && (
        <div className="grid grid-cols-2 gap-2 pt-1">
          <div className="rounded-lg bg-muted/50 p-2.5">
            <div className="flex items-center gap-1.5 text-[10px] text-muted-foreground">
              <Wallet className="h-3 w-3" />
              Current balance
            </div>
            <p className="text-sm font-semibold text-foreground mt-0.5">
              ৳{Math.round(forecast.currentBalance).toLocaleString()}
            </p>
          </div>
          <div className="rounded-lg bg-muted/50 p-2.5">
            <div className="flex items-center gap-1.5 text-[10px] text-muted-foreground">
              {forecast.avgDailyNetChange >= 0 ? (
                <TrendingUp className="h-3 w-3" />
              ) : (
                <TrendingDown className="h-3 w-3" />
              )}
              Daily net change
            </div>
            <p
              className={cn(
                "text-sm font-semibold mt-0.5",
                forecast.avgDailyNetChange >= 0
                  ? "text-emerald-600 dark:text-emerald-400"
                  : "text-rose-600 dark:text-rose-400",
              )}
            >
              {forecast.avgDailyNetChange >= 0 ? "+" : "-"}৳
              {Math.round(Math.abs(forecast.avgDailyNetChange)).toLocaleString()}
            </p>
          </div>
        </div>
      )}
    </div>
  );
}
