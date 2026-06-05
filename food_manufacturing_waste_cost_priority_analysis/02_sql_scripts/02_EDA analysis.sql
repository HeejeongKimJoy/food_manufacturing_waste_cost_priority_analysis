/*
Food Manufacturing Material Waste Exposure and Reduction Priority Analysis

Exploratory Data Analysis (EDA)

- Purpose:
Analyse estimated material waste exposure in food manufacturing production data
to identify where waste reduction review should be prioritised.
The analysis reviews product, production line, downtime status, downtime reason,
and monthly patterns as supporting context.

-- Project Scope:
This EDA reviews estimated material waste exposure in food manufacturing production data.
Estimated waste cost is calculated as waste_kg × unit_cost_per_kg.
The analysis identifies where waste reduction review should be prioritised.
It does not confirm root causes or actual improvement actions.
Actual improvement actions require waste reason or process level data, which is not available in the current dataset.
*/

/*
-- Exploratory Data Analysis Flow
-- 1 to 3: Review where material waste exposure is concentrated.
-- 4: Check whether downtime status explains waste exposure.
-- 5 to 7: Review product level reduction opportunity and saving scenarios.
-- 8 to 10: Use downtime reason and monthly trend as supporting operational context.
-- 11: Summarise final review priorities.
*/

-- =======================================================================
-- =======================================================================
-- EDA 1. Main Business Question: where material waste exposure is concentrated
-- =======================================================================
-- =======================================================================

-- ============================================================================================================================================
-- 1. Overall estimated material waste exposure
-- ============================================================================================================================================

-- This analysis provides an overview of production output, recorded waste quantity, waste to output rate, and estimated material waste cost.
-- Estimated material waste cost is calculated as waste_kg × unit_cost_per_kg.
-- This represents material waste exposure only and does not include other indirect operational costs.

SELECT 
ROUND(SUM(pr.actual_output_kg),2) AS total_output_kg, 
ROUND(SUM(pr.actual_output_kg*p.unit_cost_per_kg),2) AS total_estimated_output_value,
ROUND(SUM(pr.waste_kg),2) AS total_waste_kg,
ROUND(SUM(pr.waste_kg*p.unit_cost_per_kg),2) AS total_estimated_material_waste_cost,
ROUND(SUM(waste_kg) / SUM(actual_output_kg) * 100,2) AS waste_to_output_rate_pct
FROM production_log_staging2 AS pr
JOIN products_staging AS p
	ON pr.product_id = p.product_id;

-- Result:
-- The dataset recorded 36.7M kg of actual output and 3.0M kg of waste.
-- Waste was equivalent to 8.27% of actual output quantity.
-- Based on unit cost, this represented approximately 23.6M in estimated material waste cost.
-- The next analysis will review where this material waste is concentrated by product.

-- ============================================================================================================================================
-- 2. Product level waste exposure
-- ============================================================================================================================================

-- This analysis identifies which products are associated with higher estimated waste cost.
-- Batch count is included to check whether high total waste cost is mainly related to production volume.
-- Cost per batch and waste cost rate are included to compare product level waste exposure beyond total cost.

WITH product_waste AS
(
SELECT 
p.product_name,
COUNT(pr.batch_id) AS batch_count,
ROUND(SUM(pr.waste_kg*p.unit_cost_per_kg),2) AS total_estimated_waste_cost,
ROUND(SUM(pr.waste_kg*p.unit_cost_per_kg)/COUNT(pr.batch_id),2) AS estimated_waste_cost_per_batch,
ROUND(SUM(pr.waste_kg*p.unit_cost_per_kg)/SUM(pr.actual_output_kg*p.unit_cost_per_kg)* 100,2) AS waste_cost_rate_pct
FROM production_log_staging2 AS pr
JOIN products_staging AS p
	ON pr.product_id = p.product_id
GROUP BY p.product_name
)
SELECT *,
RANK() OVER (ORDER BY total_estimated_waste_cost DESC) AS total_waste_cost_rank,
RANK() OVER (ORDER BY estimated_waste_cost_per_batch DESC) AS cost_per_batch_rank
FROM product_waste
ORDER BY total_waste_cost_rank;

-- Result:
-- Waste cost rates were relatively similar across products, ranging from 7.97% to 8.53%.
-- However, total estimated material waste cost and cost per batch showed clearer differences.
-- Total waste cost rank identifies products with the largest material waste exposure.
-- Cost per batch rank helps identify products that may need closer batch level monitoring.
-- The next analysis will review whether material waste exposure also differs by production line.

