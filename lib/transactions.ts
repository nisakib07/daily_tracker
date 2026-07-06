import type { SupabaseClient } from "@supabase/supabase-js";
import type { Transaction } from "@/lib/types";

const TRANSACTION_PAGE_SIZE = 1000;

export async function fetchAllTransactions(
  supabase: SupabaseClient,
): Promise<Transaction[]> {
  const transactions: Transaction[] = [];
  let from = 0;

  while (true) {
    const { data, error } = await supabase
      .from("transactions")
      .select("*")
      .order("occurred_at", { ascending: false })
      .order("id", { ascending: false })
      .range(from, from + TRANSACTION_PAGE_SIZE - 1);

    if (error) throw error;
    if (!data || data.length === 0) break;

    transactions.push(...(data as Transaction[]));

    if (data.length < TRANSACTION_PAGE_SIZE) break;
    from += TRANSACTION_PAGE_SIZE;
  }

  return transactions;
}
