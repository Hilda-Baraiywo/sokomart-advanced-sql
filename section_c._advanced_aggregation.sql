-- =============================================================
-- SECTION C: ADVANCED AGGREGATION WITH SUBQUERIES
-- =============================================================

-- =============================================================
-- Q11. Customer tiers
-- Nested derived tables, `CASE`, scalar subquery
-- Result: 4 rows  (screenshot: screenshots/q11_customer_tiers.png)
-- =============================================================
WITH customer_revenue AS (
    SELECT
        c.customer_id,
        SUM(oi.line_total)::NUMERIC(14,2) AS lifetime_spent
    FROM sokomart.customers c
    JOIN sokomart.orders o ON o.customer_id = c.customer_id
    JOIN sokomart.order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'completed'
    GROUP BY c.customer_id
),
customer_tiers AS (
    SELECT
        customer_id,
        lifetime_spent,
        CASE
            WHEN lifetime_spent >= 1000000 THEN 'Platinum'
            WHEN lifetime_spent >= 500000 THEN 'Gold'
            WHEN lifetime_spent >= 100000 THEN 'Silver'
            ELSE 'Bronze'
        END AS tier
    FROM customer_revenue
)
SELECT
    tier,
    COUNT(*) AS customer_count,
    MIN(lifetime_spent) AS min_spent,
    MAX(lifetime_spent) AS max_spent,
    ROUND(AVG(lifetime_spent), 2) AS avg_spent,
    ROUND(
        100.0 * SUM(lifetime_spent)
        / NULLIF((SELECT SUM(lifetime_spent) FROM customer_tiers), 0),
        2
    ) AS revenue_share_pct
FROM customer_tiers
GROUP BY tier
ORDER BY CASE tier
    WHEN 'Platinum' THEN 1
    WHEN 'Gold' THEN 2
    WHEN 'Silver' THEN 3
    WHEN 'Bronze' THEN 4
END;


-- =============================================================
-- Q12. What did Mombasa buy in October?
--`STRING\\\_AGG(DISTINCT … ORDER BY …)`, `EXISTS`
-- Result: 152 rows  (screenshot: screenshots/q12_mombasa_purchase_october.png)
-- =============================================================
WITH qualifying_customers AS (
    SELECT c.customer_id, c.first_name, c.last_name
    FROM sokomart.customers c
    WHERE c.county = 'Mombasa'
      AND EXISTS (
          SELECT 1
          FROM sokomart.orders o
          WHERE o.customer_id = c.customer_id
            AND o.order_status <> 'cancelled'
            AND o.order_date >= DATE '2026-10-01'
            AND o.order_date <  DATE '2026-11-01'
      )
),
customer_products AS (
    SELECT
        qc.customer_id,
        qc.first_name || ' ' || qc.last_name AS full_name,
        COUNT(DISTINCT p.product_id) AS product_count,
        STRING_AGG(
            DISTINCT p.product_name,
            '; ' ORDER BY p.product_name
        ) AS products_ordered
    FROM qualifying_customers qc
    JOIN sokomart.orders o ON o.customer_id = qc.customer_id
    JOIN sokomart.order_items oi ON oi.order_id = o.order_id
    JOIN sokomart.products p ON p.product_id = oi.product_id
    WHERE o.order_status <> 'cancelled'
      AND o.order_date >= DATE '2026-10-01'
      AND o.order_date <  DATE '2026-11-01'
    GROUP BY qc.customer_id, qc.first_name, qc.last_name
)
SELECT customer_id, full_name, product_count, products_ordered
FROM customer_products
ORDER BY product_count DESC, customer_id;

-- Q12 summary: number of qualifying customers
SELECT COUNT(*) AS qualifying_customers
FROM sokomart.customers c
WHERE c.county = 'Mombasa'
  AND EXISTS (
      SELECT 1
      FROM sokomart.orders o
      WHERE o.customer_id = c.customer_id
        AND o.order_status <> 'cancelled'
        AND o.order_date >= DATE '2026-10-01'
        AND o.order_date <  DATE '2026-11-01'
  );


