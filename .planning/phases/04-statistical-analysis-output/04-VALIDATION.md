---
phase: 4
slug: statistical-analysis-output
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-04-17
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.x (R testing framework) |
| **Config file** | tests/testthat.R (created in Wave 0 if missing) |
| **Quick run command** | `Rscript -e "testthat::test_file('tests/testthat/test-04-table1.R')"` |
| **Full suite command** | `Rscript -e "testthat::test_dir('tests/testthat', filter='04')"` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick run command for the specific script
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 04-01-01 | 01 | 1 | STA-01 | unit | `Rscript -e "testthat::test_file('tests/testthat/test-04-table1.R')"` | ❌ W0 | ⬜ pending |
| 04-02-01 | 02 | 2 | STA-02 | unit | `Rscript -e "testthat::test_file('tests/testthat/test-04-bivariate.R')"` | ❌ W0 | ⬜ pending |
| 04-03-01 | 03 | 3 | STA-03, STA-04 | unit | `Rscript -e "testthat::test_file('tests/testthat/test-04-poisson.R')"` | ❌ W0 | ⬜ pending |
| 04-04-01 | 04 | 4 | STA-05 | unit | `Rscript -e "testthat::test_file('tests/testthat/test-04-negbin.R')"` | ❌ W0 | ⬜ pending |
| 04-05-01 | 05 | 5 | STA-06, STA-07 | unit | `Rscript -e "testthat::test_file('tests/testthat/test-04-export.R')"` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/testthat/test-04-table1.R` — stubs for STA-01 (Table 1 generation)
- [ ] `tests/testthat/test-04-bivariate.R` — stubs for STA-02 (chi-square, Wilcoxon tests)
- [ ] `tests/testthat/test-04-poisson.R` — stubs for STA-03, STA-04 (Poisson regression, IRR extraction)
- [ ] `tests/testthat/test-04-negbin.R` — stubs for STA-05 (negative binomial regression)
- [ ] `tests/testthat/test-04-export.R` — stubs for STA-06, STA-07 (Word export, frequency tables)
- [ ] `tests/testthat/fixtures/mock_analytical_dataset.rds` — mock analytical dataset with known statistical properties

*Note: R and testthat not available on development machine (no-data-access constraint). Tests validate code structure and function signatures. Statistical validation requires data environment.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Table 1 formatting matches publication standards | STA-01 | Visual inspection of .docx output | Open exported Word file, verify column alignment, headers, footnotes |
| IRR values match SAS PROC GENMOD within 1% | STA-03, STA-04 | Requires SAS output comparison | Compare R regression output against SAS .lst files side-by-side |
| Overdispersion detection triggers NB switch | STA-05 | Requires real data distribution | Run on HiPerGator data, verify AER::dispersiontest p-value < 0.05 triggers glm.nb() |
| Word export renders without manual editing | STA-06 | Visual inspection of .docx output | Open in Microsoft Word, verify no broken formatting or missing values |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
