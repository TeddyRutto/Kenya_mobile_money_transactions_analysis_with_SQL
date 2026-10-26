CREATE TABLE kenya\_mobile\_money\_transactions (

&#x20;   transaction\_id         VARCHAR(20) PRIMARY KEY,

&#x20;   transaction\_timestamp  TIMESTAMP,

&#x20;   customer\_id            VARCHAR(20),

&#x20;   customer\_name          VARCHAR(100),

&#x20;   gender                 VARCHAR(10),

&#x20;   age                    INT,

&#x20;   county                 VARCHAR(50),

&#x20;   phone\_number           VARCHAR(20),

&#x20;   channel                VARCHAR(30),

&#x20;   transaction\_type       VARCHAR(30),

&#x20;   merchant\_category      VARCHAR(50),

&#x20;   device\_type            VARCHAR(20),

&#x20;   amount\_kes             NUMERIC(12,2),

&#x20;   transaction\_fee\_kes    NUMERIC(12,2),

&#x20;   balance\_after\_kes      NUMERIC(12,2),

&#x20;   status                 VARCHAR(20)

);





ALTER TABLE kenya\_mobile\_money\_transactions

ALTER COLUMN transaction\_timestamp TYPE TIMESTAMP

USING TO\_TIMESTAMP(transaction\_timestamp, 'YYYY/MM/DD HH24:MI:SS');



ALTER TABLE kenya\_mobile\_money\_transactions

ALTER COLUMN transaction\_fee\_kes TYPE NUMERIC(12,2)

USING transaction\_fee\_kes::numeric;



ALTER TABLE kenya\_mobile\_money\_transactions

ALTER COLUMN amount\_kes TYPE NUMERIC(12,2)

USING amount\_kes::numeric;



ALTER TABLE kenya\_mobile\_money\_transactions

ALTER COLUMN balance\_after\_kes TYPE NUMERIC(12,2)

USING balance\_after\_kes::numeric;

\--1. Monthly revenue trend and month-over-month growth

\--Compute total fee revenue (transaction\_fee\_kes) per calendar month, then add a column showing the month-over-month % change.

