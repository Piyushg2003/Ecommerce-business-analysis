SELECT
    COUNT(*) AS total_orders,
    COUNT(order_id) AS order_ids,
    COUNT(DISTINCT order_id) AS unique_orders
FROM olist_orders_dataset;

SELECT
    COUNT(*) AS total_customers,
    COUNT(DISTINCT customer_id) AS unique_customers
FROM olist_customers_dataset;

SELECT
    COUNT(*) AS total_products,
    COUNT(DISTINCT product_id) AS unique_products
FROM olist_products_dataset;

SELECT
    COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL) AS missing_delivery_date,
    COUNT(*) FILTER (WHERE order_approved_at IS NULL) AS missing_approval_date
FROM olist_orders_dataset;

SELECT order_status, COUNT(*)
FROM olist_orders_dataset
WHERE order_delivered_customer_date IS NULL
GROUP BY order_status
ORDER BY COUNT(*) DESC;

CREATE OR REPLACE VIEW payment_summary AS
SELECT
    order_id,
    SUM(payment_value) AS total_payment,
    MAX(payment_installments) AS payment_installments
FROM olist_order_payments_dataset
GROUP BY order_id;

DROP TABLE IF EXISTS orders_fact;

CREATE TABLE orders_fact AS
SELECT
    o.order_id,
    o.customer_id,

    c.customer_city,
    c.customer_state,

    CAST(o.order_purchase_timestamp AS timestamp)::date AS order_date,

    o.order_status,

    oi.product_id,
    oi.seller_id,

    p.product_category_name,

    oi.price,
    oi.freight_value,

    (oi.price + oi.freight_value) AS total_amount,

    ps.total_payment,
    ps.payment_installments,

    r.review_score,

    CASE
        WHEN o.order_delivered_customer_date IS NOT NULL
        THEN DATE_PART(
            'day',
            CAST(o.order_delivered_customer_date AS timestamp)
            -
            CAST(o.order_purchase_timestamp AS timestamp)
        )
        ELSE NULL
    END AS delivery_days

FROM olist_orders_dataset o

JOIN olist_order_items_dataset oi
    ON o.order_id = oi.order_id

JOIN olist_customers_dataset c
    ON o.customer_id = c.customer_id

LEFT JOIN olist_products_dataset p
    ON oi.product_id = p.product_id

LEFT JOIN payment_summary ps
    ON o.order_id = ps.order_id

LEFT JOIN olist_order_reviews_dataset r
    ON o.order_id = r.order_id;

SELECT *
FROM orders_fact
LIMIT 10;

CREATE OR REPLACE VIEW monthly_revenue AS
SELECT
    DATE_TRUNC('month', order_date) AS month,
    COUNT(DISTINCT order_id) AS orders,
    ROUND(SUM(total_amount)::numeric,2) AS revenue,
    ROUND(AVG(review_score)::numeric,2) AS avg_rating
FROM orders_fact
GROUP BY 1
ORDER BY 1;

SELECT *
FROM monthly_revenue;

CREATE OR REPLACE VIEW category_revenue AS
SELECT
    product_category_name,

    COUNT(*) AS order_count,

    ROUND(SUM(total_amount)::numeric,2) AS revenue,

    ROUND(AVG(delivery_days)::numeric,1) AS avg_delivery_days,

    ROUND(AVG(review_score)::numeric,2) AS avg_rating

FROM orders_fact
GROUP BY 1
ORDER BY revenue DESC;

SELECT *
FROM category_revenue
LIMIT 10;

CREATE OR REPLACE VIEW state_sales AS
SELECT
    customer_state,
    COUNT(DISTINCT order_id) AS orders,
    ROUND(SUM(total_amount)::numeric,2) AS revenue
FROM orders_fact
GROUP BY customer_state
ORDER BY revenue DESC;