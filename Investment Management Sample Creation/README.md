# Investment Management Sample Creation

An **optional** sample that augments the main working sample with eMAXX
**personnel** (portfolio managers / investment-management staff). It is a
sibling of `Sample Replication` and `Paper Replication` and is not required to
reproduce the paper.

## What it does
Takes the working sample built by `Sample Replication/Sample_Creation.do`
(`Data/Working Files/eMAXXMergentFISD_SampleFinalCDS_WV.dta`) and attaches the
eMAXX personnel file (`Data/eMAXX/PERSONNEL_Complete.dta`), keyed on
**`fundid firmid qdate`**.

## Why `joinby` (not `merge`)
`PERSONNEL_Complete` is at the **employee × fund × firm × quarter** level — there
are **multiple managers per fund-firm-quarter** — so the using side is not unique
on `(fundid firmid qdate)` and a `merge m:1` is impossible. The do-file uses
`joinby` (many-to-many) and `unmatched(master)`, because not every fund-firm-quarter
has a personnel record and those holdings must be retained, not dropped.

## Grain switch
At the top of `IM_Sample_Creation.do`:

| `local grain` | Operation | Result |
|---|---|---|
| `"manager"` (default) | `joinby fundid firmid qdate` | one row per **holding × manager** — the panel **expands** (can be very large) |
| `"team"` | collapse personnel → fund-firm-quarter summary, then `merge m:1` | panel size **unchanged**; team-size + role counts/indicators only |

> ⚠️ In `"manager"` grain the output is `_WV` multiplied by managers-per-firm and
> can be tens of GB. Use `"team"` if you only need team size / PM presence.

## Role flags
Built from the eMAXX 3-letter `job_code` (first-pass taxonomy — refine as needed):
`is_pm` (PM\* portfolio managers), `is_cio`, `is_head`, `is_research`,
`is_trader`, `is_exec` (excluded), and `is_im` = any investment professional.

## How to run
1. Edit the `${REPL}` line in `setup.do`, run `setup.do`.
2. Run `0_run_im_sample.do`.

**Output:** `Data/Working Files/eMAXXMergentFISD_IM_Sample.dta`
(plus the dedup'd `Data/Working Files/PERSONNEL_FundFirmQtr.dta`).
