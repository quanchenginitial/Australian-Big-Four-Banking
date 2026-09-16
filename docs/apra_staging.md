# APRA Big Four monthly staging table

Verified in the project database through DBeaver on 2026-09-10, using DuckDB v1.5.5.

## Purpose and inputs

`stg.apra_big_four_monthly` contains the four mapped banks' monthly records with explicit date and financial data types. It is an intermediate table for subsequent analytical modelling.

- Source table: `raw.apra_madis`.
- Bank mapping: `core.dim_bank`.
- Source snapshot: `01_APRA_MADIS_Backseries_Mar2019_Jul2026.xlsx`.
- Prerequisite checks and source references: [initial APRA audit](apra_initial_audit.md).
- Creation and validation script: [02_create_apra_big_four_staging.sql](../sql/02_create_apra_big_four_staging.sql).

The script creates a persistent derived table. It leaves the raw table unchanged. The intended grain is **one mapped bank per report month**.

## Transformation rules

1. Join the raw records to the bank mapping using `TRIM(raw.ABN) = TRIM(dim_bank.bank_abn)`. The inner join selects the four mapped banks.
2. Retain the mapped bank code and name; trim the mapped ABN and keep it as text.
3. Convert the source's Excel date serial with `DATE '1899-12-30' + CAST(TRIM("Period") AS INTEGER)`. This rule was verified for the audited snapshot's 1900-system dates.
4. Trim the seven selected amount fields and cast them to `DECIMAL(20,4)`. The `_million` suffix records the source unit, **millions of Australian dollars**; no scaling is applied.
5. Preserve source NULLs. Invalid nonnumeric amount text causes a conversion error; missing keys and amounts are checked after creation. No values are filled with zero, and no aggregation or deduplication is applied.

The selected residents' assets, loans and deposits use the relevant ADIs' unconsolidated Australian domestic-book scope. They are not global consolidated group totals. `business_loans_million` specifically represents loans to non-financial businesses.

## Data dictionary

| Column | Type | Source or meaning |
|---|---|---|
| `bank_code` | `VARCHAR` | Code from `core.dim_bank`: ANZ, CBA, NAB or WBC |
| `bank_abn` | `VARCHAR` | Trimmed ABN from `core.dim_bank`; institution identifier |
| `bank_name` | `VARCHAR` | Name from `core.dim_bank` |
| `report_date` | `DATE` | Month-end reporting date converted from raw `Period` |
| `assets_million` | `DECIMAL(20,4)` | Total residents assets |
| `loans_million` | `DECIMAL(20,4)` | Total residents loans and finance leases |
| `deposits_million` | `DECIMAL(20,4)` | Total residents deposits |
| `business_loans_million` | `DECIMAL(20,4)` | Loans to non-financial businesses |
| `owner_occupied_loans_million` | `DECIMAL(20,4)` | Loans to households: Housing: Owner-occupied |
| `investment_loans_million` | `DECIMAL(20,4)` | Loans to households: Housing: Investment |
| `household_deposits_million` | `DECIMAL(20,4)` | Deposits by households |

The financial columns hold period-end balances. Future reports should explicitly select the reporting period when presenting balances, rather than adding monthly balances across time.

## Observed validation results

The project's DBeaver results confirmed successful creation and the following checks:

| Check | Result |
|---|---|
| Columns | 11: three `VARCHAR`, one `DATE`, seven `DECIMAL(20,4)` |
| Rows | 356 |
| Distinct banks | 4 |
| Distinct report dates | 89 |
| First report date | 2019-03-31 |
| Last report date | 2026-07-31 |
| Duplicate `(bank_code, report_date)` groups | 0 |
| Rows with a missing or blank bank code/ABN, or a missing report date | 0 |
| Rows with at least one missing selected amount | 0 |

The bank/month key is unique in the observed data; a primary-key constraint has not been declared. The table schema permits NULLs. This schema property is distinct from the actual missing-value counts above. The missing-amount check counts affected rows, not individual missing cells.

Before execution in the project database, the same creation script was also tested in an independent in-memory DuckDB database using an extraction of the source workbook. That test confirmed 89 records per bank, compared all 2,492 generated amount values with the corresponding source-extraction fields, and verified that malformed amount text was rejected. This independent test is supplementary evidence, not a full reconciliation of every field in the project's raw table.

A later [source-rebuild comparison](rebuild_apra.md), confirmed on 2026-09-11, matched all 11,122 raw rows across 30 columns and all four bank mappings against the existing project inputs. The setup, audit and staging scripts were also tested together in a separate database reading directly from the source Excel workbook.

## Execution and remaining work

- Run the creation section once after preparing the two input tables and completing the initial audit. If the target table already exists, `CREATE TABLE` reports an error without replacing it.
- Sections 3-5 of the script are read-only checks and can be rerun against the existing table.
- The table is a stored snapshot. Changes to the source tables do not automatically refresh it; a controlled refresh process remains to be added.
- Raw-data loading and bank-mapping creation are now captured in [setup/01_create_apra_inputs.sql](../sql/setup/01_create_apra_inputs.sql). Follow the [rebuild guide](rebuild_apra.md) to reconstruct the APRA inputs and staging table in a separate empty database.
- The remaining source modules, core analysis model and four Power BI pages have since been accepted. See the [final review](final_review.md) and follow the rebuild guides in their recorded source/model/report order.
