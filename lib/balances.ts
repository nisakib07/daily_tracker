import type { Account, Transaction } from "@/lib/types";

export type AccountWithBalance = Account & { balance: number };

const accountTypeOrder: Record<string, number> = {
  cash: 0,
  wallet: 1,
  card: 2,
};

export function calculateAccountBalance(
  accountId: string,
  transactions: Transaction[],
) {
  const balance = transactions.reduce((total, transaction) => {
    const amount = Number(transaction.amount);
    if (!Number.isFinite(amount)) return total;

    if (transaction.to_account_id === accountId) total += amount;
    if (transaction.from_account_id === accountId) total -= amount;

    return total;
  }, 0);

  return Math.round(balance * 100) / 100;
}

export function addBalancesToAccounts(
  accounts: Account[],
  transactions: Transaction[],
): AccountWithBalance[] {
  return accounts
    .map((account) => ({
      ...account,
      balance: calculateAccountBalance(account.id, transactions),
    }))
    .sort((a, b) => {
      const orderA = accountTypeOrder[a.type] ?? 99;
      const orderB = accountTypeOrder[b.type] ?? 99;
      return orderA - orderB;
    });
}
