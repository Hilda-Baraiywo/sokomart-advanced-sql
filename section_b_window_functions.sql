-- =============================================================
-- SOKOMART ADVANCED SQL PROJECT
-- =============================================================
show search_path;
-- =============================================================
-- Q6. County leaderboards
-- `DENSE\\\_RANK() OVER (PARTITION BY … ORDER BY …)` over a CTE
-- Result: 42 rows (screenshot: screenshots\q06_county_leaderboards.png)
-- =============================================================
WITH customer_spend AS (
    SELECT
        c.county,
        c.customer_id,
        c.first_name || ' ' || c.last_name AS full_name,
        COALESCE(SUM(oi.line_total), 0)::NUMERIC(14,2) AS total_spent
    FROM sokomart.customers c
    LEFT JOIN sokomart.orders o
        ON o.customer_id = c.customer_id
       AND o.order_status = 'completed'
    LEFT JOIN sokomart.order_items oi
        ON oi.order_id = o.order_id
    GROUP BY c.county, c.customer_id, c.first_name, c.last_name
),
ranked_customers AS (
    SELECT
        county,
        customer_id,
        full_name,
        total_spent,
        DENSE_RANK() OVER (
            PARTITION BY county
            ORDER BY total_spent DESC
        ) AS county_rank
    FROM customer_spend
)
SELECT county, county_rank, customer_id, full_name, total_spent
FROM ranked_customers
WHERE county_rank <= 3
ORDER BY county, county_rank, customer_id;


-- =============================================================
-- Q7. Best sellers per category, 2025
-- `ROW\\\_NUMBER()` top-N per group
-- Result: 15 rows (screenshot: screenshots\q07_best_sellers_per_category.png)
-- =============================================================
WITH product_sales AS (
    SELECT
        p.category,
        p.product_id,
        p.product_name,
        SUM(oi.line_total)::NUMERIC(14,2) AS revenue,
        SUM(oi.quantity)::BIGINT AS units_sold
    FROM sokomart.products p
    JOIN sokomart.order_items oi ON oi.product_id = p.product_id
    JOIN sokomart.orders o ON o.order_id = oi.order_id
    WHERE o.order_status = 'completed'
      AND o.order_date >= DATE '2025-01-01'
      AND o.order_date <  DATE '2026-01-01'
    GROUP BY p.category, p.product_id, p.product_name
),
ranked_products AS (
    SELECT
        category,
        product_id,
        product_name,
        revenue,
        units_sold,
        ROW_NUMBER() OVER (
            PARTITION BY category
            ORDER BY revenue DESC, product_id
        ) AS rank_in_category
    FROM product_sales
)
SELECT category, rank_in_category, product_id, product_name, revenue, units_sold
FROM ranked_products
WHERE rank_in_category <= 3
ORDER BY category, rank_in_category;


-- =============================================================
-- Q8. Month-over-month growth
-- `LAG()`, `NULLIF` to avoid division by zero
-- Result: 22 rows (screenshot: screenshots\q08_month_over_month_growth.png)
-- =============================================================
WITH months AS (
    SELECT generate_series(
        DATE '2025-01-01',
        DATE '2026-10-01',
        INTERVAL '1 month'
    )::DATE AS month
),
monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', o.order_date)::DATE AS month,
        SUM(oi.line_total)::NUMERIC(14,2) AS revenue
    FROM sokomart.orders o
    JOIN sokomart.order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'completed'
      AND o.order_date >= DATE '2025-01-01'
      AND o.order_date <  DATE '2026-11-01'
    GROUP BY DATE_TRUNC('month', o.order_date)::DATE
),
filled_months AS (
    SELECT
        m.month,
        COALESCE(r.revenue, 0)::NUMERIC(14,2) AS revenue
    FROM months m
    LEFT JOIN monthly_revenue r ON r.month = m.month
),
with_previous AS (
    SELECT
        month,
        revenue,
        LAG(revenue) OVER (ORDER BY month) AS prev_month_revenue
    FROM filled_months
)
SELECT
    month,
    revenue,
    prev_month_revenue,
    ROUND(
        100.0 * (revenue - prev_month_revenue)
        / NULLIF(prev_month_revenue, 0),
        2
    ) AS growth_pct
