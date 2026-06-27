********************************************************************
*** Sample_Creation.do
***
*** Builds the disaggregated bond x fund x firm x quarter sample by merging
*** eMAXX holdings with MergentFISD ratings + bond characteristics, ISSUERS,
*** WRDS Bond Returns, CapitalIQ outlook/watch, and Markit CDS. Produces:
***
***   ${working}/eMAXXMergentFISD_SampleFinalCDS.dta
***       broad merged sample (post-merge, pre-restriction). Used by
***       1_Descriptives.do (Table 1 "Full eMAXX Sample" row) and as the
***       starting point for the sample restrictions.
***
***   ${working}/eMAXXMergentFISD_SampleFinalCDS_WV.dta
***       final working file (restrictions + winsorized outcomes). Consumed
***       by Build_Master.do and 1_Descriptives.do.
***
*** ----------------------------------------------------------------------
*** REPRODUCTION MODE (set in setup.do):
***   reference  -> the vendor inputs ${in_mergent} ${in_wrds} ${in_capiq}
***                 ${in_cds} are the FROZEN reference files.
***   raw        -> they are the freshly rebuilt source outputs.
*** eMAXX appended files (*_Complete.dta) are always read from ${emaxx}.
***
*** The MergentFISD input (${in_mergent}) must be a bond-quarter panel that
*** carries BOTH ratings (SPR/MR/FR) AND bond characteristics (bond_type,
*** Off_Date, Mat_Date, offering_amt, parent_id, issuercus, and the
*** convertible / preferred / private-placement flags). EGJ/DOM ratings are
*** not used anywhere and are never read, even if the file contains them.
***
*** Run setup.do FIRST.  No 'cd' needed (absolute paths via ${REPL}).
********************************************************************

if "${REPL}" == "" {
    di as error "Run setup.do first (edit its REPL line, then execute it)."
    exit 198
}

clear all
set more off
set varabbrev off
version 17

* ---- inputs / outputs (resolved by setup.do) ----
global comp "${emaxx}"                 // appended eMAXX *_Complete.dta
global data "${wsdir}"                 // outputs -> ${wsdir} (Rebuilt_* subfolder for reference/raw; never the shipped files)
cap mkdir "${data}"

* required globals
foreach g in emaxx working wsdir in_mergent in_wrds in_capiq in_cds {
    if "${`g'}" == "" {
        di as error "Global ${`g'} is empty -- run setup.do (and set ${mode})."
        exit 198
    }
}

* Safety: a rebuild must never overwrite the shipped Working Files.
if "${wsdir}" == "${working}" {
    di as error "Refusing to run: ${wsdir} == Data/Working Files (mode = shipped)."
    di as error "Sample creation runs only for mode = reference or raw (writes to a Rebuilt_* subfolder)."
    exit 198
}

* ---- probe the MergentFISD input for which wanted columns are present ----
quietly use "${in_mergent}" in 1, clear
qui ds
local MERGVARS `r(varlist)'
clear

* bond-characteristic + rating columns we want from MergentFISD, if present.
* EGJ/DOM are intentionally NOT requested -- they are never used downstream.
local mwant issuercus parent_id Off_Date Mat_Date offering_amt bond_type   ///
            SPR_num SPRchange MR_num MRchange FR_num FRchange              ///
            convertible preferred_security preferred_stock_issuance private_placement
local mkeep
foreach v of local mwant {
    if `: list v in MERGVARS' local mkeep `mkeep' `v'
}
di as text "MergentFISD columns merged in: `mkeep'"


********************************************************************
*** Step 1 -- eMAXX corporate holdings panel
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

* Fund classification from FUND_Complete. NOTE: the rebuilt FUND_Complete
* carries only fundclass/fundname -- 'passive' is reconstructed in Step 1b and
* the detailed fund type in Step 8; neither is merged from FUND_Complete.
merge m:1 fundid qdate using "${comp}/FUND_Complete.dta", ///
    keepusing(fundclass fund_country fundname) ///
    keep(master match) nogen

* Firm code / country from FIRM_Complete
merge m:1 firmid qdate using "${comp}/FIRM_Complete.dta", ///
    keepusing(firm_code firm_country) ///
    keep(master match) nogen

********************************************************************
*** Step 1b -- Passive-fund flag (reconstructed from fund name)
***   NOTE: the rebuilt FUND_Complete no longer carries the original
***   'passive' classification. This regex on fundname is a RECONSTRUCTION
***   (index / ETF / passive trackers) and should be verified against the
***   original coding -- it determines which mutual funds are classed
***   "Passive MF" (kept) vs "Active MF" (dropped in Build_Master).
********************************************************************

