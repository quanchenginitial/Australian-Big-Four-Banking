-- Step 6B: create the shared daily date dimension for the initial bank model.
-- Initial scope: complete calendar years 2013-2026 (5113 days).
-- Sections 2 and 3 create/populate the table once; sections 4-7 are read-only.
-- Section 7 requires the two confirmed APRA staging tables.
-- This does not create facts, extend source observations or fill macro values.

-- 1. Ensure the core schema exists.
CREATE SCHEMA IF NOT EXISTS core;

-- 2. Define the date key and required calendar attributes.
-- A primary key enforces unique, non-NULL calendar_date values.
-- CREATE TABLE fails if core.dim_date already exists; no table is replaced.
CREATE TABLE core.dim_date (
    calendar_date DATE PRIMARY KEY,
    calendar_year SMALLINT NOT NULL,
    quarter_number TINYINT NOT NULL,
    month_number TINYINT NOT NULL,
    month_name VARCHAR NOT NULL,
    year_quarter VARCHAR NOT NULL,
    year_quarter_sort INTEGER NOT NULL,
    year_month VARCHAR NOT NULL,
    year_month_sort INTEGER NOT NULL,
    month_end_date DATE NOT NULL,
    quarter_end_date DATE NOT NULL,
    is_month_end BOOLEAN NOT NULL,
    is_quarter_end BOOLEAN NOT NULL
);

-- 3. Insert one row for every day, including weekends and leap days.
-- Run once after section 2. Repeating INSERT is rejected by the primary key.
-- The inclusive timestamp series is explicitly converted to DATE.
-- Calendar quarters follow January-March, April-June, July-September,
-- October-December; these are not bank-specific financial-year periods.
INSERT INTO core.dim_date (
    calendar_date, calendar_year, quarter_number, month_number, month_name,
    year_quarter, year_quarter_sort, year_month, year_month_sort,
    month_end_date, quarter_end_date, is_month_end, is_quarter_end
)
WITH days AS (
    SELECT CAST(generate_series AS DATE) AS calendar_date
    FROM generate_series(DATE '2013-01-01', DATE '2026-12-31', INTERVAL '1 day')
), calendar_parts AS (
    SELECT calendar_date,
        CAST(YEAR(calendar_date) AS SMALLINT) AS calendar_year,
        CAST(QUARTER(calendar_date) AS TINYINT) AS quarter_number,
        CAST(MONTH(calendar_date) AS TINYINT) AS month_number,
        LAST_DAY(calendar_date) AS month_end_date,
        LAST_DAY(DATE_TRUNC('quarter', calendar_date) + INTERVAL '2 months') AS quarter_end_date
    FROM days
)
SELECT calendar_date, calendar_year, quarter_number, month_number,
    STRFTIME(calendar_date, '%B') AS month_name,
    CONCAT(calendar_year, ' Q', quarter_number) AS year_quarter,
    CAST(calendar_year AS INTEGER) * 10 + quarter_number AS year_quarter_sort,
    STRFTIME(calendar_date, '%Y-%m') AS year_month,
    CAST(calendar_year AS INTEGER) * 100 + month_number AS year_month_sort,
    month_end_date, quarter_end_date,
    calendar_date = month_end_date AS is_month_end,
    calendar_date = quarter_end_date AS is_quarter_end
FROM calendar_parts;

-- 4. Inspect the thirteen fields and constraints.
-- calendar_date: DATE, null NO, key PRI; every other field: null NO.
DESCRIBE core.dim_date;

-- 5. Check the complete initial calendar.
-- Expected: 5113 dates, 2013-01-01 to 2026-12-31, 14 years, 168 months, 56 quarters.
SELECT COUNT(*) AS day_count,
    MIN(calendar_date) AS first_date, MAX(calendar_date) AS last_date,
    COUNT(DISTINCT calendar_year) AS year_count,
    COUNT(DISTINCT year_month) AS month_count,
    COUNT(DISTINCT year_quarter) AS quarter_count
