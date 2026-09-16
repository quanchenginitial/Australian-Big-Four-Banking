# Rebuild the ABS CPI modules

This guide reproduces the ABS Table 1 monthly, Table 17 quarterly and Table 18 quarterly detail modules from the pinned July 2026 workbooks. The headline staging tables retain 28 months and 312 quarters respectively. The detail table preserves all 396 series across 312 quarters, including unavailable observations, for 123,552 rows. Project import, audit and staging results are confirmed for all three modules.

## Prerequisites

- DuckDB v1.5.5 and the official `excel` extension used for the project checks.
- The local workbook `data/raw/04_ABS_CPI_Table1_Monthly_Jul2026.xlsx` (53,630 bytes), described in the [monthly source review](abs_cpi_monthly_source_review.md).
- The local workbook `data/raw/05_ABS_CPI_Table17_Quarterly_Jul2026.xlsx` (80,362 bytes), described in the [quarterly source review](abs_cpi_quarterly_source_review.md).
- The local workbook `data/raw/06_ABS_CPI_Table18_Quarterly_Detail_Jul2026.xlsx` (405,162 bytes), described in the [quarterly detail source review](abs_cpi_quarterly_detail_source_review.md). Raw workbooks are excluded from Git.
- The repository's SQL scripts and an existing `raw` schema.
- Both `stg.apra_big_four_monthly` and `stg.apra_big_four_quarterly` for script 11's APRA-period coverage query. Scripts 14 and 17 require the quarterly APRA table for coverage checks.
- Script 17 also requires `stg.abs_cpi_australia_quarterly` for Table 18's reconciliation with Table 17. Following the order below creates it first.

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
| 7 | [16_load_abs_cpi_quarterly_detail.sql](../sql/16_load_abs_cpi_quarterly_detail.sql) | Create separate Table 18 raw tables for Data1 and Data2; inspect schemas, calendars and latest All groups values |
| 8 | [17_audit_abs_cpi_quarterly_detail.sql](../sql/17_audit_abs_cpi_quarterly_detail.sql) | Audit both calendars and all 396 series, reconcile Table 17 headline measures and check ADI-period coverage |
| 9 | [18_create_abs_cpi_quarterly_detail_staging.sql](../sql/18_create_abs_cpi_quarterly_detail_staging.sql) | Create the typed detail table with source metadata; run fifteen checks and two complete raw/staging comparisons |

In script 10, set `abs_cpi_monthly_workbook_path` to the workbook's absolute local path. The import uses **Data1!A10:AB38**: row 10 provides Series IDs, and rows 11-38 provide 28 monthly observations. All 27 series are retained as VARCHAR with a date column named `period_raw`. Rows 1-9 contain metadata and are excluded. Review the source range and expected counts before adopting a different snapshot.

In script 13, set `abs_cpi_quarterly_workbook_path` to the Table 17 workbook's absolute local path. The import uses **Data1!A10:S322**: row 10 provides Series IDs and rows 11-322 provide 312 quarterly observations. All 18 series are retained as VARCHAR with the date column renamed `period_raw`. Metadata rows 1-9 are excluded. The July 2026 release snapshot ends at June quarter 2026, as expected for this quarterly table. Review both imports' fixed ranges and audit expectations when changing snapshots.

In script 16, set `abs_cpi_quarterly_detail_workbook_path` to the Table 18 workbook's absolute local path. Import **Data1!A10:IQ322** and **Data2!A10:EQ322** separately. Both have Series IDs in row 10 and 312 quarterly date rows in rows 11-322. Data1 contains 132 indexes and 118 QoQ series; Data2 contains the remaining 14 QoQ series and 132 contribution series. All raw columns are VARCHAR, the first column is `period_raw`, and `stop_at_empty = false` retains earlier empty observations. The sheets contain different measures over the same calendar, not consecutive blocks of history.

