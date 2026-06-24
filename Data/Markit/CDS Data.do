
******************************************************************************************
*** Quarterly CDS Spreads 2001 - 2020 
******************************************************************************************


* Paths repointed to the package. Raw inputs live in Raw Data/; the loops
* regenerate per-day .dta intermediates (CDSpre2018/, CDSpost2018/) under there too.
* NOTE: full rebuild reads ~5,000 daily CSVs (~55 GB); ~35-50 min (mostly imports).
global cds "${REPL}/Data/Markit/Raw Data"
cap mkdir "${cds}/CDSpre2018"
cap mkdir "${cds}/CDSpost2018"

*** CDS Spreads 2001 - 2018 (Focus on 5-year Spread)

{
// Test
import delimited "${cds}/CDS Composites (all)/V5 CDS Composites-01Apr04.csv",rowrange(2) varnames(2) clear

gen Date = date(date, "DMY", 2050)
format Date %td
drop date
order Date
destring spread5y, replace ignore("%")
replace spread5y = spread5y / 100  
drop if missing(spread5y)

// Remove Duplicates
keep if tier == "SNRFOR"

gen doc_priority = 0
replace doc_priority = 3 if inlist(docclause, "XR14", "XR")
replace doc_priority = 2 if inlist(docclause, "MR14", "MR")
replace doc_priority = 1 if inlist(docclause, "MM", "MM14", "CR", "CR14")
gen is_usd = (ccy == "USD")
gsort ticker Date -is_usd -doc_priority -compositedepth5y
by ticker Date: keep if _n == 1
duplicates report ticker

keep Date ticker shortname spread5y country
rename spread5y CDS_spread

save "${cds}/CDSpre2018/2004-04-01.dta", replace

// Loop
local input_dir "${cds}/CDS Composites (all)"
local output_dir "${cds}/CDSpre2018"

* 2. Get the list of all V5 files
local filelist : dir "`input_dir'" files "*.csv"

foreach file of local filelist {

    di "Processing: `file'"
    import delimited "`input_dir'/`file'", rowrange(2) varnames(2) clear
    if _N > 0 {
        
        gen Date_num = date(date, "DMY", 2050)
        format Date_num %td
       
        local rawdate = string(Date_num[1], "%tdCY-N-D")
        local outname "`rawdate'.dta"
        
        capture destring spread5y, replace ignore("%")
        replace spread5y = spread5y / 100 
        drop if missing(spread5y)
        
        keep if tier == "SNRFOR"
        
        gen doc_priority = 0
        replace doc_priority = 3 if inlist(docclause, "XR14", "XR")
        replace doc_priority = 2 if inlist(docclause, "MR14", "MR")
        replace doc_priority = 1 if inlist(docclause, "MM", "MM14", "CR", "CR14")
        
        gen is_usd = (ccy == "USD")
        
        gsort ticker Date_num -is_usd -doc_priority -compositedepth5y
        by ticker Date_num: keep if _n == 1
        
        rename Date_num Date
        rename spread5y CDS_spread
        keep Date ticker shortname CDS_spread country
        
        save "`output_dir'/`outname'", replace
    }
}

// Appending
local data_dir "${cds}/CDSpre2018"
cd "`data_dir'"

local final_files : dir . files "*.dta"
clear
foreach f of local final_files {
    di "Appending: `f'"
    append using "`f'"
}
label variable Date "Trading Date"
label variable CDS_spread "CDS Spread (5Y SNRFOR)"
label variable ticker "Markit Ticker"
sort ticker Date

gen qdate = qofd(Date)
format qdate %tq
sort ticker Date
order Date qdate ticker shortname country CDS_spread 

bysort ticker qdate: egen avg_CDS_spread = mean(CDS_spread)
bysort ticker qdate: egen sd_CDS_spread = sd(CDS_spread)
bysort ticker qdate: keep if Date == Date[_N]
compress

}

save "Master_CDS_Pre2018.dta", replace

use "${cds}/CDSpre2018/Master_CDS_Pre2018.dta", clear



*** CDS Spreads 2018 - 2020 (Focus on 5-year Spread)