gen byte passive = 0
replace passive = 1 if regexm(upper(fundname), ///
    "INDEX|IDX| ETF|EXCHANGE TRADED|PASSIVE|TRACKER|RUSSELL|BARCLAYS AGG|BLOOMBERG AGG|S&P 500")
label variable passive "Passive fund (reconstructed from fundname) -- VERIFY"


********************************************************************
*** Step 2 -- MergentFISD ratings + bond characteristics (bond-quarter)
***   Source: ${in_mergent}  (reference = FROZEN rich panel; raw =
***   rebuilt panel). Only the wanted columns present in the file are merged
***   (see `mkeep' built above); EGJ/DOM are never requested.
********************************************************************

merge m:1 issuecus qdate using "${in_mergent}", ///
    keepusing(`mkeep') ///
    keep(master match) nogen


********************************************************************
*** Step 3 -- Issuer characteristics (geocode, industry)
********************************************************************

merge m:1 issuercus qdate using "${comp}/ISSUERS_Complete.dta", ///
    keepusing(issuer_geocode issuer_creditsec) ///
    keep(master match) nogen


********************************************************************
*** Step 4 -- WRDS Bond Returns: amount outstanding, yield, t-spread
********************************************************************

merge m:1 issuecus qdate using "${in_wrds}", ///
    keepusing(amount_outstanding yield t_spread t_volume) ///
    keep(master match) nogen


********************************************************************
*** Step 5 -- CapitalIQ outlook / watch (issuer-quarter)
********************************************************************

merge m:1 issuercus qdate using "${in_capiq}", ///
    keepusing(outlook_deterioration outlook_improvement                ///
              watch_deterioration watch_improvement) ///
    keep(master match) nogen


********************************************************************
*** Step 6 -- Markit CDS (issuer-quarter)
********************************************************************

merge m:1 issuercus qdate using "${in_cds}", ///
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

* Drop placeholder firm id while firmid is still a string, then destring.
drop if firmid == "00000"
destring firmid, replace
encode issuecus,  gen(issueID)
encode issuercus, gen(issuerID)
cap encode issuer_creditsec, gen(issuer_creditsec_num)


********************************************************************
*** Step 8 -- Detailed fundtype classification (Goyal et al. (2024))
***   1 = INS_life, 2 = INS_other, 3 = INS_prop, 4 = MUT_act,
***   5 = MUT_pas, 6 = OTHER, 7 = PEN, 8 = VA
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
********************************************************************

compress
save "${data}/eMAXXMergentFISD_SampleFinalCDS.dta", replace


********************************************************************
*** Step 10 -- Sample restrictions
********************************************************************

* Sample window: 2012q1 onwards
drop if qdate < tq(2012q1)

* Drop bonds without any S&P / Moody's / Fitch rating
drop if (missing(SPR_num) | SPR_num == 0)  ///
      & (missing(MR_num)  | MR_num  == 0)  ///
      & (missing(FR_num)  | FR_num  == 0)

* Becker and Ivashina (2015) bond-type restrictions (only if the flag exists)
cap confirm variable convertible
if !_rc drop if convertible == "Y"
cap confirm variable preferred_security
if !_rc drop if preferred_security == "Y"
cap confirm variable preferred_stock_issuance
if !_rc drop if preferred_stock_issuance == "Y"

* Corporate debenture / MTN filter (requires bond_type)
cap confirm variable bond_type
if !_rc keep if inlist(bond_type, "CDEB", "CMTN", "CMTZ", "CZ")

* Minimum issue size: $50m (Mergent FISD offering_amt is in $ thousands)
drop if missing(offering_amt) | offering_amt < 50000

* US issuers only
keep if issuer_geocode == "USA"

* Drop financials (creditsec starting with "F") and structured (STR)
drop if substr(issuer_creditsec, 1, 1) == "F"
drop if issuer_creditsec == "STR"

* Require non-missing amount outstanding for scaling
drop if missing(amount_outstanding) | amount_outstanding <= 0

* Drop bond-quarters where holdings exceed amount outstanding (data errors)
bysort issueID qdate: egen _agg_paramt   = total(paramt)
gen byte _viol_indiv = (paramt > amount_outstanding) & !missing(paramt)
gen byte _viol_aggr  = (_agg_paramt > amount_outstanding) & !missing(_agg_paramt)
bysort issueID qdate: egen byte _bad_bq  = max(_viol_indiv | _viol_aggr)
drop if _bad_bq == 1
drop _agg_paramt _viol_indiv _viol_aggr _bad_bq


********************************************************************
*** Step 11 -- Entry / exit indicators
********************************************************************

xtset, clear
bysort issueID fundid firmid (qdate): gen byte entry = (_n == 1)
bysort issueID fundid firmid (qdate): gen byte exit  = (_n == _N)
label variable entry "First quarter fund-firm holds the bond (sample-wide)"
label variable exit  "Last quarter fund-firm holds the bond (sample-wide)"


********************************************************************
*** Step 12 -- Outcome variables (basis points of offering amount)
***   (a) net_change-based flows  (gross buys/sells from eMAXX net_change)
***   (b) delta_holdings family   (q-on-q change in paramt) -- REQUIRED by
***       Build_Master.do. Missing in the first observed quarter of each
***       bond-fund-firm panel. Winsorized 1/99 within fundtype_det_num.
********************************************************************

* (a) net_change-based flows
gen double net_change_bp_raw  = (net_change / offering_amt) * 10000
gen double pos                = max(net_change, 0)
gen double neg                = max(-net_change, 0)
gen double gross_buys_bp_raw  = (pos / offering_amt) * 10000
gen double gross_sells_bp_raw = (neg / offering_amt) * 10000
drop pos neg

gen double net_change_bp  = net_change_bp_raw
gen double gross_buys_bp  = gross_buys_bp_raw
gen double gross_sells_bp = gross_sells_bp_raw

* (b) delta holdings: q-on-q change in paramt, bp of offering amount
sort issueID fundid firmid qdate
by issueID fundid firmid (qdate): gen double _dpar = paramt - paramt[_n-1] if _n > 1
gen double delta_holdings     = (_dpar / offering_amt) * 10000
gen double neg_delta_holdings = max(-delta_holdings, 0)          // absolute negative, non-winsorized
drop _dpar

* Winsorize within fundtype_det_num (manual loop -- winsor2 has no by())
levelsof fundtype_det_num, local(ftypes)
foreach v in net_change_bp gross_buys_bp gross_sells_bp delta_holdings {
    foreach t of local ftypes {
        qui sum `v' if fundtype_det_num == `t', detail
        local p1  = r(p1)
        local p99 = r(p99)
        qui replace `v' = `p1'  if fundtype_det_num == `t' & `v' < `p1'  & !missing(`v')
        qui replace `v' = `p99' if fundtype_det_num == `t' & `v' > `p99' & !missing(`v')
    }
}
gen double pos_delta_holdings = max(delta_holdings, 0)           // positive component of winsorized delta

