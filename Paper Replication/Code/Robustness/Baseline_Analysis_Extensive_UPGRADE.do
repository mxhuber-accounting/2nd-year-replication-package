********************************************************************
*** 2c_upgrade. Baseline Analysis -- Extensive margin (UPGRADES)
***
*** Input:  ${data}/_master.dta  (built by Build_Master.do)
*** Outputs (all in ${out}):
***   Figure_extensive_descriptive_up.png  (LI vs PMF flow lines, side by side)
***   Figure_entry_exit_descriptive_up.png
***   Table4_extensive_baseline_up.docx    (3 DVs x 2 samples = 6 cols)
***   Table5_extensive_FE_up.docx          (progressive FE on net_change_bp)
***   Table6a_sample_composition_up.docx
***   Table6b_outlook_triple_up.docx
***   Table6c_CDS_triple_up.docx
***   Table8_entry_exit_up.docx
***
*** Event clock built inline from UpgradeAny.  Uses ev_window and rel_time_ev
*** as names so nothing clashes with anything that may already exist in master.
*** Sample: full _master.dta panel; Clean_Window applied at regression time.
*** Investors: LI (fundtype_det_num == 1) and PMF (fundtype_det_num == 5).
***
*** UpgradeAny is constructed inline from SPRchange / MRchange / FRchange.
*** Convention: in the master panel, rating *increases* in numerical scale
*** correspond to DOWNGRADES.  UPGRADES are therefore negative changes
*** (rating improves -> numerical value decreases).  Mirror the existing
*** DowngradeAny construction with the opposite inequality.
********************************************************************

clear all
set more off
set varabbrev off
version 17

* ============= SET PATHS =============
global root "${REPL}"
* Working-sample directory (set by setup.do: shipped / reference / raw).
* Falls back to Data/Working Files/ if run standalone without setup.do.
if "${wsdir}" == "" global wsdir "${root}/Data/Working Files"
global data "${wsdir}"
global out  "${root}/Paper Replication/Figures and Tables/Baseline_Analysis_Extensive_Upgrades"
* =====================================
cap mkdir "${root}/Paper Replication/Figures and Tables"
cap mkdir "${out}"


********************************************************************
*** Load and sanity check
********************************************************************

use "${data}/_master.dta", clear

foreach v in SPRchange MRchange FRchange Clean_Window net_change_bp gross_buys_bp ///
             gross_sells_bp entry exit issueID issuerID qdate fundtype_det_num    ///
             CDS_spread paramt fundid {
    cap confirm variable `v'
    if _rc {
        di as err "Variable '`v'' not found in _master.dta."
        exit 111
    }
}


********************************************************************
*** Build UpgradeSPR / UpgradeMR / UpgradeFR / UpgradeAny
*** Rating numerical scale: higher = worse credit, so an UPGRADE
*** corresponds to a NEGATIVE change in the rating number.
********************************************************************

cap drop UpgradeSPR UpgradeMR UpgradeFR UpgradeAny

gen byte UpgradeSPR = (SPRchange > 0) if !missing(SPRchange)
gen byte UpgradeMR  = (MRchange  > 0) if !missing(MRchange)
gen byte UpgradeFR  = (FRchange  > 0) if !missing(FRchange)

gen byte UpgradeAny = (UpgradeSPR == 1) | (UpgradeMR == 1) | (UpgradeFR == 1)


********************************************************************
*** Inline event clock relative to each bond's FIRST UpgradeAny
********************************************************************

cap drop _ev_q
cap drop rel_time_ev

preserve
    bysort issueID qdate: keep if _n == 1
    keep issueID qdate UpgradeAny
    gen long _ev_q_obs = qdate if UpgradeAny == 1
    bysort issueID: egen _ev_q = min(_ev_q_obs)
    format _ev_q %tq
    bysort issueID: keep if _n == 1
    keep issueID _ev_q
    tempfile _evclk
    save `_evclk'
restore

merge m:1 issueID using `_evclk', keep(master match) nogen

drop if missing(_ev_q)
gen int rel_time_ev = qdate - _ev_q
drop if !inrange(rel_time_ev, -8, 8)


********************************************************************
*** Event-window dummy
********************************************************************

cap drop ev_window
gen byte ev_window = .
replace  ev_window = 0 if inrange(rel_time_ev, -8, -5)
replace  ev_window = 1 if inrange(rel_time_ev, -4, -1)
replace  ev_window = 2 if rel_time_ev == 0
replace  ev_window = 3 if inrange(rel_time_ev,  1,  4)
replace  ev_window = 4 if inrange(rel_time_ev,  5,  8)
label define evwinlbl 0 "Pre_2Y" 1 "Pre_1Y" 2 "Upgrade" 3 "Post_1Y" 4 "Post_2Y", replace
label values ev_window evwinlbl


********************************************************************
*** Balanced flag computed BEFORE fundtype restriction
********************************************************************

cap drop _tag _nq bond_balanced
bysort issueID rel_time_ev: gen byte _tag = (_n == 1)
bysort issueID: egen _nq = total(_tag)
gen byte bond_balanced = (_nq == 17)
drop _tag _nq


********************************************************************
*** Bond-level pre-event partition flags (rel_time_ev in [-8,-5])
********************************************************************

cap confirm variable outlook_improvement
local has_outlook = (_rc == 0)

