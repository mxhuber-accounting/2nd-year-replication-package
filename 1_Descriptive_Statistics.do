********************************************************************
*** 1_Descriptive_Statistics
********************************************************************

* ============= SET PATHS =============
global root "/Users/matthiashuber/Library/CloudStorage/Dropbox-HECPARIS/Matthias Huber/Replication Package/Data"
global out  "${root}/Figures and Tables"
* =====================================
cap mkdir "${out}"
cap mkdir "${out}/Descriptive"


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

use "${root}/eMAXXMergentFISD_SampleFinalCDS.dta", clear

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
* Holdings-exceedance errors were dropped in 0_0_Sample_      *
* Creation so the check below is intentionally omitted.       *
*-------------------------------------------------------------*

use "${root}/eMAXXMergentFISD_SampleFinalCDS_WV.dta", clear

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

capture drop share
gen share = (paramt / offering_amt) * 100
label variable share "Holding share (% of offering amount)"
bysort issueID fundid firmid (qdate): gen delta_holdings = ///
    (paramt - paramt[_n-1]) / offering_amt * 10000
label variable delta_holdings "Change in holdings (bp of offering amount, non-winsorized)"
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
    graph export "${out}/Descriptive/Figure1_WithineMAXX.png", replace width(2400)
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
    graph export "${out}/Descriptive/Figure2_AmtOutstanding.png", replace width(2400)
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
* FIGURE 3: Mean Net Change by quarter and investor type      *
*=============================================================*

{
preserve
    collapse (mean) mean_net = net_change_bp, by(qdate PassiveInvestor)
    keep if inrange(qdate, tq(2012q1), tq(2023q4))
    twoway ///
        (line mean_net qdate if PassiveInvestor == 1, ///
            lcolor("139 0 0") lwidth(medthick) lpattern(solid)) ///
        (line mean_net qdate if PassiveInvestor == 2, ///
            lcolor(black) lwidth(medthick) lpattern(solid)) ///
        (line mean_net qdate if PassiveInvestor == 3, ///
            lcolor(gs6) lwidth(medium) lpattern(dash)) ///
        (line mean_net qdate if PassiveInvestor == 4, ///
            lcolor(gs8) lwidth(medium) lpattern(longdash)) ///
        (line mean_net qdate if PassiveInvestor == 5, ///
            lcolor(gs10) lwidth(medium) lpattern(dash_dot)), ///
        legend(order(1 "Passive MF" 2 "Life Insurer" 3 "Other Insurer" ///
                     4 "P&C Insurer" 5 "Variable Annuity") ///
               rows(1) size(small) region(lcolor(white)) position(6)) ///
        ytitle("Mean Net Change (bp of Amount Outstanding)", size(small)) ///
        xtitle("") yline(0, lcolor(gs8) lpattern(dash)) ///
        ylabel(, labsize(small) nogrid angle(horizontal)) ///
        xlabel(`=tq(2012q1)' `=tq(2014q1)' `=tq(2016q1)' `=tq(2018q1)' ///
               `=tq(2020q1)' `=tq(2022q1)' `=tq(2023q4)', ///
               labsize(small) nogrid format(%tqCCYY!qq)) ///
        xscale(range(`=tq(2012q1)' `=tq(2023q4)')) ///
        graphregion(color(white)) bgcolor(white) ///
        plotregion(margin(medsmall) lcolor(gs10))
    graph export "${out}/Descriptive/Figure3_NetChange.png", replace width(2400)
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
_logstep "Event Window [-8, +8] (Main Sample)"

save "${root}/_event_sample_main.dta", replace


*-------------------------------------------------------------*
* Panel B subsamples                                          *
*-------------------------------------------------------------*

* (a) Balanced: bond observed in all 17 rel_time quarters
preserve
    bysort issueID: egen n_reltime = nvals(rel_time)
    keep if n_reltime == 17
    _logstep "  Balanced (17 quarters)"
restore

* (b) CDS coverage
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

* Frame row order:
*   1 = Full eMAXX Sample
*   2 = Constrained Investors
*   3 = Clean Window (>2q post-issuance)
*   4 = Downgraded Bonds (ever)
*   5 = Event Window [-8, +8] (Main Sample)
*   6 = Balanced (17 quarters)
*   7 = CDS Coverage

