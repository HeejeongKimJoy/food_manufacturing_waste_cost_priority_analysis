/*
Food Manufacturing Yield & Downtime Analysis

Data Cleaning and Validation Process

Purpose:
Prepare manufacturing operational datasets for yield, waste, and downtime performance analysis.
*/

-- ============================================================================================================================================
-- ============================================================================================================================================
--  Part 1. Production_log table 
-- Creating a staging table of Production_log to preserve raw data integrity
-- ============================================================================================================================================
-- ============================================================================================================================================
CREATE TABLE production_log_staging AS
SELECT *
FROM production_log_raw;

SELECT *
FROM production_log_staging;

-- ============================================================================================================================================
-- Standardise production dates to support accurate operational reporting
-- ============================================================================================================================================

-- Identify inconsistent date formats before conversion
SELECT Production_date, STR_TO_DATE(production_date, '%d/%m/%Y')
FROM production_log_staging
WHERE STR_TO_DATE(production_date, '%d/%m/%Y') IS NULL;
-- Result: Identified 20 rows using 'DD-MM-YYYY' format

-- Replace '-' with '/' to standardise date formatting
UPDATE production_log_staging
SET Production_date = REPLACE(Production_date, '-', '/')
WHERE Production_date LIKE '%-%';

-- Convert 'DD/MM/YYYY' date values into SQL DATE format 'YYYY-MM-DD'
UPDATE production_log_staging
SET Production_date = STR_TO_DATE(Production_date, '%d/%m/%Y');

-- Modify column datatype to DATE
ALTER TABLE production_log_staging
MODIFY COLUMN Production_date DATE;

-- Validate that all production dates were successfully converted into DATE format
SELECT *
FROM production_log_staging
WHERE Production_date IS NULL;
-- Result: All production dates were successfully converted without NULL values

-- ============================================================================================================================================
-- Review operational data quality prior to production performance analysis
-- ============================================================================================================================================

-- [Batch_id] Validate Batch_id consistency used for table relationships

-- Standardise Batch_id values by removing unnecessary spaces
UPDATE production_log_staging
SET Batch_id = TRIM(Batch_id);

-- Validate Batch_id length consistency
SELECT Batch_id
FROM production_log_staging
WHERE LENGTH(Batch_id) != 6;
-- Result: All Batch_id values meet the expected length requirement

-- Missing values or 0 finding 
SELECT batch_id
FROM production_log_staging
WHERE batch_id IS NULL 
	OR batch_id = ' ';
-- No issue found


-- [Production_line] Validate production line categories before analysis

-- Review distinct production line categories
SELECT DISTINCT production_line
FROM production_log_staging;
-- Result: 7 rows were returned including (missing value, line1, L1, Ln2, L3)

-- Identify missing production line values
SELECT *
FROM production_log_staging
WHERE Production_line IS NULL
   OR TRIM(Production_line) = '';
-- Result: 25 rows were returned with missing values

-- Create a staging table for product master data to support production line validation
CREATE TABLE products_staging AS
SELECT *
FROM products_raw;

-- Preview replacement values for missing Production_line records
SELECT *, p2.Production_line AS replacement_line
FROM production_log_staging AS p1
JOIN products_staging AS p2
    ON p1.Product_ID = p2.Product_ID
WHERE p1.Production_line IS NULL
   OR TRIM(p1.Production_line) = '';

-- Restore missing Production_line values using 'product' table for reference data
UPDATE production_log_staging AS p1
JOIN products_staging AS p2
	ON p1.product_id = p2.product_id
SET p1.production_line = p2.production_line
WHERE p1.production_line IS NULL
   OR TRIM(p1.production_line) = '';

-- Preview standardised Production_line labels
SELECT production_line AS original_line,
CASE
	WHEN UPPER(TRIM(production_line)) IN ('LINE 1','LINE1', 'L1') THEN 'Line 1'
	WHEN UPPER(TRIM(production_line)) IN ('LINE 2', 'LN2') THEN 'Line 2'
	WHEN UPPER(TRIM(production_line)) IN ('LINE 3', 'L3') THEN 'Line 3'
	ELSE Production_line
END AS replacement 
FROM production_log_staging;

-- Standardise Production_line labels
UPDATE production_log_staging
SET production_line = CASE
	WHEN UPPER(TRIM(production_line)) IN ('LINE 1','LINE1', 'L1') THEN 'Line 1'
	WHEN UPPER(TRIM(production_line)) IN ('LINE 2', 'LN2') THEN 'Line 2'
	WHEN UPPER(TRIM(production_line)) IN ('LINE 3', 'L3') THEN 'Line 3'
	ELSE Production_line
