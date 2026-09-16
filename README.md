# Australian Big Four Banking Performance & Macro Insights

An independent portfolio project using SQL and Power BI to analyse
Australian Big Four banking data alongside interest rates and inflation.

## Key findings

The monthly snapshot ends in **July 2026**; capital and liquidity end in
**2026 Q1**. Shares below refer to the selected four banks.

- Combined resident assets were **AUD 4,209.35 bn**, up **5.86%** from
  July 2025. WBC had the highest annual growth at **9.68%**; CBA held the
  largest asset balance.
- Housing represented **62.26%** of total loans. CBA led housing loans
  and household deposits; NAB led non-financial business loans.
- The aggregate loan-to-deposit ratio fell from **116.15%** in June to
  **115.70%** in July as deposits grew faster than loans over that month.
- At 2026 Q1, ANZ and WBC shared the highest CET1 ratio (**12.40%**),
  CBA the highest mean LCR (**132.80%**), and NAB the highest NSFR (**115.70%**).
- July monthly-average cash rates were **4.35%** and CPI annual inflation
  was **3.50%**. These provide context; no causal effect on bank performance
  has been estimated.

Read the [analysis and source calculations](docs/analysis_findings.md) and
[final review](docs/final_review.md). MADIS domestic balances and ADI
highest-consolidation-level ratios retain different scopes. The report
provides descriptive comparisons, not an overall bank rating.

## Status

The defined four-page portfolio snapshot is complete, with final source and
documentation review on 2026-09-17. All six source workbooks have been imported. Selected measures
from the two APRA sources, RBA F1.1, ABS monthly CPI Table 1 and quarterly CPI
Table 17 have been audited and converted into typed staging tables. The final
source, ABS quarterly CPI Table 18, retains all 396 audited series in a typed
detail table. Project results were confirmed through DBeaver on 2026-09-11 and
2026-09-13. The SQL analysis model is also complete: a shared daily date
dimension and four monthly/quarterly facts have passed individual and integrated
checks. Power BI import, six active dimension relationships, calendar settings
and seventeen DAX measures are now validated. Overview was accepted on
2026-09-15; Loans & Deposits and Macro Context followed on 2026-09-16,
and Capital & Liquidity on 2026-09-17. All four pages have passed their
numerical, interaction, history-endpoint and final save checks, including
missing-value behavior for CPI and liquidity ratios. The [final review](docs/final_review.md) records the evidence and remaining
extensions. The full PBIX has not been independently rebuilt from scratch.
The source-loading and transformation scripts have also passed independent
DuckDB tests against the downloaded Excel snapshots.

| Staging table | Records | Coverage | Measures retained |
|---|---:|---|---|
| `stg.apra_big_four_monthly` | 356 | Four banks, 89 months, March 2019-July 2026 | Seven asset, loan and deposit amounts |
| `stg.apra_big_four_quarterly` | 212 | Four banks, 53 quarters, March 2013-March 2026 | Four capital/RWA amounts and six capital/liquidity ratios |
| `stg.rba_monthly_rates` | 687 | One market-wide observation per month, June 1969-August 2026 | Cash-rate target, interbank overnight cash rate and three-month bank-bill rate |
| `stg.abs_cpi_australia_monthly` | 28 | Australia, April 2024-July 2026 | All groups CPI index and published annual/monthly percentage changes, Original series |
| `stg.abs_cpi_australia_quarterly` | 312 | Australia, 1948Q3-2026Q2 | All groups CPI index and published quarterly percentage change, Original series |
| `stg.abs_cpi_australia_quarterly_detail` | 123,552 | Australia, 396 series across 312 quarters, 1948Q3-2026Q2 | 132 series each for index, published QoQ and contribution to Total CPI; one series-quarter per row, including NULL observations |

The MADIS monthly table has no duplicate bank/month keys, missing keys or missing
selected amounts. A separate source comparison matched all 11,122 MADIS raw
records across 30 columns and all four bank mappings, with zero differences in
either direction, including duplicate multiplicities.

The ADI quarterly table has 16 typed columns and passed all seven staging checks.
Its selected capital amounts and capital ratios are complete. LCR and NSFR each
have 33 consecutive populated quarters per bank from March 2018 to March 2026;
the 80 earlier missing values per metric remain NULL. MLH is NULL in all 212
selected records. Both date fields and a label for the 2023 capital-framework
change are retained.

