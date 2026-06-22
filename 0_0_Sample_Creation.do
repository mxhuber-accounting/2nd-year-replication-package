

* ============= PATHS =============

global root "/Users/matthiashuber/Library/CloudStorage/Dropbox-HECPARIS/Matthias Huber/Replication Package/Data"
global eMAXX "${root}/eMAXX"         
        
* =====================================

********************************************************************
*** Step 1 -- eMAXX corporate holdings panel
********************************************************************

use "${eMAXX}/HOLDING_Complete.dta", clear

keep if regexm(issuecus, "^[A-Za-z0-9]+$")  // alhpanumeric CUSIPs only
drop if firmid == "CO-MANAGED"

* Restrict to corporate market via SECMAST
merge m:1 issuecus qdate using "${eMAXX}/SECMAST_Complete.dta", ///
    keepusing(market qmaturity qissuance) ///
    keep(master match) nogen
keep if market == "C"
drop market

* Fund Variables
merge m:1 fundid qdate using "${eMAXX}/FUND_Complete.dta", ///
    keepusing(fundclass fund_country fundname) ///
    keep(master match) nogen

* Investment Management Variables
merge m:1 firmid qdate using "${eMAXX}/FIRM_Complete.dta", ///
    keepusing(firm_code firm_country) ///
    keep(master match) nogen
	
* Issuer Variables

merge m:1 issuercus qdate using "${eMAXX}/ISSUERS_Complete.dta", ///
    keepusing(issuer_geocode issuer_creditsec) ///
    keep(master match) nogen


********************************************************************
*** Step 2 -- Merge MergentFISD Ratings
********************************************************************

merge m:1 issuecus qdate using "${root}/MergentFISD_QuarterlyPanel.dta", ///
    keepusing(issuercus parent_id Off_Date Mat_Date offering_amt bond_type   ///
              SPR_num SPRchange MR_num MRchange FR_num FRchange coupon callable ///
              private_placement preferred_security preferred_stock_issuance  ///
              convertible) ///
    keep(master match) nogen


********************************************************************
*** Step 3 -- WRDS Bond Returns: amount outstanding, yield, t-spread
********************************************************************

merge m:1 issuecus qdate using "${root}/WRDS_Bond_Returns.dta", ///
    keepusing(amount_outstanding yield t_spread t_volume) ///
    keep(master match) nogen


********************************************************************
*** Step 4 -- CapitalIQ Issuer Ratings and Outlooks
********************************************************************

merge m:1 issuercus qdate using "${root}/CapitalIQ_Final.dta", ///
    keepusing(outlook_deterioration outlook_improvement                ///
              watch_deterioration watch_improvement) ///
    keep(master match) nogen

********************************************************************
*** Step 5 -- Markit CDS 
********************************************************************

merge m:1 issuercus qdate using "${root}/CDS_2012_2020_GVKEY-CUSIP.dta", ///
    keepusing(CDS_spread) ///
    keep(master match) nogen

********************************************************************
*** Step 6 -- Bond-level derived variables
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


********************************************************************
*** Step 7 -- Detailed fundtype classification (Goyal et al. (2024))
********************************************************************

// Generate Passive/ Active Fund Classification 
gen fundname_l = lower(fundname)
gen byte passive = regexm(fundname_l, ///
    "index|indx|etf|etn|exchange|bloomberg|ftse|boxx|ishares.*bond")
drop fundname_l
// Goyal et al (2024): The list of keywords includes (1) words related to ETFs and index fund names (e.g., INDEX, INDX, ETF, ETN, EXCHANGE); (2) words related to bond index providers (e.g., BLOOMBERG, FTSE, BOXX, ISHARES%BOND%).
// Bretscher et al. (2026): ETFs and indexers, we do a keyword search (e.g., we search for phrases such as "ETF", "index", "exchange")



// Fund Types following Bretscher et al. (2026)

gen fundtype_det = ""
replace fundtype_det = "INS_life"  if inlist(fundclass, "LIN")
replace fundtype_det = "INS_prop"  if inlist(fundclass, "PIN")
replace fundtype_det = "INS_other" if inlist(fundclass, "INS", "RIN", "HLC")
replace fundtype_det = "MUT_act" if inlist(fundclass, "BAL","MMM","MUT", ///
                                            "END","QUI","FOF","UIT") & passive == 0
replace fundtype_det = "MUT_pas" if inlist(fundclass, "BAL","MMM","MUT", ///
                                            "END","QUI","FOF","UIT") & passive == 1
