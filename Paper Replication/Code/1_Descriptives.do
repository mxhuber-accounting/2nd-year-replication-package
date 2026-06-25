********************************************************************
*** 1_Descriptives.do
***
*** Input:  ${data}/eMAXXMergentFISD_SampleFinalCDS.dta     (raw, row 1)
***         ${data}/eMAXXMergentFISD_SampleFinalCDS_WV.dta  (working file)
*** Output: ${out}/Figure[1-5]_*.png
***         ${out}/Table[1,3,4,5]_*.docx
***         ${data}/_event_sample_main.dta                  (intermediate)
***
*** Main outcome: delta_holdings (bp of offering, winsorized 1/99 by fundtype).
*** delta_holdings, pos_delta_holdings, neg_delta_holdings are built and
*** winsorized in 0_0_Sample_Creation.do and flow through unchanged here.
********************************************************************

clear all
set more off
set varabbrev off
set linesize 200
version 17

* ============= SET PATHS =============
global root "${REPL}"
global data "${root}/Data/Working Files"
global out  "${root}/Paper Replication/Figures and Tables/Descriptive"
global paperfigs "${root}/Paper Replication/Figures and Tables/Tables and Figures in Paper"
* =====================================
cap mkdir "${root}/Paper Replication/Figures and Tables"
cap mkdir "${out}"
cap mkdir "${paperfigs}"


*-------------------------------------------------------------*
* Sample selection logging (frame + helper program)           *
*-------------------------------------------------------------*

capture frame drop selection
frame create selection str80 step ///
    long n_bonds long n_bondqtr long n_obs long n_funds long n_firms

capture program drop _logstep
program define _logstep
    args label
    qui count
    local n = r(N)
    qui unique issueID
    local nb = r(unique)
    qui unique issueID qdate
    local nbq = r(unique)
    qui unique fundid
    local nf = r(unique)
    qui unique firmid
    local nfm = r(unique)
    frame post selection ("`label'") (`nb') (`nbq') (`n') (`nf') (`nfm')
    di as txt "    [`label']  bonds=`nb'  bond-qtrs=`nbq'  obs=`n'  funds=`nf'  firms=`nfm'"
end


*-------------------------------------------------------------*
* Step 1: Full eMAXX Sample (raw file)                        *
*-------------------------------------------------------------*

use "${data}/eMAXXMergentFISD_SampleFinalCDS.dta", clear

qui count
local n = r(N)
qui unique issuecus
local nb = r(unique)
qui unique issuecus qdate
local nbq = r(unique)
qui unique fundid
local nf = r(unique)
qui unique firmid
local nfm = r(unique)
frame post selection ("Full eMAXX Sample") (`nb') (`nbq') (`n') (`nf') (`nfm')
di as txt "[Full eMAXX raw]  bonds=`nb'  bond-qtrs=`nbq'  obs=`n'  funds=`nf'  firms=`nfm'"


*-------------------------------------------------------------*
* Load prepared _WV file                                      *
*-------------------------------------------------------------*

use "${data}/eMAXXMergentFISD_SampleFinalCDS_WV.dta", clear

* -------------------------------------------------------------*
* Andreani-style holdings variables (built on the full bond-   *
* fund-firm-quarter panel so the lag structure matches the     *
* sample-creation construction of delta_holdings).             *
* Paramt, amount_outstanding, and offering_amt are assumed in  *
* thousands of dollars.                                        *
* -------------------------------------------------------------*

sort issueID fundid firmid qdate
bysort issueID fundid firmid (qdate): gen _L_paramt = paramt[_n-1]

gen delta_d = paramt - _L_paramt
label variable delta_d "Delta Holding Q ('000 $)"

gen delta_ratio = (paramt - _L_paramt) / _L_paramt if _L_paramt > 0 & !missing(_L_paramt)
label variable delta_ratio "Delta Holding Ratio Q"

gen holding_Q_mln  = paramt    / 1000
gen holding_Q1_mln = _L_paramt / 1000
gen holding_Q_ln   = ln(paramt)     if paramt    > 0
gen holding_Q1_ln  = ln(_L_paramt)  if _L_paramt > 0 & !missing(_L_paramt)
label variable holding_Q_mln  "Holding Q (mln $)"
label variable holding_Q1_mln "Holding Q-1 (mln $)"
label variable holding_Q_ln   "Holding Q Ln"
label variable holding_Q1_ln  "Holding Q-1 Ln"

gen issuance_bln    = offering_amt / 1e6
gen issuance_ln     = ln(offering_amt)        if offering_amt > 0
gen amount_held_bln = amount_outstanding / 1e6
label variable issuance_bln    "Issuance Paramt (bln $)"
label variable issuance_ln     "Issuance Paramt Ln"
label variable amount_held_bln "Amount Held (bln $)"

drop _L_paramt

* PassiveInvestor classification
capture drop PassiveInvestor
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

* Share variable used for Figures 1-2 coverage decompositions
capture drop share
gen share = (paramt / offering_amt) * 100
label variable share "Holding share (% of offering amount)"

capture drop issue_totparamt
bysort issueID qdate: egen issue_totparamt = total(paramt)


*=============================================================*
* FIGURE 1: % Holdings Coverage WITHIN eMAXX                  *
*=============================================================*

{
preserve
    capture drop share
    gen share = paramt / issue_totparamt
    collapse (sum) share, by(issueID qdate PassiveInvestor)
    collapse (mean) share, by(qdate PassiveInvestor)
    replace share = share * 100
    keep if inrange(qdate, tq(2012q1), tq(2023q4))
    reshape wide share, i(qdate) j(PassiveInvestor)
    replace share0 = 100 - (share1 + share2 + share3 + share4 + share5)
    gen cum2 = share2
    gen cum3 = cum2 + share3
    gen cum4 = cum3 + share4
    gen cum5 = cum4 + share5
    gen cum1 = cum5 + share1
    gen cum0 = cum1 + share0
    twoway ///
        (bar cum0 qdate, color(gs10) lwidth(none) barwidth(0.9)) ///
        (bar cum1 qdate, color(black) lwidth(none) barwidth(0.9)) ///
        (bar cum5 qdate, color("139 0 0") lwidth(none) barwidth(0.9)) ///
        (bar cum4 qdate, color("213 94 0") lwidth(none) barwidth(0.9)) ///
        (bar cum3 qdate, color("0 158 115") lwidth(none) barwidth(0.9)) ///
        (bar cum2 qdate, color("0 63 114") lwidth(none) barwidth(0.9)), ///
        legend(order(6 "Life Insurer" 5 "Other Insurer" 4 "P&C Insurer" ///
                     3 "Variable Annuity" 2 "Passive MF" 1 "Other") ///
               cols(4) size(small) region(lcolor(white)) position(6)) ///
        ytitle("% Holdings Coverage", size(small)) xtitle("") ///
        ylabel(0(10)100, labsize(small) nogrid angle(horizontal) format(%2.0f)) ///
        xlabel(`=tq(2012q1)' `=tq(2014q1)' `=tq(2016q1)' `=tq(2018q1)' ///
               `=tq(2020q1)' `=tq(2022q1)' `=tq(2023q4)', ///
               labsize(small) nogrid format(%tqCCYY!qq)) ///
        xscale(range(`=tq(2012q1)' `=tq(2023q4)')) ///
        graphregion(color(white)) bgcolor(white) ///
        plotregion(margin(medsmall) lcolor(gs10))
    graph export "${out}/Figure1_WithineMAXX.png", replace width(2400)
    copy "${out}/Figure1_WithineMAXX.png" "${paperfigs}/F01_Figure1_eMAXX Coverage 2012Q1-2023Q4.png", replace   // paper-folder copy
restore
}


*=============================================================*
* FIGURE 2: % Holdings Coverage of TOTAL AMOUNT OUTSTANDING   *
*=============================================================*

{
preserve
    capture drop share
    gen share = paramt / amount_outstanding
    collapse (sum) share, by(issueID qdate PassiveInvestor)
    collapse (mean) share, by(qdate PassiveInvestor)
    replace share = share * 100
    keep if inrange(qdate, tq(2012q1), tq(2023q4))
    reshape wide share, i(qdate) j(PassiveInvestor)
    gen share6 = 100 - (share0 + share1 + share2 + share3 + share4 + share5)
    replace share6 = 0 if share6 < 0
    gen cum2 = share2
    gen cum3 = cum2 + share3
    gen cum4 = cum3 + share4
    gen cum5 = cum4 + share5
    gen cum1 = cum5 + share1
    gen cum0 = cum1 + share0
    gen cum6 = cum0 + share6
    twoway ///
        (bar cum6 qdate, color(gs12) lwidth(none) barwidth(0.9)) ///
        (bar cum0 qdate, color(gs6) lwidth(none) barwidth(0.9)) ///
        (bar cum1 qdate, color(black) lwidth(none) barwidth(0.9)) ///
        (bar cum5 qdate, color("139 0 0") lwidth(none) barwidth(0.9)) ///
        (bar cum4 qdate, color("213 94 0") lwidth(none) barwidth(0.9)) ///
        (bar cum3 qdate, color("0 158 115") lwidth(none) barwidth(0.9)) ///
        (bar cum2 qdate, color("0 63 114") lwidth(none) barwidth(0.9)), ///
        legend(order(7 "Life Insurer" 6 "Other Insurer" 5 "P&C Insurer" ///
                     4 "Variable Annuity" 3 "Passive MF" ///
                     2 "eMAXX Other" 1 "Non-eMAXX") ///
               cols(4) size(small) region(lcolor(white)) position(6)) ///
        ytitle("% Holdings Coverage", size(small)) xtitle("") ///
        ylabel(0(10)100, labsize(small) nogrid angle(horizontal) format(%2.0f)) ///
        xlabel(`=tq(2012q1)' `=tq(2014q1)' `=tq(2016q1)' `=tq(2018q1)' ///
               `=tq(2020q1)' `=tq(2022q1)' `=tq(2023q4)', ///
               labsize(small) nogrid format(%tqCCYY!qq)) ///
        xscale(range(`=tq(2012q1)' `=tq(2023q4)')) ///
        graphregion(color(white)) bgcolor(white) ///
        plotregion(margin(medsmall) lcolor(gs10))
    graph export "${out}/Figure2_AmtOutstanding.png", replace width(2400)
    copy "${out}/Figure2_AmtOutstanding.png" "${paperfigs}/F02_Figure2_Amount Outstanding Coverage 2012Q1-2023Q4.png", replace   // paper-folder copy
restore
}


