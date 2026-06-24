********************************************************************************
*** 0_run_paper.do  --  PAPER ANALYSIS  (reproduction Option ii: start here)
***
*** Produces every figure and table in the paper from the estimation master
*** file Data/Working Files/_master.dta. If you are using the shipped working
*** files (the default), this is the only run-file you need.
***
*** HOW TO RUN:  (1) edit the ${REPL} line in setup.do, (2) run setup.do,
***              (3) run this file.  No 'cd' needed -- setup.do uses absolute paths.
***
*** Requires the user-written command grc1leg (3_Disaggregated_Threshold):
***   net install grc1leg, from("http://www.stata.com/users/vwiggins")
***
*** Outputs are written to Paper Replication/Figures and Tables/<section>/.
********************************************************************************

* setup.do must be run FIRST (it sets ${REPL} and all paths; works from any
* working directory). This orchestrator assumes those globals are already set.
if "${REPL}" == "" {
    di as error "Run setup.do first (edit its REPL line, then execute it), then run this file."
    exit 198
}

global C "${REPL}/Paper Replication/Code"

do "${C}/1_Descriptives.do"
do "${C}/2_Baseline_Analysis.do"
do "${C}/2c_Baseline_Analysis_Extensive.do"
do "${C}/3_Disaggregated_Threshold.do"
// do "${C}/Baseline_Analysis_Extensive_UPGRADE.do" // not necessary
// do "${C}/Robustness/Downgrade vs. Upgrade.do" // not necessary

di as result "Paper replication complete. See Paper Replication/Figures and Tables/."
