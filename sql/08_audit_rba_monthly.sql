-- Step 5F: audit dates and three selected RBA monthly reference rates.
-- Requires raw.rba_f1_1_monthly and the two validated APRA staging tables.
-- Run each of the three sections as one complete statement.
-- All statements are read-only. Rates remain in per-cent units.

-- 1. Check dates, unique monthly keys and continuity of the raw calendar.
-- Expected: all four issue counts are zero for the pinned snapshot.
-- Only integer Excel serial text is accepted; malformed/missing dates are NULL.
WITH dates AS (
    SELECT
        CASE WHEN REGEXP_FULL_MATCH(TRIM(period_raw), '[0-9]+') THEN
            DATE '1899-12-30' + TRY_CAST(TRIM(period_raw) AS INTEGER)
        END AS report_date
    FROM raw.rba_f1_1_monthly
), duplicate_months AS (
    SELECT DATE_TRUNC('month', report_date) AS report_month
    FROM dates
    WHERE report_date IS NOT NULL
    GROUP BY report_month
    HAVING COUNT(*) > 1
), counts AS (
    SELECT
        COUNT(*) FILTER (WHERE report_date IS NULL) AS invalid_dates,
        COUNT(*) FILTER (
            WHERE report_date <> LAST_DAY(report_date)
        ) AS non_month_end_rows,
        (SELECT COUNT(*) FROM duplicate_months) AS duplicate_month_groups,
        DATE_DIFF('month', MIN(report_date), MAX(report_date)) + 1
            - COUNT(DISTINCT DATE_TRUNC('month', report_date)) AS missing_months_in_span
    FROM dates
)
SELECT c.check_name, c.issue_count
FROM counts
CROSS JOIN LATERAL (
    VALUES
        (1, 'invalid_dates', invalid_dates),
        (2, 'non_month_end_rows', non_month_end_rows),
        (3, 'duplicate_month_groups', duplicate_month_groups),
        (4, 'missing_months_in_span', missing_months_in_span)
) AS c(check_order, check_name, issue_count)
ORDER BY c.check_order;

-- 2. Audit the three selected series over all 687 imported months.
-- FIRMMCRT: cash-rate target; FIRMMCRI: interbank overnight cash rate;
-- FIRMMBAB90: three-month bank-accepted bills / negotiable certificates of deposit.
-- Expected missing counts: 254, 83 and 0 respectively.
-- The source contains one FIRMMBAB90 zero (November 1969). Preserve and flag it.
-- Zero and negative counts are diagnostic, not automatic deletion rules.
WITH value_text AS (
    SELECT
        m.series_id,
        NULLIF(TRIM(m.raw_value), '') AS rate_text
    FROM raw.rba_f1_1_monthly AS r
    CROSS JOIN LATERAL (
        VALUES
            ('FIRMMCRT', r."FIRMMCRT"),
            ('FIRMMCRI', r."FIRMMCRI"),
            ('FIRMMBAB90', r."FIRMMBAB90")
    ) AS m(series_id, raw_value)
), typed AS (
    SELECT
        series_id,
        rate_text,
        TRY_CAST(rate_text AS DECIMAL(18, 6)) AS rate_pct
    FROM value_text
)
SELECT
    series_id,
    COUNT(*) AS rows_checked,
    COUNT(*) FILTER (WHERE rate_text IS NULL) AS missing_count,
    COUNT(*) FILTER (
        WHERE rate_text IS NOT NULL AND rate_pct IS NULL
    ) AS cast_fail_count,
    COUNT(*) FILTER (WHERE rate_pct < 0) AS negative_count,
    COUNT(*) FILTER (WHERE rate_pct = 0) AS zero_count
FROM typed
GROUP BY series_id
ORDER BY series_id;

-- 3. Check the monthly inputs needed for the existing APRA analysis periods.
-- MADIS: 89 distinct months, March 2019-July 2026.
-- ADI: all three months of each of its 53 quarters, January 2013-March 2026
--      (159 distinct months), so a later quarterly average has all its inputs.
-- The APRA bank rows are deduplicated before matching monthly RBA observations.
-- This checks coverage only; it does not calculate a quarterly interest rate.
-- Expected: six rows. Each row has expected_months = matched_months =
-- numeric_months (89 for MADIS, 159 for ADI), with zero_count = 0.
WITH required_months AS (
    SELECT DISTINCT
        'MADIS_monthly' AS scope_name,
        CAST(DATE_TRUNC('month', report_date) AS DATE) AS month_start
    FROM stg.apra_big_four_monthly
    UNION ALL
    SELECT DISTINCT
        'ADI_quarterly' AS scope_name,
        CAST(
            DATE_TRUNC('quarter', report_date)
                + o.month_offset * INTERVAL '1 month'
            AS DATE
        ) AS month_start
    FROM stg.apra_big_four_quarterly
    CROSS JOIN (VALUES (0), (1), (2)) AS o(month_offset)
), selected_series AS (
    SELECT * FROM (VALUES ('FIRMMCRT'), ('FIRMMCRI'), ('FIRMMBAB90')) AS s(series_id)
), rates AS (
    SELECT
        CASE WHEN REGEXP_FULL_MATCH(TRIM(r.period_raw), '[0-9]+') THEN
            DATE '1899-12-30' + TRY_CAST(TRIM(r.period_raw) AS INTEGER)
        END AS report_date,
        m.series_id,
        TRY_CAST(NULLIF(TRIM(m.raw_value), '') AS DECIMAL(18, 6)) AS rate_pct
    FROM raw.rba_f1_1_monthly AS r
    CROSS JOIN LATERAL (
        VALUES
            ('FIRMMCRT', r."FIRMMCRT"),
            ('FIRMMCRI', r."FIRMMCRI"),
            ('FIRMMBAB90', r."FIRMMBAB90")
    ) AS m(series_id, raw_value)
)
SELECT
    m.scope_name,
    s.series_id,
    COUNT(DISTINCT m.month_start) AS expected_months,
    COUNT(r.report_date) AS matched_months,
    COUNT(r.rate_pct) AS numeric_months,
    COUNT(*) FILTER (WHERE r.rate_pct = 0) AS zero_count
FROM required_months AS m
CROSS JOIN selected_series AS s
LEFT JOIN rates AS r
    ON CAST(DATE_TRUNC('month', r.report_date) AS DATE) = m.month_start
   AND r.series_id = s.series_id
GROUP BY m.scope_name, s.series_id
ORDER BY m.scope_name, s.series_id;
