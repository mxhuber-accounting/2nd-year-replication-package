**********************************************************************
**# Bookmark #1
*       1) Import and Process all HOLDING.txt files
*       2) Append all HOLDING files from 1999-2023 into one dataset  
*       Source: eMAXX Quarterly Files FTP                 
**********************************************************************


global root "${REPL}/Data/eMAXX/Raw eMAXX"
global outdir "${REPL}/Data/eMAXX/"

{
*       1) Import and Process all HOLDING.txt files
**********************************************************************

forvalues y = 1999/2023 {
    forvalues q = 1/4 {
        local period "`y'Q`q'"

       import delimited "${root}/ASCII_NAEur_Mkt_All_Pipe_RN_`period'/HOLDING.txt", clear
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
        save "${root}/ASCII_NAEur_Mkt_All_Pipe_RN_`period'/HOLDING.dta", replace
 }
 }
 
*       2) Append all HOLDING files from 1999-2023 into one dataset
**********************************************************************


use "${root}/ASCII_NAEur_Mkt_All_Pipe_RN_1999Q1/HOLDING.dta", clear

forvalues y = 1999/2023 {
    forvalues q = 1/4 {
        local period = "`y'Q`q'"
        if "`period'" == "1999Q1" continue
        local filepath = "${root}/ASCII_NAEur_Mkt_All_Pipe_RN_`period'/HOLDING.dta"
        capture confirm file "`filepath'"
        if !_rc {
            append using "`filepath'"
        }
    }
}
compress
save "${outdir}/HOLDING_Complete.dta", replace
 


***********************************************************************
**# Bookmark #2
*       1) Import and Process all FIRM/FUND/SECMAST/ISSUER.txt files
*       2) Append all Firm, Fund, Issue and Issuer files from 1999-2023 into separate datasets  
* 	 	3) Import and Process all Personnel Data files   
*       Source: eMAXX Quarterly Files FTP                 
**********************************************************************


*       1) Import and Process all FIRM/FUND/SECMAST/ISSUER.txt files
**********************************************************************


forvalues y = 1999/2023 {
          forvalues q = 1/4 {
        local period "`y'Q`q'"
            
           /// Firm Variables
            import delimited "${root}/ASCII_NAEur_Mkt_All_Pipe_RN_`period'/FIRM.txt", clear
        drop firmalpha firmphone firmfax addr1 addr2 city stateacro zip m_addr1 m_addr2 m_city m_st m_zip phonecd
        capture confirm string variable firmid
        if !_rc destring firmid, replace
        rename totparamt firm_totparamt
        rename issuenum firm_issenum
        rename country firm_country
            gen qdate = yq(`y', `q')
            format qdate %tq
        compress
        save "${root}/ASCII_NAEur_Mkt_All_Pipe_RN_`period'/FIRM.dta", replace

         /// Fund Variables
        import delimited "${root}/ASCII_NAEur_Mkt_All_Pipe_RN_`period'/FUND.txt", clear
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
        save "${root}/ASCII_NAEur_Mkt_All_Pipe_RN_`period'/FUND.dta", replace
            
            /// Issue Variables
            import delimited "${root}/ASCII_NAEur_Mkt_All_Pipe_RN_`period'/SECMAST.txt", clear
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
        save "${root}/ASCII_NAEur_Mkt_All_Pipe_RN_`period'/SECMAST.dta", replace

            // Issuer Variables
            import delimited "${root}/ASCII_NAEur_Mkt_All_Pipe_RN_`period'/ISSUERS.txt", clear
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
        save "${root}/ASCII_NAEur_Mkt_All_Pipe_RN_`period'/Issuers.dta", replace
            
            
 }
 }

 
*       2) Append all Firm, Fund, Issue and Issuer files from 1999-2023 into separate datasets 
**********************************************************************  
 
// Append Firm Data

use "${root}/ASCII_NAEur_Mkt_All_Pipe_RN_1999Q1/FIRM.dta", clear

forvalues y = 1999/2023 {
    forvalues q = 1/4 {
        local period = "`y'Q`q'"
        if "`period'" == "1999Q1" continue
        local filepath = "${root}/ASCII_NAEur_Mkt_All_Pipe_RN_`period'/FIRM.dta"
        capture confirm file "`filepath'"
        if !_rc {
            append using "`filepath'"
        }
    }
}
compress
cap drop v21
save "${outdir}/FIRM_Complete.dta", replace


// Append Fund Data
use "${root}/ASCII_NAEur_Mkt_All_Pipe_RN_1999Q1/FUND.dta", clear

forvalues y = 1999/2023 {
    forvalues q = 1/4 {
        local period = "`y'Q`q'"
        if "`period'" == "1999Q1" continue
        local filepath = "${root}/ASCII_NAEur_Mkt_All_Pipe_RN_`period'/FUND.dta"
        capture confirm file "`filepath'"
        if !_rc {
            append using "`filepath'"
        }
    }
}
compress
save "${outdir}/FUND_Complete.dta", replace


// Append Issue Data
use "${root}/ASCII_NAEur_Mkt_All_Pipe_RN_1999Q1/SECMAST.dta", clear

forvalues y = 1999/2023 {
    forvalues q = 1/4 {
        local period = "`y'Q`q'"
        if "`period'" == "1999Q1" continue
        local filepath = "${root}/ASCII_NAEur_Mkt_All_Pipe_RN_`period'/SECMAST.dta"
        capture confirm file "`filepath'"
        if !_rc {
            append using "`filepath'"
        }
    }
}

