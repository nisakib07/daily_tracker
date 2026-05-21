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
import type { Account, Person, Transaction } from "@/lib/types";
import { DEFAULT_CATEGORIES_IN, DEFAULT_CATEGORIES_OUT } from "@/lib/types";
import { createClient } from "@/lib/supabase/client";
import { Loader2, Pencil, Plus, X, Check, ArrowDownLeft, ArrowUpRight, ArrowRightLeft, HandCoins, Handshake } from "lucide-react";
import { cn } from "@/lib/utils";
import { useMediaQuery } from "@/hooks/use-media-query";
import { format, parseISO } from "date-fns";

// Local storage keys for custom categories
const CUSTOM_INCOME_CATEGORIES_KEY = "dmt_custom_income_categories";
const CUSTOM_EXPENSE_CATEGORIES_KEY = "dmt_custom_expense_categories";

interface EditTransactionModalProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  transaction: Transaction | null;
  accounts: Account[];
  people: Person[];
  onSuccess: () => void;
}

function EditTransactionForm({
  transaction,
  accounts,
  people,
  onOpenChange,
  onSuccess,
}: Omit<EditTransactionModalProps, 'open'>) {
  // Initialize state directly from transaction to ensure proper prefilling
  const [amount, setAmount] = useState(transaction ? String(transaction.amount) : "");
  const [accountId, setAccountId] = useState(
    transaction 
      ? (transaction.from_account_id || transaction.to_account_id || "") 
      : ""
  );
  const [toAccountId, setToAccountId] = useState(transaction?.to_account_id || "");
  const [personId, setPersonId] = useState(transaction?.person_id || "");
  const [category, setCategory] = useState(transaction?.category || "");
  const [note, setNote] = useState(transaction?.note || "");
  const [date, setDate] = useState(
    transaction ? format(parseISO(transaction.date), "yyyy-MM-dd") : ""
  );
  const [loading, setLoading] = useState(false);
  const [showSuccess, setShowSuccess] = useState(false);
  
  // Custom category state
  const [showAddCategory, setShowAddCategory] = useState(false);
  const [newCategoryName, setNewCategoryName] = useState("");
  const [customCategories, setCustomCategories] = useState<string[]>([]);

  const isIncome = transaction?.type === "income" || transaction?.type === "borrow" || transaction?.type === "receive" || transaction?.type === "invest_return";
  const isTransfer = transaction?.type === "transfer";
  const isLoanRelated = transaction ? ["lend", "borrow", "repay", "receive"].includes(transaction.type) : false;
  const isInvestmentRelated = transaction ? ["invest", "invest_return"].includes(transaction.type) : false;
  
  const defaultCategories = isIncome ? [...DEFAULT_CATEGORIES_IN] : [...DEFAULT_CATEGORIES_OUT];
  const allCategories = [...defaultCategories, ...customCategories];

  // Format amount for display
  const formattedAmount = React.useMemo(() => {
    if (!amount) return "";
    const num = parseFloat(amount);
    if (isNaN(num)) return amount;
    return num.toLocaleString("en-IN");
  }, [amount]);

  // Load custom categories from localStorage
  useEffect(() => {
    const storageKey = isIncome ? CUSTOM_INCOME_CATEGORIES_KEY : CUSTOM_EXPENSE_CATEGORIES_KEY;
    const saved = localStorage.getItem(storageKey);
    if (saved) {
      try {
        setCustomCategories(JSON.parse(saved));
      } catch {
        setCustomCategories([]);
      }
    }
  }, [isIncome]);


  if (!transaction) return null;

  // Get type icon
  const getTypeIcon = () => {
    switch (transaction.type) {
      case "income": return <ArrowDownLeft className="h-3.5 w-3.5" />;
      case "expense": return <ArrowUpRight className="h-3.5 w-3.5" />;
      case "transfer": return <ArrowRightLeft className="h-3.5 w-3.5" />;
      case "lend": return <HandCoins className="h-3.5 w-3.5" />;
      case "borrow": return <Handshake className="h-3.5 w-3.5" />;
      case "repay": return <ArrowUpRight className="h-3.5 w-3.5" />;
      case "receive": return <ArrowDownLeft className="h-3.5 w-3.5" />;
      default: return <Pencil className="h-3.5 w-3.5" />;
    }
  };

  const getTypeLabel = () => {
    switch (transaction.type) {
      case "income": return "Income";
      case "expense": return "Expense";
      case "transfer": return "Transfer";
      case "lend": return "Loan Given";
      case "borrow": return "Borrowed";
      case "repay": return "Loan Repaid";
      case "receive": return "Loan Received Back";
      default: return "Transaction";
    }
  };

  const getTypeColor = () => {
    if (isIncome) return "emerald";
    if (isTransfer) return "blue";
    return "rose";
  };

  // Save custom category
  const handleAddCategory = () => {
    if (!newCategoryName.trim()) return;
    
    const trimmedName = newCategoryName.trim();
    if (allCategories.includes(trimmedName)) {
      setNewCategoryName("");
      setShowAddCategory(false);
      setCategory(trimmedName);
      return;
    }
    
    const updatedCategories = [...customCategories, trimmedName];
    setCustomCategories(updatedCategories);
    
    const storageKey = isIncome ? CUSTOM_INCOME_CATEGORIES_KEY : CUSTOM_EXPENSE_CATEGORIES_KEY;
    localStorage.setItem(storageKey, JSON.stringify(updatedCategories));
    
    setCategory(trimmedName);
    setNewCategoryName("");
    setShowAddCategory(false);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!amount || !accountId) return;

    setLoading(true);
    const supabase = createClient();

    try {
      const updateData: Partial<Transaction> & { occurred_at?: string } = {
        amount: parseFloat(amount),
        category,
        note: note || null,
        person_id: personId || null,
        occurred_at: (() => {
          const now = new Date();
          const [year, month, day] = date.split('-').map(Number);
          now.setFullYear(year, month - 1, day);
          return now.toISOString();
        })(),
      };

      if (isTransfer) {
        updateData.from_account_id = accountId;
        updateData.to_account_id = toAccountId;
      } else if (isIncome) {
        updateData.to_account_id = accountId;
        updateData.from_account_id = null;
      } else {
        updateData.from_account_id = accountId;
        updateData.to_account_id = null;
      }

      const { error } = await supabase
        .from("transactions")
        .update(updateData)
        .eq("id", transaction.id);

      if (error) throw error;

      // Show success celebration
      setShowSuccess(true);
      setTimeout(() => {
        setShowSuccess(false);
        onOpenChange(false);
        onSuccess();
      }, 800);
    } catch (error) {
      console.error("[v0] Error updating transaction:", error);
    } finally {
      setLoading(false);
    }
  };

  const color = getTypeColor();

  return (
    <div className="flex flex-col min-h-0 h-full">
      <form onSubmit={handleSubmit} className="flex flex-col min-h-0 h-full">
        {/* Scrollable content */}
        <div className="flex-1 min-h-0 overflow-y-auto scrollbar-hide pb-4 space-y-3">
          {/* Type Badge */}
          <div className="flex items-center gap-2 animate-field-in field-delay-1">
            <span className={cn(
              "inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-semibold animate-badge-in",
              isIncome 
                ? "bg-emerald-100 dark:bg-emerald-900/50 text-emerald-700 dark:text-emerald-300"
                : isTransfer
                ? "bg-blue-100 dark:bg-blue-900/50 text-blue-700 dark:text-blue-300"
                : "bg-rose-100 dark:bg-rose-900/50 text-rose-700 dark:text-rose-300"
            )}>
              {getTypeIcon()}
              {getTypeLabel()}
            </span>
          </div>

          {/* ✨ Hero Amount Input — animation wrapper separate from focus-within glow */}
          <div className="animate-field-in field-delay-1">
            <div
              className={cn(
                "rounded-2xl p-4 relative overflow-hidden",
                color === "emerald"
                  ? "bg-emerald-50/80 dark:bg-emerald-950/30 hero-glow-emerald"
                  : color === "blue"
                  ? "bg-blue-50/80 dark:bg-blue-950/30 hero-glow-blue"
                  : "bg-rose-50/80 dark:bg-rose-950/30 hero-glow-rose"
              )}
            >
              {/* Breathing gradient overlay */}
              <div className={cn(
                "absolute inset-0 rounded-2xl hero-breathe pointer-events-none",
                color === "emerald"
                  ? "bg-gradient-to-br from-emerald-200/20 via-transparent to-emerald-100/10 dark:from-emerald-500/10 dark:to-emerald-400/5"
                  : color === "blue"
                  ? "bg-gradient-to-br from-blue-200/20 via-transparent to-blue-100/10 dark:from-blue-500/10 dark:to-blue-400/5"
                  : "bg-gradient-to-br from-rose-200/20 via-transparent to-rose-100/10 dark:from-rose-500/10 dark:to-rose-400/5"
              )} />
              <div className="relative">
                <Label htmlFor="amount" className="text-[10px] font-semibold text-muted-foreground uppercase tracking-widest mb-2 block">
                  Amount
                </Label>
                <div className="relative">
                  <span className={cn(
                    "absolute left-3 top-1/2 -translate-y-1/2 text-2xl font-bold",
                    color === "emerald" ? "text-emerald-500" 
                    : color === "blue" ? "text-blue-500" 
                    : "text-rose-500"
                  )}>
                    ৳
                  </span>
                  <Input
                    id="amount"
                    type="number"
                    placeholder="0"
                    value={amount}
                    onChange={(e) => setAmount(e.target.value)}
                    required
                    min="0"
                    step="0.01"
                    className={cn(
                      "pl-10 h-14 text-2xl font-bold bg-white/80 dark:bg-white/5 border-0 rounded-xl shadow-sm focus-visible:ring-2 transition-shadow",
                      color === "emerald" ? "focus-visible:ring-emerald-400" 
                      : color === "blue" ? "focus-visible:ring-blue-400" 
                      : "focus-visible:ring-rose-400"
                    )}
                  />
                  {/* Live amount format display */}
                  {amount && parseFloat(amount) > 0 && (
                    <span className={cn(
                      "absolute right-3 top-1/2 -translate-y-1/2 text-xs font-medium",
                      color === "emerald" ? "text-emerald-500/60"
                      : color === "blue" ? "text-blue-500/60"
                      : "text-rose-500/60"
                    )}>
                      ৳{formattedAmount}
                    </span>
                  )}
                </div>
              </div>
            </div>
          </div>

          {/* 📋 Details Section */}
          <div className="drawer-section space-y-3 animate-field-in field-delay-2">
            <p className="text-[11px] font-semibold text-muted-foreground uppercase tracking-widest flex items-center gap-1.5">
              <span>📋</span> Details
            </p>

            {/* Account Selection */}
            <div className="space-y-1.5 animate-field-in field-delay-3">
              <Label htmlFor="account" className="text-xs font-medium">
                {isTransfer ? "From Account" : "Account"}
              </Label>
              <Select value={accountId} onValueChange={setAccountId} required>
                <SelectTrigger className="h-11 rounded-xl transition-all hover:border-muted-foreground/30">
                  <SelectValue placeholder="Select account" />
                </SelectTrigger>
                <SelectContent>
                  {accounts.map((account) => (
                    <SelectItem key={account.id} value={account.id}>
                      <span className="flex items-center gap-2">
                        <span className={cn(
                          "w-2 h-2 rounded-full shrink-0",
                          account.name.toLowerCase().includes("cash") ? "bg-emerald-500" :
                          account.name.toLowerCase().includes("bkash") ? "bg-pink-500" :
                          account.name.toLowerCase().includes("card") ? "bg-blue-500" :
                          "bg-slate-400"
                        )} />
                        {account.name}
                      </span>
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            {/* To Account for Transfers */}
            {isTransfer && (
              <div className="space-y-1.5 animate-field-in field-delay-3">
                <Label htmlFor="toAccount" className="text-xs font-medium">To Account</Label>
                <Select value={toAccountId} onValueChange={setToAccountId} required>
                  <SelectTrigger className="h-11 rounded-xl transition-all hover:border-muted-foreground/30">
                    <SelectValue placeholder="Select destination account" />
                  </SelectTrigger>
                  <SelectContent>
                    {accounts.map((account) => (
                      <SelectItem key={account.id} value={account.id} disabled={account.id === accountId}>
                        <span className="flex items-center gap-2">
                          <span className={cn(
                            "w-2 h-2 rounded-full shrink-0",
                            account.name.toLowerCase().includes("cash") ? "bg-emerald-500" :
                            account.name.toLowerCase().includes("bkash") ? "bg-pink-500" :
                            account.name.toLowerCase().includes("card") ? "bg-blue-500" :
                            "bg-slate-400"
                          )} />
                          {account.name}
                        </span>
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            )}

            {/* Category Selection (not for transfers, loan-related, or investment-related) with Add New Option */}
            {!isTransfer && !isLoanRelated && !isInvestmentRelated && (
              <div className="space-y-1.5 animate-field-in field-delay-4">
                <div className="flex items-center justify-between">
                  <Label htmlFor="category" className="text-xs font-medium">Category</Label>
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    className="h-auto p-0 text-xs font-medium text-primary hover:text-primary/80"
                    onClick={() => setShowAddCategory(!showAddCategory)}
                  >
                    <Plus className="mr-1 h-3 w-3" />
                    Add New
                  </Button>
                </div>
                
                {showAddCategory ? (
                  <div className="flex gap-2">
                    <Input
                      placeholder="Enter category name"
                      value={newCategoryName}
                      onChange={(e) => setNewCategoryName(e.target.value)}
                      className="h-11 rounded-xl flex-1"
                      autoFocus
                      onKeyDown={(e) => {
                        if (e.key === "Enter") {
                          e.preventDefault();
                          handleAddCategory();
                        }
                      }}
                    />
                    <Button
                      type="button"
                      size="icon"
                      onClick={handleAddCategory}
                      className="h-11 w-11 rounded-xl bg-emerald-600 hover:bg-emerald-700"
                      disabled={!newCategoryName.trim()}
                    >
                      <Plus className="h-4 w-4" />
                    </Button>
                    <Button
                      type="button"
                      size="icon"
                      variant="outline"
                      onClick={() => {
                        setShowAddCategory(false);
                        setNewCategoryName("");
                      }}
                      className="h-11 w-11 rounded-xl bg-transparent"
                    >
                      <X className="h-4 w-4" />
                    </Button>
                  </div>
                ) : (
                  <Select value={category} onValueChange={setCategory}>
                    <SelectTrigger className="h-11 rounded-xl transition-all hover:border-muted-foreground/30">
                      <SelectValue placeholder="Select category" />
                    </SelectTrigger>
                    <SelectContent>
                      {allCategories.map((cat) => (
                        <SelectItem key={cat} value={cat}>
                          {cat}
                          {customCategories.includes(cat) && (
                            <span className="ml-2 text-xs text-muted-foreground">(custom)</span>
                          )}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                )}
              </div>
            )}

            {/* Person Selection */}
            {(isLoanRelated || !isTransfer) && (
              <div className="space-y-1.5 animate-field-in field-delay-4">
                <Label htmlFor="person" className="text-xs font-medium">
                  Person {isLoanRelated ? <span className="text-rose-500">*</span> : <span className="text-muted-foreground">(Optional)</span>}
                </Label>
                <Select value={personId} onValueChange={setPersonId}>
                  <SelectTrigger className="h-11 rounded-xl transition-all hover:border-muted-foreground/30">
                    <SelectValue placeholder="Select person" />
                  </SelectTrigger>
                  <SelectContent>
                    {people.map((person) => (
                      <SelectItem key={person.id} value={person.id}>
                        {person.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            )}
          </div>

          {/* 📝 Extras Section */}
          <div className="drawer-section space-y-3 animate-field-in field-delay-5">
            <p className="text-[11px] font-semibold text-muted-foreground uppercase tracking-widest flex items-center gap-1.5">
              <span>📝</span> Extras
            </p>

            {/* Date Input */}
            <div className="space-y-1.5 animate-field-in field-delay-5">
              <Label htmlFor="date" className="text-xs font-medium">Date</Label>
              <Input
                id="date"
                type="date"
                value={date}
                onChange={(e) => setDate(e.target.value)}
                required
                max={format(new Date(), "yyyy-MM-dd")}
                className="h-11 rounded-xl transition-all hover:border-muted-foreground/30"
              />
            </div>

            {/* Note */}
            <div className="space-y-1.5 animate-field-in field-delay-6">
              <Label htmlFor="note" className="text-xs font-medium">
                Note <span className="text-muted-foreground">(Optional)</span>
              </Label>
              <Textarea
                id="note"
                placeholder="Add a note..."
                value={note}
                onChange={(e) => setNote(e.target.value)}
                rows={2}
                className="resize-none rounded-xl transition-all hover:border-muted-foreground/30"
              />
            </div>
          </div>
        </div>

        {/* Fixed bottom action bar */}
        <div className="drawer-action-bar pt-3 pb-[env(safe-area-inset-bottom)]">
          <div className="flex gap-2.5">
            <Button
              type="button"
              variant="outline"
              className="flex-1 h-12 rounded-xl bg-transparent active:scale-[0.96] transition-all"
              onClick={() => onOpenChange(false)}
              disabled={loading || showSuccess}
            >
              Cancel
            </Button>
            <Button
              type="submit"
              className={cn(
                "flex-[1.5] h-12 rounded-xl font-semibold active:scale-[0.96] transition-all shadow-lg relative overflow-hidden",
                showSuccess
                  ? "bg-gradient-to-r from-emerald-500 to-emerald-600 animate-success-morph"
                  : color === "emerald"
                  ? "bg-gradient-to-r from-emerald-500 to-emerald-600 hover:from-emerald-600 hover:to-emerald-700 shadow-emerald-500/25 btn-gradient-animate"
                  : color === "blue"
                  ? "bg-gradient-to-r from-blue-500 to-indigo-600 hover:from-blue-600 hover:to-indigo-700 shadow-blue-500/25 btn-gradient-animate"
                  : "bg-gradient-to-r from-rose-500 to-rose-600 hover:from-rose-600 hover:to-rose-700 shadow-rose-500/25 btn-gradient-animate",
              )}
              disabled={loading || !amount || !accountId}
            >
              {showSuccess ? (
                <span className="flex items-center gap-1.5">
                  <Check className="h-5 w-5" />
                  Saved!
                </span>
              ) : loading ? (
                <span className="flex items-center">
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  Saving...
                </span>
              ) : (
                "Save Changes"
              )}
            </Button>
          </div>
        </div>
      </form>
    </div>
  );
}

export function EditTransactionModal({
  open,
  onOpenChange,
  transaction,
  accounts,
  people,
  onSuccess,
}: EditTransactionModalProps) {
  const isDesktop = useMediaQuery("(min-width: 640px)");

  if (!transaction) return null;

  const isIncome = transaction.type === "income" || transaction.type === "borrow" || transaction.type === "receive";
  const isTransfer = transaction.type === "transfer";

  const getTypeLabel = () => {
    switch (transaction.type) {
      case "income": return "Income";
      case "expense": return "Expense";
      case "transfer": return "Transfer";
      case "lend": return "Loan Given";
      case "borrow": return "Borrowed";
      case "repay": return "Loan Repaid";
      case "receive": return "Loan Received Back";
      case "invest": return "Investment";
      case "invest_return": return "Investment Return";
      default: return "Transaction";
    }
  };

  const HeaderIcon = () => (
    <div className={cn(
      "flex h-9 w-9 sm:h-10 sm:w-10 items-center justify-center rounded-xl text-white",
      isIncome 
        ? "bg-gradient-to-br from-emerald-500 to-emerald-600" 
        : isTransfer
        ? "bg-gradient-to-br from-blue-500 to-indigo-600"
        : "bg-gradient-to-br from-rose-500 to-rose-600"
    )}>
      <Pencil className="h-4 w-4 sm:h-5 sm:w-5" />
    </div>
  );

  if (isDesktop) {
    return (
      <Dialog open={open} onOpenChange={onOpenChange}>
        <DialogContent className="sm:max-w-md p-0 overflow-hidden">
          <div className="p-4 pb-0">
            <DialogHeader>
              <div className="flex items-center gap-3">
                <HeaderIcon />
                <DialogTitle className={cn(
                  "text-xl",
                  isIncome ? "text-emerald-600" : isTransfer ? "text-blue-600" : "text-rose-600"
                )}>
                  Edit {getTypeLabel()}
                </DialogTitle>
              </div>
            </DialogHeader>
          </div>

          <div className="px-4 pb-4 max-h-[80vh] flex flex-col">
            <EditTransactionForm
              key={transaction.id}
              transaction={transaction}
              accounts={accounts}
              people={people}
              onOpenChange={onOpenChange}
              onSuccess={onSuccess}
            />
          </div>
        </DialogContent>
      </Dialog>
    );
  }

  return (
    <Drawer open={open} onOpenChange={onOpenChange}>
      <DrawerContent className="max-h-[85dvh] px-4 pb-2 flex flex-col">
        <DrawerHeader className="px-0 shrink-0">
          <div className="flex items-center gap-3">
            <HeaderIcon />
            <div>
              <DrawerTitle className={cn(
                "text-lg",
                isIncome ? "text-emerald-600" : isTransfer ? "text-blue-600" : "text-rose-600"
              )}>
                Edit {getTypeLabel()}
              </DrawerTitle>
              <p className="text-xs text-muted-foreground mt-0.5">
                Update your {getTypeLabel().toLowerCase()} details
              </p>
            </div>
          </div>
        </DrawerHeader>

        <EditTransactionForm
          key={transaction.id}
          transaction={transaction}
          accounts={accounts}
          people={people}
          onOpenChange={onOpenChange}
          onSuccess={onSuccess}
        />
      </DrawerContent>
    </Drawer>
  );
}
