# Australian Big Four Banking Performance & Macro Insights

An independent portfolio project using SQL and Power BI to analyse
Australian Big Four banking data alongside interest rates and inflation.

## Status

Work in progress. The initial APRA MADIS audit and the first typed staging table
have been completed and checked in DuckDB through DBeaver.

`stg.apra_big_four_monthly` contains 356 records for four banks across 89 months,
from March 2019 to July 2026. It stores report dates as `DATE` and seven selected
financial measures as `DECIMAL(20,4)` in AUD million. Checks found no duplicate
bank/month keys, missing keys or missing selected amounts.

See the [initial audit findings](docs/apra_initial_audit.md) and
[staging table documentation](docs/apra_staging.md) for results, transformation
rules, field definitions and scope.

Next: complete and verify the scripts needed to rebuild the input tables, then
validate the remaining sources and develop the analytical model and Power BI report.

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
- [01_audit_existing_tables.sql](sql/01_audit_existing_tables.sql): inspect raw records, bank matching, date coverage, duplicates and seven selected financial measures.
- [02_create_apra_big_four_staging.sql](sql/02_create_apra_big_four_staging.sql): create the typed four-bank monthly table and check its types, coverage, keys and missing amounts.

The audit and staging scripts require the existing `raw.apra_madis` and
`core.dim_bank` tables. Scripts to load the raw data and initialise the bank
mapping are still to be added; the current repository does not yet rebuild the
database from scratch. The staging table is a stored snapshot and does not
automatically refresh when the input tables change.

## Documentation

- [Initial APRA audit](docs/apra_initial_audit.md): observed results, source references, definitions and audit scope.
- [APRA staging table](docs/apra_staging.md): cleaning rules, data dictionary, observed validation results and execution notes.
