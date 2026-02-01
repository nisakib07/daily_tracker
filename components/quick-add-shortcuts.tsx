"use client";

import { Button } from "@/components/ui/button";
import { 
  Utensils, 
  Car,
  ShoppingBag,
  type LucideIcon 
} from "lucide-react";
import { cn } from "@/lib/utils";

interface QuickAddShortcut {
  id: string;
  label: string;
  icon: LucideIcon;
  category: string;
  defaultAmount?: number;
  color: string;
}

const shortcuts: QuickAddShortcut[] = [
  { id: "breakfast", label: "Breakfast", icon: Utensils, category: "Food & Drinks", defaultAmount: 150, color: "bg-amber-100 dark:bg-amber-900/50 text-amber-700 dark:text-amber-300 hover:bg-amber-200 dark:hover:bg-amber-900/70" },
  { id: "dinner", label: "Dinner", icon: Utensils, category: "Food & Drinks", defaultAmount: 300, color: "bg-orange-100 dark:bg-orange-900/50 text-orange-700 dark:text-orange-300 hover:bg-orange-200 dark:hover:bg-orange-900/70" },
  { id: "rickshaw", label: "Rickshaw", icon: Car, category: "Transport", defaultAmount: 100, color: "bg-blue-100 dark:bg-blue-900/50 text-blue-700 dark:text-blue-300 hover:bg-blue-200 dark:hover:bg-blue-900/70" },
  { id: "shopping", label: "Shopping", icon: ShoppingBag, category: "Shopping", color: "bg-pink-100 dark:bg-pink-900/50 text-pink-700 dark:text-pink-300 hover:bg-pink-200 dark:hover:bg-pink-900/70" },
  { id: "snacks", label: "Snacks", icon: Utensils, category: "Food & Drinks", defaultAmount: 80, color: "bg-yellow-100 dark:bg-yellow-900/50 text-yellow-700 dark:text-yellow-300 hover:bg-yellow-200 dark:hover:bg-yellow-900/70" },
];

interface QuickAddShortcutsProps {
  onSelect: (shortcut: { category: string; label: string; defaultAmount?: number }) => void;
  className?: string;
}

export function QuickAddShortcuts({ onSelect, className }: QuickAddShortcutsProps) {
  return (
    <div className={cn("space-y-2", className)}>
      <p className="text-xs text-muted-foreground font-medium uppercase tracking-wide">
        Quick Add
      </p>
      <div className="flex flex-wrap gap-2">
        {shortcuts.map((shortcut, index) => {
          const Icon = shortcut.icon;
          return (
            <Button
              key={shortcut.id}
              type="button"
              variant="ghost"
              size="sm"
              onClick={() => onSelect({ category: shortcut.category, label: shortcut.label, defaultAmount: shortcut.defaultAmount })}
              className={cn(
                "h-9 px-3 rounded-full border-0 font-medium transition-all active:scale-95 opacity-0 animate-scale-in",
                shortcut.color
              )}
              style={{ animationDelay: `${index * 50}ms`, animationFillMode: "forwards" }}
            >
              <Icon className="h-3.5 w-3.5 mr-1.5" />
              {shortcut.label}
            </Button>
          );
        })}
      </div>
    </div>
  );
}
