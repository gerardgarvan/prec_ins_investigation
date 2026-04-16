---
phase: 1
slug: data-import-format-translation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-16
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.x |
| **Config file** | tests/testthat.R (Wave 0 creates) |
| **Quick run command** | `Rscript -e "testthat::test_dir('tests/testthat')"` |
| **Full suite command** | `Rscript -e "testthat::test_dir('tests/testthat')"` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `Rscript -e "testthat::test_dir('tests/testthat')"`
- **After every plan wave:** Run `Rscript -e "testthat::test_dir('tests/testthat')"`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 0 | INF-01 | unit | `Rscript -e "testthat::test_dir('tests/testthat')"` | ❌ W0 | ⬜ pending |
| 01-01-02 | 01 | 1 | IMP-01 | unit | `Rscript -e "testthat::test_file('tests/testthat/test-formats.R')"` | ❌ W0 | ⬜ pending |
| 01-01-03 | 01 | 1 | IMP-02 | unit | `Rscript -e "testthat::test_file('tests/testthat/test-import.R')"` | ❌ W0 | ⬜ pending |
| 01-01-04 | 01 | 2 | IMP-03 | unit | `Rscript -e "testthat::test_file('tests/testthat/test-dates.R')"` | ❌ W0 | ⬜ pending |
| 01-01-05 | 01 | 2 | INF-04 | unit | `Rscript -e "testthat::test_file('tests/testthat/test-config.R')"` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/testthat/test-formats.R` — stubs for IMP-01, IMP-02
- [ ] `tests/testthat/test-import.R` — stubs for IMP-03, IMP-04, IMP-05
- [ ] `tests/testthat/test-dates.R` — stubs for IMP-03
- [ ] `tests/testthat/test-config.R` — stubs for INF-04, INF-05
- [ ] `tests/testthat/test-pipeline.R` — stubs for INF-01, INF-02, INF-03
- [ ] `tests/testthat.R` — test runner setup
- [ ] testthat package install via renv

*If none: "Existing infrastructure covers all phase requirements."*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| SAS date values match known dates | IMP-03 | Requires comparison against actual SAS output | Compare R Date values with SAS PROC PRINT output for sample records |
| Format labels match SAS format catalog | IMP-02 | Requires visual comparison of all ~60 format blocks | Spot-check 5 format blocks against Formats.sas source |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
