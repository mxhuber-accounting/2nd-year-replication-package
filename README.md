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
(where the package lives) and `${mode}` (which working sample to use) — then **run
`setup.do`**. No `cd` needed — all paths are absolute.

### The one choice: which working sample the paper uses
At the top of `setup.do`, set `global mode` to one of three:

- **`"shipped"`** (default, fast) — use the **prebuilt** sample already in
  `Data/Working Files/`. Reproduces the paper. *(Nothing to build — skip to step 3.)*
- **`"reference"`** — **rebuild** the sample from the **frozen reference** vendor files
  → writes to `Data/Working Files/Rebuilt_reference/`.
- **`"raw"`** (slow, several hours) — **rebuild every vendor database from raw**, then
  the sample → writes to `Data/Working Files/Rebuilt_raw/`.

> **Safety layer:** `reference`/`raw` rebuilds write to their own `Rebuilt_*` subfolder and
> **never overwrite the shipped `_WV.dta` / `SampleFinalCDS.dta`.** The whole pipeline
> (Build_Master + analysis) then reads from whichever folder `${mode}` selected.

### Steps
1. **`setup.do`** — edit `${REPL}`, pick `${mode}`, run it.
2. **`Sample Replication/0_run_sample.do`** — *only for `reference`/`raw`* — builds the
   sample into the `Rebuilt_*` subfolder (runs the five source builds first only for `raw`).
   For `shipped` there's nothing to build; skip this step.
3. **`Paper Replication/0_run_paper.do`** — builds `_master.dta` from the chosen `_WV.dta`
   and writes every figure and table to `Paper Replication/Figures and Tables/`.

---

## The FROZEN reference inputs — do not overwrite
These reproduce the **exact** paper findings:
```
Data/Reference Files/CapitalIQ_Final.dta
Data/Reference Files/CDS_2012_2020_GVKEY-CUSIP.dta
Data/Reference Files/WRDS_Bond_Returns.dta
Data/MergentFISD/Paper Reference File/FINALIssueRatings.dta   ← rich MergentFISD panel (+ its build .do)
```
With `mode = reference` the pipeline reads these; `mode = raw` reads the freshly
rebuilt source outputs in `Data/<source>/` instead (for MergentFISD,
`MergentFISD_QuarterlyPanel_2012-2023.dta`). The default `mode = shipped` reads
neither — it uses the prebuilt working sample directly. **Sample Replication
only ever writes to `Data/<source>/` and `Data/Working Files/` — it never
targets the files above.**

**Enforced:** the files are shipped **read-only**, and `setup.do` re-asserts
the read-only lock on every run. So even a full sample reproduction — or a
reproducer who has run it before — cannot overwrite them; the OS denies the write.
(To deliberately refresh one, `chmod u+w` it first.)

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
  Reference Files/ (FROZEN read-only: CapitalIQ_Final, CDS, WRDS_Bond_Returns)
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