The two APRA datasets have different reporting scopes. MADIS covers selected
residents' balances on unconsolidated Australian domestic books; the quarterly
ADI publication uses entities' highest consolidation level. The shared bank
mapping does not make these measures directly comparable.

The RBA table has one DATE field and three DECIMAL(18,6) rate fields, with all
eleven staging checks passing. It retains 254 early missing cash-rate targets,
83 early missing interbank rates and one flagged source bank-bill zero from
November 1969. All three rates have complete, nonzero coverage for the APRA
analysis inputs: 89 MADIS months and all 159 months of the 53 ADI quarters.
The rates are monthly averages. The quarterly macro fact now derives guarded,
equal-weight means of the three monthly averages in each required quarter.

The Australia monthly CPI table has one DATE and three DECIMAL(18,6) columns, with all
twelve staging checks passing. Source first-day month labels are converted to
month-end reporting labels. The table preserves 12 early annual-change NULLs,
one initial monthly-change NULL, seven negative monthly changes and three zero
monthly changes. Its calendar overlaps 28 MADIS months and 24 constituent
months of the ADI quarters; earlier monthly CPI data remains unavailable.
The full raw import retains all 27 series for Australia and eight capital cities;
the numeric audit and staging select the three Australia measures.

The Australia quarterly CPI table has one DATE and two DECIMAL(18,6) columns,
with all ten staging checks passing. It retains 312 consecutive quarters,
1948-09-30 through 2026-06-30. Source labels use day 1 of the quarter's final
month; staging converts them to the corresponding quarter ends. The published
quarterly change retains one initial NULL, twelve negative values and
twenty-four zeros. Both selected measures cover all 53 ADI quarters,
2013Q1-2026Q1, without missing numeric values. The raw import preserves all
18 Australia/city series; the numeric audit and staging select Australia.
Table 17 has no published annual-change column, and no YoY measure is derived
in this step. Quarterly observations do not fill the monthly CPI history gaps.

The quarterly CPI detail table has seven typed columns, with all fifteen staging
checks and both raw-to-staging comparisons passing. Its logical key is Series ID
and quarter end. All 396 IDs and their category names, metric families, units and
source sheets are retained; duplicate display names remain separate series.
Independent workbook comparisons matched all 123,552 records: 45,890 numeric
values and 77,662 NULLs. The raw audit also reconciled its All groups index and
QoQ with Table 17 across all 312 quarters, with no missing rows or value differences.
Those headline measures describe the same observations in both tables.

All 132 detail indexes and 132 QoQ series have complete numeric coverage across
the 53 ADI quarters. Each of the 132 contribution series has only three numeric
observations, 2025Q4-2026Q2. Two fall within the ADI period, giving 264 numeric
series-quarter cells and 6,732 unavailable cells. These blanks remain NULL.
Contributions use Index Points; they are not inflation rates or percentage weights.
Reporting categories and their hierarchy have not yet been selected or mapped.

## Validated SQL analysis model

The initial model reuses `core.dim_bank` and adds the five tables below.
Bank facts retain their complete audited histories, while each macro fact uses
the distinct dates required by the corresponding bank fact. Staging histories
remain unchanged.

| Model table | Grain | Records | Coverage |
|---|---|---:|---|
| `core.dim_bank` | One bank | 4 | ANZ, CBA, NAB, WBC |
| `core.dim_date` | One calendar day | 5,113 | 2013-01-01 to 2026-12-31 |
| `mart.fact_bank_monthly` | One bank and month end | 356 | 2019-03-31 to 2026-07-31 |
| `mart.fact_bank_quarterly` | One bank and quarter end | 212 | 2013-03-31 to 2026-03-31 |
| `mart.fact_macro_monthly` | One month end shared by all banks | 89 | 2019-03-31 to 2026-07-31 |
| `mart.fact_macro_quarterly` | One quarter end shared by all banks | 53 | 2013-03-31 to 2026-03-31 |

