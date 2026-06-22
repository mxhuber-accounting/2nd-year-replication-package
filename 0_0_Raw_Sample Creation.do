**********************************************************************
**# Bookmark #1
*       1) Import and Process all HOLDING.txt files
*       2) Append all HOLDING files from 1999-2023 into one dataset  
*       Source: eMAXX Quarterly Files FTP                 
**********************************************************************

{
*       1) Import and Process all HOLDING.txt files
**********************************************************************
global root "C:\Users\Student\Desktop\Matthias eMAXX\Raw Data"

forvalues y = 1999/2023 {
    forvalues q = 1/4 {
        local period "`y'Q`q'"
        di as txt "----------------------------------------------------------"
        di as result "Processing quarter: `period'"
        di as txt "----------------------------------------------------------"

       import delimited "${root}\ASCII_NAEur_Mkt_All_Pipe_RN_`period'\HOLDING.txt", clear
        gen issuecus = cusip + cusipsuff
        drop cusip cusipsuff
        order issuecus firmid fundid
        sort issuecus firmid fundid
        capture confirm string variable fundid
        if !_rc destring fundid, replace
        capture confirm numeric variable bool
        if !_rc tostring bool, replace
        gen daily = date(bool, "YMD")
        format daily %td
        gen qreport = qofd(daily)
        format qreport %tq
        rename daily reportdate
            drop reportdate 
        drop bool
        gen qdate = yq(`y', `q')
        format qdate %tq
        compress
        save "${root}\ASCII_NAEur_Mkt_All_Pipe_RN_`period'\HOLDING.dta", replace
 }
 }
 
*       2) Append all HOLDING files from 1999-2023 into one dataset
**********************************************************************
clear all
global root "C:\Users\Student\Desktop\Matthias eMAXX\Raw Data"
global outdir "C:\Users\Student\Desktop\Matthias eMAXX\Complete Files"

use "${root}\ASCII_NAEur_Mkt_All_Pipe_RN_1999Q1\HOLDING.dta", clear

forvalues y = 1999/2023 {
    forvalues q = 1/4 {
        local period = "`y'Q`q'"
        if "`period'" == "1999Q1" continue
        local filepath = "${root}\ASCII_NAEur_Mkt_All_Pipe_RN_`period'\HOLDING.dta"
        capture confirm file "`filepath'"
        if !_rc {
            append using "`filepath'"
        }
    }
}
compress
save "${outdir}\HOLDING_Complete.dta", replace
 


***********************************************************************
**# Bookmark #2
*       1) Import and Process all FIRM/FUND/SECMAST/ISSUER.txt files
*       2) Append all Firm, Fund, Issue and Issuer files from 1999-2023 into separate datasets  
* 	 	3) Import and Process all Personnel Data files   
*       Source: eMAXX Quarterly Files FTP                 
**********************************************************************


*       1) Import and Process all FIRM/FUND/SECMAST/ISSUER.txt files
**********************************************************************

global root "C:\Users\Student\Desktop\Matthias eMAXX\Raw Data"

