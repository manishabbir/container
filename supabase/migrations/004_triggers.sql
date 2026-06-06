-- ==========================================
-- MIGRATION V004: SQL TRIGGERS
-- Container Trade Management System
-- ==========================================
-- Run after: 003_functions.sql
-- ==========================================

-- ==========================================
-- AUTO-RECALCULATE SUMMARY ON SALE APPROVAL
-- ==========================================
CREATE OR REPLACE FUNCTION trigger_recalc_on_sale()
RETURNS trigger AS $$
BEGIN
  IF NEW.status = 'approved' AND (OLD.status IS NULL OR OLD.status != 'approved') THEN
    -- Update inventory quantity_sold
    UPDATE inventory_items 
    SET quantity_sold = quantity_sold + NEW.quantity_sold,
        updated_at = NOW()
    WHERE id = NEW.inventory_item_id;
    
    -- Recalculate container summary
    PERFORM recalculate_container_summary(NEW.container_id);
    PERFORM recalculate_container_balances(NEW.container_id);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_sale_approved ON sales;
CREATE TRIGGER trg_sale_approved
  AFTER UPDATE OF status ON sales
  FOR EACH ROW
  WHEN (NEW.status = 'approved' AND (OLD.status IS NULL OR OLD.status = 'pending'))
  EXECUTE FUNCTION trigger_recalc_on_sale();

-- ==========================================
-- AUTO-CALCULATE ON SALE INSERT (if auto-approved)
-- ==========================================
CREATE OR REPLACE FUNCTION trigger_calc_on_sale_insert()
RETURNS trigger AS $$
BEGIN
  IF NEW.status = 'approved' THEN
    UPDATE inventory_items 
    SET quantity_sold = quantity_sold + NEW.quantity_sold,
        updated_at = NOW()
    WHERE id = NEW.inventory_item_id;
    
    PERFORM recalculate_container_summary(NEW.container_id);
    PERFORM recalculate_container_balances(NEW.container_id);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_sale_insert ON sales;
CREATE TRIGGER trg_sale_insert
  AFTER INSERT ON sales
  FOR EACH ROW
  EXECUTE FUNCTION trigger_calc_on_sale_insert();

-- ==========================================
-- AUTO-RECALCULATE ON TRANSACTION APPROVAL
-- ==========================================
CREATE OR REPLACE FUNCTION trigger_recalc_on_transaction()
RETURNS trigger AS $$
BEGIN
  IF NEW.status = 'approved' AND (OLD.status IS NULL OR OLD.status != 'approved') THEN
    PERFORM recalculate_container_summary(NEW.container_id);
    PERFORM recalculate_container_balances(NEW.container_id);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_transaction_approved ON transactions;
CREATE TRIGGER trg_transaction_approved
  AFTER UPDATE OF status ON transactions
  FOR EACH ROW
  WHEN (NEW.status = 'approved' AND (OLD.status IS NULL OR OLD.status = 'pending'))
  EXECUTE FUNCTION trigger_recalc_on_transaction();

-- ==========================================
-- AUTO-RECALCULATE ON EXPENSE APPROVAL
-- ==========================================
CREATE OR REPLACE FUNCTION trigger_recalc_on_expense()
RETURNS trigger AS $$
BEGIN
  IF NEW.status = 'approved' AND (OLD.status IS NULL OR OLD.status != 'approved') THEN
    PERFORM recalculate_container_summary(NEW.container_id);
    PERFORM recalculate_container_balances(NEW.container_id);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_expense_approved ON expenses;
CREATE TRIGGER trg_expense_approved
  AFTER UPDATE OF status ON expenses
  FOR EACH ROW
  WHEN (NEW.status = 'approved' AND (OLD.status IS NULL OR OLD.status = 'pending'))
  EXECUTE FUNCTION trigger_recalc_on_expense();

-- ==========================================
-- AUTO-AUDIT LOG TRIGGER (financial tables)
-- ==========================================
CREATE OR REPLACE FUNCTION trigger_audit_log()
RETURNS trigger AS $$
DECLARE
  v_user_id UUID;
