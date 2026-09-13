# Shared date dimension

Step 6B, confirmed on 2026-09-13. The three project join-preflight outputs from script 19 and all four project result sets from [20_create_date_dimension.sql](../sql/20_create_date_dimension.sql) are confirmed.

## Purpose and scope

`core.dim_date` stores one row per calendar day. Its initial range is **2013-01-01 through 2026-12-31**, inclusive: **5,113 days, 14 years, 168 months and 56 quarters**. It supplies common year, quarter and month filters to the planned banking and macro facts in the [analysis model plan](analysis_model_plan.md).

The range covers complete calendar years around the initial bank analysis windows. It includes weekends, holidays and the leap days in 2016, 2020 and 2024. These are date labels, not new banking or macro observations. Days after the latest source observation complete the calendar year; they do not imply forecasts or additional published data.

Microsoft's [date-table guidance](https://learn.microsoft.com/en-us/power-bi/guidance/model-date-tables) describes a date column with unique, nonblank, consecutive dates covering full years. This table is prepared in DuckDB for later use as the common Power BI date source. Power BI relationship and date-table configuration will be performed separately.

The full RBA and CPI staging histories remain unchanged. The initial model's macro facts will use bank-driven periods within this calendar. This table does not cover the earlier 1948 CPI or 1969 RBA history; extend it before exposing those histories in a report. Calendar quarters are January-March, April-June, July-September and October-December, not each bank's financial-year quarters.

## Key, attributes and types

