# Monthly macro fact

Step 6E, confirmed on 2026-09-13. Both bank facts, the shared date dimension and all four project result sets from [23_create_fact_macro_monthly.sql](../sql/23_create_fact_macro_monthly.sql) are confirmed.

## Grain and analysis calendar

`mart.fact_macro_monthly` contains **one observation month shared by all banks**, with `report_date` as its primary key. Its initial population has **89 rows, 2019-03-31 through 2026-07-31**, matching the distinct dates in `mart.fact_bank_monthly`. It has no bank code or bank amounts.

The load takes the bank fact's distinct reporting dates and LEFT JOINs the RBA and Australia monthly CPI staging tables by exact month-end date. DISTINCT applies only to the bank dates, where four banks share each month. It does not deduplicate macro source observations. The insertion preserves source precision, NULLs, negative changes and zeros without aggregation, scaling or imputation.

This date dependency defines the analysis window in SQL. It does not imply a direct fact-to-fact Power BI relationship. The intended report uses `core.dim_date.calendar_date` to filter the bank and macro facts separately. Bank filters apply to bank facts; they do not turn a national macro observation into a bank-specific measure. See the [analysis model plan](analysis_model_plan.md).

The complete staging histories remain intact: 687 RBA months through August 2026 and 28 CPI months through July 2026. The macro fact excludes observations outside the bank analysis window and preserves bank months that have no CPI data. It is a stored snapshot and does not refresh automatically when its inputs change.

## Data dictionary and units

| Field | Type | NULL allowed | Meaning |
|---|---|---|---|
| report_date | DATE, primary key | No | Observation month represented by its last calendar day |
| cash_rate_target_pct | DECIMAL(18,6) | No | RBA cash-rate target, monthly average, per cent |
| interbank_cash_rate_pct | DECIMAL(18,6) | No | RBA interbank cash rate, monthly average, per cent |
| bank_bill_3m_pct | DECIMAL(18,6) | No | RBA three-month bank-bill rate, monthly average, per cent |
| cpi_index | DECIMAL(18,6) | Yes | Australia Original All groups CPI index; September 2025 = 100 |
| cpi_yoy_pct | DECIMAL(18,6) | Yes | Published Australia Original CPI change from the corresponding month of the previous year, per cent |
| cpi_mom_pct | DECIMAL(18,6) | Yes | Published Australia Original CPI change from the previous month, per cent |

For rates and CPI changes, `3.5` means **3.5%**. CPI index values are index numbers, not percentages. These source units differ from the decimal fractions used by the quarterly bank ratios. Preserve each field's definition when later adding report measures and formatting.

RBA dates label monthly averages; they do not make the rates month-end spot observations. CPI dates label observation months, not publication timestamps. This model does not establish what information was available on a historical release date. Definitions and source IDs remain in the [RBA staging notes](rba_staging.md) and [monthly CPI staging notes](abs_cpi_monthly_staging.md).

## Availability and constraints

| Measure | Required months | Numeric months | NULL months | First available month in this fact |
|---|---:|---:|---:|---|
| Cash-rate target | 89 | 89 | 0 | 2019-03 |
| Interbank cash rate | 89 | 89 | 0 | 2019-03 |
| Three-month bank-bill rate | 89 | 89 | 0 | 2019-03 |
| CPI index | 89 | 28 | 61 | 2024-04 |
| CPI YoY | 89 | 16 | 73 | 2025-04 |
| CPI MoM | 89 | 27 | 62 | 2024-05 |

All three CPI fields end in July 2026 in the pinned source snapshot. The 534 measure cells contain **338 numbers and 196 NULLs**. The seven negative and three zero MoM changes remain unchanged. These are counts of months, whereas the earlier trial bank joins repeated each macro absence on four bank rows.

The primary key and month-end CHECK enforce one row per observation month. Date and all three RBA values are required because RBA coverage for this window is complete. The three CPI fields allow NULL. A duplicate matching RBA or CPI source month causes a primary-key error during insertion; a missing required RBA month causes a NOT NULL error. CPI absence is allowed and checked against the source's availability pattern after insertion.

