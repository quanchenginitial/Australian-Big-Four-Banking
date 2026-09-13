-- Step 6C: create the monthly bank fact at bank/month-end grain.
-- Requires stg.apra_big_four_monthly, core.dim_bank and confirmed core.dim_date.
-- Preserve all 356 observations and seven AUD-million balances at four decimals.
-- Sections 2-3 create/populate once; sections 4-7 are repeatable read-only checks.
-- Bank names/ABNs and calendar labels remain available through the dimensions.

-- 1. Create the schema for analytical facts.
CREATE SCHEMA IF NOT EXISTS mart;

-- 2. Define the fact with a composite primary key and required measures.
-- Month-end CHECK plus the primary key enforces one row per bank/month.
-- No dimension foreign-key constraints are declared. Section 6 checks both
-- lookups and bank metadata; core.dim_bank was created without a declared key.
-- CREATE TABLE fails if this fact already exists; nothing is replaced.
CREATE TABLE mart.fact_bank_monthly (
    bank_code VARCHAR NOT NULL,
    report_date DATE NOT NULL CHECK (report_date = LAST_DAY(report_date)),
    assets_million DECIMAL(20, 4) NOT NULL,
    loans_million DECIMAL(20, 4) NOT NULL,
    deposits_million DECIMAL(20, 4) NOT NULL,
    business_loans_million DECIMAL(20, 4) NOT NULL,
    owner_occupied_loans_million DECIMAL(20, 4) NOT NULL,
    investment_loans_million DECIMAL(20, 4) NOT NULL,
    household_deposits_million DECIMAL(20, 4) NOT NULL,
    PRIMARY KEY (bank_code, report_date)
);

-- 3. Copy the audited keys and amounts without transformations or joins.
-- No filtering, grouping, deduplication, scaling, rounding or NULL filling.
-- Raw/staging data remain unchanged; this fact is a stored snapshot.
-- Run this INSERT once. The primary key rejects a second insertion.
INSERT INTO mart.fact_bank_monthly (
    bank_code, report_date, assets_million, loans_million, deposits_million,
    business_loans_million, owner_occupied_loans_million,
    investment_loans_million, household_deposits_million
)
SELECT bank_code, report_date, assets_million, loans_million, deposits_million,
    business_loans_million, owner_occupied_loans_million,
    investment_loans_million, household_deposits_million
FROM stg.apra_big_four_monthly;

-- 4. Inspect all nine fields.
-- VARCHAR bank_code + DATE report_date are the composite PRI key, both null NO.
-- Seven amounts are DECIMAL(20,4), all null NO for this complete source selection.
DESCRIBE mart.fact_bank_monthly;

-- 5. Check the retained banking history.
-- Expected: 356 rows, four banks, 89 months, 2019-03-31 through 2026-07-31.
SELECT COUNT(*) AS row_count, COUNT(DISTINCT bank_code) AS bank_count,
    COUNT(DISTINCT report_date) AS month_count,
    MIN(report_date) AS first_date, MAX(report_date) AS last_date
FROM mart.fact_bank_monthly;

