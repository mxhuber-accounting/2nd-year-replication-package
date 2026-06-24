********************************************************************************
*** Builds Data/CapitalIQ/CapitalIQ_Final.dta from raw inputs in Raw Data/:
***   - KeyDevelopment Screening Report-*.xls  (S&P CapitalIQ rating events)
***   - CIQ-CUSIP.csv                          (WRDS CapitalIQ->CUSIP/GVKEY crosswalk)
*** Produces the outlook/watch panel consumed by 0_0_Sample_Creation.do (Step 4).
*** Output is written to THIS folder (Data/CapitalIQ/), NOT the Data/ root copy.
********************************************************************************

********************************************************************************
*** CapitalIQ Issuer Ratings, Watch and Outlook Data
********************************************************************************


*** Test Processing
********************************************************************************

local file "${REPL}/Data/CapitalIQ/Raw Data/KeyDevelopment Screening Report-11.xls"

import excel "`file'", clear

{
	
foreach v of varlist _all {
    local newname = `v'[3]              
    local clean = strtoname("`newname'") 
    
    if "`newname'" != "" {
        rename `v' `clean'
    }
}
drop in 1/3

gen Date = date(Key_Developments_By_Date, "DMY")
format Date %td
drop Key_Developments_By_Date Key_Development_Sources
gen Type = substr(Key_Developments_by_Type, 22,.)
drop Key_Developments_by_Type
gen CIQ = substr(Excel_Company_ID, 3,.)
drop Excel_Company_ID
gen Headline = substr(Key_Development_Headline,23, . )
drop Key_Development_Situation Key_Development_Headline
order Date CIQ Type Headline
drop if strpos(Headline, "Foreign") > 0
replace Headline = subinstr(Headline, ": Local Currency Rating", "", .)
gen curr_full = ustrregexra(Headline, "(?i) from .*", "")
gen prev_full = ""
replace prev_full = ustrregexs(1) if ustrregexm(Headline, "(?i) from (.+)")
replace curr_full = subinstr(curr_full, "; ", "/", .)
replace prev_full = subinstr(prev_full, "; ", "/", .)
order Date CIQ Type Headline curr_full prev_full
gen curr_rating = ustrregexs(1) if ustrregexm(curr_full, "^([^/ ]+)")
gen prev_rating = ustrregexs(1) if ustrregexm(prev_full, "^([^/ ]+)")
gen curr_status = ustrregexs(1) if ustrregexm(curr_full, "/([^/]+)")
gen prev_status = ustrregexs(1) if ustrregexm(prev_full, "/([^/]+)")
replace curr_status = ustrregexra(curr_status, "/.*", "")
replace prev_status = ustrregexra(prev_status, "/.*", "")

foreach s in curr_status prev_status {
    replace `s' = ustrregexra(`s', ":.*", "")
}
levelsof prev_status

order Date CIQ Type Headline curr_full prev_full curr_rating prev_rating curr_status prev_status

foreach time in curr prev {
    gen `time'_outlook = ""
    gen `time'_watch = ""
}

foreach time in curr prev {
    replace `time'_watch = "Neg" if strpos(`time'_status, "Watch Neg") > 0
    replace `time'_watch = "Pos" if strpos(`time'_status, "Watch Pos") > 0
    replace `time'_watch = "Dev" if strpos(`time'_status, "Watch Dev") > 0
}


foreach time in curr prev {
    if `time'_watch == "" {
        replace `time'_outlook = "Negative"   if strpos(`time'_status, "Negative") > 0
        replace `time'_outlook = "Positive"   if strpos(`time'_status, "Positive") > 0
        replace `time'_outlook = "Stable"     if strpos(`time'_status, "Stable") > 0
        replace `time'_outlook = "Developing" if strpos(`time'_status, "Developing") > 0
    }
}

order Date CIQ Type Headline curr_rating prev_rating curr_outlook prev_outlook curr_watch prev_watch

