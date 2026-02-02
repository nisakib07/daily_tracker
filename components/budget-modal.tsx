"use client";

import { useEffect, useMemo, useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { createClient } from "@/lib/supabase/client";
import { useAuth } from "@/lib/auth-context";

type Props = {
  open: boolean;
  onOpenChange: (v: boolean) => void;
  monthKey: string; // "YYYY-MM-01"
  categories: string[];
  existingBudgets: Record<string, number>;
  onSaved: () => void;
};

export function BudgetModal({
  open,
  onOpenChange,
  monthKey,
  categories,
  existingBudgets,
  onSaved,
}: Props) {
  const { user } = useAuth();
  const [saving, setSaving] = useState(false);
  const [values, setValues] = useState<Record<string, string>>({});

  // Make sure we always show at least Uncategorized in the editor
  const editorCategories = useMemo(() => {
    const set = new Set<string>(categories);
    set.add("Uncategorized");
    return Array.from(set).sort((a, b) => a.localeCompare(b));
  }, [categories]);

  useEffect(() => {
    if (!open) return;
    const next: Record<string, string> = {};
    for (const c of editorCategories) {
      const v = existingBudgets[c];
      next[c] = typeof v === "number" ? String(v) : "";
    }
    setValues(next);
  }, [open, existingBudgets, editorCategories]);

  function setCategoryValue(category: string, value: string) {
    setValues((prev) => ({ ...prev, [category]: value }));
  }

  async function saveBudgets() {
    setSaving(true);
    const supabase = createClient();

    // Build rows for upsert
    const rows = editorCategories
      .map((category) => {
        const raw = (values[category] ?? "").trim();
        const amount = raw === "" ? null : Number(raw);

        if (amount === null) return null;
        if (Number.isNaN(amount) || amount < 0) return null;

        return {
          month: monthKey,
          category,
          amount,
          user_id: user?.id,
        };
      })
      .filter((row): row is { month: string; category: string; amount: number; user_id: string | undefined } => row !== null);

    // If no valid rows, just close
    if (rows.length === 0) {
      setSaving(false);
      onOpenChange(false);
      return;
    }

    const { error } = await supabase
      .from("budgets")
      .upsert(rows, { onConflict: "user_id,month,category" });

    if (error) {
      console.error("Save budgets error:", error.message);
      setSaving(false);
      return;
    }

    setSaving(false);
    onOpenChange(false);
    onSaved();
  }

  async function clearBudgets() {
    setSaving(true);
    const supabase = createClient();

    const { error } = await supabase
      .from("budgets")
      .delete()
      .eq("month", monthKey);
    if (error) {
      console.error("Clear budgets error:", error.message);
      setSaving(false);
      return;
    }

    setSaving(false);
    onOpenChange(false);
    onSaved();
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-lg">
        <DialogHeader>
          <DialogTitle>Set Budgets for {monthKey}</DialogTitle>
        </DialogHeader>

        <div className="space-y-3 max-h-[60vh] overflow-auto pr-1">
          {editorCategories.map((c) => (
            <div key={c} className="flex items-center gap-3">
              <div className="w-44 text-sm font-medium truncate">{c}</div>
              <Input
                inputMode="decimal"
                placeholder="0"
                value={values[c] ?? ""}
                onChange={(e) => setCategoryValue(c, e.target.value)}
              />
            </div>
          ))}
        </div>

        <div className="flex items-center justify-between gap-2 pt-2">
          <Button variant="outline" onClick={clearBudgets} disabled={saving}>
            Clear Month Budgets
          </Button>

          <div className="flex gap-2">
            <Button
              variant="outline"
              onClick={() => onOpenChange(false)}
              disabled={saving}
            >
              Cancel
            </Button>
            <Button onClick={saveBudgets} disabled={saving}>
              {saving ? "Saving..." : "Save"}
            </Button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}
