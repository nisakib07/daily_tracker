"use client";

import { useMemo } from "react";
import { format } from "date-fns";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { cn } from "@/lib/utils";
import type { Account, Person, Transaction } from "@/lib/types";
import { ArrowDownLeft, ArrowUpRight } from "lucide-react";

type Props = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  person: Person | null;
  transactions: Transaction[];
  accounts: Account[];
  onSuccess?: () => void; // keep if you want, but not required for this approach
  onQuickAction?: (action: "repay" | "receive", personId: string) => void; // ✅ NEW
};

function getLoanLabel(type: Transaction["type"]) {
  switch (type) {
    case "borrow":
      return "Borrowed (you received)";
    case "lend":
      return "Lent (you gave)";
    case "repay":
      return "Repaid (you paid back)";
    case "receive":
      return "Received (they repaid)";
    default:
      return type;
  }
}

function getAccountName(tx: Transaction, accountsMap: Record<string, string>) {
  // borrow/receive => money came IN => to_account_id is relevant
  if (tx.type === "borrow" || tx.type === "receive") {
    return tx.to_account_id ? accountsMap[tx.to_account_id] || "Unknown" : "-";
  }
  // lend/repay => money went OUT => from_account_id is relevant
  if (tx.type === "lend" || tx.type === "repay") {
    return tx.from_account_id
      ? accountsMap[tx.from_account_id] || "Unknown"
      : "-";
  }
  return "-";
}

