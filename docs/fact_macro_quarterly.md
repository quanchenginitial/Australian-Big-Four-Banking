# Quarterly macro fact

Step 6F, independently validated and confirmed in the project on 2026-09-13. All four facts and the date dimension have completed their individual checks. The script is [24_create_fact_macro_quarterly.sql](../sql/24_create_fact_macro_quarterly.sql).

## Grain and source window

`mart.fact_macro_quarterly` stores **one observation quarter shared by all banks**, with `report_date` as its primary key. Its **53 rows span 2013-03-31 through 2026-03-31**, matching the distinct reporting dates in `mart.fact_bank_quarterly`. The fact contains three project-derived RBA quarterly means and two published Australia quarterly CPI measures. It has no bank key.

The bank dates define the analysis window. LEFT JOINs retain each required quarter, and the complete staging histories remain unchanged: 687 monthly RBA rows and 312 quarterly CPI rows. The stored fact does not refresh automatically when staging changes. Its dependency on bank dates during SQL construction is separate from the later Power BI model, where the date dimension filters the facts independently. See the [analysis model plan](analysis_model_plan.md).

## Data dictionary

| Field | Type | NULL allowed | Meaning |
|---|---|---|---|
| report_date | DATE, primary key | No | Observation quarter represented by its calendar quarter end |
| cash_rate_target_qtr_mean_pct | DECIMAL(18,6) | Yes | Equal-weight mean of the quarter's three monthly cash-rate-target averages |
| interbank_cash_rate_qtr_mean_pct | DECIMAL(18,6) | Yes | Equal-weight mean of the quarter's three monthly interbank cash-rate averages |
| bank_bill_3m_qtr_mean_pct | DECIMAL(18,6) | Yes | Equal-weight mean of the quarter's three monthly three-month bank-bill-rate averages |
| cpi_index | DECIMAL(18,6) | No | Published Australia Original All groups quarterly CPI index from Table 17 |
| cpi_qoq_pct | DECIMAL(18,6) | No | Published Australia Original CPI change from the preceding quarter, per cent |

Rates and QoQ changes remain in per-cent units: `1.4` means 1.4%. CPI index values are index numbers. The source reference is September **month** 2025 = 100; September **quarter** 2025 retains the published index of 99.73. Dates label observation periods rather than release timestamps.

The index and QoQ are copied from `stg.abs_cpi_australia_quarterly` at their existing precision, without averaging monthly CPI, recalculating the published QoQ or creating a YoY measure. Negative and zero published changes are retained. See the [quarterly CPI staging notes](abs_cpi_quarterly_staging.md).

## Quarterly rate definition and incomplete inputs

Each rate uses the definition already validated in script 19:

`quarterly_mean_pct = (month_1_pct + month_2_pct + month_3_pct) / 3`

This is a project-derived equal-weight mean of three monthly averages. It is not an official RBA quarterly series, a daily-weighted average or a quarter-end spot rate. The `_qtr_mean_pct` names make the transformation explicit. Source definitions remain in the [RBA staging notes](rba_staging.md).

For each required quarter, the calculation requires exactly three source rows, three distinct months and three valid month-end date labels. Each rate separately requires three non-NULL values. Only then is its mean calculated and stored at six decimal places. If one rate is incomplete, that rate becomes NULL while other complete rates remain populated. Missing months, duplicate rows or invalid labels withhold all three means for the affected quarter. An entirely absent RBA quarter still retains the bank quarter through the LEFT JOIN.

The three rate columns therefore allow NULL, but **the current 53-quarter snapshot has no missing rate values**. Section 6 reports incomplete source quarters and missing derived rates as failures for this snapshot. A PASS reconciliation alone cannot establish input completeness: a correctly retained NULL still needs the completeness check. Missing values are never replaced with zero or a partial average.

Both CPI fields are required because Table 17 completely covers the selected 53 quarters. Missing CPI observations or values cause an insertion error; duplicate CPI matches cause a primary-key error. The date primary key and quarter-end CHECK enforce one macro row per calendar quarter. Date-dimension references are verified by query; no database foreign key is declared.

