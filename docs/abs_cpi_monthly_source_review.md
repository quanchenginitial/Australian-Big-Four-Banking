# ABS Table 1 monthly CPI source review

Reviewed read-only on 2026-09-11. The project import, selected-measure audit and typed staging table are confirmed through DBeaver: raw and staging schemas, date coverage, five Australia preview rows, numeric and missing-pattern checks, APRA-period coverage, and twelve staging PASS results match the independent tests.

## Source and scope

Pinned local file: `data/raw/04_ABS_CPI_Table1_Monthly_Jul2026.xlsx` (53,630 bytes). Its title is **TABLE 1. CPI: All Groups, Index numbers and Percentage change**. The [ABS July 2026 CPI release](https://www.abs.gov.au/statistics/economy/price-indexes-and-inflation/consumer-price-index-australia/jul-2026), published on 26 August 2026, provides this table in its data downloads. The file was inspected locally and not replaced with an online download.

The workbook contains `Index`, `Data1` and `Enquiries`. Data1 has 27 monthly **Original** series: three measures for Australia and each of eight capital cities. These are CPI index levels and published annual/monthly percentage changes; Table 1 does not provide seasonally adjusted or trimmed-mean series.

ABS documents **September 2025 = 100.00** as the index reference period for the complete monthly CPI. All nine index series equal 100 in the local September 2025 row. The complete monthly CPI and the earlier Monthly CPI Indicator are separate publications; this import does not splice their histories. See [ABS index reference periods](https://www.abs.gov.au/statistics/detailed-methodology-information/concepts-sources-methods/consumer-price-index-concepts-sources-and-methods/2025/re-referencing-and-linking-price-indexes) and the [final Monthly CPI Indicator release](https://www.abs.gov.au/statistics/economy/price-indexes-and-inflation/monthly-consumer-price-index-indicator/sep-2025).

## Workbook layout and raw import

| Data1 location | Content |
|---|---|
| Row 1 | Measure and geography descriptions |
| Rows 2-6 | Unit, series type, data type, frequency and collection month |
| Rows 7-9 | Series start, series end and number of observations |
| Row 10 | Series-ID headers |
| Rows 11-38 | 28 monthly observations, April 2024-July 2026 |

[10_load_abs_cpi_monthly.sql](../sql/10_load_abs_cpi_monthly.sql) imports **Data1!A10:AB38** into `raw.abs_cpi_table1_monthly`. It renames the date-column header `Series ID` to `period_raw`, retains the other 27 headers and stores all 28 columns as VARCHAR. It keeps every geography, original value and NULL. The first nine metadata rows are excluded.

The raw table has one row per month with multiple series columns. It has no bank key. Source dates use **the first day of the month**, from 2024-04-01 to 2026-07-01, and the workbook uses the Excel 1900 date system. The diagnostic queries convert integer date serials using `DATE '1899-12-30' + CAST(TRIM(period_raw) AS INTEGER)`. They retain the first-day label as `source_month`. A later staging transformation will provide month-end labels for alignment with the existing APRA/RBA tables; raw dates remain unchanged.

## Series register

| Geography | Index | Change from corresponding month of previous year | Change from previous month |
|---|---|---|---|
| Australia | A130393720C | A130393721F | A130393722J |
| Sydney | A130397375X | A130397376A | A130397377C |
| Melbourne | A130396086K | A130396087L | A130396088R |
| Brisbane | A130397382W | A130397383X | A130397384A |
| Adelaide | A130395001V | A130395002W | A130395003X |
| Perth | A130393713F | A130393714J | A130393715K |
| Hobart | A130392355X | A130392356A | A130392357C |
| Darwin | A130395008K | A130395009L | A130395010W |
| Canberra | A130393727V | A130393728W | A130393729X |

## Units and coverage

- Index series have unit `Index Numbers`. An index of 103.07 is not an inflation rate of 103.07%.
- Change series have unit `Percent`: a source value of 3.5 means 3.5%. Preview columns use `_pct` and retain this scale. A percentage-formatted reporting field will need division by 100 once.
- Each index series has 28 observations from April 2024 to July 2026, with no missing values.
- Each annual-change series has 16 observations from April 2025 to July 2026. Its first 12 rows are NULL, consistent with the absence of the required prior-year monthly indexes.
- Each monthly-change series has 27 observations from May 2024 to July 2026. Its first row is NULL because the first index observation has no preceding month in this snapshot.
- The Australian monthly-change series contains seven negative values and three zeros. Decreases and unchanged prices are valid outcomes for a change measure. Retain their signs and keep them distinct from missing values; do not carry over a blanket nonnegative-rate rule from RBA.
- These 28 months cannot supply the full 89-month MADIS or 53-quarter ADI history. Later analysis must show the available CPI window and preserve earlier unavailability. The two quarterly CPI workbooks will be reviewed separately.
- Index levels and percentage changes are non-additive across time and geographies. Use the published Australia series for the national preview rather than summing the city series.

## Import checks and independent test

The script has six sections: load the installed Excel extension, set the source path, create the raw table, describe its columns, summarize source dates and preview five Australia observations. It requires the existing `raw` schema. The creation statement runs once and fails if the table already exists; diagnostic sections 4-6 are read-only and repeatable.

Confirmed project results for the pinned workbook, observed on 2026-09-11:

| Check | Confirmed result |
|---|---|
| Column types | 28 columns, all VARCHAR |
| Rows and months | 28 and 28 |
| First and last source dates | 2024-04-01 and 2026-07-01 |
| Latest Australia row | 2026-07-01; index 103.070000; annual change 3.500000; monthly change 1.000000 |

The exact script executed successfully in a new in-memory DuckDB v1.5.5 database using the installed official Excel extension. Independent workbook reads matched all 28 date cells and 756 series cells: 639 numeric values compared at six decimal places and 117 NULLs. All column names, types and five preview rows matched. Supplementary source checks found unique consecutive months with first-day labels. The source file hash was unchanged; the populated project database was not opened. A fresh extension download was not tested.

The project import subsequently returned the same schema, coverage and five preview rows. It retains the source first-day date labels and the negative monthly changes shown in the workbook. The subsequent audit and typed staging are confirmed below.

## Confirmed date, measure and coverage audit

[11_audit_abs_cpi_monthly.sql](../sql/11_audit_abs_cpi_monthly.sql) contains four read-only statements. It requires the raw CPI table and both existing APRA staging tables. The numeric audit covers the three Australia measures; the 24 city measures remain outside this selected audit.

1. Check integer date serials, first-day month labels, duplicate months and missing months within the observed span. The project returned four issue counts of zero.
2. Profile all 28 records per selected measure, separating blanks from nonblank conversion failures and retaining negative and zero changes.
3. Check that missing values occur in the expected periods: no missing index, YoY absent before April 2025 and populated thereafter, MoM absent before May 2024 and populated thereafter. Also check for nonpositive index values. The project returned four issue counts of zero. A displaced blank can violate this test even when its total count is unchanged.
4. Describe available CPI months within each APRA analysis period, deduplicating bank/date rows and expanding every ADI quarter into its three monthly inputs.

Confirmed metric profile (conversion failures are zero throughout):

| Metric | Rows checked | Missing | Negative | Zero |
|---|---:|---:|---:|---:|
| cpi_index | 28 | 0 | 0 | 0 |
| cpi_mom_pct | 28 | 1 | 7 | 3 |
| cpi_yoy_pct | 28 | 12 | 0 | 0 |

Confirmed coverage:

| APRA scope | CPI metric | Required months | Matched months | Numeric months | Unavailable months |
|---|---|---:|---:|---:|---:|
| ADI_quarterly | cpi_index | 159 | 24 | 24 | 135 |
| ADI_quarterly | cpi_mom_pct | 159 | 24 | 23 | 136 |
| ADI_quarterly | cpi_yoy_pct | 159 | 24 | 12 | 147 |
| MADIS_monthly | cpi_index | 89 | 28 | 28 | 61 |
| MADIS_monthly | cpi_mom_pct | 89 | 28 | 27 | 62 |
| MADIS_monthly | cpi_yoy_pct | 89 | 28 | 16 | 73 |

MADIS overlaps the full April 2024-July 2026 CPI calendar. ADI's final quarter is March 2026, so its overlap is April 2024-March 2026. `unavailable_months` counts required months without a numeric observation, including absent source months and blank/nonconvertible measure values. Expected early unavailability remains unavailable. `matched_months` and `numeric_months` count matched rows so duplicates remain visible; availability itself counts distinct months. Interpret coverage together with the date, conversion and missing-pattern checks. Numeric coverage alone does not establish a valid index or date.

This query describes monthly inputs. It does not calculate quarterly CPI, fill earlier months, or join financial amounts across the different APRA scopes. Source quarterly CPI will be reviewed separately.

The exact four statements passed independent DuckDB v1.5.5 tests with APRA and CPI inputs rebuilt from their local source workbooks. The baseline matched every expectation above. Separate in-memory cases detected a removed month, a nonnumeric index, displaced YoY blanks despite an unchanged missing total, a duplicate month, and malformed/non-first-day dates. All test changes were confined to the disposable in-memory database. No source workbook or populated project database was modified. All four project-query outputs were subsequently confirmed through DBeaver on 2026-09-11.

## Confirmed Australia staging table

[12_create_abs_cpi_monthly_staging.sql](../sql/12_create_abs_cpi_monthly_staging.sql) creates `stg.abs_cpi_australia_monthly` with a month-end DATE and three DECIMAL(18,6) measures, retaining all 28 months, the original units and the observed NULL/sign patterns. Project queries confirmed four correctly typed columns, 28 rows and months from 2024-04-30 to 2026-07-31, and twelve PASS results. The [staging dictionary](abs_cpi_monthly_staging.md) explains the date-label conversion, confirmed counts and independent comparison of all 28 dates and 84 selected values. The [rebuild guide](rebuild_abs_cpi.md) records prerequisites and execution order.
