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
import { Loader2, ArrowDownLeft } from "lucide-react";
import { useMediaQuery } from "@/hooks/use-media-query";
import { format } from "date-fns";

interface InvestmentReturnModalProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  accounts: Account[];
  investments: Investment[];
  selectedInvestment?: Investment | null;
  onSuccess: () => void;
}

function InvestmentReturnForm({
  accounts,
  investments,
  selectedInvestment,
  onSuccess,
  onOpenChange,
}: Omit<InvestmentReturnModalProps, 'open'>) {
  const { user } = useAuth();
  const [investmentId, setInvestmentId] = useState(selectedInvestment?.id || "");
  const [amount, setAmount] = useState("");
  const [toAccountId, setToAccountId] = useState("");
  const [date, setDate] = useState(format(new Date(), "yyyy-MM-dd"));
  const [note, setNote] = useState("");
  const [closeInvestment, setCloseInvestment] = useState(false);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (selectedInvestment) {
      setInvestmentId(selectedInvestment.id);
    } else if (investments.length > 0 && !investmentId) {
      setInvestmentId(investments[0].id);
    }
  }, [selectedInvestment, investments, investmentId]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!investmentId || !amount || !toAccountId) return;

    setLoading(true);
    const supabase = createClient();

    try {
      // 1. Insert into transactions table
      const { error: transactionError } = await supabase
        .from("transactions")
        .insert({
          type: "invest_return",
          amount: parseFloat(amount),
          from_account_id: null,
          to_account_id: toAccountId,
          investment_id: investmentId,
          category: "Investment Return",
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

      // 2. If closeInvestment is checked, update investment status to closed
      if (closeInvestment) {
        const { error: updateError } = await supabase
          .from("investments")
          .update({ status: "closed" })
          .eq("id", investmentId);

        if (updateError) throw updateError;
      }

      resetForm();
      onOpenChange(false);
      onSuccess();
    } catch (error) {
      console.error("Error recording investment return:", error);
    } finally {
      setLoading(false);
    }
  };

  const resetForm = () => {
    setInvestmentId(selectedInvestment?.id || "");
    setAmount("");
    setToAccountId("");
    setDate(format(new Date(), "yyyy-MM-dd"));
    setNote("");
    setCloseInvestment(false);
  };

  return (
    <div className="flex flex-col min-h-0 h-full">
      {/* Scrollable content area */}
      <div className="flex-1 min-h-0 overflow-y-auto scrollbar-hide pb-4">
        <div className="space-y-3">
          {/* ✨ Hero Amount Input */}
          <div className="rounded-2xl p-4 bg-violet-50/80 dark:bg-violet-950/30 transition-all">
            <Label htmlFor="amount" className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-2 block">
              Return Amount
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

          {/* 💼 Investment Details Section */}
          <div className="drawer-section space-y-3">
            <p className="text-[11px] font-semibold text-muted-foreground uppercase tracking-wider flex items-center gap-1.5">
              <span>💼</span> Investment Select
            </p>

            {/* Investment Selection */}
            <div className="space-y-1.5">
              <Label htmlFor="investment" className="text-xs font-medium">Select Investment</Label>
              <Select value={investmentId} onValueChange={setInvestmentId} required>
                <SelectTrigger className="h-11 rounded-xl">
                  <SelectValue placeholder="Select an investment" />
                </SelectTrigger>
                <SelectContent>
                  {investments.map((inv) => (
                    <SelectItem key={inv.id} value={inv.id}>
                      {inv.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>

          {/* 🏦 Destination Account Section */}
          <div className="drawer-section space-y-3">
            <p className="text-[11px] font-semibold text-muted-foreground uppercase tracking-wider flex items-center gap-1.5">
              <span>🏦</span> Destination Account
            </p>

            <div className="space-y-1.5">
              <Label htmlFor="toAccount" className="text-xs font-medium">To Account</Label>
              <Select value={toAccountId} onValueChange={setToAccountId} required>
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

            {/* Close Investment Checkbox */}
            <div className="flex items-center gap-2 pt-2 pb-1">
              <input
                id="closeInvestment"
                type="checkbox"
                checked={closeInvestment}
                onChange={(e) => setCloseInvestment(e.target.checked)}
                className="h-4 w-4 rounded border-slate-300 text-violet-600 focus:ring-violet-500 accent-violet-600 cursor-pointer"
              />
              <Label htmlFor="closeInvestment" className="text-xs font-medium text-slate-700 dark:text-slate-300 cursor-pointer">
                Close this investment after recording return
              </Label>
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
            disabled={loading || !investmentId || !amount || !toAccountId}
            onClick={handleSubmit}
          >
            {loading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
            Record Return
          </Button>
        </div>
      </div>
    </div>
  );
}

export function InvestmentReturnModal({
  open,
  onOpenChange,
  accounts,
  investments,
  selectedInvestment,
  onSuccess,
}: InvestmentReturnModalProps) {
  const isDesktop = useMediaQuery("(min-width: 640px)");

  const HeaderIcon = () => (
    <div className="flex h-9 w-9 sm:h-10 sm:w-10 items-center justify-center rounded-xl bg-gradient-to-br from-violet-500 to-purple-600 text-white">
      <ArrowDownLeft className="h-4 w-4 sm:h-5 sm:w-5" />
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
                Record Return
              </DialogTitle>
            </div>
          </DialogHeader>
          <InvestmentReturnForm
            accounts={accounts}
            investments={investments}
            selectedInvestment={selectedInvestment}
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
                Record Return
              </DrawerTitle>
              <p className="text-xs text-muted-foreground mt-0.5">Record money returning from an investment</p>
            </div>
          </div>
        </DrawerHeader>
        <InvestmentReturnForm
          accounts={accounts}
          investments={investments}
          selectedInvestment={selectedInvestment}
          onSuccess={onSuccess}
          onOpenChange={onOpenChange}
        />
      </DrawerContent>
    </Drawer>
  );
}
