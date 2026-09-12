-- Step 5N: audit quarterly dates and the two Australia CPI measures.
-- Requires raw.abs_cpi_table17_quarterly and stg.apra_big_four_quarterly.
-- Run each of the five sections as one complete statement. All are read-only.
-- City measures remain in raw; this numeric audit selects Australia only.
-- Expectations refer to the pinned July 2026 workbook, ending in June quarter.

-- 1. Check source labels, quarterly keys and continuity.
-- Expected: four issue counts of zero. Source labels must be day 1 of
-- March, June, September or December, NOT the first day of the quarter.
-- Malformed/missing/out-of-range Excel serials become NULL without aborting.
-- The span check returns 1 if there are no valid dates. Check snapshot
-- endpoints and the 312-quarter total using section 5 of the import script.
WITH dates AS (
    SELECT
        CASE WHEN REGEXP_FULL_MATCH(TRIM(period_raw), '[0-9]+')
            AND TRY_CAST(TRIM(period_raw) AS INTEGER) BETWEEN 0
                AND DATE_DIFF('day', DATE '1899-12-30', DATE '9999-12-31') THEN
            TRY(DATE '1899-12-30' + TRY_CAST(TRIM(period_raw) AS INTEGER))
        END AS source_quarter
    FROM raw.abs_cpi_table17_quarterly
), duplicate_quarters AS (
    SELECT DATE_TRUNC('quarter', source_quarter) AS quarter_start
    FROM dates
    WHERE source_quarter IS NOT NULL
    GROUP BY quarter_start
    HAVING COUNT(*) > 1
), counts AS (
    SELECT
        COUNT(*) FILTER (WHERE source_quarter IS NULL) AS invalid_dates,
        COUNT(*) FILTER (
            WHERE DAY(source_quarter) <> 1
               OR MONTH(source_quarter) NOT IN (3, 6, 9, 12)
        ) AS non_quarter_label_rows,
        (SELECT COUNT(*) FROM duplicate_quarters) AS duplicate_quarter_groups,
        COALESCE(
            DATE_DIFF('quarter', MIN(source_quarter), MAX(source_quarter)) + 1
                - COUNT(DISTINCT DATE_TRUNC('quarter', source_quarter)),
            1
        ) AS missing_quarters_in_span
    FROM dates
)
SELECT c.check_name, c.issue_count
FROM counts
CROSS JOIN LATERAL (
    VALUES
        (1, 'invalid_dates', invalid_dates),
        (2, 'non_quarter_label_rows', non_quarter_label_rows),
        (3, 'duplicate_quarter_groups', duplicate_quarter_groups),
        (4, 'missing_quarters_in_span', missing_quarters_in_span)
) AS c(check_order, check_name, issue_count)
ORDER BY c.check_order;

