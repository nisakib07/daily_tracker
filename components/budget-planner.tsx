"use client";

import { useEffect, useMemo, useState } from "react";
import { format } from "date-fns";
import { Button } from "@/components/ui/button";
import { Progress } from "@/components/ui/progress";
import type { Transaction } from "@/lib/types";
import { createClient } from "@/lib/supabase/client";
import { BudgetModal } from "@/components/budget-modal";

type BudgetRow = {
  category: string;
  budget: number;
  spent: number;
  remaining: number;
  percent: number;
};

type Props = {
  selectedMonth: Date;
  transactions: Transaction[];
};

function monthKey(date: Date) {
  // store month as first day: YYYY-MM-01
  return format(date, "yyyy-MM-01");
}

export function BudgetPlanner({ selectedMonth, transactions }: Props) {
  const [loading, setLoading] = useState(true);
  const [budgets, setBudgets] = useState<Record<string, number>>({});
  const [editorOpen, setEditorOpen] = useState(false);

  const mKey = useMemo(() => monthKey(selectedMonth), [selectedMonth]);

  // Only expenses for the selected month
  const spentByCategory = useMemo(() => {
    const map: Record<string, number> = {};

    const start = new Date(
      selectedMonth.getFullYear(),
      selectedMonth.getMonth(),
      1,
    );
    const end = new Date(
      selectedMonth.getFullYear(),
      selectedMonth.getMonth() + 1,
      0,
      23,
      59,
      59,
      999,
    );

    for (const tx of transactions) {
      const d = new Date(tx.date);
      if (d < start || d > end) continue;

      // Budget planner MVP: only count real expenses
      if (tx.type !== "expense") continue;

      const cat =
        tx.category && tx.category.trim()
          ? tx.category.trim()
          : "Uncategorized";
      map[cat] = (map[cat] || 0) + Number(tx.amount);
    }

    return map;
  }, [transactions, selectedMonth]);

  const categories = useMemo(() => {
    // show union of categories from spending + budgets
    const set = new Set<string>([
      ...Object.keys(spentByCategory),
      ...Object.keys(budgets),
    ]);
    return Array.from(set).sort((a, b) => a.localeCompare(b));
  }, [spentByCategory, budgets]);

  const rows: BudgetRow[] = useMemo(() => {
    return categories.map((category) => {
      const spent = spentByCategory[category] || 0;
      const budget = budgets[category] ?? 0;
      const remaining = budget - spent;
      const percent =
        budget > 0 ? Math.min(100, Math.round((spent / budget) * 100)) : 0;
      return { category, spent, budget, remaining, percent };
    });
  }, [categories, spentByCategory, budgets]);

  const totals = useMemo(() => {
    const totalBudget = rows.reduce((s, r) => s + (r.budget || 0), 0);
    const totalSpent = rows.reduce((s, r) => s + (r.spent || 0), 0);
    return {
      totalBudget,
      totalSpent,
      remaining: totalBudget - totalSpent,
      percent:
        totalBudget > 0
          ? Math.min(100, Math.round((totalSpent / totalBudget) * 100))
          : 0,
    };
  }, [rows]);

  async function fetchBudgets() {
    setLoading(true);
    const supabase = createClient();

    const { data, error } = await supabase
      .from("budgets")
      .select("*")
      .eq("month", mKey);

    if (error) {
      console.error("Fetch budgets error:", error.message);
      setBudgets({});
      setLoading(false);
      return;
    }

    const map: Record<string, number> = {};
    for (const b of data || []) {
      map[b.category] = Number(b.amount);
    }
    setBudgets(map);
    setLoading(false);
  }

  useEffect(() => {
    fetchBudgets();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [mKey]);

  const monthLabel = format(selectedMonth, "MMMM yyyy");

  return (
    <div className="rounded-xl border bg-card p-4 sm:p-6 space-y-4">
      <div className="flex items-center justify-between flex-wrap gap-2">
        <div>
          <h3 className="text-base sm:text-lg font-semibold">Budget Planner</h3>
          <p className="text-xs sm:text-sm text-muted-foreground">
            {monthLabel} — set budgets and track spending by category
          </p>
        </div>

        <Button onClick={() => setEditorOpen(true)} size="sm">
          Set / Edit Budgets
        </Button>
      </div>

      {/* Totals */}
      <div className="rounded-lg border p-3 sm:p-4 space-y-2">
        <div className="flex items-center justify-between text-sm">
          <span className="font-medium">Total</span>
          <span className="text-muted-foreground">
            Spent: {totals.totalSpent.toFixed(2)} / Budget:{" "}
            {totals.totalBudget.toFixed(2)}
          </span>
        </div>
        <Progress value={totals.percent} />
        <div className="flex items-center justify-between text-xs text-muted-foreground">
          <span>{totals.percent}% used</span>
          <span>
            {totals.remaining >= 0
              ? `Remaining: ${totals.remaining.toFixed(2)}`
              : `Over: ${Math.abs(totals.remaining).toFixed(2)}`}
          </span>
        </div>
      </div>

      {/* Rows */}
      <div className="space-y-3">
        {loading ? (
          <div className="text-sm text-muted-foreground">
            Loading budgets...
          </div>
        ) : rows.length === 0 ? (
          <div className="text-sm text-muted-foreground">
            No spending or budgets found for this month yet.
          </div>
        ) : (
          rows.map((r) => {
            const warn80 = r.budget > 0 && r.percent >= 80 && r.percent < 100;
            const warn100 = r.budget > 0 && r.percent >= 100;

            return (
              <div
                key={r.category}
                className="rounded-lg border p-3 sm:p-4 space-y-2"
              >
                <div className="flex items-start justify-between gap-2">
                  <div>
                    <div className="font-medium text-sm">{r.category}</div>
                    <div className="text-xs text-muted-foreground">
                      Spent {r.spent.toFixed(2)} / Budget {r.budget.toFixed(2)}
                    </div>
                  </div>

                  <div className="text-right">
                    <div
                      className={`text-sm font-semibold ${r.remaining < 0 ? "text-red-600" : ""}`}
                    >
                      {r.remaining >= 0
                        ? `+${r.remaining.toFixed(2)}`
                        : `-${Math.abs(r.remaining).toFixed(2)}`}
                    </div>
                    <div className="text-xs text-muted-foreground">
                      {r.budget > 0 ? `${r.percent}%` : "No budget"}
                    </div>
                  </div>
                </div>

                {r.budget > 0 && <Progress value={r.percent} />}

                {warn80 && (
                  <div className="text-xs text-orange-600">
                    Warning: you used 80%+ of this budget.
                  </div>
                )}
                {warn100 && (
                  <div className="text-xs text-red-600">
                    Over budget for this category.
                  </div>
                )}
              </div>
            );
          })
        )}
      </div>

      <BudgetModal
        open={editorOpen}
        onOpenChange={setEditorOpen}
        monthKey={mKey}
        categories={categories}
        existingBudgets={budgets}
        onSaved={() => fetchBudgets()}
      />
    </div>
  );
}