cap drop outlook_pre
if `has_outlook' {
    gen byte _outlook_in_pre = (outlook_improvement == 1) & inrange(rel_time_ev, -8, -5)
    bysort issueID: egen outlook_pre = max(_outlook_in_pre)
    drop _outlook_in_pre
}
else {
    di as txt "Note: outlook_improvement missing -- outlook triple will be skipped."
}

cap drop CDS_pre
gen byte _cds_in_pre = (!missing(CDS_spread)) & inrange(rel_time_ev, -8, -5)
bysort issueID: egen CDS_pre = max(_cds_in_pre)
drop _cds_in_pre


********************************************************************
*** Holding indicators for entry/exit at-risk samples
********************************************************************

cap drop held held_lag ever_held

gen byte held = (paramt > 0 & !missing(paramt))

sort fundid issueID qdate
by fundid issueID: gen byte held_lag = held[_n-1] if qdate == qdate[_n-1] + 1
by fundid issueID: egen byte ever_held = max(held)


********************************************************************
*** Restrict to LI and PMF
********************************************************************

keep if inlist(fundtype_det_num, 1, 5)
gen byte LI = (fundtype_det_num == 1)
label variable LI "Life Insurer"


********************************************************************
*** Section A. Descriptive figures
********************************************************************

preserve
    keep if Clean_Window == 1
    keep if bond_balanced == 1

    collapse (mean) m_net = net_change_bp m_buy = gross_buys_bp m_sell = gross_sells_bp, ///
             by(fundtype_det_num rel_time_ev)

    replace m_sell = -m_sell

    foreach ft in 1 5 {
        if `ft' == 1 local lab "Life Insurers"
        if `ft' == 5 local lab "Passive Mutual Funds"
        local gname = cond(`ft' == 1, "desc_li_up", "desc_pmf_up")

        twoway ///
            (connected m_buy  rel_time_ev if fundtype_det_num == `ft', ///
                lcolor(gs6)   mcolor(gs6)   msymbol(diamond)  ///
                lwidth(medthick) msize(small) lpattern(dash)) ///
            (connected m_sell rel_time_ev if fundtype_det_num == `ft', ///
                lcolor(gs10)  mcolor(gs10)  msymbol(triangle) ///
                lwidth(medthick) msize(small) lpattern(dot)) ///
            (connected m_net  rel_time_ev if fundtype_det_num == `ft', ///
                lcolor(black) mcolor(black) msymbol(circle)   ///
                lwidth(medthick) msize(small) lpattern(solid)) ///
            , ///
            xline(0, lcolor(gs10) lpattern(dash) lwidth(thin)) ///
            yline(0, lcolor(red) lpattern(dash) lwidth(thin)) ///
            xlabel(-8(2)8, labsize(small) nogrid) ///
            ylabel(, labsize(small) angle(0) nogrid) ///
            xtitle("Quarters Relative to Upgrade", size(small)) ///
            ytitle("Mean Flow (bp of offering amount; sells inverted)", size(small)) ///
            title("`lab'", size(medium) color(black)) ///
            legend(order(1 "Gross Buys" 2 "Gross Sells" 3 "Net Change") ///
                   size(small) rows(1) position(6) ring(1) ///
                   region(lcolor(black) lwidth(thin))) ///
            graphregion(color(white)) bgcolor(white) ///
            plotregion(margin(small) lcolor(gs10)) ///
            name(`gname', replace)
    }

    graph combine desc_li_up desc_pmf_up, rows(1) ///
        graphregion(color(white)) name(desc_combined_up, replace)
    graph export "${out}/Figure_extensive_descriptive_up.png", replace width(2400)
restore


preserve
    keep if Clean_Window == 1
    collapse (mean) m_entry = entry m_exit = exit, ///
             by(fundtype_det_num rel_time_ev)
    replace m_exit = -m_exit
    foreach ft in 1 5 {
        if `ft' == 1 local lab "Life Insurers"
        if `ft' == 5 local lab "Passive Mutual Funds"
        local gname = cond(`ft' == 1, "desc_ee_li_up", "desc_ee_pmf_up")
        twoway ///
            (connected m_entry rel_time_ev if fundtype_det_num == `ft', ///
                lcolor(gs6)   mcolor(gs6)   msymbol(diamond) ///
                lwidth(medthick) msize(small) lpattern(dash)) ///
            (connected m_exit  rel_time_ev if fundtype_det_num == `ft', ///
                lcolor(gs10)  mcolor(gs10)  msymbol(triangle) ///
                lwidth(medthick) msize(small) lpattern(dot)) ///
            , ///
            xline(0, lcolor(gs10) lpattern(dash) lwidth(thin)) ///
            yline(0, lcolor(red) lpattern(dash) lwidth(thin)) ///
            xlabel(-8(2)8, labsize(small) nogrid) ///
            ylabel(, labsize(small) angle(0) nogrid) ///
            xtitle("Quarters Relative to Upgrade", size(small)) ///
            ytitle("Entry / Exit Probability (exit inverted)", size(small)) ///
            title("`lab'", size(medium) color(black)) ///
            legend(order(1 "Prob(Entry)" 2 "Prob(Exit)") ///
                   size(small) rows(1) position(6) ring(1) ///
                   region(lcolor(black) lwidth(thin))) ///
            graphregion(color(white)) bgcolor(white) ///
            plotregion(margin(small) lcolor(gs10)) ///
            name(`gname', replace)
    }
    graph combine desc_ee_li_up desc_ee_pmf_up, rows(1) ///
        graphregion(color(white)) name(desc_ee_combined_up, replace)
    graph export "${out}/Figure_entry_exit_descriptive_up.png", replace width(2400)
restore


********************************************************************
*** Section B. Table 4 -- three flow outcomes x (unbal | bal)
********************************************************************

estimates clear

local dvs       net_change_bp  gross_sells_bp  gross_buys_bp

local m = 0
foreach dv of local dvs {
    local ++m

    reghdfe `dv' ib(0).ev_window##ib(0).LI                                ///
        if Clean_Window == 1,                                             ///
        absorb(issueID#qdate) cluster(issuerID)
    estimates store t4_m`m'_u

    reghdfe `dv' ib(0).ev_window##ib(0).LI                                ///
        if Clean_Window == 1 & bond_balanced == 1,                        ///
        absorb(issueID#qdate) cluster(issuerID)
    estimates store t4_m`m'_b
}

{
local win_levs  "1 2 3 4"
local win_labs `" "Pre_1Y" "Upgrade" "Post_1Y" "Post_2Y" "'
local n_w = 4

local models    t4_m1_u t4_m1_b t4_m2_u t4_m2_b t4_m3_u t4_m3_b
local sub_labs `" "Unbal." "Bal." "Unbal." "Bal." "Unbal." "Bal." "'
local n_m = 6

local total_rows = 3 + 2*`n_w' + 4
local total_cols = 1 + `n_m'

putdocx clear
putdocx begin

putdocx paragraph, halign(center)
putdocx text ("TABLE 4."), bold
putdocx paragraph, halign(center)
putdocx text ("Trading Flows Around Upgrades -- Life Insurers vs Passive MFs."), bold

putdocx paragraph, halign(both)
putdocx text ("This table reports event-window coefficients of three flow outcomes -- net_change_bp, gross_sells_bp, and gross_buys_bp -- on the interaction of event-window indicators with a Life Insurer dummy. All flows are in basis points of offering amount and are defined over the full bond-fund-quarter panel. For each outcome, columns report the regression on the unbalanced sample (Clean_Window equal to 1) and on the balanced sample (bonds observed in all 17 event quarters in the full pre-restriction panel). The omitted reference group is Passive Mutual Funds in the omitted window (Pre_2Y, rel_time -8 to -5). Pre_1Y covers -4 to -1, Upgrade is rel_time 0, Post_1Y covers 1 to 4, Post_2Y covers 5 to 8. Fixed effects are issue-by-quarter. Standard errors clustered by issuer in parentheses. *, **, and *** denote statistical significance at the 10%, 5%, and 1% levels, respectively.")

putdocx paragraph

putdocx table tbl = (`total_rows', `total_cols'), border(all, nil)

putdocx table tbl(1,1) = (""), bold halign(left)
putdocx table tbl(1,6) = ("Gross Buys"),  bold halign(center)
putdocx table tbl(1,6), colspan(2)
putdocx table tbl(1,4) = ("Gross Sells"), bold halign(center)
putdocx table tbl(1,4), colspan(2)
putdocx table tbl(1,2) = ("Net Change"),  bold halign(center)
putdocx table tbl(1,2), colspan(2)
putdocx table tbl(1,.), border(top, single)

putdocx table tbl(2,1) = (""), halign(left)
forvalues j = 1/`n_m' {
    local sl : word `j' of `sub_labs'
    local col = `j' + 1
    putdocx table tbl(2,`col') = ("`sl'"), bold halign(right)
}

putdocx table tbl(3,1) = ("Window x Life Insurer"), bold halign(left)
forvalues j = 1/`n_m' {
    local col = `j' + 1
    putdocx table tbl(3,`col') = ("(`j')"), bold halign(right)
}
putdocx table tbl(3,.), border(bottom, single)

local r = 4
forvalues i = 1/`n_w' {
    local lv  : word `i' of `win_levs'
    local lab : word `i' of `win_labs'

    putdocx table tbl(`r',1) = ("`lab' x LI"), halign(left)
    forvalues j = 1/`n_m' {
        local mname : word `j' of `models'
        local col   = `j' + 1
        qui estimates restore `mname'
        local b  = _b[`lv'.ev_window#1.LI]
        local se = _se[`lv'.ev_window#1.LI]
        local p  = 2*ttail(e(df_r), abs(`b'/`se'))
        local stars ""
        if `p' < 0.01      local stars "***"
        else if `p' < 0.05 local stars "**"
        else if `p' < 0.10 local stars "*"
        putdocx table tbl(`r',`col') = (string(`b', "%12.3fc") + "`stars'"), halign(right)
    }
    local ++r

    putdocx table tbl(`r',1) = (""), halign(left)
    forvalues j = 1/`n_m' {
        local mname : word `j' of `models'
        local col   = `j' + 1
        qui estimates restore `mname'
        local se = _se[`lv'.ev_window#1.LI]
        putdocx table tbl(`r',`col') = ("(" + string(`se', "%12.3fc") + ")"), halign(right)
    }
    local ++r
}

local last_coef = `r' - 1
putdocx table tbl(`last_coef',.), border(bottom, single)

putdocx table tbl(`r',1) = ("Issue x Quarter FE"), halign(left)
forvalues j = 1/`n_m' {
    local col = `j' + 1
    putdocx table tbl(`r',`col') = ("Yes"), halign(right)
}
local ++r

putdocx table tbl(`r',1) = ("Observations"), halign(left)
forvalues j = 1/`n_m' {
    local mname : word `j' of `models'
    local col   = `j' + 1
    qui estimates restore `mname'
    putdocx table tbl(`r',`col') = ("`: display %12.0fc e(N)'"), halign(right)
}
local ++r

putdocx table tbl(`r',1) = ("R-squared"), halign(left)
forvalues j = 1/`n_m' {
    local mname : word `j' of `models'
    local col   = `j' + 1
    qui estimates restore `mname'
    putdocx table tbl(`r',`col') = ("`: display %12.3fc e(r2)'"), halign(right)
}
local ++r

putdocx table tbl(`r',1) = ("Clusters (Issuers)"), halign(left)
forvalues j = 1/`n_m' {
    local mname : word `j' of `models'
    local col   = `j' + 1
    qui estimates restore `mname'
    putdocx table tbl(`r',`col') = ("`: display %12.0fc e(N_clust)'"), halign(right)
}
putdocx table tbl(`r',.), border(bottom, single)

putdocx save "${out}/Table4_extensive_baseline_up.docx", replace
}


********************************************************************
*** Section C. Table 5 -- progressive FE for LI x ev_window on net_change_bp
********************************************************************

estimates clear

cap drop bond_age
gen int bond_age = qdate - qoffering
reghdfe net_change_bp c.bond_age##ib(0).ev_window##ib(0).LI ///
    if Clean_Window == 1, absorb(issueID#qdate) cluster(issuerID)

reghdfe net_change_bp ib(0).ev_window##ib(0).LI                            ///
    if Clean_Window == 1,                                                  ///
    noabsorb cluster(issuerID)
estimates store t5_c1

reghdfe net_change_bp ib(0).ev_window##ib(0).LI                            ///
    if Clean_Window == 1,                                                  ///
    absorb(issueID qdate) cluster(issuerID)
estimates store t5_c2

reghdfe net_change_bp ib(0).ev_window##ib(0).LI                            ///
    if Clean_Window == 1,                                                  ///
    absorb(issuerID#qdate) cluster(issuerID)
estimates store t5_c3

reghdfe net_change_bp ib(0).ev_window##ib(0).LI                            ///
    if Clean_Window == 1,                                                  ///
    absorb(issueID#qdate) cluster(issuerID)
estimates store t5_c4

{
local win_levs  "1 2 3 4"
local win_labs `" "Pre_1Y" "Upgrade" "Post_1Y" "Post_2Y" "'
local n_w = 4

local models    t5_c1 t5_c2 t5_c3 t5_c4
local mod_labs `" "(1)" "(2)" "(3)" "(4)" "'
local n_m = 4

local total_rows = 2 + 2*`n_w' + 7
local total_cols = 1 + `n_m'

putdocx clear
putdocx begin

putdocx paragraph, halign(center)
putdocx text ("TABLE 5."), bold
putdocx paragraph, halign(center)
putdocx text ("Net Change Around Upgrades -- Progressive Fixed-Effects Specifications."), bold

putdocx paragraph, halign(both)
putdocx text ("This table reports event-window coefficients of net_change_bp on Life Insurer x window indicators across four fixed-effects specifications. Column (1) includes no fixed effects. Column (2) adds issue and quarter fixed effects separately. Column (3) adds issuer-by-quarter fixed effects. Column (4) adds issue-by-quarter fixed effects. The omitted reference group is Passive Mutual Funds in the omitted window (Pre_2Y). Standard errors clustered by issuer in parentheses. *, **, and *** denote statistical significance at the 10%, 5%, and 1% levels, respectively.")

putdocx paragraph

putdocx table tbl = (`total_rows', `total_cols'), border(all, nil)

putdocx table tbl(1,1) = (""), bold halign(left)
putdocx table tbl(1,2) = ("Net Change (bp of offering amount)"), bold halign(center)
putdocx table tbl(1,2), colspan(`n_m')
putdocx table tbl(1,.), border(top, single)

putdocx table tbl(2,1) = ("Window x Life Insurer"), bold halign(left)
forvalues j = 1/`n_m' {
    local mlab : word `j' of `mod_labs'
    local col = `j' + 1
    putdocx table tbl(2,`col') = ("`mlab'"), bold halign(right)
}
putdocx table tbl(2,.), border(bottom, single)

local r = 3
forvalues i = 1/`n_w' {
    local lv  : word `i' of `win_levs'
    local lab : word `i' of `win_labs'

    putdocx table tbl(`r',1) = ("`lab' x LI"), halign(left)
    forvalues j = 1/`n_m' {
        local mname : word `j' of `models'
        local col   = `j' + 1
        qui estimates restore `mname'
        local b  = _b[`lv'.ev_window#1.LI]
        local se = _se[`lv'.ev_window#1.LI]
        local p  = 2*ttail(e(df_r), abs(`b'/`se'))
        local stars ""
        if `p' < 0.01      local stars "***"
        else if `p' < 0.05 local stars "**"
        else if `p' < 0.10 local stars "*"
        putdocx table tbl(`r',`col') = (string(`b', "%12.3fc") + "`stars'"), halign(right)
    }
    local ++r

    putdocx table tbl(`r',1) = (""), halign(left)
    forvalues j = 1/`n_m' {
        local mname : word `j' of `models'
        local col   = `j' + 1
        qui estimates restore `mname'
        local se = _se[`lv'.ev_window#1.LI]
        putdocx table tbl(`r',`col') = ("(" + string(`se', "%12.3fc") + ")"), halign(right)
    }
    local ++r
}

local last_coef = `r' - 1
putdocx table tbl(`last_coef',.), border(bottom, single)

local fe_issue   "No Yes No  No"
local fe_qtr     "No Yes No  No"
local fe_iss_q   "No No  Yes No"
local fe_isb_q   "No No  No  Yes"

local fe_labs `" "Issue FE" "Quarter FE" "Issuer x Quarter FE" "Issue x Quarter FE" "'
local fe_vars  fe_issue fe_qtr fe_iss_q fe_isb_q

forvalues k = 1/4 {
    local row_lab : word `k' of `fe_labs'
    local row_var : word `k' of `fe_vars'
    putdocx table tbl(`r',1) = ("`row_lab'"), halign(left)
    forvalues j = 1/`n_m' {
        local col = `j' + 1
        local val : word `j' of ``row_var''
        putdocx table tbl(`r',`col') = ("`val'"), halign(right)
    }
    local ++r
}

putdocx table tbl(`r',1) = ("Observations"), halign(left)
forvalues j = 1/`n_m' {
    local mname : word `j' of `models'
    local col   = `j' + 1
    qui estimates restore `mname'
    putdocx table tbl(`r',`col') = ("`: display %12.0fc e(N)'"), halign(right)
}
local ++r

putdocx table tbl(`r',1) = ("R-squared"), halign(left)
forvalues j = 1/`n_m' {
    local mname : word `j' of `models'
    local col   = `j' + 1
    qui estimates restore `mname'
    putdocx table tbl(`r',`col') = ("`: display %12.3fc e(r2)'"), halign(right)
}
local ++r

putdocx table tbl(`r',1) = ("Clusters (Issuers)"), halign(left)
forvalues j = 1/`n_m' {
    local mname : word `j' of `models'
    local col   = `j' + 1
    qui estimates restore `mname'
    putdocx table tbl(`r',`col') = ("`: display %12.0fc e(N_clust)'"), halign(right)
}
putdocx table tbl(`r',.), border(bottom, single)

putdocx save "${out}/Table5_extensive_FE_up.docx", replace
}


********************************************************************
*** Section D. Sample composition + partition triples
********************************************************************

cap confirm variable outlook_pre
local has_outlook = (_rc == 0)

* ---- Table 6a: sample composition ----
{
preserve
    keep if Clean_Window == 1

    local n_li_out0 = 0
    local n_li_out1 = 0
    local n_pm_out0 = 0
    local n_pm_out1 = 0
    if `has_outlook' {
        qui count if LI == 1 & outlook_pre == 0
        local n_li_out0 = r(N)
        qui count if LI == 1 & outlook_pre == 1
        local n_li_out1 = r(N)
        qui count if LI == 0 & outlook_pre == 0
        local n_pm_out0 = r(N)
        qui count if LI == 0 & outlook_pre == 1
        local n_pm_out1 = r(N)
    }
    qui count if LI == 1 & CDS_pre == 0
    local n_li_cds0 = r(N)
    qui count if LI == 1 & CDS_pre == 1
    local n_li_cds1 = r(N)
    qui count if LI == 0 & CDS_pre == 0
    local n_pm_cds0 = r(N)
    qui count if LI == 0 & CDS_pre == 1
    local n_pm_cds1 = r(N)

    putdocx clear
    putdocx begin

    putdocx paragraph, halign(center)
    putdocx text ("TABLE 6a. Sample Composition by Investor Type and Pre-Event Flag (Upgrades)."), bold

    putdocx paragraph, halign(both)
    putdocx text ("Observation counts (fund-bond-quarter) in the regression sample (Clean_Window equal to 1) by investor type and the value of the bond-level pre-event flag. Outlook equals 1 if the bond has any outlook improvement in rel_time -8 to -5. CDS equals 1 if the bond has any non-missing CDS spread observation in rel_time -8 to -5.")

    putdocx paragraph

    putdocx table tbl = (4, 5), border(all, nil)

    putdocx table tbl(1,1) = (""),            bold halign(left)
    putdocx table tbl(1,2) = ("Outlook = 0"), bold halign(right)
    putdocx table tbl(1,3) = ("Outlook = 1"), bold halign(right)
    putdocx table tbl(1,4) = ("CDS = 0"),     bold halign(right)
    putdocx table tbl(1,5) = ("CDS = 1"),     bold halign(right)
    putdocx table tbl(1,.), border(top, single)
    putdocx table tbl(1,.), border(bottom, single)

    putdocx table tbl(2,1) = ("Life Insurers"),                halign(left)
    putdocx table tbl(2,2) = (string(`n_li_out0', "%12.0fc")), halign(right)
    putdocx table tbl(2,3) = (string(`n_li_out1', "%12.0fc")), halign(right)
    putdocx table tbl(2,4) = (string(`n_li_cds0', "%12.0fc")), halign(right)
    putdocx table tbl(2,5) = (string(`n_li_cds1', "%12.0fc")), halign(right)

    putdocx table tbl(3,1) = ("Passive Mutual Funds"),         halign(left)
    putdocx table tbl(3,2) = (string(`n_pm_out0', "%12.0fc")), halign(right)
    putdocx table tbl(3,3) = (string(`n_pm_out1', "%12.0fc")), halign(right)
    putdocx table tbl(3,4) = (string(`n_pm_cds0', "%12.0fc")), halign(right)
    putdocx table tbl(3,5) = (string(`n_pm_cds1', "%12.0fc")), halign(right)

    local tot_out0 = `n_li_out0' + `n_pm_out0'
    local tot_out1 = `n_li_out1' + `n_pm_out1'
    local tot_cds0 = `n_li_cds0' + `n_pm_cds0'
    local tot_cds1 = `n_li_cds1' + `n_pm_cds1'
    putdocx table tbl(4,1) = ("Total"),                       bold halign(left)
    putdocx table tbl(4,2) = (string(`tot_out0', "%12.0fc")), bold halign(right)
    putdocx table tbl(4,3) = (string(`tot_out1', "%12.0fc")), bold halign(right)
    putdocx table tbl(4,4) = (string(`tot_cds0', "%12.0fc")), bold halign(right)
    putdocx table tbl(4,5) = (string(`tot_cds1', "%12.0fc")), bold halign(right)
    putdocx table tbl(4,.), border(top, single)
    putdocx table tbl(4,.), border(bottom, single)

    putdocx save "${out}/Table6a_sample_composition_up.docx", replace
restore
}

* ---- Tables 6b and 6c: outlook and CDS partition triples ----

local flag_vars    outlook_pre  CDS_pre
local flag_pretty `" "Outlook"  "CDS Coverage" "'
local flag_files   Table6b_outlook_triple_up Table6c_CDS_triple_up
local flag_titles `" "Outlook Pre-Event Partition Triple (Upgrades)"  "CDS-Coverage Pre-Event Partition Triple (Upgrades)" "'

forvalues k = 1/2 {
    local flag       : word `k' of `flag_vars'
    local flab       : word `k' of `flag_pretty'
    local ffile      : word `k' of `flag_files'
    local ftitle     : word `k' of `flag_titles'

    if "`flag'" == "outlook_pre" {
        cap confirm variable outlook_pre
        if _rc {
            di as txt "Skipping `flab' triple -- outlook_pre missing."
            continue
        }
    }

    estimates clear

    reghdfe net_change_bp ib(0).ev_window##ib(0).LI##ib(0).`flag'         ///
        if Clean_Window == 1,                                             ///
        absorb(issueID#qdate) cluster(issuerID)
    estimates store m_unbal

    reghdfe net_change_bp ib(0).ev_window##ib(0).LI##ib(0).`flag'         ///
        if Clean_Window == 1 & bond_balanced == 1,                        ///
        absorb(issueID#qdate) cluster(issuerID)
    estimates store m_bal

    local win_levs  "1 2 3 4"
    local win_labs `" "Pre_1Y" "Upgrade" "Post_1Y" "Post_2Y" "'
    local n_w = 4

    local models    m_unbal m_bal
    local mod_labs `" "Unbalanced" "Balanced" "'
    local n_m = 2

    local total_rows = 2 + 4*`n_w' + 4
    local total_cols = 1 + `n_m'

    putdocx clear
    putdocx begin

    putdocx paragraph, halign(center)
    putdocx text ("TABLE. `ftitle'."), bold

    putdocx paragraph, halign(both)
    putdocx text ("This table reports event-window coefficients of net_change_bp on a Life Insurer dummy and its interaction with a bond-level pre-event `flab' flag. The flag equals 1 if the bond has any `flab' signal in rel_time -8 to -5 and 0 otherwise. Column (1) uses the full event-window sample; column (2) restricts to bonds observed in all 17 event quarters (the balanced sample). Each window block reports the LI x Window coefficient (the baseline gap on bonds without the signal) and the LI x Window x Flag triple (the additional gap on signal-flagged bonds). Fixed effects are issue-by-quarter throughout. Standard errors clustered by issuer in parentheses. *, **, and *** denote significance at the 10%, 5%, and 1% levels.")

    putdocx paragraph

    putdocx table tbl = (`total_rows', `total_cols'), border(all, nil)

    putdocx table tbl(1,1) = (""), bold halign(left)
    putdocx table tbl(1,2) = ("Net Change (bp of offering amount)"), bold halign(center)
    putdocx table tbl(1,2), colspan(`n_m')
    putdocx table tbl(1,.), border(top, single)

    putdocx table tbl(2,1) = (""), bold halign(left)
    forvalues j = 1/`n_m' {
        local mlab : word `j' of `mod_labs'
        local col = `j' + 1
        putdocx table tbl(2,`col') = ("`mlab'"), bold halign(right)
    }
    putdocx table tbl(2,.), border(bottom, single)

    local r = 3
    forvalues i = 1/`n_w' {
        local lv  : word `i' of `win_levs'
        local lab : word `i' of `win_labs'

        putdocx table tbl(`r',1) = ("`lab' x LI"), halign(left)
        forvalues j = 1/`n_m' {
            local mname : word `j' of `models'
            local col   = `j' + 1
            qui estimates restore `mname'
            local b  = _b[`lv'.ev_window#1.LI]
            local se = _se[`lv'.ev_window#1.LI]
            local p  = 2*ttail(e(df_r), abs(`b'/`se'))
            local stars ""
            if `p' < 0.01      local stars "***"
            else if `p' < 0.05 local stars "**"
            else if `p' < 0.10 local stars "*"
            putdocx table tbl(`r',`col') = (string(`b', "%12.3fc") + "`stars'"), halign(right)
        }
        local ++r

        putdocx table tbl(`r',1) = (""), halign(left)
        forvalues j = 1/`n_m' {
            local mname : word `j' of `models'
            local col   = `j' + 1
            qui estimates restore `mname'
            local se = _se[`lv'.ev_window#1.LI]
            putdocx table tbl(`r',`col') = ("(" + string(`se', "%12.3fc") + ")"), halign(right)
        }
        local ++r

        putdocx table tbl(`r',1) = ("`lab' x LI x `flab'"), halign(left)
        forvalues j = 1/`n_m' {
            local mname : word `j' of `models'
            local col   = `j' + 1
            qui estimates restore `mname'
            local b  = _b[`lv'.ev_window#1.LI#1.`flag']
            local se = _se[`lv'.ev_window#1.LI#1.`flag']
            local p  = 2*ttail(e(df_r), abs(`b'/`se'))
            local stars ""
            if `p' < 0.01      local stars "***"
            else if `p' < 0.05 local stars "**"
            else if `p' < 0.10 local stars "*"
            putdocx table tbl(`r',`col') = (string(`b', "%12.3fc") + "`stars'"), halign(right)
        }
        local ++r

        putdocx table tbl(`r',1) = (""), halign(left)
        forvalues j = 1/`n_m' {
            local mname : word `j' of `models'
            local col   = `j' + 1
            qui estimates restore `mname'
            local se = _se[`lv'.ev_window#1.LI#1.`flag']
            putdocx table tbl(`r',`col') = ("(" + string(`se', "%12.3fc") + ")"), halign(right)
        }
        local ++r
    }

    local last_coef = `r' - 1
    putdocx table tbl(`last_coef',.), border(bottom, single)

    putdocx table tbl(`r',1) = ("Issue x Quarter FE"), halign(left)
    forvalues j = 1/`n_m' {
        local col = `j' + 1
        putdocx table tbl(`r',`col') = ("Yes"), halign(right)
    }
    local ++r

    putdocx table tbl(`r',1) = ("Observations"), halign(left)
    forvalues j = 1/`n_m' {
        local mname : word `j' of `models'
        local col   = `j' + 1
        qui estimates restore `mname'
        putdocx table tbl(`r',`col') = ("`: display %12.0fc e(N)'"), halign(right)
    }
    local ++r

    putdocx table tbl(`r',1) = ("R-squared"), halign(left)
    forvalues j = 1/`n_m' {
        local mname : word `j' of `models'
        local col   = `j' + 1
        qui estimates restore `mname'
        putdocx table tbl(`r',`col') = ("`: display %12.3fc e(r2)'"), halign(right)
    }
    local ++r

    putdocx table tbl(`r',1) = ("Clusters (Issuers)"), halign(left)
    forvalues j = 1/`n_m' {
        local mname : word `j' of `models'
        local col   = `j' + 1
        qui estimates restore `mname'
        putdocx table tbl(`r',`col') = ("`: display %12.0fc e(N_clust)'"), halign(right)
    }
    putdocx table tbl(`r',.), border(bottom, single)

    putdocx save "${out}/`ffile'.docx", replace
}


********************************************************************
*** Section F. Table 8 -- Entry/Exit, unbalanced | balanced
********************************************************************

estimates clear

reghdfe entry ib(0).ev_window##ib(0).LI                                    ///
    if Clean_Window == 1,                                                  ///
    absorb(issueID#qdate) cluster(issuerID)
estimates store t8_ent_u
qui sum entry if e(sample), meanonly
local mean_t8_ent_u = r(mean)

reghdfe entry ib(0).ev_window##ib(0).LI                                    ///
    if Clean_Window == 1 & bond_balanced == 1,                             ///
    absorb(issueID#qdate) cluster(issuerID)
estimates store t8_ent_b
qui sum entry if e(sample), meanonly
local mean_t8_ent_b = r(mean)

reghdfe exit ib(0).ev_window##ib(0).LI                                     ///
    if Clean_Window == 1,                                                  ///
    absorb(issueID#qdate) cluster(issuerID)
estimates store t8_exi_u
qui sum exit if e(sample), meanonly
local mean_t8_exi_u = r(mean)

reghdfe exit ib(0).ev_window##ib(0).LI                                     ///
    if Clean_Window == 1 & bond_balanced == 1,                             ///
    absorb(issueID#qdate) cluster(issuerID)
estimates store t8_exi_b
qui sum exit if e(sample), meanonly
local mean_t8_exi_b = r(mean)

{
local win_levs  "1 2 3 4"
local win_labs `" "Pre_1Y" "Upgrade" "Post_1Y" "Post_2Y" "'
local n_w = 4

local models    t8_ent_u t8_ent_b t8_exi_u t8_exi_b
local mod_labs `" "Unbalanced" "Balanced" "Unbalanced" "Balanced" "'
local mod_means `mean_t8_ent_u' `mean_t8_ent_b' `mean_t8_exi_u' `mean_t8_exi_b'
local n_m = 4

local total_rows = 3 + 2*`n_w' + 6
local total_cols = 1 + `n_m'

putdocx clear
putdocx begin

putdocx paragraph, halign(center)
putdocx text ("TABLE 8."), bold
putdocx paragraph, halign(center)
putdocx text ("Position Entry and Exit Around Upgrades."), bold

putdocx paragraph, halign(both)
putdocx text ("This table reports linear probability model coefficients of position entry and position exit on the interaction of event-window indicators with a Life Insurer dummy. Entry equals 1 in the quarter a fund initiates a position in a bond. Exit equals 1 in the quarter a fund terminates a position in a bond. Columns (1) and (3) use the full event-window sample (Clean_Window equal to 1). Columns (2) and (4) restrict to bonds observed in all 17 event quarters. The reference group is Passive Mutual Funds in the omitted window (Pre_2Y, rel_time -8 to -5). Coefficients are reported in raw probability units; the row labeled Mean of DV gives the unconditional mean in each column's sample. Fixed effects are issue-by-quarter. Standard errors clustered by issuer in parentheses. *, **, and *** denote significance at the 10%, 5%, and 1% levels.")

putdocx paragraph

putdocx table tbl = (`total_rows', `total_cols'), border(all, nil)

putdocx table tbl(1,1) = (""), bold halign(left)
putdocx table tbl(1,4) = ("Exit"),  bold halign(center)
putdocx table tbl(1,4), colspan(2)
putdocx table tbl(1,2) = ("Entry"), bold halign(center)
putdocx table tbl(1,2), colspan(2)
putdocx table tbl(1,.), border(top, single)

putdocx table tbl(2,1) = (""), halign(left)
forvalues j = 1/`n_m' {
    local mlab : word `j' of `mod_labs'
    local col  = `j' + 1
    putdocx table tbl(2,`col') = ("`mlab'"), bold halign(right)
}

putdocx table tbl(3,1) = ("Window x Life Insurer"), bold halign(left)
forvalues j = 1/`n_m' {
    local col = `j' + 1
    putdocx table tbl(3,`col') = ("(`j')"), bold halign(right)
}
putdocx table tbl(3,.), border(bottom, single)

local r = 4
forvalues i = 1/`n_w' {
    local lv  : word `i' of `win_levs'
    local lab : word `i' of `win_labs'

    putdocx table tbl(`r',1) = ("`lab' x LI"), halign(left)
    forvalues j = 1/`n_m' {
        local mname : word `j' of `models'
        local col   = `j' + 1
        qui estimates restore `mname'
        local b  = _b[`lv'.ev_window#1.LI]
        local se = _se[`lv'.ev_window#1.LI]
        local p  = 2*ttail(e(df_r), abs(`b'/`se'))
        local stars ""
        if `p' < 0.01      local stars "***"
        else if `p' < 0.05 local stars "**"
        else if `p' < 0.10 local stars "*"
        putdocx table tbl(`r',`col') = (string(`b', "%12.4fc") + "`stars'"), halign(right)
    }
    local ++r

    putdocx table tbl(`r',1) = (""), halign(left)
    forvalues j = 1/`n_m' {
        local mname : word `j' of `models'
        local col   = `j' + 1
        qui estimates restore `mname'
        local se = _se[`lv'.ev_window#1.LI]
        putdocx table tbl(`r',`col') = ("(" + string(`se', "%12.4fc") + ")"), halign(right)
    }
    local ++r
}

local last_coef = `r' - 1
putdocx table tbl(`last_coef',.), border(bottom, single)

putdocx table tbl(`r',1) = ("Issue x Quarter FE"), halign(left)
forvalues j = 1/`n_m' {
    local col = `j' + 1
    putdocx table tbl(`r',`col') = ("Yes"), halign(right)
}
local ++r

putdocx table tbl(`r',1) = ("Mean of DV"), halign(left)
forvalues j = 1/`n_m' {
    local mm : word `j' of `mod_means'
    local col = `j' + 1
    putdocx table tbl(`r',`col') = (string(real("`mm'"), "%12.4fc")), halign(right)
}
local ++r

putdocx table tbl(`r',1) = ("Observations"), halign(left)
forvalues j = 1/`n_m' {
    local mname : word `j' of `models'
    local col   = `j' + 1
    qui estimates restore `mname'
    putdocx table tbl(`r',`col') = ("`: display %12.0fc e(N)'"), halign(right)
}
local ++r

putdocx table tbl(`r',1) = ("R-squared"), halign(left)
forvalues j = 1/`n_m' {
    local mname : word `j' of `models'
    local col   = `j' + 1
    qui estimates restore `mname'
    putdocx table tbl(`r',`col') = ("`: display %12.3fc e(r2)'"), halign(right)
}
local ++r

putdocx table tbl(`r',1) = ("Clusters (Issuers)"), halign(left)
forvalues j = 1/`n_m' {
    local mname : word `j' of `models'
    local col   = `j' + 1
    qui estimates restore `mname'
    putdocx table tbl(`r',`col') = ("`: display %12.0fc e(N_clust)'"), halign(right)
}
putdocx table tbl(`r',.), border(bottom, single)

putdocx save "${out}/Table8_entry_exit_up.docx", replace
}

********************************************************************
*** End
********************************************************************