forvalues y = 1999/2023 {
          forvalues q = 1/4 {
        local period "`y'Q`q'"
        di as txt "----------------------------------------------------------"
        di as result "Processing quarter: `period'"
        di as txt "----------------------------------------------------------"
            
            // Firm Variables
            import delimited "${root}\ASCII_NAEur_Mkt_All_Pipe_RN_`period'\FIRM.txt", clear
        drop firmalpha firmphone firmfax addr1 addr2 city stateacro zip m_addr1 m_addr2 m_city m_st m_zip phonecd
        capture confirm string variable firmid
        if !_rc destring firmid, replace
        rename totparamt firm_totparamt
        rename issuenum firm_issenum
        rename country firm_country
            gen qdate = yq(`y', `q')
            format qdate %tq
        compress
        save "${root}\ASCII_NAEur_Mkt_All_Pipe_RN_`period'\FIRM.dta", replace

            // Fund Variables
        import delimited "${root}\ASCII_NAEur_Mkt_All_Pipe_RN_`period'\FUND.txt", clear
        drop fundalpha sector sub_code
        capture confirm numeric variable bool
        if !_rc tostring bool, replace
        gen daily = date(bool, "YMD")
        format daily %td
        gen qreport = qofd(daily)
        format qreport %tq
        rename daily reportdate
        drop bool
        capture confirm string variable firmid
        if !_rc destring firmid, replace
        rename totparamt fund_totparamt
        rename issuenum fund_issenum
        rename ctry_code fund_country
            gen qdate = yq(`y', `q')
            format qdate %tq
        compress
        save "${root}\ASCII_NAEur_Mkt_All_Pipe_RN_`period'\FUND.dta", replace
            
            // Issue Variables
            import delimited "${root}\ASCII_NAEur_Mkt_All_Pipe_RN_`period'\SECMAST.txt", clear
            drop issuedesc cpnrate cpnstru coll source  pledge moodyrat sprat fitchrat dprat // Rating Fields are empty
        drop if missing(issuesuf)
        gen issuecus = issuercus + issuesuf
        drop issuercus issuesuf
        capture confirm numeric variable matdate
        if !_rc tostring matdate, replace
        gen mat_date = date(matdate, "YMD")
        format mat_date %td
        gen qmaturity = qofd(mat_date)
        format qmaturity %tq
        drop matdate
        capture confirm numeric variable datedissdt
        if !_rc tostring datedissdt, replace
        gen issuance_date = date(datedissdt, "YMD")
        format issuance_date %td
        gen qissuance = qofd(issuance_date)
        format qissuance %tq
        drop datedissdt
        rename paramt issue_paramt
        rename netchange issue_netchange
        rename totparamt issue_totparamt
        rename holdnum issue_holdnum
        rename buynum issue_buynum
        rename sellnum issue_sellnum
            gen qdate = yq(`y', `q')
        format qdate %tq
        compress
        save "${root}\ASCII_NAEur_Mkt_All_Pipe_RN_`period'\SECMAST.dta", replace

            // Issuer Variables
            import delimited "${root}\ASCII_NAEur_Mkt_All_Pipe_RN_`period'\ISSUERS.txt", clear
            drop issuernam entity state alfsrt 
            capture confirm variable v9
            if !_rc {
                  drop v9
            }
        rename creditsec issuer_creditsec
        rename geocode issuer_geocode
            gen qdate = yq(`y', `q')
        format qdate %tq
        compress
        save "${root}\ASCII_NAEur_Mkt_All_Pipe_RN_`period'\Issuers.dta", replace
            
            
 }
 }

 
*       2) Append all Firm, Fund, Issue and Issuer files from 1999-2023 into separate datasets 
**********************************************************************  
 
// Append Firm Data
clear all
global root "C:\Users\Student\Desktop\Matthias eMAXX\Raw Data"
global outdir "C:\Users\Student\Desktop\Matthias eMAXX\Complete Files"

use "${root}\ASCII_NAEur_Mkt_All_Pipe_RN_1999Q1\FIRM.dta", clear

forvalues y = 1999/2023 {
    forvalues q = 1/4 {
        local period = "`y'Q`q'"
        if "`period'" == "1999Q1" continue
        local filepath = "${root}\ASCII_NAEur_Mkt_All_Pipe_RN_`period'\FIRM.dta"
        capture confirm file "`filepath'"
        if !_rc {
            append using "`filepath'"
        }
    }
}
compress
drop v21
save "${outdir}\FIRM_Complete.dta", replace


// Append Fund Data
use "${root}\ASCII_NAEur_Mkt_All_Pipe_RN_1999Q1\FUND.dta", clear

forvalues y = 1999/2023 {
    forvalues q = 1/4 {
        local period = "`y'Q`q'"
        if "`period'" == "1999Q1" continue
        local filepath = "${root}\ASCII_NAEur_Mkt_All_Pipe_RN_`period'\FUND.dta"
        capture confirm file "`filepath'"
        if !_rc {
            append using "`filepath'"
        }
    }
}
compress
save "${outdir}\FUND_Complete.dta", replace


// Append Issue Data
use "${root}\ASCII_NAEur_Mkt_All_Pipe_RN_1999Q1\SECMAST.dta", clear

forvalues y = 1999/2023 {
    forvalues q = 1/4 {
        local period = "`y'Q`q'"
        if "`period'" == "1999Q1" continue
        local filepath = "${root}\ASCII_NAEur_Mkt_All_Pipe_RN_`period'\SECMAST.dta"
        capture confirm file "`filepath'"
        if !_rc {
            append using "`filepath'"
        }
    }
}

compress
order issuecus qdate market pvtplc mat_date qmaturity issuance_date qissuance issue_paramt issue_netchange issue_holdnum issue_buynum issue_sellnum issue_totparamt
save "${outdir}\SECMAST_Complete.dta", replace


// Append Issuer Data
use "${root}\ASCII_NAEur_Mkt_All_Pipe_RN_1999Q1\ISSUERS.dta", clear

forvalues y = 1999/2023 {
    forvalues q = 1/4 {
        local period = "`y'Q`q'"
        if "`period'" == "1999Q1" continue
        local filepath = "${root}\ASCII_NAEur_Mkt_All_Pipe_RN_`period'\ISSUERS.dta"
        capture confirm file "`filepath'"
        if !_rc {
            append using "`filepath'"
        }
    }
}
compress
save "${outdir}\ISSUERS_Complete.dta", replace



*       3) Import and Process all Personnel Data files
**********************************************************************
{
clear all
global root "C:\Users\Student\Desktop\Matthias eMAXX\Raw Data"
global outdir "C:\Users\Student\Desktop\Matthias eMAXX\Complete Files"

use "${root}\ASCII_NAEur_Mkt_All_Pipe_RN_1999Q1\PER_JOB.dta", clear

forvalues y = 1999/2023 {
    forvalues q = 1/4 {
        local period = "`y'Q`q'"
        if "`period'" == "1999Q1" continue
        local filepath = "${root}\ASCII_NAEur_Mkt_All_Pipe_RN_`period'\PER_JOB.dta"
        capture confirm file "`filepath'"
        if !_rc {
            append using "`filepath'"
        }
    }
}
compress
save "${outdir}\PER_JOB.dta", replace

clear all
global root "C:\Users\Student\Desktop\Matthias eMAXX\Raw Data"
global outdir "C:\Users\Student\Desktop\Matthias eMAXX\Complete Files"

use "${root}\ASCII_NAEur_Mkt_All_Pipe_RN_1999Q1\PER_DATA.dta", clear

forvalues y = 1999/2023 {
    forvalues q = 1/4 {
        local period = "`y'Q`q'"
        if "`period'" == "1999Q1" continue
        local filepath = "${root}\ASCII_NAEur_Mkt_All_Pipe_RN_`period'\PER_DATA.dta"
        capture confirm file "`filepath'"
        if !_rc {
            append using "`filepath'"
        }
    }
}
compress
save "${outdir}\PER_DATA.dta", replace

clear all
global root "C:\Users\Student\Desktop\Matthias eMAXX\Raw Data"
global outdir "C:\Users\Student\Desktop\Matthias eMAXX\Complete Files"

use "${root}\ASCII_NAEur_Mkt_All_Pipe_RN_1999Q1\PER_FUND.dta", clear

forvalues y = 1999/2023 {
    forvalues q = 1/4 {
        local period = "`y'Q`q'"
        if "`period'" == "1999Q1" continue
        local filepath = "${root}\ASCII_NAEur_Mkt_All_Pipe_RN_`period'\PER_FUND.dta"
        capture confirm file "`filepath'"
        if !_rc {
            append using "`filepath'"
        }
    }
}
compress
save "${outdir}\PER_FUND.dta", replace

// Merge Personnel Data

use "${outdir}\PER_JOB.dta", clear
merge n:1 empid qdate using "${outdir}\PER_DATA.dta", nogen

duplicates drop empid qdate firmid, force // Duplicates arise from managing multiple geo or firm codes, as there are no description files explaining the codes this data is dropped
duplicates report empid qdate firmid
compress
save "${outdir}\PER_JOBDATA.dta", replace


use "${outdir}\PER_FUND.dta", clear
merge n:1 empid qdate firmid  using "${outdir}\PER_JOBDATA.dta", keep(master match) nogen
compress
duplicates report empid firmid fundid qdate
save "${outdir}\PERSONNEL_Complete.dta", replace
}



**********************************************************************
**# Bookmark #3
*       1) Clean And Prepare FUND Variables  
*       2) Clean And Prepare FIRM Variables              
**********************************************************************


