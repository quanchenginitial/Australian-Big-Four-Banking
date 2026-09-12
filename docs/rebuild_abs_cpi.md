# Rebuild the ABS monthly CPI module

This guide reproduces the ABS Table 1 monthly import, Australia audit and typed staging table from the pinned July 2026 workbook. It retains all 28 months. The two quarterly CPI workbooks are later modules.

## Prerequisites

- DuckDB v1.5.5 and the official `excel` extension used for the project checks.
- The local workbook `data/raw/04_ABS_CPI_Table1_Monthly_Jul2026.xlsx` (53,630 bytes). Raw workbooks are excluded from Git. Source details are recorded in the [source review](abs_cpi_monthly_source_review.md).
- The repository's SQL scripts and an existing `raw` schema.
- Both `stg.apra_big_four_monthly` and `stg.apra_big_four_quarterly` for script 11's APRA-period coverage query.

For a complete repository rebuild, start in a separate empty database with the [APRA guide](rebuild_apra.md), then follow the [RBA guide](rebuild_rba.md), and continue here on the same connection. The APRA setup installs/loads Excel support and creates the required schemas and bank mapping. Confirm the active database using [00_check_connection.sql](../sql/00_check_connection.sql).

## Execution order

Run each file's numbered statements sequentially:

| Order | Script | Result |
|---|---|---|
| 1 | [10_load_abs_cpi_monthly.sql](../sql/10_load_abs_cpi_monthly.sql) | Create `raw.abs_cpi_table1_monthly`, inspect types and dates, and preview Australia observations |
| 2 | [11_audit_abs_cpi_monthly.sql](../sql/11_audit_abs_cpi_monthly.sql) | Check the monthly calendar, three Australia measures, missing-value positions and APRA coverage |
| 3 | [12_create_abs_cpi_monthly_staging.sql](../sql/12_create_abs_cpi_monthly_staging.sql) | Create `stg.abs_cpi_australia_monthly`, inspect types and coverage, and run twelve checks |

In script 10, set `abs_cpi_monthly_workbook_path` to the workbook's absolute local path. The import uses **Data1!A10:AB38**: row 10 provides Series IDs, and rows 11-38 provide 28 monthly observations. All 27 series are retained as VARCHAR with a date column named `period_raw`. Rows 1-9 contain metadata and are excluded. Review the source range and expected counts before adopting a different snapshot.

Scripts 10 and 12 use `CREATE TABLE`. Run their creation statements once in the rebuild database; they fail if the target table already exists. Their diagnostic statements can be repeated after creation. Script 11 is entirely read-only. These scripts create stored snapshots and do not implement automatic refresh.

## Expected results for the pinned workbook

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

## APRA-period coverage

Script 11 deduplicates APRA bank/date rows and expands each of the 53 ADI quarters into three monthly inputs. It then compares those periods with the monthly CPI source. Expected results:

| Scope | Required months | Matched CPI months | Numeric index months | Numeric YoY months | Numeric MoM months |
|---|---:|---:|---:|---:|---:|
| MADIS monthly | 89 | 28 | 28 | 16 | 27 |
| ADI constituent months | 159 | 24 | 24 | 12 | 23 |

MADIS overlaps April 2024-July 2026; ADI overlaps April 2024-March 2026. The reported unavailable months include earlier absent source months and expected early blanks. They remain unavailable. The source review records all six rows, including those unavailable counts. This coverage query does not calculate quarterly CPI or combine APRA financial measures.

## Validation record

Project results were confirmed through DBeaver on 2026-09-11: the raw schema, calendar and five preview rows; all four audit outputs; and the staging schema, month-end calendar and twelve PASS checks.

Independent in-memory DuckDB v1.5.5 tests executed the scripts against the original workbook. Audit tests used both APRA staging tables rebuilt from their source files. Independent workbook reads matched 28 raw dates and 756 raw series cells at the documented numeric precision, including 117 NULLs. Staging comparisons matched all 28 calendar-derived month ends and 84 selected measure cells, including 13 NULLs. Audit tests also detected missing/duplicate months, nonnumeric values, displaced blanks and invalid or non-first-day dates.

Tests used the installed Excel extension and did not open the populated project database, modify source workbooks or test a fresh extension download. The selected Australia audit and staging checks do not establish numeric audit coverage for every city series. The separate source files, units and coverage must remain explicit when the quarterly CPI modules are added.
