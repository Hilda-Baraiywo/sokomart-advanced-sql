-- =============================================================
-- SECTION A. CTEs AND SUBQUERIES (Questions 1-5)
-- =============================================================

-- ================================================================================================
-- Q1. Big spenders of 2025 (CTE + scalar subquery over the CTE)
-- Result 1: 1432 rows  (screenshot: screenshots/q01_customer_2025_revenue.png)
-- Result 2: 1 row  (screenshot: screenshots/q01_customers_with_completed_purchases_avg_spent.png)
-- =================================================================================================

WITH customer_2025_revenue AS (
    -- One row per customer who had completed revenue in 2025.
    SELECT
        o.customer_id,
        SUM(oi.line_total) AS total_spent_2025
    FROM sokomart.orders AS o
    JOIN sokomart.order_items AS oi
      ON oi.order_id = o.order_id
    WHERE o.order_status = 'completed'
      AND o.order_date >= DATE '2025-01-01'
      AND o.order_date <  DATE '2026-01-01'
    GROUP BY o.customer_id
)
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name AS full_name,
    c.county,
    ROUND(r.total_spent_2025, 2) AS total_spent_2025,
    ROUND((
        SELECT AVG(r2.total_spent_2025)
        FROM customer_2025_revenue AS r2
    ), 2) AS avg_spent_2025,
    ROUND(
        r.total_spent_2025 - (
            SELECT AVG(r3.total_spent_2025)
            FROM customer_2025_revenue AS r3
        ),
        2
    ) AS amount_above_avg
FROM customer_2025_revenue AS r
JOIN sokomart.customers AS c
  ON c.customer_id = r.customer_id
WHERE r.total_spent_2025 > (
    SELECT AVG(r4.total_spent_2025)
    FROM customer_2025_revenue AS r4
)
ORDER BY r.total_spent_2025 DESC, c.customer_id;

-- Q1 second query:
-- Number of customers who bought (completed purchases) in 2025,
-- the average spend among those buyers, and the number returned
-- by the main above-average query.
WITH customer_2025_revenue AS (
    SELECT
        o.customer_id,
        SUM(oi.line_total) AS total_spent_2025
    FROM sokomart.orders AS o
    JOIN sokomart.order_items AS oi
      ON oi.order_id = o.order_id
    WHERE o.order_status = 'completed'
      AND o.order_date >= DATE '2025-01-01'
      AND o.order_date <  DATE '2026-01-01'
    GROUP BY o.customer_id
)
SELECT
    COUNT(*)::INTEGER AS customers_who_bought_2025,
    ROUND(AVG(total_spent_2025), 2) AS avg_spent_2025,
    COUNT(*) FILTER (
        WHERE total_spent_2025 > (
            SELECT AVG(r2.total_spent_2025)
            FROM customer_2025_revenue AS r2
        )
    )::INTEGER AS above_average_customer_rows
FROM customer_2025_revenue;


-- ===============================================================================================
-- Q2. Premium-priced products (correlated subquery in WHERE and SELECT)
-- Result: 104 rows  (screenshot: screenshots/q02_premium_products.png)
-- Result: 5 rows  (screenshot: screenshots/q02_active_products_per_category.png)
-- =================================================================================================


SELECT
    p.product_id,
    p.product_name,
    p.category,
    p.unit_price,
    (
        SELECT AVG(p2.unit_price)
        FROM sokomart.products AS p2
        WHERE p2.category = p.category
    ) AS category_avg_price,
    p.unit_price - (
        SELECT AVG(p3.unit_price)
        FROM sokomart.products AS p3
        WHERE p3.category = p.category
    ) AS price_gap
FROM sokomart.products AS p
WHERE p.product_status = 'active'
  AND p.unit_price > (
      SELECT AVG(p4.unit_price)
      FROM sokomart.products AS p4
      WHERE p4.category = p.category
  )
ORDER BY p.category, price_gap DESC, p.product_id;

-- Q2 second query: count qualifying active products per category.
SELECT
    qualifying.category,
    COUNT(*) AS products_above_category_average
FROM (
    SELECT
        p.product_id,
        p.category
    FROM sokomart.products AS p
    WHERE p.product_status = 'active'
      AND p.unit_price > (
          SELECT AVG(p2.unit_price)
          FROM sokomart.products AS p2
          WHERE p2.category = p.category
      )
) AS qualifying
GROUP BY qualifying.category
ORDER BY qualifying.category;


-- ================================================================================
-- Q3. 2026 monthly profit and loss (January-October) (at least three chained CTEs)
-- Result: 10 rows  (screenshot: screenshots/q03_monthly_profit_and_loss_2026.png)
-- =================================================================================