compress
order issuecus qdate market pvtplc mat_date qmaturity issuance_date qissuance issue_paramt issue_netchange issue_holdnum issue_buynum issue_sellnum issue_totparamt
save "${outdir}/SECMAST_Complete.dta", replace


// Append Issuer Data
use "${root}/ASCII_NAEur_Mkt_All_Pipe_RN_1999Q1/ISSUERS.dta", clear

forvalues y = 1999/2023 {
    forvalues q = 1/4 {
        local period = "`y'Q`q'"
        if "`period'" == "1999Q1" continue
        local filepath = "${root}/ASCII_NAEur_Mkt_All_Pipe_RN_`period'/ISSUERS.dta"
        capture confirm file "`filepath'"
        if !_rc {
            append using "`filepath'"
        }
    }
}
compress
save "${outdir}/ISSUERS_Complete.dta", replace



*       3) Import and Process all Personnel Data files
**********************************************************************
{

*  3a) Import each personnel .txt -> per-period .dta (mirrors the FIRM/FUND/etc.
*      blocks above: add qdate from the period and normalize id types). Each
*      import is guarded with `confirm file`, so quarters that have no personnel
*      file are skipped instead of erroring.
forvalues y = 1999/2023 {
    forvalues q = 1/4 {
        local period "`y'Q`q'"
        foreach f in PER_JOB PER_DATA PER_FUND {
            capture confirm file "${root}/ASCII_NAEur_Mkt_All_Pipe_RN_`period'/`f'.txt"
            if _rc continue
            import delimited "${root}/ASCII_NAEur_Mkt_All_Pipe_RN_`period'/`f'.txt", clear
            capture confirm string variable firmid
            if !_rc destring firmid, replace
            capture confirm string variable fundid
            if !_rc destring fundid, replace
            gen qdate = yq(`y', `q')
            format qdate %tq
            compress
            save "${root}/ASCII_NAEur_Mkt_All_Pipe_RN_`period'/`f'.dta", replace
        }
    }
}

*  3b) Append each personnel file across quarters into one dataset
use "${root}/ASCII_NAEur_Mkt_All_Pipe_RN_1999Q1/PER_JOB.dta", clear

forvalues y = 1999/2023 {
    forvalues q = 1/4 {
        local period = "`y'Q`q'"
        if "`period'" == "1999Q1" continue
        local filepath = "${root}/ASCII_NAEur_Mkt_All_Pipe_RN_`period'/PER_JOB.dta"
        capture confirm file "`filepath'"
        if !_rc {
            append using "`filepath'"
        }
    }
}
compress
save "${outdir}/PER_JOB.dta", replace


use "${root}/ASCII_NAEur_Mkt_All_Pipe_RN_1999Q1/PER_DATA.dta", clear

forvalues y = 1999/2023 {
    forvalues q = 1/4 {
        local period = "`y'Q`q'"
        if "`period'" == "1999Q1" continue
        local filepath = "${root}/ASCII_NAEur_Mkt_All_Pipe_RN_`period'/PER_DATA.dta"
        capture confirm file "`filepath'"
        if !_rc {
            append using "`filepath'"
        }
    }
}
compress
save "${outdir}/PER_DATA.dta", replace


use "${root}/ASCII_NAEur_Mkt_All_Pipe_RN_1999Q1/PER_FUND.dta", clear

forvalues y = 1999/2023 {
    forvalues q = 1/4 {
        local period = "`y'Q`q'"
        if "`period'" == "1999Q1" continue
        local filepath = "${root}/ASCII_NAEur_Mkt_All_Pipe_RN_`period'/PER_FUND.dta"
        capture confirm file "`filepath'"
        if !_rc {
            append using "`filepath'"
        }
    }
}
compress
save "${outdir}/PER_FUND.dta", replace

// Merge Personnel Data

use "${outdir}/PER_JOB.dta", clear
merge n:1 empid qdate using "${outdir}/PER_DATA.dta", nogen

duplicates drop empid qdate firmid, force // Duplicates arise from managing multiple geo or firm codes, as there are no description files explaining the codes this data is dropped
duplicates report empid qdate firmid
compress
save "${outdir}/PER_JOBDATA.dta", replace


use "${outdir}/PER_FUND.dta", clear
merge n:1 empid qdate firmid  using "${outdir}/PER_JOBDATA.dta", keep(master match) nogen
compress
duplicates report empid firmid fundid qdate
save "${outdir}/PERSONNEL_Complete.dta", replace
}



**********************************************************************
**# Bookmark #3
*       1) Clean And Prepare FUND Variables  
*       2) Clean And Prepare FIRM Variables              
**********************************************************************


*       1) Clean And Prepare FUND Files 
**********************************************************************

use "${outdir}/FUND_Complete.dta", clear

// Drop Duplicates Following Goyal et al. (2024)
sort fundid qdate 
bysort fundid qdate (qreport): keep if _n == 1

save "${outdir}/FUND_Complete.dta", replace


*       2) Clean And Prepare FIRM Variables              
**********************************************************************

use "${outdir}/FIRM_Complete.dta", clear
duplicates drop firmid qdate, force
save "${outdir}/FIRM_Complete.dta", replace

*       3) Clean And Prepare SECMAST Variables              
**********************************************************************
use "${outdir}/SECMAST_Complete.dta", clear
duplicates drop issuecus qdate, force
save "${outdir}/SECMAST_Complete.dta", replace


*       3) Clean And Prepare SECMAST Variables              
**********************************************************************
use "${outdir}/ISSUERS_Complete.dta", clear
duplicates drop issuercus qdate, force
save "${outdir}/ISSUERS_Complete.dta", replace






