# Integrated analysis-model validation

Step 6G, independently validated and confirmed in the project on 2026-09-13. All four facts and the daily date dimension have passed their individual project checks. The three integrated outputs from [25_validate_analysis_model.sql](../sql/25_validate_analysis_model.sql) also passed.

The script reads the six model tables together. It checks their current row counts and logical keys, all six intended dimension relationships, and combined bank/date/macro joins at each frequency. It creates no objects and changes no data. Run its three complete numbered statements separately on the existing DBeaver project connection; each statement can be repeated.

## 1. Table inventory and keys

| Table | Logical key | Expected rows and unique keys |
|---|---|---:|
| core.dim_bank | bank_code | 4 |
| core.dim_date | calendar_date | 5,113 |
| mart.fact_bank_monthly | bank_code, report_date | 356 |
| mart.fact_bank_quarterly | bank_code, report_date | 212 |
| mart.fact_macro_monthly | report_date | 89 |
| mart.fact_macro_quarterly | report_date | 53 |

Expect six PASS rows. Each `row_count` and `unique_keys` must equal `expected_rows`, with `null_key_rows` zero. A bank fact's composite key permits different banks to share a date; macro facts have one row per date. Missing tables produce a query error and must be resolved before acceptance.

## 2. Dimension relationships

| Relationship shown | Parent key | Fact key | Expected fact and joined rows |
|---|---|---|---:|
| bank -> bank_monthly | core.dim_bank.bank_code | mart.fact_bank_monthly.bank_code | 356 |
| bank -> bank_quarterly | core.dim_bank.bank_code | mart.fact_bank_quarterly.bank_code | 212 |
| date -> bank_monthly | core.dim_date.calendar_date | mart.fact_bank_monthly.report_date | 356 |
| date -> bank_quarterly | core.dim_date.calendar_date | mart.fact_bank_quarterly.report_date | 212 |
| date -> macro_monthly | core.dim_date.calendar_date | mart.fact_macro_monthly.report_date | 89 |
| date -> macro_quarterly | core.dim_date.calendar_date | mart.fact_macro_quarterly.report_date | 53 |

Expect six PASS rows, with `fact_rows = joined_rows` at the pinned counts and `unmatched_rows = bad_parent_keys = 0`. LEFT JOINs retain missing references so they remain visible in the issue counts. Repeated parent keys increase joined rows when referenced. `bad_parent_keys` also checks the entire dimension for NULL or duplicate key groups, including unused keys that would not increase today's join counts. The existing bank dimension has no declared primary key, so this explicit check matters.

These SQL queries validate data for the intended relationships; they neither declare database foreign keys nor configure Power BI relationships. The planned model uses the date dimension to filter all four facts and the bank dimension to filter the two bank facts. See the [analysis model plan](analysis_model_plan.md).

## 3. Combined trial joins

Each bank fact is LEFT JOINed to the bank dimension, daily date dimension and macro fact of the same frequency in one query. Expect two PASS rows:

| scope_name | bank_rows | joined_rows | unmatched_rows | duplicate_joined_keys |
|---|---:|---:|---:|---:|
| monthly | 356 | 356 | 0 | 0 |
| quarterly | 212 | 212 | 0 | 0 |

`unmatched_rows` counts joined rows missing any bank, date or macro match. `duplicate_joined_keys` counts bank-period groups appearing more than once after all three joins. A matched monthly macro row with an unavailable CPI value is still a valid match; NULL measures are not missing date keys.

The direct bank/macro join is a SQL diagnostic only. It repeats shared macro observations across the four banks, so its macro values must not be summed. Power BI will relate the facts independently through the date dimension; this test does not propose a direct fact-to-fact relationship or a combined exported fact table.

## Acceptance scope

Read all three outputs together: **6 + 6 + 2 PASS rows** are required. These checks supplement the earlier schema, calendar, source-completeness, missing-value-pattern and full-record reconciliations in scripts 19-24. They do not repeat those value audits, prove economic conclusions, or validate a Power BI model that has not yet been configured. Review the pinned counts when adopting another source snapshot. Table 18 expenditure detail remains a later reporting extension outside these six core objects.

## Independent validation and project status

The exact script passed in a fresh in-memory DuckDB v1.5.5 database after rebuilding the five relevant source/staging inputs and the creation/insertion sections of scripts 20-24. Its three result sets contained six, six and two PASS rows with the expected counts.

Four temporary scenarios exercised failures:

| Temporary change | Observed result |
|---|---|
| Duplicate the CBA dimension record | Bank inventory fails; bank relationship and combined joins expand to 445 monthly and 265 quarterly rows, with 89/53 duplicate bank-period groups |
| Remove dimension date 2026-03-31 | Date inventory fails; four date relationships expose 4/4/1/1 unmatched fact rows; both combined joins retain their row counts and expose four unmatched rows |
| Remove the monthly macro row for 2020-02-29 | Macro inventory and its pinned relationship count fail; monthly combined join retains 356 rows and exposes four unmatched rows; quarterly output is unchanged |
| Add an unused duplicate bank key | Inventory and bank parent-key checks fail although current joined row counts and both combined outputs remain unchanged |

All changes were rolled back and the original three result sets were restored. Source workbook hashes were unchanged. The populated project database was not opened during independent tests.

## Confirmed project execution

Three DBeaver screenshots on 2026-09-13 confirmed all expected results: the six-table inventory at 20:41:52, the six dimension relationships at 20:42:11, and both combined trial joins at 20:42:29. All 14 statuses were PASS. Inventory counts and unique-key counts were 4/5113/356/212/89/53, with no NULL keys. All six relationships preserved their fact row counts with no unmatched rows or bad parent keys. Combined queries retained 356 monthly and 212 quarterly bank rows, with no unmatched rows or duplicate bank-period groups. The project script matches the independently tested version.

The SQL analysis model is now confirmed. The [model rebuild guide](rebuild_analysis_model.md) records the complete execution order and expected results. Power BI import, relationship configuration, measures and report validation remain subsequent work.