-- ============================================================================================================================================
-- 3. Compare material waste exposure by production line
-- ============================================================================================================================================

-- This analysis compares estimated waste exposure by production line.
-- Total estimated waste cost shows the overall cost exposure by line.
-- Cost per batch and waste cost rate help compare line level exposure beyond total volume.

SELECT 
pr.production_line,
COUNT(pr.batch_id) AS batch_count,
ROUND(SUM(pr.waste_kg*p.unit_cost_per_kg),2) AS total_estimated_waste_cost,
ROUND(SUM(pr.waste_kg*p.unit_cost_per_kg)/COUNT(pr.batch_id),2) AS estimated_waste_cost_per_batch,
ROUND(SUM(pr.waste_kg*p.unit_cost_per_kg)/SUM(pr.actual_output_kg*p.unit_cost_per_kg)* 100,2) AS waste_cost_rate_pct
FROM production_log_staging2 AS pr
JOIN products_staging AS p
	ON pr.product_id = p.product_id
GROUP BY pr.production_line
ORDER BY total_estimated_waste_cost DESC;

-- Result:
-- Line 1 had the highest total estimated waste cost and the highest batch count, but waste cost rates were similar across lines.
-- This indicates that the largest total exposure was mainly related to production volume.
-- However, Line 3 had the highest estimated waste cost per batch.
-- Since each line may produce different products, line results should be interpreted together with product mix.
-- Product and line analysis show where waste exposure is concentrated,
-- but they do not show whether downtime status is associated with higher waste exposure.
-- The next analysis will compare waste exposure between batches with and without downtime.

-- ============================================================================================================================================
-- 4. Compare material waste exposure between batches with and without downtime
-- ============================================================================================================================================

-- This analysis compares material waste exposure between batches with downtime and batches without downtime.
-- Product and line analysis showed where waste exposure was concentrated,
-- but they did not explain whether operational interruptions were associated with higher waste exposure.
-- This step uses downtime status as operational context.
-- Each affected batch has only one downtime record, so the join does not duplicate production batch values.

SELECT 
CASE 
	WHEN d.downtime_id IS NULL THEN 'No downtime'
	ELSE 'Downtime'
	END AS Downtime_state, 
COUNT(pr.batch_id) AS batch_count,
ROUND(SUM(pr.actual_output_kg),2) AS total_output_kg,
ROUND(SUM(pr.waste_kg),2) AS total_waste_kg,
ROUND(SUM(pr.waste_kg*p.unit_cost_per_kg),2) AS total_estimated_waste_cost,
ROUND(SUM(pr.waste_kg*p.unit_cost_per_kg)/COUNT(pr.batch_id),2) AS estimated_waste_cost_per_batch,
ROUND(SUM(pr.waste_kg*p.unit_cost_per_kg)/SUM(pr.actual_output_kg*p.unit_cost_per_kg)* 100,2) AS waste_cost_rate_pct
FROM production_log_staging2 AS pr
LEFT JOIN downtime_log_staging AS d
	ON pr.batch_id = d.batch_id
JOIN products_staging AS p
	ON pr.product_id = p.product_id
GROUP BY downtime_state
ORDER BY total_estimated_waste_cost DESC;

-- Result:
-- Total estimated waste cost was higher for batches with no downtime.
-- However, estimated waste cost per batch and waste cost rate were almost the same between the two groups.
-- This suggests that downtime status alone does not explain waste exposure.
-- The next analysis will review whether product level waste cost rate gaps create a meaningful reduction opportunity.

-- ============================================================================================================================================
-- 5. Product level waste reduction opportunity
-- ============================================================================================================================================

-- This analysis reviews products with waste cost rates above the overall waste cost rate.
-- Previous analysis did not show a clear waste exposure difference by production line or downtime status.
-- Therefore, this step checks whether product level rate gaps represent a meaningful share of overall estimated waste cost.

WITH product_waste AS
(
SELECT p.product_name,
COUNT(pr.batch_id) AS batch_count,
ROUND(SUM(pr.actual_output_kg * p.unit_cost_per_kg),2) AS total_estimated_output_value,
ROUND(SUM(pr.waste_kg * p.unit_cost_per_kg),2) AS total_estimated_waste_cost,
ROUND(SUM(pr.waste_kg * p.unit_cost_per_kg)/SUM(pr.actual_output_kg * p.unit_cost_per_kg)*100,2) AS waste_cost_rate_pct
FROM production_log_staging2 AS pr
JOIN products_staging AS p
	ON pr.product_id = p.product_id
GROUP BY p.product_name
),
overall_rate AS
(
SELECT ROUND(SUM(pr.waste_kg * p.unit_cost_per_kg)/SUM(pr.actual_output_kg * p.unit_cost_per_kg)*100,2) AS overall_waste_cost_rate_pct
FROM production_log_staging2 AS pr
JOIN products_staging AS p
	ON pr.product_id = p.product_id
)
SELECT *,
CASE WHEN pw.waste_cost_rate_pct > overall.overall_waste_cost_rate_pct THEN 'Above overall rate'
	 ELSE 'Below overall rate'
     END AS rate_status,
