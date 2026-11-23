# SokoMart Kenya — Advanced SQL Project

**Student Name:** Hilda Chepkirui
**Programme:** LuxDevHQ Cohort 9  
**Database:** `luxdevhq_cohort9_advanced_sql`  
**Schema:** `sokomart`  
**Database system:** PostgreSQL  
**SQL client:** DBeaver

## 1. Project Overview

This project applies advanced SQL techniques to the SokoMart Kenya retail database to analyse sales performance, customer behaviour, product profitability, payment performance and operational efficiency.

The project demonstrates practical use of:

- Common Table Expressions (CTEs) and subqueries
- Window functions and advanced aggregation
- Views and materialized views
- User-defined functions and stored procedures
- Triggers and audit logging
- Query execution plans and indexing
- Transactions, savepoints and rollback
- Data cleaning and duplicate removal

The objective is to transform retail data into actionable insights that can support better business decisions.

## 2. Repository Structure

```text
sokomart-advanced-sql/
│
├── README.md
│
├── sql/
│   ├── 00_practice_drills.sql
│   ├── section_a_ctes_subqueries.sql
│   ├── section_b_window_functions.sql
│   ├── section_c_advanced_aggregation.sql
│   ├── section_d_views_functions_procedures.sql
│   └── section_e_optimisation_transactions.sql
│
└── screenshots/
    ├── d01_products_priced_above_avg.png
    ├── d02_msa_customers_with_orders_2025.png
    ├── d03_kisumu_customer_with_failed_payment.png
    ├── d04_avg_order_lines_units_by_order_status.png
    ├── d05_shipping_counties_completed_orders_2026.png
    ├── d06_monthly_completed_orders_and_avg_2025.png
    ├── d07_existing_customer_177.png
    ├── d07_non_existing_customer_-1.png
    ├── d08_active_customer_set_to_suspended.png
    ├── d08_customer_active_in_supplied_dataset.png
    ├── d09_beauty_products_below_average_stock.png
    ├── d10_county_customer_count_and_completed_revenue.png
    │
    ├── q01_customer_2025_revenue.png
    ├── q01_customers_with_completed_purchases_avg_spent.png
    ├── q02_active_products_per_category.png
    ├── q02_premium_products.png
    ├── q03_monthly_profit_and_loss_2026.png
    ├── q04_cross_category_shoppers_nakuru.png
    ├── q04_nakuru_shoppers_from_5_categories.png
    ├── q05_products_nobody_has_ordered.png
    ├── q06_county_leaderboards.png
    ├── q07_best_sellers_per_category.png
    ├── q08_month_over_month_growth.png
    ├── q09_nyeri_customers_orders_completed_2026.png
    ├── q09_total_rows_distinct_first_up_down_customers.png
    ├── q10_year_to_date_revenue.png
    ├── q11_customer_tiers.png
    ├── q12_mombasa_purchase_october.png
    ├── q13_payment_health_by_method.png
    ├── q14_dept_above_avg_gross_profit.png
    ├── q15_one_sales_table_with_subtotals.png
    ├── q16_top_10_kiambu_customers_by_lifetime_spend.png
    ├── q16_v_customer_purchase_summary.png
    ├── q17_calls_for_customer_4000.png
    ├── q17_top_5_nairobi_customers.png
    ├── q17_v_customer_spend_comparison.png
    ├── q18_product_71_before_change.png
    ├── q18_verify_price_history_and_audit_log.png
    ├── q18_verify_updates.png
    ├── q19_invalid_transition.png
    ├── q19_order_48882_after_transition.png
    ├── q19_order_48882_before_transition.png
    ├── q19_order_audit_row.png
    ├── q19_order_history_row.png
    ├── q19_order_status_history.png
    ├── q20_products_before_placement.png
    ├── q21a.png
    ├── q22a.png
    ├── q23a_average_beauty_price_inside_transaction.png
    ├── q23a_beauty_average_after_rollback.png
    ├── q23a_price_before_change.png
    ├── q23b_products_after_savepoint.png
    ├── q23b_products_before_savepoint.png
    ├── q23b_products_during_transaction.png
    ├── q24a_checking_for_duplicates.png
    ├── q24b_10_rows_to_deleted.png
    ├── q24c_same_payments_in_payments_table.png
    ├── q24d_error.png
    ├── q25_customers_with_3plus_streak.png
    └── q25_three_months_in_a_row.png
```

