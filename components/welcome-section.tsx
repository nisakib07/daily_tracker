"use client";

import { useMemo } from "react";
import { AnimatedCounter } from "@/components/animated-counter";
import { TrendingUp, TrendingDown, Sparkles } from "lucide-react";
import { cn } from "@/lib/utils";

interface WelcomeSectionProps {
  userName?: string;
  totalBalance: number;
  previousBalance?: number;
}

export function WelcomeSection({
  userName,
  totalBalance,
  previousBalance,
}: WelcomeSectionProps) {
  const greeting = useMemo(() => {
    const hour = new Date().getHours();
    if (hour < 12) return "Good morning";
    if (hour < 17) return "Good afternoon";
    return "Good evening";
  }, []);

  const displayName = userName?.split("@")[0] || "there";
  const balanceChange = previousBalance !== undefined 
    ? totalBalance - previousBalance 
    : 0;
  const hasPositiveChange = balanceChange > 0;

  // Financial health indicator based on balance
  const healthStatus = useMemo(() => {
    if (totalBalance > 50000) return { label: "Excellent", color: "text-emerald-600 dark:text-emerald-400", bg: "bg-emerald-100 dark:bg-emerald-900/50" };
    if (totalBalance > 10000) return { label: "Good", color: "text-blue-600 dark:text-blue-400", bg: "bg-blue-100 dark:bg-blue-900/50" };
    if (totalBalance > 0) return { label: "Fair", color: "text-amber-600 dark:text-amber-400", bg: "bg-amber-100 dark:bg-amber-900/50" };
    return { label: "Needs attention", color: "text-rose-600 dark:text-rose-400", bg: "bg-rose-100 dark:bg-rose-900/50" };
  }, [totalBalance]);

  return (
    <div className="animate-fade-in-up">
      <div className="flex items-start justify-between gap-4">
        <div className="space-y-1">
          <p className="text-sm text-muted-foreground font-medium">
            {greeting}, <span className="text-foreground">{displayName}</span>
          </p>
          <div className="flex items-baseline gap-2 flex-wrap">
            <span className="text-[10px] sm:text-xs text-muted-foreground uppercase tracking-wide">
              Total Balance
            </span>
            {balanceChange !== 0 && (
              <div className={cn(
                "flex items-center gap-0.5 text-[10px] sm:text-xs font-medium px-1.5 py-0.5 rounded-full",
                hasPositiveChange 
                  ? "text-emerald-600 dark:text-emerald-400 bg-emerald-50 dark:bg-emerald-950/50" 
                  : "text-rose-600 dark:text-rose-400 bg-rose-50 dark:bg-rose-950/50"
              )}>
                {hasPositiveChange ? (
                  <TrendingUp className="h-3 w-3" />
                ) : (
                  <TrendingDown className="h-3 w-3" />
                )}
                <span>
                  {hasPositiveChange ? "+" : ""}
                  {balanceChange.toLocaleString()}
                </span>
              </div>
            )}
          </div>
          <div className={cn(
            "text-2xl sm:text-3xl font-bold animate-count-up",
            totalBalance >= 0 ? "text-emerald-600 dark:text-emerald-400" : "text-rose-600 dark:text-rose-400"
          )}>
            <AnimatedCounter 
              value={totalBalance} 
              prefix="৳" 
              duration={1200}
            />
          </div>
        </div>

        {/* Financial Health Indicator */}
        <div className={cn(
          "flex items-center gap-1.5 px-2.5 py-1.5 rounded-full text-xs font-medium animate-scale-in animation-delay-300",
          healthStatus.bg
        )}>
          <Sparkles className={cn("h-3.5 w-3.5", healthStatus.color)} />
          <span className={healthStatus.color}>{healthStatus.label}</span>
        </div>
      </div>
    </div>
  );
}
