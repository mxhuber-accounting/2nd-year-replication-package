********************************************************************
*** 2_Baseline_Analysis.do
***
*** Input:  ${data}/_master.dta  (built by Build_Master.do)
*** Output: ${out}/tableN_*.docx   (no subfolder prefix)
***
*** Main outcome: delta_holdings (bp of offering amount, winsorized 1/99
*** by fundtype). Built in Sample_Creation.do.
***
*** Event clock: first downgrade by any agency (S&P, Moody's, Fitch)
***
*** Table 1  -- Baseline by investor type (Constr_Investor)
*** Table 2  -- Robustness: progressive FE & controls (LI vs PMF)
*** Table 3  -- Sign decomposition: pos / neg delta x Full/Bal., LI vs PMF
*** Table 4  -- Extensive margin (entry/exit) x Full/Bal., LI vs PMF
*** Table 5  -- First downgrade by agency (S&P / Moody's / Fitch)
*** Table 6  -- Anticipation: prior outlook deterioration (triple), Unbal/Bal
*** Table 7  -- CDS coverage (triple), Unbal/Bal
*** Table 8  -- Manager cross-section: firmid == INM (triple), Unbal/Bal
*** Table 9  -- DV robustness: net change (bp) / delta holdings ($) / share
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
global out  "${root}/Paper Replication/Figures and Tables/Baseline_Analysis"
global paperfigs "${root}/Paper Replication/Figures and Tables/Tables and Figures in Paper"
* =====================================
cap mkdir "${root}/Paper Replication/Figures and Tables"
cap mkdir "${out}"
cap mkdir "${paperfigs}"


********************************************************************
*** Helper: build event clock around any binary bond-quarter event
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

    gen window = .
    replace window = 1 if inrange(rel_time, -8, -5)
    replace window = 2 if inrange(rel_time, -4, -1)
    replace window = 3 if rel_time == 0
    replace window = 4 if inrange(rel_time, 1, 4)
    replace window = 5 if inrange(rel_time, 5, 8)
    label define winlbl 1 "Pre_2Y" 2 "Pre_1Y" 3 "Downgrade" 4 "Post_1Y" 5 "Post_2Y", replace
    label values window winlbl
end


********************************************************************
*** TABLE 1 -- Baseline by investor type (Constr_Investor)
********************************************************************

use "${data}/_master.dta", clear
build_event_clock, eventvar("DowngradeAny")

reghdfe net_change_bp ib(1).window##ib(0).Constr_Investor ///
    if Clean_Window == 1, absorb(issueID##qdate) cluster(issuerID)
estimates store t1_baseline

{
local types     "1 2 3 4"
local type_labs `" "Life Insurer" "Other Insurer" "P&C Insurer" "Variable Annuity" "'
local n_types   = 4

local windows   "2 3 4 5"
local win_labs  `" "Pre_1Y" "Downgrade" "Post_1Y" "Post_2Y" "'
local n_wins    = 4

local total_rows = 2 + 2*`n_types' + 4
local total_cols = `n_wins' + 1

putdocx clear
putdocx begin

putdocx paragraph, halign(center)
putdocx text ("TABLE 3."), bold
putdocx paragraph, halign(center)
putdocx text ("Trading Around Credit Rating Downgrades -- Baseline by Investor Type."), bold

putdocx paragraph, halign(both)
putdocx text ("This table reports coefficient estimates from a panel regression of the quarterly change in bond holdings (Delta Holdings, in basis points of offering amount, winsorized at the 1st and 99th percentiles within fundtype) on event-window indicators interacted with investor-type indicators. The event clock is centered on the first downgrade by any major rating agency (S&P, Moody's, or Fitch). Each cell shows the differential trading response of the row's investor type relative to Passive Mutual Funds in the column's event window, relative to the Pre_2Y baseline differential. Event windows: Pre_2Y (t = -8 to -5, omitted), Pre_1Y (t = -4 to -1), Downgrade (t = 0), Post_1Y (t = 1 to 4), Post_2Y (t = 5 to 8). Window main effects are absorbed by issue x quarter fixed effects. Sample includes life insurers, other insurers, P&C insurers, variable annuities, and passive mutual funds, restricted to bond-quarters in the clean window. Standard errors clustered by issuer in parentheses. *, **, and *** denote statistical significance at the 10%, 5%, and 1% levels, respectively.")

putdocx paragraph

putdocx table tbl = (`total_rows', `total_cols'), border(all, nil)

putdocx table tbl(1,1) = (""), bold halign(left)
putdocx table tbl(1,2) = ("Delta Holdings (bp of offering amount)"), bold halign(center)
putdocx table tbl(1,2), colspan(`n_wins')
putdocx table tbl(1,.), border(top, single)

putdocx table tbl(2,1) = ("Investor Type (vs. Passive MF)"), bold halign(left)
forvalues j = 1/`n_wins' {
    local wlab : word `j' of `win_labs'
    local col  = `j' + 1
    putdocx table tbl(2,`col') = ("`wlab'"), bold halign(right)
}
putdocx table tbl(2,.), border(bottom, single)

local r = 3
qui estimates restore t1_baseline

forvalues i = 1/`n_types' {
    local tv   : word `i' of `types'
    local tlab : word `i' of `type_labs'

    putdocx table tbl(`r',1) = ("`tlab'"), halign(left)
    forvalues j = 1/`n_wins' {
        local wv  : word `j' of `windows'
        local col = `j' + 1
        local b = .
        local se = .
        capture local b  = _b[`wv'.window#`tv'.Constr_Investor]
        capture local se = _se[`wv'.window#`tv'.Constr_Investor]
        if missing(`b') {
            putdocx table tbl(`r',`col') = ("--"), halign(right)
        }
        else {
            local p = 2*ttail(e(df_r), abs(`b'/`se'))
            local stars ""
            if `p' < 0.01      local stars "***"
            else if `p' < 0.05 local stars "**"
            else if `p' < 0.10 local stars "*"
            putdocx table tbl(`r',`col') = (string(`b', "%12.3fc") + "`stars'"), halign(right)
        }
    }
    local ++r

    putdocx table tbl(`r',1) = (""), halign(left)
    forvalues j = 1/`n_wins' {
        local wv  : word `j' of `windows'
        local col = `j' + 1
        local se = .
        capture local se = _se[`wv'.window#`tv'.Constr_Investor]
        if missing(`se') {
            putdocx table tbl(`r',`col') = (""), halign(right)
        }
        else {
            putdocx table tbl(`r',`col') = ("(" + string(`se', "%12.3fc") + ")"), halign(right)
        }
    }
    local ++r
}

local last_coef = `r' - 1
putdocx table tbl(`last_coef',.), border(bottom, single)

putdocx table tbl(`r',1) = ("Issue x Quarter FE"), halign(left)
forvalues j = 1/`n_wins' {
    local col = `j' + 1
    putdocx table tbl(`r',`col') = ("Yes"), halign(right)
}
local ++r

putdocx table tbl(`r',1) = ("Observations"), halign(left)
putdocx table tbl(`r',2) = ("`: display %12.0fc e(N)'"), halign(right)
putdocx table tbl(`r',2), colspan(`n_wins')
local ++r

putdocx table tbl(`r',1) = ("R-squared"), halign(left)
putdocx table tbl(`r',2) = ("`: display %12.3fc e(r2)'"), halign(right)
putdocx table tbl(`r',2), colspan(`n_wins')
local ++r

putdocx table tbl(`r',1) = ("Clusters (Issuers)"), halign(left)
putdocx table tbl(`r',2) = ("`: display %12.0fc e(N_clust)'"), halign(right)
putdocx table tbl(`r',2), colspan(`n_wins')
putdocx table tbl(`r',.), border(bottom, single)

putdocx save "${out}/table1_baseline_constr_investor.docx", replace
copy "${out}/table1_baseline_constr_investor.docx" "${paperfigs}/T03_Table3_Baseline by Investor Type.docx", replace   // paper-folder copy
}



********************************************************************
*** TABLE 2 -- Robustness: progressive FE and controls (LI vs PMF)
***   Cols 1-2: Quarter FE                       + controls (Full/Bal)
***   Cols 3-4: Issuer x Quarter FE              + controls (Full/Bal)
***   Cols 5-6: Issue FE + Quarter FE (separate) -- no controls (Full/Bal)
***   Cols 7-8: Issue x Quarter FE               -- no controls (baseline, Full/Bal)
***   Controls (cols 1-4): ttm, NAIC_num, log(amount_outstanding)
********************************************************************

use "${data}/_master.dta", clear
build_event_clock, eventvar("DowngradeAny")

* bond_balanced computed BEFORE LI+PMF restriction
bysort issueID rel_time: gen _tag = (_n == 1)
bysort issueID: egen _nq = total(_tag)
gen byte bond_balanced = (_nq == 17)
drop _tag _nq

keep if inlist(fundtype_det_num, 1, 5)

gen byte LI = (fundtype_det_num == 1)
label variable LI "Life Insurer"

foreach v in ttm NAIC_num log_aoutstanding {
    cap confirm variable `v'
    if _rc {
        di as err "Variable '`v'' not found -- required for robustness controls."
        exit 111
    }
}

estimates clear
cap drop bond_age
gen int bond_age = qdate - qoffering

	
reghdfe delta_holdings ib(1).window##i.LI ///
    if Clean_Window == 1, absorb(issueID#qdate i.bond_age#i.LI) cluster(issuerID)

* ---- Quarter FE + controls
reghdfe delta_holdings ib(1).window##ib(0).LI ///
    ttm NAIC_num log_aoutstanding bond_age ///
    if Clean_Window == 1, absorb(qdate) cluster(issuerID)
estimates store t2_c1

reghdfe delta_holdings ib(1).window##ib(0).LI ///
    ttm NAIC_num log_aoutstanding bond_age ///
    if Clean_Window == 1 & bond_balanced == 1, absorb(qdate) cluster(issuerID)
estimates store t2_c2

* ---- Issuer x Quarter FE + controls
reghdfe delta_holdings ib(1).window##ib(0).LI ///
    ttm NAIC_num log_aoutstanding ///
    if Clean_Window == 1, absorb(issuerID##qdate) cluster(issuerID)
estimates store t2_c3

reghdfe delta_holdings ib(1).window##ib(0).LI ///
    ttm NAIC_num log_aoutstanding ///
    if Clean_Window == 1 & bond_balanced == 1, absorb(issuerID##qdate) cluster(issuerID)
estimates store t2_c4

* ---- Issue FE + Quarter FE (separate), no controls
reghdfe delta_holdings ib(1).window##ib(0).LI ///
    if Clean_Window == 1, absorb(issueID qdate) cluster(issuerID)
estimates store t2_c5

reghdfe delta_holdings ib(1).window##ib(0).LI ///
    if Clean_Window == 1 & bond_balanced == 1, absorb(issueID qdate) cluster(issuerID)
estimates store t2_c6

* ---- Issue x Quarter FE, no controls (baseline)
reghdfe delta_holdings ib(1).window##ib(0).LI ///
    if Clean_Window == 1, absorb(issueID##qdate) cluster(issuerID)
estimates store t2_c7

reghdfe delta_holdings ib(1).window##ib(0).LI ///
    if Clean_Window == 1 & bond_balanced == 1, absorb(issueID##qdate) cluster(issuerID)
estimates store t2_c8

{
local models    "t2_c1 t2_c2 t2_c3 t2_c4 t2_c5 t2_c6 t2_c7 t2_c8"
local fe_labs   `" "Quarter" "Quarter" "Issuer x Q" "Issuer x Q" "Issue + Q" "Issue + Q" "Issue x Q" "Issue x Q" "'
local ctrl_labs `" "Yes" "Yes" "Yes" "Yes" "No" "No" "No" "No" "'
local samp_labs `" "Full" "Bal." "Full" "Bal." "Full" "Bal." "Full" "Bal." "'
local n_models  = 8

local windows   "2 3 4 5"
local win_labs  `" "Pre_1Y x LI" "Downgrade x LI" "Post_1Y x LI" "Post_2Y x LI" "'
local n_wins    = 4

local total_rows = 2 + 2*`n_wins' + 6
local total_cols = `n_models' + 1

putdocx clear
putdocx begin, pagesize(A4) landscape margin(all, 0.7in)

putdocx paragraph, halign(center)
putdocx text ("TABLE 4."), bold
putdocx paragraph, halign(center)
putdocx text ("Life Insurer Delta Holdings around Credit Rating Downgrades -- Progressive FE and Controls."), bold

putdocx paragraph, halign(both)
putdocx text ("This table reports robustness checks for the Life Insurer differential around credit rating downgrades, varying the fixed-effect structure, the inclusion of bond-level controls, and the sample across columns. The dependent variable is Delta Holdings (bp of offering amount, winsorized 1/99 by fundtype). The event clock is centered on the first downgrade by any rating agency (S&P, Moody's, or Fitch). Each cell reports the Life Insurer x event-window coefficient (denoted LI x Window in the row labels). Columns (1)-(2) Quarter FE; Columns (3)-(4) Issuer x Quarter FE; Columns (5)-(6) Issue and Quarter FE; Columns (7)-(8) Issue x Quarter FE (baseline). Columns (1)-(4) include bond-level controls: time to maturity (ttm), composite NAIC notch rating, and log amount outstanding. Columns (5)-(8) omit controls because Issue fixed effects absorb most bond-level variation. Odd-numbered columns within each pair use the Full sample; even-numbered columns require the bond to be observed in all 17 event-time quarters (Balanced). Sample restricted to Life Insurers and Passive Mutual Funds. Standard errors clustered by issuer in parentheses. *, **, and *** denote statistical significance at the 10%, 5%, and 1% levels, respectively.")

putdocx paragraph

putdocx table tbl = (`total_rows', `total_cols'), border(all, nil)

putdocx table tbl(1,1) = (""), bold halign(left)
putdocx table tbl(1,2) = ("Delta Holdings (bp)"), bold halign(center)
putdocx table tbl(1,2), colspan(`n_models')
putdocx table tbl(1,.), border(top, single)

putdocx table tbl(2,1) = ("Event Window"), bold halign(left)
forvalues j = 1/`n_models' {
    local col = `j' + 1
    putdocx table tbl(2,`col') = ("(`j')"), bold halign(right)
}
putdocx table tbl(2,.), border(bottom, single)

local r = 3

forvalues i = 1/`n_wins' {
    local wv   : word `i' of `windows'
    local wlab : word `i' of `win_labs'

    putdocx table tbl(`r',1) = ("`wlab'"), halign(left)
    forvalues j = 1/`n_models' {
        local m   : word `j' of `models'
        local col = `j' + 1
        qui estimates restore `m'
        local b = .
        local se = .
        capture local b  = _b[`wv'.window#1.LI]
        capture local se = _se[`wv'.window#1.LI]
        if missing(`b') {
            putdocx table tbl(`r',`col') = ("--"), halign(right)
        }
        else {
            local p = 2*ttail(e(df_r), abs(`b'/`se'))
            local stars ""
            if `p' < 0.01      local stars "***"
            else if `p' < 0.05 local stars "**"
            else if `p' < 0.10 local stars "*"
            putdocx table tbl(`r',`col') = (string(`b', "%12.3fc") + "`stars'"), halign(right)
        }
    }
    local ++r

    putdocx table tbl(`r',1) = (""), halign(left)
    forvalues j = 1/`n_models' {
        local m   : word `j' of `models'
        local col = `j' + 1
        qui estimates restore `m'
        local se = .
        capture local se = _se[`wv'.window#1.LI]
        if missing(`se') {
            putdocx table tbl(`r',`col') = (""), halign(right)
        }
        else {
            putdocx table tbl(`r',`col') = ("(" + string(`se', "%12.3fc") + ")"), halign(right)
        }
    }
    local ++r
}

local last_coef = `r' - 1
putdocx table tbl(`last_coef',.), border(bottom, single)

putdocx table tbl(`r',1) = ("Fixed Effects"), halign(left)
forvalues j = 1/`n_models' {
    local felab : word `j' of `fe_labs'
    local col   = `j' + 1
    putdocx table tbl(`r',`col') = ("`felab'"), halign(right)
}
local ++r

putdocx table tbl(`r',1) = ("Bond Controls"), halign(left)
forvalues j = 1/`n_models' {
    local clab : word `j' of `ctrl_labs'
    local col  = `j' + 1
    putdocx table tbl(`r',`col') = ("`clab'"), halign(right)
}
local ++r

putdocx table tbl(`r',1) = ("Sample"), halign(left)
forvalues j = 1/`n_models' {
    local slab : word `j' of `samp_labs'
    local col  = `j' + 1
    putdocx table tbl(`r',`col') = ("`slab'"), halign(right)
}
local ++r

putdocx table tbl(`r',1) = ("Observations"), halign(left)
forvalues j = 1/`n_models' {
    local m   : word `j' of `models'
    local col = `j' + 1
    qui estimates restore `m'
    putdocx table tbl(`r',`col') = ("`: display %12.0fc e(N)'"), halign(right)
}
local ++r

putdocx table tbl(`r',1) = ("R-squared"), halign(left)
forvalues j = 1/`n_models' {
    local m   : word `j' of `models'
    local col = `j' + 1
    qui estimates restore `m'
    putdocx table tbl(`r',`col') = ("`: display %12.3fc e(r2)'"), halign(right)
}
local ++r

putdocx table tbl(`r',1) = ("Clusters (Issuers)"), halign(left)
forvalues j = 1/`n_models' {
    local m   : word `j' of `models'
    local col = `j' + 1
    qui estimates restore `m'
    putdocx table tbl(`r',`col') = ("`: display %12.0fc e(N_clust)'"), halign(right)
}
putdocx table tbl(`r',.), border(bottom, single)

putdocx save "${out}/table2_robustness_FE_controls.docx", replace
copy "${out}/table2_robustness_FE_controls.docx" "${paperfigs}/T04_Table4_Robustness FE and Controls.docx", replace   // paper-folder copy
}

********************************************************************
*** TABLE 3 -- Sign decomposition: pos / neg delta x Full/Bal., LI vs PMF
********************************************************************

use "${data}/_master.dta", clear
build_event_clock, eventvar("DowngradeAny")

bysort issueID rel_time: gen _tag = (_n == 1)
bysort issueID: egen _nq = total(_tag)
gen byte bond_balanced = (_nq == 17)
drop _tag _nq

keep if inlist(fundtype_det_num, 1, 5)

estimates clear

reghdfe pos_delta_holdings ib(1).window##ib(1).PassiveInvestor ///
    if Clean_Window == 1, absorb(issueID##qdate) cluster(issuerID)
estimates store t3_pos_full

reghdfe pos_delta_holdings ib(1).window##ib(1).PassiveInvestor ///
    if Clean_Window == 1 & bond_balanced == 1, ///
    absorb(issueID##qdate) cluster(issuerID)
estimates store t3_pos_bal

reghdfe neg_delta_holdings ib(1).window##ib(1).PassiveInvestor ///
    if Clean_Window == 1, absorb(issueID##qdate) cluster(issuerID)
estimates store t3_neg_full

reghdfe neg_delta_holdings ib(1).window##ib(1).PassiveInvestor ///
    if Clean_Window == 1 & bond_balanced == 1, ///
    absorb(issueID##qdate) cluster(issuerID)
estimates store t3_neg_bal

{
local models    "t3_pos_full t3_pos_bal t3_neg_full t3_neg_bal"
local samples   `" "Full" "Bal." "Full" "Bal." "'
local n_models  = 4

local windows   "2 3 4 5"
local win_labs  `" "Pre_1Y x Life Insurer" "Downgrade x Life Insurer" "Post_1Y x Life Insurer" "Post_2Y x Life Insurer" "'
local n_wins    = 4

local total_rows = 2 + 2*`n_wins' + 5
local total_cols = `n_models' + 1

putdocx clear
putdocx begin

putdocx paragraph, halign(center)
putdocx text ("TABLE 3."), bold
putdocx paragraph, halign(center)
putdocx text ("Life Insurer Holdings Changes around Credit Rating Downgrades -- Sign Decomposition."), bold

putdocx paragraph, halign(both)
putdocx text ("This table reports coefficient estimates from panel regressions decomposing the quarterly change in bond holdings (Delta Holdings) into a positive component (Pos Delta, retains positive changes and zeros otherwise) and a negative component (Neg Delta, absolute value of negative changes and zeros otherwise). Both components are in basis points of offering amount and winsorized at the 1st and 99th percentiles within fundtype. The event clock is centered on the first downgrade by any rating agency. Each cell shows the differential response of Life Insurers relative to Passive Mutual Funds in the column outcome and event window, relative to the Pre_2Y baseline. Sample restricted to Life Insurers and Passive MFs. Columns labelled Full use all bond-fund-firm-quarter observations in the event window; columns labelled Bal. further require the bond to be observed in all 17 event-time quarters. All specifications include issue x quarter fixed effects. Standard errors clustered by issuer in parentheses. *, **, and *** denote statistical significance at the 10%, 5%, and 1% levels, respectively.")

putdocx paragraph

putdocx table tbl = (`total_rows', `total_cols'), border(all, nil)

putdocx table tbl(1,1) = (""), bold halign(left)
putdocx table tbl(1,2) = ("Pos Delta"),  bold halign(center)
putdocx table tbl(1,4) = ("Neg Delta"),  bold halign(center)
putdocx table tbl(1,4), colspan(2)
putdocx table tbl(1,2), colspan(2)
putdocx table tbl(1,.), border(top, single)

putdocx table tbl(2,1) = ("Event Window"), bold halign(left)
forvalues j = 1/`n_models' {
    local col = `j' + 1
    putdocx table tbl(2,`col') = ("(`j')"), bold halign(right)
}
putdocx table tbl(2,.), border(bottom, single)

local r = 3

forvalues i = 1/`n_wins' {
    local wv   : word `i' of `windows'
    local wlab : word `i' of `win_labs'

    putdocx table tbl(`r',1) = ("`wlab'"), halign(left)
    forvalues j = 1/`n_models' {
        local m   : word `j' of `models'
        local col = `j' + 1
        qui estimates restore `m'
        local b  = .
        local se = .
        capture local b  = _b[`wv'.window#2.PassiveInvestor]
        capture local se = _se[`wv'.window#2.PassiveInvestor]
        if missing(`b') {
            putdocx table tbl(`r',`col') = ("--"), halign(right)
        }
        else {
            local p = 2*ttail(e(df_r), abs(`b'/`se'))
            local stars ""
            if `p' < 0.01      local stars "***"
            else if `p' < 0.05 local stars "**"
            else if `p' < 0.10 local stars "*"
            putdocx table tbl(`r',`col') = (string(`b', "%12.3fc") + "`stars'"), halign(right)
        }
    }
    local ++r

    putdocx table tbl(`r',1) = (""), halign(left)
    forvalues j = 1/`n_models' {
        local m   : word `j' of `models'
        local col = `j' + 1
        qui estimates restore `m'
        local se = .
        capture local se = _se[`wv'.window#2.PassiveInvestor]
        if missing(`se') {
            putdocx table tbl(`r',`col') = (""), halign(right)
        }
        else {
            putdocx table tbl(`r',`col') = ("(" + string(`se', "%12.3fc") + ")"), halign(right)
        }
    }
    local ++r
}

local last_coef = `r' - 1
putdocx table tbl(`last_coef',.), border(bottom, single)

putdocx table tbl(`r',1) = ("Issue x Quarter FE"), halign(left)
forvalues j = 1/`n_models' {
    local col = `j' + 1
    putdocx table tbl(`r',`col') = ("Yes"), halign(right)
}
local ++r

putdocx table tbl(`r',1) = ("Sample"), halign(left)
forvalues j = 1/`n_models' {
    local slab : word `j' of `samples'
    local col  = `j' + 1
    putdocx table tbl(`r',`col') = ("`slab'"), halign(right)
}
local ++r

putdocx table tbl(`r',1) = ("Observations"), halign(left)
forvalues j = 1/`n_models' {
    local m   : word `j' of `models'
    local col = `j' + 1
    qui estimates restore `m'
    putdocx table tbl(`r',`col') = ("`: display %12.0fc e(N)'"), halign(right)
}
local ++r

putdocx table tbl(`r',1) = ("R-squared"), halign(left)
forvalues j = 1/`n_models' {
    local m   : word `j' of `models'
    local col = `j' + 1
    qui estimates restore `m'
    putdocx table tbl(`r',`col') = ("`: display %12.3fc e(r2)'"), halign(right)
}
local ++r

putdocx table tbl(`r',1) = ("Clusters (Issuers)"), halign(left)
forvalues j = 1/`n_models' {
    local m   : word `j' of `models'
    local col = `j' + 1
    qui estimates restore `m'
    putdocx table tbl(`r',`col') = ("`: display %12.0fc e(N_clust)'"), halign(right)
}
putdocx table tbl(`r',.), border(bottom, single)

putdocx save "${out}/table3_signdecomp_LI_vs_PMF.docx", replace
}


********************************************************************
*** TABLE 4 -- Extensive margin (entry/exit) x Full/Bal., LI vs PMF
********************************************************************

use "${data}/_master.dta", clear
build_event_clock, eventvar("DowngradeAny")

bysort issueID rel_time: gen _tag = (_n == 1)
bysort issueID: egen _nq = total(_tag)
gen byte bond_balanced = (_nq == 17)
drop _tag _nq

keep if inlist(fundtype_det_num, 1, 5)

foreach v in entry exit {
    cap confirm variable `v'
    if _rc {
        di as err "Variable '`v'' not found -- extensive margin table requires it."
        exit 111
    }
}

estimates clear

reghdfe entry ib(1).window##ib(1).PassiveInvestor ///
    if Clean_Window == 1, absorb(issueID##qdate) cluster(issuerID)
estimates store t4_entry_full

reghdfe entry ib(1).window##ib(1).PassiveInvestor ///
    if Clean_Window == 1 & bond_balanced == 1, ///
    absorb(issueID##qdate) cluster(issuerID)
estimates store t4_entry_bal

reghdfe exit ib(1).window##ib(1).PassiveInvestor ///
    if Clean_Window == 1, absorb(issueID##qdate) cluster(issuerID)
estimates store t4_exit_full

reghdfe exit ib(1).window##ib(1).PassiveInvestor ///
    if Clean_Window == 1 & bond_balanced == 1, ///
    absorb(issueID##qdate) cluster(issuerID)
estimates store t4_exit_bal

{
local models    "t4_entry_full t4_entry_bal t4_exit_full t4_exit_bal"
local samples   `" "Full" "Bal." "Full" "Bal." "'
local n_models  = 4

local windows   "2 3 4 5"
local win_labs  `" "Pre_1Y x Life Insurer" "Downgrade x Life Insurer" "Post_1Y x Life Insurer" "Post_2Y x Life Insurer" "'
local n_wins    = 4

local total_rows = 2 + 2*`n_wins' + 5
local total_cols = `n_models' + 1

putdocx clear
putdocx begin

putdocx paragraph, halign(center)
putdocx text ("TABLE 4."), bold
putdocx paragraph, halign(center)
putdocx text ("Life Insurer Extensive Margin around Credit Rating Downgrades."), bold

putdocx paragraph, halign(both)
putdocx text ("This table reports linear-probability-model coefficient estimates from panel regressions of quarterly entry and exit indicators on event-window indicators interacted with a Life Insurer indicator. Entry equals one in the first quarter a fund-firm holds the bond; exit equals one in the last quarter a fund-firm holds the bond (set to zero in 2023q4 to avoid right-censoring). The event clock is centered on the first downgrade by any rating agency. Each cell shows the differential probability for Life Insurers relative to Passive Mutual Funds in the column outcome and event window, relative to the Pre_2Y baseline. Sample restricted to Life Insurers and Passive MFs. Columns labelled Full use all bond-fund-firm-quarter observations; columns labelled Bal. further require the bond to be observed in all 17 event-time quarters. All specifications include issue x quarter fixed effects. Standard errors clustered by issuer in parentheses. *, **, and *** denote statistical significance at the 10%, 5%, and 1% levels, respectively.")

putdocx paragraph

putdocx table tbl = (`total_rows', `total_cols'), border(all, nil)

putdocx table tbl(1,1) = (""), bold halign(left)
putdocx table tbl(1,2) = ("Entry"), bold halign(center)
putdocx table tbl(1,4) = ("Exit"),  bold halign(center)
putdocx table tbl(1,4), colspan(2)
putdocx table tbl(1,2), colspan(2)
putdocx table tbl(1,.), border(top, single)

putdocx table tbl(2,1) = ("Event Window"), bold halign(left)
forvalues j = 1/`n_models' {
    local col = `j' + 1
    putdocx table tbl(2,`col') = ("(`j')"), bold halign(right)
}
putdocx table tbl(2,.), border(bottom, single)

local r = 3

forvalues i = 1/`n_wins' {
    local wv   : word `i' of `windows'
    local wlab : word `i' of `win_labs'

    putdocx table tbl(`r',1) = ("`wlab'"), halign(left)
    forvalues j = 1/`n_models' {
        local m   : word `j' of `models'
        local col = `j' + 1
        qui estimates restore `m'
        local b = .
        local se = .
        capture local b  = _b[`wv'.window#2.PassiveInvestor]
        capture local se = _se[`wv'.window#2.PassiveInvestor]
        if missing(`b') {
            putdocx table tbl(`r',`col') = ("--"), halign(right)
        }
        else {
            local p = 2*ttail(e(df_r), abs(`b'/`se'))
            local stars ""
            if `p' < 0.01      local stars "***"
            else if `p' < 0.05 local stars "**"
            else if `p' < 0.10 local stars "*"
            putdocx table tbl(`r',`col') = (string(`b', "%12.4fc") + "`stars'"), halign(right)
        }
    }
    local ++r

    putdocx table tbl(`r',1) = (""), halign(left)
    forvalues j = 1/`n_models' {
        local m   : word `j' of `models'
        local col = `j' + 1
        qui estimates restore `m'
        local se = .
        capture local se = _se[`wv'.window#2.PassiveInvestor]
        if missing(`se') {
            putdocx table tbl(`r',`col') = (""), halign(right)
        }
        else {
            putdocx table tbl(`r',`col') = ("(" + string(`se', "%12.4fc") + ")"), halign(right)
        }
    }
    local ++r
}

local last_coef = `r' - 1
putdocx table tbl(`last_coef',.), border(bottom, single)

putdocx table tbl(`r',1) = ("Issue x Quarter FE"), halign(left)
forvalues j = 1/`n_models' {
    local col = `j' + 1
    putdocx table tbl(`r',`col') = ("Yes"), halign(right)
}
local ++r

putdocx table tbl(`r',1) = ("Sample"), halign(left)
forvalues j = 1/`n_models' {
    local slab : word `j' of `samples'
    local col  = `j' + 1
    putdocx table tbl(`r',`col') = ("`slab'"), halign(right)
}
local ++r

putdocx table tbl(`r',1) = ("Observations"), halign(left)
forvalues j = 1/`n_models' {
    local m   : word `j' of `models'
    local col = `j' + 1
    qui estimates restore `m'
    putdocx table tbl(`r',`col') = ("`: display %12.0fc e(N)'"), halign(right)
}
local ++r

putdocx table tbl(`r',1) = ("R-squared"), halign(left)
forvalues j = 1/`n_models' {
    local m   : word `j' of `models'
    local col = `j' + 1
    qui estimates restore `m'
    putdocx table tbl(`r',`col') = ("`: display %12.3fc e(r2)'"), halign(right)
}
local ++r

putdocx table tbl(`r',1) = ("Clusters (Issuers)"), halign(left)
forvalues j = 1/`n_models' {
    local m   : word `j' of `models'
    local col = `j' + 1
    qui estimates restore `m'
    putdocx table tbl(`r',`col') = ("`: display %12.0fc e(N_clust)'"), halign(right)
}
putdocx table tbl(`r',.), border(bottom, single)

putdocx save "${out}/table4_extensive_LI_vs_PMF.docx", replace
}


********************************************************************
*** TABLE 5 -- First downgrade by agency (S&P / Moody's / Fitch)
********************************************************************

estimates clear

local agencies "DowngradeSPR DowngradeMR DowngradeFR"
local k = 0
foreach a of local agencies {
    local ++k
    use "${data}/_master.dta", clear
    build_event_clock, eventvar("`a'")
    keep if inlist(fundtype_det_num, 1, 5)

    reghdfe delta_holdings ib(1).window##ib(1).PassiveInvestor ///
        if Clean_Window == 1, absorb(issueID##qdate) cluster(issuerID)
    estimates store t5_m`k'
}

{
local models    "t5_m1 t5_m2 t5_m3"
local mod_labs  `" "S&P" "Moody's" "Fitch" "'
local n_models  = 3

local windows   "2 3 4 5"
local win_labs  `" "Pre_1Y x Life Insurer" "Downgrade x Life Insurer" "Post_1Y x Life Insurer" "Post_2Y x Life Insurer" "'
local n_wins    = 4

local total_rows = 2 + 2*`n_wins' + 4
local total_cols = `n_models' + 1

putdocx clear
putdocx begin

putdocx paragraph, halign(center)
putdocx text ("TABLE 5."), bold
putdocx paragraph, halign(center)
putdocx text ("Life Insurer Delta Holdings around First Downgrade, by Rating Agency."), bold

putdocx paragraph, halign(both)
putdocx text ("This table reports coefficient estimates from panel regressions of Delta Holdings (bp of offering amount, winsorized 1/99 by fundtype) on event-window indicators interacted with a Life Insurer indicator. Each column re-defines the event clock around the bond's first downgrade by the column's rating agency. Cells report the Life Insurer differential relative to Passive Mutual Funds in each event window, relative to the Pre_2Y baseline. Sample restricted to Life Insurers and Passive MFs. All specifications include issue x quarter fixed effects. Standard errors clustered by issuer in parentheses. *, **, and *** denote statistical significance at the 10%, 5%, and 1% levels, respectively.")

putdocx paragraph

putdocx table tbl = (`total_rows', `total_cols'), border(all, nil)

putdocx table tbl(1,1) = (""), bold halign(left)
putdocx table tbl(1,2) = ("Delta Holdings (bp)"), bold halign(center)
putdocx table tbl(1,2), colspan(`n_models')
putdocx table tbl(1,.), border(top, single)

putdocx table tbl(2,1) = ("Event Window"), bold halign(left)
forvalues j = 1/`n_models' {
    local mlab : word `j' of `mod_labs'
    local col  = `j' + 1
    putdocx table tbl(2,`col') = ("`mlab'"), bold halign(right)
}
putdocx table tbl(2,.), border(bottom, single)

local r = 3

forvalues i = 1/`n_wins' {
    local wv   : word `i' of `windows'
    local wlab : word `i' of `win_labs'

    putdocx table tbl(`r',1) = ("`wlab'"), halign(left)
    forvalues j = 1/`n_models' {
        local m   : word `j' of `models'
        local col = `j' + 1
        qui estimates restore `m'
        local b = .
        local se = .
        capture local b  = _b[`wv'.window#2.PassiveInvestor]
        capture local se = _se[`wv'.window#2.PassiveInvestor]
        if missing(`b') {
            putdocx table tbl(`r',`col') = ("--"), halign(right)
        }
        else {
            local p = 2*ttail(e(df_r), abs(`b'/`se'))
            local stars ""
            if `p' < 0.01      local stars "***"
            else if `p' < 0.05 local stars "**"
            else if `p' < 0.10 local stars "*"
            putdocx table tbl(`r',`col') = (string(`b', "%12.3fc") + "`stars'"), halign(right)
        }
    }
    local ++r

    putdocx table tbl(`r',1) = (""), halign(left)
    forvalues j = 1/`n_models' {
        local m   : word `j' of `models'
        local col = `j' + 1
        qui estimates restore `m'
        local se = .
        capture local se = _se[`wv'.window#2.PassiveInvestor]
        if missing(`se') {
            putdocx table tbl(`r',`col') = (""), halign(right)
        }
        else {
            putdocx table tbl(`r',`col') = ("(" + string(`se', "%12.3fc") + ")"), halign(right)
        }
    }
    local ++r
}

local last_coef = `r' - 1
putdocx table tbl(`last_coef',.), border(bottom, single)

putdocx table tbl(`r',1) = ("Issue x Quarter FE"), halign(left)
forvalues j = 1/`n_models' {
    local col = `j' + 1
    putdocx table tbl(`r',`col') = ("Yes"), halign(right)
}
local ++r

putdocx table tbl(`r',1) = ("Observations"), halign(left)
forvalues j = 1/`n_models' {
    local m   : word `j' of `models'
    local col = `j' + 1
    qui estimates restore `m'
    putdocx table tbl(`r',`col') = ("`: display %12.0fc e(N)'"), halign(right)
}
local ++r

putdocx table tbl(`r',1) = ("R-squared"), halign(left)
forvalues j = 1/`n_models' {
    local m   : word `j' of `models'
    local col = `j' + 1
    qui estimates restore `m'
    putdocx table tbl(`r',`col') = ("`: display %12.3fc e(r2)'"), halign(right)
}
local ++r

putdocx table tbl(`r',1) = ("Clusters (Issuers)"), halign(left)
forvalues j = 1/`n_models' {
    local m   : word `j' of `models'
    local col = `j' + 1
    qui estimates restore `m'
    putdocx table tbl(`r',`col') = ("`: display %12.0fc e(N_clust)'"), halign(right)
}
putdocx table tbl(`r',.), border(bottom, single)

putdocx save "${out}/table5_byagency_LI_vs_PMF.docx", replace
}


********************************************************************
*** TABLE 6 -- Anticipation: prior outlook deterioration (TRIPLE), Unbal/Bal
********************************************************************

use "${data}/_master.dta", clear
build_event_clock, eventvar("DowngradeAny")

bysort issueID rel_time: gen _tag = (_n == 1)
bysort issueID: egen _nq = total(_tag)
gen byte bond_balanced = (_nq == 17)
drop _tag _nq

keep if inlist(fundtype_det_num, 1, 5)

gen byte LI = (fundtype_det_num == 1)
label variable LI "Life Insurer"

cap confirm variable outlook_deterioration
if _rc {
    di as err "Variable 'outlook_deterioration' not found -- required for Table 6."
    exit 111
}

preserve
    keep if inrange(rel_time, -8, -5)
    bysort issueID: egen prior_outlook = max(outlook_deterioration)
    keep issueID prior_outlook
    duplicates drop
    tempfile pol
    save `pol'
restore
merge m:1 issueID using `pol', keep(master match) nogen
replace prior_outlook = 0 if missing(prior_outlook)
label variable prior_outlook "Prior outlook deterioration in [-8,-4]"

estimates clear

reghdfe delta_holdings ib(1).window##ib(0).LI##ib(0).prior_outlook ///
    if Clean_Window == 1, absorb(issueID##qdate) cluster(issuerID)
estimates store t6_unbal

reghdfe delta_holdings ib(1).window##ib(0).LI##ib(0).prior_outlook ///
    if Clean_Window == 1 & bond_balanced == 1, ///
    absorb(issueID##qdate) cluster(issuerID)
estimates store t6_bal

{
local models     "t6_unbal t6_unbal t6_bal t6_bal"
local coef_kinds "base triple base triple"
local n_models   = 4

local windows   "2 3 4 5"
local win_labs  `" "Pre_1Y x Life Insurer" "Downgrade x Life Insurer" "Post_1Y x Life Insurer" "Post_2Y x Life Insurer" "'
local n_wins    = 4

local total_rows = 2 + 2*`n_wins' + 5
local total_cols = `n_models' + 1

putdocx clear
putdocx begin

putdocx paragraph, halign(center)
putdocx text ("TABLE 5."), bold
putdocx paragraph, halign(center)
putdocx text ("Anticipation Channel -- Prior Outlook Deterioration (Triple Interaction)."), bold

putdocx paragraph, halign(both)
putdocx text ("This table reports coefficient estimates from triple-interaction panel regressions of Delta Holdings (bp of offering amount, winsorized 1/99 by fundtype) on event-window indicators, a Life Insurer indicator, and a bond-level indicator for prior S&P outlook deterioration in event time -8 to -5. The event clock is centered on the first downgrade by any rating agency. Columns labelled LI x Window report the Life Insurer x event-window coefficient for bonds with no prior outlook deterioration. Columns labelled x Prior Outlook report the triple interaction, the additional differential for bonds that had a prior outlook deterioration. Columns 1-2 use the full sample; Columns 3-4 require the bond to be observed in all 17 event-time quarters. Sample restricted to Life Insurers and Passive MFs. All specifications include issue x quarter fixed effects. Standard errors clustered by issuer in parentheses. *, **, and *** denote statistical significance at the 10%, 5%, and 1% levels, respectively.")

putdocx paragraph

putdocx table tbl = (`total_rows', `total_cols'), border(all, nil)

putdocx table tbl(1,1) = (""), bold halign(left)
putdocx table tbl(1,2) = ("Full Sample"),  bold halign(center)
putdocx table tbl(1,4) = ("Balanced Sample"), bold halign(center)
putdocx table tbl(1,4), colspan(2)
putdocx table tbl(1,2), colspan(2)
putdocx table tbl(1,.), border(top, single)

putdocx table tbl(2,1) = ("Event Window"), bold halign(left)
forvalues j = 1/`n_models' {
    local col = `j' + 1
    putdocx table tbl(2,`col') = ("(`j')"), bold halign(right)
}
putdocx table tbl(2,.), border(bottom, single)

local r = 3

forvalues i = 1/`n_wins' {
    local wv   : word `i' of `windows'
    local wlab : word `i' of `win_labs'

    putdocx table tbl(`r',1) = ("`wlab'"), halign(left)
    forvalues j = 1/`n_models' {
        local m    : word `j' of `models'
        local kind : word `j' of `coef_kinds'
        local col  = `j' + 1

        qui estimates restore `m'
        local b  = .
        local se = .
        if "`kind'" == "base" {
            capture local b  = _b[`wv'.window#1.LI]
            capture local se = _se[`wv'.window#1.LI]
        }
        else {
            capture local b  = _b[`wv'.window#1.LI#1.prior_outlook]
            capture local se = _se[`wv'.window#1.LI#1.prior_outlook]
        }

        if missing(`b') {
            putdocx table tbl(`r',`col') = ("--"), halign(right)
        }
        else {
            local p = 2*ttail(e(df_r), abs(`b'/`se'))
            local stars ""
            if `p' < 0.01      local stars "***"
            else if `p' < 0.05 local stars "**"
            else if `p' < 0.10 local stars "*"
            putdocx table tbl(`r',`col') = (string(`b', "%12.3fc") + "`stars'"), halign(right)
        }
    }
    local ++r

    putdocx table tbl(`r',1) = (""), halign(left)
    forvalues j = 1/`n_models' {
        local m    : word `j' of `models'
        local kind : word `j' of `coef_kinds'
        local col  = `j' + 1

        qui estimates restore `m'
        local se = .
        if "`kind'" == "base" {
            capture local se = _se[`wv'.window#1.LI]
        }
        else {
            capture local se = _se[`wv'.window#1.LI#1.prior_outlook]
        }
        if missing(`se') {
            putdocx table tbl(`r',`col') = (""), halign(right)
        }
        else {
            putdocx table tbl(`r',`col') = ("(" + string(`se', "%12.3fc") + ")"), halign(right)
        }
    }
    local ++r
}

local last_coef = `r' - 1
putdocx table tbl(`last_coef',.), border(bottom, single)

putdocx table tbl(`r',1) = ("Coefficient"), halign(left)
local kind_disp `" "LI x Win" "x Prior" "LI x Win" "x Prior" "'
forvalues j = 1/`n_models' {
    local klab : word `j' of `kind_disp'
    local col  = `j' + 1
    putdocx table tbl(`r',`col') = ("`klab'"), halign(right)
}
local ++r

putdocx table tbl(`r',1) = ("Issue x Quarter FE"), halign(left)
forvalues j = 1/`n_models' {
    local col = `j' + 1
    putdocx table tbl(`r',`col') = ("Yes"), halign(right)
}
local ++r

putdocx table tbl(`r',1) = ("Observations"), halign(left)
forvalues j = 1/`n_models' {
    local m   : word `j' of `models'
    local col = `j' + 1
    qui estimates restore `m'
    putdocx table tbl(`r',`col') = ("`: display %12.0fc e(N)'"), halign(right)
}
local ++r

putdocx table tbl(`r',1) = ("R-squared"), halign(left)
forvalues j = 1/`n_models' {
    local m   : word `j' of `models'
    local col = `j' + 1
    qui estimates restore `m'
    putdocx table tbl(`r',`col') = ("`: display %12.3fc e(r2)'"), halign(right)
}
local ++r

putdocx table tbl(`r',1) = ("Clusters (Issuers)"), halign(left)
forvalues j = 1/`n_models' {
    local m   : word `j' of `models'
    local col = `j' + 1
    qui estimates restore `m'
    putdocx table tbl(`r',`col') = ("`: display %12.0fc e(N_clust)'"), halign(right)
}
putdocx table tbl(`r',.), border(bottom, single)

putdocx save "${out}/table6_outlook_triple_unbal_bal.docx", replace
copy "${out}/table6_outlook_triple_unbal_bal.docx" "${paperfigs}/T05_Table5_Outlook Triple.docx", replace   // paper-folder copy
}


********************************************************************
*** TABLE 7 -- CDS coverage (TRIPLE), Unbal/Bal
********************************************************************

use "${data}/_master.dta", clear
build_event_clock, eventvar("DowngradeAny")

gen byte _cds_pre = (!missing(CDS_spread) & inrange(rel_time, -8, -5))
bysort issueID: egen CDS_covered_bond = max(_cds_pre)
drop _cds_pre CDS_data
rename CDS_covered_bond CDS_data


bysort issueID rel_time: gen _tag = (_n == 1)
bysort issueID: egen _nq = total(_tag)
gen byte bond_balanced = (_nq == 17)
drop _tag _nq

keep if inlist(fundtype_det_num, 1, 5)

gen byte LI = (fundtype_det_num == 1)
label variable LI "Life Insurer"

estimates clear

reghdfe delta_holdings ib(1).window##ib(0).LI##ib(0).CDS_data ///
    if Clean_Window == 1, absorb(issueID##qdate) cluster(issuerID)
estimates store t7_unbal

reghdfe delta_holdings ib(1).window##ib(0).LI##ib(0).CDS_data ///
    if Clean_Window == 1 & bond_balanced == 1, ///
    absorb(issuerID##qdate) cluster(issueID)
estimates store t7_bal

{
local models     "t7_unbal t7_unbal t7_bal t7_bal"
local coef_kinds "base triple base triple"
local n_models   = 4

local windows   "2 3 4 5"
local win_labs  `" "Pre_1Y x Life Insurer" "Downgrade x Life Insurer" "Post_1Y x Life Insurer" "Post_2Y x Life Insurer" "'
local n_wins    = 4

local total_rows = 2 + 2*`n_wins' + 5
local total_cols = `n_models' + 1

putdocx clear
putdocx begin

putdocx paragraph, halign(center)
putdocx text ("TABLE 6."), bold
putdocx paragraph, halign(center)
putdocx text ("CDS Coverage Triple Interaction."), bold

putdocx paragraph, halign(both)
putdocx text ("This table reports coefficient estimates from triple-interaction panel regressions of Delta Holdings (bp of offering amount, winsorized 1/99 by fundtype) on event-window indicators, a Life Insurer indicator, and a bond-level indicator for CDS coverage (equal to one if the bond ever has a non-missing CDS spread in the sample). The event clock is centered on the first downgrade by any rating agency. Columns labelled LI x Window report the Life Insurer x event-window coefficient for bonds without CDS coverage. Columns labelled x CDS Coverage report the triple interaction. Columns 1-2 use the full sample; Columns 3-4 require the bond to be observed in all 17 event-time quarters. Sample restricted to Life Insurers and Passive MFs. All specifications include issue x quarter fixed effects. Standard errors clustered by issuer in parentheses. *, **, and *** denote statistical significance at the 10%, 5%, and 1% levels, respectively.")

putdocx paragraph

putdocx table tbl = (`total_rows', `total_cols'), border(all, nil)

putdocx table tbl(1,1) = (""), bold halign(left)
putdocx table tbl(1,2) = ("Full Sample"), bold halign(center)
putdocx table tbl(1,4) = ("Balanced Sample"), bold halign(center)
putdocx table tbl(1,4), colspan(2)
putdocx table tbl(1,2), colspan(2)
putdocx table tbl(1,.), border(top, single)

putdocx table tbl(2,1) = ("Event Window"), bold halign(left)
forvalues j = 1/`n_models' {
    local col = `j' + 1
    putdocx table tbl(2,`col') = ("(`j')"), bold halign(right)
}
putdocx table tbl(2,.), border(bottom, single)

local r = 3

forvalues i = 1/`n_wins' {
    local wv   : word `i' of `windows'
    local wlab : word `i' of `win_labs'

    putdocx table tbl(`r',1) = ("`wlab'"), halign(left)
    forvalues j = 1/`n_models' {
        local m    : word `j' of `models'
        local kind : word `j' of `coef_kinds'
        local col  = `j' + 1

        qui estimates restore `m'
        local b  = .
        local se = .
        if "`kind'" == "base" {
            capture local b  = _b[`wv'.window#1.LI]
            capture local se = _se[`wv'.window#1.LI]
        }
        else {
            capture local b  = _b[`wv'.window#1.LI#1.CDS_data]
            capture local se = _se[`wv'.window#1.LI#1.CDS_data]
        }

        if missing(`b') {
            putdocx table tbl(`r',`col') = ("--"), halign(right)
        }
        else {
            local p = 2*ttail(e(df_r), abs(`b'/`se'))
            local stars ""
            if `p' < 0.01      local stars "***"
            else if `p' < 0.05 local stars "**"
            else if `p' < 0.10 local stars "*"
            putdocx table tbl(`r',`col') = (string(`b', "%12.3fc") + "`stars'"), halign(right)
        }
    }
    local ++r

    putdocx table tbl(`r',1) = (""), halign(left)
    forvalues j = 1/`n_models' {
        local m    : word `j' of `models'
        local kind : word `j' of `coef_kinds'
        local col  = `j' + 1

        qui estimates restore `m'
        local se = .
        if "`kind'" == "base" {
            capture local se = _se[`wv'.window#1.LI]
        }
        else {
            capture local se = _se[`wv'.window#1.LI#1.CDS_data]
        }
        if missing(`se') {
            putdocx table tbl(`r',`col') = (""), halign(right)
        }
        else {
            putdocx table tbl(`r',`col') = ("(" + string(`se', "%12.3fc") + ")"), halign(right)
        }
    }
    local ++r
}

local last_coef = `r' - 1
putdocx table tbl(`last_coef',.), border(bottom, single)

putdocx table tbl(`r',1) = ("Coefficient"), halign(left)
local kind_disp `" "LI x Win" "x CDS" "LI x Win" "x CDS" "'
forvalues j = 1/`n_models' {
    local klab : word `j' of `kind_disp'
    local col  = `j' + 1
    putdocx table tbl(`r',`col') = ("`klab'"), halign(right)
}
local ++r

putdocx table tbl(`r',1) = ("Issue x Quarter FE"), halign(left)
forvalues j = 1/`n_models' {
    local col = `j' + 1
    putdocx table tbl(`r',`col') = ("Yes"), halign(right)
}
local ++r

putdocx table tbl(`r',1) = ("Observations"), halign(left)
forvalues j = 1/`n_models' {
    local m   : word `j' of `models'
    local col = `j' + 1
    qui estimates restore `m'
    putdocx table tbl(`r',`col') = ("`: display %12.0fc e(N)'"), halign(right)
}
local ++r

putdocx table tbl(`r',1) = ("R-squared"), halign(left)
forvalues j = 1/`n_models' {
    local m   : word `j' of `models'
    local col = `j' + 1
    qui estimates restore `m'
    putdocx table tbl(`r',`col') = ("`: display %12.3fc e(r2)'"), halign(right)
}
local ++r

putdocx table tbl(`r',1) = ("Clusters (Issuers)"), halign(left)
forvalues j = 1/`n_models' {
    local m   : word `j' of `models'
    local col = `j' + 1
    qui estimates restore `m'
    putdocx table tbl(`r',`col') = ("`: display %12.0fc e(N_clust)'"), halign(right)
}
putdocx table tbl(`r',.), border(bottom, single)

putdocx save "${out}/table7_cds_triple_unbal_bal.docx", replace
copy "${out}/table7_cds_triple_unbal_bal.docx" "${paperfigs}/T06_Table6_CDS Triple.docx", replace   // paper-folder copy
}



********************************************************************
*** TABLE 8 -- Manager cross-section: External vs Captive (TRIPLE)
***   external_mgr = 1 if firmid == "INM" (the bond is held in an
***   externally-managed LI portfolio).
***   external_mgr is then forced to 0 for all PMF rows so that
***   PMF stays as the LI-vs-PMF baseline and does not enter the
***   captive/external dimension.
***   The triple interaction identifies the differential trading
***   response of externally-managed LI portfolios relative to
***   captive LI portfolios, within the LI vs PMF comparison.
********************************************************************

use "${data}/_master.dta", clear
build_event_clock, eventvar("DowngradeAny")

bysort issueID rel_time: gen _tag = (_n == 1)
bysort issueID: egen _nq = total(_tag)
gen byte bond_balanced = (_nq == 17)
drop _tag _nq

keep if inlist(fundtype_det_num, 1, 5)

gen byte LI = (fundtype_det_num == 1)
label variable LI "Life Insurer"

* External manager flag: built from firm_code == "INM" and forced to 0 on PMF rows
cap confirm string variable firm_code
if _rc {
    di as err "firm_code is not a string variable -- adjust the comparison if it is numeric."
    exit 111
}
gen byte external_mgr = (firm_code == "INM")
replace external_mgr = 0 if fundtype_det_num == 5
label variable external_mgr "Externally-managed LI portfolio (firm_code == INM)"


* Diagnostic: PMF rows should all be zero on this dimension
qui tab external_mgr fundtype_det_num, missing
di as txt "external_mgr by fundtype (PMF column should be all 0):"

estimates clear

reghdfe delta_holdings ib(1).window##ib(0).LI##ib(0).external_mgr ///
    if Clean_Window == 1, absorb(issueID##qdate) cluster(issuerID)
estimates store t8_unbal

reghdfe delta_holdings ib(1).window##ib(0).LI##ib(0).external_mgr ///
    if Clean_Window == 1 & bond_balanced == 1, ///
    absorb(issueID##qdate) cluster(issuerID)
estimates store t8_bal

{
local models     "t8_unbal t8_unbal t8_bal t8_bal"
local coef_kinds "base triple base triple"
local n_models   = 4

local windows   "2 3 4 5"
local win_labs  `" "Pre_1Y x Life Insurer" "Downgrade x Life Insurer" "Post_1Y x Life Insurer" "Post_2Y x Life Insurer" "'
local n_wins    = 4

local total_rows = 2 + 2*`n_wins' + 5
local total_cols = `n_models' + 1

putdocx clear
putdocx begin

putdocx paragraph, halign(center)
putdocx text ("TABLE 8."), bold
putdocx paragraph, halign(center)
putdocx text ("Manager Cross-Section -- External vs Captive Asset Management (Triple Interaction)."), bold

putdocx paragraph, halign(both)
putdocx text ("This table reports coefficient estimates from triple-interaction panel regressions of Delta Holdings (bp of offering amount, winsorized 1/99 by fundtype) on event-window indicators, a Life Insurer indicator, and an indicator for externally-managed Life Insurer portfolios (firmid == INM). The external-manager indicator is set to zero for all Passive Mutual Fund rows so that the captive vs external split applies only within Life Insurers. The event clock is centered on the first downgrade by any rating agency. Columns labelled LI x Window report the Life Insurer differential for captive LI portfolios (firmid != INM). Columns labelled x External report the triple interaction, the additional differential for externally-managed LI portfolios. Columns 1-2 use the full sample; Columns 3-4 require the bond to be observed in all 17 event-time quarters. Sample restricted to Life Insurers and Passive Mutual Funds. All specifications include issue x quarter fixed effects. Standard errors clustered by issuer in parentheses. *, **, and *** denote statistical significance at the 10%, 5%, and 1% levels, respectively.")

putdocx paragraph

putdocx table tbl = (`total_rows', `total_cols'), border(all, nil)

putdocx table tbl(1,1) = (""), bold halign(left)
putdocx table tbl(1,2) = ("Full Sample"), bold halign(center)
putdocx table tbl(1,4) = ("Balanced Sample"), bold halign(center)
putdocx table tbl(1,4), colspan(2)
putdocx table tbl(1,2), colspan(2)
putdocx table tbl(1,.), border(top, single)

putdocx table tbl(2,1) = ("Event Window"), bold halign(left)
forvalues j = 1/`n_models' {
    local col = `j' + 1
    putdocx table tbl(2,`col') = ("(`j')"), bold halign(right)
}
putdocx table tbl(2,.), border(bottom, single)

local r = 3

forvalues i = 1/`n_wins' {
    local wv   : word `i' of `windows'
    local wlab : word `i' of `win_labs'

    putdocx table tbl(`r',1) = ("`wlab'"), halign(left)
    forvalues j = 1/`n_models' {
        local m    : word `j' of `models'
        local kind : word `j' of `coef_kinds'
        local col  = `j' + 1

        qui estimates restore `m'
        local b  = .
        local se = .
        if "`kind'" == "base" {
            capture local b  = _b[`wv'.window#1.LI]
            capture local se = _se[`wv'.window#1.LI]
        }
        else {
            capture local b  = _b[`wv'.window#1.LI#1.external_mgr]
            capture local se = _se[`wv'.window#1.LI#1.external_mgr]
        }

        if missing(`b') {
            putdocx table tbl(`r',`col') = ("--"), halign(right)
        }
        else {
            local p = 2*ttail(e(df_r), abs(`b'/`se'))
            local stars ""
            if `p' < 0.01      local stars "***"
            else if `p' < 0.05 local stars "**"
            else if `p' < 0.10 local stars "*"
            putdocx table tbl(`r',`col') = (string(`b', "%12.3fc") + "`stars'"), halign(right)
        }
    }
    local ++r

    putdocx table tbl(`r',1) = (""), halign(left)
    forvalues j = 1/`n_models' {
        local m    : word `j' of `models'
        local kind : word `j' of `coef_kinds'
        local col  = `j' + 1

        qui estimates restore `m'
        local se = .
        if "`kind'" == "base" {
            capture local se = _se[`wv'.window#1.LI]
        }
        else {
            capture local se = _se[`wv'.window#1.LI#1.external_mgr]
        }
        if missing(`se') {
            putdocx table tbl(`r',`col') = (""), halign(right)
        }
        else {
            putdocx table tbl(`r',`col') = ("(" + string(`se', "%12.3fc") + ")"), halign(right)
        }
    }
    local ++r
}

local last_coef = `r' - 1
putdocx table tbl(`last_coef',.), border(bottom, single)

putdocx table tbl(`r',1) = ("Coefficient"), halign(left)
local kind_disp `" "LI x Win" "x External" "LI x Win" "x External" "'
forvalues j = 1/`n_models' {
    local klab : word `j' of `kind_disp'
    local col  = `j' + 1
    putdocx table tbl(`r',`col') = ("`klab'"), halign(right)
}
local ++r

putdocx table tbl(`r',1) = ("Issue x Quarter FE"), halign(left)
forvalues j = 1/`n_models' {
    local col = `j' + 1
    putdocx table tbl(`r',`col') = ("Yes"), halign(right)
}
local ++r

putdocx table tbl(`r',1) = ("Observations"), halign(left)
forvalues j = 1/`n_models' {
    local m   : word `j' of `models'
    local col = `j' + 1
    qui estimates restore `m'
    putdocx table tbl(`r',`col') = ("`: display %12.0fc e(N)'"), halign(right)
}
local ++r

putdocx table tbl(`r',1) = ("R-squared"), halign(left)
forvalues j = 1/`n_models' {
    local m   : word `j' of `models'
    local col = `j' + 1
    qui estimates restore `m'
    putdocx table tbl(`r',`col') = ("`: display %12.3fc e(r2)'"), halign(right)
}
local ++r

putdocx table tbl(`r',1) = ("Clusters (Issuers)"), halign(left)
forvalues j = 1/`n_models' {
    local m   : word `j' of `models'
    local col = `j' + 1
    qui estimates restore `m'
    putdocx table tbl(`r',`col') = ("`: display %12.0fc e(N_clust)'"), halign(right)
}
putdocx table tbl(`r',.), border(bottom, single)

putdocx save "${out}/table8_external_mgr_triple_unbal_bal.docx", replace
}



********************************************************************
*** FIGURE -- Quarter-by-quarter LI vs PMF differential coefficient
***  Two panels: baseline t = -1 (left) and baseline t = -5 (right)
********************************************************************

use "${data}/_master.dta", clear
build_event_clock, eventvar("DowngradeAny")
keep if inlist(fundtype_det_num, 1, 5)

gen byte LI = (fundtype_det_num == 1)
label variable LI "Life Insurer"

* rel_time runs -8..+8 (17 levels). Shift to positive integers for ib().
gen rel_time_shifted = rel_time + 9   // -8 -> 1, -1 -> 8, 0 -> 9, +8 -> 17

estimates clear

* ---- Spec with t = -1 (rel_time_shifted == 8) as baseline ----
reghdfe delta_holdings ib(8).rel_time_shifted##ib(0).LI ///
    if Clean_Window == 1, absorb(issueID##qdate) cluster(issuerID)
estimates store es_baseline_m1

* ---- Spec with t = -5 (rel_time_shifted == 4) as baseline ----
reghdfe delta_holdings ib(4).rel_time_shifted##ib(0).LI ///
    if Clean_Window == 1, absorb(issueID##qdate) cluster(issuerID)
estimates store es_baseline_m5

* Shared coef label dictionary (positions 1..17 map to event times -8..+8)
local coeflabs ///
    1 = "-8" 2 = "-7" 3 = "-6" 4 = "-5" 5 = "-4" 6 = "-3" 7 = "-2" 8 = "-1" ///
    9 = "0"  10 = "1" 11 = "2" 12 = "3" 13 = "4" 14 = "5" 15 = "6" 16 = "7" 17 = "8"

coefplot es_baseline_m1, ///
    keep(*.rel_time_shifted#1.LI) ///
    rename(^([0-9]+)\.rel_time_shifted#1\.LI$ = \1, regex) ///
    vertical recast(connected) ciopts(recast(rcap) lcolor(black%60)) ///
    mcolor(black) lcolor(black) msymbol(circle) lwidth(medthick) ///
    coeflabels(`coeflabs', labsize(vsmall)) ///
    yline(0, lpattern(dash) lcolor(gs8)) ///
    xline(8, lpattern(dash) lcolor(red%50)) ///
    ytitle("LI x Event Time coefficient (bp)", size(small)) ///
    xtitle("Event Time (quarters)", size(small)) ///
    title("Baseline: t = -1", size(medium)) ///
    legend(off) ///
    graphregion(color(white)) bgcolor(white) ///
    plotregion(margin(small) lcolor(gs10)) ///
    name(es_m1, replace)

coefplot es_baseline_m5, ///
    keep(*.rel_time_shifted#1.LI) ///
    rename(^([0-9]+)\.rel_time_shifted#1\.LI$ = \1, regex) ///
    vertical recast(connected) ciopts(recast(rcap) lcolor(black%60)) ///
    mcolor(black) lcolor(black) msymbol(circle) lwidth(medthick) ///
    coeflabels(`coeflabs', labsize(vsmall)) ///
    yline(0, lpattern(dash) lcolor(gs8)) ///
    xline(4, lpattern(dash) lcolor(red%50)) ///
    ytitle("LI x Event Time coefficient (bp)", size(small)) ///
    xtitle("Event Time (quarters)", size(small)) ///
    title("Baseline: t = -5", size(medium)) ///
    legend(off) ///
    graphregion(color(white)) bgcolor(white) ///
    plotregion(margin(small) lcolor(gs10)) ///
    name(es_m5, replace)

graph combine es_m1 es_m5, rows(1) ///
    graphregion(color(white)) name(es_combined, replace)
graph export "${out}/FigureES_LI_quarter_by_quarter.png", replace width(2400)

graph display



********************************************************************
*** TABLE 7 -- Trading flows around downgrades: Life Insurers vs Passive MFs
***   Outcomes: net_change_bp (Net Change), gross_sells_bp (Gross Sells),
***   gross_buys_bp (Gross Buys). ib(1).window##ib(1).PassiveInvestor on the
***   {Life Insurer, Passive MF} sample; reports the Life Insurer x window
***   interaction (#2.PassiveInvestor), Passive MF = omitted, Pre_2Y = omitted
***   window. Unbalanced (Clean_Window) and Balanced (all 17 quarters) per outcome.
********************************************************************

use "${data}/_master.dta", clear
build_event_clock, eventvar("DowngradeAny")

bysort issueID rel_time: gen _tag = (_n == 1)
bysort issueID: egen _nq = total(_tag)
gen byte bond_balanced = (_nq == 17)
drop _tag _nq

keep if inlist(fundtype_det_num, 1, 5)

estimates clear

foreach pair in "net_change_bp nc" "gross_sells_bp gs" "gross_buys_bp gb" {
    local y   : word 1 of `pair'
    local tag : word 2 of `pair'
    reghdfe `y' ib(1).window##ib(1).PassiveInvestor ///
        if Clean_Window == 1, absorb(issueID##qdate) cluster(issuerID)
    estimates store t7_`tag'_unbal
    reghdfe `y' ib(1).window##ib(1).PassiveInvestor ///
        if Clean_Window == 1 & bond_balanced == 1, ///
        absorb(issueID##qdate) cluster(issuerID)
    estimates store t7_`tag'_bal
}

{
local models   "t7_nc_unbal t7_nc_bal t7_gs_unbal t7_gs_bal t7_gb_unbal t7_gb_bal"
local samples  `" "Unbal." "Bal." "Unbal." "Bal." "Unbal." "Bal." "'
local n_models = 6

local windows  "2 3 4 5"
local win_labs `" "Pre_1Y x LI" "Downgrade x LI" "Post_1Y x LI" "Post_2Y x LI" "'
local n_wins   = 4

local total_rows = 3 + 2*`n_wins' + 4
local total_cols = `n_models' + 1

putdocx clear
putdocx begin

putdocx paragraph, halign(center)
putdocx text ("TABLE 7"), bold
putdocx paragraph, halign(center)
putdocx text ("Trading Flows Around Downgrades -- Life Insurers vs Passive MFs."), bold

putdocx paragraph, halign(both)
putdocx text ("This table reports event-window coefficients of three flow outcomes -- Net Change, Gross Sells, and Gross Buys, all in basis points of offering amount -- on the interaction of event-window indicators with a Life Insurer dummy. Flows are defined over the full bond-fund-quarter panel. For each outcome, columns report the regression on the unbalanced sample (Clean Window equal to 1) and on the balanced sample (bonds observed in all 17 event-time quarters). The omitted reference group is Passive Mutual Funds and the omitted window is Pre_2Y (relative time -8 to -5). Pre_1Y covers relative time -4 to -1, Downgrade is relative time 0, Post_1Y covers 1 to 4, and Post_2Y covers 5 to 8. Fixed effects are issue-by-quarter. Standard errors clustered by issuer in parentheses. *, **, and *** denote statistical significance at the 10%, 5%, and 1% levels, respectively.")

putdocx paragraph

putdocx table tbl = (`total_rows', `total_cols'), border(all, nil)

* Row 1 -- outcome group headers (each spanning its Unbal./Bal. pair)
putdocx table tbl(1,1) = (""), bold halign(left)
putdocx table tbl(1,2) = ("Net Change"),  bold halign(center)
putdocx table tbl(1,4) = ("Gross Sells"), bold halign(center)
putdocx table tbl(1,6) = ("Gross Buys"),  bold halign(center)
putdocx table tbl(1,6), colspan(2)
putdocx table tbl(1,4), colspan(2)
putdocx table tbl(1,2), colspan(2)
putdocx table tbl(1,.), border(top, single)

* Row 2 -- Unbal./Bal. subheaders
putdocx table tbl(2,1) = (""), halign(left)
forvalues j = 1/`n_models' {
    local slab : word `j' of `samples'
    local col  = `j' + 1
    putdocx table tbl(2,`col') = ("`slab'"), bold halign(right)
}

* Row 3 -- column numbers + row-stub header
putdocx table tbl(3,1) = ("Window x Life Insurer"), bold halign(left)
forvalues j = 1/`n_models' {
    local col = `j' + 1
    putdocx table tbl(3,`col') = ("(`j')"), bold halign(right)
}
putdocx table tbl(3,.), border(bottom, single)

local r = 4

forvalues i = 1/`n_wins' {
    local wv   : word `i' of `windows'
    local wlab : word `i' of `win_labs'

    putdocx table tbl(`r',1) = ("`wlab'"), halign(left)
    forvalues j = 1/`n_models' {
        local m   : word `j' of `models'
        local col = `j' + 1
        qui estimates restore `m'
        local b  = .
        local se = .
        capture local b  = _b[`wv'.window#2.PassiveInvestor]
        capture local se = _se[`wv'.window#2.PassiveInvestor]
        if missing(`b') {
            putdocx table tbl(`r',`col') = ("--"), halign(right)
        }
        else {
            local p = 2*ttail(e(df_r), abs(`b'/`se'))
            local stars ""
            if `p' < 0.01      local stars "***"
            else if `p' < 0.05 local stars "**"
            else if `p' < 0.10 local stars "*"
            putdocx table tbl(`r',`col') = (string(`b', "%12.3fc") + "`stars'"), halign(right)
        }
    }
    local ++r

    putdocx table tbl(`r',1) = (""), halign(left)
    forvalues j = 1/`n_models' {
        local m   : word `j' of `models'
        local col = `j' + 1
        qui estimates restore `m'
        local se = .
        capture local se = _se[`wv'.window#2.PassiveInvestor]
        if missing(`se') {
            putdocx table tbl(`r',`col') = (""), halign(right)
        }
        else {
            putdocx table tbl(`r',`col') = ("(" + string(`se', "%12.3fc") + ")"), halign(right)
        }
    }
    local ++r
}

local last_coef = `r' - 1
putdocx table tbl(`last_coef',.), border(bottom, single)

putdocx table tbl(`r',1) = ("Issue x Quarter FE"), halign(left)
forvalues j = 1/`n_models' {
    local col = `j' + 1
    putdocx table tbl(`r',`col') = ("Yes"), halign(right)
}
local ++r

putdocx table tbl(`r',1) = ("Observations"), halign(left)
forvalues j = 1/`n_models' {
    local m   : word `j' of `models'
    local col = `j' + 1
    qui estimates restore `m'
    putdocx table tbl(`r',`col') = ("`: display %12.0fc e(N)'"), halign(right)
}
local ++r

putdocx table tbl(`r',1) = ("R-squared"), halign(left)
forvalues j = 1/`n_models' {
    local m   : word `j' of `models'
    local col = `j' + 1
    qui estimates restore `m'
    putdocx table tbl(`r',`col') = ("`: display %12.3fc e(r2)'"), halign(right)
}
local ++r

putdocx table tbl(`r',1) = ("Clusters (Issuers)"), halign(left)
forvalues j = 1/`n_models' {
    local m   : word `j' of `models'
    local col = `j' + 1
    qui estimates restore `m'
    putdocx table tbl(`r',`col') = ("`: display %12.0fc e(N_clust)'"), halign(right)
}
putdocx table tbl(`r',.), border(bottom, single)

putdocx save "${out}/table7_tradingflows_LI_vs_PMF.docx", replace
copy "${out}/table7_tradingflows_LI_vs_PMF.docx" "${paperfigs}/T07_Table7_Trading Flows Around Downgrades.docx", replace   // paper-folder copy
}


********************************************************************
*** End
********************************************************************
