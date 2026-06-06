-- ==========================================
-- MIGRATION V003: SQL FUNCTIONS
-- Container Trade Management System
-- ==========================================
-- Run after: 002_rls_policies.sql
-- ==========================================

-- ==========================================
-- BANKER'S ROUNDING
-- ==========================================
CREATE OR REPLACE FUNCTION banker_round_exact(
  p_value NUMERIC, p_decimals INTEGER DEFAULT 2
) RETURNS NUMERIC AS $$
DECLARE
  v_factor NUMERIC; v_shifted NUMERIC; v_fraction NUMERIC; v_rounded NUMERIC;
BEGIN
  IF p_value IS NULL THEN RETURN NULL; END IF;
  v_factor := 10 ^ p_decimals;
  v_shifted := p_value * v_factor;
  v_fraction := v_shifted - FLOOR(v_shifted);
  IF v_fraction > 0.5 THEN v_rounded := CEIL(v_shifted);
  ELSIF v_fraction < 0.5 THEN v_rounded := FLOOR(v_shifted);
  ELSE
    IF FLOOR(v_shifted) % 2 = 0 THEN v_rounded := FLOOR(v_shifted);
    ELSE v_rounded := CEIL(v_shifted); END IF;
  END IF;
  RETURN v_rounded / v_factor;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ==========================================
-- RECALCULATE CONTAINER SUMMARY (P&L)
-- ==========================================
CREATE OR REPLACE FUNCTION recalculate_container_summary(p_container_id UUID)
RETURNS TABLE(success BOOLEAN, error_code TEXT, error_message TEXT, net_profit NUMERIC, cogs NUMERIC) AS $$
DECLARE
  v_total_sales NUMERIC := 0; v_total_returns NUMERIC := 0;
  v_net_sales NUMERIC := 0; v_tax_collected NUMERIC := 0;
  v_total_purchase_cost NUMERIC := 0; v_cogs NUMERIC := 0;
  v_gross_profit NUMERIC := 0; v_expenses_home NUMERIC := 0;
  v_expenses_abroad NUMERIC := 0; v_funds_received NUMERIC := 0;
  v_funds_sent_pkr NUMERIC := 0; v_funds_sent_foreign NUMERIC := 0;
  v_foreign_currency TEXT; v_damages NUMERIC := 0;
  v_discounts NUMERIC := 0; v_commissions NUMERIC := 0;
  v_exchange_gl NUMERIC := 0; v_invested NUMERIC := 0;
