********************************************************************
*** 6. Disaggregated Threshold Analysis -- Stacked DiD on NAIC fallen angels
********************************************************************

clear all
set more off
set varabbrev off
version 17

* ============= SET PATHS =============
global root "/Users/matthiashuber/Library/CloudStorage/Dropbox-HECPARIS/Matthias Huber/Replication Package"
global data "${root}/Data/Working Files"
global out  "${root}/Paper Replication/Figures and Tables/Threshold"
* =====================================
cap mkdir "${root}/Paper Replication/Figures and Tables"
cap mkdir "${out}"


********************************************************************
*** Build cohort-level bond-quarter scaffolding
********************************************************************

use "${data}/_master.dta", clear

* Sanity check: required event variables must be in master
foreach v in fa first_fa naic_bucket Clean_Window {
    cap confirm variable `v'
    if _rc {
        di as err "Variable '`v'' not found in _master.dta -- check 0_Build_Master.do."
        exit 111
    }
}

* Bond-quarter panel for IG-at-c flagging
preserve
    bysort issueID qdate: keep if _n == 1
    keep issueID qdate naic_bucket NAIC_num first_fa
    tempfile bondqtr
    save `bondqtr'
restore

* Cohort list = unique fallen-angel quarters
preserve
    keep if !missing(first_fa)
    keep first_fa
    duplicates drop
    sort first_fa
    tempfile cohorts
    save `cohorts'
restore


********************************************************************
*** Build stacked panel by looping over cohort quarters
********************************************************************

tempfile stacked
save `stacked', emptyok

use `cohorts', clear
levelsof first_fa, local(cohort_qs)

foreach c of local cohort_qs {

    * Determine bonds eligible for cohort c
    use `bondqtr', clear

    gen byte at_thr = (qdate == `c' - 1 & NAIC_num == 10)
    bysort issueID: egen thr_at_c = max(at_thr)
    drop at_thr

    bysort issueID: keep if _n == 1
    keep issueID first_fa thr_at_c

    gen byte treated_b = (first_fa == `c') & !missing(first_fa)
    gen byte control_b = (thr_at_c == 1                                  ///
        & (missing(first_fa) | !inrange(first_fa, `c'-8, `c'+8))         ///
        & treated_b == 0)

    keep if treated_b == 1 | control_b == 1
    keep issueID treated_b
    tempfile cohortbonds
    save `cohortbonds'

    * Pull cohort-window observations from master
    use "${data}/_master.dta", clear
    merge m:1 issueID using `cohortbonds', keep(match) nogen

    keep if inrange(qdate, `c'-8, `c'+8)
    gen cohort_q   = `c'
    gen rel_time_c = qdate - `c'
    gen byte treated = treated_b
    drop treated_b

    append using `stacked'
    save `stacked', replace
}


********************************************************************
*** Estimate stacked DiD
********************************************************************

