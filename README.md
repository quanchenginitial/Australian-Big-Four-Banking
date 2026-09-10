# Australian Big Four Banking Performance & Macro Insights

An independent portfolio project using SQL and Power BI to analyse
Australian Big Four banking data alongside interest rates and inflation.

## Status

Work in progress. The APRA MADIS audit, first typed staging table and scripts
to rebuild these tables from the downloaded Excel snapshot have been completed.
The rebuild was tested in an independent DuckDB database, and comparisons against
the existing project inputs were confirmed through DBeaver on 2026-09-11.

`stg.apra_big_four_monthly` contains 356 records for four banks across 89 months,
from March 2019 to July 2026. It stores report dates as `DATE` and seven selected
financial measures as `DECIMAL(20,4)` in AUD million. Checks found no duplicate
bank/month keys, missing keys or missing selected amounts.

See the [initial audit findings](docs/apra_initial_audit.md) and
[staging table documentation](docs/apra_staging.md) for results, transformation
rules, field definitions and scope.

The source comparison matched all 11,122 raw records across 30 columns and all
four bank mappings, with zero differences in either direction. This confirms
reproduction of the source snapshot, including duplicate multiplicities.

Next: validate the remaining sources and develop the analytical model and Power BI report.

## Tools

- DuckDB and DBeaver for SQL
- Power BI for data modelling, DAX and reporting
- Git and GitHub for version control

## Data sources

Public Excel workbooks from APRA, RBA and ABS.
Raw workbooks and database files are stored locally and excluded from Git.

The current APRA table uses the MADIS March 2019-July 2026 back-series snapshot.
Amounts are in millions of Australian dollars. The selected residents' balances
relate to the relevant ADIs' unconsolidated Australian domestic books.

## SQL scripts

- [00_check_connection.sql](sql/00_check_connection.sql): check the active database and existing tables.
- [setup/01_create_apra_inputs.sql](sql/setup/01_create_apra_inputs.sql): create the raw APRA table and four-bank mapping in a new empty database.
- [01_audit_existing_tables.sql](sql/01_audit_existing_tables.sql): inspect raw records, bank matching, date coverage, duplicates and seven selected financial measures.
- [02_create_apra_big_four_staging.sql](sql/02_create_apra_big_four_staging.sql): create the typed four-bank monthly table and check its types, coverage, keys and missing amounts.
- [03_check_apra_source_rebuild.sql](sql/03_check_apra_source_rebuild.sql): compare all source records and the scripted bank mappings against an existing database.

## Rebuild the APRA data

Follow the [APRA rebuild guide](docs/rebuild_apra.md) using a separate empty DuckDB
database and the downloaded source workbook. Set the workbook path in the setup
script, then run the connection check, input setup, audit and staging scripts in
the documented order. The workflow was tested with DuckDB v1.5.5 and its official
Excel extension.

This procedure rebuilds `raw.apra_madis`, `core.dim_bank` and
`stg.apra_big_four_monthly`. The remaining five source workbooks and the Power BI
report are outside this completed step. The staging table is a stored snapshot;
an automatic refresh process has not yet been implemented.

## Documentation

- [Initial APRA audit](docs/apra_initial_audit.md): observed results, source references, definitions and audit scope.
- [APRA staging table](docs/apra_staging.md): cleaning rules, data dictionary, observed validation results and execution notes.
- [APRA rebuild guide](docs/rebuild_apra.md): prerequisites, execution order and full source-comparison results.
