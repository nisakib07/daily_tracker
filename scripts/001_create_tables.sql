-- Daily Money Tracker Schema
-- Single-user MVP (no auth required for now, structured to add later)

-- Accounts table
CREATE TABLE IF NOT EXISTS accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('cash', 'wallet', 'card')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- People table (for borrow/lend tracking)
CREATE TABLE IF NOT EXISTS people (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  phone TEXT,
  note TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Transactions table (ledger)
CREATE TABLE IF NOT EXISTS transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type TEXT NOT NULL CHECK (type IN ('expense', 'income', 'transfer', 'lend', 'borrow', 'repay', 'receive')),
  amount NUMERIC NOT NULL CHECK (amount > 0),
  from_account_id UUID REFERENCES accounts(id) ON DELETE SET NULL,
  to_account_id UUID REFERENCES accounts(id) ON DELETE SET NULL,
  category TEXT,
  note TEXT,
  person_id UUID REFERENCES people(id) ON DELETE SET NULL,
  date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_type ON transactions(type);
CREATE INDEX IF NOT EXISTS idx_transactions_from_account ON transactions(from_account_id);
CREATE INDEX IF NOT EXISTS idx_transactions_to_account ON transactions(to_account_id);
CREATE INDEX IF NOT EXISTS idx_transactions_person ON transactions(person_id);

-- Seed default accounts if none exist
INSERT INTO accounts (name, type) 
SELECT 'Cash', 'cash'
WHERE NOT EXISTS (SELECT 1 FROM accounts WHERE name = 'Cash');

INSERT INTO accounts (name, type)
SELECT 'bKash', 'wallet'
WHERE NOT EXISTS (SELECT 1 FROM accounts WHERE name = 'bKash');

INSERT INTO accounts (name, type)
SELECT 'Card', 'card'
WHERE NOT EXISTS (SELECT 1 FROM accounts WHERE name = 'Card');
