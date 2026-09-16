# Quarterly bank fact

Step 6D, confirmed on 2026-09-13. The shared date dimension, monthly bank fact and all four project result sets from [22_create_fact_bank_quarterly.sql](../sql/22_create_fact_bank_quarterly.sql) are confirmed.

## Grain, scope and retained fields

`mart.fact_bank_quarterly` stores **one bank at one publication-quarter reporting date**, keyed by `(bank_code, report_date)`. It preserves **212 observations: four banks over 53 quarters, 2013-03-31 through 2026-03-31**. The reporting date labels a period; it is not a release timestamp.

The insertion projects 14 fields directly from `stg.apra_big_four_quarterly`, retaining both dates, all ten selected measures and the existing capital-framework label. There are no joins, filters, scaling, ratio recalculations, aggregation or NULL replacements. The fact is a stored snapshot; changes in staging do not automatically refresh it.

Bank names and ABNs remain available through `core.dim_bank`, and calendar labels through `core.dim_date`. The ADI source reports at each entity's highest consolidation level. Its scope differs from the monthly MADIS domestic, unconsolidated source. See the existing [ADI staging notes](apra_adi_staging.md) and [analysis model plan](analysis_model_plan.md).

| Field | Type | NULL allowed | Meaning |
|---|---|---|---|
| bank_code | VARCHAR | No | Bank lookup key; part of primary key |
| report_date | DATE | No | Publication-period quarter end; part of primary key |
| entity_quarter_end | DATE | No | Source's separate entity quarter end |
| cet1_capital_million | DECIMAL(20,4) | No | Total Common Equity Tier 1 capital, AUD millions |
| tier1_capital_million | DECIMAL(20,4) | No | Total Tier 1 capital, AUD millions |
| total_capital_million | DECIMAL(20,4) | No | Total capital base, AUD millions |
| rwa_million | DECIMAL(20,4) | No | Total risk-weighted assets, AUD millions |
| cet1_ratio | DECIMAL(18,6) | No | Reported Common Equity Tier 1 capital ratio |
| tier1_ratio | DECIMAL(18,6) | No | Reported Tier 1 capital ratio |
| total_capital_ratio | DECIMAL(18,6) | No | Reported total capital ratio |
| lcr_ratio | DECIMAL(18,6) | Yes | Reported mean Liquidity Coverage Ratio |
| nsfr_ratio | DECIMAL(18,6) | Yes | Reported Net Stable Funding Ratio |
| mlh_ratio | DECIMAL(18,6) | Yes | Reported average Minimum Liquidity Holdings ratio |
| capital_framework | VARCHAR | No | Existing staging label identifying the source framework period |

The two dates match for every selected source record but remain separate fields. `report_date` is the intended relationship to `core.dim_date.calendar_date`; the entity date is retained as a source attribute, with its agreement checked for this snapshot.

## Units, missing values and framework periods

Amounts keep their four-decimal AUD-million values. Ratios keep six-decimal fractions: `0.124000` means 12.4% and `1.318000` means 131.8%. The model retains published ratios rather than recomputing them from capital and RWA. Percentage formatting belongs in the reporting layer.

Only the three liquidity fields allow NULL. LCR and NSFR each have **80 NULLs**, representing 20 early quarters per bank through 2017, followed by 33 numeric quarters per bank from 2018Q1. MLH has **212 NULLs**, with no available observations in this selection. None of these values are filled with zero. Across all ten measures, there are **1,748 numeric cells and 372 NULL cells**.

`capital_framework` remains `Basel III (2013-2022)` before 2023-01-01 and `ADI capital framework (2023+)` thereafter. The groups contain 160 and 52 bank-quarter rows respectively. These existing project labels identify the reporting break described by the source; they do not adjust observations to a common basis.

Capital balances are not summed across quarters. Published ratios should initially be reported by bank and quarter; summing bank ratios or presenting an unlabelled simple average is inappropriate for the planned report. Mean LCR and average MLH retain their source definitions rather than being relabelled as quarter-end balances. Cross-source ratios combining monthly MADIS amounts and consolidated ADI measures are outside this model.

## Constraints and dimensional references

