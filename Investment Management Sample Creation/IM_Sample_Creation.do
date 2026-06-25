********************************************************************************
*** IM_Sample_Creation.do  --  INVESTMENT MANAGEMENT SAMPLE
***
*** Final, OPTIONAL sample-construction step. Attaches eMAXX PERSONNEL
*** (portfolio managers / investment-management staff) to the working sample
*** produced by  Sample Replication/Sample_Creation.do.
***
*** WHY joinby (not merge):
***   PERSONNEL_Complete is at the  empid x fund x firm x quarter  level, with
***   MULTIPLE managers per fund-firm-quarter. The using side is therefore NOT
***   unique on (fundid firmid qdate), so a 1:1 / m:1 merge is impossible. We
***   use joinby (m:m) so each holding is paired with every manager of that
***   fund-firm-quarter. Perfect matches are not expected for every fund-firm-
***   quarter, so unmatched(master) keeps holdings that have no personnel row.
***
*** GRAIN switch (top of file):
***   "manager" : joinby -> one row per  holding x manager  (panel EXPANDS;
***               this can be VERY large -- _WV times managers-per-firm).
***   "team"    : collapse personnel to a fund-firm-quarter team summary, then
***               merge m:1 (panel size unchanged; counts/indicators only).
***
*** Keys line up by type: fundid (long), firmid (long, destring'd in
*** Sample_Creation), qdate (int) in both _WV and PERSONNEL_Complete.
***
*** Input :  ${working}/eMAXXMergentFISD_SampleFinalCDS_WV.dta   (Sample_Creation)
***          ${emaxx}/PERSONNEL_Complete.dta                     (eMAXX build)
*** Output:  ${working}/PERSONNEL_FundFirmQtr.dta                (dedup'd personnel)
***          ${working}/eMAXXMergentFISD_IM_Sample.dta           (the IM sample)
***
*** Run setup.do first (defines ${working}, ${emaxx}). No 'cd' needed.
********************************************************************************

if "${REPL}" == "" {
    di as error "Run setup.do first (edit its REPL line, then execute it), then run this file."
    exit 198
}

clear all
set more off
set varabbrev off
version 17

* ------------------------------- GRAIN ------------------------------------
local grain "manager"          // "manager" (joinby) | "team" (collapse + m:1)
* --------------------------------------------------------------------------


********************************************************************************
*** 1) Personnel: dedup to manager level, classify investment-management roles
***    PERSONNEL_Complete: empid x fund x firm x quarter (one row per posting).
********************************************************************************

use empid fundid firmid qdate job_code title ///
    using "${emaxx}/PERSONNEL_Complete.dta", clear

* one row per manager per fund-firm-quarter (drop duplicate postings)
bysort fundid firmid qdate empid (job_code): keep if _n == 1

* Investment-management role flags from the eMAXX 3-letter job_code.
* (First-pass taxonomy -- refine the code lists as needed.)
gen byte is_pm       = (substr(job_code,1,2) == "PM")                          // portfolio managers: PMG, PMH, PMB, ...
gen byte is_cio      = (job_code == "CIO")                                     // chief investment officer
gen byte is_head     = inlist(job_code,"HFI","DFC","BDH","RDH","TDH","TFH") ///
                     | inlist(job_code,"TBH","DOH","RGH","QRH","GDF")          // desk / fixed-income / research heads
gen byte is_research = (substr(job_code,1,2) == "RA") ///
                     | inlist(job_code,"RDH","RDY","RDC","ECO","QRH")          // research analysts / economists
gen byte is_trader   = (substr(job_code,1,2) == "TB") | (substr(job_code,1,2) == "TR") ///
                     | inlist(job_code,"TEM","TIG","TPF","TPD","TDB","THP")    // traders
gen byte is_exec     = inlist(job_code,"CEO","CFO","COO","CHR","PRE")          // non-investment executives (excluded from is_im)
gen byte is_im       = is_pm | is_cio | is_head | is_research | is_trader      // any investment-management professional

label var is_pm       "Portfolio manager (PM* job_code)"
label var is_cio      "Chief investment officer"
label var is_head     "Investment desk / FI / research head"
label var is_research "Research analyst / economist"
label var is_trader   "Trader"
label var is_exec     "Non-investment executive"
label var is_im       "Investment-management professional (PM/CIO/head/research/trader)"

compress
save "${working}/PERSONNEL_FundFirmQtr.dta", replace

if "`grain'" == "team" {
    * one row per fund-firm-quarter: team size + role counts / indicators
    collapse (count) n_personnel = empid     ///
             (sum)   n_pm = is_pm n_im = is_im n_research = is_research n_trader = is_trader ///
             (max)   any_pm = is_pm any_cio = is_cio any_im = is_im, ///
             by(fundid firmid qdate)
    label var n_personnel "Personnel count (fund-firm-quarter)"
    label var n_pm        "Portfolio-manager count (fund-firm-quarter)"
    label var n_im        "Investment-management staff count (fund-firm-quarter)"
    label var any_pm      "Has >=1 portfolio manager (fund-firm-quarter)"
    label var any_im      "Has >=1 investment-management professional"
    tempfile team
    save `team'
}


********************************************************************************
*** 2) Attach personnel to the working sample (keys: fundid firmid qdate)
********************************************************************************

use "${working}/eMAXXMergentFISD_SampleFinalCDS_WV.dta", clear

if "`grain'" == "manager" {
    * m:m -> one row per holding x manager; keep holdings without a manager
    joinby fundid firmid qdate using "${working}/PERSONNEL_FundFirmQtr.dta", ///
        unmatched(master) _merge(_mrg_pers)
    label define _mrgpL 1 "holding only" 3 "holding + manager", replace
    label values _mrg_pers _mrgpL
    label var _mrg_pers "Personnel join outcome"
}
else {
    merge m:1 fundid firmid qdate using `team', keep(master match) gen(_mrg_pers)
    foreach v in n_personnel n_pm n_im n_research n_trader {
        replace `v' = 0 if missing(`v')
    }
    foreach v in any_pm any_cio any_im {
        replace `v' = 0 if missing(`v')
    }
}

* ---- match diagnostics ----
di as result _n "==== Investment Management Sample: join diagnostics (grain = `grain') ===="
qui count
di as result "Rows in IM sample : " %15.0fc r(N)
tab _mrg_pers


********************************************************************************
*** 3) Save the investment management sample
********************************************************************************

compress
save "${working}/eMAXXMergentFISD_IM_Sample.dta", replace
di as result "Saved: ${working}/eMAXXMergentFISD_IM_Sample.dta"
