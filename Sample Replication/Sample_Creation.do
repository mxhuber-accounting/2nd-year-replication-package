********************************************************************
*** 0_0_Sample_Creation.do
***
*** Builds the disaggregated bond x fund x firm x quarter sample by
*** merging eMAXX holdings with MergentFISD ratings, ISSUERS, WRDS Bond
*** Returns, CapitalIQ outlook/watch, and Markit CDS. Produces the two
*** input files consumed by 0_Build_Master.do and 1_Descriptives.do:
***
***   ${data}/eMAXXMergentFISD_SampleFinalCDS.dta
***       -- broad merged sample (post-merging, pre-restriction). Used
***       only by 1_Descriptives.do row 1 of Table 1 ("Full eMAXX Sample"
***       count) and as the starting point for sample restrictions.
***
***   ${data}/eMAXXMergentFISD_SampleFinalCDS_WV.dta
***       -- final working file (restrictions + winsorized outcomes).
***       Consumed by 0_Build_Master.do and 1_Descriptives.do.
***
*** Assumes the eMAXX *Complete*.dta files have already been built by
*** appending the quarterly raw files (HOLDING_Complete.dta,
*** FUND_Complete.dta, FIRM_Complete.dta, SECMAST_Complete.dta,
*** ISSUERS_Complete.dta) and that MergentFISD_QuarterlyPanel.dta is
*** built. The Markit CDS and CapitalIQ panels are taken as already
*** prepared at the issuer-quarter level.
********************************************************************

clear all
set more off
set varabbrev off
version 17

* ============= SET PATHS =============
global root "${REPL}"
global comp "${root}/Data/eMAXX"                  // appended eMAXX *.dta
global rate "${root}/Data/MergentFISD"         // MergentFISD ratings + LSEG outlook/watch
global ciq  "${root}/Data/CapitalIQ"           // CapitalIQ outlook/watch
global wrds "${root}/Data/WRDS Bond Returns"               // WRDS bond yields, amount outstanding, spreads
global cds  "${root}/Data/Markit"                        // Markit CDS panel (issuer-quarter)
global data "${root}/Data/Working Files"                  // outputs (read by 0_Build_Master.do)
* =====================================
cap mkdir "${data}"


********************************************************************
*** Step 1 -- eMAXX corporate holdings panel
***   Source: ${comp}/HOLDING_Complete.dta (appended quarterly)
***   Restricts to corporate bonds, drops CO-MANAGED, dedups.
********************************************************************

use "${comp}/HOLDING_Complete.dta", clear

keep if regexm(issuecus, "^[A-Za-z0-9]+$")               // identifiable CUSIPs only
drop if firmid == "CO-MANAGED"
bysort issuecus fundid firmid qdate (qreport): keep if _n == 1

* Restrict to corporate market via SECMAST
merge m:1 issuecus qdate using "${comp}/SECMAST_Complete.dta", ///
    keepusing(market qmaturity qissuance) ///
    keep(master match) nogen
keep if market == "C"
drop market

* Fund classification from FUND_Complete (built by Goyal et al. (2024) coding)
merge m:1 fundid qdate using "${comp}/FUND_Complete.dta", ///
    keepusing(fundclass fundtype passive fund_country fundname) ///
    keep(master match) nogen

* Firm code / country from FIRM_Complete
merge m:1 firmid qdate using "${comp}/FIRM_Complete.dta", ///
    keepusing(firm_code firm_country) ///
    keep(master match) nogen


********************************************************************
*** Step 2 -- Merge MergentFISD ratings panel (bond-quarter)
***   Source: ${rate}/MergentFISD_QuarterlyPanel.dta
***   Brings in SPR_num, MR_num, FR_num, EGJ_num and changes, plus
***   Off_Date, Mat_Date, offering_amt, bond_type, and the
***   private_placement / preferred / convertible flags.
********************************************************************

merge m:1 issuecus qdate using "${rate}/MergentFISD_QuarterlyPanel.dta", ///
    keepusing(issuercus parent_id Off_Date Mat_Date offering_amt bond_type   ///
              SPR_num SPRchange MR_num MRchange FR_num FRchange              ///
              EGJ_num EGJchange DOM_num DOMchange coupon callable            ///
              private_placement preferred_security preferred_stock_issuance  ///
              convertible) ///
    keep(master match) nogen


********************************************************************
*** Step 3 -- Issuer characteristics (geocode, industry)
***   Source: ${comp}/ISSUERS_Complete.dta
********************************************************************

merge m:1 issuercus qdate using "${comp}/ISSUERS_Complete.dta", ///
    keepusing(issuer_geocode issuer_creditsec) ///
    keep(master match) nogen


********************************************************************
*** Step 4 -- WRDS Bond Returns: amount outstanding, yield, t-spread
***   Source: ${wrds}/WRDS_Bond_Returns.dta  (rename to your file)
********************************************************************

merge m:1 issuecus qdate using "${wrds}/WRDS_Bond_Returns.dta", ///
    keepusing(amount_outstanding yield t_spread t_volume) ///
    keep(master match) nogen


