-- Step 6A: check analysis grains and proposed date joins before creating marts.
-- Requires the six confirmed staging tables. Three read-only statements.
-- These temporary joins test cardinality/coverage; they do not create model tables.
-- Planned Power BI facts keep bank and macro observations at separate grains.
-- Expected snapshot results: section 1 six PASS; section 2 nine PASS;
-- section 3 ten PASS. Preserve known missing CPI observations.

-- 1. Confirm keys, period labels and retained history for all six inputs.
-- invalid_key_rows includes missing keys and incorrect month/quarter-end labels.
-- PASS also checks the pinned row/period counts and first/last dates.
WITH input_keys AS (
    SELECT 'MADIS_monthly' AS input_name, bank_code AS entity_key,
        report_date, 'month' AS frequency FROM stg.apra_big_four_monthly
    UNION ALL
    SELECT 'ADI_quarterly', bank_code, report_date, 'quarter'
    FROM stg.apra_big_four_quarterly
    UNION ALL
    SELECT 'RBA_monthly', 'Australia', report_date, 'month'
    FROM stg.rba_monthly_rates
    UNION ALL
    SELECT 'CPI_headline_monthly', 'Australia', report_date, 'month'
    FROM stg.abs_cpi_australia_monthly
    UNION ALL
    SELECT 'CPI_headline_quarterly', 'Australia', report_date, 'quarter'
    FROM stg.abs_cpi_australia_quarterly
    UNION ALL
    SELECT 'CPI_detail_quarterly', series_id, report_date, 'quarter'
    FROM stg.abs_cpi_australia_quarterly_detail
), duplicate_keys AS (
    SELECT input_name, entity_key, report_date
    FROM input_keys
    GROUP BY input_name, entity_key, report_date
    HAVING COUNT(*) > 1
), duplicates AS (
    SELECT input_name, COUNT(*) AS duplicate_key_groups
    FROM duplicate_keys GROUP BY input_name
), observed AS (
    SELECT input_name, COUNT(*) AS row_count,
        COUNT(DISTINCT report_date) AS period_count,
        MIN(report_date) AS first_date, MAX(report_date) AS last_date,
        COUNT(*) FILTER (
            WHERE NULLIF(TRIM(entity_key), '') IS NULL OR report_date IS NULL
                OR report_date <> LAST_DAY(report_date)
                OR (frequency = 'quarter' AND MONTH(report_date) NOT IN (3, 6, 9, 12))
        ) AS invalid_key_rows
    FROM input_keys GROUP BY input_name
), expected(check_order, input_name, expected_rows, expected_periods, first_date, last_date) AS (
    VALUES
        (1, 'MADIS_monthly', 356, 89, DATE '2019-03-31', DATE '2026-07-31'),
        (2, 'ADI_quarterly', 212, 53, DATE '2013-03-31', DATE '2026-03-31'),
        (3, 'RBA_monthly', 687, 687, DATE '1969-06-30', DATE '2026-08-31'),
        (4, 'CPI_headline_monthly', 28, 28, DATE '2024-04-30', DATE '2026-07-31'),
        (5, 'CPI_headline_quarterly', 312, 312, DATE '1948-09-30', DATE '2026-06-30'),
        (6, 'CPI_detail_quarterly', 123552, 312, DATE '1948-09-30', DATE '2026-06-30')
)
SELECT e.input_name,
    COALESCE(o.row_count, 0) AS row_count,
    COALESCE(o.period_count, 0) AS period_count,
    COALESCE(d.duplicate_key_groups, 0) AS duplicate_key_groups,
    COALESCE(o.invalid_key_rows, 0) AS invalid_key_rows,
    CASE WHEN o.row_count = e.expected_rows AND o.period_count = e.expected_periods
            AND o.first_date = e.first_date AND o.last_date = e.last_date
            AND o.invalid_key_rows = 0 AND COALESCE(d.duplicate_key_groups, 0) = 0
        THEN 'PASS' ELSE 'FAIL' END AS status
FROM expected AS e
LEFT JOIN observed AS o ON e.input_name = o.input_name
LEFT JOIN duplicates AS d ON e.input_name = d.input_name
ORDER BY e.check_order;

