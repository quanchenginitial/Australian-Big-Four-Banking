-- Step 5J: audit monthly dates and three Australia CPI measures.
-- Requires raw.abs_cpi_table1_monthly and both APRA staging tables.
-- Run each of the four sections as one complete statement. All are read-only.
-- City measures remain in raw; this numeric audit selects Australia only.

-- 1. Check source dates, monthly keys and continuity.
-- Expected: four issue counts of zero. Source dates must be MONTH STARTS.
-- Accept integer Excel serial text only; malformed/missing dates become NULL.
WITH dates AS (
    SELECT
        CASE WHEN REGEXP_FULL_MATCH(TRIM(period_raw), '[0-9]+') THEN
            DATE '1899-12-30' + TRY_CAST(TRIM(period_raw) AS INTEGER)
        END AS source_month
    FROM raw.abs_cpi_table1_monthly
), duplicate_months AS (
    SELECT DATE_TRUNC('month', source_month) AS month_start
    FROM dates
    WHERE source_month IS NOT NULL
    GROUP BY month_start
    HAVING COUNT(*) > 1
), counts AS (
    SELECT
        COUNT(*) FILTER (WHERE source_month IS NULL) AS invalid_dates,
        COUNT(*) FILTER (
            WHERE source_month <> CAST(DATE_TRUNC('month', source_month) AS DATE)
        ) AS non_month_start_rows,
        (SELECT COUNT(*) FROM duplicate_months) AS duplicate_month_groups,
        DATE_DIFF('month', MIN(source_month), MAX(source_month)) + 1
            - COUNT(DISTINCT DATE_TRUNC('month', source_month)) AS missing_months_in_span
    FROM dates
)
SELECT c.check_name, c.issue_count
FROM counts
CROSS JOIN LATERAL (
    VALUES
        (1, 'invalid_dates', invalid_dates),
        (2, 'non_month_start_rows', non_month_start_rows),
        (3, 'duplicate_month_groups', duplicate_month_groups),
        (4, 'missing_months_in_span', missing_months_in_span)
) AS c(check_order, check_name, issue_count)
ORDER BY c.check_order;

-- 2. Profile Australia index, year-on-year and month-on-month changes.
-- Expected rows_checked: 28 for each measure; cast_fail_count: all zero.
-- index: missing 0, negative 0, zero 0.
-- YoY:   missing 12, negative 0, zero 0.
-- MoM:   missing 1, negative 7, zero 3.
-- Negative changes and zeros are retained observations, not automatic errors.
WITH value_text AS (
    SELECT
        m.metric,
        NULLIF(TRIM(m.raw_value), '') AS value_text
    FROM raw.abs_cpi_table1_monthly AS r
    CROSS JOIN LATERAL (
        VALUES
            ('cpi_index', r."A130393720C"),
            ('cpi_yoy_pct', r."A130393721F"),
            ('cpi_mom_pct', r."A130393722J")
    ) AS m(metric, raw_value)
), typed AS (
    SELECT
        metric,
        value_text,
        TRY_CAST(value_text AS DECIMAL(18, 6)) AS numeric_value
    FROM value_text
)
SELECT
    metric,
    COUNT(*) AS rows_checked,
    COUNT(*) FILTER (WHERE value_text IS NULL) AS missing_count,
    COUNT(*) FILTER (
        WHERE value_text IS NOT NULL AND numeric_value IS NULL
    ) AS cast_fail_count,
    COUNT(*) FILTER (WHERE numeric_value < 0) AS negative_count,
    COUNT(*) FILTER (WHERE numeric_value = 0) AS zero_count
FROM typed
GROUP BY metric
ORDER BY metric;

