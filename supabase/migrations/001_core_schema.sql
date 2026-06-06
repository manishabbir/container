-- ==========================================
-- MIGRATION V001: CORE SCHEMA
-- Container Trade Management System
-- ==========================================
-- Run order: Must be executed sequentially
-- ==========================================

-- ==========================================
-- 1. PROFILES
-- ==========================================
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  full_name TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('admin', 'inside_country', 'abroad', 'viewer')),
  country TEXT DEFAULT 'Pakistan',
  currency TEXT DEFAULT 'PKR',
  is_active BOOLEAN DEFAULT true,
  created_by UUID REFERENCES profiles(id),
  commission_rate NUMERIC(7,4) DEFAULT 0 CHECK (commission_rate >= 0 AND commission_rate <= 100),
  commission_type TEXT DEFAULT 'none' CHECK (commission_type IN ('percentage', 'fixed_per_container', 'none')),
  max_discount_percent NUMERIC(7,4) DEFAULT 10.0 CHECK (max_discount_percent >= 0 AND max_discount_percent <= 100),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_profiles_role ON profiles(role);
CREATE INDEX idx_profiles_active ON profiles(is_active);

-- ==========================================
-- 2. CONTAINERS
-- ==========================================
CREATE TABLE IF NOT EXISTS containers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL DEFAULT 'planning' 
    CHECK (status IN ('planning', 'collecting_funds', 'purchasing', 'in_transit', 'selling', 'closed', 'archived')),
  default_container BOOLEAN DEFAULT false,
  primary_foreign_currency TEXT NOT NULL DEFAULT 'USD',
  created_by UUID NOT NULL REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  opened_at TIMESTAMPTZ,
  closed_at TIMESTAMPTZ,
  tax_rate_pkr NUMERIC(7,4) DEFAULT 0 CHECK (tax_rate_pkr >= 0 AND tax_rate_pkr <= 100),
  tax_regime TEXT DEFAULT NULL CHECK (tax_regime IN ('sales_tax', 'vat', 'income_tax', 'none', NULL)),
  notes TEXT
);

CREATE UNIQUE INDEX idx_containers_default ON containers(default_container) WHERE default_container = true;
CREATE INDEX idx_containers_status ON containers(status);
CREATE INDEX idx_containers_created_by ON containers(created_by);

-- ==========================================
-- 3. CUSTOMERS
-- ==========================================
CREATE TABLE IF NOT EXISTS customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  phone TEXT,
  address TEXT,
  city TEXT,
  country TEXT DEFAULT 'Pakistan',
  tax_id TEXT,
  credit_limit_pkr NUMERIC(18,2) CHECK (credit_limit_pkr IS NULL OR credit_limit_pkr >= 0),
  credit_days INTEGER DEFAULT 0 CHECK (credit_days >= 0),
  notes TEXT,
  created_by UUID NOT NULL REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_customers_name ON customers(name);
CREATE INDEX idx_customers_city ON customers(city);
CREATE INDEX idx_customers_created_by ON customers(created_by);

-- ==========================================
-- 4. SUPPLIERS
-- ==========================================
CREATE TABLE IF NOT EXISTS suppliers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  contact_person TEXT,
  phone TEXT,
  email TEXT,
  address TEXT,
  country TEXT,
  tax_id TEXT,
  payment_terms TEXT,
  notes TEXT,
  created_by UUID NOT NULL REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_suppliers_name ON suppliers(name);
CREATE INDEX idx_suppliers_country ON suppliers(country);