## Execution and expected outputs

Dependencies are `mart.fact_bank_quarterly`, `core.dim_date`, `stg.rba_monthly_rates` and `stg.abs_cpi_australia_quarterly`. The monthly macro fact is not an execution dependency.

| Section | Operation | Expected result |
|---|---|---|
| 1 | Ensure the `mart` schema exists | Statement succeeds |
| 2 | Define the six fields and constraints | Statement succeeds |
| 3 | Populate the bank quarters using guarded RBA means and source CPI | 53 rows inserted |
| 4 | Describe the fact | Six fields; DATE key and both CPI fields null NO; three RBA means null YES |
| 5 | Summarize the history | 53 rows, 53 quarters; 2013-03-31 to 2026-03-31 |
| 6 | Validate dates, coverage and source completeness | 17 PASS rows; all counts zero |
| 7 | Compare all six fields with the required derived/source values | Two PASS rows; both differences zero |

Sections 2 and 3 run once. Creation fails if the table exists; duplicate insertion is rejected by the primary key. If creation succeeded but insertion has not run, execute section 3 without recreating the table. Sections 4-7 are repeatable read-only checks. Select the complete statement through its semicolon, including the INSERT and all CTEs in section 3.

Section 6 checks row/quarter counts, unique and valid date keys, a continuous span, exact endpoints, equality with the bank quarter set, date references, diagnostic bank-join row counts, RBA input completeness, missing derived rates, positive rates/index, CPI quarter coverage and required CPI values. It imposes no positivity rule on CPI QoQ. Expectations describe the pinned source window and must be reviewed when refreshing it.

Section 7 reconstructs the required quarters with the same guarded rate definition and published CPI, then compares all six fields using `EXCEPT ALL` in both directions. Both `expected_minus_fact_rows` and `fact_minus_expected_rows` must be zero. NULL semantics and duplicate multiplicity are preserved.

## Independent validation and project status

The exact script ran in a fresh in-memory DuckDB v1.5.5 database after rebuilding the existing ADI, RBA and quarterly CPI inputs, the date dimension and quarterly bank fact. All six field definitions, the overview, 17 integrity checks and two full-record comparisons passed. A diagnostic join retained and matched all 212 bank rows across 53 quarters; full RBA/CPI staging row counts remained 687/312.

Independent workbook reads derived the 53 bank dates and compared all six fields of all 53 records. Separate Decimal arithmetic matched **159 derived quarterly rate values**; all **106 published CPI values** matched the workbook. The result has 265 numbers and no NULL measures. For 2026Q1, the retained values are cash/interbank means 3.796667, bank-bill mean 3.973333, CPI index 101.700000 and QoQ 1.400000.

Four temporary changes tested a deleted macro quarter, a changed positive derived rate, a missing dimension date and an extra quarter outside the bank window. Five separate RBA input scenarios tested a missing month, a duplicate month, one NULL cash-rate value, an invalid month-end label and an entirely missing quarter. All five RBA input scenarios retained all 53 quarters; incomplete rates became NULL, complete unaffected rates and CPI stayed unchanged, and completeness checks flagged the affected quarter. Full-value comparisons still passed when the stored NULLs correctly reflected those incomplete inputs.

Separate load tests rejected duplicate and absent required CPI quarters. Table checks accepted NULL rates and zero QoQ while rejecting duplicate quarter keys, a NULL date, a NULL CPI index and a month end outside a quarter end. All changes were confined to in-memory tests; source hashes were unchanged and the populated project database was not opened.

## Confirmed project execution

Four DBeaver screenshots on 2026-09-13 confirmed all expected results: six fields with the date primary key, required CPI fields and nullable RBA means at 18:43:05; 53 rows and quarters from 2013-03-31 to 2026-03-31 at 18:44:16; all 17 integrity checks passing with zero issue counts at 18:44:39; and both full-record comparisons passing with zero differences at 18:44:57. The project script matches the independently tested version.

All six model tables have also passed [integrated model validation](model_validation.md). The [model rebuild guide](rebuild_analysis_model.md) records the complete execution order and expected results.
