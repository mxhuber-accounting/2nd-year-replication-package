********************************************************************************
*** UNIFIED MERGENT FISD QUARTERLY RATING PANEL  (final)
********************************************************************************

global root "${REPL}/Data/MergentFISD/Raw Data"
global wf   "${REPL}/Data/MergentFISD"
cap mkdir "${wf}"

*** Convert CSV Files
import delimited "${root}/MergentIssues_2012-2023.csv", clear stringcols(_all)
save "${root}/MergentIssues_2012-2023.dta", replace
import delimited "${root}/MergentRatings_2012-2023.csv", clear stringcols(_all)
save "${root}/MergentRatings_2012-2023.dta", replace


* PROGRAM to process both files separately
********************************************************************************
{
capture program drop process_fisd
program define process_fisd
    args sample_tag horizon_q

    
    *** ISSUES Files
	
    use "${root}/MergentIssues_`sample_tag'.dta", clear

    capture confirm variable issuecus
    if _rc {
        capture confirm variable complete_cusip
        if !_rc gen issuecus = substr(complete_cusip, 1, 8)
        else {
            gen issuecus = issuer_cusip + issue_cusip
            replace issuecus = substr(issuecus, 1, 8)
        }
    }
    
    duplicates drop issuecus, force

    capture confirm string variable offering_date
    if !_rc gen Off_Date = date(offering_date, "YMD")
    else    gen Off_Date = offering_date
    capture confirm string variable maturity
    if !_rc gen Mat_Date = date(maturity, "YMD")
    else    gen Mat_Date = maturity
    format Off_Date Mat_Date %td
    
    qui count if missing(Off_Date)
    di as text "  Bonds with unparseable offering_date: " r(N)
    qui count if missing(Mat_Date)
    di as text "  Bonds with unparseable maturity:      " r(N)
    
    gen qoffering = qofd(Off_Date)
    gen qmat      = qofd(Mat_Date)
    format qoffering qmat %tq

    destring offering_amt, replace force
    drop if missing(qoffering)

    *** Bond characteristics carried into the panel (issue-level, constant within
    *** issuecus). Needed by Sample_Creation for the bond_type / convertible /
    *** preferred restrictions and for Off_Date / Mat_Date. Merged back before save.
    preserve
        capture confirm variable parent_id
        if !_rc destring parent_id, replace force
        local charvars issuecus Off_Date Mat_Date
        foreach c in parent_id bond_type convertible preferred_security ///
                     preferred_stock_issuance private_placement {
            capture confirm variable `c'
            if !_rc local charvars `charvars' `c'
        }
        keep `charvars'
        bysort issuecus: keep if _n == 1
        tempfile issues_chars
        save `issues_chars'
    restore

    keep issuecus issuer_cusip qoffering qmat offering_amt
    rename issuer_cusip issuercus
    tempfile issues_clean
    save `issues_clean'

    *** RATINGS Files
	 
    use "${root}/MergentRatings_`sample_tag'.dta", clear

    capture confirm variable issuecus
    if _rc gen issuecus = substr(complete_cusip, 1, 8)
    capture confirm variable reason
    if !_rc drop if reason == "MA" | reason == "MC"
    capture confirm variable rating_type
    if !_rc drop if rating_type == "DPR"

    capture confirm variable rating_date
    if _rc {
        di as error "rating_date not found in `sample_tag' ratings"
        exit 111
    }
    capture confirm string variable rating_date
    if !_rc gen Date = date(rating_date, "YMD")
    else    gen Date = rating_date
    format Date %td
    gen qdate = qofd(Date)
    format qdate %tq

    merge m:1 issuecus using `issues_clean', keep(match) nogen

    duplicates drop issuecus Date rating_type rating, force
    bysort issuecus Date rating_type (rating): keep if _n == _N

    *** Reshape Wide, Construct Numeric Ratings
	 
    keep issuecus issuercus qoffering qmat offering_amt Date qdate rating_type rating
    reshape wide rating, i(issuecus Date) j(rating_type) string

    * S&P
    gen SPR_num = .
    replace SPR_num = 1  if ratingSPR == "AAA"
    replace SPR_num = 2  if ratingSPR == "AA+"
    replace SPR_num = 3  if ratingSPR == "AA"
    replace SPR_num = 4  if ratingSPR == "AA-"
    replace SPR_num = 5  if ratingSPR == "A+"
    replace SPR_num = 6  if ratingSPR == "A"
    replace SPR_num = 7  if ratingSPR == "A-"
    replace SPR_num = 8  if ratingSPR == "BBB+"
    replace SPR_num = 9  if ratingSPR == "BBB"
    replace SPR_num = 10 if ratingSPR == "BBB-"
    replace SPR_num = 11 if ratingSPR == "BB+"
    replace SPR_num = 12 if ratingSPR == "BB"
    replace SPR_num = 13 if ratingSPR == "BB-"
    replace SPR_num = 14 if ratingSPR == "B+"
    replace SPR_num = 15 if ratingSPR == "B"
    replace SPR_num = 16 if ratingSPR == "B-"
    replace SPR_num = 17 if ratingSPR == "CCC+"
    replace SPR_num = 18 if ratingSPR == "CCC"
    replace SPR_num = 19 if ratingSPR == "CCC-"
    replace SPR_num = 20 if ratingSPR == "CC"
    replace SPR_num = 21 if ratingSPR == "C"
    replace SPR_num = 22 if inlist(ratingSPR, "D", "SD")

    * Moody's
    gen MR_num = .
    replace MR_num = 1  if ratingMR == "Aaa"
    replace MR_num = 2  if ratingMR == "Aa1"
    replace MR_num = 3  if ratingMR == "Aa2"
    replace MR_num = 4  if ratingMR == "Aa3"
    replace MR_num = 5  if ratingMR == "A1"
    replace MR_num = 6  if ratingMR == "A2"
    replace MR_num = 7  if ratingMR == "A3"
    replace MR_num = 8  if ratingMR == "Baa1"
    replace MR_num = 9  if ratingMR == "Baa2"
    replace MR_num = 10 if ratingMR == "Baa3"
    replace MR_num = 11 if ratingMR == "Ba1"
    replace MR_num = 12 if ratingMR == "Ba2"
    replace MR_num = 13 if ratingMR == "Ba3"
    replace MR_num = 14 if ratingMR == "B1"
    replace MR_num = 15 if ratingMR == "B2"
    replace MR_num = 16 if ratingMR == "B3"
    replace MR_num = 17 if ratingMR == "Caa1"
    replace MR_num = 18 if ratingMR == "Caa2"
    replace MR_num = 19 if ratingMR == "Caa3"
    replace MR_num = 20 if ratingMR == "Ca"
    replace MR_num = 21 if ratingMR == "C"

    * Fitch
    gen FR_num = .
    replace FR_num = 1  if ratingFR == "AAA"
    replace FR_num = 2  if ratingFR == "AA+"
    replace FR_num = 3  if ratingFR == "AA"
    replace FR_num = 4  if ratingFR == "AA-"
    replace FR_num = 5  if ratingFR == "A+"
    replace FR_num = 6  if ratingFR == "A"
    replace FR_num = 7  if ratingFR == "A-"
    replace FR_num = 8  if ratingFR == "BBB+"
    replace FR_num = 9  if ratingFR == "BBB"
    replace FR_num = 10 if ratingFR == "BBB-"
    replace FR_num = 11 if ratingFR == "BB+"
    replace FR_num = 12 if ratingFR == "BB"
    replace FR_num = 13 if ratingFR == "BB-"
    replace FR_num = 14 if ratingFR == "B+"
    replace FR_num = 15 if ratingFR == "B"
    replace FR_num = 16 if ratingFR == "B-"
    replace FR_num = 17 if ratingFR == "CCC+"
    replace FR_num = 18 if ratingFR == "CCC"
    replace FR_num = 19 if ratingFR == "CCC-"
    replace FR_num = 20 if ratingFR == "CC"
    replace FR_num = 21 if ratingFR == "C"
    replace FR_num = 22 if inlist(ratingFR, "D", "DD", "DDD", "RD")

    label var SPR_num "Numerical S&P Rating"
    label var MR_num  "Numerical Moody's Rating"
    label var FR_num  "Numerical Fitch Rating"

    keep issuercus issuecus Date qdate qoffering qmat offering_amt SPR_num MR_num FR_num
    order issuercus issuecus Date qdate qoffering qmat offering_amt SPR_num MR_num FR_num
    sort issuecus qdate Date
    duplicates drop

    *** Collapse to Quarter-End Rating
	
    foreach v in SPR_num MR_num FR_num {
        bysort issuecus (qdate Date): replace `v' = `v'[_n-1] if missing(`v')
    }
    foreach v in SPR_num MR_num FR_num {
        bysort issuecus qdate (Date): gen `v'_eoq = `v'[_N]
    }
	
    bysort issuecus qdate (Date): keep if _n == _N
    drop SPR_num MR_num FR_num Date
    rename (SPR_num_eoq MR_num_eoq FR_num_eoq) (SPR_num MR_num FR_num)

    *** Expand to Quarterly Panel
	
    local hz = quarterly("`horizon_q'", "YQ")

    drop if qdate > `hz'
    drop if qdate < qoffering   
    gen qend = cond(missing(qmat), `hz', min(qmat, `hz'))

    preserve
        bysort issuecus: keep if _n == 1
        keep issuecus issuercus qoffering qmat qend offering_amt
        gen n_quarters = qend - qoffering + 1
        expand n_quarters
        bysort issuecus: gen qdate = qoffering + _n - 1
        format qdate %tq
        keep issuecus issuercus qoffering qmat offering_amt qdate
        tempfile panel
        save `panel'
    restore

    merge 1:1 issuecus qdate using `panel', nogen update replace

    sort issuecus qdate
    foreach v in SPR_num MR_num FR_num {
        bysort issuecus (qdate): replace `v' = `v'[_n-1] if missing(`v')
    }

    *** Truncate Observations after Defaults without Emergence
	
    gen byte def_q = (SPR_num == 22) | (FR_num == 22)
    bysort issuecus (qdate): gen byte first_def = def_q & (sum(def_q) == 1)
    bysort issuecus (qdate): egen qfirst_def = min(cond(first_def, qdate, .))
    format qfirst_def %tq

    foreach v in SPR_num MR_num FR_num {
        bysort issuecus (qdate): gen byte chg_`v' = (`v' != `v'[_n-1]) & !missing(`v') & !missing(`v'[_n-1]) & _n > 1
    }
    gen byte any_chg = chg_SPR_num | chg_MR_num | chg_FR_num
    bysort issuecus (qdate): egen byte has_post_def_change = max(cond(qdate > qfirst_def & !missing(qfirst_def), any_chg, 0))

    drop if !missing(qfirst_def) & qdate > qfirst_def & has_post_def_change == 0

    drop def_q first_def qfirst_def chg_* any_chg has_post_def_change qend
    gen sample = "`sample_tag'"

    *** Rating Change Indicators (computed within this sample period only)
    sort issuecus qdate
    foreach v in SPR MR FR {
        bysort issuecus (qdate): gen `v'change = `v'_num[_n-1] - `v'_num
        replace `v'change = . if missing(`v'_num) | missing(`v'_num[_n-1])
        label var `v'change "Quarterly `v' rating change (+ = upgrade)"
    }
    foreach v in SPR MR FR {
        replace `v'change = 0 if `v'_num == 22 | `v'_num[_n-1] == 22
    }
    drop if missing(SPR_num) & missing(MR_num) & missing(FR_num)

    *** Attach the issue-level bond characteristics extracted above
    merge m:1 issuecus using `issues_chars', keep(master match) nogen

    compress
    save "${wf}/MergentFISD_QuarterlyPanel_`sample_tag'.dta", replace