*-------------------------------------------------------------*
* Step 2: Constrained Investors + Clean Window                *
*-------------------------------------------------------------*

capture drop Clean_Window
gen Clean_Window = (qdate > qoffering + 2)
label variable Clean_Window "Bond-quarter >2 quarters after issuance"

keep if inlist(PassiveInvestor, 1, 2, 3, 4, 5)
_logstep "Constrained Investors"

keep if Clean_Window == 1
_logstep "  Clean Window (>2q post-issuance)"


*=============================================================*
* FIGURE 3: Mean Delta Holdings by quarter and investor type  *
*=============================================================*

{
preserve
    collapse (mean) mean_d = delta_holdings, by(qdate PassiveInvestor)
    keep if inrange(qdate, tq(2012q1), tq(2023q4))
    twoway ///
        (line mean_d qdate if PassiveInvestor == 1, ///
            lcolor("139 0 0") lwidth(medthick) lpattern(solid)) ///
        (line mean_d qdate if PassiveInvestor == 2, ///
            lcolor(black) lwidth(medthick) lpattern(solid)) ///
        (line mean_d qdate if PassiveInvestor == 3, ///
            lcolor(gs6) lwidth(medium) lpattern(dash)) ///
        (line mean_d qdate if PassiveInvestor == 4, ///
            lcolor(gs8) lwidth(medium) lpattern(longdash)) ///
        (line mean_d qdate if PassiveInvestor == 5, ///
            lcolor(gs10) lwidth(medium) lpattern(dash_dot)), ///
        legend(order(1 "Passive MF" 2 "Life Insurer" 3 "Other Insurer" ///
                     4 "P&C Insurer" 5 "Variable Annuity") ///
               rows(1) size(small) region(lcolor(white)) position(6)) ///
        ytitle("Mean Delta Holdings (bp of offering amount)", size(small)) ///
        xtitle("") yline(0, lcolor(gs8) lpattern(dash)) ///
        ylabel(, labsize(small) nogrid angle(horizontal)) ///
        xlabel(`=tq(2012q1)' `=tq(2014q1)' `=tq(2016q1)' `=tq(2018q1)' ///
               `=tq(2020q1)' `=tq(2022q1)' `=tq(2023q4)', ///
               labsize(small) nogrid format(%tqCCYY!qq)) ///
        xscale(range(`=tq(2012q1)' `=tq(2023q4)')) ///
        graphregion(color(white)) bgcolor(white) ///
        plotregion(margin(medsmall) lcolor(gs10))
    graph export "${out}/Figure3_DeltaHoldings.png", replace width(2400)
