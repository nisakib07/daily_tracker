"use client";

import { Card } from "@/components/ui/card";
import type { Transaction, Person, LedgerEntry } from "@/lib/types";
import { Users, ArrowUpRight, ArrowDownLeft, ChevronRight } from "lucide-react";
import { cn } from "@/lib/utils";

interface LedgerProps {
  transactions: Transaction[];
  people: Person[];
  onViewPerson?: (personId: string) => void;
}

export function Ledger({ transactions, people, onViewPerson }: LedgerProps) {
  // Calculate ledger entries from all loan-related transactions
  const ledgerEntries: LedgerEntry[] = people.map((person) => {
    const personTransactions = transactions.filter(tx => tx.person_id === person.id);
    
    let youOwe = 0;   // Money you borrowed from them
    let theyOwe = 0;  // Money they borrowed from you (loans given)

    personTransactions.forEach(tx => {
      const amount = Number(tx.amount);
      switch (tx.type) {
        case "borrow":
          // You borrowed from them
          youOwe += amount;
          break;
        case "lend":
          // You lent to them
          theyOwe += amount;
          break;
        case "repay":
          // You repaid them
          youOwe -= amount;
          break;
        case "receive":
          // They repaid you
          theyOwe -= amount;
          break;
      }
    });

    return {
      personId: person.id,
      personName: person.name,
      youOwe: Math.max(0, youOwe),
      theyOwe: Math.max(0, theyOwe),
      netBalance: theyOwe - youOwe, // Positive = they owe you, Negative = you owe them
    };
  }).filter(entry => entry.youOwe > 0 || entry.theyOwe > 0 || entry.netBalance !== 0);

  // Calculate totals
  const totalYouOwe = ledgerEntries.reduce((sum, e) => sum + e.youOwe, 0);
  const totalTheyOwe = ledgerEntries.reduce((sum, e) => sum + e.theyOwe, 0);

  if (ledgerEntries.length === 0) {
    return (
      <Card className="p-6 border-dashed border-2 border-slate-200 bg-slate-50/50">
        <div className="flex flex-col items-center justify-center py-6 text-center">
          <div className="flex h-12 w-12 sm:h-14 sm:w-14 items-center justify-center rounded-full bg-slate-100 mb-4">
            <Users className="h-6 w-6 sm:h-7 sm:w-7 text-slate-400" />
          </div>
          <p className="font-medium text-foreground mb-1">No loans or borrows</p>
          <p className="text-xs sm:text-sm text-muted-foreground max-w-xs">
            When you lend or borrow money, it will appear here to help you track balances
          </p>
        </div>
      </Card>
    );
  }

  return (
    <div className="space-y-4">
      {/* Summary Cards */}
      <div className="grid grid-cols-2 gap-2 sm:gap-3">
        <Card className="p-3 sm:p-4 border-0 bg-gradient-to-br from-emerald-50 to-emerald-100/50">
          <div className="flex items-center gap-1.5 sm:gap-2 mb-1.5 sm:mb-2">
            <ArrowDownLeft className="h-3.5 w-3.5 sm:h-4 sm:w-4 text-emerald-600" />
            <span className="text-[10px] sm:text-xs font-medium text-emerald-600 uppercase tracking-wide">To Receive</span>
          </div>
          <p className="text-xl sm:text-2xl font-bold text-emerald-700">৳{totalTheyOwe.toLocaleString()}</p>
          <p className="text-[10px] sm:text-xs text-emerald-600/70 mt-0.5 sm:mt-1">People owe you</p>
        </Card>
        <Card className="p-3 sm:p-4 border-0 bg-gradient-to-br from-amber-50 to-amber-100/50">
          <div className="flex items-center gap-1.5 sm:gap-2 mb-1.5 sm:mb-2">
            <ArrowUpRight className="h-3.5 w-3.5 sm:h-4 sm:w-4 text-amber-600" />
            <span className="text-[10px] sm:text-xs font-medium text-amber-600 uppercase tracking-wide">To Pay</span>
          </div>
          <p className="text-xl sm:text-2xl font-bold text-amber-700">৳{totalYouOwe.toLocaleString()}</p>
          <p className="text-[10px] sm:text-xs text-amber-600/70 mt-0.5 sm:mt-1">You owe people</p>
        </Card>
      </div>

      {/* Ledger Entries */}
      <div className="space-y-2">
        {ledgerEntries.map((entry) => (
          <Card 
            key={entry.personId}
            className="p-3 sm:p-4 border-0 shadow-sm hover:shadow-md transition-all cursor-pointer"
            onClick={() => onViewPerson?.(entry.personId)}
          >
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2 sm:gap-3">
                <div className={cn(
                  "flex h-9 w-9 sm:h-10 sm:w-10 items-center justify-center rounded-full text-white font-semibold text-xs sm:text-sm",
                  entry.netBalance >= 0 
                    ? "bg-gradient-to-br from-emerald-500 to-teal-600"
                    : "bg-gradient-to-br from-amber-500 to-orange-600"
                )}>
                  {entry.personName.charAt(0).toUpperCase()}
                </div>
                <div>
                  <p className="font-semibold text-foreground text-sm sm:text-base">{entry.personName}</p>
                  <p className="text-[10px] sm:text-xs text-muted-foreground">
                    {entry.netBalance >= 0 ? "Owes you" : "You owe"}
                  </p>
                </div>
              </div>
              <div className="flex items-center gap-1 sm:gap-2">
                <p className={cn(
                  "text-base sm:text-lg font-bold",
                  entry.netBalance >= 0 ? "text-emerald-600" : "text-amber-600"
                )}>
                  {entry.netBalance >= 0 ? "+" : "-"}৳{Math.abs(entry.netBalance).toLocaleString()}
                </p>
                <ChevronRight className="h-4 w-4 text-muted-foreground" />
              </div>
            </div>
          </Card>
        ))}
      </div>
    </div>
  );
}