end

}


process_fisd "1983-2016" "2016q2"
process_fisd "2012-2023" "2023q4"


* Merge Both Sample Periods
********************************************************************************

use "${wf}/MergentFISD_QuarterlyPanel_1983-2016.dta", clear
append using "${wf}/MergentFISD_QuarterlyPanel_2012-2023.dta"

{
gen byte sample_priority = (sample == "2012-2023")
gen n_nonmiss = !missing(SPR_num) + !missing(MR_num) + !missing(FR_num)

gsort issuecus qdate n_nonmiss sample_priority

bysort issuecus qdate: replace SPR_num      = SPR_num[_n-1]      if missing(SPR_num)
bysort issuecus qdate: replace MR_num       = MR_num[_n-1]       if missing(MR_num)
bysort issuecus qdate: replace FR_num       = FR_num[_n-1]       if missing(FR_num)
bysort issuecus qdate: replace issuercus    = issuercus[_n-1]    if missing(issuercus)
bysort issuecus qdate: replace qoffering    = qoffering[_n-1]    if missing(qoffering)
bysort issuecus qdate: replace qmat         = qmat[_n-1]         if missing(qmat)
bysort issuecus qdate: replace offering_amt = offering_amt[_n-1] if missing(offering_amt)

bysort issuecus qdate: keep if _n == _N
drop n_nonmiss sample sample_priority

* Create Rating Change Indicators
********************************************************************************
sort issuecus qdate
cap drop SPRchange MRchange FRchange

foreach v in SPR MR FR {
    bysort issuecus (qdate): gen `v'change = `v'_num[_n-1] - `v'_num
    

    replace `v'change = . if missing(`v'_num) | missing(`v'_num[_n-1])
    
    label var `v'change "Quarterly `v' rating change (+ = upgrade)"
	}

