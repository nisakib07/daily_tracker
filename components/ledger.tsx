"use client";

import { useMemo } from "react";
import { Card } from "@/components/ui/card";
import type { Transaction, Person, LedgerEntry } from "@/lib/types";
import {
  Users,
  ArrowUpRight,
  ArrowDownLeft,
  ChevronRight,
  Clock,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { format, parseISO } from "date-fns";

interface LedgerProps {
  transactions: Transaction[];
  people: Person[];
  onViewPerson?: (personId: string) => void;
}

type LedgerEntryWithMeta = LedgerEntry & {
  lastActivityAt: string | null;
};

export function Ledger({ transactions, people, onViewPerson }: LedgerProps) {
  const ledgerEntries: LedgerEntryWithMeta[] = useMemo(() => {
    // Only loan-related types matter here
    const loanTypes = new Set(["borrow", "lend", "repay", "receive"]);

    return people
      .map((person) => {
        const personTransactions = transactions.filter(
          (tx) => tx.person_id === person.id && loanTypes.has(tx.type),
        );

        let youOwe = 0; // Money you borrowed from them
        let theyOwe = 0; // Money they borrowed from you (loans given)
        let lastActivityAt: string | null = null;

        personTransactions.forEach((tx) => {
          const amount = Number(tx.amount);

          // Track last activity (latest tx.date)
          if (!lastActivityAt) lastActivityAt = tx.date;
          else {
            const curr = new Date(tx.date).getTime();
            const prev = new Date(lastActivityAt).getTime();
            if (curr > prev) lastActivityAt = tx.date;
          }

          switch (tx.type) {
            case "borrow":
              youOwe += amount;
              break;
            case "lend":
              theyOwe += amount;
              break;
            case "repay":
              youOwe -= amount;
              break;
            case "receive":
              theyOwe -= amount;
              break;
          }
        });

        const safeYouOwe = Math.max(0, youOwe);
        const safeTheyOwe = Math.max(0, theyOwe);
        const netBalance = safeTheyOwe - safeYouOwe; // + = they owe you, - = you owe them

        return {
          personId: person.id,
          personName: person.name,
          youOwe: safeYouOwe,
          theyOwe: safeTheyOwe,
          netBalance,
          lastActivityAt,
        };
      })
      .filter(
        (entry) =>
          entry.youOwe > 0 || entry.theyOwe > 0 || entry.netBalance !== 0,
      )
      .sort((a, b) => {
        // 1) most urgent first: bigger absolute net
        const diffAbs = Math.abs(b.netBalance) - Math.abs(a.netBalance);
        if (diffAbs !== 0) return diffAbs;

        // 2) if tie, most recent activity first
        const aTime = a.lastActivityAt
          ? new Date(a.lastActivityAt).getTime()
          : 0;
        const bTime = b.lastActivityAt
          ? new Date(b.lastActivityAt).getTime()
          : 0;
        return bTime - aTime;
      });
  }, [people, transactions]);

  const totalYouOwe = useMemo(
    () => ledgerEntries.reduce((sum, e) => sum + e.youOwe, 0),
    [ledgerEntries],
  );
  const totalTheyOwe = useMemo(
    () => ledgerEntries.reduce((sum, e) => sum + e.theyOwe, 0),
    [ledgerEntries],
  );

  const formatLastActivity = (iso: string | null) => {
    if (!iso) return null;
    try {
      // parseISO handles string ISO well; fallback to Date if needed
      const d = iso.includes("T") ? parseISO(iso) : new Date(iso);
      return format(d, "MMM d");
    } catch {
      return null;
    }
  };

  if (ledgerEntries.length === 0) {
    return (
      <Card className="p-6 border-dashed border-2 border-slate-200 bg-slate-50/50">
        <div className="flex flex-col items-center justify-center py-6 text-center">
          <div className="flex h-12 w-12 sm:h-14 sm:w-14 items-center justify-center rounded-full bg-slate-100 mb-4">
            <Users className="h-6 w-6 sm:h-7 sm:w-7 text-slate-400" />
          </div>
          <p className="font-medium text-foreground mb-1">
            No loans or borrows
          </p>
          <p className="text-xs sm:text-sm text-muted-foreground max-w-xs">
            When you lend or borrow money, it will appear here to help you track
            balances
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
            <span className="text-[10px] sm:text-xs font-medium text-emerald-600 uppercase tracking-wide">
              To Receive
            </span>
          </div>
          <p className="text-xl sm:text-2xl font-bold text-emerald-700">
            ৳{totalTheyOwe.toLocaleString()}
          </p>
          <p className="text-[10px] sm:text-xs text-emerald-600/70 mt-0.5 sm:mt-1">
            People owe you
          </p>
        </Card>

        <Card className="p-3 sm:p-4 border-0 bg-gradient-to-br from-amber-50 to-amber-100/50">
          <div className="flex items-center gap-1.5 sm:gap-2 mb-1.5 sm:mb-2">
            <ArrowUpRight className="h-3.5 w-3.5 sm:h-4 sm:w-4 text-amber-600" />
            <span className="text-[10px] sm:text-xs font-medium text-amber-600 uppercase tracking-wide">
              To Pay
            </span>
          </div>
          <p className="text-xl sm:text-2xl font-bold text-amber-700">
            ৳{totalYouOwe.toLocaleString()}
          </p>
          <p className="text-[10px] sm:text-xs text-amber-600/70 mt-0.5 sm:mt-1">
            You owe people
          </p>
        </Card>
      </div>

      {/* Ledger Entries */}
      <div className="space-y-2">
        {ledgerEntries.map((entry) => {
          const isReceive = entry.netBalance >= 0;
          const badgeText = isReceive ? "You will receive" : "You will pay";
          const last = formatLastActivity(entry.lastActivityAt);

          return (
            <Card
              key={entry.personId}
              role={onViewPerson ? "button" : undefined}
              tabIndex={onViewPerson ? 0 : undefined}
              className={cn(
                "border-0 shadow-sm transition-all",
                onViewPerson
                  ? "cursor-pointer hover:shadow-md active:scale-[0.99]"
                  : "",
              )}
              onClick={() => onViewPerson?.(entry.personId)}
              onKeyDown={(e) => {
                if (!onViewPerson) return;
                if (e.key === "Enter" || e.key === " ")
                  onViewPerson(entry.personId);
              }}
            >
              <div className="p-3 sm:p-4">
                <div className="flex items-start justify-between gap-3">
                  <div className="flex items-start gap-3 min-w-0">
                    <div
                      className={cn(
                        "flex h-11 w-11 sm:h-12 sm:w-12 items-center justify-center rounded-full text-white font-semibold text-sm",
                        isReceive
                          ? "bg-gradient-to-br from-emerald-500 to-teal-600"
                          : "bg-gradient-to-br from-amber-500 to-orange-600",
                      )}
                    >
                      {entry.personName.charAt(0).toUpperCase()}
                    </div>

                    <div className="min-w-0">
                      <div className="flex items-center gap-2 flex-wrap">
                        <p className="font-semibold text-foreground text-sm sm:text-base truncate">
                          {entry.personName}
                        </p>
                        <span
                          className={cn(
                            "text-[10px] sm:text-xs px-2 py-0.5 rounded-full font-medium",
                            isReceive
                              ? "bg-emerald-100 text-emerald-700"
                              : "bg-amber-100 text-amber-700",
                          )}
                        >
                          {badgeText}
                        </span>
                      </div>

                      <div className="flex items-center gap-2 mt-1 flex-wrap">
                        <p className="text-[11px] sm:text-xs text-muted-foreground">
                          {isReceive ? "Owes you" : "You owe"}
                        </p>

                        {last && (
                          <span className="inline-flex items-center gap-1 text-[11px] sm:text-xs text-muted-foreground">
                            <Clock className="h-3.5 w-3.5" />
                            Last: {last}
                          </span>
                        )}
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center gap-2 flex-shrink-0">
                    <p
                      className={cn(
                        "text-base sm:text-lg font-bold whitespace-nowrap",
                        isReceive ? "text-emerald-600" : "text-amber-600",
                      )}
                    >
                      {isReceive ? "+" : "-"}৳
                      {Math.abs(entry.netBalance).toLocaleString()}
                    </p>
                    <ChevronRight className="h-4 w-4 text-muted-foreground" />
                  </div>
                </div>

                {/* Optional: small breakdown row (helps trust) */}
                <div className="mt-3 grid grid-cols-2 gap-2 text-[11px] sm:text-xs">
                  <div className="rounded-lg bg-slate-50 border border-slate-100 px-2.5 py-2">
                    <p className="text-muted-foreground">They owe</p>
                    <p className="font-semibold text-emerald-700">
                      ৳{entry.theyOwe.toLocaleString()}
                    </p>
                  </div>
                  <div className="rounded-lg bg-slate-50 border border-slate-100 px-2.5 py-2">
                    <p className="text-muted-foreground">You owe</p>
                    <p className="font-semibold text-amber-700">
                      ৳{entry.youOwe.toLocaleString()}
                    </p>
                  </div>
                </div>
              </div>
            </Card>
          );
        })}
      </div>
    </div>
  );
}
