-- Step 6E: create one macro observation row per monthly banking period.
-- Requires mart.fact_bank_monthly, core.dim_date, stg.rba_monthly_rates,
-- and stg.abs_cpi_australia_monthly, with the completed source/join audits.
-- Keep all 89 bank months. Rates/changes remain per cent (3.5 = 3.5%).
-- CPI index remains an index. No bank key, scaling, averaging or NULL filling.
-- Sections 2-3 create/populate once; sections 4-7 are read-only checks.

-- 1. Ensure the schema for analytical facts exists.
CREATE SCHEMA IF NOT EXISTS mart;

-- 2. Define one required month-end key and six typed measures.
-- All required RBA months are complete in this pinned snapshot.
-- CPI fields allow NULL for unavailable months and missing published changes.
-- No database foreign key is declared; section 6 checks date references.
-- CREATE TABLE fails if the table already exists; nothing is replaced.
CREATE TABLE mart.fact_macro_monthly (
    report_date DATE PRIMARY KEY CHECK (report_date = LAST_DAY(report_date)),
    cash_rate_target_pct DECIMAL(18, 6) NOT NULL,
    interbank_cash_rate_pct DECIMAL(18, 6) NOT NULL,
    bank_bill_3m_pct DECIMAL(18, 6) NOT NULL,
    cpi_index DECIMAL(18, 6),
    cpi_yoy_pct DECIMAL(18, 6),
    cpi_mom_pct DECIMAL(18, 6)
);

-- 3. Use the banking fact's distinct months as the analysis calendar.
-- DISTINCT applies only to four banks sharing dates, not to macro source rows.
-- LEFT JOIN keeps early bank months without CPI. Source values are copied as-is.
-- The primary key rejects duplicated macro matches; required RBA NULLs fail.
-- This stored snapshot does not refresh automatically. Run INSERT once.
INSERT INTO mart.fact_macro_monthly (
    report_date, cash_rate_target_pct, interbank_cash_rate_pct, bank_bill_3m_pct,
    cpi_index, cpi_yoy_pct, cpi_mom_pct
)
WITH bank_months AS (
    SELECT DISTINCT report_date FROM mart.fact_bank_monthly
)
SELECT b.report_date, r.cash_rate_target_pct, r.interbank_cash_rate_pct,
    r.bank_bill_3m_pct, c.cpi_index, c.cpi_yoy_pct, c.cpi_mom_pct
FROM bank_months AS b
LEFT JOIN stg.rba_monthly_rates AS r ON b.report_date = r.report_date
LEFT JOIN stg.abs_cpi_australia_monthly AS c ON b.report_date = c.report_date;

-- 4. Inspect seven fields: one DATE primary key and six DECIMAL(18,6).
-- report_date and three RBA fields null NO; three CPI fields null YES.
DESCRIBE mart.fact_macro_monthly;

-- 5. Check one macro row for every required bank month.
-- Expected: 89 rows, 89 months, 2019-03-31 through 2026-07-31.
SELECT COUNT(*) AS row_count,
    COUNT(DISTINCT DATE_TRUNC('month', report_date)) AS month_count,
    MIN(report_date) AS first_date, MAX(report_date) AS last_date
FROM mart.fact_macro_monthly;