WITH completed_order_lines AS (
    -- Step 1: completed 2026 order lines, with month and line cost.
    SELECT
        DATE_TRUNC('month', o.order_date)::date AS month,
        oi.line_total::NUMERIC AS line_revenue,
        (oi.quantity * p.cost_price)::NUMERIC AS line_cost
    FROM sokomart.orders AS o
    JOIN sokomart.order_items AS oi
      ON oi.order_id = o.order_id
    JOIN sokomart.products AS p
      ON p.product_id = oi.product_id
    WHERE o.order_status = 'completed'
      AND o.order_date >= DATE '2026-01-01'
      AND o.order_date <  DATE '2026-11-01'
),
monthly_totals AS (
    -- Step 2: add revenue and cost for each month.
    SELECT
        month,
        SUM(line_revenue) AS revenue,
        SUM(line_cost) AS cost
    FROM completed_order_lines
    GROUP BY month
),
monthly_profit AS (
    -- Step 3: calculate gross profit.
    SELECT
        month,
        revenue,
        cost,
        revenue - cost AS gross_profit
    FROM monthly_totals
),
calendar_months AS (
    SELECT
        generate_series(
            DATE '2026-01-01',
            DATE '2026-10-01',
            INTERVAL '1 month'
        )::date AS month
)
SELECT
    TO_CHAR(cm.month, 'YYYY-MM') AS month,
    ROUND(COALESCE(mp.revenue, 0), 2) AS revenue,
    ROUND(COALESCE(mp.cost, 0), 2) AS cost,
    ROUND(COALESCE(mp.gross_profit, 0), 2) AS gross_profit,
    CASE
        WHEN COALESCE(mp.revenue, 0) = 0 THEN NULL
        ELSE ROUND(
            100.0 * mp.gross_profit / mp.revenue,
            2
        )
    END AS margin_pct
FROM calendar_months AS cm
LEFT JOIN monthly_profit AS mp
  ON mp.month = cm.month
ORDER BY cm.month;


-- =================================================================================
-- Q4. Cross-category shoppers in Nakuru (derived table and COUNT(DISTINCT ...)
-- Result: 346 rows  (screenshot: screenshots/q04_cross_category_shoppers_nakuru.png)
-- Result: 1 row  (screenshot: screenshots/q04_nakuru_shoppers_from_5_categories.png)
-- ==================================================================================

SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name AS full_name,
    c.county,
    shopper_summary.category_count,
    ROUND(shopper_summary.total_spent, 2) AS total_spent
FROM sokomart.customers AS c
JOIN (
    SELECT
        o.customer_id,
        COUNT(DISTINCT p.category) AS category_count,
        SUM(oi.line_total) AS total_spent
    FROM sokomart.orders AS o
    JOIN sokomart.order_items AS oi
      ON oi.order_id = o.order_id
    JOIN sokomart.products AS p
      ON p.product_id = oi.product_id
    WHERE o.order_status = 'completed'
    GROUP BY o.customer_id
) AS shopper_summary
  ON shopper_summary.customer_id = c.customer_id
WHERE c.county = 'Nakuru'
  AND shopper_summary.category_count >= 3
ORDER BY
    shopper_summary.category_count DESC,
    shopper_summary.total_spent DESC,
    c.customer_id;

-- Q4 second query: qualifying Nakuru shoppers and how many
-- of those shoppers bought from all five product categories.
SELECT
    COUNT(*) AS qualifying_nakuru_customers,
    COUNT(*) FILTER (
        WHERE shopper_summary.category_count = 5
    ) AS qualifying_customers_all_five_categories
FROM sokomart.customers AS c
JOIN (
    SELECT
        o.customer_id,
        COUNT(DISTINCT p.category) AS category_count,
        SUM(oi.line_total) AS total_spent
    FROM sokomart.orders AS o
    JOIN sokomart.order_items AS oi
      ON oi.order_id = o.order_id
    JOIN sokomart.products AS p
      ON p.product_id = oi.product_id
    WHERE o.order_status = 'completed'
    GROUP BY o.customer_id
) AS shopper_summary
  ON shopper_summary.customer_id = c.customer_id
WHERE c.county = 'Nakuru'
  AND shopper_summary.category_count >= 3;


-- ==================================================================================
-- Q5. Products nobody has ordered (anti-join with NOT EXISTS (NOT IN is not used)
-- Result: 18 rows  (screenshot: screenshots/q05_products_nobody_has_ordered.png)
-- ==================================================================================
SELECT
    p.product_id,
    p.product_name,
    p.category,
    p.product_status,
    p.stock_quantity,
    p.created_at
FROM sokomart.products AS p
WHERE NOT EXISTS (
    SELECT 1
    FROM sokomart.order_items AS oi
    WHERE oi.product_id = p.product_id
)
ORDER BY p.category, p.product_name, p.product_id;
