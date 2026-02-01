import { streamText, tool } from 'ai';
import { z } from 'zod';
import { createClient } from '@/lib/supabase/server';

const supabase = createClient();

// Tool to get user's transactions for analysis
const getTransactionsForAnalysis = tool({
  description: 'Get user transactions for spending analysis and insights',
  inputSchema: z.object({
    days: z.number().optional().default(30).describe('Number of days to analyze (default: 30)'),
    category: z.string().optional().describe('Filter by specific category'),
  }),
  execute: async ({ days, category }) => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('Unauthorized');

      const dateFrom = new Date();
      dateFrom.setDate(dateFrom.getDate() - days);

      let query = supabase
        .from('transactions')
        .select('*')
        .eq('user_id', user.id)
        .eq('type', 'expense')
        .gte('occurred_at', dateFrom.toISOString())
        .order('occurred_at', { ascending: false });

      if (category) {
        query = query.eq('category', category);
      }

      const { data: transactions, error } = await query.limit(100);

      if (error) throw error;

      // Calculate summary
      const summary = {
        totalExpenses: transactions?.reduce((sum, t) => sum + (t.amount || 0), 0) || 0,
        transactionCount: transactions?.length || 0,
        averagePerTransaction: transactions && transactions.length > 0
          ? (transactions.reduce((sum, t) => sum + (t.amount || 0), 0) / transactions.length).toFixed(2)
          : 0,
        byCategory: {} as Record<string, { count: number; total: number }>,
        topExpenses: transactions?.slice(0, 5) || [],
      };

      // Group by category
      transactions?.forEach(t => {
        const cat = t.category || 'Uncategorized';
        if (!summary.byCategory[cat]) {
          summary.byCategory[cat] = { count: 0, total: 0 };
        }
        summary.byCategory[cat].count += 1;
        summary.byCategory[cat].total += t.amount || 0;
      });

      return summary;
    } catch (error) {
      return { error: (error as Error).message };
    }
  },
});

// Tool to get account information
const getAccountInfo = tool({
  description: 'Get information about all accounts and their balances',
  inputSchema: z.object({}),
  execute: async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('Unauthorized');

      const { data: accounts, error } = await supabase
        .from('accounts')
        .select('*')
        .eq('user_id', user.id);

      if (error) throw error;

      // Calculate balances
      const accountsWithBalances = await Promise.all(
        (accounts || []).map(async (account) => {
          const { data: transactions } = await supabase
            .from('transactions')
            .select('*')
            .eq('user_id', user.id)
            .or(`from_account_id.eq.${account.id},to_account_id.eq.${account.id}`);

          let balance = 0;
          transactions?.forEach(t => {
            if (t.from_account_id === account.id && (t.type === 'expense' || t.type === 'transfer')) {
              balance -= t.amount || 0;
            } else if (t.to_account_id === account.id && (t.type === 'income' || t.type === 'transfer')) {
              balance += t.amount || 0;
            }
          });

          return {
            id: account.id,
            name: account.name,
            type: account.type,
            balance: balance.toFixed(2),
          };
        })
      );

      return accountsWithBalances;
    } catch (error) {
      return { error: (error as Error).message };
    }
  },
});

// Tool to get budget information
const getBudgetInfo = tool({
  description: 'Get budget information for current month',
  inputSchema: z.object({}),
  execute: async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('Unauthorized');

      const currentMonth = new Date().toISOString().slice(0, 7) + '-01';

      const { data: budgets, error } = await supabase
        .from('budgets')
        .select('*')
        .eq('user_id', user.id)
        .eq('month', currentMonth);

      if (error) throw error;

      // Get spending for each budget category
      const budgetsWithSpending = await Promise.all(
        (budgets || []).map(async (budget) => {
          const monthStart = new Date(currentMonth);
          const monthEnd = new Date(monthStart);
          monthEnd.setMonth(monthEnd.getMonth() + 1);

          const { data: transactions } = await supabase
            .from('transactions')
            .select('*')
            .eq('user_id', user.id)
            .eq('type', 'expense')
            .eq('category', budget.category)
            .gte('occurred_at', monthStart.toISOString())
            .lt('occurred_at', monthEnd.toISOString());

          const spent = transactions?.reduce((sum, t) => sum + (t.amount || 0), 0) || 0;
          const remaining = budget.amount - spent;
          const percentageUsed = ((spent / budget.amount) * 100).toFixed(1);

          return {
            category: budget.category,
            budgeted: budget.amount,
            spent: spent.toFixed(2),
            remaining: remaining.toFixed(2),
            percentageUsed: `${percentageUsed}%`,
          };
        })
      );

      return budgetsWithSpending;
    } catch (error) {
      return { error: (error as Error).message };
    }
  },
});

export async function POST(req: Request) {
  const { messages } = await req.json();

  const result = streamText({
    model: 'openai/gpt-4o-mini',
    system: `You are a helpful personal finance assistant for a daily expense tracker app. You help users understand their spending patterns, provide insights about their finances, and answer questions about their transactions, accounts, and budgets.

When analyzing spending:
- Be specific with numbers and percentages
- Highlight trends and patterns
- Suggest areas where they might cut expenses
- Be encouraging about good spending habits

Always be conversational and helpful. Use the available tools to get current financial data before providing advice.`,
    messages,
    tools: {
      getTransactionsForAnalysis,
      getAccountInfo,
      getBudgetInfo,
    },
    maxSteps: 5,
  });

  return result.toUIMessageStreamResponse();
}
