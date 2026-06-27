********************************************************************************
*** 0_run_im_sample.do  --  INVESTMENT MANAGEMENT SAMPLE (orchestrator)
***
*** Builds the investment management sample: takes the working sample from
*** Sample Replication (eMAXXMergentFISD_SampleFinalCDS_WV.dta) and attaches
*** eMAXX PERSONNEL (portfolio-manager) data via joinby.
***
*** HOW TO RUN:  (1) edit the ${REPL} line in setup.do, (2) run setup.do,
***              (3) run this file.  No 'cd' needed -- absolute paths.
***
*** Prerequisite: the working sample (chosen by ${mode}) must already exist in
*** ${wsdir} -- i.e. the shipped _WV for mode=shipped, or a completed
*** 0_run_sample.do rebuild for mode=reference/raw.
********************************************************************************

if "${REPL}" == "" {
    di as error "Run setup.do first (edit its REPL line, then execute it), then run this file."
    exit 198
}

do "${REPL}/Investment Management Sample Creation/IM_Sample_Creation.do"

di as result "Investment management sample complete. See ${wsdir}/eMAXXMergentFISD_IM_Sample.dta."
