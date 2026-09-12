# Australia monthly CPI staging table

Status on 2026-09-11: the raw import, four-part audit and typed staging table are confirmed in the project database. The staging script also passed independent source-to-table testing.

## Purpose and grain

[12_create_abs_cpi_monthly_staging.sql](../sql/12_create_abs_cpi_monthly_staging.sql) creates `stg.abs_cpi_australia_monthly` from `raw.abs_cpi_table1_monthly`, following the [11 audit](../sql/11_audit_abs_cpi_monthly.sql). It retains all 28 months, April 2024-July 2026, and the three Australia Original series. The table has one row per month. Geography is fixed to Australia, as stated in the table name, and there is no bank column.

The 24 city measures and original date labels remain available in the raw table. The [source review](abs_cpi_monthly_source_review.md) records the complete series register, source definitions and observed project audit.

## Data dictionary

| Column | Type | Source | Meaning |
|---|---|---|---|
| report_date | DATE | period_raw | Month-end label for the source observation month |
| cpi_index | DECIMAL(18,6) | A130393720C | Australia All groups CPI index, September 2025 = 100.00 |
| cpi_yoy_pct | DECIMAL(18,6) | A130393721F | Published change from the corresponding month of the previous year, per cent |
| cpi_mom_pct | DECIMAL(18,6) | A130393722J | Published change from the previous month, per cent |

## Transformation rules

- Convert the audited integer Excel date serial using `DATE '1899-12-30' + CAST(TRIM(period_raw) AS INTEGER)`, then apply `LAST_DAY`. For example, source label 2026-07-01 becomes report_date 2026-07-31. This preserves the observation month and aligns monthly keys with the APRA and RBA staging tables. It does not represent the publication date or change a monthly statistic into a measurement taken on the last day.
- Use `CAST(NULLIF(TRIM(...), '') AS DECIMAL(18,6))` for each selected measure. Blanks remain NULL; invalid nonblank numeric text raises an error. Raw text remains available and unchanged.
- Keep the published index and changes separately. The index remains 103.07 in July 2026; annual change 3.5 represents 3.5%. Divide `_pct` values by 100 once if creating fraction-based, percentage-formatted reporting fields. Do not apply percentage formatting to the index.
- Preserve the 12 early YoY NULLs and one initial MoM NULL. Keep all seven negative MoM values and three MoM zeros. These counts describe the pinned snapshot; neither negative nor zero inflation changes are automatically errors.
- Retain all months without joining or filtering to a bank-analysis period. The completed audit found 28 matched MADIS months and 24 matched ADI constituent months, with measure-specific numeric coverage. Earlier CPI observations remain unavailable.
- Use the published YoY and MoM series rather than replacing them with calculations from the displayed rounded index. Later analytical calculations must document their own precision and definitions.
- The intended key is report_date, with one record per month. The initial `CREATE TABLE AS` does not declare primary-key or NOT NULL constraints. The post-creation checks validate the observed keys and values.
- This is a stored snapshot. The creation statement fails if the table already exists, and raw-table changes do not refresh it automatically.

## Execution and confirmed project results

Run the five numbered sections in order on the project connection: ensure the staging schema exists, create the table once, inspect types, summarize dates, and run the twelve checks. Sections 3-5 can be repeated after creation.

Project queries confirmed one DATE and three DECIMAL(18,6) columns, with 28 rows and 28 distinct months from **2024-04-30 to 2026-07-31**. The month-end dates intentionally differ from the first-day labels displayed by the raw import. All twelve validation rows matched the expected counts:

| Check | Actual count | Expected count | Status |
|---|---:|---:|---|
| duplicate_month_keys | 0 | 0 | PASS |
| missing_date_rows | 0 | 0 | PASS |
| non_month_end_rows | 0 | 0 | PASS |
| missing_months_in_span | 0 | 0 | PASS |
| cpi_index_missing | 0 | 0 | PASS |
| cpi_yoy_missing | 12 | 12 | PASS |
| cpi_mom_missing | 1 | 1 | PASS |
| nonpositive_index_rows | 0 | 0 | PASS |
| unexpected_yoy_null_pattern | 0 | 0 | PASS |
| unexpected_mom_null_pattern | 0 | 0 | PASS |
| cpi_mom_negative | 7 | 7 | PASS |
| cpi_mom_zero | 3 | 3 | PASS |

The missing-pattern checks use month-end boundaries: YoY begins on 2025-04-30 and MoM on 2024-05-31. Interpret the checks together with the row/date summary and confirmed raw audit; matching a few counts alone cannot verify every source value. Follow the [ABS monthly CPI rebuild guide](rebuild_abs_cpi.md) to reproduce the module.

## Independent validation

The exact import and staging scripts ran in a new in-memory DuckDB v1.5.5 database using the installed official Excel extension. All column names and types, the history summary and the twelve checks passed.

An independent workbook read compared all 28 dates with calendar-derived month ends and all 84 selected measure cells with the staged values: 71 numeric values at six-decimal precision and 13 NULLs. All matched, including the February month ends and the September 2025 reference index of 100. The latest row retained index 103.070000, YoY 3.500000 and MoM 1.000000 at 2026-07-31.

Filtering the staged dates to the previously confirmed APRA periods retained 28 MADIS months and 24 ADI constituent months. Numeric index/YoY/MoM counts remained 28/16/27 and 24/12/23 respectively. This verified retained period coverage without calculating quarterly CPI or building bank joins.

The source workbook hash was unchanged and the populated project database was not opened by the independent tests. The subsequent DBeaver results confirmed the project table's schema, full month-end history and twelve PASS checks. Quarterly CPI workbooks and the analytical model remain later steps.