-- =============================================================
-- Q13. Payment health by method, 2026
-- `FILTER` clause, CTE
-- Result: 4 rows  (screenshot: screenshots/q13_payment_health_by_method.png)
-- =============================================================
WITH payments_2026 AS (
    SELECT payment_method, payment_status, amount
    FROM sokomart.payments
    WHERE payment_date >= DATE '2026-01-01'
      AND payment_date <  DATE '2027-01-01'
)
SELECT
    payment_method,
    COUNT(*) AS total_payments,
    COUNT(*) FILTER (WHERE payment_status = 'successful') AS successful,
    COUNT(*) FILTER (WHERE payment_status = 'failed') AS failed,
    COUNT(*) FILTER (WHERE payment_status = 'pending') AS pending,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE payment_status = 'successful')
        / NULLIF(COUNT(*), 0),
        2
    ) AS success_rate_pct,
    COALESCE(
        SUM(amount) FILTER (WHERE payment_status = 'failed'),
        0
    )::NUMERIC(14,2) AS failed_amount
FROM payments_2026
GROUP BY payment_method
ORDER BY total_payments DESC;


-- =============================================================
-- Q14. Which departments carry the profit?
-- CTE + scalar subqueries in `SELECT` and `WHERE`
-- Result: 2 rows  (screenshot: screenshots/q14_dept_above_avg_gross_profit.png)
-- =============================================================
WITH category_profit AS (
    SELECT
        p.category,
        SUM(oi.line_total)::NUMERIC(14,2) AS revenue,
        SUM(oi.line_total - (oi.quantity * p.cost_price))::NUMERIC(14,2)
            AS gross_profit
    FROM sokomart.orders o
    JOIN sokomart.order_items oi ON oi.order_id = o.order_id
    JOIN sokomart.products p ON p.product_id = oi.product_id
    WHERE o.order_status = 'completed'
      AND o.order_date >= DATE '2025-01-01'
      AND o.order_date <  DATE '2026-01-01'
    GROUP BY p.category
)
SELECT
    category,
    revenue,
    gross_profit,
    ROUND(100.0 * gross_profit / NULLIF(revenue, 0), 2) AS margin_pct,
    (SELECT AVG(gross_profit) FROM category_profit)
        AS avg_category_gross_profit,
    ROUND(
        100.0 * (
            gross_profit - (SELECT AVG(gross_profit) FROM category_profit)
        ) / NULLIF((SELECT AVG(gross_profit) FROM category_profit), 0),
        2
    ) AS pct_above_avg
FROM category_profit
WHERE gross_profit > (SELECT AVG(gross_profit) FROM category_profit)
ORDER BY gross_profit DESC;


-- =============================================================
-- Q15. One sales table with subtotals
-- `GROUPING SETS`, `GROUPING()`
-- Result: 36 rows  (screenshot: screenshots/q15_one_sales_table_with_subtotals.png)
-- =============================================================
WITH sales_lines AS (
    SELECT
        o.shipping_county AS county,
        p.category,
        o.order_id,
        oi.quantity,
        oi.line_total
    FROM sokomart.orders o
    JOIN sokomart.order_items oi ON oi.order_id = o.order_id
    JOIN sokomart.products p ON p.product_id = oi.product_id
    WHERE o.order_status = 'completed'
      AND o.order_date >= DATE '2026-01-01'
      AND o.order_date <  DATE '2027-01-01'
      AND o.shipping_county IN (
          'Nairobi', 'Mombasa', 'Kisumu', 'Nakuru', 'Uasin Gishu'
      )
)
SELECT
    CASE
        WHEN GROUPING(county) = 0 AND GROUPING(category) = 0
            THEN 'county x category'
        WHEN GROUPING(county) = 0 AND GROUPING(category) = 1
            THEN 'county total'
        WHEN GROUPING(county) = 1 AND GROUPING(category) = 0
            THEN 'category total'
        ELSE 'grand total'
    END AS grouping_level,
    CASE WHEN GROUPING(county) = 1 THEN 'ALL COUNTIES'
         ELSE county END AS county,
    CASE WHEN GROUPING(category) = 1 THEN 'ALL CATEGORIES'
         ELSE category END AS category,
    SUM(line_total)::NUMERIC(14,2) AS revenue,
    COUNT(DISTINCT order_id) AS order_count
FROM sales_lines
GROUP BY GROUPING SETS (
    (county, category),
    (county),
    (category),
    ()
)
ORDER BY
    GROUPING(county),
    county,
    GROUPING(category),
    category;