{
	
// Test
import delimited "${cds}/CDS Composites (all) 2018 onwards data/Standard EOD Pricing Report-01Apr19.csv",rowrange(2) varnames(2) clear

gen Date = date(date, "DMY", 2050)
format Date %td
drop date
order Date
keep if tier == "SNRFOR"
keep if tenor =="5Y"
keep if primarycurve == "Y"
keep if primarycoupon == "Y"
duplicates report ticker
gsort ticker Date -compositedepth5y
by ticker Date: keep if _n == 1
duplicates report ticker
keep Date ticker shortname parspread convspread country
rename parspread CDS_spread
save "${cds}/CDSpost2018/2019-04-19.dta",replace

// Loop 
local input_dir "${cds}/CDS Composites (all) 2018 onwards data"
local output_dir "${cds}/CDSpost2018"

local filelist : dir "`input_dir'" files "*.csv"

foreach file of local filelist {
    
    import delimited "`input_dir'/`file'", rowrange(2) varnames(2) clear
    
    if _N > 0 {
        
        gen Date_num = date(date, "DMY", 2050)
        format Date_num %td
        
        local rawdate = string(Date_num[1], "%tdCY-N-D")
        local outname "`rawdate'.dta"
        
        keep if tier == "SNRFOR"
        keep if tenor == "5Y"
        keep if primarycurve == "Y"
        keep if primarycoupon == "Y"
        
        gsort ticker Date_num -compositedepth5y
        by ticker Date_num: keep if _n == 1
        
        rename Date_num Date
        keep Date ticker shortname convspread parspread country
        rename parspread CDS_spread

        save "`output_dir'/`outname'", replace
        di "Saved: `outname'"
    }
}

// Appending

clear all
cd "${cds}/CDSpost2018"
local final_files : dir . files "*.dta"

clear
foreach f of local final_files {
    di "Appending: `f'"
    append using "`f'"
}

label variable Date "Trading Date"
label variable CDS_spread "CDS Spread (5Y SNRFOR)"

gen qdate = qofd(Date)
format qdate %tq
sort ticker Date

bysort ticker qdate: egen avg_CDS_spread = mean(CDS_spread)
bysort ticker qdate: egen sd_CDS_spread = sd(CDS_spread)
bysort ticker qdate: keep if Date == Date[_N]
order Date qdate ticker shortname country CDS_spread avg_CDS_spread
duplicates report
compress

}

save "Master_CDS_2018_2020.dta", replace

use "${cds}/CDSpost2018/Master_CDS_2018_2020.dta", clear


*** Append Both Periods

local pre2018 "${cds}/CDSpre2018/Master_CDS_Pre2018.dta"
local post2018 "${cds}/CDSpost2018/Master_CDS_2018_2020.dta"
local final_out "${cds}/Global_CDS_Full_Panel.dta"

use "`pre2018'", clear
append using "`post2018'"

// Remove Duplicates
sort ticker qdate
duplicates report ticker qdate
duplicates tag ticker qdate, gen(duptag)
gsort -duptag ticker qdate 
drop if duptag == 1 & missing(convspread)
drop duptag

sort ticker qdate
compress

save "${cds}/CDS_2004_2020.dta", replace

use "${cds}/CDS_2004_2020.dta", clear

keep if qdate >= tq(2012q1)

save "${cds}/CDS_2012_2020.dta", replace

keep ticker shortname
duplicates drop ticker, force
outsheet ticker using "${cds}/cds_ticker_list.txt", noquote replace

use "${cds}/CDS_2012_2020.dta", clear







*** Merge with CUSIP Data from WRDS

import delimited "${cds}/Ticker-Cusip.csv",  rowrange(2) varnames(2) clear
gen Date = date(datadate, "YMD")
format Date %td
gen qdate = qofd(Date)
format qdate %tq
order qdate
rename tic ticker
duplicates drop ticker qdate, force
save "${cds}/Ticker-Cusip.dta", replace 

use "${cds}/Ticker-Cusip.dta", clear

use "${cds}/CDS_2012_2020.dta", clear
merge 1:1 qdate ticker using "${cds}/Ticker-Cusip.dta", ///
    keepusing(conm gvkey cusip cik) ///
    keep(master match) nogenerate
sort ticker qdate
gen issuercus = substr(cusip, 1,6)
drop if missing(issuercus)
gen issuecus = substr(cusip, 1,8)
drop cusip
order Date qdate issuercus issuecus gvkey cik
label variable avg_CDS_spread "Average CDS Spread (5Y SNFROR)"
compress
save "${cds}/CDS_2012_2020_CUSIP.dta", replace

	

// Identify all related CUSIPs

use "${cds}/CDS_2012_2020_CUSIP.dta", clear

outsheet gvkey using "${cds}/cds_gvkey_list.txt", noquote replace

import delimited "${cds}/gvkey-cusip.csv", clear

sort gvkey cusip

gen issuercus = substr(cusip, 1, 6)
gen issuecus = substr(cusip, 1, 8)
replace enddate = "2023-12-31" if missing(enddate)

gen s_date = daily(startdate, "YMD")
gen e_date = daily(enddate, "YMD")
format s_date e_date %td
drop startdate enddate

gen q_start = qofd(s_date)
gen q_end   = qofd(e_date)
format q_start q_end %tq

drop s_date e_date
save "bond_quarterly_map.dta", replace

use "${cds}/CDS_2012_2020_CUSIP.dta", clear

joinby gvkey using "bond_quarterly_map.dta"
keep if qdate >= q_start & qdate <= q_end
drop q_start q_end

drop issuercus issuecus
gen issuercus = substr(cusip, 1, 6)
gen issuecus = substr(cusip, 1, 8)
order cusip issuercus
sort issuercus qdate

duplicates report issuercus qdate
duplicates drop issuercus qdate, force

save "${cds}/CDS_2012_2020_GVKEY-CUSIP.dta", replace









