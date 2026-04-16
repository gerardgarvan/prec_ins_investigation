---
phase: 2
slug: data-cleaning-merging
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-16
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.3.2 |
| **Config file** | None — Wave 0 installs |
| **Quick run command** | `testthat::test_file("tests/testthat/test_02_cleaning.R")` |
| **Full suite command** | `testthat::test_dir("tests/testthat")` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `testthat::test_file("tests/testthat/test_02_cleaning.R")`
- **After every plan wave:** Run `testthat::test_dir("tests/testthat")`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 0 | CLN-01 | unit | `test_file("tests/testthat/test_02_cleaning.R")` | W0 | pending |
| 02-01-02 | 01 | 0 | CLN-02 | unit | `test_file("tests/testthat/test_02_cleaning.R")` | W0 | pending |
| 02-01-03 | 01 | 0 | CLN-03 | unit | `test_file("tests/testthat/test_02_cleaning.R")` | W0 | pending |
| 02-01-04 | 01 | 0 | CLN-04 | unit | `test_file("tests/testthat/test_02_cleaning.R")` | W0 | pending |
| 02-01-05 | 01 | 0 | CLN-05 | unit | `test_file("tests/testthat/test_02_cleaning.R")` | W0 | pending |
| 02-01-06 | 01 | 0 | CLN-06 | unit | `test_file("tests/testthat/test_02_cleaning.R")` | W0 | pending |
| 02-02-01 | 02 | 1 | MRG-01 | unit | `test_file("tests/testthat/test_02_merging.R")` | W0 | pending |
| 02-02-02 | 02 | 1 | MRG-02 | manual | Visual inspection of console output | N/A | pending |
| 02-02-03 | 02 | 1 | MRG-03 | unit | `test_file("tests/testthat/test_02_merging.R")` | W0 | pending |
| 02-02-04 | 02 | 1 | MRG-04 | unit | `test_file("tests/testthat/test_02_merging.R")` | W0 | pending |

*Status: pending / green / red / flaky*

---

## Wave 0 Requirements

- [x] `tests/testthat/test_02_cleaning.R` — stubs for CLN-01 through CLN-06
  - Test: encounter1 + encounter2 row sum equals combined dataset
  - Test: all payer_type_primary codes map to grouped categories
  - Test: missing values handled explicitly (no implicit NA propagation)
  - Test: encounter type/discharge status factor levels match SAS formats
- [x] `tests/testthat/test_02_merging.R` — stubs for MRG-01, MRG-03, MRG-04
  - Test: encounter-diagnosis join produces expected row count
  - Test: relationship argument prevents Cartesian product
  - Test: post-merge assertions verify no unexpected NAs
- [x] `tests/testthat/helper-fixtures.R` — shared test fixtures
  - Fixture: mock encounter dataset (10 rows)
  - Fixture: mock diagnosis dataset (30 rows, 3 dx per encounter)
  - Fixture: expected join output (30 rows)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Row counts logged after merges | MRG-02 | Logging behavior (console output) | Run 02_merge.R, verify message() output shows row counts before/after each join |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 30s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved
