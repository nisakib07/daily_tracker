"use client";

import React from "react";
import { useState, useEffect } from "react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  Drawer,
  DrawerContent,
  DrawerHeader,
  DrawerTitle,
} from "@/components/ui/drawer";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import type { Account, Investment } from "@/lib/types";
import { createClient } from "@/lib/supabase/client";
import { useAuth } from "@/lib/auth-context";
import { Loader2, Plus } from "lucide-react";
import { useMediaQuery } from "@/hooks/use-media-query";
import { format } from "date-fns";

interface InvestmentAddFundsModalProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  accounts: Account[];
  investment: Investment | null;
  onSuccess: () => void;
}

function InvestmentAddFundsForm({
  accounts,
  investment,
  onSuccess,
  onOpenChange,
}: Omit<InvestmentAddFundsModalProps, 'open'>) {
  const { user } = useAuth();
  const [amount, setAmount] = useState("");
  const [fromAccountId, setFromAccountId] = useState("");
  const [date, setDate] = useState(format(new Date(), "yyyy-MM-dd"));
  const [note, setNote] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!investment || !amount || !fromAccountId) return;

    setLoading(true);
    const supabase = createClient();

    try {
      // Insert into transactions table
      const { error: transactionError } = await supabase
        .from("transactions")
        .insert({
          type: "invest",
          amount: parseFloat(amount),
          from_account_id: fromAccountId,
          to_account_id: null,
          investment_id: investment.id,
          category: "Investment",
          note: note.trim() || null,
          user_id: user?.id,
          occurred_at: (() => {
            const now = new Date();
            const [year, month, day] = date.split('-').map(Number);
            now.setFullYear(year, month - 1, day);
            return now.toISOString();
          })(),
        });

      if (transactionError) throw transactionError;

      resetForm();
      onOpenChange(false);
      onSuccess();
    } catch (error) {
      console.error("Error adding funds to investment:", error);
    } finally {
      setLoading(false);
    }
  };

  const resetForm = () => {
    setAmount("");
    setFromAccountId("");
    setDate(format(new Date(), "yyyy-MM-dd"));
    setNote("");
  };

  return (
    <div className="flex flex-col min-h-0 h-full">
      {/* Scrollable content area */}
      <div className="flex-1 min-h-0 overflow-y-auto scrollbar-hide pb-4">
        <div className="space-y-3">
          {/* Investment Name (Read-Only) */}
          <div className="rounded-xl p-3 bg-slate-50 dark:bg-slate-900 border border-slate-100 dark:border-slate-800">
            <span className="text-[10px] font-semibold text-muted-foreground uppercase tracking-wide">
              Adding Funds To
            </span>
            <p className="text-sm font-bold text-slate-800 dark:text-slate-200 mt-0.5">
              {investment?.name}
            </p>
          </div>

          {/* ✨ Hero Amount Input */}
          <div className="rounded-2xl p-4 bg-violet-50/80 dark:bg-violet-950/30 transition-all">
            <Label htmlFor="amount" className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-2 block">
              Investment Amount
            </Label>
            <div className="relative">
              <span className="absolute left-3 top-1/2 -translate-y-1/2 text-2xl font-bold text-violet-500">
                ৳
              </span>
              <Input
                id="amount"
                type="number"
                inputMode="decimal"
                placeholder="0.00"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                required
                min="0"
                step="0.01"
                className="pl-10 h-14 text-2xl font-bold bg-white/80 dark:bg-white/5 border-0 rounded-xl shadow-sm focus-visible:ring-2 focus-visible:ring-violet-400 transition-shadow"
              />
            </div>
          </div>

          {/* 🏦 From Account Section */}
          <div className="drawer-section space-y-3">
            <p className="text-[11px] font-semibold text-muted-foreground uppercase tracking-wider flex items-center gap-1.5">
              <span>🏦</span> Source Account
            </p>

            <div className="space-y-1.5">
              <Label htmlFor="fromAccount" className="text-xs font-medium">From Account</Label>
              <Select value={fromAccountId} onValueChange={setFromAccountId} required>
                <SelectTrigger className="h-11 rounded-xl">
                  <SelectValue placeholder="Select account" />
                </SelectTrigger>
                <SelectContent>
                  {accounts.map((account) => (
                    <SelectItem key={account.id} value={account.id}>
                      {account.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>

          {/* 📝 Extras Section */}
          <div className="drawer-section space-y-3">
            <p className="text-[11px] font-semibold text-muted-foreground uppercase tracking-wider flex items-center gap-1.5">
              <span>📝</span> Extras
            </p>

            {/* Date Input */}
            <div className="space-y-1.5">
              <Label htmlFor="date" className="text-xs font-medium">Date</Label>
              <Input
                id="date"
                type="date"
                value={date}
                onChange={(e) => setDate(e.target.value)}
                required
                max={format(new Date(), "yyyy-MM-dd")}
                className="h-11 rounded-xl"
              />
            </div>

            {/* Note */}
            <div className="space-y-1.5">
              <Label htmlFor="note" className="text-xs font-medium">
                Note <span className="text-muted-foreground">(Optional)</span>
              </Label>
              <Textarea
                id="note"
                placeholder="Add a note..."
                value={note}
                onChange={(e) => setNote(e.target.value)}
                rows={2}
                className="resize-none rounded-xl"
              />
            </div>
          </div>
        </div>
      </div>

      {/* Fixed bottom action bar */}
      <div className="drawer-action-bar pt-3 pb-[env(safe-area-inset-bottom)]">
        <div className="flex gap-2.5">
          <Button
            type="button"
            variant="outline"
            className="flex-1 h-12 rounded-xl bg-transparent active:scale-[0.98] transition-transform"
            onClick={() => onOpenChange(false)}
          >
            Cancel
          </Button>
          <Button
            type="button"
            className="flex-[1.5] h-12 rounded-xl font-semibold bg-gradient-to-r from-violet-500 to-purple-600 hover:from-violet-600 hover:to-purple-700 active:scale-[0.98] transition-transform shadow-lg shadow-violet-500/25"
            disabled={loading || !investment || !amount || !fromAccountId}
            onClick={handleSubmit}
          >
            {loading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
            Add Funds
          </Button>
        </div>
      </div>
    </div>
  );
}

export function InvestmentAddFundsModal({
  open,
  onOpenChange,
  accounts,
  investment,
  onSuccess,
}: InvestmentAddFundsModalProps) {
  const isDesktop = useMediaQuery("(min-width: 640px)");

  const HeaderIcon = () => (
    <div className="flex h-9 w-9 sm:h-10 sm:w-10 items-center justify-center rounded-xl bg-gradient-to-br from-violet-500 to-purple-600 text-white">
      <Plus className="h-4 w-4 sm:h-5 sm:w-5" />
    </div>
  );

  if (isDesktop) {
    return (
      <Dialog open={open} onOpenChange={onOpenChange}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <div className="flex items-center gap-3">
              <HeaderIcon />
              <DialogTitle className="text-xl text-violet-600">
                Add Funds
              </DialogTitle>
            </div>
          </DialogHeader>
          <InvestmentAddFundsForm
            accounts={accounts}
            investment={investment}
            onSuccess={onSuccess}
            onOpenChange={onOpenChange}
          />
        </DialogContent>
      </Dialog>
    );
  }

  return (
    <Drawer open={open} onOpenChange={onOpenChange}>
      <DrawerContent className="px-4 pb-[max(1.5rem,env(safe-area-inset-bottom))] max-h-[85dvh] flex flex-col">
        <DrawerHeader className="px-0 shrink-0">
          <div className="flex items-center gap-3">
            <HeaderIcon />
            <div>
              <DrawerTitle className="text-lg text-violet-600">
                Add Funds
              </DrawerTitle>
              <p className="text-xs text-muted-foreground mt-0.5">Add more capital to this investment</p>
            </div>
          </div>
        </DrawerHeader>
        <InvestmentAddFundsForm
          accounts={accounts}
          investment={investment}
          onSuccess={onSuccess}
          onOpenChange={onOpenChange}
        />
      </DrawerContent>
    </Drawer>
  );
}
