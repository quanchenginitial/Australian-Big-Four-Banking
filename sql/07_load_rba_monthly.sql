-- Step 5E: import the RBA F1.1 monthly money-market snapshot.
-- Requires the existing raw schema. Run sections 1-6 on the project connection.
-- Section 3 creates a new table once and does not replace an existing table.
-- The table has one row per month, not one row per bank.

-- 1. Load the installed official Excel reader.
LOAD excel;

-- 2. Set the local workbook path (publication date: 1 September 2026).
SET VARIABLE rba_workbook_path =
    'E:/DuckDB/Australian_Big_Four_Banking/data/raw/03_RBA_F1_1_Monthly_Money_Market.xlsx';

-- 3. Import the monthly observations and retain all 15 series.
-- Data!A11:P11 contains the Series ID headers; observations occupy rows 12-698.
-- The first column contains dates, despite its source header "Series ID".
-- Rename only that column to period_raw. Keep all source values as VARCHAR.
-- Rows 1-10 are metadata, and rows after 698 are empty in this snapshot.
CREATE TABLE raw.rba_f1_1_monthly AS
SELECT
    "Series ID" AS period_raw,
    * EXCLUDE ("Series ID")
FROM read_xlsx(
    getvariable('rba_workbook_path'),
    sheet = 'Data',
    range = 'A11:P698',
    header = true,
    all_varchar = true,
    stop_at_empty = false
);

-- 4. Check the imported column names and types.
-- Expected: period_raw plus 15 Series ID columns, all VARCHAR (16 columns).
DESCRIBE raw.rba_f1_1_monthly;

-- 5. Check the row count and monthly date range.
-- Expected: 687 rows, 687 months, 1969-06-30 through 2026-08-31.
-- Excel uses the 1900 date system. Raw date serials remain unchanged.
WITH dates AS (
    SELECT
        DATE '1899-12-30'
            + CAST(TRIM(period_raw) AS INTEGER) AS report_date
    FROM raw.rba_f1_1_monthly
)
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT report_date) AS month_count,
    MIN(report_date) AS first_date,
    MAX(report_date) AS last_date
FROM dates;

-- 6. Preview the latest five months for three reference rates.
-- These are monthly averages expressed in per cent: 4.35 means 4.35%.
-- The month-end date identifies the month; it does not mean an end-month rate.
-- Decimal conversion here is for this read-only preview, not a raw-table edit.
-- NULLs stay NULL. The later audit will examine series-specific coverage.
SELECT
    DATE '1899-12-30'
        + CAST(TRIM(period_raw) AS INTEGER) AS report_date,
    CAST(NULLIF(TRIM("FIRMMCRT"), '')
        AS DECIMAL(18, 6)) AS cash_rate_target_pct,
    CAST(NULLIF(TRIM("FIRMMCRI"), '')
        AS DECIMAL(18, 6)) AS interbank_cash_rate_pct,
    CAST(NULLIF(TRIM("FIRMMBAB90"), '')
        AS DECIMAL(18, 6)) AS bank_bill_3m_pct
FROM raw.rba_f1_1_monthly
ORDER BY report_date DESC
LIMIT 5;
