# Australian Big Four Banking Performance & Macro Insights

An independent portfolio project using SQL and Power BI to analyse
Australian Big Four banking data alongside interest rates and inflation.

## Status

Work in progress. The two APRA sources and the RBA F1.1 workbook have been
imported. Their selected measures have been audited and converted into typed
staging tables, with project results confirmed through DBeaver on 2026-09-11.
The source-loading and transformation scripts have also passed independent
DuckDB tests against the downloaded Excel snapshots.

| Staging table | Records | Coverage | Selected measures |
|---|---:|---|---|
| `stg.apra_big_four_monthly` | 356 | Four banks, 89 months, March 2019-July 2026 | Seven asset, loan and deposit amounts |
| `stg.apra_big_four_quarterly` | 212 | Four banks, 53 quarters, March 2013-March 2026 | Four capital/RWA amounts and six capital/liquidity ratios |
| `stg.rba_monthly_rates` | 687 | One market-wide observation per month, June 1969-August 2026 | Cash-rate target, interbank overnight cash rate and three-month bank-bill rate |

The MADIS monthly table has no duplicate bank/month keys, missing keys or missing
selected amounts. A separate source comparison matched all 11,122 MADIS raw
records across 30 columns and all four bank mappings, with zero differences in
either direction, including duplicate multiplicities.

The ADI quarterly table has 16 typed columns and passed all seven staging checks.
Its selected capital amounts and capital ratios are complete. LCR and NSFR each
have 33 consecutive populated quarters per bank from March 2018 to March 2026;
the 80 earlier missing values per metric remain NULL. MLH is NULL in all 212
selected records. Both date fields and a label for the 2023 capital-framework
change are retained.

The two APRA datasets have different reporting scopes. MADIS covers selected
residents' balances on unconsolidated Australian domestic books; the quarterly
ADI publication uses entities' highest consolidation level. The shared bank
mapping does not make these measures directly comparable.

The RBA table has one DATE field and three DECIMAL(18,6) rate fields, with all
eleven staging checks passing. It retains 254 early missing cash-rate targets,
83 early missing interbank rates and one flagged source bank-bill zero from
November 1969. All three rates have complete, nonzero coverage for the APRA
analysis inputs: 89 MADIS months and all 159 months of the 53 ADI quarters.
The rates are monthly averages; quarterly aggregation has not yet been built.

Next: import and validate the three ABS inflation workbooks, starting with
monthly CPI, before developing the analytical model and Power BI report.

## Tools

- DuckDB and DBeaver for SQL
- Power BI for data modelling, DAX and reporting
- Git and GitHub for version control

## Data sources

Public Excel workbooks from APRA, RBA and ABS.
Raw workbooks and database files are stored locally and excluded from Git.

The completed imports use these pinned snapshots:

- `01_APRA_MADIS_Backseries_Mar2019_Jul2026.xlsx`: Table 1, range A2:AD11124; 11,122 raw rows and 30 columns.
- `02_APRA_ADI_Capital_Liquidity_Mar2013_Mar2026.xlsx`: Table 4, range A3:W5298; 5,295 raw rows and 23 columns.
- `03_RBA_F1_1_Monthly_Money_Market.xlsx`: Data, range A11:P698; 687 raw rows and 16 columns (a date column and 15 series). The selected staging table keeps three rates and all months.

APRA monetary amounts remain in millions of Australian dollars. ADI ratios retain
decimal fractions, so `0.124` represents 12.4% and `1.318` represents 131.8%.
Missing liquidity observations remain NULL. RBA rates retain per-cent units
in `_pct` columns: `4.35` means 4.35%, so divide by 100 once if a reporting field
requires a decimal fraction. Source definitions and coverage are documented
below. Validation of the remaining three ABS workbooks is pending.

## SQL scripts

- [00_check_connection.sql](sql/00_check_connection.sql): check the active database and existing tables.
- [setup/01_create_apra_inputs.sql](sql/setup/01_create_apra_inputs.sql): create the raw MADIS table and four-bank mapping in a new empty database.
- [01_audit_existing_tables.sql](sql/01_audit_existing_tables.sql): inspect raw records, bank matching, date coverage, duplicates and seven selected financial measures.
- [02_create_apra_big_four_staging.sql](sql/02_create_apra_big_four_staging.sql): create the typed four-bank monthly table and check its types, coverage, keys and missing amounts.
- [03_check_apra_source_rebuild.sql](sql/03_check_apra_source_rebuild.sql): compare all MADIS source records and the scripted bank mappings against an existing database.
- [04_load_apra_adi_quarterly.sql](sql/04_load_apra_adi_quarterly.sql): load the ADI quarterly back series and check its coverage and bank matching.
- [05_audit_apra_adi_quarterly.sql](sql/05_audit_apra_adi_quarterly.sql): audit quarterly keys, both dates, ten selected numeric measures and liquidity coverage.
- [06_create_apra_big_four_quarterly.sql](sql/06_create_apra_big_four_quarterly.sql): create the typed quarterly table, retain the framework-period label and validate its types, coverage and expected NULLs.
- [07_load_rba_monthly.sql](sql/07_load_rba_monthly.sql): import all 15 RBA series and inspect the raw schema, date coverage and latest rate samples.
- [08_audit_rba_monthly.sql](sql/08_audit_rba_monthly.sql): audit dates and three selected rates, then verify their monthly coverage for both APRA periods.
- [09_create_rba_monthly_staging.sql](sql/09_create_rba_monthly_staging.sql): create the typed monthly reference-rate table and check its retained history, missing values and historical source zero.

## Rebuild the completed data modules

Start with the [APRA rebuild guide](docs/rebuild_apra.md) in a separate empty
DuckDB database, then continue with the [RBA rebuild guide](docs/rebuild_rba.md)
on the same connection. Use the three downloaded workbooks and adjust the source
paths as instructed. The modules were tested with DuckDB v1.5.5 and its official
Excel extension. RBA's APRA-period coverage query requires both APRA staging
tables to exist first.

The guides create `raw.apra_madis`, `raw.apra_adi_quarterly`,
`raw.rba_f1_1_monthly`, `core.dim_bank`, `stg.apra_big_four_monthly`,
`stg.apra_big_four_quarterly` and `stg.rba_monthly_rates`. The remaining three
ABS workbooks and the Power BI report are outside this completed step.
The staging tables are stored snapshots; an automatic refresh process has not
yet been implemented.

## Documentation

- [Initial APRA audit](docs/apra_initial_audit.md): observed results, source references, definitions and audit scope.
- [APRA staging table](docs/apra_staging.md): cleaning rules, data dictionary, observed validation results and execution notes.
- [ADI quarterly source review](docs/apra_adi_source_review.md): source selection, reporting scope, units, date/key audit and liquidity coverage.
- [ADI quarterly staging table](docs/apra_adi_staging.md): 16-column data dictionary, transformation rules and confirmed validation results.
- [APRA rebuild guide](docs/rebuild_apra.md): prerequisites, execution order for both APRA modules and MADIS source-comparison results.
- [RBA source review](docs/rba_source_review.md): workbook layout, series IDs, units, missing-value patterns and confirmed coverage checks.
- [RBA staging table](docs/rba_staging.md): four-column data dictionary, conversion rules and eleven confirmed staging checks.
- [RBA rebuild guide](docs/rebuild_rba.md): prerequisites, execution order and expected results for rebuilding the monthly rate module after APRA.