-- 6. Validate macro dates, banking coverage and preserved value patterns.
-- Expected: twenty PASS rows. CPI missing counts are 61/73/62 for index/YoY/MoM;
-- MoM negative/zero counts are 7/3. All other counts are zero.
-- These are snapshot expectations. Missing changes, negative changes and zeros
-- retain distinct meanings. The dates below are availability boundaries.
WITH bank_months AS (
    SELECT DISTINCT report_date FROM mart.fact_bank_monthly
), duplicate_months AS (
    SELECT DATE_TRUNC('month', report_date) AS report_month
    FROM mart.fact_macro_monthly
    GROUP BY report_month HAVING COUNT(*) > 1
), bank_coverage AS (
    SELECT COUNT(*) AS missing_bank_months
    FROM bank_months AS b
    WHERE NOT EXISTS (
        SELECT 1 FROM mart.fact_macro_monthly AS m WHERE m.report_date = b.report_date
    )
), bank_join AS (
    SELECT ABS(COUNT(*) - (SELECT COUNT(*) FROM mart.fact_bank_monthly))
        AS bank_join_row_difference
    FROM mart.fact_bank_monthly AS b
    LEFT JOIN mart.fact_macro_monthly AS m ON b.report_date = m.report_date
), counts AS (
    SELECT ABS(COUNT(*) - 89) AS row_count_difference,
        ABS(COUNT(DISTINCT DATE_TRUNC('month', m.report_date)) - 89) AS month_count_difference,
        (SELECT COUNT(*) FROM duplicate_months) AS duplicate_month_keys,
        COUNT(*) FILTER (WHERE m.report_date IS NULL) AS missing_date_rows,
        COUNT(*) FILTER (WHERE m.report_date <> LAST_DAY(m.report_date)) AS non_month_end_rows,
        COALESCE(DATE_DIFF('month', MIN(m.report_date), MAX(m.report_date)) + 1
            - COUNT(DISTINCT DATE_TRUNC('month', m.report_date)), 0) AS missing_months_in_span,
        CASE WHEN MIN(m.report_date) IS DISTINCT FROM DATE '2019-03-31' THEN 1 ELSE 0 END
            + CASE WHEN MAX(m.report_date) IS DISTINCT FROM DATE '2026-07-31' THEN 1 ELSE 0 END
            AS boundary_mismatches,
        (SELECT missing_bank_months FROM bank_coverage) AS missing_bank_months,
        COUNT(*) FILTER (WHERE NOT EXISTS (
            SELECT 1 FROM bank_months AS b WHERE b.report_date = m.report_date
        )) AS extra_macro_months,
        COUNT(*) FILTER (WHERE NOT EXISTS (
            SELECT 1 FROM core.dim_date AS d WHERE d.calendar_date = m.report_date
        )) AS unmatched_date_rows,
        (SELECT bank_join_row_difference FROM bank_join) AS bank_join_row_difference,
        COUNT(*) FILTER (
            WHERE m.cash_rate_target_pct IS NULL OR m.interbank_cash_rate_pct IS NULL
                OR m.bank_bill_3m_pct IS NULL
        ) AS missing_rba_value_rows,
        COUNT(*) FILTER (
            WHERE m.cash_rate_target_pct <= 0 OR m.interbank_cash_rate_pct <= 0
                OR m.bank_bill_3m_pct <= 0
        ) AS nonpositive_rba_rows,
        COUNT(*) FILTER (WHERE m.cpi_index IS NULL) AS cpi_index_missing,
        COUNT(*) FILTER (WHERE m.cpi_yoy_pct IS NULL) AS cpi_yoy_missing,
        COUNT(*) FILTER (WHERE m.cpi_mom_pct IS NULL) AS cpi_mom_missing,
        COUNT(*) FILTER (
            WHERE (m.cpi_index IS NULL) IS DISTINCT FROM (m.report_date < DATE '2024-04-30')
                OR (m.cpi_yoy_pct IS NULL) IS DISTINCT FROM (m.report_date < DATE '2025-04-30')
                OR (m.cpi_mom_pct IS NULL) IS DISTINCT FROM (m.report_date < DATE '2024-05-31')
        ) AS unexpected_cpi_null_pattern_rows,
        COUNT(*) FILTER (WHERE m.cpi_index <= 0) AS nonpositive_index_rows,
        COUNT(*) FILTER (WHERE m.cpi_mom_pct < 0) AS cpi_mom_negative,
        COUNT(*) FILTER (WHERE m.cpi_mom_pct = 0) AS cpi_mom_zero
    FROM mart.fact_macro_monthly AS m
)
SELECT c.check_name, c.actual_count, c.expected_count,
    CASE WHEN c.actual_count = c.expected_count THEN 'PASS' ELSE 'FAIL' END AS status
FROM counts
CROSS JOIN LATERAL (
    VALUES
        (1, 'row_count_difference', row_count_difference, 0),
        (2, 'month_count_difference', month_count_difference, 0),
        (3, 'duplicate_month_keys', duplicate_month_keys, 0),
        (4, 'missing_date_rows', missing_date_rows, 0),
        (5, 'non_month_end_rows', non_month_end_rows, 0),
        (6, 'missing_months_in_span', missing_months_in_span, 0),
        (7, 'boundary_mismatches', boundary_mismatches, 0),
        (8, 'missing_bank_months', missing_bank_months, 0),
        (9, 'extra_macro_months', extra_macro_months, 0),
        (10, 'unmatched_date_rows', unmatched_date_rows, 0),
        (11, 'bank_join_row_difference', bank_join_row_difference, 0),
        (12, 'missing_rba_value_rows', missing_rba_value_rows, 0),
        (13, 'nonpositive_rba_rows', nonpositive_rba_rows, 0),
        (14, 'cpi_index_missing', cpi_index_missing, 61),
        (15, 'cpi_yoy_missing', cpi_yoy_missing, 73),
        (16, 'cpi_mom_missing', cpi_mom_missing, 62),
        (17, 'unexpected_cpi_null_pattern_rows', unexpected_cpi_null_pattern_rows, 0),
        (18, 'nonpositive_index_rows', nonpositive_index_rows, 0),
        (19, 'cpi_mom_negative', cpi_mom_negative, 7),
        (20, 'cpi_mom_zero', cpi_mom_zero, 3)
) AS c(check_order, check_name, actual_count, expected_count)
ORDER BY c.check_order;

-- 7. Reconcile all seven fields against the required staging observations.
-- Expected: two PASS rows, both differences zero. EXCEPT ALL preserves
-- duplicate matches and NULL semantics; matching counts alone is insufficient.
WITH bank_months AS (
    SELECT DISTINCT report_date FROM mart.fact_bank_monthly
), expected_values AS (
    SELECT b.report_date, r.cash_rate_target_pct, r.interbank_cash_rate_pct,
        r.bank_bill_3m_pct, c.cpi_index, c.cpi_yoy_pct, c.cpi_mom_pct
    FROM bank_months AS b
    LEFT JOIN stg.rba_monthly_rates AS r ON b.report_date = r.report_date
    LEFT JOIN stg.abs_cpi_australia_monthly AS c ON b.report_date = c.report_date
), fact_values AS (
    SELECT report_date, cash_rate_target_pct, interbank_cash_rate_pct,
        bank_bill_3m_pct, cpi_index, cpi_yoy_pct, cpi_mom_pct
    FROM mart.fact_macro_monthly
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
