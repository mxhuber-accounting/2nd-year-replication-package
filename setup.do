********************************************************************************
*** setup.do  --  Replication Package master path file
***
*** Institutional Bondholdings: Anticipation of Credit Rating Downgrades by
*** Long-Horizon Investors  (Matthias Xaver Huber, HEC Paris)
***
*** HOW TO USE:
***   Reproducers edit ONLY the ${REPL} line below to point at the unzipped
***   replication package. Every other path is derived from it. Each do-file in
***   "1 Sample Replication" and "2 Paper Replication" starts by running this
***   file, so paths are defined in exactly one place.
********************************************************************************

* ============================ EDIT THIS ONE LINE ============================
global REPL "/Users/matthiashuber/Library/CloudStorage/Dropbox-HECPARIS/Matthias Huber/Replication Package"
* ===========================================================================

* ---- Data root and source databases -------------------------------------
global data     "${REPL}/Data"
global emaxx     "${data}/eMAXX"               // eMAXX holdings (Complete .dta) + Raw eMAXX/
global mergent   "${data}/MergentFISD"         // MergentFISD rating panels + IssuesLookup
global capiq     "${data}/CapitalIQ"           // CapitalIQ outlook/watch panel
global wrds      "${data}/WRDS Bond Returns"   // WRDS bond yields, amount outstanding, spreads
global markit    "${data}/Markit"              // Markit CDS panel
global working   "${data}/Working Files"       // sample outputs: SampleFinalCDS, _WV, _master
global refdir    "${data}/Reference Files"     // the four FROZEN reference inputs (read-only)

* ====================== REPRODUCTION MODE =================================
* "reference"  = use the four FROZEN safety files in Data/ root  -> reproduces
*                the EXACT paper findings. (default)
* "regenerate" = use the freshly rebuilt source outputs from Sample Replication.
global mode "reference"

* ---- FROZEN reference files in Data/Reference Files/ -- DO NOT OVERWRITE --
* These four reproduce the exact paper results. "1 Sample Replication" writes
* ONLY to Data/<source>/ and Working Files/ -- it never touches these.
global ref_mergent "${refdir}/MergentFISD_QuarterlyPanel.dta"
global ref_capiq   "${refdir}/CapitalIQ_Final.dta"
global ref_cds     "${refdir}/CDS_2012_2020_GVKEY-CUSIP.dta"
global ref_wrds    "${refdir}/WRDS_Bond_Returns.dta"

* Enforce read-only on the four reference files 
cap shell chmod 444 "${ref_mergent}" "${ref_capiq}" "${ref_cds}" "${ref_wrds}"
di as text  "{hline 78}"
di as result "  FROZEN reference files (Data/Reference Files/) are READ-ONLY -> exact paper results."
di as text   "  Sample reproduction writes only to Data/<source>/ and never overwrites them."
di as text  "{hline 78}"

* ---- Canonical source inputs consumed by Sample_Creation.do -------------
if "${mode}" == "reference" {
    global in_mergent "${ref_mergent}"
    global in_capiq   "${ref_capiq}"
    global in_cds     "${ref_cds}"
    global in_wrds    "${ref_wrds}"
}
else {
    global in_mergent "${mergent}/MergentFISD_QuarterlyPanel_2012-2023.dta"
    global in_capiq   "${capiq}/CapitalIQ_Final.dta"
    global in_cds     "${markit}/CDS_2012_2020_GVKEY-CUSIP.dta"
    global in_wrds    "${wrds}/WRDS_Bond_Returns.dta"
}
* =========================================================================

* ---- Output -------------------------------------------------------------
global figtab    "${REPL}/Paper Replication/Figures and Tables"

* ---- Final Adjustments -------------------------------------------------------
set more off
cap mkdir "${working}"
cap mkdir "${figtab}"
