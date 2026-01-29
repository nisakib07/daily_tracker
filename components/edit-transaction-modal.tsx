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
import { Loader2, Pencil, Plus, X } from "lucide-react";
import { cn } from "@/lib/utils";
import { useMediaQuery } from "@/hooks/use-media-query";

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
  const [amount, setAmount] = useState("");
  const [accountId, setAccountId] = useState("");
  const [toAccountId, setToAccountId] = useState("");
  const [personId, setPersonId] = useState("");
  const [category, setCategory] = useState("");
  const [note, setNote] = useState("");
  const [date, setDate] = useState("");
  const [loading, setLoading] = useState(false);
  
  // Custom category state
  const [showAddCategory, setShowAddCategory] = useState(false);
  const [newCategoryName, setNewCategoryName] = useState("");
  const [customCategories, setCustomCategories] = useState<string[]>([]);

  const isIncome = transaction?.type === "income" || transaction?.type === "borrow" || transaction?.type === "receive";
  const isTransfer = transaction?.type === "transfer";
  const isLoanRelated = transaction ? ["lend", "borrow", "repay", "receive"].includes(transaction.type) : false;
  
  const defaultCategories = isIncome ? [...DEFAULT_CATEGORIES_IN] : [...DEFAULT_CATEGORIES_OUT];
  const allCategories = [...defaultCategories, ...customCategories];

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

  useEffect(() => {
    if (transaction) {
      setAmount(String(transaction.amount));
      setAccountId(transaction.from_account_id || transaction.to_account_id || "");
      setToAccountId(transaction.to_account_id || "");
      setPersonId(transaction.person_id || "");
      setCategory(transaction.category || "");
      setNote(transaction.note || "");
      setDate(new Date(transaction.date).toISOString().split('T')[0]);
    }
  }, [transaction]);

  if (!transaction) return null;

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

      onOpenChange(false);
      onSuccess();
    } catch (error) {
      console.error("[v0] Error updating transaction:", error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-4 pt-2">
      {/* Amount Input */}
      <div className="space-y-2">
        <Label htmlFor="amount" className="text-sm font-medium">Amount</Label>
        <div className="relative">
          <span className="absolute left-4 top-1/2 -translate-y-1/2 text-lg font-semibold text-muted-foreground">৳</span>
          <Input
            id="amount"
            type="number"
            placeholder="0"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            required
            min="0"
            step="0.01"
            className="pl-10 h-12 sm:h-14 text-xl sm:text-2xl font-bold"
          />
        </div>
      </div>

      {/* Account Selection */}
      <div className="space-y-2">
        <Label htmlFor="account" className="text-sm font-medium">
          {isTransfer ? "From Account" : "Account"}
        </Label>
        <Select value={accountId} onValueChange={setAccountId} required>
          <SelectTrigger className="h-11 sm:h-12">
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

      {/* To Account for Transfers */}
      {isTransfer && (
        <div className="space-y-2">
          <Label htmlFor="toAccount" className="text-sm font-medium">To Account</Label>
          <Select value={toAccountId} onValueChange={setToAccountId} required>
            <SelectTrigger className="h-11 sm:h-12">
              <SelectValue placeholder="Select destination account" />
            </SelectTrigger>
            <SelectContent>
              {accounts.map((account) => (
                <SelectItem key={account.id} value={account.id} disabled={account.id === accountId}>
                  {account.name}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
      )}

      {/* Category Selection (not for transfers or loan-related) with Add New Option */}
      {!isTransfer && !isLoanRelated && (
        <div className="space-y-2">
          <div className="flex items-center justify-between">
            <Label htmlFor="category" className="text-sm font-medium">Category</Label>
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
                className="h-11 sm:h-12 flex-1"
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
                className="h-11 sm:h-12 w-11 sm:w-12 bg-emerald-600 hover:bg-emerald-700"
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
                className="h-11 sm:h-12 w-11 sm:w-12 bg-transparent"
              >
                <X className="h-4 w-4" />
              </Button>
            </div>
          ) : (
            <Select value={category} onValueChange={setCategory}>
              <SelectTrigger className="h-11 sm:h-12">
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
        <div className="space-y-2">
          <Label htmlFor="person" className="text-sm font-medium">
            Person {isLoanRelated ? "(Required)" : "(Optional)"}
          </Label>
          <Select value={personId} onValueChange={setPersonId}>
            <SelectTrigger className="h-11 sm:h-12">
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

      {/* Date Input */}
      <div className="space-y-2">
        <Label htmlFor="date" className="text-sm font-medium">Date</Label>
        <Input
          id="date"
          type="date"
          value={date}
          onChange={(e) => setDate(e.target.value)}
          required
          max={new Date().toISOString().split('T')[0]}
          className="h-11 sm:h-12"
        />
      </div>

      {/* Note */}
      <div className="space-y-2">
        <Label htmlFor="note" className="text-sm font-medium">Note (Optional)</Label>
        <Textarea
          id="note"
          placeholder="Add a note..."
          value={note}
          onChange={(e) => setNote(e.target.value)}
          rows={2}
          className="resize-none"
        />
      </div>

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
          disabled={loading || !amount || !accountId}
        >
          {loading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
          Save Changes
        </Button>
      </div>
    </form>
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
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <div className="flex items-center gap-3">
              <HeaderIcon />
              <DialogTitle className="text-xl">
                Edit {getTypeLabel()}
              </DialogTitle>
            </div>
          </DialogHeader>
          <EditTransactionForm
            transaction={transaction}
            accounts={accounts}
            people={people}
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
            <DrawerTitle className="text-xl">
              Edit {getTypeLabel()}
            </DrawerTitle>
          </div>
        </DrawerHeader>
        <div className="overflow-y-auto">
          <EditTransactionForm
            transaction={transaction}
            accounts={accounts}
            people={people}
            onOpenChange={onOpenChange}
            onSuccess={onSuccess}
          />
        </div>
      </DrawerContent>
    </Drawer>
  );
}
