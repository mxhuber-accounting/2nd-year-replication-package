# Variable Dictionary

Key constructed variables, where they are built (file:line), and how. This is a
reading aid for auditors — it is not executed. Line numbers are approximate and
may drift as the code evolves; the construction logic is what matters.

The pipeline builds variables in three places:
- **`Sample Replication/Sample_Creation.do`** — the bond × fund × firm × quarter
  panel and its raw outcome variables.
- **`Sample Replication/Build_Master.do`** — investor coding, rating/event
  indicators (→ `_master.dta`, the analysis file).
- **`Paper Replication/Code/*.do`** — per-analysis event-time / sample dummies.

---

## Identifiers & fund type

| Variable | Built in | Definition |
|---|---|---|
| `fundtype_det` / `fundtype_det_num` | `Sample_Creation.do:206-219` | String fund type from eMAXX `fundclass`, then `encode`d. Categories: `INS_life`, `INS_prop`, `INS_other`, `MUT_act`, `MUT_pas`, `VA`, `PEN`, `OTHER`. **`encode` assigns codes alphabetically over the observed levels**, giving `1=INS_life` (Life Insurer), `2=INS_other`, `3=INS_prop` (P&C), `4=MUT_act` (Active MF), `5=MUT_pas` (Passive MF), `6=OTHER`, `7=PEN`, `8=VA`. The whole pipeline relies on **1 = Life Insurer, 5 = Passive MF**. |
| `passive` | `Sample_Creation.do` (Step 1b) | Byte flag = 1 for index/ETF/passive mutual-fund rows (regex on `fundname`); feeds the `MUT_pas` vs `MUT_act` split. |
| `LI` | analysis files, e.g. `2_Baseline_Analysis.do:219`, `3_Disaggregated_Threshold.do:112` | `byte LI = (fundtype_det_num == 1)` — Life-insurer dummy. Re-created locally in each analysis file. |

## Investor coding (Build_Master, on `_master`)

| Variable | Built in | Definition |
|---|---|---|
| `PassiveInvestor` | `Build_Master.do:46-56` | 0-indexed investor type for figures/pooled specs: `0 Other, 1 Passive MF, 2 Life Insurer, 3 Other Insurer, 4 P&C Insurer, 5 VA` (from `fundtype_det_num` 5/1/2/3/8). |
| `Constr_Investor` | `Build_Master.do:59-69` | "Constrained investor type" with **Passive MF as baseline (0)**: `0 Passive MF, 1 Life Insurer, 2 Other Insurer, 3 P&C Insurer, 4 VA`; missing for dropped types. |

> `Build_Master.do:42-43` drops Active MFs (`fundtype_det_num==4`) and keeps the
> five long-term types `inlist(fundtype_det_num,1,2,3,5,8)`.

## Outcome / flow variables (Sample_Creation, bp of offering amount)

| Variable | Built in | Definition |
|---|---|---|
| `delta_holdings` | `Sample_Creation.do:309-311,325,330` | q-on-q change in par holdings `paramt` scaled to **basis points of `offering_amt`** (`(paramt − paramt[_n−1]) / offering_amt × 10000`), within `issueID fundid firmid (qdate)`. **Winsorized 1/99 within `fundtype_det_num`**. Missing in each panel's first quarter. |
| `pos_delta_holdings` | `Sample_Creation.do:325,331` | `max(delta_holdings, 0)` after winsorizing — positive component. |
| `neg_delta_holdings` | `Sample_Creation.do:311,332` | `max(−delta_holdings, 0)` — absolute negative component, **non-winsorized**. |
| `net_change_bp` | `Sample_Creation.do:296,303` | eMAXX `net_change / offering_amt × 10000`. |
| `gross_buys_bp` / `gross_sells_bp` | `Sample_Creation.do:299-305` | Positive / negative part of `net_change`, each scaled to bp of offering. |
| `entry` / `exit` | `Sample_Creation.do:281-282` | Within `issueID fundid firmid (qdate)`: `entry=(_n==1)` (first quarter the holding appears), `exit=(_n==_N)` (last quarter). |

## Rating & event indicators (Build_Master, on `_master`)

| Variable | Built in | Definition |
|---|---|---|
| `NAIC_num` | `Build_Master.do:124-141` | Composite numeric rating from `SPR_num MR_num FR_num`: 1 agency → that value; 2 → `rowmax` (the **lower** rating, since higher number = worse); 3 → `rowmedian`. Scale `1=AAA … 10=BBB- , 11=BB+ …`. |
| `naic_bucket` | `Build_Master.do:146-148` | `1 = Investment Grade` (`NAIC_num ≤ 10`), `0 = High Yield`. |
| `fa` (fallen angel) | `Build_Master.do:166,170-178` | `byte fa = (L_bucket==1 & naic_bucket==0)` on a deduplicated bond-quarter panel — IG last quarter, HY this quarter — then cleaned of any same event in the prior 8 quarters. `first_fa` (`:182`) = first such quarter per `issueID`. |
| `DowngradeAny` / `UpgradeAny` | `Build_Master.do:72-74,77-81` | Any-agency downgrade/upgrade in the bond-quarter (OR over SPR/MR/FR change flags). |
| `Clean_Window` | `Build_Master.do:84-86` | `byte = (qdate > qoffering + 2)` — bond-quarters more than 2 quarters after issuance (drops seasoning noise). |

## Event-time / sample dummies (analysis files)

| Variable | Built in | Definition |
|---|---|---|
| `rel_time_c` | `3_Disaggregated_Threshold.do:96,619` | `qdate − c` (event-centered quarters relative to the cohort/event quarter `c`). |
| `rel_time_shifted` | `3_Disaggregated_Threshold.do:116,639` | `rel_time_c + 9` ∈ **[1,17]** (so it can be used as a factor variable with no negative levels). |
| `window` | e.g. `3_Disaggregated_Threshold.do:358-363` | 5-bin event window from `rel_time_c`: `1 Pre_2Y (−8..−5), 2 Pre_1Y (−4..−1), 3 Downgrade (0), 4 Post_1Y (1..4), 5 Post_2Y (5..8)`. Rebuilt per analysis file. |
| `treated` | `3_Disaggregated_Threshold.do:80,97` | In each stacked cohort `c`: `byte = (first_fa == c)` — bonds that become fallen angels in cohort quarter `c` (treated vs. BBB- survivors). |

> ⚠️ **Known issue (flagged in review):** `3_Disaggregated_Threshold.do:131,655`
> try to pool the Pre_2Y window with `inrange(rel_time_shifted, -8, -5)`, but
> `rel_time_shifted` ∈ [1,17], so the condition never fires — the intended pooled
> baseline silently collapses to the single quarter t=−8. Fix is to use
> `inrange(rel_time_shifted, 1, 4)` (≡ `rel_time_c ∈ [−8,−5]`). Not yet applied
> because it changes the Table 8 numbers.
