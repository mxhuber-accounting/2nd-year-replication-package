
global root "/Users/matthiashuber/HEC PARIS Dropbox/Matthias Huber/Matthias-Pepa-Vedran/"


*************************************************
*** Issue Characteristics
*************************************************
import delimited "${root}/Rating Data/MergentFISD/Bond Issues Dump.csv",clear

{

keep issue_id issuer_id issuer_cusip issue_cusip maturity convertible mtn ///
    asset_backed yankee foreign_currency offering_date offering_amt ///
    offering_price offering_yield redeemable putable private_placement ///
    isin preferred_security sedol naics_code rule_144a parent_id ///
    bond_type coupon_type industry_group exchangeable canadian ///
    perpetual unit_deal

rename issue_cusip FullSuffix
rename issuer_cusip issuercus
gen issuecus = issuercus + FullSuffix
replace issuecus = substr(issuecus, 1,8)

keep issue_id issuer_id issuercus issuecus maturity convertible mtn ///
    asset_backed yankee foreign_currency offering_date offering_amt ///
    offering_price offering_yield redeemable putable private_placement ///
    isin preferred_security sedol naics_code rule_144a parent_id ///
    bond_type coupon_type industry_group exchangeable canadian ///
    perpetual unit_deal
order issue_id issuer_id issuercus issuecus maturity convertible mtn ///
    asset_backed yankee foreign_currency offering_date offering_amt ///
    offering_price offering_yield redeemable putable private_placement ///
    isin preferred_security sedol naics_code rule_144a parent_id ///
    bond_type coupon_type industry_group exchangeable canadian ///
    perpetual unit_deal

duplicates report issuecus // 1 duplicate
duplicates tag issuecus, gen(dup_tag)
gsort -dup_tag
drop dup_tag
drop if issuecus == "29357JAC" & convertible == "" // drop less informative duplicate observation
compress
save "${root}/Rating Data/MergentFISD/Bond Issues Dump.dta",replace
}

use "${root}/Rating Data/MergentFISD/Bond Issues Dump.dta", clear

// Potential Filters
keep if bond_type == "CDEB" | bond_type == "CMTN"
keep if industry_group == 1 | industry_group == 3 | industry_group == 5
drop if convertible == "Y"
drop if exchangeable == "Y"
drop if asset_backed == "Y"
drop if yankee == "Y"
drop if canadian == "Y"
drop if foreign_currency == "Y"
drop if putable == "Y"
drop if perpetual == "Y"
drop if preferred_security == "Y"
drop if unit_deal == "Y"
drop if redeemable == "Y"





*************************************************
*** Import Data
*************************************************

import delimited "${root}/Rating Data/MergentFISD/Bond Ratings Dump.csv", clear

order issuer_cusip issue_cusip complete_cusip
gen issuecus = substr(complete_cusip, 1, 8)
gen SPR = rating if rating_type == "SPR"
gen MR = rating if rating_type == "MR"
gen FR = rating if rating_type == "FR"
gen R_Date = date(rating_date, "YMD")
format R_Date %td
gen Off_Date = date(offering_date, "YMD")
format Off_Date %td
gen Mat_Date = date(maturity, "YMD")
format Mat_Date %td
gen SPR_Date = R_Date if rating_type == "SPR"
gen MR_Date = R_Date if rating_type == "MR"
gen FR_Date = R_Date if rating_type == "FR"
format SPR_Date MR_Date FR_Date %td
gsort complete_cusip SPR_Date MR_Date FR_Date
drop rating_type rating_date offering_date maturity
drop rating_status reason rating_status_date investment_grade
gen qdate = qofd(R_Date)
format qdate %tq
gen q_off = qofd(Off_Date)
gen q_mat = qofd(Mat_Date)
format q_off q_mat %tq
order complete_cusip issuer_cusip issue_cusip SPR MR FR SPR_Date MR_Date FR_Date R_Date qdate

save "${root}/Rating Data/MergentFISD/Bond Ratings Dump.dta", replace


*************************************************
*** S&P Ratings
*************************************************


