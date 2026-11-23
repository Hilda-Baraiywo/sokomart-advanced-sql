-- =============================================================
-- SECTION E: OPTIMISATION AND TRANSACTIONS
-- =============================================================

-- =============================================================
-- Q21. Read a query plan
-- Run EXPLAIN ANALYZE, then run the query itself.
-- Fill the comment table below from your own DBeaver plan output.
-- (screenshots/q21a.png) |
-- =============================================================
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    SUM(i.line_total) AS revenue
FROM sokomart.customers c
JOIN sokomart.orders o
    ON o.customer_id = c.customer_id
JOIN sokomart.order_items i
    ON i.order_id = o.order_id
WHERE c.county = 'Kisumu'
  AND o.order_status = 'completed'
  AND o.order_date >= DATE '2026-09-01'
  AND o.order_date <  DATE '2026-10-01'
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY revenue DESC;

SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    SUM(i.line_total) AS revenue
FROM sokomart.customers c
JOIN sokomart.orders o
    ON o.customer_id = c.customer_id
JOIN sokomart.order_items i
    ON i.order_id = o.order_id
WHERE c.county = 'Kisumu'
  AND o.order_status = 'completed'
  AND o.order_date >= DATE '2026-09-01'
  AND o.order_date <  DATE '2026-10-01'
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY revenue DESC;

-- Q21: Complete this table using the actual execution plan.
-- top_node | join_methods_used | scan_on_orders | scan_on_customers
-- estimated_vs_actual_rows_orders | planning_ms | execution_ms | result_rows
-- DO NOT guess these values; copy them from your own plan and query result.
-- =============================================================
-- Q21: ACTUAL EXECUTION PLAN SUMMARY
-- =============================================================

-- top_node: Sort
-- join_methods_used: Hash Join, Nested Loop
-- scan_on_orders: Index Scan using idx_orders_order_date
-- scan_on_customers: Bitmap Heap Scan using idx_customers_county

-- estimated_vs_actual_rows_orders: Estimated 2020, Actual 2061
-- planning_ms: 3.383
-- execution_ms: 5.275
-- result_rows: 91

-- =============================================================
-- Q22(a). Plans before indexes
-- Drop the indexes using the DROP INDEX block in 05_indexes.sql.
-- Then run ANALYZE and these three plans.
-- (screenshots/q22a.png)
-- =============================================================

DROP INDEX IF EXISTS sokomart.idx_customers_county, sokomart.idx_customers_registration_date,
     sokomart.idx_products_category, sokomart.idx_orders_customer_id, sokomart.idx_orders_order_date,
     sokomart.idx_orders_status_date, sokomart.idx_orders_customer_date,
     sokomart.idx_order_items_product_id, sokomart.idx_payments_order_id,
     sokomart.idx_payments_status_method, sokomart.idx_payments_payment_date,
     sokomart.idx_price_history_product_id, sokomart.idx_status_history_order_id;


ANALYZE sokomart.orders;
ANALYZE sokomart.payments;
ANALYZE sokomart.order_items;

EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, order_date, total_amount
FROM sokomart.orders
WHERE customer_id = 408
ORDER BY order_date;

EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM sokomart.payments
WHERE order_id = 25000;

EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, quantity, line_total
FROM sokomart.order_items
WHERE product_id = 71;


-- =============================================================
-- Q22(b). Plans after indexes
-- Re-run 05_indexes.sql, then ANALYZE and repeat the three plans.
-- =============================================================

-- customer access paths
CREATE INDEX IF NOT EXISTS idx_customers_county            ON sokomart.customers (county);
CREATE INDEX IF NOT EXISTS idx_customers_registration_date ON sokomart.customers (registration_date);

-- product access paths
CREATE INDEX IF NOT EXISTS idx_products_category           ON sokomart.products (category);

