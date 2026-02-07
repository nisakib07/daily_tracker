-- =========================================
-- ADD USER AUTHENTICATION TO ALL TABLES
-- =========================================
-- This migration adds user_id columns to all tables
-- and updates RLS policies to isolate data per user

-- =========================================
-- ACCOUNTS - Add user_id
-- =========================================

-- Add user_id column if it doesn't exist
ALTER TABLE public.accounts 
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

-- Drop existing public policies
DROP POLICY IF EXISTS "public read accounts" ON public.accounts;
DROP POLICY IF EXISTS "public insert accounts" ON public.accounts;
DROP POLICY IF EXISTS "public update accounts" ON public.accounts;
DROP POLICY IF EXISTS "public delete accounts" ON public.accounts;

-- Create user-scoped policies
CREATE POLICY "users_select_own_accounts" ON public.accounts 
FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "users_insert_own_accounts" ON public.accounts 
FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_update_own_accounts" ON public.accounts 
FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "users_delete_own_accounts" ON public.accounts 
FOR DELETE USING (auth.uid() = user_id);


-- =========================================
-- PEOPLE - Add user_id
-- =========================================

ALTER TABLE public.people 
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

DROP POLICY IF EXISTS "public read people" ON public.people;
DROP POLICY IF EXISTS "public insert people" ON public.people;
DROP POLICY IF EXISTS "public update people" ON public.people;
DROP POLICY IF EXISTS "public delete people" ON public.people;

CREATE POLICY "users_select_own_people" ON public.people 
FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "users_insert_own_people" ON public.people 
FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_update_own_people" ON public.people 
FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "users_delete_own_people" ON public.people 
FOR DELETE USING (auth.uid() = user_id);


-- =========================================
-- TRANSACTIONS - Add user_id
-- =========================================

ALTER TABLE public.transactions 
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

DROP POLICY IF EXISTS "public read transactions" ON public.transactions;
DROP POLICY IF EXISTS "public insert transactions" ON public.transactions;
DROP POLICY IF EXISTS "public update transactions" ON public.transactions;
DROP POLICY IF EXISTS "public delete transactions" ON public.transactions;

CREATE POLICY "users_select_own_transactions" ON public.transactions 
FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "users_insert_own_transactions" ON public.transactions 
FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_update_own_transactions" ON public.transactions 
FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "users_delete_own_transactions" ON public.transactions 
FOR DELETE USING (auth.uid() = user_id);


-- =========================================
-- BUDGETS - Add user_id
-- =========================================

ALTER TABLE public.budgets 
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

-- Drop unique index and recreate with user_id
DROP INDEX IF EXISTS uniq_budget_month_category;
CREATE UNIQUE INDEX IF NOT EXISTS uniq_budget_month_category_user 
ON public.budgets (user_id, month, category);

DROP POLICY IF EXISTS "public read budgets" ON public.budgets;
DROP POLICY IF EXISTS "public insert budgets" ON public.budgets;
DROP POLICY IF EXISTS "public update budgets" ON public.budgets;
DROP POLICY IF EXISTS "public delete budgets" ON public.budgets;

CREATE POLICY "users_select_own_budgets" ON public.budgets 
FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "users_insert_own_budgets" ON public.budgets 
FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_update_own_budgets" ON public.budgets 
FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "users_delete_own_budgets" ON public.budgets 
FOR DELETE USING (auth.uid() = user_id);


-- =========================================
-- FUNCTION: Auto-create default accounts for new users
-- =========================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Create default accounts for the new user
  INSERT INTO public.accounts (name, type, user_id) VALUES
    ('Cash', 'cash', NEW.id),
    ('bKash', 'wallet', NEW.id),
    ('Card', 'card', NEW.id);
  
  RETURN NEW;
END;
$$;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Create trigger to auto-create accounts on signup
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();


-- =========================================
-- Create indexes for user_id columns
-- =========================================

CREATE INDEX IF NOT EXISTS idx_accounts_user_id ON public.accounts (user_id);
CREATE INDEX IF NOT EXISTS idx_people_user_id ON public.people (user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON public.transactions (user_id);
CREATE INDEX IF NOT EXISTS idx_budgets_user_id ON public.budgets (user_id);
