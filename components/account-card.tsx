"use client";

import React from "react";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import type { Account } from "@/lib/types";
import { Banknote, CreditCard, Smartphone, Settings } from "lucide-react";
import { cn } from "@/lib/utils";

interface AccountCardProps {
  account: Account & { balance?: number };
  onEdit?: (account: Account & { balance?: number }) => void;
}

const accountStyles: Record<string, { icon: React.ReactNode; gradient: string; iconBg: string; textColor: string }> = {
  cash: {
    icon: <Banknote className="h-5 w-5" />,
    gradient: "from-emerald-500 to-teal-600",
    iconBg: "bg-emerald-500",
    textColor: "text-emerald-700 dark:text-emerald-400",
  },
  wallet: {
    icon: <Smartphone className="h-5 w-5" />,
    gradient: "from-pink-500 to-rose-600",
    iconBg: "bg-pink-500",
    textColor: "text-pink-700 dark:text-pink-400",
  },
  card: {
    icon: <CreditCard className="h-5 w-5" />,
    gradient: "from-violet-500 to-purple-600",
    iconBg: "bg-violet-500",
    textColor: "text-violet-700 dark:text-violet-400",
  },
};

export function AccountCard({ account, onEdit }: AccountCardProps) {
  const style = accountStyles[account.type] || accountStyles.cash;
  const balance = account.balance || 0;

  return (
    <Card className="group relative overflow-hidden border-0 bg-white dark:bg-slate-800 shadow-md hover:shadow-xl transition-all duration-300">
      {/* Gradient top bar */}
      <div className={cn("absolute top-0 left-0 right-0 h-1 bg-gradient-to-r", style.gradient)} />
      
      {/* Edit Button */}
      {onEdit && (
        <Button
          variant="ghost"
          size="icon"
          className="absolute top-2 right-2 h-8 w-8 opacity-0 group-hover:opacity-100 transition-opacity bg-white/80 dark:bg-slate-700/80 hover:bg-white dark:hover:bg-slate-700 shadow-sm"
          onClick={() => onEdit(account)}
        >
          <Settings className="h-4 w-4 text-slate-500 dark:text-slate-300" />
        </Button>
      )}
      
      <div className="p-3 sm:p-4 pt-4 sm:pt-5">
        <div className="flex items-center gap-2 sm:gap-3 mb-2 sm:mb-3">
          <div className={cn(
            "flex h-8 w-8 sm:h-10 sm:w-10 items-center justify-center rounded-lg sm:rounded-xl text-white shadow-lg transition-transform group-hover:scale-110",
            `bg-gradient-to-br ${style.gradient}`
          )}>
            <span className="[&>svg]:h-4 [&>svg]:w-4 sm:[&>svg]:h-5 sm:[&>svg]:w-5">{style.icon}</span>
          </div>
          <span className="font-semibold text-foreground text-sm sm:text-base truncate">{account.name}</span>
        </div>
        <div>
          <p className="text-[10px] sm:text-xs text-muted-foreground uppercase tracking-wide mb-0.5">Balance</p>
          <p className={cn(
            "text-lg sm:text-2xl font-bold",
            balance >= 0 ? style.textColor : "text-rose-600"
          )}>
            ৳{balance.toLocaleString()}
          </p>
        </div>
      </div>
    </Card>
  );
}