use "${root}/Rating Data/MergentFISD/Bond Ratings Dump.dta", clear
{
drop if missing(SPR) 
drop MR FR R_Date MR_Date FR_Date rating 
duplicates drop

gen SPR_num = . 
replace SPR_num = 1  if SPR == "AAA"
replace SPR_num = 2  if SPR == "AA+"
replace SPR_num = 3  if SPR == "AA"
replace SPR_num = 4  if SPR == "AA-"
replace SPR_num = 5  if SPR == "A+"
replace SPR_num = 6  if SPR == "A"
replace SPR_num = 7  if SPR == "A-"
replace SPR_num = 8  if SPR == "BBB+"
replace SPR_num = 9  if SPR == "BBB"
replace SPR_num = 10 if SPR == "BBB-"
replace SPR_num = 11 if SPR == "BB+"
replace SPR_num = 12 if SPR == "BB"
replace SPR_num = 13 if SPR == "BB-"
replace SPR_num = 14 if SPR == "B+"
replace SPR_num = 15 if SPR == "B"
replace SPR_num = 16 if SPR == "B-"
replace SPR_num = 17 if SPR == "CCC+"
replace SPR_num = 18 if SPR == "CCC"
replace SPR_num = 19 if SPR == "CCC-"
replace SPR_num = 20 if SPR == "CC"
replace SPR_num = 21 if SPR == "C"
replace SPR_num = 22 if SPR == "D"
replace SPR_num = 22 if SPR == "SD"
replace SPR_num = 0  if SPR == "NR"
gsort complete_cusip SPR_Date 
order complete_cusip issuer_cusip issue_cusip SPR SPR_num
// keep only the last observation per quarter to construct quarterly ratings
bys complete_cusip qdate (SPR_Date): keep if _n == _N


local horizon = quarterly("2025q4","YQ")
preserve
    bysort complete_cusip (qdate): gen qdate_end = qdate[_n+1] - 1
    bysort complete_cusip (qdate): gen last_rating = SPR[_N]
    bysort complete_cusip (qdate): replace qdate_end = `horizon' if missing(qdate_end) & SPR_num > 0
    gen n_quarters = qdate_end - qdate + 1
    expand n_quarters
    bysort complete_cusip qdate: gen qdate_expanded = qdate + _n - 1
    drop qdate
    rename qdate_expanded qdate
    format qdate %tq
    keep complete_cusip qdate
    tempfile panel
    save `panel', replace
restore
merge 1:1 complete_cusip qdate using `panel', nogen

gsort complete_cusip qdate 

bysort complete_cusip (qdate): replace issuer_cusip = issuer_cusip[_n-1] if missing(issuer_cusip)
bysort complete_cusip (qdate): replace issue_cusip = issue_cusip[_n-1] if missing(issue_cusip)
bysort complete_cusip (qdate): replace SPR_Date = SPR_Date[_n-1] if missing(SPR_Date)
bysort complete_cusip (qdate): replace issue_id = issue_id[_n-1] if missing(issue_id)
bysort complete_cusip (qdate): replace issuer_id = issuer_id[_n-1] if missing(issuer_id)
bysort complete_cusip (qdate): replace prospectus_issuer_name = prospectus_issuer_name[_n-1] if missing(prospectus_issuer_name)
bysort complete_cusip (qdate): replace issue_name = issue_name[_n-1] if missing(issue_name)
bysort complete_cusip (qdate): replace issuecus = issuecus[_n-1] if missing(issuecus)
bysort complete_cusip (qdate): replace Off_Date = Off_Date[_n-1] if missing(Off_Date)
bysort complete_cusip (qdate): replace Mat_Date = Mat_Date[_n-1] if missing(Mat_Date)
bysort complete_cusip (qdate): replace SPR = SPR[_n-1] if missing(SPR)
bysort complete_cusip (qdate): replace SPR_num = SPR_num[_n-1] if missing(SPR_num)
bysort complete_cusip (qdate): gen SPRchange = SPR_num[_n-1] - SPR_num
replace SPRchange = 0 if SPR_num < 1 | SPR_num[_n-1] < 1
// Excluding SP Defaults as Rating Change / Downgrade
replace SPRchange = 0 if SPR_num > 21 | SPR_num[_n-1] > 21
replace SPRchange = 0 if missing(SPRchange)
summarize SPRchange, detail

rename issuer_cusip issuercus
order issuercus issuecus SPR SPR_num SPR_Date qdate SPRchange Off_Date Mat_Date
keep issuercus issuecus SPR SPR_num SPR_Date qdate SPRchange Off_Date Mat_Date
sort issuecus qdate
}

save "$path/MergentFISD_SPR.dta", replace

use "$path/MergentFISD_SPR.dta", clear
summarize SPRchange, detail



*************************************************
*** Moody's Ratings
*************************************************


use "$path/MergentFISD.dta", clear
{
drop if missing(MR) 
drop SPR FR R_Date SPR_Date FR_Date rating 
duplicates drop

gen MR_num = . 
replace MR_num = 1  if MR == "Aaa"
replace MR_num = 2  if MR == "Aa1"
replace MR_num = 3  if MR == "Aa2"
replace MR_num = 4  if MR == "Aa3"
replace MR_num = 5  if MR == "A1"
replace MR_num = 6  if MR == "A2"
replace MR_num = 7  if MR == "A3"
replace MR_num = 8  if MR == "Baa1"
replace MR_num = 9  if MR == "Baa2"
replace MR_num = 10 if MR == "Baa3"
replace MR_num = 11 if MR == "Ba1"
replace MR_num = 12 if MR == "Ba2"
replace MR_num = 13 if MR == "Ba3"
replace MR_num = 14 if MR == "B1"
replace MR_num = 15 if MR == "B2"
replace MR_num = 16 if MR == "B3"
replace MR_num = 17 if MR == "Caa1"
replace MR_num = 18 if MR == "Caa2"
replace MR_num = 19 if MR == "Caa3"
replace MR_num = 20 if MR == "Ca"
replace MR_num = 21 if MR == "C"
replace MR_num =  0 if MR == "NR"
replace MR_num = -1 if MR == "WR"	

gsort complete_cusip MR_Date 
order complete_cusip issuer_cusip issue_cusip MR MR_num
// keep only the last observation per quarter to construct quarterly ratings
bys complete_cusip qdate (MR_Date): keep if _n == _N


local horizon = quarterly("2025q4","YQ")
preserve
    bysort complete_cusip (qdate): gen qdate_end = qdate[_n+1] - 1
    bysort complete_cusip (qdate): gen last_rating = MR[_N]
    bysort complete_cusip (qdate): replace qdate_end = `horizon' if missing(qdate_end) & MR_num > 0
    gen n_quarters = qdate_end - qdate + 1
    expand n_quarters
    bysort complete_cusip qdate: gen qdate_expanded = qdate + _n - 1
    drop qdate
    rename qdate_expanded qdate
    format qdate %tq

    keep complete_cusip qdate
    tempfile panel
    save `panel', replace
restore
merge 1:1 complete_cusip qdate using `panel', nogen
gsort complete_cusip qdate 

bysort complete_cusip (qdate): replace issuer_cusip = issuer_cusip[_n-1] if missing(issuer_cusip)
bysort complete_cusip (qdate): replace issue_cusip = issue_cusip[_n-1] if missing(issue_cusip)
bysort complete_cusip (qdate): replace MR_Date = MR_Date[_n-1] if missing(MR_Date)
bysort complete_cusip (qdate): replace issue_id = issue_id[_n-1] if missing(issue_id)
bysort complete_cusip (qdate): replace issuer_id = issuer_id[_n-1] if missing(issuer_id)
bysort complete_cusip (qdate): replace prospectus_issuer_name = prospectus_issuer_name[_n-1] if missing(prospectus_issuer_name)
bysort complete_cusip (qdate): replace issue_name = issue_name[_n-1] if missing(issue_name)
bysort complete_cusip (qdate): replace issuecus = issuecus[_n-1] if missing(issuecus)
bysort complete_cusip (qdate): replace Off_Date = Off_Date[_n-1] if missing(Off_Date)
bysort complete_cusip (qdate): replace Mat_Date = Mat_Date[_n-1] if missing(Mat_Date)
bysort complete_cusip (qdate): replace MR = MR[_n-1] if missing(MR)
bysort complete_cusip (qdate): replace MR_num = MR_num[_n-1] if missing(MR_num)

bysort complete_cusip (qdate): gen MRchange = MR_num[_n-1] - MR_num
replace MRchange = 0 if MR_num < 1 | MR_num[_n-1] < 1
replace MRchange = 0 if missing(MRchange)
summarize MRchange, detail 

rename issuer_cusip issuercus
order issuercus issuecus MR MR_num MR_Date qdate MRchange Off_Date Mat_Date
keep issuercus issuecus MR MR_num MR_Date qdate MRchange Off_Date Mat_Date
sort issuecus qdate
}
save "$path/MergentFISD_MR.dta", replace



*************************************************
*** Fitch Ratings
*************************************************

