# ABS Table 18 quarterly CPI detail staging

Prepared and independently validated on 2026-09-13. Both raw imports, all five project audit outputs and all four staging validation outputs are confirmed through DBeaver.

## Purpose and grain

[18_create_abs_cpi_quarterly_detail_staging.sql](../sql/18_create_abs_cpi_quarterly_detail_staging.sql) creates `stg.abs_cpi_australia_quarterly_detail`. It preserves all **396 Series IDs × 312 quarters = 123,552 rows**, including unavailable observations. The logical key is `(series_id, report_date)`.

Each row contains one source measure for one expenditure category in one quarter. The three measure families each contain 132 series. The table covers the weighted average of eight capital cities, labelled Australia in the source metadata. All series are Original. It has no bank key and does not replicate the CPI observations across banks.

There are 124 distinct category display names in this snapshot; some names belong to multiple IDs within the same measure family. All 396 IDs remain separate. This step does not assign hierarchy levels, deduplicate names, pair measures into category records, or select a reporting subset.

## Dependencies and source register

Run only after all five statements in [17_audit_abs_cpi_quarterly_detail.sql](../sql/17_audit_abs_cpi_quarterly_detail.sql) have returned the reviewed results. Creation requires `raw.abs_cpi_table18_data1_quarterly` and `raw.abs_cpi_table18_data2_quarterly`. It does not read the workbook or require the APRA/Table 17 tables again.

The creation statement embeds a fixed register of all 396 Series IDs from `06_ABS_CPI_Table18_Quarterly_Detail_Jul2026.xlsx`. Each entry records its source sheet, category name, metric and unit. `category_name` is the trimmed middle component of the workbook description, whose structure is `measure ; category ; Australia ;`. Units are copied from the source metadata. The original workbook retains the full descriptions; the raw tables preserve the Series IDs as column names.

The register joins by exact Series ID and source sheet. It does not infer metadata from raw column positions. A left join retains unknown raw series so missing metadata becomes visible in the checks. Review the register and expected counts against the source metadata before using another snapshot; an unfamiliar series must not be assigned a category by guessing its name or position.

## Column definitions

| Column | Type | Meaning |
|---|---|---|
| report_date | DATE | Quarter-end label for the source observation period |
| series_id | VARCHAR | Original ABS Series ID; part of the logical key |
| category_name | VARCHAR | Trimmed source expenditure-category label; not a unique key |
| metric | VARCHAR | `cpi_index`, `cpi_qoq_pct` or `cpi_contribution_index_points` |
| unit | VARCHAR | Source unit: Index Numbers, Percent or Index Points |
| source_sheet | VARCHAR | Data1 or Data2, retained for traceability |
| metric_value | DECIMAL(18,6) | Typed published value, or NULL when unavailable |

`CREATE TABLE AS SELECT` does not add primary-key or NOT NULL constraints. The validation statements check the logical key and required metadata. The creation statement intentionally fails if the target table already exists, rather than replacing it.

## Transformations and interpretation

Both raw sheets are unpivoted with `INCLUDE NULLS`, retaining every measure cell. `UNION ALL` combines their different series over the same 312-quarter calendar. Blank or whitespace-only numeric text becomes NULL; strict decimal conversion rejects nonblank invalid numeric text. No observations are filtered, filled, deduplicated or recalculated.

Audited source dates use day 1 of the quarter's last month: March, June, September or December. The Excel 1900 serial is decoded and `LAST_DAY` sets the quarter-end label. For example, 2026-06-01 becomes 2026-06-30, still representing 2026Q2. `report_date` is neither a publication date nor a claim that quarterly CPI was measured only on that day.

| Metric | Unit | Interpretation |
|---|---|---|
| cpi_index | Index Numbers | Published index; reference September **month** 2025 = 100.00 |
| cpi_qoq_pct | Percent | Published change from the previous quarter; 0.6 means 0.6% |
| cpi_contribution_index_points | Index Points | Published contribution to Total CPI in index points |

September **quarter** 2025 All groups CPI remains 99.73. The source contains no published YoY family. Contributions are not inflation rates, percentage weights or percentage-point contributions to inflation growth. The [source review](abs_cpi_quarterly_detail_source_review.md) records the official reference-period explanation and the pinned source details.

Use `metric_value` with a selected metric and its unit. Do not sum across different units, across dates as if indexes were flows, or across overlapping groups, subgroups and expenditure classes. Reporting selections and hierarchy relationships require a separate modelling decision.