Both bank facts preserve the selected staging values and enforce a composite
bank/date primary key. Macro facts have a date primary key and no bank key.
The monthly macro fact retains CPI index/YoY/MoM missing counts of 61/73/62;
those missing measures do not remove bank months. All 265 quarterly macro
measure values are populated in the selected window. Its three rate means
allow NULL for incomplete inputs, which are separately flagged by validation.
The quarterly means are project-derived averages of three monthly averages,
not official RBA quarterly observations or quarter-end spot rates. Quarterly
CPI retains the published Table 17 index and QoQ.

All schemas, histories, individual integrity checks and full-record comparisons
passed in the project. Integrated acceptance on 2026-09-13 confirmed six table
inventories, six dimension relationships and two combined trial joins: monthly
bank records remained 356 and quarterly records 212, with no unmatched rows or
duplicate bank-period groups. Independent in-memory tests also checked source
values, calendar attributes, quarterly rate arithmetic and temporary faults.

The intended Power BI model uses single-direction dimension-to-fact filtering:
the date dimension filters all four facts, and the bank dimension filters the
two bank facts. All six relationships are now configured as active, single-direction
one-to-many relationships in Power BI, with date marking and sort settings verified. See the [model plan and diagram](docs/analysis_model_plan.md)
and [integrated validation results](docs/model_validation.md).

Four Power BI pages and seventeen measures are complete. See the
[Overview report](docs/power_bi_overview.md),
[Loans & Deposits report](docs/power_bi_loans_deposits.md),
[Macro Context report](docs/power_bi_macro_context.md),
[Capital & Liquidity report](docs/power_bi_capital_liquidity.md) and
[Power BI rebuild guide](docs/rebuild_power_bi.md).
Descriptive results are in [Analysis findings](docs/analysis_findings.md);
validation coverage and limitations are in [Final review](docs/final_review.md).
Table 18 expenditure detail remains a later extension with its own series grain.

## Power BI Overview

![Australian Big Four Banking Overview](reports/overview.png)

The first page shows monthly assets, loans, deposits, a derived loan-to-deposit
ratio and total-assets annual growth, with bank comparisons and full-history
trend charts. The month selector filters cards and bank comparisons; the bank
selector also filters both history charts. The page includes source and scope notes.

At July 2026 with all four banks selected, the cards show assets **AUD 4,209.35 bn**,
loans **AUD 2,953.25 bn**, deposits **AUD 2,552.49 bn**, loan-to-deposit ratio
**115.70%**, and asset growth from July 2025 of **5.86%**. These are resident
balances on the MADIS domestic, unconsolidated basis, not global group totals.

- [Report definitions, validation and interactions](docs/power_bi_overview.md)
- [Rebuild the Power BI model and page](docs/rebuild_power_bi.md)
- [Versioned DAX measures and checks](powerbi/dax/)
- [Monthly macro Power Query source](powerbi/power-query/fact_macro_monthly.pq)

The screenshot is a static report preview. The local PBIX remains under the
ignored `exports/` directory; this checkpoint provides the screenshot, DAX and
manual rebuild instructions rather than a hosted interactive report.

## Power BI Loans & Deposits

![Australian Big Four Banking Loans and Deposits](reports/loans_deposits.png)

The second page compares housing loans, loans to non-financial businesses and
household deposits across the four banks, with corresponding history charts.
Its three cards show **AUD 1,838.83 bn**, **AUD 892.45 bn** and
**AUD 1,272.39 bn**, respectively, at July 2026 with All banks selected.

Housing combines owner-occupied and investment housing loans. These selected
loan categories are not an exhaustive breakdown of total loans. All amounts
use the same MADIS domestic, unconsolidated resident scope as the Overview.
The month selector filters cards and bank comparisons while histories retain
March 2019 through July 2026; the bank selector filters all seven data visuals.

The three additional measures each passed four snapshot checks, including an
unavailable month returning BLANK. Final June/All and July/ANZ interactions,
history endpoint values, restoration of July/All and saving were confirmed
on 2026-09-16. The screenshot is a static preview; the local PBIX stays in
the ignored `exports/` directory.

- [Definitions, chart configuration and acceptance values](docs/power_bi_loans_deposits.md)
- [Rebuild all four accepted pages](docs/rebuild_power_bi.md)
- [Housing Loans DAX and checks](powerbi/dax/06_housing_loans.dax)
- [Business Loans DAX and checks](powerbi/dax/07_business_loans.dax)
- [Household Deposits DAX and checks](powerbi/dax/08_household_deposits.dax)