-- ==========================================
-- 5. INVENTORY ITEMS
-- ==========================================
CREATE TABLE IF NOT EXISTS inventory_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  container_id UUID NOT NULL REFERENCES containers(id) ON DELETE CASCADE,
  item_name TEXT NOT NULL,
  description TEXT,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  unit TEXT DEFAULT 'pcs',
  purchase_price_per_unit_foreign NUMERIC(18,4) NOT NULL CHECK (purchase_price_per_unit_foreign > 0),
  purchase_price_per_unit_pkr NUMERIC(18,2) NOT NULL CHECK (purchase_price_per_unit_pkr > 0),
  purchase_currency TEXT NOT NULL,
  purchase_exchange_rate NUMERIC(12,6) NOT NULL CHECK (purchase_exchange_rate > 0),
  total_purchase_cost_foreign NUMERIC(18,4) NOT NULL,
  total_purchase_cost_pkr NUMERIC(18,2) NOT NULL,
  sale_price_per_unit_pkr NUMERIC(18,2),
  weight_per_unit NUMERIC(10,3),
  weight_unit TEXT CHECK (weight_unit IN ('kg', 'lbs', NULL)),
  quantity_sold INTEGER DEFAULT 0 CHECK (quantity_sold >= 0),
  quantity_damaged INTEGER DEFAULT 0 CHECK (quantity_damaged >= 0),
  quantity_returned INTEGER DEFAULT 0 CHECK (quantity_returned >= 0),
  quantity_reserved INTEGER DEFAULT 0 CHECK (quantity_reserved >= 0),
  purchase_lot_number TEXT,
  purchase_date DATE,
  status TEXT DEFAULT 'purchased' 
    CHECK (status IN ('purchased', 'in_transit', 'received', 'partially_sold', 'sold_out', 'damaged', 'closed')),
  created_by UUID NOT NULL REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT chk_inventory_not_oversold 
    CHECK (quantity_sold + quantity_damaged + quantity_returned + quantity_reserved <= quantity)
);

CREATE INDEX idx_inventory_container ON inventory_items(container_id);
CREATE INDEX idx_inventory_status ON inventory_items(status);

-- ==========================================
-- 6. SALES
-- ==========================================
CREATE TABLE IF NOT EXISTS sales (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  container_id UUID NOT NULL REFERENCES containers(id) ON DELETE CASCADE,
  inventory_item_id UUID REFERENCES inventory_items(id),
  customer_id UUID NOT NULL REFERENCES customers(id),
  sale_date DATE NOT NULL DEFAULT CURRENT_DATE,
  quantity_sold INTEGER NOT NULL CHECK (quantity_sold > 0),
  unit_price_pkr NUMERIC(18,2) NOT NULL CHECK (unit_price_pkr > 0),
  total_amount_pkr NUMERIC(18,2) NOT NULL CHECK (total_amount_pkr > 0),
  discount_pkr NUMERIC(18,2) DEFAULT 0 CHECK (discount_pkr >= 0),
  discount_reason TEXT,
  tax_pkr NUMERIC(18,2) DEFAULT 0 CHECK (tax_pkr >= 0),
  tax_rate NUMERIC(7,4) DEFAULT 0 CHECK (tax_rate >= 0),
  is_return BOOLEAN DEFAULT false,
  original_sale_id UUID REFERENCES sales(id),
  cash_type TEXT NOT NULL CHECK (cash_type IN ('hard_cash', 'bank_money')),
  payment_status TEXT DEFAULT 'not_paid' CHECK (payment_status IN ('not_paid', 'partially_paid', 'fully_paid', 'refunded')),
  due_date DATE,
  paid_amount_pkr NUMERIC(18,2) DEFAULT 0 CHECK (paid_amount_pkr >= 0),
  payment_plan_id UUID,
  description TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'deleted')),
  approved_by UUID REFERENCES profiles(id),
  created_by UUID NOT NULL REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  deleted_by UUID REFERENCES profiles(id)
);

CREATE INDEX idx_sales_container ON sales(container_id);
CREATE INDEX idx_sales_customer ON sales(customer_id);
CREATE INDEX idx_sales_status ON sales(status);
CREATE INDEX idx_sales_date ON sales(sale_date);
CREATE INDEX idx_sales_inventory_item ON sales(inventory_item_id);

-- ==========================================
-- 7. PAYMENT PLANS
-- ==========================================
CREATE TABLE IF NOT EXISTS payment_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sale_id UUID NOT NULL REFERENCES sales(id),
  customer_id UUID NOT NULL REFERENCES customers(id),
  total_amount_pkr NUMERIC(18,2) NOT NULL CHECK (total_amount_pkr > 0),
  total_installments INTEGER NOT NULL CHECK (total_installments > 0),
  installment_frequency TEXT NOT NULL CHECK (installment_frequency IN ('weekly', 'biweekly', 'monthly', 'custom')),
  installment_amount_pkr NUMERIC(18,2) NOT NULL CHECK (installment_amount_pkr > 0),
  first_due_date DATE NOT NULL,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'completed', 'defaulted', 'cancelled')),
  amount_paid_pkr NUMERIC(18,2) DEFAULT 0 CHECK (amount_paid_pkr >= 0),
  amount_overdue_pkr NUMERIC(18,2) DEFAULT 0 CHECK (amount_overdue_pkr >= 0),
  default_penalty_pkr NUMERIC(18,2) DEFAULT 0 CHECK (default_penalty_pkr >= 0),
  created_by UUID NOT NULL REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_payment_plans_sale ON payment_plans(sale_id);
