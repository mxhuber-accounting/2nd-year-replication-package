********************************************************************
*** Merge_Variables.do  --  Reference catalog of optional merges.
***                          NOT part of the replication pipeline; illustrative only.
***                          (Filenames in the snippets may be stale examples.)
***
*** This file is NOT meant to be executed top-to-bottom. Every merge
*** snippet is commented out. To bring an additional variable into a
*** working dataset, copy the relevant block, paste it into the do-file
*** you are editing, uncomment, and replace /* INSERT */ with the
*** variable name(s) you want.
***
*** Match keys by source level:
***   bond-quarter       -> issuecus + qdate
***   issuer-quarter     -> issuercus + qdate
***   fund-quarter       -> fundid + qdate
***   firm-quarter       -> firmid + qdate
***   bond-fund-firm-q   -> issuecus + fundid + firmid + qdate
***
*** Each block also lists the variables known to live in that source
*** (non-exhaustive -- inspect the file directly when uncertain).
********************************************************************

clear all
set more off
set varabbrev off
version 17

* ============= SET PATHS =============
global root "${REPL}"
global comp "${root}/Data/eMAXX"                  // appended eMAXX *.dta
global rate "${root}/Data/MergentFISD"         // MergentFISD ratings + LSEG outlook/watch
global ciq  "${root}/Data/CapitalIQ"           // CapitalIQ outlook/watch
global wrds "${root}/Data/WRDS Bond Returns"               // WRDS bond yields, amount outstanding, spreads
global cds  "${root}/Data/Markit"                        // Markit CDS panel (issuer-quarter)
* Working-sample directory (set by setup.do: shipped / reference / raw).
* Falls back to Data/Working Files/ if run standalone without setup.do.
if "${wsdir}" == "" global wsdir "${root}/Data/Working Files"
global data "${wsdir}"                  // working files
* =====================================


/*
* ============================================================
* eMAXX SECMAST -- bond-quarter characteristics
* Match: issuecus + qdate           ${comp}/SECMAST_Complete.dta
* ------------------------------------------------------------
* Available (selection):
*   market            "C" = corporate
*   pvtplc            private placement flag
*   qmaturity         maturity quarter (built in Sample_Creation)
*   qissuance         issuance quarter
*   issue_paramt      eMAXX par amount issued
*   issue_netchange   eMAXX bond-quarter aggregate net change
*   issue_holdnum     number of holders this quarter
*   issue_buynum      number of buyers this quarter
*   issue_sellnum     number of sellers this quarter
*   issue_totparamt   aggregate eMAXX par held this quarter
* ============================================================

merge m:1 issuecus qdate using "${comp}/SECMAST_Complete.dta", ///
    keepusing(/* INSERT VARIABLES */) ///
    keep(master match) nogen
*/


/*
* ============================================================
* eMAXX FUND -- fund-quarter characteristics
* Match: fundid + qdate             ${comp}/FUND_Complete.dta
* ------------------------------------------------------------
* Available (selection):
*   fundclass         3-letter eMAXX class (LIN, PIN, MUT, ANN, ...)
*   fundtype          broad Goyal et al (2024) classification
*   fundtype_det      detailed classification (built in Sample_Creation)
*   passive           1 if fundname matches passive regex
*   fund_country      ISO country
*   fundname          (string; large)
*   fund_totparamt    aggregate par held by fund this quarter
*   fund_issenum      number of distinct issues held by fund
* ============================================================

merge m:1 fundid qdate using "${comp}/FUND_Complete.dta", ///
    keepusing(/* INSERT VARIABLES */) ///
    keep(master match) nogen
*/


/*
* ============================================================
* eMAXX FIRM -- firm-quarter characteristics
* Match: firmid + qdate             ${comp}/FIRM_Complete.dta
* ------------------------------------------------------------
* Available (selection):
*   firm_code, firm_country
*   firm_totparamt    aggregate par held by firm this quarter
*   firm_issenum      number of distinct issues held by firm
* ============================================================

merge m:1 firmid qdate using "${comp}/FIRM_Complete.dta", ///
    keepusing(/* INSERT VARIABLES */) ///
    keep(master match) nogen
*/


/*
* ============================================================
* eMAXX ISSUERS -- issuer-quarter characteristics
* Match: issuercus + qdate          ${comp}/ISSUERS_Complete.dta
* ------------------------------------------------------------
* Available (selection):
*   issuer_geocode    ISO country
*   issuer_creditsec  industry sector code (one-letter prefix)
* ============================================================

merge m:1 issuercus qdate using "${comp}/ISSUERS_Complete.dta", ///
    keepusing(/* INSERT VARIABLES */) ///
    keep(master match) nogen
*/


/*
* ============================================================
* eMAXX PERSONNEL -- portfolio manager data
* Match: issuercus + qdate          ${comp}/PERSONNEL_Complete.dta
* ------------------------------------------------------------
* Available (selection):
*   empid             employee identifier
*   firmid, fundid    cross-reference keys
* ============================================================

merge m:1 issuercus qdate using "${comp}/PERSONNEL_Complete.dta", ///
    keepusing(/* INSERT VARIABLES */) ///
    keep(master match) nogen
*/


