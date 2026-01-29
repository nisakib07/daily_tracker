-- =========================================
-- MIGRATE EXISTING DATA TO YOUR USER ACCOUNT
-- =========================================

-- STEP 1: First create user via Supabase Dashboard:
-- Go to Authentication > Users > Add user > Create new user
-- Email: nadiatul.sakib@gmail.com
-- Password: 123456
-- Check "Auto Confirm User" checkbox
-- Click "Create user"

-- STEP 2: After creating user, run these UPDATE statements one by one:

-- Update accounts
UPDATE public.accounts 
SET user_id = (SELECT id FROM auth.users WHERE email = 'nadiatul.sakib@gmail.com')
WHERE user_id IS NULL;

-- Update people
UPDATE public.people 
SET user_id = (SELECT id FROM auth.users WHERE email = 'nadiatul.sakib@gmail.com')
WHERE user_id IS NULL;

-- Update transactions
UPDATE public.transactions 
SET user_id = (SELECT id FROM auth.users WHERE email = 'nadiatul.sakib@gmail.com')
WHERE user_id IS NULL;

-- Update budgets
UPDATE public.budgets 
SET user_id = (SELECT id FROM auth.users WHERE email = 'nadiatul.sakib@gmail.com')
WHERE user_id IS NULL;
