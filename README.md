# Australian Big Four Banking Performance & Macro Insights

An independent portfolio project using SQL and Power BI to analyse
Australian Big Four banking data alongside interest rates and inflation.

## Status

Work in progress. The local DuckDB connection and initial APRA MADIS data audit
have been completed. The four mapped banks each have 89 monthly records from
March 2019 to July 2026, giving 356 bank-month records. Seven selected financial
measures passed the initial missing-value and numeric-conversion checks.

See the [initial audit findings](docs/apra_initial_audit.md) for results, units
and statistical scope. Typed SQL transformations, validation of the remaining
sources, and Power BI reporting are the next phases.

## Tools

- DuckDB and DBeaver for SQL
- Power BI for data modelling, DAX and reporting
- Git and GitHub for version control

## Data sources

Public Excel workbooks from APRA, RBA and ABS.
Raw workbooks and database files are stored locally and excluded from Git.

The initial audit uses the APRA MADIS March 2019-July 2026 back-series snapshot.
Amounts are in millions of Australian dollars. The selected residents' balances
relate to the relevant ADIs' unconsolidated Australian domestic books.

## SQL scripts

- [00_check_connection.sql](sql/00_check_connection.sql): check the active database and existing tables.
- [01_audit_existing_tables.sql](sql/01_audit_existing_tables.sql): inspect raw records, bank matching, date coverage, duplicates and seven selected financial measures.

The audit requires the existing `raw.apra_madis` and `core.dim_bank` tables.
Source-loading and table-creation scripts are still to be added; the current
repository does not yet rebuild the database from scratch.

## Documentation

- [Initial APRA audit](docs/apra_initial_audit.md): observed results, source references, definitions and remaining work.