use "$path/MergentFISD.dta", clear
{
drop if missing(FR) 
drop MR SPR R_Date SPR_Date MR_Date rating 
duplicates drop

gen FR_num = .

{
replace FR_num = 1  if FR == "AAA"
replace FR_num = 2  if FR == "AA+"
replace FR_num = 3  if FR == "AA"
replace FR_num = 4  if FR == "AA-"
replace FR_num = 5  if FR == "A+"
replace FR_num = 6  if FR == "A"
replace FR_num = 7  if FR == "A-"
replace FR_num = 8  if FR == "BBB+"
replace FR_num = 9  if FR == "BBB"
replace FR_num = 10 if FR == "BBB-"
replace FR_num = 11 if FR == "BB+"
replace FR_num = 12 if FR == "BB"
replace FR_num = 13 if FR == "BB-"
replace FR_num = 14 if FR == "B+"
replace FR_num = 15 if FR == "B"
replace FR_num = 16 if FR == "B-"
replace FR_num = 17 if FR == "CCC+"
replace FR_num = 18 if FR == "CCC"
replace FR_num = 19 if FR == "CCC-"
replace FR_num = 20 if FR == "CC"
replace FR_num = 21 if FR == "C"
replace FR_num = 22 if FR == "RD"
replace FR_num = 22 if FR == "D"
replace FR_num = 22 if FR == "DDD" // old Fitch Scale
replace FR_num =  0 if FR == "NR"
replace FR_num = -1 if FR == "WD"
}

gsort complete_cusip FR_Date 
order complete_cusip issuer_cusip issue_cusip FR FR_num
// keep only the last observation per quarter to construct quarterly ratings
bys complete_cusip qdate (FR_Date): keep if _n == _N


local horizon = quarterly("2025q4","YQ")
preserve
    bysort complete_cusip (qdate): gen qdate_end = qdate[_n+1] - 1
    bysort complete_cusip (qdate): gen last_rating = FR[_N]
    bysort complete_cusip (qdate): replace qdate_end = `horizon' if missing(qdate_end) & FR_num > 0
    gen n_quarters = qdate_end - qdate + 1
    expand n_quarters
    bysort complete_cusip qdate: gen qdate_expanded = qdate + _n - 1
    drop qdate
    rename qdate_expanded qdate
    format qdate %tq

    keep complete_cusip qdate
    tempfile panel
    save `panel', replace
restore
merge 1:1 complete_cusip qdate using `panel', nogen
gsort complete_cusip qdate 

bysort complete_cusip (qdate): replace issuer_cusip = issuer_cusip[_n-1] if missing(issuer_cusip)
bysort complete_cusip (qdate): replace issue_cusip = issue_cusip[_n-1] if missing(issue_cusip)
bysort complete_cusip (qdate): replace FR_Date = FR_Date[_n-1] if missing(FR_Date)
bysort complete_cusip (qdate): replace issue_id = issue_id[_n-1] if missing(issue_id)
bysort complete_cusip (qdate): replace issuer_id = issuer_id[_n-1] if missing(issuer_id)
bysort complete_cusip (qdate): replace prospectus_issuer_name = prospectus_issuer_name[_n-1] if missing(prospectus_issuer_name)
bysort complete_cusip (qdate): replace issue_name = issue_name[_n-1] if missing(issue_name)
bysort complete_cusip (qdate): replace issuecus = issuecus[_n-1] if missing(issuecus)
bysort complete_cusip (qdate): replace Off_Date = Off_Date[_n-1] if missing(Off_Date)
bysort complete_cusip (qdate): replace Mat_Date = Mat_Date[_n-1] if missing(Mat_Date)
bysort complete_cusip (qdate): replace FR = FR[_n-1] if missing(FR)
bysort complete_cusip (qdate): replace FR_num = FR_num[_n-1] if missing(FR_num)

bysort complete_cusip (qdate): gen FRchange = FR_num[_n-1] - FR_num
replace FRchange = 0 if FR_num < 1 | FR_num[_n-1] < 1
replace FRchange = 0 if missing(FRchange)
summarize FRchange, detail

rename issuer_cusip issuercus
order issuercus issuecus FR FR_num FR_Date qdate FRchange Off_Date Mat_Date
keep issuercus issuecus FR FR_num FR_Date qdate FRchange Off_Date Mat_Date
sort issuecus qdate
}

save "$path/MergentFISD_FR.dta", replace



*************************************************
*** Merge Agency Datasets
*************************************************

use "$path/MergentFISD_SPR.dta", clear

{

merge 1:m issuecus qdate using "$path/MergentFISD_MR.dta"
drop _merge 

merge 1:m issuecus qdate using "$path/MergentFISD_FR.dta"
drop _merge 

unique issuercus if !missing(SPR)
unique issuercus if !missing(MR)
unique issuercus if !missing(FR)
unique issuecus if !missing(SPR)
unique issuecus if !missing(MR)
unique issuecus if !missing(FR)
unique issuercus if !missing(SPR) & !missing(MR)
unique issuercus if !missing(SPR) & !missing(MR) & !missing(FR)
unique issuecus if !missing(SPR) & !missing(MR)
unique issuecus if !missing(SPR) & !missing(MR) & !missing(FR)
save "$path/MergentFISD_ALL.dta", replace
keep issuecus qdate SPRchange

save "$path/SPRchange.dta", replace


global path "/Users/matthiashuber/HEC PARIS Dropbox/Matthias Huber/Bondholding/Rating Data"

use  "$path/LSEG Ratings/LSEGRatingsMIS_final", clear
merge m:1 issuercus qdate using  "$path/S&P Ratings/SPCUSIP_merge.dta"
drop MIS_prev MNotches MRAction MIS_pnum MQNotches MQRAction CIQ SP_prev SPQNotches SPQRAction SP_pnum _merge
bysort issuercus (qdate): gen SP_change = SP_num[_n-1] - SP_num 
replace SP_change = 0 if SP_num < 1 | SP_num[_n-1] < 1
replace SP_change = 0 if SP_num > 21 | SP_num[_n-1] > 21
replace SP_change = 0 if missing(SP_change)
summarize SP_change, detail
bysort issuercus (qdate): gen MIS_change = MIS_num[_n-1] - MIS_num 
replace MIS_change = 0 if MIS_num < 1 | MIS_num[_n-1] < 1
replace MIS_change = 0 if missing(MIS_change)
summarize MIS_change, detail
order issuercus issuecus qdate SP SP_num SP_change MIS MIS_num MIS_change MDate RatingSource
save "/Users/matthiashuber/HEC PARIS Dropbox/Matthias Huber/Bondholding/DATA/RATING/IssuerRatings", replace
use  "/Users/matthiashuber/HEC PARIS Dropbox/Matthias Huber/Bondholding/DATA/RATING//MergentFISD_ALL.dta", clear
merge m:1 issuercus qdate using "/Users/matthiashuber/HEC PARIS Dropbox/Matthias Huber/Bondholding/DATA/RATING/IssuerRatings.dta"
drop _merge

order issuercus issuecus qdate SPR SPR_num SPR_Date SPRchange SP SP_num SP_change MR MR_num MR_Date MRchange MIS MIS_num MIS_change RatingSource FR FR_num FR_Date FRchange Off_Date Mat_Date
sort issuercus issuecus qdate
compress

save "/Users/matthiashuber/HEC PARIS Dropbox/Matthias Huber/Bondholding/DATA/RATING/AllRatings.dta", replace
}

use "/Users/matthiashuber/HEC PARIS Dropbox/Matthias Huber/Bondholding/DATA/RATING/AllRatings.dta", clear


*************************************************
*** Import LSEG Ratings
*************************************************


import excel using "/Users/matthiashuber/Documents/HEC/1st Year Summer Paper/MergentISSUELSEG.xlsx", sheet("Sheet2") firstrow clear
save sheet2_temp, replace

{

import excel using "/Users/matthiashuber/Documents/HEC/1st Year Summer Paper/MergentISSUELSEG.xlsx", sheet("Sheet3") firstrow clear
save sheet3_temp, replace

use sheet2_temp, clear
append using sheet3_temp
save merged_issues, replace
erase sheet2_temp.dta
erase sheet3_temp.dta


use merged_issues, clear 

drop if Rating == "NULL"
drop if Rating == "Unable to collect data for the field 'TR.GR.Rating' and some specific identifier(s)."
drop if RatingSource == "Rating Source"
rename A issuecus
replace RatingSource = "DP" if RatingSource == "D&P"
replace RatingSource = "RI" if RatingSource == "R&I"

keep if regexm(RatingSource, "^(MDY|FTC|DOM|RI|JCR|RNL|DP|EGJ)$")

drop RatingSourceDescription
replace Date = trim(Date)
gen double Date_d = date(Date, "MDY")
format Date_d %td
drop Date
rename Date_d Date
duplicates report issuecus RatingSource Date

reshape wide Rating, i(issuecus Date) j(RatingSource) string

label variable RatingMDY  "Moody's Long-term Issue Credit Rating"
label variable RatingFTC  "Fitch Long-term Issue Credit Rating"
label variable RatingDOM  "Dominion Bond Rating Service (DBRS) - Bond"
label variable RatingRI   "R&I Long-term Issue Credit Rating"
label variable RatingJCR  "JCR Long-term Issue Credit Rating"
label variable RatingRNL  "NRA Long-term Issue International Scale Credit Rating"
label variable RatingDP   "Duff & Phelps Long-term Issue Credit Rating"
label variable RatingEGJ  "Egan-Jones Long-term Issue Credit Rating"

order issuecus Date RatingMDY RatingFTC RatingEGJ RatingDOM RatingJCR RatingRI RatingDOM RatingDP RatingRNL


// Clean up ONLY NR Ratings

foreach v of varlist RatingMDY RatingFTC RatingEGJ RatingDOM RatingJCR RatingRI RatingRNL {
    di as text "Processing `v' ..."
    
    bysort issuecus: egen all_NR_`v' = min(cond(`v' == "NR" | missing(`v'), 1, 0))
    
    drop if all_NR_`v' == 1 & `v' == "NR"
    
    drop all_NR_`v'
}

sort issuecus Date RatingMDY 

save merged_issues_rehape, replace
use merged_issues_rehape, clear
bysort issuecus: egen only_bad_MDY = min(inlist(RatingMDY, "NR", "WR"))
egen all_missing_other = rowmiss(RatingFTC RatingEGJ RatingDOM RatingJCR RatingRI RatingDP RatingRNL)
bysort issuecus: egen all_missing_group = min(all_missing_other == 7)
drop if only_bad_MDY == 1 & all_missing_group == 1
drop only_bad_MDY all_missing_other all_missing_group

gen qdate = qofd(Date)
format qdate %tq
order issuecus Date qdate
drop RatingRNL

save merged_issues_clean, replace
}

use "/Users/matthiashuber/Documents/HEC/1st Year Summer Paper/merged_issues_clean", clear




*************************************************
// Moody's QUARTERLY RATNGS
*************************************************

use "/Users/matthiashuber/Documents/HEC/1st Year Summer Paper/merged_issues_clean", clear

{
keep if !missing(RatingMDY)
keep issuecus Date qdate RatingMDY
sort issuecus qdate
bysort issuecus qdate (Date): keep if _n == _N
rename Date MDYDate

local horizon = quarterly("2023q4","YQ")

preserve
    bysort issuecus (qdate): gen qdate_end = qdate[_n+1] - 1
    replace qdate_end = qdate if inlist(RatingMDY, "NR", "WR")
    bysort issuecus (qdate): replace qdate_end = `horizon' if missing(qdate_end) & !inlist(RatingMDY, "NR", "WR") & RatingMDY != ""

    gen n_quarters = qdate_end - qdate + 1
    replace n_quarters = 1 if n_quarters < 1

    expand n_quarters

    bysort issuecus qdate: gen qdate_expanded = qdate + _n - 1
    drop qdate
    rename qdate_expanded qdate
    format qdate %tq

    keep issuecus qdate RatingMDY

    tempfile mdy_panel
    save `mdy_panel', replace
restore

merge 1:1 issuecus qdate using `mdy_panel', nogen
sort issuecus qdate

