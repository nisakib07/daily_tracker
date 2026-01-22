"use client";

import { useState } from "react";
import type { Transaction } from "@/lib/types";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { 
  ArrowDownLeft, 
  ArrowUpRight, 
  ArrowRightLeft, 
  Inbox, 
  MoreVertical, 
  Pencil, 
  Trash2,
  HandCoins,
  Handshake,
  Loader2
} from "lucide-react";
import { format } from "date-fns";
import { cn } from "@/lib/utils";
import { createClient } from "@/lib/supabase/client";

interface ActivityListProps {
  transactions: Transaction[];
  getAccountName: (id: string | null) => string | null;
  getPersonName: (id: string | null) => string | null;
  onEdit: (transaction: Transaction) => void;
  onDelete: () => void;
}

export function ActivityList({ 
  transactions, 
  getAccountName, 
  getPersonName,
  onEdit,
  onDelete
}: ActivityListProps) {
  const [deleteId, setDeleteId] = useState<string | null>(null);
  const [deleting, setDeleting] = useState(false);

  const handleDelete = async () => {
    if (!deleteId) return;
    
    setDeleting(true);
    const supabase = createClient();
    
    try {
      const { error } = await supabase
        .from("transactions")
        .delete()
        .eq("id", deleteId);
      
      if (error) throw error;
      
      onDelete();
    } catch (error) {
      console.error("[v0] Error deleting transaction:", error);
    } finally {
      setDeleting(false);
      setDeleteId(null);
    }
  };

  if (transactions.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-12 sm:py-16 text-center">
        <div className="flex h-14 w-14 sm:h-16 sm:w-16 items-center justify-center rounded-full bg-slate-100 mb-4">
          <Inbox className="h-7 w-7 sm:h-8 sm:w-8 text-slate-400" />
        </div>
        <p className="font-medium text-foreground mb-1">No transactions</p>
        <p className="text-sm text-muted-foreground">
          Add your first transaction to get started
        </p>
      </div>
    );
  }

  const getIcon = (type: string) => {
    switch (type) {
      case "income":
        return <ArrowDownLeft className="h-4 w-4 sm:h-5 sm:w-5" />;
      case "expense":
        return <ArrowUpRight className="h-4 w-4 sm:h-5 sm:w-5" />;
      case "transfer":
        return <ArrowRightLeft className="h-4 w-4 sm:h-5 sm:w-5" />;
      case "lend":
        return <HandCoins className="h-4 w-4 sm:h-5 sm:w-5" />;
      case "borrow":
        return <Handshake className="h-4 w-4 sm:h-5 sm:w-5" />;
      case "repay":
        return <ArrowUpRight className="h-4 w-4 sm:h-5 sm:w-5" />;
      case "receive":
        return <ArrowDownLeft className="h-4 w-4 sm:h-5 sm:w-5" />;
      default:
        return <ArrowDownLeft className="h-4 w-4 sm:h-5 sm:w-5" />;
    }
  };

  const getIconStyle = (type: string) => {
    switch (type) {
      case "income":
      case "receive":
        return "bg-gradient-to-br from-emerald-100 to-emerald-200 text-emerald-600";
      case "expense":
      case "repay":
        return "bg-gradient-to-br from-rose-100 to-rose-200 text-rose-600";
      case "transfer":
        return "bg-gradient-to-br from-blue-100 to-blue-200 text-blue-600";
      case "lend":
        return "bg-gradient-to-br from-indigo-100 to-indigo-200 text-indigo-600";
      case "borrow":
        return "bg-gradient-to-br from-amber-100 to-amber-200 text-amber-600";
      default:
        return "bg-gradient-to-br from-slate-100 to-slate-200 text-slate-600";
    }
  };

  const getAmountStyle = (type: string) => {
    switch (type) {
      case "income":
      case "borrow":
      case "receive":
        return "text-emerald-600";
      case "expense":
      case "lend":
      case "repay":
        return "text-rose-600";
      case "transfer":
        return "text-blue-600";
      default:
        return "text-slate-600";
    }
  };

  const isMoneyIn = (type: string) => ["income", "borrow", "receive"].includes(type);

  const getTypeLabel = (type: string) => {
    switch (type) {
      case "income": return "Income";
      case "expense": return "Expense";
      case "transfer": return "Transfer";
      case "lend": return "Loan Given";
      case "borrow": return "Borrowed";
      case "repay": return "Loan Repaid";
      case "receive": return "Loan Received";
      default: return type;
    }
  };

  return (
    <>
      <div className="space-y-2">
        {transactions.map((tx) => {
          const isTransfer = tx.type === "transfer";
          const accountName = isTransfer 
            ? `${getAccountName(tx.from_account_id)} → ${getAccountName(tx.to_account_id)}`
            : getAccountName(isMoneyIn(tx.type) ? tx.to_account_id : tx.from_account_id);
          const personName = getPersonName(tx.person_id);

          return (
            <div
              key={tx.id}
              className="group flex items-center justify-between rounded-xl bg-white border border-slate-100 p-3 sm:p-4 transition-all hover:shadow-md hover:border-slate-200"
            >
              <div className="flex items-center gap-2 sm:gap-3 flex-1 min-w-0">
                <div
                  className={cn(
                    "flex h-9 w-9 sm:h-11 sm:w-11 flex-shrink-0 items-center justify-center rounded-lg sm:rounded-xl transition-transform group-hover:scale-110",
                    getIconStyle(tx.type)
                  )}
                >
                  {getIcon(tx.type)}
                </div>
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-1 sm:gap-2 flex-wrap">
                    <p className="font-semibold text-foreground text-sm sm:text-base truncate">
                      {tx.category || getTypeLabel(tx.type)}
                    </p>
                    {["lend", "borrow", "repay", "receive"].includes(tx.type) && (
                      <span className={cn(
                        "text-[10px] sm:text-xs px-1.5 sm:px-2 py-0.5 rounded-full font-medium flex-shrink-0",
                        tx.type === "lend" || tx.type === "repay" 
                          ? "bg-rose-100 text-rose-700"
                          : "bg-emerald-100 text-emerald-700"
                      )}>
                        {getTypeLabel(tx.type)}
                      </span>
                    )}
                  </div>
                  <p className="text-xs sm:text-sm text-muted-foreground truncate">
                    {accountName}
                    {personName && <span className="text-slate-400"> • {personName}</span>}
                  </p>
                  {tx.note && (
                    <p className="text-[10px] sm:text-xs text-muted-foreground/70 mt-0.5 line-clamp-1">
                      {tx.note}
                    </p>
                  )}
                </div>
              </div>
              
              <div className="flex items-center gap-1 sm:gap-2 flex-shrink-0 ml-2">
                <div className="text-right">
                  <p className={cn("text-base sm:text-lg font-bold", getAmountStyle(tx.type))}>
                    {isMoneyIn(tx.type) ? "+" : "-"}৳{Number(tx.amount).toLocaleString()}
                  </p>
                  <p className="text-[10px] sm:text-xs text-muted-foreground">
                    {format(new Date(tx.date), "h:mm a")}
                  </p>
                </div>

                {/* Actions Dropdown */}
                <DropdownMenu>
                  <DropdownMenuTrigger asChild>
                    <Button 
                      variant="ghost" 
                      size="icon" 
                      className="h-8 w-8 sm:opacity-0 sm:group-hover:opacity-100 transition-opacity"
                    >
                      <MoreVertical className="h-4 w-4" />
                    </Button>
                  </DropdownMenuTrigger>
                  <DropdownMenuContent align="end">
                    <DropdownMenuItem onClick={() => onEdit(tx)}>
                      <Pencil className="mr-2 h-4 w-4" />
                      Edit
                    </DropdownMenuItem>
                    <DropdownMenuItem 
                      onClick={() => setDeleteId(tx.id)}
                      className="text-rose-600 focus:text-rose-600"
                    >
                      <Trash2 className="mr-2 h-4 w-4" />
                      Delete
                    </DropdownMenuItem>
                  </DropdownMenuContent>
                </DropdownMenu>
              </div>
            </div>
          );
        })}
      </div>

      {/* Delete Confirmation Dialog */}
      <AlertDialog open={!!deleteId} onOpenChange={(open) => !open && setDeleteId(null)}>
        <AlertDialogContent className="mx-4 sm:mx-auto max-w-md">
          <AlertDialogHeader>
            <AlertDialogTitle>Delete Transaction</AlertDialogTitle>
            <AlertDialogDescription>
              Are you sure you want to delete this transaction? This action cannot be undone and will affect your account balance.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter className="flex-col sm:flex-row gap-2">
            <AlertDialogCancel disabled={deleting} className="bg-transparent">Cancel</AlertDialogCancel>
            <AlertDialogAction
              onClick={handleDelete}
              className="bg-rose-600 hover:bg-rose-700"
              disabled={deleting}
            >
              {deleting && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
              Delete
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  );
}
