USE [FictionalSalesDatabase]
GO

-- Link to original data source: https://www.kaggle.com/datasets/teluskiman/fictional-sales-data

-- Data cleaning I perform before loading the csv files into database:
-- Clean data of customer_dim.csv because the address field contains several commas in each cell. 
-- By using TEXTSPLIT function, I split it into 4 new columns : 
-- a. address
-- b. city
-- c. state
-- d. zip

-- Metadata
SELECT 
	CASE 
		WHEN object_id = OBJECT_ID('FactSalesTransactions')
			THEN 'FactSalesTransactions'
		WHEN object_id = OBJECT_ID('DimProduct')
			THEN 'DimProduct'
		ELSE 'DimCustomer'
	END AS table_name,
	c.name AS column_name,
	t.name AS data_type,
	c.max_length AS max_length
FROM sys.columns c
JOIN sys.types t ON c.user_type_id = t.user_type_id
WHERE object_id IN ( OBJECT_ID('FactSalesTransactions'), OBJECT_ID('DimProduct'), OBJECT_ID('DimCustomer') )
ORDER BY table_name;

-- Fix data type of columns
ALTER TABLE DimCustomer ALTER COLUMN cust_age INT;
ALTER TABLE DimCustomer ALTER COLUMN effective_start_date DATE;
ALTER TABLE DimCustomer ALTER COLUMN effective_end_date DATE;
ALTER TABLE DimProduct ALTER COLUMN product_price FLOAT;
ALTER TABLE DimProduct ALTER COLUMN effective_start_date DATE;
ALTER TABLE DimProduct ALTER COLUMN effective_end_date DATE;
ALTER TABLE FactSalesTransactions ALTER COLUMN product_quantity INT;
ALTER TABLE FactSalesTransactions ALTER COLUMN order_date DATE;

-- Exclude rows with order date after or before 2019
DELETE FROM FactSalesTransactions WHERE YEAR(order_date) != 2019;

-- Get distinct count of transactions made
SELECT COUNT(DISTINCT [order_id]) AS [Transaction Count]
FROM [FictionalSalesDatabase].[dbo].[FactSalesTransactions]; --> There are 178,406 records with unique order ID

-- Descriptive Stats of Sales
WITH cte_price AS
(
	SELECT 
		YEAR([order_date]) AS [year],
		[order_date],
		[order_id],
		[product_quantity] * [product_price] AS [Total Price]
	FROM [FictionalSalesDatabase].[dbo].[FactSalesTransactions] [sales]
	LEFT JOIN [FictionalSalesDatabase].[dbo].[DimProduct] [prod]
		ON [sales].[product_id] = [prod].[product_id]
		AND [sales].[order_date] BETWEEN [effective_start_date] AND [effective_end_date]
	WHERE YEAR([order_date]) = 2019
), 
-- Median
cte_median AS
( 
	SELECT
		(SELECT DISTINCT [year] FROM [cte_price]) AS [Year], 
		(
			(	
				SELECT MAX([Total Price])
				FROM 
				(
					SELECT TOP 50 PERCENT [Total Price]
					FROM [cte_price]
					ORDER BY 1
				) a
			)
			+
			(
				SELECT MIN([Total Price])
				FROM
				(
					SELECT TOP 50 PERCENT [Total Price]
					FROM [cte_price]
					ORDER BY 1 DESC
				) a
			)
		) / 2 AS [Median]  --> The median value of single transactions is USD 16.99
),
cte_stats AS 
(
	SELECT 
		YEAR([order_date]) AS [Year],
		[order_id],
		[product_quantity] * [product_price] AS [Total Price]
	FROM [FictionalSalesDatabase].[dbo].[FactSalesTransactions] [sales]
	LEFT JOIN [FictionalSalesDatabase].[dbo].[DimProduct] [prod]
		ON [sales].[product_id] = [prod].[product_id]
		AND [sales].[order_date] BETWEEN [effective_start_date] AND [effective_end_date]
	WHERE YEAR([order_date]) = 2019
)