Scripts 10, 12, 13, 15, 16 and 18 use `CREATE TABLE`. Run their creation statements once in the rebuild database; they fail if the target table already exists. Their diagnostic statements can be repeated after creation. Scripts 11, 14 and 17 are entirely read-only. Complete each raw audit before creating its staging table. These scripts create stored snapshots and do not implement automatic refresh.

For script 17, execute each of its five complete statements, including all CTEs through the final semicolon. For script 18, select the complete creation statement, including the 396-row metadata register and final SELECT. The register matches by source sheet and Series ID, not category name or column position. Review all three imports' fixed ranges, audit expectations and Table 18 metadata register when changing source snapshots.

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

## Expected Table 17 quarterly results

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

## Expected Table 18 quarterly detail results

| Check | Expected result |
|---|---|
| Raw schemas | Data1: 251 VARCHAR columns; Data2: 147 VARCHAR columns; first column `period_raw` in both |
| Raw calendars | Each sheet: 312 rows and quarters, 1948-09-01 through 2026-06-01 |
| Calendar/cross-sheet audit | Sixteen issue counts of zero |
| All-series metric profile | Three families, each with 132 series and 41,184 cells; conversion failures all zero |
| Series metadata/coverage audit | Ten issue counts of zero |
| Table 17 reconciliation | Five PASS rows: 312 matched quarters; missing rows and index/QoQ differences all zero |
| Staging schema | Seven columns: DATE, five VARCHAR fields and DECIMAL(18,6) |
| Staging records/calendar | 123,552 rows, 396 Series IDs, 312 quarters, 1948-09-30 through 2026-06-30 |
| Staging validation | Fifteen PASS rows |
| Full typed raw/staging comparison | Two PASS rows, zero differences in each direction |

The three family profiles preserve these source values:

| Metric | Numeric values | NULLs | Negative values | Zeros |
|---|---:|---:|---:|---:|
| cpi_index | 22,813 | 18,371 | 0 | 0 |
| cpi_qoq_pct | 22,681 | 18,503 | 5,537 | 1,280 |
| cpi_contribution_index_points | 396 | 40,788 | 0 | 0 |

The detail table's logical key is `(series_id, report_date)`. It retains each series-quarter cell through `UNPIVOT INCLUDE NULLS`, attaches source category/metric/unit metadata, and uses the same audited quarter-label conversion as Table 17. There are 124 distinct category display names, with some shared by separate IDs within a measure family. Preserve the IDs; do not deduplicate by name or infer hierarchy levels.

Contributions are in Index Points. All 132 contribution series have only three numeric observations, 2025Q4-2026Q2, with earlier blanks preserved. Index numbers, QoQ percentages and contribution index points must be interpreted separately. The table does not derive YoY, fill gaps or aggregate overlapping categories. Its All groups index and QoQ are the same headline observations retained in Table 17.

Script 18's final check compares every typed `(report_date, series_id, source_sheet, metric_value)` in both directions with `EXCEPT ALL`, including NULLs and duplicate multiplicity. It checks transformation fidelity; the fixed metadata mapping was independently compared with the workbook during preparation. See the [detail staging dictionary](abs_cpi_quarterly_detail_staging.md) for all seven fields and the fifteen expected checks.

## APRA-period coverage

Script 11 deduplicates APRA bank/date rows and expands each of the 53 ADI quarters into three monthly inputs. It then compares those periods with the monthly CPI source. Expected results:

| Scope | Required months | Matched CPI months | Numeric index months | Numeric YoY months | Numeric MoM months |
|---|---:|---:|---:|---:|---:|
| MADIS monthly | 89 | 28 | 28 | 16 | 27 |
| ADI constituent months | 159 | 24 | 24 | 12 | 23 |

MADIS overlaps April 2024-July 2026; ADI overlaps April 2024-March 2026. The reported unavailable months include earlier absent source months and expected early blanks. They remain unavailable. The source review records all six rows, including those unavailable counts. This coverage query does not calculate quarterly CPI or combine APRA financial measures.

