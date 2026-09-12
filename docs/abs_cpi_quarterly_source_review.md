# ABS Table 17 quarterly CPI source review

Reviewed read-only on 2026-09-12; updated on 2026-09-13. The project import, Australia value preview, five-part audit and typed staging table are confirmed. The import, audit and staging scripts also passed independent testing against the pinned workbook.

## Source and reporting period

Local file: `data/raw/05_ABS_CPI_Table17_Quarterly_Jul2026.xlsx` (80,362 bytes). Its title is **TABLE 17. CPI: Quarterly All Groups, Index numbers and Percentage change**. The [ABS July 2026 CPI release](https://www.abs.gov.au/statistics/economy/price-indexes-and-inflation/consumer-price-index-australia/jul-2026) lists Table 17 among its quarterly downloads. ABS includes these tables in each monthly release and adds the newest quarter with March, June, September and December data. The July release snapshot therefore ends at June quarter 2026.

The local file was inspected without modification or replacement by an online download. It contains `Index`, `Data1` and `Enquiries` sheets. All 18 data series are **Original**, with frequency **Quarter**. They cover Australia and eight capital cities, with an index and a published change from the previous quarter for each geography. There is no published year-on-year column in this workbook.

## Workbook layout

| Data1 location | Content |
|---|---|
| Row 1 | Measure and geography descriptions |
| Rows 2-6 | Units, series type, data type, frequency and collection month |
| Rows 7-9 | Start date, end date and observation count |
| Row 10 | Series-ID headers |
| Rows 11-322 | 312 quarterly observations, September quarter 1948-June quarter 2026 |

[13_load_abs_cpi_quarterly.sql](../sql/13_load_abs_cpi_quarterly.sql) imports **Data1!A10:S322** into `raw.abs_cpi_table17_quarterly`. It renames the first header `Series ID` to `period_raw` and retains the other 18 IDs. All 19 columns are VARCHAR. Source values, dates, blanks, signs and zeros are preserved across all geographies.

The source labels quarters using day 1 of their final month: March, June, September or December. For example, 2026-06-01 identifies June quarter 2026. These are neither quarter-start nor quarter-end dates. The workbook uses the Excel 1900 date system. Preview queries convert the serial using `DATE '1899-12-30' + CAST(TRIM(period_raw) AS INTEGER)` and retain the source label as `source_quarter`. The staging script aligns it to the corresponding quarter end.

## Series register and observed coverage

| Geography | Index series | Quarter-on-quarter change series |
|---|---|---|
| Sydney | A2325806K | A2325810A |
| Melbourne | A2325811C | A2325815L |
| Brisbane | A2325816R | A2325820F |
| Adelaide | A2325821J | A2325825T |
| Perth | A2325826V | A2325830K |
| Hobart | A2325831L | A2325835W |
| Darwin | A2325836X | A2325840R |
| Canberra | A2325841T | A2325845A |
| Australia | A2325846C | A2325850V |

The following profiles come from the local workbook and independent test. The project audit additionally confirmed the two Australia measures; city profiles remain independent source observations:

- Australia and the seven cities other than Darwin each have 312 index observations from September quarter 1948 and 311 quarterly-change observations from December quarter 1948, ending in June quarter 2026. Their first change value is NULL.
- Darwin has 184 index observations from September quarter 1980 and 183 quarterly-change observations from December quarter 1980. Its 128 and 129 earlier blanks remain NULL.
- The Australia index has no missing, nonpositive or nonnumeric values. Its quarterly-change series has one missing observation, 12 negative values and 24 zeros. Changes below or equal to zero are retained outcomes, not automatic errors.
- Across all 18 series, 5,351 cells are numeric and 265 are NULL. There are no nonblank nonnumeric values in the source profile.

## Units and reference-period change

Index series have unit `Index Numbers`. Published quarterly changes have unit `Percent`, so 0.6 means 0.6%. Preview columns use `cpi_index` and `cpi_qoq_pct` to distinguish the measures. The import does not calculate YoY or replace published QoQ with a calculation from rounded index numbers. Any later derived rate must identify its formula and precision.

ABS [re-referencing guidance](https://www.abs.gov.au/statistics/detailed-methodology-information/information-papers/re-referencing-quarterly-consumer-price-index) specifies **September month 2025 = 100.00** for the quarterly index series. It rescales the historical series and, from December quarter 2025, calculates quarterly indexes from the three monthly indexes. The reference month must not be confused with September quarter: the Australia September-quarter value in this workbook is **99.73**. Published index rounding can affect recalculated changes, particularly at low early index levels. Preserve the supplied index basis and published change series when designing later reconciliation checks.

Quarterly observations remain quarterly. Do not extend them into absent monthly CPI history by copying a quarterly value to every month. The new quarterly CPI table has no bank key, and selecting matching dates does not resolve differences between the APRA financial reporting scopes.

## Import procedure and expected results

Run the six numbered sections in order: load Excel support, set the source path, create the raw table, describe its columns, summarize quarters and preview Australia values. The script requires the existing `raw` schema. Section 3 creates the table once and fails if it already exists; sections 4-6 are repeatable read-only queries.

Expected import results for this snapshot:

| Check | Expected result |
|---|---|
| Raw schema | 19 columns, all VARCHAR |
| Rows and quarters | 312 and 312 |
| First and last source dates | 1948-09-01 and 2026-06-01 |

Expected Australia preview:

| source_quarter | cpi_index | cpi_qoq_pct |
|---|---:|---:|
| 2026-06-01 | 102.31 | 0.6 |
| 2026-03-01 | 101.70 | 1.4 |
| 2025-12-01 | 100.32 | 0.6 |
| 2025-09-01 | 99.73 | 1.3 |
| 2025-06-01 | 98.43 | 0.7 |

## Quarterly audit procedure and confirmed results

[14_audit_abs_cpi_quarterly.sql](../sql/14_audit_abs_cpi_quarterly.sql) contains five repeatable read-only statements. Run each numbered section as a complete statement. It requires the imported raw CPI table and the previously validated `stg.apra_big_four_quarterly` table. The numeric audit selects the two Australia series; city series remain preserved in raw.

| Section | Purpose | Expected result |
|---|---|---|
| 1 | Invalid dates, wrong source labels, duplicate quarter groups and missing quarters within the observed span | Four issue counts of 0 |
| 2 | Missing values, conversion failures, negative values and zeros | Profile below |
| 3 | Index availability, QoQ missing-value positions and nonpositive index values | Three issue counts of 0 |
| 4 | Coverage of the distinct APRA ADI quarters | Both measures: 53 required, 53 matched, 53 numeric, 0 unavailable |
| 5 | Latest five Australia observations | Same preview as the import expectations above |

| Metric | Rows checked | Missing | Conversion failures | Negative | Zero |
|---|---:|---:|---:|---:|---:|
| cpi_index | 312 | 0 | 0 | 0 | 0 |
| cpi_qoq_pct | 312 | 1 | 0 | 12 | 24 |

The missing QoQ value must be at September quarter 1948 only; the audit checks its position as well as its count. Missing text and nonblank conversion failures are counted separately. Negative or zero changes are valid observations; index values must be positive. Date parsing accepts integer serial text within the supported calendar range through 9999-12-31 and reports invalid inputs without interrupting the audit. A span with no valid dates produces an issue; the separate import overview checks the pinned 312-quarter total and endpoints.

The coverage check first deduplicates the four-bank quarters, giving 53 distinct quarters from 2013Q1 through 2026Q1. CPI's final 2026Q2 observation is outside that APRA period. Invalid CPI date labels do not match. Matched and numeric counts retain duplicate row inflation so it remains visible; unavailable counts refer to distinct required quarters. Read coverage together with the date and metric checks: numeric availability alone does not establish uniqueness or index validity. This is a quarterly availability check, with no monthly interpolation or derived rate calculation.

## Independent validation

The exact import script ran successfully in a new in-memory DuckDB v1.5.5 database with the installed official Excel extension. All column names and types, counts, date limits and five Australia preview rows matched expectations. Independent workbook reads matched all 312 date cells and 5,616 series cells, comprising 5,351 numeric values compared at six decimal places and 265 NULLs. Raw values remain text; this numeric comparison accommodates reader floating-point text tails without modifying raw data.

Supplementary checks found 312 consecutive unique quarters with the expected source date labels. The Australia missing/sign counts and Darwin's earlier blanks were retained. The source hash was unchanged. Tests did not open the populated project database or test a fresh extension download.

On 2026-09-13, the exact audit script ran in a new in-memory DuckDB v1.5.5 database after rebuilding its APRA and CPI inputs with the existing setup/import/staging scripts. All five result sets matched the expectations above. Independent workbook reads also confirmed the Australia missing/sign profiles and latest five observations. Seven temporary fault scenarios verified detection of a removed quarter, nonnumeric index text, a relocated QoQ blank with its total unchanged, a duplicated quarter, malformed/out-of-range dates and incorrect source labels, nonpositive indexes, and an empty input table. Each scenario was rolled back inside the temporary database. Source files were unchanged.

Project screenshots confirm the 19 VARCHAR columns, 312 rows, 312 quarters and 1948-09-01 to 2026-06-01 source date range. Subsequent queries on 2026-09-13 confirmed all five audit outputs: four zero date/key issue counts; both 312-row metric profiles; three zero missing-pattern/index issue counts; two complete 53-quarter ADI coverage rows; and the five Australia observations shown above. The prior import preview is therefore fully confirmed.

[15_create_abs_cpi_quarterly_staging.sql](../sql/15_create_abs_cpi_quarterly_staging.sql) retains the complete Australia history with quarter-end dates and typed index/QoQ measures. Project results on 2026-09-13 confirmed three correctly typed columns, 312 rows and 312 quarters from 1948-09-30 to 2026-06-30, and all ten staging checks PASS. The [staging specification](abs_cpi_quarterly_staging.md) records the dictionary, confirmed counts and independent comparison of all 312 dates and 624 measure cells. Follow the [ABS CPI rebuild guide](rebuild_abs_cpi.md) to reproduce both completed CPI modules.