*       1) Clean And Prepare FUND Files 
**********************************************************************

use "D:\DATA\Complete Files\FUND_Complete.dta", clear

// Drop Duplicates Following Goyal et al. (2024
sort fundid qdate 
bysort fundid qdate (qreport): keep if _n == 1

// Generate Fundtypes Following Goyal et al. (2024)
gen fundtype = ""
replace fundtype = "INS" if inlist(fundclass,"INS","LIN","PIN","RIN") // Alternatively include HLC 
replace fundtype = "MUT" if inlist(fundclass,"ANN","AMM","BAL","MMM","MUT","END","QUI","FOF","UIT")
replace fundtype = "PEN" if inlist(fundclass,"CPF","GPE","UPE")
replace fundtype = "OTHER" if missing(fundtype)
tabulate fundtype
label variable fundtype "eMAXX Broad Fund Type Classification"
order fundid fundclass fundtype

// Generate Passive/ Active Fund Classification Goyal et al. (2024)
gen fundname_l = lower(fundname)
gen byte passive = regexm(fundname_l, ///
    "index|indx|etf|etn|exchange|bloomberg|ftse|boxx|ishares.*bond")
drop fundname_l
// The list of keywords includes (1) words related to ETFs and index fund names (e.g., INDEX, INDX, ETF, ETN, EXCHANGE); (2) words related to bond index providers (e.g., BLOOMBERG, FTSE, BOXX, ISHARES%BOND%).

