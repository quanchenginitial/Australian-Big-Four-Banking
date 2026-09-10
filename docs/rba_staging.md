# RBA monthly reference-rate staging table

Status on 2026-09-11: the raw import, selected-rate audit, APRA-period coverage and typed staging table are confirmed in the project database. The staging script has also passed independent source-to-table testing.

## Purpose and retained history

[09_create_rba_monthly_staging.sql](../sql/09_create_rba_monthly_staging.sql) creates `stg.rba_monthly_rates` from `raw.rba_f1_1_monthly`, following the [08 audit](../sql/08_audit_rba_monthly.sql). It retains all **687 months**, from 1969-06-30 through 2026-08-31, for three selected reference rates. Early missing values are preserved. The original 15 series remain available in the raw table.

This table has one row per month, with no bank column. Keeping the full selected history makes the transformation independent of a particular reporting window. Later analytical datasets or report filters select the appropriate APRA period. Source definitions and the observed availability of the other series are recorded in the [source review](rba_source_review.md).

## Data dictionary

| Column | Type | Source | Meaning |
|---|---|---|---|
| `report_date` | DATE | `period_raw` | Month-end label identifying the observation month |
| `cash_rate_target_pct` | DECIMAL(18,6) | FIRMMCRT | Monthly average cash-rate target, per cent |
| `interbank_cash_rate_pct` | DECIMAL(18,6) | FIRMMCRI | Monthly average interbank overnight cash rate, per cent |
| `bank_bill_3m_pct` | DECIMAL(18,6) | FIRMMBAB90 | Monthly average three-month bank-accepted bill / negotiable certificate of deposit rate, per cent |

## Transformation and use

- Dates use `DATE '1899-12-30' + CAST(TRIM(period_raw) AS INTEGER)`, consistent with the workbook's Excel 1900 date system and the completed integer-serial audit.
- Rates use `CAST(NULLIF(TRIM(...), '') AS DECIMAL(18,6))`. Blank text becomes NULL, and invalid nonblank numeric text raises an error. Conversion removes insignificant floating-point text tails at the documented six-decimal precision.
- The `_pct` suffix means **per-cent units**: `4.350000` represents 4.35%. The table does not divide by 100. For a later percentage-formatted report field, first convert this value to the fraction `0.0435` by dividing by 100 once; applying a percentage format directly to 4.35 would display 435%.
- The rates are monthly averages. Month-end date labels do not make them end-month observations. Do not sum rates over months or banks. Any later quarterly aggregation must explicitly define its method.
- Cash-rate-target history has 254 NULLs and interbank-rate history has 83 NULLs in the pinned snapshot. They remain NULL rather than being filled with zero or carried backward from a later observation.
- The bank-bill series contains one source zero at 1969-11-30. The table retains it and the validation query identifies its date. Reproducing it is not a judgment that it is an economically valid rate or an encoded missing value. It lies outside both current APRA analysis periods.
- The intended key is the observation month. The initial `CREATE TABLE AS` does not declare a primary key or NOT NULL constraints; the post-creation checks examine actual dates and duplicates. A nullable column definition does not itself indicate a data error.
- The table is a stored snapshot. Creation fails if it already exists, leaving the existing table intact. Changes in raw inputs do not automatically refresh it; a future refresh procedure must rebuild it explicitly.

## Confirmed project-database validation

The five script sections create the staging schema if necessary, create the table once, inspect its types, summarize its history, and show eleven checks vertically. Sections 3-5 can be repeated after creation.

The user's DBeaver results on 2026-09-11 confirmed section 3's four columns: one DATE and three DECIMAL(18,6) columns. Section 4 returned 687 rows, 687 distinct months, first date 1969-06-30 and last date 2026-08-31.

Section 5 returned eleven PASS results:

| Check | Actual count | Expected count | Status |
|---|---:|---:|---|
| Duplicate month-key groups | 0 | 0 | PASS |
| Missing date rows | 0 | 0 | PASS |
| Non-month-end rows | 0 | 0 | PASS |
| Cash-rate-target missing values | 254 | 254 | PASS |
| Interbank cash-rate missing values | 83 | 83 | PASS |
| Three-month bank-bill missing values | 0 | 0 | PASS |
| Cash-rate-target zeros | 0 | 0 | PASS |
| Interbank cash-rate zeros | 0 | 0 | PASS |
| Three-month bank-bill zeros | 1 | 1 | PASS |
| Three-month bank-bill zeros dated November 1969 | 1 | 1 | PASS |
| Rows with any negative selected rate | 0 | 0 | PASS |

The two counts of 1 refer to the same historical source cell: one check counts all bank-bill zeros and the other confirms its known date. PASS means the table preserves these snapshot expectations, including NULLs and that flagged zero. The project staging query confirmed the full-history zero counts as well as the other checks above.

The 08 project audit confirmed complete numeric coverage and no zero values for all three selected rates across the 89 months required by MADIS (March 2019-July 2026) and all 159 constituent months of the 53 ADI quarters (January 2013-March 2026). This is coverage of monthly inputs, not a completed quarterly-rate calculation.

## Independent validation

The exact 07 import and 09 staging queries were tested in a new in-memory DuckDB v1.5.5 database using the installed Excel extension and the original workbook. All schema, count, date and eleven-check expectations passed. The project database was not opened and the source workbook was not modified.

An independent workbook read matched all 687 dates and 2,061 selected rate cells at six decimal places: 1,724 numeric values and 337 NULLs. The sole bank-bill zero remained at 1969-11-30. The latest staged row retained target 4.350000, interbank cash rate 4.350000 and three-month bank-bill rate 4.510000 for August 2026. Checks of the typed values in both APRA periods also retained 159 and 89 unique months, with all three rates populated and positive.

The independent value comparisons supplement the observed project results above. Follow the [RBA rebuild guide](rebuild_rba.md) to reproduce the module after the APRA prerequisites. The stored staging table does not refresh automatically.