BEGIN
  SELECT COALESCE(SUM(CASE WHEN is_return=false THEN total_amount_pkr-discount_pkr ELSE 0 END), 0),
         COALESCE(SUM(CASE WHEN is_return=true THEN ABS(total_amount_pkr) ELSE 0 END), 0),
         COALESCE(SUM(tax_pkr), 0), COALESCE(SUM(discount_pkr), 0)
  INTO v_total_sales, v_total_returns, v_tax_collected, v_discounts
  FROM sales WHERE container_id = p_container_id AND status = 'approved';
  v_net_sales := v_total_sales - v_total_returns;
  SELECT COALESCE(SUM(total_purchase_cost_pkr), 0) INTO v_total_purchase_cost
  FROM inventory_items WHERE container_id = p_container_id;
  SELECT COALESCE(SUM((quantity_sold::NUMERIC/quantity)*total_purchase_cost_pkr), 0) INTO v_cogs
  FROM inventory_items WHERE container_id = p_container_id AND quantity > 0;
  v_gross_profit := v_net_sales - v_cogs;
  SELECT COALESCE(SUM(amount_home), 0) INTO v_expenses_home
  FROM expenses WHERE container_id = p_container_id AND expense_side = 'home' AND status = 'approved';
  SELECT COALESCE(SUM(amount_home), 0) INTO v_expenses_abroad
  FROM expenses WHERE container_id = p_container_id AND expense_side = 'abroad' AND status = 'approved';
  SELECT primary_foreign_currency INTO v_foreign_currency FROM containers WHERE id = p_container_id;
  SELECT COALESCE(SUM(total_value_pkr), 0) INTO v_damages
  FROM inventory_adjustments WHERE container_id = p_container_id AND status = 'approved'
    AND adjustment_type IN ('damage','theft','loss','write_off');
  SELECT COALESCE(SUM(commission_amount_pkr), 0) INTO v_commissions
  FROM commissions WHERE container_id = p_container_id AND status IN ('approved','paid');
  SELECT COALESCE(SUM(exchange_gain_loss_pkr), 0) INTO v_exchange_gl
  FROM container_foreign_currencies WHERE container_id = p_container_id;
  SELECT COALESCE(SUM(investment_amount_pkr), 0) INTO v_invested
  FROM container_ownership_shares WHERE container_id = p_container_id AND is_active = true;
  v_net_profit := v_gross_profit - v_expenses_home - v_expenses_abroad - v_damages - v_discounts + v_exchange_gl - v_commissions;
  
  INSERT INTO container_summary (container_id,total_sales_pkr,total_sales_returns_pkr,net_sales_pkr,
    total_tax_collected_pkr,total_purchase_cost_pkr,cogs_pkr,cogs_percent,gross_profit_pkr,
    gross_profit_margin_percent,total_expenses_home_pkr,total_expenses_abroad_pkr,
    total_funds_received_pkr,total_funds_sent_abroad_pkr,total_funds_sent_abroad_foreign,
    foreign_currency,total_damages_pkr,total_discounts_pkr,exchange_gain_loss_pkr,
    total_commissions_pkr,net_profit_pkr,net_profit_margin_percent,total_invested_pkr,
    roi_percent,last_calculated_at,updated_at)
  VALUES (p_container_id,v_total_sales,v_total_returns,v_net_sales,v_tax_collected,
    v_total_purchase_cost,v_cogs,
    CASE WHEN v_net_sales>0 THEN (v_cogs/v_net_sales)*100 ELSE 0 END,
    v_gross_profit,
    CASE WHEN v_net_sales>0 THEN (v_gross_profit/v_net_sales)*100 ELSE 0 END,
    v_expenses_home,v_expenses_abroad,v_funds_received,v_funds_sent_pkr,v_funds_sent_foreign,
    v_foreign_currency,v_damages,v_discounts,v_exchange_gl,v_commissions,v_net_profit,
    CASE WHEN v_net_sales>0 THEN (v_net_profit/v_net_sales)*100 ELSE 0 END,
    v_invested,
    CASE WHEN v_invested>0 THEN (v_net_profit/v_invested)*100 ELSE 0 END,
    NOW(),NOW())
  ON CONFLICT (container_id) DO UPDATE SET
    total_sales_pkr=EXCLUDED.total_sales_pkr,total_sales_returns_pkr=EXCLUDED.total_sales_returns_pkr,
    net_sales_pkr=EXCLUDED.net_sales_pkr,total_tax_collected_pkr=EXCLUDED.total_tax_collected_pkr,
    total_purchase_cost_pkr=EXCLUDED.total_purchase_cost_pkr,cogs_pkr=EXCLUDED.cogs_pkr,
    cogs_percent=EXCLUDED.cogs_percent,gross_profit_pkr=EXCLUDED.gross_profit_pkr,
    gross_profit_margin_percent=EXCLUDED.gross_profit_margin_percent,
    total_expenses_home_pkr=EXCLUDED.total_expenses_home_pkr,
    total_expenses_abroad_pkr=EXCLUDED.total_expenses_abroad_pkr,
    total_funds_received_pkr=EXCLUDED.total_funds_received_pkr,
    total_funds_sent_abroad_pkr=EXCLUDED.total_funds_sent_abroad_pkr,
    total_funds_sent_abroad_foreign=EXCLUDED.total_funds_sent_abroad_foreign,
    total_damages_pkr=EXCLUDED.total_damages_pkr,total_discounts_pkr=EXCLUDED.total_discounts_pkr,
    exchange_gain_loss_pkr=EXCLUDED.exchange_gain_loss_pkr,
    total_commissions_pkr=EXCLUDED.total_commissions_pkr,net_profit_pkr=EXCLUDED.net_profit_pkr,
    net_profit_margin_percent=EXCLUDED.net_profit_margin_percent,
    total_invested_pkr=EXCLUDED.total_invested_pkr,roi_percent=EXCLUDED.roi_percent,
    last_calculated_at=NOW(),updated_at=NOW();
  RETURN QUERY SELECT true,NULL::TEXT,NULL::TEXT,v_net_profit,v_cogs;
EXCEPTION WHEN OTHERS THEN
  RETURN QUERY SELECT false,'ERR-500','Recalculation failed: '||SQLERRM,NULL::NUMERIC,NULL::NUMERIC;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- NOTIFICATION FUNCTION
