********************************************************************
*** 0_1_Master Working File
********************************************************************

* ============= SET PATHS =============
global root "/Users/matthiashuber/Library/CloudStorage/Dropbox-HECPARIS/Matthias Huber/Replication Package/Data"
global eMAXX "${root}/eMAXX" 
* =====================================

use "${root}/eMAXXMergentFISD_SampleFinalCDS_WV.dta", clear

* Drop Active Mutual Funds
drop if fundtype_det_num == 4
keep if inlist(fundtype_det_num, 1, 2, 3, 5, 8)

* Investor coding 
cap drop PassiveInvestor
gen PassiveInvestor = 0
replace PassiveInvestor = 1 if fundtype_det_num == 5
replace PassiveInvestor = 2 if fundtype_det_num == 1
replace PassiveInvestor = 3 if fundtype_det_num == 2
replace PassiveInvestor = 4 if fundtype_det_num == 3
replace PassiveInvestor = 5 if fundtype_det_num == 8
label define PassiveInvestor_lb 0 "Other" 1 "Passive MF" 2 "Life Insurer" ///
    3 "Other Insurer" 4 "P&C Insurer" 5 "VA", replace
label values PassiveInvestor PassiveInvestor_lb
label variable PassiveInvestor "Investor Type"

* Constr_Investor 
cap drop Constr_Investor
gen Constr_Investor = .
replace Constr_Investor = 0 if fundtype_det_num == 5
replace Constr_Investor = 1 if fundtype_det_num == 1
replace Constr_Investor = 2 if fundtype_det_num == 2
replace Constr_Investor = 3 if fundtype_det_num == 3
replace Constr_Investor = 4 if fundtype_det_num == 8
label define Constr_Investor_lb 0 "Passive MF" 1 "Life Insurer" ///
    2 "Other Insurer" 3 "P&C Insurer" 4 "VA", replace
label values Constr_Investor Constr_Investor_lb
label variable Constr_Investor "Constrained Investor Type"

* Any-agency downgrade indicator
cap drop DowngradeAny
gen byte DowngradeAny = (DowngradeSPR == 1 | DowngradeMR == 1 | DowngradeFR == 1)
label variable DowngradeAny "Any agency downgrade in this bond-quarter"

* Clean window (excludes first 2 quarters post-issuance)
cap drop Clean_Window
gen byte Clean_Window = (qdate > qoffering + 2)
label variable Clean_Window "Bond-quarter >2 quarters after issuance"

* CDS coverage indicator at bond level
cap drop CDS_data
gen byte _cds_obs = !missing(CDS_spread)
bysort issueID: egen CDS_data = max(_cds_obs)
drop _cds_obs
label variable CDS_data "Bond ever has CDS spread data"

* Investment Manager indicator 
gen byte is_INM = (firm_code == "INM")
label variable is_INM "External manager (firm_code == INM)"

* Log of amount outstanding 
cap drop log_aoutstanding
gen log_aoutstanding = log(amount_outstanding)
label variable log_aoutstanding "log(Amount Outstanding)"


********************************************************************
*** NAIC composite rating
*** 3 ratings -> median; 2 ratings -> lower (rowmax of *_num); 1 -> that one
********************************************************************

cap drop NAIC_num
gen byte _has_spr = !missing(SPR_num)
gen byte _has_mr  = !missing(MR_num)
gen byte _has_fr  = !missing(FR_num)
gen byte _n_ag    = _has_spr + _has_mr + _has_fr

gen NAIC_num = .
replace NAIC_num = SPR_num if _n_ag == 1 & _has_spr == 1
replace NAIC_num = MR_num  if _n_ag == 1 & _has_mr  == 1
replace NAIC_num = FR_num  if _n_ag == 1 & _has_fr  == 1

egen _tmp_max = rowmax(SPR_num MR_num FR_num) if _n_ag == 2
replace NAIC_num = _tmp_max if _n_ag == 2
drop _tmp_max

egen _tmp_med = rowmedian(SPR_num MR_num FR_num) if _n_ag == 3
replace NAIC_num = _tmp_med if _n_ag == 3
drop _tmp_med

drop _has_spr _has_mr _has_fr _n_ag

* Broad NAIC bucket (1 = IG, 0 = HY); cutoff at NAIC_num <= 10
gen byte naic_bucket = .
replace naic_bucket = 1 if !missing(NAIC_num) & NAIC_num <= 10
replace naic_bucket = 0 if !missing(NAIC_num) & NAIC_num >  10


********************************************************************
*** Bond-quarter NAIC event indicators
********************************************************************

preserve
    bysort issueID qdate: keep if _n == 1
    keep issueID qdate NAIC_num naic_bucket
    tsset issueID qdate

    gen L_naic   = L.NAIC_num
    gen L_bucket = L.naic_bucket

    gen byte naic_dn    = (!missing(L_naic) & NAIC_num > L_naic)
    gen byte fa         = (L_bucket == 1 & naic_bucket == 0)
    gen byte naic_dn_ig = (naic_dn == 1 & L_bucket == 1 & naic_bucket == 1)
    gen byte naic_dn_hy = (naic_dn == 1 & L_bucket == 0 & naic_bucket == 0)

    * Clean events of any same-event in the prior 8 quarters
    foreach v in naic_dn fa naic_dn_ig naic_dn_hy {
        gen pri8_`v' = 0
        forvalues k = 1/8 {
            replace pri8_`v' = pri8_`v' + cond(missing(L`k'.`v'), 0, L`k'.`v')
        }
        replace `v' = 0 if pri8_`v' > 0
        drop pri8_`v'
    }

    * First fallen-angel date per bond 
    gen _t_fa = qdate if fa == 1
    bysort issueID: egen first_fa = min(_t_fa)
    format first_fa %tq
    drop _t_fa

    keep issueID qdate naic_dn fa naic_dn_ig naic_dn_hy first_fa
    tempfile naic_events
    save `naic_events'
restore
merge m:1 issueID qdate using `naic_events', keep(master match) nogen


save "${root}/_master.dta", replace


********************************************************************
*** End
********************************************************************