save "D:\DATA\Complete Files\FUND_Complete.dta", replace


// For all of the following variables, merging them with holding data is only possible using qdate and NOT qreport, this may result in some inconsistencies to be paid attention to, as the primary inidicator can NOT be the more exact qreport anymore 

*       2) Clean And Prepare FIRM Variables              
**********************************************************************

use "D:\DATA\Complete Files\FIRM_Complete.dta", clear
duplicates drop firmid qdate, force

*       3) Clean And Prepare SECMAST Variables              
**********************************************************************
use "D:\DATA\Complete Files\SECMAST_Complete.dta", clear
duplicates drop issuecus qdate, force


*       3) Clean And Prepare SECMAST Variables              
**********************************************************************
use "D:\DATA\Complete Files\ISSUERS_Complete.dta", clear
duplicates drop issuercus qdate, force
save "D:\DATA\Complete Files\ISSUERS_Complete.dta", replace

}



**********************************************************************
**# Bookmark #2
*       1) Create Corporate Sample
*       2) Limit to MergentFISD Bonds              
**********************************************************************

global root "D:\DATA\Complete Files" // Path to Complete Files
global outdir "D:\DATA" // Directory for the Working File

{

*       1) Create Corporate Sample            
**********************************************************************
use "${root}\HOLDING_Complete.dta", clear

keep if regexm(issuecus, "^[A-Za-z0-9]+$") // drop unidentifiable bonds

// Drop Duplicates following Goyal et al. (2024)
drop if firmid == "CO-MANAGED"
bysort issuecus fundid firmid qdate (qreport): keep if _n == 1

merge m:1 issuecus qdate using "${root}\SECMAST_Complete.dta", ///
    keepusing(market) ///
    keep(master match) ///
    nogen
keep if market == "C"
drop market

merge m:1 fundid qdate using "${root}\FUND_Complete.dta", ///
    keepusing(fundclass fundtype passive) ///
    keep(master match) ///
    nogen
	
merge m:1 firmid qdate using "${root}\FIRM_Complete.dta", ///
    keepusing(firm_code) ///
    keep(master match) ///
    nogen

save "${root}\HOLDING_CompleteCORP.dta", replace

**********************************************************************
**# Bookmark #1
*       1) Merge eMAXX to MergentFISD Ratings         
*       2) Merge eMAXX to MergentFISD Ratings         
**********************************************************************

global root "/Users/matthiashuber/Library/CloudStorage/Dropbox-HECPARIS/Matthias Huber/Matthias-Pepa-Vedran/Rating Data/MergentFISD"
global wf   "/Users/matthiashuber/Library/CloudStorage/Dropbox-HECPARIS/Matthias Huber/Replication 2026/Working Files"
global outdir global root "/Users/matthiashuber/Library/CloudStorage/Dropbox-HECPARIS/Matthias Huber/Matthias-Pepa-Vedran"