RANK() OVER (ORDER BY waste_cost_rate_pct DESC) AS waste_cost_rate_rank
FROM product_waste AS pw
CROSS JOIN overall_rate AS overall
;

-- Result:
-- Nine products recorded waste cost rates above the overall rate.
-- However, their rates ranged only from 8.31% to 8.53%, compared with the overall waste cost rate of 8.27%.
-- This suggests that products above the overall rate may not create a large reduction opportunity by rate difference alone.
-- Therefore, the next analysis will calculate how much estimated excess waste cost these products represent as a share of overall estimated waste cost.

-- ============================================================================================================================================
-- 6. Estimate excess waste cost from products above the overall rate
-- ============================================================================================================================================

-- This analysis estimates the excess waste cost from products above the overall waste cost rate.
-- Excess waste cost is calculated as the rate gap multiplied by each product's estimated output value.
-- This checks whether products above the overall rate represent a meaningful reduction opportunity.

WITH product_waste AS
(
SELECT 
p.product_name,
COUNT(pr.batch_id) AS batch_count,
SUM(pr.actual_output_kg * p.unit_cost_per_kg) AS total_estimated_output_value,
SUM(pr.waste_kg * p.unit_cost_per_kg) AS total_estimated_waste_cost,
SUM(pr.waste_kg * p.unit_cost_per_kg) /
SUM(pr.actual_output_kg * p.unit_cost_per_kg) * 100 AS waste_cost_rate_pct
FROM production_log_staging2 AS pr
JOIN products_staging AS p
    ON pr.product_id = p.product_id
GROUP BY p.product_name
),

overall_rate AS
(
SELECT 
SUM(pr.waste_kg * p.unit_cost_per_kg) AS overall_estimated_waste_cost,
SUM(pr.waste_kg * p.unit_cost_per_kg) /
SUM(pr.actual_output_kg * p.unit_cost_per_kg) * 100 AS overall_waste_cost_rate_pct
FROM production_log_staging2 AS pr
JOIN products_staging AS p
    ON pr.product_id = p.product_id
)

SELECT 
ROUND(MAX(o.overall_estimated_waste_cost),2) AS overall_estimated_waste_cost,
ROUND(SUM(pw.total_estimated_waste_cost),2) AS total_waste_cost_above_overall_rate,
ROUND(SUM(pw.total_estimated_output_value * ((pw.waste_cost_rate_pct - o.overall_waste_cost_rate_pct) / 100)),2) AS total_estimated_excess_waste_cost,
ROUND(SUM(pw.total_estimated_output_value * ((pw.waste_cost_rate_pct - o.overall_waste_cost_rate_pct) / 100)) / MAX(o.overall_estimated_waste_cost) * 100,2) AS excess_waste_share_pct,
COUNT(pw.product_name) AS products_above_overall_rate
FROM product_waste AS pw
CROSS JOIN overall_rate AS o
WHERE pw.waste_cost_rate_pct > o.overall_waste_cost_rate_pct;

-- Result:
-- The total estimated excess waste cost was only 123k which represents 0.52% of overall estimated waste cost.
-- This suggests that focusing only on products above the overall waste cost rate may not create a large saving opportunity.
-- Therefore, a more practical review direction is to focus on products with the highest total waste cost,
-- where small reductions may create more meaningful savings.
-- The next analysis will estimate potential savings from reducing waste cost by 1%, 3%, and 5% for the top 5 products by total estimated waste cost.


-- ============================================================================================================================================
-- 7. Saving opportunity for high total waste cost products
-- ============================================================================================================================================

-- This analysis estimates potential savings from the top 5 products by total estimated waste cost.
-- Previous analysis showed that focusing only on products above the overall waste cost rate may not create a large saving opportunity.
-- Therefore, this step reviews the saving impact if high total waste cost products achieve small reductions.
-- This is a scenario estimate and does not identify the root cause of waste.