********************************************************************
*** Step 5 -- CapitalIQ outlook / watch (issuer-quarter)
***   Source: ${ciq}/CapitalIQ_Final.dta
***   Provides outlook_deterioration (referenced by 2_..._Analysis Table 5)
********************************************************************

merge m:1 issuercus qdate using "${ciq}/CapitalIQ_Final.dta", ///
    keepusing(outlook_deterioration outlook_improvement                ///
              watch_deterioration watch_improvement) ///
    keep(master match) nogen


********************************************************************
*** Step 6 -- Markit CDS (issuer-quarter)
***   Source: ${cds}/CDS_GVKEY_CUSIP.dta  (rename to your file)
********************************************************************

merge m:1 issuercus qdate using "${cds}/CDS_GVKEY_CUSIP.dta", ///
    keepusing(CDS_spread) ///
    keep(master match) nogen


********************************************************************
*** Step 7 -- Bond-level derived variables
********************************************************************

gen qoffering = qofd(Off_Date)
format qoffering %tq
gen qmat = qofd(Mat_Date)
format qmat %tq
gen ttm = (qmat - qdate) / 4
label variable ttm "Time to maturity (years)"

destring firmid, replace
encode issuecus,  gen(issueID)
encode issuercus, gen(issuerID)
cap encode issuer_creditsec, gen(issuer_creditsec_num)


********************************************************************
*** Step 8 -- Detailed fundtype classification (Goyal et al. (2024))
***   1 = INS_life, 2 = INS_other, 3 = INS_prop, 4 = MUT_act,
***   5 = MUT_pas, 6 = OTHER, 7 = PEN, 8 = VA
*** (numeric labels assigned by encode; verify the levels after first run)
********************************************************************

gen fundtype_det = ""
replace fundtype_det = "INS_life"  if inlist(fundclass, "LIN")
replace fundtype_det = "INS_prop"  if inlist(fundclass, "PIN")
replace fundtype_det = "INS_other" if inlist(fundclass, "INS", "RIN", "HLC")
replace fundtype_det = "MUT_act"   if inlist(fundclass, "ANN", "AMM", "BAL", "MMM", "MUT", ///
                                              "END", "QUI", "FOF", "UIT") & passive == 0
replace fundtype_det = "MUT_pas"   if inlist(fundclass, "ANN", "AMM", "BAL", "MMM", "MUT", ///
                                              "END", "QUI", "FOF", "UIT") & passive == 1
replace fundtype_det = "VA"        if inlist(fundclass, "ANN", "AMM")
replace fundtype_det = "PEN"       if inlist(fundclass, "CPF", "GPE", "UPE")
replace fundtype_det = "OTHER"     if missing(fundtype_det)
encode fundtype_det, gen(fundtype_det_num)
label variable fundtype_det     "Detailed fund type (string)"
label variable fundtype_det_num "Detailed fund type (numeric)"


********************************************************************
*** Step 9 -- Save the broad merged sample
***   Consumed by 1_Descriptives.do for the first row of Table 1.
********************************************************************

compress
save "${data}/eMAXXMergentFISD_SampleFinalCDS.dta", replace


********************************************************************
*** Step 10 -- Sample restrictions
********************************************************************

* Sample window: 2012q1 onwards (when WRDS / CapitalIQ coverage is reliable)
drop if qdate < tq(2012q1)

* Drop bonds without any rating in any agency
drop if (missing(SPR_num) | SPR_num == 0)  ///
      & (missing(MR_num)  | MR_num  == 0)  ///
      & (missing(FR_num)  | FR_num  == 0)  ///
      & (missing(EGJ_num) | EGJ_num == 0)  ///
      & (missing(DOM_num) | DOM_num == 0)

drop if firmid == "00000"

* Becker and Ivashina (2015) bond-type restrictions
drop if convertible              == "Y"
drop if preferred_security       == "Y"
drop if preferred_stock_issuance == "Y"
* drop if private_placement      == "Y"        // optional

* Corporate debenture / MTN filter (Tidy-Finance / Becker-Ivashina convention)
keep if inlist(bond_type, "CDEB", "CMTN", "CMTZ", "CZ")

* Minimum issue size: $50m. NOTE: Mergent FISD offering_amt is in $ thousands.
drop if missing(offering_amt) | offering_amt < 50000

* US issuers only
keep if issuer_geocode == "USA"

* Drop financials (creditsec starting with "F") and structured (STR)
drop if substr(issuer_creditsec, 1, 1) == "F"
drop if issuer_creditsec == "STR"

* Require non-missing amount outstanding for scaling
drop if missing(amount_outstanding) | amount_outstanding <= 0

* Drop bond-quarters where holdings exceed amount outstanding (data errors).
* If any single fund-firm position OR the bond-quarter aggregate exceeds the
* amount outstanding, drop the entire bond-quarter -- one corrupted row casts
* doubt on the reporting integrity of the whole bond-quarter.
bysort issueID qdate: egen _agg_paramt   = total(paramt)
gen byte _viol_indiv = (paramt > amount_outstanding) & !missing(paramt)
gen byte _viol_aggr  = (_agg_paramt > amount_outstanding) & !missing(_agg_paramt)
bysort issueID qdate: egen byte _bad_bq  = max(_viol_indiv | _viol_aggr)
drop if _bad_bq == 1
drop _agg_paramt _viol_indiv _viol_aggr _bad_bq


