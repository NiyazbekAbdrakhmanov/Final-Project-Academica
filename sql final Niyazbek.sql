CREATE DATABASE Customers_transactions; 
use customers_transactions;
SET SQL_SAFE_UPDATES = 0;
update customers set Gender = NULL where Gender ='';
update customers set Age = null where Age ='';
alter table customers modify AGE INT NULL;


SELECT * FROM transactions;
SELECT * FROM customers;

CREATE TABLE Transactions (
    date_new DATE,
    Id_check INT,
    ID_client INT,
    Count_products DECIMAL(10,3),
    Sum_payment DECIMAL(10,2)
);

LOAD DATA INFILE "C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\transactions.csv"
INTO TABLE Transactions 
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

show variables like 'secure_file_priv';




#1 список клиентов с непрерывной историей за год
SELECT 
    ID_client,
    SUM(Sum_payment) / COUNT(DISTINCT Id_check) AS avg_check,
    SUM(Sum_payment) / 12 AS avg_monthly_payment,
    COUNT(Id_check) AS total_operations
FROM transactions
WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01'
GROUP BY ID_client
HAVING COUNT(DISTINCT DATE_FORMAT(date_new, '%Y-%m')) = 12;

#2 Информация в разрезе месяцев
WITH monthly_stats AS (
    SELECT 
        DATE_FORMAT(date_new, '%Y-%m') AS month_id,
        SUM(Sum_payment) AS month_sum,
        COUNT(Id_check) AS month_ops,
        COUNT(DISTINCT ID_client) AS month_clients,
        COUNT(DISTINCT Id_check) AS month_checks
    FROM transactions
    WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY month_id
)
SELECT 
    month_id,
    month_sum / month_checks AS avg_check_monthly, 
    month_ops / month_clients AS avg_ops_per_client, 
    month_clients,
    #Доля операций месяца от общего кол-ва за год
    month_ops / SUM(month_ops) OVER() AS ops_share_year,
    #Доля суммы месяца от общей суммы за год
    month_sum / SUM(month_sum) OVER() AS sum_share_year
FROM monthly_stats
ORDER BY month_id;


#3 Соотношение M/F/NA по месяцам и их затраты
SELECT 
    DATE_FORMAT(t.date_new, '%Y-%m') AS month_id,
    COUNT(CASE WHEN c.Gender = 'M' THEN 1 END) / COUNT(*) * 100 AS male_pct,
    COUNT(CASE WHEN c.Gender = 'F' THEN 1 END) / COUNT(*) * 100 AS female_pct,
    COUNT(CASE WHEN c.Gender IS NULL OR c.Gender = '' THEN 1 END) / COUNT(*) * 100 AS na_pct,
    SUM(CASE WHEN c.Gender = 'M' THEN t.Sum_payment ELSE 0 END) / SUM(t.Sum_payment) AS male_spending_share,
    SUM(CASE WHEN c.Gender = 'F' THEN t.Sum_payment ELSE 0 END) / SUM(t.Sum_payment) AS female_spending_share,
    SUM(CASE WHEN c.Gender IS NULL OR c.Gender = '' THEN t.Sum_payment ELSE 0 END) / SUM(t.Sum_payment) AS na_spending_share
FROM transactions t
LEFT JOIN customers c ON t.ID_client = c.Id_client
WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01'
GROUP BY month_id
ORDER BY month_id;

#4 Возрастные группы 

#Сначала создала временную таблицу или CTE для удобства категорий
WITH age_categorized AS (
    SELECT 
        t.*,
        CASE 
            WHEN c.Age IS NULL THEN 'No Data'
            ELSE CONCAT(FLOOR(c.Age / 10) * 10, '-', FLOOR(c.Age / 10) * 10 + 9)
        END AS age_group,
        QUARTER(t.date_new) AS qtr,
        YEAR(t.date_new) AS yr
    FROM transactions t
    LEFT JOIN customers c ON t.ID_client = c.Id_client
    WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01'
)
SELECT 
    age_group,
    yr,
    qtr,
    SUM(Sum_payment) AS total_sum,
    COUNT(Id_check) AS total_ops,
    AVG(Sum_payment) AS avg_payment_qtr,
    SUM(Sum_payment) / (SELECT SUM(Sum_payment) FROM transactions WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01') * 100 AS pct_of_total_revenue
FROM age_categorized
GROUP BY age_group, yr, qtr
ORDER BY age_group, yr, qtr;


