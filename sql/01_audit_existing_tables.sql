-- Initial APRA MADIS audit, verified on 2026-09-10 with DuckDB v1.5.5.
-- Prerequisites: existing raw.apra_madis and core.dim_bank tables.
-- Read-only: run each statement in DBeaver using the project connection.
-- Source snapshot: 01_APRA_MADIS_Backseries_Mar2019_Jul2026.xlsx.
-- Financial amounts are in AUD million; Period uses Excel's 1900 date system.
-- Results and scope: docs/apra_initial_audit.md.

-- 1. Inspect the imported table and the existing bank mapping.
SELECT COUNT(*) AS row_count
FROM raw.apra_madis;

DESCRIBE raw.apra_madis;

SELECT *
FROM core.dim_bank
LIMIT 10;

-- 2. Inspect sample values before choosing conversion rules.
SELECT
    "Period" AS period_raw,
    "ABN" AS abn_raw,
    "Institution Name" AS institution_name,
    "Total residents loans and finance leases" AS loans_raw,
    "Total residents deposits" AS deposits_raw
FROM raw.apra_madis
LIMIT 5;

-- 3. Keep all four mapped banks visible, including unmatched banks.
SELECT
    b.bank_code,
    COUNT(r."ABN") AS matched_rows,
    COUNT(DISTINCT r."Period") AS period_count
FROM core.dim_bank AS b
LEFT JOIN raw.apra_madis AS r
    ON TRIM(r."ABN") = TRIM(b.bank_abn)
GROUP BY b.bank_code
ORDER BY b.bank_code;

-- 4. Find duplicate raw institution/period combinations across all banks.
-- An empty result means no duplicate groups were found.
SELECT
    "ABN" AS abn_raw,
    "Period" AS period_raw,
    COUNT(*) AS duplicate_count
FROM raw.apra_madis
GROUP BY "ABN", "Period"
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC
LIMIT 20;

-- 5. Preview date conversion for the modern dates in this source snapshot.
SELECT DISTINCT
    "Period" AS period_raw,
    DATE '1899-12-30'
        + TRY_CAST(TRIM("Period") AS INTEGER) AS report_date
FROM raw.apra_madis
ORDER BY report_date DESC
LIMIT 5;

-- 6. Check each bank's monthly coverage.
-- missing_months measures gaps within the observed span; also check endpoints.
WITH bank_dates AS (
    SELECT
        b.bank_code,
        DATE '1899-12-30'
            + TRY_CAST(TRIM(r."Period") AS INTEGER) AS report_date
    FROM raw.apra_madis AS r
    JOIN core.dim_bank AS b
        ON TRIM(r."ABN") = TRIM(b.bank_abn)
)
SELECT
    bank_code,
    MIN(report_date) AS first_date,
    MAX(report_date) AS last_date,
    COUNT(DISTINCT DATE_TRUNC('month', report_date)) AS month_count,
    DATE_DIFF('month', MIN(report_date), MAX(report_date)) + 1
        - COUNT(DISTINCT DATE_TRUNC('month', report_date)) AS missing_months,
    COUNT(*) FILTER (WHERE report_date IS NULL) AS invalid_dates,
    COUNT(*) FILTER (
        WHERE report_date <> LAST_DAY(report_date)
    ) AS non_month_end_rows
FROM bank_dates
GROUP BY bank_code
ORDER BY bank_code;

-- 7. Check date validity and month-end alignment across the entire raw table.
WITH dates AS (
    SELECT DATE '1899-12-30'
        + TRY_CAST(TRIM("Period") AS INTEGER) AS report_date
    FROM raw.apra_madis
)
SELECT
    COUNT(*) FILTER (WHERE report_date IS NULL) AS invalid_dates,
    COUNT(*) FILTER (
        WHERE report_date <> LAST_DAY(report_date)
    ) AS non_month_end_rows
FROM dates;

-- 8. Inspect seven core amounts for the four mapped banks. Units: AUD million.
-- Blank/NULL and conversion failures are counted separately.
-- Zero and negative counts are review flags; no values are changed here.
WITH amounts AS (
    SELECT
        m.metric,
        NULLIF(TRIM(m.raw_value), '') AS value_text
    FROM raw.apra_madis AS r
    JOIN core.dim_bank AS b
        ON TRIM(r."ABN") = TRIM(b.bank_abn)
    CROSS JOIN LATERAL (
        VALUES
            ('assets', r."Total residents assets"),
            ('loans', r."Total residents loans and finance leases"),
            ('deposits', r."Total residents deposits"),
            ('business_loans', r."Loans to non-financial businesses"),
            ('owner_occupied_loans', r."Loans to households: Housing: Owner-occupied"),
            ('investment_loans', r."Loans to households: Housing: Investment"),
            ('household_deposits', r."Deposits by households")
    ) AS m(metric, raw_value)
), typed AS (
    SELECT
        metric,
        value_text,
        TRY_CAST(value_text AS DECIMAL(20, 4)) AS amount_million
    FROM amounts
)
SELECT
    metric,
    COUNT(*) AS rows_checked,
    COUNT(*) FILTER (WHERE value_text IS NULL) AS missing_count,
    COUNT(*) FILTER (
        WHERE value_text IS NOT NULL AND amount_million IS NULL
    ) AS cast_fail_count,
    COUNT(*) FILTER (WHERE amount_million < 0) AS negative_count,
    COUNT(*) FILTER (WHERE amount_million = 0) AS zero_count
FROM typed
GROUP BY metric
ORDER BY metric;
