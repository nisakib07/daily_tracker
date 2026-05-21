-- =========================================
-- INVESTMENTS TABLE
-- =========================================
-- Tracks investment entities (e.g., "Rahim's Business", "DSE Stocks")
-- Money flows in/out via transactions linked by investment_id

CREATE TABLE IF NOT EXISTS public.investments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'closed')),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.investments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_select_own_investments" ON public.investments
FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "users_insert_own_investments" ON public.investments
FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_update_own_investments" ON public.investments
FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "users_delete_own_investments" ON public.investments
FOR DELETE USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_investments_user_id ON public.investments (user_id);
CREATE INDEX IF NOT EXISTS idx_investments_status ON public.investments (status);


-- =========================================
-- UPDATE TRANSACTIONS TABLE
-- =========================================

-- 1. Add investment_id column to transactions
ALTER TABLE public.transactions
ADD COLUMN IF NOT EXISTS investment_id UUID REFERENCES public.investments(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_transactions_investment_id ON public.transactions (investment_id);

-- 2. Drop old CHECK constraint and add new one with invest/invest_return types
-- The constraint name may vary, so we drop by finding it first
DO $$
DECLARE
  constraint_name TEXT;
BEGIN
  SELECT con.conname INTO constraint_name
  FROM pg_constraint con
  JOIN pg_class rel ON rel.oid = con.conrelid
  JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
  WHERE rel.relname = 'transactions'
    AND nsp.nspname = 'public'
    AND con.contype = 'c'
    AND pg_get_constraintdef(con.oid) LIKE '%type%';

  IF constraint_name IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.transactions DROP CONSTRAINT %I', constraint_name);
  END IF;
END $$;

-- Add updated CHECK constraint with invest and invest_return types
ALTER TABLE public.transactions
ADD CONSTRAINT transactions_type_check CHECK (
  type IN ('expense', 'income', 'transfer', 'lend', 'borrow', 'repay', 'receive', 'invest', 'invest_return')
);