-- order access paths
CREATE INDEX IF NOT EXISTS idx_orders_customer_id          ON sokomart.orders (customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_order_date           ON sokomart.orders (order_date);
CREATE INDEX IF NOT EXISTS idx_orders_status_date          ON sokomart.orders (order_status, order_date);
CREATE INDEX IF NOT EXISTS idx_orders_customer_date        ON sokomart.orders (customer_id, order_date);

-- order item access paths (uq_order_items_order_product already covers order_id lookups)
CREATE INDEX IF NOT EXISTS idx_order_items_product_id      ON sokomart.order_items (product_id);

-- payment access paths
CREATE INDEX IF NOT EXISTS idx_payments_order_id           ON sokomart.payments (order_id);
CREATE INDEX IF NOT EXISTS idx_payments_status_method      ON sokomart.payments (payment_status, payment_method);
CREATE INDEX IF NOT EXISTS idx_payments_payment_date       ON sokomart.payments (payment_date);

-- history tables
CREATE INDEX IF NOT EXISTS idx_price_history_product_id    ON sokomart.product_price_history (product_id);
CREATE INDEX IF NOT EXISTS idx_status_history_order_id     ON sokomart.order_status_history (order_id);

ANALYZE sokomart.customers, sokomart.products, sokomart.orders,
        sokomart.order_items, sokomart.payments;

EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, order_date, total_amount
FROM sokomart.orders
WHERE customer_id = 408
ORDER BY order_date;

EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM sokomart.payments
WHERE order_id = 25000;

EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, quantity, line_total
FROM sokomart.order_items
WHERE product_id = 71;


-- =============================================================
-- Q22(c). Partial index for pending orders
-- =============================================================
CREATE INDEX IF NOT EXISTS idx_orders_pending_date
ON sokomart.orders (order_date)
WHERE order_status = 'pending';


CREATE INDEX idx_orders_pending_date
ON sokomart.orders(order_date)
WHERE order_status = 'pending';
ANALYZE sokomart.orders;

EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, order_date, total_amount
FROM sokomart.orders
WHERE order_status = 'pending'
  AND order_date < DATE '2026-10-25';

SELECT
    pg_size_pretty(
        pg_relation_size('sokomart.idx_orders_pending_date')
    ) AS partial_index_size,
    pg_size_pretty(
        pg_relation_size('sokomart.idx_orders_order_date')
    ) AS full_index_size;

-- Q22: Record your actual before/after plan comparison here.
-- query | scan_before | execution_ms_before | scan_after | execution_ms_after | rows
-- Query 1 (orders by customer_id=408):
-- Query 2 (payments by order_id=25000):
-- Query 3 (order_items by product_id=71):
-- Note: the planner may still choose a sequential scan for small/selective
-- tables or when it estimates that scanning the table is cheaper.

-- =============================================================
-- Q22: BEFORE/AFTER INDEX COMPARISON
-- =============================================================

-- query                         | scan_before | execution_ms_before | scan_after       | execution_ms_after | rows
--
-- Query 1: orders customer 408   | Seq Scan    | 11.838              | Bitmap Heap Scan | 0.266              | 11
--
-- Query 2: payments order 25000  | Seq Scan    | 8.421               | Index Scan       | 0.171              | 1
--
-- Query 3: order_items product71 | Seq Scan    | 19.477              | Bitmap Heap Scan | 0.843              | 358


-- =============================================================
-- Q23(a). Beauty price change with ROLLBACK
-- (screenshots/q23a_price_before_change.png)
-- (screenshots/q23a_average_beauty_price_inside_transaction.png)
-- (screenshots/q23a_beauty_average_after_rollback.png)
-- (screenshots/q23b_products_before_savepoint.png)
-- (screenshots/q23b_products_during_transaction.png)
-- (screenshots/q23b_products_after_savepoint.png) |
-- =============================================================
SELECT AVG(unit_price)::NUMERIC(14,2) AS beauty_average_before
FROM sokomart.products
WHERE category = 'Beauty';

BEGIN;

UPDATE sokomart.products
SET unit_price = ROUND(unit_price * 0.90, 2)
WHERE category = 'Beauty';

SELECT AVG(unit_price)::NUMERIC(14,2) AS beauty_average_inside_transaction
FROM sokomart.products
WHERE category = 'Beauty';

ROLLBACK;

SELECT AVG(unit_price)::NUMERIC(14,2) AS beauty_average_after_rollback
FROM sokomart.products
WHERE category = 'Beauty';


-- =============================================================
-- Q23(b). SAVEPOINT: keep the restock, undo the mistaken stock update
-- =============================================================
SELECT product_id, product_name, stock_quantity
FROM sokomart.products
WHERE product_id IN (59, 166)
ORDER BY product_id;

BEGIN;

UPDATE sokomart.products
SET stock_quantity = stock_quantity + 40
WHERE product_id = 59;

INSERT INTO sokomart.audit_logs
    (table_name, record_id, action, old_data, new_data)
SELECT
    'products',
    59,
    'UPDATE',
    jsonb_build_object('stock_quantity', stock_quantity - 40),
    jsonb_build_object('stock_quantity', stock_quantity,
                       'reason', 'Restock +40 units - Q23')
FROM sokomart.products
WHERE product_id = 59;

SAVEPOINT after_restock;

UPDATE sokomart.products
SET stock_quantity = 0
WHERE product_id = 166;

SELECT product_id, product_name, stock_quantity
FROM sokomart.products
WHERE product_id IN (59, 166)
ORDER BY product_id;

ROLLBACK TO SAVEPOINT after_restock;

COMMIT;

SELECT product_id, product_name, stock_quantity
FROM sokomart.products
WHERE product_id IN (59, 166)
ORDER BY product_id;


-- =============================================================
-- Q23(c). Constraint failure aborts the transaction
-- Execute as a separate transaction and observe the error.
-- =============================================================
 BEGIN;
 UPDATE sokomart.products
 SET stock_quantity = stock_quantity + 1
 WHERE product_id = 166;
 UPDATE sokomart.products
 SET stock_quantity = -5
 WHERE product_id = 166;
 COMMIT;
-- The second UPDATE should violate chk_products_stock.
-- PostgreSQL marks the transaction aborted; COMMIT reports ROLLBACK.
-- Verify after the failed transaction:
SELECT product_id, stock_quantity
FROM sokomart.products
WHERE product_id = 166;


-- =============================================================
-- Q24(a). Identify duplicate payments in staging
-- Duplicate definition uses all seven business-key columns.
-- (screenshots/q24a_checking_for_duplicates.png)
-- (screenshots/q24b_10_rows_to_deleted.png)
-- (screenshots/q24d_error.png) 
-- =============================================================
WITH ranked_staging AS (
    SELECT
        staging_id,
        payment_id,
        order_id,
        payment_date,
        payment_method,
        amount,
        payment_status,
        transaction_reference,
        ROW_NUMBER() OVER (
            PARTITION BY payment_id, order_id, payment_date,
                         payment_method, amount, payment_status,
                         transaction_reference
            ORDER BY loaded_at, staging_id
        ) AS copy_no,
        COUNT(*) OVER (
            PARTITION BY payment_id, order_id, payment_date,
                         payment_method, amount, payment_status,
                         transaction_reference
        ) AS copies
    FROM sokomart.payment_staging
),
duplicate_groups AS (
    SELECT
        payment_id,
        MAX(copies) AS copies,
        COUNT(*) AS rows_in_group
    FROM ranked_staging
    WHERE copies > 1
    GROUP BY payment_id
)
SELECT
    COUNT(*) AS duplicated_payments,
    COALESCE(SUM(rows_in_group - 1), 0) AS extra_rows_to_delete,
    COALESCE(MAX(copies), 1) AS max_copies
FROM duplicate_groups;


-- =============================================================
-- Q24(b). First 10 duplicate rows that will be deleted
-- =============================================================
WITH ranked_staging AS (
    SELECT
        staging_id,
        payment_id,
        transaction_reference,
        amount,
        source_file,
        loaded_at,
        ROW_NUMBER() OVER (
            PARTITION BY payment_id, order_id, payment_date,
                         payment_method, amount, payment_status,
                         transaction_reference
            ORDER BY loaded_at, staging_id
        ) AS copy_no
    FROM sokomart.payment_staging
)
SELECT
    staging_id,
    payment_id,
    transaction_reference,
    amount,
    source_file,
    loaded_at,
    copy_no
FROM ranked_staging
WHERE copy_no > 1
ORDER BY loaded_at, staging_id
LIMIT 10;


-- =============================================================
-- Q24(c). Deduplicate staging, verify, then COMMIT
-- Run this block as one transaction.
-- =============================================================
SELECT
    COUNT(*) AS staging_rows_before,
    COUNT(DISTINCT payment_id) AS distinct_payments_before
FROM sokomart.payment_staging;

BEGIN;

WITH ranked_staging AS (
    SELECT
        staging_id,
        ROW_NUMBER() OVER (
            PARTITION BY payment_id, order_id, payment_date,
                         payment_method, amount, payment_status,
                         transaction_reference
            ORDER BY loaded_at, staging_id
        ) AS copy_no
    FROM sokomart.payment_staging
)
DELETE FROM sokomart.payment_staging ps
USING ranked_staging rs
WHERE ps.staging_id = rs.staging_id
  AND rs.copy_no > 1;

--SELECT
--    COUNT(*) AS staging_rows_after,
--    COUNT(DISTINCT payment_id) AS distinct_payments_after,
--    SUM(amount)::NUMERIC(14,2) AS staged_amount_after
--FROM sokomart.payment_staging;
--
--SELECT
--    SUM(p.amount)::NUMERIC(14,2) AS same_payments_in_payments_table
--FROM sokomart.payments p
--WHERE p.payment_id IN (
--    SELECT DISTINCT payment_id
--    FROM sokomart.payment_staging
--);

-- Verify staging row count and distinct payment count
SELECT
    COUNT(*) AS staging_rows_after,
    COUNT(DISTINCT payment_id) AS distinct_payments_after,
    SUM(amount)::NUMERIC(14,2) AS staged_amount_after
FROM sokomart.payment_staging;

-- Compare staged amount with matching payments table amount
SELECT
    (
        SELECT SUM(amount)
        FROM sokomart.payment_staging
    )::NUMERIC(14,2) AS staged_amount_after,

    (
        SELECT SUM(p.amount)
        FROM sokomart.payments p
        WHERE p.payment_id IN (
            SELECT DISTINCT payment_id
            FROM sokomart.payment_staging
        )
    )::NUMERIC(14,2) AS same_payments_in_payments_table,

    (
        SELECT SUM(amount)
        FROM sokomart.payment_staging
    ) = (
        SELECT SUM(p.amount)
        FROM sokomart.payments p
        WHERE p.payment_id IN (
            SELECT DISTINCT payment_id
            FROM sokomart.payment_staging
        )
    ) AS amounts_match;

-- If the verification is correct, commit. Otherwise issue ROLLBACK.
COMMIT;

-- Q24(d): Unique index ensures one staging row per payment_id.
CREATE UNIQUE INDEX IF NOT EXISTS idx_payment_staging_payment_id
ON sokomart.payment_staging (payment_id);

-- Re-insert test: run separately to capture the expected unique violation.
 INSERT INTO sokomart.payment_staging
     (payment_id, order_id, payment_date, payment_method, amount,
      payment_status, transaction_reference, source_file, loaded_at)
 SELECT
     payment_id, order_id, payment_date, payment_method, amount,
     payment_status, transaction_reference, source_file, loaded_at
 FROM sokomart.payment_staging
 ORDER BY staging_id
 LIMIT 1;



-- =============================================================
-- Q25. Three months in a row
-- Longest consecutive completed-order month streak per customer
-- (screenshots/q25_customers_with_3plus_streak.png)
-- (screenshots/q25_three_months_in_a_row.png)
-- =============================================================
WITH customer_months AS (
    SELECT DISTINCT
        o.customer_id,
        DATE_TRUNC('month', o.order_date)::DATE AS sales_month
    FROM sokomart.orders o
    WHERE o.order_status = 'completed'
),
numbered_months AS (
    SELECT
        customer_id,
        sales_month,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY sales_month
        ) AS month_number
    FROM customer_months
),
islands AS (
    SELECT
        customer_id,
        sales_month,
        sales_month - (month_number::INTEGER * INTERVAL '1 month')
            AS island_key
    FROM numbered_months
),
streaks AS (
    SELECT
        customer_id,
        MIN(sales_month)::DATE AS streak_start_month,
        MAX(sales_month)::DATE AS streak_end_month,
        COUNT(*)::INTEGER AS streak_length
    FROM islands
    GROUP BY customer_id, island_key
),
qualifying_streaks AS (
    SELECT *
    FROM streaks
    WHERE streak_length >= 3
),
ranked_streaks AS (
    SELECT
        customer_id,
        streak_start_month,
        streak_end_month,
        streak_length,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY streak_length DESC, streak_start_month
        ) AS streak_rank
    FROM qualifying_streaks
)
SELECT
    r.customer_id,
    c.first_name || ' ' || c.last_name AS full_name,
    c.county,
    r.streak_start_month,
    r.streak_end_month,
    r.streak_length