-- 3. Verify that missing values occur in the expected part of this snapshot.
-- Expected: four issue counts of zero. This checks positions, not just totals.
-- Index is populated throughout. YoY is NULL before April 2025; MoM before May 2024.
-- Nonblank conversion failures are reported by section 2, not counted as blanks.
-- This uses pinned coverage dates; review them if changing the source snapshot.
WITH values_clean AS (
    SELECT
        CASE WHEN REGEXP_FULL_MATCH(TRIM(period_raw), '[0-9]+') THEN
            DATE '1899-12-30' + TRY_CAST(TRIM(period_raw) AS INTEGER)
        END AS source_month,
        NULLIF(TRIM("A130393720C"), '') AS index_text,
        NULLIF(TRIM("A130393721F"), '') AS yoy_text,
        NULLIF(TRIM("A130393722J"), '') AS mom_text
    FROM raw.abs_cpi_table1_monthly
), counts AS (
    SELECT
        COUNT(*) FILTER (WHERE index_text IS NULL) AS missing_index_rows,
        COUNT(*) FILTER (
            WHERE (source_month < DATE '2025-04-01' AND yoy_text IS NOT NULL)
               OR (source_month >= DATE '2025-04-01' AND yoy_text IS NULL)
        ) AS unexpected_yoy_null_pattern,
        COUNT(*) FILTER (
            WHERE (source_month < DATE '2024-05-01' AND mom_text IS NOT NULL)
               OR (source_month >= DATE '2024-05-01' AND mom_text IS NULL)
        ) AS unexpected_mom_null_pattern,
        COUNT(*) FILTER (
            WHERE TRY_CAST(index_text AS DECIMAL(18, 6)) <= 0
        ) AS nonpositive_index_rows
    FROM values_clean
)
SELECT c.check_name, c.issue_count
FROM counts
CROSS JOIN LATERAL (
    VALUES
        (1, 'missing_index_rows', missing_index_rows),
        (2, 'unexpected_yoy_null_pattern', unexpected_yoy_null_pattern),
        (3, 'unexpected_mom_null_pattern', unexpected_mom_null_pattern),
        (4, 'nonpositive_index_rows', nonpositive_index_rows)
) AS c(check_order, check_name, issue_count)
ORDER BY c.check_order;

-- 4. Describe available CPI inputs across the APRA analysis periods.
-- Deduplicate bank/months first. ADI requires all three months of each quarter.
-- This is a monthly coverage diagnostic, not a quarterly CPI calculation.
-- MADIS: required 89, matched 28; numeric index/YoY/MoM = 28/16/27.
-- ADI: required 159, matched 24; numeric index/YoY/MoM = 24/12/23.
-- unavailable_months includes missing source months and nonnumeric/blank values.
-- Expected early unavailability is not an import error and must not be filled.
-- Counts of matched/numeric rows expose duplicate inflation; unavailable_months
-- counts distinct required months. Read this together with sections 1-3.
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
), selected_metrics AS (
    SELECT * FROM (
        VALUES ('cpi_index'), ('cpi_yoy_pct'), ('cpi_mom_pct')
    ) AS m(metric)
), cpi AS (
    SELECT
        CASE WHEN REGEXP_FULL_MATCH(TRIM(r.period_raw), '[0-9]+') THEN
            DATE '1899-12-30' + TRY_CAST(TRIM(r.period_raw) AS INTEGER)
        END AS source_month,
        m.metric,
        TRY_CAST(NULLIF(TRIM(m.raw_value), '') AS DECIMAL(18, 6)) AS numeric_value
    FROM raw.abs_cpi_table1_monthly AS r
    CROSS JOIN LATERAL (
        VALUES
            ('cpi_index', r."A130393720C"),
            ('cpi_yoy_pct', r."A130393721F"),
            ('cpi_mom_pct', r."A130393722J")
    ) AS m(metric, raw_value)
)
SELECT
    r.scope_name,
    m.metric,
    COUNT(DISTINCT r.month_start) AS required_months,
    COUNT(c.source_month) AS matched_months,
    COUNT(c.numeric_value) AS numeric_months,
    COUNT(DISTINCT r.month_start)
        - COUNT(DISTINCT r.month_start) FILTER (
            WHERE c.numeric_value IS NOT NULL
        ) AS unavailable_months
FROM required_months AS r
CROSS JOIN selected_metrics AS m
LEFT JOIN cpi AS c
    ON CAST(DATE_TRUNC('month', c.source_month) AS DATE) = r.month_start
   AND c.metric = m.metric
GROUP BY r.scope_name, m.metric
ORDER BY r.scope_name, m.metric;