gen rating_action = ""
replace rating_action = "Upgrade"   if strpos(lower(Type), "upgrade") > 0
replace rating_action = "Downgrade" if strpos(lower(Type), "downgrade") > 0
replace rating_action = "New"       if strpos(lower(Type), "new rating") > 0
replace rating_action = "NR"        if strpos(lower(Type), "not-rated") > 0

gen status_change = 0
replace status_change = 1 if strpos(lower(Type), "creditwatch") > 0 | strpos(lower(Type), "outlook") > 0

replace rating_action = "Mixed/Multiple" if strpos(lower(Type), "upgrade") > 0 & strpos(lower(Type), "downgrade") > 0

order Date CIQ Type Headline rating_action status_change curr_rating prev_rating curr_outlook prev_outlook curr_watch prev_watch

keep Date CIQ Company_Name_s_ rating_action status_change curr_rating prev_rating curr_outlook prev_outlook curr_watch prev_watch  CIK Security_Tickers
order Date CIQ Company_Name_s_ rating_action status_change curr_rating prev_rating curr_outlook prev_outlook curr_watch prev_watch  CIK Security_Tickers
sort Date CIQ Company_Name_s_ rating_action status_change curr_rating prev_rating curr_outlook prev_outlook curr_watch prev_watch  CIK Security_Tickers
drop if missing(Date)
compress
}


*** Loop to Process all Excel Files
********************************************************************************

clear
set more off

local raw_dir "${REPL}/Data/CapitalIQ/Raw Data"
local out_dir "${REPL}/Data/CapitalIQ"

cd "`raw_dir'"
local files : dir . files "*.xls"

{
tempfile master
save `master', emptyok replace

foreach f in `files' {
    display "Processing: `f'"
    
    import excel "`f'", clear

    foreach v of varlist _all {
        local newname = `v'[3]
        local clean = strtoname("`newname'")
        if "`newname'" != "" {
            capture rename `v' `clean' 
        }
    }
    drop in 1/3

    gen Date = date(Key_Developments_By_Date, "DMY")
    format Date %td
  
    capture gen Type = substr(Key_Developments_by_Type, 22,.)
    capture gen CIQ = substr(Excel_Company_ID, 3,.)
    capture gen Headline = substr(Key_Development_Headline,23, . )
    
    drop if strpos(Headline, "Foreign") > 0
    replace Headline = subinstr(Headline, ": Local Currency Rating", "", .)

    gen curr_full = ustrregexra(Headline, "(?i) from .*", "")
    gen prev_full = ""
    replace prev_full = ustrregexs(1) if ustrregexm(Headline, "(?i) from (.+)")

    replace curr_full = subinstr(curr_full, "; ", "/", .)
    replace prev_full = subinstr(prev_full, "; ", "/", .)

    gen curr_rating = ustrregexs(1) if ustrregexm(curr_full, "^([^/ ;]+)")
    gen prev_rating = ustrregexs(1) if ustrregexm(prev_full, "^([^/ ;]+)")
    gen curr_status = ustrregexs(1) if ustrregexm(curr_full, "/([^/]+)")
    gen prev_status = ustrregexs(1) if ustrregexm(prev_full, "/([^/]+)")
    
    replace curr_status = ustrregexra(curr_status, "/.*", "")
    replace prev_status = ustrregexra(prev_status, "/.*", "")

    foreach s in curr_status prev_status {
        replace `s' = ustrregexra(`s', ":.*", "")
    }

    foreach time in curr prev {
        gen `time'_outlook = ""
        gen `time'_watch = ""
        
        replace `time'_watch = "Neg" if strpos(`time'_status, "Watch Neg") > 0
        replace `time'_watch = "Pos" if strpos(`time'_status, "Watch Pos") > 0
        replace `time'_watch = "Dev" if strpos(`time'_status, "Watch Dev") > 0
        
        replace `time'_outlook = "Negative"   if strpos(`time'_status, "Negative") > 0 & `time'_watch == ""
        replace `time'_outlook = "Positive"   if strpos(`time'_status, "Positive") > 0 & `time'_watch == ""
        replace `time'_outlook = "Stable"     if strpos(`time'_status, "Stable") > 0   & `time'_watch == ""
        replace `time'_outlook = "Developing" if strpos(`time'_status, "Developing") > 0 & `time'_watch == ""
    }

    gen rating_action = ""
    replace rating_action = "Upgrade"   if strpos(lower(Type), "upgrade") > 0
    replace rating_action = "Downgrade" if strpos(lower(Type), "downgrade") > 0
    replace rating_action = "New"       if strpos(lower(Type), "new rating") > 0
    replace rating_action = "NR"        if strpos(lower(Type), "not-rated") > 0
    replace rating_action = "Mixed/Multiple" if strpos(lower(Type), "upgrade") > 0 & strpos(lower(Type), "downgrade") > 0

    gen status_change = 0
    replace status_change = 1 if strpos(lower(Type), "creditwatch") > 0 | strpos(lower(Type), "outlook") > 0

    drop if missing(Date)
    keep Date CIQ Company_Name_s_ rating_action status_change curr_rating prev_rating curr_outlook prev_outlook curr_watch prev_watch CIK Security_Tickers
	order Date CIQ Company_Name_s_ rating_action status_change curr_rating prev_rating curr_outlook prev_outlook curr_watch prev_watch CIK Security_Tickers
    sort Date CIQ 
    append using `master'
    save `master', replace
}

