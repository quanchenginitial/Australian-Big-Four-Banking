# Monthly bank fact

Step 6C, confirmed on 2026-09-13. The join preflight, shared date dimension and all four project result sets from [21_create_fact_bank_monthly.sql](../sql/21_create_fact_bank_monthly.sql) are confirmed.

## Grain and scope

`mart.fact_bank_monthly` stores **one bank at one month-end**. Its composite primary key is `(bank_code, report_date)`. It preserves all **356 observations: four banks over 89 months, 2019-03-31 through 2026-07-31**.

The source is the audited `stg.apra_big_four_monthly` table. The fact is a stored snapshot with nine fields: the two relationship keys and seven balances. Bank names and ABNs are available through `core.dim_bank`; calendar labels and sorting attributes come from `core.dim_date`. See the [analysis model plan](analysis_model_plan.md) for the planned quarterly and macro facts.

The insertion selects the nine fields directly from staging, without joins, filters, aggregation, deduplication, scaling or missing-value replacement. The raw and staging tables are preserved. Subsequent staging changes do not automatically refresh this stored fact; adopt a later source snapshot through a separate rebuild/refresh step with updated checks.

## Data dictionary

All nine fields are NOT NULL. The selected staging measures are complete in this pinned snapshot. Amounts keep their existing `DECIMAL(20,4)` precision and **million Australian dollar** units.

| Field | Type | Meaning |
|---|---|---|
| bank_code | VARCHAR, composite primary key | ANZ, CBA, NAB or WBC; lookup to `core.dim_bank.bank_code` |
| report_date | DATE, composite primary key | Month-end observation date; lookup to `core.dim_date.calendar_date` |
| assets_million | DECIMAL(20,4) | Total residents assets |
| loans_million | DECIMAL(20,4) | Total residents loans and finance leases |
| deposits_million | DECIMAL(20,4) | Total residents deposits |
| business_loans_million | DECIMAL(20,4) | Loans to non-financial businesses |
| owner_occupied_loans_million | DECIMAL(20,4) | Loans to households: Housing: Owner-occupied |
| investment_loans_million | DECIMAL(20,4) | Loans to households: Housing: Investment |
| household_deposits_million | DECIMAL(20,4) | Deposits by households |

These source measures describe the MADIS domestic, unconsolidated Australian-resident scope. They are not global consolidated group totals and are not directly interchangeable with the ADI quarterly capital/liquidity reporting scope. The business-loans field means non-financial-business loans specifically. Detailed source definitions remain in the existing [APRA staging notes](apra_staging.md).

Balances can be combined across banks at the same date within the common reporting scope. Adding monthly closing balances across time does not produce an annual balance or annual lending flow. Growth rates, shares and other report measures will be defined in a later step.

## Keys and dimension checks

The table declares a composite primary key and a CHECK requiring `report_date = LAST_DAY(report_date)`. Together they enforce at most one row per bank/month. NOT NULL constraints prevent absent keys and amounts. The four bank codes and the fixed history are verified by the validation queries.

No database foreign-key constraints are declared. The existing `core.dim_bank` was created without a declared primary key. Section 6 explicitly checks dimensional matches, bank-key uniqueness, bank metadata and the row count after both lookups. These query checks are distinct from database constraints and the Power BI relationships that will be configured later. A future dimension edit requires rerunning the checks.

For the later model, `core.dim_bank` will filter the bank fact through `bank_code`, and `core.dim_date` through `calendar_date` to `report_date`. Month-end attributes in the daily dimension repeat and are not its unique relationship key. Macro observations will have their own facts sharing the date dimension.

## Execution and expected outputs

Run the seven numbered sections in DBeaver against the existing project connection. Prerequisites are `stg.apra_big_four_monthly`, `core.dim_bank`, and the confirmed [date dimension](date_dimension.md).

