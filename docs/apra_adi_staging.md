# APRA ADI quarterly staging table

Status on 2026-09-11: source import, selected audit and typed staging table confirmed in the project database. The staging script has also passed independent source-to-table testing.

## Purpose and inputs

`stg.apra_big_four_quarterly` provides one row per mapped bank and publication quarter from the March 2013-March 2026 ADI centralised publication snapshot. It is created by [06_create_apra_big_four_quarterly.sql](../sql/06_create_apra_big_four_quarterly.sql), using `raw.apra_adi_quarterly` and `core.dim_bank` after the [05 audit](../sql/05_audit_apra_adi_quarterly.sql).

Banks are selected by matching trimmed ABNs. The result contains 212 records: 53 quarters for each of ANZ, CBA, NAB and WBC. This source reports at the entities' highest consolidation level and has a different reporting scope from the monthly MADIS table. See the [source review](apra_adi_source_review.md).

## Data dictionary

| Column | Type | Meaning |
|---|---|---|
| `bank_code` | VARCHAR | Code from the existing four-bank mapping |
| `bank_abn` | VARCHAR | Trimmed ABN from that mapping |
| `bank_name` | VARCHAR | Standard name from that mapping |
| `report_date` | DATE | Publication period, converted from `Period` |
| `entity_quarter_end` | DATE | Separate entity date from `Entity quarter end` |
| `cet1_capital_million` | DECIMAL(20,4) | Total Common Equity Tier 1 capital, AUD millions |
| `tier1_capital_million` | DECIMAL(20,4) | Total Tier 1 capital, AUD millions |
| `total_capital_million` | DECIMAL(20,4) | Total capital base, AUD millions |
| `rwa_million` | DECIMAL(20,4) | Total risk-weighted assets, AUD millions |
| `cet1_ratio` | DECIMAL(18,6) | Reported Common Equity Tier 1 capital ratio |
| `tier1_ratio` | DECIMAL(18,6) | Reported Tier 1 capital ratio |
| `total_capital_ratio` | DECIMAL(18,6) | Reported total capital ratio |
| `lcr_ratio` | DECIMAL(18,6) | Reported mean Liquidity Coverage Ratio |
| `nsfr_ratio` | DECIMAL(18,6) | Reported Net Stable Funding Ratio |
| `mlh_ratio` | DECIMAL(18,6) | Reported average Minimum Liquidity Holdings ratio; entirely NULL for this selection |
| `capital_framework` | VARCHAR | Source framework period, derived from publication date |

## Conversion and interpretation

- Dates use the workbook's Excel 1900 date system, with `1899-12-30` as the conversion base. The two date fields match for the audited four-bank records but remain separate columns.
- Monetary values stay in AUD millions. Four decimal places preserve the selected source amounts at the documented precision without exposing floating-point tails from Excel.
- Ratios retain decimal fractions: `0.124000` means 12.4%, and `1.318000` means 131.8%. Percentage display belongs in the reporting layer; the import does not divide values by 100. These columns retain the published ratios rather than recalculating them from rounded capital amounts.
- Blank numeric text becomes NULL using `NULLIF(TRIM(...), '')`. Strict `CAST` rejects invalid nonblank numeric text. Missing values are not filled with zero.
- `capital_framework` is `Basel III (2013-2022)` for dates before 2023-01-01 and `ADI capital framework (2023+)` thereafter, following the workbook's explanatory notes. The label identifies a reporting break; it does not make observations across that break directly comparable.
- The mean LCR and average MLH labels retain the source definitions. They are not automatically treated as simple quarter-end balances. Capital balances must not be summed across quarters.
- The intended key is `(bank_code, report_date)`. The initial `CREATE TABLE AS` does not declare a primary key or NOT NULL constraints; post-creation checks verify the observed records. Nullable column metadata alone does not imply that the data contain missing values.
- The table is a persistent derived snapshot. Section 2 creates it once and errors if it already exists. It does not refresh automatically when raw inputs change; a later refresh process must handle rebuilding explicitly.

## Confirmed project-database checks

The user's DBeaver screenshots on 2026-09-11 confirmed sections 3-5 of the staging script.

Section 3 returned 16 columns: four VARCHAR, two DATE, four DECIMAL(20,4) and six DECIMAL(18,6).

Section 4 returned 212 rows, four banks and 53 quarters from 2013-03-31 through 2026-03-31.

Section 5 returned seven PASS results:

| Check | Actual count | Expected count | Status |
|---|---:|---:|---|
| Duplicate bank/quarter key groups | 0 | 0 | PASS |
| Missing key or date rows | 0 | 0 | PASS |
| Rows missing any of the four capital amounts or three capital ratios | 0 | 0 | PASS |
| LCR missing rows | 80 | 80 | PASS |
| NSFR missing rows | 80 | 80 | PASS |
| MLH missing rows | 212 | 212 | PASS |
| Rows whose LCR/NSFR missingness differs from the audited time pattern | 0 | 0 | PASS |

For LCR and NSFR, each bank has 20 missing quarters in 2013-2017 and 33 populated quarters from 2018-03-31 to 2026-03-31. MLH has no observations for the selected four banks. Counts of 80 and 212 are expected missing values, not failures. These expectations are specific to the pinned workbook snapshot.

## Independent validation

The exact 04 import and 06 staging scripts were executed in a fresh in-memory DuckDB v1.5.5 database, with the existing four-bank mapping. The source workbook and project database were not modified, and the project database was not opened.

All expected schema, row-count and validation results passed. An independent read of the original workbook matched all 212 bank/quarter records, both dates, and all 2,120 numeric cells at the chosen decimal precision: 1,748 populated values and 372 NULLs. Framework labels cover 160 records through 2022 and 52 records from 2023. The latest ANZ samples remain CET1 `0.124000` and LCR `1.318000`.

The independent value comparison supplements the observed project-database checks above. It does not imply that every institution and every field in the original raw table has been audited. Both APRA modules can be reconstructed following the [rebuild guide](rebuild_apra.md); their stored tables do not refresh automatically.
