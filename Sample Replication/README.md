# Sample Replication (data construction)

Builds the analysis working sample (`eMAXXMergentFISD_SampleFinalCDS_WV.dta` +
`SampleFinalCDS.dta`). Whether/where it builds is governed by `global mode` in
`setup.do`:

- **`"shipped"`** (default) — **nothing to build**; the paper uses the prebuilt
  files already in `Data/Working Files/`. Skip this folder, run `0_run_paper.do`.
- **`"reference"`** — rebuild from the FROZEN reference vendor files →
  `Data/Working Files/Rebuilt_reference/`.
- **`"raw"`** (slow) — rebuild every vendor database from raw first, then the
  sample → `Data/Working Files/Rebuilt_raw/`.

**Safety:** a `reference`/`raw` rebuild writes to its own `Rebuilt_*` subfolder
(`${wsdir}`) and **never overwrites the shipped Working Files**. `Sample_Creation.do`
refuses to run if `${wsdir}` equals `Data/Working Files/`.

**Run (reference/raw only):** edit `${REPL}` + `${mode}` in `setup.do`, **run
`setup.do`**, then run `0_run_sample.do`.

Pipeline (`0_run_sample.do`):
1. **Source databases** — *only when `mode = "raw"`* — each builds from its own raw
   inputs in `Data/<source>/`: `eMAXX_1998-2023.do`, `MergentFISD.do`,
   `CapitalIQ_DO.do`, `WRDS_Bond_Returns.do`, `CDS Data.do`.
2. **`Sample_Creation.do`** — merges the sources (via the `${in_*}` inputs that
   `setup.do` resolves per mode) into the bond × fund × firm × quarter panel and
   writes `SampleFinalCDS(.dta)` and `_WV(.dta)` into `${wsdir}`.

`Build_Master.do` (derives the analysis variables → `_master.dta` in `${wsdir}`) is
run by **`Paper Replication/0_run_paper.do`**, not here.

`Merge_Variables.do` is a reference catalog of optional merges (not run by the pipeline).

⚠️ This path **never** overwrites the four frozen reference inputs.
