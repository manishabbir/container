-- ==========================================
-- MIGRATION V002: RLS POLICIES
-- Container Trade Management System
-- ==========================================
-- Run after: 001_core_schema.sql
-- ==========================================

-- ==========================================
-- Enable Row Level Security on all tables
-- ==========================================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE containers ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE installment_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE expense_allocations ENABLE ROW LEVEL SECURITY;
ALTER TABLE container_summary ENABLE ROW LEVEL SECURITY;
ALTER TABLE container_balances ENABLE ROW LEVEL SECURITY;
ALTER TABLE ledger_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE exchange_rates ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_adjustments ENABLE ROW LEVEL SECURITY;
ALTER TABLE closing_adjustments ENABLE ROW LEVEL SECURITY;
ALTER TABLE commissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE container_foreign_currencies ENABLE ROW LEVEL SECURITY;
ALTER TABLE tax_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE container_ownership_shares ENABLE ROW LEVEL SECURITY;
ALTER TABLE container_closing_payouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_wide_summary ENABLE ROW LEVEL SECURITY;

-- ==========================================
-- Helper function: Get current user role
-- ==========================================
CREATE OR REPLACE FUNCTION get_current_user_role()
RETURNS TEXT AS $$
  SELECT role FROM profiles WHERE id = auth.uid();
$$ LANGUAGE sql STABLE;

-- ==========================================
-- Helper function: Check if user is admin
-- ==========================================
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = auth.uid() AND role = 'admin'
  );
$$ LANGUAGE sql STABLE;

-- ==========================================
-- 1. PROFILES POLICIES
-- ==========================================
CREATE POLICY "Users can view their own profile" 
  ON profiles FOR SELECT 
  USING (id = auth.uid());

CREATE POLICY "Admins can view all profiles" 
  ON profiles FOR SELECT 
  USING (is_admin());

CREATE POLICY "Admins can create profiles" 
  ON profiles FOR INSERT 
  WITH CHECK (is_admin());

CREATE POLICY "Admins can update profiles" 
  ON profiles FOR UPDATE 
  USING (is_admin());

CREATE POLICY "Admins can delete profiles" 
  ON profiles FOR DELETE 
  USING (is_admin());

-- ==========================================
-- 2. CONTAINERS POLICIES
-- ==========================================
CREATE POLICY "All authenticated users can view containers" 
  ON containers FOR SELECT 
  USING (auth.role() = 'authenticated');

CREATE POLICY "All authenticated users can create containers" 
  ON containers FOR INSERT 
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "All authenticated users can update containers" 
  ON containers FOR UPDATE 
  USING (auth.role() = 'authenticated');

CREATE POLICY "Only admins can delete containers" 
  ON containers FOR DELETE 
  USING (is_admin());

-- ==========================================
-- 3. CUSTOMERS POLICIES
-- ==========================================
CREATE POLICY "All authenticated users can view customers" 
  ON customers FOR SELECT 
  USING (auth.role() = 'authenticated');

CREATE POLICY "Inside users and admins can create customers" 
  ON customers FOR INSERT 
  WITH CHECK (
    is_admin() OR 
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'inside_country')
  );

CREATE POLICY "Inside users and admins can update customers" 
  ON customers FOR UPDATE 
  USING (
    is_admin() OR 
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'inside_country')
  );

CREATE POLICY "Only admins can delete customers" 
  ON customers FOR DELETE 
  USING (is_admin());

-- ==========================================
-- 4. SUPPLIERS POLICIES
-- ==========================================
CREATE POLICY "All authenticated users can view suppliers" 
  ON suppliers FOR SELECT 
  USING (auth.role() = 'authenticated');

CREATE POLICY "Abroad users and admins can create suppliers" 
  ON suppliers FOR INSERT 
  WITH CHECK (
    is_admin() OR 
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'abroad')
  );

CREATE POLICY "Abroad users and admins can update suppliers" 
  ON suppliers FOR UPDATE 
  USING (
    is_admin() OR 
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'abroad')
  );

CREATE POLICY "Only admins can delete suppliers" 
  ON suppliers FOR DELETE 
  USING (is_admin());

-- ==========================================
-- 5. INVENTORY ITEMS POLICIES
-- ==========================================
CREATE POLICY "All authenticated users can view inventory" 
  ON inventory_items FOR SELECT 
  USING (auth.role() = 'authenticated');

CREATE POLICY "Abroad users and admins can create inventory" 
  ON inventory_items FOR INSERT 
  WITH CHECK (
    is_admin() OR 
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'abroad')
  );

CREATE POLICY "Abroad users and admins can update inventory" 
  ON inventory_items FOR UPDATE 
  USING (
    is_admin() OR 
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'abroad')
  );

CREATE POLICY "Only admins can delete inventory" 
  ON inventory_items FOR DELETE 
  USING (is_admin());

