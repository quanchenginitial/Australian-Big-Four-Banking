# Rebuild the APRA inputs and staging tables

This procedure rebuilds the APRA MADIS monthly and ADI quarterly portions of the project from the downloaded Excel snapshots. It does not yet load the other four workbooks (one RBA and three ABS sources) or build a Power BI report.

## Required inputs

- DuckDB v1.5.5, as used for the original project checks.
- The official DuckDB `excel` extension. The setup script uses `INSTALL excel` and `LOAD excel`; first-time installation requires access to the extension repository.
- The local workbook `data/raw/01_APRA_MADIS_Backseries_Mar2019_Jul2026.xlsx`.
- The local workbook `data/raw/02_APRA_ADI_Capital_Liquidity_Mar2013_Mar2026.xlsx`.
- The SQL scripts in this repository.

Both workbooks are excluded from Git. The MADIS snapshot has headers in `Table 1!A2:AD2` and 11,122 data rows through row 11124; the bootstrap pins the range `A2:AD11124`. The ADI snapshot has headers in `Table 4!A3:W3` and 5,295 data rows through row 5298; script 04 pins the range `A3:W5298`. If using updated workbooks, review their filenames, sheets, headers, ranges and expected counts before adapting the scripts.

## Rebuild in a separate empty database

Create a separate DuckDB database and connect DBeaver to it. Use an unmistakable test filename, such as `database/apra_rebuild_check.duckdb`, rather than the populated project database. Confirm the active database and file path with the connection-check script.

Run these files in order on the new connection:

| Order | Script | Result |
|---|---|---|
| 1 | [00_check_connection.sql](../sql/00_check_connection.sql) | Confirm the new database path and inspect its tables |
| 2 | [setup/01_create_apra_inputs.sql](../sql/setup/01_create_apra_inputs.sql) | Create `raw.apra_madis` and `core.dim_bank` |
| 3 | [01_audit_existing_tables.sql](../sql/01_audit_existing_tables.sql) | Audit the reconstructed inputs |
| 4 | [02_create_apra_big_four_staging.sql](../sql/02_create_apra_big_four_staging.sql) | Create and validate `stg.apra_big_four_monthly` |
| 5 | [03_check_apra_source_rebuild.sql](../sql/03_check_apra_source_rebuild.sql) | Confirm full MADIS raw-record and bank-mapping agreement with the inputs |
| 6 | [04_load_apra_adi_quarterly.sql](../sql/04_load_apra_adi_quarterly.sql) | Create `raw.apra_adi_quarterly`; check periods and matching of the existing bank ABNs |
| 7 | [05_audit_apra_adi_quarterly.sql](../sql/05_audit_apra_adi_quarterly.sql) | Audit selected quarterly keys, dates, amounts, ratios and liquidity coverage |
| 8 | [06_create_apra_big_four_quarterly.sql](../sql/06_create_apra_big_four_quarterly.sql) | Create and validate `stg.apra_big_four_quarterly` |

Before running the files, adjust `apra_workbook_path` in the setup and 03 comparison scripts to the MADIS workbook's absolute path, and `adi_workbook_path` in script 04 to the ADI workbook's absolute path. Each file sets its own variable. DBeaver's working directory is not assumed to be the project folder. Run the numbered statements within each file in order on the same connection. Script 04 depends on the raw schema and bank mapping created by the setup file.

The setup, 04 import and both staging scripts use `CREATE TABLE`. They are one-time creation steps for an empty database and will not replace existing tables. This procedure is not an automatic refresh of the live project. Diagnostic queries can be repeated after the corresponding tables exist.

Expected results for the pinned MADIS snapshot:

- Raw table: 11,122 rows and 30 `VARCHAR` columns.
- Bank mapping: four rows with text bank codes, ABNs and names.
- Staging table: 356 rows, 11 columns, four banks and 89 monthly report dates, from 2019-03-31 to 2026-07-31.
- Staging duplicate bank/month keys, missing-key rows and missing-amount rows: all zero.

Expected results for the pinned ADI snapshot:

