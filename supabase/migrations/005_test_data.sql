-- ==========================================
-- MIGRATION V005: TEST DATA
-- Container Trade Management System
-- ==========================================
-- Run after: 004_triggers.sql
-- Contains: 3 test containers with complete data for validation
-- ==========================================

-- ==========================================
-- PROFILES (test users)
-- ==========================================
INSERT INTO profiles (id, email, full_name, role, country, currency, is_active, commission_rate, commission_type, max_discount_percent)
VALUES
  ('00000000-0000-0000-0000-000000000001', 'admin@example.com', 'Admin User', 'admin', 'Pakistan', 'PKR', true, 0, 'none', 100),
  ('00000000-0000-0000-0000-000000000002', 'inside@example.com', 'Inside User (Pakistan)', 'inside_country', 'Pakistan', 'PKR', true, 5.0, 'percentage', 10),
  ('00000000-0000-0000-0000-000000000003', 'abroad@example.com', 'Abroad User (UAE)', 'abroad', 'UAE', 'USD', true, 3.0, 'percentage', 5)
ON CONFLICT (id) DO NOTHING;

-- ==========================================
-- TEST CASE 1: SIMPLE CONTAINER
-- Single currency, fully sold, commission calculated
-- ==========================================
INSERT INTO containers (id, name, description, status, primary_foreign_currency, created_by, opened_at)
VALUES ('00000000-0000-0000-0000-000000000101', 'Test Container #1 - Simple', 'Single currency, fully sold with commission', 'selling', 'USD', '00000000-0000-0000-0000-000000000001', NOW())
ON CONFLICT (id) DO NOTHING;

-- Fund transfer
INSERT INTO transactions (id, container_id, transaction_type, from_user_id, to_user_id, amount_home, amount_foreign, foreign_currency, exchange_rate, cash_type, status, created_by)
VALUES ('00000000-0000-0000-0000-000000000201', '00000000-0000-0000-0000-000000000101', 'fund_transfer', '00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003', 2780000, 10000, 'USD', 278, 'bank_money', 'approved', '00000000-0000-0000-0000-000000000002')
ON CONFLICT (id) DO NOTHING;

-- Fund receipt
INSERT INTO transactions (id, container_id, transaction_type, from_user_id, to_user_id, amount_home, amount_foreign, foreign_currency, exchange_rate, cash_type, status, created_by)
VALUES ('00000000-0000-0000-0000-000000000202', '00000000-0000-0000-0000-000000000101', 'fund_receipt', '00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000003', 2780000, 10000, 'USD', 278, 'bank_money', 'approved', '00000000-0000-0000-0000-000000000003')
ON CONFLICT (id) DO NOTHING;

-- Inventory item (100 units, $100 each at 278 rate = 27,800 PKR/unit)
INSERT INTO inventory_items (id, container_id, item_name, quantity, unit, purchase_price_per_unit_foreign, purchase_price_per_unit_pkr, purchase_currency, purchase_exchange_rate, total_purchase_cost_foreign, total_purchase_cost_pkr, sale_price_per_unit_pkr, status, created_by)
VALUES ('00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-000000000101', 'Item A - Electronics', 100, 'pcs', 100, 27800, 'USD', 278, 10000, 2780000, 35000, 'purchased', '00000000-0000-0000-0000-000000000003')
ON CONFLICT (id) DO NOTHING;

-- Customer
INSERT INTO customers (id, name, phone, city, created_by)
VALUES ('00000000-0000-0000-0000-000000000401', 'Test Customer A', '+92-300-1234567', 'Karachi', '00000000-0000-0000-0000-000000000002')
ON CONFLICT (id) DO NOTHING;

-- Sale (80 units at 35,000 PKR each = 2,800,000 PKR)
INSERT INTO sales (id, container_id, inventory_item_id, customer_id, sale_date, quantity_sold, unit_price_pkr, total_amount_pkr, cash_type, payment_status, status, created_by, created_at)
VALUES ('00000000-0000-0000-0000-000000000501', '00000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-000000000401', CURRENT_DATE, 80, 35000, 2800000, 'bank_money', 'fully_paid', 'approved', '00000000-0000-0000-0000-000000000002', NOW())
ON CONFLICT (id) DO NOTHING;

-- Commission (5% of 2,800,000 = 140,000)
INSERT INTO commissions (id, container_id, user_id, commission_type, related_sale_id, base_amount_pkr, commission_rate, commission_amount_pkr, status)
VALUES ('00000000-0000-0000-0000-000000000801', '00000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-000000000002', 'sales_commission', '00000000-0000-0000-0000-000000000501', 2800000, 5.0, 140000, 'approved')
ON CONFLICT (id) DO NOTHING;