-- =============================================================
-- Q16(a). Customer purchase summary view
-- `CREATE VIEW` over CTEs + `LEFT JOIN`; `CREATE MATERIALIZED VIEW`
-- Result: 5000 rows  (screenshot: screenshots/q16_v_customer_purchase_summary.png)
-- Result: 10 rows  (screenshot: screenshots/q16_top_10_kiambu_customers_by_lifetime_spend.png)
-- Result: 5 rows  (screenshot: screenshots/q16_mv_monthly_category_sales.png)
-- =============================================================
CREATE OR REPLACE VIEW sokomart.v_customer_purchase_summary AS
WITH order_summary AS (
    SELECT
        o.customer_id,
        COUNT(*) AS completed_orders,
        SUM(o.total_amount)::NUMERIC(14,2) AS lifetime_spent,
        AVG(o.total_amount)::NUMERIC(14,2) AS avg_order_value,
        MIN(o.order_date)::DATE AS first_order_date,
        MAX(o.order_date)::DATE AS last_order_date
    FROM sokomart.orders o
    WHERE o.order_status = 'completed'
    GROUP BY o.customer_id
)
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name AS full_name,
    c.county,
    c.registration_date,
    COALESCE(os.completed_orders, 0) AS completed_orders,
    COALESCE(os.lifetime_spent, 0)::NUMERIC(14,2) AS lifetime_spent,
    os.avg_order_value,
    os.first_order_date,
    os.last_order_date,
    CASE
        WHEN os.last_order_date IS NULL THEN NULL
        ELSE DATE '2026-10-31' - os.last_order_date
    END AS days_since_last_order
FROM sokomart.customers c
LEFT JOIN order_summary os ON os.customer_id = c.customer_id;

-- Q16(a) Top 10 Kiambu customers by lifetime spend
SELECT *
FROM sokomart.v_customer_purchase_summary
WHERE county = 'Kiambu'
ORDER BY lifetime_spent DESC, customer_id
LIMIT 10;

-- Q16(a) View row count and customers with zero completed orders
SELECT
    COUNT(*) AS view_rows,
    COUNT(*) FILTER (WHERE completed_orders = 0) AS customers_with_zero_orders
FROM sokomart.v_customer_purchase_summary;


-- =============================================================
-- Q16(b). Monthly category sales materialized view
-- =============================================================
DROP MATERIALIZED VIEW IF EXISTS sokomart.mv_monthly_category_sales CASCADE;

CREATE MATERIALIZED VIEW sokomart.mv_monthly_category_sales AS
SELECT
    DATE_TRUNC('month', o.order_date)::DATE AS sales_month,
    p.category,
    COUNT(DISTINCT o.order_id) AS orders,
    SUM(oi.quantity)::BIGINT AS units_sold,
    SUM(oi.line_total)::NUMERIC(14,2) AS revenue,
    SUM(oi.line_total - oi.quantity * p.cost_price)::NUMERIC(14,2)
        AS gross_profit
FROM sokomart.orders o
JOIN sokomart.order_items oi ON oi.order_id = o.order_id
JOIN sokomart.products p ON p.product_id = oi.product_id
WHERE o.order_status = 'completed'
GROUP BY DATE_TRUNC('month', o.order_date)::DATE, p.category;

CREATE UNIQUE INDEX ux_mv_monthly_category_sales_month_category
ON sokomart.mv_monthly_category_sales (sales_month, category);

-- Q16(b) December 2025 rows
SELECT *
FROM sokomart.mv_monthly_category_sales
WHERE sales_month = DATE '2025-12-01'
ORDER BY revenue DESC;


