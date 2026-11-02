---
phase: 5
slug: data-lineage-and-file-inventory
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-11-02
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | R script output verification (no test framework — output files inspected directly) |
| **Config file** | none |
| **Quick run command** | `Rscript R/00_check_inputs.R` |
| **Full suite command** | `Rscript R/00_check_inputs.R && cat docs/file_manifest.csv | wc -l` |
| **Estimated runtime** | ~5 seconds (header-only reads, no data load) |

---

## Sampling Rate

- **After every task commit:** Verify output file exists and has expected structure
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** All four deliverables present and non-empty
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 5-01-01 | 01 | 1 | SAS alias parse | file check | `test -f docs/file_manifest.csv` | ❌ W0 | ⬜ pending |
| 5-02-01 | 02 | 2 | column_lineage.csv | file check | `test -f docs/column_lineage.csv` | ❌ W0 | ⬜ pending |
| 5-03-01 | 03 | 3 | DATA_LINEAGE.md | file check | `test -f docs/DATA_LINEAGE.md` | ❌ W0 | ⬜ pending |
| 5-04-01 | 04 | 4 | 00_check_inputs.R | script run | `Rscript R/00_check_inputs.R` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `docs/` directory created
- [ ] `R/00_check_inputs.R` file created (stub)

*All output verification is file-existence + content inspection.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Mermaid diagrams render correctly | D-09 | Requires browser/renderer | Open DATA_LINEAGE.md in GitHub or VS Code Mermaid preview |
| HiPerGator path probes are correct | D-04 | Requires HiPerGator access | Run `00_check_inputs.R` on HiPerGator and review output report |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
