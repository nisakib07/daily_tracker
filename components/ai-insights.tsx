"use client";

import { useMemo } from "react";
import { cn } from "@/lib/utils";
import { generateInsights, type Insight } from "@/lib/smart-insights";
import type { Transaction } from "@/lib/types";
import { Sparkles, AlertCircle, CheckCircle, Info, Lightbulb } from "lucide-react";

interface AIInsightsProps {
  transactions: Transaction[];
  className?: string;
}

function InsightCard({ insight }: { insight: Insight }) {
  const getTypeStyles = () => {
    switch (insight.type) {
      case "positive":
        return {
          bg: "bg-emerald-50 dark:bg-emerald-900/20",
          border: "border-emerald-200 dark:border-emerald-800/50",
          icon: CheckCircle,
          iconColor: "text-emerald-500",
        };
      case "warning":
        return {
          bg: "bg-amber-50 dark:bg-amber-900/20",
          border: "border-amber-200 dark:border-amber-800/50",
          icon: AlertCircle,
          iconColor: "text-amber-500",
        };
      case "tip":
        return {
          bg: "bg-blue-50 dark:bg-blue-900/20",
          border: "border-blue-200 dark:border-blue-800/50",
          icon: Lightbulb,
          iconColor: "text-blue-500",
        };
      default:
        return {
          bg: "bg-slate-50 dark:bg-slate-800/50",
          border: "border-slate-200 dark:border-slate-700",
          icon: Info,
          iconColor: "text-slate-500",
        };
    }
  };

  const styles = getTypeStyles();
  const Icon = styles.icon;

  return (
    <div className={cn(
      "rounded-lg border p-3 transition-all hover:shadow-sm animate-fade-in-up",
      styles.bg,
      styles.border
    )}>
      <div className="flex gap-3">
        <div className="flex-shrink-0">
          <span className="text-xl">{insight.icon}</span>
        </div>
        <div className="flex-1 min-w-0">
          <div className="flex items-start justify-between gap-2">
            <h4 className="text-sm font-medium text-foreground leading-tight">
              {insight.title}
            </h4>
            <Icon className={cn("h-4 w-4 flex-shrink-0 mt-0.5", styles.iconColor)} />
          </div>
          <p className="text-xs text-muted-foreground mt-1">
            {insight.description}
          </p>
        </div>
      </div>
    </div>
  );
}

export function AIInsights({ transactions, className }: AIInsightsProps) {
  const insights = useMemo(() => {
    return generateInsights(transactions);
  }, [transactions]);

  if (insights.length === 0) {
    return null;
  }

  return (
    <div className={cn(
      "rounded-xl border bg-card p-4 sm:p-5 space-y-4 animate-fade-in-up",
      className
    )}>
      {/* Header */}
      <div className="flex items-center gap-2">
        <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-gradient-to-br from-violet-100 to-fuchsia-100 dark:from-violet-900/30 dark:to-fuchsia-900/30">
          <Sparkles className="h-4 w-4 text-violet-600 dark:text-violet-400" />
        </div>
        <div>
          <h3 className="text-sm font-semibold text-foreground flex items-center gap-1.5">
            Smart Insights
            <span className="inline-flex items-center px-1.5 py-0.5 rounded text-[9px] font-medium bg-gradient-to-r from-violet-500 to-fuchsia-500 text-white">
              AI
            </span>
          </h3>
          <p className="text-[10px] text-muted-foreground">Powered by your spending data</p>
        </div>
      </div>

      {/* Insights List */}
      <div className="space-y-2">
        {insights.map((insight, index) => (
          <div
            key={insight.id}
            style={{ animationDelay: `${index * 100}ms` }}
          >
            <InsightCard insight={insight} />
          </div>
        ))}
      </div>

      {/* Footer tip */}
      <p className="text-[10px] text-center text-muted-foreground pt-2 border-t border-border">
        💡 Insights update automatically based on your transactions
      </p>
    </div>
  );
}
