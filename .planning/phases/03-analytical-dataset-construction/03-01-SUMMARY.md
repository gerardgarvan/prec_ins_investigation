---
phase: 03-analytical-dataset-construction
plan: 01
subsystem: test-infrastructure
tags: [testing, fixtures, wave-0, TDD]
dependency_graph:
  requires: [02-04]
  provides: [test-infrastructure-phase3]
  affects: [03-02, 03-03, 03-04, 03-05]
tech_stack:
  added: []
  patterns: [testthat-helper-pattern, mock-data-design, deterministic-testing]
key_files:
  created:
    - tests/testthat/helper-phase3-fixtures.R
    - tests/testthat/test_03_cohort.R
    - tests/testthat/test_03_exposure.R
    - tests/testthat/test_03_outcomes.R
    - tests/testthat/test_03_covariates.R
  modified: []
decisions:
  - decision: "Use mock_p3_* prefix for Phase 3 fixtures to avoid collision with Phase 2 mock_* objects"
    rationale: "Prevents naming conflicts, allows both Phase 2 and Phase 3 tests to coexist in same test suite"
    alternatives: ["Overwrite Phase 2 fixtures", "Use namespacing"]
  - decision: "15-patient fixture design with known exclusion counts at each cohort step"
    rationale: "Deterministic test values enable precise assertions for all 19 requirements without requiring actual data"
    alternatives: ["Larger random dataset", "Minimal 8-patient dataset"]
  - decision: "Fixture includes excluded patients (P109 age<18, P110 sex=UN, P111-P113 no cancer dx, P114-P115 no enrollment)"
    rationale: "Tests negative cases and exclusion logic, not just happy path"
    alternatives: ["Only include final cohort patients"]
  - decision: "Embed expected counts in fixture comments for test reference"
    rationale: "Documentation lives with data, reduces test maintenance burden"
    alternatives: ["Separate expected-values.R file"]
metrics:
  duration_seconds: 323
  tasks_completed: 2
  files_created: 5
  lines_added: 1343
  commits: 2
  test_coverage: 19 requirements
completed_date: "2026-04-17"
---

# Phase 03 Plan 01: Phase 3 Test Infrastructure Summary

**One-liner:** Created Wave 0 test infrastructure for Phase 3 analytical dataset construction with 15-patient mock fixture and 19 test scaffolds covering all cohort, exposure, outcome, and covariate requirements.

## Objective Achievement

**Goal:** Establish Phase 3 test infrastructure with mock patient-level fixture data and test scaffolds for all 19 requirements across 4 scripts (03_cohort.R, 03_exposure.R, 03_outcomes.R, 03_covariates.R).

**Result:** ✓ Complete. Created 5 test files (1 fixture helper + 4 test scripts) with deterministic expected values for all 19 Phase 3 requirements.

## What Was Built

### Fixture Data (helper-phase3-fixtures.R)

**15-patient mock dataset** designed for deterministic testing:

**Group A — Full cohort members (10 patients, P101-P110):**
- P101: Female, White, age 62, breast cancer, Private→Medicare, surgery+chemo (intensity=4), has Z92.21 dx
- P102: Male, Black, age 70, prostate cancer, Medicare→Medicare, surgery+radiation (intensity=5), has Z92.3 dx
- P103: Female, White Hispanic, age 45, colon cancer, Medicaid→Private, surgery+chemo+radiation (intensity=7)
- P104: Male, AI/AN, age 55, lung cancer, Private→Private, chemo only (intensity=2)
- P105: Female, White, age 38, leukemia, Private→Medicaid, SCT (intensity=8), has V15.3 dx
- P106: Male, Black, age 72, kidney cancer, Medicare→dual, surgery only (intensity=1)
- P107: Female, Asian, age 50, breast cancer, Private→Private, radiation only (intensity=3), has Z92.21 dx
- P108: Male, White, age 68, rectal cancer, Medicare→Medicare, ancillary only (intensity=0)
- P109: Female, White, age 12, leukemia (EXCLUDED — age < 18)
- P110: Male, sex=UN, age 60, breast cancer (EXCLUDED — sex="UN")

**Group B — No cancer diagnosis (3 patients, P111-P113):**
- Valid enrollment but no reportable cancer dx (EXCLUDED at cancer dx step)

**Group C — No valid enrollment (2 patients, P114-P115):**
- Cancer dx but no valid enrollment (EXCLUDED at enrollment step)

