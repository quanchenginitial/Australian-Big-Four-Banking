-- Step 6F: create one macro observation row per quarterly banking period.
-- Requires mart.fact_bank_quarterly, core.dim_date, stg.rba_monthly_rates,
-- and stg.abs_cpi_australia_quarterly. All 53 required quarters were preflighted.
-- RBA quarterly means are project-derived equal-weight means of three monthly
-- averages, not official quarterly series, daily-weighted means or spot rates.
-- Retain per-cent rates/changes and the published quarterly CPI index/QoQ.
-- Sections 2-3 create/populate once; sections 4-7 are read-only checks.

-- 1. Ensure the analytical schema exists.
CREATE SCHEMA IF NOT EXISTS mart;

-- 2. Define the quarter-end key and five DECIMAL(18,6) measures.
-- RBA means allow NULL so incomplete inputs preserve the quarter and any other
-- complete rates. Section 6 must flag such incompleteness in this snapshot.
-- Both quarterly CPI measures are required for this fully covered bank window.
-- No database foreign key is declared; section 6 checks the date reference.
CREATE TABLE mart.fact_macro_quarterly (
    report_date DATE PRIMARY KEY CHECK (
        report_date = LAST_DAY(DATE_TRUNC('quarter', report_date) + INTERVAL '2 months')
    ),
    cash_rate_target_qtr_mean_pct DECIMAL(18, 6),
    interbank_cash_rate_qtr_mean_pct DECIMAL(18, 6),
    bank_bill_3m_qtr_mean_pct DECIMAL(18, 6),
    cpi_index DECIMAL(18, 6) NOT NULL,
    cpi_qoq_pct DECIMAL(18, 6) NOT NULL
);

-- 3. Derive guarded RBA means and copy quarterly CPI for each bank quarter.
-- Exactly three rows, three distinct months, three month-end labels and three
-- non-NULL values are required separately for each rate. No partial averages.
-- DISTINCT applies only to bank dates. Preserve all required quarters with
-- LEFT JOINs; do not average monthly CPI changes or recalculate published QoQ.
-- This stored snapshot does not refresh automatically. Run INSERT once.
INSERT INTO mart.fact_macro_quarterly (
    report_date, cash_rate_target_qtr_mean_pct,
    interbank_cash_rate_qtr_mean_pct, bank_bill_3m_qtr_mean_pct, cpi_index, cpi_qoq_pct
)
WITH bank_quarters AS (
    SELECT DISTINCT report_date FROM mart.fact_bank_quarterly
), rba_quarters AS (
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
)
SELECT q.report_date, r.cash_rate_target_qtr_mean_pct,
    r.interbank_cash_rate_qtr_mean_pct, r.bank_bill_3m_qtr_mean_pct,
    c.cpi_index, c.cpi_qoq_pct
FROM bank_quarters AS q
LEFT JOIN rba_quarters AS r ON q.report_date = r.report_date
LEFT JOIN stg.abs_cpi_australia_quarterly AS c ON q.report_date = c.report_date;

-- 4. Inspect six fields: one DATE primary key and five DECIMAL(18,6).
-- Date/CPI fields null NO; three RBA means null YES, though all are populated now.
DESCRIBE mart.fact_macro_quarterly;

-- 5. Check the required banking-quarter history.
-- Expected: 53 rows, 53 quarters, 2013-03-31 through 2026-03-31.
SELECT COUNT(*) AS row_count,
    COUNT(DISTINCT DATE_TRUNC('quarter', report_date)) AS quarter_count,
    MIN(report_date) AS first_date, MAX(report_date) AS last_date
FROM mart.fact_macro_quarterly;

