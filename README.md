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

**Goal: regenerate every figure and table in the paper.** The data moves through
three stages, and you choose which stage to start from:

```
raw vendor data  -->  preprocessed vendor files  -->  final dataset  -->  figures & tables
      |                          |                          |
   Option 3                   Option 2                   Option 1
```

Edit the **two settings at the top of `setup.do`** — `${REPL}` (where this package
lives on your machine) and `${mode}` (which stage you start from) — then **run
`setup.do`**. The three options are fully independent: each writes to its own
location and leaves the others untouched, so you can run any one of them — or all
three — without them affecting each other.

### Option 1 — from the final, fully processed dataset · ≈ 20 minutes
`mode = "shipped"` (the default). Start from the finished dataset that ships with
the package and simply produce the figures and tables. Fastest path — there is
nothing to build.

### Option 2 — from the preprocessed vendor data · ≈ 1–2 hours
`mode = "reference"`. Start from the cleaned, per-vendor files: merge them and run
the sample selection yourself to rebuild the final dataset, then produce the
figures and tables.

### Option 3 — from the raw vendor data, from scratch · several hours
`mode = "raw"`. Start from the original raw vendor downloads: rebuild each
preprocessed vendor file, then do the merge and sample selection, then the figures
and tables — the complete end-to-end reproduction.

### What to run
1. **`setup.do`** — set `${REPL}` and `${mode}`, then run it.
2. **`Sample Replication/0_run_sample.do`** — rebuilds the dataset. Needed for
   Options 2 and 3 only; for Option 1 there is nothing to build, so skip it.
3. **`Paper Replication/0_run_paper.do`** — writes every figure and table to
   `Paper Replication/Figures and Tables/`.

---

## The preprocessed vendor data — do not overwrite
These are the cleaned, per-vendor files that **Option 2** reads. They reproduce
the **exact** paper findings:
```
Data/Reference Files/CapitalIQ_Final.dta
Data/Reference Files/CDS_2012_2020_GVKEY-CUSIP.dta
Data/Reference Files/WRDS_Bond_Returns.dta
Data/MergentFISD/Paper Reference File/FINALIssueRatings.dta   ← rich MergentFISD panel (+ its build .do)
```
**Option 2** (`reference`) reads these directly. **Option 3** (`raw`) regenerates
its own copies from the raw vendor data in `Data/<source>/` instead (for
MergentFISD, `MergentFISD_QuarterlyPanel_2012-2023.dta`). **Option 1** (`shipped`)
reads neither — it uses the finished dataset directly. Sample construction only
ever writes to `Data/<source>/` and `Data/Working Files/` — it never touches the
files above.

**Kept read-only:** these files ship read-only and `setup.do` re-asserts the lock
on every run, so a rebuild — even a from-scratch one — cannot overwrite them; the
OS denies the write. (To deliberately refresh one, `chmod u+w` it first.)

---

## Structure
```
setup.do                      ← edit ${REPL} once; defines all paths + the reference/raw choice
README.md
VARIABLE_DICTIONARY.md        ← definitions of key constructed variables (audit aid)

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
  Working Files/   (shipped SampleFinalCDS, _WV, _master; rebuilds -> Rebuilt_reference/ | Rebuilt_raw/)
  Reference Files/ (preprocessed, read-only: CapitalIQ_Final, CDS, WRDS_Bond_Returns)
```

> **Data on GitHub:** the `Data/` tree is ~100 GB and is *not* committed (it is
> git-ignored). The repository holds the code, `setup.do`, and docs; the data is
> distributed separately (Dropbox / institutional access).

---

## Pipeline map
What each script reads, writes, and in which mode it runs. `${wsdir}` is the
working-sample folder chosen by `${mode}` (`Data/Working Files/` for `shipped`,
`…/Rebuilt_reference/` or `…/Rebuilt_raw/` for a rebuild).

| Step | Script | Reads | Writes | Runs in |
|---|---|---|---|---|
| 0 | `setup.do` | — | sets `${REPL}`, `${mode}`, `${wsdir}`, all paths | always (first) |
| 1 | `Sample Replication/0_run_sample.do` | (raw) `Data/<source>/Raw …` | orchestrates 1a + 1b | reference, raw |
| 1a | `eMAXX_1998-2023.do`, `MergentFISD.do`, `CapitalIQ_DO.do`, `WRDS_Bond_Returns.do`, `CDS Data.do` | raw vendor files | `Data/<source>/*_Complete` / panels | **raw only** |
| 1b | `Sample Replication/Sample_Creation.do` | `${in_*}` vendor inputs + eMAXX `*_Complete` | `${wsdir}/SampleFinalCDS.dta`, `…_WV.dta` | reference, raw |
| 2 | `Paper Replication/0_run_paper.do` | `${wsdir}/…_WV.dta` | orchestrates 2a–2e | always |
| 2a | `Sample Replication/Build_Master.do` | `${wsdir}/…_WV.dta` | `${wsdir}/_master.dta` | always (via paper) |
| 2b | `Code/1_Descriptives.do` | `${wsdir}/_master.dta` | Descriptive/ → F01, F02, F03, T01, T02 | always |
| 2c | `Code/2_Baseline_Analysis.do` | `_master.dta` | Baseline_Analysis/ → T03–T07 | always |
| 2d | `Code/2c_Baseline_Analysis_Extensive.do` | `_master.dta` | Baseline_Analysis_Extensive/ → F04 | always |
| 2e | `Code/3_Disaggregated_Threshold.do` | `_master.dta` | Threshold/ → F05, F06 | always |
| 3 | `Investment Management Sample Creation/0_run_im_sample.do` | `${wsdir}/…_WV.dta` + `${emaxx}/PERSONNEL_Complete.dta` | `${wsdir}/…_IM_Sample.dta` | optional, any mode |

In `shipped` mode step 1 builds nothing (the prebuilt sample is used); start at step 2.
See `VARIABLE_DICTIONARY.md` for the variables these scripts construct, and
`Paper Replication/README.md` for the internal-vs-paper table/figure numbering.

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
ssc install coefplot
ssc install winsor2
ssc install egenmore
ssc install distinct
ssc install unique
net install grc1leg, from("http://www.stata.com/users/vwiggins")
```