**Expected cohort counts (documented in fixture):**
- Starting: 15 patients
- After valid enrollment (COH-01): 13 patients (P114, P115 excluded)
- After cancer dx (COH-02): 10 patients (P111, P112, P113 excluded)
- After age ≥ 18 (COH-03): 9 patients (P109 excluded)
- After sex ≠ "UN" (COH-03): 8 patients (P110 excluded)
- **Final cohort: 8 patients (P101-P108)**

**Change_ins distribution (EXP-01):**
- change_ins=1: P101, P103, P105, P106 (4 patients)
- change_ins=0: P102, P104, P107, P108 (4 patients)

**Treatment intensity distribution (EXP-02):**
- intensity=0 (ancillary): P108
- intensity=1 (surgery): P106
- intensity=2 (chemo): P104
- intensity=3 (radiation): P107
- intensity=4 (surgery+chemo): P101
- intensity=5 (surgery+radiation): P102
- intensity=7 (surgery+chemo+radiation): P103
- intensity=8 (SCT): P105

**Fixture objects created (19 total, prefix mock_p3_):**
1. `mock_p3_sas_formats` — Subset of SAS formats for Phase 3
2. `mock_p3_demo` — Demographics (15 patients)
3. `mock_p3_enrollment` — Enrollment records (13 with valid enrollment)
4. `mock_p3_encounters` — Encounter-level data (2-4 encounters per cohort patient)
5. `mock_p3_dx` — Diagnoses with cancer codes and ICD personal treatment history
6. `mock_p3_provider_full` — Provider + specialty merged
7. `mock_p3_dispensing` — Dispensing data for chemo NDC testing
8. `mock_p3_proc` — Procedures (surgery, chemo, radiation, SCT codes)
9. `mock_p3_ruca` — RUCA codes
10. `mock_p3_sdi` — SDI scores with first_sdi2 tertiles

### Test Scaffolds (4 files, 19 tests)

**test_03_cohort.R (5 tests):**
- COH-01: Valid enrollment filters correctly (13 patients remain)
- COH-02: Cancer diagnosis identification uses ICD codes (10 patients remain)
- COH-03: Sequential exclusion logs patient counts (attrition table with 5 steps)
- COH-04: CONSORT flowchart generates PNG and PDF (skipped until function implemented)
- COH-05: First cancer diagnosis date identified correctly (earliest admit_date with cancer dx)

**test_03_exposure.R (4 tests):**
- EXP-01: Insurance change variable calculated correctly (4 change_ins=1, 4 change_ins=0)
- EXP-02: Treatment intensity derived correctly (8 intensity levels from fixtures)
- EXP-03: Cancer site groups map correctly (Breast→"2", Digestive→"3", Hematologic→"5")
- EXP-04: Chemotherapy identification uses NDC and procedure codes (P101, P103, P104 flagged)

**test_03_outcomes.R (6 tests):**
- OUT-01: Non-acute encounters flagged correctly (enc_type in ["AV","TH"], post-first-cancer-dx)
- OUT-02: Cancer-related visits require non-acute + cancer dx
- OUT-03: Cancer visit with provider requires cancer visit + cancer provider
- OUT-04: Survivorship visits require non-acute + cancer provider + ICD personal treatment codes
- OUT-05: Person-time calculated correctly (P101: 458 days from first to last encounter)
- OUT-06: Visit counts aggregated per patient (8 rows, no NAs via replace_na pattern)

**test_03_covariates.R (4 tests):**
- COV-01: Demographics recoded with PCORnet CDM labels (sex, race, hispanic as factors)
- COV-02: Age categories match SAS age2 groupings (P101 age 62→age2=4, P102 age 70→age2=5)
- COV-03: SDI score categorized into tertiles (P101 SDI 30→first_sdi2=1, P103 SDI 80→first_sdi2=3)
- COV-04: RUCA classification processed correctly (P101 ruca=1→"Metropolitan", P106 ruca=3→"Rural areas")

## Deviations from Plan

None — plan executed exactly as written.

## Verification Results

**Automated checks:**
- Fixture file: 507 lines, 19 mock_p3_* objects (exceeds plan minimum of 200 lines, 10 objects) ✓
- Test files: 19 test_that blocks total (5+4+6+4) matching 19 Phase 3 requirements ✓
- Requirement ID coverage: All COH/EXP/OUT/COV requirement IDs present in test descriptions ✓
- Naming convention: All fixtures use mock_p3_* prefix (no collision with Phase 2 mock_*) ✓

**Manual verification:**
- Each test_that block contains at least one expect_* assertion ✓
- All 4 test files contain `library(testthat)` and `library(dplyr)` ✓
- Tests reference fixture objects correctly via testthat helper mechanism ✓
- Deterministic expected values documented in fixture comments ✓