-- ==========================================
-- 6. SALES POLICIES
-- ==========================================
CREATE POLICY "All authenticated users can view sales" 
  ON sales FOR SELECT 
  USING (auth.role() = 'authenticated');

CREATE POLICY "Inside users and admins can create sales" 
  ON sales FOR INSERT 
  WITH CHECK (
    is_admin() OR 
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'inside_country')
  );

CREATE POLICY "Admins can update any sale" 
  ON sales FOR UPDATE 
  USING (is_admin());

CREATE POLICY "Creators can update their pending sales" 
  ON sales FOR UPDATE 
  USING (
    created_by = auth.uid() AND status = 'pending'
  );

CREATE POLICY "Only admins can delete sales" 
  ON sales FOR DELETE 
  USING (is_admin());

-- ==========================================
-- 7. PAYMENT PLANS POLICIES
-- ==========================================
CREATE POLICY "All authenticated users can view payment plans" 
  ON payment_plans FOR SELECT 
  USING (auth.role() = 'authenticated');

CREATE POLICY "Inside users and admins can create payment plans" 
  ON payment_plans FOR INSERT 
  WITH CHECK (
    is_admin() OR 
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'inside_country')
  );

CREATE POLICY "Creators and admins can update payment plans" 
  ON payment_plans FOR UPDATE 
  USING (created_by = auth.uid() OR is_admin());

-- ==========================================
-- 8. INSTALLMENT PAYMENTS POLICIES
-- ==========================================
CREATE POLICY "All authenticated users can view installments" 
  ON installment_payments FOR SELECT 
  USING (auth.role() = 'authenticated');

CREATE POLICY "Inside users and admins can manage installments" 
  ON installment_payments FOR INSERT 
  WITH CHECK (
    is_admin() OR 
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'inside_country')
  );

CREATE POLICY "Creators and admins can update installments" 
  ON installment_payments FOR UPDATE 
  USING (is_admin());

-- ==========================================
-- 9. TRANSACTIONS POLICIES
-- ==========================================
CREATE POLICY "All authenticated users can view transactions" 
  ON transactions FOR SELECT 
  USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can create transactions" 
  ON transactions FOR INSERT 
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Admins can update any transaction" 
  ON transactions FOR UPDATE 
  USING (is_admin());

CREATE POLICY "Creators can update their pending transactions" 
  ON transactions FOR UPDATE 
  USING (
    created_by = auth.uid() AND status = 'pending'
  );

CREATE POLICY "Only admins can delete transactions" 
  ON transactions FOR DELETE 
  USING (is_admin());

-- ==========================================
-- 10. EXPENSES POLICIES
-- ==========================================
CREATE POLICY "All authenticated users can view expenses" 
  ON expenses FOR SELECT 
  USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can create expenses" 
  ON expenses FOR INSERT 
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Admins can update any expense" 
  ON expenses FOR UPDATE 
  USING (is_admin());

CREATE POLICY "Creators can update their pending expenses" 
  ON expenses FOR UPDATE 
  USING (
    paid_by = auth.uid() AND status = 'pending'
  );

-- ==========================================
-- 11. EXPENSE ALLOCATIONS POLICIES
-- ==========================================
CREATE POLICY "All authenticated users can view expense allocations" 
  ON expense_allocations FOR SELECT 
  USING (auth.role() = 'authenticated');

CREATE POLICY "System creates allocations via triggers" 
  ON expense_allocations FOR INSERT 
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Admins can update expense allocations" 
  ON expense_allocations FOR UPDATE 
  USING (is_admin());

-- ==========================================
-- 12. CONTAINER SUMMARY POLICIES
-- ==========================================
CREATE POLICY "All authenticated users can view container summaries" 
  ON container_summary FOR SELECT 
  USING (auth.role() = 'authenticated');

CREATE POLICY "System updates container summaries via triggers" 
  ON container_summary FOR INSERT 
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "System updates container summaries via triggers" 
  ON container_summary FOR UPDATE 
  USING (auth.role() = 'authenticated');

-- ==========================================
-- 13. CONTAINER BALANCES POLICIES
-- ==========================================
CREATE POLICY "All authenticated users can view container balances" 
  ON container_balances FOR SELECT 
  USING (auth.role() = 'authenticated');

CREATE POLICY "System updates container balances via triggers" 
  ON container_balances FOR INSERT 
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "System updates container balances via triggers" 
  ON container_balances FOR UPDATE 
  USING (auth.role() = 'authenticated');

-- ==========================================
-- 14. LEDGER ENTRIES POLICIES
-- ==========================================
CREATE POLICY "Users can view their own ledger entries" 
  ON ledger_entries FOR SELECT 
  USING (user_id = auth.uid());

CREATE POLICY "Admins can view all ledger entries" 
  ON ledger_entries FOR SELECT 
  USING (is_admin());