## Power BI Macro Context

![Australian Big Four Banking Macro Context](reports/macro_context.png)

The third page places the banking snapshot alongside national interest rates
and inflation. At July 2026, its cards show the monthly-average cash-rate
target **4.35%**, interbank overnight cash rate **4.35%**, three-month bank-bill
rate **4.48%** and published CPI annual change **3.50%**.

The RBA F1.1 rate chart spans March 2019-July 2026. The ABS Original All groups
CPI YoY chart shows its available April 2025-July 2026 history; earlier values
remain unavailable. These are national observations shared by all banks, so
this page has a month selector and no bank selector. Cards follow the selected
month while both charts retain their available histories.

Four additional DAX measures passed 21 source-derived checks. The author
confirmed the chart endpoints, June card changes with unchanged histories,
March 2025 CPI blank display, restoration of July and saving on 2026-09-16.
This is a fixed snapshot and a static preview; the PBIX remains local under
ignored `exports/`.

- [Definitions, source series and accepted checks](docs/power_bi_macro_context.md)
- [Rebuild all four accepted pages](docs/rebuild_power_bi.md)
- [Cash Rate Target DAX and checks](powerbi/dax/09_cash_rate_target.dax)
- [Interbank Cash Rate DAX and checks](powerbi/dax/10_interbank_cash_rate.dax)
- [3M Bank Bill Rate DAX and checks](powerbi/dax/11_bank_bill_3m.dax)
- [CPI YoY DAX and checks](powerbi/dax/12_cpi_yoy.dax)

## Power BI Capital & Liquidity

![Australian Big Four Banking Capital and Liquidity](reports/capital_liquidity.png)

The fourth page shows quarterly CET1 capital and risk-weighted assets, with
separate bank comparisons and histories for CET1 ratio, mean LCR and NSFR.
At 2026 Q1 / All, the two cards show **AUD 226.60 bn** and **AUD 1,889.68 bn**.
Reported bank ratios are displayed individually; they are not summed or averaged.

The APRA ADI data uses each entity's highest consolidation level, distinct
from the monthly MADIS domestic, unconsolidated scope. CET1 history spans
2013 Q1-2026 Q1 and notes the 2023 capital-framework change. LCR and NSFR
show their available 2018 Q1-2026 Q1 histories; earlier missing values stay blank.
The quarter selector filters the cards and bank comparisons while histories
retain their available ranges. The bank selector filters all eight data visuals.

Five additional measures passed 39 source-derived DAX checks. History endpoints,
quarter/bank filtering, missing liquidity displays, restoration of 2026 Q1 / All
and final saving were accepted on 2026-09-17. The screenshot is a static preview;
the PBIX remains local under ignored `exports/`.

- [Definitions, bank values, history endpoints and accepted checks](docs/power_bi_capital_liquidity.md)
- [Rebuild all four accepted pages](docs/rebuild_power_bi.md)
- [CET1 Capital DAX and checks](powerbi/dax/13_cet1_capital.dax)
- [Risk-Weighted Assets DAX and checks](powerbi/dax/14_risk_weighted_assets.dax)
- [CET1 Ratio DAX and checks](powerbi/dax/15_cet1_ratio.dax)
- [LCR DAX and checks](powerbi/dax/16_lcr.dax)
- [NSFR DAX and checks](powerbi/dax/17_nsfr.dax)

## Tools

- DuckDB and DBeaver for SQL
- Power BI for data modelling, DAX and reporting
- Git and GitHub for version control

## Data sources

Public Excel workbooks from APRA, RBA and ABS.
Raw workbooks and database files are stored locally and excluded from Git.

The completed imports use these pinned snapshots:

