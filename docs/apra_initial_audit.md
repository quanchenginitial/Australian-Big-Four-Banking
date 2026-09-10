# Initial APRA MADIS data audit

Audit date: 2026-09-10. Environment: DuckDB v1.5.5, queried through DBeaver.

The initial checks passed for the imported APRA table's dates and the seven selected financial measures for the four mapped banks. This checkpoint records technical validation before building the cleaned analytical tables.

## Source and statistical scope

- Local source: `data/raw/01_APRA_MADIS_Backseries_Mar2019_Jul2026.xlsx`.
- `Table 1`: headers in A2:AD2; 11,122 data rows in rows 3:11124.
- Units: **millions of Australian dollars**, confirmed by `Table 1!A1` and `Notes !A17`. Foreign-currency amounts are included at their Australian-dollar equivalent.
- Dates: the workbook uses the Excel 1900 date system. For this snapshot, serial `46234` corresponds to `2026-07-31`.
- Statistical scope: the relevant ADIs' unconsolidated Australian domestic books, as described in `Explanatory notes !A5` and `A11`. The selected assets, total loans and total deposits fields refer to **residents**; they must not be presented as global consolidated banking-group balances.

The sheet names `Notes ` and `Explanatory notes ` have a trailing space. The source workbook is stored locally and excluded from Git.

## How to run the checks

Open [01_audit_existing_tables.sql](../sql/01_audit_existing_tables.sql) in DBeaver and execute its statements using the project's DuckDB connection. The script requires the existing `raw.apra_madis` and `core.dim_bank` tables. It performs read-only queries and does not create or alter tables.

The results below were observed in the project database. The source workbook was also inspected read-only: its row count, date coverage and the first five institution/ABN/loan/deposit samples agreed with the database results. This is not a full cell-by-cell reconciliation.

## Table structure and record counts

| Check | Observed result |
|---|---|
| Raw table | `raw.apra_madis` |
| Raw rows | 11,122 |
| Raw columns | 30, all `VARCHAR` |
| Bank mapping | 4 rows in `core.dim_bank` |
| Records matched to the four banks using trimmed ABNs | 356 |
| Duplicate raw `(ABN, Period)` groups across all institutions | 0 |

The schema permits NULL values; that schema setting alone does not measure actual missing data. Missing amounts are checked separately below. Duplicate checks at this stage use the original stored key values.

## Bank mapping and monthly coverage

| Bank | ABN | Matched rows | Distinct months | First date | Last date | Missing months |
|---|---|---:|---:|---|---|---:|
| ANZ | 11005357522 | 89 | 89 | 2019-03-31 | 2026-07-31 | 0 |
| CBA | 48123123124 | 89 | 89 | 2019-03-31 | 2026-07-31 | 0 |
| NAB | 12004044937 | 89 | 89 | 2019-03-31 | 2026-07-31 | 0 |
| WBC | 33007457141 | 89 | 89 | 2019-03-31 | 2026-07-31 | 0 |

The existing mapping identifies Australia and New Zealand Banking Group Limited, Commonwealth Bank of Australia, National Australia Bank Limited, and Westpac Banking Corporation respectively.

For this four-bank selection, the observed grain is one bank per month, giving 4 x 89 = 356 records. The gap calculation checks each bank's observed date span; both endpoints were also compared with the source snapshot.

Across all 11,122 raw rows:

| Date check | Count |
|---|---:|
| Missing or unparseable report dates | 0 |
| Dates not falling on the final day of a month | 0 |

Date conversion tested: `DATE '1899-12-30' + TRY_CAST(TRIM("Period") AS INTEGER)`.

## Selected financial measures

All seven measures retain the source unit of **AUD million**.

| SQL metric | Exact APRA source column |
|---|---|
| `assets` | Total residents assets |
| `loans` | Total residents loans and finance leases |
| `deposits` | Total residents deposits |
| `business_loans` | Loans to non-financial businesses |
| `owner_occupied_loans` | Loans to households: Housing: Owner-occupied |
| `investment_loans` | Loans to households: Housing: Investment |
| `household_deposits` | Deposits by households |

Whitespace-only strings and NULLs are treated as missing for the audit. Nonblank values are tested with `TRY_CAST(... AS DECIMAL(20, 4))`.

| Metric | Values checked | Missing | Conversion failures | Negative | Zero |
|---|---:|---:|---:|---:|---:|
| assets | 356 | 0 | 0 | 0 | 0 |
| business_loans | 356 | 0 | 0 | 0 | 0 |
| deposits | 356 | 0 | 0 | 0 | 0 |
| household_deposits | 356 | 0 | 0 | 0 | 0 |
| investment_loans | 356 | 0 | 0 | 0 | 0 |
| loans | 356 | 0 | 0 | 0 | 0 |
| owner_occupied_loans | 356 | 0 | 0 | 0 | 0 |

In total, 2,492 selected measure values were checked. Zero and negative counts are diagnostic flags, not automatic rules for deleting or replacing data. No source values were changed by these queries.

## Boundaries and next steps

This audit covers the dates in the imported APRA MADIS table and the seven selected amounts for the four mapped banks. It does not validate every financial field, other institutions' amounts, the remaining five workbooks, or the economic meaning of future analysis.

Next steps:

1. Build a typed staging table, keeping ABNs as text, report dates as `DATE`, and financial measures in AUD million. Check the resulting bank/month keys and retained row counts.
2. Capture source-loading and bank-mapping creation scripts so the database can be rebuilt from the local source files. The current audit script alone does not rebuild it.
3. Validate and integrate the other APRA, RBA and ABS sources, documenting frequency and scope differences.
4. Develop analytical SQL, the Power BI model and report, and the final portfolio findings.
