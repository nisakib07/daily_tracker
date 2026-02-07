-- Enable required extension
create extension if not exists "pgcrypto";

-- =========================================
-- ACCOUNTS
-- =========================================
create table if not exists public.accounts (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  type text not null check (type in ('cash', 'wallet', 'card')),
  created_at timestamptz default now()
);

alter table public.accounts enable row level security;

drop policy if exists "public read accounts" on public.accounts;
drop policy if exists "public insert accounts" on public.accounts;
drop policy if exists "public update accounts" on public.accounts;
drop policy if exists "public delete accounts" on public.accounts;

create policy "public read accounts"
on public.accounts for select to anon
using (true);

create policy "public insert accounts"
on public.accounts for insert to anon
with check (true);

create policy "public update accounts"
on public.accounts for update to anon
using (true) with check (true);

create policy "public delete accounts"
on public.accounts for delete to anon
using (true);

-- Seed default accounts (idempotent)
insert into public.accounts (name, type)
select 'Cash', 'cash'
where not exists (select 1 from public.accounts where name = 'Cash');

insert into public.accounts (name, type)
select 'bKash', 'wallet'
where not exists (select 1 from public.accounts where name = 'bKash');

insert into public.accounts (name, type)
select 'Card', 'card'
where not exists (select 1 from public.accounts where name = 'Card');


-- =========================================
-- PEOPLE
-- =========================================
create table if not exists public.people (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text,
  note text,
  created_at timestamptz default now()
);

alter table public.people enable row level security;

drop policy if exists "public read people" on public.people;
drop policy if exists "public insert people" on public.people;
drop policy if exists "public update people" on public.people;
drop policy if exists "public delete people" on public.people;

create policy "public read people"
on public.people for select to anon
using (true);

create policy "public insert people"
on public.people for insert to anon
with check (true);

create policy "public update people"
on public.people for update to anon
using (true) with check (true);

create policy "public delete people"
on public.people for delete to anon
using (true);


-- =========================================
-- TRANSACTIONS
-- (Adds occurred_at; keeps created_at)
-- =========================================
create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  type text not null check (
    type in ('expense', 'income', 'transfer', 'lend', 'borrow', 'repay', 'receive')
  ),
  amount numeric not null check (amount > 0),
  from_account_id uuid references public.accounts(id) on delete set null,
  to_account_id uuid references public.accounts(id) on delete set null,
  category text,
  note text,
  person_id uuid references public.people(id) on delete set null,
  occurred_at timestamptz not null default now(),   -- ✅ what your app inserts
  created_at timestamptz default now()
);

-- If the table existed before, ensure occurred_at exists
alter table public.transactions
add column if not exists occurred_at timestamptz;

-- Ensure occurred_at has value for older rows
update public.transactions
set occurred_at = coalesce(occurred_at, created_at, now())
where occurred_at is null;

alter table public.transactions
alter column occurred_at set not null;

alter table public.transactions enable row level security;

drop policy if exists "public read transactions" on public.transactions;
drop policy if exists "public insert transactions" on public.transactions;
drop policy if exists "public update transactions" on public.transactions;
drop policy if exists "public delete transactions" on public.transactions;

create policy "public read transactions"
on public.transactions for select to anon
using (true);

create policy "public insert transactions"
on public.transactions for insert to anon
with check (true);

create policy "public update transactions"
on public.transactions for update to anon
using (true) with check (true);

create policy "public delete transactions"
on public.transactions for delete to anon
using (true);

create index if not exists idx_transactions_occurred_at
on public.transactions (occurred_at desc);

create index if not exists idx_transactions_type
on public.transactions (type);

create index if not exists idx_transactions_from_account
on public.transactions (from_account_id);

create index if not exists idx_transactions_to_account
on public.transactions (to_account_id);

create index if not exists idx_transactions_person
on public.transactions (person_id);


-- =========================================
-- BUDGETS
-- =========================================
create table if not exists public.budgets (
  id uuid primary key default gen_random_uuid(),
  month date not null,
  category text not null,
  amount numeric not null check (amount >= 0),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create unique index if not exists uniq_budget_month_category
on public.budgets (month, category);

alter table public.budgets enable row level security;

drop policy if exists "public read budgets" on public.budgets;
drop policy if exists "public insert budgets" on public.budgets;
drop policy if exists "public update budgets" on public.budgets;
drop policy if exists "public delete budgets" on public.budgets;

create policy "public read budgets"
on public.budgets for select to anon
using (true);

create policy "public insert budgets"
on public.budgets for insert to anon
with check (true);

create policy "public update budgets"
on public.budgets for update to anon
using (true) with check (true);

create policy "public delete budgets"
on public.budgets for delete to anon
using (true);


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



UPDATE public.accounts 
SET user_id = (SELECT id FROM auth.users WHERE email = 'nadiatul.sakib@gmail.com')
WHERE user_id IS NULL;

UPDATE public.people 
SET user_id = (SELECT id FROM auth.users WHERE email = 'nadiatul.sakib@gmail.com')
WHERE user_id IS NULL;

UPDATE public.transactions 
SET user_id = (SELECT id FROM auth.users WHERE email = 'nadiatul.sakib@gmail.com')
WHERE user_id IS NULL;

UPDATE public.budgets 
SET user_id = (SELECT id FROM auth.users WHERE email = 'nadiatul.sakib@gmail.com')
WHERE user_id IS NULL;