-- ==========================================
CREATE OR REPLACE FUNCTION create_notification(
  p_user_id UUID,p_type TEXT,p_title TEXT,p_message TEXT,
  p_action_url TEXT DEFAULT NULL,p_transaction_id UUID DEFAULT NULL,p_sale_id UUID DEFAULT NULL
) RETURNS UUID AS $$
DECLARE v_id UUID;
BEGIN
  INSERT INTO notifications(user_id,type,title,message,action_url,transaction_id,sale_id,is_read,created_at)
  VALUES(p_user_id,p_type,p_title,p_message,p_action_url,p_transaction_id,p_sale_id,false,NOW())
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==========================================
-- AUDIT LOG FUNCTION
-- ==========================================
CREATE OR REPLACE FUNCTION log_audit_entry(
  p_user_id UUID,p_action TEXT,p_entity_type TEXT,p_entity_id UUID,
  p_old_values JSONB DEFAULT NULL,p_new_values JSONB DEFAULT NULL,p_ip_address TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE v_id UUID;
BEGIN
  INSERT INTO audit_logs(user_id,action,entity_type,entity_id,old_values,new_values,ip_address)
  VALUES(p_user_id,p_action,p_entity_type,p_entity_id,p_old_values,p_new_values,p_ip_address)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==========================================
-- RECALCULATE CONTAINER BALANCES
-- ==========================================
CREATE OR REPLACE FUNCTION recalculate_container_balances(p_container_id UUID)
RETURNS void AS $$
DECLARE
  v_balance_home NUMERIC:=0; v_cash_hand NUMERIC:=0; v_cash_bank NUMERIC:=0;
  v_receivables NUMERIC:=0; v_currency TEXT;
BEGIN
  SELECT primary_foreign_currency INTO v_currency FROM containers WHERE id=p_container_id;
  SELECT COALESCE(SUM(amount_home),0) INTO v_balance_home
  FROM transactions WHERE container_id=p_container_id AND status='approved';
  SELECT COALESCE(SUM(amount_home),0) INTO v_balance_home
  FROM expenses WHERE container_id=p_container_id AND status='approved';
  
  SELECT COALESCE(SUM(CASE WHEN cash_type='hard_cash' THEN amount_home ELSE 0 END),0),
         COALESCE(SUM(CASE WHEN cash_type='bank_money' THEN amount_home ELSE 0 END),0)
  INTO v_cash_hand, v_cash_bank
  FROM transactions WHERE container_id=p_container_id AND status='approved';
  
  SELECT COALESCE(SUM(total_amount_pkr-COALESCE(paid_amount_pkr,0)),0) INTO v_receivables
  FROM sales WHERE container_id=p_container_id AND status='approved'
    AND payment_status IN ('not_paid','partially_paid');
  
  INSERT INTO container_balances(container_id,balance_home_pkr,foreign_currency,
    cash_in_hand_home_pkr,cash_in_bank_home_pkr,pending_receivables_pkr,last_updated_at,updated_at)
  VALUES(p_container_id,v_balance_home,v_currency,v_cash_hand,v_cash_bank,v_receivables,NOW(),NOW())
  ON CONFLICT(container_id) DO UPDATE SET
    balance_home_pkr=EXCLUDED.balance_home_pkr,cash_in_hand_home_pkr=EXCLUDED.cash_in_hand_home_pkr,
    cash_in_bank_home_pkr=EXCLUDED.cash_in_bank_home_pkr,pending_receivables_pkr=EXCLUDED.pending_receivables_pkr,
    last_updated_at=NOW(),updated_at=NOW();
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- ALLOCATE EXPENSE ACROSS INVENTORY ITEMS
-- ==========================================
CREATE OR REPLACE FUNCTION allocate_expense(p_expense_id UUID, p_container_id UUID)
RETURNS void AS $$
DECLARE
  v_expense RECORD; v_item RECORD;
  v_total_qty INTEGER:=0; v_total_cost NUMERIC:=0; v_total_weight NUMERIC:=0;
  v_alloc NUMERIC; v_sum NUMERIC:=0; v_rem NUMERIC:=0; v_cnt INTEGER:=0;
  v_max_id UUID; v_max_val NUMERIC:=-1;
BEGIN
  SELECT * INTO v_expense FROM expenses WHERE id=p_expense_id;
  IF NOT FOUND THEN RETURN; END IF;
  
  IF v_expense.allocation_method='by_quantity' THEN
    SELECT SUM(quantity) INTO v_total_qty FROM inventory_items WHERE container_id=p_container_id;
    IF v_total_qty=0 THEN RETURN; END IF;
    FOR v_item IN SELECT * FROM inventory_items WHERE container_id=p_container_id LOOP
      v_alloc := banker_round_exact((v_item.quantity::NUMERIC/v_total_qty)*v_expense.amount_home,2);
      INSERT INTO expense_allocations(expense_id,inventory_item_id,allocated_amount_home,
        allocated_amount_foreign,allocation_basis,allocation_percentage)
      VALUES(p_expense_id,v_item.id,v_alloc,NULL,'by_quantity',(v_item.quantity::NUMERIC/v_total_qty)*100);
      v_sum := v_sum + v_alloc;
      IF v_item.quantity > v_max_val THEN v_max_val:=v_item.quantity; v_max_id:=v_item.id; END IF;
      v_cnt := v_cnt + 1;
    END LOOP;
  ELSIF v_expense.allocation_method='by_cost_value' THEN
    SELECT SUM(total_purchase_cost_pkr) INTO v_total_cost FROM inventory_items WHERE container_id=p_container_id;
    IF v_total_cost=0 THEN RETURN; END IF;
    FOR v_item IN SELECT * FROM inventory_items WHERE container_id=p_container_id LOOP
      v_alloc := banker_round_exact((v_item.total_purchase_cost_pkr/v_total_cost)*v_expense.amount_home,2);
      INSERT INTO expense_allocations(expense_id,inventory_item_id,allocated_amount_home,
        allocated_amount_foreign,allocation_basis,allocation_percentage)
      VALUES(p_expense_id,v_item.id,v_alloc,NULL,'by_cost_value',(v_item.total_purchase_cost_pkr/v_total_cost)*100);
      v_sum := v_sum + v_alloc;
      IF v_item.total_purchase_cost_pkr > v_max_val THEN v_max_val:=v_item.total_purchase_cost_pkr; v_max_id:=v_item.id; END IF;
    END LOOP;
  ELSE
    RETURN;
  END IF;
  
  v_rem := v_expense.amount_home - v_sum;
  IF v_rem != 0 AND v_max_id IS NOT NULL THEN
    UPDATE expense_allocations SET allocated_amount_home = allocated_amount_home + v_rem
    WHERE expense_id=p_expense_id AND inventory_item_id=v_max_id;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- RUN FINANCIAL TESTS
-- ==========================================
CREATE OR REPLACE FUNCTION run_financial_tests()
RETURNS TABLE(test_name TEXT, status TEXT, expected NUMERIC, actual NUMERIC, difference NUMERIC, passed BOOLEAN) AS $$
DECLARE
  v_cogs NUMERIC; v_net_sales NUMERIC; v_gross NUMERIC; v_net NUMERIC;
  v_damages NUMERIC; v_balance NUMERIC; v_qty INTEGER;
BEGIN
  -- TEST 1: Simple Container COGS = (80/100)*2,780,000 = 2,224,000
  test_name:='Test 1a: Simple Container COGS';
  SELECT cogs_pkr INTO v_cogs FROM container_summary WHERE container_id='00000000-0000-0000-0000-000000000101';
  expected:=2224000; actual:=v_cogs; difference:=ABS(expected-actual); passed:=difference<=1;
  status:=CASE WHEN passed THEN 'PASS' ELSE 'FAIL' END; RETURN NEXT;
  
  -- TEST 2: Simple Container Net Profit = 576,000 - 140,000 = 436,000
  test_name:='Test 1b: Simple Container Net Profit';
  SELECT net_profit_pkr INTO v_net FROM container_summary WHERE container_id='00000000-0000-0000-0000-000000000101';
  expected:=436000; actual:=v_net; difference:=ABS(expected-actual); passed:=difference<=1;
  status:=CASE WHEN passed THEN 'PASS' ELSE 'FAIL' END; RETURN NEXT;
  
  -- TEST 3: Partial Sale - Return reduces quantity_sold to 28
  test_name:='Test 3a: Return Reduces quantity_sold';
  SELECT quantity_sold INTO v_qty FROM inventory_items WHERE id='00000000-0000-0000-0000-000000000303';
  expected:=28; actual:=v_qty; difference:=ABS(expected-actual); passed:=difference=0;
  status:=CASE WHEN passed THEN 'PASS' ELSE 'FAIL' END; RETURN NEXT;
  
  -- TEST 4: Damages recorded correctly = 41,700
  test_name:='Test 3b: Damages Value';
  SELECT total_damages_pkr INTO v_damages FROM container_summary WHERE container_id='00000000-0000-0000-0000-000000000103';
  expected:=41700; actual:=v_damages; difference:=ABS(expected-actual); passed:=difference<=1;
  status:=CASE WHEN passed THEN 'PASS' ELSE 'FAIL' END; RETURN NEXT;
  
  -- TEST 5: Container balance positive
  test_name:='Test 5: Container #1 Balance Positive';
  SELECT balance_home_pkr INTO v_balance FROM container_balances WHERE container_id='00000000-0000-0000-0000-000000000101';
  expected:=2800000; actual:=v_balance; passed:=v_balance>0;
  status:=CASE WHEN passed THEN 'PASS' ELSE 'FAIL' END; RETURN NEXT;
END;
$$ LANGUAGE plpgsql;