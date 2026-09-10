# Australian Big Four Banking Performance & Macro Insights

An independent portfolio project using SQL and Power BI to analyse
Australian Big Four banking data alongside interest rates and inflation.

## Status

Work in progress. Both APRA sources have been imported and audited, and their
typed four-bank staging tables were confirmed through DBeaver on 2026-09-11.
The source-loading and transformation scripts have also passed independent
DuckDB tests against the downloaded Excel snapshots.

| Staging table | Records | Coverage | Selected measures |
|---|---:|---|---|
| `stg.apra_big_four_monthly` | 356 | Four banks, 89 months, March 2019-July 2026 | Seven asset, loan and deposit amounts |
| `stg.apra_big_four_quarterly` | 212 | Four banks, 53 quarters, March 2013-March 2026 | Four capital/RWA amounts and six capital/liquidity ratios |

The monthly table has no duplicate bank/month keys, missing keys or missing
selected amounts. A separate source comparison matched all 11,122 MADIS raw
records across 30 columns and all four bank mappings, with zero differences in
either direction, including duplicate multiplicities.

The quarterly table has 16 typed columns and passed all seven staging checks.
Its selected capital amounts and capital ratios are complete. LCR and NSFR each
have 33 consecutive populated quarters per bank from March 2018 to March 2026;
the 80 earlier missing values per metric remain NULL. MLH is NULL in all 212
selected records. Both date fields and a label for the 2023 capital-framework
change are retained.

The two datasets have different reporting scopes. MADIS covers selected
residents' balances on unconsolidated Australian domestic books; the quarterly
ADI publication uses entities' highest consolidation level. The shared bank
mapping does not make these measures directly comparable.

Next: import and validate the RBA interest-rate workbook, then the ABS inflation
workbooks, before developing the analytical model and Power BI report.

## Tools

- DuckDB and DBeaver for SQL
- Power BI for data modelling, DAX and reporting
- Git and GitHub for version control

## Data sources

Public Excel workbooks from APRA, RBA and ABS.
Raw workbooks and database files are stored locally and excluded from Git.

The completed APRA imports use these pinned snapshots:

- `01_APRA_MADIS_Backseries_Mar2019_Jul2026.xlsx`: Table 1, range A2:AD11124; 11,122 raw rows and 30 columns.
- `02_APRA_ADI_Capital_Liquidity_Mar2013_Mar2026.xlsx`: Table 4, range A3:W5298; 5,295 raw rows and 23 columns.

Amounts remain in millions of Australian dollars. Quarterly ratios retain
decimal fractions, so `0.124` represents 12.4% and `1.318` represents 131.8%.
Missing liquidity observations remain NULL. Source definitions and coverage
are documented below. The remaining four workbooks comprise one RBA source
and three ABS sources; their validation is pending.

## SQL scripts

- [00_check_connection.sql](sql/00_check_connection.sql): check the active database and existing tables.
- [setup/01_create_apra_inputs.sql](sql/setup/01_create_apra_inputs.sql): create the raw MADIS table and four-bank mapping in a new empty database.
- [01_audit_existing_tables.sql](sql/01_audit_existing_tables.sql): inspect raw records, bank matching, date coverage, duplicates and seven selected financial measures.
- [02_create_apra_big_four_staging.sql](sql/02_create_apra_big_four_staging.sql): create the typed four-bank monthly table and check its types, coverage, keys and missing amounts.
- [03_check_apra_source_rebuild.sql](sql/03_check_apra_source_rebuild.sql): compare all MADIS source records and the scripted bank mappings against an existing database.
- [04_load_apra_adi_quarterly.sql](sql/04_load_apra_adi_quarterly.sql): load the ADI quarterly back series and check its coverage and bank matching.
- [05_audit_apra_adi_quarterly.sql](sql/05_audit_apra_adi_quarterly.sql): audit quarterly keys, both dates, ten selected numeric measures and liquidity coverage.
- [06_create_apra_big_four_quarterly.sql](sql/06_create_apra_big_four_quarterly.sql): create the typed quarterly table, retain the framework-period label and validate its types, coverage and expected NULLs.

## Rebuild the APRA data

Follow the [APRA rebuild guide](docs/rebuild_apra.md) using a separate empty DuckDB
database and the two downloaded APRA workbooks. Set their absolute paths in the
setup and 04 import scripts, then follow the documented execution order.
Both APRA modules were tested with DuckDB v1.5.5 and its official Excel extension.

The procedure creates `raw.apra_madis`, `raw.apra_adi_quarterly`, `core.dim_bank`,
`stg.apra_big_four_monthly` and `stg.apra_big_four_quarterly`. The remaining four
source workbooks and the Power BI report are outside this completed step.
The staging tables are stored snapshots; an automatic refresh process has not
yet been implemented.

## Documentation

- [Initial APRA audit](docs/apra_initial_audit.md): observed results, source references, definitions and audit scope.
- [APRA staging table](docs/apra_staging.md): cleaning rules, data dictionary, observed validation results and execution notes.
- [ADI quarterly source review](docs/apra_adi_source_review.md): source selection, reporting scope, units, date/key audit and liquidity coverage.
- [ADI quarterly staging table](docs/apra_adi_staging.md): 16-column data dictionary, transformation rules and confirmed validation results.
- [APRA rebuild guide](docs/rebuild_apra.md): prerequisites, execution order for both APRA modules and MADIS source-comparison results.