compress
local sp_regex "^(AAA|AA\+|AA|AA-|A\+|A|A-|BBB\+|BBB|BBB-|BB\+|BB|BB-|B\+|B|B-|CCC\+|CCC|CCC-|CC|C|D|SD|NR)$"
drop if !ustrregexm(curr_rating, "`sp_regex'") & curr_rating != "" // Drop all non-long-term Local Currency Issuer Ratings
replace prev_rating = "" if prev_rating == "New:"
drop if !ustrregexm(prev_rating, "`sp_regex'") & rating_action != "New" & prev_rating != "" // Drop all non-long-term Local Currency Issuer Ratings

save "`out_dir'/CapitalIQ_KeyDev.dta", replace
}

local out_dir "${REPL}/Data/CapitalIQ"

use "`out_dir'/CapitalIQ_KeyDev.dta", clear

levelsof curr_rating
drop if missing(CIQ)
preserve
    keep CIQ
    duplicates drop CIQ, force
    drop if CIQ == ""
    
    outsheet CIQ using "`out_dir'/CIQ.txt", noquote nonames replace
restore


*** Merge with WRDS CUSIP and GVKEY Identifiers
********************************************************************************

// CUSIP
{
local out_dir "${REPL}/Data/CapitalIQ"

import delimited "`raw_dir'/CIQ-CUSIP.csv", clear

keep if symboltypecat == "cusip"
gen s_date = daily(startdate, "YMD")
gen e_date = daily(enddate, "YMD")
format s_date e_date %td
drop startdate enddate
replace e_date = td(31dec2023) if missing(e_date)

gen issuercus = substr(symbolvalue, 1, 6)
order issuercus
drop symboltypecat symbolid symboltypename symboltypeid symbolvalue

bysort issuercus: egen start = min(s_date)
bysort issuercus: egen end = max(e_date)
drop s_date e_date
duplicates drop issuercus, force
format start end %td

rename companyid CIQ
tostring CIQ, replace
save "`out_dir'/CIQ-CUSIP-6.dta", replace
}

// GVKEY
{

local out_dir "${REPL}/Data/CapitalIQ"

import delimited "`raw_dir'/CIQ-CUSIP.csv", clear

keep if symboltypecat == "gvkey"
keep if symboltypename == "S&P GVKey"

rename symbolvalue gvkey
order gvkey
drop symboltypecat symbolid symboltypename symboltypeid startdate enddate
duplicates drop companyid gvkey, force
rename companyid CIQ
tostring CIQ, replace
bysort CIQ (gvkey): gen gvkey_num = _n
sum gvkey_num
reshape wide gvkey, i(CIQ companyname) j(gvkey_num)
rename gvkey1 gvkey
duplicates report CIQ
save "`out_dir'/CIQ-GVKEY.dta", replace
}

// Merge

