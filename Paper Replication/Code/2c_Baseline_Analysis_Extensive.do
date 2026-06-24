********************************************************************
*** 2c. Baseline Analysis -- Extensive margin (net_change_bp, entry, exit)
***
*** Input:  ${data}/_master.dta  (built by 0_Build_Master.do)
*** Output: ${out}/Figure_extensive_descriptive.png
***         ${out}/Table4_extensive_baseline.docx        (LI x window, headline)
***         ${out}/Table5_extensive_FE.docx              (progressive FE)
***         ${out}/Table6_extensive_partition.docx       (outlook + CDS triples)
***         ${out}/Table7_extensive_entry_exit.docx      (entry/exit, unbal+bal)
***
*** Event clock: DowngradeAny on the standard event clock (rel_time in [-8,+8]).
*** Sample: full _master.dta panel (we DO NOT drop on delta_holdings here).
***         Clean_Window applied as regression condition.
*** Investor types: Life Insurers (fundtype_det_num == 1) and
***                 Passive Mutual Funds (fundtype_det_num == 5).
*** Window buckets: Pre_2Y baseline; Pre_1Y, Downgrade, Post_1Y, Post_2Y reported.
********************************************************************

clear all
set more off
set varabbrev off
version 17

* ============= SET PATHS =============
global root "/Users/matthiashuber/Library/CloudStorage/Dropbox-HECPARIS/Matthias Huber/Replication Package"
global data "${root}/Data/Working Files"
global out  "${root}/Paper Replication/Figures and Tables/Baseline_Analysis_Extensive"
* =====================================
cap mkdir "${root}/Paper Replication/Figures and Tables"
cap mkdir "${out}"


********************************************************************
*** Program: build_event_clock  (defined here; clear all above drops it)
********************************************************************
cap program drop build_event_clock
program define build_event_clock
    syntax , Eventvar(string) [Winmin(integer -8) Winmax(integer 8)]

    cap drop _t_e first_e_date rel_time is_treated window
    qui gen _t_e = qdate if `eventvar' == 1
    bysort issueID: egen first_e_date = min(_t_e)
    format first_e_date %tq
    gen rel_time = qdate - first_e_date
    gen byte is_treated = !missing(first_e_date)
    drop _t_e

    qui keep if is_treated == 1
    qui keep if inrange(rel_time, `winmin', `winmax')
end


********************************************************************
*** Load and set up panel
********************************************************************

use "${data}/_master.dta", clear

foreach v in DowngradeAny Clean_Window net_change_bp gross_buys_bp gross_sells_bp ///
             entry exit issueID issuerID qdate fundtype_det_num {
    cap confirm variable `v'
    if _rc {
        di as err "Variable '`v'' not found in _master.dta."
        exit 111
    }
}

build_event_clock, eventvar("DowngradeAny")

* Window dummy (0 = Pre_2Y baseline)
gen byte window = .
replace  window = 0 if inrange(rel_time, -8, -5)
replace  window = 1 if inrange(rel_time, -4, -1)
replace  window = 2 if rel_time == 0
replace  window = 3 if inrange(rel_time,  1,  4)
replace  window = 4 if inrange(rel_time,  5,  8)
label define winlbl 0 "Pre_2Y" 1 "Pre_1Y" 2 "Downgrade" 3 "Post_1Y" 4 "Post_2Y", replace
label values window winlbl

* Balanced flag BEFORE fundtype restriction
bysort issueID rel_time: gen byte _tag = (_n == 1)
bysort issueID: egen _nq = total(_tag)
gen byte bond_balanced = (_nq == 17)
drop _tag _nq

* Bond-level partition flags using the [-8,-5] pre-event window
cap confirm variable outlook_deterioration
if !_rc {
    gen byte _outlook_in_pre = (outlook_deterioration == 1) & inrange(rel_time, -8, -5)
    bysort issueID: egen outlook_pre = max(_outlook_in_pre)
    drop _outlook_in_pre
}
else {
    di as txt "Note: outlook_deterioration missing -- outlook triple will be skipped."
    gen byte outlook_pre = .
}

cap confirm variable CDS_spread
if !_rc {
    gen byte _cds_in_pre = (!missing(CDS_spread)) & inrange(rel_time, -8, -5)
    bysort issueID: egen CDS_pre = max(_cds_in_pre)
    drop _cds_in_pre
}
else {
    di as txt "Note: CDS_spread missing -- CDS triple will be skipped."
    gen byte CDS_pre = .
}

