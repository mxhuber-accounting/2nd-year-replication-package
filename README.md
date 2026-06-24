# Replication Package — Institutional Bondholdings: Anticipation of Credit Rating Downgrades by Long-Horizon Investors

**Matthias Xaver Huber**

This package replicates the tables and figures of the paper. It builds a disaggregated bond × fund × firm × quarter panel from eMAXX, Mergent FISD, WRDS Bond Returns, S&P Capital IQ, and Markit CDS data, then runs descriptive statistics and stacked difference-in-differences event studies around the first credit rating downgrade.

## Software

Stata 17 or later.

Required user-written packages are installed automatically by `_setup.do` on first run: `reghdfe`, `ftools`, `unique`, `egenmore`, `winsor2`, `estout`, `distinct`.

## Data sources

All raw inputs are obtained through WRDS or directly from the data provider. Subscriptions are required.

| File | Source | Description |
| --- | --- | --- |
| `eMAXX/HOLDING_Complete.dta` | LSEG eMAXX | Quarterly institutional bond holdings |
| `eMAXX/FUND_Complete.dta` | LSEG eMAXX | Fund characteristics |
| `eMAXX/FIRM_Complete.dta` | LSEG eMAXX | Investment manager characteristics |
| `eMAXX/ISSUERS_Complete.dta` | LSEG eMAXX | Issuer characteristics |
| `eMAXX/SECMAST_Complete.dta` | LSEG eMAXX | Security master |
| `MergentFISD_QuarterlyPanel.dta` | Mergent FISD (WRDS) | Bond characteristics and credit ratings |
| `WRDS_Bond_Returns.dta` | WRDS Bond Returns (TRACE) | Prices, yields, transaction spreads |
| `CapitalIQ_Final.dta` | S&P Capital IQ | Outlook and watch events |
| `CDS_2012_2020_GVKEY-CUSIP.dta` | Markit (WRDS) | Single-name CDS spreads |

> **Note:** The raw `.dta` data files are proprietary and are **not** included in this repository (they are excluded by `.gitignore`). Only the Stata do-files are versioned here.

## Folder structure

```
Replication Package/
└── Data/                                       <-- ${root}
    ├── _setup.do                               (this file)
    ├── README.md
    │
    ├── eMAXX/                                  <-- ${eMAXX}  (raw inputs)
    │   ├── HOLDING_Complete.dta
    │   ├── FUND_Complete.dta
    │   ├── FIRM_Complete.dta
    │   ├── ISSUERS_Complete.dta
    │   └── SECMAST_Complete.dta
    │
    ├── MergentFISD_QuarterlyPanel.dta          (raw inputs at root)
    ├── WRDS_Bond_Returns.dta
    ├── CapitalIQ_Final.dta
    ├── CDS_2012_2020_GVKEY-CUSIP.dta
    │
    ├── eMAXXMergentFISD_SampleFinalCDS.dta     (built by 0_0)
    ├── eMAXXMergentFISD_SampleFinalCDS_WV.dta  (built by 0_0, primary panel)
    ├── _master.dta                             (built by 0_1)
    ├── _event_sample_main.dta                  (built by 1)
    │
    └── Figures and Tables/                     <-- ${out}
        ├── Descriptive/
        └── Baseline_Analysis/
```

The build files (`_WV.dta`, `_master.dta`, `_event_sample_main.dta`) and the raw provider files sit at the root level. The `eMAXX` subfolder holds the five raw eMAXX components.

## Run order

Run `_setup.do` once per session before any analysis file. Each analysis file is self-contained otherwise.

| Step | File | Output |
| --- | --- | --- |
| 0 | `_setup.do` | Installs packages, sets globals |
| 1 | `0_0_Sample_Creation.do` | `eMAXXMergentFISD_SampleFinalCDS.dta`, `eMAXXMergentFISD_SampleFinalCDS_WV.dta` |
| 2 | `0_1_Build_Master.do` | `_master.dta` |
| 3 | `1_Descriptives.do` | Table 1, 3, 4, 5; Figures 1–5; `_event_sample_main.dta` |
| 4 | `2_Baseline_Analysis.do` | Baseline regression tables |
| 5 | `2c_Baseline_Analysis_Extensive.do` | Extensive-margin robustness |
| 6 | `3_Disaggregated_Threshold.do` | NAIC-threshold analysis |

