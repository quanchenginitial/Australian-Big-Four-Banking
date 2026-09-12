-- Step 5I: import ABS Table 1 monthly All groups CPI.
-- Requires the existing raw schema and installed official Excel extension.
-- Run sections 1-6 sequentially on the project connection.
-- Section 3 creates the table once; it does not replace an existing table.

-- 1. Load Excel support.
LOAD excel;

-- 2. Set the local path for the July 2026 snapshot.
SET VARIABLE abs_cpi_monthly_workbook_path =
    'E:/DuckDB/Australian_Big_Four_Banking/data/raw/04_ABS_CPI_Table1_Monthly_Jul2026.xlsx';

-- 3. Keep all 27 series plus the source date, as VARCHAR.
-- Data1 row 10 contains Series IDs; rows 11-38 contain 28 months.
-- Source dates label months with their FIRST day. Preserve them in raw.
-- The series cover Australia and eight capital cities, with three measures each.
CREATE TABLE raw.abs_cpi_table1_monthly AS
SELECT
    "Series ID" AS period_raw,
    * EXCLUDE ("Series ID")
FROM read_xlsx(
    getvariable('abs_cpi_monthly_workbook_path'),
    sheet = 'Data1',
    range = 'A10:AB38',
    header = true,
    all_varchar = true,
    stop_at_empty = false
);

-- 4. Inspect the schema: expected 28 columns, all VARCHAR.
DESCRIBE raw.abs_cpi_table1_monthly;

-- 5. Inspect the source monthly calendar.
-- Expected: 28 rows, 28 months, 2024-04-01 through 2026-07-01.
-- These are source month labels, not month-end reporting dates.
WITH dates AS (
    SELECT
        DATE '1899-12-30'
            + CAST(TRIM(period_raw) AS INTEGER) AS source_month
    FROM raw.abs_cpi_table1_monthly
)
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT source_month) AS month_count,
    MIN(source_month) AS first_date,
    MAX(source_month) AS last_date
FROM dates;

-- 6. Preview the latest five Australia observations (Original series).
-- Index units differ from percentage changes: 103.07 is an index, not a rate.
-- September 2025 = 100.00. A published change of 3.5 means 3.5%.
-- YoY first appears in April 2025; MoM first appears in May 2024.
-- Keep NULLs, negative changes and zeros. They are not interchangeable.
-- Casts below are for a read-only preview; raw values remain unchanged.
SELECT
    DATE '1899-12-30'
        + CAST(TRIM(period_raw) AS INTEGER) AS source_month,
    CAST(NULLIF(TRIM("A130393720C"), '')
        AS DECIMAL(18, 6)) AS cpi_index,
    CAST(NULLIF(TRIM("A130393721F"), '')
        AS DECIMAL(18, 6)) AS cpi_yoy_pct,
    CAST(NULLIF(TRIM("A130393722J"), '')
        AS DECIMAL(18, 6)) AS cpi_mom_pct
FROM raw.abs_cpi_table1_monthly
ORDER BY source_month DESC
LIMIT 5;
