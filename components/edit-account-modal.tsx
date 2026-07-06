"use client";

import React from "react";
import { useState, useEffect, useMemo } from "react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";
import {
  Drawer,
  DrawerContent,
  DrawerHeader,
  DrawerTitle,
  DrawerDescription,
} from "@/components/ui/drawer";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import type { Account, Transaction } from "@/lib/types";
import { calculateAccountBalance } from "@/lib/balances";
import { createClient } from "@/lib/supabase/client";
import { useAuth } from "@/lib/auth-context";
import { Loader2, Settings, AlertTriangle, Scale } from "lucide-react";
import { useMediaQuery } from "@/hooks/use-media-query";

interface EditAccountModalProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  account: (Account & { balance?: number }) | null;
  transactions: Transaction[];
  onSuccess: () => void | Promise<void>;
}

function EditAccountForm({
  account,
  transactions,
  onOpenChange,
  onSuccess,
}: Omit<EditAccountModalProps, 'open'>) {
  const { user } = useAuth();
  const [name, setName] = useState("");
  const [adjustmentAmount, setAdjustmentAmount] = useState("");
  const [adjustmentType, setAdjustmentType] = useState<"add" | "subtract">("add");
  const [note, setNote] = useState("");
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (account) {
      setName(account.name);
      setAdjustmentAmount("");
      setNote("");
    }
  }, [account?.id]);

  if (!account) return null;

  const currentBalance = calculateAccountBalance(account.id, transactions);
  const parsedAdjustmentAmount = Number.parseFloat(adjustmentAmount);
  const hasAdjustment =
    Number.isFinite(parsedAdjustmentAmount) && parsedAdjustmentAmount > 0;
  const previewBalance =
    currentBalance +
    (adjustmentType === "add" ? 1 : -1) * parsedAdjustmentAmount;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!account) return;

    setLoading(true);
    const supabase = createClient();

    try {
      if (name !== account.name) {
        const { error } = await supabase
          .from("accounts")
          .update({ name })
          .eq("id", account.id);
        if (error) throw error;
      }

      if (hasAdjustment) {
        if (!user?.id) throw new Error("You must be signed in to adjust balance.");

        const amount = parsedAdjustmentAmount;
        const isAdding = adjustmentType === "add";

        const { error } = await supabase.from("transactions").insert({
          type: isAdding ? "income" : "expense",
          amount,
          from_account_id: isAdding ? null : account.id,
          to_account_id: isAdding ? account.id : null,
          category: "Balance Adjustment",
          note: note || `Manual balance ${isAdding ? "increase" : "decrease"}`,
          user_id: user?.id,
          occurred_at: new Date().toISOString(),
        });

        if (error) throw error;
      }

      await onSuccess();
      onOpenChange(false);
    } catch (error) {
      console.error("[v0] Error updating account:", error);
      alert("Something went wrong while saving. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-4 pt-2">
      {/* Account Name */}
      <div className="space-y-2">
        <Label htmlFor="name" className="text-sm font-medium">Account Name</Label>
        <Input
          id="name"
          value={name}
          onChange={(e) => setName(e.target.value)}
          className="h-11 sm:h-12"
        />
      </div>

      <div className="space-y-3">
        <Label className="text-sm font-medium">Balance Adjustment (Optional)</Label>
        <div className="p-3 sm:p-4 rounded-xl bg-slate-50 dark:bg-slate-900 border border-slate-200 dark:border-slate-800">
          <div className="flex items-start gap-2 mb-3">
            <Scale className="h-4 w-4 text-slate-500 mt-0.5 flex-shrink-0" />
            <p className="text-[10px] sm:text-xs text-muted-foreground">
              Use this to align your digital balance with your real-world account. This will create an adjustment transaction.
            </p>
          </div>
          
          <div className="flex gap-2 mb-3">
            <Button
              type="button"
              variant={adjustmentType === "add" ? "default" : "outline"}
              size="sm"
              className={adjustmentType === "add" ? "bg-emerald-600 hover:bg-emerald-700 shadow-sm shadow-emerald-500/20" : "bg-transparent border-slate-200 dark:border-slate-700"}
              onClick={() => setAdjustmentType("add")}
            >
              Add Money
            </Button>
            <Button
              type="button"
              variant={adjustmentType === "subtract" ? "default" : "outline"}
              size="sm"
              className={adjustmentType === "subtract" ? "bg-rose-600 hover:bg-rose-700 shadow-sm shadow-rose-500/20" : "bg-transparent border-slate-200 dark:border-slate-700"}
              onClick={() => setAdjustmentType("subtract")}
            >
              Remove Money
            </Button>
          </div>

          <div className="relative">
            <span className="absolute left-3 top-1/2 -translate-y-1/2 text-sm font-semibold text-muted-foreground">৳</span>
            <Input
              type="number"
              placeholder="0"
              value={adjustmentAmount}
              onChange={(e) => setAdjustmentAmount(e.target.value)}
              min="0"
              step="0.01"
              className="pl-8"
            />
          </div>

          {hasAdjustment && (
            <p className="text-xs text-slate-600 mt-2">
              New balance will be: ৳{previewBalance.toLocaleString()}
            </p>
          )}
        </div>
      </div>

      {/* Note for adjustment */}
      {hasAdjustment && (
        <div className="space-y-2">
          <Label htmlFor="note" className="text-sm font-medium">Adjustment Note (Optional)</Label>
          <Input
            id="note"
            placeholder="Reason for adjustment..."
            value={note}
            onChange={(e) => setNote(e.target.value)}
          />
        </div>
      )}

      {/* Action Buttons */}
      <div className="flex gap-2 sm:gap-3 pt-2">
        <Button
          type="button"
          variant="outline"
          className="flex-1 h-10 sm:h-12 bg-transparent"
          onClick={() => onOpenChange(false)}
        >
          Cancel
        </Button>
        <Button
          type="submit"
          className="flex-1 h-10 sm:h-12 font-semibold"
          disabled={loading}
        >
          {loading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
          Save Changes
        </Button>
      </div>
    </form>
  );
}

export function EditAccountModal({
  open,
  onOpenChange,
  account,
  transactions,
  onSuccess,
}: EditAccountModalProps) {
  const isDesktop = useMediaQuery("(min-width: 640px)");
  const currentBalance = useMemo(
    () => (account ? calculateAccountBalance(account.id, transactions) : 0),
    [account?.id, transactions],
  );

  if (!account) return null;

  const HeaderIcon = () => (
    <div className="flex h-9 w-9 sm:h-10 sm:w-10 items-center justify-center rounded-xl bg-gradient-to-br from-blue-500 to-indigo-600 text-white shadow-md shadow-blue-500/20">
      <Settings className="h-4 w-4 sm:h-5 sm:w-5" />
    </div>
  );

  if (isDesktop) {
    return (
      <Dialog open={open} onOpenChange={onOpenChange}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <div className="flex items-center gap-3">
              <HeaderIcon />
              <div>
                <DialogTitle className="text-xl">Edit {account.name}</DialogTitle>
                <DialogDescription>
                  Current balance: ৳{currentBalance.toLocaleString()}
                </DialogDescription>
              </div>
            </div>
          </DialogHeader>
          <EditAccountForm
            account={account}
            transactions={transactions}
            onOpenChange={onOpenChange}
            onSuccess={onSuccess}
          />
        </DialogContent>
      </Dialog>
    );
  }

  return (
    <Drawer open={open} onOpenChange={onOpenChange}>
      <DrawerContent className="px-4 pb-6 max-h-[90vh]">
        <DrawerHeader className="px-0">
          <div className="flex items-center gap-3">
            <HeaderIcon />
            <div>
              <DrawerTitle className="text-xl">Edit {account.name}</DrawerTitle>
              <DrawerDescription>
                Current balance: ৳{currentBalance.toLocaleString()}
              </DrawerDescription>
            </div>
          </div>
        </DrawerHeader>
        <div className="overflow-y-auto">
          <EditAccountForm
            account={account}
            transactions={transactions}
            onOpenChange={onOpenChange}
            onSuccess={onSuccess}
          />
        </div>
      </DrawerContent>
    </Drawer>
  );
}