gen MDY_num = .
{ 
replace MDY_num = 1  if RatingMDY== "Aaa"
replace MDY_num = 2  if RatingMDY== "Aa1"
replace MDY_num = 3  if RatingMDY== "Aa2"
replace MDY_num = 4  if RatingMDY== "Aa3"
replace MDY_num = 5  if RatingMDY== "A1"
replace MDY_num = 6  if RatingMDY== "A2"
replace MDY_num = 7  if RatingMDY== "A3"
replace MDY_num = 8  if RatingMDY== "Baa1"
replace MDY_num = 9  if RatingMDY== "Baa2"
replace MDY_num = 10 if RatingMDY== "Baa3"
replace MDY_num = 11 if RatingMDY== "Ba1"
replace MDY_num = 12 if RatingMDY== "Ba2"
replace MDY_num = 13 if RatingMDY== "Ba3"
replace MDY_num = 14 if RatingMDY== "B1"
replace MDY_num = 15 if RatingMDY== "B2"
replace MDY_num = 16 if RatingMDY== "B3"
replace MDY_num = 17 if RatingMDY== "Caa1"
replace MDY_num = 18 if RatingMDY== "Caa2"
replace MDY_num = 19 if RatingMDY== "Caa3"
replace MDY_num = 20 if RatingMDY== "Ca"
replace MDY_num = 21 if RatingMDY== "C"
replace MDY_num =  0 if RatingMDY== "NR"
replace MDY_num = -1 if RatingMDY== "WR"	
}

}

