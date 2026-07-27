"use client";

import { useMemo } from "react";
import { cn } from "@/lib/utils";
import { calculateFinancialHealth, type HealthScoreBreakdown } from "@/lib/smart-insights";
import type { Transaction } from "@/lib/types";
import {
  TrendingUp,
  Wallet,
  Target,
  Activity,
  PiggyBank,
  ChevronRight
} from "lucide-react";

interface FinancialHealthScoreProps {
  transactions: Transaction[];
  currentBalance: number;
  budgets?: { category: string; amount: number }[];
  className?: string;
  compact?: boolean;
}

function CircularProgress({ 
  value, 
  size = 120, 
  strokeWidth = 8,
  grade,
  emoji
}: { 
  value: number; 
  size?: number; 
  strokeWidth?: number;
  grade: string;
  emoji: string;
}) {
  const radius = (size - strokeWidth) / 2;
  const circumference = radius * 2 * Math.PI;
  const offset = circumference - (value / 100) * circumference;
  
  // Color based on score
  const getColor = () => {
    if (value >= 85) return "stroke-emerald-500";
    if (value >= 70) return "stroke-blue-500";
    if (value >= 55) return "stroke-yellow-500";
    if (value >= 40) return "stroke-orange-500";
    return "stroke-rose-500";
  };
  
  const getBgColor = () => {
    if (value >= 85) return "stroke-emerald-100 dark:stroke-emerald-900/30";
    if (value >= 70) return "stroke-blue-100 dark:stroke-blue-900/30";
    if (value >= 55) return "stroke-yellow-100 dark:stroke-yellow-900/30";
    if (value >= 40) return "stroke-orange-100 dark:stroke-orange-900/30";
    return "stroke-rose-100 dark:stroke-rose-900/30";
  };

  return (
    <div className="relative" style={{ width: size, height: size }}>
      <svg width={size} height={size} className="transform -rotate-90">
        {/* Background circle */}
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          strokeWidth={strokeWidth}
          className={getBgColor()}
        />
        {/* Progress circle */}
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          strokeWidth={strokeWidth}
          strokeDasharray={circumference}
          strokeDashoffset={offset}
          strokeLinecap="round"
          className={cn(getColor(), "transition-all duration-1000 ease-out")}
          style={{ 
            animation: "score-fill 1.5s ease-out forwards",
          }}
        />
      </svg>
      <div className="absolute inset-0 flex flex-col items-center justify-center">
        <span className="text-2xl">{emoji}</span>
        <span className="text-2xl font-bold text-foreground">{value}</span>
        <span className="text-xs font-semibold text-muted-foreground">Grade {grade}</span>
      </div>
    </div>
  );
}

function MetricBar({
  label,
  icon: Icon,
  score,
  maxScore,
  statusLabel,
  color,
  insufficientData = false,
}: {
  label: string;
  icon: typeof TrendingUp;
  score: number;
  maxScore: number;
  value: number;
  statusLabel: string;
  color: string;
  insufficientData?: boolean;
}) {
  const percentage = insufficientData ? 0 : (score / maxScore) * 100;

  return (
    <div className="space-y-1.5">
      <div className="flex items-center justify-between text-xs">
        <div className="flex items-center gap-1.5">
          <Icon className={cn("h-3.5 w-3.5", insufficientData ? "text-muted-foreground" : color)} />
          <span className="font-medium text-foreground">{label}</span>
        </div>
        <span className="text-muted-foreground">{statusLabel}</span>
      </div>
      <div className="flex items-center gap-2">
        <div className="flex-1 h-2 bg-muted rounded-full overflow-hidden">
          {insufficientData ? (
            <div className="h-full w-full rounded-full border border-dashed border-muted-foreground/30" />
          ) : (
            <div
              className={cn(
                "h-full rounded-full transition-all duration-700 ease-out",
                color.replace("text-", "bg-")
              )}
              style={{ width: `${percentage}%` }}
            />
          )}
        </div>
        <span className="text-[10px] font-medium text-muted-foreground w-10 text-right">
          {insufficientData ? "-- / --" : `${score}/${maxScore}`}
        </span>
      </div>
    </div>
  );
}