SELECT 
	a.Year,
	MIN([Total Price]) AS 'Min Sales (in USD)',
	MAX([Median]) AS 'Median (in USD)',
	AVG([Total Price]) AS 'Avg Sales (in USD)',
	MAX([Total Price]) AS 'Max Sales (in USD)',
	MAX([Total Price]) - MIN([Total Price]) AS 'Range'
FROM cte_stats a
JOIN cte_median b ON a.Year = b.Year
GROUP BY a.Year;

-- Total Sales in 2019
SELECT 
	YEAR([order_date]) AS [Year], 
	SUM(product_quantity * product_price) AS [Total Sales (in USD)]
FROM [FictionalSalesDatabase].[dbo].[FactSalesTransactions] [sales]
LEFT JOIN [FictionalSalesDatabase].[dbo].[DimProduct] [prod]
	ON [sales].[product_id] = [prod].[product_id]
	AND [sales].[order_date] BETWEEN [effective_start_date] AND [effective_end_date]
GROUP BY YEAR([order_date]); --> There is a total of sales amount of USD 34,996,944.4699568

-- Total Qty Sold in 2019
SELECT 
	YEAR([order_date]) AS [Year], 
	SUM(product_quantity) AS [Total Quantity Sold (in pcs)]
FROM [FictionalSalesDatabase].[dbo].[FactSalesTransactions] [sales]
GROUP BY YEAR([order_date]); --> There is a total of quantity sold of 209,038 pcs

-- Monthly Sales & Qty Sold Trend
SELECT	
	YEAR([sales].[order_date]) AS [Year],
	MONTH([sales].[order_date]) AS [Month],
	SUM(product_quantity * product_price) AS [Total Sales (in USD)],
	SUM(product_quantity) AS [Total Quantity Sold (in pcs)]
FROM [FictionalSalesDatabase].[dbo].[FactSalesTransactions] [sales]
LEFT JOIN [FictionalSalesDatabase].[dbo].[DimProduct] [prod]
	ON [sales].[product_id] = [prod].[product_id]
	AND [sales].[order_date] BETWEEN [effective_start_date] AND [effective_end_date]
GROUP BY YEAR([sales].[order_date]), MONTH([sales].[order_date])
ORDER BY 2;

-- Daily Sales & Qty Sold Trend
SELECT
	[sales].[order_date] AS [Order Date],
	SUM(product_quantity * product_price) AS [Total Sales (in USD)],
	SUM(product_quantity) AS [Total Quantity Sold (in pcs)]
FROM [FictionalSalesDatabase].[dbo].[FactSalesTransactions] [sales]
LEFT JOIN [FictionalSalesDatabase].[dbo].[DimProduct] [prod]
	ON [sales].[product_id] = [prod].[product_id]
	AND [sales].[order_date] BETWEEN [effective_start_date] AND [effective_end_date]
GROUP BY [sales].[order_date]
ORDER BY 1;

-- Top 5 Daily Sales
SELECT TOP 5
	[sales].[order_date] AS [Order Date],
	SUM(product_quantity * product_price) AS [Total Sales (in USD)],
	SUM(product_quantity) AS [Total Quantity Sold (in pcs)]
FROM [FictionalSalesDatabase].[dbo].[FactSalesTransactions] [sales]
LEFT JOIN [FictionalSalesDatabase].[dbo].[DimProduct] [prod]
	ON [sales].[product_id] = [prod].[product_id]
	AND [sales].[order_date] BETWEEN [effective_start_date] AND [effective_end_date]
GROUP BY [sales].[order_date]
ORDER BY 2 DESC;

-- Distinct count of product
SELECT COUNT(DISTINCT product_id) AS [Product Count]
FROM [FictionalSalesDatabase].[dbo].[products]; -- There are 19 records of unique products being sold in the store

