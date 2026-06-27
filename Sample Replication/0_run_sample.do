********************************************************************************
*** 0_run_sample.do  --  BUILD THE WORKING SAMPLE
***
*** Builds the working sample according to  global mode  (set in setup.do).
*** Output goes to  ${wsdir}  -- for a rebuild this is a Rebuilt_* subfolder of
*** Data/Working Files/, so the SHIPPED working files are NEVER overwritten.
***
***   mode = "shipped"   -> nothing to build; the paper uses the prebuilt files.
***   mode = "reference" -> Sample_Creation reads the FROZEN reference files
***                         -> Data/Working Files/Rebuilt_reference/
***   mode = "raw"       -> rebuild every vendor database from raw, then sample
***                         -> Data/Working Files/Rebuilt_raw/   (slow)
***
*** HOW TO RUN: (1) in setup.do set ${REPL} and ${mode}, (2) run setup.do,
***             (3) run this file. Then run Paper Replication/0_run_paper.do.
********************************************************************************

if "${REPL}" == "" {
    di as error "Run setup.do first (edit its REPL line + choose ${mode}), then run this file."
    exit 198
}

di as text  "{hline 78}"
di as result "  BUILD WORKING SAMPLE   --   mode = ${mode}   ->   ${wsdir}"
di as text  "{hline 78}"

if "${mode}" == "shipped" {
    di as result "  mode = shipped: the paper uses the PREBUILT sample in Data/Working Files/."
    di as text   "  Nothing to build here -- go straight to Paper Replication/0_run_paper.do."
}
else {
    * ---- 1) Source databases: ONLY when rebuilding from raw ----------------
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

    * ---- 2) Sample construction (writes to ${wsdir}, a Rebuilt_* subfolder) -
    do "${REPL}/Sample Replication/Sample_Creation.do"

    di as result "Working sample built (mode = ${mode}) -> ${wsdir}."
    di as result "Now run Paper Replication/0_run_paper.do (it reads ${wsdir})."
}
