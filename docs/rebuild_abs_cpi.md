# Rebuild the ABS CPI modules

This guide reproduces the ABS Table 1 monthly and Table 17 quarterly imports, Australia audits and typed staging tables from the pinned July 2026 workbooks. They retain all 28 months and 312 quarters respectively. Table 18 is the remaining CPI workbook to be processed.

## Prerequisites

- DuckDB v1.5.5 and the official `excel` extension used for the project checks.
- The local workbook `data/raw/04_ABS_CPI_Table1_Monthly_Jul2026.xlsx` (53,630 bytes), described in the [monthly source review](abs_cpi_monthly_source_review.md).
- The local workbook `data/raw/05_ABS_CPI_Table17_Quarterly_Jul2026.xlsx` (80,362 bytes), described in the [quarterly source review](abs_cpi_quarterly_source_review.md). Raw workbooks are excluded from Git.
- The repository's SQL scripts and an existing `raw` schema.
- Both `stg.apra_big_four_monthly` and `stg.apra_big_four_quarterly` for script 11's APRA-period coverage query. Script 14's coverage query requires the quarterly APRA table.

For a complete repository rebuild, start in a separate empty database with the [APRA guide](rebuild_apra.md), then follow the [RBA guide](rebuild_rba.md), and continue here on the same connection. The APRA setup installs/loads Excel support and creates the required schemas and bank mapping. Confirm the active database using [00_check_connection.sql](../sql/00_check_connection.sql).

## Execution order

Run each file's numbered statements sequentially:

| Order | Script | Result |
|---|---|---|
| 1 | [10_load_abs_cpi_monthly.sql](../sql/10_load_abs_cpi_monthly.sql) | Create `raw.abs_cpi_table1_monthly`, inspect types and dates, and preview Australia observations |
| 2 | [11_audit_abs_cpi_monthly.sql](../sql/11_audit_abs_cpi_monthly.sql) | Check the monthly calendar, three Australia measures, missing-value positions and APRA coverage |
| 3 | [12_create_abs_cpi_monthly_staging.sql](../sql/12_create_abs_cpi_monthly_staging.sql) | Create `stg.abs_cpi_australia_monthly`, inspect types and coverage, and run twelve checks |
| 4 | [13_load_abs_cpi_quarterly.sql](../sql/13_load_abs_cpi_quarterly.sql) | Create `raw.abs_cpi_table17_quarterly`, inspect types and dates, and preview Australia observations |
| 5 | [14_audit_abs_cpi_quarterly.sql](../sql/14_audit_abs_cpi_quarterly.sql) | Check quarterly source labels, Australia index/QoQ, missing-value positions and ADI quarterly coverage |
| 6 | [15_create_abs_cpi_quarterly_staging.sql](../sql/15_create_abs_cpi_quarterly_staging.sql) | Create `stg.abs_cpi_australia_quarterly`, inspect types and coverage, and run ten checks |

In script 10, set `abs_cpi_monthly_workbook_path` to the workbook's absolute local path. The import uses **Data1!A10:AB38**: row 10 provides Series IDs, and rows 11-38 provide 28 monthly observations. All 27 series are retained as VARCHAR with a date column named `period_raw`. Rows 1-9 contain metadata and are excluded. Review the source range and expected counts before adopting a different snapshot.

In script 13, set `abs_cpi_quarterly_workbook_path` to the Table 17 workbook's absolute local path. The import uses **Data1!A10:S322**: row 10 provides Series IDs and rows 11-322 provide 312 quarterly observations. All 18 series are retained as VARCHAR with the date column renamed `period_raw`. Metadata rows 1-9 are excluded. The July 2026 release snapshot ends at June quarter 2026, as expected for this quarterly table. Review both imports' fixed ranges and audit expectations when changing snapshots.

Scripts 10, 12, 13 and 15 use `CREATE TABLE`. Run their creation statements once in the rebuild database; they fail if the target table already exists. Their diagnostic statements can be repeated after creation. Scripts 11 and 14 are entirely read-only. Complete each raw audit before creating its staging table. These scripts create stored snapshots and do not implement automatic refresh.

## Expected monthly results

| Check | Expected result |
|---|---|
| Raw schema | 28 VARCHAR columns: `period_raw` and 27 series IDs |
| Raw calendar | 28 rows, 28 months, 2024-04-01 through 2026-07-01 |
| Raw date audit | Invalid dates, non-month-start dates, duplicate months and missing months within the span: all zero |
| Australia measures | 28 records checked per measure; zero nonblank conversion failures |
| Missing values | Index: 0; annual change: 12; monthly change: 1 |
| Monthly-change signs | Seven negative values and three zeros, preserved |
| Missing positions/index positivity | Four issue counts of zero |
| Staging schema | `report_date` DATE, and `cpi_index`, `cpi_yoy_pct`, `cpi_mom_pct` DECIMAL(18,6) |
| Staging calendar | 28 rows, 28 months, 2024-04-30 through 2026-07-31 |
| Staging validation | Twelve PASS rows, including the expected NULL and sign counts |

Raw dates label months with their first day. Staging uses `LAST_DAY` to align the same months with APRA and RBA monthly keys. This conversion does not change the observation month or provide a publication date.

