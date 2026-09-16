# Rebuild the Power BI report pages

This manual guide recreates the four accepted pages: Overview, Loans &
Deposits, Macro Context and Capital & Liquidity. Build the existing SQL
model first. This guide preserves its table names and uses the
versioned DAX files. The current PBIX has been tested by the report author;
the entire report has not been recreated automatically from this guide.

## Prerequisites and import

1. Complete the [SQL model rebuild](rebuild_analysis_model.md), including scripts
   19-25 and their expected checks. The local database is a stored snapshot;
   refreshing Power BI alone does not update the source/staging/fact pipeline.
2. Install 64-bit Power BI Desktop and the DuckDB Windows ODBC driver. The
   project was checked with Desktop 2.157.1354.0 (August 2026), DuckDB 1.5.5 and
   [ODBC release 1.5.5.0](https://github.com/duckdb/duckdb-odbc/releases/tag/v1.5.5.0).
   Follow the [driver installation instructions](https://duckdb.org/docs/current/clients/odbc/windows).
3. Close the DBeaver database connection normally before opening the file from
   another process. Do not manually remove database or WAL files.
4. In Power BI, use Get data > ODBC, with DSN `(None)`. Supply a connection
   string using your own absolute database path:

   ```text
   Driver={DuckDB Driver};Database=E:\DuckDB\Australian_Big_Four_Banking\database\australian_big_four_banking.duckdb;access_mode=read_only;
   ```

   Leave the SQL statement empty for Navigator. If prompted for credentials,
   the project's local file uses Default or Custom with no username/password.
5. Import `core.dim_bank`, `core.dim_date`, `mart.fact_bank_monthly`,
   `mart.fact_bank_quarterly`, `mart.fact_macro_monthly` and
   `mart.fact_macro_quarterly`. Keep the loaded names without schema prefixes:
   `dim_bank`, `dim_date` and the four `fact_*` names.

The saved [monthly macro Power Query](../powerbi/power-query/fact_macro_monthly.pq)
provides the explicit `Odbc.Query` SELECT and type conversion used for that
table. Adjust its database path before reuse. The other five tables were
imported through Navigator; this file is not a complete six-table M export.
For an ODBC source, [Microsoft documents](https://learn.microsoft.com/en-us/power-query/connectors/odbc)
that adding properties after a DSN can be ineffective, hence the DSN-less string.

## Types and relationships

Check types before Close & Apply. Keys/names/labels are Text, dates are Date,
calendar numbers and sort keys are Whole number, and `is_month_end` /
`is_quarter_end` are True/False. Bank amounts are Fixed decimal number;
bank ratio fields and macro values are Decimal number. Preserve nullable
liquidity and CPI fields. Dictionaries are in the existing
[date](date_dimension.md), [monthly bank](fact_bank_monthly.md),
[quarterly bank](fact_bank_quarterly.md), [monthly macro](fact_macro_monthly.md)
and [quarterly macro](fact_macro_quarterly.md) documentation.

Create six active relationships, with one-to-many cardinality and Single
filtering from each dimension to each fact:

| One-side column | Many-side column |
|---|---|
| `dim_bank[bank_code]` | `fact_bank_monthly[bank_code]` |
| `dim_bank[bank_code]` | `fact_bank_quarterly[bank_code]` |
| `dim_date[calendar_date]` | `fact_bank_monthly[report_date]` |
| `dim_date[calendar_date]` | `fact_bank_quarterly[report_date]` |
| `dim_date[calendar_date]` | `fact_macro_monthly[report_date]` |
| `dim_date[calendar_date]` | `fact_macro_quarterly[report_date]` |

Mark `dim_date` as the date table using `calendar_date`. Configure Sort by column:
`month_name` by `month_number`, `year_month` by `year_month_sort`, and
`year_quarter` by `year_quarter_sort`. Select the actual field name to access
Column tools. Date attributes repeated across daily rows are not relationship keys.

## Model checks and measures

Run these files in DAX query view:

| Query | Expected result |
|---|---|
| [Loaded counts](../powerbi/dax/validate_loaded_row_counts.dax) | Six PASS rows: 4 / 5,113 / 356 / 212 / 89 / 53 for the named tables |
| [Calendar sort settings](../powerbi/dax/inspect_calendar_sort_settings.dax) | Three mappings matching the previous paragraph |
| [Known missing values](../powerbi/dax/validate_imported_missing_values.dax) | Six PASS rows: monthly CPI index/YoY/MoM 61/73/62; quarterly LCR/NSFR/MLH 80/80/212 |

Then run the seventeen numbered measure files in [powerbi/dax](../powerbi/dax/),
in order 01-17. After each query's checks PASS, use **Update model with changes**
to add its measure and save. Files 01-04 each return three PASS rows; file 05
returns five; files 06-08 each return four; files 09-11 each return five;
file 12 returns six; files 13-14 each return five; file 15 returns nine;
files 16-17 each return ten. A `DEFINE MEASURE` tested by Run is query-scoped until the model
update is applied. These checks target the pinned input snapshot; deliberately
review their expected values when changing the source data.

The loan-to-deposit and YoY measures depend on the earlier balance measures.
Measures 01-08 use `fact_bank_monthly` as their home table; measures 09-12
use `fact_macro_monthly`; measures 13-17 use `fact_bank_quarterly`.
Apply `#,##0.00` to the amounts and `0.00%`
to the ratios and all four macro measures. Do not multiply numeric fractions by 100 or convert
the model measures to formatted text. `FORMAT` in query result columns is only
for displaying the test output.

## Build and accept Overview

Create a page named Overview and follow the field/configuration table in
[Power BI Overview](power_bi_overview.md). Use the raw `month_end_date` field,
not a date hierarchy, for both continuous history axes. The assets chart has
one measure; the loans/deposits chart has both measures on the same Y-axis.

For the new Card visual, select its specific measure under Visual > Callout >
Apply settings to > Cards before changing Value > Display units to None.
Under General > Data format, select that measure and set the custom format.
Replacing a copied visual's field may require setting the new field's format
again. Use the actual selected Card when looking for Callout; bar-chart labels
are configured under Data labels.

Use Format > Edit interactions to set the month selector to Filter for cards
and bars and None for both history charts. The bank selector filters all nine
data visuals. Add the source/scope footer, then check June/All and July/ANZ
against the acceptance table. Verify both history charts retain their full
span during month changes and change banks during bank selection. Hover the
July ANZ endpoints to verify all three amounts. Restore July/All and save the
PBIX under `exports/Australian_Big_Four_Banking.pbix`.

## Build and accept Loans & Deposits

Create a blank page with tab name **Loans & Deposits** and heading **Loans and
Deposits**. Add fresh dropdown slicers using `dim_date[year_month]` and
`dim_bank[bank_code]`, defaulting to July 2026 and All. Follow the field and
format table in [Loans & Deposits](power_bi_loans_deposits.md).

1. Add three cards using measures 06-08. Select the specific measure when
   setting Callout display units to None and custom amount format `#,##0.00`.
2. Add a clustered bar chart with bank_code on Y and Housing Loans plus
   Business Loans on X. Keep the Legend field well empty; the two measures
   define the series. Show their legend and two-decimal data labels.
3. Add a second bar chart with bank_code on Y and Household Deposits on X.
   Show two-decimal labels, but turn the single-series legend off.
4. Add two history charts using raw `dim_date[month_end_date]` on a continuous,
   ascending X-axis. The first uses both loan measures on the same Y-axis;
   the second uses only Household Deposits. Use Auto Y bounds, amount units
   None and `#,##0.00`, with point labels Off and tooltips On. Keep the loan
   legend On and household-deposit legend Off.
5. Use Format > Edit interactions on this page's source slicers. Month must
   Filter the three cards and two bank charts and use None for both histories.
   Bank must Filter all seven data visuals. Check these settings explicitly
   even when copying existing visuals.
6. Arrange the cards above two rows, with bank comparisons on the left and
   the matching histories on the right. Add the four-line source/scope and
   definition footer from the page guide.
7. Run that guide's June/All and July/ANZ acceptance checks. Both histories
   retain their full date span during month changes and filter to the selected
   bank. Verify the July ANZ and All history endpoints. Restore July/All and
   save the existing PBIX under `exports/Australian_Big_Four_Banking.pbix`.

## Build and accept Macro Context

Create a blank page with tab name and heading **Macro Context**. Add a month
dropdown using `dim_date[year_month]`, defaulting to July 2026. This page uses
national observations and has no bank selector. Keep the existing date-to-macro
relationship and Single dimension-to-fact filtering. Follow the full
[Macro Context configuration and acceptance guide](power_bi_macro_context.md).

1. Add four cards using measures 09-12. Set each measure's model format to
   Percentage with two decimals or Custom `0.00%`. Inspect each visual's
   General > Data format and set display units None. RBA source rates are
   monthly averages; CPI is the published annual percentage change.
2. Add a line chart with raw `dim_date[month_end_date]` on continuous ascending
   X and all three rate measures on the shared primary Y-axis. Leave the
   Secondary Y-axis and Legend field empty, but turn the displayed legend On.
   Use title Interest Rates Trend - Full History (Monthly Avg, %).
3. Add the CPI line chart to the right using the same raw date axis and only
   CPI YoY on Y. Turn its legend Off and use the title
   CPI YoY Trend - Available History (%).
4. Give both histories Auto axis bounds, percentage Y-axis formatting,
   display units None, point labels Off and tooltips On. Do not fill missing
   CPI observations with zero or extend the available series to earlier years.
5. Select the month slicer and use Format > Edit interactions: Filter on all
   four cards, None on both history charts. Verify the new chart's interactions
   explicitly when copying visuals.
6. Align the four cards above the two side-by-side charts. Add the four-line
   source, coverage and national-scope footer from the page guide.
7. Check rate history starts in March 2019 and ends in July 2026 at
   4.35%/4.35%/4.48%. Check CPI starts at April 2025, 2.40%, and ends at
   July 2026, 3.50%. Select June: cards become 4.35%/4.35%/4.46%/3.80%
   while both histories stay unchanged through July. Select March 2025:
   CPI displays a missing-value placeholder and both histories stay unchanged.
   Restore July, clear visual selections and save the existing local PBIX.

## Build and accept Capital & Liquidity

Create a blank page with tab name **Capital & Liquidity** and heading
**Capital and Liquidity**. Add dropdowns using `dim_date[year_quarter]`
and `dim_bank[bank_code]`, defaulting to **2026 Q1 / All**. Quarter labels
contain a space. Keep the accepted dimension-to-fact relationships. Follow
the [Capital & Liquidity guide](power_bi_capital_liquidity.md).

1. Add two cards with measures 13-14, using `#,##0.00` and display units
   None. They sum selected banks at one fact date, not across quarters.
2. Add three clustered bar charts: bank_code on Y and one of measures
   15-17 on X. Use the complete CET1/LCR/NSFR titles from the page guide,
   descending ratio order, a zero-based percent X-axis, automatic maximum,
   and two-decimal percentage labels.
3. Below each comparison add its matching line chart. Use the plain
   `dim_date[quarter_end_date]` on continuous ascending X, one measure on
   Y, and `dim_bank[bank_code]` in Legend. The bank context is required:
   the ratio measures deliberately return BLANK for All/multiple banks
   without a separate bank category or legend series.
4. Use `0.00%`, display units None, automatic axis bounds, point labels
   Off, tooltips On and bottom legends with consistent bank colours. The
   source ratios are already fractions; do not divide by 100 again. Keep
   LCR's Mean label. CET1 uses Full History (2013 Q1-2026 Q1); LCR and
   NSFR use Available History (2018 Q1-2026 Q1). Keep earlier blanks.
5. Set the quarter slicer to Filter for the two cards and three comparisons,
   and None for all three histories. Set the bank slicer to Filter for all
   eight data visuals. Verify these incoming interactions on copied charts.
   Clear selected bars or line points before checking the default view.
6. Add the 2023 capital-framework note under CET1 and the five-line footer
   from the page guide below the three histories. The ADI source uses each
   entity's highest consolidation level, unlike monthly MADIS.
7. Check all history first/last values against the guide. At 2025 Q4 / All,
   cards become 225.45 and 1,869.82 while histories retain their ranges.
   Select ANZ and confirm one history per metric. At 2017 Q4 / ANZ, LCR
   and NSFR bars are absent while their 2018 Q1-2026 Q1 histories remain.
8. Restore 2026 Q1 / All: cards show 226.60 and 1,889.68; bank ratios match
   the guide. Clear chart selections, ensure the footer and legends are
   readable, and save the existing local PBIX under `exports/`.

Overview was accepted on 2026-09-15; Loans & Deposits and Macro Context
on 2026-09-16; Capital & Liquidity on 2026-09-17.
Each acceptance includes the author's explicit interaction and save confirmation.

The report's automated DAX checks, earlier visual screenshots and final manual
interaction confirmation are the evidence for this checkpoint. Source SQL
reconciliation remains documented separately. An independent full report
rebuild and final project release review remain future work.

References: [DAX query/model update workflow](https://learn.microsoft.com/en-us/power-bi/transform-model/dax-query-view),
[numeric formats](https://learn.microsoft.com/en-us/power-bi/create-reports/desktop-custom-format-strings),
[visual interactions](https://learn.microsoft.com/en-us/power-bi/create-reports/service-reports-visual-interactions).
