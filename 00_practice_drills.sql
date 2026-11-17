-- =============================================================
-- 00. PRACTICE DRILLS (D1-D10)
-- =============================================================

show search_path;
set search_path to sokomart, public;
-- ===================================================================================
-- D1. Products priced above the overall average (scalar subquery in WHERE and SELECT)
-- Result: 65 rows  (screenshot: screenshots/d01_products_priced_above_avg.png)
-- ===================================================================================

SELECT
    p.product_id,
    p.product_name,
    p.category,
    p.unit_price,
    (
        SELECT AVG(p2.unit_price)
        FROM sokomart.products AS p2
    ) AS overall_avg_price
FROM sokomart.products AS p
WHERE p.unit_price > (
    SELECT AVG(p3.unit_price)
    FROM sokomart.products AS p3
)
ORDER BY p.unit_price DESC, p.product_id
LIMIT 10;

-- D1 second query: count all products above the overall average.
SELECT COUNT(*) AS products_above_overall_average
FROM sokomart.products AS p
WHERE p.unit_price > (
    SELECT AVG(p2.unit_price)
    FROM sokomart.products AS p2
);


-- =======================================================================================
-- D2. Mombasa customers with an order in December 2025 (IN (subquery); any order status)
-- Result: 204 rows  (screenshot: screenshots/d02_msa_customers_with_orders_2025.png)
-- =======================================================================================

SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email
FROM sokomart.customers AS c
WHERE c.county = 'Mombasa'
  AND c.customer_id IN (
      SELECT o.customer_id
      FROM sokomart.orders AS o
      WHERE o.order_date >= DATE '2025-12-01'
        AND o.order_date <  DATE '2026-01-01'
  )
ORDER BY c.customer_id;

-- D2 second query: count qualifying customers.
SELECT COUNT(*) AS mombasa_customers_with_december_2025_order
FROM sokomart.customers AS c
WHERE c.county = 'Mombasa'
  AND c.customer_id IN (
      SELECT o.customer_id
      FROM sokomart.orders AS o
      WHERE o.order_date >= DATE '2025-12-01'
        AND o.order_date <  DATE '2026-01-01'
  );


-- =======================================================================================
-- D3. Kisumu customers with at least one failed payment (correlated EXISTS)
-- Result: 155 rows  (screenshot: screenshots/d03_kisumu_customers_with_failed_payment.png)
-- =======================================================================================

SELECT COUNT(*) AS kisumu_customers_with_failed_payment
FROM sokomart.customers AS c
WHERE c.county = 'Kisumu'
  AND EXISTS (
      SELECT 1
      FROM sokomart.orders AS o
      JOIN sokomart.payments AS pay
        ON pay.order_id = o.order_id
      WHERE o.customer_id = c.customer_id
        AND pay.payment_status = 'failed'
  );


-- =======================================================================================
-- D4. Average order lines and units by order status (derived table - subquery in FROM)
-- Result: 4 rows  (screenshot: screenshots/d04_avg_order_lines_units_by_order_status.png)
-- =======================================================================================

SELECT
    per_order.order_status,
    COUNT(*) AS orders,
    ROUND(AVG(per_order.line_count), 2) AS avg_lines_per_order,
    ROUND(AVG(per_order.unit_count), 2) AS avg_units_per_order
FROM (
    -- First calculate line and unit totals for each order.
    SELECT
        o.order_id,
        o.order_status,
        COUNT(oi.order_item_id) AS line_count,
        COALESCE(SUM(oi.quantity), 0) AS unit_count
    FROM sokomart.orders AS o
    LEFT JOIN sokomart.order_items AS oi
      ON oi.order_id = o.order_id
    GROUP BY o.order_id, o.order_status
) AS per_order
GROUP BY per_order.order_status
ORDER BY per_order.order_status;


-- =======================================================================================
-- D5. Top 5 shipping counties by completed orders in 2026 (single CTE)
-- Result: 5 rows  (screenshot: screenshots/d05_shipping_counties_completed_orders_2026.png)
-- =======================================================================================

WITH completed_orders_2026 AS (
    SELECT
        o.order_id,
        o.shipping_county
    FROM sokomart.orders AS o
    WHERE o.order_status = 'completed'
      AND o.order_date >= DATE '2026-01-01'
      AND o.order_date <  DATE '2027-01-01'
)
SELECT
    shipping_county,
    COUNT(*) AS completed_orders
FROM completed_orders_2026
GROUP BY shipping_county
ORDER BY completed_orders DESC, shipping_county
LIMIT 5;


-- =======================================================================================
-- D6. Monthly completed order counts and 2025 average (chained CTEs)
-- Result: 12 rows  (screenshot: screenshots/d06_monthly_completed_orders_and_avg_2025.png)
-- =======================================================================================

WITH months AS (
    SELECT
        generate_series(
            DATE '2025-01-01',
            DATE '2025-12-01',
            INTERVAL '1 month'
        )::date AS month
),
monthly_counts AS (
    SELECT
        m.month,
        COUNT(o.order_id) AS completed_orders
    FROM months AS m
    LEFT JOIN sokomart.orders AS o
      ON o.order_status = 'completed'
     AND o.order_date >= m.month
     AND o.order_date <  m.month + INTERVAL '1 month'
    GROUP BY m.month
),
monthly_stats AS (
    SELECT
        AVG(completed_orders::numeric) AS avg_per_month
    FROM monthly_counts
)
SELECT
    TO_CHAR(mc.month, 'YYYY-MM') AS month,
    mc.completed_orders,
    ROUND(ms.avg_per_month, 2) AS avg_per_month,
    CASE
        WHEN mc.completed_orders > ms.avg_per_month
            THEN 'above average'
        ELSE 'at/below average'
    END AS vs_average