- `01_APRA_MADIS_Backseries_Mar2019_Jul2026.xlsx`: Table 1, range A2:AD11124; 11,122 raw rows and 30 columns.
- `02_APRA_ADI_Capital_Liquidity_Mar2013_Mar2026.xlsx`: Table 4, range A3:W5298; 5,295 raw rows and 23 columns.
- `03_RBA_F1_1_Monthly_Money_Market.xlsx`: Data, range A11:P698; 687 raw rows and 16 columns (a date column and 15 series). The selected staging table keeps three rates and all months.
- `04_ABS_CPI_Table1_Monthly_Jul2026.xlsx`: Data1, range A10:AB38; 28 raw rows and 28 columns (a date column and 27 series). The selected staging table keeps three Australia measures and all months.
- `05_ABS_CPI_Table17_Quarterly_Jul2026.xlsx`: Data1, range A10:S322; 312 raw rows and 19 columns (a date column and 18 series). The selected staging table keeps two Australia measures and all quarters.
- `06_ABS_CPI_Table18_Quarterly_Detail_Jul2026.xlsx`: Data1, range A10:IQ322, and Data2, range A10:EQ322; 312 rows per sheet, with 251 and 147 VARCHAR columns respectively. The raw tables and detail staging retain all 396 series across the same 312-quarter calendar.

APRA monetary amounts remain in millions of Australian dollars. ADI ratios retain
decimal fractions, so `0.124` represents 12.4% and `1.318` represents 131.8%.
Missing liquidity observations remain NULL. RBA rates retain per-cent units
in `_pct` columns: `4.35` means 4.35%. CPI change columns also retain per-cent
units: `3.5` means 3.5%. Divide these `_pct` values by 100 once if a reporting
field requires a decimal fraction. The CPI index has its own scale,
September MONTH 2025 = 100.00, and is not a percentage. September QUARTER 2025
retains index 99.73 in Table 17. Published changes are preserved rather than
recalculated from rounded indexes. Source definitions, reference-period changes
and coverage are documented below. Table 18 stores a single `metric_value` with
its `metric` and `unit`: index numbers, per-cent changes or contribution index
points. Select the measure and unit before aggregation, and do not sum overlapping
groups, subgroups and expenditure classes.

## SQL scripts

- [00_check_connection.sql](sql/00_check_connection.sql): check the active database and existing tables.
- [setup/01_create_apra_inputs.sql](sql/setup/01_create_apra_inputs.sql): create the raw MADIS table and four-bank mapping in a new empty database.
- [01_audit_existing_tables.sql](sql/01_audit_existing_tables.sql): inspect raw records, bank matching, date coverage, duplicates and seven selected financial measures.
- [02_create_apra_big_four_staging.sql](sql/02_create_apra_big_four_staging.sql): create the typed four-bank monthly table and check its types, coverage, keys and missing amounts.
- [03_check_apra_source_rebuild.sql](sql/03_check_apra_source_rebuild.sql): compare all MADIS source records and the scripted bank mappings against an existing database.
- [04_load_apra_adi_quarterly.sql](sql/04_load_apra_adi_quarterly.sql): load the ADI quarterly back series and check its coverage and bank matching.
- [05_audit_apra_adi_quarterly.sql](sql/05_audit_apra_adi_quarterly.sql): audit quarterly keys, both dates, ten selected numeric measures and liquidity coverage.
- [06_create_apra_big_four_quarterly.sql](sql/06_create_apra_big_four_quarterly.sql): create the typed quarterly table, retain the framework-period label and validate its types, coverage and expected NULLs.
- [07_load_rba_monthly.sql](sql/07_load_rba_monthly.sql): import all 15 RBA series and inspect the raw schema, date coverage and latest rate samples.
- [08_audit_rba_monthly.sql](sql/08_audit_rba_monthly.sql): audit dates and three selected rates, then verify their monthly coverage for both APRA periods.
- [09_create_rba_monthly_staging.sql](sql/09_create_rba_monthly_staging.sql): create the typed monthly reference-rate table and check its retained history, missing values and historical source zero.
- [10_load_abs_cpi_monthly.sql](sql/10_load_abs_cpi_monthly.sql): import all 27 monthly CPI series and inspect raw types, dates and five Australia samples.
- [11_audit_abs_cpi_monthly.sql](sql/11_audit_abs_cpi_monthly.sql): audit source month labels, three Australia measures, missing-value positions and available months within the APRA periods.
- [12_create_abs_cpi_monthly_staging.sql](sql/12_create_abs_cpi_monthly_staging.sql): create the typed Australia monthly CPI table, align dates to month ends and validate twelve snapshot expectations.
- [13_load_abs_cpi_quarterly.sql](sql/13_load_abs_cpi_quarterly.sql): import all 18 quarterly CPI series and inspect raw types, dates and five Australia samples.
- [14_audit_abs_cpi_quarterly.sql](sql/14_audit_abs_cpi_quarterly.sql): audit source quarter labels, Australia index/QoQ measures, missing-value positions and ADI quarterly coverage.
- [15_create_abs_cpi_quarterly_staging.sql](sql/15_create_abs_cpi_quarterly_staging.sql): create the typed Australia quarterly CPI table, align dates to quarter ends and validate ten snapshot expectations.
- [16_load_abs_cpi_quarterly_detail.sql](sql/16_load_abs_cpi_quarterly_detail.sql): import both Table 18 sheets, preserve all series and inspect their schemas, calendars and latest All groups observations.
- [17_audit_abs_cpi_quarterly_detail.sql](sql/17_audit_abs_cpi_quarterly_detail.sql): audit both calendars and all 396 series, reconcile the headline measures with Table 17 and describe ADI-period coverage.
- [18_create_abs_cpi_quarterly_detail_staging.sql](sql/18_create_abs_cpi_quarterly_detail_staging.sql): create the complete typed series-quarter table with source metadata, validate fifteen expectations and compare every typed raw observation with staging in both directions.
- [19_check_model_joins.sql](sql/19_check_model_joins.sql): check all six staging grains and trial monthly/quarterly alignment, including guarded quarterly rate inputs.
- [20_create_date_dimension.sql](sql/20_create_date_dimension.sql): create the shared 2013-2026 daily calendar, validate its attributes and confirm model date coverage.
- [21_create_fact_bank_monthly.sql](sql/21_create_fact_bank_monthly.sql): create the monthly bank fact, check its grain and dimension references, and reconcile all retained amounts.
- [22_create_fact_bank_quarterly.sql](sql/22_create_fact_bank_quarterly.sql): create the quarterly bank fact with source liquidity NULLs and framework labels, then validate and reconcile every field.
- [23_create_fact_macro_monthly.sql](sql/23_create_fact_macro_monthly.sql): retain one macro row per required bank month, preserving CPI missing-value patterns and reconciling source values.
- [24_create_fact_macro_quarterly.sql](sql/24_create_fact_macro_quarterly.sql): derive guarded RBA quarterly means and retain published CPI for the 53 bank quarters, with completeness and full-record checks.
- [25_validate_analysis_model.sql](sql/25_validate_analysis_model.sql): validate all six model inventories, six dimension relationships and combined monthly/quarterly trial joins.

