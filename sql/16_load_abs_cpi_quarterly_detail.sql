-- Step 5Q: import both data sheets from ABS quarterly CPI Table 18.
-- Requires the existing raw schema and installed official Excel extension.
-- Run sections 1-7 sequentially on the project connection.
-- Sections 3 and 4 each create a table once; existing tables are not replaced.
-- Keep the two sheet imports separate, with original Series IDs and blanks.

-- 1. Load Excel support.
LOAD excel;

-- 2. Set the path to the pinned July 2026 release snapshot.
SET VARIABLE abs_cpi_quarterly_detail_workbook_path =
    'E:/DuckDB/Australian_Big_Four_Banking/data/raw/06_ABS_CPI_Table18_Quarterly_Detail_Jul2026.xlsx';

-- 3. Import Data1: one date column, 132 indexes and 118 quarterly changes.
-- Row 10 contains Series IDs; rows 11-322 contain 312 quarterly source labels.
CREATE TABLE raw.abs_cpi_table18_data1_quarterly AS
SELECT
    "Series ID" AS period_raw,
    * EXCLUDE ("Series ID")
FROM read_xlsx(
    getvariable('abs_cpi_quarterly_detail_workbook_path'),
    sheet = 'Data1',
    range = 'A10:IQ322',
    header = true,
    all_varchar = true,
    stop_at_empty = false
);

-- 4. Import Data2: one date column, 14 remaining quarterly changes and
-- 132 contributions to Total CPI (Index Points). These are separate measures.
-- Contribution series have three observations, December 2025-June 2026;
-- retain their earlier blanks. No rates, weights or missing values are derived.
CREATE TABLE raw.abs_cpi_table18_data2_quarterly AS
SELECT
    "Series ID" AS period_raw,
    * EXCLUDE ("Series ID")
FROM read_xlsx(
    getvariable('abs_cpi_quarterly_detail_workbook_path'),
    sheet = 'Data2',
    range = 'A10:EQ322',
    header = true,
    all_varchar = true,
    stop_at_empty = false
);

-- 5. Summarize the schema without a 398-row DESCRIBE result.
-- Data1: 251 columns, all VARCHAR. Data2: 147 columns, all VARCHAR.
-- Each table's first column is period_raw; non_varchar_count must be zero.
SELECT
    CASE table_name
        WHEN 'abs_cpi_table18_data1_quarterly' THEN 'Data1'
        WHEN 'abs_cpi_table18_data2_quarterly' THEN 'Data2'
    END AS source_sheet,
    COUNT(*) AS column_count,
    COUNT(*) FILTER (WHERE data_type = 'VARCHAR') AS varchar_count,
    COUNT(*) FILTER (WHERE data_type <> 'VARCHAR') AS non_varchar_count,
    MAX(CASE WHEN ordinal_position = 1 THEN column_name END) AS first_column
FROM information_schema.columns
WHERE table_catalog = CURRENT_DATABASE()
  AND table_schema = 'raw'
  AND table_name IN (
      'abs_cpi_table18_data1_quarterly',
      'abs_cpi_table18_data2_quarterly'
  )
GROUP BY table_name
ORDER BY source_sheet;

-- 6. Check BOTH quarterly calendars independently.
-- Expected per sheet: 312 rows, 312 quarters, 1948-09-01 through 2026-06-01.
-- Source labels use day 1 of March/June/September/December, not quarter ends.
-- No data from the two sheets is appended into additional observations.
WITH periods AS (
    SELECT 'Data1' AS source_sheet, period_raw
    FROM raw.abs_cpi_table18_data1_quarterly
    UNION ALL
    SELECT 'Data2' AS source_sheet, period_raw
    FROM raw.abs_cpi_table18_data2_quarterly
), dates AS (
    SELECT
        source_sheet,
        DATE '1899-12-30' + CAST(TRIM(period_raw) AS INTEGER) AS source_quarter
    FROM periods
)
SELECT
    source_sheet,
    COUNT(*) AS row_count,
    COUNT(DISTINCT DATE_TRUNC('quarter', source_quarter)) AS quarter_count,
    MIN(source_quarter) AS first_date,
    MAX(source_quarter) AS last_date
FROM dates
GROUP BY source_sheet
ORDER BY source_sheet;

-- 7. Preview the latest five All groups observations from both sheets.
-- Data1 provides index and QoQ; Data2 provides contribution to Total CPI.
-- The full join is a read-only preview. The raw sheet tables stay separate.
-- Raw date uniqueness/alignment and all series will be audited next.
-- cpi_qoq_pct is Percent (0.6 = 0.6%); cpi_contribution_index_points is Index
-- Points, not a growth rate or percentage-point contribution to inflation.
-- Its first nonblank quarter is 2025-12-01. Earlier NULLs are expected.
WITH data1 AS (
    SELECT
        DATE '1899-12-30' + CAST(TRIM(period_raw) AS INTEGER) AS source_quarter,
        CAST(NULLIF(TRIM("A2325846C"), '') AS DECIMAL(18, 6)) AS cpi_index,
        CAST(NULLIF(TRIM("A2325850V"), '') AS DECIMAL(18, 6)) AS cpi_qoq_pct
    FROM raw.abs_cpi_table18_data1_quarterly
), data2 AS (
    SELECT
        DATE '1899-12-30' + CAST(TRIM(period_raw) AS INTEGER) AS source_quarter,
        CAST(NULLIF(TRIM("A3597525W"), '')
            AS DECIMAL(18, 6)) AS cpi_contribution_index_points
    FROM raw.abs_cpi_table18_data2_quarterly
)
SELECT
    COALESCE(d1.source_quarter, d2.source_quarter) AS source_quarter,
    d1.cpi_index,
    d1.cpi_qoq_pct,
    d2.cpi_contribution_index_points
FROM data1 AS d1
FULL OUTER JOIN data2 AS d2 ON d1.source_quarter = d2.source_quarter
ORDER BY source_quarter DESC
LIMIT 5;