save "/Users/matthiashuber/Documents/HEC/1st Year Summer Paper/MDYissue.dta", replace

*************************************************
// FITCH QUARTERLY RATNGS
*************************************************


use "/Users/matthiashuber/Documents/HEC/1st Year Summer Paper/merged_issues_clean", clear

{
keep if !missing(RatingFTC)
keep issuecus Date qdate RatingFTC
sort issuecus qdate 
drop if regexm(RatingFTC, "EXP")
bysort issuecus qdate (Date): keep if _n == _N
rename Date FTCDate

local horizon = quarterly("2023q4","YQ")

preserve
    bysort issuecus (qdate): gen qdate_end = qdate[_n+1] - 1

    replace qdate_end = qdate if inlist(RatingFTC, "NR", "WD")

    bysort issuecus (qdate): ///
        replace qdate_end = `horizon' if missing(qdate_end) ///
        & !inlist(RatingFTC, "NR", "WD") ///
        & RatingFTC != ""

    gen n_quarters = qdate_end - qdate + 1
    replace n_quarters = 1 if n_quarters < 1   

    expand n_quarters

    bysort issuecus qdate: gen qdate_expanded = qdate + _n - 1
    drop qdate
    rename qdate_expanded qdate
    format qdate %tq

    keep issuecus qdate RatingFTC

    tempfile fitch_panel
    save `fitch_panel', replace
restore

merge 1:1 issuecus qdate using `fitch_panel', nogen

sort issuecus qdate

gen FTC_num = .
replace FTC_num = 1  if RatingFTC== "AAA"
replace FTC_num = 2  if RatingFTC== "AA+"
replace FTC_num = 3  if RatingFTC== "AA"
replace FTC_num = 4  if RatingFTC== "AA-"
replace FTC_num = 5  if RatingFTC== "A+"
replace FTC_num = 6  if RatingFTC== "A"
replace FTC_num = 7  if RatingFTC== "A-"
replace FTC_num = 8  if RatingFTC== "BBB+"
replace FTC_num = 9  if RatingFTC== "BBB"
replace FTC_num = 10 if RatingFTC== "BBB-"
replace FTC_num = 11 if RatingFTC== "BB+"
replace FTC_num = 12 if RatingFTC== "BB"
replace FTC_num = 13 if RatingFTC== "BB-"
replace FTC_num = 14 if RatingFTC== "B+"
replace FTC_num = 15 if RatingFTC== "B"
replace FTC_num = 16 if RatingFTC== "B-"
replace FTC_num = 17 if RatingFTC== "CCC+"
replace FTC_num = 18 if RatingFTC== "CCC"
replace FTC_num = 19 if RatingFTC== "CCC-"
replace FTC_num = 20 if RatingFTC== "CC"
replace FTC_num = 21 if RatingFTC== "C"
replace FTC_num = 22 if RatingFTC== "RD"
replace FTC_num = 22 if RatingFTC== "D"
replace FTC_num = 22 if RatingFTC== "DDD" // old Fitch Scale
replace FTC_num =  0 if RatingFTC== "NR"
replace FTC_num = -1 if RatingFTC== "WD"

}

save "/Users/matthiashuber/Documents/HEC/1st Year Summer Paper/FTCissue.dta", replace

*************************************************
// EGJ QUARTERLY RATINGS
*************************************************

use "/Users/matthiashuber/Documents/HEC/1st Year Summer Paper/merged_issues_clean", clear

{
keep if !missing(RatingEGJ)
keep issuecus Date qdate RatingEGJ
sort issuecus qdate
bysort issuecus qdate (Date): keep if _n == _N
rename Date EGJDate

local horizon = quarterly("2023q4","YQ")

preserve
    bysort issuecus (qdate): gen qdate_end = qdate[_n+1] - 1
    replace qdate_end = qdate if inlist(RatingEGJ, "NR", "WR")
    bysort issuecus (qdate): replace qdate_end = `horizon' if missing(qdate_end) & !inlist(RatingEGJ, "NR", "WR") & RatingEGJ != ""

    gen n_quarters = qdate_end - qdate + 1
    replace n_quarters = 1 if n_quarters < 1

    expand n_quarters

    bysort issuecus qdate: gen qdate_expanded = qdate + _n - 1
    drop qdate
    rename qdate_expanded qdate
    format qdate %tq

    keep issuecus qdate RatingEGJ

    tempfile egj_panel
    save `egj_panel', replace
restore

merge 1:1 issuecus qdate using `egj_panel', nogen
sort issuecus qdate

gen EGJ_num = .
{
replace EGJ_num = 1  if RatingEGJ == "AAA"
replace EGJ_num = 2  if RatingEGJ == "AA+"
replace EGJ_num = 3  if RatingEGJ == "AA"
replace EGJ_num = 4  if RatingEGJ == "AA-"
replace EGJ_num = 5  if RatingEGJ == "A+"
replace EGJ_num = 6  if RatingEGJ == "A"
replace EGJ_num = 7  if RatingEGJ == "A-"
replace EGJ_num = 8  if RatingEGJ == "BBB+"
replace EGJ_num = 9  if RatingEGJ == "BBB"
replace EGJ_num = 10 if RatingEGJ == "BBB-"
replace EGJ_num = 11 if RatingEGJ == "BB+"
replace EGJ_num = 12 if RatingEGJ == "BB"
replace EGJ_num = 13 if RatingEGJ == "BB-"
replace EGJ_num = 14 if RatingEGJ == "B+"
replace EGJ_num = 15 if RatingEGJ == "B"
replace EGJ_num = 16 if RatingEGJ == "B-"
replace EGJ_num = 17 if RatingEGJ == "CCC+"
replace EGJ_num = 18 if RatingEGJ == "CCC"
replace EGJ_num = 19 if RatingEGJ == "CCC-"
replace EGJ_num = 20 if RatingEGJ == "CC"
replace EGJ_num = 21 if RatingEGJ == "C"

replace EGJ_num = 0  if RatingEGJ == "NR"
replace EGJ_num = -1 if RatingEGJ == "WR" | RatingEGJ == "WD"
}

bysort issuecus (qdate): gen EGJchange = EGJ_num[_n-1] - EGJ_num
by issuecus: replace EGJchange = 0 if EGJ_num < 1 | EGJ_num[_n-1] < 1
replace EGJchange = 0 if missing(EGJchange)
summarize EGJchange, detail 

}