-- 6. Validate fact grain, dimension lookups and retained source patterns.
-- Expected: fourteen PASS rows, all issue counts zero.
-- Check every dimension match without filtering unmatched facts out of the load.
-- All seven amounts are positive in this pinned snapshot; that check describes
-- the validated input and is not an instruction to replace missing/zero values.
WITH duplicate_fact_keys AS (
    SELECT bank_code, DATE_TRUNC('month', report_date) AS report_month
    FROM mart.fact_bank_monthly
    GROUP BY bank_code, report_month HAVING COUNT(*) > 1
), bank_calendars AS (
    SELECT bank_code FROM mart.fact_bank_monthly
    GROUP BY bank_code
    HAVING COUNT(*) <> 89 OR COUNT(DISTINCT report_date) <> 89
        OR MIN(report_date) IS DISTINCT FROM DATE '2019-03-31'
        OR MAX(report_date) IS DISTINCT FROM DATE '2026-07-31'
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
    FROM mart.fact_bank_monthly AS f
    LEFT JOIN core.dim_bank AS b ON f.bank_code = b.bank_code
    LEFT JOIN core.dim_date AS d ON f.report_date = d.calendar_date
), bank_metadata AS (
    SELECT COUNT(*) AS bank_attribute_mismatch_rows
    FROM stg.apra_big_four_monthly AS s
    JOIN core.dim_bank AS b ON s.bank_code = b.bank_code
    WHERE s.bank_abn IS DISTINCT FROM b.bank_abn
        OR s.bank_name IS DISTINCT FROM b.bank_name
), counts AS (
    SELECT ABS(COUNT(*) - 356) AS row_count_difference,
        ABS(COUNT(DISTINCT f.bank_code) - 4) AS bank_count_difference,
        (SELECT COUNT(*) FROM duplicate_fact_keys) AS duplicate_bank_month_keys,
        (SELECT COUNT(*) FROM bank_calendars) AS bank_calendar_mismatches,
        COUNT(*) FILTER (
            WHERE NULLIF(TRIM(f.bank_code), '') IS NULL OR f.report_date IS NULL
                OR f.assets_million IS NULL OR f.loans_million IS NULL
                OR f.deposits_million IS NULL OR f.business_loans_million IS NULL
                OR f.owner_occupied_loans_million IS NULL
                OR f.investment_loans_million IS NULL OR f.household_deposits_million IS NULL
        ) AS missing_required_values_rows,
        COUNT(*) FILTER (WHERE f.report_date <> LAST_DAY(f.report_date)) AS non_month_end_rows,
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
            WHERE f.assets_million <= 0 OR f.loans_million <= 0 OR f.deposits_million <= 0
                OR f.business_loans_million <= 0 OR f.owner_occupied_loans_million <= 0
                OR f.investment_loans_million <= 0 OR f.household_deposits_million <= 0
        ) AS nonpositive_amount_rows
    FROM mart.fact_bank_monthly AS f
)
SELECT c.check_name, c.actual_count, 0 AS expected_count,
    CASE WHEN c.actual_count = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM counts
CROSS JOIN LATERAL (
    VALUES
        (1, 'row_count_difference', row_count_difference),
        (2, 'bank_count_difference', bank_count_difference),
        (3, 'duplicate_bank_month_keys', duplicate_bank_month_keys),
        (4, 'bank_calendar_mismatches', bank_calendar_mismatches),
        (5, 'missing_required_values_rows', missing_required_values_rows),
        (6, 'non_month_end_rows', non_month_end_rows),
        (7, 'unmatched_bank_rows', unmatched_bank_rows),
        (8, 'unmatched_date_rows', unmatched_date_rows),
        (9, 'duplicate_bank_dimension_keys', duplicate_bank_dimension_keys),
        (10, 'bank_dimension_row_difference', bank_dimension_row_difference),
        (11, 'invalid_bank_dimension_rows', invalid_bank_dimension_rows),
        (12, 'lookup_join_row_difference', lookup_join_row_difference),
        (13, 'bank_attribute_mismatch_rows', bank_attribute_mismatch_rows),
        (14, 'nonpositive_amount_rows', nonpositive_amount_rows)
) AS c(check_order, check_name, actual_count)
ORDER BY c.check_order;

-- 7. Compare all nine retained fields with staging in both directions.
-- Expected: two PASS rows, each difference zero. EXCEPT ALL retains multiplicity.
-- This verifies preservation of keys/amounts, not just equal row counts or totals.
WITH staged_values AS (
    SELECT bank_code, report_date, assets_million, loans_million, deposits_million,
        business_loans_million, owner_occupied_loans_million,
        investment_loans_million, household_deposits_million
    FROM stg.apra_big_four_monthly
), fact_values AS (
    SELECT bank_code, report_date, assets_million, loans_million, deposits_million,
        business_loans_million, owner_occupied_loans_million,
        investment_loans_million, household_deposits_million
    FROM mart.fact_bank_monthly
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