\-- Which month grew fastest? (Skills: time bucketing, LAG() / .pct\_change().



WITH monthly AS (

&#x20;   SELECT

&#x20;       DATE\_TRUNC('month', transaction\_timestamp)::date AS month,

&#x20;       SUM(transaction\_fee\_kes)                         AS fee\_revenue

&#x20;   FROM kenya\_mobile\_money\_transactions

&#x20;   WHERE status = 'Completed'          

&#x20;   GROUP BY 1

),

growth AS (

&#x20;   SELECT

&#x20;       month,

&#x20;       fee\_revenue,

&#x20;       LAG(fee\_revenue) OVER (ORDER BY month) AS prev\_revenue,

&#x20;       ROUND(

&#x20;           100.0 \* (fee\_revenue - LAG(fee\_revenue) OVER (ORDER BY month))

&#x20;           / NULLIF(LAG(fee\_revenue) OVER (ORDER BY month), 0),

&#x20;           2

&#x20;       ) AS mom\_pct\_change

&#x20;   FROM monthly

)

SELECT \*

FROM growth

ORDER BY month;



\--2. Peak transaction hours (heatmap-ready)

\--Build a day-of-week × hour-of-day matrix of transaction counts. Identify the single busiest hour block. 

\--(Skills: extracting hour \& weekday from a timestamp, pivoting.)



WITH t AS (

&#x20;   SELECT transaction\_timestamp AS ts

&#x20;   FROM kenya\_mobile\_money\_transactions

)

SELECT

&#x20;   TO\_CHAR(ts, 'Dy') AS weekday,

&#x20;   COUNT(\*) FILTER (WHERE EXTRACT(HOUR FROM ts) = 0)  AS h00,

&#x20;   COUNT(\*) FILTER (WHERE EXTRACT(HOUR FROM ts) = 1)  AS h01,

&#x20;   COUNT(\*) FILTER (WHERE EXTRACT(HOUR FROM ts) = 2)  AS h02,

&#x20;   COUNT(\*) FILTER (WHERE EXTRACT(HOUR FROM ts) = 3)  AS h03,

&#x20;   COUNT(\*) FILTER (WHERE EXTRACT(HOUR FROM ts) = 4)  AS h04,

&#x20;   COUNT(\*) FILTER (WHERE EXTRACT(HOUR FROM ts) = 5)  AS h05,

&#x20;   COUNT(\*) FILTER (WHERE EXTRACT(HOUR FROM ts) = 6)  AS h06,

&#x20;   COUNT(\*) FILTER (WHERE EXTRACT(HOUR FROM ts) = 7)  AS h07,

&#x20;   COUNT(\*) FILTER (WHERE EXTRACT(HOUR FROM ts) = 8)  AS h08,

&#x20;   COUNT(\*) FILTER (WHERE EXTRACT(HOUR FROM ts) = 9)  AS h09,

&#x20;   COUNT(\*) FILTER (WHERE EXTRACT(HOUR FROM ts) = 10) AS h10,

&#x20;   COUNT(\*) FILTER (WHERE EXTRACT(HOUR FROM ts) = 11) AS h11,

&#x20;   COUNT(\*) FILTER (WHERE EXTRACT(HOUR FROM ts) = 12) AS h12,

&#x20;   COUNT(\*) FILTER (WHERE EXTRACT(HOUR FROM ts) = 13) AS h13,

&#x20;   COUNT(\*) FILTER (WHERE EXTRACT(HOUR FROM ts) = 14) AS h14,

&#x20;   COUNT(\*) FILTER (WHERE EXTRACT(HOUR FROM ts) = 15) AS h15,

&#x20;   COUNT(\*) FILTER (WHERE EXTRACT(HOUR FROM ts) = 16) AS h16,

&#x20;   COUNT(\*) FILTER (WHERE EXTRACT(HOUR FROM ts) = 17) AS h17,

&#x20;   COUNT(\*) FILTER (WHERE EXTRACT(HOUR FROM ts) = 18) AS h18,

&#x20;   COUNT(\*) FILTER (WHERE EXTRACT(HOUR FROM ts) = 19) AS h19,

&#x20;   COUNT(\*) FILTER (WHERE EXTRACT(HOUR FROM ts) = 20) AS h20,

&#x20;   COUNT(\*) FILTER (WHERE EXTRACT(HOUR FROM ts) = 21) AS h21,

&#x20;   COUNT(\*) FILTER (WHERE EXTRACT(HOUR FROM ts) = 22) AS h22,

&#x20;   COUNT(\*) FILTER (WHERE EXTRACT(HOUR FROM ts) = 23) AS h23

FROM t

GROUP BY EXTRACT(ISODOW FROM ts), TO\_CHAR(ts, 'Dy')

ORDER BY EXTRACT(ISODOW FROM ts);



WITH t AS (

&#x20;   SELECT transaction\_timestamp AS ts

&#x20;   FROM kenya\_mobile\_money\_transactions

)

SELECT

&#x20;   TRIM(TO\_CHAR(ts, 'Day'))   AS weekday,

&#x20;   EXTRACT(HOUR FROM ts)::int AS hour\_of\_day,

&#x20;   COUNT(\*)                   AS txn\_count

FROM t

GROUP BY EXTRACT(ISODOW FROM ts), TRIM(TO\_CHAR(ts, 'Day')), EXTRACT(HOUR FROM ts)

ORDER BY txn\_count DESC

LIMIT 1;





\--3. Top customers by value, ranked within their county

\--For each county, rank customers by total amount transacted and return the top 3 per county.

\--(Skills: RANK() / ROW\_NUMBER() partitioned by county, or groupby().rank().)







SELECT status, COUNT(\*)

FROM kenya\_mobile\_money\_transactions

GROUP BY status;



WITH customer\_totals AS (

&#x20;   SELECT

&#x20;       county,

&#x20;       customer\_id,

&#x20;       MAX(customer\_name)       AS customer\_name,

&#x20;       COUNT(\*)                 AS txn\_count,

&#x20;       SUM(amount\_kes)::numeric AS total\_amount\_kes

&#x20;   FROM kenya\_mobile\_money\_transactions

&#x20;   GROUP BY county, customer\_id

),

ranked AS (

&#x20;   SELECT

&#x20;       \*,

&#x20;       ROW\_NUMBER() OVER (PARTITION BY county ORDER BY total\_amount\_kes DESC) AS rank\_in\_county

&#x20;   FROM customer\_totals

)

SELECT county, rank\_in\_county, customer\_id, customer\_name, txn\_count,

&#x20;      ROUND(total\_amount\_kes, 2) AS total\_amount\_kes

FROM ranked

WHERE rank\_in\_county <= 3

ORDER BY county, rank\_in\_county;



SELECT customer\_id, COUNT(county)

FROM kenya\_mobile\_money\_transactions

GROUP BY customer\_id

HAVING COUNT(county) > 1

LIMIT 10;





\--4. 7-day rolling transaction volume

\--Create a daily transaction-count series, then compute the 7-day rolling average of daily volume.

\--On how many days did volume exceed 1.5× its rolling average? 

\--(Skills: resampling to daily, rolling windows.)





WITH daily AS (

&#x20;   -- one row per calendar day, including days with zero transactions

&#x20;   SELECT

&#x20;       d::date AS day,

&#x20;       COALESCE(c.txn\_count, 0) AS txn\_count

&#x20;   FROM generate\_series(

&#x20;           (SELECT MIN(transaction\_timestamp)::date FROM kenya\_mobile\_money\_transactions),

&#x20;           (SELECT MAX(transaction\_timestamp)::date FROM kenya\_mobile\_money\_transactions),

&#x20;           INTERVAL '1 day'

&#x20;        ) AS d

&#x20;   LEFT JOIN (

&#x20;       SELECT transaction\_timestamp::date AS day, COUNT(\*) AS txn\_count

&#x20;       FROM kenya\_mobile\_money\_transactions

&#x20;       GROUP BY 1

&#x20;   ) c ON c.day = d::date

),

rolling AS (

&#x20;   SELECT

&#x20;       day,

&#x20;       txn\_count,

&#x20;       AVG(txn\_count) OVER (ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS rolling\_avg\_7d,

&#x20;       ROW\_NUMBER() OVER (ORDER BY day) AS day\_num

&#x20;   FROM daily

)

SELECT

&#x20;   day,

&#x20;   txn\_count,

&#x20;   ROUND(rolling\_avg\_7d::numeric, 2)       AS rolling\_avg\_7d,

&#x20;   ROUND((1.5 \* rolling\_avg\_7d)::numeric, 2) AS threshold\_1\_5x,

&#x20;   txn\_count > 1.5 \* rolling\_avg\_7d        AS is\_spike

FROM rolling

WHERE day\_num >= 7          

ORDER BY day;



\--5. Customer RFM segmentation

\--For every customer compute Recency (days since last transaction, relative to the dataset's max date),

\--Frequency (number of transactions), and Monetary (total amount). Score each into quintiles (1–5) and label the top segment as "Champions". 

\--(Skills: multi-metric aggregation, quantile bucketing, NTILE().)



WITH rfm\_base AS (

&#x20;   SELECT

&#x20;       customer\_id,

&#x20;       MAX(customer\_name)                         AS customer\_name,

&#x20;       MAX(transaction\_timestamp)::date           AS last\_txn\_date,

&#x20;       COUNT(\*)                                   AS frequency,

&#x20;       SUM(amount\_kes)::numeric                   AS monetary

&#x20;   FROM kenya\_mobile\_money\_transactions

&#x20;   GROUP BY customer\_id

),

with\_recency AS (

&#x20;   SELECT

&#x20;       \*,

&#x20;       (SELECT MAX(transaction\_timestamp)::date FROM kenya\_mobile\_money\_transactions)

&#x20;           - last\_txn\_date                        AS recency\_days

&#x20;   FROM rfm\_base

),

scored AS (

&#x20;   SELECT

&#x20;       \*,

&#x20;       NTILE(5) OVER (ORDER BY recency\_days DESC, customer\_id) AS r\_score,  

&#x20;       NTILE(5) OVER (ORDER BY frequency ASC,    customer\_id)  AS f\_score,  

&#x20;       NTILE(5) OVER (ORDER BY monetary ASC,     customer\_id)  AS m\_score   

&#x20;   FROM with\_recency

)

SELECT

&#x20;   customer\_id,

&#x20;   customer\_name,

&#x20;   recency\_days,

&#x20;   frequency,

&#x20;   ROUND(monetary, 2) AS monetary,

&#x20;   r\_score, f\_score, m\_score,

&#x20;   CONCAT(r\_score, f\_score, m\_score) AS rfm\_code,

&#x20;   CASE

&#x20;       WHEN r\_score = 5 AND f\_score = 5 AND m\_score = 5 THEN 'Champions'

&#x20;       ELSE 'Other'

&#x20;   END AS segment

FROM scored

ORDER BY r\_score DESC, f\_score DESC, m\_score DESC;





\--6. Failure/reversal rate by channel and transaction type

\--Using all statuses, compute the percentage of transactions that are Failed or Reversed, broken down by channel × transaction\_type. 

\--Which combination is least reliable? (Skills: conditional aggregation, ratio over groups.)



SELECT status, COUNT(\*)

FROM kenya\_mobile\_money\_transactions

GROUP BY status

ORDER BY 2 DESC;



SELECT

&#x20;   channel,

&#x20;   transaction\_type,

&#x20;   COUNT(\*)                                                                       AS total\_txns,

&#x20;   COUNT(\*) FILTER (WHERE LOWER(TRIM(status)) IN ('failed', 'reversed'))          AS bad\_txns,

&#x20;   COUNT(\*) FILTER (WHERE LOWER(TRIM(status)) = 'failed')                         AS failed\_txns,

&#x20;   COUNT(\*) FILTER (WHERE LOWER(TRIM(status)) = 'reversed')                       AS reversed\_txns,

&#x20;   ROUND(100.0 \* COUNT(\*) FILTER (WHERE LOWER(TRIM(status)) IN ('failed', 'reversed'))

&#x20;         / COUNT(\*), 2)                                                           AS failure\_reversal\_pct

FROM kenya\_mobile\_money\_transactions

GROUP BY channel, transaction\_type

ORDER BY failure\_reversal\_pct DESC;



\--7. Fee efficiency by transaction band

\--Bucket transactions into amount bands (0–500, 501–1,000, 1,001–5,000, 5,001–20,000, 20,000+) 

\--and compute the average effective fee rate (fee / amount) per band. 

\--Does the fee structure favour large or small transactions? (Skills: CASE / pd.cut, ratio metrics.)



WITH banded AS (

&#x20;   SELECT

&#x20;       CASE

&#x20;           WHEN amount\_kes <= 500    THEN 1

&#x20;           WHEN amount\_kes <= 1000   THEN 2

&#x20;           WHEN amount\_kes <= 5000   THEN 3

&#x20;           WHEN amount\_kes <= 20000  THEN 4

&#x20;           ELSE 5

&#x20;       END AS band\_order,

&#x20;       CASE

&#x20;           WHEN amount\_kes <= 500    THEN '0-500'

&#x20;           WHEN amount\_kes <= 1000   THEN '501-1,000'

&#x20;           WHEN amount\_kes <= 5000   THEN '1,001-5,000'

&#x20;           WHEN amount\_kes <= 20000  THEN '5,001-20,000'

&#x20;           ELSE '20,000+'

&#x20;       END AS amount\_band,

&#x20;       amount\_kes,

&#x20;       transaction\_fee\_kes

&#x20;   FROM kenya\_mobile\_money\_transactions

&#x20;   WHERE amount\_kes > 0

)

SELECT

&#x20;   amount\_band,

&#x20;   COUNT(\*)                                                         AS txn\_count,

&#x20;   ROUND(AVG(transaction\_fee\_kes / amount\_kes)::numeric \* 100, 3)   AS avg\_fee\_rate\_pct,

&#x20;   ROUND((SUM(transaction\_fee\_kes) / SUM(amount\_kes))::numeric \* 100, 3) AS weighted\_fee\_rate\_pct,

&#x20;   ROUND(AVG(transaction\_fee\_kes)::numeric, 2)                      AS avg\_fee\_kes

FROM banded

GROUP BY band\_order, amount\_band

ORDER BY band\_order;



\--8. Customer inter-transaction gap

\--For each customer, order their transactions by time and compute the average number of days between consecutive transactions.

\--List the 10 most active (smallest average gap) customers.

\--(Skills: LAG() over a partition ordered by time, or groupby().diff().)





WITH gaps AS (

&#x20;   SELECT

&#x20;       customer\_id,

&#x20;       customer\_name,

&#x20;       transaction\_timestamp,

&#x20;       EXTRACT(EPOCH FROM (

&#x20;           transaction\_timestamp

&#x20;           - LAG(transaction\_timestamp) OVER (PARTITION BY customer\_id ORDER BY transaction\_timestamp)

&#x20;       )) / 86400.0 AS gap\_days

&#x20;   FROM kenya\_mobile\_money\_transactions

),

per\_customer AS (

&#x20;   SELECT

&#x20;       customer\_id,

&#x20;       MAX(customer\_name)             AS customer\_name,

&#x20;       COUNT(\*)                       AS txn\_count,

&#x20;       AVG(gap\_days)::numeric         AS avg\_gap\_days

&#x20;   FROM gaps

&#x20;   GROUP BY customer\_id

&#x20;   HAVING COUNT(gap\_days) >= 1        -- need at least 2 transactions to have a gap

)

SELECT

&#x20;   customer\_id,

&#x20;   customer\_name,

&#x20;   txn\_count,

&#x20;   ROUND(avg\_gap\_days, 2) AS avg\_gap\_days

FROM per\_customer

ORDER BY avg\_gap\_days ASC, txn\_count DESC

LIMIT 10;



\--9.Monthly new vs returning customers (cohorts)

\--Assign each customer to the month of their first transaction (their cohort). 

\--For each subsequent month, count how many customers are transacting for the first time ("new") vs already seen ("returning").

\--(Skills: first-seen per group, cohort assignment, self-comparison across periods.)



WITH first\_seen AS (

&#x20;   SELECT

&#x20;       customer\_id,

&#x20;       DATE\_TRUNC('month', MIN(transaction\_timestamp))::date AS cohort\_month

&#x20;   FROM kenya\_mobile\_money\_transactions

&#x20;   GROUP BY customer\_id

),

monthly\_active AS (

&#x20;   -- one row per customer per month they transacted in

&#x20;   SELECT DISTINCT

&#x20;       customer\_id,

&#x20;       DATE\_TRUNC('month', transaction\_timestamp)::date AS active\_month

&#x20;   FROM kenya\_mobile\_money\_transactions

)

SELECT

&#x20;   m.active\_month                                              AS month,

&#x20;   COUNT(\*) FILTER (WHERE m.active\_month = f.cohort\_month)     AS new\_customers,

&#x20;   COUNT(\*) FILTER (WHERE m.active\_month > f.cohort\_month)     AS returning\_customers,

&#x20;   COUNT(\*)                                                    AS total\_active,

&#x20;   ROUND(100.0 \* COUNT(\*) FILTER (WHERE m.active\_month > f.cohort\_month)

&#x20;         / COUNT(\*), 2)                                        AS returning\_pct

FROM monthly\_active m

JOIN first\_seen f USING (customer\_id)

GROUP BY m.active\_month

ORDER BY m.active\_month;



WITH first\_seen AS (

&#x20;   SELECT customer\_id,

&#x20;          DATE\_TRUNC('month', MIN(transaction\_timestamp))::date AS cohort\_month

&#x20;   FROM kenya\_mobile\_money\_transactions

&#x20;   GROUP BY customer\_id

),

monthly\_active AS (

&#x20;   SELECT DISTINCT customer\_id,

&#x20;          DATE\_TRUNC('month', transaction\_timestamp)::date AS active\_month

&#x20;   FROM kenya\_mobile\_money\_transactions

)

SELECT

&#x20;   f.cohort\_month,

&#x20;   ((EXTRACT(YEAR FROM m.active\_month) - EXTRACT(YEAR FROM f.cohort\_month)) \* 12

&#x20;    + EXTRACT(MONTH FROM m.active\_month) - EXTRACT(MONTH FROM f.cohort\_month))::int AS months\_since\_first,

&#x20;   COUNT(\*) AS active\_customers

FROM monthly\_active m

JOIN first\_seen f USING (customer\_id)

GROUP BY 1, 2

ORDER BY 1, 2;



\--10. County revenue concentration (Pareto / 80-20)

\--Rank counties by total transaction value and compute the cumulative % of total value. 

\--How few counties account for 80% of all money moved? (Skills: ordered cumulative sums, window SUM() OVER (ORDER BY ...), Pareto analysis.)



WITH county\_totals AS (

&#x20;   SELECT

&#x20;       county,

&#x20;       SUM(amount\_kes)::numeric AS total\_value

&#x20;   FROM kenya\_mobile\_money\_transactions

&#x20;   WHERE county IS NOT NULL

&#x20;   GROUP BY county

),

cumulative AS (

&#x20;   SELECT

&#x20;       county,

&#x20;       total\_value,

&#x20;       RANK() OVER (ORDER BY total\_value DESC)                               AS county\_rank,

&#x20;       100.0 \* total\_value / SUM(total\_value) OVER ()                        AS pct\_of\_total,

&#x20;       100.0 \* SUM(total\_value) OVER (ORDER BY total\_value DESC, county)

&#x20;             / SUM(total\_value) OVER ()                                      AS cumulative\_pct

&#x20;   FROM county\_totals

)

SELECT

&#x20;   county\_rank,

&#x20;   county,

&#x20;   ROUND(total\_value, 2)    AS total\_value,

&#x20;   ROUND(pct\_of\_total, 2)   AS pct\_of\_total,

&#x20;   ROUND(cumulative\_pct, 2) AS cumulative\_pct,

&#x20;   cumulative\_pct <= 80     AS within\_80\_pct

FROM cumulative

ORDER BY county\_rank;



SELECT

&#x20;   COUNT(\*) AS counties\_for\_80pct,

&#x20;   (SELECT COUNT(\*) FROM county\_totals) AS total\_counties

FROM cumulative

WHERE cumulative\_pct - pct\_of\_total < 80;



WITH county\_totals AS (

&#x20;   SELECT

&#x20;       county,

&#x20;       SUM(amount\_kes)::numeric AS total\_value

&#x20;   FROM kenya\_mobile\_money\_transactions

&#x20;   WHERE county IS NOT NULL

&#x20;   GROUP BY county

),

cumulative AS (

&#x20;   SELECT

&#x20;       county,

&#x20;       total\_value,

&#x20;       RANK() OVER (ORDER BY total\_value DESC)                          AS county\_rank,

&#x20;       100.0 \* total\_value / SUM(total\_value) OVER ()                   AS pct\_of\_total,

&#x20;       100.0 \* SUM(total\_value) OVER (ORDER BY total\_value DESC, county)

&#x20;             / SUM(total\_value) OVER ()                                 AS cumulative\_pct

&#x20;   FROM county\_totals

)

SELECT

&#x20;   county\_rank,

&#x20;   county,

&#x20;   ROUND(total\_value, 2)    AS total\_value,

&#x20;   ROUND(pct\_of\_total, 2)   AS pct\_of\_total,

&#x20;   ROUND(cumulative\_pct, 2) AS cumulative\_pct,

&#x20;   (cumulative\_pct - pct\_of\_total) < 80 AS needed\_for\_80pct

FROM cumulative

ORDER BY county\_rank;



