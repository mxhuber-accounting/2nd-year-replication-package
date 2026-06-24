# Paper Replication (analysis)

Reproduces every figure and table in the paper from
`Data/Working Files/_master.dta` (reproduction Option ii — the recommended
starting point). Run `0_run_paper.do` from the package root.

`Code/`:
- `1_Descriptives.do` — sample selection, descriptive statistics, main figures
- `2_Baseline_Analysis.do` — baseline event-study tables (LI vs PMF, FE/controls, sign decomposition, …)
- `2c_Baseline_Analysis_Extensive.do` — extensive margin (net change, entry/exit)
- `3_Disaggregated_Threshold.do` — disaggregated / rating-threshold analysis (needs `grc1leg`)
- `Baseline_Analysis_Extensive_UPGRADE.do` — symmetry check on upgrades
- `Robustness/Downgrade vs. Upgrade.do` — robustness

Output goes to `Figures and Tables/<section>/`. Requires `reghdfe`, `estout`,
and `grc1leg` (see the root README for installation).