CREATE POLICY "System creates ledger entries via triggers" 
  ON ledger_entries FOR INSERT 
  WITH CHECK (auth.role() = 'authenticated');

-- ==========================================
-- 15. NOTIFICATIONS POLICIES
-- ==========================================
CREATE POLICY "Users can view their own notifications" 
  ON notifications FOR SELECT 
  USING (user_id = auth.uid());

CREATE POLICY "Users can mark their own notifications as read" 
  ON notifications FOR UPDATE 
  USING (user_id = auth.uid());

CREATE POLICY "System creates notifications via triggers" 
  ON notifications FOR INSERT 
  WITH CHECK (auth.role() = 'authenticated');

-- ==========================================
-- 16. AUDIT LOGS POLICIES
-- ==========================================
CREATE POLICY "Admins can view audit logs" 
  ON audit_logs FOR SELECT 
  USING (is_admin());

CREATE POLICY "System creates audit logs via triggers" 
  ON audit_logs FOR INSERT 
  WITH CHECK (auth.role() = 'authenticated');

-- ==========================================
-- 17. EXCHANGE RATES POLICIES
-- ==========================================
CREATE POLICY "All authenticated users can view exchange rates" 
  ON exchange_rates FOR SELECT 
  USING (auth.role() = 'authenticated');

CREATE POLICY "Abroad users and admins can set exchange rates" 
  ON exchange_rates FOR INSERT 
  WITH CHECK (
    is_admin() OR 
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'abroad')
  );

CREATE POLICY "Abroad users and admins can update exchange rates" 
  ON exchange_rates FOR UPDATE 
  USING (
    is_admin() OR 
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'abroad')
  );

-- ==========================================
-- 18. INVENTORY ADJUSTMENTS POLICIES
-- ==========================================
CREATE POLICY "All authenticated users can view inventory adjustments" 
  ON inventory_adjustments FOR SELECT 
  USING (auth.role() = 'authenticated');

CREATE POLICY "Abroad users and admins can create adjustments" 
  ON inventory_adjustments FOR INSERT 
  WITH CHECK (
    is_admin() OR 
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'abroad')
  );

CREATE POLICY "Admins can approve adjustments" 
  ON inventory_adjustments FOR UPDATE 
  USING (is_admin());

-- ==========================================
-- 19. CLOSING ADJUSTMENTS POLICIES
-- ==========================================
CREATE POLICY "Admins can manage closing adjustments" 
  ON closing_adjustments FOR ALL 
  USING (is_admin());

-- ==========================================
-- 20. COMMISSIONS POLICIES
-- ==========================================
CREATE POLICY "Users can view their own commissions" 
  ON commissions FOR SELECT 
  USING (user_id = auth.uid());

CREATE POLICY "Admins can view and manage all commissions" 
  ON commissions FOR ALL 
  USING (is_admin());

-- ==========================================
-- 21. CONTAINER FOREIGN CURRENCIES POLICIES
-- ==========================================
CREATE POLICY "All authenticated users can view foreign currencies" 
  ON container_foreign_currencies FOR SELECT 
  USING (auth.role() = 'authenticated');

CREATE POLICY "System updates foreign currency tracking via triggers" 
  ON container_foreign_currencies FOR INSERT 
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "System updates foreign currency tracking via triggers" 
  ON container_foreign_currencies FOR UPDATE 
  USING (auth.role() = 'authenticated');

-- ==========================================
-- 22. TAX RECORDS POLICIES
-- ==========================================
CREATE POLICY "All authenticated users can view tax records" 
  ON tax_records FOR SELECT 
  USING (auth.role() = 'authenticated');

CREATE POLICY "Admins can manage tax records" 
  ON tax_records FOR ALL 
  USING (is_admin());

-- ==========================================
-- 23. CONTAINER OWNERSHIP SHARES POLICIES
-- ==========================================
CREATE POLICY "Admins can manage ownership shares" 
  ON container_ownership_shares FOR ALL 
  USING (is_admin());

CREATE POLICY "Users can view their own ownership shares" 
  ON container_ownership_shares FOR SELECT 
  USING (user_id = auth.uid());

-- ==========================================
-- 24. CONTAINER CLOSING PAYOUTS POLICIES
-- ==========================================
CREATE POLICY "Admins can manage payouts" 
  ON container_closing_payouts FOR ALL 
  USING (is_admin());

CREATE POLICY "Users can view their own payouts" 
  ON container_closing_payouts FOR SELECT 
  USING (user_id = auth.uid());

-- ==========================================
-- 25. SYSTEM WIDE SUMMARY POLICIES
-- ==========================================
CREATE POLICY "Admins can view system wide summary" 
  ON system_wide_summary FOR SELECT 
  USING (is_admin());

-- ==========================================
-- END OF MIGRATION V002
-- ==========================================