local nrows = 10
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
forvalues i = 1/5 {
    putdocx table tbl(`row',1) = ("`lbl_`i''"),  halign(left)
    putdocx table tbl(`row',2) = ("`b_`i''"),    halign(right)
    putdocx table tbl(`row',3) = ("`bq_`i''"),   halign(right)
    putdocx table tbl(`row',4) = ("`obs_`i''"),  halign(right)
    putdocx table tbl(`row',5) = ("`f_`i''"),    halign(right)
    putdocx table tbl(`row',6) = ("`fm_`i''"),   halign(right)
    local ++row
}

putdocx table tbl(8,1) = ("Panel B: Subsamples (of Main Sample)"), italic halign(left)
putdocx table tbl(8,1), colspan(6)

local row = 9
forvalues i = 6/7 {
    putdocx table tbl(`row',1) = ("`lbl_`i''"),  halign(left)
    putdocx table tbl(`row',2) = ("`b_`i''"),    halign(right)
    putdocx table tbl(`row',3) = ("`bq_`i''"),   halign(right)
    putdocx table tbl(`row',4) = ("`obs_`i''"),  halign(right)
    putdocx table tbl(`row',5) = ("`f_`i''"),    halign(right)
    putdocx table tbl(`row',6) = ("`fm_`i''"),   halign(right)
    local ++row
}

putdocx table tbl(10,.), border(bottom, single)

putdocx save "${out}/Descriptive/Table1_SampleSelection.docx", replace


*=============================================================*
* TABLE 3: Mean Net Change by Event Time x Investor Type      *
*=============================================================*

use "${root}/_event_sample_main.dta", clear

preserve
    keep if inlist(PassiveInvestor, 1, 2, 3, 4, 5)
    collapse (mean) m_net = net_change_bp (count) n = net_change_bp, ///
        by(rel_time PassiveInvestor)
    reshape wide m_net n, i(rel_time) j(PassiveInvestor)
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
            local m`k'_`i' = string(m_net`k'[`i'], "%9.2f")
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
    putdocx text ("Mean Net Change Around Rating Downgrades by Investor Type."), bold
    putdocx paragraph, halign(both)
    putdocx text ("This table reports the cross-sectional mean of net change in bond holdings ")
    putdocx text ("(in basis points of offering amount) by event time and investor type within the ")
    putdocx text ("main event-window sample. The event clock is centered on the first downgrade by ")
    putdocx text ("any rating agency (S&P, Moody's, or Fitch), with rel_time = 0 denoting the ")
    putdocx text ("quarter of the first downgrade. The sample comprises bond-fund-firm-quarter ")
    putdocx text ("observations of constrained investors (Life Insurers, Other Insurers, P&C ")
    putdocx text ("Insurers, Passive Mutual Funds, and Variable Annuities) for bonds ever ")
    putdocx text ("downgraded, restricted to relative time in [-8,+8]. Net change is pre-winsorized ")
    putdocx text ("at the 1st and 99th percentiles within fundtype. The bottom row reports the total ")
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

    putdocx save "${out}/Descriptive/Table3_MeanNetChange_RelTime.docx", replace
restore


*=============================================================*
* FIGURE 4: Mean Net Change by Event Time and Investor Type   *
*=============================================================*

use "${root}/_event_sample_main.dta", clear

{
preserve
    keep if inlist(PassiveInvestor, 1, 2, 3, 4, 5)
    collapse (mean) mean_net = net_change_bp, by(rel_time PassiveInvestor)
    twoway ///
        (line mean_net rel_time if PassiveInvestor == 1, ///
            lcolor("139 0 0") lwidth(medthick) lpattern(solid)) ///
        (line mean_net rel_time if PassiveInvestor == 2, ///
            lcolor(black) lwidth(medthick) lpattern(solid)) ///
        (line mean_net rel_time if PassiveInvestor == 3, ///
            lcolor(gs6) lwidth(medium) lpattern(dash)) ///
        (line mean_net rel_time if PassiveInvestor == 4, ///
            lcolor(gs8) lwidth(medium) lpattern(longdash)) ///
        (line mean_net rel_time if PassiveInvestor == 5, ///
            lcolor(gs10) lwidth(medium) lpattern(dash_dot)), ///
        legend(order(1 "Passive MF" 2 "Life Insurer" 3 "Other Insurer" ///
                     4 "P&C Insurer" 5 "Variable Annuity") ///
               rows(1) size(small) region(lcolor(white)) position(6)) ///
        ytitle("Mean Net Change (bp of Amount Outstanding)", size(small)) ///
        xtitle("Event Time (Quarters Relative to First Downgrade)", size(small)) ///
        yline(0, lcolor(gs8) lpattern(dash)) ///
        xline(0, lcolor(gs8) lpattern(dash)) ///
        ylabel(, labsize(small) nogrid angle(horizontal)) ///
        xlabel(-8(2)8, labsize(small) nogrid) ///
        xscale(range(-8 8)) ///
        graphregion(color(white)) bgcolor(white) ///
        plotregion(margin(medsmall) lcolor(gs10))
    graph export "${out}/Descriptive/Figure4_NetChange_RelTime.png", replace width(2400)
restore
}


*=============================================================*
* FIGURE 5: First Downgrades and Sample Size by Calendar Qtr  *
*=============================================================*

use "${root}/_event_sample_main.dta", clear

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
    graph export "${out}/Descriptive/Figure5_DowngradesSampleSize.png", replace width(2400)
restore
}


*=============================================================*
* TABLE 4: Descriptive Statistics (Event Sample)              *
*=============================================================*

use "${root}/_event_sample_main.dta", clear

capture drop offering_amt_bln
gen offering_amt_bln = offering_amt / 1e6

capture confirm variable yield
if _rc {
    di as err "Variable 'yield' not found -- rename in the variable list below if needed."
}
capture confirm variable agency_count
if _rc {
    di as err "Variable 'agency_count' not found -- rename in the variable list below if needed."
}

local depvars   "net_change_bp gross_buys_bp gross_sells_bp delta_holdings share"
local deplabs   `" "Net Change (bp)" "Gross Buys (bp)" "Gross Sells (bp)" "Delta Holdings (bp, non-winsorized)" "Holding Share (% of offering)" "'

local bondvars  "ttm offering_amt_bln yield agency_count"
local bondlabs  `" "Time to Maturity (years)" "Offering Amount (bln $)" "Yield (%)" "Rating Agencies (count)" "'

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
putdocx text ("This table reports descriptive statistics for the variables used in this research within the ")
putdocx text ("main event-window sample. The sample comprises bond-fund-firm-quarter observations of constrained ")
putdocx text ("investors (Life Insurers, Other Insurers, P&C Insurers, Passive Mutual Funds, and Variable ")
putdocx text ("Annuities) for bonds ever downgraded by S&P, Moody's, or Fitch, restricted to relative time in ")
putdocx text ("[-8,+8] quarters around the first downgrade and to bond-quarters at least three quarters after ")
putdocx text ("issuance (Clean Window). Net Change, Gross Buys, and Gross Sells are pre-winsorized at the 1st ")
putdocx text ("and 99th percentiles within fundtype and expressed in basis points of the offering amount. ")
putdocx text ("Delta Holdings is the non-winsorized counterpart, computed as the quarter-on-quarter change in ")
putdocx text ("position scaled by offering amount and expressed in basis points. Holding Share is the ")
putdocx text ("quarter-end position scaled by the offering amount, expressed in percent. Time to Maturity is ")
putdocx text ("measured in years. Offering Amount is expressed in billions of dollars. Yield is in percent. ")
putdocx text ("Rating Agencies is the count of rating agencies (S&P, Moody's, Fitch) with a non-missing rating ")
putdocx text ("for the bond-quarter.")

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

putdocx table tbl(`row',1) = ("Bond characteristics"), italic halign(left)
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

putdocx save "${out}/Descriptive/Table4_DescriptiveStatistics.docx", replace


*=============================================================*
* TABLE 5: Descriptive Statistics by Investor Type            *
*=============================================================*

use "${root}/_event_sample_main.dta", clear

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

foreach v in net_change_bp gross_buys_bp gross_sells_bp {
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
putdocx text ("This table reports descriptive statistics of the three trading-outcome variables by investor ")
putdocx text ("type within the main event-window sample, comprising bond-fund-firm-quarter observations of ")
putdocx text ("constrained investors for bonds ever downgraded by S&P, Moody's, or Fitch, restricted to ")
putdocx text ("relative time in [-8,+8] quarters around the first downgrade and to bond-quarters at least ")
putdocx text ("three quarters after issuance (Clean Window). Panel A reports the quarterly net change in ")
putdocx text ("bond holdings, Panel B reports gross buys, and Panel C reports gross sells. All three are ")
putdocx text ("expressed in basis points of the offering amount and pre-winsorized at the 1st and 99th ")
putdocx text ("percentiles within fundtype. Gross sells are reported as positive values. The All ")
putdocx text ("Constrained row pools the five investor types.")

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

putdocx table tbl(2,1) = ("Panel A: Net Change (bp of offering amount)"), italic halign(left)
putdocx table tbl(2,1), colspan(7)

local row = 3
forvalues k = 1/`ntypes' {
    local lab : word `k' of `typelabels'
    putdocx table tbl(`row',1) = ("`lab'"),                       halign(left)
    putdocx table tbl(`row',2) = ("`net_change_bp_n_`k''"),       halign(right)
    putdocx table tbl(`row',3) = ("`net_change_bp_mn_`k''"),      halign(right)
    putdocx table tbl(`row',4) = ("`net_change_bp_sd_`k''"),      halign(right)
    putdocx table tbl(`row',5) = ("`net_change_bp_p25_`k''"),     halign(right)
    putdocx table tbl(`row',6) = ("`net_change_bp_p50_`k''"),     halign(right)
    putdocx table tbl(`row',7) = ("`net_change_bp_p75_`k''"),     halign(right)
    local ++row
}

putdocx table tbl(`row',1) = ("Panel B: Gross Buys (bp of offering amount)"), italic halign(left)
putdocx table tbl(`row',1), colspan(7)
local ++row

forvalues k = 1/`ntypes' {
    local lab : word `k' of `typelabels'
    putdocx table tbl(`row',1) = ("`lab'"),                       halign(left)
    putdocx table tbl(`row',2) = ("`gross_buys_bp_n_`k''"),       halign(right)
    putdocx table tbl(`row',3) = ("`gross_buys_bp_mn_`k''"),      halign(right)
    putdocx table tbl(`row',4) = ("`gross_buys_bp_sd_`k''"),      halign(right)
    putdocx table tbl(`row',5) = ("`gross_buys_bp_p25_`k''"),     halign(right)
    putdocx table tbl(`row',6) = ("`gross_buys_bp_p50_`k''"),     halign(right)
    putdocx table tbl(`row',7) = ("`gross_buys_bp_p75_`k''"),     halign(right)
    local ++row
}

putdocx table tbl(`row',1) = ("Panel C: Gross Sells (bp of offering amount, positive)"), italic halign(left)
putdocx table tbl(`row',1), colspan(7)
local ++row

forvalues k = 1/`ntypes' {
    local lab : word `k' of `typelabels'
    putdocx table tbl(`row',1) = ("`lab'"),                       halign(left)
    putdocx table tbl(`row',2) = ("`gross_sells_bp_n_`k''"),      halign(right)
    putdocx table tbl(`row',3) = ("`gross_sells_bp_mn_`k''"),     halign(right)
    putdocx table tbl(`row',4) = ("`gross_sells_bp_sd_`k''"),     halign(right)
    putdocx table tbl(`row',5) = ("`gross_sells_bp_p25_`k''"),    halign(right)
    putdocx table tbl(`row',6) = ("`gross_sells_bp_p50_`k''"),    halign(right)
    putdocx table tbl(`row',7) = ("`gross_sells_bp_p75_`k''"),    halign(right)
    local ++row
}

local lastrow = `row' - 1
putdocx table tbl(`lastrow',.), border(bottom, single)

putdocx save "${out}/Descriptive/Table5_DescStats_ByInvestor.docx", replace


********************************************************************
*** End
********************************************************************