The D1–D10 practice drills are supplementary exercises and are not part of the 25 marked questions.

## 3. Database Setup and How to Run

### Requirements

- PostgreSQL
- DBeaver Community Edition or another PostgreSQL-compatible SQL client
- The SokoMart project package, including database setup scripts and datasets

### Database configuration

| Setting | Value |
|---|---|
| Database | `luxdevhq_cohort9_advanced_sql` |
| Schema | `sokomart` |
| Database system | PostgreSQL |
| SQL client | DBeaver |

### Step 1: Load the SokoMart database

The project SQL scripts expect the SokoMart database to have already been created, populated and indexed using the setup files supplied in the project package.

Follow the instructions in the project's `docs/database_setup.md` guide.

For a fresh setup, use this order:

1. Run `07_reset_database.sql` if a clean database reset is required.
2. Run `03` to create the database tables.
3. Run `04` to import the supplied CSV data.
4. Run `05` to create the database indexes.

The `04` data-loading script uses PostgreSQL command-line instructions such as `\copy`. Run it using PostgreSQL SQL Shell/psql as described in the setup guide, rather than executing it as an ordinary DBeaver SQL script.

### Step 2: Run the project SQL files

Connect DBeaver to `luxdevhq_cohort9_advanced_sql` and execute the scripts in this order:

| Order | SQL file | Contents |
|---:|---|---|
| 1 | `sql/00_practice_drills.sql` | Supplementary practice drills |
| 2 | `sql/section_a_ctes_subqueries.sql` | Q1–Q5: CTEs and subqueries |
| 3 | `sql/section_b_window_functions.sql` | Q6–Q10: Window functions |
| 4 | `sql/section_c_advanced_aggregation.sql` | Q11–Q15: Advanced aggregation |
| 5 | `sql/section_d_views_functions_procedures.sql` | Q16–Q20: Views, functions, procedures and triggers |
| 6 | `sql/section_e_optimisation_transactions.sql` | Q21–Q25: Optimisation, transactions and data cleaning |

Run each file from top to bottom. Follow comments that instruct you to execute statements separately, particularly procedure calls, transaction demonstrations, rollback tests and expected error messages.

**Important execution notes:**

- Some scripts create database objects, update records or create indexes.
- Some transaction questions require autocommit to be disabled so rollback behaviour can be demonstrated correctly.
- Do not rerun data-modifying statements blindly on a database that has already been used for testing.
- For a repeatable fresh run, reset and reload the database before executing the project scripts again.

## 4. Results and Screenshots

The following table links each marked question to its SQL file and supporting screenshots. Multiple screenshots are included where a question requires several outputs or verification steps.