* Restrict to LI and PMF
keep if inlist(fundtype_det_num, 1, 5)
gen byte LI = (fundtype_det_num == 1)
label variable LI "Life Insurer"


********************************************************************
*** Section A. Descriptive figure
*** Two panels (LI, PMF), each with three lines (net_change, gross_buys,
*** gross_sells) plotted by rel_time. Side by side via graph combine.
********************************************************************

preserve
    keep if Clean_Window == 1
    keep if !missing(rel_time)

    collapse (mean)   m_net = net_change_bp   m_buy = gross_buys_bp   m_sell = gross_sells_bp ///
             (semean) se_net = net_change_bp se_buy = gross_buys_bp  se_sell = gross_sells_bp, ///
             by(fundtype_det_num rel_time)

    foreach x in net buy sell {
        gen hi_`x' = m_`x' + 1.96 * se_`x'
        gen lo_`x' = m_`x' - 1.96 * se_`x'
    }

    foreach ft in 1 5 {
        if `ft' == 1 local lab "Life Insurers"
        if `ft' == 5 local lab "Passive Mutual Funds"
        local gname = cond(`ft' == 1, "desc_li", "desc_pmf")

        twoway ///
            (rcap hi_buy  lo_buy  rel_time if fundtype_det_num == `ft', lcolor(gs6%40)) ///
            (rcap hi_sell lo_sell rel_time if fundtype_det_num == `ft', lcolor(gs10%40)) ///
            (rcap hi_net  lo_net  rel_time if fundtype_det_num == `ft', lcolor(black%40)) ///
            (connected m_buy  rel_time if fundtype_det_num == `ft', ///
                lcolor(gs6)   mcolor(gs6)   msymbol(diamond)  ///
                lwidth(medthick) msize(small) lpattern(dash)) ///
            (connected m_sell rel_time if fundtype_det_num == `ft', ///
                lcolor(gs10)  mcolor(gs10)  msymbol(triangle) ///
                lwidth(medthick) msize(small) lpattern(dot)) ///
            (connected m_net  rel_time if fundtype_det_num == `ft', ///
                lcolor(black) mcolor(black) msymbol(circle)   ///
                lwidth(medthick) msize(small) lpattern(solid)) ///
            , ///
            xline(0, lcolor(gs6) lpattern(dash) lwidth(thin)) ///
            yline(0, lcolor(gs10) lpattern(dot) lwidth(thin)) ///
            xlabel(-8(2)8, labsize(small) nogrid) ///
            ylabel(, labsize(small) angle(0) nogrid) ///
            xtitle("Quarters Relative to Downgrade", size(small)) ///
            ytitle("Mean Flow (bp of offering amount)", size(small)) ///
            title("`lab'", size(medium) color(black)) ///
            legend(order(4 "Gross Buys" 5 "Gross Sells" 6 "Net Change") ///
                   size(small) rows(1) position(6) ring(1) ///
                   region(lcolor(black) lwidth(thin))) ///
            graphregion(color(white)) bgcolor(white) ///
            plotregion(margin(small) lcolor(gs10)) ///
            name(`gname', replace)
    }

    graph combine desc_li desc_pmf, rows(1) ///
        graphregion(color(white)) name(desc_combined, replace)
    graph export "${out}/Figure_extensive_descriptive.png", replace width(2400)
restore


********************************************************************
*** Section B. Table 4 -- baseline LI x window on net_change_bp
*** Headline spec: issueID x qdate FE, clustered issuerID.
********************************************************************

estimates clear

reghdfe net_change_bp ib(0).window##ib(0).LI                              ///
    if Clean_Window == 1,                                                 ///
    absorb(issueID#qdate) cluster(issuerID)
estimates store t4_base

{
local win_levs  "1 2 3 4"
local win_labs `" "Pre_1Y" "Downgrade" "Post_1Y" "Post_2Y" "'
local n_w = 4

local total_rows = 2 + 2*`n_w' + 5
local total_cols = 2

putdocx clear
putdocx begin

putdocx paragraph, halign(center)
putdocx text ("TABLE 4."), bold
putdocx paragraph, halign(center)
putdocx text ("Net Change Around Downgrades -- Life Insurers vs Passive MFs."), bold

putdocx paragraph, halign(both)
putdocx text ("This table reports event-window coefficients of net_change_bp (net quarterly change in a fund's bond holdings, in basis points of offering amount, defined over the full bond-fund-quarter panel) on the interaction of event-window indicators with a Life Insurer dummy. The omitted reference group is Passive Mutual Funds (fundtype_det_num equal to 5) in the omitted window (Pre_2Y, rel_time -8 to -5). Pre_1Y covers -4 to -1, Downgrade is rel_time 0, Post_1Y covers 1 to 4, Post_2Y covers 5 to 8. Fixed effects are issue-by-quarter. Standard errors clustered by issuer in parentheses. *, **, and *** denote statistical significance at the 10%, 5%, and 1% levels, respectively.")

putdocx paragraph

putdocx table tbl = (`total_rows', `total_cols'), border(all, nil)

putdocx table tbl(1,1) = (""),                                              bold halign(left)
putdocx table tbl(1,2) = ("Net Change (bp of offering amount)"),            bold halign(center)
putdocx table tbl(1,.), border(top, single)

putdocx table tbl(2,1) = ("Window x Life Insurer"), bold halign(left)
putdocx table tbl(2,2) = ("Coefficient"),           bold halign(right)
putdocx table tbl(2,.), border(bottom, single)

local r = 3
forvalues i = 1/`n_w' {
    local lv  : word `i' of `win_levs'
    local lab : word `i' of `win_labs'

    qui estimates restore t4_base
    local b  = _b[`lv'.window#1.LI]
    local se = _se[`lv'.window#1.LI]
    local p  = 2*ttail(e(df_r), abs(`b'/`se'))
    local stars ""
    if `p' < 0.01      local stars "***"
    else if `p' < 0.05 local stars "**"
    else if `p' < 0.10 local stars "*"

    putdocx table tbl(`r',1) = ("`lab' x LI"),                          halign(left)
    putdocx table tbl(`r',2) = (string(`b', "%12.3fc") + "`stars'"),    halign(right)
    local ++r

    putdocx table tbl(`r',1) = (""),                                    halign(left)
    putdocx table tbl(`r',2) = ("(" + string(`se', "%12.3fc") + ")"),   halign(right)
    local ++r
}

local last_coef = `r' - 1
putdocx table tbl(`last_coef',.), border(bottom, single)

qui estimates restore t4_base
putdocx table tbl(`r',1) = ("Issue x Quarter FE"),                        halign(left)
putdocx table tbl(`r',2) = ("Yes"),                                       halign(right)
local ++r
putdocx table tbl(`r',1) = ("Clusters"),                                  halign(left)
putdocx table tbl(`r',2) = ("Issuer"),                                    halign(right)
local ++r
putdocx table tbl(`r',1) = ("Observations"),                              halign(left)
putdocx table tbl(`r',2) = ("`: display %12.0fc e(N)'"),                  halign(right)
local ++r
putdocx table tbl(`r',1) = ("R-squared"),                                 halign(left)
putdocx table tbl(`r',2) = ("`: display %12.3fc e(r2)'"),                 halign(right)
local ++r
putdocx table tbl(`r',1) = ("Clusters (Issuers)"),                        halign(left)
putdocx table tbl(`r',2) = ("`: display %12.0fc e(N_clust)'"),            halign(right)
putdocx table tbl(`r',.), border(bottom, single)

putdocx save "${out}/Table4_extensive_baseline.docx", replace
}


********************************************************************
*** Section C. Table 5 -- progressive FE for LI x window on net_change_bp
*** Col 1: no FE; Col 2: issue + quarter FE; Col 3: issuer x quarter FE;
*** Col 4: issue x quarter FE. Clustered issuerID throughout.
********************************************************************

estimates clear

reghdfe net_change_bp ib(0).window##ib(0).LI                              ///
    if Clean_Window == 1,                                                 ///
    noabsorb cluster(issuerID)
estimates store t5_c1

reghdfe net_change_bp ib(0).window##ib(0).LI                              ///
    if Clean_Window == 1,                                                 ///
    absorb(issueID qdate) cluster(issuerID)
estimates store t5_c2

reghdfe net_change_bp ib(0).window##ib(0).LI                              ///
    if Clean_Window == 1,                                                 ///
    absorb(issuerID#qdate) cluster(issuerID)
estimates store t5_c3

reghdfe net_change_bp ib(0).window##ib(0).LI                              ///
    if Clean_Window == 1,                                                 ///
    absorb(issueID#qdate) cluster(issuerID)
estimates store t5_c4

{
local win_levs  "1 2 3 4"
local win_labs `" "Pre_1Y" "Downgrade" "Post_1Y" "Post_2Y" "'
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
putdocx text ("Net Change Around Downgrades -- Progressive Fixed-Effects Specifications."), bold

putdocx paragraph, halign(both)
putdocx text ("This table reports event-window coefficients of net_change_bp on Life Insurer x window indicators across four fixed-effects specifications, progressively absorbing issue, quarter, issuer-quarter, and issue-quarter heterogeneity. Column (1) includes no fixed effects. Column (2) adds issue and quarter fixed effects separately. Column (3) adds issuer-by-quarter fixed effects. Column (4) adds issue-by-quarter fixed effects. The omitted reference group is Passive Mutual Funds in the omitted window (Pre_2Y). Standard errors clustered by issuer in parentheses. *, **, and *** denote statistical significance at the 10%, 5%, and 1% levels, respectively.")

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
        local b  = _b[`lv'.window#1.LI]
        local se = _se[`lv'.window#1.LI]
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
        local se = _se[`lv'.window#1.LI]
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

putdocx save "${out}/Table5_extensive_FE.docx", replace
}


********************************************************************
*** Section D. Table 6 -- partition triples on net_change_bp
*** Col 1: LI x Window x Outlook_pre (outlook det in [-8,-5])
*** Col 2: LI x Window x CDS_pre     (CDS coverage in [-8,-5])
*** issueID#qdate FE absorbs all bond-quarter main effects.
********************************************************************

estimates clear

cap confirm variable outlook_deterioration
local has_outlook = (_rc == 0)
cap confirm variable CDS_spread
local has_cds = (_rc == 0)

if `has_outlook' {
    reghdfe net_change_bp ib(0).window##ib(0).LI##ib(0).outlook_pre       ///
        if Clean_Window == 1,                                             ///
        absorb(issueID#qdate) cluster(issuerID)
    estimates store t6_out
}
if `has_cds' {
    reghdfe net_change_bp ib(0).window##ib(0).LI##ib(0).CDS_pre           ///
        if Clean_Window == 1,                                             ///
        absorb(issueID#qdate) cluster(issuerID)
    estimates store t6_cds
}

{
local win_levs  "1 2 3 4"
local win_labs `" "Pre_1Y" "Downgrade" "Post_1Y" "Post_2Y" "'
local n_w = 4

* Build dynamic model list based on what is available
local models
local mod_labs
local mod_flags
local n_m = 0
if `has_outlook' {
    local models    `models'   t6_out
    local mod_labs `"`mod_labs' "Outlook" "'
    local mod_flags `mod_flags' outlook_pre
    local ++n_m
}
if `has_cds' {
    local models    `models'   t6_cds
    local mod_labs `"`mod_labs' "CDS Coverage" "'
    local mod_flags `mod_flags' CDS_pre
    local ++n_m
}

if `n_m' == 0 {
    di as txt "Table 6 skipped: neither outlook_deterioration nor CDS_spread available."
}
else {

local total_rows = 2 + 4*`n_w' + 5
local total_cols = 1 + `n_m'

putdocx clear
putdocx begin

putdocx paragraph, halign(center)
putdocx text ("TABLE 6."), bold
putdocx paragraph, halign(center)
putdocx text ("Net Change Around Downgrades -- Outlook and CDS Pre-Event Partition Triples."), bold

putdocx paragraph, halign(both)
putdocx text ("This table reports triple-interaction coefficients of net_change_bp on event-window indicators interacted with a Life Insurer dummy and a bond-level pre-event signal flag. In column (1), the flag equals 1 if the bond has any negative outlook revision in rel_time -8 to -5 and 0 otherwise. In column (2), the flag equals 1 if the bond has any CDS observation in rel_time -8 to -5 and 0 otherwise. The reported coefficients are the Life Insurer x Window x Flag triples (the LI x Window coefficient is also reported). Fixed effects are issue-by-quarter, which absorb all bond-quarter main effects including the flag. Standard errors clustered by issuer in parentheses. *, **, and *** denote statistical significance at the 10%, 5%, and 1% levels, respectively.")

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

    * LI x Window coefficient
    putdocx table tbl(`r',1) = ("`lab' x LI"), halign(left)
    forvalues j = 1/`n_m' {
        local mname : word `j' of `models'
        local col   = `j' + 1
        qui estimates restore `mname'
        local b  = _b[`lv'.window#1.LI]
        local se = _se[`lv'.window#1.LI]
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
        local se = _se[`lv'.window#1.LI]
        putdocx table tbl(`r',`col') = ("(" + string(`se', "%12.3fc") + ")"), halign(right)
    }
    local ++r

    * Triple
    putdocx table tbl(`r',1) = ("`lab' x LI x Flag"), halign(left)
    forvalues j = 1/`n_m' {
        local mname : word `j' of `models'
        local flag  : word `j' of `mod_flags'
        local col   = `j' + 1
        qui estimates restore `mname'
        local b  = _b[`lv'.window#1.LI#1.`flag']
        local se = _se[`lv'.window#1.LI#1.`flag']
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
        local flag  : word `j' of `mod_flags'
        local col   = `j' + 1
        qui estimates restore `mname'
        local se = _se[`lv'.window#1.LI#1.`flag']
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

putdocx save "${out}/Table6_extensive_partition.docx", replace
}
}


********************************************************************
*** Section E. Table 7 -- Entry and Exit, unbalanced and balanced
*** 4 columns: entry-unbal, entry-bal, exit-unbal, exit-bal.
*** Coefficients NOT scaled to pp -- raw LPM coefficients.
*** issueID#qdate FE, clustered issuerID.
********************************************************************

estimates clear

reghdfe entry ib(0).window##ib(0).LI                                      ///
    if Clean_Window == 1,                                                 ///
    absorb(issueID#qdate) cluster(issuerID)
estimates store t7_ent_u

reghdfe entry ib(0).window##ib(0).LI                                      ///
    if Clean_Window == 1 & bond_balanced == 1,                            ///
    absorb(issueID#qdate) cluster(issuerID)
estimates store t7_ent_b

reghdfe exit ib(0).window##ib(0).LI                                       ///
    if Clean_Window == 1,                                                 ///
    absorb(issueID#qdate) cluster(issuerID)
estimates store t7_exi_u

reghdfe exit ib(0).window##ib(0).LI                                       ///
    if Clean_Window == 1 & bond_balanced == 1,                            ///
    absorb(issueID#qdate) cluster(issuerID)
estimates store t7_exi_b

{
local win_levs  "1 2 3 4"
local win_labs `" "Pre_1Y" "Downgrade" "Post_1Y" "Post_2Y" "'
local n_w = 4

local models    t7_ent_u t7_ent_b t7_exi_u t7_exi_b
local mod_labs `" "Unbalanced" "Balanced" "Unbalanced" "Balanced" "'
local n_m = 4

local total_rows = 3 + 2*`n_w' + 5
local total_cols = 1 + `n_m'

putdocx clear
putdocx begin

putdocx paragraph, halign(center)
putdocx text ("TABLE 7."), bold
putdocx paragraph, halign(center)
putdocx text ("Extensive-Margin Trading Around Downgrades -- Entry and Exit."), bold

putdocx paragraph, halign(both)
putdocx text ("This table reports linear probability model coefficients of position entry (an indicator equal to 1 in the quarter a fund initiates a position in a bond) and position exit (an indicator equal to 1 in the quarter a fund terminates a position in a bond) on the interaction of event-window indicators with a Life Insurer dummy. The reference group is Passive Mutual Funds in the omitted window (Pre_2Y, rel_time -8 to -5). Columns (1) and (3) use the full event-window sample. Columns (2) and (4) restrict to bonds observed in all 17 event quarters (the balanced sample). The balanced flag is computed on the full panel before the LI and PMF restriction. Coefficients are reported in raw probability units; multiply by 100 to obtain percentage points. Fixed effects are issue-by-quarter throughout. Standard errors clustered by issuer in parentheses. *, **, and *** denote statistical significance at the 10%, 5%, and 1% levels, respectively.")

putdocx paragraph

putdocx table tbl = (`total_rows', `total_cols'), border(all, nil)

* Top group header: Entry | Exit
putdocx table tbl(1,1) = (""), bold halign(left)
putdocx table tbl(1,2) = ("Entry"), bold halign(center)
putdocx table tbl(1,2), colspan(2)
putdocx table tbl(1,4) = ("Exit"),  bold halign(center)
putdocx table tbl(1,4), colspan(2)
putdocx table tbl(1,.), border(top, single)

* Second header: balanced status
putdocx table tbl(2,1) = (""), bold halign(left)
forvalues j = 1/`n_m' {
    local mlab : word `j' of `mod_labs'
    local col  = `j' + 1
    putdocx table tbl(2,`col') = ("`mlab'"), bold halign(right)
}

* Third header: column numbers
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
        local b  = _b[`lv'.window#1.LI]
        local se = _se[`lv'.window#1.LI]
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
        local se = _se[`lv'.window#1.LI]
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

putdocx save "${out}/Table7_extensive_entry_exit.docx", replace
}


********************************************************************
*** End
********************************************************************