restore
}


*-------------------------------------------------------------*
* Step 3: Bonds ever Downgraded                               *
*-------------------------------------------------------------*

gen byte DowngradeAny = (DowngradeSPR == 1 | DowngradeMR == 1 | DowngradeFR == 1)
gen _t_d = qdate if DowngradeAny == 1
bysort issueID: egen first_d_date = min(_t_d)
format first_d_date %tq
gen rel_time = qdate - first_d_date
gen byte is_treated = !missing(first_d_date)
drop _t_d

keep if is_treated == 1
_logstep "Downgraded Bonds (ever)"


*-------------------------------------------------------------*
* Step 4: Event Window [-8, +8] (Main Sample)                 *
*-------------------------------------------------------------*

keep if inrange(rel_time, -8, 8)
_logstep "Event Window [-8, +8] (Extensive Margin Sample)"

save "${data}/_event_sample_ext.dta", replace

drop if missing(delta_holdings)
_logstep "  Non-Missing Delta Holdings (Main Sample)"

save "${data}/_event_sample_main.dta", replace


*-------------------------------------------------------------*
* Panel B subsamples                                          *
*-------------------------------------------------------------*

preserve
    bysort issueID: egen n_reltime = nvals(rel_time)
    keep if n_reltime == 17
    _logstep "  Balanced (17 quarters)"
restore

preserve
    keep if !missing(CDS_spread)
    _logstep "  CDS Coverage"
restore


*=============================================================*
* TABLE 1: Sample Construction and Composition                *
*=============================================================*

frame change selection
list, sep(0) noobs
local nsteps = _N
forvalues i = 1/`nsteps' {
    local lbl_`i'  = step[`i']
    local b_`i'    = string(n_bonds[`i'],    "%12.0gc")
    local bq_`i'   = string(n_bondqtr[`i'],  "%12.0gc")
    local obs_`i'  = string(n_obs[`i'],      "%12.0gc")
    local f_`i'    = string(n_funds[`i'],    "%12.0gc")
    local fm_`i'   = string(n_firms[`i'],    "%12.0gc")
}
frame change default

local nrows = 11
local ncols = 6

putdocx clear
putdocx begin, pagesize(A4) landscape margin(all, 0.7in)

putdocx paragraph, halign(center)
putdocx text ("TABLE 1."), bold
putdocx paragraph, halign(center)
putdocx text ("Sample Construction and Composition."), bold
putdocx paragraph, halign(both)
putdocx text ("This table reports the sample selection process and the unit counts at each step. ")
putdocx text ("Panel A reports sequential restrictions from the full eMAXX-Mergent FISD merged file ")
putdocx text ("to the final event-window sample used in the empirical analysis. Panel B reports two ")
putdocx text ("subsamples obtained from the main event-window sample: a balanced subsample restricting ")
putdocx text ("to bonds observed in all 17 event-time quarters, and a subsample with non-missing CDS ")
putdocx text ("spreads. Constrained investors are Life Insurers, Other Insurers, P&C Insurers, Passive ")
putdocx text ("Mutual Funds, and Variable Annuities (fundtype_det_num in {1,2,3,5,8}). Downgraded bonds ")
putdocx text ("are those experiencing at least one rating downgrade by S&P, Moody's, or Fitch. The event ")
putdocx text ("window restricts to relative time in [-8,+8] quarters around the first downgrade. The ")
putdocx text ("Clean Window restriction further drops the first two quarters after issuance. ")
putdocx text ("Bond-Fund-Firm-Quarters is the unit of observation in the regression sample.")

