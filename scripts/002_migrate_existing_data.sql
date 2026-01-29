-- =========================================
-- MIGRATE EXISTING DATA TO YOUR USER ACCOUNT
-- =========================================
-- Run this AFTER you've signed up with nadiatul.sakib@gmail.com
-- This will assign all existing data to your account

-- Step 1: Get your user ID (run this first to verify)
-- SELECT id, email FROM auth.users WHERE email = 'nadiatul.sakib@gmail.com';

-- Step 2: Update all existing data to belong to your user
-- Replace the subquery with your actual user ID if needed

DO $$
DECLARE
  target_user_id UUID;
BEGIN
  -- Get the user ID for nadiatul.sakib@gmail.com
  SELECT id INTO target_user_id 
  FROM auth.users 
  WHERE email = 'nadiatul.sakib@gmail.com';
  
  IF target_user_id IS NULL THEN
    RAISE EXCEPTION 'User nadiatul.sakib@gmail.com not found. Please sign up first.';
  END IF;
  
  -- Update all accounts without a user_id
  UPDATE public.accounts 
  SET user_id = target_user_id 
  WHERE user_id IS NULL;
  
  -- Update all people without a user_id
  UPDATE public.people 
  SET user_id = target_user_id 
  WHERE user_id IS NULL;
  
  -- Update all transactions without a user_id
  UPDATE public.transactions 
  SET user_id = target_user_id 
  WHERE user_id IS NULL;
  
  -- Update all budgets without a user_id
  UPDATE public.budgets 
  SET user_id = target_user_id 
  WHERE user_id IS NULL;
  
  RAISE NOTICE 'Successfully migrated all data to user %', target_user_id;
END $$;
