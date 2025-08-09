-- SQL Scripts for E-Commerce Analysis
-- Author: Zahra Kazemi

-- 1) Categorizing sales type
CREATE VIEW salescategory AS
SELECT *,
       CASE 
           WHEN quantity > 0 AND unitprice > 0 AND invoiceno NOT LIKE 'C%%' 
                THEN 'Realsale'
           WHEN quantity < 0 AND customerid IS NULL AND invoiceno LIKE 'C%%' 
                THEN 'Return'
           ELSE 'Unidentified'
       END AS salescategory
FROM ecommerce_sales;

-- 2) Identifying customer type (Repeat Buyer / One-Time Buyer)
CREATE VIEW customer_type AS
SELECT 
    customerid, 
    COUNT(DISTINCT invoiceno) AS countofinvoices,
    CASE 
        WHEN COUNT(DISTINCT invoiceno) > 1 THEN 'RepeatBuyer'  
        ELSE 'One-Time Buyer' 
    END AS customer_status
FROM salescategory
WHERE salescategory = 'Realsale' AND customerid IS NOT NULL
GROUP BY customerid;

-- 3) Calculating the average gap between purchases per customer
-- NOTE: 'sale_type' should be a view/table equivalent to 'salescategory' if used elsewhere
CREATE VIEW customer_interpurchace_gap AS
SELECT
    customerid,
    AVG(gap_days) AS avg_gap_days
FROM (
    SELECT
        customerid,
        invoicedate,
        LAG(invoicedate) OVER (PARTITION BY customerid ORDER BY invoicedate) AS gap_date,
        invoicedate - LAG(invoicedate) OVER (PARTITION BY customerid ORDER BY invoicedate) AS gap_days
    FROM sale_type
    WHERE salescategory = 'Realsale' AND customerid IS NOT NULL
) t
WHERE gap_date IS NOT NULL
GROUP BY customerid;

-- Detailed view (optional)
-- SELECT
--     customerid,
--     invoicedate,
--     LAG(invoicedate) OVER (PARTITION BY customerid ORDER BY invoicedate) AS previous_date,
--     invoicedate - LAG(invoicedate) OVER (PARTITION BY customerid ORDER BY invoicedate) AS gap_days
-- FROM sale_type
-- WHERE salescategory = 'Realsale' AND customerid IS NOT NULL;

-- 4) Calculating percentage of returns
CREATE VIEW per_of_return AS 
WITH sale_data AS (
    SELECT 
        invoiceno,
        SUM(CASE 
                WHEN salescategory = 'Realsale' THEN unitprice * quantity
                ELSE 0
            END) AS real_sale,
        SUM(CASE 
                WHEN salescategory = 'Return' THEN ABS(unitprice * quantity)
                ELSE 0
            END) AS return_sale
    FROM sale_type
    GROUP BY invoiceno
)
SELECT 
    invoiceno,
    real_sale,
    return_sale,
    ROUND(
        CASE 
            WHEN real_sale > 0 THEN ((return_sale / real_sale) * 100)::NUMERIC
            ELSE 0
        END, 2
    ) AS per_return
FROM sale_data
ORDER BY per_return DESC;

-- Optional: Top 10 invoices with the highest return value
-- SELECT * FROM per_of_return ORDER BY return_sale DESC LIMIT 10;