save "/Users/matthiashuber/Documents/HEC/1st Year Summer Paper/EGJissue.dta", replace


*************************************************
// DOM QUARTERLY RATINGS
*************************************************

use "/Users/matthiashuber/Documents/HEC/1st Year Summer Paper/merged_issues_clean", clear

{
keep if !missing(RatingDOM)
keep issuecus Date qdate RatingDOM
sort issuecus qdate
bysort issuecus qdate (Date): keep if _n == _N
rename Date DOMDate
levelsof RatingDOM

local horizon = quarterly("2023q4","YQ")

preserve
    bysort issuecus (qdate): gen qdate_end = qdate[_n+1] - 1
    replace qdate_end = qdate if inlist(RatingDOM, "NR", "Discontinued")
    bysort issuecus (qdate): replace qdate_end = `horizon' if missing(qdate_end) & !inlist(RatingDOM, "NR", "Discontinued") & RatingDOM != ""

    gen n_quarters = qdate_end - qdate + 1
    replace n_quarters = 1 if n_quarters < 1

    expand n_quarters

    bysort issuecus qdate: gen qdate_expanded = qdate + _n - 1
    drop qdate
    rename qdate_expanded qdate
    format qdate %tq

    keep issuecus qdate RatingDOM

    tempfile dom_panel
    save `dom_panel', replace
restore

merge 1:1 issuecus qdate using `dom_panel', nogen


gen DOM_num = .
{
replace DOM_num = 1  if RatingDOM == "AAA"
replace DOM_num = 2  if RatingDOM == "AA (high)"
replace DOM_num = 3  if RatingDOM == "AA"
replace DOM_num = 4  if RatingDOM == "AA (low)"
replace DOM_num = 5  if RatingDOM == "A+"
replace DOM_num = 6  if RatingDOM == "A"
replace DOM_num = 7  if RatingDOM == "A-"
replace DOM_num = 8  if RatingDOM == "BBB+"
replace DOM_num = 9  if RatingDOM == "BBB"
replace DOM_num = 10 if RatingDOM == "BBB-"
replace DOM_num = 11 if RatingDOM == "BB (high)"
replace DOM_num = 12 if RatingDOM == "BB"
replace DOM_num = 13 if RatingDOM == "BB (low)"
replace DOM_num = 14 if RatingDOM == "B (high)"
replace DOM_num = 15 if RatingDOM == "B"
replace DOM_num = 16 if RatingDOM == "B (low)"
replace DOM_num = 17 if RatingDOM == "CCC (high)"
replace DOM_num = 18 if RatingDOM == "CCC"
replace DOM_num = 19 if RatingDOM == "CCC (low)"
replace DOM_num = 20 if RatingDOM == "CC"
replace DOM_num = 21 if RatingDOM == "C"

replace DOM_num = -1 if RatingDOM == "Discontinued" 
}

sort issuecus qdate

bysort issuecus (qdate): gen DOMchange = DOM_num[_n-1] - DOM_num
by issuecus: replace DOMchange = 0 if DOM_num < 1 | DOM_num[_n-1] < 1
replace DOMchange = 0 if missing(DOMchange)
summarize DOMchange, detail 

}

save "/Users/matthiashuber/Documents/HEC/1st Year Summer Paper/DOMissue.dta", replace


*************************************************
// RI QUARTERLY RATINGS (Ommited as Only 226 Observations)
*************************************************

use "/Users/matthiashuber/Documents/HEC/1st Year Summer Paper/merged_issues_clean", clear

{
keep if !missing(RatingRI)
keep issuecus Date qdate RatingRI
sort issuecus qdate
bysort issuecus qdate (Date): keep if _n == _N
rename Date RIDate

local horizon = quarterly("2023q4","YQ")

preserve
    bysort issuecus (qdate): gen qdate_end = qdate[_n+1] - 1
    replace qdate_end = qdate if inlist(RatingRI, "NR", "WR")
    bysort issuecus (qdate): replace qdate_end = `horizon' if missing(qdate_end) & !inlist(RatingRI, "NR", "WR") & RatingRI != ""

    gen n_quarters = qdate_end - qdate + 1
    replace n_quarters = 1 if n_quarters < 1

    expand n_quarters

    bysort issuecus qdate: gen qdate_expanded = qdate + _n - 1
    drop qdate
    rename qdate_expanded qdate
    format qdate %tq

    keep issuecus qdate RatingRI

    tempfile ri_panel
    save `ri_panel', replace
restore

merge 1:1 issuecus qdate using `ri_panel', nogen
sort issuecus qdate
}

save "/Users/matthiashuber/Documents/HEC/1st Year Summer Paper/RIissue.dta", replace

*************************************************
// JCR QUARTERLY RATINGS (Ommited as Only 195 Observations)
*************************************************

use "/Users/matthiashuber/Documents/HEC/1st Year Summer Paper/merged_issues_clean", clear

