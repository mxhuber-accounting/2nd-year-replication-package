# Paper Replication (analysis)

Reproduces every figure and table in the paper from
`Data/Working Files/_master.dta` (reproduction Option ii — the recommended
starting point). Run `setup.do` first, then `0_run_paper.do` (no `cd` needed).

`Code/`:
- `1_Descriptives.do` — sample selection, descriptive statistics, main figures
- `2_Baseline_Analysis.do` — baseline event-study tables (LI vs PMF, FE/controls, sign decomposition, …)
- `2c_Baseline_Analysis_Extensive.do` — extensive margin (net change, entry/exit)
- `3_Disaggregated_Threshold.do` — disaggregated / rating-threshold analysis (needs `grc1leg`)
- `Robustness/Baseline_Analysis_Extensive_UPGRADE.do` — symmetry check on upgrades
- `Robustness/Downgrade vs. Upgrade.do` — robustness

Output goes to `Figures and Tables/<section>/`. Requires `reghdfe`, `estout`,
`coefplot`, and `grc1leg` (see the root README for installation).

## Paper output numbering (internal ↔ paper)
The scripts use **internal** labels (and store-names that don't match the paper
order); the curated copies in `Figures and Tables/Tables and Figures in Paper/`
are renamed to the **paper's** numbers. The map:

| Paper | Title | Built in | Internal store-name |
|---|---|---|---|
| Table 1 | Sample Construction & Composition | `1_Descriptives.do` | `Table1_SampleSelection` |
| Table 2 | Descriptive Statistics | `1_Descriptives.do` | `Table4_DescriptiveStatistics` |
| Table 3 | Baseline by Investor Type | `2_Baseline_Analysis.do` | `table1_baseline_constr_investor` |
| Table 4 | Robustness: FE & Controls | `2_Baseline_Analysis.do` | `table2_robustness_FE_controls` |
| Table 5 | Outlook Triple | `2_Baseline_Analysis.do` | `table6_outlook_triple_unbal_bal` |
| Table 6 | CDS Triple | `2_Baseline_Analysis.do` | `table7_cds_triple_unbal_bal` |
| Table 7 | Trading Flows Around Downgrades | `2_Baseline_Analysis.do` | `table7_tradingflows_LI_vs_PMF` |
| Figure 1 | eMAXX Coverage | `1_Descriptives.do` | `Figure1_WithineMAXX` |
| Figure 2 | Amount Outstanding Coverage | `1_Descriptives.do` | `Figure2_AmtOutstanding` |
| Figure 3 (A/B) | Δ Holdings by Event Quarter / Year | `1_Descriptives.do` | `Figure4_DeltaHoldings_RelTime` / `_RelYear` |
| Figure 4 | Extensive Margin Descriptive | `2c_Baseline_Analysis_Extensive.do` | `Figure_extensive_descriptive` |
| Figure 5 (A/B) | Trading by Event Window (descr. / coef.) | `3_Disaggregated_Threshold.do` | `Figure_threshold_descriptive_window` / `_coef_window` |
| Figure 6 | Trading Around the IG Threshold | `3_Disaggregated_Threshold.do` | `Figure8_threshold_eventstudy` |

`3_Disaggregated_Threshold.do` also estimates the stacked-DiD threshold models
(internal "Table 8") used in the text; those are not copied to the paper folder.