The table is created with explicit types. `calendar_date` is its primary key; all other fields are NOT NULL. [DuckDB's table-definition syntax](https://duckdb.org/docs/current/sql/statements/create_table) supports these constraints. Repeated date keys and NULL keys are rejected by the database.

| Column | Type | Meaning / example |
|---|---|---|
| calendar_date | DATE, primary key | Unique daily relationship key, such as 2026-03-31 |
| calendar_year | SMALLINT | Calendar year, such as 2026 |
| quarter_number | TINYINT | Calendar quarter number, 1-4 |
| month_number | TINYINT | Month number, 1-12 |
| month_name | VARCHAR | English full month name, such as March |
| year_quarter | VARCHAR | Quarter label, such as `2026 Q1` |
| year_quarter_sort | INTEGER | Chronological quarter key, such as 20261 |
| year_month | VARCHAR | Month label, such as `2026-03` |
| year_month_sort | INTEGER | Chronological month key, such as 202603 |
| month_end_date | DATE | Last date of this day's month |
| quarter_end_date | DATE | Last date of this day's calendar quarter |
| is_month_end | BOOLEAN | Whether this daily row is the month's last day |
| is_quarter_end | BOOLEAN | Whether this daily row is the quarter's last day |

For example:

| calendar_date | year_month | year_quarter | is_month_end | is_quarter_end |
|---|---|---|---|---|
| 2024-02-28 | 2024-02 | 2024 Q1 | false | false |
| 2024-02-29 | 2024-02 | 2024 Q1 | true | false |
| 2024-03-31 | 2024-03 | 2024 Q1 | true | true |

Use `calendar_date` as the unique date-side relationship key to each fact's `report_date`. `month_end_date` and `quarter_end_date` repeat across multiple daily rows and are descriptive attributes, not unique relationship keys. Joining a monthly bank row to every daily row sharing its `month_end_date` would multiply that bank observation.

During report setup, sort `month_name` by `month_number`, `year_month` by `year_month_sort`, and `year_quarter` by `year_quarter_sort`. Use the combined year/month or year/quarter labels when displaying periods across multiple years. The year, quarter and month fields support filtering; the banking facts retain their original monthly or quarterly grains.

## Build and execution order

The date generator itself needs no source workbook or staging input. It uses a fixed inclusive daily series, explicitly casting timestamps to DATE. Only the final coverage query needs `stg.apra_big_four_monthly` and `stg.apra_big_four_quarterly`.

Run the seven complete numbered statements in order on the existing project connection:

| Section | Action | Expected result |
|---|---|---|
| 1 | Ensure the core schema exists | Statement succeeds |
| 2 | Define the constrained date table | Statement succeeds |
| 3 | Populate all daily rows | Statement succeeds |
| 4 | Describe fields and constraints | 13 fields; all null flags NO; calendar_date has key PRI |
| 5 | Summarise the calendar | 5,113 days, 2013-01-01 to 2026-12-31, 14 years, 168 months, 56 quarters |
| 6 | Check calendar integrity | 13 PASS rows |
| 7 | Check required model dates | 5 PASS rows; no unmatched dates or wrong period flags |

Run sections 2 and 3 once. Creation fails if the table exists, and repeating the population step fails on duplicate primary keys. Sections 4-7 are read-only and repeatable. If table creation succeeded but population did not run, the empty table can be populated by section 3 without creating it again. The script does not replace any existing table or create the planned facts.

## Calendar and coverage checks

Section 6 checks the row count, uniqueness, continuous daily span, exact endpoints, numeric calendar attributes, labels, sort keys, period-end dates/flags and missing attributes. Those issue counts must be zero. It also confirms **168 month-end rows, 56 quarter-end rows and 3 leap-day rows**. Nonzero counts here are expected features of the calendar.

Section 7 uses the existing banking dates and the proposed macro date keys:

| Scope | Required rows | Matched rows | Unmatched rows | Wrong period flags |
|---|---:|---:|---:|---:|
| bank_monthly | 356 | 356 | 0 | 0 |
| bank_quarterly | 212 | 212 | 0 | 0 |
| macro_monthly | 89 | 89 | 0 | 0 |
| macro_quarterly | 53 | 53 | 0 | 0 |
| quarterly_rate_inputs | 159 | 159 | 0 | 0 |

The two macro scopes contain distinct banking periods. The final scope expands the 53 ADI quarters into their three required month-end labels. These are checks of date-key coverage; they do not create macro facts or establish the existence of a CPI value. Script 19 separately confirmed available values and the expected monthly CPI NULLs.

The calendar's 168 months and 56 quarters cover full years. They therefore exceed the initial model's 89 monthly periods and 53 quarterly periods. Match actual observations to the calendar and keep absent observations absent. A later source refresh that extends beyond 2026 requires a deliberate calendar extension and updated validation expectations.

## Independent validation

The exact script ran successfully in a new in-memory DuckDB v1.5.5 database after the two APRA staging tables were rebuilt from their existing SQL scripts and pinned workbooks. All 13 column types and NOT NULL flags matched, and the primary key was present. The overview, 13 calendar checks and 5 coverage rows matched expectations.

Python's independent Gregorian calendar calculations matched **all 5,113 complete records across all 13 fields**, including every sort key, month/quarter end and flag. The three leap days were 2016-02-29, 2020-02-29 and 2024-02-29.

Four temporary changes verified detection of a missing bank quarter-end date, a missing first calendar day, incorrect labels/sort keys and an incorrect quarter-end flag. Separate constraint checks confirmed that duplicate and NULL date keys are rejected. Each data change was confined to an in-memory test database.

The source workbooks remained unchanged and the populated project database was not opened during independent testing. The installed Excel extension was used only to rebuild the APRA test inputs; the date generator requires no Excel extension.

## Confirmed project execution

Four DBeaver screenshots on 2026-09-13 confirmed the project results: 13 correctly typed, required fields and the date primary key at 16:58:53; the 5,113-day overview at 16:59:08; all 13 calendar checks passing at 16:59:31; and all five date-coverage checks passing at 16:59:44. Required and matched counts were 356, 212, 89, 53 and 159, with zero unmatched dates or wrong period flags. The project SQL file matches the independently tested version.

Both the [monthly bank fact](fact_bank_monthly.md) and [quarterly bank fact](fact_bank_quarterly.md) are confirmed, with their reporting dates checked against `calendar_date`. The [monthly macro fact](fact_macro_monthly.md) and [quarterly macro fact](fact_macro_quarterly.md) are also confirmed for their 89 months and 53 quarters against the same daily key. All six tables have passed [integrated model validation](model_validation.md); see [model rebuild](rebuild_analysis_model.md) for the complete execution order.