FROM core.dim_date;

-- 6. Validate continuity, labels, sort keys, period ends and leap days.
-- Expected: thirteen PASS rows. Counts 168/56/3 are expected calendar features.
WITH duplicate_dates AS (
    SELECT calendar_date FROM core.dim_date
    GROUP BY calendar_date HAVING COUNT(*) > 1
), counts AS (
    SELECT ABS(COUNT(*) - 5113) AS row_count_difference,
        (SELECT COUNT(*) FROM duplicate_dates) AS duplicate_date_keys,
        COALESCE(DATE_DIFF('day', MIN(calendar_date), MAX(calendar_date)) + 1
            - COUNT(DISTINCT calendar_date), 1) AS missing_dates_in_span,
        CAST(MIN(calendar_date) IS DISTINCT FROM DATE '2013-01-01' AS INTEGER)
            + CAST(MAX(calendar_date) IS DISTINCT FROM DATE '2026-12-31' AS INTEGER) AS boundary_mismatches,
        COUNT(*) FILTER (
            WHERE calendar_year <> YEAR(calendar_date)
                OR quarter_number <> QUARTER(calendar_date)
                OR month_number <> MONTH(calendar_date)
        ) AS date_attribute_mismatches,
        COUNT(*) FILTER (
            WHERE month_name <> STRFTIME(calendar_date, '%B')
                OR year_quarter <> CONCAT(YEAR(calendar_date), ' Q', QUARTER(calendar_date))
                OR year_month <> STRFTIME(calendar_date, '%Y-%m')
        ) AS label_mismatches,
        COUNT(*) FILTER (
            WHERE year_quarter_sort <> YEAR(calendar_date) * 10 + QUARTER(calendar_date)
                OR year_month_sort <> YEAR(calendar_date) * 100 + MONTH(calendar_date)
        ) AS sort_key_mismatches,
        COUNT(*) FILTER (
            WHERE month_end_date <> LAST_DAY(calendar_date)
                OR quarter_end_date <> LAST_DAY(DATE_TRUNC('quarter', calendar_date) + INTERVAL '2 months')
        ) AS period_end_date_mismatches,
        COUNT(*) FILTER (
            WHERE is_month_end IS DISTINCT FROM (calendar_date = LAST_DAY(calendar_date))
                OR is_quarter_end IS DISTINCT FROM
                    (calendar_date = LAST_DAY(calendar_date) AND MONTH(calendar_date) IN (3, 6, 9, 12))
        ) AS period_end_flag_mismatches,
        COUNT(*) FILTER (
            WHERE calendar_date IS NULL OR calendar_year IS NULL OR quarter_number IS NULL
                OR month_number IS NULL OR month_name IS NULL OR year_quarter IS NULL
                OR year_quarter_sort IS NULL OR year_month IS NULL OR year_month_sort IS NULL
                OR month_end_date IS NULL OR quarter_end_date IS NULL
                OR is_month_end IS NULL OR is_quarter_end IS NULL
        ) AS null_attribute_rows,
        COUNT(*) FILTER (WHERE is_month_end) AS month_end_rows,
        COUNT(*) FILTER (WHERE is_quarter_end) AS quarter_end_rows,
        COUNT(*) FILTER (WHERE MONTH(calendar_date) = 2 AND DAY(calendar_date) = 29) AS leap_day_rows
    FROM core.dim_date
)
SELECT c.check_name, c.actual_count, c.expected_count,
    CASE WHEN c.actual_count = c.expected_count THEN 'PASS' ELSE 'FAIL' END AS status
