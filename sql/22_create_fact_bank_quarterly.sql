-- Step 6D: create the quarterly bank fact at bank/publication-quarter grain.
-- Requires stg.apra_big_four_quarterly, core.dim_bank and core.dim_date.
-- Preserve 212 observations, both dates, ten measures and the framework label.
-- Amounts remain AUD millions; ratios remain fractions (0.124 = 12.4%).
-- Sections 2-3 create/populate once; sections 4-7 are repeatable read-only checks.

-- 1. Ensure the schema for analytical facts exists.
CREATE SCHEMA IF NOT EXISTS mart;

-- 2. Define the fact with a composite primary key and a quarter-end check.
-- Only the three liquidity ratios allow NULL, preserving source unavailability.
-- No dimension foreign keys are declared; section 6 checks both references.
-- CREATE TABLE fails if the fact already exists; nothing is replaced.
CREATE TABLE mart.fact_bank_quarterly (
    bank_code VARCHAR NOT NULL,
    report_date DATE NOT NULL CHECK (
        report_date = LAST_DAY(DATE_TRUNC('quarter', report_date) + INTERVAL '2 months')
    ),
    entity_quarter_end DATE NOT NULL,
    cet1_capital_million DECIMAL(20, 4) NOT NULL,
    tier1_capital_million DECIMAL(20, 4) NOT NULL,
    total_capital_million DECIMAL(20, 4) NOT NULL,
    rwa_million DECIMAL(20, 4) NOT NULL,
    cet1_ratio DECIMAL(18, 6) NOT NULL,
    tier1_ratio DECIMAL(18, 6) NOT NULL,
    total_capital_ratio DECIMAL(18, 6) NOT NULL,
    lcr_ratio DECIMAL(18, 6),
    nsfr_ratio DECIMAL(18, 6),
    mlh_ratio DECIMAL(18, 6),
    capital_framework VARCHAR NOT NULL,
    PRIMARY KEY (bank_code, report_date)
);

-- 3. Copy the audited fields directly from quarterly staging.
-- No joins, filters, grouping, ratio calculations, scaling or NULL filling.
-- Preserve the separate entity date and the existing framework-period label.
-- This stored snapshot does not refresh automatically when staging changes.
-- Run once; the primary key rejects a repeated insertion.
INSERT INTO mart.fact_bank_quarterly (
    bank_code, report_date, entity_quarter_end,
    cet1_capital_million, tier1_capital_million, total_capital_million, rwa_million,
    cet1_ratio, tier1_ratio, total_capital_ratio, lcr_ratio, nsfr_ratio, mlh_ratio,
    capital_framework
)
SELECT bank_code, report_date, entity_quarter_end,
    cet1_capital_million, tier1_capital_million, total_capital_million, rwa_million,
    cet1_ratio, tier1_ratio, total_capital_ratio, lcr_ratio, nsfr_ratio, mlh_ratio,
    capital_framework
FROM stg.apra_big_four_quarterly;

-- 4. Inspect all fourteen fields.
-- Two VARCHAR, two DATE, four DECIMAL(20,4), six DECIMAL(18,6).
-- bank_code/report_date both PRI; only lcr_ratio/nsfr_ratio/mlh_ratio null YES.
DESCRIBE mart.fact_bank_quarterly;

-- 5. Check the retained quarterly history.
-- Expected: 212 rows, four banks, 53 quarters, 2013-03-31 through 2026-03-31.
SELECT COUNT(*) AS row_count, COUNT(DISTINCT bank_code) AS bank_count,
    COUNT(DISTINCT report_date) AS quarter_count,
    MIN(report_date) AS first_date, MAX(report_date) AS last_date
FROM mart.fact_bank_quarterly;