BEGIN
  -- Try to get the current user ID from session
  v_user_id := COALESCE(auth.uid(), '00000000-0000-0000-0000-000000000000'::UUID);
  
  IF TG_OP = 'UPDATE' THEN
    INSERT INTO audit_logs (user_id, action, entity_type, entity_id, old_values, new_values)
    VALUES (v_user_id, 'update_' || TG_TABLE_NAME, TG_TABLE_NAME, NEW.id,
            row_to_json(OLD)::jsonb, row_to_json(NEW)::jsonb);
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO audit_logs (user_id, action, entity_type, entity_id, old_values)
    VALUES (v_user_id, 'delete_' || TG_TABLE_NAME, TG_TABLE_NAME, OLD.id,
            row_to_json(OLD)::jsonb);
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add audit triggers to critical financial tables
DROP TRIGGER IF EXISTS trg_audit_sales ON sales;
CREATE TRIGGER trg_audit_sales AFTER UPDATE OR DELETE ON sales FOR EACH ROW EXECUTE FUNCTION trigger_audit_log();

DROP TRIGGER IF EXISTS trg_audit_transactions ON transactions;
CREATE TRIGGER trg_audit_transactions AFTER UPDATE OR DELETE ON transactions FOR EACH ROW EXECUTE FUNCTION trigger_audit_log();

DROP TRIGGER IF EXISTS trg_audit_expenses ON expenses;
CREATE TRIGGER trg_audit_expenses AFTER UPDATE OR DELETE ON expenses FOR EACH ROW EXECUTE FUNCTION trigger_audit_log();

DROP TRIGGER IF EXISTS trg_audit_inventory ON inventory_items;
CREATE TRIGGER trg_audit_inventory AFTER UPDATE OR DELETE ON inventory_items FOR EACH ROW EXECUTE FUNCTION trigger_audit_log();

-- ==========================================
-- AUTO-CREATE NOTIFICATION ON TRANSACTION
-- ==========================================
CREATE OR REPLACE FUNCTION trigger_transaction_notification()
RETURNS trigger AS $$
DECLARE
  v_from_name TEXT;
  v_to_name TEXT;
BEGIN
  IF TG_OP = 'INSERT' AND NEW.status = 'pending' THEN
    SELECT full_name INTO v_from_name FROM profiles WHERE id = NEW.from_user_id;
    
    -- Notify admin about pending transaction
    PERFORM create_notification(
      (SELECT id FROM profiles WHERE role = 'admin' LIMIT 1),
      'approval_request',
      'New Transaction Pending Approval',
      v_from_name || ' sent ' || NEW.amount_home || ' PKR. Review needed.',
      '/transactions/' || NEW.id,
      NEW.id, NULL
    );
    
    -- Notify recipient
    IF NEW.to_user_id IS NOT NULL THEN
      PERFORM create_notification(
        NEW.to_user_id,
        'approval_request',
        'Fund Transfer Received',
        v_from_name || ' sent ' || NEW.amount_home || ' PKR to you.',
        '/transactions/' || NEW.id,
        NEW.id, NULL
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_notify_transaction ON transactions;
CREATE TRIGGER trg_notify_transaction AFTER INSERT ON transactions FOR EACH ROW EXECUTE FUNCTION trigger_transaction_notification();

-- ==========================================
-- AUTO-UPDATE inventory_items.status
-- ==========================================
CREATE OR REPLACE FUNCTION trigger_update_item_status()
RETURNS trigger AS $$
DECLARE
  v_remaining INTEGER;
BEGIN
  v_remaining := NEW.quantity - NEW.quantity_sold - NEW.quantity_damaged - NEW.quantity_returned - NEW.quantity_reserved;
  
  IF v_remaining <= 0 THEN
    UPDATE inventory_items SET status = 'sold_out' WHERE id = NEW.id;
  ELSIF NEW.quantity_sold > 0 THEN
    UPDATE inventory_items SET status = 'partially_sold' WHERE id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_update_item_status ON inventory_items;
CREATE TRIGGER trg_update_item_status AFTER UPDATE OF quantity_sold, quantity_damaged ON inventory_items FOR EACH ROW EXECUTE FUNCTION trigger_update_item_status();

-- ==========================================
-- END OF MIGRATION V004
-- ==========================================