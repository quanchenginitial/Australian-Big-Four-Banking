-- Step 5G: create the typed RBA monthly reference-rate table.
-- Requires raw.rba_f1_1_monthly and the completed 08 date/coverage audit.
-- Keep all 687 months and the three selected reference rates.
-- Section 2 creates the table once. Sections 3-5 are repeatable checks.
-- This is a stored snapshot, with one row per month and no bank column.

-- 1. Ensure the staging schema exists.
CREATE SCHEMA IF NOT EXISTS stg;

-- 2. Convert dates and selected rates, preserving source NULLs and zeros.
-- Rates remain in per-cent units: 4.35 means 4.35%.
-- The rates are monthly averages; report_date identifies the month.
-- CAST rejects invalid nonblank numeric text. No filtering or imputation.
-- CREATE TABLE fails if the table already exists, without replacing it.
CREATE TABLE stg.rba_monthly_rates AS
SELECT
    DATE '1899-12-30'
        + CAST(TRIM(period_raw) AS INTEGER) AS report_date,
    CAST(NULLIF(TRIM("FIRMMCRT"), '')
        AS DECIMAL(18, 6)) AS cash_rate_target_pct,
    CAST(NULLIF(TRIM("FIRMMCRI"), '')
        AS DECIMAL(18, 6)) AS interbank_cash_rate_pct,
    CAST(NULLIF(TRIM("FIRMMBAB90"), '')
        AS DECIMAL(18, 6)) AS bank_bill_3m_pct
FROM raw.rba_f1_1_monthly;

-- 3. Check all four columns and types.
-- Expected: report_date DATE, and three DECIMAL(18,6) rate columns.
DESCRIBE stg.rba_monthly_rates;

-- 4. Check retained history and monthly coverage.
-- Expected: 687 rows, 687 months, 1969-06-30 through 2026-08-31.
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT DATE_TRUNC('month', report_date)) AS month_count,
    MIN(report_date) AS first_date,
    MAX(report_date) AS last_date
FROM stg.rba_monthly_rates;

-- 5. Check keys/dates, preserved missing values, and the historical source zero.
-- Expected counts apply only to this pinned workbook snapshot.
-- The bank-bill zero is a flagged source value, not a repaired/validated rate.
-- PASS means the stored values match these expectations, not that a source
-- zero has been economically validated. Read alongside the 08 scope checks.
-- Expected: eleven PASS rows; the old missing values and zero remain present.
WITH duplicate_months AS (
    SELECT DATE_TRUNC('month', report_date) AS report_month
    FROM stg.rba_monthly_rates
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
        COUNT(*) FILTER (
            WHERE cash_rate_target_pct IS NULL
        ) AS cash_rate_target_missing,
        COUNT(*) FILTER (
            WHERE interbank_cash_rate_pct IS NULL
        ) AS interbank_cash_rate_missing,
        COUNT(*) FILTER (
            WHERE bank_bill_3m_pct IS NULL
        ) AS bank_bill_3m_missing,
        COUNT(*) FILTER (
            WHERE cash_rate_target_pct = 0
        ) AS cash_rate_target_zero,
        COUNT(*) FILTER (
            WHERE interbank_cash_rate_pct = 0
        ) AS interbank_cash_rate_zero,
        COUNT(*) FILTER (
            WHERE bank_bill_3m_pct = 0
        ) AS bank_bill_3m_zero,
        COUNT(*) FILTER (
            WHERE report_date = DATE '1969-11-30' AND bank_bill_3m_pct = 0
        ) AS bank_bill_zero_1969_11,
        COUNT(*) FILTER (
            WHERE cash_rate_target_pct < 0
               OR interbank_cash_rate_pct < 0
               OR bank_bill_3m_pct < 0
        ) AS negative_rate_rows
    FROM stg.rba_monthly_rates
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
        (4, 'cash_rate_target_missing', cash_rate_target_missing, 254),
        (5, 'interbank_cash_rate_missing', interbank_cash_rate_missing, 83),
        (6, 'bank_bill_3m_missing', bank_bill_3m_missing, 0),
        (7, 'cash_rate_target_zero', cash_rate_target_zero, 0),
        (8, 'interbank_cash_rate_zero', interbank_cash_rate_zero, 0),
        (9, 'bank_bill_3m_zero', bank_bill_3m_zero, 1),
        (10, 'bank_bill_zero_1969_11', bank_bill_zero_1969_11, 1),
        (11, 'negative_rate_rows', negative_rate_rows, 0)
) AS c(check_order, check_name, actual_count, expected_count)
ORDER BY c.check_order;
