# APRA ADI centralised publication: source review

Reviewed read-only on 2026-09-11. Project-database import counts, bank coverage, the selected quarterly audit and the typed staging table were confirmed through DBeaver on the same date.

## Source and intended use

Local file: `data/raw/02_APRA_ADI_Capital_Liquidity_Mar2013_Mar2026.xlsx`.

The workbook's `Cover!B20:B23` identifies it as the *Authorised deposit-taking institution centralised publication*, covering March 2013 to March 2026 and released on 29 June 2026. Its regulatory capital and liquidity measures can support quarterly comparisons of the four selected banks.

APRA describes the centralised publication as entity-level quarterly data, with capital history from 2013 and liquidity ratios from 2018. This differs from the separate industry-aggregate performance publication available on the same [APRA publication page](https://www.apra.gov.au/news-and-publications/quarterly-authorised-deposit-taking-institution-statistics).

## Select the historical table

| Sheet | Content | Observed data in this snapshot |
|---|---|---|
| `Table 1` | Regulatory capital | Latest-period snapshot, 76 entity records |
| `Table 2` | Risk-weighted asset components | Latest-period snapshot, 76 entity records |
| `Table 3 ` | Liquidity ratios | Latest-period snapshot, 76 entity records; sheet name has a trailing space |
| `Table 4` | Back series, including ABNs | 5,295 historical records and 23 populated columns |

`Table 4!A3:W3` contains the headers. Data occupy rows 4-5298. The worksheet's reported dimensions extend through column X, but X is outside the populated table. The import range is therefore **A3:W5298** for this pinned snapshot. Tables 1-3 also contain extensive empty formatted rows; worksheet dimensions alone are not record counts.

Table 4 includes both `Period` and `Entity quarter end`. These must be retained separately: the former identifies the publication period, while the latter records the entity's quarter end. In the latest Tables 1-3 snapshot, most entity dates are 31 March 2026, but at least one is 28 February 2026. Do not assume the fields are interchangeable for all institutions.

The source's 53 publication periods run from 2013-03-31 to 2026-03-31. Matching the existing four-bank ABNs gives:

| Bank | ABN | Source records | Distinct publication periods |
|---|---|---:|---:|
| ANZ | 11005357522 | 53 | 53 |
| CBA | 48123123124 | 53 | 53 |
| NAB | 12004044937 | 53 | 53 |
| WBC | 33007457141 | 53 | 53 |

These are observations from the source workbook; the import script repeats the coverage checks against the project database.

## Scope, units and interpretation

- **Consolidation:** `Explanatory notes!A7` states that the publication uses entities' highest consolidation level. Keep this quarterly dataset distinct from MADIS residents' balances on unconsolidated Australian domestic books. A shared bank identifier does not make the two financial reporting scopes identical.
- **Population:** `Explanatory notes!A28` restricts the publication to domestically incorporated ADIs and excludes foreign branch banks. Match the four intended entities by ABN, rather than treating every record labelled `Major banks` as one of the four mapped parent entities.
- **Amounts:** `Notes!A16` and `Table 4!G2/N2` identify millions of Australian dollars. Monetary columns retain this unit.
- **Ratios:** percentages are stored as decimal fractions. For example, `Table 4!K7` is `0.124`, formatted as 12.4%, and `U7` is `1.318`, formatted as 131.8%. Preserve these fractions when converting to numeric types; do not divide them by 100 again.
- **Numeric precision:** the Excel reader can expose floating-point tails in raw text, such as `1.3180000000000001` for that LCR sample. Keep the raw value and choose an explicit decimal precision in the later typed table.
- **Blank cells:** `Notes!A17` says blanks can represent not-applicable items or periods before/after collection. Preserve them as NULL and review coverage for each metric; they must not be automatically replaced by zero.
- **Capital framework change:** `Explanatory notes!A11:A13` distinguishes the Basel III reporting framework through 2022 from the ADI capital framework starting 1 January 2023. Account for this break when interpreting trends.
- **Liquidity definitions:** `Explanatory notes!A41` directs readers to the glossary for differences in mean LCR and average MLH definitions. Do not automatically treat every ratio as a simple quarter-end observation.

## Initial import

[04_load_apra_adi_quarterly.sql](../sql/04_load_apra_adi_quarterly.sql) creates `raw.apra_adi_quarterly` from the historical sheet with all 23 columns retained as `VARCHAR`. It requires the existing raw schema and bank mapping. It creates a new table once and does not replace existing tables.

The first database checks cover imported row count, publication-period coverage and matching of the four bank ABNs. The subsequent audit below covers duplicate bank/period keys, both date fields, amount and ratio conversion, and metric-specific missing periods. The typed table also records the documented 2023 framework break.

The import script was tested in an independent in-memory DuckDB v1.5.5 database reading the workbook directly. It returned 5,295 rows, 23 VARCHAR columns, the expected date coverage, and 53 rows for each mapped bank. A supplementary check found zero duplicate raw ABN/Period groups.

The user's subsequent DBeaver results confirmed 5,295 imported rows and 53 publication periods from 2013-03-31 to 2026-03-31. Each of ANZ, CBA, NAB and WBC matched 53 rows and 53 periods over that same range, giving 212 selected bank/quarter records.

## Confirmed audit: dates, capital measures and liquidity coverage

[05_audit_apra_adi_quarterly.sql](../sql/05_audit_apra_adi_quarterly.sql) performs three read-only checks restricted to the four mapped banks: date/key diagnostics, numeric checks for four capital amounts and six ratios, and bank-level coverage of LCR, NSFR and MLH.

The exact script ran in an independent in-memory database loaded from the Excel snapshot. The user's three DBeaver result screenshots on 2026-09-11 subsequently confirmed the same results in the project database:

- All six date/key diagnostic counts are zero. In this four-bank selection, the publication and entity quarter-end dates match.
- Each of the ten metrics has 212 rows checked. The four capital amounts and three capital ratios have no missing values.
- LCR and NSFR each have 80 missing values, corresponding to 20 quarters per bank in 2013-2017. Each bank has 33 valid quarters for both metrics from 2018-03-31 to 2026-03-31, with no gaps inside that span.
- MLH has 212 missing values and no observations for the selected banks. Its first/last valid dates and within-span gap count are therefore NULL. Leave these cells missing; the planned four-bank liquidity analysis uses LCR and NSFR.
- All ten metrics have zero nonblank conversion failures, negative values and zero values. Negative and zero counts are diagnostic flags rather than general deletion rules; liquidity ratios above 1 are retained.

The numeric audit uses `DECIMAL(20,6)` to check convertibility while accommodating the observed floating-point text tails. Missing values are never substituted with zero by these queries. These findings cover the selected four-bank records and ten metrics, rather than every field and institution in the raw table.

## Confirmed typed quarterly table

[06_create_apra_big_four_quarterly.sql](../sql/06_create_apra_big_four_quarterly.sql) creates `stg.apra_big_four_quarterly` with both dates, four capital amounts, six ratios and a capital-framework label. Amounts use `DECIMAL(20,4)` and ratios use `DECIMAL(18,6)`; observed liquidity blanks remain NULL.

The script passed independent in-memory testing, including comparison of all 2,120 selected numeric cells (including 372 NULLs) with an independent Excel read at the chosen decimal precision. The user's subsequent DBeaver results confirmed all 16 column types, 212 rows, four banks, 53 quarters from 2013-03-31 to 2026-03-31, and seven PASS results. See the [quarterly staging documentation](apra_adi_staging.md) for the data dictionary and observed checks.