putdocx table tbl = (`nrows', `ncols'), border(all, nil)

putdocx table tbl(1,1) = ("Step"),                       bold halign(left)
putdocx table tbl(1,2) = ("Unique Bonds"),               bold halign(right)
putdocx table tbl(1,3) = ("Bond-Quarters"),              bold halign(right)
putdocx table tbl(1,4) = ("Bond-Fund-Firm-Quarters"),    bold halign(right)
putdocx table tbl(1,5) = ("Unique Funds"),               bold halign(right)
putdocx table tbl(1,6) = ("Unique Firms"),               bold halign(right)
putdocx table tbl(1,.), border(top, single)
putdocx table tbl(1,.), border(bottom, single)

putdocx table tbl(2,1) = ("Panel A: Sequential Restrictions"), italic halign(left)
putdocx table tbl(2,1), colspan(6)

local row = 3
forvalues i = 1/6 {
    putdocx table tbl(`row',1) = ("`lbl_`i''"),  halign(left)
    putdocx table tbl(`row',2) = ("`b_`i''"),    halign(right)
    putdocx table tbl(`row',3) = ("`bq_`i''"),   halign(right)
    putdocx table tbl(`row',4) = ("`obs_`i''"),  halign(right)
    putdocx table tbl(`row',5) = ("`f_`i''"),    halign(right)
    putdocx table tbl(`row',6) = ("`fm_`i''"),   halign(right)
    local ++row
}

putdocx table tbl(9,1) = ("Panel B: Subsamples (of Main Sample)"), italic halign(left)
putdocx table tbl(9,1), colspan(6)

local row = 10
forvalues i = 7/8 {
    putdocx table tbl(`row',1) = ("`lbl_`i''"),  halign(left)
    putdocx table tbl(`row',2) = ("`b_`i''"),    halign(right)
    putdocx table tbl(`row',3) = ("`bq_`i''"),   halign(right)
    putdocx table tbl(`row',4) = ("`obs_`i''"),  halign(right)
    putdocx table tbl(`row',5) = ("`f_`i''"),    halign(right)
    putdocx table tbl(`row',6) = ("`fm_`i''"),   halign(right)
    local ++row
}

putdocx table tbl(11,.), border(bottom, single)

putdocx save "${out}/Table1_SampleSelection.docx", replace
copy "${out}/Table1_SampleSelection.docx" "${paperfigs}/T01_Table1_Sample Construction and Composition.docx", replace   // paper-folder copy


*=============================================================*
* TABLE 3: Mean Delta Holdings by Event Time x Investor Type  *
*=============================================================*

use "${data}/_event_sample_main.dta", clear

preserve
    keep if inlist(PassiveInvestor, 1, 2, 3, 4, 5)
    collapse (mean) m_d = delta_holdings (count) n = delta_holdings, ///
        by(rel_time PassiveInvestor)
    reshape wide m_d n, i(rel_time) j(PassiveInvestor)
    tempfile t3
    save `t3', replace
restore

preserve
    use `t3', clear
    sort rel_time
    local nrt = _N
    forvalues i = 1/`nrt' {
        local rt_`i' = rel_time[`i']
        foreach k of numlist 1/5 {
            local m`k'_`i' = string(m_d`k'[`i'], "%9.2f")
        }
    }

    foreach k of numlist 1/5 {
        qui sum n`k', meanonly
        local Ntot_`k' = string(r(sum), "%12.0gc")
    }

    local nrows = `nrt' + 2
    local ncols = 6

    putdocx clear
    putdocx begin, pagesize(A4) margin(all, 0.8in)

    putdocx paragraph, halign(center)
    putdocx text ("TABLE 3."), bold
    putdocx paragraph, halign(center)
    putdocx text ("Mean Change in Holdings Around Rating Downgrades by Investor Type."), bold
    putdocx paragraph, halign(both)
    putdocx text ("This table reports the cross-sectional mean of the change in bond holdings ")
    putdocx text ("(in basis points of offering amount, winsorized at the 1st and 99th percentiles within ")
    putdocx text ("fundtype) by event time and investor type within the main event-window sample. The event ")
    putdocx text ("clock is centered on the first downgrade by any rating agency (S&P, Moody's, or Fitch), ")
    putdocx text ("with rel_time = 0 denoting the quarter of the first downgrade. The sample comprises ")
    putdocx text ("bond-fund-firm-quarter observations of constrained investors (Life Insurers, Other ")
    putdocx text ("Insurers, P&C Insurers, Passive Mutual Funds, and Variable Annuities) for bonds ever ")
    putdocx text ("downgraded, restricted to relative time in [-8,+8]. The bottom row reports the total ")
    putdocx text ("number of bond-fund-firm-quarter observations underlying the means in each column.")

    putdocx table tbl = (`nrows', `ncols'), border(all, nil)

    putdocx table tbl(1,1) = ("Event time"),       bold halign(left)
    putdocx table tbl(1,2) = ("Passive MF"),       bold halign(right)
    putdocx table tbl(1,3) = ("Life Insurer"),     bold halign(right)
    putdocx table tbl(1,4) = ("Other Insurer"),    bold halign(right)
    putdocx table tbl(1,5) = ("P&C Insurer"),      bold halign(right)
    putdocx table tbl(1,6) = ("Variable Annuity"), bold halign(right)
    putdocx table tbl(1,.), border(top, single)
    putdocx table tbl(1,.), border(bottom, single)

    local row = 2
    forvalues i = 1/`nrt' {
        putdocx table tbl(`row',1) = ("`=`rt_`i'''"), halign(left)
        putdocx table tbl(`row',2) = ("`m1_`i''"),    halign(right)
        putdocx table tbl(`row',3) = ("`m2_`i''"),    halign(right)
        putdocx table tbl(`row',4) = ("`m3_`i''"),    halign(right)
        putdocx table tbl(`row',5) = ("`m4_`i''"),    halign(right)
        putdocx table tbl(`row',6) = ("`m5_`i''"),    halign(right)
        local ++row
    }

    putdocx table tbl(`row',1) = ("Bond-Fund-Firm-Qtrs"), italic halign(left)
    putdocx table tbl(`row',2) = ("`Ntot_1'"), italic halign(right)
    putdocx table tbl(`row',3) = ("`Ntot_2'"), italic halign(right)
    putdocx table tbl(`row',4) = ("`Ntot_3'"), italic halign(right)
    putdocx table tbl(`row',5) = ("`Ntot_4'"), italic halign(right)
    putdocx table tbl(`row',6) = ("`Ntot_5'"), italic halign(right)
    putdocx table tbl(`row',.), border(top, single)
    putdocx table tbl(`row',.), border(bottom, single)

    putdocx save "${out}/Table3_MeanDeltaHoldings_RelTime.docx", replace
restore


*=============================================================*
* FIGURE 4: Mean Delta Holdings by Event Time and Investor    *
*=============================================================*

use "${data}/_event_sample_main.dta", clear

{
preserve
    keep if inlist(PassiveInvestor, 1, 2, 3, 4, 5)
    collapse (mean) mean_d = delta_holdings, by(rel_time PassiveInvestor)
    twoway ///
        (line mean_d rel_time if PassiveInvestor == 1, ///
            lcolor("139 0 0") lwidth(medthick) lpattern(solid)) ///
        (line mean_d rel_time if PassiveInvestor == 2, ///
            lcolor(black) lwidth(medthick) lpattern(solid)) ///
        (line mean_d rel_time if PassiveInvestor == 3, ///
            lcolor(gs6) lwidth(medium) lpattern(dash)) ///
        (line mean_d rel_time if PassiveInvestor == 4, ///
            lcolor(gs8) lwidth(medium) lpattern(longdash)) ///
        (line mean_d rel_time if PassiveInvestor == 5, ///
            lcolor(gs10) lwidth(medium) lpattern(dash_dot)), ///
        legend(order(1 "Passive MF" 2 "Life Insurer" 3 "Other Insurer" ///
                     4 "P&C Insurer" 5 "Variable Annuity") ///
               rows(1) size(small) region(lcolor(white)) position(6)) ///
        ytitle("Mean Delta Holdings (bp of offering amount)", size(small)) ///
        xtitle("Event Time (Quarters Relative to First Downgrade)", size(small)) ///
        yline(0, lcolor(gs8) lpattern(dash)) ///
        xline(0, lcolor(gs8) lpattern(dash)) ///
        ylabel(, labsize(small) nogrid angle(horizontal)) ///
        xlabel(-8(2)8, labsize(small) nogrid) ///
        xscale(range(-8 8)) ///
        graphregion(color(white)) bgcolor(white) ///
        plotregion(margin(medsmall) lcolor(gs10))
    graph export "${out}/Figure4_DeltaHoldings_RelTime.png", replace width(2400)
    copy "${out}/Figure4_DeltaHoldings_RelTime.png" "${paperfigs}/F03_Figure3_PanelA_Delta Holdings by Event Quarter.png", replace   // paper-folder copy
restore
}

use "${data}/_event_sample_main.dta", clear
{
preserve
    keep if inlist(PassiveInvestor, 1, 2, 3, 4, 5)

    * Map event quarters to event years
    *   rel_year = -2 -> Pre_2Y  (rel_time -8 to -5)
    *   rel_year = -1 -> Pre_1Y  (rel_time -4 to -1)
    *   rel_year =  0 -> Downgrade (rel_time 0)
    *   rel_year =  1 -> Post_1Y (rel_time 1 to 4)
    *   rel_year =  2 -> Post_2Y (rel_time 5 to 8)
    gen rel_year = .
    replace rel_year = -2 if inrange(rel_time, -8, -5)
    replace rel_year = -1 if inrange(rel_time, -4, -1)
    replace rel_year =  0 if rel_time == 0
    replace rel_year =  1 if inrange(rel_time,  1,  4)
    replace rel_year =  2 if inrange(rel_time,  5,  8)

    collapse (mean) mean_d = delta_holdings, by(rel_year PassiveInvestor)

    twoway ///
        (connected mean_d rel_year if PassiveInvestor == 1, ///
            lcolor("139 0 0") mcolor("139 0 0") lwidth(medthick) lpattern(solid) msymbol(O) msize(small)) ///
        (connected mean_d rel_year if PassiveInvestor == 2, ///
            lcolor(black) mcolor(black) lwidth(medthick) lpattern(solid) msymbol(O) msize(small)) ///
        (connected mean_d rel_year if PassiveInvestor == 3, ///
            lcolor(gs6) mcolor(gs6) lwidth(medium) lpattern(dash) msymbol(T) msize(small)) ///
        (connected mean_d rel_year if PassiveInvestor == 4, ///
            lcolor(gs8) mcolor(gs8) lwidth(medium) lpattern(longdash) msymbol(D) msize(small)) ///
        (connected mean_d rel_year if PassiveInvestor == 5, ///
            lcolor(gs10) mcolor(gs10) lwidth(medium) lpattern(dash_dot) msymbol(S) msize(small)), ///
        legend(order(1 "Passive MF" 2 "Life Insurer" 3 "Other Insurer" ///
                     4 "P&C Insurer" 5 "Variable Annuity") ///
               rows(1) size(small) region(lcolor(white)) position(6)) ///
        ytitle("Mean Delta Holdings (bp of offering amount)", size(small)) ///
        xtitle("Event Window (Years Relative to First Downgrade)", size(small)) ///
        yline(0, lcolor(gs8) lpattern(dash)) ///
        xline(0, lcolor(gs8) lpattern(dash)) ///
        ylabel(, labsize(small) nogrid angle(horizontal)) ///
        xlabel(-2 "Pre_2Y" -1 "Pre_1Y" 0 "Downgrade" 1 "Post_1Y" 2 "Post_2Y", ///
               labsize(small) nogrid) ///
        xscale(range(-2 2)) ///
        graphregion(color(white)) bgcolor(white) ///
        plotregion(margin(medsmall) lcolor(gs10))

    graph export "${out}/Figure4_DeltaHoldings_RelYear.png", replace width(2400)
    copy "${out}/Figure4_DeltaHoldings_RelYear.png" "${paperfigs}/F03_Figure3_PanelB_Delta Holdings by Event Year.png", replace   // paper-folder copy
restore
}

*=============================================================*
* FIGURE 5: First Downgrades and Sample Size by Calendar Qtr  *
*=============================================================*

use "${data}/_event_sample_main.dta", clear

{
preserve
    keep issueID qdate first_d_date rel_time
    bysort issueID qdate: keep if _n == 1

    gen byte is_first_dg = (rel_time == 0)

    collapse (sum) n_first_dg = is_first_dg (count) n_bonds = issueID, by(qdate)

    keep if inrange(qdate, tq(2012q1), tq(2023q4))

    twoway ///
        (bar n_first_dg qdate, yaxis(1) color("139 0 0") barwidth(0.9) lwidth(none)) ///
        (line n_bonds qdate, yaxis(2) lcolor(black) lwidth(medthick) lpattern(solid)), ///
        legend(order(1 "First Downgrades (left)" 2 "Bonds in Sample (right)") ///
               rows(1) size(small) region(lcolor(white)) position(6)) ///
        ytitle("Number of First Downgrades", axis(1) size(small)) ///
        ytitle("Number of Bonds in Sample", axis(2) size(small)) ///
        xtitle("") ///
        ylabel(, axis(1) labsize(small) nogrid angle(horizontal)) ///
        ylabel(, axis(2) labsize(small) nogrid angle(horizontal)) ///
        xlabel(`=tq(2012q1)' `=tq(2014q1)' `=tq(2016q1)' `=tq(2018q1)' ///
               `=tq(2020q1)' `=tq(2022q1)' `=tq(2023q4)', ///
               labsize(small) nogrid format(%tqCCYY!qq)) ///
        xscale(range(`=tq(2012q1)' `=tq(2023q4)')) ///
        graphregion(color(white)) bgcolor(white) ///
        plotregion(margin(medsmall) lcolor(gs10))
    graph export "${out}/Figure5_DowngradesSampleSize.png", replace width(2400)
restore
}


*=============================================================*
* TABLE 4: Descriptive Statistics (Event Sample)              *
*=============================================================*

use "${data}/_event_sample_ext.dta", clear

* ---- Bond-quarter variables for the table ----
gen offering_amt_bln = offering_amt / 1e6
gen amount_out_bln   = amount_outstanding / 1e6
label variable offering_amt_bln "Offering Amount (bln $)"
label variable amount_out_bln   "Amount Outstanding (bln $)"

* Constrained institutional holdings as share of amount outstanding
* (sum paramt across all bond-fund-firm rows of each bond-quarter, divide by AO, x100)
bysort issueID qdate: egen _sum_paramt = total(paramt)
gen constr_inst_share = (_sum_paramt / amount_outstanding) * 100
label variable constr_inst_share "Constrained Institutional Holdings (% of AO)"
drop _sum_paramt

* Composite NAIC rating (median-of-3 / lower-of-2 / sole-of-1)
cap drop NAIC_num
egen _agcount  = rownonmiss(SPR_num MR_num FR_num)
egen _agmed3   = rowmedian(SPR_num MR_num FR_num)
egen _agmax    = rowmax(SPR_num MR_num FR_num)
gen NAIC_num = .
replace NAIC_num = _agmed3 if _agcount == 3
replace NAIC_num = _agmax  if inlist(_agcount, 1, 2)
label variable NAIC_num "Composite NAIC Rating"
drop _agcount _agmed3 _agmax

* ---- Variable groups ----
* Dependent variables (delta_holdings/pos/neg are missing where lag is missing;
*  N for those is smaller than for the extensive-only outcomes).
local depvars  "delta_holdings pos_delta_holdings neg_delta_holdings net_change_bp gross_buys_bp gross_sells_bp entry exit"
local deplabs  `" "Delta Holdings (Turnover Ratio Q, bp)" "Positive Delta (bp)" "Negative Delta (bp, abs)" "Net Change (bp)" "Gross Buys (bp)" "Gross Sells (bp)" "Entry" "Exit" "'

local bondvars "offering_amt_bln ttm amount_out_bln constr_inst_share NAIC_num agency_count"
local bondlabs `" "Offering Amount (bln $)" "Time to Maturity (years)" "Amount Outstanding (bln $)" "Constrained Institutional Holdings (% of AO)" "Composite NAIC Rating" "Rating Agencies (count)" "'

local ndep  : word count `depvars'
local nbond : word count `bondvars'

foreach v in `depvars' `bondvars' {
    qui sum `v', detail
    local `v'_n   = string(r(N),    "%12.0gc")
    local `v'_mn  = string(r(mean), "%9.3f")
    local `v'_sd  = string(r(sd),   "%9.3f")
    local `v'_p25 = string(r(p25),  "%9.3f")
    local `v'_p50 = string(r(p50),  "%9.3f")
    local `v'_p75 = string(r(p75),  "%9.3f")
}

local nrows = 3 + `ndep' + `nbond'
local ncols = 7

putdocx clear
putdocx begin, pagesize(A4) margin(all, 0.8in)

putdocx paragraph, halign(center)
putdocx text ("TABLE 4."), bold
putdocx paragraph, halign(center)
putdocx text ("Descriptive Statistics."), bold
putdocx paragraph, halign(both)
putdocx text ("This table reports descriptive statistics for the variables used in this research within the extensive-margin event-window sample. The sample comprises bond-fund-firm-quarter observations of constrained investors (Life Insurers, Other Insurers, P&C Insurers, Passive Mutual Funds, and Variable Annuities) for bonds ever downgraded by S&P, Moody's, or Fitch, restricted to relative time in [-8,+8] quarters around the first downgrade and to bond-quarters at least three quarters after issuance (Clean Window). Delta Holdings (Turnover Ratio Q) is the quarter-on-quarter change in paramt scaled by offering amount and expressed in basis points, winsorized at the 1st and 99th percentiles within fundtype. Positive Delta and Negative Delta decompose Delta Holdings into positive and absolute negative components, also winsorized within fundtype. Delta Holdings, Positive Delta, and Negative Delta are missing for the first observed quarter of each bond-fund-firm panel; the observation count is therefore smaller than for the remaining outcomes. Net Change, Gross Buys, and Gross Sells are the eMAXX-reconciled trading flows in basis points of amount outstanding, pre-winsorized within fundtype. Entry equals one in the first quarter a fund-firm holds the bond. Exit equals one in the last quarter a fund-firm holds the bond (set to zero in 2023q4 to avoid right-censoring). Constrained Institutional Holdings is the sum of paramt across all constrained-investor fund-firm rows for the bond-quarter, expressed as a percent of amount outstanding. The composite NAIC rating is the median of S&P, Moody's, and Fitch when all three are available, the lower (higher NAIC number) when two are available, and the sole rating when one is available. Rating Agencies is the count of agencies with a non-missing rating in the bond-quarter.")

putdocx table tbl = (`nrows', `ncols'), border(all, nil)

putdocx table tbl(1,1) = ("Variables"),  bold halign(left)
putdocx table tbl(1,2) = ("Obs."),       bold halign(right)
putdocx table tbl(1,3) = ("Mean"),       bold halign(right)
putdocx table tbl(1,4) = ("Std. Dev."),  bold halign(right)
putdocx table tbl(1,5) = ("25th"),       bold halign(right)
putdocx table tbl(1,6) = ("Median"),     bold halign(right)
putdocx table tbl(1,7) = ("75th"),       bold halign(right)
putdocx table tbl(1,.), border(top, single)
putdocx table tbl(1,.), border(bottom, single)

putdocx table tbl(2,1) = ("Dependent variables"), italic halign(left)
putdocx table tbl(2,1), colspan(7)

local row = 3
forvalues k = 1/`ndep' {
    local v   : word `k' of `depvars'
    local lab : word `k' of `deplabs'
    putdocx table tbl(`row',1) = ("`lab'"),         halign(left)
    putdocx table tbl(`row',2) = ("``v'_n'"),       halign(right)
    putdocx table tbl(`row',3) = ("``v'_mn'"),      halign(right)
    putdocx table tbl(`row',4) = ("``v'_sd'"),      halign(right)
    putdocx table tbl(`row',5) = ("``v'_p25'"),     halign(right)
    putdocx table tbl(`row',6) = ("``v'_p50'"),     halign(right)
    putdocx table tbl(`row',7) = ("``v'_p75'"),     halign(right)
    local ++row
}

putdocx table tbl(`row',1) = ("Bond variables"), italic halign(left)
putdocx table tbl(`row',1), colspan(7)
local ++row

forvalues k = 1/`nbond' {
    local v   : word `k' of `bondvars'
    local lab : word `k' of `bondlabs'
    putdocx table tbl(`row',1) = ("`lab'"),         halign(left)
    putdocx table tbl(`row',2) = ("``v'_n'"),       halign(right)
    putdocx table tbl(`row',3) = ("``v'_mn'"),      halign(right)
    putdocx table tbl(`row',4) = ("``v'_sd'"),      halign(right)
    putdocx table tbl(`row',5) = ("``v'_p25'"),     halign(right)
    putdocx table tbl(`row',6) = ("``v'_p50'"),     halign(right)
    putdocx table tbl(`row',7) = ("``v'_p75'"),     halign(right)
    local ++row
}

local lastrow = `row' - 1
putdocx table tbl(`lastrow',.), border(bottom, single)

putdocx save "${out}/Table4_DescriptiveStatistics.docx", replace
copy "${out}/Table4_DescriptiveStatistics.docx" "${paperfigs}/T02_Table2_Descriptive Statistics.docx", replace   // paper-folder copy


*=============================================================*
* TABLE 5: Delta Holdings / Net Change / Exit by Investor Type *
*=============================================================*

use "${data}/_event_sample_ext.dta", clear

local types       1 2 3 4 5 ALL
local typelabels  `" "Passive MF" "Life Insurer" "Other Insurer" "P&C Insurer" "Variable Annuity" "All Constrained" "'
local ntypes : word count `types'

capture program drop _statrow5
program define _statrow5, rclass
    args var typecode
    if "`typecode'" == "ALL" {
        qui sum `var', detail
    }
    else {
        qui sum `var' if PassiveInvestor == `typecode', detail
    }
    return scalar n   = r(N)
    return scalar mn  = r(mean)
    return scalar sd  = r(sd)
    return scalar p25 = r(p25)
    return scalar p50 = r(p50)
    return scalar p75 = r(p75)
end

foreach v in delta_holdings net_change_bp exit {
    local k = 0
    foreach t of local types {
        local ++k
        _statrow5 `v' `t'
        local `v'_n_`k'   = string(r(n),   "%12.0gc")
        local `v'_mn_`k'  = string(r(mn),  "%9.3f")
        local `v'_sd_`k'  = string(r(sd),  "%9.3f")
        local `v'_p25_`k' = string(r(p25), "%9.3f")
        local `v'_p50_`k' = string(r(p50), "%9.3f")
        local `v'_p75_`k' = string(r(p75), "%9.3f")
    }
}

local nrows = 4 + 3*`ntypes'
local ncols = 7

putdocx clear
putdocx begin, pagesize(A4) margin(all, 0.8in)

putdocx paragraph, halign(center)
putdocx text ("TABLE 5."), bold
putdocx paragraph, halign(center)
putdocx text ("Descriptive Statistics of Trading Outcomes by Investor Type."), bold
putdocx paragraph, halign(both)
putdocx text ("This table reports descriptive statistics of three trading outcomes by investor type within the extensive-margin event-window sample, comprising bond-fund-firm-quarter observations of constrained investors for bonds ever downgraded by S&P, Moody's, or Fitch, restricted to relative time in [-8,+8] quarters around the first downgrade and to bond-quarters at least three quarters after issuance (Clean Window). Panel A reports Delta Holdings, the quarter-on-quarter change in position scaled by offering amount and expressed in basis points, winsorized at the 1st and 99th percentiles within fundtype. Panel B reports Net Change, the eMAXX-reconciled net flow in basis points of amount outstanding, pre-winsorized within fundtype. Panel C reports Exit, equal to one in the last quarter a fund-firm holds the bond and zero otherwise (set to zero in 2023q4 to avoid right-censoring). Delta Holdings is missing for the first observed quarter of each bond-fund-firm panel; its observation count is therefore smaller than for Net Change and Exit within each investor type. The All Constrained row pools the five investor types.")

putdocx table tbl = (`nrows', `ncols'), border(all, nil)

putdocx table tbl(1,1) = ("Investor Type"), bold halign(left)
putdocx table tbl(1,2) = ("Obs"),           bold halign(right)
putdocx table tbl(1,3) = ("Mean"),          bold halign(right)
putdocx table tbl(1,4) = ("Std. Dev."),     bold halign(right)
putdocx table tbl(1,5) = ("25th"),          bold halign(right)
putdocx table tbl(1,6) = ("Median"),        bold halign(right)
putdocx table tbl(1,7) = ("75th"),          bold halign(right)
putdocx table tbl(1,.), border(top, single)
putdocx table tbl(1,.), border(bottom, single)

putdocx table tbl(2,1) = ("Panel A: Delta Holdings (bp of offering amount)"), italic halign(left)
putdocx table tbl(2,1), colspan(7)

local row = 3
forvalues k = 1/`ntypes' {
    local lab : word `k' of `typelabels'
    putdocx table tbl(`row',1) = ("`lab'"),                          halign(left)
    putdocx table tbl(`row',2) = ("`delta_holdings_n_`k''"),         halign(right)
    putdocx table tbl(`row',3) = ("`delta_holdings_mn_`k''"),        halign(right)
    putdocx table tbl(`row',4) = ("`delta_holdings_sd_`k''"),        halign(right)
    putdocx table tbl(`row',5) = ("`delta_holdings_p25_`k''"),       halign(right)
    putdocx table tbl(`row',6) = ("`delta_holdings_p50_`k''"),       halign(right)
    putdocx table tbl(`row',7) = ("`delta_holdings_p75_`k''"),       halign(right)
    local ++row
}

putdocx table tbl(`row',1) = ("Panel B: Net Change (bp of amount outstanding)"), italic halign(left)
putdocx table tbl(`row',1), colspan(7)
local ++row

forvalues k = 1/`ntypes' {
    local lab : word `k' of `typelabels'
    putdocx table tbl(`row',1) = ("`lab'"),                          halign(left)
    putdocx table tbl(`row',2) = ("`net_change_bp_n_`k''"),          halign(right)
    putdocx table tbl(`row',3) = ("`net_change_bp_mn_`k''"),         halign(right)
    putdocx table tbl(`row',4) = ("`net_change_bp_sd_`k''"),         halign(right)
    putdocx table tbl(`row',5) = ("`net_change_bp_p25_`k''"),        halign(right)
    putdocx table tbl(`row',6) = ("`net_change_bp_p50_`k''"),        halign(right)
    putdocx table tbl(`row',7) = ("`net_change_bp_p75_`k''"),        halign(right)
    local ++row
}

putdocx table tbl(`row',1) = ("Panel C: Exit (binary)"), italic halign(left)
putdocx table tbl(`row',1), colspan(7)
local ++row

forvalues k = 1/`ntypes' {
    local lab : word `k' of `typelabels'
    putdocx table tbl(`row',1) = ("`lab'"),                          halign(left)
    putdocx table tbl(`row',2) = ("`exit_n_`k''"),                   halign(right)
    putdocx table tbl(`row',3) = ("`exit_mn_`k''"),                  halign(right)
    putdocx table tbl(`row',4) = ("`exit_sd_`k''"),                  halign(right)
    putdocx table tbl(`row',5) = ("`exit_p25_`k''"),                 halign(right)
    putdocx table tbl(`row',6) = ("`exit_p50_`k''"),                 halign(right)
    putdocx table tbl(`row',7) = ("`exit_p75_`k''"),                 halign(right)
    local ++row
}

local lastrow = `row' - 1
putdocx table tbl(`lastrow',.), border(bottom, single)

putdocx save "${out}/Table5_DescStats_ByInvestor.docx", replace


*=============================================================*
* APPENDIX TABLE B: Descriptive Stats for LI and PMF separately*
*  Variables: Delta Holdings, Net Change, Entry, Exit          *
*  Sample: extensive-margin event sample                       *
*=============================================================*

use "${data}/_event_sample_ext.dta", clear

local appvars "delta_holdings net_change_bp entry exit"
local applabs `" "Delta Holdings (Turnover Ratio Q, bp)" "Net Change (bp)" "Entry" "Exit" "'
local nvars : word count `appvars'

* PassiveInvestor codes: 1 = Passive MF, 2 = Life Insurer
foreach inv in 2 1 {
    foreach v of local appvars {
        qui sum `v' if PassiveInvestor == `inv', detail
        local `v'_`inv'_n   = string(r(N),    "%12.0gc")
        local `v'_`inv'_mn  = string(r(mean), "%9.3f")
        local `v'_`inv'_sd  = string(r(sd),   "%9.3f")
        local `v'_`inv'_p25 = string(r(p25),  "%9.3f")
        local `v'_`inv'_p50 = string(r(p50),  "%9.3f")
        local `v'_`inv'_p75 = string(r(p75),  "%9.3f")
    }
}

local nrows = 1 + 2 * (1 + `nvars')
local ncols = 7

putdocx clear
putdocx begin, pagesize(A4) margin(all, 0.8in)

putdocx paragraph, halign(center)
putdocx text ("APPENDIX TABLE B."), bold
putdocx paragraph, halign(center)
putdocx text ("Descriptive Statistics of Holdings Outcomes by Investor Type."), bold
putdocx paragraph, halign(both)
putdocx text ("This appendix table reports descriptive statistics for the four outcome variables -- Delta Holdings (Turnover Ratio Q, in basis points of offering amount, winsorized 1/99 by fundtype), Net Change (eMAXX-reconciled net flow, in basis points of amount outstanding, pre-winsorized by fundtype), Entry, and Exit -- separately for Life Insurers and Passive Mutual Funds. The sample is the extensive-margin event-window sample (constrained investors, bonds ever downgraded by S&P, Moody's, or Fitch, event time [-8, +8], Clean Window), without restricting to non-missing Delta Holdings. Delta Holdings is missing for the first observed quarter of each bond-fund-firm panel; its observation count is therefore smaller than for the remaining outcomes within each investor type. Entry equals one in the first quarter the fund-firm holds the bond; Exit equals one in the last quarter the fund-firm holds the bond (set to zero in 2023q4 to avoid right-censoring).")

putdocx table tbl = (`nrows', `ncols'), border(all, nil)

putdocx table tbl(1,1) = ("Variable"),    bold halign(left)
putdocx table tbl(1,2) = ("Obs."),        bold halign(right)
putdocx table tbl(1,3) = ("Mean"),        bold halign(right)
putdocx table tbl(1,4) = ("Std. Dev."),   bold halign(right)
putdocx table tbl(1,5) = ("25th"),        bold halign(right)
putdocx table tbl(1,6) = ("Median"),      bold halign(right)
putdocx table tbl(1,7) = ("75th"),        bold halign(right)
putdocx table tbl(1,.), border(top, single)
putdocx table tbl(1,.), border(bottom, single)

local row = 2

* Section: Life Insurer (PassiveInvestor == 2)
putdocx table tbl(`row',1) = ("Life Insurer"), italic halign(left)
putdocx table tbl(`row',1), colspan(7)
local ++row

forvalues k = 1/`nvars' {
    local v   : word `k' of `appvars'
    local lab : word `k' of `applabs'
    putdocx table tbl(`row',1) = ("`lab'"),         halign(left)
    putdocx table tbl(`row',2) = ("``v'_2_n'"),     halign(right)
    putdocx table tbl(`row',3) = ("``v'_2_mn'"),    halign(right)
    putdocx table tbl(`row',4) = ("``v'_2_sd'"),    halign(right)
    putdocx table tbl(`row',5) = ("``v'_2_p25'"),   halign(right)
    putdocx table tbl(`row',6) = ("``v'_2_p50'"),   halign(right)
    putdocx table tbl(`row',7) = ("``v'_2_p75'"),   halign(right)
    local ++row
}

* Section: Passive Mutual Fund (PassiveInvestor == 1)
putdocx table tbl(`row',1) = ("Passive Mutual Fund"), italic halign(left)
putdocx table tbl(`row',1), colspan(7)
local ++row

forvalues k = 1/`nvars' {
    local v   : word `k' of `appvars'
    local lab : word `k' of `applabs'
    putdocx table tbl(`row',1) = ("`lab'"),         halign(left)
    putdocx table tbl(`row',2) = ("``v'_1_n'"),     halign(right)
    putdocx table tbl(`row',3) = ("``v'_1_mn'"),    halign(right)
    putdocx table tbl(`row',4) = ("``v'_1_sd'"),    halign(right)
    putdocx table tbl(`row',5) = ("``v'_1_p25'"),   halign(right)
    putdocx table tbl(`row',6) = ("``v'_1_p50'"),   halign(right)
    putdocx table tbl(`row',7) = ("``v'_1_p75'"),   halign(right)
    local ++row
}

local lastrow = `row' - 1
putdocx table tbl(`lastrow',.), border(bottom, single)

putdocx save "${out}/AppendixB_Stats_LI_vs_PMF.docx", replace


********************************************************************
*** End
********************************************************************
