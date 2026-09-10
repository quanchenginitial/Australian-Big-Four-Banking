-- Step 5C: create the typed four-bank quarterly capital/liquidity table.
-- Requires raw.apra_adi_quarterly, core.dim_bank and the completed 05 audit.
-- Run sections 1-5 in order. Section 2 creates the table once; it does not
-- replace an existing table. Sections 3-5 are repeatable read-only checks.
-- Amounts remain AUD millions. Ratios remain fractions (0.124 = 12.4%).
-- Preserve missing liquidity values as NULL. This consolidated quarterly
-- source has a different reporting scope from the monthly MADIS source.

-- 1. Ensure the staging schema exists.
CREATE SCHEMA IF NOT EXISTS stg;

-- 2. Create one row per mapped bank and publication quarter.
-- CAST rejects invalid nonblank numeric text; NULLIF preserves blank values.
-- Keep both publication and entity dates, even though they match in this
-- audited four-bank snapshot. The framework label records the source's
-- 2023 reporting change; it does not adjust values for comparability.
CREATE TABLE stg.apra_big_four_quarterly AS
WITH typed AS (
    SELECT
        b.bank_code,
        TRIM(b.bank_abn) AS bank_abn,
        b.bank_name,
        DATE '1899-12-30'
            + CAST(TRIM(r."Period") AS INTEGER) AS report_date,
        DATE '1899-12-30'
            + CAST(TRIM(r."Entity quarter end") AS INTEGER) AS entity_quarter_end,
        CAST(NULLIF(TRIM(r."Total Common Equity Tier 1 capital"), '')
            AS DECIMAL(20, 4)) AS cet1_capital_million,
        CAST(NULLIF(TRIM(r."Total Tier 1 capital"), '')
            AS DECIMAL(20, 4)) AS tier1_capital_million,
        CAST(NULLIF(TRIM(r."Total capital base"), '')
            AS DECIMAL(20, 4)) AS total_capital_million,
        CAST(NULLIF(TRIM(r."Total risk-weighted assets"), '')
            AS DECIMAL(20, 4)) AS rwa_million,
        CAST(NULLIF(TRIM(r."Common Equity Tier 1 capital ratio"), '')
            AS DECIMAL(18, 6)) AS cet1_ratio,
        CAST(NULLIF(TRIM(r."Tier 1 capital ratio"), '')
            AS DECIMAL(18, 6)) AS tier1_ratio,
        CAST(NULLIF(TRIM(r."Total capital ratio"), '')
            AS DECIMAL(18, 6)) AS total_capital_ratio,
        CAST(NULLIF(TRIM(r."Mean Liquidity coverage ratio (LCR)"), '')
            AS DECIMAL(18, 6)) AS lcr_ratio,
        CAST(NULLIF(TRIM(r."Net stable funding ratio (NSFR)"), '')
            AS DECIMAL(18, 6)) AS nsfr_ratio,
        CAST(NULLIF(TRIM(r."Average Minimum liquidity holdings ratio (MLH)"), '')
            AS DECIMAL(18, 6)) AS mlh_ratio
    FROM raw.apra_adi_quarterly AS r
    JOIN core.dim_bank AS b
        ON TRIM(r."ABN") = TRIM(b.bank_abn)
)
SELECT
    typed.*,
    CASE
        WHEN report_date < DATE '2023-01-01' THEN 'Basel III (2013-2022)'
        ELSE 'ADI capital framework (2023+)'
    END AS capital_framework
FROM typed;

-- 3. Check all 16 columns and their types.
-- Expected: four VARCHAR, two DATE, four DECIMAL(20,4), six DECIMAL(18,6).
DESCRIBE stg.apra_big_four_quarterly;

-- 4. Check the table size and publication-date range.
-- Expected: 212 rows, 4 banks, 53 quarters, 2013-03-31 to 2026-03-31.
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT bank_code) AS bank_count,
    COUNT(DISTINCT report_date) AS quarter_count,
    MIN(report_date) AS first_date,
    MAX(report_date) AS last_date
FROM stg.apra_big_four_quarterly;

-- 5. Verify keys, required capital values and preserved liquidity blanks.
-- Expected counts apply to this pinned 2013Q1-2026Q1 snapshot only.
-- LCR/NSFR: 20 missing early quarters per bank, then 33 populated quarters.
-- MLH: no observations for these four banks. All seven checks should PASS.
WITH duplicate_keys AS (
    SELECT bank_code, report_date
    FROM stg.apra_big_four_quarterly
    GROUP BY bank_code, report_date
    HAVING COUNT(*) > 1
), counts AS (
    SELECT
        (SELECT COUNT(*) FROM duplicate_keys) AS duplicate_keys,
        COUNT(*) FILTER (
            WHERE NULLIF(TRIM(bank_code), '') IS NULL
               OR NULLIF(TRIM(bank_abn), '') IS NULL
               OR report_date IS NULL
               OR entity_quarter_end IS NULL
        ) AS missing_keys,
        COUNT(*) FILTER (
            WHERE cet1_capital_million IS NULL
               OR tier1_capital_million IS NULL
               OR total_capital_million IS NULL
               OR rwa_million IS NULL
               OR cet1_ratio IS NULL
               OR tier1_ratio IS NULL
               OR total_capital_ratio IS NULL
        ) AS missing_capital,
        COUNT(*) FILTER (WHERE lcr_ratio IS NULL) AS missing_lcr,
        COUNT(*) FILTER (WHERE nsfr_ratio IS NULL) AS missing_nsfr,
        COUNT(*) FILTER (WHERE mlh_ratio IS NULL) AS missing_mlh,
        COUNT(*) FILTER (
            WHERE (report_date < DATE '2018-01-01'
                   AND (lcr_ratio IS NOT NULL OR nsfr_ratio IS NOT NULL))
               OR (report_date >= DATE '2018-01-01'
                   AND (lcr_ratio IS NULL OR nsfr_ratio IS NULL))
        ) AS unexpected_liquidity_pattern
    FROM stg.apra_big_four_quarterly
)
SELECT
    c.check_name,
    c.actual_count,
    c.expected_count,
    CASE WHEN c.actual_count = c.expected_count THEN 'PASS' ELSE 'FAIL' END AS status
FROM counts
CROSS JOIN LATERAL (
    VALUES
        (1, 'duplicate_bank_quarter_keys', duplicate_keys, 0),
        (2, 'missing_key_rows', missing_keys, 0),
        (3, 'missing_capital_rows', missing_capital, 0),
        (4, 'lcr_missing_rows', missing_lcr, 80),
        (5, 'nsfr_missing_rows', missing_nsfr, 80),
        (6, 'mlh_missing_rows', missing_mlh, 212),
        (7, 'unexpected_liquidity_pattern_rows', unexpected_liquidity_pattern, 0)
) AS c(check_order, check_name, actual_count, expected_count)
ORDER BY c.check_order;