********************************************************************
*** Step 11 -- Entry / exit indicators
***   Defined on the bond x fund x firm panel.
***   entry = 1 in the first quarter the fund-firm holds the bond.
***   exit  = 1 in the last  quarter the fund-firm holds the bond.
********************************************************************

xtset, clear
bysort issueID fundid firmid (qdate): gen byte entry = (_n == 1)
bysort issueID fundid firmid (qdate): gen byte exit  = (_n == _N)
label variable entry "First quarter fund-firm holds the bond (sample-wide)"
label variable exit  "Last quarter fund-firm holds the bond (sample-wide)"


********************************************************************
*** Step 12 -- Outcome variables in basis points of offering amount
***   Scaling: x 10000.  Winsorized at 1/99 within fundtype_det_num.
***   Sign convention: gross_sells_bp is a positive number.
********************************************************************

gen double net_change_bp_raw = (net_change / offering_amt) * 10000
gen double pos               = max(net_change, 0)
gen double neg               = max(-net_change, 0)
gen double gross_buys_bp_raw  = (pos / offering_amt) * 10000
gen double gross_sells_bp_raw = (neg / offering_amt) * 10000
drop pos neg

gen double net_change_bp  = net_change_bp_raw
gen double gross_buys_bp  = gross_buys_bp_raw
gen double gross_sells_bp = gross_sells_bp_raw

* Winsorize within fundtype_det_num (manual loop -- winsor2 does not support by())
levelsof fundtype_det_num, local(ftypes)
foreach v in net_change_bp gross_buys_bp gross_sells_bp {
    foreach t of local ftypes {
        qui sum `v' if fundtype_det_num == `t', detail
        local p1  = r(p1)
        local p99 = r(p99)
        qui replace `v' = `p1'  if fundtype_det_num == `t' & `v' < `p1'  & !missing(`v')
        qui replace `v' = `p99' if fundtype_det_num == `t' & `v' > `p99' & !missing(`v')
    }
}

label variable net_change_bp  "Net change in holdings (bp of offering amount, winsorized 1/99 by fundtype)"
label variable gross_buys_bp  "Gross buys (bp of offering amount, winsorized 1/99 by fundtype)"
label variable gross_sells_bp "Gross sells (positive bp of offering amount, winsorized 1/99 by fundtype)"


********************************************************************
*** Step 13 -- Downgrade indicators and bond-level rating helpers
********************************************************************

foreach agency in SPR MR FR {
    cap drop Downgrade`agency'
    gen byte Downgrade`agency' = (`agency'change < 0) if !missing(`agency'change)
    replace  Downgrade`agency' = 0 if missing(Downgrade`agency')
}

gen byte agency_count = (!missing(SPR_num) & SPR_num > 0) ///
                     + (!missing(MR_num)  & MR_num  > 0) ///
                     + (!missing(FR_num)  & FR_num  > 0)
replace  agency_count = . if agency_count == 0
label variable agency_count "Count of agencies (SPR, MR, FR) with non-missing rating"

gen byte rating_split = 0
replace  rating_split = 1 if (SPR_num != MR_num) & !missing(SPR_num) & !missing(MR_num)
label variable rating_split "1 if S&P and Moody's disagree on rating"


********************************************************************
*** Step 14 -- Keep only the variables used downstream
***   (downstream = 0_Build_Master.do, 1_Descriptives.do,
***    2_Disaggregated_Analysis.do, 3_Disaggregated_Threshold.do)
***   To merge anything extra later, use the Merge_Variables.do file.
********************************************************************

keep issueID issuerID fundid firmid qdate                                ///
     issuecus issuercus parent_id                                        ///
     fundtype_det_num fundtype_det fundclass passive                     ///
     firm_code firm_country issuer_geocode issuer_creditsec_num          ///
     bond_type callable                                                  ///
     paramt amount_outstanding offering_amt                              ///
     net_change net_change_bp gross_buys_bp gross_sells_bp               ///
     entry exit                                                          ///
     SPR_num MR_num FR_num SPRchange MRchange FRchange                   ///
     DowngradeSPR DowngradeMR DowngradeFR                                ///
     agency_count rating_split                                           ///
     Off_Date Mat_Date qoffering qmat ttm coupon                         ///
     outlook_deterioration outlook_improvement                           ///
     watch_deterioration watch_improvement                               ///
     CDS_spread yield t_spread t_volume

order issueID issuerID fundid firmid qdate fundtype_det_num


********************************************************************
*** Step 15 -- Save the final working file consumed by 0_Build_Master
********************************************************************

compress
save "${data}/eMAXXMergentFISD_SampleFinalCDS_WV.dta", replace


********************************************************************
*** End
********************************************************************