FROM ranked_streaks r
JOIN sokomart.customers c ON c.customer_id = r.customer_id
WHERE r.streak_rank = 1
ORDER BY r.streak_length DESC, r.customer_id
LIMIT 10;

-- Q25 summary: qualifying customers and longest qualifying streak
WITH customer_months AS (
    SELECT DISTINCT
        o.customer_id,
        DATE_TRUNC('month', o.order_date)::DATE AS sales_month
    FROM sokomart.orders o
    WHERE o.order_status = 'completed'
),
numbered_months AS (
    SELECT
        customer_id,
        sales_month,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id ORDER BY sales_month
        ) AS month_number
    FROM customer_months
),
islands AS (
    SELECT
        customer_id,
        sales_month,
        sales_month - (month_number::INTEGER * INTERVAL '1 month')
            AS island_key
    FROM numbered_months
),
streaks AS (
    SELECT customer_id, COUNT(*)::INTEGER AS streak_length
    FROM islands
    GROUP BY customer_id, island_key
    HAVING COUNT(*) >= 3
),
customer_longest_streak AS (
    SELECT customer_id, MAX(streak_length) AS longest_streak
    FROM streaks
    GROUP BY customer_id
)
SELECT
    COUNT(*) AS customers_with_3plus_streak,
    MAX(longest_streak) AS longest_streak
FROM customer_longest_streak;