local out_dir "${REPL}/Data/CapitalIQ"
use "`out_dir'/CapitalIQ_KeyDev.dta", clear

{
joinby CIQ using "`out_dir'/CIQ-CUSIP-6.dta", unmatched(master) 
keep if Date >= start & Date <= end

merge n:1 CIQ using "`out_dir'/CIQ-GVKEY.dta", keep(master match) keepusing(gvkey gvkey2 gvkey3) nogen

drop if Date < td(31dec2011)
drop if Date > td(31dec2023)

gen qdate = qofd(Date)
format qdate %tq
order Date qdate

order Date qdate CIQ issuercus rating_action status_change curr_rating prev_rating curr_outlook prev_outlook curr_watch prev_watch Company_Name_s_ companyname
drop Company_Name_s_
compress

save "`out_dir'/CapitalIQ_KeyDev_CUSIP-6.dta", replace


local out_dir "${REPL}/Data/CapitalIQ"

use "`out_dir'/CapitalIQ_KeyDev_CUSIP-6.dta", clear

preserve
    bysort issuercus: keep if _n == 1
    keep issuercus CIQ companyname
    save "`out_dir'/issuercus_list.dta", replace
restore

preserve
    clear
    set obs 48
    gen qdate = yq(2012,1) + _n - 1
    format qdate %tq
    cross using "`out_dir'/issuercus_list.dta"
    gen skeleton = 1
    save "`out_dir'/skeleton.dta", replace
restore
gen skeleton = 0
append using "`out_dir'/skeleton.dta"

bysort issuercus qdate: egen has_event = max(skeleton == 0)
drop if skeleton == 1 & has_event == 1
drop has_event skeleton
sort issuercus qdate

save "`out_dir'/CapitalIQ_KeyDev_panel.dta", replace


local out_dir "${REPL}/Data/CapitalIQ"

use "`out_dir'/CapitalIQ_KeyDev_panel.dta", clear
drop _merge start end
duplicates drop

// Data Fill

gsort issuercus qdate Date
foreach v in curr_rating curr_outlook curr_watch  {
    by issuercus: replace `v' = `v'[_n-1] if missing(`v') | `v' == ""
}

foreach v in CIK gvkey gvkey2 gvkey3 Security_Tickers {
    capture confirm string variable `v'
    if _rc == 0 {
        bysort issuercus (`v'): replace `v' = `v'[_N] if missing(`v') | `v' == ""
    }
    else {
        bysort issuercus (`v'): replace `v' = `v'[_N] if missing(`v')
    }
}
sort issuercus qdate

gsort issuercus Date

by issuercus: gen first_event_idx = sum(!missing(Date)) == 1 & !missing(Date)
by issuercus: gen first_action_is_new = rating_action == "New" if first_event_idx == 1
by issuercus: egen issuer_first_is_new = max(first_action_is_new == 1)
by issuercus: gen tag_r = !missing(prev_rating)  & prev_rating  != "" & !missing(Date) & issuer_first_is_new == 0
by issuercus: gen tag_o = !missing(prev_outlook) & prev_outlook != "" & !missing(Date) & issuer_first_is_new == 0

by issuercus: gen first_r = sum(tag_r) == 1 & tag_r == 1
by issuercus: gen first_o = sum(tag_o) == 1 & tag_o == 1

by issuercus: gen first_prev_rating  = prev_rating  if first_r == 1
by issuercus: gen first_prev_outlook = prev_outlook if first_o == 1

by issuercus: replace first_prev_rating  = first_prev_rating[_n-1]  ///
    if missing(first_prev_rating)  | first_prev_rating  == ""
by issuercus: replace first_prev_outlook = first_prev_outlook[_n-1] ///
    if missing(first_prev_outlook) | first_prev_outlook == ""

gsort issuercus qdate Date

by issuercus: replace curr_rating  = first_prev_rating ///
    if (missing(curr_rating)  | curr_rating  == "") & first_prev_rating  != ""
by issuercus: replace curr_outlook = first_prev_outlook ///
    if (missing(curr_outlook) | curr_outlook == "") & first_prev_outlook != ""

drop tag_r tag_o first_r first_o first_prev_rating first_prev_outlook ///
     first_event_idx first_action_is_new issuer_first_is_new

sort issuercus qdate

drop if missing(curr_rating)

save "`out_dir'/CapitalIQ_Panel.dta", replace

}




*** Generate Rating Action Codes
********************************************************************************

local out_dir "${REPL}/Data/CapitalIQ"
use "`out_dir'/CapitalIQ_Panel.dta", clear

gen CIQ_num = .
replace CIQ_num = 1  if curr_rating == "AAA"
replace CIQ_num = 2  if curr_rating == "AA+"
replace CIQ_num = 3  if curr_rating == "AA"
replace CIQ_num = 4  if curr_rating == "AA-"
replace CIQ_num = 5  if curr_rating == "A+"
replace CIQ_num = 6  if curr_rating == "A"
replace CIQ_num = 7  if curr_rating == "A-"
replace CIQ_num = 8  if curr_rating == "BBB+"
replace CIQ_num = 9  if curr_rating == "BBB"
replace CIQ_num = 10 if curr_rating == "BBB-"
replace CIQ_num = 11 if curr_rating == "BB+"
replace CIQ_num = 12 if curr_rating == "BB"
replace CIQ_num = 13 if curr_rating == "BB-"
replace CIQ_num = 14 if curr_rating == "B+"
replace CIQ_num = 15 if curr_rating == "B"
replace CIQ_num = 16 if curr_rating == "B-"
replace CIQ_num = 17 if curr_rating == "CCC+"
replace CIQ_num = 18 if curr_rating == "CCC"
replace CIQ_num = 19 if curr_rating == "CCC-"
replace CIQ_num = 20 if curr_rating == "CC"
replace CIQ_num = 21 if curr_rating == "C"
replace CIQ_num = 22 if inlist(curr_rating, "D", "SD")

gen outlook_num = .
replace outlook_num = 3 if curr_outlook == "Positive" & !missing(CIQ_num)
replace outlook_num = 2 if curr_outlook == "Stable" & !missing(CIQ_num)
replace outlook_num = 1 if curr_outlook == "Negative" & !missing(CIQ_num)
replace outlook_num = 2 if curr_outlook == "Developing"  & !missing(CIQ_num) 
gen watch_num = .
replace watch_num = 3 if inlist(curr_watch, "Pos", "Positive") & !missing(CIQ_num)
replace watch_num = 2 if inlist(curr_watch, "Dev", "Developing") & !missing(CIQ_num)
replace watch_num = 1 if inlist(curr_watch, "Neg", "Negative")& !missing(CIQ_num)

bysort issuercus qdate: egen n_rating_actions_q = ///
    total(inlist(rating_action, "Upgrade", "Downgrade", "New", "NR"))

gen byte _outlook_action = !missing(Date) & curr_outlook != prev_outlook ///
    & curr_outlook != "" & prev_outlook != "" & !missing(CIQ_num)
bysort issuercus qdate: egen n_outlook_actions_q = total(_outlook_action)
drop _outlook_action

gen byte _watch_action = !missing(Date) & curr_watch != prev_watch & !missing(CIQ_num)
bysort issuercus qdate: egen n_watch_actions_q = total(_watch_action)
drop _watch_action


bysort issuercus qdate (Date): keep if _n == _N

duplicates report issuercus qdate

xtset, clear
sort issuercus qdate

by issuercus: gen CIQ_change = CIQ_num - CIQ_num[_n-1]
gen byte CIQ_downgrade = CIQ_change > 0 & !missing(CIQ_change)
gen byte CIQ_upgrade   = CIQ_change < 0 & !missing(CIQ_change)

by issuercus: gen outlook_change = outlook_num - outlook_num[_n-1]
gen byte outlook_improvement   = outlook_change > 0 & !missing(outlook_change) & !missing(CIQ_num)
gen byte outlook_deterioration = outlook_change < 0 & !missing(outlook_change) & !missing(CIQ_num)

by issuercus: gen watch_change = watch_num - watch_num[_n-1]
gen byte watch_improvement   = watch_change > 0 & !missing(watch_change) & !missing(CIQ_num)
gen byte watch_deterioration = watch_change < 0 & !missing(watch_change) & !missing(CIQ_num)

label variable issuercus     "Capital IQ Issuer CUSIP-6"
label variable CIQ           "Capital IQ Company ID"
label variable companyname   "Capital IQ Company Name"
label variable qdate         "Quarter (Year-Quarter)"
label variable Date          "Capital IQ Latest Event Date in Quarter"
label variable CIK           "Capital IQ Central Index Key (SEC)"
label variable Security_Tickers "Capital IQ Security Tickers"
label variable gvkey         "Capital IQ S&P GVKEY (primary)"
label variable gvkey2        "Capital IQ S&P GVKEY (secondary)"
label variable gvkey3        "Capital IQ S&P GVKEY (tertiary)"

label variable rating_action "Capital IQ S&P Rating Action (Upgrade/Downgrade/New/NR)"
label variable status_change "Capital IQ S&P Status Change Indicator"
label variable curr_rating   "Capital IQ S&P Current Rating (end-of-quarter)"
label variable prev_rating   "Capital IQ S&P Previous Rating (pre-event)"
label variable curr_outlook  "Capital IQ S&P Current Outlook (end-of-quarter)"
label variable prev_outlook  "Capital IQ S&P Previous Outlook (pre-event)"
label variable curr_watch    "Capital IQ S&P Current CreditWatch (end-of-quarter)"
label variable prev_watch    "Capital IQ S&P Previous CreditWatch (pre-event)"

label variable CIQ_num       "Capital IQ S&P Rating (numeric: 1=AAA ... 22=D/SD)"
label variable outlook_num   "Capital IQ S&P Outlook (numeric: 3=Pos, 2=Stable, 1=Neg)"
label variable watch_num     "Capital IQ S&P CreditWatch (numeric: 3=Pos, 2=Dev, 1=Neg)"

label variable n_rating_actions_q  "Capital IQ S&P Rating Actions in Quarter (count)"
label variable n_outlook_actions_q "Capital IQ S&P Outlook Revisions in Quarter (count)"
label variable n_watch_actions_q   "Capital IQ S&P CreditWatch Actions in Quarter (count)"

label variable CIQ_change           "Capital IQ S&P Rating Change (notches; +=downgrade)"
label variable CIQ_downgrade        "Capital IQ S&P Rating Downgrade (binary)"
label variable CIQ_upgrade          "Capital IQ S&P Rating Upgrade (binary)"
label variable outlook_change       "Capital IQ S&P Outlook Change (+=improvement)"
label variable outlook_improvement  "Capital IQ S&P Outlook Improvement (binary)"
label variable outlook_deterioration "Capital IQ S&P Outlook Deterioration (binary)"
label variable watch_change         "Capital IQ S&P CreditWatch Change (+=improvement)"
label variable watch_improvement    "Capital IQ S&P CreditWatch Improvement (binary)"
label variable watch_deterioration  "Capital IQ S&P CreditWatch Deterioration (binary)"

label define rating_lbl ///
    1 "AAA" 2 "AA+" 3 "AA" 4 "AA-" ///
    5 "A+" 6 "A" 7 "A-" ///
    8 "BBB+" 9 "BBB" 10 "BBB-" ///
    11 "BB+" 12 "BB" 13 "BB-" ///
    14 "B+" 15 "B" 16 "B-" ///
    17 "CCC+" 18 "CCC" 19 "CCC-" ///
    20 "CC" 21 "C" 22 "D/SD"
label values CIQ_num rating_lbl

label define outlook_lbl 1 "Negative" 2 "Stable" 3 "Positive"
label values outlook_num outlook_lbl

label define watch_lbl 1 "Negative" 2 "Developing" 3 "Positive"
label values watch_num watch_lbl

save "`out_dir'/CapitalIQ_Final", replace

local out_dir "${REPL}/Data/CapitalIQ"

use "`out_dir'/CapitalIQ_Final", clear


