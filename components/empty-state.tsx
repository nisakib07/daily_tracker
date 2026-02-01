"use client";

import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { 
  Inbox, 
  Users, 
  PieChart, 
  Wallet, 
  TrendingUp,
  Plus,
  type LucideIcon 
} from "lucide-react";

type EmptyStateType = "transactions" | "loans" | "analytics" | "accounts" | "budget";

interface EmptyStateProps {
  type: EmptyStateType;
  onAction?: () => void;
  actionLabel?: string;
  className?: string;
}

const emptyStateConfig: Record<EmptyStateType, {
  icon: LucideIcon;
  title: string;
  description: string;
  gradient: string;
  iconColor: string;
}> = {
  transactions: {
    icon: Inbox,
    title: "No transactions yet",
    description: "Start tracking your finances by adding your first transaction",
    gradient: "from-emerald-100 to-teal-100 dark:from-emerald-900/30 dark:to-teal-900/30",
    iconColor: "text-emerald-500 dark:text-emerald-400",
  },
  loans: {
    icon: Users,
    title: "No loans or borrows",
    description: "When you lend or borrow money, it will appear here to help you track balances",
    gradient: "from-amber-100 to-orange-100 dark:from-amber-900/30 dark:to-orange-900/30",
    iconColor: "text-amber-500 dark:text-amber-400",
  },
  analytics: {
    icon: PieChart,
    title: "No data to analyze",
    description: "Add some transactions to see your spending patterns and trends",
    gradient: "from-blue-100 to-indigo-100 dark:from-blue-900/30 dark:to-indigo-900/30",
    iconColor: "text-blue-500 dark:text-blue-400",
  },
  accounts: {
    icon: Wallet,
    title: "No accounts found",
    description: "Set up your accounts to start managing your money",
    gradient: "from-violet-100 to-purple-100 dark:from-violet-900/30 dark:to-purple-900/30",
    iconColor: "text-violet-500 dark:text-violet-400",
  },
  budget: {
    icon: TrendingUp,
    title: "No budget set",
    description: "Create a budget to track your spending against your goals",
    gradient: "from-rose-100 to-pink-100 dark:from-rose-900/30 dark:to-pink-900/30",
    iconColor: "text-rose-500 dark:text-rose-400",
  },
};

export function EmptyState({ type, onAction, actionLabel, className }: EmptyStateProps) {
  const config = emptyStateConfig[type];
  const Icon = config.icon;

  return (
    <div className={cn(
      "flex flex-col items-center justify-center py-10 sm:py-16 text-center animate-fade-in-up",
      className
    )}>
      {/* Illustrated Icon Container with floating animation */}
      <div className={cn(
        "relative flex h-24 w-24 sm:h-28 sm:w-28 items-center justify-center rounded-full mb-6 animate-float",
        "bg-gradient-to-br",
        config.gradient
      )}>
        {/* Outer decorative ring - slow spin */}
        <div className="absolute inset-0 rounded-full border-2 border-dashed border-current opacity-20 animate-[spin_20s_linear_infinite]" />
        
        {/* Inner decorative ring */}
        <div className="absolute inset-3 rounded-full border border-current opacity-10 animate-[spin_15s_linear_infinite_reverse]" />
        
        {/* Main icon with bounce */}
        <Icon className={cn("h-10 w-10 sm:h-12 sm:w-12 animate-bounce-in", config.iconColor)} />
        
        {/* Floating sparkle dots */}
        <div className="absolute -top-2 -right-2 h-4 w-4 rounded-full bg-gradient-to-br from-yellow-300 to-amber-400 dark:from-yellow-400 dark:to-amber-500 animate-sparkle shadow-lg" />
        <div className="absolute -bottom-1 -left-3 h-3 w-3 rounded-full bg-gradient-to-br from-blue-300 to-indigo-400 dark:from-blue-400 dark:to-indigo-500 animate-sparkle shadow-lg" style={{ animationDelay: "0.5s" }} />
        <div className="absolute top-1/2 -right-4 h-2 w-2 rounded-full bg-gradient-to-br from-pink-300 to-rose-400 dark:from-pink-400 dark:to-rose-500 animate-sparkle shadow-lg" style={{ animationDelay: "1s" }} />
        
        {/* Floating decorative elements */}
        <div className="absolute -top-4 left-1/4 text-lg animate-float-delayed opacity-60">✨</div>
        <div className="absolute -bottom-3 right-1/4 text-sm animate-float-slow opacity-50">💫</div>
      </div>

      {/* Text Content */}
      <h3 className="font-semibold text-foreground text-base sm:text-lg mb-1.5">
        {config.title}
      </h3>
      <p className="text-sm text-muted-foreground max-w-xs mb-5">
        {config.description}
      </p>

      {/* Action Button */}
      {onAction && (
        <Button
          onClick={onAction}
          className="bg-gradient-to-r from-emerald-500 to-emerald-600 hover:from-emerald-600 hover:to-emerald-700 shadow-lg shadow-emerald-500/25 transition-all hover:shadow-emerald-500/40"
        >
          <Plus className="mr-2 h-4 w-4" />
          {actionLabel || "Get Started"}
        </Button>
      )}
    </div>
  );
}