-- 2. Trial monthly LEFT JOINs on the exact month-end report_date.
-- Keep all 356 bank-month rows. RBA is complete over the 89 required months.
-- CPI covers 28 of 89 months: 61 x 4 = 244 bank rows have no CPI month.
-- CPI YoY is unavailable for 73 x 4 = 292 rows; MoM for 62 x 4 = 248 rows.
-- These are bank-row counts, not distinct missing macro months or errors.
-- Do not use an INNER JOIN that discards the earlier banking history.
WITH joined AS (
    SELECT b.bank_code, b.report_date,
        r.report_date AS rba_date, c.report_date AS cpi_date,
        r.cash_rate_target_pct, r.interbank_cash_rate_pct, r.bank_bill_3m_pct,
        c.cpi_index, c.cpi_yoy_pct, c.cpi_mom_pct
    FROM stg.apra_big_four_monthly AS b
    LEFT JOIN stg.rba_monthly_rates AS r ON b.report_date = r.report_date
    LEFT JOIN stg.abs_cpi_australia_monthly AS c ON b.report_date = c.report_date
), duplicate_keys AS (
    SELECT bank_code, report_date FROM joined
    GROUP BY bank_code, report_date HAVING COUNT(*) > 1
), counts AS (
    SELECT
        (SELECT COUNT(*) FROM stg.apra_big_four_monthly) AS bank_rows_before,
        COUNT(*) AS bank_rows_after,
        (SELECT COUNT(*) FROM duplicate_keys) AS duplicate_joined_keys,
        COUNT(*) FILTER (WHERE rba_date IS NULL) AS unmatched_rba_rows,
        COUNT(*) FILTER (WHERE cash_rate_target_pct IS NULL
            OR interbank_cash_rate_pct IS NULL OR bank_bill_3m_pct IS NULL) AS missing_rba_value_rows,
        COUNT(*) FILTER (WHERE cpi_date IS NULL) AS unmatched_cpi_rows,
        COUNT(*) FILTER (WHERE cpi_index IS NULL) AS cpi_index_unavailable_rows,
        COUNT(*) FILTER (WHERE cpi_yoy_pct IS NULL) AS cpi_yoy_unavailable_rows,
        COUNT(*) FILTER (WHERE cpi_mom_pct IS NULL) AS cpi_mom_unavailable_rows
    FROM joined
)
SELECT c.check_name, c.actual_count, c.expected_count,
    CASE WHEN c.actual_count = c.expected_count THEN 'PASS' ELSE 'FAIL' END AS status
FROM counts
CROSS JOIN LATERAL (
    VALUES
        (1, 'bank_rows_before', bank_rows_before, 356),
        (2, 'bank_rows_after', bank_rows_after, 356),
        (3, 'duplicate_joined_keys', duplicate_joined_keys, 0),
        (4, 'unmatched_rba_rows', unmatched_rba_rows, 0),
        (5, 'missing_rba_value_rows', missing_rba_value_rows, 0),
        (6, 'unmatched_cpi_rows', unmatched_cpi_rows, 244),
        (7, 'cpi_index_unavailable_rows', cpi_index_unavailable_rows, 244),
        (8, 'cpi_yoy_unavailable_rows', cpi_yoy_unavailable_rows, 292),
        (9, 'cpi_mom_unavailable_rows', cpi_mom_unavailable_rows, 248)
) AS c(check_order, check_name, actual_count, expected_count)
ORDER BY c.check_order;