The CPI index uses September 2025 = 100.00. Published changes retain per-cent units in `_pct` fields. For July 2026, index 103.070000, annual change 3.500000 and monthly change 1.000000 are retained. These are the Australia Original series; the other 24 city measures remain in raw. The [staging dictionary](abs_cpi_monthly_staging.md) lists transformation rules and all twelve checks.

## Expected quarterly results

| Check | Expected result |
|---|---|
| Raw schema | 19 VARCHAR columns: `period_raw` and 18 series IDs |
| Raw calendar | 312 rows, 312 quarters, 1948-09-01 through 2026-06-01 |
| Raw date audit | Invalid dates, incorrect quarter labels, duplicate quarters and missing quarters within the span: all zero |
| Australia measures | 312 records checked per measure; zero nonblank conversion failures |
| Missing values | Index: 0; quarterly change: 1, at 1948Q3 only |
| Quarterly-change signs | Twelve negative values and twenty-four zeros, preserved |
| Missing positions/index positivity | Three issue counts of zero |
| Staging schema | `report_date` DATE; `cpi_index` and `cpi_qoq_pct` DECIMAL(18,6) |
| Staging calendar | 312 rows, 312 quarters, 1948-09-30 through 2026-06-30 |
| Staging validation | Ten PASS rows, including expected NULL and sign counts |

Quarterly raw dates label observations with day 1 of the quarter's final month: March, June, September or December. The raw audit validates this convention before staging applies `LAST_DAY`. For example, 2026-06-01 becomes 2026-06-30, both representing 2026Q2. `report_date` identifies the observation quarter and is not the release date.

The selected Australia Original series are A2325846C for index and A2325850V for published QoQ. The latest staged row retains index 102.310000 and quarterly change 0.600000 at 2026-06-30. The other 16 city measures remain in raw. Table 17 has no published YoY column, and this module does not derive one. The [quarterly staging dictionary](abs_cpi_quarterly_staging.md) lists the transformation rules and all ten confirmed checks.

The quarterly index reference is September **month** 2025 = 100.00; September **quarter** 2025 retains index 99.73. ABS re-referencing and rounding affect comparisons between published indexes and derived rates. Preserve the published changes and consult the [quarterly source review](abs_cpi_quarterly_source_review.md) before designing cross-frequency reconciliation. The modules do not calculate monthly/quarterly averages, replace published rates or fill absent monthly observations with quarterly values.

## APRA-period coverage

Script 11 deduplicates APRA bank/date rows and expands each of the 53 ADI quarters into three monthly inputs. It then compares those periods with the monthly CPI source. Expected results:

| Scope | Required months | Matched CPI months | Numeric index months | Numeric YoY months | Numeric MoM months |
|---|---:|---:|---:|---:|---:|
| MADIS monthly | 89 | 28 | 28 | 16 | 27 |
| ADI constituent months | 159 | 24 | 24 | 12 | 23 |

MADIS overlaps April 2024-July 2026; ADI overlaps April 2024-March 2026. The reported unavailable months include earlier absent source months and expected early blanks. They remain unavailable. The source review records all six rows, including those unavailable counts. This coverage query does not calculate quarterly CPI or combine APRA financial measures.

Script 14 uses the 53 distinct ADI quarters directly, without expanding them into months. Both quarterly CPI measures have **53 required, 53 matched and 53 numeric quarters, with 0 unavailable**, covering 2013Q1-2026Q1. CPI's final 2026Q2 observation lies outside that APRA period. Invalid source labels do not match. Matched/numeric row counts expose duplicate inflation, so coverage must be read alongside the date and numeric audits. Complete quarterly coverage does not extend the monthly CPI series or resolve APRA reporting-scope differences.

## Validation record

Monthly project results were confirmed through DBeaver on 2026-09-11: the raw schema, calendar and five preview rows; all four audit outputs; and the staging schema, month-end calendar and twelve PASS checks.

Independent in-memory DuckDB v1.5.5 tests executed the scripts against the original workbook. Audit tests used both APRA staging tables rebuilt from their source files. Independent workbook reads matched 28 raw dates and 756 raw series cells at the documented numeric precision, including 117 NULLs. Staging comparisons matched all 28 calendar-derived month ends and 84 selected measure cells, including 13 NULLs. Audit tests also detected missing/duplicate months, nonnumeric values, displaced blanks and invalid or non-first-day dates.

Quarterly project results were confirmed through DBeaver on 2026-09-13: the raw schema and calendar, five audit outputs including the latest Australia observations, and the staging schema, quarter-end calendar and ten PASS checks. Independent module tests ran the exact quarterly scripts in new in-memory databases. Raw comparisons matched all 312 source date cells and 5,616 series cells, including 265 NULLs. Staging comparisons matched 312 independently calculated quarter ends and 624 selected measure cells, including one NULL. Numeric comparisons used six-decimal precision. Audit fault tests detected missing/duplicate quarters, nonnumeric or nonpositive indexes, a relocated QoQ blank, invalid dates/labels and an empty input table.

Tests used the installed Excel extension and did not open the populated project database, modify source workbooks or test a fresh extension download. The selected Australia audit and staging checks do not establish numeric audit coverage for every city series. Table 18 and the analytical model remain outside these completed modules.
