"use client";

import React, { useMemo } from "react";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import type { Account, Transaction } from "@/lib/types";
import { Banknote, CreditCard, Smartphone, Settings, ArrowDownLeft, ArrowUpRight } from "lucide-react";
import { cn } from "@/lib/utils";
import { format, parseISO, subDays } from "date-fns";

interface AccountCardProps {
  account: Account & { balance?: number };
  lastTransaction?: Transaction | null;
  recentTransactions?: Transaction[];
  onEdit?: (account: Account & { balance?: number }) => void;
}

const accountStyles: Record<string, { icon: React.ReactNode; gradient: string; iconBg: string; textColor: string; glowClass: string }> = {
  cash: {
    icon: <Banknote className="h-5 w-5" />,
    gradient: "from-emerald-500 to-teal-600",
    iconBg: "bg-emerald-500",
    textColor: "text-emerald-700 dark:text-emerald-400",
    glowClass: "dark:glow-emerald",
  },
  wallet: {
    icon: <Smartphone className="h-5 w-5" />,
    gradient: "from-pink-500 to-rose-600",
    iconBg: "bg-pink-500",
    textColor: "text-pink-700 dark:text-pink-400",
    glowClass: "dark:glow-rose",
  },
  card: {
    icon: <CreditCard className="h-5 w-5" />,
    gradient: "from-blue-500 to-indigo-600",
    iconBg: "bg-violet-500",
    textColor: "text-blue-700 dark:text-blue-400",
    glowClass: "dark:glow-blue",
  },
};

// Mini sparkline component for showing recent activity trend
function Sparkline({ data, color }: { data: number[]; color: string }) {
  if (data.length < 2) return null;
  
  const max = Math.max(...data);
  const min = Math.min(...data);
  const range = max - min || 1;
  
  const width = 60;
  const height = 20;
  const padding = 2;
  
  const points = data.map((value, index) => {
    const x = padding + (index / (data.length - 1)) * (width - padding * 2);
    const y = height - padding - ((value - min) / range) * (height - padding * 2);
    return `${x},${y}`;
  }).join(" ");
  
  return (
    <svg 
      width={width} 
      height={height} 
      className="overflow-visible"
      aria-hidden="true"
    >
      <polyline
        points={points}
        fill="none"
        stroke={color}
        strokeWidth="1.5"
        strokeLinecap="round"
        strokeLinejoin="round"
        className="animate-sparkline"
      />
      {/* Dot at the end */}
      <circle
        cx={padding + (width - padding * 2)}
        cy={height - padding - ((data[data.length - 1] - min) / range) * (height - padding * 2)}
        r="2"
        fill={color}
        className="animate-pulse"
      />
    </svg>
  );
}

