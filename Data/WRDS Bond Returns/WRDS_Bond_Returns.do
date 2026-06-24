**********************************************************************
**# Bookmark #2
*       1) Prepare WRDS Bond Returns Data
**********************************************************************

global root "${REPL}/Data/WRDS Bond Returns"

*       1) Prepare WRDS Bond Returns Data
**********************************************************************

import delimited "${root}/Raw Data/WRDS Bond Returns.csv",clear

gen daily = date(date, "YMD")
format daily %td
gen qdate = qofd(daily)
format qdate %tq
replace cusip = substr(cusip, 1, 8)
rename cusip issuecus 
gen t_dvolumenum = 0
replace t_dvolumenum = real(subinstr(subinstr(t_dvolume, "$", "", .), ",", "", .))
format t_dvolumenum %15.0fc
drop t_dvolume
rename t_dvolumenum t_dvolume

gen t_volumenum = 0
replace t_volumenum = real(subinstr(subinstr(t_volume, "$", "", .), ",", "", .))
format t_volumenum %15.0fc
drop t_volume
rename t_volumenum t_volume

gen yield_num = real(subinstr(yield, "%", "", .))
drop yield 
rename yield_num yield

gen t_spread_num = real(subinstr(t_spread, "%", "", .))
drop t_spread 
rename t_spread_num t_spread

order issuecus issue_id amount_outstanding daily qdate t_date t_volume t_dvolume t_spread t_yld_pt yield price_eom price_ldm price_l5m ret_eom ret_ldm ret_l5m

// Last Yield Per Quarter

sort issuecus qdate daily

by issuecus qdate: gen byte last_in_q = (_n == _N) 
gen qyield_last = yield if last_in_q
by issuecus qdate: replace qyield_last = qyield_last[_N]
drop last_in_q

// Average Yield Per Quarter 
by issuecus qdate: egen qyield_avg = mean(yield)


// Collapse to Quarterly Data w/o compounded returns 
collapse ///
    (sum) ///
        t_volume ///
        t_dvolume ///
    (last) ///
	    daily ///
        qyield_last ///
        yield ///
        t_yld_pt ///
        t_spread ///
        price_eom ///
        price_ldm ///
        price_l5m ///
        duration ///
        tmt ///
        remcoups ///
        defaulted ///
        default_date ///
        default_type ///
        reinstated ///
        reinstated_date ///
		r_sp r_mr r_fr ///
        n_sp n_mr n_fr ///
        rating_num ///
        rating_cat ///
        rating_class ///
    (first) ///
        issue_id ///
        amount_outstanding ///
        bond_sym_id ///
        bsym ///
        isin ///
        company_symbol ///
        bond_type ///
        security_level ///
        conv ///
        offering_date ///
        offering_amt ///
        offering_price ///
        principal_amt ///
        maturity ///
        treasury_maturity ///
        coupon ///
        day_count_basis ///
        dated_date ///
        first_interest_date ///
        last_interest_date ///
        ncoups ///
        gap ///
        coupmonth ///
        nextcoup ///
        coupamt ///
        coupacc ///
        multicoups ///
        qyield_avg ///
    , by(issuecus qdate)

label variable issuecus "Issue CUSIP"
label variable qdate    "Quarter"
label variable t_volume  "WRDS Total Quarterly Trading Volume (Units)"
label variable t_dvolume "WRDS Total Quarterly Trading Volume in Dollars"
label variable qyield_last "WRDS End-of-Quarter Bond Yield"
label variable qyield_avg  "WRDS Average Bond Yield Within Quarter"
label variable yield       "WRDS Bond Yield (Quarter-End)"
label variable t_yld_pt    "Average trade‐weighted yield point(Quarter-End)"
label variable t_spread    "WRDS Credit Spread over Treasury (Quarter-End)"
label variable price_eom "WRDS End-of-Month Bond Price (Quarter-End)"
label variable price_ldm "WRDS Bond Price (Last Day of Month, Quarter-End)"
label variable price_l5m "WRDS Bond Price (5th Last Trading Day, Quarter-End)"
label variable duration "WRDS Modified Duration (Quarter-End)"
label variable tmt      "WRDS Time to Maturity in Years (Quarter-End)"
label variable remcoups "WRDS Remaining Number of Coupon Payments"
label variable defaulted        "WRDS Bond Default Indicator (Quarter-End)"
label variable default_date     "WRDS Bond Default Date"
label variable default_type     "WRDS Bond Default Type"
label variable reinstated       "WRDS Bond Reinstatement Indicator"
label variable reinstated_date  "WRDS Bond Reinstatement Date"
label variable rating_num   "WRDS Composite Numeric Bond Rating"
label variable rating_cat   "WRDS Composite Alphabetic Bond Rating"
label variable rating_class "WRDS Investment Grade Indicator"
label variable r_sp "WRDS S&P Bond Rating"
label variable r_mr "WRDS Moody's Bond Rating"
label variable r_fr "WRDS Fitch Bond Rating"
label variable n_sp "WRDS S&P Numeric Rating"
label variable n_mr "WRDS Moody's Numeric Rating"
label variable n_fr "WRDS Fitch Numeric Rating"
label variable issue_id           "WRDS Internal Bond Issue Identifier"
label variable amount_outstanding "WRDS Bond Amount Outstanding"
label variable bond_sym_id        "WRDS Bond Symbol Identifier"
label variable bsym               "WRDS Bond Symbol"
label variable isin               "WRDS ISIN"
label variable company_symbol     "WRDS Issuer Ticker Symbol"
label variable bond_type          "WRDS Bond Type"
label variable security_level     "WRDS Bond Security Level"
label variable conv               "WRDS Convertible Bond Indicator"
label variable offering_date  "WRDS Bond Offering Date"
label variable offering_amt   "WRDS Bond Offering Amount"
label variable offering_price "WRDS Bond Offering Price"
label variable principal_amt  "WRDS Bond Principal Amount"
label variable maturity           "WRDS Bond Maturity Date"
label variable treasury_maturity  "WRDS Reference Treasury Maturity"
label variable coupon             "WRDS Bond Coupon Rate"
label variable day_count_basis    "WRDS Bond Day Count Convention"
label variable dated_date          "WRDS Bond Dated Date"
label variable first_interest_date "WRDS First Interest Payment Date"
label variable last_interest_date  "WRDS Last Interest Payment Date"
label variable ncoups              "WRDS Number of Coupon Payments per Year"
label variable gap        "WRDS Coupon Gap Indicator"
label variable coupmonth "WRDS Coupon Payment Month"
label variable nextcoup  "WRDS Next Coupon Payment Date"
label variable coupamt   "WRDS Coupon Payment Amount"
label variable coupacc   "WRDS Accrued Coupon Amount"
label variable multicoups "WRDS Multiple Coupon Indicator"

order issuecus qdate amount_outstanding qyield_last qyield_avg t_volume t_dvolume t_spread t_yld_pt yield price_eom price_ldm price_l5m
save "${root}/WRDS_Bond_Returns.dta", replace
