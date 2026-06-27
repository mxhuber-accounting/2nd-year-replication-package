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

* ============== CHOOSE THE SAMPLE-CREATION SOURCE (pick one) ==============
* The ONLY choice the reproducer makes besides ${REPL} above. It controls how
* "Sample Replication/0_run_sample.do" builds the working sample:
*
*   "reference" = build the sample from the FROZEN reference vendor files in
*                 Data/Reference Files/   (fast; reproduces the paper). DEFAULT.
*   "raw"       = rebuild every vendor database from raw vendor data first,
*                 then build the sample (slow, several hours).
*
* The paper run (Paper Replication/0_run_paper.do) is identical either way.
global mode "reference"

if !inlist("${mode}", "reference", "raw") {
    di as error `"setup.do: global mode must be "reference" or "raw" (got "${mode}")."'
    exit 198
}

* ---- FROZEN reference inputs -- DO NOT OVERWRITE --
* These reproduce the exact paper results. Sample creation writes ONLY to
* Data/<source>/ and Working Files/ -- it never touches these.
*   MergentFISD reference = the rich FINALIssueRatings panel (ratings + bond
*   characteristics), kept with its build script in
*   Data/MergentFISD/Paper Reference File/.  The other three are in
*   Data/Reference Files/.
global ref_mergent "${mergent}/Paper Reference File/FINALIssueRatings.dta"
global ref_capiq   "${refdir}/CapitalIQ_Final.dta"
global ref_cds     "${refdir}/CDS_2012_2020_GVKEY-CUSIP.dta"
global ref_wrds    "${refdir}/WRDS_Bond_Returns.dta"

* Enforce read-only on the four reference files 
cap shell chmod 444 "${ref_mergent}" "${ref_capiq}" "${ref_cds}" "${ref_wrds}"
di as text  "{hline 78}"
di as result "  FROZEN reference inputs are READ-ONLY -> exact paper results."
di as text   "  Sample reproduction writes only to Data/<source>/ and never overwrites them."
di as text  "{hline 78}"

* ---- Canonical source inputs consumed by Sample_Creation.do -------------
if "${mode}" == "reference" {
    global in_mergent "${ref_mergent}"
    global in_capiq   "${ref_capiq}"
    global in_cds     "${ref_cds}"
    global in_wrds    "${ref_wrds}"
}
else {   // "raw" -- freshly rebuilt source outputs from Sample Replication
    global in_mergent "${mergent}/MergentFISD_QuarterlyPanel_2012-2023.dta"
    global in_capiq   "${capiq}/CapitalIQ_Final.dta"
    global in_cds     "${markit}/CDS_2012_2020_GVKEY-CUSIP.dta"
    global in_wrds    "${wrds}/WRDS_Bond_Returns.dta"
}
* =========================================================================

* ---- Output -------------------------------------------------------------
global figtab    "${REPL}/Paper Replication/Figures and Tables"
global paperfigs "${figtab}/Tables and Figures in Paper"   // curated, numbered subset used in the paper

* ---- Final Adjustments -------------------------------------------------------
set more off
cap mkdir "${working}"
cap mkdir "${figtab}"
cap mkdir "${paperfigs}"
