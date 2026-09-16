# Rebuild the SQL analysis model

The completed SQL model contains the existing four-bank dimension, a daily date dimension and four facts at monthly and quarterly grains. All individual and integrated project checks were confirmed through DBeaver on 2026-09-13. This guide records how to reproduce those objects from the pinned source snapshots. The subsequent Power BI stage is now complete; follow the [Power BI rebuild guide](rebuild_power_bi.md) after this SQL procedure. The [final review](final_review.md) distinguishes SQL testing from report acceptance.

## Prerequisites and source order

Use DuckDB v1.5.5, the repository SQL and the six local workbooks listed in the [README](../README.md). Raw workbooks and database files are excluded from Git. The source-loading stage requires the official Excel extension; first-time installation needs access to its repository. Model scripts 19-25 read database tables and do not need workbook paths or another Excel import.

For a complete rebuild, connect DBeaver to a separate empty DuckDB database and run these source guides in order on the same connection:

1. [APRA rebuild](rebuild_apra.md): create the raw schema, `core.dim_bank`, and both APRA raw/staging modules.
2. [RBA rebuild](rebuild_rba.md): create the full monthly rate raw/staging module.
3. [ABS CPI rebuild](rebuild_abs_cpi.md): create monthly Table 1, quarterly Table 17 and detail Table 18 raw/staging modules.

Follow each guide's path settings, fixed workbook ranges and source audit checks before continuing. This yields all six staging inputs required by script 19, as well as the bank mapping. Table 18 is checked by that preflight but is not used to populate the four initial model facts.

## Model execution order

Confirm the connection and file path with [00_check_connection.sql](../sql/00_check_connection.sql). After completing the source stage, execute the following files in order. Within each file, select each complete numbered statement through its final semicolon and run it before moving to the next statement. An INSERT containing CTEs is one complete statement.

| Order | Script | Object or check | Expected result |
|---|---|---|---|
| 1 | [19_check_model_joins.sql](../sql/19_check_model_joins.sql) | Source grains and period alignment | Three read-only outputs: 6 input, 9 monthly and 10 quarterly PASS rows |
| 2 | [20_create_date_dimension.sql](../sql/20_create_date_dimension.sql) | core.dim_date | 13 fields; 5,113 days; 13 calendar PASS rows and 5 coverage PASS rows |
| 3 | [21_create_fact_bank_monthly.sql](../sql/21_create_fact_bank_monthly.sql) | mart.fact_bank_monthly | 9 fields; 356 rows; 14 integrity PASS rows and 2 zero-difference comparisons |
| 4 | [22_create_fact_bank_quarterly.sql](../sql/22_create_fact_bank_quarterly.sql) | mart.fact_bank_quarterly | 14 fields; 212 rows; 21 integrity PASS rows and 2 zero-difference comparisons |
| 5 | [23_create_fact_macro_monthly.sql](../sql/23_create_fact_macro_monthly.sql) | mart.fact_macro_monthly | 7 fields; 89 rows; 20 integrity PASS rows and 2 zero-difference comparisons |
| 6 | [24_create_fact_macro_quarterly.sql](../sql/24_create_fact_macro_quarterly.sql) | mart.fact_macro_quarterly | 6 fields; 53 rows; 17 integrity PASS rows and 2 zero-difference comparisons |
| 7 | [25_validate_analysis_model.sql](../sql/25_validate_analysis_model.sql) | Combined model acceptance | Three read-only outputs: 6 inventory, 6 relationship and 2 combined-join PASS rows |

In scripts 20-24, sections 1-3 ensure the schema, create the table and insert its records. Sections 4-7 describe and validate the result. CREATE TABLE runs once and fails if the table exists; repeating INSERT is rejected by its primary key. If creation succeeded but insertion has not run, execute section 3 without recreating the table. Scripts 19 and 25, and sections 4-7 of scripts 20-24, are repeatable read-only diagnostics.

The four facts depend on audited staging inputs. The bank facts copy their selected records directly; their validation also reads both dimensions. The monthly macro fact uses distinct dates from the monthly bank fact, and the quarterly macro fact uses distinct dates from the quarterly bank fact. Both macro validations reference the date dimension. These construction dependencies do not define Power BI relationships.

## Coverage and intentional missing values