-- ==========================================
-- TEST CASE 2: MULTI-CURRENCY CONTAINER
-- USD + AED, exchange gain/loss, expense allocation
-- ==========================================
INSERT INTO containers (id, name, description, status, primary_foreign_currency, created_by, opened_at)
VALUES ('00000000-0000-0000-0000-000000000102', 'Test Container #2 - Multi-Currency', 'USD + AED with expenses and exchange G/L', 'selling', 'USD', '00000000-0000-0000-0000-000000000001', NOW())
ON CONFLICT (id) DO NOTHING;

-- Fund transfer: 556,000 PKR = 2,000 USD at 278
INSERT INTO transactions (id, container_id, transaction_type, from_user_id, to_user_id, amount_home, amount_foreign, foreign_currency, exchange_rate, cash_type, status, created_by)
VALUES ('00000000-0000-0000-0000-000000000203', '00000000-0000-0000-0000-000000000102', 'fund_transfer', '00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003', 556000, 2000, 'USD', 278, 'bank_money', 'approved', '00000000-0000-0000-0000-000000000002')
ON CONFLICT (id) DO NOTHING;
INSERT INTO transactions (id, container_id, transaction_type, from_user_id, to_user_id, amount_home, amount_foreign, foreign_currency, exchange_rate, cash_type, status, created_by)
VALUES ('00000000-0000-0000-0000-000000000204', '00000000-0000-0000-0000-000000000102', 'fund_receipt', '00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000003', 556000, 2000, 'USD', 278, 'bank_money', 'approved', '00000000-0000-0000-0000-000000000003')
ON CONFLICT (id) DO NOTHING;

-- Fund transfer: 151,600 PKR = 2,000 AED at 75.8
INSERT INTO transactions (id, container_id, transaction_type, from_user_id, to_user_id, amount_home, amount_foreign, foreign_currency, exchange_rate, cash_type, status, created_by)
VALUES ('00000000-0000-0000-0000-000000000205', '00000000-0000-0000-0000-000000000102', 'fund_transfer', '00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003', 151600, 2000, 'AED', 75.8, 'bank_money', 'approved', '00000000-0000-0000-0000-000000000002')
ON CONFLICT (id) DO NOTHING;
INSERT INTO transactions (id, container_id, transaction_type, from_user_id, to_user_id, amount_home, amount_foreign, foreign_currency, exchange_rate, cash_type, status, created_by)
VALUES ('00000000-0000-0000-0000-000000000206', '00000000-0000-0000-0000-000000000102', 'fund_receipt', '00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000003', 151600, 2000, 'AED', 75.8, 'bank_money', 'approved', '00000000-0000-0000-0000-000000000003')
ON CONFLICT (id) DO NOTHING;

-- Inventory: 200 units, $5 each at 280 rate = 1,400 PKR/unit
INSERT INTO inventory_items (id, container_id, item_name, quantity, unit, purchase_price_per_unit_foreign, purchase_price_per_unit_pkr, purchase_currency, purchase_exchange_rate, total_purchase_cost_foreign, total_purchase_cost_pkr, sale_price_per_unit_pkr, status, created_by)
VALUES ('00000000-0000-0000-0000-000000000302', '00000000-0000-0000-0000-000000000102', 'Item B - Textiles', 200, 'pcs', 5, 1400, 'USD', 280, 1000, 280000, 2000, 'purchased', '00000000-0000-0000-0000-000000000003')
ON CONFLICT (id) DO NOTHING;

-- Expense: 18,000 AED shipping at 76 rate = 1,368,000 PKR
INSERT INTO expenses (id, container_id, expense_side, amount_home, amount_foreign, foreign_currency, exchange_rate, category, allocation_method, paid_by, status)
VALUES ('00000000-0000-0000-0000-000000000601', '00000000-0000-0000-0000-000000000102', 'abroad', 1368000, 18000, 'AED', 76, 'Shipping', 'by_quantity', '00000000-0000-0000-0000-000000000003', 'approved')
ON CONFLICT (id) DO NOTHING;

-- Customer
INSERT INTO customers (id, name, phone, city, created_by)
VALUES ('00000000-0000-0000-0000-000000000402', 'Test Customer B', '+92-321-7654321', 'Lahore', '00000000-0000-0000-0000-000000000002')
ON CONFLICT (id) DO NOTHING;

-- Sale (150 units at 2,000 PKR each = 300,000 PKR)
INSERT INTO sales (id, container_id, inventory_item_id, customer_id, sale_date, quantity_sold, unit_price_pkr, total_amount_pkr, cash_type, payment_status, status, created_by, created_at)
VALUES ('00000000-0000-0000-0000-000000000502', '00000000-0000-0000-0000-000000000102', '00000000-0000-0000-0000-000000000302', '00000000-0000-0000-0000-000000000402', CURRENT_DATE, 150, 2000, 300000, 'bank_money', 'fully_paid', 'approved', '00000000-0000-0000-0000-000000000002', NOW())
ON CONFLICT (id) DO NOTHING;

