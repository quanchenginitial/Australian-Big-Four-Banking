-- Step 4A: create the typed monthly table for the four mapped banks.
-- Prerequisites: raw.apra_madis, core.dim_bank, and the initial APRA audit.
-- Grain: one mapped bank per report month. All amounts are AUD million.
-- This creates a persistent derived table; it does not modify the raw table.
-- Sections 1-2 create the table once. Sections 3-5 are repeatable checks.
-- If the table already exists, section 2 reports an error without replacing it.

-- 1. Create the schema used for intermediate cleaned data.
CREATE SCHEMA IF NOT EXISTS stg;

-- 2. Create and populate the table from the audited raw records.
-- CAST reports an error on invalid text. Source NULLs remain NULL and are
-- checked in section 5. ABNs are identifiers and remain text.
CREATE TABLE stg.apra_big_four_monthly AS
SELECT
    b.bank_code,
    TRIM(b.bank_abn) AS bank_abn,
    b.bank_name,
    DATE '1899-12-30'
        + CAST(TRIM(r."Period") AS INTEGER) AS report_date,
    CAST(TRIM(r."Total residents assets")
        AS DECIMAL(20, 4)) AS assets_million,
    CAST(TRIM(r."Total residents loans and finance leases")
        AS DECIMAL(20, 4)) AS loans_million,
    CAST(TRIM(r."Total residents deposits")
        AS DECIMAL(20, 4)) AS deposits_million,
    CAST(TRIM(r."Loans to non-financial businesses")
        AS DECIMAL(20, 4)) AS business_loans_million,
    CAST(TRIM(r."Loans to households: Housing: Owner-occupied")
        AS DECIMAL(20, 4)) AS owner_occupied_loans_million,
    CAST(TRIM(r."Loans to households: Housing: Investment")
        AS DECIMAL(20, 4)) AS investment_loans_million,
    CAST(TRIM(r."Deposits by households")
        AS DECIMAL(20, 4)) AS household_deposits_million
FROM raw.apra_madis AS r
JOIN core.dim_bank AS b
    ON TRIM(r."ABN") = TRIM(b.bank_abn);

-- 3. Inspect the resulting types: three VARCHAR, one DATE, seven DECIMAL.
DESCRIBE stg.apra_big_four_monthly;

-- 4. Check retained rows and date coverage.
-- Expected for the audited snapshot: 356 rows, 4 banks, 89 months,
-- first_date 2019-03-31 and last_date 2026-07-31.
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT bank_code) AS bank_count,
    COUNT(DISTINCT report_date) AS month_count,
    MIN(report_date) AS first_date,
    MAX(report_date) AS last_date
FROM stg.apra_big_four_monthly;

-- 5. Check normalized bank/month duplicates and missing keys/amounts.
-- Expected: all three counts are zero. A missing_amount_rows count represents
-- rows with at least one missing selected measure, not individual values.
WITH duplicate_keys AS (
    SELECT bank_code, report_date
    FROM stg.apra_big_four_monthly
    GROUP BY bank_code, report_date
    HAVING COUNT(*) > 1
)
SELECT
    (SELECT COUNT(*) FROM duplicate_keys) AS duplicate_bank_month_keys,
    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(bank_code), '') IS NULL
           OR NULLIF(TRIM(bank_abn), '') IS NULL
           OR report_date IS NULL
    ) AS missing_key_rows,
    COUNT(*) FILTER (
        WHERE assets_million IS NULL
           OR loans_million IS NULL
           OR deposits_million IS NULL
           OR business_loans_million IS NULL
           OR owner_occupied_loans_million IS NULL
           OR investment_loans_million IS NULL
           OR household_deposits_million IS NULL
    ) AS missing_amount_rows
FROM stg.apra_big_four_monthly;
