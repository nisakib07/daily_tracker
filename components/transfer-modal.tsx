"use client";

import React from "react";
import { useState } from "react";
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
import type { Account } from "@/lib/types";
import { createClient } from "@/lib/supabase/client";
import { useAuth } from "@/lib/auth-context";
import { Loader2, ArrowRightLeft } from "lucide-react";
import { useMediaQuery } from "@/hooks/use-media-query";
import { format } from "date-fns";

interface TransferModalProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  accounts: Account[];
  onSuccess: () => void;
}

function TransferForm({
  accounts,
  onSuccess,
  onOpenChange,
}: Omit<TransferModalProps, 'open'>) {
  const { user } = useAuth();
  const [amount, setAmount] = useState("");
  const [fromAccountId, setFromAccountId] = useState("");
  const [toAccountId, setToAccountId] = useState("");
  const [note, setNote] = useState("");
  const [date, setDate] = useState(format(new Date(), "yyyy-MM-dd"));
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!amount || !fromAccountId || !toAccountId || fromAccountId === toAccountId) return;

    setLoading(true);
    const supabase = createClient();

    try {
      const { error } = await supabase.from("transactions").insert({
        type: "transfer",
        amount: parseFloat(amount),
        from_account_id: fromAccountId,
        to_account_id: toAccountId,
        category: "Transfer",
        note: note || null,
        user_id: user?.id,
        occurred_at: (() => {
          const now = new Date();
          const [year, month, day] = date.split('-').map(Number);
          now.setFullYear(year, month - 1, day);
          return now.toISOString();
        })(),
      });

      if (error) throw error;

      resetForm();
      onOpenChange(false);
      onSuccess();
    } catch (error) {
      console.error("[v0] Error creating transfer:", error);
    } finally {
      setLoading(false);
    }
  };

  const resetForm = () => {
    setAmount("");
    setFromAccountId("");
    setToAccountId("");
    setNote("");
    setDate(format(new Date(), "yyyy-MM-dd"));
  };

  const fromAccount = accounts.find(a => a.id === fromAccountId);
  const toAccount = accounts.find(a => a.id === toAccountId);

  return (
    <div className="flex flex-col min-h-0 h-full">
      {/* Scrollable content area */}
      <div className="flex-1 min-h-0 overflow-y-auto scrollbar-hide pb-4">
        <div className="space-y-3">
          {/* ✨ Hero Amount Input */}
          <div className="rounded-2xl p-4 bg-blue-50/80 dark:bg-blue-950/30 hero-glow-blue transition-all">
            <Label htmlFor="amount" className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-2 block">
              Amount
            </Label>
            <div className="relative">
              <span className="absolute left-3 top-1/2 -translate-y-1/2 text-2xl font-bold text-blue-500">
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
                className="pl-10 h-14 text-2xl font-bold bg-white/80 dark:bg-white/5 border-0 rounded-xl shadow-sm focus-visible:ring-2 focus-visible:ring-blue-400 transition-shadow"
              />
            </div>
          </div>

          {/* 📋 Accounts Section */}
          <div className="drawer-section space-y-3">
            <p className="text-[11px] font-semibold text-muted-foreground uppercase tracking-wider flex items-center gap-1.5">
              <span>📋</span> Accounts
            </p>

            {/* From Account */}
            <div className="space-y-1.5">
              <Label htmlFor="fromAccount" className="text-xs font-medium">From Account</Label>
              <Select value={fromAccountId} onValueChange={setFromAccountId} required>
                <SelectTrigger className="h-11 rounded-xl">
                  <SelectValue placeholder="Select source account" />
                </SelectTrigger>
                <SelectContent>
                  {accounts.map((account) => (
                    <SelectItem key={account.id} value={account.id} disabled={account.id === toAccountId}>
                      {account.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            {/* Transfer Arrow */}
            {fromAccountId && toAccountId && (
              <div className="flex items-center justify-center py-1">
                <div className="flex items-center gap-2 px-3 py-1.5 bg-slate-100 dark:bg-slate-800 rounded-full">
                  <span className="font-medium text-slate-700 dark:text-slate-300 text-sm">{fromAccount?.name}</span>
                  <ArrowRightLeft className="h-3.5 w-3.5 text-blue-500" />
                  <span className="font-medium text-slate-700 dark:text-slate-300 text-sm">{toAccount?.name}</span>
                </div>
              </div>
            )}

            {/* To Account */}
            <div className="space-y-1.5">
              <Label htmlFor="toAccount" className="text-xs font-medium">To Account</Label>
              <Select value={toAccountId} onValueChange={setToAccountId} required>
                <SelectTrigger className="h-11 rounded-xl">
                  <SelectValue placeholder="Select destination account" />
                </SelectTrigger>
                <SelectContent>
                  {accounts.map((account) => (
                    <SelectItem key={account.id} value={account.id} disabled={account.id === fromAccountId}>
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
            className="flex-[1.5] h-12 rounded-xl font-semibold bg-gradient-to-r from-blue-500 to-indigo-600 hover:from-blue-600 hover:to-indigo-700 active:scale-[0.98] transition-transform shadow-lg shadow-blue-500/25"
            disabled={loading || !amount || !fromAccountId || !toAccountId || fromAccountId === toAccountId}
            onClick={handleSubmit}
          >
            {loading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
            Transfer
          </Button>
        </div>
      </div>
    </div>
  );
}

export function TransferModal({
  open,
  onOpenChange,
  accounts,
  onSuccess,
}: TransferModalProps) {
  const isDesktop = useMediaQuery("(min-width: 640px)");

  const HeaderIcon = () => (
    <div className="flex h-9 w-9 sm:h-10 sm:w-10 items-center justify-center rounded-xl bg-gradient-to-br from-blue-500 to-indigo-600 text-white">
      <ArrowRightLeft className="h-4 w-4 sm:h-5 sm:w-5" />
    </div>
  );

  if (isDesktop) {
    return (
      <Dialog open={open} onOpenChange={onOpenChange}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <div className="flex items-center gap-3">
              <HeaderIcon />
              <DialogTitle className="text-xl text-blue-600">
                Transfer Between Accounts
              </DialogTitle>
            </div>
          </DialogHeader>
          <TransferForm
            accounts={accounts}
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
              <DrawerTitle className="text-lg text-blue-600">
                Transfer Between Accounts
              </DrawerTitle>
              <p className="text-xs text-muted-foreground mt-0.5">Move funds between your accounts</p>
            </div>
          </div>
        </DrawerHeader>
        <TransferForm
          accounts={accounts}
          onSuccess={onSuccess}
          onOpenChange={onOpenChange}
        />
      </DrawerContent>
    </Drawer>
  );
}
