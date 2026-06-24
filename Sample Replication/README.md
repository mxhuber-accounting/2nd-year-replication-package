# Sample Replication (data construction)

Rebuilds the analysis sample **from raw vendor data** (reproduction Option i).
Set `global mode "regenerate"` in `setup.do`, **run `setup.do`**, then run
`0_run_sample.do` (no `cd` needed).

Pipeline:
1. **Source databases** — each builds from its own raw inputs and lives in
   `Data/<source>/`: `eMAXX_1998-2023.do`, `MergentFISD.do`, `CapitalIQ_DO.do`,
   `WRDS_Bond_Returns.do`, `CDS Data.do`.
2. **`Sample_Creation.do`** — merges the sources into the bond × fund × firm panel
   and writes `Data/Working Files/eMAXXMergentFISD_SampleFinalCDS(.dta)` and `_WV(.dta)`.
3. **`Build_Master.do`** — derives analysis variables and writes
   `Data/Working Files/_master.dta` (consumed by Paper Replication).

`Merge_Variables.do` is a reference catalog of optional merges (not run by the pipeline).

⚠️ This path **never** overwrites the four frozen reference files in `Data/` root.