FROM monthly_counts AS mc
CROSS JOIN monthly_stats AS ms
ORDER BY mc.month;


-- =============================================================
-- D7. Function: count all orders for a customer (SQL function)
-- Result 1: 1 row (screenshot: screenshots/d07_existing_customer_177.png)
-- Result 2: 0 rows (screenshot: screenshots/d07_non_existing_customer_-1.png)
-- =======================================================================================

CREATE OR REPLACE FUNCTION sokomart.fn_order_count(
    p_customer_id INTEGER
)
RETURNS INTEGER
LANGUAGE SQL
STABLE
AS $$
    SELECT COUNT(*)::INTEGER
    FROM sokomart.orders AS o
    WHERE o.customer_id = p_customer_id;
$$;

-- Existing customer 177.
SELECT sokomart.fn_order_count(177) AS order_count_customer_177;

-- A customer ID that does not exist; COUNT returns zero.
SELECT sokomart.fn_order_count(-1) AS order_count_missing_customer;


-- =============================================================
-- D8. Procedure: set a customer's status with validation
-- stored procedure, RAISE EXCEPTION, CALL, ROLLBACK
-- Result: 1 rows  (screenshot: screenshots/d08_customer_active_in_supplied_dataset.png)
-- Result: 1 rows  (screenshot: screenshots/d08_active_customer_set_to_suspended.png)
-- =======================================================================================
CREATE OR REPLACE PROCEDURE sokomart.sp_set_customer_status(
    p_customer_id INTEGER,
    p_status VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Validate the requested status before changing any data.
    IF LOWER(p_status) NOT IN ('active', 'inactive', 'suspended') THEN
        RAISE EXCEPTION
            'Invalid customer status: %. Allowed values are active, inactive, suspended.',
            p_status;
    END IF;

    -- Check that the customer exists.
    IF NOT EXISTS (
        SELECT 1
        FROM sokomart.customers
        WHERE customer_id = p_customer_id
    ) THEN
        RAISE EXCEPTION 'Customer ID % does not exist.', p_customer_id;
    END IF;

    UPDATE sokomart.customers
    SET customer_status = LOWER(p_status)
    WHERE customer_id = p_customer_id;
END;
$$;

-- Show the starting status. It should be active in the supplied dataset.
-- 1. Check the original status.
SELECT customer_id, customer_status
FROM sokomart.customers
WHERE customer_id = 177;

-- 2. Start transaction.
BEGIN;

-- 3. Change status to suspended.
CALL sokomart.sp_set_customer_status(177, 'active');

-- 4. Inspect the temporary change.
SELECT customer_id, customer_status
FROM sokomart.customers
WHERE customer_id = 177;

-- 5. Undo the change.
ROLLBACK;

-- 6. Confirm the original status is restored.
SELECT customer_id, customer_status
FROM sokomart.customers
WHERE customer_id = 177;

-- Run this CALL separately to see the required invalid-status exception.
-- CALL sokomart.sp_set_customer_status(177, 'vip');

-- Optional: run separately to see the missing-customer exception.
-- CALL sokomart.sp_set_customer_status(-1, 'active');


-- =======================================================================================
-- D9. Beauty products below the Beauty average stock (CTE + scalar subquery over that CTE)
-- Result: 21 rows  (screenshot: screenshots/d09_beauty_products_below_average_stock.png)
-- =======================================================================================

WITH beauty_products AS (
    SELECT
        p.product_id,
        p.product_name,
        p.stock_quantity
    FROM sokomart.products AS p
    WHERE p.category = 'Beauty'
)
SELECT
    bp.product_id,
    bp.product_name,
    bp.stock_quantity,
    (
        SELECT AVG(bp2.stock_quantity::numeric)
        FROM beauty_products AS bp2
    ) AS beauty_avg_stock
FROM beauty_products AS bp
WHERE bp.stock_quantity < (
    SELECT AVG(bp3.stock_quantity::numeric)
    FROM beauty_products AS bp3
)
ORDER BY bp.stock_quantity, bp.product_id;


-- ==========================================================================================
-- D10. Procedure: county customer count and completed revenue (procedure with OUT parameters
-- Result: 1 row  (screenshot: screenshots/d10_county_customer_count&completed_revenue.png)
-- =======================================================================================


CREATE OR REPLACE PROCEDURE sokomart.sp_county_summary(
    IN p_county VARCHAR,
    OUT p_customers INTEGER,
    OUT p_revenue NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    SELECT COUNT(*)::INTEGER
    INTO p_customers
    FROM sokomart.customers AS c
    WHERE c.county = p_county;

    SELECT COALESCE(SUM(oi.line_total), 0)::NUMERIC
    INTO p_revenue
    FROM sokomart.customers AS c
    JOIN sokomart.orders AS o
      ON o.customer_id = c.customer_id
    JOIN sokomart.order_items AS oi
      ON oi.order_id = o.order_id
    WHERE c.county = p_county
      AND o.order_status = 'completed';
END;
$$;

-- PostgreSQL returns the OUT values as one result row.
CALL sokomart.sp_county_summary('Nakuru', NULL, NULL);