FROM counts
CROSS JOIN LATERAL (
    VALUES
        (1, 'row_count_difference', row_count_difference, 0),
        (2, 'duplicate_date_keys', duplicate_date_keys, 0),
        (3, 'missing_dates_in_span', missing_dates_in_span, 0),
        (4, 'boundary_mismatches', boundary_mismatches, 0),
        (5, 'date_attribute_mismatches', date_attribute_mismatches, 0),
        (6, 'label_mismatches', label_mismatches, 0),
        (7, 'sort_key_mismatches', sort_key_mismatches, 0),
        (8, 'period_end_date_mismatches', period_end_date_mismatches, 0),
        (9, 'period_end_flag_mismatches', period_end_flag_mismatches, 0),
        (10, 'null_attribute_rows', null_attribute_rows, 0),
        (11, 'month_end_rows', month_end_rows, 168),
        (12, 'quarter_end_rows', quarter_end_rows, 56),
        (13, 'leap_day_rows', leap_day_rows, 3)
) AS c(check_order, check_name, actual_count, expected_count)
ORDER BY c.check_order;

-- 7. Verify all date keys required by the initial model and quarterly rate inputs.
-- Expected: five PASS rows, required/matched rows 356, 212, 89, 53, 159.
-- Macro scopes use planned bank-driven keys; no macro facts are created here.
-- Rate-input scope generates the three month ends required by each ADI quarter;
-- script 19 separately checked the availability and completeness of their rates.
-- Join facts to calendar_date only. Repeated month_end_date/quarter_end_date
-- attributes describe each day and are not unique relationship keys.
WITH bank_months AS (
    SELECT DISTINCT report_date FROM stg.apra_big_four_monthly
), bank_quarters AS (
    SELECT DISTINCT report_date FROM stg.apra_big_four_quarterly
), required_keys AS (
    SELECT 'bank_monthly' AS scope_name, report_date, 'month' AS period_type
    FROM stg.apra_big_four_monthly
    UNION ALL
    SELECT 'bank_quarterly', report_date, 'quarter' FROM stg.apra_big_four_quarterly
    UNION ALL
    SELECT 'macro_monthly', report_date, 'month' FROM bank_months
    UNION ALL
    SELECT 'macro_quarterly', report_date, 'quarter' FROM bank_quarters
    UNION ALL
    SELECT 'quarterly_rate_inputs',
        LAST_DAY(DATE_TRUNC('quarter', q.report_date) + m.month_offset * INTERVAL '1 month'),
        'month'
    FROM bank_quarters AS q
    CROSS JOIN (VALUES (0), (1), (2)) AS m(month_offset)
), coverage AS (
    SELECT r.scope_name, COUNT(*) AS required_rows,
        COUNT(d.calendar_date) AS matched_rows,
        COUNT(*) FILTER (WHERE d.calendar_date IS NULL) AS unmatched_rows,
        COUNT(*) FILTER (
            WHERE d.calendar_date IS NOT NULL
                AND ((r.period_type = 'month' AND NOT d.is_month_end)
                    OR (r.period_type = 'quarter' AND NOT d.is_quarter_end))
        ) AS wrong_period_flags
    FROM required_keys AS r
    LEFT JOIN core.dim_date AS d ON r.report_date = d.calendar_date
    GROUP BY r.scope_name
), expected(check_order, scope_name, expected_rows) AS (
    VALUES (1, 'bank_monthly', 356), (2, 'bank_quarterly', 212),
        (3, 'macro_monthly', 89), (4, 'macro_quarterly', 53), (5, 'quarterly_rate_inputs', 159)
)
SELECT e.scope_name, COALESCE(c.required_rows, 0) AS required_rows,
    COALESCE(c.matched_rows, 0) AS matched_rows,
    COALESCE(c.unmatched_rows, 0) AS unmatched_rows,
    COALESCE(c.wrong_period_flags, 0) AS wrong_period_flags,
    CASE WHEN c.required_rows = e.expected_rows AND c.matched_rows = e.expected_rows
            AND c.unmatched_rows = 0 AND c.wrong_period_flags = 0
        THEN 'PASS' ELSE 'FAIL' END AS status
FROM expected AS e LEFT JOIN coverage AS c ON e.scope_name = c.scope_name
ORDER BY e.check_order;
