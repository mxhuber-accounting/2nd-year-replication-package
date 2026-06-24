********************************************************************************
*** 0_run_sample.do  --  FULL DATA CONSTRUCTION  (reproduction Option i)
***
*** Rebuilds every source database FROM RAW, then constructs the sample and the
*** estimation master file. This is the slow path: it reads tens of GB of raw
*** vendor data and takes several hours end to end.
***
*** HOW TO RUN:  in Stata, set the working directory to the package root, e.g.
***                cd "/path/to/Replication Package"
***              edit the ${REPL} line in setup.do, set  global mode "regenerate",
***              then run this file.
***
*** Source build do-files live next to their data in Data/<source>/ and each
*** reads its own Raw Data/. Outputs go to Data/<source>/ and Data/Working Files/.
*** The four FROZEN reference files in Data/ root are never written here.
********************************************************************************

do "setup.do"

* ---- 1) Source databases (each self-contained; reads its own Raw Data/) ----
do "${emaxx}/eMAXX_1998-2023.do"          // eMAXX *_Complete.dta            (hours)
do "${mergent}/MergentFISD.do"            // MergentFISD rating panels + IssuesLookup
do "${capiq}/CapitalIQ_DO.do"             // CapitalIQ_Final  (needs CIQ-CUSIP.csv in Raw Data)
do "${wrds}/WRDS_Bond_Returns.do"         // WRDS_Bond_Returns
do "${markit}/CDS Data.do"                // Markit CDS panel               (~35-50 min)

* ---- 2) Sample construction ------------------------------------------------
do "${REPL}/Sample Replication/Sample_Creation.do"   // -> Working Files: SampleFinalCDS(.dta), _WV(.dta)
do "${REPL}/Sample Replication/Build_Master.do"      // -> Working Files: _master.dta

di as result "Sample replication complete. Proceed to '2 run' the Paper Replication."