The All groups index and QoQ share the same Series IDs and observations as the selected Table 17 measures; the raw audit confirmed their agreement across all 312 quarters. They are alternative representations of the same headline data, not additional independent observations to aggregate together.

## Execution and expected results

Execute the six numbered sections in order. Select the entire statement in section 2, including all 396 register rows and the final SELECT, through its terminating semicolon. Run creation once. Sections 3-6 are read-only and repeatable.

| Section | Action | Expected result |
|---|---|---|
| 1 | Ensure the staging schema exists | Statement succeeds |
| 2 | Create the complete typed detail table | Statement succeeds |
| 3 | Describe the schema | Seven columns with the types listed above |
| 4 | Summarise retained history | 123,552 rows; 396 series; 312 quarters; 1948-09-30 to 2026-06-30 |
| 5 | Validate keys, metadata, calendars and source patterns | Fifteen PASS rows |
| 6 | Compare typed raw observations with staging in both directions | Two PASS rows, each difference 0 |

Section 5 checks total rows and distinct IDs, duplicate series-quarter keys, missing keys/metadata, metric-unit-sheet combinations, quarter ends and complete 312-quarter calendars for every series. These issue counts must be zero. It also checks the following retained source patterns:

| Check | Expected count |
|---|---:|
| cpi_index_missing | 18,371 |
| cpi_qoq_missing | 18,503 |
| cpi_contribution_missing | 40,788 |
| nonpositive_index_values | 0 |
| negative_contribution_values | 0 |
| cpi_qoq_negative | 5,537 |
| cpi_qoq_zero | 1,280 |

Nonzero expected counts are intentional. Earlier unavailable periods, published negative changes and zeros remain in the table. These counts describe the pinned snapshot and must be reviewed when refreshing it.

Section 6 compares every `(report_date, series_id, source_sheet, metric_value)` using `EXCEPT ALL` in both directions. Corresponding NULL values compare equally, while duplicate multiplicity is retained. Both `raw_minus_staging_rows` and `staging_minus_raw_rows` must be zero. This verifies transformation fidelity; it does not independently establish the accuracy of the ABS data or replace the source metadata audit. Category/metric/unit mappings were separately compared with the workbook during preparation.

## Coverage and missing observations

The complete table contains **45,890 numeric values and 77,662 NULLs**. Each measure family has 41,184 rows. Index and QoQ histories start at different dates across categories, as documented and checked in the raw audit.

All 132 contribution series have exactly three numeric observations, in 2025Q4, 2026Q1 and 2026Q2. Earlier contribution cells remain NULL. Within the confirmed ADI period, 2013Q1-2026Q1, each family has 6,996 required series-quarter cells. Index and QoQ each provide all 6,996 numeric values. Contributions provide 264, with 6,732 unavailable; the June 2026 quarter lies outside that ADI period.

## Independent validation

The exact import and staging scripts ran in a new in-memory DuckDB v1.5.5 database with the installed Excel extension. The seven-column schema, overview, fifteen validation rows and two reconciliation rows all matched expectations.

A fresh read-only openpyxl read independently reconstructed every expected record from the original workbook. All **123,552 records** matched on Series ID, quarter-end date, category, metric, unit, source sheet and value. All 45,890 numeric values matched at six decimal places; all 77,662 NULLs were retained. The 396 source metadata records matched, including the 24 additional IDs sharing category-and-metric labels. Coverage within the confirmed ADI period also matched the counts above.

Four temporary changes verified that the checks detect a changed positive value despite unchanged aggregate patterns, a duplicated NULL observation, a relocated contribution NULL with unchanged totals, and missing metric metadata. Each change was rolled back inside the test database.

The source workbook hash remained unchanged. These independent tests did not open the populated project database or test a fresh extension download.

## Confirmed project results

Four DBeaver screenshots on 2026-09-13 confirmed the actual project execution:

| Output | Confirmed result | Screenshot time |
|---|---|---|
| Schema | Seven fields: one DATE, five VARCHAR and one DECIMAL(18,6) | 02:30:35 |
| Calendar and series | 123,552 rows, 396 IDs, 312 quarters, 1948-09-30 to 2026-06-30 | 02:30:52 |
| Staging checks | All fifteen PASS, including the retained NULL, negative and zero counts | 02:31:12 |
| Complete raw comparison | Both directions PASS; zero differences | 02:31:29 |

The project SQL file matches the independently tested script, SHA256 `6d5a4d20be3f3fdf6f9033ce0b9cb8a7c9c7daf62b00df526c17009e49274791`. These results complete the Table 18 import, audit and typed-staging module. The table remains a stored snapshot; automatic refresh and analytical modelling are subsequent work.
