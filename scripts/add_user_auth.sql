-- =========================================
-- ADD USER_ID TO ALL TABLES
-- =========================================

-- Add user_id column to accounts
ALTER TABLE public.accounts 
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

-- Add user_id column to people
ALTER TABLE public.people 
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

-- Add user_id column to transactions
ALTER TABLE public.transactions 
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

-- Add user_id column to budgets
ALTER TABLE public.budgets 
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

-- =========================================
-- UPDATE RLS POLICIES FOR ACCOUNTS
-- =========================================
DROP POLICY IF EXISTS "public read accounts" ON public.accounts;
DROP POLICY IF EXISTS "public insert accounts" ON public.accounts;
DROP POLICY IF EXISTS "public update accounts" ON public.accounts;
DROP POLICY IF EXISTS "public delete accounts" ON public.accounts;

CREATE POLICY "users can view own accounts"
ON public.accounts FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "users can insert own accounts"
ON public.accounts FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users can update own accounts"
ON public.accounts FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users can delete own accounts"
ON public.accounts FOR DELETE
USING (auth.uid() = user_id);

-- =========================================
-- UPDATE RLS POLICIES FOR PEOPLE
-- =========================================
DROP POLICY IF EXISTS "public read people" ON public.people;
DROP POLICY IF EXISTS "public insert people" ON public.people;
DROP POLICY IF EXISTS "public update people" ON public.people;
DROP POLICY IF EXISTS "public delete people" ON public.people;

CREATE POLICY "users can view own people"
ON public.people FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "users can insert own people"
ON public.people FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users can update own people"
ON public.people FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users can delete own people"
ON public.people FOR DELETE
USING (auth.uid() = user_id);

-- =========================================
-- UPDATE RLS POLICIES FOR TRANSACTIONS
-- =========================================
DROP POLICY IF EXISTS "public read transactions" ON public.transactions;
DROP POLICY IF EXISTS "public insert transactions" ON public.transactions;
DROP POLICY IF EXISTS "public update transactions" ON public.transactions;
DROP POLICY IF EXISTS "public delete transactions" ON public.transactions;

CREATE POLICY "users can view own transactions"
ON public.transactions FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "users can insert own transactions"
ON public.transactions FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users can update own transactions"
ON public.transactions FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users can delete own transactions"
ON public.transactions FOR DELETE
USING (auth.uid() = user_id);

-- =========================================
-- UPDATE RLS POLICIES FOR BUDGETS
-- =========================================
DROP POLICY IF EXISTS "public read budgets" ON public.budgets;
DROP POLICY IF EXISTS "public insert budgets" ON public.budgets;
DROP POLICY IF EXISTS "public update budgets" ON public.budgets;
DROP POLICY IF EXISTS "public delete budgets" ON public.budgets;

CREATE POLICY "users can view own budgets"
ON public.budgets FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "users can insert own budgets"
ON public.budgets FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users can update own budgets"
ON public.budgets FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users can delete own budgets"
ON public.budgets FOR DELETE
USING (auth.uid() = user_id);

-- =========================================
-- CREATE INDEXES FOR USER_ID
-- =========================================
CREATE INDEX IF NOT EXISTS idx_accounts_user_id ON public.accounts(user_id);
CREATE INDEX IF NOT EXISTS idx_people_user_id ON public.people(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON public.transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_budgets_user_id ON public.budgets(user_id);