-- ==========================================
-- TEST CASE 3: PARTIAL SALE + DAMAGES
-- Not all items sold, some damaged, returns processed
-- ==========================================
INSERT INTO containers (id, name, description, status, primary_foreign_currency, created_by, opened_at)
VALUES ('00000000-0000-0000-0000-000000000103', 'Test Container #3 - Partial + Damages', 'Partial sales with damages and returns', 'selling', 'USD', '00000000-0000-0000-0000-000000000001', NOW())
ON CONFLICT (id) DO NOTHING;

-- Fund transfer: 417,000 PKR = 1,500 USD at 278
INSERT INTO transactions (id, container_id, transaction_type, from_user_id, to_user_id, amount_home, amount_foreign, foreign_currency, exchange_rate, cash_type, status, created_by)
VALUES ('00000000-0000-0000-0000-000000000207', '00000000-0000-0000-0000-000000000103', 'fund_transfer', '00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003', 417000, 1500, 'USD', 278, 'bank_money', 'approved', '00000000-0000-0000-0000-000000000002')
ON CONFLICT (id) DO NOTHING;
INSERT INTO transactions (id, container_id, transaction_type, from_user_id, to_user_id, amount_home, amount_foreign, foreign_currency, exchange_rate, cash_type, status, created_by)
VALUES ('00000000-0000-0000-0000-000000000208', '00000000-0000-0000-0000-000000000103', 'fund_receipt', '00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000003', 417000, 1500, 'USD', 278, 'bank_money', 'approved', '00000000-0000-0000-0000-000000000003')
ON CONFLICT (id) DO NOTHING;

-- Inventory: 50 units, $30 each at 278 = 8,340 PKR/unit
INSERT INTO inventory_items (id, container_id, item_name, quantity, unit, purchase_price_per_unit_foreign, purchase_price_per_unit_pkr, purchase_currency, purchase_exchange_rate, total_purchase_cost_foreign, total_purchase_cost_pkr, sale_price_per_unit_pkr, status, created_by)
VALUES ('00000000-0000-0000-0000-000000000303', '00000000-0000-0000-0000-000000000103', 'Item C - Furniture', 50, 'pcs', 30, 8340, 'USD', 278, 1500, 417000, 12000, 'purchased', '00000000-0000-0000-0000-000000000003')
ON CONFLICT (id) DO NOTHING;

-- Damage (5 units damaged at 8,340 PKR each = 41,700 PKR)
INSERT INTO inventory_adjustments (id, container_id, inventory_item_id, adjustment_type, quantity, unit_value_pkr, total_value_pkr, reason, status, created_by)
VALUES ('00000000-0000-0000-0000-000000000701', '00000000-0000-0000-0000-000000000103', '00000000-0000-0000-0000-000000000303', 'damage', 5, 8340, 41700, 'Water damage during shipping', 'approved', '00000000-0000-0000-0000-000000000003')
ON CONFLICT (id) DO NOTHING;

-- Customer
INSERT INTO customers (id, name, phone, city, created_by)
VALUES ('00000000-0000-0000-0000-000000000403', 'Test Customer C', '+92-333-5555555', 'Islamabad', '00000000-0000-0000-0000-000000000002')
ON CONFLICT (id) DO NOTHING;

-- Sale (30 units at 12,000 PKR each = 360,000 PKR)
INSERT INTO sales (id, container_id, inventory_item_id, customer_id, sale_date, quantity_sold, unit_price_pkr, total_amount_pkr, cash_type, payment_status, status, created_by, created_at)
VALUES ('00000000-0000-0000-0000-000000000503', '00000000-0000-0000-0000-000000000103', '00000000-0000-0000-0000-000000000303', '00000000-0000-0000-0000-000000000403', CURRENT_DATE, 30, 12000, 360000, 'hard_cash', 'fully_paid', 'approved', '00000000-0000-0000-0000-000000000002', NOW())
ON CONFLICT (id) DO NOTHING;

-- Return (2 units returned from the 30 sold)
INSERT INTO sales (id, container_id, inventory_item_id, customer_id, sale_date, quantity_sold, unit_price_pkr, total_amount_pkr, is_return, original_sale_id, cash_type, payment_status, status, created_by, created_at)
VALUES ('00000000-0000-0000-0000-000000000504', '00000000-0000-0000-0000-000000000103', '00000000-0000-0000-0000-000000000303', '00000000-0000-0000-0000-000000000403', CURRENT_DATE, 2, 12000, -24000, true, '00000000-0000-0000-0000-000000000503', 'hard_cash', 'fully_paid', 'approved', '00000000-0000-0000-0000-000000000002', NOW())
ON CONFLICT (id) DO NOTHING;