CREATE INDEX idx_payment_plans_customer ON payment_plans(customer_id);

-- Add FK from sales to payment_plans
ALTER TABLE sales ADD CONSTRAINT fk_sales_payment_plan 
  FOREIGN KEY (payment_plan_id) REFERENCES payment_plans(id);

-- ==========================================
-- 8. INSTALLMENT PAYMENTS
-- ==========================================
CREATE TABLE IF NOT EXISTS installment_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_plan_id UUID NOT NULL REFERENCES payment_plans(id) ON DELETE CASCADE,
  installment_number INTEGER NOT NULL CHECK (installment_number > 0),
  due_date DATE NOT NULL,
  amount_due_pkr NUMERIC(18,2) NOT NULL CHECK (amount_due_pkr > 0),
  amount_paid_pkr NUMERIC(18,2) DEFAULT 0 CHECK (amount_paid_pkr >= 0),
  payment_date DATE,
  cash_type TEXT CHECK (cash_type IN ('hard_cash', 'bank_money')),
  is_late BOOLEAN DEFAULT false,
  late_fee_pkr NUMERIC(18,2) DEFAULT 0 CHECK (late_fee_pkr >= 0),
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'overdue', 'waived')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_installments_plan ON installment_payments(payment_plan_id);
CREATE INDEX idx_installments_status ON installment_payments(status);

-- ==========================================
-- 9. TRANSACTIONS
-- ==========================================
CREATE TABLE IF NOT EXISTS transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  container_id UUID NOT NULL REFERENCES containers(id) ON DELETE CASCADE,
  transaction_type TEXT NOT NULL CHECK (transaction_type IN ('fund_transfer', 'fund_receipt', 'purchase_payment', 'supplier_payment', 'expense', 'container_transfer')),
  from_user_id UUID NOT NULL REFERENCES profiles(id),
  to_user_id UUID REFERENCES profiles(id),
  supplier_id UUID REFERENCES suppliers(id),
  amount_home NUMERIC(18,2) NOT NULL CHECK (amount_home != 0),
  amount_foreign NUMERIC(18,4),
  foreign_currency TEXT,
  exchange_rate NUMERIC(12,6),
  cash_type TEXT NOT NULL CHECK (cash_type IN ('hard_cash', 'bank_money')),
  payment_due_date DATE,
  payment_status TEXT DEFAULT 'paid' CHECK (payment_status IN ('pending_payment', 'paid', 'overdue')),
  tax_withheld_pkr NUMERIC(18,2) DEFAULT 0 CHECK (tax_withheld_pkr >= 0),
  description TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'deleted')),
  approved_by UUID REFERENCES profiles(id),
  approved_at TIMESTAMPTZ,
  rejected_by UUID REFERENCES profiles(id),
  rejected_at TIMESTAMPTZ,
  rejection_reason TEXT,
  created_by UUID NOT NULL REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  deleted_by UUID REFERENCES profiles(id)
);

CREATE INDEX idx_transactions_container ON transactions(container_id);
CREATE INDEX idx_transactions_status ON transactions(status);
CREATE INDEX idx_transactions_type ON transactions(transaction_type);
CREATE INDEX idx_transactions_from_user ON transactions(from_user_id);
CREATE INDEX idx_transactions_to_user ON transactions(to_user_id);
CREATE INDEX idx_transactions_created ON transactions(created_at);

-- ==========================================
-- 10. EXPENSES
-- ==========================================
CREATE TABLE IF NOT EXISTS expenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  container_id UUID NOT NULL REFERENCES containers(id) ON DELETE CASCADE,
  expense_side TEXT NOT NULL CHECK (expense_side IN ('home', 'abroad')),
  amount_home NUMERIC(18,2) NOT NULL CHECK (amount_home > 0),
  amount_foreign NUMERIC(18,4),
  foreign_currency TEXT,
  exchange_rate NUMERIC(12,6),
  category TEXT NOT NULL,
  lifecycle_stage TEXT,
  description TEXT,
  paid_by UUID NOT NULL REFERENCES profiles(id),
  paid_to_supplier_id UUID REFERENCES suppliers(id),
  receipt_url TEXT,
  allocation_method TEXT DEFAULT 'none' CHECK (allocation_method IN ('by_quantity', 'by_cost_value', 'by_weight', 'manual', 'none')),
  tax_deductible BOOLEAN DEFAULT false,
  tax_amount_pkr NUMERIC(18,2) DEFAULT 0 CHECK (tax_amount_pkr >= 0),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  approved_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_expenses_container ON expenses(container_id);