| Section | Operation | Expected result |
|---|---|---|
| 1 | Create the `mart` schema if needed | Statement succeeds |
| 2 | Define the fact and constraints | Statement succeeds |
| 3 | Insert all audited keys and amounts | 356 rows inserted |
| 4 | Describe the fact | Nine fields; all null flags NO; first two key flags PRI |
| 5 | Summarize the fact | 356 rows, four banks, 89 months; 2019-03-31 to 2026-07-31 |
| 6 | Validate grain, lookups and source patterns | 14 PASS rows, all issue counts zero |
| 7 | Reconcile all nine fields with staging | Two PASS rows, both difference counts zero |

Run sections 2 and 3 once. Creation fails when the table already exists; repeating the insertion is rejected by the primary key. If only creation succeeded, proceed to section 3 without repeating section 2. Sections 4-7 are read-only and repeatable. Select a complete numbered SQL statement through its semicolon, including all CTEs in sections 6 and 7.

## Validation definitions

Every section 6 check has expected count zero:

| Check | What it detects |
|---|---|
| row_count_difference | Absolute difference from 356 fact rows |
| bank_count_difference | Absolute difference from four distinct bank codes |
| duplicate_bank_month_keys | Repeated bank/month groups |
| bank_calendar_mismatches | Banks without 89 rows, 89 dates or the expected endpoints |
| missing_required_values_rows | Missing/blank bank code, missing date or missing amount |
| non_month_end_rows | Observation dates that are not month ends |
| unmatched_bank_rows | Fact rows without a bank dimension match |
| unmatched_date_rows | Fact rows without a daily date dimension match |
| duplicate_bank_dimension_keys | Repeated bank codes in the bank dimension |
| bank_dimension_row_difference | Absolute difference from four bank dimension rows |
| invalid_bank_dimension_rows | Missing/blank bank code, ABN or bank name in the dimension |
| lookup_join_row_difference | Row-count change after both dimension lookups |
| bank_attribute_mismatch_rows | Staging ABN/name inconsistent with its bank dimension entry |
| nonpositive_amount_rows | Fact rows containing any amount at or below zero |

Positive amounts are a validated feature of this source selection, not a universal rule for future data and not a reason to fill missing values. No positivity constraint or imputation is added to the table.

Section 7 compares all nine retained fields using `EXCEPT ALL` in both directions. `staging_minus_fact_rows` and `fact_minus_staging_rows` must both be zero. This checks exact values and multiplicity; equal row counts or totals alone would not show whether individual records had changed.

## Independent validation and project status

The exact script ran in a fresh in-memory DuckDB v1.5.5 database, using the existing APRA setup/staging scripts and the creation portion of script 20. All nine field definitions, the summary, all 14 integrity checks and both full-record comparisons passed.

A separate workbook reader matched **all 356 records across all nine fields**, including **2,492 amounts at four decimal places**, directly to the pinned MADIS workbook. Five temporary scenarios verified detection of a missing bank entry, a duplicated bank entry, a missing date, an altered positive amount and an inconsistent bank name. Changing an amount by 0.0001 left the aggregate checks passing but produced one difference in each reconciliation direction. This demonstrates why both kinds of checks are needed.

Four separate constraint checks confirmed rejection of duplicate fact keys, a NULL bank code, a NULL required amount and a non-month-end date. Source workbook hashes remained unchanged. Tests used the installed Excel extension and did not open the populated project database.

## Confirmed project execution

Four DBeaver screenshots on 2026-09-13 confirmed all expected results: nine fields with NOT NULL flags and the composite primary key at 17:15:19; 356 rows, four banks and 89 months at 17:15:52; all 14 integrity checks passing with zero issues at 17:16:08; and both staging comparisons passing with zero differences at 17:16:20. The project script matches the independently tested version.

The [quarterly bank fact](fact_bank_quarterly.md), [monthly macro fact](fact_macro_monthly.md) and [quarterly macro fact](fact_macro_quarterly.md) are also confirmed. The monthly macro fact uses the 89 distinct monthly banking dates as its analysis calendar. All six model tables have passed [integrated model validation](model_validation.md); see [model rebuild](rebuild_analysis_model.md) for the complete execution order.
