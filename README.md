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

## Two ways to reproduce

### Option ii — Paper only (fast, recommended)
Use the shipped working files and reproduce every figure and table directly.
1. Open `setup.do`, edit the single `${REPL}` line to point at this folder.
2. In Stata, `cd` to this folder, then run `Paper Replication/0_run_paper.do`.

Reads `Data/Working Files/_master.dta`; writes to `Paper Replication/Figures and Tables/`.

### Option i — Full reconstruction (slow, from raw vendor data)
Rebuild every source database from raw, then the sample, then the analysis.
1. In `setup.do`, set `${REPL}` **and** `global mode "regenerate"`.
2. `cd` to this folder, run `Sample Replication/0_run_sample.do` (several hours),
   then `Paper Replication/0_run_paper.do`.

---

## The four FROZEN reference files — do not overwrite
These live in `Data/Reference Files/` and reproduce the **exact** paper findings:
```
Data/Reference Files/CapitalIQ_Final.dta
Data/Reference Files/CDS_2012_2020_GVKEY-CUSIP.dta
Data/Reference Files/MergentFISD_QuarterlyPanel.dta
Data/Reference Files/WRDS_Bond_Returns.dta
```
With `mode = reference` (default) the pipeline reads these. `mode = regenerate`
reads the freshly rebuilt source outputs in `Data/<source>/` instead. **Sample
Replication only ever writes to `Data/<source>/` and `Data/Working Files/` — it
never targets the four files above.**

**Enforced:** the four files are shipped **read-only**, and `setup.do` re-asserts
the read-only lock on every run. So even a full sample reproduction — or a
reproducer who has run it before — cannot overwrite them; the OS denies the write.
(To deliberately refresh one, `chmod u+w` it first.)

---

## Structure
```
setup.do                      ← edit ${REPL} once; defines all paths + the mode switch
README.md

Sample Replication/           ← DATA CONSTRUCTION (Option i)
  0_run_sample.do             ← orchestrator: source builds → sample → master
  Sample_Creation.do          ← builds Working Files/SampleFinalCDS(.dta), _WV(.dta)
  Build_Master.do             ← builds Working Files/_master.dta
  Merge_Variables.do          ← reference catalog of optional merges

Paper Replication/            ← ANALYSIS (Option ii)
  0_run_paper.do              ← orchestrator: runs all analysis do-files
  Code/                       ← 1_Descriptives, 2_Baseline_Analysis, 2c_, 3_, UPGRADE, Robustness
  Figures and Tables/         ← output (one subfolder per section)

Data/                         ← all data; each source folder holds its OWN build do-file + Raw Data/
  eMAXX/        (eMAXX_1998-2023.do + Raw eMAXX/ + *_Complete.dta)
  MergentFISD/  (MergentFISD.do + Raw Data/ + rating panels + IssuesLookup)
  CapitalIQ/    (CapitalIQ_DO.do + Raw Data/ + CapitalIQ_Final)
  WRDS Bond Returns/ (WRDS_Bond_Returns.do + Raw Data/)
  Markit/       (CDS Data.do + Raw Data/ + CDS panel)
  Working Files/   (SampleFinalCDS, _WV, _master)
  Reference Files/ (the four FROZEN read-only reference inputs — see above)
```

> **Data on GitHub:** the `Data/` tree is ~100 GB and is *not* committed (it is
> git-ignored). The repository holds the code, `setup.do`, and docs; the data is
> distributed separately (Dropbox / institutional access).

---

## Requirements
Stata 17+ (tested on StataNow/MP). User-written commands:
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
