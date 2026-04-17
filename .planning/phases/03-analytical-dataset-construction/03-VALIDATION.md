---
phase: 3
slug: analytical-dataset-construction
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-04-16
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.x |
| **Config file** | tests/testthat.R (exists from Phase 2) |
| **Quick run command** | `Rscript -e "testthat::test_file('tests/testthat/test_03_cohort.R')"` |
| **Full suite command** | `Rscript -e "testthat::test_dir('tests/testthat')"` |
| **Estimated runtime** | ~5 seconds (no data — structural/logic tests only) |

---

## Sampling Rate

- **After every task commit:** Run quick command for relevant test file
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 0 | COH-01..05 | unit | `Rscript -e "testthat::test_file('tests/testthat/test_03_cohort.R')"` | ❌ W0 | ⬜ pending |
| 03-02-01 | 02 | 1 | EXP-01..04 | unit | `Rscript -e "testthat::test_file('tests/testthat/test_03_exposure.R')"` | ❌ W0 | ⬜ pending |
| 03-03-01 | 03 | 2 | OUT-01..06 | unit | `Rscript -e "testthat::test_file('tests/testthat/test_03_outcomes.R')"` | ❌ W0 | ⬜ pending |
| 03-04-01 | 04 | 3 | COV-01..04 | unit | `Rscript -e "testthat::test_file('tests/testthat/test_03_covariates.R')"` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/testthat/test_03_cohort.R` — stubs for COH-01 through COH-05
- [ ] `tests/testthat/test_03_exposure.R` — stubs for EXP-01 through EXP-04
- [ ] `tests/testthat/test_03_outcomes.R` — stubs for OUT-01 through OUT-06
- [ ] `tests/testthat/test_03_covariates.R` — stubs for COV-01 through COV-04
- [ ] `tests/testthat/helper-fixtures.R` — extend existing fixtures with Phase 3 mock data (cohort members, encounters with cancer dx, provider specialties)
- [ ] `mice` package — add to renv if not present (for MI-ready dataset)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| CONSORT flowchart visual quality | COH-04 | Visual output requires human review of box alignment, text readability, arrow positioning | Open output/figures/consort_flowchart.png and verify boxes are aligned, text is readable, arrows connect correctly |
| Publication-ready figure format | COH-04 | Journal formatting standards vary | Verify PDF is vector graphics, dimensions are suitable for journal column width |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
