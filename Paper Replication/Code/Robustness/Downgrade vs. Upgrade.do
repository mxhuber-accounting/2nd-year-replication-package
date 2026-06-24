********************************************************************
*** TABLE X -- Bond-Age Robustness: Downgrades vs Upgrades, Side by Side
***   Cols 1-3: Downgrade events (DowngradeAny)
***   Cols 4-6: Upgrade events (UpgradeAny)
***   Within each event type:
***     (a) Baseline:               Issue x Quarter FE, no aging adjustment
***     (b) Linear aging:           Issue x Quarter FE + c.bond_age#i.LI
***     (c) Nonparametric aging:    Issue x Quarter FE + i.bond_age#i.LI
***
***   Two dependent variables, each gets its own table:
***     - delta_holdings  -> Table_bondage_down_vs_up_delta.docx
***     - net_change_bp   -> Table_bondage_down_vs_up_netchg.docx
***
***   Sample restricted to LI and PMF.
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
cap mkdir "${out}"


********************************************************************
*** Helper: run the 3-column block for a given event variable and DV
*** Stores estimates with the given prefix.
********************************************************************

capture program drop run_block
program define run_block
    syntax , eventvar(string) prefix(string) dv(string)

    * Load master, build event clock, prepare sample
    use "${data}/_master.dta", clear

    * Build event clock inline
    cap drop _ev_q rel_time_ev
    preserve
        bysort issueID qdate: keep if _n == 1
        keep issueID qdate `eventvar'
        gen long _ev_q_obs = qdate if `eventvar' == 1
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

    * Event-window dummy (window = 1 omitted for Pre_2Y in regressions)
    cap drop window
    gen byte window = .
    replace  window = 1 if inrange(rel_time_ev, -8, -5)
    replace  window = 2 if inrange(rel_time_ev, -4, -1)
    replace  window = 3 if rel_time_ev == 0
    replace  window = 4 if inrange(rel_time_ev,  1,  4)
    replace  window = 5 if inrange(rel_time_ev,  5,  8)

    * Restrict to LI and PMF, build LI dummy
    keep if inlist(fundtype_det_num, 1, 5)
    cap drop LI
    gen byte LI = (fundtype_det_num == 1)

    * Bond age
    cap drop bond_age
    gen int bond_age = qdate - qoffering

    * Col (a): Baseline, Issue x Quarter FE, no aging adjustment
    reghdfe `dv' ib(1).window##ib(0).LI ///
        if Clean_Window == 1, absorb(issueID##qdate) cluster(issuerID)
    estimates store `prefix'_a

    * Col (b): Issue x Quarter FE + linear c.bond_age#i.LI
    reghdfe `dv' ib(1).window##ib(0).LI c.bond_age#i.LI ///
        if Clean_Window == 1, absorb(issueID##qdate) cluster(issuerID)
    estimates store `prefix'_b

    * Col (c): Issue x Quarter FE + nonparametric i.bond_age#i.LI
    reghdfe `dv' ib(1).window##ib(0).LI ///
        if Clean_Window == 1, absorb(issueID##qdate i.bond_age#i.LI) cluster(issuerID)
    estimates store `prefix'_c
end


********************************************************************
*** Helper: build and save the docx for a given DV / table
********************************************************************

