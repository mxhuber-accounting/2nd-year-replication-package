# Sample Replication (data construction)

Builds the analysis working sample
`Data/Working Files/eMAXXMergentFISD_SampleFinalCDS_WV.dta` from one of two
sources, chosen by `global mode` in `setup.do`:

- **`"reference"`** (default, fast) — merge the FROZEN reference vendor files in
  `Data/Reference Files/`. Reproduces the paper.
- **`"raw"`** (slow, several hours) — rebuild every vendor database from raw
  vendor data first, then merge.

**Run:** edit `${REPL}` and pick `${mode}` in `setup.do`, **run `setup.do`**, then
run `0_run_sample.do` (no `cd` needed).

Pipeline (`0_run_sample.do`):
1. **Source databases** — *only when `mode = "raw"`* — each builds from its own raw
   inputs in `Data/<source>/`: `eMAXX_1998-2023.do`, `MergentFISD.do`,
   `CapitalIQ_DO.do`, `WRDS_Bond_Returns.do`, `CDS Data.do`.
2. **`Sample_Creation.do`** — merges the sources (via the `${in_*}` inputs that
   `setup.do` resolves per mode) into the bond × fund × firm × quarter panel and
   writes `Data/Working Files/eMAXXMergentFISD_SampleFinalCDS(.dta)` and `_WV(.dta)`.

`Build_Master.do` (derives the analysis variables → `_master.dta`) is run by
**`Paper Replication/0_run_paper.do`**, not here.

`Merge_Variables.do` is a reference catalog of optional merges (not run by the pipeline).

⚠️ This path **never** overwrites the four frozen reference files in `Data/Reference Files/`.