| Object | Confirmed history | Key or measure detail |
|---|---|---|
| core.dim_bank | Four banks: ANZ, CBA, NAB, WBC | Unique bank_code; bank ABN and source name retained |
| core.dim_date | 2013-01-01 to 2026-12-31 | Unique daily calendar_date; 168 month ends, 56 quarter ends, 3 leap days |
| mart.fact_bank_monthly | 2019-03-31 to 2026-07-31; 89 months per bank | Composite bank/date key; seven required amounts in AUD millions |
| mart.fact_bank_quarterly | 2013-03-31 to 2026-03-31; 53 quarters per bank | Composite bank/date key; two dates, four amounts, six ratios, framework label |
| mart.fact_macro_monthly | Same 89 dates as the monthly bank fact | Date key; three required monthly rates and three nullable CPI measures |
| mart.fact_macro_quarterly | Same 53 dates as the quarterly bank fact | Date key; three nullable guarded rate means and two required published CPI measures |

Read `actual_count` against `expected_count` rather than assuming every PASS count must be zero. The expected nonzero counts preserve source features:

- Quarterly bank LCR and NSFR each have 80 NULLs before 2018; MLH has 212 NULLs. The three liquidity columns allow NULL, while capital measures are required. The 2023 framework label records the source reporting break.
- Monthly macro CPI index, YoY and MoM have 61, 73 and 62 NULLs respectively across the 89-month window. MoM retains seven negatives and three zeros. Missing CPI does not remove a bank month.
- All quarterly macro measures are populated across the 53 required quarters. The three rate means nevertheless allow NULL when their monthly inputs are incomplete. Script 24 checks both input completeness and the stored values; correctly retained incomplete values can reconcile while completeness checks fail.
- The daily date dimension contains full years, including dates without bank observations. Its dates do not extend the bank facts' actual coverage.

Quarterly RBA rates are project-derived equal-weight means of three monthly averages, stored at six decimal places. Every quarter must have three rows, three distinct months and valid month-end labels; each rate additionally requires three non-NULL values. Quarterly CPI index and QoQ come from Table 17 without monthly interpolation or recalculation. Full staging histories remain intact.

## Acceptance and interpretation

Check each schema and overview, all PASS outputs, and both directions of every full-record comparison. Continue to script 25 only after the individual tables pass. The final six relationships must retain their fact row counts, with zero unmatched rows and invalid parent-key groups. Combined monthly and quarterly queries must retain 356 and 212 bank rows, with zero unmatched rows and duplicate bank-period groups.

The [analysis model plan](analysis_model_plan.md) explains reporting scope, grains, units and intended filter direction. The [integrated validation notes](model_validation.md) record the confirmed outputs and fault tests. Individual dictionaries and checks are documented for the [date dimension](date_dimension.md), [monthly bank fact](fact_bank_monthly.md), [quarterly bank fact](fact_bank_quarterly.md), [monthly macro fact](fact_macro_monthly.md) and [quarterly macro fact](fact_macro_quarterly.md).

MADIS monthly balances and ADI quarterly capital/liquidity observations have different consolidation scopes. ADI ratios use decimal fractions; RBA rates and CPI changes use per-cent values. Balances must not be summed across reporting dates, and ratios or repeated macro observations must not be summed across banks. The trial joins test matching and row counts; they do not establish economic causation or release-time data availability.

## Validation evidence and later refreshes

Project screenshots confirmed script 19's three outputs, the schema/overview/checks/comparisons of scripts 20-24, and script 25's three outputs. Final integrated acceptance was confirmed at 20:41:52, 20:42:11 and 20:42:29 on 2026-09-13. All seven project SQL files match their independently tested versions.

Independent in-memory tests rebuilt the relevant inputs from the original workbooks and exercised each model script. Separate calendar/workbook calculations matched the full date dimension, both bank facts and both macro facts, including 159 quarterly rate means. Temporary changes tested key duplication, missing references, shifted missing-value patterns, changed measures and incomplete quarterly rate inputs. The integrated test rebuilt all six model objects together and passed 6/6/2 checks; four temporary faults were detected and rolled back. See the individual notes for the exact scope of each test. Tests did not open the populated project database, alter workbooks or test a fresh extension download.

The tables are stored snapshots and do not refresh automatically. This procedure recreates them in an empty database. When adopting a new snapshot, review workbook ranges and headers, staging histories, expected counts and missing-value patterns, bank reporting windows, date-dimension coverage and the Table 18 metadata register. Updating the source files alone does not update facts or make existing pinned checks appropriate for the new period.