-- 3. Trial quarterly rate derivation and exact quarter-end LEFT JOINs.
-- Project definition: equal-weight mean of the quarter's three monthly averages.
-- It is not an official RBA quarterly series, a daily-weighted quarterly mean,
-- or a quarter-end spot rate. Retain per-cent units and six decimal places.
-- AVG ignores NULLs: require exactly three rows, three distinct valid months
-- and three numeric observations for EACH rate before calculating that rate.
-- Incomplete inputs return NULL; another complete rate can still be retained.
-- For the 53 ADI quarters, all three derived rates and Table 17 CPI are complete.
-- The joins must preserve all 212 bank-quarter rows without duplicate keys.
WITH rba_quarters AS (
    SELECT
        LAST_DAY(DATE_TRUNC('quarter', report_date) + INTERVAL '2 months') AS report_date,
        COUNT(*) AS source_month_rows,
        COUNT(DISTINCT DATE_TRUNC('month', report_date)) AS distinct_source_months,
        COUNT(*) FILTER (WHERE report_date = LAST_DAY(report_date)) AS valid_month_labels,
        CASE WHEN COUNT(*) = 3
                AND COUNT(DISTINCT DATE_TRUNC('month', report_date)) = 3
                AND COUNT(*) FILTER (WHERE report_date = LAST_DAY(report_date)) = 3
                AND COUNT(cash_rate_target_pct) = 3
            THEN CAST(AVG(cash_rate_target_pct) AS DECIMAL(18, 6)) END AS cash_rate_target_qtr_mean_pct,
        CASE WHEN COUNT(*) = 3
                AND COUNT(DISTINCT DATE_TRUNC('month', report_date)) = 3
                AND COUNT(*) FILTER (WHERE report_date = LAST_DAY(report_date)) = 3
                AND COUNT(interbank_cash_rate_pct) = 3
            THEN CAST(AVG(interbank_cash_rate_pct) AS DECIMAL(18, 6)) END AS interbank_cash_rate_qtr_mean_pct,
        CASE WHEN COUNT(*) = 3
                AND COUNT(DISTINCT DATE_TRUNC('month', report_date)) = 3
                AND COUNT(*) FILTER (WHERE report_date = LAST_DAY(report_date)) = 3
                AND COUNT(bank_bill_3m_pct) = 3
            THEN CAST(AVG(bank_bill_3m_pct) AS DECIMAL(18, 6)) END AS bank_bill_3m_qtr_mean_pct
    FROM stg.rba_monthly_rates
    GROUP BY LAST_DAY(DATE_TRUNC('quarter', report_date) + INTERVAL '2 months')
), required_quarters AS (
    SELECT DISTINCT report_date FROM stg.apra_big_four_quarterly
), rate_coverage AS (
    SELECT COUNT(*) FILTER (
        WHERE r.report_date IS NULL OR r.source_month_rows <> 3
            OR r.distinct_source_months <> 3 OR r.valid_month_labels <> 3
            OR r.cash_rate_target_qtr_mean_pct IS NULL
            OR r.interbank_cash_rate_qtr_mean_pct IS NULL
            OR r.bank_bill_3m_qtr_mean_pct IS NULL
    ) AS incomplete_rba_quarters
    FROM required_quarters AS q LEFT JOIN rba_quarters AS r ON q.report_date = r.report_date
), joined AS (
    SELECT b.bank_code, b.report_date,
        r.report_date AS rba_date, c.report_date AS cpi_date,
        r.cash_rate_target_qtr_mean_pct, r.interbank_cash_rate_qtr_mean_pct,
        r.bank_bill_3m_qtr_mean_pct, c.cpi_index, c.cpi_qoq_pct
    FROM stg.apra_big_four_quarterly AS b
    LEFT JOIN rba_quarters AS r ON b.report_date = r.report_date
    LEFT JOIN stg.abs_cpi_australia_quarterly AS c ON b.report_date = c.report_date
), duplicate_keys AS (
    SELECT bank_code, report_date FROM joined
    GROUP BY bank_code, report_date HAVING COUNT(*) > 1
), counts AS (
    SELECT
        (SELECT COUNT(*) FROM required_quarters) AS required_quarters,
        (SELECT incomplete_rba_quarters FROM rate_coverage) AS incomplete_rba_quarters,
        (SELECT COUNT(*) FROM stg.apra_big_four_quarterly) AS bank_rows_before,
        COUNT(*) AS bank_rows_after,
        (SELECT COUNT(*) FROM duplicate_keys) AS duplicate_joined_keys,
        COUNT(*) FILTER (WHERE rba_date IS NULL) AS unmatched_rba_quarter_rows,
        COUNT(*) FILTER (WHERE cash_rate_target_qtr_mean_pct IS NULL
            OR interbank_cash_rate_qtr_mean_pct IS NULL
            OR bank_bill_3m_qtr_mean_pct IS NULL) AS missing_rba_value_rows,
        COUNT(*) FILTER (WHERE cpi_date IS NULL) AS unmatched_cpi_quarter_rows,
        COUNT(*) FILTER (WHERE cpi_index IS NULL) AS cpi_index_unavailable_rows,
        COUNT(*) FILTER (WHERE cpi_qoq_pct IS NULL) AS cpi_qoq_unavailable_rows
    FROM joined
)
SELECT c.check_name, c.actual_count, c.expected_count,
    CASE WHEN c.actual_count = c.expected_count THEN 'PASS' ELSE 'FAIL' END AS status
FROM counts
CROSS JOIN LATERAL (
    VALUES
        (1, 'required_quarters', required_quarters, 53),
        (2, 'incomplete_rba_quarters', incomplete_rba_quarters, 0),
        (3, 'bank_rows_before', bank_rows_before, 212),
        (4, 'bank_rows_after', bank_rows_after, 212),
        (5, 'duplicate_joined_keys', duplicate_joined_keys, 0),
        (6, 'unmatched_rba_quarter_rows', unmatched_rba_quarter_rows, 0),
        (7, 'missing_rba_value_rows', missing_rba_value_rows, 0),
        (8, 'unmatched_cpi_quarter_rows', unmatched_cpi_quarter_rows, 0),
        (9, 'cpi_index_unavailable_rows', cpi_index_unavailable_rows, 0),
        (10, 'cpi_qoq_unavailable_rows', cpi_qoq_unavailable_rows, 0)
) AS c(check_order, check_name, actual_count, expected_count)
ORDER BY c.check_order;
