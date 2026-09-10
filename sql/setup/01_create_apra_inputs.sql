-- Bootstrap the APRA inputs in a NEW, EMPTY DuckDB database.
-- Do not run this file against the populated project database.
-- Dependencies: DuckDB v1.5.5 and the official excel extension.
-- Change only the workbook path below for a different local project location.
-- This script targets the pinned March 2019-July 2026 workbook snapshot.
-- Run once; existing tables cause an error and are not replaced.

INSTALL excel;
LOAD excel;

SET VARIABLE apra_workbook_path =
    'E:/DuckDB/Australian_Big_Four_Banking/data/raw/01_APRA_MADIS_Backseries_Mar2019_Jul2026.xlsx';

CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS core;

-- Table 1: row 1 is the units note, row 2 contains the 30 column names.
-- A2:AD11124 includes the header and all 11,122 rows of this snapshot.
-- Preserve date serials and amounts as text for the existing audit/staging SQL.
CREATE TABLE raw.apra_madis AS
SELECT *
FROM read_xlsx(
    getvariable('apra_workbook_path'),
    sheet = 'Table 1',
    range = 'A2:AD11124',
    header = true,
    all_varchar = true,
    stop_at_empty = false
);

-- Reproduce the four existing institution mappings. ABNs remain text.
-- These codes identify the selected licensed entities, not every group member.
CREATE TABLE core.dim_bank AS
SELECT *
FROM (
    VALUES
        ('ANZ', '11005357522', 'Australia and New Zealand Banking Group Limited'),
        ('CBA', '48123123124', 'Commonwealth Bank of Australia'),
        ('NAB', '12004044937', 'National Australia Bank Limited'),
        ('WBC', '33007457141', 'Westpac Banking Corporation')
) AS bank_mapping(bank_code, bank_abn, bank_name);

-- Expected: 11,122 raw rows and four mapped banks.
SELECT
    (SELECT COUNT(*) FROM raw.apra_madis) AS raw_rows,
    (SELECT COUNT(*) FROM core.dim_bank) AS bank_rows;

-- Next: run sql/01_audit_existing_tables.sql, then
-- sql/02_create_apra_big_four_staging.sql in the same new database.