CREATE INDEX idx_expenses_side ON expenses(expense_side);
CREATE INDEX idx_expenses_category ON expenses(category);
CREATE INDEX idx_expenses_status ON expenses(status);

-- ==========================================
-- 11. EXPENSE ALLOCATIONS
-- ==========================================
CREATE TABLE IF NOT EXISTS expense_allocations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  expense_id UUID NOT NULL REFERENCES expenses(id) ON DELETE CASCADE,
  inventory_item_id UUID NOT NULL REFERENCES inventory_items(id),
  allocated_amount_home NUMERIC(18,2) NOT NULL CHECK (allocated_amount_home >= 0),
  allocated_amount_foreign NUMERIC(18,4),
  allocation_basis TEXT NOT NULL CHECK (allocation_basis IN ('by_quantity', 'by_cost_value', 'by_weight', 'manual')),
  allocation_percentage NUMERIC(7,4) CHECK (allocation_percentage >= 0 AND allocation_percentage <= 100),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_exp_alloc_expense ON expense_allocations(expense_id);
CREATE INDEX idx_exp_alloc_item ON expense_allocations(inventory_item_id);

-- ==========================================
-- 12. CONTAINER SUMMARY
-- ==========================================
CREATE TABLE IF NOT EXISTS container_summary (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  container_id UUID NOT NULL REFERENCES containers(id) ON DELETE CASCADE,
  total_sales_pkr NUMERIC(18,2) DEFAULT 0,
  total_sales_returns_pkr NUMERIC(18,2) DEFAULT 0,
  net_sales_pkr NUMERIC(18,2) DEFAULT 0,
  total_tax_collected_pkr NUMERIC(18,2) DEFAULT 0,
  total_purchase_cost_pkr NUMERIC(18,2) DEFAULT 0,
  cogs_pkr NUMERIC(18,2) DEFAULT 0,
  cogs_percent NUMERIC(7,4) DEFAULT 0,
  gross_profit_pkr NUMERIC(18,2) DEFAULT 0,
  gross_profit_margin_percent NUMERIC(7,4) DEFAULT 0,
  total_expenses_home_pkr NUMERIC(18,2) DEFAULT 0,
  total_expenses_abroad_pkr NUMERIC(18,2) DEFAULT 0,
  total_funds_received_pkr NUMERIC(18,2) DEFAULT 0,
  total_funds_sent_abroad_pkr NUMERIC(18,2) DEFAULT 0,
  total_funds_sent_abroad_foreign NUMERIC(18,4) DEFAULT 0,
  foreign_currency TEXT,
  secondary_foreign_currency TEXT,
  closing_foreign_balance_pkr NUMERIC(18,2) DEFAULT 0,
  closing_secondary_foreign_balance_pkr NUMERIC(18,2) DEFAULT 0,
  total_damages_pkr NUMERIC(18,2) DEFAULT 0,
  total_discounts_pkr NUMERIC(18,2) DEFAULT 0,
  exchange_gain_loss_pkr NUMERIC(18,2) DEFAULT 0,
  total_commissions_pkr NUMERIC(18,2) DEFAULT 0,
  net_profit_pkr NUMERIC(18,2) DEFAULT 0,
  net_profit_margin_percent NUMERIC(7,4) DEFAULT 0,
  total_invested_pkr NUMERIC(18,2) DEFAULT 0,
  roi_percent NUMERIC(7,4) DEFAULT 0,
  last_calculated_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(container_id)
);

CREATE INDEX idx_container_summary_profit ON container_summary(net_profit_pkr DESC);

