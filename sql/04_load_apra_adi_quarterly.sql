-- Step 5A: import the ADI centralised publication's quarterly back series.
-- Requires the existing raw schema and core.dim_bank mapping.
-- Run sections 1-5 in order in the existing project connection.
-- Section 3 creates a new table once. It does not replace existing tables.

-- 1. Load the installed official Excel reader.
LOAD excel;

-- 2. Set the path to the audited March 2013-March 2026 snapshot.
SET VARIABLE adi_workbook_path =
    'E:/DuckDB/Australian_Big_Four_Banking/data/raw/02_APRA_ADI_Capital_Liquidity_Mar2013_Mar2026.xlsx';

-- 3. Import Table 4, which holds the historical data and ABNs.
-- Row 3 contains 23 headers; rows 4-5298 hold 5,295 records.
-- Column X is outside the populated table. Preserve blanks as NULL, not zero.
-- all_varchar preserves Excel date serials and decimal ratio values as text.
CREATE TABLE raw.apra_adi_quarterly AS
SELECT *
FROM read_xlsx(
    getvariable('adi_workbook_path'),
    sheet = 'Table 4',
    range = 'A3:W5298',
    header = true,
    all_varchar = true,
    stop_at_empty = false
);

-- 4. Check the imported rows and publication-period coverage.
-- Period is the publication quarter; Entity quarter end is a separate field.
-- Expected: 5295 rows, 53 periods, 2013-03-31 through 2026-03-31.
WITH dates AS (
    SELECT
        DATE '1899-12-30'
            + CAST(TRIM("Period") AS INTEGER) AS period_date
    FROM raw.apra_adi_quarterly
)
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT period_date) AS period_count,
    MIN(period_date) AS first_date,
    MAX(period_date) AS last_date
FROM dates;

-- 5. Confirm that the existing ABN mapping finds all four banks.
-- Expected for each bank: 53 rows and 53 periods over the same date range.
SELECT
    b.bank_code,
    COUNT(r."ABN") AS matched_rows,
    COUNT(DISTINCT r."Period") AS period_count,
    MIN(DATE '1899-12-30' + CAST(TRIM(r."Period") AS INTEGER)) AS first_date,
    MAX(DATE '1899-12-30' + CAST(TRIM(r."Period") AS INTEGER)) AS last_date
FROM core.dim_bank AS b
LEFT JOIN raw.apra_adi_quarterly AS r
    ON TRIM(r."ABN") = TRIM(b.bank_abn)
GROUP BY b.bank_code
ORDER BY b.bank_code;

-- Next: validate keys, both date fields, ratios and their missing-data periods
-- before building a typed quarterly table. Ratios are decimal fractions:
-- 0.124 = 12.4%, and 1.318 = 131.8%; do not divide them by 100 again.