## Known Stubs

None. This is test infrastructure only — no production code created.

## Testing Strategy

**Wave 0 TDD Pattern:**
Tests are in RED state (will fail when run) until production scripts (03_cohort.R, 03_exposure.R, 03_outcomes.R, 03_covariates.R) are implemented in Plans 02-05.

**Test execution approach:**
- Run tests after each production script implementation
- Expected failures initially (no production code exists yet)
- Tests will turn GREEN as production code is written
- Provides immediate feedback on correctness of cohort logic, exposure derivation, outcome calculation, covariate processing

## Impact Assessment

**Immediate:**
- Phase 3 has testable expectations before implementation
- Plans 02-05 can verify correctness against known expected values
- Reduces risk of logic errors in cohort construction and variable derivation

**Dependencies unblocked:**
- Plan 03-02 (Cohort Construction) can proceed with 5 COH tests as acceptance criteria
- Plan 03-03 (Exposure Variables) can proceed with 4 EXP tests as acceptance criteria
- Plan 03-04 (Outcome Variables) can proceed with 6 OUT tests as acceptance criteria
- Plan 03-05 (Covariates) can proceed with 4 COV tests as acceptance criteria

**Technical debt:**
- COH-04 test skipped (CONSORT generation function not yet defined) — will implement in Plan 03-02
- Fixture design assumes specific SAS logic (intensity calculation, site grouping) — verify against SAS code during implementation

## Commits

1. **9a6bf22** — `test(03-01): add Phase 3 mock fixture data`
   - Created helper-phase3-fixtures.R (507 lines, 19 fixture objects)
   - 15-patient design with known exclusion counts
   - Deterministic expected values for all 19 requirements

2. **e36b563** — `test(03-01): add Phase 3 test scaffolds for all 19 requirements`
   - Created test_03_cohort.R (5 tests), test_03_exposure.R (4 tests), test_03_outcomes.R (6 tests), test_03_covariates.R (4 tests)
   - Total: 19 test_that blocks
   - All tests reference mock_p3_* fixtures

## Self-Check

**Files created:**
```bash
# Verify all 5 files exist
$ [ -f "tests/testthat/helper-phase3-fixtures.R" ] && echo "✓ helper-phase3-fixtures.R"
✓ helper-phase3-fixtures.R

$ [ -f "tests/testthat/test_03_cohort.R" ] && echo "✓ test_03_cohort.R"
✓ test_03_cohort.R

$ [ -f "tests/testthat/test_03_exposure.R" ] && echo "✓ test_03_exposure.R"
✓ test_03_exposure.R

$ [ -f "tests/testthat/test_03_outcomes.R" ] && echo "✓ test_03_outcomes.R"
✓ test_03_outcomes.R

$ [ -f "tests/testthat/test_03_covariates.R" ] && echo "✓ test_03_covariates.R"
✓ test_03_covariates.R
```

**Commits exist:**
```bash
$ git log --oneline --grep="test(03-01)" | head -2
✓ e36b563 test(03-01): add Phase 3 test scaffolds for all 19 requirements
✓ 9a6bf22 test(03-01): add Phase 3 mock fixture data
```

**Line counts:**
```bash
$ wc -l tests/testthat/helper-phase3-fixtures.R
507 tests/testthat/helper-phase3-fixtures.R

$ grep -c "test_that" tests/testthat/test_03_*.R
test_03_cohort.R:5
test_03_exposure.R:4
test_03_outcomes.R:6
test_03_covariates.R:4
```

## Self-Check: PASSED

All files created, all commits exist, all line counts exceed minimums, all test counts match requirements.

## Next Steps

**Immediate (Plan 03-02):**
- Implement 03_cohort.R production script
- Run test_03_cohort.R to verify cohort construction logic
- Implement CONSORT flowchart generation function (un-skip COH-04 test)

**Sequential (Plans 03-03 through 03-05):**
- Plan 03-03: Implement 03_exposure.R, run test_03_exposure.R
- Plan 03-04: Implement 03_outcomes.R, run test_03_outcomes.R
- Plan 03-05: Implement 03_covariates.R, run test_03_covariates.R

**Verification:**
- After all production scripts implemented, run full Phase 3 test suite
- Expect all 19 tests to pass (GREEN)
- If failures occur, debug against deterministic fixture values

---

*Completed: 2026-04-17*
*Duration: 323 seconds (5.4 minutes)*
*Tasks: 2/2 complete*
*Pattern: Wave 0 TDD infrastructure (replicated from Phase 2 success)*
