-- Money Master production hardening and performance migration.
-- Run after 001_create_tables.sql and 002_add_investments.sql.

begin;

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- RLS hardening
-- ---------------------------------------------------------------------------

alter table public.accounts enable row level security;
alter table public.people enable row level security;
alter table public.transactions enable row level security;
alter table public.budgets enable row level security;
alter table public.investments enable row level security;

revoke all on public.accounts from anon;
revoke all on public.people from anon;
revoke all on public.transactions from anon;
revoke all on public.budgets from anon;
revoke all on public.investments from anon;

grant select, insert, update, delete on public.accounts to authenticated;
grant select, insert, update, delete on public.people to authenticated;
grant select, insert, update, delete on public.transactions to authenticated;
grant select, insert, update, delete on public.budgets to authenticated;
grant select, insert, update, delete on public.investments to authenticated;

drop policy if exists "public read accounts" on public.accounts;
drop policy if exists "public insert accounts" on public.accounts;
drop policy if exists "public update accounts" on public.accounts;
drop policy if exists "public delete accounts" on public.accounts;
drop policy if exists "public read people" on public.people;
drop policy if exists "public insert people" on public.people;
drop policy if exists "public update people" on public.people;
drop policy if exists "public delete people" on public.people;
drop policy if exists "public read transactions" on public.transactions;
drop policy if exists "public insert transactions" on public.transactions;
drop policy if exists "public update transactions" on public.transactions;
drop policy if exists "public delete transactions" on public.transactions;
drop policy if exists "public read budgets" on public.budgets;
drop policy if exists "public insert budgets" on public.budgets;
drop policy if exists "public update budgets" on public.budgets;
drop policy if exists "public delete budgets" on public.budgets;

drop policy if exists "users_select_own_accounts" on public.accounts;
drop policy if exists "users_insert_own_accounts" on public.accounts;
drop policy if exists "users_update_own_accounts" on public.accounts;
drop policy if exists "users_delete_own_accounts" on public.accounts;
create policy "users_select_own_accounts" on public.accounts for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "users_insert_own_accounts" on public.accounts for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "users_update_own_accounts" on public.accounts for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "users_delete_own_accounts" on public.accounts for delete to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "users_select_own_people" on public.people;
drop policy if exists "users_insert_own_people" on public.people;
drop policy if exists "users_update_own_people" on public.people;
drop policy if exists "users_delete_own_people" on public.people;
create policy "users_select_own_people" on public.people for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "users_insert_own_people" on public.people for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "users_update_own_people" on public.people for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "users_delete_own_people" on public.people for delete to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "users_select_own_transactions" on public.transactions;
drop policy if exists "users_insert_own_transactions" on public.transactions;
drop policy if exists "users_update_own_transactions" on public.transactions;
drop policy if exists "users_delete_own_transactions" on public.transactions;
create policy "users_select_own_transactions" on public.transactions for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "users_insert_own_transactions" on public.transactions for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "users_update_own_transactions" on public.transactions for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "users_delete_own_transactions" on public.transactions for delete to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "users_select_own_budgets" on public.budgets;
drop policy if exists "users_insert_own_budgets" on public.budgets;
drop policy if exists "users_update_own_budgets" on public.budgets;
drop policy if exists "users_delete_own_budgets" on public.budgets;
create policy "users_select_own_budgets" on public.budgets for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "users_insert_own_budgets" on public.budgets for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "users_update_own_budgets" on public.budgets for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "users_delete_own_budgets" on public.budgets for delete to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "users_select_own_investments" on public.investments;
drop policy if exists "users_insert_own_investments" on public.investments;
drop policy if exists "users_update_own_investments" on public.investments;
drop policy if exists "users_delete_own_investments" on public.investments;
create policy "users_select_own_investments" on public.investments for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "users_insert_own_investments" on public.investments for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "users_update_own_investments" on public.investments for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "users_delete_own_investments" on public.investments for delete to authenticated
  using ((select auth.uid()) = user_id);

-- Composite indexes support RLS filters and cursor-based Activity reads.
create index if not exists idx_accounts_user_created
  on public.accounts (user_id, created_at);