capture program drop build_table
program define build_table
    syntax , dvtitle(string) dvunits(string) tableno(string) outfile(string) ///
             dnprefix(string) upprefix(string)

    local models    "`dnprefix'_a `dnprefix'_b `dnprefix'_c `upprefix'_a `upprefix'_b `upprefix'_c"
    local age_labs  `" "None" "Linear x LI" "Nonparam x LI" "None" "Linear x LI" "Nonparam x LI" "'
    local n_models  = 6

    local windows   "2 3 4 5"
    local win_labs_dn `" "Pre_1Y x LI" "Downgrade x LI" "Post_1Y x LI" "Post_2Y x LI" "'
    local win_labs_up `" "Pre_1Y x LI" "Upgrade x LI"   "Post_1Y x LI" "Post_2Y x LI" "'
    local n_wins    = 4

    local total_rows = 3 + 2*`n_wins' + 4
    local total_cols = `n_models' + 1

    putdocx clear
    putdocx begin, pagesize(A4) landscape margin(all, 0.7in)

    putdocx paragraph, halign(center)
    putdocx text ("TABLE `tableno'."), bold
    putdocx paragraph, halign(center)
    putdocx text ("Bond-Age Robustness: Downgrades vs. Upgrades -- `dvtitle'."), bold

    putdocx paragraph, halign(both)
    putdocx text ("This table reports the Life Insurer differential in `dvtitle' (`dvunits') around credit rating downgrades (columns 1-3) and upgrades (columns 4-6) under progressively stricter controls for bond age. Bond age is defined as the number of quarters since issuance. Within each event-type block, the first column (1, 4) reports the baseline specification with issue-by-quarter fixed effects and no bond-age adjustment. The second column (2, 5) adds a linear bond-age slope interacted with the Life Insurer indicator. The third column (3, 6) replaces the linear interaction with a fully nonparametric bond-age-by-Life-Insurer fixed effect absorbing differential aging at every value of bond age. The event clock is centered on the first event of the indicated type by any rating agency (S&P, Moody's, or Fitch). Sample restricted to Life Insurers and Passive Mutual Funds. Standard errors clustered by issuer in parentheses. *, **, and *** denote statistical significance at the 10%, 5%, and 1% levels, respectively. The Downgrade and Upgrade rows refer to the event quarter itself; row labels are otherwise common across blocks.")

    putdocx paragraph

    putdocx table tbl = (`total_rows', `total_cols'), border(all, nil)

    * Row 1: event-type headers
    putdocx table tbl(1,1) = (""), bold halign(left)
    putdocx table tbl(1,5) = ("Upgrade Events"),   bold halign(center)
    putdocx table tbl(1,5), colspan(3)
    putdocx table tbl(1,2) = ("Downgrade Events"), bold halign(center)
    putdocx table tbl(1,2), colspan(3)
    putdocx table tbl(1,.), border(top, single)

    * Row 2: dependent variable subheader
    putdocx table tbl(2,1) = (""), bold halign(left)
    putdocx table tbl(2,2) = ("`dvtitle' (`dvunits')"), bold halign(center)
    putdocx table tbl(2,2), colspan(`n_models')

    * Row 3: column numbers
    putdocx table tbl(3,1) = ("Event Window"), bold halign(left)
    forvalues j = 1/`n_models' {
        local col = `j' + 1
        putdocx table tbl(3,`col') = ("(`j')"), bold halign(right)
    }
    putdocx table tbl(3,.), border(bottom, single)

    local r = 4

    forvalues i = 1/`n_wins' {
        local wv      : word `i' of `windows'
        local wlab_dn : word `i' of `win_labs_dn'

        if `i' == 2 {
            local row_lab "Event x LI"
        }
        else {
            local row_lab "`wlab_dn'"
        }

        putdocx table tbl(`r',1) = ("`row_lab'"), halign(left)
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

    putdocx table tbl(`r',1) = ("Bond Age Adjustment"), halign(left)
    forvalues j = 1/`n_models' {
        local alab : word `j' of `age_labs'
        local col  = `j' + 1
        putdocx table tbl(`r',`col') = ("`alab'"), halign(right)
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

    putdocx save "${out}/`outfile'", replace
end


********************************************************************
*** Table 1: delta_holdings
********************************************************************

estimates clear

run_block, eventvar("DowngradeAny") prefix("dn_dh") dv("delta_holdings")
run_block, eventvar("UpgradeAny")   prefix("up_dh") dv("delta_holdings")

build_table, ///
    dvtitle("Delta Holdings") ///
    dvunits("bp of offering amount") ///
    tableno("X1") ///
    outfile("Table_bondage_down_vs_up_delta.docx") ///
    dnprefix("dn_dh") ///
    upprefix("up_dh")


********************************************************************
*** Table 2: net_change_bp
********************************************************************

estimates clear

run_block, eventvar("DowngradeAny") prefix("dn_nc") dv("net_change_bp")
run_block, eventvar("UpgradeAny")   prefix("up_nc") dv("net_change_bp")

build_table, ///
    dvtitle("Net Change") ///
    dvunits("bp of offering amount") ///
    tableno("X2") ///
    outfile("Table_bondage_down_vs_up_netchg.docx") ///
    dnprefix("dn_nc") ///
    upprefix("up_nc")
