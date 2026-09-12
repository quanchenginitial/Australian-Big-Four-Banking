# Australia quarterly CPI staging table

Status on 2026-09-13: the raw import, five-part Australia audit and typed staging table are confirmed in the project database. The staging script also passed independent source-to-table testing.

## Purpose and grain

[15_create_abs_cpi_quarterly_staging.sql](../sql/15_create_abs_cpi_quarterly_staging.sql) creates `stg.abs_cpi_australia_quarterly` from `raw.abs_cpi_table17_quarterly`, following the [14 audit](../sql/14_audit_abs_cpi_quarterly.sql). It retains all 312 quarters from 1948Q3 through 2026Q2 and the two Australia Original series. The table has one row per quarter. Geography is fixed to Australia, with no bank column.

The 16 city measures and original date labels remain in raw. The [source review](abs_cpi_quarterly_source_review.md) records the complete series register, units, reference basis and confirmed project audit. Table 17 has no published YoY column; this staging step contains only the index and published quarterly change.

## Data dictionary

| Column | Type | Source | Meaning |
|---|---|---|---|
| report_date | DATE | period_raw | Quarter-end label for the source observation quarter |
| cpi_index | DECIMAL(18,6) | A2325846C | Australia All groups CPI index, September month 2025 = 100.00 |
| cpi_qoq_pct | DECIMAL(18,6) | A2325850V | Published change from the previous quarter, per cent |

## Transformation rules

- Convert the audited integer Excel serial using `DATE '1899-12-30' + CAST(TRIM(period_raw) AS INTEGER)`, then apply `LAST_DAY`. The completed raw audit confirms that each source date is day 1 of March, June, September or December. Consequently, month end is also quarter end: 2026-06-01 becomes 2026-06-30. This labels the observation quarter and aligns calendar keys with APRA quarterly staging. It is not a publication date or a claim that CPI was measured only on the last day.
- Use `CAST(NULLIF(TRIM(...), '') AS DECIMAL(18,6))` for each measure. Blanks remain NULL and invalid nonblank numeric text raises an error. The raw source text remains available.
- Keep the index and published QoQ separately. At June quarter 2026, index 102.31 and quarterly change 0.6 retain their original units. For a later fraction-based percentage field, divide `_pct` by 100 once. Do not format the index as a percentage.
- Preserve the initial QoQ NULL at 1948Q3, all 12 negative changes and all 24 zero changes. These counts describe the pinned July 2026 workbook, not permanent CPI constraints.
- Preserve the source reference basis: September **month** 2025 = 100.00. September **quarter** 2025 retains 99.73. Do not replace published QoQ with a calculation from rounded index numbers or add an undocumented derived YoY field.
- Retain the complete quarterly history without filtering to APRA dates, joining to banks or extending quarterly observations into missing monthly CPI history. The raw audit confirmed complete numeric coverage of both measures across APRA's 53 quarters, 2013Q1-2026Q1.
- The intended key is `report_date`, with one row per quarter. This initial `CREATE TABLE AS` declares neither primary-key nor NOT NULL constraints; the post-creation queries validate the observed keys and values.
- This is a stored snapshot. Creation fails if the table already exists, and later raw-table changes do not refresh it automatically. Rerun the raw audit if the source changes before staging.

## Execution and confirmed project results

Run the five numbered sections in order on the project connection: ensure the staging schema exists, create the table once, inspect types, summarize quarterly history and run the ten checks. Sections 3-5 are repeatable read-only queries.

Project queries confirmed one DATE and two DECIMAL(18,6) columns, with **312 rows and 312 distinct quarters, 1948-09-30 through 2026-06-30**. The day component intentionally changes from the raw first-day labels to quarter ends. All ten validation rows matched their expected counts:

| Check | Actual count | Expected count | Status |
|---|---:|---:|---|
| duplicate_quarter_keys | 0 | 0 | PASS |
| missing_date_rows | 0 | 0 | PASS |
| non_quarter_end_rows | 0 | 0 | PASS |
| missing_quarters_in_span | 0 | 0 | PASS |
| cpi_index_missing | 0 | 0 | PASS |
| cpi_qoq_missing | 1 | 1 | PASS |
| nonpositive_index_rows | 0 | 0 | PASS |
| unexpected_qoq_null_pattern | 0 | 0 | PASS |
| cpi_qoq_negative | 12 | 12 | PASS |
| cpi_qoq_zero | 24 | 24 | PASS |

The missing-pattern check requires QoQ to be NULL only at 1948-09-30. The quarter-end check requires both a month-end day and a quarter-ending month. Read the checks together with the history overview and completed raw audit; counts alone cannot establish agreement with every source value.

## Independent validation

The exact import and staging scripts ran in a new in-memory DuckDB v1.5.5 database using the installed official Excel extension. All three column names/types, the history overview and ten PASS checks matched expectations.

An independent workbook read compared all 312 staged dates with quarter ends calculated using Python's calendar, and all 624 selected measure cells with the staged values. All 623 numeric values matched at six-decimal precision and the one NULL was retained. The dates form 312 consecutive unique quarters. September quarter 2025 retained index 99.730000; the latest row is 2026-06-30 with index 102.310000 and QoQ 0.600000.

Filtering staged dates to the previously confirmed APRA period retained 53 quarters from 2013-03-31 to 2026-03-31, with 53 numeric observations for each measure. This verified retained coverage without building a bank join or recalculating rates.

The source workbook hash was unchanged. Independent tests did not open the populated project database or test a fresh extension download. Subsequent DBeaver results confirmed the project table's three column types, full quarter-end history and ten PASS checks. The [ABS CPI rebuild guide](rebuild_abs_cpi.md) documents execution for both completed CPI modules. Table 18 and the analytical model remain later steps.
