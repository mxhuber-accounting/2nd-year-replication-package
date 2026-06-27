********************************************************************************
*** 0_run_paper.do  --  PAPER ANALYSIS  (reproduction Option ii: start here)
***
*** Builds the estimation master (_WV.dta -> _master.dta via Build_Master.do)
*** and then produces every figure and table in the paper. With the shipped
*** working files this is the only run-file you need.
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

* The paper run reads the working sample chosen in setup.do (${mode}) from ${wsdir}.
di as text  "{hline 78}"
di as result "  PAPER RUN   --   working sample: mode = ${mode}   (${wsdir})"
di as text  "{hline 78}"
capture confirm file "${wsdir}/eMAXXMergentFISD_SampleFinalCDS_WV.dta"
if _rc {
    di as error "No _WV.dta found in ${wsdir}."
    di as error "For mode = reference or raw, run Sample Replication/0_run_sample.do first."
    exit 601
}

global C "${REPL}/Paper Replication/Code"

* Build the estimation master file from the working sample (_WV.dta -> _master.dta)
do "${REPL}/Sample Replication/Build_Master.do"

do "${C}/1_Descriptives.do"
do "${C}/2_Baseline_Analysis.do"
do "${C}/2c_Baseline_Analysis_Extensive.do"
do "${C}/3_Disaggregated_Threshold.do"
// do "${C}/Baseline_Analysis_Extensive_UPGRADE.do" // not necessary
// do "${C}/Robustness/Downgrade vs. Upgrade.do" // not necessary

di as result "Paper replication complete. See Paper Replication/Figures and Tables/."