-- 2. Profile Australia index and published quarter-on-quarter change.
-- Expected rows_checked: 312 each; cast_fail_count: zero for both.
-- index: missing 0, negative 0, zero 0.
-- QoQ:   missing 1, negative 12, zero 24.
-- Negative changes and zeros are retained observations, not automatic errors.
WITH value_text AS (
    SELECT
        m.metric,
        NULLIF(TRIM(m.raw_value), '') AS value_text
    FROM raw.abs_cpi_table17_quarterly AS r
    CROSS JOIN LATERAL (
        VALUES
            ('cpi_index', r."A2325846C"),
            ('cpi_qoq_pct', r."A2325850V")
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

-- 3. Check missing-value positions and index validity.
-- Expected: three issue counts of zero. Index is populated throughout.
-- QoQ is blank ONLY for September quarter 1948, the first observation.
-- Nonblank conversion failures are reported in section 2, not as blanks.
-- Do not replace published QoQ with a calculation from rounded index numbers.
WITH values_clean AS (
    SELECT
        CASE WHEN REGEXP_FULL_MATCH(TRIM(period_raw), '[0-9]+')
            AND TRY_CAST(TRIM(period_raw) AS INTEGER) BETWEEN 0
                AND DATE_DIFF('day', DATE '1899-12-30', DATE '9999-12-31') THEN
            TRY(DATE '1899-12-30' + TRY_CAST(TRIM(period_raw) AS INTEGER))
        END AS source_quarter,
        NULLIF(TRIM("A2325846C"), '') AS index_text,
        NULLIF(TRIM("A2325850V"), '') AS qoq_text
    FROM raw.abs_cpi_table17_quarterly
), counts AS (
    SELECT
        COUNT(*) FILTER (WHERE index_text IS NULL) AS missing_index_rows,
        COUNT(*) FILTER (
            WHERE (source_quarter = DATE '1948-09-01' AND qoq_text IS NOT NULL)
               OR (source_quarter <> DATE '1948-09-01' AND qoq_text IS NULL)
        ) AS unexpected_qoq_null_pattern,
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
        (2, 'unexpected_qoq_null_pattern', unexpected_qoq_null_pattern),
        (3, 'nonpositive_index_rows', nonpositive_index_rows)
) AS c(check_order, check_name, issue_count)
ORDER BY c.check_order;

-- 4. Check quarterly CPI coverage across the APRA ADI analysis period.
-- Deduplicate the bank quarters before joining national CPI.
-- Expected for BOTH metrics: required 53, matched 53, numeric 53, unavailable 0.
-- These are 2013Q1-2026Q1. CPI's additional 2026Q2 is outside this scope.
-- Invalid source labels do not match. Matched/numeric row counts expose
-- duplicate inflation; unavailable_quarters counts distinct required quarters.
-- Read together with sections 1-3. This checks dates and availability only;
-- it does not merge financial reporting scopes or fill monthly CPI gaps.
WITH required_quarters AS (
    SELECT DISTINCT
        CAST(DATE_TRUNC('quarter', report_date) AS DATE) AS quarter_start
    FROM stg.apra_big_four_quarterly
), selected_metrics AS (
    SELECT * FROM (
        VALUES ('cpi_index'), ('cpi_qoq_pct')
    ) AS m(metric)
), cpi AS (
    SELECT
        CASE WHEN REGEXP_FULL_MATCH(TRIM(r.period_raw), '[0-9]+')
            AND TRY_CAST(TRIM(r.period_raw) AS INTEGER) BETWEEN 0
                AND DATE_DIFF('day', DATE '1899-12-30', DATE '9999-12-31') THEN
            TRY(DATE '1899-12-30' + TRY_CAST(TRIM(r.period_raw) AS INTEGER))
        END AS source_quarter,
        m.metric,
        TRY_CAST(NULLIF(TRIM(m.raw_value), '') AS DECIMAL(18, 6)) AS numeric_value
    FROM raw.abs_cpi_table17_quarterly AS r
    CROSS JOIN LATERAL (
        VALUES
            ('cpi_index', r."A2325846C"),
            ('cpi_qoq_pct', r."A2325850V")
    ) AS m(metric, raw_value)
)
SELECT
    'ADI_quarterly' AS scope_name,
    m.metric,
    COUNT(DISTINCT r.quarter_start) AS required_quarters,
    COUNT(c.source_quarter) AS matched_quarters,
    COUNT(c.numeric_value) AS numeric_quarters,
    COUNT(DISTINCT r.quarter_start)
        - COUNT(DISTINCT r.quarter_start) FILTER (
            WHERE c.numeric_value IS NOT NULL
        ) AS unavailable_quarters
FROM required_quarters AS r
CROSS JOIN selected_metrics AS m
LEFT JOIN cpi AS c
    ON CAST(DATE_TRUNC('quarter', c.source_quarter) AS DATE) = r.quarter_start
   AND DAY(c.source_quarter) = 1
   AND MONTH(c.source_quarter) IN (3, 6, 9, 12)
   AND c.metric = m.metric
GROUP BY m.metric
ORDER BY m.metric;

-- 5. Recheck the latest five Australia observations.
-- source_quarter is still the source label, not a staged quarter-end date.
-- QoQ remains per cent: 0.6 means 0.6%. Table 17 has no published YoY column.
-- The index reference is September MONTH 2025 = 100.00;
-- September QUARTER 2025 has index 99.73 in this snapshot.
SELECT
    CASE WHEN REGEXP_FULL_MATCH(TRIM(period_raw), '[0-9]+')
        AND TRY_CAST(TRIM(period_raw) AS INTEGER) BETWEEN 0
            AND DATE_DIFF('day', DATE '1899-12-30', DATE '9999-12-31') THEN
        TRY(DATE '1899-12-30' + TRY_CAST(TRIM(period_raw) AS INTEGER))
    END AS source_quarter,
    TRY_CAST(NULLIF(TRIM("A2325846C"), '') AS DECIMAL(18, 6)) AS cpi_index,
    TRY_CAST(NULLIF(TRIM("A2325850V"), '') AS DECIMAL(18, 6)) AS cpi_qoq_pct
FROM raw.abs_cpi_table17_quarterly
ORDER BY source_quarter DESC NULLS LAST
LIMIT 5;