export function PersonLedgerSheet({
  open,
  onOpenChange,
  person,
  transactions,
  accounts,
  onQuickAction,
}: Props) {
  const accountsMap = useMemo(() => {
    const map: Record<string, string> = {};
    for (const a of accounts) map[a.id] = a.name;
    return map;
  }, [accounts]);

  const personTx = useMemo(() => {
    if (!person) return [];
    return transactions
      .filter(
        (tx) =>
          tx.person_id === person.id &&
          (tx.type === "borrow" ||
            tx.type === "lend" ||
            tx.type === "repay" ||
            tx.type === "receive"),
      )
      .sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());
  }, [transactions, person]);

  // netBalance: + => they owe you, - => you owe them
  const netBalance = useMemo(() => {
    let youOwe = 0;
    let theyOwe = 0;

    for (const tx of personTx) {
      const amt = Number(tx.amount);
      if (tx.type === "borrow") youOwe += amt;
      if (tx.type === "lend") theyOwe += amt;
      if (tx.type === "repay") youOwe -= amt;
      if (tx.type === "receive") theyOwe -= amt;
    }

    youOwe = Math.max(0, youOwe);
    theyOwe = Math.max(0, theyOwe);
    return theyOwe - youOwe;
  }, [personTx]);

  // running balance for timeline (same meaning as netBalance)
  const timeline = useMemo(() => {
    let running = 0;
    return personTx.map((tx) => {
      const amt = Number(tx.amount);

      // + increases "they owe you", - increases "you owe them"
      if (tx.type === "lend" || tx.type === "repay") running += amt;
      if (tx.type === "borrow" || tx.type === "receive") running -= amt;

      return { tx, running };
    });
  }, [personTx]);

  const statusText = netBalance >= 0 ? "Owes you" : "You owe";
  const amountText = `${netBalance >= 0 ? "+" : "-"}৳${Math.abs(netBalance).toLocaleString()}`;

  const canReceive = !!person && netBalance > 0; // they owe you
  const canRepay = !!person && netBalance < 0; // you owe them

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent side="right" className="w-full sm:max-w-md">
        <SheetHeader>
          <SheetTitle className="flex items-center justify-between gap-3">
            <span>{person ? person.name : "Person"}</span>
            <span
              className={cn(
                "text-sm font-semibold",
                netBalance >= 0 ? "text-emerald-600" : "text-amber-600",
              )}
            >
              {amountText}
            </span>
          </SheetTitle>

          {person ? (
            <div className="text-xs text-muted-foreground">
              {statusText}
              {person.phone ? ` • ${person.phone}` : ""}
            </div>
          ) : null}
        </SheetHeader>

        <div className="mt-4 space-y-3">
          {/* ✅ Quick actions (opens TransactionModal, no duplicate form here) */}
          {person && (canReceive || canRepay) ? (
            <Card className="p-3">
              <div className="flex items-center justify-between">
                <div className="text-sm font-semibold">Quick settle</div>
                <div
                  className={cn(
                    "text-xs font-medium",
                    netBalance >= 0 ? "text-emerald-600" : "text-amber-600",
                  )}
                >
                  {netBalance >= 0 ? "They owe you" : "You owe them"}
                </div>
              </div>

              <div className="mt-3 grid grid-cols-2 gap-2">
                <Button
                  type="button"
                  className={cn(
                    "h-11 font-semibold",
                    canReceive
                      ? "bg-gradient-to-r from-emerald-500 to-teal-600 hover:from-emerald-600 hover:to-teal-700"
                      : "bg-slate-200 text-slate-500 hover:bg-slate-200",
                  )}
                  disabled={!canReceive}
                  onClick={() =>
                    person && onQuickAction?.("receive", person.id)
                  }
                >
                  <ArrowDownLeft className="mr-2 h-4 w-4" />
                  Receive
                </Button>

                <Button
                  type="button"
                  className={cn(
                    "h-11 font-semibold",
                    canRepay
                      ? "bg-gradient-to-r from-rose-500 to-pink-600 hover:from-rose-600 hover:to-pink-700"
                      : "bg-slate-200 text-slate-500 hover:bg-slate-200",
                  )}
                  disabled={!canRepay}
                  onClick={() => person && onQuickAction?.("repay", person.id)}
                >
                  <ArrowUpRight className="mr-2 h-4 w-4" />
                  Repay
                </Button>
              </div>

              <p className="mt-2 text-[11px] text-muted-foreground">
                This opens the transaction modal with the person pre-selected.
              </p>
            </Card>
          ) : (
            <Card className="p-3">
              <div className="flex items-center justify-between">
                <div className="text-xs text-muted-foreground">
                  Current Status
                </div>
                <div
                  className={cn(
                    "text-sm font-bold",
                    netBalance >= 0 ? "text-emerald-600" : "text-amber-600",
                  )}
                >
                  {statusText}
                </div>
              </div>
            </Card>
          )}

          {/* Timeline */}
          <div className="space-y-2">
            <div className="text-sm font-semibold">History</div>

            {timeline.length === 0 ? (
              <Card className="p-4 text-sm text-muted-foreground">
                No loan transactions found.
              </Card>
            ) : (
              timeline.map(({ tx, running }) => {
                const isIn = tx.type === "borrow" || tx.type === "receive";
                const badgeClass = isIn
                  ? "bg-emerald-50 text-emerald-700"
                  : "bg-amber-50 text-amber-700";

                return (
                  <Card key={tx.id} className="p-3">
                    <div className="flex items-start justify-between gap-3">
                      <div className="min-w-0">
                        <div className="flex items-center gap-2">
                          <span
                            className={cn(
                              "rounded-full px-2 py-0.5 text-[11px] font-medium",
                              badgeClass,
                            )}
                          >
                            {getLoanLabel(tx.type)}
                          </span>
                          <span className="text-xs text-muted-foreground">
                            {format(new Date(tx.date), "dd MMM yyyy")}
                          </span>
                        </div>

                        <div className="mt-1 text-xs text-muted-foreground">
                          Account:{" "}
                          <span className="font-medium text-foreground">
                            {getAccountName(tx, accountsMap)}
                          </span>
                        </div>

                        {tx.note ? (
                          <div className="mt-1 text-xs text-muted-foreground">
                            Note:{" "}
                            <span className="text-foreground">{tx.note}</span>
                          </div>
                        ) : null}
                      </div>

                      <div className="text-right">
                        <div
                          className={cn(
                            "text-sm font-bold",
                            isIn ? "text-emerald-600" : "text-amber-600",
                          )}
                        >
                          {isIn ? "+" : "-"}৳
                          {Number(tx.amount).toLocaleString()}
                        </div>
                        <div className="mt-1 text-[11px] text-muted-foreground">
                          After:{" "}
                          <span
                            className={cn(
                              "font-semibold",
                              running >= 0
                                ? "text-emerald-600"
                                : "text-amber-600",
                            )}
                          >
                            {running >= 0 ? "+" : "-"}৳
                            {Math.abs(running).toLocaleString()}
                          </span>
                        </div>
                      </div>
                    </div>
                  </Card>
                );
              })
            )}
          </div>

          <div className="pt-2">
            <Button
              variant="outline"
              className="w-full bg-transparent"
              onClick={() => onOpenChange(false)}
            >
              Close
            </Button>
          </div>
        </div>
      </SheetContent>
    </Sheet>
  );
}