END;

-- Validate Production_line values after cleaning
SELECT DISTINCT production_line
FROM production_log_staging;


-- [Shift] Validate shift categories for operational reporting consistency

-- Reviwq missing or 0 values
SELECT shift
FROM production_log_staging
WHERE shift IS NULL 
	OR shift = ' ';

-- Review distinct shift categories
SELECT DISTINCT shift
FROM production_log_staging;
-- Result: Inconsistent shift labels were identified, including 'A S', and 'N S'

-- Preview standardised shift labels
SELECT DISTINCT shift AS original,
UPPER(REPLACE(TRIM(shift),' ','')) AS replacement
FROM production_log_staging;

-- Standardise shift categories for operational reporting consistency
UPDATE production_log_staging
SET shift = UPPER(REPLACE(TRIM(shift),' ',''));

-- Validate shift values after cleaning
SELECT DISTINCT Shift
FROM production_log_staging;
-- Result: All shift labels were successfully standardised into DS, AS, and NS


-- [Planned_output_kg] Validate planned production quantity

-- Validate planned production quantities before yield analysis
SELECT *
FROM production_log_staging
WHERE Planned_output_kg IS NULL
   OR Planned_output_kg <= 0;
-- Result: No invalid planned output values identified

-- ============================================================================================================================================
-- Identify duplicate production records that may distort operational KPI analysis
-- ============================================================================================================================================

-- Create CTE to find duplicates
WITH cte_staging2 AS
(
SELECT*,
ROW_NUMBER () OVER (
PARTITION BY Batch_id, Production_date) AS row_num
FROM production_log_staging
)
SELECT *
FROM cte_staging2
WHERE row_num > 1;
-- Result: 3 rows were identified including '1193CZ', '4074TS', '4955LF'

-- Review the duplicates to validate that it is actual duplicates
SELECT *
FROM production_log_staging
WHERE batch_id = '1193CZ';

SELECT *
FROM production_log_staging
WHERE batch_id = '4074TS';

SELECT *
FROM production_log_staging
WHERE batch_id = '4955LF';
-- All of the values have been identified that they are actual duplicates

