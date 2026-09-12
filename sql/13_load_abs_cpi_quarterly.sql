-- Step 5M: import ABS Table 17 quarterly All groups CPI.
-- Requires the existing raw schema and installed official Excel extension.
-- Run sections 1-6 sequentially on the project connection.
-- Section 3 creates the table once; it does not replace an existing table.

-- 1. Load Excel support.
LOAD excel;

-- 2. Set the local workbook path for the July 2026 release snapshot.
-- The latest quarterly observation is June quarter 2026.
SET VARIABLE abs_cpi_quarterly_workbook_path =
    'E:/DuckDB/Australian_Big_Four_Banking/data/raw/05_ABS_CPI_Table17_Quarterly_Jul2026.xlsx';

-- 3. Import the source date and all 18 series as VARCHAR.
-- Data1 row 10 contains Series IDs; rows 11-322 contain 312 quarters.
-- Source dates use day 1 of the quarter's LAST month (March/June/September/December).
-- Keep all city and Australia series, including historical blanks and zeros.
CREATE TABLE raw.abs_cpi_table17_quarterly AS
SELECT
    "Series ID" AS period_raw,
    * EXCLUDE ("Series ID")
FROM read_xlsx(
    getvariable('abs_cpi_quarterly_workbook_path'),
    sheet = 'Data1',
    range = 'A10:S322',
    header = true,
    all_varchar = true,
    stop_at_empty = false
);

-- 4. Inspect all 19 columns: period_raw plus 18 series, all VARCHAR.
DESCRIBE raw.abs_cpi_table17_quarterly;

-- 5. Check the quarterly source calendar.
-- Expected: 312 rows, 312 quarters, 1948-09-01 through 2026-06-01.
-- These source labels will be aligned to quarter ends in a later staging step.
WITH dates AS (
    SELECT
        DATE '1899-12-30'
            + CAST(TRIM(period_raw) AS INTEGER) AS source_quarter
    FROM raw.abs_cpi_table17_quarterly
)
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT DATE_TRUNC('quarter', source_quarter)) AS quarter_count,
    MIN(source_quarter) AS first_date,
    MAX(source_quarter) AS last_date
FROM dates;

-- 6. Preview the latest five Australia observations (Original series).
-- Table 17 contains index and QoQ series; it has no published YoY column.
-- The index uses September MONTH 2025 = 100.00. September QUARTER 2025 is 99.73.
-- Change values remain in per-cent units: 0.6 means 0.6% quarter-on-quarter.
-- Casts are only for this read-only preview; raw values remain unchanged.
SELECT
    DATE '1899-12-30'
        + CAST(TRIM(period_raw) AS INTEGER) AS source_quarter,
    CAST(NULLIF(TRIM("A2325846C"), '')
        AS DECIMAL(18, 6)) AS cpi_index,
    CAST(NULLIF(TRIM("A2325850V"), '')
        AS DECIMAL(18, 6)) AS cpi_qoq_pct
FROM raw.abs_cpi_table17_quarterly
ORDER BY source_quarter DESC
LIMIT 5;
