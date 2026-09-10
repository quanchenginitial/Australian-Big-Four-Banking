# Rebuild the APRA inputs and staging table

This procedure rebuilds the APRA MADIS portion of the project from the downloaded Excel snapshot. It does not yet load the other five workbooks or build a Power BI report.

## Required inputs

- DuckDB v1.5.5, as used for the original project checks.
- The official DuckDB `excel` extension. The setup script uses `INSTALL excel` and `LOAD excel`; first-time installation requires access to the extension repository.
- The local workbook `data/raw/01_APRA_MADIS_Backseries_Mar2019_Jul2026.xlsx`.
- The SQL scripts in this repository.

The workbook is excluded from Git. The existing snapshot has headers in `Table 1!A2:AD2` and 11,122 data rows through row 11124. The bootstrap pins the range `A2:AD11124` to reproduce that snapshot. If using an updated workbook, review its filename, sheet, headers, range and expected counts before adapting the scripts.

## Rebuild in a separate empty database

Create a separate DuckDB database and connect DBeaver to it. Use an unmistakable test filename, such as `database/apra_rebuild_check.duckdb`, rather than the populated project database. Confirm the active database and file path with the connection-check script.

Run these files in order on the new connection:

| Order | Script | Result |
|---|---|---|
| 1 | [00_check_connection.sql](../sql/00_check_connection.sql) | Confirm the new database path and inspect its tables |
| 2 | [setup/01_create_apra_inputs.sql](../sql/setup/01_create_apra_inputs.sql) | Create `raw.apra_madis` and `core.dim_bank` |
| 3 | [01_audit_existing_tables.sql](../sql/01_audit_existing_tables.sql) | Audit the reconstructed inputs |
| 4 | [02_create_apra_big_four_staging.sql](../sql/02_create_apra_big_four_staging.sql) | Create and validate `stg.apra_big_four_monthly` |

Before running the setup file, adjust its `apra_workbook_path` setting to the workbook's absolute path on your computer. DBeaver's working directory is not assumed to be the project folder.

The setup and staging scripts use `CREATE TABLE`. They are one-time creation steps for an empty database and will not replace existing tables. This procedure is not an automatic refresh of the live project.

Expected results for the pinned snapshot:

- Raw table: 11,122 rows and 30 `VARCHAR` columns.
- Bank mapping: four rows with text bank codes, ABNs and names.
- Staging table: 356 rows, 11 columns, four banks and 89 monthly report dates, from 2019-03-31 to 2026-07-31.
- Staging duplicate bank/month keys, missing-key rows and missing-amount rows: all zero.

The `all_varchar = true` reader setting preserves the original date serials and numeric text expected by the audit and staging scripts. See the [DuckDB Excel extension documentation](https://duckdb.org/docs/current/core_extensions/excel) for reader options. Source units, statistical scope and transformation definitions are recorded in the [initial audit](apra_initial_audit.md) and [staging documentation](apra_staging.md).

## Compare against the existing project database

Run [03_check_apra_source_rebuild.sql](../sql/03_check_apra_source_rebuild.sql) on the original project connection. Adjust its workbook path if necessary. This comparison loads the Excel reader, sets a connection variable and queries the existing tables; it does not recreate them.

The raw comparison checks all 30 columns using `EXCEPT ALL` in both directions. It ignores physical row order while retaining duplicate multiplicities. It does not trim or normalise values, so a nonzero difference must be inspected before claiming an exact match. A zero difference in both directions plus the expected counts confirms that the Excel reader reproduces the stored raw rows for this snapshot.

The mapping comparison similarly checks all four records and all three mapping fields. It verifies reproduction of the project's selected mappings, rather than independently certifying all banking-group legal entities.

The following results were confirmed from the project's DBeaver queries on 2026-09-11:

| Comparison | Source/expected rows | Database rows | Only in source/expected | Only in database |
|---|---:|---:|---:|---:|
| APRA raw table | 11,122 | 11,122 | 0 | 0 |
| Bank mapping | 4 | 4 | 0 | 0 |

Both comparisons passed. All 11,122 raw rows matched across all 30 columns, including NULLs and duplicate multiplicities, and the four scripted mappings matched the existing mapping table across all three fields. This establishes exact reproduction of the stored input values for this snapshot; it does not independently validate the economic meaning of every field.

Validation status as of 2026-09-11:

- The setup script, existing audit script, existing staging script and comparison script were run in an independent in-memory DuckDB v1.5.5 database, reading the Excel workbook directly. They produced the expected input counts, column types, staging coverage and zero quality-check counts. The 2,492 staged amounts also agreed with a separate extraction of the source workbook.
- A separate test changed a raw field outside the seven selected measures, added a duplicate raw row and changed a mapped bank name. The comparison detected all these differences, including the duplicate multiplicity.
- The tests used the installed Excel extension; they did not test a fresh extension download. The populated project database was not opened or modified by these tests.
- The read-only comparison was subsequently executed on the existing project connection. Its observed results are recorded in the table above, with zero differences for both the raw records and bank mappings.