-- 6. Validate dates, source completeness and retained bank-quarter coverage.
-- Expected: seventeen PASS rows, all issue counts zero.
-- RBA nullable schema is intentional; this snapshot must contain no NULL rates.
-- Positive rates/index describe the pinned window. QoQ negatives/zeros are valid.
WITH bank_quarters AS (
    SELECT DISTINCT report_date FROM mart.fact_bank_quarterly
), rba_quarters AS (
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
), duplicate_quarters AS (
    SELECT DATE_TRUNC('quarter', report_date) AS report_quarter
    FROM mart.fact_macro_quarterly
    GROUP BY report_quarter HAVING COUNT(*) > 1
), bank_coverage AS (
    SELECT COUNT(*) AS missing_bank_quarters FROM bank_quarters AS q
    WHERE NOT EXISTS (
        SELECT 1 FROM mart.fact_macro_quarterly AS m WHERE m.report_date = q.report_date
    )
), bank_join AS (
    SELECT ABS(COUNT(*) - (SELECT COUNT(*) FROM mart.fact_bank_quarterly))
        AS bank_join_row_difference
    FROM mart.fact_bank_quarterly AS b
    LEFT JOIN mart.fact_macro_quarterly AS m ON b.report_date = m.report_date
), rate_coverage AS (
    SELECT COUNT(*) FILTER (
        WHERE r.report_date IS NULL OR r.source_month_rows <> 3
            OR r.distinct_source_months <> 3 OR r.valid_month_labels <> 3
            OR r.cash_rate_target_qtr_mean_pct IS NULL
            OR r.interbank_cash_rate_qtr_mean_pct IS NULL
            OR r.bank_bill_3m_qtr_mean_pct IS NULL
    ) AS incomplete_rba_quarters
    FROM bank_quarters AS q LEFT JOIN rba_quarters AS r ON q.report_date = r.report_date
), cpi_coverage AS (
    SELECT COUNT(*) AS unmatched_cpi_quarters FROM bank_quarters AS q
    WHERE NOT EXISTS (
        SELECT 1 FROM stg.abs_cpi_australia_quarterly AS c WHERE c.report_date = q.report_date
    )
), counts AS (
    SELECT ABS(COUNT(*) - 53) AS row_count_difference,
        ABS(COUNT(DISTINCT DATE_TRUNC('quarter', m.report_date)) - 53) AS quarter_count_difference,
        (SELECT COUNT(*) FROM duplicate_quarters) AS duplicate_quarter_keys,
        COUNT(*) FILTER (WHERE m.report_date IS NULL) AS missing_date_rows,
        COUNT(*) FILTER (WHERE m.report_date <>
            LAST_DAY(DATE_TRUNC('quarter', m.report_date) + INTERVAL '2 months')
        ) AS non_quarter_end_rows,
        COALESCE(DATE_DIFF('quarter', MIN(m.report_date), MAX(m.report_date)) + 1
            - COUNT(DISTINCT DATE_TRUNC('quarter', m.report_date)), 0) AS missing_quarters_in_span,
        CASE WHEN MIN(m.report_date) IS DISTINCT FROM DATE '2013-03-31' THEN 1 ELSE 0 END
            + CASE WHEN MAX(m.report_date) IS DISTINCT FROM DATE '2026-03-31' THEN 1 ELSE 0 END
            AS boundary_mismatches,
        (SELECT missing_bank_quarters FROM bank_coverage) AS missing_bank_quarters,
        COUNT(*) FILTER (WHERE NOT EXISTS (
            SELECT 1 FROM bank_quarters AS q WHERE q.report_date = m.report_date
        )) AS extra_macro_quarters,
        COUNT(*) FILTER (WHERE NOT EXISTS (
            SELECT 1 FROM core.dim_date AS d WHERE d.calendar_date = m.report_date
        )) AS unmatched_date_rows,
        (SELECT bank_join_row_difference FROM bank_join) AS bank_join_row_difference,
        (SELECT incomplete_rba_quarters FROM rate_coverage) AS incomplete_rba_quarters,
        COUNT(*) FILTER (
            WHERE m.cash_rate_target_qtr_mean_pct IS NULL
                OR m.interbank_cash_rate_qtr_mean_pct IS NULL OR m.bank_bill_3m_qtr_mean_pct IS NULL
        ) AS missing_rba_value_rows,
        COUNT(*) FILTER (
            WHERE m.cash_rate_target_qtr_mean_pct <= 0
                OR m.interbank_cash_rate_qtr_mean_pct <= 0 OR m.bank_bill_3m_qtr_mean_pct <= 0
        ) AS nonpositive_rba_rows,
        (SELECT unmatched_cpi_quarters FROM cpi_coverage) AS unmatched_cpi_quarters,
        COUNT(*) FILTER (WHERE m.cpi_index IS NULL OR m.cpi_qoq_pct IS NULL) AS missing_cpi_value_rows,
        COUNT(*) FILTER (WHERE m.cpi_index <= 0) AS nonpositive_index_rows
    FROM mart.fact_macro_quarterly AS m
)
SELECT c.check_name, c.actual_count, 0 AS expected_count,
    CASE WHEN c.actual_count = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM counts