## Rebuild the data modules and SQL model

Start with the [APRA rebuild guide](docs/rebuild_apra.md) in a separate empty
DuckDB database, then continue with the [RBA rebuild guide](docs/rebuild_rba.md)
and [ABS CPI rebuild guide](docs/rebuild_abs_cpi.md) on the same
connection. Continue with the [analysis model rebuild guide](docs/rebuild_analysis_model.md)
to execute scripts 19-25 in order. Use the six downloaded workbooks and adjust the source paths as
instructed. The modules were tested with DuckDB v1.5.5 and its official Excel
extension. Both macro modules' APRA-period coverage queries require the two APRA
staging tables to exist first. The Table 18 audit also requires the Table 17
staging table, created earlier in the ABS guide.

The guides create `raw.apra_madis`, `raw.apra_adi_quarterly`,
`raw.rba_f1_1_monthly`, `raw.abs_cpi_table1_monthly`,
`raw.abs_cpi_table17_quarterly`, `raw.abs_cpi_table18_data1_quarterly`,
`raw.abs_cpi_table18_data2_quarterly`, `core.dim_bank`,
`stg.apra_big_four_monthly`, `stg.apra_big_four_quarterly`,
`stg.rba_monthly_rates`, `stg.abs_cpi_australia_monthly`,
`stg.abs_cpi_australia_quarterly` and `stg.abs_cpi_australia_quarterly_detail`.
The model guide adds `core.dim_date` and the four `mart.fact_*` tables listed
above, reusing `core.dim_bank`. Creation and insertion statements run once in
the rebuild database; diagnostics are repeatable. The Power BI report is outside
this SQL rebuild. Staging and facts are stored snapshots; an automatic refresh
process has not yet been implemented.

## Documentation

