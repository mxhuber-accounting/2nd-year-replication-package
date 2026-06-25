********************************************************************************
*** 0_run_sample.do  --  BUILD THE WORKING SAMPLE
***
*** Produces  Data/Working Files/eMAXXMergentFISD_SampleFinalCDS_WV.dta  from one
*** of two sources, chosen by  global mode  in setup.do:
***
***   mode = "reference"  -> read the FROZEN reference vendor files in
***                          Data/Reference Files/  (fast; no source builds).
***   mode = "raw"        -> rebuild every vendor database FROM RAW first
***                          (eMAXX, MergentFISD, WRDS, Markit, CapitalIQ),
***                          then build the sample (slow, several hours).
***
*** HOW TO RUN:  (1) in setup.do edit ${REPL} and set ${mode}, (2) run setup.do,
***              (3) run this file.  Then run Paper Replication/0_run_paper.do.
***              No 'cd' needed -- absolute paths via ${REPL}.
********************************************************************************

if "${REPL}" == "" {
    di as error "Run setup.do first (edit its REPL line + choose ${mode}), then run this file."
    exit 198
}

di as text  "{hline 78}"
di as result "  BUILD WORKING SAMPLE   --   source = ${mode}"
di as text  "{hline 78}"

* ---- 1) Source databases: ONLY when rebuilding from raw --------------------
if "${mode}" == "raw" {
    di as text "  mode = raw: rebuilding every vendor database from raw data..."
    do "${emaxx}/eMAXX_1998-2023.do"          // eMAXX *_Complete.dta            (hours)
    do "${mergent}/MergentFISD.do"            // MergentFISD rating+characteristics panel
    do "${capiq}/CapitalIQ_DO.do"             // CapitalIQ_Final  (needs CIQ-CUSIP.csv)
    do "${wrds}/WRDS_Bond_Returns.do"         // WRDS_Bond_Returns
    do "${markit}/CDS Data.do"                // Markit CDS panel               (~35-50 min)
}
else {
    di as text "  mode = reference: using the FROZEN reference files (no source builds)."
}

* ---- 2) Sample construction (reads the ${in_*} inputs resolved by setup.do) -
do "${REPL}/Sample Replication/Sample_Creation.do"   // -> Working Files/_WV (and SampleFinalCDS)

di as result "Working sample built (source = ${mode}). Now run Paper Replication/0_run_paper.do."
