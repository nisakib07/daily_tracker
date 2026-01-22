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
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import type { Account, Person, TransactionType } from "@/lib/types";
import { DEFAULT_CATEGORIES_IN, DEFAULT_CATEGORIES_OUT } from "@/lib/types";
import { createClient } from "@/lib/supabase/client";
import { Loader2, Plus, ArrowDownLeft, ArrowUpRight, HandCoins, Handshake, X } from "lucide-react";
import { cn } from "@/lib/utils";
import { useMediaQuery } from "@/hooks/use-media-query";

interface TransactionModalProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  type: TransactionType;
  accounts: Account[];
  people: Person[];
  onSuccess: () => void;
  onAddPerson: () => void;
}

type TransactionSubType = "regular" | "loan";

// Local storage keys for custom categories
const CUSTOM_INCOME_CATEGORIES_KEY = "dmt_custom_income_categories";
const CUSTOM_EXPENSE_CATEGORIES_KEY = "dmt_custom_expense_categories";

function TransactionForm({
  type,
  accounts,
  people,
  onSuccess,
  onAddPerson,
  onOpenChange,
}: Omit<TransactionModalProps, 'open'>) {
  const [subType, setSubType] = useState<TransactionSubType>("regular");
  const [amount, setAmount] = useState("");
  const [accountId, setAccountId] = useState("");
  const [personId, setPersonId] = useState("");
  const [category, setCategory] = useState("");
  const [note, setNote] = useState("");
  const [date, setDate] = useState(new Date().toISOString().split('T')[0]);
  const [loading, setLoading] = useState(false);
  
  // Custom category state
  const [showAddCategory, setShowAddCategory] = useState(false);
  const [newCategoryName, setNewCategoryName] = useState("");
  const [customCategories, setCustomCategories] = useState<string[]>([]);

  const isIncome = type === "in";
  const defaultCategories = isIncome ? [...DEFAULT_CATEGORIES_IN] : [...DEFAULT_CATEGORIES_OUT];
  const allCategories = [...defaultCategories, ...customCategories];

  // Load custom categories from localStorage on mount
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
    
    if (subType === "loan" && !personId) {
      alert("Please select a person for loan transactions");
      return;
    }

    setLoading(true);
    const supabase = createClient();

    try {
      let transactionType: string;
      let transactionCategory: string | null = category;

      if (subType === "loan") {
        if (isIncome) {
          transactionType = "borrow";
          transactionCategory = "Borrowed Money";
        } else {
          transactionType = "lend";
          transactionCategory = "Loan Given";
        }
      } else {
        transactionType = isIncome ? "income" : "expense";
      }

      const { error: txError } = await supabase.from("transactions").insert({
        type: transactionType,
        amount: parseFloat(amount),
        from_account_id: isIncome ? null : accountId,
        to_account_id: isIncome ? accountId : null,
        person_id: personId || null,
        category: transactionCategory,
        note: note || null,
        date: new Date(date).toISOString(),
      });

      if (txError) throw txError;

      resetForm();
      onOpenChange(false);
      onSuccess();
    } catch (error) {
      console.error("[v0] Error creating transaction:", error);
    } finally {
      setLoading(false);
    }
  };

  const resetForm = () => {
    setSubType("regular");
    setAmount("");
    setAccountId("");
    setPersonId("");
    setCategory("");
    setNote("");
    setDate(new Date().toISOString().split('T')[0]);
    setShowAddCategory(false);
    setNewCategoryName("");
  };

  const handleLoanAction = async (actionType: "repay" | "receive") => {
    if (!amount || !accountId || !personId) {
      alert("Please fill all required fields");
      return;
    }

    setLoading(true);
    const supabase = createClient();

    try {
      const { error } = await supabase.from("transactions").insert({
        type: actionType,
        amount: parseFloat(amount),
        from_account_id: actionType === "repay" ? accountId : null,
        to_account_id: actionType === "receive" ? accountId : null,
        person_id: personId,
        category: actionType === "repay" ? "Loan Repayment" : "Loan Received Back",
        note: note || null,
        date: new Date(date).toISOString(),
      });

      if (error) throw error;

      resetForm();
      onOpenChange(false);
      onSuccess();
    } catch (error) {
      console.error("[v0] Error creating loan action:", error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <Tabs value={subType} onValueChange={(v) => setSubType(v as TransactionSubType)} className="pt-2">
      <TabsList className="grid w-full grid-cols-2 mb-4 h-auto p-1">
        <TabsTrigger value="regular" className="flex items-center gap-1.5 text-xs sm:text-sm py-2">
          {isIncome ? <ArrowDownLeft className="h-3.5 w-3.5 sm:h-4 sm:w-4" /> : <ArrowUpRight className="h-3.5 w-3.5 sm:h-4 sm:w-4" />}
          <span className="truncate">{isIncome ? "Regular Income" : "Regular Expense"}</span>
        </TabsTrigger>
        <TabsTrigger value="loan" className="flex items-center gap-1.5 text-xs sm:text-sm py-2">
          {isIncome ? <Handshake className="h-3.5 w-3.5 sm:h-4 sm:w-4" /> : <HandCoins className="h-3.5 w-3.5 sm:h-4 sm:w-4" />}
          <span className="truncate">{isIncome ? "Borrow/Receive" : "Lend/Repay"}</span>
        </TabsTrigger>
      </TabsList>

      <form onSubmit={handleSubmit} className="space-y-4">
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
            {isIncome ? "To Account" : "From Account"}
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

        <TabsContent value="regular" className="space-y-4 mt-0">
          {/* Category Selection with Add New Option */}
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
              <Select value={category} onValueChange={setCategory} required>
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

          {/* Person Selection (Optional) */}
          <div className="space-y-2">
            <div className="flex items-center justify-between">
              <Label htmlFor="person" className="text-sm font-medium">Person (Optional)</Label>
              <Button
                type="button"
                variant="ghost"
                size="sm"
                className="h-auto p-0 text-xs font-medium text-primary hover:text-primary/80"
                onClick={onAddPerson}
              >
                <Plus className="mr-1 h-3 w-3" />
                Add New
              </Button>
            </div>
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
        </TabsContent>

        <TabsContent value="loan" className="space-y-4 mt-0">
          {/* Loan Info */}
          <div className={cn(
            "p-3 sm:p-4 rounded-xl border",
            isIncome ? "bg-emerald-50 border-emerald-200" : "bg-rose-50 border-rose-200"
          )}>
            <p className={cn(
              "text-xs sm:text-sm font-medium mb-1",
              isIncome ? "text-emerald-700" : "text-rose-700"
            )}>
              {isIncome 
                ? "Choose what type of money you're receiving:" 
                : "Choose what type of payment you're making:"}
            </p>
            <p className={cn(
              "text-[10px] sm:text-xs whitespace-pre-line",
              isIncome ? "text-emerald-600" : "text-rose-600"
            )}>
              {isIncome 
                ? "• Borrow: Someone lends you money\n• Receive: Someone pays back what they owed you" 
                : "• Lend: You give a loan to someone\n• Repay: You pay back what you borrowed"}
            </p>
          </div>

          {/* Person Selection (Required for loans) */}
          <div className="space-y-2">
            <div className="flex items-center justify-between">
              <Label htmlFor="loanPerson" className="text-sm font-medium">
                Person <span className="text-rose-500">*</span>
              </Label>
              <Button
                type="button"
                variant="ghost"
                size="sm"
                className="h-auto p-0 text-xs font-medium text-primary hover:text-primary/80"
                onClick={onAddPerson}
              >
                <Plus className="mr-1 h-3 w-3" />
                Add New
              </Button>
            </div>
            <Select value={personId} onValueChange={setPersonId} required>
              <SelectTrigger className="h-11 sm:h-12">
                <SelectValue placeholder="Select person (required)" />
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

          {/* Loan Action Buttons */}
          <div className="grid grid-cols-2 gap-2 sm:gap-3">
            {isIncome ? (
              <>
                <Button
                  type="submit"
                  className="h-10 sm:h-12 font-semibold bg-gradient-to-r from-amber-500 to-orange-600 hover:from-amber-600 hover:to-orange-700 text-xs sm:text-sm"
                  disabled={loading || !amount || !accountId || !personId}
                >
                  {loading && <Loader2 className="mr-1.5 h-3.5 w-3.5 sm:mr-2 sm:h-4 sm:w-4 animate-spin" />}
                  <Handshake className="mr-1.5 h-3.5 w-3.5 sm:mr-2 sm:h-4 sm:w-4" />
                  Borrow
                </Button>
                <Button
                  type="button"
                  onClick={() => handleLoanAction("receive")}
                  className="h-10 sm:h-12 font-semibold bg-gradient-to-r from-emerald-500 to-teal-600 hover:from-emerald-600 hover:to-teal-700 text-xs sm:text-sm"
                  disabled={loading || !amount || !accountId || !personId}
                >
                  {loading && <Loader2 className="mr-1.5 h-3.5 w-3.5 sm:mr-2 sm:h-4 sm:w-4 animate-spin" />}
                  <ArrowDownLeft className="mr-1.5 h-3.5 w-3.5 sm:mr-2 sm:h-4 sm:w-4" />
                  Receive
                </Button>
              </>
            ) : (
              <>
                <Button
                  type="submit"
                  className="h-10 sm:h-12 font-semibold bg-gradient-to-r from-blue-500 to-indigo-600 hover:from-blue-600 hover:to-indigo-700 text-xs sm:text-sm"
                  disabled={loading || !amount || !accountId || !personId}
                >
                  {loading && <Loader2 className="mr-1.5 h-3.5 w-3.5 sm:mr-2 sm:h-4 sm:w-4 animate-spin" />}
                  <HandCoins className="mr-1.5 h-3.5 w-3.5 sm:mr-2 sm:h-4 sm:w-4" />
                  Give Loan
                </Button>
                <Button
                  type="button"
                  onClick={() => handleLoanAction("repay")}
                  className="h-10 sm:h-12 font-semibold bg-gradient-to-r from-rose-500 to-pink-600 hover:from-rose-600 hover:to-pink-700 text-xs sm:text-sm"
                  disabled={loading || !amount || !accountId || !personId}
                >
                  {loading && <Loader2 className="mr-1.5 h-3.5 w-3.5 sm:mr-2 sm:h-4 sm:w-4" />}
                  <ArrowUpRight className="mr-1.5 h-3.5 w-3.5 sm:mr-2 sm:h-4 sm:w-4" />
                  Repay
                </Button>
              </>
            )}
          </div>
        </TabsContent>

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

        {/* Action Buttons for Regular Tab */}
        {subType === "regular" && (
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
              className={cn(
                "flex-1 h-10 sm:h-12 font-semibold",
                isIncome
                  ? "bg-gradient-to-r from-emerald-500 to-emerald-600 hover:from-emerald-600 hover:to-emerald-700"
                  : "bg-gradient-to-r from-rose-500 to-rose-600 hover:from-rose-600 hover:to-rose-700"
              )}
              disabled={loading || !amount || !accountId || (!showAddCategory && !category)}
            >
              {loading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
              {isIncome ? "Add Income" : "Add Expense"}
            </Button>
          </div>
        )}

        {/* Cancel button for Loan Tab */}
        {subType === "loan" && (
          <Button
            type="button"
            variant="outline"
            className="w-full h-10 sm:h-12 bg-transparent"
            onClick={() => onOpenChange(false)}
          >
            Cancel
          </Button>
        )}
      </form>
    </Tabs>
  );
}

export function TransactionModal({
  open,
  onOpenChange,
  type,
  accounts,
  people,
  onSuccess,
  onAddPerson,
}: TransactionModalProps) {
  const isDesktop = useMediaQuery("(min-width: 640px)");
  const isIncome = type === "in";

  const HeaderIcon = () => (
    <div className={cn(
      "flex h-9 w-9 sm:h-10 sm:w-10 items-center justify-center rounded-xl text-white",
      isIncome 
        ? "bg-gradient-to-br from-emerald-500 to-emerald-600" 
        : "bg-gradient-to-br from-rose-500 to-rose-600"
    )}>
      {isIncome ? <ArrowDownLeft className="h-4 w-4 sm:h-5 sm:w-5" /> : <ArrowUpRight className="h-4 w-4 sm:h-5 sm:w-5" />}
    </div>
  );

  const title = isIncome ? "Add Money In" : "Add Money Out";

  if (isDesktop) {
    return (
      <Dialog open={open} onOpenChange={onOpenChange}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <div className="flex items-center gap-3">
              <HeaderIcon />
              <DialogTitle className={cn(
                "text-xl",
                isIncome ? "text-emerald-600" : "text-rose-600"
              )}>
                {title}
              </DialogTitle>
            </div>
          </DialogHeader>
          <TransactionForm
            type={type}
            accounts={accounts}
            people={people}
            onSuccess={onSuccess}
            onAddPerson={onAddPerson}
            onOpenChange={onOpenChange}
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
            <DrawerTitle className={cn(
              "text-xl",
              isIncome ? "text-emerald-600" : "text-rose-600"
            )}>
              {title}
            </DrawerTitle>
          </div>
        </DrawerHeader>
        <div className="overflow-y-auto">
          <TransactionForm
            type={type}
            accounts={accounts}
            people={people}
            onSuccess={onSuccess}
            onAddPerson={onAddPerson}
            onOpenChange={onOpenChange}
          />
        </div>
      </DrawerContent>
    </Drawer>
  );
}