- [Analysis findings](docs/analysis_findings.md): six conclusions, calculation inputs and source locations.
- [Final review](docs/final_review.md): validation evidence, documentation corrections and future extensions.

- [Initial APRA audit](docs/apra_initial_audit.md): observed results, source references, definitions and audit scope.
- [APRA staging table](docs/apra_staging.md): cleaning rules, data dictionary, observed validation results and execution notes.
- [ADI quarterly source review](docs/apra_adi_source_review.md): source selection, reporting scope, units, date/key audit and liquidity coverage.
- [ADI quarterly staging table](docs/apra_adi_staging.md): 16-column data dictionary, transformation rules and confirmed validation results.
- [APRA rebuild guide](docs/rebuild_apra.md): prerequisites, execution order for both APRA modules and MADIS source-comparison results.
- [RBA source review](docs/rba_source_review.md): workbook layout, series IDs, units, missing-value patterns and confirmed coverage checks.
- [RBA staging table](docs/rba_staging.md): four-column data dictionary, conversion rules and eleven confirmed staging checks.
- [RBA rebuild guide](docs/rebuild_rba.md): prerequisites, execution order and expected results for rebuilding the monthly rate module after APRA.
- [ABS monthly CPI source review](docs/abs_cpi_monthly_source_review.md): source layout, series register, units and confirmed import/audit results.
- [Australia monthly CPI staging table](docs/abs_cpi_monthly_staging.md): four-column dictionary, month-end conversion and twelve confirmed staging checks.
- [ABS quarterly CPI source review](docs/abs_cpi_quarterly_source_review.md): Table 17 layout, series IDs, index reference basis and confirmed date/metric/coverage audit.
- [Australia quarterly CPI staging table](docs/abs_cpi_quarterly_staging.md): three-column dictionary, quarter-end conversion and ten confirmed staging checks.
- [ABS quarterly CPI detail source review](docs/abs_cpi_quarterly_detail_source_review.md): both Table 18 sheets, all-series metadata and coverage, and confirmed audit and Table 17 reconciliation results.
- [Australia quarterly CPI detail staging table](docs/abs_cpi_quarterly_detail_staging.md): seven-column dictionary, preserved series and missing observations, fifteen confirmed checks and two complete source comparisons.
- [ABS CPI rebuild guide](docs/rebuild_abs_cpi.md): prerequisites, execution order and expected results for monthly Table 1, quarterly Table 17 and quarterly detail Table 18.
- [Analysis model plan](docs/analysis_model_plan.md): grains, periods, reporting scopes, units, quarterly rate definition and intended relationship diagram.
- [Date dimension](docs/date_dimension.md): thirteen-field dictionary, calendar generation, period labels and confirmed date-coverage checks.
- [Monthly bank fact](docs/fact_bank_monthly.md): nine-field dictionary, amount scope, keys and confirmed source comparisons.
- [Quarterly bank fact](docs/fact_bank_quarterly.md): fourteen-field dictionary, retained liquidity NULLs, framework labels and confirmed source comparisons.
- [Monthly macro fact](docs/fact_macro_monthly.md): seven-field dictionary, bank-month alignment and preserved CPI availability.
- [Quarterly macro fact](docs/fact_macro_quarterly.md): six-field dictionary, guarded means, published quarterly CPI and confirmed completeness/value checks.
- [Integrated model validation](docs/model_validation.md): six-table acceptance, dimension relationships, combined trial joins and observed fault detection.
- [Analysis model rebuild guide](docs/rebuild_analysis_model.md): source prerequisites, scripts 19-25, expected outputs and snapshot-refresh boundaries.
- [Power BI Overview](docs/power_bi_overview.md): five measures, chart fields, reporting scope and accepted interactions.
- [Power BI Loans & Deposits](docs/power_bi_loans_deposits.md): three additional measures, bank comparisons, histories and accepted interactions.
- [Power BI Macro Context](docs/power_bi_macro_context.md): four national macro measures, available histories, source coverage and accepted interactions.
- [Power BI Capital & Liquidity](docs/power_bi_capital_liquidity.md): five quarterly measures, bank comparisons, available histories, framework note and accepted checks.
- [Power BI rebuild guide](docs/rebuild_power_bi.md): import, model settings, seventeen DAX measures and all four accepted report pages.
