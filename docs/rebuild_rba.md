# Rebuild the RBA monthly rate module

This guide adds the RBA F1.1 monthly money-market import, selected-rate audit and typed staging table to a separate test database. It preserves the downloaded snapshot and all its 687 months. The three ABS workbooks and the Power BI report remain outside this completed module.

## Prerequisites

- DuckDB v1.5.5 and its official `excel` extension, as used for the project checks.
- The pinned workbook `data/raw/03_RBA_F1_1_Monthly_Money_Market.xlsx`, whose metadata publication date is 1 September 2026. It is excluded from Git.
- The repository's SQL scripts and the existing `raw` schema.
- Both `stg.apra_big_four_monthly` and `stg.apra_big_four_quarterly` for script 08's APRA-period coverage query.

For a new empty database, first complete the [APRA rebuild guide](rebuild_apra.md), including its input setup and both staging tables. That setup installs/loads Excel support and creates the raw schema. Then continue below on the same database connection. The APRA tables are needed to determine the bank-analysis periods; RBA observations themselves have no bank code.

## Execution order

Confirm that DBeaver is connected to the separate rebuild database, rather than an already populated project database. [00_check_connection.sql](../sql/00_check_connection.sql) displays the active database and path.

Run these three files in order, executing each file's numbered statements sequentially:

| Order | Script | Result |
|---|---|---|
| 1 | [07_load_rba_monthly.sql](../sql/07_load_rba_monthly.sql) | Create `raw.rba_f1_1_monthly`, then inspect schema, dates and latest samples |
| 2 | [08_audit_rba_monthly.sql](../sql/08_audit_rba_monthly.sql) | Audit the monthly calendar, three reference rates and their APRA-period coverage |
| 3 | [09_create_rba_monthly_staging.sql](../sql/09_create_rba_monthly_staging.sql) | Create `stg.rba_monthly_rates`, then inspect types, history and eleven validation checks |

In script 07, set `rba_workbook_path` to the workbook's absolute local path before running the import. The script uses `Data!A11:P698`: row 11 supplies series-ID headers and rows 12-698 supply 687 observations. Worksheet formatting extends farther than the data and is not part of the import range. If adopting a newer snapshot, review the filename, sheet, header, range and expected counts before changing the scripts.

Scripts 07 and 09 use `CREATE TABLE` and do not replace an existing table. Their creation statements run once in the rebuild database. The diagnostic queries are repeatable after the required tables exist. Script 08 is entirely read-only. These scripts do not implement an automatic refresh of a populated database.

## Expected results

| Check | Expected result for the pinned snapshot |
|---|---|
| Raw schema | 16 VARCHAR columns: `period_raw` and 15 series IDs |
| Raw and staging coverage | 687 rows, 687 months, 1969-06-30 through 2026-08-31 |
| Date audit | Invalid dates, non-month-end rows, duplicate months and missing months within the full span: all zero |
| Selected rates | FIRMMCRT, FIRMMCRI and FIRMMBAB90: 687 records checked each |
| Missing rates | Cash-rate target: 254; interbank cash rate: 83; three-month bank-bill rate: 0 |
| Nonblank conversion failures and negative values | Zero for all three selected series |
| Historical zero | One bank-bill source value at 1969-11-30, retained and flagged |
| APRA period coverage | Each selected rate matches all 159 months needed for ADI quarters and all 89 MADIS months, with no missing numeric values or zeros in those windows |
| Staging schema | One DATE field and three DECIMAL(18,6) rate fields |
| Staging validation | Eleven PASS rows; expected historical NULL and zero counts remain present |

The ADI coverage calculation expands each of the 53 quarters into its three monthly inputs, beginning in January 2013 and ending in March 2026. MADIS uses March 2019-July 2026. Script 08 deduplicates APRA bank/date rows before joining the market-wide RBA observations. It checks monthly input availability without calculating a quarterly interest rate.

Rates stay in **per-cent units**, so the latest August 2026 row has target 4.350000, interbank rate 4.350000 and three-month bank-bill rate 4.510000. These are monthly averages. See the [source review](rba_source_review.md) and [staging dictionary](rba_staging.md) for units, series definitions and treatment of historical blanks and the flagged zero.

## Validation record

Project results were confirmed through DBeaver on 2026-09-11. The import returned the expected schema, coverage and latest samples. The audit confirmed dates, selected-rate missing/conversion checks and complete APRA-period coverage. The subsequent staging checks confirmed all four column types, all 687 months and eleven PASS results, including preservation of the known November 1969 bank-bill zero.

Independent in-memory DuckDB v1.5.5 tests also executed the source-loading, audit and staging scripts against the original workbook. The APRA-period audit used APRA staging tables rebuilt from their source workbooks. An independent workbook read matched all 687 staged dates and 2,061 selected rate cells at six decimal places, including 337 NULLs. Missing-month, nonnumeric-rate and duplicate-month test cases were detected. The tests used the installed Excel extension; they did not test a fresh extension download or open the populated project database.

The source-to-staging tests and observed project checks support this selected-rate module. They do not assert economic validity of the flagged 1969 zero, suitability of all 15 raw series for every analysis window, or a full raw-table `EXCEPT ALL` reconciliation like the separate MADIS comparison.