replace fundtype_det = "VA"      if inlist(fundclass, "ANN","AMM")
replace fundtype_det = "PEN"       if inlist(fundclass, "CPF", "GPE", "UPE")
replace fundtype_det = "OTHER"     if missing(fundtype_det)
encode fundtype_det, gen(fundtype_det_num)
label variable fundtype_det     "Detailed fund type (string)"
label variable fundtype_det_num "Detailed fund type (numeric)"

********************************************************************
*** Step 8 -- Broad Sample Save
********************************************************************

compress
save "${root}/eMAXXMergentFISD_SampleFinalCDS.dta", replace



********************************************************************
*** Step 9 -- Sample restrictions
********************************************************************

use "${root}/eMAXXMergentFISD_SampleFinalCDS.dta", clear

* Sample window from 2012q1 
drop if qdate < tq(2012q1)

* Drop bonds without any rating in any agency
drop if (missing(SPR_num) | SPR_num == 0)  ///
      & (missing(MR_num)  | MR_num  == 0)  ///
      & (missing(FR_num)  | FR_num  == 0)  ///

drop if firmid == 00000 // unidenfifiable Management Firm

* Becker and Ivashina (2015) bond-type restrictions
drop if convertible              == "Y"
drop if preferred_security       == "Y"
drop if preferred_stock_issuance == "Y"
* drop if private_placement      == "Y"        // optional

* Corporate debenture / MTN filter 
keep if inlist(bond_type, "CDEB", "CMTN", "CMTZ", "CZ")

* Minimum issue size at $50m
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
* amount outstanding, the entire bond-quarter is dropped
bysort issueID qdate: egen _agg_paramt   = total(paramt)
gen byte _viol_indiv = (paramt > amount_outstanding) & !missing(paramt)
gen byte _viol_aggr  = (_agg_paramt > amount_outstanding) & !missing(_agg_paramt)
bysort issueID qdate: egen byte _bad_bq  = max(_viol_indiv | _viol_aggr)
drop if _bad_bq == 1
drop _agg_paramt _viol_indiv _viol_aggr _bad_bq


********************************************************************
*** Step 10 -- Entry / exit indicators
***   Defined on the bond x fund x firm panel.
***   entry = 1 in the first quarter the fund-firm holds the bond.
***   exit  = 1 in the last  quarter the fund-firm holds the bond.
********************************************************************

xtset, clear
bysort issueID fundid firmid (qdate): gen byte entry = (_n == 1)
bysort issueID fundid firmid (qdate): gen byte exit  = (_n == _N)
replace entry = 0 if entry == 1 & qdate == tq(2012q1)
replace exit = 0 if exit == 1 & qdate == qmat
label variable entry "First quarter fund-firm holds the bond (sample-wide)"
label variable exit  "Last quarter fund-firm holds the bond (sample-wide)"


********************************************************************
*** Step 11 -- Outcome variables in basis points of offering amount
***   Scaling: x 10000.  Winsorized at 1/99 within fundtype_det_num.
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

* Winsorize within fundtype_det_num 
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
*** Step 12 -- Downgrade indicators and bond-level rating helpers
********************************************************************

foreach agency in SPR MR FR {
    gen byte Downgrade`agency' = (`agency'change < 0) if !missing(`agency'change)
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
*** Step 13 -- Keep only relevant variables
********************************************************************

keep issueID issuerID fundid firmid qdate                                ///
     issuecus issuercus parent_id                                        ///
     fundtype_det_num fundclass passive                     ///
     firm_code firm_country issuer_geocode issuer_creditsec_num          ///
     paramt amount_outstanding offering_amt                              ///
     net_change net_change_bp gross_buys_bp gross_sells_bp               ///
     entry exit                                                          ///
     SPR_num MR_num FR_num SPRchange MRchange FRchange                   ///
     DowngradeSPR DowngradeMR DowngradeFR                                ///
     agency_count rating_split                                           ///
     Off_Date Mat_Date qoffering ttm qmat                          ///
     outlook_deterioration outlook_improvement                           ///
     watch_deterioration watch_improvement                               ///
     CDS_spread yield t_spread t_volume

order issueID issuerID fundid firmid qdate fundtype_det_num


********************************************************************
*** Step 14 -- Save the final working file consumed by 0_Build_Master
********************************************************************

compress
save "${root}/eMAXXMergentFISD_SampleFinalCDS_WV.dta", replace

********************************************************************
*** End
********************************************************************

use "${root}/eMAXXMergentFISD_SampleFinalCDS_WV.dta", clear