CROSS JOIN LATERAL (
    VALUES
        (1, 'row_count_difference', row_count_difference),
        (2, 'quarter_count_difference', quarter_count_difference),
        (3, 'duplicate_quarter_keys', duplicate_quarter_keys),
        (4, 'missing_date_rows', missing_date_rows),
        (5, 'non_quarter_end_rows', non_quarter_end_rows),
        (6, 'missing_quarters_in_span', missing_quarters_in_span),
        (7, 'boundary_mismatches', boundary_mismatches),
        (8, 'missing_bank_quarters', missing_bank_quarters),
        (9, 'extra_macro_quarters', extra_macro_quarters),
        (10, 'unmatched_date_rows', unmatched_date_rows),
        (11, 'bank_join_row_difference', bank_join_row_difference),
        (12, 'incomplete_rba_quarters', incomplete_rba_quarters),
        (13, 'missing_rba_value_rows', missing_rba_value_rows),
        (14, 'nonpositive_rba_rows', nonpositive_rba_rows),
        (15, 'unmatched_cpi_quarters', unmatched_cpi_quarters),
        (16, 'missing_cpi_value_rows', missing_cpi_value_rows),
        (17, 'nonpositive_index_rows', nonpositive_index_rows)
) AS c(check_order, check_name, actual_count)
ORDER BY c.check_order;

-- 7. Reconcile all six fields with guarded rate means and source quarterly CPI.
-- Expected: two PASS rows, both differences zero. EXCEPT ALL retains NULL
-- semantics and multiplicity. Read with section 6: correctly retained NULL
-- rates still require investigation when required source inputs are incomplete.
WITH bank_quarters AS (
    SELECT DISTINCT report_date FROM mart.fact_bank_quarterly
), rba_quarters AS (
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
), expected_values AS (
SELECT q.report_date, r.cash_rate_target_qtr_mean_pct,
    r.interbank_cash_rate_qtr_mean_pct, r.bank_bill_3m_qtr_mean_pct,
    c.cpi_index, c.cpi_qoq_pct
FROM bank_quarters AS q
LEFT JOIN rba_quarters AS r ON q.report_date = r.report_date
LEFT JOIN stg.abs_cpi_australia_quarterly AS c ON q.report_date = c.report_date
), fact_values AS (
    SELECT report_date, cash_rate_target_qtr_mean_pct,
    interbank_cash_rate_qtr_mean_pct, bank_bill_3m_qtr_mean_pct, cpi_index, cpi_qoq_pct
    FROM mart.fact_macro_quarterly
), expected_minus_fact AS (
    SELECT * FROM expected_values EXCEPT ALL SELECT * FROM fact_values
), fact_minus_expected AS (
    SELECT * FROM fact_values EXCEPT ALL SELECT * FROM expected_values
), counts AS (
    SELECT 1 AS check_order, 'expected_minus_fact_rows' AS check_name,
        COUNT(*) AS actual_count FROM expected_minus_fact
    UNION ALL
    SELECT 2, 'fact_minus_expected_rows', COUNT(*) FROM fact_minus_expected
)
SELECT check_name, actual_count, 0 AS expected_count,
    CASE WHEN actual_count = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM counts ORDER BY check_order;