-- ==========================================
-- 13. CONTAINER BALANCES
-- ==========================================
CREATE TABLE IF NOT EXISTS container_balances (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  container_id UUID NOT NULL REFERENCES containers(id) ON DELETE CASCADE,
  balance_home_pkr NUMERIC(18,2) DEFAULT 0,
  balance_foreign NUMERIC(18,4) DEFAULT 0,
  foreign_currency TEXT,
  balance_foreign_secondary NUMERIC(18,4) DEFAULT 0,
  foreign_currency_secondary TEXT,
  cash_in_hand_home_pkr NUMERIC(18,2) DEFAULT 0,
  cash_in_bank_home_pkr NUMERIC(18,2) DEFAULT 0,
  cash_in_hand_foreign NUMERIC(18,4) DEFAULT 0,
  cash_in_bank_foreign NUMERIC(18,4) DEFAULT 0,
  pending_receivables_pkr NUMERIC(18,2) DEFAULT 0,
  pending_payables_pkr NUMERIC(18,2) DEFAULT 0,
  last_updated_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(container_id)
);

-- ==========================================
-- 14. LEDGER ENTRIES
-- ==========================================
CREATE TABLE IF NOT EXISTS ledger_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id),
  container_id UUID REFERENCES containers(id),
  transaction_id UUID REFERENCES transactions(id),
  sale_id UUID REFERENCES sales(id),
  expense_id UUID REFERENCES expenses(id),
  commission_id UUID,
  entry_type TEXT NOT NULL CHECK (entry_type IN ('credit', 'debit')),
  cash_type TEXT NOT NULL CHECK (cash_type IN ('hard_cash', 'bank_money')),
  amount_home NUMERIC(18,2) NOT NULL CHECK (amount_home != 0),
  amount_foreign NUMERIC(18,4),
  foreign_currency TEXT,
  balance_after_home NUMERIC(18,2) NOT NULL,
  balance_after_foreign NUMERIC(18,4),
  description TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_ledger_user ON ledger_entries(user_id);
CREATE INDEX idx_ledger_container ON ledger_entries(container_id);
CREATE INDEX idx_ledger_created ON ledger_entries(created_at DESC);

-- ==========================================
-- 15. NOTIFICATIONS
-- ==========================================
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id),
  transaction_id UUID REFERENCES transactions(id),
  sale_id UUID REFERENCES sales(id),
  type TEXT NOT NULL CHECK (type IN ('approval_request', 'approved', 'rejected', 'info')),
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  is_read BOOLEAN DEFAULT false,
  action_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  read_at TIMESTAMPTZ
);

CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_notifications_unread ON notifications(user_id) WHERE is_read = false;
CREATE INDEX idx_notifications_created ON notifications(created_at DESC);

-- ==========================================
-- 16. AUDIT LOGS
-- ==========================================
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id),
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id UUID,
  old_values JSONB,
  new_values JSONB,
  ip_address TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_audit_user ON audit_logs(user_id);
CREATE INDEX idx_audit_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_action ON audit_logs(action);
CREATE INDEX idx_audit_created ON audit_logs(created_at DESC);

-- ==========================================
-- 17. EXCHANGE RATES
-- ==========================================
CREATE TABLE IF NOT EXISTS exchange_rates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  container_id UUID REFERENCES containers(id),
  transaction_id UUID REFERENCES transactions(id),
  from_currency TEXT NOT NULL DEFAULT 'PKR',
  to_currency TEXT NOT NULL,
  rate NUMERIC(12,6) NOT NULL CHECK (rate > 0),
  set_by UUID NOT NULL REFERENCES profiles(id),
  source TEXT NOT NULL CHECK (source IN ('manual', 'system')),
  effective_date DATE NOT NULL DEFAULT CURRENT_DATE,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_exchange_rates_currency ON exchange_rates(from_currency, to_currency);
CREATE INDEX idx_exchange_rates_date ON exchange_rates(effective_date DESC);
CREATE INDEX idx_exchange_rates_container ON exchange_rates(container_id);

-- ==========================================
-- 18. INVENTORY ADJUSTMENTS
-- ==========================================
CREATE TABLE IF NOT EXISTS inventory_adjustments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  container_id UUID NOT NULL REFERENCES containers(id) ON DELETE CASCADE,
  inventory_item_id UUID NOT NULL REFERENCES inventory_items(id),
  adjustment_type TEXT NOT NULL CHECK (adjustment_type IN ('damage', 'theft', 'loss', 'write_off', 'found', 'transfer_in', 'transfer_out')),
  quantity INTEGER NOT NULL,
  unit_value_pkr NUMERIC(18,2) NOT NULL CHECK (unit_value_pkr >= 0),
  total_value_pkr NUMERIC(18,2) NOT NULL CHECK (total_value_pkr >= 0),
  reason TEXT NOT NULL,
  approved_by UUID REFERENCES profiles(id),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  created_by UUID NOT NULL REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_inv_adj_container ON inventory_adjustments(container_id);