FROM with_previous
ORDER BY month;


-- =============================================================
-- Q9. Is each order bigger than the last?
-- `LAG() OVER (PARTITION BY customer\\\_id ORDER BY order\\\_date)`
-- Result: 393 rows (screenshot: screenshots\q09_nyeri_customers_orders_completed_2026.png)
-- Result: 1 row (screenshot: screenshots\q09_total_rows_distinct_first_up_down_customers.png)
-- =============================================================

total rows, distinct customers, first/up/down orders
WITH nyeri_orders AS (
    SELECT
        c.customer_id,
        o.order_id,
        o.order_date,
        o.total_amount::NUMERIC(14,2) AS total_amount
    FROM sokomart.customers c
    JOIN sokomart.orders o ON o.customer_id = c.customer_id
    WHERE c.county = 'Nyeri'
      AND o.order_status = 'completed'
      AND o.order_date >= DATE '2026-01-01'
      AND o.order_date <  DATE '2027-01-01'
),
compared_orders AS (
    SELECT
        customer_id,
        order_id,
        order_date,
        total_amount,
        LAG(total_amount) OVER (
            PARTITION BY customer_id
            ORDER BY order_date, order_id
        ) AS previous_order_amount
    FROM nyeri_orders
)
SELECT
    customer_id,
    order_id,
    order_date,
    total_amount,
    previous_order_amount,
    total_amount - previous_order_amount AS change_amount,
    CASE
        WHEN previous_order_amount IS NULL THEN 'first order'
        WHEN total_amount > previous_order_amount THEN 'up'
        WHEN total_amount < previous_order_amount THEN 'down'
        ELSE 'same'
    END AS direction
FROM compared_orders
ORDER BY customer_id, order_date, order_id;

-- Q9 summary: total rows, distinct customers, first/up/down orders
WITH nyeri_orders AS (
    SELECT c.customer_id, o.order_id, o.order_date, o.total_amount
    FROM sokomart.customers c
    JOIN sokomart.orders o ON o.customer_id = c.customer_id
    WHERE c.county = 'Nyeri'
      AND o.order_status = 'completed'
      AND o.order_date >= DATE '2026-01-01'
      AND o.order_date <  DATE '2027-01-01'
),
compared_orders AS (
    SELECT *,
        LAG(total_amount) OVER (
            PARTITION BY customer_id ORDER BY order_date, order_id
        ) AS previous_order_amount
    FROM nyeri_orders
),
labelled AS (
    SELECT *,
        CASE
            WHEN previous_order_amount IS NULL THEN 'first order'
            WHEN total_amount > previous_order_amount THEN 'up'
            WHEN total_amount < previous_order_amount THEN 'down'
            ELSE 'same'
        END AS direction
    FROM compared_orders
)
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT customer_id) AS distinct_customers,
    COUNT(*) FILTER (WHERE direction = 'first order') AS first_orders,
    COUNT(*) FILTER (WHERE direction = 'up') AS orders_bigger_than_previous,
    COUNT(*) FILTER (WHERE direction = 'down') AS orders_smaller_than_previous
FROM labelled;


-- =============================================================
-- Q10. Year-to-date revenue
-- `SUM() OVER (PARTITION BY year ORDER BY month ROWS …)`
-- Result: 22 rows (screenshot: screenshots\q10_year_to_date_revenue.png)
-- =============================================================
WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', o.order_date)::DATE AS month,
        EXTRACT(YEAR FROM o.order_date)::INTEGER AS year,
        SUM(oi.line_total)::NUMERIC(14,2) AS monthly_revenue
    FROM sokomart.orders o
    JOIN sokomart.order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'completed'
      AND o.order_date >= DATE '2025-01-01'
      AND o.order_date <  DATE '2026-11-01'
    GROUP BY DATE_TRUNC('month', o.order_date)::DATE,
             EXTRACT(YEAR FROM o.order_date)::INTEGER
)
SELECT
    year,
    month,
    monthly_revenue,
    SUM(monthly_revenue) OVER (
        PARTITION BY year
        ORDER BY month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_revenue_ytd,
    SUM(monthly_revenue) OVER (
        ORDER BY month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_revenue_all_time
FROM monthly_revenue
ORDER BY month;
