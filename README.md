# Replication Package

**Institutional Bondholdings: Anticipation of Credit Rating Downgrades by Long-Horizon Investors**
Matthias Xaver Huber — HEC Paris

This package reproduces all figures and tables in the paper. It builds a
disaggregated bond × fund × firm × quarter panel from eMAXX, Mergent FISD, WRDS
Bond Returns, S&P Capital IQ, and Markit CDS, then runs descriptive statistics
and stacked difference-in-differences event studies around the first credit
rating downgrade. It is organized so a reproduction team can choose **how far
upstream to start**.

---

## How to reproduce

Open `setup.do` and edit the **two settings in the box at the top** — `${REPL}`
(where the package lives) and `${mode}` (which sample to build) — then **run
`setup.do`**. No `cd` needed — all paths are absolute.

### The one choice: where the sample comes from
At the top of `setup.do`, set `global mode` to one of:

- **`"reference"`** (default, fast) — build the sample from the **FROZEN reference
  vendor files** in `Data/Reference Files/`. Reproduces the paper.
- **`"raw"`** (slow, several hours) — **rebuild every vendor database from raw**
  vendor data first, then build the sample.

### Steps
1. **`setup.do`** — edit `${REPL}`, pick `${mode}`, run it.
2. **`Sample Replication/0_run_sample.do`** — builds `Data/Working Files/_WV.dta`
   (it runs the five source builds first **only** when `mode = "raw"`).
3. **`Paper Replication/0_run_paper.do`** — builds `_master.dta` from `_WV.dta` and
   writes every figure and table to `Paper Replication/Figures and Tables/`.

> **Fastest path:** the package ships a prebuilt `_WV.dta`, so to reproduce the paper
> without rebuilding the sample at all, run `setup.do` then **step 3** — skip step 2.

---

## The FROZEN reference inputs — do not overwrite
These reproduce the **exact** paper findings:
```
Data/Reference Files/CapitalIQ_Final.dta
Data/Reference Files/CDS_2012_2020_GVKEY-CUSIP.dta
Data/Reference Files/WRDS_Bond_Returns.dta
Data/MergentFISD/Paper Reference File/FINALIssueRatings.dta   ← rich MergentFISD panel (+ its build .do)
```
With `mode = reference` (default) the pipeline reads these. `mode = raw`
reads the freshly rebuilt source outputs in `Data/<source>/` instead (for
MergentFISD, `MergentFISD_QuarterlyPanel_2012-2023.dta`). **Sample
Replication only ever writes to `Data/<source>/` and `Data/Working Files/` — it
never targets the files above.**

**Enforced:** the files are shipped **read-only**, and `setup.do` re-asserts
the read-only lock on every run. So even a full sample reproduction — or a
reproducer who has run it before — cannot overwrite them; the OS denies the write.
(To deliberately refresh one, `chmod u+w` it first.)

---

## Structure
```
setup.do                      ← edit ${REPL} once; defines all paths + the reference/raw choice
README.md

Sample Replication/           ← DATA CONSTRUCTION
  0_run_sample.do             ← orchestrator: (raw only) source builds → Sample_Creation
  Sample_Creation.do          ← builds Working Files/SampleFinalCDS(.dta), _WV(.dta)
  Build_Master.do             ← builds Working Files/_master.dta (run by the paper orchestrator)
  Merge_Variables.do          ← reference catalog of optional merges

Paper Replication/            ← ANALYSIS
  0_run_paper.do              ← orchestrator: Build_Master → all analysis do-files
  Code/                       ← 1_Descriptives, 2_Baseline_Analysis, 2c_, 3_, UPGRADE, Robustness
  Figures and Tables/         ← output (one subfolder per section + Tables and Figures in Paper/)

Investment Management Sample Creation/   ← OPTIONAL: joinby eMAXX personnel onto the sample

Data/                         ← all data; each source folder holds its OWN build do-file + Raw Data/
  eMAXX/        (eMAXX_1998-2023.do + Raw eMAXX/ + *_Complete.dta)
  MergentFISD/  (MergentFISD.do + Raw Data/ + rating panels + IssuesLookup;
                 Paper Reference File/ = FINALIssueRatings.dta + its build .do)
  CapitalIQ/    (CapitalIQ_DO.do + Raw Data/ + CapitalIQ_Final)
  WRDS Bond Returns/ (WRDS_Bond_Returns.do + Raw Data/)
  Markit/       (CDS Data.do + Raw Data/ + CDS panel)
  Working Files/   (SampleFinalCDS, _WV, _master)
  Reference Files/ (FROZEN read-only: CapitalIQ_Final, CDS, WRDS_Bond_Returns)
```

> **Data on GitHub:** the `Data/` tree is ~100 GB and is *not* committed (it is
> git-ignored). The repository holds the code, `setup.do`, and docs; the data is
> distributed separately (Dropbox / institutional access).

---

## Requirements
Stata 17+ (tested on StataNow/MP). **`setup.do` auto-installs the required
user-written commands** on its first run (only the ones that are missing), so no
manual setup is needed — as long as the machine has internet access. For
reference (or to pre-install offline), they are:
```
ssc install reghdfe
ssc install ftools
ssc install estout
ssc install winsor2
ssc install egenmore
ssc install distinct
ssc install unique
net install grc1leg, from("http://www.stata.com/users/vwiggins")
```
