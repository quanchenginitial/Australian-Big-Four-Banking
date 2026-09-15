# Rebuild the Power BI report pages

This manual guide recreates the accepted Overview and Loans & Deposits pages
after the existing SQL model has been built. It preserves the model's table names and uses the
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

Then run the eight numbered measure files in [powerbi/dax](../powerbi/dax/),
in order 01-08. After each query's checks PASS, use **Update model with changes**
to add its measure and save. Files 01-04 each return three PASS rows; file 05
returns five; files 06-08 each return four. A `DEFINE MEASURE` tested by Run is query-scoped until the model
update is applied. These checks target the pinned input snapshot; deliberately
review their expected values when changing the source data.

The loan-to-deposit and YoY measures depend on the earlier balance measures.
All eight measures use `fact_bank_monthly` as their home table. Apply `#,##0.00` to the amounts
and `0.00%` to the ratios. Do not multiply numeric fractions by 100 or convert
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

Overview was accepted on 2026-09-15; Loans & Deposits was accepted on 2026-09-16.
Each acceptance includes the author's explicit interaction and save confirmation.

The report's automated DAX checks, earlier visual screenshots and final manual
interaction confirmation are the evidence for this checkpoint. Source SQL
reconciliation remains documented separately. An independent full report
rebuild and final project release review remain future work.

References: [DAX query/model update workflow](https://learn.microsoft.com/en-us/power-bi/transform-model/dax-query-view),
[numeric formats](https://learn.microsoft.com/en-us/power-bi/create-reports/desktop-custom-format-strings),
[visual interactions](https://learn.microsoft.com/en-us/power-bi/create-reports/service-reports-visual-interactions).