-- Top 5 Product by Qty
SELECT TOP 5
	[prod].[product_name],
	SUM(product_quantity * product_price) AS [Total Sales (in USD)],
	SUM(product_quantity) AS [Total Quantity Sold (in pcs)]
FROM [FictionalSalesDatabase].[dbo].[FactSalesTransactions] [sales]
LEFT JOIN [FictionalSalesDatabase].[dbo].[DimProduct] [prod]
	ON [sales].[product_id] = [prod].[product_id]
	AND [sales].[order_date] BETWEEN [effective_start_date] AND [effective_end_date]
GROUP BY [prod].[product_name]
ORDER BY 3 DESC;

-- Top 5 Product by Sales
SELECT TOP 5
	[prod].[product_name],
	SUM(product_quantity * product_price) AS [Total Sales (in USD)],
	SUM(product_quantity) AS [Total Quantity Sold (in pcs)]
FROM [FictionalSalesDatabase].[dbo].[FactSalesTransactions] [sales]
LEFT JOIN [FictionalSalesDatabase].[dbo].[DimProduct] [prod]
	ON [sales].[product_id] = [prod].[product_id]
	AND [sales].[order_date] BETWEEN [effective_start_date] AND [effective_end_date]
GROUP BY [prod].[product_name]
ORDER BY 2 DESC;

-- Distinct count of customer
SELECT COUNT(DISTINCT cust_id) AS 'Customer Count'
FROM [FictionalSalesDatabase].[dbo].[DimCustomer]; --> There are 140,787 records of unique customer

-- Distinct count of customer that made transactions
SELECT COUNT(DISTINCT cust_id) AS 'Customer with Transactions Count'
FROM [FictionalSalesDatabase].[dbo].[FactSalesTransactions]; --> There are 140,768 records of unique customer 

-- Top 5 Customers
SELECT TOP 5
	[cust].[cust_id],
	SUM([product_quantity] * [product_price]) AS 'Total Spending in 2019 (in USD)'
FROM [FictionalSalesDatabase].[dbo].[FactSalesTransactions] [sales]
RIGHT JOIN [FictionalSalesDatabase].[dbo].[DimCustomer] [cust] 
	ON [sales].[cust_id] = [cust].[cust_id]
LEFT JOIN [FictionalSalesDatabase].[dbo].[DimProduct] [prod]
	ON [sales].[product_id] = [prod].[product_id]
	AND [sales].[order_date] BETWEEN [prod].[effective_start_date] AND [prod].[effective_end_date]
GROUP BY [cust].[cust_id]
ORDER BY 2 DESC;

-- Customer Age Distribution
SELECT 
	[cust_age],
	COUNT([cust_id]) AS 'Frequency'
FROM [FictionalSalesDatabase].[dbo].[DimCustomer]
GROUP BY [cust_age]
ORDER BY 1;

-- Customer Age Stats

-- Customer Demographic (City) Distribution
SELECT 
	[cust_city],
	COUNT([cust_id]) AS 'Frequency'
FROM [FictionalSalesDatabase].[dbo].[DimCustomer]
GROUP BY [cust_city]
ORDER BY 2 DESC;

-- Top Spending by Customer City

-- Data Overview
SELECT TOP 10
    [order_date],
	  [sales].[cust_id],
	  [product_name],
    [product_quantity],
	  [prod].[product_price],
	  [cust].[cust_city]
FROM [FictionalSalesDatabase].[dbo].[FactSalesTransactions] [sales]
LEFT JOIN [FictionalSalesDatabase].[dbo].[DimProduct] [prod]
	ON [sales].[product_id] = [prod].[product_id]
	AND [sales].[order_date] BETWEEN [prod].[effective_start_date] AND [prod].[effective_end_date]
LEFT JOIN [FictionalSalesDatabase].[dbo].[DimCustomer] [cust] 
	ON [sales].[cust_id] = [cust].[cust_id]
ORDER BY [order_date];