Script 14 uses the 53 distinct ADI quarters directly, without expanding them into months. Both quarterly CPI measures have **53 required, 53 matched and 53 numeric quarters, with 0 unavailable**, covering 2013Q1-2026Q1. CPI's final 2026Q2 observation lies outside that APRA period. Invalid source labels do not match. Matched/numeric row counts expose duplicate inflation, so coverage must be read alongside the date and numeric audits. Complete quarterly coverage does not extend the monthly CPI series or resolve APRA reporting-scope differences.

Script 17 uses all 396 detail series and the same 53 distinct ADI quarters, 2013Q1-2026Q1. Each measure family requires **132 series × 53 quarters = 6,996 cells**:

| Metric | Required cells | Matched cells | Numeric cells | Unavailable cells |
|---|---:|---:|---:|---:|
| cpi_index | 6,996 | 6,996 | 6,996 | 0 |
| cpi_qoq_pct | 6,996 | 6,996 | 6,996 | 0 |
| cpi_contribution_index_points | 6,996 | 6,996 | 264 | 6,732 |

Only 2025Q4 and 2026Q1 contribution observations fall within that ADI period. Their limited coverage is retained rather than filled. Read these counts with the calendar and metadata audit results; they do not establish additivity across expenditure categories or comparable APRA reporting scopes.

## Validation record

Monthly project results were confirmed through DBeaver on 2026-09-11: the raw schema, calendar and five preview rows; all four audit outputs; and the staging schema, month-end calendar and twelve PASS checks.

Independent in-memory DuckDB v1.5.5 tests executed the scripts against the original workbook. Audit tests used both APRA staging tables rebuilt from their source files. Independent workbook reads matched 28 raw dates and 756 raw series cells at the documented numeric precision, including 117 NULLs. Staging comparisons matched all 28 calendar-derived month ends and 84 selected measure cells, including 13 NULLs. Audit tests also detected missing/duplicate months, nonnumeric values, displaced blanks and invalid or non-first-day dates.

Quarterly project results were confirmed through DBeaver on 2026-09-13: the raw schema and calendar, five audit outputs including the latest Australia observations, and the staging schema, quarter-end calendar and ten PASS checks. Independent module tests ran the exact quarterly scripts in new in-memory databases. Raw comparisons matched all 312 source date cells and 5,616 series cells, including 265 NULLs. Staging comparisons matched 312 independently calculated quarter ends and 624 selected measure cells, including one NULL. Numeric comparisons used six-decimal precision. Audit fault tests detected missing/duplicate quarters, nonnumeric or nonpositive indexes, a relocated QoQ blank, invalid dates/labels and an empty input table.

Table 18 project results were confirmed through DBeaver on 2026-09-13: both raw schemas/calendars and five preview rows, all five raw-audit outputs, and the staging schema, overview, fifteen PASS checks and two zero-difference source comparisons. The final staging checks were confirmed at 02:31:12 and the comparisons at 02:31:29.

Independent Table 18 tests ran the exact import, audit and staging scripts in new in-memory databases, rebuilding their dependencies as needed from the pinned workbooks. Raw comparisons matched all 624 date cells across the two sheets and all 123,552 measure cells. A fresh workbook read independently matched every complete staged record, including quarter-end dates, all 396 metadata mappings, 45,890 numeric values at six-decimal precision and 77,662 NULLs. Twelve raw-audit fault scenarios and four staging-check fault scenarios confirmed detection of missing/duplicate observations, invalid values/dates, misplaced blanks, series/register problems, changed values and missing metadata.

Tests used the installed Excel extension and did not open the populated project database, modify source workbooks or test a fresh extension download. Table 1 and Table 17 numeric audits select Australia and do not establish numeric audit coverage for every city series; Table 18 audits all 396 series. The core analysis model and all four Power BI pages have since been accepted; see the [SQL model rebuild](rebuild_analysis_model.md) and [Power BI rebuild](rebuild_power_bi.md). Table 18 category-level reporting remains a separate extension.