create index if not exists idx_people_user_name
  on public.people (user_id, name);
create index if not exists idx_transactions_user_occurred_id
  on public.transactions (user_id, occurred_at desc, id desc);
create index if not exists idx_transactions_user_from
  on public.transactions (user_id, from_account_id);
create index if not exists idx_transactions_user_to
  on public.transactions (user_id, to_account_id);
create index if not exists idx_transactions_user_person
  on public.transactions (user_id, person_id);
create index if not exists idx_transactions_user_investment
  on public.transactions (user_id, investment_id);
create index if not exists idx_budgets_user_month
  on public.budgets (user_id, month, category);
create index if not exists idx_investments_user_status_created
  on public.investments (user_id, status, created_at desc);

-- ---------------------------------------------------------------------------
-- Idempotent mutation receipts
-- ---------------------------------------------------------------------------

create table if not exists public.money_mutation_receipts (
  user_id uuid not null references auth.users(id) on delete cascade,
  mutation_id uuid not null,
  mutation_kind text not null,
  created_at timestamptz not null default now(),
  primary key (user_id, mutation_id)
);

alter table public.money_mutation_receipts enable row level security;
revoke all on public.money_mutation_receipts from anon;
grant select, insert, delete on public.money_mutation_receipts to authenticated;

drop policy if exists "users_select_own_money_mutations" on public.money_mutation_receipts;
drop policy if exists "users_insert_own_money_mutations" on public.money_mutation_receipts;
drop policy if exists "users_delete_own_money_mutations" on public.money_mutation_receipts;
create policy "users_select_own_money_mutations" on public.money_mutation_receipts
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "users_insert_own_money_mutations" on public.money_mutation_receipts
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "users_delete_own_money_mutations" on public.money_mutation_receipts
  for delete to authenticated using ((select auth.uid()) = user_id);