/*
* ============================================================
* MergentFISD ratings panel -- bond-quarter ratings + bond chars
* Match: issuecus + qdate           ${rate}/MergentFISD_QuarterlyPanel.dta
* ------------------------------------------------------------
* Available (selection):
*   issuercus, parent_id, Off_Date, Mat_Date, offering_amt
*   bond_type, coupon
*   SPR_num, MR_num, FR_num, EGJ_num, DOM_num
*   SPRchange, MRchange, FRchange, EGJchange, DOMchange
*   private_placement, preferred_security, preferred_stock_issuance,
*   convertible, callable, putable
* ============================================================

merge m:1 issuecus qdate using "${rate}/MergentFISD_QuarterlyPanel.dta", ///
    keepusing(/* INSERT VARIABLES */) ///
    keep(master match) nogen
*/


/*
* ============================================================
* LSEG Watch data -- issue-level watch flags (sparse)
* Match: issuecus + qdate           ${rate}/WatchDataQuarterly.dta
* ------------------------------------------------------------
* Available:
*   WatchTypeFTC      Fitch  watch type
*   WatchTypeMDY      Moody's watch type
* ============================================================

merge m:1 issuecus qdate using "${rate}/WatchDataQuarterly.dta", ///
    keepusing(WatchTypeFTC WatchTypeMDY) ///
    keep(master match) nogen
*/


/*
* ============================================================
* LSEG Outlook data -- issue-level outlook flags (sparse)
* Match: issuecus + qdate           ${rate}/OutlookDataQuarterly.dta
* ------------------------------------------------------------
* Available:
*   OutlookFTC        Fitch outlook (NEG/POS/STA/...)
*   OutlookMDY        Moody's outlook
* ============================================================

merge m:1 issuecus qdate using "${rate}/OutlookDataQuarterly.dta", ///
    keepusing(OutlookFTC OutlookMDY) ///
    keep(master match) nogen
*/


/*
* ============================================================
* CapitalIQ -- issuer-quarter outlook / watch / rating actions
* Match: issuercus + qdate          ${ciq}/CapitalIQ_Final.dta
* ------------------------------------------------------------
* Available (selection):
*   CIQ_num                       S&P numeric rating (CapitalIQ)
*   outlook_num                   outlook numeric (-1 NEG, 0 STA, +1 POS)
*   watch_num                     watch numeric
*   n_rating_actions_q            count of rating actions in quarter
*   n_outlook_actions_q           count of outlook actions
*   n_watch_actions_q             count of watch actions
*   CIQ_change                    rating change magnitude
*   CIQ_downgrade, CIQ_upgrade    binary rating change flags
*   outlook_change                outlook level change
*   outlook_deterioration         binary outlook downgrade
*   outlook_improvement           binary outlook upgrade
*   watch_change                  watch level change
*   watch_deterioration           binary watch downgrade
*   watch_improvement             binary watch upgrade
* ============================================================

merge m:1 issuercus qdate using "${ciq}/CapitalIQ_Final.dta", ///
    keepusing(/* INSERT VARIABLES */) ///
    keep(master match) nogen
*/


/*
* ============================================================
* WRDS Bond Returns -- bond-quarter price, yield, TRACE volume
* Match: issuecus + qdate           ${wrds}/WRDS_Bond_Returns.dta
* ------------------------------------------------------------
* Available (selection):
*   amount_outstanding            par amount outstanding (USD)
*   yield                         quarterly yield (%)
*   qyield_last, qyield_avg       end-of-quarter / average yield
*   t_spread                      TRACE bid-ask spread
*   t_yld_pt                      TRACE yield (price-implied)
*   t_volume, t_dvolume           TRACE par / dollar volume
* ============================================================

merge m:1 issuecus qdate using "${wrds}/WRDS_Bond_Returns.dta", ///
    keepusing(/* INSERT VARIABLES */) ///
    keep(master match) nogen
*/


/*
* ============================================================
* Markit CDS -- issuer-quarter CDS spreads
* Match: issuercus + qdate          ${cds}/CDS_GVKEY_CUSIP.dta
* ------------------------------------------------------------
* Available (selection):
*   CDS_spread                    5Y senior unsecured CDS spread (bp)
*   avg_CDS_spread                quarterly average spread
*   sd_CDS_spread                 within-quarter spread vol
*   convspread                    conventional spread (Markit field)
*   shortname                     reference entity short name
* ============================================================

merge m:1 issuercus qdate using "${cds}/CDS_GVKEY_CUSIP.dta", ///
    keepusing(/* INSERT VARIABLES */) ///
    keep(master match) nogen
*/


/*
* ============================================================
* MergentFISD bond-level ratings panel (alternative source)
* Match: issuecus + qdate           ${rate}/FINALIssueRatings.dta
* ------------------------------------------------------------
*   Use this when MergentFISD_QuarterlyPanel.dta is missing a field
*   that the issue-rating master file carries.
* ============================================================

merge m:1 issuecus qdate using "${rate}/FINALIssueRatings.dta", ///
    keepusing(/* INSERT VARIABLES */) ///
    keep(master match) nogen
*/


********************************************************************
*** End -- copy any block above into your working do-file as needed.
********************************************************************