use "${wf}/MergentFISD_QuarterlyPanel.dta", clear 

merge 1:m issuecus qdate using "${root}\HOLDING_CompleteCORP.dta", ///
    keep(master match) ///
    nogen
keep issuecus issuercus qreport qdate fundid firmid  paramt net_change parent_id Off_Date Mat_Date offering_amt bond_type SPR_num SPRchange MR_num MRchange FR_num FRchange EGJ_num EGJchange DOM_num DOMchange private_placement preferred_security preferred_stock_issuance convertible

order issuecus issuercus parent_id qdate fundid firmid paramt net_change Off_Date Mat_Date offering_amt private_placement preferred_security preferred_stock_issuance convertible
sort issuecus issuercus parent_id qdate

unique issuecus 
unique issuercus 
unique fundid

// Variable Labels
{
label variable issuecus     "Issue CUSIP"
label variable issuercus    "Issuer CUSIP"
label variable qdate        "eMAXX Quarter"
label variable qreport     "eMAXX Reporting quarter"
label variable fundid       "eMAXX Fund ID"
label variable firmid       "eMAXX Firm ID"
label variable paramt       "eMAXX Par amount held"
label variable net_change  "eMAXX Net change in par amount held"
label variable parent_id    "MergentFISD Parent of Issuer"
label variable Off_Date     "MergentFISD Bond offering date"
label variable Mat_Date     "MergentFISD Bond maturity date"
label variable offering_amt "MergentFISD Bond offering amount"
label variable bond_type   "MergentFISDBond type"
label variable SPR_num      "MergentFISD S&P Numeric Bond Rating"
label variable SPRchange   "Change in S&P Rating (< 0 for Downgrades) "
label variable MR_num       "MergentFISD Moody's Numeric Bond Rating"
label variable MRchange    "Change in Moody's Rating (< 0 for Downgrades) "
label variable FR_num       "MergentFISD Fitch Numeric Bond Rating"
label variable FRchange    "Change in Fitch Rating (< 0 for Downgrades)"
label variable EGJ_num      "LSEG EganJones Numeric Bond Rating"
label variable EGJchange   "Change in EganJones Rating (< 0 for Downgrades)"
label variable DOM_num      "LSEG Dominion Numeric Bond Rating"
label variable DOMchange   "Change in Dominion Rating (< 0 for Downgrades)"
}

save "${outdir}\eMAXXMergentFISD.dta", replace

**********************************************************************
**# Bookmark #2
*       1) OPTIONAL: Merge any additional characteristics from eMAXX  
*       2) OPTIONAL: Merge any additional characteristics from MergentFISD
*       3) OPTIONAL: Merge any Outlook and Watch Data from LSEG          
**********************************************************************

*       1) OPTIONAL: Merge any additional characteristics from eMAXX 
**********************************************************************
use "${outdir}\eMAXXMergentFISD.dta", clear

/*
// Bond Characteristics
* Choose Variables: use "${root}\SECMAST_Complete.dta", clear 
clear all
merge m:1 issuecus qdate using "${root}\SECMAST_Complete.dta", ///
    keepusing(*INSERT VARIABLEs HERE*) ///
    keep(master match) ///
    nogen
 
// Fund Characteristics
* Choose Variables: use "${root}\FUND_Complete.dta", clear 
merge m:1 fundid qdate using "${root}\FUND_Complete.dta", ///
    keepusing(*INSERT VARIABLES HERE*) ///
    keep(master match) ///
    nogen

// Firm Characteristics 
* Choose Variables: use "${root}\FIRM_Complete.dta", clear 
merge m:1 firmid qdate using "${root}\FIRM_Complete.dta", ///
    keepusing(firm_country) ///
    keep(master match) ///
	nogen

// Issuer Characteristics
 * Choose Variables: use "${root}\ISSUERS_Complete.dta", clear
merge m:1 issuercus qdate using "${root}\ISSUERS_Complete.dta", ///
    keepusing(*INSERT VARIABLES HERE*) ///
    keep(master match) ///
	nogen
*/