export function AccountCard({ account, lastTransaction, recentTransactions, onEdit }: AccountCardProps) {
  const style = accountStyles[account.type] || accountStyles.cash;
  const balance = account.balance || 0;

  // Determine if last transaction was money in or out for this account
  const isMoneyIn = lastTransaction && (
    lastTransaction.to_account_id === account.id &&
    ["income", "borrow", "receive", "transfer"].includes(lastTransaction.type)
  );

  // Calculate sparkline data from recent transactions (last 7 days balance trend)
  const sparklineData = useMemo(() => {
    if (!recentTransactions || recentTransactions.length === 0) {
      // Generate placeholder trend if no recent transactions
      return [balance * 0.9, balance * 0.95, balance * 0.92, balance * 0.98, balance];
    }
    
    // Get transactions for this account in the last 7 days
    const now = new Date();
    const weekAgo = subDays(now, 7);
    
    const relevantTxs = recentTransactions
      .filter(tx => {
        const txDate = new Date(tx.date);
        return txDate >= weekAgo && (tx.from_account_id === account.id || tx.to_account_id === account.id);
      })
      .sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());
    
    if (relevantTxs.length < 2) {
      return [balance * 0.95, balance * 0.97, balance * 0.96, balance * 0.99, balance];
    }
    
    // Build running balance
    let runningBalance = balance;
    const dataPoints: number[] = [balance];
    
    // Work backwards to get historical balances
    for (let i = relevantTxs.length - 1; i >= 0 && dataPoints.length < 6; i--) {
      const tx = relevantTxs[i];
      const amount = Number(tx.amount);
      
      if (tx.to_account_id === account.id) {
        runningBalance -= amount;
      }
      if (tx.from_account_id === account.id) {
        runningBalance += amount;
      }
      
      dataPoints.unshift(runningBalance);
    }
    
    return dataPoints;
  }, [recentTransactions, account.id, balance]);

  // Determine sparkline color based on trend
  const trendIsPositive = sparklineData.length >= 2 && 
    sparklineData[sparklineData.length - 1] >= sparklineData[0];
  const sparklineColor = trendIsPositive ? "#10b981" : "#f43f5e";

  return (
    <Card className={cn(
      "group relative overflow-hidden border-0 shadow-md hover:shadow-xl transition-all duration-300",
      "glass",
      style.glowClass,
      "animate-fade-in-up",
      "min-h-[160px] sm:min-h-[180px] flex flex-col"
    )}>
      {/* Gradient top bar */}
      <div className={cn("absolute top-0 left-0 right-0 h-1 bg-gradient-to-r", style.gradient)} />
      
      {/* Subtle gradient overlay */}
      <div className={cn(
        "absolute inset-0 opacity-5 bg-gradient-to-br pointer-events-none",
        style.gradient
      )} />
      
      {/* Edit Button */}
      {onEdit && (
        <Button
          variant="ghost"
          size="icon"
          className="absolute top-2 right-2 h-7 w-7 sm:h-8 sm:w-8 opacity-0 group-hover:opacity-100 transition-all bg-white/80 dark:bg-slate-700/80 hover:bg-white dark:hover:bg-slate-700 shadow-sm hover:scale-110"
          onClick={() => onEdit(account)}
        >
          <Settings className="h-3.5 w-3.5 sm:h-4 sm:w-4 text-slate-500 dark:text-slate-300" />
        </Button>
      )}
      
      <div className="relative p-3 sm:p-4 pt-4 sm:pt-5 flex-1 flex flex-col">
        <div className="flex items-center gap-2 sm:gap-3 mb-2 sm:mb-3">
          <div className={cn(
            "flex h-8 w-8 sm:h-10 sm:w-10 items-center justify-center rounded-lg sm:rounded-xl text-white shadow-lg transition-transform group-hover:scale-110 group-hover:rotate-3",
            `bg-gradient-to-br ${style.gradient}`
          )}>
            <span className="[&>svg]:h-4 [&>svg]:w-4 sm:[&>svg]:h-5 sm:[&>svg]:w-5">{style.icon}</span>
          </div>
          <span className="font-semibold text-foreground text-sm sm:text-base truncate">{account.name}</span>
        </div>
        
        <div className="flex items-end justify-between gap-2 flex-grow-0">
          <div>
            <p className="text-[10px] sm:text-xs text-muted-foreground uppercase tracking-wide mb-0.5">Balance</p>
            <p className={cn(
              "text-lg sm:text-2xl font-bold transition-all",
              balance >= 0 ? style.textColor : "text-rose-600"
            )}>
              ৳{balance.toLocaleString()}
            </p>
          </div>
          
          {/* Sparkline */}
          <div className="opacity-60 group-hover:opacity-100 transition-opacity">
            <Sparkline data={sparklineData} color={sparklineColor} />
          </div>
        </div>
        
        {/* Last Transaction Preview - takes remaining space */}
        {lastTransaction && (
          <div className="mt-auto pt-2 border-t border-border/50">
            <div className="flex items-center gap-1.5 text-[10px] sm:text-xs text-muted-foreground">
              {isMoneyIn ? (
                <ArrowDownLeft className="h-3 w-3 text-emerald-500" />
              ) : (
                <ArrowUpRight className="h-3 w-3 text-rose-500" />
              )}
              <span className={cn(
                "font-medium",
                isMoneyIn ? "text-emerald-600 dark:text-emerald-400" : "text-rose-600 dark:text-rose-400"
              )}>
                {isMoneyIn ? "+" : "-"}৳{Number(lastTransaction.amount).toLocaleString()}
              </span>
              <span className="truncate opacity-70">
                {lastTransaction.category || lastTransaction.type}
              </span>
            </div>
            <p className="text-[9px] sm:text-[10px] text-muted-foreground/60 mt-0.5">
              {format(parseISO(String(lastTransaction.occurred_at)), "MMM d, h:mm a")}
            </p>
          </div>
        )}
      </div>
    </Card>
  );
}