create or replace function public.apply_money_mutation(
  p_mutation_id uuid,
  p_kind text,
  p_payload jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_inserted uuid;
  v_month date;
  v_investment_id uuid;
begin
  if v_user is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  insert into public.money_mutation_receipts (user_id, mutation_id, mutation_kind)
  values (v_user, p_mutation_id, p_kind)
  on conflict do nothing
  returning mutation_id into v_inserted;

  if v_inserted is null then
    return jsonb_build_object('applied', false, 'duplicate', true);
  end if;

  case p_kind
    when 'money_in' then
      insert into public.transactions
        (type, amount, to_account_id, category, note, user_id, occurred_at)
      values
        ('income', (p_payload->>'amount')::numeric,
         (p_payload->>'account_id')::uuid, p_payload->>'category',
         nullif(p_payload->>'note', ''), v_user,
         (p_payload->>'occurred_at')::timestamptz);

    when 'money_out' then
      insert into public.transactions
        (type, amount, from_account_id, category, note, user_id, occurred_at)
      values
        ('expense', (p_payload->>'amount')::numeric,
         (p_payload->>'account_id')::uuid, p_payload->>'category',
         nullif(p_payload->>'note', ''), v_user,
         (p_payload->>'occurred_at')::timestamptz);

    when 'transfer' then
      insert into public.transactions
        (type, amount, from_account_id, to_account_id, category, note, user_id, occurred_at)
      values
        ('transfer', (p_payload->>'amount')::numeric,
         (p_payload->>'from_account_id')::uuid,
         (p_payload->>'to_account_id')::uuid, 'Transfer',
         nullif(p_payload->>'note', ''), v_user,
         (p_payload->>'occurred_at')::timestamptz);

    when 'create_person' then
      insert into public.people (id, name, phone, note, user_id)
      values (p_mutation_id, trim(p_payload->>'name'),
              nullif(p_payload->>'phone', ''), nullif(p_payload->>'note', ''), v_user)
      on conflict (id) do nothing;

    when 'update_person' then
      update public.people set
        name = trim(p_payload->>'name'),
        phone = nullif(p_payload->>'phone', ''),
        note = nullif(p_payload->>'note', '')
      where id = (p_payload->>'person_id')::uuid and user_id = v_user;

    when 'delete_person' then
      delete from public.people
      where id = (p_payload->>'person_id')::uuid and user_id = v_user;

    when 'update_account' then
      update public.accounts set name = trim(p_payload->>'name')
      where id = (p_payload->>'account_id')::uuid and user_id = v_user;
      if coalesce((p_payload->>'adjustment_amount')::numeric, 0) > 0 then
        insert into public.transactions
          (type, amount, from_account_id, to_account_id, category, note, user_id, occurred_at)
        values
          (case when (p_payload->>'add_money')::boolean then 'income' else 'expense' end,
           (p_payload->>'adjustment_amount')::numeric,
           case when (p_payload->>'add_money')::boolean then null else (p_payload->>'account_id')::uuid end,
           case when (p_payload->>'add_money')::boolean then (p_payload->>'account_id')::uuid else null end,
           'Balance Adjustment', nullif(p_payload->>'note', ''), v_user, now());
      end if;

    when 'loan' then
      insert into public.transactions
        (type, amount, from_account_id, to_account_id, person_id, category, note, user_id, occurred_at)
      values
        (p_payload->>'type', (p_payload->>'amount')::numeric,
         case when p_payload->>'type' in ('lend', 'repay') then (p_payload->>'account_id')::uuid else null end,
         case when p_payload->>'type' in ('borrow', 'receive') then (p_payload->>'account_id')::uuid else null end,
         (p_payload->>'person_id')::uuid, p_payload->>'category',
         nullif(p_payload->>'note', ''), v_user,
         (p_payload->>'occurred_at')::timestamptz);

    when 'create_investment' then
      v_investment_id := p_mutation_id;
      insert into public.investments (id, name, description, status, user_id)
      values (v_investment_id, trim(p_payload->>'name'),
              nullif(p_payload->>'description', ''), 'active', v_user)
      on conflict (id) do nothing;
      insert into public.transactions
        (type, amount, from_account_id, investment_id, category, note, user_id, occurred_at)
      values
        ('invest', (p_payload->>'amount')::numeric,
         (p_payload->>'from_account_id')::uuid, v_investment_id, 'Investment',
         nullif(p_payload->>'note', ''), v_user,
         (p_payload->>'occurred_at')::timestamptz);

    when 'add_investment_funds' then
      insert into public.transactions
        (type, amount, from_account_id, investment_id, category, note, user_id, occurred_at)
      values
        ('invest', (p_payload->>'amount')::numeric,
         (p_payload->>'from_account_id')::uuid,
         (p_payload->>'investment_id')::uuid, 'Investment',
         nullif(p_payload->>'note', ''), v_user,
         (p_payload->>'occurred_at')::timestamptz);

    when 'investment_return' then
      insert into public.transactions
        (type, amount, to_account_id, investment_id, category, note, user_id, occurred_at)
      values
        ('invest_return', (p_payload->>'amount')::numeric,
         (p_payload->>'to_account_id')::uuid,
         (p_payload->>'investment_id')::uuid, 'Investment Return',
         nullif(p_payload->>'note', ''), v_user,
         (p_payload->>'occurred_at')::timestamptz);
      if coalesce((p_payload->>'close_investment')::boolean, false) then
        update public.investments set status = 'closed'
        where id = (p_payload->>'investment_id')::uuid and user_id = v_user;
      end if;

    when 'update_transaction' then
      update public.transactions set
        amount = (p_payload->>'amount')::numeric,
        occurred_at = (p_payload->>'occurred_at')::timestamptz,
        from_account_id = nullif(p_payload->>'from_account_id', '')::uuid,
        to_account_id = nullif(p_payload->>'to_account_id', '')::uuid,
        person_id = nullif(p_payload->>'person_id', '')::uuid,
        category = nullif(p_payload->>'category', ''),
        note = nullif(p_payload->>'note', '')
      where id = (p_payload->>'transaction_id')::uuid and user_id = v_user;

    when 'replace_budgets' then
      v_month := (p_payload->>'month')::date;
      delete from public.budgets where user_id = v_user and month = v_month;
      insert into public.budgets (month, category, amount, user_id, updated_at)
      select v_month, key, value::numeric, v_user, now()
      from jsonb_each_text(coalesce(p_payload->'budgets', '{}'::jsonb))
      where trim(key) <> '' and value::numeric > 0;

    when 'clear_budgets' then
      delete from public.budgets
      where user_id = v_user and month = (p_payload->>'month')::date;

    when 'delete_investment' then
      delete from public.transactions
      where user_id = v_user and investment_id = (p_payload->>'investment_id')::uuid;
      delete from public.investments
      where user_id = v_user and id = (p_payload->>'investment_id')::uuid;

    when 'delete_transaction' then
      delete from public.transactions
      where user_id = v_user and id = (p_payload->>'transaction_id')::uuid;

    else
      raise exception 'Unsupported mutation kind: %', p_kind using errcode = '22023';
  end case;

  return jsonb_build_object('applied', true, 'duplicate', false);
end;
$$;

revoke execute on function public.apply_money_mutation(uuid, text, jsonb) from public;
revoke execute on function public.apply_money_mutation(uuid, text, jsonb) from anon;
grant execute on function public.apply_money_mutation(uuid, text, jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- Server-side summaries and cursor-paged Activity
-- ---------------------------------------------------------------------------

create or replace function public.money_master_dashboard_summary(p_month date)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with owned_transactions as (
    select * from public.transactions where user_id = (select auth.uid())
  ), account_totals as (
    select a.id,
      coalesce(sum(case when t.to_account_id = a.id then t.amount else 0 end), 0)
      - coalesce(sum(case when t.from_account_id = a.id then t.amount else 0 end), 0) as balance
    from public.accounts a
    left join owned_transactions t
      on t.to_account_id = a.id or t.from_account_id = a.id
    where a.user_id = (select auth.uid())
    group by a.id
  )
  select jsonb_build_object(
    'account_balances', coalesce(
      (select jsonb_agg(jsonb_build_object('account_id', id, 'balance', balance))
       from account_totals), '[]'::jsonb),
    'month_income', coalesce(
      (select sum(amount) from owned_transactions
       where type = 'income' and occurred_at >= date_trunc('month', p_month::timestamp)
       and occurred_at < date_trunc('month', p_month::timestamp) + interval '1 month'), 0),
    'month_expense', coalesce(
      (select sum(amount) from owned_transactions
       where type = 'expense' and occurred_at >= date_trunc('month', p_month::timestamp)
       and occurred_at < date_trunc('month', p_month::timestamp) + interval '1 month'), 0),
    'transaction_count', (select count(*) from owned_transactions)
  );
$$;

revoke execute on function public.money_master_dashboard_summary(date) from public;
revoke execute on function public.money_master_dashboard_summary(date) from anon;
grant execute on function public.money_master_dashboard_summary(date) to authenticated;

create or replace function public.money_master_transaction_page(
  p_before timestamptz default null,
  p_before_id uuid default null,
  p_limit integer default 100
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select coalesce(jsonb_agg(to_jsonb(page_rows)), '[]'::jsonb)
  from (
    select id, type, amount, from_account_id, to_account_id, person_id,
           investment_id, category, note, occurred_at, created_at
    from public.transactions
    where user_id = (select auth.uid())
      and (
        p_before is null
        or occurred_at < p_before
        or (occurred_at = p_before and p_before_id is not null and id < p_before_id)
      )
    order by occurred_at desc, id desc
    limit greatest(1, least(p_limit, 250))
  ) page_rows;
$$;

revoke execute on function public.money_master_transaction_page(timestamptz, uuid, integer) from public;
revoke execute on function public.money_master_transaction_page(timestamptz, uuid, integer) from anon;
grant execute on function public.money_master_transaction_page(timestamptz, uuid, integer) to authenticated;

-- Trigger functions should not be directly executable by API roles.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.accounts (name, type, user_id) values
    ('Cash', 'cash', new.id),
    ('bKash', 'wallet', new.id),
    ('Card', 'card', new.id);
  return new;
end;
$$;
revoke execute on function public.handle_new_user() from public, anon, authenticated;

commit;