use `stacked', clear

keep if inlist(fundtype_det_num, 1, 5)
gen byte LI = (fundtype_det_num == 1)
label variable LI "Life Insurer"

egen stack_id        = group(cohort_q)
gen  rel_time_shifted = rel_time_c + 9      

estimates clear

*============================================================
* Stacked DiD: Fallen Angels vs. BBB- Survivors
* Pooled Pre_2Y (t = -8 to -5) baseline
* Life Insurers vs. Passive Mutual Funds
*============================================================

*------------------------------------------------------------
* 1. Event-time variable with pooled Pre_2Y baseline
*------------------------------------------------------------
cap drop rel_time_grp
gen rel_time_grp = rel_time_shifted
replace rel_time_grp = 1 if inrange(rel_time_shifted, -8, -5)
label var rel_time_grp "Event time (Pre_2Y pooled into cat. 1)"


tab rel_time_shifted rel_time_grp if Clean_Window == 1, missing

*------------------------------------------------------------
* 2. Sample restriction: Life Insurers and Passive MFs
*------------------------------------------------------------
* (Run on the restricted sample so the triple interaction is well-defined)
* fundtype_det_num: 1 = Life Insurers, 5 = Passive MFs

*------------------------------------------------------------
* 3. Stacked DiD regression
*------------------------------------------------------------
reghdfe delta_holdings ib(1).rel_time_grp##ib(0).treated##ib(0).LI ///
    if Clean_Window == 1 & inlist(fundtype_det_num, 1, 5),         ///
    absorb(stack_id#issueID stack_id#rel_time_grp) cluster(issuerID)

estimates store t8_stacked

*------------------------------------------------------------
* 4. Build coefficient matrix for coefplot
*    Extracts the triple interaction (Life Insurer differential)
*    and the double interaction (PMF treatment effect)
*------------------------------------------------------------
matrix LI_b  = J(17, 3, .)
matrix PMF_b = J(17, 3, .)

local row = 1
forvalues t = -8/8 {
    local s = `t' + 9

    if inrange(`t', -8, -5) {
        * Pooled baseline: anchor at zero
        matrix LI_b[`row', 1]  = `t'
        matrix LI_b[`row', 2]  = 0
        matrix LI_b[`row', 3]  = 0
        matrix PMF_b[`row', 1] = `t'
        matrix PMF_b[`row', 2] = 0
        matrix PMF_b[`row', 3] = 0
    }
    else {
        * PMF coefficient: rel_time_grp#treated (LI = 0)
        matrix PMF_b[`row', 1] = `t'
        matrix PMF_b[`row', 2] = _b[`s'.rel_time_grp#1.treated]
        matrix PMF_b[`row', 3] = _se[`s'.rel_time_grp#1.treated]

        * LI coefficient: rel_time_grp#treated + rel_time_grp#treated#LI
        lincom _b[`s'.rel_time_grp#1.treated] + _b[`s'.rel_time_grp#1.treated#1.LI]
        matrix LI_b[`row', 1] = `t'
        matrix LI_b[`row', 2] = r(estimate)
        matrix LI_b[`row', 3] = r(se)
    }
    local ++row
}

matrix colnames LI_b  = rel_time coef se
matrix colnames PMF_b = rel_time coef se
matrix list LI_b
matrix list PMF_b

*------------------------------------------------------------
* 5. Coefplot: two-panel figure (LI left, PMF right)
*------------------------------------------------------------
preserve
clear
svmat LI_b, names(col)
gen group = "Life Insurers"
tempfile li_plot
save `li_plot'

clear
svmat PMF_b, names(col)
gen group = "Passive Mutual Funds"
append using `li_plot'

gen ci_lo = coef - 1.96 * se
gen ci_hi = coef + 1.96 * se

* LI panel
twoway (rcap ci_lo ci_hi rel_time if group == "Life Insurers", lcolor(black)) ///
       (scatter coef rel_time if group == "Life Insurers", ///
            mcolor(black) msymbol(O) msize(small)) ///
       , yline(0, lpattern(dash) lcolor(red))                ///
         xline(0, lpattern(dash) lcolor(gs8))               ///
         xlabel(-8(2)8) ylabel(, angle(horizontal))         ///
         xtitle("Quarters Relative to NAIC IG-to-HY Crossing") ///
         ytitle("Treated × Event Time (bp of offering amount)") ///
         title("Life Insurers", size(medium))               ///
         legend(off)                                        ///
         graphregion(color(white)) plotregion(color(white)) ///
         name(li_panel, replace)

* PMF panel
twoway (rcap ci_lo ci_hi rel_time if group == "Passive Mutual Funds", lcolor(black)) ///
       (scatter coef rel_time if group == "Passive Mutual Funds", ///
            mcolor(black) msymbol(O) msize(small)) ///
       , yline(0, lpattern(dash) lcolor(red))                ///
         xline(0, lpattern(dash) lcolor(gs8))               ///
         xlabel(-8(2)8) ylabel(, angle(horizontal))         ///
         xtitle("Quarters Relative to NAIC IG-to-HY Crossing") ///
         ytitle("Treated × Event Time (bp of offering amount)") ///
         title("Passive Mutual Funds", size(medium))        ///
         legend(off)                                        ///
         graphregion(color(white)) plotregion(color(white)) ///
         name(pmf_panel, replace)

* Combine
graph combine li_panel pmf_panel, cols(2) ///
    graphregion(color(white)) ///
    name(fig8_eventstudy, replace)

graph export "${out}/Figure8_threshold_eventstudy.png", replace width(2400)
restore

*------------------------------------------------------------
* 6. putdocx table: Stacked DiD coefficients
*------------------------------------------------------------
putdocx clear
putdocx begin

putdocx paragraph, halign(center)
putdocx text ("TABLE 8."), bold

putdocx paragraph, halign(center)
putdocx text ("Stacked Difference-in-Differences — Fallen Angels vs. BBB- Survivors."), bold

putdocx paragraph
putdocx text ("This table reports coefficient estimates from a stacked difference-in-differences regression of "), italic
putdocx text ("Delta Holdings"), italic
putdocx text (" (quarter-on-quarter change in bond holdings, in basis points of offering amount, winsorized 1/99 by fundtype) on event-time indicators, a treatment indicator, a Life Insurer indicator, and their triple interactions. "), italic
putdocx text ("For each cohort quarter c, treated bonds are those whose first fallen-angel event (NAIC investment-grade to high-yield crossing, NAIC_num going from at most 10 to greater than 10) occurs in c, with the event clean of any fallen-angel event in the prior eight quarters. Control bonds are at NAIC investment grade in c and have either no fallen-angel event in the sample or one outside event time -8 to +8. Observations are stacked across cohorts. "), italic
putdocx text ("The omitted reference is the pooled Pre_2Y window (rel_time -8 to -5); event-time coefficients are interpreted relative to the average of these four quarters. "), italic
putdocx text ("Column 1 reports the Passive Mutual Fund treatment effect (rel_time_grp × treated). Column 2 reports the differential Life Insurer response (rel_time_grp × treated + rel_time_grp × treated × LI). "), italic
putdocx text ("Sample restricted to Life Insurers and Passive Mutual Funds. Fixed effects are stack × issue and stack × event-time. Standard errors clustered by issuer in parentheses. *, **, and *** denote statistical significance at the 10%, 5%, and 1% levels, respectively."), italic

* Table dimensions: header + 13 coef rows (×2 for SE) + 4 footer rows = 32 rows
local nrows = 1 + 1 + 1 + 13*2 + 4
putdocx table tbl = (`nrows', 3), border(all, nil)

* Header row
putdocx table tbl(1, 1) = ("Quarters Relative to Event"), bold halign(center)
putdocx table tbl(1, 2) = ("Passive MFs"), bold halign(center)
putdocx table tbl(1, 3) = ("Life Insurers"), bold halign(center)
putdocx table tbl(1, .), border(bottom)

* Pre_2Y baseline anchor row
putdocx table tbl(2, 1) = ("Pre_2Y (t = -8 to -5, omitted)"), halign(left) italic
putdocx table tbl(2, 2) = ("—"), halign(center)
putdocx table tbl(2, 3) = ("—"), halign(center)

* Loop through estimated event-time quarters
local row = 3
forvalues t = -4/8 {
    local s = `t' + 9

    * PMF coefficient and SE
    local b_pmf  = _b[`s'.rel_time_grp#1.treated]
    local se_pmf = _se[`s'.rel_time_grp#1.treated]
    local t_pmf  = `b_pmf' / `se_pmf'
    local stars_pmf = ""
    if abs(`t_pmf') > 2.576 local stars_pmf = "***"
    else if abs(`t_pmf') > 1.960 local stars_pmf = "**"
    else if abs(`t_pmf') > 1.645 local stars_pmf = "*"

    * LI coefficient and SE via lincom
    qui lincom _b[`s'.rel_time_grp#1.treated] + _b[`s'.rel_time_grp#1.treated#1.LI]
    local b_li  = r(estimate)
    local se_li = r(se)
    local t_li  = `b_li' / `se_li'
    local stars_li = ""
    if abs(`t_li') > 2.576 local stars_li = "***"
    else if abs(`t_li') > 1.960 local stars_li = "**"
    else if abs(`t_li') > 1.645 local stars_li = "*"

    * Format
    local b_pmf_f  : di %12.3fc `b_pmf'
    local se_pmf_f : di %12.3fc `se_pmf'
    local b_li_f   : di %12.3fc `b_li'
    local se_li_f  : di %12.3fc `se_li'

    putdocx table tbl(`row', 1) = ("t = `t'"), halign(left)
    putdocx table tbl(`row', 2) = ("`b_pmf_f'`stars_pmf'"), halign(center)
    putdocx table tbl(`row', 3) = ("`b_li_f'`stars_li'"), halign(center)
    local ++row
    putdocx table tbl(`row', 2) = ("(`se_pmf_f')"), halign(center)
    putdocx table tbl(`row', 3) = ("(`se_li_f')"), halign(center)
    local ++row
}

* Footer rows
putdocx table tbl(`row', .), border(top)
putdocx table tbl(`row', 1) = ("Stack × Issue FE"), halign(left)
putdocx table tbl(`row', 2) = ("Yes"), halign(center)
putdocx table tbl(`row', 3) = ("Yes"), halign(center)
local ++row
putdocx table tbl(`row', 1) = ("Stack × Event-Time FE"), halign(left)
putdocx table tbl(`row', 2) = ("Yes"), halign(center)
putdocx table tbl(`row', 3) = ("Yes"), halign(center)
local ++row

qui estimates restore t8_stacked
local nobs : di %12.0fc e(N)
local r2   : di %5.3f   e(r2)

putdocx table tbl(`row', 1) = ("Observations"), halign(left)
putdocx table tbl(`row', 2) = ("`nobs'"), halign(center) colspan(2)
local ++row
putdocx table tbl(`row', 1) = ("R-squared"), halign(left)
putdocx table tbl(`row', 2) = ("`r2'"), halign(center) colspan(2)

putdocx save "${out}/Table8_threshold_stacked_DiD.docx", replace

display "==> Table 8 (stacked DiD, pooled Pre_2Y baseline) written."


*============================================================
* Window-level figures: descriptives + DiD coefficients
* Style matches Figure 8 (quarterly version) exactly
*============================================================

*------------------------------------------------------------
* 1. Window variable
*------------------------------------------------------------
cap drop window
gen window = .
replace window = 1 if inrange(rel_time_c, -8, -5)      // Pre_2Y
replace window = 2 if inrange(rel_time_c, -4, -1)      // Pre_1Y
replace window = 3 if rel_time_c == 0                  // Downgrade
replace window = 4 if inrange(rel_time_c, 1, 4)        // Post_1Y
replace window = 5 if inrange(rel_time_c, 5, 8)        // Post_2Y
label define winlbl 1 "Pre_2Y" 2 "Pre_1Y" 3 "Downgrade" 4 "Post_1Y" 5 "Post_2Y"
label values window winlbl

*------------------------------------------------------------
* 2. Descriptive figure: raw means by window, connected lines
*    (matches Image 1 style — Fallen Angels vs. BBB- Survivors)
*------------------------------------------------------------
preserve
keep if Clean_Window == 1 & inlist(fundtype_det_num, 1, 5) & !missing(window)

collapse (mean) mean_dh = delta_holdings, by(window treated LI)

* LI panel
twoway (connected mean_dh window if LI == 1 & treated == 0,                       ///
            lcolor(gs8) mcolor(gs8) msymbol(T) lpattern(dash))                    ///
       (connected mean_dh window if LI == 1 & treated == 1,                       ///
            lcolor(black) mcolor(black) msymbol(O))                               ///
       , xline(3, lpattern(dash) lcolor(red))                                     ///
         yline(0, lpattern(dot) lcolor(gs10))                                     ///
         xlabel(1 "Pre_2Y" 2 "Pre_1Y" 3 "Downgrade" 4 "Post_1Y" 5 "Post_2Y")      ///
         ylabel(, angle(horizontal))                                              ///
         xtitle("Event Window")                                                   ///
         ytitle("Mean Delta Holdings (bp of offering amount)")                    ///
         title("Life Insurers", size(medium))                                     ///
         legend(order(1 "BBB- Survivors" 2 "Fallen Angels") rows(1) position(6))  ///
         graphregion(color(white)) plotregion(color(white))                       ///
         name(li_desc_win, replace)

* PMF panel
twoway (connected mean_dh window if LI == 0 & treated == 0,                       ///
            lcolor(gs8) mcolor(gs8) msymbol(T) lpattern(dash))                    ///
       (connected mean_dh window if LI == 0 & treated == 1,                       ///
            lcolor(black) mcolor(black) msymbol(O))                               ///
       , xline(3, lpattern(dash) lcolor(red))                                     ///
         yline(0, lpattern(dot) lcolor(gs10))                                     ///
         xlabel(1 "Pre_2Y" 2 "Pre_1Y" 3 "Downgrade" 4 "Post_1Y" 5 "Post_2Y")      ///
         ylabel(, angle(horizontal))                                              ///
         xtitle("Event Window")                                                   ///
         ytitle("Mean Delta Holdings (bp of offering amount)")                    ///
         title("Passive Mutual Funds", size(medium))                              ///
         legend(order(1 "BBB- Survivors" 2 "Fallen Angels") rows(1) position(6))  ///
         graphregion(color(white)) plotregion(color(white))                       ///
         name(pmf_desc_win, replace)

grc1leg li_desc_win pmf_desc_win, cols(2)                                         ///
    graphregion(color(white))                                                     ///
    name(fig_threshold_desc_window, replace)

graph export "${out}/Figure_threshold_descriptive_window.png", replace width(2400)
restore

*------------------------------------------------------------
* 3. Window-level DiD regressions (separate samples for LI / PMF)
*------------------------------------------------------------
reghdfe delta_holdings ib(1).window##ib(0).treated ///
    if Clean_Window == 1 & fundtype_det_num == 1,  ///
    absorb(stack_id#issueID stack_id#rel_time_shifted) cluster(issuerID)
estimates store t8_win_LI

reghdfe delta_holdings ib(1).window##ib(0).treated ///
    if Clean_Window == 1 & fundtype_det_num == 5,  ///
    absorb(stack_id#issueID stack_id#rel_time_shifted) cluster(issuerID)
estimates store t8_win_PMF

*------------------------------------------------------------
* 4. Coefficient figure: window-level DiD with 95% CIs
*    (matches Image 2 style — Treated × Window coefplot)
*------------------------------------------------------------
matrix LI_win  = J(5, 3, .)
matrix PMF_win = J(5, 3, .)

local row = 1
forvalues w = 1/5 {
    if `w' == 1 {
        matrix LI_win[`row', 1]  = `w'
        matrix LI_win[`row', 2]  = 0
        matrix LI_win[`row', 3]  = 0
        matrix PMF_win[`row', 1] = `w'
        matrix PMF_win[`row', 2] = 0
        matrix PMF_win[`row', 3] = 0
    }
    else {
        qui estimates restore t8_win_LI
        matrix LI_win[`row', 1] = `w'
        matrix LI_win[`row', 2] = _b[`w'.window#1.treated]
        matrix LI_win[`row', 3] = _se[`w'.window#1.treated]

        qui estimates restore t8_win_PMF
        matrix PMF_win[`row', 1] = `w'
        matrix PMF_win[`row', 2] = _b[`w'.window#1.treated]
        matrix PMF_win[`row', 3] = _se[`w'.window#1.treated]
    }
    local ++row
}

matrix colnames LI_win  = window coef se
matrix colnames PMF_win = window coef se

preserve
clear
svmat LI_win, names(col)
gen group = "Life Insurers"
tempfile li_win_plot
save `li_win_plot'

clear
svmat PMF_win, names(col)
gen group = "Passive Mutual Funds"
append using `li_win_plot'

gen ci_lo = coef - 1.96 * se
gen ci_hi = coef + 1.96 * se

* LI panel
twoway (rcap ci_lo ci_hi window if group == "Life Insurers", lcolor(black))       ///
       (scatter coef window if group == "Life Insurers",                          ///
            mcolor(black) msymbol(O) msize(small))                                ///
       , yline(0, lpattern(dash) lcolor(red))                                     ///
         xline(3, lpattern(dash) lcolor(gs8))                                     ///
         xlabel(1 "Pre_2Y" 2 "Pre_1Y" 3 "Downgrade" 4 "Post_1Y" 5 "Post_2Y")      ///
         ylabel(, angle(horizontal))                                              ///
         xtitle("Event Window")                                                   ///
         ytitle("Treated × Window (bp of offering amount)")                       ///
         title("Life Insurers", size(medium))                                     ///
         legend(off)                                                              ///
         graphregion(color(white)) plotregion(color(white))                       ///
         name(li_coef_win, replace)

* PMF panel
twoway (rcap ci_lo ci_hi window if group == "Passive Mutual Funds", lcolor(black)) ///
       (scatter coef window if group == "Passive Mutual Funds",                   ///
            mcolor(black) msymbol(O) msize(small))                                ///
       , yline(0, lpattern(dash) lcolor(red))                                     ///
         xline(3, lpattern(dash) lcolor(gs8))                                     ///
         xlabel(1 "Pre_2Y" 2 "Pre_1Y" 3 "Downgrade" 4 "Post_1Y" 5 "Post_2Y")      ///
         ylabel(, angle(horizontal))                                              ///
         xtitle("Event Window")                                                   ///
         ytitle("Treated × Window (bp of offering amount)")                       ///
         title("Passive Mutual Funds", size(medium))                              ///
         legend(off)                                                              ///
         graphregion(color(white)) plotregion(color(white))                       ///
         name(pmf_coef_win, replace)

graph combine li_coef_win pmf_coef_win, cols(2)                                   ///
    graphregion(color(white))                                                     ///
    name(fig_threshold_coef_window, replace)

graph export "${out}/Figure_threshold_coef_window.png", replace width(2400)

restore
********************************************************************
*** End
********************************************************************




********************************************************************
*** 6b. Disaggregated Threshold Analysis -- Stacked DiD on NAIC fallen angels
***     DV: net_change_bp (eMAXX-reconciled net flow, extensive margin)
********************************************************************

clear all
set more off
set varabbrev off
version 17

* ============= SET PATHS =============
global root "/Users/matthiashuber/Library/CloudStorage/Dropbox-HECPARIS/Matthias Huber/Replication Package"
global data "${root}/Data/Working Files"
global out  "${root}/Paper Replication/Figures and Tables/Threshold"
* =====================================
cap mkdir "${root}/Paper Replication/Figures and Tables"
cap mkdir "${out}"


********************************************************************
*** Build cohort-level bond-quarter scaffolding
********************************************************************

use "${data}/_master.dta", clear

* Sanity check: required event variables must be in master
foreach v in fa first_fa naic_bucket Clean_Window net_change_bp {
    cap confirm variable `v'
    if _rc {
        di as err "Variable '`v'' not found in _master.dta -- check 0_Build_Master.do."
        exit 111
    }
}

* Bond-quarter panel for IG-at-c flagging
preserve
    bysort issueID qdate: keep if _n == 1
    keep issueID qdate naic_bucket NAIC_num first_fa
    tempfile bondqtr
    save `bondqtr'
restore

* Cohort list = unique fallen-angel quarters
preserve
    keep if !missing(first_fa)
    keep first_fa
    duplicates drop
    sort first_fa
    tempfile cohorts
    save `cohorts'
restore


********************************************************************
*** Build stacked panel by looping over cohort quarters
********************************************************************

tempfile stacked
save `stacked', emptyok

use `cohorts', clear
levelsof first_fa, local(cohort_qs)

foreach c of local cohort_qs {

    * Determine bonds eligible for cohort c
    use `bondqtr', clear

    gen byte at_thr = (qdate == `c' - 1 & NAIC_num == 10)
    bysort issueID: egen thr_at_c = max(at_thr)
    drop at_thr

    bysort issueID: keep if _n == 1
    keep issueID first_fa thr_at_c

    gen byte treated_b = (first_fa == `c') & !missing(first_fa)
    gen byte control_b = (thr_at_c == 1                                  ///
        & (missing(first_fa) | !inrange(first_fa, `c'-8, `c'+8))         ///
        & treated_b == 0)

    keep if treated_b == 1 | control_b == 1
    keep issueID treated_b
    tempfile cohortbonds
    save `cohortbonds'

    * Pull cohort-window observations from master
    use "${data}/_master.dta", clear
    merge m:1 issueID using `cohortbonds', keep(match) nogen

    keep if inrange(qdate, `c'-8, `c'+8)
    gen cohort_q   = `c'
    gen rel_time_c = qdate - `c'
    gen byte treated = treated_b
    drop treated_b

    append using `stacked'
    save `stacked', replace
}


********************************************************************
*** Estimate stacked DiD on net_change_bp
********************************************************************

use `stacked', clear

keep if inlist(fundtype_det_num, 1, 5)
gen byte LI = (fundtype_det_num == 1)
label variable LI "Life Insurer"

egen stack_id        = group(cohort_q)
gen  rel_time_shifted = rel_time_c + 9

estimates clear

*============================================================
* Stacked DiD: Fallen Angels vs. BBB- Survivors
* DV: net_change_bp
* Pooled Pre_2Y (t = -8 to -5) baseline
* Life Insurers vs. Passive Mutual Funds
*============================================================

*------------------------------------------------------------
* 1. Event-time variable with pooled Pre_2Y baseline
*------------------------------------------------------------
cap drop rel_time_grp
gen rel_time_grp = rel_time_shifted
replace rel_time_grp = 1 if inrange(rel_time_shifted, -8, -5)
label var rel_time_grp "Event time (Pre_2Y pooled into cat. 1)"

tab rel_time_shifted rel_time_grp if Clean_Window == 1, missing

*------------------------------------------------------------
* 2. Stacked DiD regression on net_change_bp
*------------------------------------------------------------
reghdfe net_change_bp ib(1).rel_time_grp##ib(0).treated##ib(0).LI ///
    if Clean_Window == 1 & inlist(fundtype_det_num, 1, 5),        ///
    absorb(stack_id#issueID stack_id#rel_time_grp) cluster(issuerID)

estimates store t8nc_stacked

*------------------------------------------------------------
* 3. Build coefficient matrix for coefplot
*------------------------------------------------------------
matrix LI_b_nc  = J(17, 3, .)
matrix PMF_b_nc = J(17, 3, .)

local row = 1
forvalues t = -8/8 {
    local s = `t' + 9

    if inrange(`t', -8, -5) {
        matrix LI_b_nc[`row', 1]  = `t'
        matrix LI_b_nc[`row', 2]  = 0
        matrix LI_b_nc[`row', 3]  = 0
        matrix PMF_b_nc[`row', 1] = `t'
        matrix PMF_b_nc[`row', 2] = 0
        matrix PMF_b_nc[`row', 3] = 0
    }
    else {
        matrix PMF_b_nc[`row', 1] = `t'
        matrix PMF_b_nc[`row', 2] = _b[`s'.rel_time_grp#1.treated]
        matrix PMF_b_nc[`row', 3] = _se[`s'.rel_time_grp#1.treated]

        qui lincom _b[`s'.rel_time_grp#1.treated] + _b[`s'.rel_time_grp#1.treated#1.LI]
        matrix LI_b_nc[`row', 1] = `t'
        matrix LI_b_nc[`row', 2] = r(estimate)
        matrix LI_b_nc[`row', 3] = r(se)
    }
    local ++row
}

matrix colnames LI_b_nc  = rel_time coef se
matrix colnames PMF_b_nc = rel_time coef se
matrix list LI_b_nc
matrix list PMF_b_nc

*------------------------------------------------------------
* 4. Coefplot: two-panel quarterly event study figure
*------------------------------------------------------------
preserve
clear
svmat LI_b_nc, names(col)
gen group = "Life Insurers"
tempfile li_plot
save `li_plot'

clear
svmat PMF_b_nc, names(col)
gen group = "Passive Mutual Funds"
append using `li_plot'

gen ci_lo = coef - 1.96 * se
gen ci_hi = coef + 1.96 * se

* LI panel
twoway (rcap ci_lo ci_hi rel_time if group == "Life Insurers", lcolor(black))    ///
       (scatter coef rel_time if group == "Life Insurers",                        ///
            mcolor(black) msymbol(O) msize(small))                                ///
       , yline(0, lpattern(dash) lcolor(red))                                     ///
         xline(0, lpattern(dash) lcolor(gs8))                                     ///
         xlabel(-8(2)8) ylabel(, angle(horizontal))                               ///
         xtitle("Quarters Relative to NAIC IG-to-HY Crossing")                    ///
         ytitle("Treated × Event Time (bp of offering amount)")                   ///
         title("Life Insurers", size(medium))                                     ///
         legend(off)                                                              ///
         graphregion(color(white)) plotregion(color(white))                       ///
         name(li_panel_nc, replace)

* PMF panel
twoway (rcap ci_lo ci_hi rel_time if group == "Passive Mutual Funds", lcolor(black)) ///
       (scatter coef rel_time if group == "Passive Mutual Funds",                 ///
            mcolor(black) msymbol(O) msize(small))                                ///
       , yline(0, lpattern(dash) lcolor(red))                                     ///
         xline(0, lpattern(dash) lcolor(gs8))                                     ///
         xlabel(-8(2)8) ylabel(, angle(horizontal))                               ///
         xtitle("Quarters Relative to NAIC IG-to-HY Crossing")                    ///
         ytitle("Treated × Event Time (bp of offering amount)")                   ///
         title("Passive Mutual Funds", size(medium))                              ///
         legend(off)                                                              ///
         graphregion(color(white)) plotregion(color(white))                       ///
         name(pmf_panel_nc, replace)

graph combine li_panel_nc pmf_panel_nc, cols(2) ///
    graphregion(color(white)) ///
    name(fig8_eventstudy_nc, replace)

graph export "${out}/Figure8_threshold_eventstudy_netchange.png", replace width(2400)
restore

*------------------------------------------------------------
* 5. putdocx table: Stacked DiD quarterly coefficients
*------------------------------------------------------------
putdocx clear
putdocx begin

putdocx paragraph, halign(center)
putdocx text ("TABLE 8B."), bold

putdocx paragraph, halign(center)
putdocx text ("Stacked Difference-in-Differences — Net Change, Fallen Angels vs. BBB- Survivors."), bold

putdocx paragraph
putdocx text ("This table reports coefficient estimates from a stacked difference-in-differences regression of "), italic
putdocx text ("Net Change"), italic
putdocx text (" (quarter-on-quarter net change in bond holdings from the eMAXX-reconciled flow variable, in basis points of offering amount, winsorized 1/99 by fundtype) on event-time indicators, a treatment indicator, a Life Insurer indicator, and their triple interactions. "), italic
putdocx text ("Net Change incorporates the extensive margin of fund-firm pairs entering and exiting positions, unlike Delta Holdings which is conditional on holding the bond in the preceding quarter. "), italic
putdocx text ("For each cohort quarter c, treated bonds are those whose first fallen-angel event (NAIC IG-to-HY crossing, NAIC_num going from at most 10 to greater than 10) occurs in c. Control bonds are at the IG/HY threshold (NAIC_num equal to 10) in c-1 and have no fallen-angel event in event time -8 to +8. Observations are stacked across cohorts. "), italic
putdocx text ("The omitted reference is the pooled Pre_2Y window (rel_time -8 to -5); event-time coefficients are interpreted relative to the average of these four quarters. "), italic
putdocx text ("Column 1 reports the Passive Mutual Fund treatment effect. Column 2 reports the differential Life Insurer response, computed as the sum of the rel_time_grp × treated and rel_time_grp × treated × LI coefficients. "), italic
putdocx text ("Sample restricted to Life Insurers and Passive Mutual Funds. Fixed effects are stack × issue and stack × event-time. Standard errors clustered by issuer in parentheses. *, **, and *** denote statistical significance at the 10%, 5%, and 1% levels, respectively."), italic

local nrows = 1 + 1 + 13*2 + 4
putdocx table tbl = (`nrows', 3), border(all, nil)

putdocx table tbl(1, 1) = ("Quarters Relative to Event"), bold halign(center)
putdocx table tbl(1, 2) = ("Passive MFs"), bold halign(center)
putdocx table tbl(1, 3) = ("Life Insurers"), bold halign(center)
putdocx table tbl(1, .), border(bottom)

putdocx table tbl(2, 1) = ("Pre_2Y (t = -8 to -5, omitted)"), halign(left) italic
putdocx table tbl(2, 2) = ("—"), halign(center)
putdocx table tbl(2, 3) = ("—"), halign(center)

local row = 3
forvalues t = -4/8 {
    local s = `t' + 9

    local b_pmf  = _b[`s'.rel_time_grp#1.treated]
    local se_pmf = _se[`s'.rel_time_grp#1.treated]
    local t_pmf  = `b_pmf' / `se_pmf'
    local stars_pmf = ""
    if abs(`t_pmf') > 2.576 local stars_pmf = "***"
    else if abs(`t_pmf') > 1.960 local stars_pmf = "**"
    else if abs(`t_pmf') > 1.645 local stars_pmf = "*"

    qui lincom _b[`s'.rel_time_grp#1.treated] + _b[`s'.rel_time_grp#1.treated#1.LI]
    local b_li  = r(estimate)
    local se_li = r(se)
    local t_li  = `b_li' / `se_li'
    local stars_li = ""
    if abs(`t_li') > 2.576 local stars_li = "***"
    else if abs(`t_li') > 1.960 local stars_li = "**"
    else if abs(`t_li') > 1.645 local stars_li = "*"

    local b_pmf_f  : di %12.3fc `b_pmf'
    local se_pmf_f : di %12.3fc `se_pmf'
    local b_li_f   : di %12.3fc `b_li'
    local se_li_f  : di %12.3fc `se_li'

    putdocx table tbl(`row', 1) = ("t = `t'"), halign(left)
    putdocx table tbl(`row', 2) = ("`b_pmf_f'`stars_pmf'"), halign(center)
    putdocx table tbl(`row', 3) = ("`b_li_f'`stars_li'"), halign(center)
    local ++row
    putdocx table tbl(`row', 2) = ("(`se_pmf_f')"), halign(center)
    putdocx table tbl(`row', 3) = ("(`se_li_f')"), halign(center)
    local ++row
}

putdocx table tbl(`row', .), border(top)
putdocx table tbl(`row', 1) = ("Stack × Issue FE"), halign(left)
putdocx table tbl(`row', 2) = ("Yes"), halign(center)
putdocx table tbl(`row', 3) = ("Yes"), halign(center)
local ++row
putdocx table tbl(`row', 1) = ("Stack × Event-Time FE"), halign(left)
putdocx table tbl(`row', 2) = ("Yes"), halign(center)
putdocx table tbl(`row', 3) = ("Yes"), halign(center)
local ++row

qui estimates restore t8nc_stacked
local nobs : di %12.0fc e(N)
local r2   : di %5.3f e(r2)

putdocx table tbl(`row', 1) = ("Observations"), halign(left)
putdocx table tbl(`row', 2) = ("`nobs'"), halign(center) colspan(2)
local ++row
putdocx table tbl(`row', 1) = ("R-squared"), halign(left)
putdocx table tbl(`row', 2) = ("`r2'"), halign(center) colspan(2)

putdocx save "${out}/Table8_threshold_stacked_DiD_netchange.docx", replace

display "==> Table 8B (stacked DiD net_change_bp, pooled Pre_2Y baseline) written."

********************************************************************
*** Window-level analysis on net_change_bp
********************************************************************

*------------------------------------------------------------
* 6. Window variable
*------------------------------------------------------------
cap drop window
gen window = .
replace window = 1 if inrange(rel_time_c, -8, -5)      // Pre_2Y
replace window = 2 if inrange(rel_time_c, -4, -1)      // Pre_1Y
replace window = 3 if rel_time_c == 0                  // Downgrade
replace window = 4 if inrange(rel_time_c, 1, 4)        // Post_1Y
replace window = 5 if inrange(rel_time_c, 5, 8)        // Post_2Y
label define winlbl 1 "Pre_2Y" 2 "Pre_1Y" 3 "Downgrade" 4 "Post_1Y" 5 "Post_2Y"
label values window winlbl

*------------------------------------------------------------
* 7. Descriptive figure: raw means by window
*------------------------------------------------------------
preserve
keep if Clean_Window == 1 & inlist(fundtype_det_num, 1, 5) & !missing(window)

collapse (mean) mean_nc = net_change_bp, by(window treated LI)

* LI panel
twoway (connected mean_nc window if LI == 1 & treated == 0,                       ///
            lcolor(gs8) mcolor(gs8) msymbol(T) lpattern(dash))                    ///
       (connected mean_nc window if LI == 1 & treated == 1,                       ///
            lcolor(black) mcolor(black) msymbol(O))                               ///
       , xline(3, lpattern(dash) lcolor(red))                                     ///
         yline(0, lpattern(dot) lcolor(gs10))                                     ///
         xlabel(1 "Pre_2Y" 2 "Pre_1Y" 3 "Downgrade" 4 "Post_1Y" 5 "Post_2Y")      ///
         ylabel(, angle(horizontal))                                              ///
         xtitle("Event Window")                                                   ///
         ytitle("Mean Net Change (bp of offering amount)")                        ///
         title("Life Insurers", size(medium))                                     ///
         legend(order(1 "BBB- Survivors" 2 "Fallen Angels") rows(1) position(6))  ///
         graphregion(color(white)) plotregion(color(white))                       ///
         name(li_desc_win_nc, replace)

* PMF panel
twoway (connected mean_nc window if LI == 0 & treated == 0,                       ///
            lcolor(gs8) mcolor(gs8) msymbol(T) lpattern(dash))                    ///
       (connected mean_nc window if LI == 0 & treated == 1,                       ///
            lcolor(black) mcolor(black) msymbol(O))                               ///
       , xline(3, lpattern(dash) lcolor(red))                                     ///
         yline(0, lpattern(dot) lcolor(gs10))                                     ///
         xlabel(1 "Pre_2Y" 2 "Pre_1Y" 3 "Downgrade" 4 "Post_1Y" 5 "Post_2Y")      ///
         ylabel(, angle(horizontal))                                              ///
         xtitle("Event Window")                                                   ///
         ytitle("Mean Net Change (bp of offering amount)")                        ///
         title("Passive Mutual Funds", size(medium))                              ///
         legend(order(1 "BBB- Survivors" 2 "Fallen Angels") rows(1) position(6))  ///
         graphregion(color(white)) plotregion(color(white))                       ///
         name(pmf_desc_win_nc, replace)

graph combine li_desc_win_nc pmf_desc_win_nc, cols(2)                             ///
    graphregion(color(white))                                                     ///
    name(fig_threshold_desc_window_nc, replace)

graph export "${out}/Figure_threshold_descriptive_window_netchange.png", replace width(2400)
restore

*------------------------------------------------------------
* 8. Window-level DiD regressions (LI and PMF separately)
*------------------------------------------------------------
reghdfe net_change_bp ib(1).window##ib(0).treated ///
    if Clean_Window == 1 & fundtype_det_num == 1, ///
    absorb(stack_id#issueID stack_id#rel_time_shifted) cluster(issuerID)
estimates store t8nc_win_LI

reghdfe net_change_bp ib(1).window##ib(0).treated ///
    if Clean_Window == 1 & fundtype_det_num == 5, ///
    absorb(stack_id#issueID stack_id#rel_time_shifted) cluster(issuerID)
estimates store t8nc_win_PMF

*------------------------------------------------------------
* 9. Coefficient figure: window-level DiD with 95% CIs
*------------------------------------------------------------
matrix LI_win_nc  = J(5, 3, .)
matrix PMF_win_nc = J(5, 3, .)

local row = 1
forvalues w = 1/5 {
    if `w' == 1 {
        matrix LI_win_nc[`row', 1]  = `w'
        matrix LI_win_nc[`row', 2]  = 0
        matrix LI_win_nc[`row', 3]  = 0
        matrix PMF_win_nc[`row', 1] = `w'
        matrix PMF_win_nc[`row', 2] = 0
        matrix PMF_win_nc[`row', 3] = 0
    }
    else {
        qui estimates restore t8nc_win_LI
        matrix LI_win_nc[`row', 1] = `w'
        matrix LI_win_nc[`row', 2] = _b[`w'.window#1.treated]
        matrix LI_win_nc[`row', 3] = _se[`w'.window#1.treated]

        qui estimates restore t8nc_win_PMF
        matrix PMF_win_nc[`row', 1] = `w'
        matrix PMF_win_nc[`row', 2] = _b[`w'.window#1.treated]
        matrix PMF_win_nc[`row', 3] = _se[`w'.window#1.treated]
    }
    local ++row
}

matrix colnames LI_win_nc  = window coef se
matrix colnames PMF_win_nc = window coef se

preserve
clear
svmat LI_win_nc, names(col)
gen group = "Life Insurers"
tempfile li_win_plot_nc
save `li_win_plot_nc'

clear
svmat PMF_win_nc, names(col)
gen group = "Passive Mutual Funds"
append using `li_win_plot_nc'

gen ci_lo = coef - 1.96 * se
gen ci_hi = coef + 1.96 * se

* LI panel
twoway (rcap ci_lo ci_hi window if group == "Life Insurers", lcolor(black))       ///
       (scatter coef window if group == "Life Insurers",                          ///
            mcolor(black) msymbol(O) msize(small))                                ///
       , yline(0, lpattern(dash) lcolor(red))                                     ///
         xline(3, lpattern(dash) lcolor(gs8))                                     ///
         xlabel(1 "Pre_2Y" 2 "Pre_1Y" 3 "Downgrade" 4 "Post_1Y" 5 "Post_2Y")      ///
         ylabel(, angle(horizontal))                                              ///
         xtitle("Event Window")                                                   ///
         ytitle("Treated × Window (bp of offering amount)")                       ///
         title("Life Insurers", size(medium))                                     ///
         legend(off)                                                              ///
         graphregion(color(white)) plotregion(color(white))                       ///
         name(li_coef_win_nc, replace)

* PMF panel
twoway (rcap ci_lo ci_hi window if group == "Passive Mutual Funds", lcolor(black)) ///
       (scatter coef window if group == "Passive Mutual Funds",                   ///
            mcolor(black) msymbol(O) msize(small))                                ///
       , yline(0, lpattern(dash) lcolor(red))                                     ///
         xline(3, lpattern(dash) lcolor(gs8))                                     ///
         xlabel(1 "Pre_2Y" 2 "Pre_1Y" 3 "Downgrade" 4 "Post_1Y" 5 "Post_2Y")      ///
         ylabel(, angle(horizontal))                                              ///
         xtitle("Event Window")                                                   ///
         ytitle("Treated × Window (bp of offering amount)")                       ///
         title("Passive Mutual Funds", size(medium))                              ///
         legend(off)                                                              ///
         graphregion(color(white)) plotregion(color(white))                       ///
         name(pmf_coef_win_nc, replace)

graph combine li_coef_win_nc pmf_coef_win_nc, cols(2)                             ///
    graphregion(color(white))                                                     ///
    name(fig_threshold_coef_window_nc, replace)

graph export "${out}/Figure_threshold_coef_window_netchange.png", replace width(2400)
restore

*------------------------------------------------------------
* 10. putdocx table: Window-level coefficients (net_change_bp)
*------------------------------------------------------------
putdocx clear
putdocx begin

putdocx paragraph, halign(center)
putdocx text ("TABLE 8C."), bold
putdocx paragraph, halign(center)
putdocx text ("Threshold Analysis — Net Change, Fallen Angels vs. BBB- Survivors, Life Insurers and Passive MFs."), bold

putdocx paragraph
putdocx text ("This table reports stacked difference-in-differences coefficients of "), italic
putdocx text ("Net Change"), italic
putdocx text (" (quarter-on-quarter net change in bond holdings from the eMAXX-reconciled flow variable, in basis points of offering amount, winsorized 1/99 by fundtype) on event-window indicators interacted with a treatment indicator. "), italic
putdocx text ("Net Change incorporates the extensive margin of fund-firm pairs entering and exiting positions. "), italic
putdocx text ("For each cohort quarter c, treated bonds are those whose first fallen-angel event (NAIC IG-to-HY crossing) occurs in c. Control bonds are at the IG/HY threshold (NAIC_num equal to 10, i.e. BBB-) in c-1 and have no fallen-angel event in event time -8 to +8. Observations are stacked across cohorts. "), italic
putdocx text ("The omitted window is Pre_2Y (rel_time -8 to -5). Pre_1Y covers -4 to -1, Downgrade is rel_time 0, Post_1Y covers 1 to 4, Post_2Y covers 5 to 8. "), italic
putdocx text ("Columns report separate regressions on Life Insurer (column 1) and Passive Mutual Fund (column 2) holdings. Fixed effects are stack × issue and stack × event-time. Standard errors clustered by issuer in parentheses. *, **, and *** denote statistical significance at the 10%, 5%, and 1% levels, respectively."), italic

local nrows = 2 + 4*2 + 5
putdocx table tbl = (`nrows', 3), border(all, nil)

putdocx table tbl(1, 1) = ("Window × Treated"), bold halign(center)
putdocx table tbl(1, 2) = ("Life Insurers"), bold halign(center)
putdocx table tbl(1, 3) = ("Passive MFs"), bold halign(center)
putdocx table tbl(1, .), border(bottom)

local row = 2
foreach w in 2 3 4 5 {
    local wname : label winlbl `w'

    qui estimates restore t8nc_win_LI
    local b_li  = _b[`w'.window#1.treated]
    local se_li = _se[`w'.window#1.treated]
    local t_li  = `b_li' / `se_li'
    local stars_li = ""
    if abs(`t_li') > 2.576 local stars_li = "***"
    else if abs(`t_li') > 1.960 local stars_li = "**"
    else if abs(`t_li') > 1.645 local stars_li = "*"

    qui estimates restore t8nc_win_PMF
    local b_pmf  = _b[`w'.window#1.treated]
    local se_pmf = _se[`w'.window#1.treated]
    local t_pmf  = `b_pmf' / `se_pmf'
    local stars_pmf = ""
    if abs(`t_pmf') > 2.576 local stars_pmf = "***"
    else if abs(`t_pmf') > 1.960 local stars_pmf = "**"
    else if abs(`t_pmf') > 1.645 local stars_pmf = "*"

    local b_li_f   : di %12.3fc `b_li'
    local se_li_f  : di %12.3fc `se_li'
    local b_pmf_f  : di %12.3fc `b_pmf'
    local se_pmf_f : di %12.3fc `se_pmf'

    putdocx table tbl(`row', 1) = ("`wname' × Treated"), halign(left)
    putdocx table tbl(`row', 2) = ("`b_li_f'`stars_li'"), halign(center)
    putdocx table tbl(`row', 3) = ("`b_pmf_f'`stars_pmf'"), halign(center)
    local ++row
    putdocx table tbl(`row', 2) = ("(`se_li_f')"), halign(center)
    putdocx table tbl(`row', 3) = ("(`se_pmf_f')"), halign(center)
    local ++row
}

putdocx table tbl(`row', .), border(top)
putdocx table tbl(`row', 1) = ("Stack × Issue FE"), halign(left)
putdocx table tbl(`row', 2) = ("Yes"), halign(center)
putdocx table tbl(`row', 3) = ("Yes"), halign(center)
local ++row
putdocx table tbl(`row', 1) = ("Stack × Event-Time FE"), halign(left)
putdocx table tbl(`row', 2) = ("Yes"), halign(center)
putdocx table tbl(`row', 3) = ("Yes"), halign(center)
local ++row

qui estimates restore t8nc_win_LI
local n_li  : di %12.0fc e(N)
local r2_li : di %5.3f e(r2)
qui estimates restore t8nc_win_PMF
local n_pmf  : di %12.0fc e(N)
local r2_pmf : di %5.3f e(r2)

putdocx table tbl(`row', 1) = ("Observations"), halign(left)
putdocx table tbl(`row', 2) = ("`n_li'"),  halign(center)
putdocx table tbl(`row', 3) = ("`n_pmf'"), halign(center)
local ++row
putdocx table tbl(`row', 1) = ("R-squared"), halign(left)
putdocx table tbl(`row', 2) = ("`r2_li'"),  halign(center)
putdocx table tbl(`row', 3) = ("`r2_pmf'"), halign(center)

putdocx save "${out}/Table8_threshold_window_netchange.docx", replace

display "==> All net_change_bp threshold outputs written."

********************************************************************
*** End
********************************************************************