-- 6. Validate grain, dimensional references and the pinned source patterns.
-- Expected: twenty-one PASS rows. LCR/NSFR/MLH missing counts are 80/80/212;
-- all other counts are zero. Read actual_count against expected_count.
-- LCR/NSFR are absent through 2017 and populated from 2018Q1 for every bank.
-- Framework labels mark the source's 2023 change; they do not adjust values.
WITH duplicate_fact_keys AS (
    SELECT bank_code, DATE_TRUNC('quarter', report_date) AS report_quarter
    FROM mart.fact_bank_quarterly
    GROUP BY bank_code, report_quarter HAVING COUNT(*) > 1
), bank_calendars AS (
    SELECT bank_code FROM mart.fact_bank_quarterly
    GROUP BY bank_code
    HAVING COUNT(*) <> 53 OR COUNT(DISTINCT report_date) <> 53
        OR MIN(report_date) IS DISTINCT FROM DATE '2013-03-31'
        OR MAX(report_date) IS DISTINCT FROM DATE '2026-03-31'
), duplicate_dimension_keys AS (
    SELECT bank_code FROM core.dim_bank
    GROUP BY bank_code HAVING COUNT(*) > 1
), dimension_stats AS (
    SELECT ABS(COUNT(*) - 4) AS bank_dimension_row_difference,
        COUNT(*) FILTER (
            WHERE NULLIF(TRIM(bank_code), '') IS NULL
                OR NULLIF(TRIM(bank_abn), '') IS NULL
                OR NULLIF(TRIM(bank_name), '') IS NULL
        ) AS invalid_bank_dimension_rows
    FROM core.dim_bank
), lookup_rows AS (
    SELECT COUNT(*) AS joined_rows
    FROM mart.fact_bank_quarterly AS f
    LEFT JOIN core.dim_bank AS b ON f.bank_code = b.bank_code
    LEFT JOIN core.dim_date AS d ON f.report_date = d.calendar_date
), bank_metadata AS (
    SELECT COUNT(*) AS bank_attribute_mismatch_rows
    FROM stg.apra_big_four_quarterly AS s
    JOIN core.dim_bank AS b ON s.bank_code = b.bank_code
    WHERE s.bank_abn IS DISTINCT FROM b.bank_abn
        OR s.bank_name IS DISTINCT FROM b.bank_name
), counts AS (
    SELECT ABS(COUNT(*) - 212) AS row_count_difference,
        ABS(COUNT(DISTINCT f.bank_code) - 4) AS bank_count_difference,
        (SELECT COUNT(*) FROM duplicate_fact_keys) AS duplicate_bank_quarter_keys,
        (SELECT COUNT(*) FROM bank_calendars) AS bank_calendar_mismatches,
        COUNT(*) FILTER (
            WHERE NULLIF(TRIM(f.bank_code), '') IS NULL OR f.report_date IS NULL
                OR f.entity_quarter_end IS NULL OR NULLIF(TRIM(f.capital_framework), '') IS NULL
                OR f.cet1_capital_million IS NULL OR f.tier1_capital_million IS NULL
                OR f.total_capital_million IS NULL OR f.rwa_million IS NULL
                OR f.cet1_ratio IS NULL OR f.tier1_ratio IS NULL OR f.total_capital_ratio IS NULL
        ) AS missing_required_values_rows,
        COUNT(*) FILTER (WHERE f.report_date <>
            LAST_DAY(DATE_TRUNC('quarter', f.report_date) + INTERVAL '2 months')
        ) AS non_quarter_end_rows,
        COUNT(*) FILTER (
            WHERE f.entity_quarter_end IS DISTINCT FROM f.report_date
        ) AS entity_date_mismatch_rows,
        COUNT(*) FILTER (WHERE NOT EXISTS (
            SELECT 1 FROM core.dim_bank AS b WHERE f.bank_code = b.bank_code
        )) AS unmatched_bank_rows,
        COUNT(*) FILTER (WHERE NOT EXISTS (
            SELECT 1 FROM core.dim_date AS d WHERE f.report_date = d.calendar_date
        )) AS unmatched_date_rows,
        (SELECT COUNT(*) FROM duplicate_dimension_keys) AS duplicate_bank_dimension_keys,
        (SELECT bank_dimension_row_difference FROM dimension_stats) AS bank_dimension_row_difference,
        (SELECT invalid_bank_dimension_rows FROM dimension_stats) AS invalid_bank_dimension_rows,
        ABS((SELECT joined_rows FROM lookup_rows) - COUNT(*)) AS lookup_join_row_difference,
        (SELECT bank_attribute_mismatch_rows FROM bank_metadata) AS bank_attribute_mismatch_rows,
        COUNT(*) FILTER (
            WHERE f.cet1_capital_million <= 0 OR f.tier1_capital_million <= 0
                OR f.total_capital_million <= 0 OR f.rwa_million <= 0
                OR f.cet1_ratio <= 0 OR f.tier1_ratio <= 0 OR f.total_capital_ratio <= 0
        ) AS nonpositive_capital_rows,
        COUNT(*) FILTER (
            WHERE f.lcr_ratio <= 0 OR f.nsfr_ratio <= 0 OR f.mlh_ratio <= 0
        ) AS nonpositive_liquidity_rows,
        COUNT(*) FILTER (WHERE f.lcr_ratio IS NULL) AS lcr_missing_rows,
        COUNT(*) FILTER (WHERE f.nsfr_ratio IS NULL) AS nsfr_missing_rows,
        COUNT(*) FILTER (WHERE f.mlh_ratio IS NULL) AS mlh_missing_rows,
        COUNT(*) FILTER (
            WHERE (f.report_date < DATE '2018-01-01'
                AND (f.lcr_ratio IS NOT NULL OR f.nsfr_ratio IS NOT NULL))
                OR (f.report_date >= DATE '2018-01-01'
                AND (f.lcr_ratio IS NULL OR f.nsfr_ratio IS NULL))
        ) AS unexpected_liquidity_pattern_rows,
        COUNT(*) FILTER (
            WHERE f.capital_framework IS DISTINCT FROM CASE
                WHEN f.report_date < DATE '2023-01-01' THEN 'Basel III (2013-2022)'
                ELSE 'ADI capital framework (2023+)' END
        ) AS capital_framework_mismatch_rows
    FROM mart.fact_bank_quarterly AS f
)
SELECT c.check_name, c.actual_count, c.expected_count,
    CASE WHEN c.actual_count = c.expected_count THEN 'PASS' ELSE 'FAIL' END AS status