label variable net_change_bp      "Net change in holdings (bp of offering amount, winsorized 1/99 by fundtype)"
label variable gross_buys_bp      "Gross buys (bp of offering amount, winsorized 1/99 by fundtype)"
label variable gross_sells_bp     "Gross sells (positive bp of offering amount, winsorized 1/99 by fundtype)"
label variable delta_holdings     "Change in holdings (bp of offering, winsorized 1/99 by fundtype)"
label variable pos_delta_holdings "Positive change (bp of offering, winsorized 1/99 by fundtype)"
label variable neg_delta_holdings "Negative change, absolute (bp of offering, non-winsorized)"


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
*** Step 14 -- Keep the variables consumed downstream
***   (Build_Master.do, 1_Descriptives.do, 2_/2c_/3_ analysis)
***   Use Merge_Variables.do to add anything extra later.
********************************************************************

keep issueID issuerID fundid firmid qdate                                ///
     fundtype_det_num fundclass passive                                  ///
     parent_id issuercus issuecus                                        ///
     firm_code firm_country issuer_geocode issuer_creditsec_num          ///
     paramt net_change amount_outstanding offering_amt                   ///
     Off_Date Mat_Date qoffering qmat ttm                                ///
     SPR_num MR_num FR_num SPRchange MRchange FRchange                   ///
     DowngradeSPR DowngradeMR DowngradeFR agency_count rating_split      ///
     net_change_bp gross_buys_bp gross_sells_bp                          ///
     delta_holdings pos_delta_holdings neg_delta_holdings                ///
     entry exit                                                          ///
     yield t_spread t_volume                                             ///
     outlook_deterioration outlook_improvement                          ///
     watch_deterioration watch_improvement                               ///
     CDS_spread

order issueID issuerID fundid firmid qdate fundtype_det_num


********************************************************************
*** Step 15 -- Save the final working file consumed by Build_Master.do
********************************************************************

compress
save "${data}/eMAXXMergentFISD_SampleFinalCDS_WV.dta", replace


********************************************************************
*** End
********************************************************************