WITH current_waste_cost AS
(
SELECT ROUND(SUM(pr.waste_kg*p.unit_cost_per_kg),2) AS current_waste_cost
FROM production_log_staging2 AS pr
JOIN products_staging AS p
	ON pr.product_id = p.product_id
),

top_5_product_cost AS
(
SELECT ROUND(SUM(top_5.product_waste_cost),2) AS top_5_product_waste_cost
FROM
(
SELECT 
p.product_name,
SUM(pr.waste_kg * p.unit_cost_per_kg) AS product_waste_cost
FROM production_log_staging2 AS pr
JOIN products_staging AS p
	ON pr.product_id = p.product_id
GROUP BY p.product_name
ORDER BY product_waste_cost DESC LIMIT 5) AS top_5
)

SELECT 
'1%' AS reduction_percentage,
c.current_waste_cost,
t.top_5_product_waste_cost,
ROUND(t.top_5_product_waste_cost * 0.01, 2) AS estimated_saving_cost,
ROUND(c.current_waste_cost - (t.top_5_product_waste_cost * 0.01),2) AS estimated_cost_after_reduction
FROM current_waste_cost AS c
CROSS JOIN top_5_product_cost AS t

UNION ALL

SELECT 
'3%' AS reduction_percentage,
c.current_waste_cost,
t.top_5_product_waste_cost,
ROUND(t.top_5_product_waste_cost * 0.03, 2) AS estimated_saving_cost,
ROUND(c.current_waste_cost - (t.top_5_product_waste_cost * 0.03),2) AS estimated_cost_after_reduction
FROM current_waste_cost AS c
CROSS JOIN top_5_product_cost AS t

UNION ALL

SELECT 
'5%' AS reduction_percentage,
c.current_waste_cost,
t.top_5_product_waste_cost,
ROUND(t.top_5_product_waste_cost * 0.05, 2) AS estimated_saving_cost,
ROUND(c.current_waste_cost - (t.top_5_product_waste_cost * 0.05),2) AS estimated_cost_after_reduction
FROM current_waste_cost AS c
CROSS JOIN top_5_product_cost AS t
;

-- Result:
-- The top 5 products by total estimated waste cost accounted for 9.00M out of 23.59M total estimated waste cost.
-- This represents approximately 38.15% of overall estimated waste cost.
-- A 1%, 3%, and 5% reduction in these top 5 products would create estimated savings of 89.98K, 269.93K, and 449.89K respectively.
-- Compared with the limited excess waste opportunity from products above the overall rate,
-- high total waste cost products provide a more practical starting point for meaningful waste cost reduction.
-- This scenario does not confirm how waste can be reduced.
-- Actual improvement actions require waste reason or process level data, which is not available in the current dataset.

-- Therefore, the next analysis will review downtime reason as supporting operational context,
-- not as the main explanation for overall waste exposure.


-- =======================================================================
-- =======================================================================
-- EDA 2. Supporting Operational Checks
-- =======================================================================
-- =======================================================================

-- ============================================================================================================================================
-- 8. Compare material waste exposure by downtime reason
-- ============================================================================================================================================

-- This analysis reviews downtime reason as supporting operational context for material waste exposure.
-- Downtime was not a strong explanation for overall waste exposure in the previous analysis.
-- However, it is still useful to review downtime reasons within batches that had downtime.
-- Total waste cost shows which downtime reason is linked with the largest estimated waste exposure.
-- Waste cost per event helps check whether the exposure is mainly related to downtime frequency or cost per event.

WITH downtime_waste_cost AS
(
SELECT d.reason,
COUNT(d.downtime_id) AS downtime_events,
ROUND(SUM(pr.waste_kg * p.unit_cost_per_kg), 2) AS total_estimated_waste_cost,
ROUND(SUM(pr.waste_kg * p.unit_cost_per_kg)/COUNT(d.downtime_id),2) AS estimated_waste_cost_per_event
FROM production_log_staging2 AS pr
JOIN downtime_log_staging AS d
    ON pr.batch_id = d.batch_id
JOIN products_staging AS p
    ON pr.product_ID = p.product_ID
GROUP BY d.reason
)
SELECT *,
RANK() OVER(ORDER BY total_estimated_waste_cost DESC) AS total_waste_cost_rank
FROM downtime_waste_cost
ORDER BY total_waste_cost_rank;

