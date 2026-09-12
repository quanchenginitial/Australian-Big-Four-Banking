# ABS Table 18 quarterly CPI detail source review

Reviewed read-only on 2026-09-13. Both project raw imports, all five project audit outputs and all four staging validation outputs are confirmed. The import, audit and typed staging scripts also passed independent tests against the pinned workbook.

## Source and scope

The pinned local file is `data/raw/06_ABS_CPI_Table18_Quarterly_Detail_Jul2026.xlsx`, 405,162 bytes, SHA256 `cc608103d747d8acf59ba54c529de952bb0619d68beb2e442ded71d49f3ff15a`. It is the Table 18 quarterly CPI detail workbook listed on the [ABS July 2026 CPI release](https://www.abs.gov.au/statistics/economy/price-indexes-and-inflation/consumer-price-index-australia/jul-2026). It covers expenditure groups, subgroups and classes for the weighted average of eight capital cities, labelled Australia in the series descriptions.

The file contains `Index`, `Data1`, `Data2` and `Enquiries`. Both data sheets are required to retain all 396 series. All series are Original, with frequency Quarter and collection month 3. The source was inspected without changing it or replacing it with an online download.

## Layout and raw imports

| Sheet | Data range, including headers | Raw columns | Series content | Target table |
|---|---|---:|---|---|
| Data1 | A10:IQ322 | 251 | 132 indexes and 118 changes from the previous quarter | `raw.abs_cpi_table18_data1_quarterly` |
| Data2 | A10:EQ322 | 147 | 14 remaining quarterly changes and 132 contributions to Total CPI | `raw.abs_cpi_table18_data2_quarterly` |

Both sheets have descriptions in row 1, units and other metadata in rows 2-9, Series IDs in row 10, and 312 quarterly date rows in rows 11-322. [16_load_abs_cpi_quarterly_detail.sql](../sql/16_load_abs_cpi_quarterly_detail.sql) imports each sheet as a separate raw table. It renames `Series ID` to `period_raw`, preserves the remaining Series IDs, and reads all columns as VARCHAR with `stop_at_empty = false`. The two tables contain different measures for the same quarterly calendar; their rows are not appended into a longer time series.

There are 396 unique Series IDs, matching the workbook's `Index` register. Descriptions are not unique: 24 descriptions repeat beyond their first occurrence. Preserve IDs rather than deduplicating by display names. Selecting categories and documenting their hierarchy remain part of later modelling work.

## Dates, measures and units

Both sheets contain **312 consecutive unique quarters, 1948Q3-2026Q2**, with source labels **1948-09-01 through 2026-06-01**. The source date is day 1 of the quarter's final month, always March, June, September or December. It is neither the first day of the quarter nor the actual quarter end. The workbook uses the Excel 1900 date system, decoded with `DATE '1899-12-30' + CAST(TRIM(period_raw) AS INTEGER)`. Raw values remain unchanged; quarter-end conversion belongs to a later staging step.

The July 2026 file is a publication snapshot. ABS adds the latest quarter to Tables 17 and 18 with the March, June, September and December monthly reference periods, so June quarter 2026 is the expected endpoint of this file. See the [release's quarterly data notes](https://www.abs.gov.au/statistics/economy/price-indexes-and-inflation/consumer-price-index-australia/jul-2026#data-downloads).

| Published measure family | Series count | Source unit | Treatment |
|---|---:|---|---|
| Index Numbers | 132 | Index Numbers | Preserve the published index level |
| Percentage Change from Previous Period | 132 | Percent | Preserve published QoQ; 0.6 means 0.6% |
| Contribution to Total CPI | 132 | Index Points | Preserve separately as index-point contributions |

Index-point contribution is not a quarterly inflation rate, a percentage-point contribution to inflation, or a percentage weight. Do not apply percent formatting to this measure or add it to a rate. Each of these 132 contribution series has only **three nonblank observations**, December quarter 2025-June quarter 2026, and 309 earlier NULLs in the pinned file. The import retains these blanks without inferring missing history or its cause.

The quarterly indexes use September **month** 2025 = 100.00, according to the [ABS re-referencing guidance](https://www.abs.gov.au/statistics/detailed-methodology-information/information-papers/re-referencing-quarterly-consumer-price-index). The All groups September **quarter** 2025 value is 99.73. Different index series have their own conversion factors, and published rounding affects recalculated rates. Keep the supplied levels and changes. This workbook has no published YoY measure family; this import does not calculate one.

## Observed coverage from the local workbook

| Sheet | Measure cells | Numeric | NULL | Nonblank nonnumeric |
|---|---:|---:|---:|---:|
| Data1 | 78,000 | 43,864 | 34,136 | 0 |
| Data2 | 45,552 | 2,026 | 43,526 | 0 |
| Total | 123,552 | 45,890 | 77,662 | 0 |

Start dates differ across categories. For example, All groups index begins at 1948Q3, Food/Housing/Transport indexes at 1972Q3, and Insurance and financial services index at 2005Q2. Published QoQ begins one quarter after each of these example indexes. Each of the 396 series' populated count, first date and last date matched its workbook metadata. These are independent source observations; they do not yet represent project audit results.

## Import procedure and expected results

Run the seven numbered sections in order: load Excel support, set the workbook path, create the Data1 table, create the Data2 table, summarize their schemas, summarize their calendars, and preview the latest five All groups observations. The script requires the existing `raw` schema. Each creation statement runs once and fails if its own table already exists. Sections 5-7 are repeatable read-only queries.

The schema summary uses one row per table so the two wide schemas are easy to inspect:

| source_sheet | column_count | varchar_count | non_varchar_count | first_column |
|---|---:|---:|---:|---|
| Data1 | 251 | 251 | 0 | period_raw |
| Data2 | 147 | 147 | 0 | period_raw |

The date summary should return two rows, each with **312 rows, 312 quarters, first_date 1948-09-01, last_date 2026-06-01**.

The preview uses these three source columns:

| Output | Sheet / column | Series ID | Unit |
|---|---|---|---|
| cpi_index | Data1 / B | A2325846C | Index Numbers |
| cpi_qoq_pct | Data1 / ED | A2325850V | Percent |
| cpi_contribution_index_points | Data2 / P | A3597525W | Index Points |

| source_quarter | cpi_index | cpi_qoq_pct | cpi_contribution_index_points |
|---|---:|---:|---:|
| 2026-06-01 | 102.31 | 0.6 | 102.31 |
| 2026-03-01 | 101.70 | 1.4 | 101.70 |
| 2025-12-01 | 100.32 | 0.6 | 100.32 |
| 2025-09-01 | 99.73 | 1.3 | NULL |
| 2025-06-01 | 98.43 | 0.7 | NULL |

This read-only preview joins the two sheets by decoded source quarter using a full outer join. It does not create a merged table. Preview casts do not change raw types. Project screenshots on 2026-09-13 confirmed both schema rows, both 312-quarter calendars and all five preview rows, including the two earlier contribution NULLs.

## All-series audit procedure and expected results

[17_audit_abs_cpi_quarterly_detail.sql](../sql/17_audit_abs_cpi_quarterly_detail.sql) contains five self-contained, read-only statements. It requires both imported Table 18 raw tables, the validated Table 17 staging table `stg.abs_cpi_australia_quarterly`, and `stg.apra_big_four_quarterly`. No new tables or source-file reads are performed by the audit.

| Section | Purpose | Expected result |
|---|---|---|
| 1 | Check both source calendars, pinned counts/endpoints and cross-sheet date alignment | Sixteen issue counts of 0 |
| 2 | Profile all 396 series, grouped into three measure families | Three rows, as below |
| 3 | Verify source IDs, families, per-series coverage and missing positions | Ten issue counts of 0 |
| 4 | Reconcile All groups index/QoQ with the validated Table 17 staging table | Five PASS rows: 312 matched quarters; missing rows and value mismatches all 0 |
| 5 | Describe all-series coverage across the 53 distinct ADI quarters | Three coverage rows, as below |

The audit uses [DuckDB's documented UNPIVOT syntax](https://duckdb.org/docs/current/sql/statements/unpivot) with `INCLUDE NULLS` to retain every series-quarter cell in its queries. This produces 123,552 cells across all 396 series, including earlier unavailable observations. Section 2 initially assigns families using the pinned workbook's column blocks; section 3 independently verifies the Series IDs, sheet membership and family assignments against the recorded source register. Read these checks together.

Each family contains **132 series**, with **41,184 cells checked**. Expected profiles:

| Metric family | Missing | Conversion failures | Negative | Zero |
|---|---:|---:|---:|---:|
| cpi_index | 18,371 | 0 | 0 | 0 |
| cpi_qoq_pct | 18,503 | 0 | 5,537 | 1,280 |
| cpi_contribution_index_points | 40,788 | 0 | 0 | 0 |

Section 3 embeds all 396 IDs in 27 groups sharing sheet, measure family, declared start and observation count. Every series ends at 2026-06-01 in this snapshot. Checks cover missing/unexpected columns, misclassified families, incorrect row/numeric counts, wrong first/last populated quarters and blanks outside the expected leading period. Nonblank conversion failures are kept separate from missing text. Index values must be positive; contributions are checked for negative values in this snapshot. Published negative and zero QoQ values are retained. The expected register must be reviewed with the source metadata when changing snapshots; descriptions are not used as unique keys.

Section 4 aligns valid Table 18 source labels to quarter ends for a full outer join with Table 17. It compares index and QoQ at DECIMAL(18,6), using NULL-aware comparisons so the initial missing QoQ is retained. A matched-row count of 312 is required; missing dates on either side and value mismatches must each be zero. This reconciliation covers the two shared headline measures, not the other Table 18 components.

Section 5 deduplicates the bank quarters before comparing all series. Each measure family requires **132 series × 53 quarters = 6,996 series-quarter cells** in 2013Q1-2026Q1:

| Metric family | Required cells | Matched cells | Numeric cells | Unavailable cells |
|---|---:|---:|---:|---:|
| cpi_index | 6,996 | 6,996 | 6,996 | 0 |
| cpi_qoq_pct | 6,996 | 6,996 | 6,996 | 0 |
| cpi_contribution_index_points | 6,996 | 6,996 | 264 | 6,732 |

Only December quarter 2025 and March quarter 2026 contributions lie in the ADI period, giving 132 × 2 = 264 numeric cells. June quarter 2026 lies outside it. The unavailable contribution cells remain NULL. Matched/numeric row counts retain duplicate inflation; unavailable counts refer to distinct required series-quarter pairs. Numeric coverage alone does not establish valid signs, uniqueness or comparable financial reporting scopes.

## Independent validation

The exact import script ran in a new in-memory DuckDB v1.5.5 database with the installed official Excel extension. Both complete schemas, both calendar summaries and all five preview rows matched expectations.

Independent workbook reads matched all **624 date cells** across the two sheets and all **123,552 measure cells**: 45,890 numeric values at six-decimal precision and 77,662 NULLs. All 396 headers matched the `Index` register. Both source calendars were unique, consecutive and identical. The 132 contribution series retained exactly their three published observations and earlier blanks. Numeric comparison at six decimal places accommodates floating-point text tails between readers while leaving raw text unchanged.

The Table 18 All groups index and QoQ also matched the pinned Table 17 workbook across all 312 dates and 624 selected measure cells, including the initial QoQ NULL. This compares the local source snapshots, not queries against the populated project database.

Both source workbook hashes remained unchanged. Tests did not open the populated project database or test a fresh extension download.

The exact audit also ran successfully in a new in-memory DuckDB v1.5.5 database after its APRA and CPI dependencies were rebuilt from the pinned workbooks using the existing scripts. All five outputs matched the expected counts above, including the 396-series metadata checks and Table 17 reconciliation. Twelve temporary fault scenarios verified detection of a missing Data2 quarter, a missing first Data1 quarter, a duplicate quarter, a nonnumeric component index, relocated QoQ/contribution blanks with unchanged totals, invalid dates/labels, changed headline values, nonpositive values, an unexpected series column, a missing series column and an empty Data2 table. Each scenario was rolled back inside the test database.

Project screenshots on 2026-09-13 confirmed all five audit outputs: sixteen calendar/cross-sheet issue counts of 0 at 02:13:50; the three complete metric profiles at 02:14:19; ten series metadata/coverage issue counts of 0 at 02:14:54; five Table 17 reconciliation PASS rows at 02:15:14; and all three ADI coverage rows at 02:15:35. These match the independently tested results above.

The completed staging step preserves all 396 series in `stg.abs_cpi_australia_quarterly_detail`, with one row per Series ID and quarter. It retains source category names and units, including separate IDs that share a display name. Project screenshots on 2026-09-13 confirmed seven correctly typed fields at 02:30:35, 123,552 rows across 396 series and 312 quarters at 02:30:52, fifteen PASS checks at 02:31:12, and two zero-difference raw/staging comparisons at 02:31:29. Quarter-end coverage is 1948-09-30 through 2026-06-30. [18_create_abs_cpi_quarterly_detail_staging.sql](../sql/18_create_abs_cpi_quarterly_detail_staging.sql) and the [staging notes](abs_cpi_quarterly_detail_staging.md) record the transformation and validation. Selecting reporting categories and defining their hierarchy remain later modelling work.