CREATE INDEX idx_inv_adj_item ON inventory_adjustments(inventory_item_id);
CREATE INDEX idx_inv_adj_status ON inventory_adjustments(status);

-- ==========================================
-- 19. CLOSING ADJUSTMENTS
-- ==========================================
CREATE TABLE IF NOT EXISTS closing_adjustments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  container_id UUID NOT NULL REFERENCES containers(id) ON DELETE CASCADE,
  adjustment_type TEXT NOT NULL CHECK (adjustment_type IN ('bad_debt_write_off', 'forex_revaluation', 'inventory_write_off', 'rounding', 'correction', 'misc', 'tax_adjustment')),
  description TEXT NOT NULL,
  amount_pkr NUMERIC(18,2) NOT NULL,
  reason TEXT,
  approved_by UUID NOT NULL REFERENCES profiles(id),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_closing_adj_container ON closing_adjustments(container_id);
CREATE INDEX idx_closing_adj_status ON closing_adjustments(status);

-- ==========================================
-- 20. COMMISSIONS
-- ==========================================
CREATE TABLE IF NOT EXISTS commissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  container_id UUID NOT NULL REFERENCES containers(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id),
  commission_type TEXT NOT NULL CHECK (commission_type IN ('sales_commission', 'purchase_commission', 'performance_bonus', 'referral', 'fixed')),
  related_sale_id UUID REFERENCES sales(id),
  base_amount_pkr NUMERIC(18,2) NOT NULL CHECK (base_amount_pkr >= 0),
  commission_rate NUMERIC(7,4) NOT NULL CHECK (commission_rate >= 0),
  commission_amount_pkr NUMERIC(18,2) NOT NULL CHECK (commission_amount_pkr >= 0),
  currency TEXT DEFAULT 'PKR',
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'paid', 'cancelled')),
  approved_by UUID REFERENCES profiles(id),
  paid_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_commissions_container ON commissions(container_id);
CREATE INDEX idx_commissions_user ON commissions(user_id);
CREATE INDEX idx_commissions_status ON commissions(status);

-- Add FK for ledger_entries.commission_id
ALTER TABLE ledger_entries ADD CONSTRAINT fk_ledger_commission 
  FOREIGN KEY (commission_id) REFERENCES commissions(id);

-- ==========================================
-- 21. CONTAINER FOREIGN CURRENCIES
-- ==========================================
CREATE TABLE IF NOT EXISTS container_foreign_currencies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  container_id UUID NOT NULL REFERENCES containers(id) ON DELETE CASCADE,
  currency TEXT NOT NULL,
  is_primary BOOLEAN DEFAULT false,
  total_received_foreign NUMERIC(18,4) DEFAULT 0 CHECK (total_received_foreign >= 0),
  total_spent_foreign NUMERIC(18,4) DEFAULT 0 CHECK (total_spent_foreign >= 0),
  remaining_balance_foreign NUMERIC(18,4) DEFAULT 0,
  closing_rate NUMERIC(12,6),
  exchange_gain_loss_pkr NUMERIC(18,2) DEFAULT 0,
  last_updated_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(container_id, currency)
);

CREATE INDEX idx_for_currency_container ON container_foreign_currencies(container_id);

