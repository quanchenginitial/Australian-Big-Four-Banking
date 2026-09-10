-- Compare the downloaded workbook and bootstrap bank mapping with the
-- EXISTING project database. This script does not create or change tables.
-- Run numbered sections 1-4 in DBeaver using the existing project connection.
-- EXCEPT ALL compares every selected field and preserves duplicate counts;
-- physical row order does not affect the comparison. Values are not trimmed.

-- 1. Load the already installed official Excel reader for this connection.
-- If it has not been installed on a new machine, first run INSTALL excel;
LOAD excel;

-- 2. Set the local path of the pinned source snapshot.
SET VARIABLE apra_workbook_path =
    'E:/DuckDB/Australian_Big_Four_Banking/data/raw/01_APRA_MADIS_Backseries_Mar2019_Jul2026.xlsx';

-- 3. Compare all 30 source columns with the stored raw table.
-- Expected: excel_rows=11122, database_rows=11122, both differences=0.
-- SELECT * follows source/table column order, already verified by the audit.
WITH excel_rows AS MATERIALIZED (
    SELECT *
    FROM read_xlsx(
        getvariable('apra_workbook_path'),
        sheet = 'Table 1',
        range = 'A2:AD11124',
        header = true,
        all_varchar = true,
        stop_at_empty = false
    )
), only_in_excel AS (
    SELECT * FROM excel_rows
    EXCEPT ALL
    SELECT * FROM raw.apra_madis
), only_in_database AS (
    SELECT * FROM raw.apra_madis
    EXCEPT ALL
    SELECT * FROM excel_rows
)
SELECT
    (SELECT COUNT(*) FROM excel_rows) AS excel_rows,
    (SELECT COUNT(*) FROM raw.apra_madis) AS database_rows,
    (SELECT COUNT(*) FROM only_in_excel) AS only_in_excel,
    (SELECT COUNT(*) FROM only_in_database) AS only_in_database;

-- 4. Compare the three mapping fields, including full bank names.
-- Expected: expected_banks=4, database_banks=4, both differences=0.
WITH expected_banks AS (
    SELECT *
    FROM (
        VALUES
            ('ANZ', '11005357522', 'Australia and New Zealand Banking Group Limited'),
            ('CBA', '48123123124', 'Commonwealth Bank of Australia'),
            ('NAB', '12004044937', 'National Australia Bank Limited'),
            ('WBC', '33007457141', 'Westpac Banking Corporation')
    ) AS bank_mapping(bank_code, bank_abn, bank_name)
), only_in_expected AS (
    SELECT * FROM expected_banks
    EXCEPT ALL
    SELECT bank_code, bank_abn, bank_name FROM core.dim_bank
), only_in_database AS (
    SELECT bank_code, bank_abn, bank_name FROM core.dim_bank
    EXCEPT ALL
    SELECT * FROM expected_banks
)
SELECT
    (SELECT COUNT(*) FROM expected_banks) AS expected_banks,
    (SELECT COUNT(*) FROM core.dim_bank) AS database_banks,
    (SELECT COUNT(*) FROM only_in_expected) AS only_in_expected,
    (SELECT COUNT(*) FROM only_in_database) AS only_in_database;