## Sample definitions

**Sample window.** 2012q1 to 2023q4.

**Bond universe.** US corporate debentures and medium-term notes (`bond_type` in CDEB, CMTN, CMTZ, CZ) with offering amount of at least $50 million, non-missing amount outstanding, rated by at least one of S&P, Moody's, or Fitch. Convertibles, preferred securities, financials (`issuer_creditsec` beginning with F), and structured (STR) are excluded.

**Investor universe.** Constrained investors only: Life Insurers, Other Insurers, P&C Insurers, Passive Mutual Funds, and Variable Annuity funds (`fundtype_det_num` in {1, 2, 3, 5, 8}). Active Mutual Funds (`fundtype_det_num == 4`) are excluded.

**Counterfactual.** Passive Mutual Funds serve as the omitted base group, following Bretscher, Schmid, Sen, and Sharma (2026, RFS).

**Event clock.** Anchored on the first downgrade by any of S&P, Moody's, or Fitch within the sample window. Event-window sample restricts to relative time in [-8, +8] quarters.

**Clean window.** Bond-quarters more than two quarters after issuance, to remove primary-market allocation noise.

## Key derived variables

| Variable | Definition |
| --- | --- |
| `passive` | 1 if fund name matches ETF/index keywords (Goyal et al. 2024; Bretscher et al. 2026) |
| `fundtype_det_num` | 1 = LI, 2 = OI, 3 = PC, 4 = AMF, 5 = PMF, 6 = OTHER, 7 = PEN, 8 = VA |
| `net_change_bp` | Quarterly net change in holdings, scaled by offering amount, in basis points; winsorized 1/99 within fundtype |
| `gross_buys_bp`, `gross_sells_bp` | Positive parts of net change, winsorized as above |
| `delta_holdings` | Non-winsorized counterpart to `net_change_bp` |
| `share` | Quarter-end position as percent of offering amount |
| `entry`, `exit` | First / last quarter the fund-firm holds the bond (excludes 2012q1 and maturity-quarter censoring) |
| `DowngradeSPR`, `DowngradeMR`, `DowngradeFR` | Per-agency downgrade indicators; missing when agency does not rate |
| `DowngradeAny` | Indicator for at least one agency downgrade in the bond-quarter |
| `NAIC_num` | Composite NAIC-style numeric rating (1 = AAA … cutoff at 10 for IG/HY) |
| `naic_bucket` | 1 = IG (`NAIC_num` ≤ 10), 0 = HY |
| `Clean_Window` | Bond-quarter more than two quarters post-issuance |
| `CDS_data` | Bond ever has a non-missing CDS spread |
| `is_INM` | External manager indicator (`firm_code == "INM"`) |

## Notes on data construction

- `offering_amt` from Mergent FISD is stored in thousands of dollars. All scaling in basis points uses this convention.
- Bond-quarters where any single fund-firm position or the bond-quarter aggregate of `paramt` exceeds amount outstanding (with a 0.1% tolerance for rounding) are dropped as data errors.

## Reproducing the paper

Open `_setup.do`, edit the global `root` line to point to the replication package on your machine, then run files in order. Each analysis file writes its outputs to `${out}/<subfolder>/`. The build files (`_WV.dta`, `_master.dta`, `_event_sample_main.dta`) are recomputed from raw inputs by the do-files; they are not shipped with the package.

Total build time, end to end, is approximately 30–60 minutes depending on hardware. The bottleneck is `0_0_Sample_Creation.do` (the eMAXX panel is large) and the regression files (`reghdfe` with high-dimensional fixed effects).

## Contact

Matthias X. Huber, HEC Paris. Questions on the replication package can be directed to the corresponding author.

matthias-xaver.huber@hec.edu
