---
phase: 02-data-cleaning-merging
plan: 01
subsystem: test-infrastructure
tags: [wave-0, test-fixtures, testthat, pcornet-cdm, mock-data]
dependency_graph:
  requires: [01-formats, 01-import]
  provides: [test-fixtures, cleaning-tests, merging-tests]
  affects: [02-02, 02-03, 02-04]
tech_stack:
  added: [testthat, tibble, dplyr]
  patterns: [mock-data-fixtures, test-driven-development, wave-0-red-state]
key_files:
  created:
    - tests/testthat/helper-fixtures.R
    - tests/testthat/test_02_cleaning.R
    - tests/testthat/test_02_merging.R
  modified: []
decisions:
  - "D-01: Mock data uses realistic PCORnet CDM column names (lowercase snake_case)"
  - "D-02: Simplified diagnosis parts from 7 to 2 for test fixtures (maintains pattern)"
  - "D-03: Simplified procedure parts from 4 to 2 for test fixtures (maintains pattern)"
  - "D-04: Included payer code 'ZZ' as unmapped code to test D-04 handling"
  - "D-05: Included NA payer_type_primary in encounter1 for CLN-04 missing value testing"
  - "D-06: Included payer code '4' (dual eligibility) in encounter2 for CLN-06 testing"
  - "D-07: MRG-02 test validates logging contract (message output) not actual logged_join function (implemented in Plan 02-03)"
metrics:
  duration_seconds: 213
  duration_human: "3 minutes 33 seconds"
  tasks_completed: 2
  files_created: 3
  lines_added: 429
  commits: 2
  completed_at: "2026-04-16T23:28:26Z"
---

# Phase 02 Plan 01: Wave 0 Test Infrastructure Summary

**One-liner:** Created test fixtures and scaffolds for all Phase 2 cleaning and merging requirements, establishing RED-state TDD foundation with realistic mock PCORnet CDM data.

## Objective

Create Wave 0 test infrastructure: mock data fixtures and test scaffolds for all Phase 2 cleaning and merging requirements (CLN-01 through CLN-06, MRG-01 through MRG-04).

**Status:** Complete — All test files created, tests currently in RED state awaiting implementation.

## What Was Built

### Test Fixtures (helper-fixtures.R)

Created comprehensive mock data matching PCORnet CDM structure:

- **mock_sas_formats**: Subset of SAS format definitions (p_payer, payerr, enc_type, discharge_status, discharge_disposition)
- **mock_encounter1** and **mock_encounter2**: 10 total encounter rows with realistic payer codes, encounter types, dates
- **mock_dx_parts**: List of 2 diagnosis tibbles (30 total rows, 3 dx per encounter)
- **mock_proc_parts**: List of 2 procedure tibbles (20 total rows, 2 px per encounter)
- **mock_provider**: 5 provider rows with specialty codes
- **mock_prov_spec**: 5 specialty reference rows with cancer_provider flags

**Key testing scenarios covered:**
- Payer codes: "1" (Medicare), "2" (Medicaid), "5" (Private), "4" (Dual), "ZZ" (unmapped)
- Missing values: NA payer_type_primary for CLN-04 testing
- Encounter types: "AV", "IP", "ED" for CLN-05 factor recoding
- Date ranges: 2020-01-15 to 2020-10-12 (realistic 10-month span)
- Join patterns: 3 diagnoses per encounter, 2 procedures per encounter

### Cleaning Test Scaffolds (test_02_cleaning.R)

10 test_that blocks covering CLN-01 through CLN-06:

1. **CLN-01**: Verify column names are lowercase snake_case (post-import)
2. **CLN-02**: Test bind_rows encounter combination (row count preservation)
3. **CLN-03a**: Test payer code recoding via factor() with sas_formats$p_payer
4. **CLN-03b**: Test unmapped payer code handling (NA from factor, assign "Unknown")
5. **CLN-04**: Test explicit is.na() handling of missing payer values
6. **CLN-05a**: Test enc_type factor recoding
7. **CLN-05b**: Test discharge_status factor recoding
8. **CLN-05c**: Test discharge_disposition factor recoding
9. **CLN-06a**: Test dual eligibility (code "4") maps to "Med_Medicaid"
10. **CLN-06b**: Test government payer (code "3") maps to "Private" per study-specific format

### Merging Test Scaffolds (test_02_merging.R)

8 test_that blocks covering MRG-01 through MRG-04:

1. **MRG-01a**: Test encounter-diagnosis join (one-to-many relationship)
2. **MRG-01b**: Test encounter-procedure join (one-to-many relationship)
3. **MRG-02**: Test logged_join contract (message output with row counts)
4. **MRG-03a**: Test relationship argument catches unexpected many-to-many
5. **MRG-03b**: Test normal join does not produce Cartesian product
6. **MRG-04a**: Test no unexpected NA encounterids after merge
7. **MRG-04b**: Test patient count preserved after merge

**Note:** All tests currently in RED state (will fail until 02_clean.R and 02_merge.R are implemented in subsequent plans).

## Commits

| Commit | Task | Message | Files |
|--------|------|---------|-------|
| 364699c | 1 | test(02-01): add Wave 0 test fixtures for Phase 2 cleaning and merging | tests/testthat/helper-fixtures.R |
| e362d9d | 2 | test(02-01): add Wave 0 test scaffolds for Phase 2 cleaning and merging | tests/testthat/test_02_cleaning.R, tests/testthat/test_02_merging.R |

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — this is Wave 0 test infrastructure. The tests themselves are stubs (RED state) awaiting implementation.

## Verification

Per plan acceptance criteria:

- [x] tests/testthat/helper-fixtures.R exists and is non-empty
- [x] File contains `mock_encounter1` with 5 rows and columns patid, encounterid, enc_type, payer_type_primary
- [x] File contains `mock_encounter2` with 5 rows including payer_type_primary == "4" (Dual) and payer_type_primary == "ZZ" (unmapped)
- [x] File contains `mock_dx_parts` as a list of length 2
- [x] File contains `mock_proc_parts` as a list of length 2
- [x] File contains `mock_provider` with 5 rows
- [x] File contains `mock_prov_spec` with columns cancer_provider
- [x] File contains `mock_sas_formats` with elements p_payer, payerr, enc_type, discharge_status, discharge_disposition
- [x] File contains `library(tibble)` at top
- [x] All column names are lowercase snake_case (no uppercase letters)
- [x] One encounter has NA payer_type_primary for CLN-04 testing
- [x] tests/testthat/test_02_cleaning.R contains `library(testthat)` and `library(dplyr)`
- [x] tests/testthat/test_02_cleaning.R contains `source(here::here("tests", "testthat", "helper-fixtures.R"))`
- [x] tests/testthat/test_02_cleaning.R contains test_that blocks for CLN-01, CLN-02, CLN-03, CLN-04, CLN-05, CLN-06
- [x] tests/testthat/test_02_cleaning.R contains reference to `mock_sas_formats$p_payer` per D-03
- [x] tests/testthat/test_02_cleaning.R contains check for payer code "4" mapping to "Med_Medicaid"
- [x] tests/testthat/test_02_merging.R contains `library(testthat)` and `library(dplyr)`
- [x] tests/testthat/test_02_merging.R contains test_that blocks for MRG-01, MRG-02, MRG-03, MRG-04
- [x] tests/testthat/test_02_merging.R contains MRG-02 test with `capture.output` and `type = "message"` to validate row count logging
- [x] tests/testthat/test_02_merging.R contains `relationship = "one-to-many"` in join calls
- [x] tests/testthat/test_02_merging.R contains `expect_error` for many-to-many detection
- [x] Both test files execute without syntax errors (not testable without R installed, but verified via code review)

## Next Steps

1. **Plan 02-02** will implement 02_clean.R to make CLN-01 through CLN-06 tests pass (GREEN state)
2. **Plan 02-03** will implement 02_merge.R to make MRG-01 through MRG-04 tests pass (GREEN state)
3. Tests should be run after each implementation task to verify GREEN state

## Self-Check

**File existence:**
- [x] tests/testthat/helper-fixtures.R — FOUND (created in Task 1)
- [x] tests/testthat/test_02_cleaning.R — FOUND (created in Task 2)
- [x] tests/testthat/test_02_merging.R — FOUND (created in Task 2)

**Commit existence:**
- [x] 364699c — FOUND (Task 1 commit)
- [x] e362d9d — FOUND (Task 2 commit)

**Content verification:**
- [x] helper-fixtures.R contains all 7 mock objects (formats, 2x encounter, 2x dx_parts, 2x proc_parts, provider, prov_spec)
- [x] test_02_cleaning.R contains 10 test_that blocks covering all CLN requirements
- [x] test_02_merging.R contains 8 test_that blocks covering all MRG requirements
- [x] All files use correct library() imports (testthat, dplyr, tibble)
- [x] All tests source helper-fixtures.R via here::here()

**Self-Check: PASSED**