FROM counts
CROSS JOIN LATERAL (
    VALUES
        (1, 'row_count_difference', row_count_difference, 0),
        (2, 'bank_count_difference', bank_count_difference, 0),
        (3, 'duplicate_bank_quarter_keys', duplicate_bank_quarter_keys, 0),
        (4, 'bank_calendar_mismatches', bank_calendar_mismatches, 0),
        (5, 'missing_required_values_rows', missing_required_values_rows, 0),
        (6, 'non_quarter_end_rows', non_quarter_end_rows, 0),
        (7, 'entity_date_mismatch_rows', entity_date_mismatch_rows, 0),
        (8, 'unmatched_bank_rows', unmatched_bank_rows, 0),
        (9, 'unmatched_date_rows', unmatched_date_rows, 0),
        (10, 'duplicate_bank_dimension_keys', duplicate_bank_dimension_keys, 0),
        (11, 'bank_dimension_row_difference', bank_dimension_row_difference, 0),
        (12, 'invalid_bank_dimension_rows', invalid_bank_dimension_rows, 0),
        (13, 'lookup_join_row_difference', lookup_join_row_difference, 0),
        (14, 'bank_attribute_mismatch_rows', bank_attribute_mismatch_rows, 0),
        (15, 'nonpositive_capital_rows', nonpositive_capital_rows, 0),
        (16, 'nonpositive_liquidity_rows', nonpositive_liquidity_rows, 0),
        (17, 'lcr_missing_rows', lcr_missing_rows, 80),
        (18, 'nsfr_missing_rows', nsfr_missing_rows, 80),
        (19, 'mlh_missing_rows', mlh_missing_rows, 212),
        (20, 'unexpected_liquidity_pattern_rows', unexpected_liquidity_pattern_rows, 0),
        (21, 'capital_framework_mismatch_rows', capital_framework_mismatch_rows, 0)
) AS c(check_order, check_name, actual_count, expected_count)
ORDER BY c.check_order;

-- 7. Compare every retained field with staging in both directions.
-- Expected: two PASS rows, both differences zero. EXCEPT ALL preserves
-- multiplicity and checks the location of NULLs as well as dates and values.
WITH staged_values AS (
    SELECT bank_code, report_date, entity_quarter_end,
        cet1_capital_million, tier1_capital_million, total_capital_million, rwa_million,
        cet1_ratio, tier1_ratio, total_capital_ratio, lcr_ratio, nsfr_ratio, mlh_ratio,
        capital_framework
    FROM stg.apra_big_four_quarterly
), fact_values AS (
    SELECT bank_code, report_date, entity_quarter_end,
        cet1_capital_million, tier1_capital_million, total_capital_million, rwa_million,
        cet1_ratio, tier1_ratio, total_capital_ratio, lcr_ratio, nsfr_ratio, mlh_ratio,
        capital_framework
    FROM mart.fact_bank_quarterly
), staging_minus_fact AS (
    SELECT * FROM staged_values EXCEPT ALL SELECT * FROM fact_values
), fact_minus_staging AS (
    SELECT * FROM fact_values EXCEPT ALL SELECT * FROM staged_values
), counts AS (
    SELECT 1 AS check_order, 'staging_minus_fact_rows' AS check_name,
        COUNT(*) AS actual_count FROM staging_minus_fact
    UNION ALL
    SELECT 2, 'fact_minus_staging_rows', COUNT(*) FROM fact_minus_staging
)
SELECT check_name, actual_count, 0 AS expected_count,
    CASE WHEN actual_count = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM counts ORDER BY check_order;
