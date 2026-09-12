-- Step 5K: create the typed Australia monthly CPI table.
-- Requires raw.abs_cpi_table1_monthly and the completed 11 audit.
-- Retain all 28 months and the three Australia Original measures.
-- Section 2 creates the table once. Sections 3-5 are repeatable checks.

-- 1. Ensure the staging schema exists.
CREATE SCHEMA IF NOT EXISTS stg;

-- 2. Convert the month label and selected measures.
-- Raw dates use month starts. LAST_DAY provides a month-end report_date
-- consistent with the existing APRA/RBA tables, without shifting the month.
-- This label identifies the observation month, not the publication date.
-- Index units remain index numbers (September 2025 = 100.00).
-- Changes remain in per-cent units: 3.5 means 3.5%.
-- Preserve NULLs, negative changes and zeros. No date filtering or imputation.
-- Strict CAST rejects invalid nonblank numeric text.
-- CREATE TABLE fails if the table exists, without replacing it.
CREATE TABLE stg.abs_cpi_australia_monthly AS
SELECT
    LAST_DAY(
        DATE '1899-12-30' + CAST(TRIM(period_raw) AS INTEGER)
    ) AS report_date,
    CAST(NULLIF(TRIM("A130393720C"), '')
        AS DECIMAL(18, 6)) AS cpi_index,
    CAST(NULLIF(TRIM("A130393721F"), '')
        AS DECIMAL(18, 6)) AS cpi_yoy_pct,
    CAST(NULLIF(TRIM("A130393722J"), '')
        AS DECIMAL(18, 6)) AS cpi_mom_pct
FROM raw.abs_cpi_table1_monthly;

-- 3. Inspect column names and types.
-- Expected: report_date DATE and three DECIMAL(18,6) measure columns.
DESCRIBE stg.abs_cpi_australia_monthly;

-- 4. Check retained history.
-- Expected: 28 rows, 28 months, 2024-04-30 through 2026-07-31.
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT DATE_TRUNC('month', report_date)) AS month_count,
    MIN(report_date) AS first_date,
    MAX(report_date) AS last_date
FROM stg.abs_cpi_australia_monthly;

-- 5. Validate monthly keys, dates and the retained source patterns.
-- Expected: twelve PASS rows for the pinned July 2026 snapshot.
-- YoY has 12 initial NULLs; MoM has one initial NULL, seven negatives and three zeros.
-- These expected counts describe this snapshot; they are not universal CPI rules.
WITH duplicate_months AS (
    SELECT DATE_TRUNC('month', report_date) AS report_month
    FROM stg.abs_cpi_australia_monthly
    WHERE report_date IS NOT NULL
    GROUP BY report_month
    HAVING COUNT(*) > 1
), counts AS (
    SELECT
        (SELECT COUNT(*) FROM duplicate_months) AS duplicate_month_keys,
        COUNT(*) FILTER (WHERE report_date IS NULL) AS missing_date_rows,
        COUNT(*) FILTER (
            WHERE report_date <> LAST_DAY(report_date)
        ) AS non_month_end_rows,
        DATE_DIFF('month', MIN(report_date), MAX(report_date)) + 1
            - COUNT(DISTINCT DATE_TRUNC('month', report_date)) AS missing_months_in_span,
        COUNT(*) FILTER (WHERE cpi_index IS NULL) AS cpi_index_missing,
        COUNT(*) FILTER (WHERE cpi_yoy_pct IS NULL) AS cpi_yoy_missing,
        COUNT(*) FILTER (WHERE cpi_mom_pct IS NULL) AS cpi_mom_missing,
        COUNT(*) FILTER (WHERE cpi_index <= 0) AS nonpositive_index_rows,
        COUNT(*) FILTER (
            WHERE (report_date < DATE '2025-04-30' AND cpi_yoy_pct IS NOT NULL)
               OR (report_date >= DATE '2025-04-30' AND cpi_yoy_pct IS NULL)
        ) AS unexpected_yoy_null_pattern,
        COUNT(*) FILTER (
            WHERE (report_date < DATE '2024-05-31' AND cpi_mom_pct IS NOT NULL)
               OR (report_date >= DATE '2024-05-31' AND cpi_mom_pct IS NULL)
        ) AS unexpected_mom_null_pattern,
        COUNT(*) FILTER (WHERE cpi_mom_pct < 0) AS cpi_mom_negative,
        COUNT(*) FILTER (WHERE cpi_mom_pct = 0) AS cpi_mom_zero
    FROM stg.abs_cpi_australia_monthly
)
SELECT
    c.check_name,
    c.actual_count,
    c.expected_count,
    CASE WHEN c.actual_count = c.expected_count THEN 'PASS' ELSE 'FAIL' END AS status
FROM counts
CROSS JOIN LATERAL (
    VALUES
        (1, 'duplicate_month_keys', duplicate_month_keys, 0),
        (2, 'missing_date_rows', missing_date_rows, 0),
        (3, 'non_month_end_rows', non_month_end_rows, 0),
        (4, 'missing_months_in_span', missing_months_in_span, 0),
        (5, 'cpi_index_missing', cpi_index_missing, 0),
        (6, 'cpi_yoy_missing', cpi_yoy_missing, 12),
        (7, 'cpi_mom_missing', cpi_mom_missing, 1),
        (8, 'nonpositive_index_rows', nonpositive_index_rows, 0),
        (9, 'unexpected_yoy_null_pattern', unexpected_yoy_null_pattern, 0),
        (10, 'unexpected_mom_null_pattern', unexpected_mom_null_pattern, 0),
        (11, 'cpi_mom_negative', cpi_mom_negative, 7),
        (12, 'cpi_mom_zero', cpi_mom_zero, 3)
) AS c(check_order, check_name, actual_count, expected_count)
ORDER BY c.check_order;
