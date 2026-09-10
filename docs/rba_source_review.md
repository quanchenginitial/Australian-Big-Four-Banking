# RBA F1.1 monthly money-market source review

Reviewed read-only on 2026-09-11. The project-database import, date audit, selected-rate checks, APRA-period coverage and typed staging table were confirmed through DBeaver on the same date.

## Source and layout

Local snapshot: `data/raw/03_RBA_F1_1_Monthly_Money_Market.xlsx` (466,985 bytes).
The [RBA statistical tables page](https://www.rba.gov.au/statistics/tables/) lists F1.1 as the monthly money-market interest rates and yields table. This review uses the downloaded local snapshot; it does not replace it with a current download.

The workbook has `Data` and `Notes` sheets. `Data!B10:P10` gives the publication date as **1 September 2026**. The 687 observations run from **1969-06-30 through 2026-08-31**. Metadata and observations are arranged as follows:

| Location | Content |
|---|---|
| `Data!A1` | Table title |
| `Data!A2:P2` | Series titles |
| `Data!A3:P3` | Descriptions and aggregation conventions |
| `Data!A4:P4` | Frequency |
| `Data!A5:P5` | Series type |
| `Data!A6:P6` | Units |
| `Data!A9:P9` | Data providers |
| `Data!A10:P10` | Publication date |
| `Data!A11:P11` | Series IDs, used as import headers |
| `Data!A12:P698` | Monthly observations |
| `Notes!A3:A11` | Definitions and methodology notes |

Although the worksheet reports 9,999 rows and 21 columns, observations end at row 698 and column P. A read-only scan found no nonempty non-date rows below the series-ID header and no populated data cells beyond column P. Import the pinned range **A11:P698**, rather than treating worksheet dimensions as record counts.

The first header, `Data!A11`, is `Series ID`, but its column contains the observation dates. [07_load_rba_monthly.sql](../sql/07_load_rba_monthly.sql) renames this column to `period_raw`, retains the other 15 headers and loads all 16 columns as VARCHAR into `raw.rba_f1_1_monthly`. It preserves all observations and NULLs; it does not perform a date-window filter or create bank-specific copies.

## Series and source coverage

The following counts profile all 15 series through an independent read of the local workbook. The project-database audit of the three selected rates is recorded below. All latest dates in this table refer to the last nonblank observation, rather than the workbook publication date.

| Series ID | Measure | Unit | Populated months | First observation | Last observation |
|---|---|---|---:|---|---|
| FIRMMCRT | Cash Rate Target | Per cent | 433 | 1990-08-31 | 2026-08-31 |
| FIRMMCRI | Interbank Overnight Cash Rate | Per cent | 604 | 1976-05-31 | 2026-08-31 |
| FIRMMCRIHM | Highest Interbank Overnight Cash Rate | Per cent | 160 | 2013-05-31 | 2026-08-31 |
| FIRMMCRILM | Lowest Interbank Overnight Cash Rate | Per cent | 160 | 2013-05-31 | 2026-08-31 |
| FIRMMCRIVM | Volume of Cash Market Transactions | $m | 160 | 2013-05-31 | 2026-08-31 |
| FIRMMCRINM | Number of Cash Market Transactions | Number | 125 | 2016-04-30 | 2026-08-31 |
| FIRMMBAB30 | 1-month BABs/NCDs | Per cent | 410 | 1992-07-31 | 2026-08-31 |
| FIRMMBAB90 | 3-month BABs/NCDs | Per cent | 687 | 1969-06-30 | 2026-08-31 |
| FIRMMBAB180 | 6-month BABs/NCDs | Per cent | 410 | 1992-07-31 | 2026-08-31 |
| FIRMMOIS1 | 1-month Overnight Indexed Swaps | Per cent | 257 | 2001-07-31 | 2022-11-30 |
| FIRMMOIS3 | 3-month Overnight Indexed Swaps | Per cent | 257 | 2001-07-31 | 2022-11-30 |
| FIRMMOIS6 | 6-month Overnight Indexed Swaps | Per cent | 257 | 2001-07-31 | 2022-11-30 |
| FIRMMTN1 | 1-month Treasury Note | Per cent | 139 | 1995-01-31 | 2013-05-31 |
| FIRMMTN3 | 3-month Treasury Note | Per cent | 139 | 1995-01-31 | 2013-05-31 |
| FIRMMTN6 | 6-month Treasury Note | Per cent | 101 | 1995-01-31 | 2011-03-31 |

`Data!B9:P9` attributes the cash-market and Treasury-note series to RBA, BAB/NCD series to ASX and OIS series to FENICS. `Notes!A8:A9` records earlier provider changes. These source labels and changes should be retained when selecting measures for analysis.

## Units, time basis and missing values

- The cash-rate target, interbank cash rate and BAB/NCD rates are explicitly described as **monthly averages** in row 3. The month-end date is a period label, not evidence of an end-month rate. For example, `Data!B695` is 4.31 for May 2026 and `B698` is 4.35 for August 2026.
- Row 6 defines rates in **per cent**: a source value of 4.35 represents 4.35%, not a fraction of 4.35. Retain percent units in the raw layer. A later fraction-based reporting field would need division by 100 once; naming and formatting must make the chosen unit explicit.
- The Excel reader can expose numeric tails such as `4.3499999999999996`. Raw values are retained. The sample query casts to DECIMAL(18,6) for a readable preview; the typed staging table uses the same precision, as recorded in its [data dictionary](rba_staging.md).
- Dates use the Excel 1900 date system. Under `all_varchar = true`, the first and last dates read as serial strings 25384 and 46265; adding those integer days to `1899-12-30` gives the observed month-end dates.
- These are market-wide monthly observations. Their intended raw grain is one row per month, with no bank code. Bank and macro tables should be connected later through the time model without treating the macro rate as an additive bank amount.
- NULLs have different coverage patterns across series. Keep them NULL and inspect the selected analysis window before applying any completeness rule. In particular, OIS observations in this snapshot end in November 2022 and Treasury-note histories end earlier; this review does not infer the cause of every blank.
- `Notes!A3` discusses explicit cash-rate targets from January 1990, while this snapshot's first nonblank FIRMMCRT value is August 1990. Preserve the observed coverage and do not manufacture the earlier months from the general note.
- `Notes!A11` gives a general monthly-average statement, but `Data!F3:G3` explicitly labels transaction volume and number as monthly sums. Preserve the series-specific descriptions; a later use of these two measures requires resolving this metadata distinction. The first planned macro-rate analysis does not use transaction volume or number.
- A source zero appears at `Data!I17` (FIRMMBAB90, November 1969). It is preserved and flagged in the staging validation; the review does not classify it as either a valid market observation or a missing-value code without further evidence.

## Confirmed import

The script has six numbered sections: load Excel support, set the workbook path, create the raw table once, inspect its types, summarize date coverage, and preview the latest five months for FIRMMCRT/FIRMMCRI/FIRMMBAB90. The preview selects three reference rates without dropping the other series from the raw table.

The user's three DBeaver screenshots confirmed 16 VARCHAR columns, 687 rows and 687 months, from 1969-06-30 through 2026-08-31. All five preview rows matched the independent test. The latest row shows 2026-08-31, cash-rate target 4.35, interbank cash rate 4.35 and 3-month bank-bill rate 4.51, in per-cent units. Omitted trailing decimal zeros in the result grid do not change these values.

The exact import script has been tested in an independent in-memory DuckDB v1.5.5 database with the installed official Excel extension. All expected column names, types, counts, dates and five preview rows matched. An independent workbook read matched all 687 date cells and all 10,305 series cells (4,299 populated values and 6,006 NULLs). Numeric comparisons used six decimal places to accommodate Excel-reader floating-point text tails; the raw import itself keeps those original text values. The source zero at November 1969 was preserved. Supplementary checks found zero duplicate dates, non-month-end dates or missing months within the full date span. The test did not open the populated project database or change the workbook. The subsequent project import is confirmed above; further audit queries are described below.

## Selected-rate audit and confirmed APRA coverage

[08_audit_rba_monthly.sql](../sql/08_audit_rba_monthly.sql) contains three read-only queries. Numeric checks focus on FIRMMCRT, FIRMMCRI and FIRMMBAB90, the initial reference rates for the macro analysis. The other 12 series remain available in raw but are outside these selected-rate checks.

1. Validate integer Excel date serials, month-end dates, unique monthly keys and continuity of the full raw calendar. The project query returned four issue counts of zero.
2. Check all 687 records for each selected rate, distinguishing blanks from nonblank conversion failures. The project audit confirmed the missing counts below and zero conversion-failure/negative counts. The full-history zero counts were independently verified from the source and subsequently confirmed in the project staging checks.
3. Match the monthly inputs required by the two existing APRA staging tables. Deduplicate their bank/date rows before joining RBA observations. For every ADI quarter, require all three constituent months, including January and February 2013 for the first quarter. This checks availability; it does not calculate a quarterly rate or resolve the separate APRA financial scopes.

| Series ID | Rows checked | Missing | Conversion failures | Negative | Zeros confirmed in staging |
|---|---:|---:|---:|---:|---:|
| FIRMMBAB90 | 687 | 0 | 0 | 0 | 1 |
| FIRMMCRI | 687 | 83 | 0 | 0 | 0 |
| FIRMMCRT | 687 | 254 | 0 | 0 | 0 |

The missing values are early observations before the populated history shown in the source-coverage table. The one bank-bill zero is the source observation from November 1969 described above. It remains flagged and unchanged, rather than being treated as a conversion error or silently replaced.

| APRA scope | Required monthly period | Expected months per selected rate |
|---|---|---:|
| ADI_quarterly | January 2013-March 2026: all months of 53 quarters | 159 |
| MADIS_monthly | March 2019-July 2026 | 89 |

The third project query returned six rows, one per scope and selected rate. For each row, `expected_months`, `matched_months` and `numeric_months` matched the table above, and `zero_count` was zero. Read these results together with the date and numeric checks: a numeric count by itself does not establish an economically valid observation.

The exact 08 script passed independent testing in DuckDB v1.5.5, using both APRA staging tables rebuilt from their source workbooks plus the RBA import. All results matched these expectations. Separate in-memory tests removed February 2013, made a May 2019 target value nonnumeric and duplicated April 2019; the queries detected the missing month, failed conversion and duplicate respectively, including the affected APRA coverage counts. No source workbook or populated project database was modified. The subsequent project-query observations are recorded above.

## Confirmed typed monthly reference rates

[09_create_rba_monthly_staging.sql](../sql/09_create_rba_monthly_staging.sql) creates `stg.rba_monthly_rates` with a DATE field and the three selected rates as DECIMAL(18,6). It keeps all 687 months, preserves NULLs and the historical source zero, and retains per-cent units in explicitly named `_pct` columns. See the [staging documentation](rba_staging.md) for the four-column dictionary and confirmed checks.

The staging script passed independent source-to-table checks, including all 687 dates and 2,061 selected rate cells at six-decimal precision. The subsequent project queries confirmed all four column types, the same 687-month coverage and eleven PASS results. The bank-bill zero count is one, with that same observation located at 1969-11-30. The selected-rate work does not establish that every raw series is suitable for every analysis period. The [RBA rebuild guide](rebuild_rba.md) records execution order and prerequisites.