-- Result:
-- Machine Jam had the highest total estimated waste cost among downtime reasons.
-- However, estimated waste cost per event was similar across downtime reasons, ranging from 1032.71 to 1096.66.
-- This suggests that Machine Jam occurred more frequently,
-- and total waste exposure within downtime batches appears to be mainly related to downtime frequency rather than a clearly higher cost per event.
-- This should be interpreted only within batches that had downtime.
-- The next analysis will review whether downtime reason patterns differ by production line.

-- ============================================================================================================================================
-- 9. Compare downtime reason patterns by production line
-- ============================================================================================================================================

-- This analysis reviews downtime reason patterns within each production line.
-- It compares downtime frequency, total estimated waste cost, and cost per event.
-- This helps check whether the overall downtime pattern is consistent across production lines.

WITH downtime_frequency AS
(
SELECT pr.production_line, d.reason, COUNT(d.downtime_id) AS downtime_events,
ROUND(SUM(pr.waste_kg * p.unit_cost_per_kg), 2) AS total_estimated_waste_cost,
ROUND(SUM(pr.waste_kg * p.unit_cost_per_kg)/COUNT(d.downtime_id),2) AS estimated_waste_cost_per_event
FROM production_log_staging2 AS pr
JOIN downtime_log_staging AS d
	ON pr.batch_id = d.batch_id
JOIN products_staging AS p
    ON pr.product_ID = p.product_ID
GROUP BY pr.production_line, d.reason
)
SELECT *,
RANK() OVER (PARTITION BY production_line ORDER BY downtime_events DESC) AS downtime_frequency_rank_by_line
FROM downtime_frequency
ORDER BY production_line, downtime_frequency_rank_by_line;

-- Result:
-- Machine Jam was the most frequent downtime reason across production lines.
-- However, the highest estimated waste cost per event differed by line.
-- For example, Power Failure showed higher cost per event on Line 2, while Cleaning showed higher cost per event on Line 3.
-- This suggests that line level monitoring should review both frequent downtime reasons and reasons with higher cost per event.
-- The next analysis will review monthly waste exposure trends to support ongoing monitoring.

-- ============================================================================================================================================
-- 10. Monthly material waste exposure trend
-- ============================================================================================================================================

-- This analysis reviews monthly waste exposure and downtime frequency.
-- It helps check whether estimated waste cost is concentrated in specific months
-- and whether monthly waste exposure moves with downtime occurrence.

SELECT 
YEAR(pr.production_date) AS `Year`, 
MONTH(pr.production_date) AS `Month`, 
COUNT(pr.batch_id) AS batch_count,
COUNT(d.downtime_id) AS downtime_count, 
ROUND(SUM(pr.waste_kg*p.unit_cost_per_kg),2) AS total_estimated_waste_cost,
ROUND(SUM(pr.waste_kg*p.unit_cost_per_kg)/COUNT(pr.batch_id),2) AS estimated_waste_cost_per_batch,
ROUND(SUM(pr.waste_kg*p.unit_cost_per_kg)/SUM(pr.actual_output_kg*p.unit_cost_per_kg)*100,2) AS waste_cost_rate_pct
FROM production_log_staging2 AS pr
LEFT JOIN downtime_log_staging AS d
		ON pr.batch_id = d.Batch_id
JOIN products_staging AS p
	ON pr.product_id = p.Product_ID
GROUP BY YEAR(pr.production_date), MONTH(pr.production_date)
ORDER BY `Year`, `Month`;

-- Result:
-- Monthly total estimated waste cost varied across the year.
-- However, waste cost rate stayed within a narrow range, from 8.16% to 8.44%.
-- Estimated waste cost per batch also remained within a relatively close range.
-- This suggests that monthly total waste cost should be reviewed together with batch count,
-- rather than interpreted as a clear monthly efficiency issue.
-- Downtime count provides additional context for monthly monitoring.
-- The next analysis will summarise the final review priorities.

-- ============================================================================================================================================
-- 11. Final insight and review priorities
-- ============================================================================================================================================

-- Final Insight:

-- Overall estimated material waste cost was approximately 23.6M.
-- Waste cost rates were relatively similar across products, production lines, downtime status, and months.
-- Downtime status alone did not explain waste exposure.
-- Products above the overall waste cost rate represented only 0.52% excess waste opportunity.
-- The top 5 products by total estimated waste cost accounted for approximately 38.15% of overall estimated waste cost.
-- Therefore, waste reduction review should prioritise high total waste cost products first.
-- Downtime reason and monthly trend should be used as supporting monitoring context.
-- This EDA identifies review priorities, not confirmed root causes.
-- Actual waste reduction actions require waste reason or process level data, which is not available in the current dataset.