export function FinancialHealthScore({
  transactions,
  currentBalance,
  budgets,
  className,
  compact = false
}: FinancialHealthScoreProps) {
  const healthScore = useMemo(() => {
    return calculateFinancialHealth(transactions, currentBalance, budgets);
  }, [transactions, currentBalance, budgets]);

  if (compact) {
    return (
      <div className={cn(
        "rounded-xl border bg-card p-4 animate-fade-in-up",
        className
      )}>
        <div className="flex items-center gap-4">
          <CircularProgress 
            value={healthScore.overall} 
            size={80} 
            strokeWidth={6}
            grade={healthScore.grade}
            emoji={healthScore.emoji}
          />
          <div className="flex-1 min-w-0">
            <h3 className="font-semibold text-foreground">Financial Health</h3>
            <p className="text-xs text-muted-foreground mt-0.5">{healthScore.message}</p>
            <div className="flex items-center gap-1 mt-2 text-xs text-primary cursor-pointer hover:underline">
              <span>View details</span>
              <ChevronRight className="h-3 w-3" />
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className={cn(
      "rounded-xl border bg-card p-4 sm:p-5 space-y-4 animate-fade-in-up",
      className
    )}>
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-gradient-to-br from-indigo-100 to-purple-100 dark:from-indigo-900/30 dark:to-purple-900/30">
            <Activity className="h-4 w-4 text-indigo-600 dark:text-indigo-400" />
          </div>
          <div>
            <h3 className="text-sm font-semibold text-foreground">Financial Health Score</h3>
            <p className="text-[10px] text-muted-foreground">Based on your spending habits</p>
          </div>
        </div>
      </div>

      {/* Score Circle + Message */}
      <div className="flex flex-col sm:flex-row items-center gap-4 sm:gap-6">
        <CircularProgress 
          value={healthScore.overall} 
          size={120} 
          strokeWidth={10}
          grade={healthScore.grade}
          emoji={healthScore.emoji}
        />
        <div className="flex-1 text-center sm:text-left">
          <p className="text-sm font-medium text-foreground">{healthScore.message}</p>
          <p className="text-xs text-muted-foreground mt-1">
            Score out of 100 points
          </p>
        </div>
      </div>

      {/* Breakdown */}
      <div className="space-y-3 pt-3 border-t border-border">
        <h4 className="text-xs font-medium text-muted-foreground uppercase tracking-wider">
          Score Breakdown
        </h4>
        
        <MetricBar
          label="Savings Rate"
          icon={Wallet}
          score={healthScore.savingsRate.score}
          maxScore={healthScore.savingsRate.maxScore}
          value={healthScore.savingsRate.value}
          statusLabel={healthScore.savingsRate.label}
          color="text-emerald-500"
          insufficientData={healthScore.savingsRate.insufficientData}
        />

        <MetricBar
          label="Budget Adherence"
          icon={Target}
          score={healthScore.budgetAdherence.score}
          maxScore={healthScore.budgetAdherence.maxScore}
          value={healthScore.budgetAdherence.value}
          statusLabel={healthScore.budgetAdherence.label}
          color="text-blue-500"
        />

        <MetricBar
          label="Spending Consistency"
          icon={Activity}
          score={healthScore.spendingConsistency.score}
          maxScore={healthScore.spendingConsistency.maxScore}
          value={healthScore.spendingConsistency.value}
          statusLabel={healthScore.spendingConsistency.label}
          color="text-purple-500"
          insufficientData={healthScore.spendingConsistency.insufficientData}
        />

        <MetricBar
          label="Income Stability"
          icon={TrendingUp}
          score={healthScore.incomeStability.score}
          maxScore={healthScore.incomeStability.maxScore}
          value={healthScore.incomeStability.value}
          statusLabel={healthScore.incomeStability.label}
          color="text-amber-500"
          insufficientData={healthScore.incomeStability.insufficientData}
        />

        <MetricBar
          label="Financial Cushion"
          icon={PiggyBank}
          score={healthScore.financialCushion.score}
          maxScore={healthScore.financialCushion.maxScore}
          value={healthScore.financialCushion.value}
          statusLabel={healthScore.financialCushion.label}
          color="text-cyan-500"
        />
      </div>
    </div>
  );
}