-- Create a new staging table to preserve data
CREATE TABLE `production_log_staging2` (
  `Batch_id` text,
  `Production_date` date DEFAULT NULL,
  `Product_ID` int DEFAULT NULL,
  `Production_line` text,
  `Shift` text,
  `Planned_output_kg` double DEFAULT NULL,
  `Actual_output_kg` double DEFAULT NULL,
  `Waste_kg` double DEFAULT NULL,
  `Operation_minutes` int DEFAULT NULL,
  `row_num` INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO production_log_staging2
SELECT *,
ROW_NUMBER () OVER (
PARTITION BY Batch_id) AS row_num
FROM production_log_staging;

-- Review duplicates in a new staging table
SELECT *
FROM production_log_staging2
WHERE row_num > 1;

-- Delete duplicates
DELETE
FROM production_log_staging2
WHERE row_num > 1;

-- Remove support column after duplicate removal
ALTER TABLE production_log_staging2
DROP COLUMN row_num;



-- ============================================================================================================================================
-- ============================================================================================================================================
-- Part 2. Downtime_log table 
-- Creating a staging table of Production_log to preserve raw data integrity
-- ============================================================================================================================================
-- ============================================================================================================================================
CREATE TABLE downtime_log_staging AS
SELECT *
FROM downtime_log_raw;

SELECT *
FROM downtime_log_staging;

-- ============================================================================================================================================
-- Review operational data quality prior to production performance analysis
-- ============================================================================================================================================

-- [Downtime_id] Validate downtime event identifiers

-- Standardise Downtime_id values by removing unnecessary spaces
UPDATE downtime_log_staging
SET Downtime_id = TRIM(Downtime_id);

-- Validate Downtime_id length consistency
SELECT Downtime_id
FROM downtime_log_staging
WHERE LENGTH(Downtime_id) != 5;
-- Result: All Downtime_id values meet the expected length requirement


-- [Batch_id] Validate production batch references used to link downtime events

UPDATE downtime_log_staging
SET Batch_id = TRIM(Batch_id);

SELECT Batch_id
FROM downtime_log_staging
WHERE LENGTH(Batch_id) != 6;
-- Result: All Batch_id values meet the expected length requirement

-- Validate that all downtime records are linked to valid production batches
SELECT d.Batch_id
FROM downtime_log_staging AS d
LEFT JOIN production_log_staging2 AS p
    ON d.Batch_id = p.Batch_id
WHERE p.Batch_id IS NULL;
-- Result: All downtime records are linked to valid production batches


-- [Downtime_minutes] Validate downtime values

-- Identify invalid values before downtime impact analysis
SELECT *
FROM downtime_log_staging
WHERE Downtime_minutes IS NULL
   OR Downtime_minutes <= 0;
-- Result: No invalid values identified


-- [Severity] Validate downtime severity categories

-- Review distinct severity values
SELECT DISTINCT Severity
FROM downtime_log_staging;
-- Result: Inconsistent severity values were identified, including H, M, l.

-- Preview standardised severity values
SELECT Severity AS original,
CASE 
	WHEN UPPER(TRIM(Severity)) IN ('HIGH', 'H') THEN 'High'
    WHEN UPPER(TRIM(Severity)) IN ('MEDIUM', 'M') THEN 'Medium'
	WHEN UPPER(TRIM(Severity)) IN ('LOW', 'L') THEN 'Low'
	ELSE Severity
END AS replacement
FROM downtime_log_staging;

-- Standardise severity values for downtime impact analysis
UPDATE downtime_log_staging
SET Severity = CASE
	WHEN UPPER(TRIM(Severity)) IN ('HIGH', 'H') THEN 'High'
    WHEN UPPER(TRIM(Severity)) IN ('MEDIUM', 'M') THEN 'Medium'
	WHEN UPPER(TRIM(Severity)) IN ('LOW', 'L') THEN 'Low'
	ELSE Severity
END;

-- Validate severity values after cleaning
SELECT DISTINCT Severity
FROM downtime_log_staging;
-- Result: All severity values were standardised into High, Medium, and Low


-- [Reason] Validate downtime reason categories

-- Review distinct downtime reasons
SELECT DISTINCT Reason
FROM downtime_log_staging;
-- Result: Minor spelling inconsistencies were identified 

-- Standardise downtime reason labels for consistent root cause analysis
UPDATE downtime_log_staging
SET Reason = TRIM(Reason);

UPDATE downtime_log_staging
SET Reason = 'Machine Jam'
WHERE Reason LIKE 'Machine %Jam%';
	
UPDATE downtime_log_staging
SET Reason = 'Cleaning'
WHERE Reason LIKE 'Cleaningg';

UPDATE downtime_log_staging
SET Reason = 'Maintenance'
WHERE Reason = 'Maintenence';

UPDATE downtime_log_staging
SET Reason = 'Packaging Issue'
WHERE Reason = 'Packagin Issue';

-- Validate downtime reason values after cleaning
SELECT DISTINCT Reason
FROM downtime_log_staging;

-- ============================================================================================================================================
-- Identify duplicate downtime records that may distort downtime analysis
-- ============================================================================================================================================
WITH cte_down AS 
(
SELECT *,
ROW_NUMBER() OVER(
PARTITION BY Downtime_id, Batch_id, Downtime_minutes, Severity, Reason) AS row_num
FROM downtime_log_staging
)
SELECT *
FROM cte_down
WHERE row_num > 1;
-- Result: No duplicate downtime records were identified



-- ============================================================================================================================================
-- ============================================================================================================================================
-- Part 3. Products table 
-- Review operational data quality prior to production performance analysis
-- ============================================================================================================================================
-- ============================================================================================================================================

-- The staging table has already been created for identifing missing production line values in Part 1

-- [Product_ID]
SELECT DISTINCT Product_ID
FROM products_staging;
-- Result: 20 unique products were identified


-- [Product_name]
UPDATE products_staging
SET product_name = TRIM(Product_name);

SELECT DISTINCT Product_name
FROM products_staging;
-- Result: 20 unique products were identified


-- [Category]
SELECT DISTINCT Category
FROM products_staging;
-- Result: No invalid planned output values identified


-- [Production_line]
SELECT DISTINCT Production_line
FROM products_staging;
-- Result: No invalid planned output values identified


-- [Unit_cost_per_kg] & [Target_yield_pct]
-- Review missing values or invaild values 
SELECT *
FROM products_staging
WHERE Unit_cost_per_kg = ' '
	OR Unit_cost_per_kg IS NULL;

SELECT *
FROM products_staging
WHERE Target_yield_pct = ' '
	OR Target_yield_pct IS NULL;
-- Result: No missing or invalid values were identified