// Excluding Direct S&P Default 

foreach v in SPR MR FR {
replace `v'change = 0 if `v'_num == 22 | `v'_num[_n-1] == 22
}

sum SPRchange MRchange FRchange, detail
tab SPRchange MRchange if !missing(SPRchange) & !missing(MRchange) & (SPRchange != 0 | MRchange != 0)

drop if qdate < tq(2000q1)                                       // Bonds outside sample period
drop if missing(SPR_num) & missing(MR_num) & missing(FR_num)     // Pre-first-rating quarters

sort issuecus qdate
compress

}

save "${wf}/MergentFISD_QuarterlyPanel_Combined.dta", replace




*** DIAGNOSTIC
********************************************************************************

use "${wf}/MergentFISD_QuarterlyPanel_Combined.dta", clear
{
isid issuecus qdate
di as text _n ">>> Quarter range"
sum qdate, format

di as text _n ">>> Coverage"
di as text "  Total bond-quarters: " _N
preserve
    bysort issuecus: keep if _n == 1
    di as text "  Unique bonds: " _N
restore
foreach v in SPR_num MR_num FR_num {
    qui count if !missing(`v')
    di as text "  `v' coverage: " r(N) " (" %4.1f 100*r(N)/_N "%)"
}

qui count if missing(SPR_num) & missing(MR_num) & missing(FR_num)
di as text _n ">>> Bond-quarters missing all three ratings: " r(N) " (should be 0)"

qui count if missing(qmat)
di as text ">>> Bond-quarters with missing qmat: " r(N)

preserve
    bysort issuecus (qdate): keep if _n == 1
    qui count if qdate < qoffering
    di as text ">>> Bonds whose panel starts before qoffering: " r(N) " (should be 0)"
restore

preserve
    bysort issuecus: gen n_q = _N
    bysort issuecus: keep if _n == 1
    sum n_q, detail
restore

preserve
    bysort issuecus: keep if _n == 1
    gen yoff = year(dofq(qoffering))
    gen ymat = year(dofq(qmat))
    di "Bonds offered per year:"
    tab yoff
    di "Bonds maturing per year:"
    tab ymat
restore
}




*** Combined Issue Characteristics File 
********************************************************************************
use "${root}/MergentIssues_1983-2016.dta", clear
{
gen sample = "1983-2016"
append using "${root}/MergentIssues_2012-2023.dta", force
replace sample = "2012-2023" if missing(sample)

capture confirm variable issuecus
if _rc {
    capture confirm variable complete_cusip
    if !_rc gen issuecus = substr(complete_cusip, 1, 8)
    else {
        gen issuecus = issuer_cusip + issue_cusip
        replace issuecus = substr(issuecus, 1, 8)
    }
}

capture confirm string variable offering_date
if !_rc gen Off_Date = date(offering_date, "YMD")
else    gen Off_Date = offering_date
capture confirm string variable maturity
if !_rc gen Mat_Date = date(maturity, "YMD")
else    gen Mat_Date = maturity
format Off_Date Mat_Date %td
gen qoffering = qofd(Off_Date)
gen qmat      = qofd(Mat_Date)
format qoffering qmat %tq

capture confirm variable offering_amt
if !_rc destring offering_amt, replace force

gen byte sample_priority = (sample == "2012-2023")
gsort issuecus -sample_priority
bysort issuecus: keep if _n == 1

drop sample sample_priority
sort issuecus
compress
save "${wf}/MergentFISD_IssuesLookup.dta", replace
}




*** NOTE
********************************************************************************
* This build keeps ALL bonds. Bond-type / convertible / preferred restrictions
* are applied downstream in 0_0_Sample_Creation.do (Step 9), by merging the
* characteristics from MergentFISD_IssuesLookup.dta onto the rating panel.

