-- ==========================================
-- 22. TAX RECORDS
-- ==========================================
CREATE TABLE IF NOT EXISTS tax_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  container_id UUID NOT NULL REFERENCES containers(id) ON DELETE CASCADE,
  tax_type TEXT NOT NULL CHECK (tax_type IN ('sales_tax', 'vat', 'customs_duty', 'withholding_tax', 'income_tax', 'other')),
  amount_pkr NUMERIC(18,2) NOT NULL CHECK (amount_pkr >= 0),
  amount_foreign NUMERIC(18,4),
  foreign_currency TEXT,
  exchange_rate NUMERIC(12,6),
  related_sale_id UUID REFERENCES sales(id),
  related_expense_id UUID REFERENCES expenses(id),
  related_transaction_id UUID REFERENCES transactions(id),
  description TEXT,
  paid_by UUID NOT NULL REFERENCES profiles(id),
  tax_authority TEXT,
  receipt_url TEXT,
  status TEXT DEFAULT 'paid' CHECK (status IN ('pending_payment', 'paid', 'exempt', 'disputed')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_tax_records_container ON tax_records(container_id);
CREATE INDEX idx_tax_records_type ON tax_records(tax_type);

-- ==========================================
-- 23. CONTAINER OWNERSHIP SHARES
-- ==========================================
CREATE TABLE IF NOT EXISTS container_ownership_shares (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  container_id UUID NOT NULL REFERENCES containers(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id),
  investment_amount_pkr NUMERIC(18,2) NOT NULL CHECK (investment_amount_pkr >= 0),
  investment_amount_foreign NUMERIC(18,4),
  foreign_currency TEXT,
  share_type TEXT NOT NULL CHECK (share_type IN ('equity', 'loan', 'profit_sharing')),
  ownership_percentage NUMERIC(7,4) NOT NULL CHECK (ownership_percentage >= 0 AND ownership_percentage <= 100),
  profit_share_percentage NUMERIC(7,4) CHECK (profit_share_percentage >= 0 AND profit_share_percentage <= 100),
  loss_share_percentage NUMERIC(7,4) CHECK (loss_share_percentage >= 0 AND loss_share_percentage <= 100),
  is_active BOOLEAN DEFAULT true,
  invested_at TIMESTAMPTZ DEFAULT NOW(),
  withdrawn_at TIMESTAMPTZ,
  notes TEXT,
  created_by UUID NOT NULL REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(container_id, user_id)
);

CREATE INDEX idx_ownership_container ON container_ownership_shares(container_id);
CREATE INDEX idx_ownership_user ON container_ownership_shares(user_id);

-- ==========================================
-- 24. CONTAINER CLOSING PAYOUTS
-- ==========================================
CREATE TABLE IF NOT EXISTS container_closing_payouts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  container_id UUID NOT NULL REFERENCES containers(id) ON DELETE CASCADE,
  ownership_share_id UUID NOT NULL REFERENCES container_ownership_shares(id),
  user_id UUID NOT NULL REFERENCES profiles(id),
  investment_amount_pkr NUMERIC(18,2) NOT NULL,
  profit_share_pkr NUMERIC(18,2) DEFAULT 0,
  loss_share_pkr NUMERIC(18,2) DEFAULT 0,
  total_payout_pkr NUMERIC(18,2) NOT NULL,
  payout_method TEXT CHECK (payout_method IN ('bank_transfer', 'cash', 'adjustment')),
  payout_transaction_id UUID REFERENCES transactions(id),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'paid', 'cancelled')),
  approved_by UUID REFERENCES profiles(id),
  paid_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_payouts_container ON container_closing_payouts(container_id);
CREATE INDEX idx_payouts_user ON container_closing_payouts(user_id);
CREATE INDEX idx_payouts_status ON container_closing_payouts(status);

-- ==========================================
-- 25. SYSTEM WIDE SUMMARY
-- ==========================================
CREATE TABLE IF NOT EXISTS system_wide_summary (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_date DATE NOT NULL DEFAULT CURRENT_DATE,
  total_active_containers INTEGER DEFAULT 0,
  total_closed_containers INTEGER DEFAULT 0,
  total_sales_pkr NUMERIC(18,2) DEFAULT 0,
  total_cogs_pkr NUMERIC(18,2) DEFAULT 0,
  total_gross_profit_pkr NUMERIC(18,2) DEFAULT 0,
  total_expenses_pkr NUMERIC(18,2) DEFAULT 0,
  total_tax_paid_pkr NUMERIC(18,2) DEFAULT 0,
  total_commissions_pkr NUMERIC(18,2) DEFAULT 0,
  total_exchange_gain_loss_pkr NUMERIC(18,2) DEFAULT 0,
  total_net_profit_pkr NUMERIC(18,2) DEFAULT 0,
  total_invested_pkr NUMERIC(18,2) DEFAULT 0,
  cash_in_hand_pkr NUMERIC(18,2) DEFAULT 0,
  cash_in_bank_pkr NUMERIC(18,2) DEFAULT 0,
  total_receivables_pkr NUMERIC(18,2) DEFAULT 0,
  total_payables_pkr NUMERIC(18,2) DEFAULT 0,
  last_calculated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_system_summary_date ON system_wide_summary(report_date DESC);

-- ==========================================
-- END OF MIGRATION V001
-- ==========================================