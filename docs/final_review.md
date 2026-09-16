# Final review of the portfolio snapshot

Reviewed on **17 September 2026**, against report checkpoint **2cbd2af**.
The defined four-page portfolio scope is complete: six imported source
workbooks, six analysis-model tables, six active Power BI relationships,
seventeen measures and four accepted report pages. Descriptive results are
recorded in [Analysis findings](analysis_findings.md).

This review supports the current static portfolio snapshot and manual rebuild
instructions. It is not an independent reconstruction of the full PBIX, a
new execution of the existing SQL/DAX suites, or a regulatory assessment.
The repository does not contain a hosted interactive report or an automatic
data-refresh pipeline. No GitHub release tag is implied by this review.

## Evidence and review results

| Area | Evidence and result |
|---|---|
| Source snapshots | All six local workbook SHA256 hashes match the previously validated inputs. No source workbook was changed. |
| SQL artifacts | All 27 SQL files reviewed for provenance: 19 match recorded validation hashes, seven early scripts match their accepted preparation files, and the connection diagnostic contains only read-only metadata queries. No SQL changes are required by this review. |
| Model acceptance | Existing script 25 evidence contains 6 inventory, 6 relationship and 2 combined-join PASS rows. Counts are 4 / 5,113 / 356 / 212 / 89 / 53. These prior results were reviewed, not rerun. |
| Power BI measures | All 17 repository queries match the accepted query text after newline normalization. Their 89 value/filter checks were previously confirmed in the author's model, along with model addition. The separate count/missingness/sort checks remain documented in the rebuild guide. |
| Report acceptance | Overview accepted 15 September; Loans & Deposits and Macro Context 16 September; Capital & Liquidity 17 September. Each has author-confirmed numerical, selection, history and save checks. Four saved screenshots were reviewed. |
| Findings arithmetic | Original monthly source values reconcile to all 2,492 previously audited selected amount cells. Annual growth, shares, monthly growth, ratio differences and macro spreads use unrounded inputs. Latest quarterly values were reread from the original ADI workbook. |
| Units and scope | Amounts convert AUD million to AUD billion once. RBA/CPI per-cent values divide by 100 for DAX formatting; ADI ratios already contain fractions. MADIS domestic and ADI highest-consolidation scopes remain separate. |
| Missing history | CPI annual change has 16 available months; LCR/NSFR each have 33 available quarters per bank. Earlier unavailable values remain blank. The 2023 capital-framework note is retained. |
| Documentation | Obsolete completion-status wording was corrected. The Macro Context acceptance table now explicitly includes the March 2019 starting values. Local Markdown targets were checked against the proposed documentation plus the existing repository. |
| Repository boundary | Baseline main and origin/main both identify 2cbd2af with a clean working tree. Its 82 tracked files exclude the local workbooks, database and PBIX. Existing SQL, DAX, Power Query and all four screenshots remain unchanged in this documentation update. |

The evidence distinguishes three types of assurance: independently tested SQL
from earlier stages, DAX results and interactions confirmed by the report
author, and the present read-only source/document review. Screenshots confirm
visible output, not every hidden Power BI setting or every historical plotted
value. The full [Power BI rebuild guide](rebuild_power_bi.md) remains a manual
procedure that has not been independently executed from start to finish.

## Corrections made in this review

Earlier staging/model documents still described now-completed Power BI work as
future work. Their status text now points to the accepted report and final
review while retaining the original tests and their dates. Table 18 category
modelling is still an extension and is not marked complete.

The Macro Context guide asked readers to check the first March 2019 point
without listing its values in the adjacent table. The table now gives target
**1.50%**, interbank **1.50%** and three-month bank bills **1.83%**, read from
the pinned RBA workbook. This is a documentation correction; the accepted
measure and report values are unchanged.

No numerical or aggregation defect was found within the reviewed measures
and source comparisons. The analytical conclusions use four-bank denominators,
label separate monthly and quarterly snapshots, and avoid attributing bank
growth to macroeconomic causes without a supporting analysis.

## Reproducing and extending the work

Use the pinned workbooks with the [APRA](rebuild_apra.md),
[RBA](rebuild_rba.md), [ABS](rebuild_abs_cpi.md),
[SQL model](rebuild_analysis_model.md) and [Power BI](rebuild_power_bi.md)
guides in that order. Use a separate empty database when rebuilding. The
workbooks and PBIX remain local, so a Git clone alone cannot reproduce the
report. Later downloads can contain revisions; the existing expected values
are specific to the snapshots below.

Future work is distinct from completion of this four-page snapshot:

- Rebuild the entire PBIX independently on a fresh environment and record the
  result, including driver installation and all incoming visual interactions.
- Add a controlled refresh process with updated coverage, missingness and
  value checks before adopting new source snapshots.
- Introduce profitability, credit-quality and funding-composition data before
  extending the descriptive comparisons into broader bank-performance analysis.
- Model Table 18 detail with a series dimension and explicit category hierarchy
  if expenditure-level CPI analysis is added.

No statistical or causal relationship has been established between interest
rates, inflation and bank balances. Regulatory thresholds and bank-specific
requirements have not been evaluated. These are analytical boundaries of the
current data, rather than additional claims established by the validation tests.

## Pinned source identifiers

The following SHA256 values identify the exact workbooks used. Files are
excluded from Git and are referenced by filename in the rebuild guides.

| Local filename | SHA256 |
|---|---|
| `01_APRA_MADIS_Backseries_Mar2019_Jul2026.xlsx` | `cec42b342dbb006e2f754eeab2ec2b2606481cc8b2b85ae8b3a2c1abf150912e` |
| `02_APRA_ADI_Capital_Liquidity_Mar2013_Mar2026.xlsx` | `db6039981576f552527c97659dfd12518f3ae8dbde4212718e412b2a203b01e1` |
| `03_RBA_F1_1_Monthly_Money_Market.xlsx` | `257486d5183ad28aa2a0d2c0b29d900edc8b6e820ba8936a18640aa8f88bda4a` |
| `04_ABS_CPI_Table1_Monthly_Jul2026.xlsx` | `0c1c6fa0d6ed6f11d7ddf5e5bd684432acee59e83eb36c840f42b1f36cb472dc` |
| `05_ABS_CPI_Table17_Quarterly_Jul2026.xlsx` | `742c7159d8a0a5cf7c357f418d2ba467209d3547aa1583e80a9ff1dd4478cb9f` |
| `06_ABS_CPI_Table18_Quarterly_Detail_Jul2026.xlsx` | `cc608103d747d8acf59ba54c529de952bb0619d68beb2e442ded71d49f3ff15a` |