{
keep if !missing(RatingJCR)
keep issuecus Date qdate RatingJCR
sort issuecus qdate
bysort issuecus qdate (Date): keep if _n == _N
rename Date JCRDate

local horizon = quarterly("2023q4","YQ")

preserve
    bysort issuecus (qdate): gen qdate_end = qdate[_n+1] - 1
    replace qdate_end = qdate if inlist(RatingJCR, "NR", "WR")
    bysort issuecus (qdate): replace qdate_end = `horizon' if missing(qdate_end) & !inlist(RatingJCR, "NR", "WR") & RatingJCR != ""

    gen n_quarters = qdate_end - qdate + 1
    replace n_quarters = 1 if n_quarters < 1

    expand n_quarters

    bysort issuecus qdate: gen qdate_expanded = qdate + _n - 1
    drop qdate
    rename qdate_expanded qdate
    format qdate %tq

    keep issuecus qdate RatingJCR

    tempfile jcr_panel
    save `jcr_panel', replace
restore

merge 1:1 issuecus qdate using `jcr_panel', nogen
sort issuecus qdate
}

save "/Users/matthiashuber/Documents/HEC/1st Year Summer Paper/JCRissue.dta", replace



*************************************************
// MERGE ALL QUARTERLY RATINGS
*************************************************

use "/Users/matthiashuber/Documents/HEC/1st Year Summer Paper/MDYissue.dta", clear

merge 1:1 issuecus qdate using "/Users/matthiashuber/Documents/HEC/1st Year Summer Paper/FTCissue.dta", nogen
merge 1:1 issuecus qdate using "/Users/matthiashuber/Documents/HEC/1st Year Summer Paper/EGJissue.dta", nogen
merge 1:1 issuecus qdate using "/Users/matthiashuber/Documents/HEC/1st Year Summer Paper/DOMissue.dta", nogen

sort issuecus qdate
save "/Users/matthiashuber/Documents/HEC/1st Year Summer Paper/AllRatingsPanel.dta", replace

*************************************************
// Merge LSEG Ratings with Mergent FISD
*************************************************

use "/Users/matthiashuber/Documents/HEC/1st Year Summer Paper/AllRatingsPanel.dta", clear
{
order issuecus qdate RatingMDY MDY_num MDYDate RatingFTC FTC_num FTCDate RatingEGJ EGJ_num EGJDate 
rename issuecus issuecus9
gen issuecus = substr(issuecus9, 1,8)
save AllRatingsNum, replace

global path "/Users/matthiashuber/HEC PARIS Dropbox/Matthias Huber/Bondholding/DATA/RATING"

use "$path/MergentFISD_SPR.dta", clear

replace issuecus = substr(issuecus, 1,8)

merge 1:1 issuecus qdate using "$path/MergentFISD_MR.dta", nogen
merge 1:1 issuecus qdate using "$path/MergentFISD_FR.dta", nogen

sort issuecus qdate

save "$path/MergentFISD_allratings.dta", replace

use "$path/MergentFISD_allratings.dta", clear

merge 1:1 issuecus qdate using AllRatingsNum

label variable SPR  "S&P MergentFISD Issue Rating"
label variable MR  "Moody's MergentFISD Issue Rating"
label variable FR  "Fitch MergentFISD Issue Rating"

label variable SPR_num  "S&P MergentFISD Issue Rating Numeric"
label variable MR_num  "Moody's MergentFISD Issue Rating Numeric"
label variable FR_num  "Fitch MergentFISD Issue Rating Numeric"

label variable Off_Date  "MergentFISD Offering Date"
label variable Mat_Date  "MergentFISD Maturity Date"

drop issuecus9 _merge
compress


// Check when Moody's / Fitch Ratings are different for same issuecus qdate
gen flag = 1 if MR_num != MDY_num & !missing(MDY_num) & !missing(MR_num) 
gen flagFR = 1 if FR_num != FTC_num & !missing(FTC_num) & !missing(FR_num)

replace MDY_num = MR_num if flag == 1 // 27 cases
replace FTC_num = FR_num if flagFR == 1 // 3 cases

gen diff = 1 if MR_num != MDY_num 
gsort -diff

keep issuercus issuecus qdate Off_Date Mat_Date SPR_num SPRchange MR_num MRchange FR_num FRchange EGJ_num EGJchange DOM_num DOMchange
order issuercus issuecus qdate Off_Date Mat_Date SPR_num SPRchange MR_num MRchange FR_num FRchange EGJ_num EGJchange DOM_num DOMchange

sort issuecus qdate
}

save AllRatingsMERGEDfinal, replace

*************************************************
// MERGE with key MergentFISD Bond characteristics
*************************************************


import delimited "/Users/matthiashuber/Documents/HEC/1st Year Summer Paper/Bond ISSUES Dump.csv",clear

{
keep issue_id issuer_id issuer_cusip issue_cusip maturity convertible mtn asset_backed yankee foreign_currency offering_date offering_amt offering_date offering_price offering_yield redeemable putable private_placement isin preferred_stock_issuance preferred_security  sedol naics_code rule_144a parent_id bond_type

rename issue_cusip FullSuffix
rename issuer_cusip issuercus
gen issuecus = issuercus + FullSuffix
replace issuecus = substr(issuecus, 1,8)

keep issuecus issuercus issue_id issuer_id parent_id offering_amt convertible mtn asset_backed yankee redeemable putable private_placement isin preferred_security bond_type preferred_stock_issuance
order issuecus issuercus issue_id issuer_id parent_id offering_amt convertible mtn asset_backed yankee redeemable putable private_placement isin preferred_security bond_type preferred_stock_issuance

duplicates report issuecus // 1 duplicate
duplicates tag issuecus, gen(dup_tag)
gsort -dup_tag
drop dup_tag
drop if issuecus == "29357JAC" & convertible == "" // drop less informative duplicate observation
compress
save "/Users/matthiashuber/Documents/HEC/1st Year Summer Paper/MergentFISDBondData.dta",replace


use AllRatingsMERGEDfinal, clear

merge m:1 issuecus using "/Users/matthiashuber/Documents/HEC/1st Year Summer Paper/MergentFISDBondData.dta"
drop if _merge == 2 
drop _merge
order issuecus issuercus parent_id
save "/Users/matthiashuber/Documents/HEC/1st Year Summer Paper/FINALIssueRatings.dta", replace
}



*************************************************
// Import Watch Data
*************************************************

{
import excel using "/Users/matthiashuber/Documents/HEC/1st Year Summer Paper/MergentISSUELSEGWatch_pull 1.xlsx", sheet("Sheet2") firstrow clear
save sheet2_temp, replace

import excel using "/Users/matthiashuber/Documents/HEC/1st Year Summer Paper/MergentISSUELSEGWatch_pull 1.xlsx", sheet("Sheet3") firstrow clear
save sheet3_temp, 

use sheet2_temp, clear
append using sheet3_temp
save merged_issues, replace
erase sheet2_temp.dta
erase sheet3_temp.dta
drop if WatchType == "NULL"
drop if WatchType == "Unable to collect data for the field 'TR.GW.WatchType' and some specific identifier(s)."
rename Column1 issuecus
drop if missing(issuecus)
drop WatchType2
drop if WatchEndDate == "NULL"
drop if missing(WatchEndDate)
replace WatchTypeDescription = H if missing(WatchTypeDescription)
drop H
destring Date, replace
gen double Date_d = date(Date, "MDY")
drop Date
rename Date_d Date
format Date %td
gen qdatestart = qofd(Date)
format qdatestart %tq
destring WatchEndDate, replace
gen double WatchEndDate2 = date(WatchEndDate, "MDY")
drop WatchEndDate
rename WatchEndDate2 WatchEndDate
format WatchEndDate %td
gen qdateend = qofd(WatchEndDate)
format qdateend %tq
keep if inlist(RatingSource, "MDY", "FTC") // No Egan-Jones Watch available
drop WatchTypeDescription RatingSourceDescription
reshape wide WatchType WatchEndDate qdateend qdatestart, ///
    i(issuecus Date) j(RatingSource) string

save WatchData, replace

*************************************************
*** Moody's Watch
*************************************************

use WatchData, clear

keep issuecus Date WatchTypeMDY qdatestartMDY qdateendMDY 
order issuecus Date WatchTypeMDY qdatestartMDY qdateendMDY 
drop if missing(WatchType)

gen n_quarters = qdateendMDY - qdatestartMDY + 1
expand n_quarters
bysort issuecus qdatestartMDY: gen qdate = qdatestartMDY + _n - 1
format qdate %tq

order issuecus qdate
sort issuecus qdate
keep issuecus qdate Date WatchTypeMDY
compress
duplicates drop issuecus qdate, force // duplicate announcements of Watch Information
save WatchDataMDY, replace



*************************************************
*** Fitch Watch
*************************************************

use WatchData, clear

keep issuecus Date WatchTypeFTC qdatestartFTC qdateendFTC 
order issuecus Date WatchTypeFTC qdatestartFTC qdateendFTC 
drop if missing(WatchType)

gen n_quarters = qdateendFTC - qdatestartFTC + 1
expand n_quarters
bysort issuecus qdatestartFTC: gen qdate = qdatestartFTC + _n - 1
format qdate %tq

order issuecus qdate
sort issuecus qdate
keep issuecus qdate Date WatchTypeFTC
compress
duplicates drop issuecus qdate, force // duplicate announcements of Watch Information
save WatchDataFTC, replace

merge 1:1 issuecus qdate using "WatchDataMDY"
replace issuecus = substr(issuecus, 1, 8)
rename Date WatchDate
drop _merge
save WatchDataQuarterly, replace

}



*************************************************
// Import Outlook Data
*************************************************

{
import excel using "/Users/matthiashuber/Documents/HEC/1st Year Summer Paper/MergentISSUELSEGOutlook_pull 1.xlsx", sheet("Sheet2") firstrow clear
save sheet2_temp, replace

import excel using "/Users/matthiashuber/Documents/HEC/1st Year Summer Paper/MergentISSUELSEGOutlook_pull 1.xlsx", sheet("Sheet3") firstrow clear
save sheet3_temp, replace

use sheet2_temp, clear
append using sheet3_temp
save merged_issues, replace
erase sheet2_temp.dta
erase sheet3_temp.dta

rename A issuecus 
drop if Outlook == "NULL"
drop if Outlook == "Unable to collect data for the field 'TR.GO.Outlook' and some specific identifier(s)."
drop if missing(issuecus)
drop if OutlookEndDate == "NULL"

drop if missing(OutlookEndDate)
destring Date, replace
gen double Date_d = date(Date, "MDY")
drop RatingSourceDescription OutlookDescription Date
rename Date_d Date
format Date %td
gen qdatestart = qofd(Date)
format qdatestart %tq
destring OutlookEndDate, replace
gen double OutlookEndDate2 = date(OutlookEndDate, "MDY")
drop OutlookEndDate
rename OutlookEndDate2 OutlookEndDate
format OutlookEndDate %td
gen qdateend = qofd(OutlookEndDate)
format qdateend %tq
keep if inlist(OutlookRatingSourceCode, "MDY", "FTC") // No Egan-Jones Watch available
drop OutlookEndDate
reshape wide Outlook qdateend qdatestart, ///
    i(issuecus Date) j(OutlookRatingSourceCode) string
save OutlookData, replace

use OutlookData, clear


*************************************************
*** Moody's Outlook
*************************************************

use OutlookData, clear

keep issuecus Date OutlookMDY qdatestartMDY qdateendMDY 
order issuecus Date OutlookMDY qdatestartMDY qdateendMDY 
drop if missing(OutlookMDY)

gen n_quarters = qdateendMDY - qdatestartMDY + 1
expand n_quarters
bysort issuecus qdatestartMDY: gen qdate = qdatestartMDY + _n - 1
format qdate %tq

order issuecus qdate
sort issuecus qdate
keep issuecus qdate Date OutlookMDY
compress
duplicates drop issuecus qdate, force // duplicate announcements of Outlook Information
save OutlookDataMDY, replace


*************************************************
*** Fitch Watch
*************************************************

use OutlookData, clear

keep issuecus Date OutlookFTC qdatestartFTC qdateendFTC 
order issuecus Date OutlookFTC qdatestartFTC qdateendFTC 
drop if missing(OutlookFTC)

gen n_quarters = qdateendFTC - qdatestartFTC + 1
expand n_quarters
bysort issuecus qdatestartFTC: gen qdate = qdatestartFTC + _n - 1
format qdate %tq

order issuecus qdate
sort issuecus qdate
keep issuecus qdate Date OutlookFTC
compress
duplicates drop issuecus qdate, force // duplicate announcements of Outlook Information
save OutlookDataFTC, replace

merge 1:1 issuecus qdate using "OutlookDataMDY"
replace issuecus = substr(issuecus, 1, 8)
rename Date OutlookDate
drop _merge
save OutlookDataQuarterly, replace
}




/*

RatingSource	RatingSourceDescription

MDY	Moody's Long-term Issue Credit Rating
FUR	LSEG Internal (Fitch)
MUR	LSEG Internal (Moody's)
SUR	LSEG Internal (S&P)
FTC	Fitch Long-term Issue Credit Rating
EGJ	Egan-Jones Long-term Issue Credit Rating
FRR	Fitch Issue Recovery Rating
DOM	Dominion Bond Rating Service (DBRS) - Bond
R&I	R&I Long-term Issue Credit Rating
JCR	JCR Long-term Issue Credit Rating
FLN	Fitch Long-term National Scale Rating
MUN	Moody's Long-term Underlying Rating
FDR	Fitch Issue Distressed Recovery Rating
SRR	SR Rating
FIB	Fitch/IBCA
FUN	Fitch Long-term Unenhanced Rating
FTH	Fitch Ratings Thailand Limited
DPF	Dominion Bond Rating Service (DBRS) - Preferred Share
FST	Fitch Short-term Issue Credit Rating
MST	Moody's Short-term Issue Credit Rating
MLN	Moody's Long-term National Scale Rating
MGB	Moody's Green Bond Assessment
FLB	FIX SCR (Affiliate of Fitch Ratings) Long-term Issue National Scale Rating
DST	Dominion Bond Rating Service (DBRS) - Commercial Paper & Short-term Debt
FRL	Feller-Rate Long-term National Scale Rating
MDM	Moody's Mexico
BKW	Bankwatch
D&P	Duff & Phelps
FIT	Old Fitch
IBC	IBCA
CLA	Class & Asociados Long-term National Scale Rating
DGC	Dagong Short-term Issue Credit Rating
RNL	NRA Long-term Issue International Scale Credit Rating

*/