-- =============================================================
-- Q17. Function: customer spend for an inclusive date range
-- Result: 5 rows  (screenshot: screenshots/q17_calls_for_customer_4000.png)
-- Result: 1 row  (screenshot: screenshots/q17_v_customer_comparison.png)
-- Result: 5 rows  (screenshot: screenshots/q17_top_5_nairobi_customers.png)
-- =============================================================
CREATE OR REPLACE FUNCTION sokomart.fn_customer_spend(
    p_customer_id INTEGER,
    p_start_date DATE,
    p_end_date DATE
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_spend NUMERIC(14,2);
BEGIN
    IF p_end_date < p_start_date THEN
        RAISE EXCEPTION
            'End date (%) cannot be before start date (%)',
            p_end_date, p_start_date;
    END IF;

    SELECT COALESCE(SUM(oi.line_total), 0)::NUMERIC(14,2)
    INTO v_spend
    FROM sokomart.orders o
    JOIN sokomart.order_items oi ON oi.order_id = o.order_id
    WHERE o.customer_id = p_customer_id
      AND o.order_status = 'completed'
      AND o.order_date >= p_start_date
      AND o.order_date < (p_end_date + INTERVAL '1 day');

    RETURN COALESCE(v_spend, 0);
END;
$$;

-- Q17: Calls for customer 4000
SELECT '2025' AS period,
       sokomart.fn_customer_spend(4000, DATE '2025-01-01', DATE '2025-12-31') AS spend
UNION ALL
SELECT 'Jan-Oct 2026',
       sokomart.fn_customer_spend(4000, DATE '2026-01-01', DATE '2026-10-31')
UNION ALL
SELECT 'Jan 2025-Oct 2026',
       sokomart.fn_customer_spend(4000, DATE '2025-01-01', DATE '2026-10-31')
UNION ALL
SELECT 'December 2025',
       sokomart.fn_customer_spend(4000, DATE '2025-12-01', DATE '2025-12-31')
UNION ALL
SELECT 'Unknown customer -1',
       sokomart.fn_customer_spend(-1, DATE '2025-01-01', DATE '2025-12-31');

-- Q17: Compare all-time function result with Q16 view lifetime_spent
SELECT
    customer_id,
    lifetime_spent,
    sokomart.fn_customer_spend(
        customer_id, DATE '2000-01-01', DATE '2026-10-31'
    ) AS fn_value,
    lifetime_spent = sokomart.fn_customer_spend(
        customer_id, DATE '2000-01-01', DATE '2026-10-31'
    ) AS matches
FROM sokomart.v_customer_purchase_summary
WHERE customer_id = 4000;

-- Q17: Top 5 Nairobi customers by December 2025 spend
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name AS full_name,
    sokomart.fn_customer_spend(
        c.customer_id, DATE '2025-12-01', DATE '2025-12-31'
    ) AS december_2025_spend
FROM sokomart.customers c
WHERE c.county = 'Nairobi'
ORDER BY december_2025_spend DESC, c.customer_id
LIMIT 5;


-- =============================================================
-- Q18. Procedure: change a product price and record history
-- Result: 1 row  (screenshot: screenshots/q18_product_71_before_change.png)
-- Result: 1 row  (screenshot: screenshots/q18_verify_updates.png)
-- Result: 1 row  (screenshot: screenshots/q18_verify_price_history_and_audit_log.png)
-- =============================================================
CREATE OR REPLACE PROCEDURE sokomart.sp_update_product_price(
    p_product_id INTEGER,
    p_new_price NUMERIC,
    p_reason VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_old_price NUMERIC(14,2);
    v_cost_price NUMERIC(14,2);
BEGIN
    SELECT unit_price, cost_price
    INTO v_old_price, v_cost_price
    FROM sokomart.products
    WHERE product_id = p_product_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product % does not exist', p_product_id;
    END IF;

    IF p_new_price <= 0 THEN
        RAISE EXCEPTION 'New price must be greater than zero';
    END IF;

    IF p_new_price < v_cost_price THEN
        RAISE EXCEPTION
            'New price (%) cannot be below cost price (%)',
            p_new_price, v_cost_price;
    END IF;

    UPDATE sokomart.products
    SET unit_price = p_new_price
    WHERE product_id = p_product_id;

    INSERT INTO sokomart.product_price_history
        (product_id, old_price, new_price, change_reason)
    VALUES
        (p_product_id, v_old_price, p_new_price, p_reason);

    INSERT INTO sokomart.audit_logs
        (table_name, record_id, action, old_data, new_data)
    VALUES
        (
            'products',
            p_product_id,
            'UPDATE',
            jsonb_build_object('unit_price', v_old_price),
            jsonb_build_object('unit_price', p_new_price)
        );
END;
$$;

-- Q18: Inspect product 71 before the change
SELECT product_id, product_name, unit_price, cost_price
FROM sokomart.products
WHERE product_id = 71;

-- Q18: Apply requested price change
CALL sokomart.sp_update_product_price(
    71, 1099.00, 'Supplier price increase - Nov 2026'
);

-- Q18: Verify updated product
SELECT product_id, product_name, unit_price, cost_price
FROM sokomart.products
WHERE product_id = 71;

-- Q18: Verify price history and audit log
SELECT price_history_id, product_id, old_price, new_price, change_reason
FROM sokomart.product_price_history
WHERE product_id = 71
ORDER BY price_history_id DESC
LIMIT 5;


-- =============================================================
-- Q19(a). Trigger function and order status audit trigger
-- Trigger function, `TG\\\\\\\_OP`, `OLD`/`NEW`, `IS DISTINCT FROM`; procedure with rules.
-- Result: 1 row  (screenshot: screenshots/q19_order_48882_before_transition.png)
-- Result: 1 row  (screenshot: screenshots/q19_order_48882_after_transition.png)
-- Result: 1 row  (screenshot: screenshots/q19_order_history_row.png)
-- Result: 1 row  (screenshot: screenshots/q19_order_audit_row.png)
-- Result: 1 row  (screenshot: screenshots/q19_order_status_history.png)
-- Result: 1 row  (screenshot: screenshots/q19_invalid_transition.png)
-- =============================================================
CREATE OR REPLACE FUNCTION sokomart.fn_audit_order_status()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO sokomart.order_status_history
            (order_id, old_status, new_status)
        VALUES
            (NEW.order_id, NULL, NEW.order_status);

        INSERT INTO sokomart.audit_logs
            (table_name, record_id, action, old_data, new_data)
        VALUES
            (
                'orders',
                NEW.order_id,
                'INSERT',
                NULL,
                jsonb_build_object('order_status', NEW.order_status)
            );

    ELSIF TG_OP = 'UPDATE'
       AND OLD.order_status IS DISTINCT FROM NEW.order_status THEN

        INSERT INTO sokomart.order_status_history
            (order_id, old_status, new_status)
        VALUES
            (NEW.order_id, OLD.order_status, NEW.order_status);

        INSERT INTO sokomart.audit_logs
            (table_name, record_id, action, old_data, new_data)
        VALUES
            (
                'orders',
                NEW.order_id,
                'UPDATE',
                jsonb_build_object('order_status', OLD.order_status),
                jsonb_build_object('order_status', NEW.order_status)
            );
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_orders_status_audit ON sokomart.orders;

CREATE TRIGGER trg_orders_status_audit
AFTER INSERT OR UPDATE OF order_status
ON sokomart.orders
FOR EACH ROW
EXECUTE FUNCTION sokomart.fn_audit_order_status();


-- =============================================================
-- Q19(b). Procedure: enforce allowed order status transitions
-- =============================================================
CREATE OR REPLACE PROCEDURE sokomart.sp_update_order_status(
    p_order_id INTEGER,
    p_new_status VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_old_status VARCHAR;
BEGIN
    SELECT order_status
    INTO v_old_status
    FROM sokomart.orders
    WHERE order_id = p_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order % does not exist', p_order_id;
    END IF;

    IF NOT (
        (v_old_status = 'pending' AND p_new_status IN ('completed', 'cancelled'))
        OR
        (v_old_status = 'completed' AND p_new_status = 'returned')
    ) THEN
        RAISE EXCEPTION
            'Invalid order status transition: % -> %',
            v_old_status, p_new_status;
    END IF;

    UPDATE sokomart.orders
    SET order_status = p_new_status
    WHERE order_id = p_order_id;

    IF p_new_status = 'completed' THEN
        UPDATE sokomart.payments
        SET payment_status = 'successful'
        WHERE order_id = p_order_id;

    ELSIF p_new_status = 'cancelled' THEN
        UPDATE sokomart.payments
        SET payment_status = 'failed'
        WHERE order_id = p_order_id
          AND payment_status = 'pending';
    END IF;
END;
$$;

-- Q19(c): Check order 48882 and its payment before transition
SELECT o.order_id, o.order_status, p.payment_status
FROM sokomart.orders o
LEFT JOIN sokomart.payments p ON p.order_id = o.order_id
WHERE o.order_id = 48882;

-- Complete order 48882; trigger writes history and audit rows
CALL sokomart.sp_update_order_status(48882, 'completed');

SELECT o.order_id, o.order_status, p.payment_status
FROM sokomart.orders o
LEFT JOIN sokomart.payments p ON p.order_id = o.order_id
WHERE o.order_id = 48882;

-- Verify history and audit
SELECT order_id, old_status, new_status
FROM sokomart.order_status_history
WHERE order_id = 48882;

SELECT table_name, record_id, action, old_data, new_data
FROM sokomart.audit_logs
WHERE table_name = 'orders' AND record_id = 48882;

-- Plain UPDATE to returned: trigger must also record this change
UPDATE sokomart.orders
SET order_status = 'returned'
WHERE order_id = 48882;

-- No history should be added by an update that does not change status
UPDATE sokomart.orders
SET shipping_county = shipping_county
WHERE order_id = 48882;

SELECT COUNT(*) AS history_rows_for_order_48882
FROM sokomart.order_status_history
WHERE order_id = 48882;

-- Invalid transition demonstration; execute separately to capture exception
--CALL sokomart.sp_update_order_status(49961, 'completed');
