********************************************************************************
*** 0_run_paper.do  --  PAPER ANALYSIS  (reproduction Option ii: start here)
***
*** Produces every figure and table in the paper from the estimation master
*** file Data/Working Files/_master.dta. If you are using the shipped working
*** files (the default), this is the only run-file you need.
***
*** HOW TO RUN:  in Stata, set the working directory to the package root, e.g.
***                cd "/path/to/Replication Package"
***              edit the ${REPL} line in setup.do, then run this file.
***
*** Requires the user-written command grc1leg (3_Disaggregated_Threshold):
***   net install grc1leg, from("http://www.stata.com/users/vwiggins")
***
*** Outputs are written to Paper Replication/Figures and Tables/<section>/.
********************************************************************************

do "setup.do"

global C "${REPL}/Paper Replication/Code"

do "${C}/1_Descriptives.do"
do "${C}/2_Baseline_Analysis.do"
do "${C}/2c_Baseline_Analysis_Extensive.do"
do "${C}/3_Disaggregated_Threshold.do"
do "${C}/Baseline_Analysis_Extensive_UPGRADE.do"
do "${C}/Robustness/Downgrade vs. Upgrade.do"

di as result "Paper replication complete. See Paper Replication/Figures and Tables/."