There is no database foreign-key declaration. Section 6 checks the date-dimension reference and equality of the fact's month set with the bank analysis month set. It also verifies that a diagnostic bank-to-macro LEFT JOIN does not add rows. This diagnostic is separate from the later Power BI relationship design.

## Execution and expected outputs

Dependencies are the confirmed `mart.fact_bank_monthly`, `core.dim_date`, `stg.rba_monthly_rates` and `stg.abs_cpi_australia_monthly`. The quarterly bank and macro facts are not execution dependencies.

| Section | Operation | Expected result |
|---|---|---|
| 1 | Ensure the `mart` schema exists | Statement succeeds |
| 2 | Define the seven fields and constraints | Statement succeeds |
| 3 | Populate the required macro months | 89 rows inserted |
| 4 | Describe the fact | Seven fields; DATE key and three RBA fields null NO, three CPI fields null YES |
| 5 | Summarize the retained months | 89 rows, 89 months; 2019-03-31 to 2026-07-31 |
| 6 | Check dates, coverage and value patterns | 20 PASS rows |
| 7 | Reconcile all seven fields with the required source observations | Two PASS rows, both differences zero |

Execute sections 2 and 3 once. Creation does not replace an existing table, and repeated insertion is rejected by the primary key. If creation succeeded but insertion has not run, execute section 3 without repeating section 2. Sections 4-7 are repeatable read-only checks. Select the complete numbered statement through its final semicolon, including every CTE in sections 3, 6 and 7.

Section 6 validates counts, unique month keys, month-end dates, a continuous span, endpoints, exact banking-month coverage, date-dimension references, diagnostic join row counts, RBA completeness and the pinned CPI value patterns. Expected nonzero counts are `cpi_index_missing = 61`, `cpi_yoy_missing = 73`, `cpi_mom_missing = 62`, `cpi_mom_negative = 7` and `cpi_mom_zero = 3`. All other counts are zero. The NULL-pattern check examines dates as well as totals.

Section 7 reconstructs the required source observations from the bank calendar and the two staging inputs, then uses `EXCEPT ALL` on all seven fields in both directions. `expected_minus_fact_rows` and `fact_minus_expected_rows` must both be zero. This preserves multiplicity and NULL semantics, detecting individual changes that summary counts would miss.

Update the dates and expectations deliberately when adopting another source snapshot. Source positivity in this selected period is not a universal constraint or a reason to replace future nonpositive values. A later refresh needs explicit handling of the stored fact and its checks.

## Independent validation and project status

The exact script ran in a new in-memory DuckDB v1.5.5 database after rebuilding the existing monthly APRA, RBA and CPI inputs and the date/monthly bank tables. Seven field definitions, the overview, all 20 integrity checks and both reconciliation checks passed. The diagnostic bank join retained and matched all 356 bank rows across 89 months; staging still held 687 RBA and 28 CPI rows.

Independent reads of all three original workbooks derived the bank month set and matched every field of all **89 records**, including **338 numeric values at six decimals and 196 NULLs**. Six temporary scenarios detected a deleted macro month, a YoY NULL moved across its availability boundary while preserving its total, an altered positive CPI index, a missing dimension date, a duplicated RBA source row after loading, and an extra macro month outside the bank window.

Three separate load checks confirmed rejection of duplicate RBA months, duplicate CPI months and a missing required RBA month. Additional table checks accepted missing CPI while rejecting duplicate month keys, a NULL date, a NULL rate and a non-month-end date. All changes were confined to fresh in-memory databases. The source workbook hashes remained unchanged; the populated project database was not opened.

## Confirmed project execution

Four DBeaver screenshots on 2026-09-13 confirmed all expected results: seven correctly typed fields, the date primary key and NULL settings at 18:28:10; 89 rows and months from 2019-03-31 to 2026-07-31 at 18:28:29; all 20 integrity checks passing at 18:28:51; and both full-record comparisons passing with zero differences at 18:29:22. CPI NULL counts remained 61/73/62 and MoM negative/zero counts 7/3. The project script matches the independently tested version.

The [quarterly macro fact](fact_macro_quarterly.md) is also confirmed. All six model tables have passed [integrated model validation](model_validation.md); see [model rebuild](rebuild_analysis_model.md) for the complete execution order.
