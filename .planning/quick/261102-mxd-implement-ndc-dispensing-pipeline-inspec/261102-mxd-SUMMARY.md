---
phase: quick
plan: 261102-mxd
subsystem: ndc-dispensing
tags: [ndc, chemo, ancillary, seer-rx, dispensing, fix-17]
tech-stack:
  added: []
  patterns: [00_build_* reference builder pattern, ndc9 normalization join]
key-files:
  created:
    - R/00_build_ndc.R
    - tests/testthat/test_00_ndc.R
  modified:
    - R/01_import.R
    - R/02_clean.R
    - R/03_exposure.R
    - reference/README.md
    - docs/DATA_LINEAGE.md
    - docs/plans/fix-list.md
decisions:
  - "Follow V5_12 != '1' rule exactly: Hormonal Therapy (code 4) counts as chemo_disp; documented as TODO(ERIN)"
  - "No date window on dispensing-to-reference join (V5_12 has none)"
  - "Save both 02_dispensing_patids.rds (backward-compat) and 02_dispensing_ndc.rds (new NDC join)"
metrics:
  duration: ~180s
  completed: 2026-11-02
  tasks: 4
  files: 8
---

# Quick Task 261102-mxd: NDC Dispensing SEER*Rx Chemo/Ancillary Pipeline

**One-liner:** SEER*Rx NDC reference builder with ndc9 join deriving real chemo_disp (codes 2-6) / anc_disp (code 1) patient flags per SAS V5_12 rule, replacing all-dispensing-as-chemo stub.

## Tasks Completed

| Task | Name | Status | Commit |
|------|------|--------|--------|
| 1 | Create R/00_build_ndc.R and wire into 01_import.R | DONE | ec4e900 |
| 2 | Keep NDC in 02_clean.R and wire real chemo_disp/anc_disp in 03_exposure.R | DONE | ec4e900 |
| 3 | Update docs and fix-list | DONE | ec4e900 |
| 4 | Commit and push | DONE | ec4e900 |

## What Was Built

### R/00_build_ndc.R (new)
Follows the `00_build_sdi.R` / `00_build_ruca.R` builder pattern exactly:
- Fail-fast `stop()` if `reference/ndconc_results_new.csv` missing
- Reads all columns as text (`col_character()`); `clean_names()` for snake_case
- Builds `ndc9` key: strip non-digits from `NDC_9_Product_`, take first 9 chars
  - "72205-0061" -> strip dash -> "722050061" (reference key)
  - "72205006101" -> first 9 -> "722050061" (dispensing match)
- Recodes `SEERRxCategory` text -> `seer_cat_code` 1-6 per SAS V5_12 `$seer` format
- Logs: unmapped categories, ndc9 ambiguity (>1 code), per-code tabyl
- Saves `01_imported_ndc.rds` (distinct ndc9 x seer_cat_code)

### R/01_import.R (modified)
- Added GROUP 8c: `source(here::here("R", "00_build_ndc.R"))` after SDI block
- Added `01_imported_ndc.rds` to imported datasets summary message

### R/02_clean.R (modified)
- Section 4c: replaced patid-only reduction with full NDC normalization
  - Computes `ndc9 = substr(str_remove_all(ndc, "[^0-9]"), 1, 9)` for each dispensing row
  - Logs ndc9 length distribution (detects 7/8-char non-standard codes pre-dedup)
  - Saves `02_dispensing_ndc.rds` (distinct patid + ndc9 + ndc_raw)
  - Keeps `02_dispensing_patids.rds` (backward-compat; patid only)

### R/03_exposure.R (modified)
- Inputs header: added `01_imported_ndc.rds` and `02_dispensing_ndc.rds`
- Section 2: loads `ndc_ref` and `dispensing_ndc` (replaces `dispensing_patids` load)
- Section 3 (dispensing flags): real SEER*Rx join
  - `disp_cat`: left_join dispensing_ndc to ndc_ref on ndc9
  - Logs unmatched NDC counts by ndc_len (7/8-char non-standard + 9-char no-match)
  - `disp_flags`: patient-level `chemo_disp` (codes 2-6) and `anc_disp` (code 1)
  - All-dispensing-as-chemo EDGE CASE stub removed
- Section 7 (ancillary): `anc = if_else(anc_disp == 1L, 1L, 0L)` (real SEERRx rule)
  - "No other treatment" stub removed

### tests/testthat/test_00_ndc.R (new)
5 unit tests -- all pass (FAIL 0):
- NDC-01: dashed reference "72205-0061" -> ndc9 "722050061"
- NDC-02: 11-digit dispensing "72205006101" first-9 equals reference ndc9 (join match)
- NDC-03: "Hormonal Therapy" -> code "4" -> chemo_disp=1, anc_disp=0
- NDC-04: "Ancillary Therapy" -> code "1" -> anc_disp=1, chemo_disp=0
- NDC-05: unmatched NDC -> NA code -> chemo_disp=0, anc_disp=0

### Docs updated
- `reference/README.md`: table row for `ndconc_results_new.csv` + sheets-used note
- `docs/DATA_LINEAGE.md`: `ndc_cond2.sas7bdat` marked RESOLVED; TODO(ERIN) block on Hormonal Therapy corticosteroids counted as chemo under V5_12 rule
- `docs/plans/fix-list.md`: row #17 marked DONE

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| Follow V5_12 `!= "1"` rule exactly (Hormonal Therapy = chemo) | SAS source is unambiguous; deviation requires clinical confirmation |
| No date window on NDC join | V5_12 dispensing join has no dispense_date filter |
| Save both dispensing_patids and dispensing_ndc | Preserve backward-compat for any consumer of patid-only table |

## Deviations from Plan

None -- plan executed exactly as written.

## Self-Check: PASSED

- R/00_build_ndc.R exists (confirmed write)
- tests/testthat/test_00_ndc.R exists with 5 passing tests (FAIL 0 | PASS 13 verified)
- R/01_import.R sources 00_build_ndc.R and lists 01_imported_ndc.rds
- R/02_clean.R and R/03_exposure.R parse without error (parse OK verified)
- No "all dispensing = chemo" or "no other treatment" stub text in 03_exposure.R (grep verified)
- reference/README.md contains ndconc_results_new (docs OK verified)
- docs/DATA_LINEAGE.md contains prednisone/corticosteroid TODO(ERIN) (docs OK verified)
- docs/plans/fix-list.md row #17 DONE
- Commit ec4e900 exists on master; pushed to origin (git push verified)
