-- Step 5O: create the typed Australia quarterly CPI table.
-- Requires raw.abs_cpi_table17_quarterly and the completed 14 audit.
-- Retain all 312 quarters and the two Australia Original measures.
-- Section 2 creates the table once. Sections 3-5 are repeatable checks.

-- 1. Ensure the staging schema exists.
CREATE SCHEMA IF NOT EXISTS stg;

-- 2. Convert the audited quarter label and selected measures.
-- Source dates use day 1 of the quarter's LAST month (March/June/September/December).
-- LAST_DAY converts that label to the corresponding quarter-end report_date.
-- For example, 2026-06-01 becomes 2026-06-30, still representing 2026Q2.
-- report_date labels the observation quarter; it is not a publication date
-- or a claim that quarterly CPI was measured only on the last day.
-- Index units remain index numbers (September MONTH 2025 = 100.00).
-- September QUARTER 2025 retains index 99.73 in this source snapshot.
-- Published QoQ remains in per-cent units: 0.6 means 0.6%.
-- Preserve NULLs, negative changes and zeros. No filtering or imputation.
-- Table 17 has no published YoY column; this step does not derive one.
-- Strict CAST rejects invalid nonblank numeric text.
-- CREATE TABLE fails if the table exists, without replacing it.
CREATE TABLE stg.abs_cpi_australia_quarterly AS
SELECT
    LAST_DAY(
        DATE '1899-12-30' + CAST(TRIM(period_raw) AS INTEGER)
    ) AS report_date,
    CAST(NULLIF(TRIM("A2325846C"), '')
        AS DECIMAL(18, 6)) AS cpi_index,
    CAST(NULLIF(TRIM("A2325850V"), '')
        AS DECIMAL(18, 6)) AS cpi_qoq_pct
FROM raw.abs_cpi_table17_quarterly;

-- 3. Inspect column names and types.
-- Expected: report_date DATE, cpi_index and cpi_qoq_pct DECIMAL(18,6).
DESCRIBE stg.abs_cpi_australia_quarterly;

-- 4. Check retained quarterly history.
-- Expected: 312 rows, 312 quarters, 1948-09-30 through 2026-06-30.
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT DATE_TRUNC('quarter', report_date)) AS quarter_count,
    MIN(report_date) AS first_date,
    MAX(report_date) AS last_date
FROM stg.abs_cpi_australia_quarterly;

-- 5. Validate quarterly keys, dates and retained source patterns.
-- Expected: ten PASS rows for the pinned July 2026 workbook snapshot.
-- QoQ has one initial NULL (1948Q3), twelve negatives and twenty-four zeros.
-- These counts describe this snapshot; they are not universal CPI rules.
-- Review with section 4's row count and endpoints and the completed raw audit.
WITH duplicate_quarters AS (
    SELECT DATE_TRUNC('quarter', report_date) AS report_quarter
    FROM stg.abs_cpi_australia_quarterly
    WHERE report_date IS NOT NULL
    GROUP BY report_quarter
    HAVING COUNT(*) > 1
), counts AS (
    SELECT
        (SELECT COUNT(*) FROM duplicate_quarters) AS duplicate_quarter_keys,
        COUNT(*) FILTER (WHERE report_date IS NULL) AS missing_date_rows,
        COUNT(*) FILTER (
            WHERE report_date <> LAST_DAY(report_date)
               OR MONTH(report_date) NOT IN (3, 6, 9, 12)
        ) AS non_quarter_end_rows,
        COALESCE(
            DATE_DIFF('quarter', MIN(report_date), MAX(report_date)) + 1
                - COUNT(DISTINCT DATE_TRUNC('quarter', report_date)),
            1
        ) AS missing_quarters_in_span,
        COUNT(*) FILTER (WHERE cpi_index IS NULL) AS cpi_index_missing,
        COUNT(*) FILTER (WHERE cpi_qoq_pct IS NULL) AS cpi_qoq_missing,
        COUNT(*) FILTER (WHERE cpi_index <= 0) AS nonpositive_index_rows,
        COUNT(*) FILTER (
            WHERE (report_date = DATE '1948-09-30' AND cpi_qoq_pct IS NOT NULL)
               OR (report_date <> DATE '1948-09-30' AND cpi_qoq_pct IS NULL)
        ) AS unexpected_qoq_null_pattern,
        COUNT(*) FILTER (WHERE cpi_qoq_pct < 0) AS cpi_qoq_negative,
        COUNT(*) FILTER (WHERE cpi_qoq_pct = 0) AS cpi_qoq_zero
    FROM stg.abs_cpi_australia_quarterly
)
SELECT
    c.check_name,
    c.actual_count,
    c.expected_count,
    CASE WHEN c.actual_count = c.expected_count THEN 'PASS' ELSE 'FAIL' END AS status
FROM counts
CROSS JOIN LATERAL (
    VALUES
        (1, 'duplicate_quarter_keys', duplicate_quarter_keys, 0),
        (2, 'missing_date_rows', missing_date_rows, 0),
        (3, 'non_quarter_end_rows', non_quarter_end_rows, 0),
        (4, 'missing_quarters_in_span', missing_quarters_in_span, 0),
        (5, 'cpi_index_missing', cpi_index_missing, 0),
        (6, 'cpi_qoq_missing', cpi_qoq_missing, 1),
        (7, 'nonpositive_index_rows', nonpositive_index_rows, 0),
        (8, 'unexpected_qoq_null_pattern', unexpected_qoq_null_pattern, 0),
        (9, 'cpi_qoq_negative', cpi_qoq_negative, 12),
        (10, 'cpi_qoq_zero', cpi_qoq_zero, 24)
) AS c(check_order, check_name, actual_count, expected_count)
ORDER BY c.check_order;
