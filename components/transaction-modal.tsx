"use client";

import React, { useEffect, useMemo, useState } from "react";
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
import { useAuth } from "@/lib/auth-context";
import {
  Loader2,
  Plus,
  ArrowDownLeft,
  ArrowUpRight,
  HandCoins,
  Handshake,
  X,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useMediaQuery } from "@/hooks/use-media-query";
import { QuickAddShortcuts } from "@/components/quick-add-shortcuts";
import { suggestCategory } from "@/lib/smart-insights";
import { format } from "date-fns";

type TransactionSubType = "regular" | "loan";
type DefaultLoanAction = "borrow" | "lend" | "repay" | "receive";

interface TransactionModalProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  type: TransactionType;
  accounts: Account[];
  people: Person[];
  onSuccess: () => void;
  onAddPerson: () => void;

  // ✅ NEW (Option B)
  defaultSubType?: TransactionSubType;
  defaultPersonId?: string | null;
  defaultLoanAction?: DefaultLoanAction | null;
}

// Local storage keys for custom categories
const CUSTOM_INCOME_CATEGORIES_KEY = "dmt_custom_income_categories";
const CUSTOM_EXPENSE_CATEGORIES_KEY = "dmt_custom_expense_categories";

function TransactionForm({
  open,
  type,
  accounts,
  people,
  onSuccess,
  onAddPerson,
  onOpenChange,

  // ✅ NEW
  defaultSubType,
  defaultPersonId,
  defaultLoanAction,
}: Omit<TransactionModalProps, "open"> & { open: boolean }) {
  const { user } = useAuth();
  // Initialize state directly from defaults
  const [subType, setSubType] = useState<TransactionSubType>(defaultSubType || "regular");
  const [amount, setAmount] = useState("");
  const [accountId, setAccountId] = useState("");
  const [personId, setPersonId] = useState(defaultPersonId || "");
  const [category, setCategory] = useState("");
  const [note, setNote] = useState("");
  const [date, setDate] = useState(format(new Date(), "yyyy-MM-dd"));
  const [loading, setLoading] = useState(false);

  // Custom category state
  const [showAddCategory, setShowAddCategory] = useState(false);
  const [newCategoryName, setNewCategoryName] = useState("");
  const [customCategories, setCustomCategories] = useState<string[]>([]);


  const isIncome = type === "in";
  const defaultCategories = isIncome
    ? [...DEFAULT_CATEGORIES_IN]
    : [...DEFAULT_CATEGORIES_OUT];
  const allCategories = useMemo(
    () => [...defaultCategories, ...customCategories],
    [defaultCategories, customCategories],
  );



  // Load custom categories from localStorage on mount
  useEffect(() => {
    const storageKey = isIncome
      ? CUSTOM_INCOME_CATEGORIES_KEY
      : CUSTOM_EXPENSE_CATEGORIES_KEY;
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

    const storageKey = isIncome
      ? CUSTOM_INCOME_CATEGORIES_KEY
      : CUSTOM_EXPENSE_CATEGORIES_KEY;
    localStorage.setItem(storageKey, JSON.stringify(updatedCategories));

    setCategory(trimmedName);
    setNewCategoryName("");
    setShowAddCategory(false);
  };

  const resetForm = () => {
    setSubType("regular");
    setAmount("");
    setAccountId("");
    setPersonId("");
    setCategory("");
    setNote("");
    setDate(format(new Date(), "yyyy-MM-dd"));
    setShowAddCategory(false);
    setNewCategoryName("");
  };

  const handleCreateRegularOrBorrowLend = async () => {
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
        user_id: user?.id,
        occurred_at: (() => {
          const now = new Date();
          const [year, month, day] = date.split('-').map(Number);
          now.setFullYear(year, month - 1, day);
          return now.toISOString();
        })(),
      });

      if (txError) throw txError;

      resetForm();
      onOpenChange(false);
      onSuccess();
    } catch (error) {
      console.error("[v0] Error creating transaction:", error);
      alert("Something went wrong while saving. Please try again.");
    } finally {
      setLoading(false);
    }
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
        category:
          actionType === "repay" ? "Loan Repayment" : "Loan Received Back",
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
      console.error("[v0] Error creating loan action:", error);
      alert("Something went wrong while saving. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  // ✅ If dashboard asks for defaultLoanAction and we are on loan tab,
  // we can auto-trigger repay/receive after required fields are ready.
  // We DO NOT auto-trigger borrow/lend because those are “create” actions
  // and we don’t want to create rows without user intent.
  useEffect(() => {
    if (!open) return;
    if (subType !== "loan") return;
    if (!defaultLoanAction) return;

    // Only auto-trigger repay/receive
    if (defaultLoanAction !== "repay" && defaultLoanAction !== "receive")
      return;

    // Wait until user has selected account + amount.
    // We won't auto-run without them; this is just for "button highlight" flow.
    // (You can change this later if you want strict auto-action)
  }, [open, subType, defaultLoanAction]);

  const titlePrimaryRegular = isIncome ? "Add Income" : "Add Expense";
  const isRegularSubmitDisabled =
    loading || !amount || !accountId || (!showAddCategory && !category);

  const isLoanDisabled = loading || !amount || !accountId || !personId;

  // ✅ if we’re on loan tab and defaultLoanAction is repay/receive,
  // visually "emphasize" that button (without forcing action).
  const emphasizeReceive =
    subType === "loan" && defaultLoanAction === "receive";
  const emphasizeRepay = subType === "loan" && defaultLoanAction === "repay";

  return (
    <div className="flex flex-col min-h-0 h-full">
      <Tabs
        value={subType}
        onValueChange={(v) => setSubType(v as TransactionSubType)}
        className="flex flex-1 flex-col min-h-0"
      >
        <TabsList className="grid w-full grid-cols-2 mb-3 h-auto p-1">
          <TabsTrigger
            value="regular"
            className="flex items-center gap-1.5 text-xs sm:text-sm py-2"
          >
            {isIncome ? (
              <ArrowDownLeft className="h-3.5 w-3.5 sm:h-4 sm:w-4" />
            ) : (
              <ArrowUpRight className="h-3.5 w-3.5 sm:h-4 sm:w-4" />
            )}
            <span className="truncate">
              {isIncome ? "Regular Income" : "Regular Expense"}
            </span>
          </TabsTrigger>
          <TabsTrigger
            value="loan"
            className="flex items-center gap-1.5 text-xs sm:text-sm py-2"
          >
            {isIncome ? (
              <Handshake className="h-3.5 w-3.5 sm:h-4 sm:w-4" />
            ) : (
              <HandCoins className="h-3.5 w-3.5 sm:h-4 sm:w-4" />
            )}
            <span className="truncate">
              {isIncome ? "Borrow/Receive" : "Lend/Repay"}
            </span>
          </TabsTrigger>
        </TabsList>

        {/* Scrollable content area */}
        <div className="flex-1 min-h-0 overflow-y-auto scrollbar-hide pb-4">
          <form
            onSubmit={(e) => {
              e.preventDefault();
              if (subType === "regular") {
                handleCreateRegularOrBorrowLend();
              }
            }}
            className="space-y-3"
          >
            {/* ✨ Hero Amount Input */}
            <div
              className={cn(
                "rounded-2xl p-4 transition-all",
                isIncome
                  ? "bg-emerald-50/80 dark:bg-emerald-950/30 hero-glow-emerald"
                  : "bg-rose-50/80 dark:bg-rose-950/30 hero-glow-rose"
              )}
            >
              <Label htmlFor="amount" className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-2 block">
                Amount
              </Label>
              <div className="relative">
                <span className={cn(
                  "absolute left-3 top-1/2 -translate-y-1/2 text-2xl font-bold",
                  isIncome ? "text-emerald-500" : "text-rose-500"
                )}>
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
                  className={cn(
                    "pl-10 h-14 text-2xl font-bold bg-white/80 dark:bg-white/5 border-0 rounded-xl shadow-sm focus-visible:ring-2 transition-shadow",
                    isIncome ? "focus-visible:ring-emerald-400" : "focus-visible:ring-rose-400"
                  )}
                />
              </div>
            </div>

            {/* 📋 Details Section */}
            <div className="drawer-section space-y-3">
              <p className="text-[11px] font-semibold text-muted-foreground uppercase tracking-wider flex items-center gap-1.5">
                <span>📋</span> Details
              </p>

              {/* Account Selection */}
              <div className="space-y-1.5">
                <Label htmlFor="account" className="text-xs font-medium">
                  {isIncome ? "To Account" : "From Account"}
                </Label>
                <Select value={accountId} onValueChange={setAccountId} required>
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

            <TabsContent value="regular" className="space-y-3 mt-0">
              {/* Quick Add Shortcuts for expenses */}
              {!isIncome && (
                <QuickAddShortcuts 
                  onSelect={({ category: cat, label, defaultAmount, defaultAccountName }) => {
                    setCategory(cat);
                    setNote(label || "");
                    if (defaultAmount && !amount) {
                      setAmount(defaultAmount.toString());
                    }
                    if (defaultAccountName) {
                      const matchingAccount = accounts.find(
                        (acc) => acc.name.toLowerCase() === defaultAccountName.toLowerCase()
                      );
                      if (matchingAccount) {
                        setAccountId(matchingAccount.id);
                      }
                    }
                  }}
                />
              )}
              
              {/* Category */}
              <div className="space-y-1.5">
                <div className="flex items-center justify-between">
                  <Label htmlFor="category" className="text-xs font-medium">
                    Category
                  </Label>
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
                  <Select value={category} onValueChange={setCategory} required>
                    <SelectTrigger className="h-11 rounded-xl">
                      <SelectValue placeholder="Select category" />
                    </SelectTrigger>
                    <SelectContent>
                      {allCategories.map((cat) => (
                        <SelectItem key={cat} value={cat}>
                          {cat}
                          {customCategories.includes(cat) && (
                            <span className="ml-2 text-xs text-muted-foreground">
                              (custom)
                            </span>
                          )}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                )}
              </div>

              {/* Person (Optional) */}
              <div className="space-y-1.5">
                <div className="flex items-center justify-between">
                  <Label htmlFor="person" className="text-xs font-medium">
                    Person <span className="text-muted-foreground">(Optional)</span>
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
                <Select value={personId} onValueChange={setPersonId}>
                  <SelectTrigger className="h-11 rounded-xl">
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

            <TabsContent value="loan" className="space-y-3 mt-0">
              {/* Loan Info */}
              <div
                className={cn(
                  "p-3 rounded-xl border",
                  isIncome
                    ? "bg-emerald-50 dark:bg-emerald-950/40 border-emerald-200 dark:border-emerald-800"
                    : "bg-rose-50 dark:bg-rose-950/40 border-rose-200 dark:border-rose-800",
                )}
              >
                <p
                  className={cn(
                    "text-xs font-medium mb-1",
                    isIncome ? "text-emerald-700 dark:text-emerald-300" : "text-rose-700 dark:text-rose-300",
                  )}
                >
                  {isIncome
                    ? "Choose what type of money you're receiving:"
                    : "Choose what type of payment you're making:"}
                </p>
                <p
                  className={cn(
                    "text-[10px] whitespace-pre-line",
                    isIncome ? "text-emerald-600 dark:text-emerald-400" : "text-rose-600 dark:text-rose-400",
                  )}
                >
                  {isIncome
                    ? "• Borrow: Someone lends you money\n• Receive: Someone pays back what they owed you"
                    : "• Lend: You give a loan to someone\n• Repay: You pay back what you borrowed"}
                </p>
              </div>

              {/* Person Selection (Required) */}
              <div className="space-y-1.5">
                <div className="flex items-center justify-between">
                  <Label htmlFor="loanPerson" className="text-xs font-medium">
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
                  <SelectTrigger className="h-11 rounded-xl">
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
            </TabsContent>
            </div>

            {/* 📝 Extras Section */}
            <div className="drawer-section space-y-3">
              <p className="text-[11px] font-semibold text-muted-foreground uppercase tracking-wider flex items-center gap-1.5">
                <span>📝</span> Extras
              </p>

              {/* Date */}
              <div className="space-y-1.5">
                <Label htmlFor="date" className="text-xs font-medium">
                  Date
                </Label>
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

              {/* Note with Smart Category Suggestion */}
              <div className="space-y-1.5">
                <Label htmlFor="note" className="text-xs font-medium">
                  Note <span className="text-muted-foreground">(Optional)</span>
                </Label>
                <Textarea
                  id="note"
                  placeholder={isIncome 
                    ? "e.g., 'salary' or 'upwork' auto-suggests category"
                    : "e.g., 'uber ride' auto-suggests Transport"
                  }
                  value={note}
                  onChange={(e) => {
                    const newNote = e.target.value;
                    setNote(newNote);
                    
                    if (subType === "regular") {
                      const suggested = suggestCategory(newNote);
                      if (suggested && allCategories.includes(suggested)) {
                        setCategory(suggested);
                      }
                    }
                  }}
                  rows={2}
                  className="resize-none rounded-xl"
                />
                {subType === "regular" && (
                  <p className="text-[10px] text-muted-foreground flex items-center gap-1">
                    <span className="inline-flex items-center px-1 py-0.5 rounded text-[8px] font-medium bg-gradient-to-r from-violet-500 to-fuchsia-500 text-white">AI</span>
                    Auto-suggests category as you type
                  </p>
                )}
              </div>
            </div>
          </form>
        </div>

        {/* Fixed bottom action bar */}
        <div className="drawer-action-bar pt-3 pb-[env(safe-area-inset-bottom)]">
          {subType === "regular" ? (
            <div className="flex gap-2.5">
              <Button
                type="button"
                variant="outline"
                className="flex-1 h-12 rounded-xl bg-transparent active:scale-[0.98] transition-transform"
                onClick={() => onOpenChange(false)}
                disabled={loading}
              >
                Cancel
              </Button>
              <Button
                type="button"
                className={cn(
                  "flex-[1.5] h-12 rounded-xl font-semibold active:scale-[0.98] transition-transform shadow-lg",
                  isIncome
                    ? "bg-gradient-to-r from-emerald-500 to-emerald-600 hover:from-emerald-600 hover:to-emerald-700 shadow-emerald-500/25"
                    : "bg-gradient-to-r from-rose-500 to-rose-600 hover:from-rose-600 hover:to-rose-700 shadow-rose-500/25",
                )}
                disabled={isRegularSubmitDisabled}
                onClick={handleCreateRegularOrBorrowLend}
              >
                {loading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                {titlePrimaryRegular}
              </Button>
            </div>
          ) : (
            <div className="space-y-2">
              <div className="grid grid-cols-2 gap-2.5">
                {isIncome ? (
                  <>
                    <Button
                      type="button"
                      className={cn(
                        "h-12 rounded-xl font-semibold bg-gradient-to-r from-amber-500 to-orange-600 hover:from-amber-600 hover:to-orange-700 text-xs sm:text-sm active:scale-[0.98] transition-transform shadow-lg shadow-amber-500/20",
                        defaultLoanAction === "borrow" &&
                          "ring-2 ring-orange-300",
                      )}
                      disabled={isLoanDisabled}
                      onClick={handleCreateRegularOrBorrowLend}
                    >
                      {loading && (
                        <Loader2 className="mr-1.5 h-3.5 w-3.5 animate-spin" />
                      )}
                      <Handshake className="mr-1.5 h-3.5 w-3.5" />
                      Borrow
                    </Button>
                    <Button
                      type="button"
                      onClick={() => handleLoanAction("receive")}
                      className={cn(
                        "h-12 rounded-xl font-semibold bg-gradient-to-r from-emerald-500 to-teal-600 hover:from-emerald-600 hover:to-teal-700 text-xs sm:text-sm active:scale-[0.98] transition-transform shadow-lg shadow-emerald-500/20",
                        emphasizeReceive && "ring-2 ring-emerald-300",
                      )}
                      disabled={isLoanDisabled}
                    >
                      {loading && (
                        <Loader2 className="mr-1.5 h-3.5 w-3.5 animate-spin" />
                      )}
                      <ArrowDownLeft className="mr-1.5 h-3.5 w-3.5" />
                      Receive
                    </Button>
                  </>
                ) : (
                  <>
                    <Button
                      type="button"
                      className={cn(
                        "h-12 rounded-xl font-semibold bg-gradient-to-r from-blue-500 to-indigo-600 hover:from-blue-600 hover:to-indigo-700 text-xs sm:text-sm active:scale-[0.98] transition-transform shadow-lg shadow-blue-500/20",
                        defaultLoanAction === "lend" &&
                          "ring-2 ring-indigo-300",
                      )}
                      disabled={isLoanDisabled}
                      onClick={handleCreateRegularOrBorrowLend}
                    >
                      {loading && (
                        <Loader2 className="mr-1.5 h-3.5 w-3.5 animate-spin" />
                      )}
                      <HandCoins className="mr-1.5 h-3.5 w-3.5" />
                      Give Loan
                    </Button>
                    <Button
                      type="button"
                      onClick={() => handleLoanAction("repay")}
                      className={cn(
                        "h-12 rounded-xl font-semibold bg-gradient-to-r from-rose-500 to-pink-600 hover:from-rose-600 hover:to-pink-700 text-xs sm:text-sm active:scale-[0.98] transition-transform shadow-lg shadow-rose-500/20",
                        emphasizeRepay && "ring-2 ring-rose-300",
                      )}
                      disabled={isLoanDisabled}
                    >
                      {loading && (
                        <Loader2 className="mr-1.5 h-3.5 w-3.5 animate-spin" />
                      )}
                      <ArrowUpRight className="mr-1.5 h-3.5 w-3.5" />
                      Repay
                    </Button>
                  </>
                )}
              </div>

              <Button
                type="button"
                variant="outline"
                className="w-full h-11 rounded-xl bg-transparent active:scale-[0.98] transition-transform"
                onClick={() => onOpenChange(false)}
                disabled={loading}
              >
                Cancel
              </Button>
            </div>
          )}
        </div>
      </Tabs>
    </div>
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

  // ✅ NEW
  defaultSubType,
  defaultPersonId,
  defaultLoanAction,
}: TransactionModalProps) {
  const isDesktop = useMediaQuery("(min-width: 640px)");
  const isIncome = type === "in";

  const HeaderIcon = () => (
    <div
      className={cn(
        "flex h-9 w-9 sm:h-10 sm:w-10 items-center justify-center rounded-xl text-white",
        isIncome
          ? "bg-gradient-to-br from-emerald-500 to-emerald-600"
          : "bg-gradient-to-br from-rose-500 to-rose-600",
      )}
    >
      {isIncome ? (
        <ArrowDownLeft className="h-4 w-4 sm:h-5 sm:w-5" />
      ) : (
        <ArrowUpRight className="h-4 w-4 sm:h-5 sm:w-5" />
      )}
    </div>
  );

  const title = isIncome ? "Add Money In" : "Add Money Out";

  if (isDesktop) {
    return (
      <Dialog open={open} onOpenChange={onOpenChange}>
        <DialogContent className="sm:max-w-md p-0 overflow-hidden">
          <div className="p-4 pb-0">
            <DialogHeader>
              <div className="flex items-center gap-3">
                <HeaderIcon />
                <DialogTitle
                  className={cn(
                    "text-xl",
                    isIncome ? "text-emerald-600" : "text-rose-600",
                  )}
                >
                  {title}
                </DialogTitle>
              </div>
            </DialogHeader>
          </div>

          <div className="px-4 pb-4 max-h-[80vh] flex flex-col">
            <TransactionForm
              key={`${defaultSubType}-${defaultPersonId}-${defaultLoanAction}`}
              open={open}
              type={type}
              accounts={accounts}
              people={people}
              onSuccess={onSuccess}
              onAddPerson={onAddPerson}
              onOpenChange={onOpenChange}
              defaultSubType={defaultSubType}
              defaultPersonId={defaultPersonId}
              defaultLoanAction={defaultLoanAction}
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
              <DrawerTitle
                className={cn(
                  "text-lg",
                  isIncome ? "text-emerald-600" : "text-rose-600",
                )}
              >
                {title}
              </DrawerTitle>
              <p className="text-xs text-muted-foreground mt-0.5">
                {isIncome ? "Record your income details" : "Record your expense details"}
              </p>
            </div>
          </div>
        </DrawerHeader>

        <TransactionForm
          key={`${defaultSubType}-${defaultPersonId}-${defaultLoanAction}`}
          open={open}
          type={type}
          accounts={accounts}
          people={people}
          onSuccess={onSuccess}
          onAddPerson={onAddPerson}
          onOpenChange={onOpenChange}
          defaultSubType={defaultSubType}
          defaultPersonId={defaultPersonId}
          defaultLoanAction={defaultLoanAction}
        />
      </DrawerContent>
    </Drawer>
  );
}

