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

* ========================= EDIT THESE TWO SETTINGS =========================
* (1) WHERE — point this at the unzipped replication package on this machine:
global REPL "/Users/matthiashuber/Library/CloudStorage/Dropbox-HECPARIS/Matthias Huber/Replication Package"

* (2) WHICH SAMPLE — which working sample the paper run (0_run_paper.do) uses:
*       "shipped"   = the PREBUILT sample already in Data/Working Files/
*                     (fast; reproduces the paper).  [DEFAULT]
*       "reference" = REBUILD the sample from the FROZEN reference vendor files
*                     -> writes to  Data/Working Files/Rebuilt_reference/
*       "raw"       = REBUILD every vendor database from raw, then the sample
*                     -> writes to  Data/Working Files/Rebuilt_raw/   (slow)
*     Rebuilds go to their OWN subfolder and NEVER overwrite the shipped files.
global mode "shipped"
* ===========================================================================

if !inlist("${mode}", "shipped", "reference", "raw") {
    di as error `"setup.do: global mode must be "shipped", "reference", or "raw" (got "${mode}")."'
    exit 198
}
di as result _n "  Working sample (mode) = ${mode}    [shipped = prebuilt | reference/raw = rebuilt to a subfolder]" _n

* ---- Data root and source databases -------------------------------------
global data     "${REPL}/Data"
global emaxx     "${data}/eMAXX"               // eMAXX holdings (Complete .dta) + Raw eMAXX/
global mergent   "${data}/MergentFISD"         // MergentFISD rating panels + IssuesLookup
global capiq     "${data}/CapitalIQ"           // CapitalIQ outlook/watch panel
global wrds      "${data}/WRDS Bond Returns"   // WRDS bond yields, amount outstanding, spreads
global markit    "${data}/Markit"              // Markit CDS panel
global working   "${data}/Working Files"       // sample outputs: SampleFinalCDS, _WV, _master
global refdir    "${data}/Reference Files"     // the four FROZEN reference inputs (read-only)

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
* (Only used by a "reference"/"raw" rebuild; "shipped" never runs Sample_Creation.)
if inlist("${mode}", "shipped", "reference") {
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

* ---- Working-sample directory (the SAFETY LAYER) ------------------------
* All of {SampleFinalCDS, _WV, _master} for the chosen sample live in ${wsdir}.
* "shipped" uses Data/Working Files/ as-is; rebuilds go to a Rebuilt_* subfolder
* so the prebuilt files are never overwritten.
if      "${mode}" == "shipped"   global wsdir "${working}"
else if "${mode}" == "reference" global wsdir "${working}/Rebuilt_reference"
else                             global wsdir "${working}/Rebuilt_raw"
cap mkdir "${working}"
cap mkdir "${wsdir}"
* =========================================================================

* ---- Output -------------------------------------------------------------
global figtab    "${REPL}/Paper Replication/Figures and Tables"
global paperfigs "${figtab}/Tables and Figures in Paper"   // curated, numbered subset used in the paper

* ---- Required user-written commands (installed once, only if missing) -------
* Each check tests a command that proves the package is present, then installs
* it if absent. NOTE: egenmore has no eponymous command, so we test its _gnvals
* helper; reghdfe also pulls in ftools; grc1leg is not on SSC.
capture which reghdfe
if _rc ssc install reghdfe, replace
capture which ftools
if _rc ssc install ftools, replace
capture which hashsort
if _rc ssc install gtools, replace
capture which esttab
if _rc ssc install estout, replace
capture which coefplot
if _rc ssc install coefplot, replace
capture which winsor2
if _rc ssc install winsor2, replace
capture which _gnvals
if _rc ssc install egenmore, replace
capture which distinct
if _rc ssc install distinct, replace
capture which unique
if _rc ssc install unique, replace
capture which grc1leg
if _rc net install grc1leg, from("http://www.stata.com/users/vwiggins") replace

* ---- Final Adjustments -------------------------------------------------------
set more off
cap mkdir "${working}"
cap mkdir "${figtab}"
cap mkdir "${paperfigs}"