- Raw table: 5,295 rows, 23 VARCHAR columns and 53 publication periods from 2013-03-31 through 2026-03-31.
- Four-bank matching: 53 rows and 53 periods for each bank, giving 212 selected records.
- The six date/key issues in script 05: all zero. Each of its ten numeric metrics has 212 records checked, with zero nonblank conversion failures, negative values or zero values.
- Four capital amounts and three capital ratios: no missing values. LCR and NSFR: 80 NULLs each, with 33 populated quarters per bank from 2018-03-31 to 2026-03-31 and no gaps within that span. MLH: 212 NULLs.
- Staging table: 212 rows, 16 columns, four banks and 53 quarters over the same publication-date range. Types are four VARCHAR, two DATE, four DECIMAL(20,4) and six DECIMAL(18,6).
- Script 06 validation: all seven rows show PASS. Missing counts of 80, 80 and 212 are expected and preserved; they are not failed checks.

The `all_varchar = true` reader setting preserves the original date serials and numeric text expected by the audit and staging scripts. See the [DuckDB Excel extension documentation](https://duckdb.org/docs/current/core_extensions/excel) for reader options. Source units, statistical scope and transformation definitions are recorded in the [MADIS initial audit](apra_initial_audit.md), [monthly staging documentation](apra_staging.md), [ADI source review](apra_adi_source_review.md) and [quarterly staging documentation](apra_adi_staging.md). The two publications have different consolidation scopes; do not assume their amounts are directly comparable because they share bank codes.

## Compare MADIS inputs against the existing project database

Run [03_check_apra_source_rebuild.sql](../sql/03_check_apra_source_rebuild.sql) on the original project connection. Adjust its workbook path if necessary. This comparison loads the Excel reader, sets a connection variable and queries the existing tables; it does not recreate them.

The raw comparison checks all 30 columns using `EXCEPT ALL` in both directions. It ignores physical row order while retaining duplicate multiplicities. It does not trim or normalise values, so a nonzero difference must be inspected before claiming an exact match. A zero difference in both directions plus the expected counts confirms that the Excel reader reproduces the stored raw rows for this snapshot.

The mapping comparison similarly checks all four records and all three mapping fields. It verifies reproduction of the project's selected mappings, rather than independently certifying all banking-group legal entities.

The following results were confirmed from the project's DBeaver queries on 2026-09-11:

| Comparison | Source/expected rows | Database rows | Only in source/expected | Only in database |
|---|---:|---:|---:|---:|
| MADIS raw table | 11,122 | 11,122 | 0 | 0 |
| Bank mapping | 4 | 4 | 0 | 0 |

Both comparisons passed. All 11,122 raw rows matched across all 30 columns, including NULLs and duplicate multiplicities, and the four scripted mappings matched the existing mapping table across all three fields. This establishes exact reproduction of the stored input values for this snapshot; it does not independently validate the economic meaning of every field.

Validation status as of 2026-09-11:

- The setup script, existing audit script, existing staging script and comparison script were run in an independent in-memory DuckDB v1.5.5 database, reading the Excel workbook directly. They produced the expected input counts, column types, staging coverage and zero quality-check counts. The 2,492 staged amounts also agreed with a separate extraction of the source workbook.
- A separate test changed a raw field outside the seven selected measures, added a duplicate raw row and changed a mapped bank name. The comparison detected all these differences, including the duplicate multiplicity.
- The tests used the installed Excel extension; they did not test a fresh extension download. The populated project database was not opened or modified by these tests.
- The read-only comparison was subsequently executed on the existing project connection. Its observed results are recorded in the table above, with zero differences for both the raw records and bank mappings.

## Quarterly validation record

The 04 import, 05 audit and 06 staging scripts were tested in independent in-memory DuckDB v1.5.5 databases using the ADI workbook and the existing four-bank mapping. Their types, counts, dates and audit results agreed with the expectations above. An independent Excel read also matched both staged dates and all 2,120 selected numeric cells at the chosen precision, including 372 NULLs. These tests used the installed Excel extension and did not open or modify the project database.

The project-database import and audit were subsequently confirmed through DBeaver. On 2026-09-11, the user also confirmed the quarterly staging table's 16 column types, 212 records, four banks, 53 quarters, date range and all seven PASS results.

The full 30-column `EXCEPT ALL` comparison described above applies to MADIS. The ADI validation consists of the import checks, selected four-bank audit, independent source-to-staging checks and observed project staging results; it does not claim that the existing ADI raw table has undergone the same full-table reconciliation.