The composite primary key and quarter-end CHECK enforce at most one observation per bank/calendar quarter. Eleven fields are NOT NULL; the three liquidity ratios remain nullable. The source's positive populated values and exact missingness pattern are validation expectations for this snapshot, not universal database constraints for future sources.

No database foreign keys are declared. The existing bank dimension has no declared primary key; section 6 verifies its row count, key uniqueness, required metadata, reference matches and agreement with staging. Both bank and date lookups are also checked for changes in fact row counts. These are query checks, separate from table constraints and the accepted Power BI relationships described in the [report rebuild guide](rebuild_power_bi.md).

## Execution and expected outputs

Run the complete numbered statements in the existing DBeaver connection. Dependencies are `stg.apra_big_four_quarterly`, `core.dim_bank` and `core.dim_date`. This script does not depend on the monthly fact or either planned macro fact.

| Section | Operation | Expected result |
|---|---|---|
| 1 | Ensure the `mart` schema exists | Statement succeeds |
| 2 | Define the table and constraints | Statement succeeds |
| 3 | Insert the retained staging fields | 212 rows inserted |
| 4 | Describe all fields | 14 fields; first two keys PRI; only LCR/NSFR/MLH null flags YES |
| 5 | Summarize the fact | 212 rows, four banks, 53 quarters; 2013-03-31 to 2026-03-31 |
| 6 | Validate integrity and source patterns | 21 PASS rows; actual counts match expected counts |
| 7 | Reconcile all 14 fields with staging | Two PASS rows; both differences zero |

Sections 2 and 3 run once: existing tables are not replaced, and the primary key rejects repeated insertion. If creation succeeded but insertion has not run, execute section 3 without repeating section 2. Sections 4-7 are repeatable read-only queries. Select all CTEs through the final semicolon in sections 6 and 7.

Section 6 checks row/bank counts, unique bank-quarter keys, complete calendars, required fields, quarter-end dates, agreement of the two dates, bank/date references, dimension integrity, lookup row counts, bank metadata, populated-value positivity, the three liquidity NULL counts, the timing of LCR/NSFR availability and framework labels. All expected counts are zero except `lcr_missing_rows = 80`, `nsfr_missing_rows = 80` and `mlh_missing_rows = 212`. These three nonzero counts should still show PASS.

Section 7 uses `EXCEPT ALL` across all 14 fields in both directions, retaining multiplicity and NULL semantics. Both `staging_minus_fact_rows` and `fact_minus_staging_rows` must be zero. This checks the exact values and locations of missing observations, not merely their totals.

## Independent validation and project status

The exact script ran successfully in a fresh in-memory DuckDB v1.5.5 database, using the existing APRA setup, ADI import and staging scripts, plus the creation portion of the date-dimension script. All field definitions, the overview, 21 integrity checks and both full-record comparisons passed.

A fresh independent workbook reader matched all **212 records across 14 fields**. It compared both dates and every measure at its stored precision, including 1,748 numbers and 372 NULLs, and independently checked the framework labels. Seven temporary scenarios verified detection of a missing bank, a duplicated bank, a missing date, a changed positive ratio, a liquidity NULL moved across the 2018 boundary while preserving the total missing count, an incorrect framework label and an incorrect entity date.

Separate checks confirmed that liquidity NULLs are accepted while duplicate keys, a NULL reporting key, a NULL capital amount and a month end outside a quarter end are rejected. All temporary changes were confined to in-memory test databases. Source workbooks remained unchanged, and the populated project database was not opened.

## Confirmed project execution

Four DBeaver screenshots on 2026-09-13 confirmed the complete quarterly results: all 14 fields, key and NULL settings at 18:13:03; 212 rows, four banks and 53 quarters from 2013-03-31 through 2026-03-31 at 18:13:18; all 21 integrity checks passing at 18:13:39; and both full-record comparisons passing with zero differences at 18:13:54. The LCR/NSFR/MLH missing counts remained 80/80/212. The project SQL file matches the independently tested version.

The [monthly macro fact](fact_macro_monthly.md) and [quarterly macro fact](fact_macro_quarterly.md) are also confirmed. The latter uses the 53 distinct bank-quarter dates. All six model tables have passed [integrated model validation](model_validation.md); see [model rebuild](rebuild_analysis_model.md) for the complete execution order.