| Question | SQL file | Rows / result count | Screenshot evidence |
|---|---|---:|---|
| Q1 — 2025 big spenders | `sql/section_a_ctes_subqueries.sql` | 10 top / [actual] above average | [2025 revenue](screenshots/q01_customer_2025_revenue.png) · [Above-average customers](screenshots/q01_customers_with_completed_purchases_avg_spent.png) |
| Q2 — Premium-priced products | `sql/section_a_ctes_subqueries.sql` | [actual count] | [Active products by category](screenshots/q02_active_products_per_category.png) · [Premium products](screenshots/q02_premium_products.png) |
| Q3 — Monthly profit and loss | `sql/section_a_ctes_subqueries.sql` | 10 | [View](screenshots/q03_monthly_profit_and_loss_2026.png) |
| Q4 — Nakuru cross-category shoppers | `sql/section_a_ctes_subqueries.sql` | [actual count] | [Cross-category shoppers](screenshots/q04_cross_category_shoppers_nakuru.png) · [Five-category result](screenshots/q04_nakuru_shoppers_from_5_categories.png) |
| Q5 — Products never ordered | `sql/section_a_ctes_subqueries.sql` | [actual count] | [View](screenshots/q05_products_nobody_has_ordered.png) |
| Q6 — Top customers by county | `sql/section_b_window_functions.sql` | [actual count] | [View](screenshots/q06_county_leaderboards.png) |
| Q7 — Best-selling products by category | `sql/section_b_window_functions.sql` | 15 | [View](screenshots/q07_best_sellers_per_category.png) |
| Q8 — Monthly revenue growth | `sql/section_b_window_functions.sql` | 22 | [View](screenshots/q08_month_over_month_growth.png) |
| Q9 — Nyeri customer order analysis | `sql/section_b_window_functions.sql` | [actual count] | [Customer orders](screenshots/q09_nyeri_customers_orders_completed_2026.png) · [Summary counts](screenshots/q09_total_rows_distinct_first_up_down_customers.png) |
| Q10 — Monthly YTD and running revenue | `sql/section_b_window_functions.sql` | 22 | [View](screenshots/q10_year_to_date_revenue.png) |
| Q11 — Customer spending tiers | `sql/section_c_advanced_aggregation.sql` | 4 | [View](screenshots/q11_customer_tiers.png) |
| Q12 — Mombasa customer product interests | `sql/section_c_advanced_aggregation.sql` | [actual count] | [View](screenshots/q12_mombasa_purchase_october.png) |
| Q13 — Payment method performance | `sql/section_c_advanced_aggregation.sql` | 4 | [View](screenshots/q13_payment_health_by_method.png) |
| Q14 — Category profitability | `sql/section_c_advanced_aggregation.sql` | [actual count] | [View](screenshots/q14_dept_above_avg_gross_profit.png) |
| Q15 — County and category sales | `sql/section_c_advanced_aggregation.sql` | 36 | [View](screenshots/q15_one_sales_table_with_subtotals.png) |
| Q16 — Customer purchase summary | `sql/section_d_views_functions_procedures.sql` | [actual count] | [Purchase summary view](screenshots/q16_v_customer_purchase_summary.png) · [Top Kiambu customers](screenshots/q16_top_10_kiambu_customers_by_lifetime_spend.png) |
| Q17 — Customer spend function | `sql/section_d_views_functions_procedures.sql` | [actual count] | [Function calls](screenshots/q17_calls_for_customer_4000.png) · [Top Nairobi customers](screenshots/q17_top_5_nairobi_customers.png) · [Spend comparison](screenshots/q17_v_customer_spend_comparison.png) |
| Q18 — Product price update procedure | `sql/section_d_views_functions_procedures.sql` | [actual count] | [Before change](screenshots/q18_product_71_before_change.png) · [Update verification](screenshots/q18_verify_updates.png) · [Price history and audit log](screenshots/q18_verify_price_history_and_audit_log.png) |
| Q19 — Order status audit trigger | `sql/section_d_views_functions_procedures.sql` | [actual count] | [Before transition](screenshots/q19_order_48882_before_transition.png) · [After transition](screenshots/q19_order_48882_after_transition.png) · [Audit row](screenshots/q19_order_audit_row.png) · [History row](screenshots/q19_order_history_row.png) · [Status history](screenshots/q19_order_status_history.png) · [Invalid transition](screenshots/q19_invalid_transition.png) |
| Q20 — Place order procedure | `sql/section_d_views_functions_procedures.sql` | [actual count] | [Products before placement](screenshots/q20_products_before_placement.png) |
| Q21 — Dashboard query execution plan | `sql/section_e_optimisation_transactions.sql` | 91 final rows | [Execution plan](screenshots/q21a.png) |
| Q22 — Index performance comparison | `sql/section_e_optimisation_transactions.sql` | 3 query comparisons | [Index comparison](screenshots/q22a.png) |
| Q23 — Transaction management | `sql/section_e_optimisation_transactions.sql` | Multiple transaction checks | [Price before change](screenshots/q23a_price_before_change.png) · [Average inside transaction](screenshots/q23a_average_beauty_price_inside_transaction.png) · [Average after rollback](screenshots/q23a_beauty_average_after_rollback.png) · [Stock before savepoint](screenshots/q23b_products_before_savepoint.png) · [Stock during transaction](screenshots/q23b_products_during_transaction.png) · [Stock after savepoint](screenshots/q23b_products_after_savepoint.png) |
| Q24 — Payment duplicate cleanup | `sql/section_e_optimisation_transactions.sql` | [actual rows removed] | [Duplicate check](screenshots/q24a_checking_for_duplicates.png) · [Rows identified for deletion](screenshots/q24b_10_rows_to_deleted.png) · [Payment amount comparison](screenshots/q24c_same_payments_in_payments_table.png) · [Duplicate insert error](screenshots/q24d_error.png) |
| Q25 — Three-month purchase streaks | `sql/section_e_optimisation_transactions.sql` | [actual count] | [Qualifying customers](screenshots/q25_customers_with_3plus_streak.png) · [Three-month streaks](screenshots/q25_three_months_in_a_row.png) |