// Personnel Characteristics
 * Choose Variables: use "${root}\PERSONNEL_Complete.dta", clear
merge m:1 issuercus qdate using "${root}\PERSONNEL_Complete.dta", ///
    keepusing(*INSERT VARIABLES HERE*) ///
    keep(master match) ///
	nogen
*/
	
*       2) OPTIONAL: Merge any additional characteristics from MergentFISD 
**********************************************************************

/*
// MergentFISD Bond and Rating Characteristics
merge m:1 issuecus qdate using "${root}\FINALIssueRatings.dta", ///
    keepusing(*INSERT VARIABLEs HERE*) ///
    keep(master match) ///
	nogen
*/

*       3) OPTIONAL: Merge any Outlook and Watch Data from LSEG 
*       ! appear to be quite few outlook and watch actions 
**********************************************************************


// LSEG Watch Data
merge m:1 issuecus qdate using "${root}\WatchDataQuarterly.dta", ///
	keepusing(WatchTypeFTC WatchTypeMDY) /// 
    keep(master match) ///
	nogen

// LSEG Outlook Data
merge m:1 issuecus qdate using "${root}\OutlookDataQuarterly.dta", ///
	keepusing(OutlookFTC OutlookMDY) ///
    keep(master match) ///
	nogen
	
// Code Outlook Data
foreach v in outlookMR watchMR outlookFR watchFR {
    gen `v' = 0
}

replace outlookMR = -1   if upper(OutlookMDY) == "NEG"
replace outlookMR =  1   if upper(OutlookMDY) == "POS"
replace outlookMR = -0.5 if upper(OutlookMDY) == "RUR"
replace watchMR = -1 if upper(WatchTypeMDY) == "DNG"
replace watchMR =  1 if upper(WatchTypeMDY) == "UPG"
replace outlookFR = -1 if upper(OutlookFTC) == "NEG"
replace outlookFR =  1 if upper(OutlookFTC) == "POS"
replace watchFR = -1 if upper(WatchTypeFTC) == "NEG"
replace watchFR =  1 if upper(WatchTypeFTC) == "POS"

gen outlookMR_neg = (outlookMR == -1)
gen outlookMR_pos = (outlookMR == 1)
gen watchMR_neg   = (watchMR == -1)
gen watchMR_pos   = (watchMR == 1)
gen outlookFR_neg = (outlookFR == -1)
gen outlookFR_pos = (outlookFR == 1)
gen watchFR_neg   = (watchFR == -1)
gen watchFR_pos   = (watchFR == 1)

drop OutlookMDY WatchTypeMDY OutlookFTC WatchTypeFTC
	



**********************************************************************
**# Bookmark #3
*       1) MergeYield Data from WRDS
*       2) Final Adjustments to the Sample      
**********************************************************************

*       1) MergeYield Data from WRDS
**********************************************************************

merge m:1 issuecus qdate using "${root}\WRDS Bond Returns.dta", ///
	keepusing(amount_outstanding qyield_last qyield_avg t_volume t_dvolume t_spread t_yld_pt yield) ///
    keep(master match) ///
	nogen


*       2) Final Adjustments to the Sample      
**********************************************************************


/*	 
// OPTIONAL: Restrict to Corporate Bonds following https://www.tidy-finance.org/r/trace-and-fisd.html
keep if inlist(bond_type, "CDEB", "CMTN", "CMTZ", "CZ") // Restrict to Corporate Bonds following 
*/

// Merge Issuer and Fund Country to Restrict to US Sample

merge m:1 fundid qdate using "${root}\FUND_Complete.dta", ///
    keepusing(fundname fundclass fund_country) ///
    keep(master match) ///
	nogen
	
merge m:1 issuercus qdate using "${root}\ISSUERS_Complete.dta", ///
    keepusing(issuer_geocode issuer_creditsec) ///
    keep(master match) ///
	nogen

merge m:1 firmid qdate using "${root}\FIRM_Complete.dta", ///
    keepusing(firm_code firm_country) ///
    keep(master match) ///
    nogen
	


compress 
save "${outdir}\eMAXXMergentFISD_WV.dta", replace










		
		