## 5. Business Insights and Recommendations

The following findings use recorded query outputs where available. Complete the remaining figures using the final query results before submission.

1. **Customer value and county performance (Q1 and Q6):**  
   Q1 identifies the top 10 customers by 2025 spending and compares customer spending against the average. Q6 ranks customer revenue within each county. The above-average customer count was **[actual count]**, while **[county]** had the strongest customer revenue performance at KES **[amount]**.  
   **Recommendation:** Create loyalty campaigns for high-value customers and targeted retention campaigns in counties with lower customer spending.

2. **Product pricing and stock management (Q2 and D9):**  
   Q2 identifies active products priced above their category average. D9 compares Beauty product stock against the category average. The number of premium-priced products was **[count]**, and the Beauty average stock level was **[quantity] units**.  
   **Recommendation:** Review product pricing against category benchmarks and use stock comparisons to guide replenishment decisions.

3. **Monthly sales performance (Q3, Q8 and Q10):**  
   Q3 returns 10 monthly profit-and-loss results for January–October 2026. Q8 and Q10 each provide 22 monthly results covering January 2025–October 2026. The highest-revenue month was **[month]**, with KES **[amount]**, representing **[percentage]%** growth compared with the previous month (Q8).  
   **Recommendation:** Use monthly revenue and gross-profit trends to plan inventory, promotions and purchasing ahead of high-demand periods.

4. **Customer purchasing behaviour (Q4, Q9 and Q25):**  
   Q4 identifies Nakuru customers who purchased across at least three product categories. Q9 analyses changes between completed orders from Nyeri customers, while Q25 identifies consecutive monthly purchasing streaks. The number of qualifying Nakuru customers was **[count]**, and the longest consecutive purchasing streak was **[months] months**.  
   **Recommendation:** Introduce relevant cross-category bundles and repeat-purchase rewards to encourage customer engagement and retention.

5. **Payment reliability (Q13):**  
   Q13 compares payment methods and returns four payment-method summary rows, including successful, failed and pending payments. The method with the highest success rate was **[method]**, at **[percentage]%**. Failed payments totalled KES **[amount]** in 2026.  
   **Recommendation:** Investigate failed transactions, improve payment follow-up and monitor payment success rates by method.

6. **Product category profitability (Q14 and Q15):**  
   Q14 identifies categories whose gross profit exceeds the average category gross profit. Q15 returns 36 county/category and summary grouping results for completed 2026 orders. The leading category by gross profit was **[category]**, with KES **[amount]** and a margin of **[percentage]%**.  
   **Recommendation:** Protect margins in profitable categories and investigate product costs, pricing and sales mix in weaker categories.

7. **Operational controls and order management (Q18, Q19 and Q20):**  
   The procedures and trigger automate controlled price changes, order placement and order-status auditing. These database operations provide validation and audit records that support data consistency.  
   **Recommendation:** Continue using validated database procedures and audit trails for important business updates, and regularly review failed operations and exceptions.

8. **Database performance and data quality (Q21, Q22 and Q24):**  
   Q21 returned 91 final rows, with a recorded execution time of 5.275 ms. In Q22, indexes reduced execution time from 11.838 ms to 0.266 ms for the orders query, from 8.421 ms to 0.171 ms for the payments query, and from 19.477 ms to 0.843 ms for the order-items query. These represent improvements of approximately 97.75%, 97.97% and 95.67%, respectively. The partial index occupied 32 kB compared with 1,112 kB for the full date index. Q24 identified duplicate payment staging records; the cleanup removed **[actual count]** extra rows.  
   **Recommendation:** Retain useful indexes, review query plans as data grows and enforce appropriate uniqueness constraints to prevent duplicate staging records.

## 6. Tools and Technologies

| Tool | Purpose |
|---|---|
| PostgreSQL | Database management and SQL execution |
| DBeaver | SQL development and database administration |
| SQL | Data analysis, transformations and database automation |
| Git | Version control |
| GitHub | Project repository and submission |

## 9. Conclusion

This project demonstrates how advanced PostgreSQL techniques can be applied to a retail business database to analyse customers, products, revenue, profitability and payment performance. It also shows how database objects, transaction controls, indexing and data-cleaning techniques can improve the reliability and efficiency of business operations.

The analysis provides a foundation for evidence-based decisions that can help SokoMart improve customer retention, product management, payment reliability and overall operational performance.
