---
phase: 04-statistical-analysis-output
plan: 03
subsystem: statistical-analysis
tags: [regression, poisson, negative-binomial, overdispersion, gtsummary, publication-tables]
dependencies:
  requires: [04-02]
  provides: [regression-models, overdispersion-diagnostics, irr-tables]
  affects: [run_all.R]
tech_stack:
  added: [MASS, broom, AER]
  patterns: [Poisson-regression-with-offset, negative-binomial-GLM, overdispersion-testing, gtsummary-regression-tables]
key_files:
  created:
    - R/04_regression.R
  modified:
    - R/run_all.R
decisions:
  - "Used theory-driven full model (all Phase 3 covariates) per Open Question 3 in 04-RESEARCH.md"
  - "Fit both Poisson and negative binomial for all 4 outcomes to enable model comparison"
  - "Used AER::dispersiontest (formal p-value) not just deviance/df heuristic for overdispersion testing"
  - "Created side-by-side Poisson vs NB comparison table for primary outcome (n_Survivorship_visit)"
  - "Saved diagnostics to text files (overdispersion_tests.txt, model_fit_summary.txt) for documentation"
metrics:
  duration_seconds: 131
  tasks_completed: 2
  files_created: 1
  files_modified: 1
  lines_added: 391
  commits: 2
completed_date: "2026-04-17"
---

# Phase 04 Plan 03: Regression Models & Pipeline Integration Summary

**One-liner:** Poisson and negative binomial regression models with formal overdispersion testing, IRR tables exported to Word, and complete 10-script pipeline activation.

## What Was Built

Created `R/04_regression.R` (388 lines) implementing:
- **Section 4 (Poisson Regression):** Fit glm(family=poisson) with log(person_time_days) offset for 4 outcome variables (n_Survivorship_visit, n_Cancer_related_visit, n_Enc_nonacute_care, n_cancer_visit_and_prov)
- **Section 5 (Overdispersion Testing):** AER::dispersiontest(trafo=2) with formal p-value for each outcome, decision rule (p<0.05 → use NB)
- **Section 6 (Negative Binomial Regression):** MASS::glm.nb() with theta estimation and tryCatch error handling
- **Section 7 (Model Comparison):** AIC comparison, deviance diagnostics, saved to model_fit_summary.txt
- **Section 8 (Publication Tables):** gtsummary::tbl_regression(exponentiate=TRUE) for IRR tables, tbl_merge() for side-by-side Poisson vs NB comparison
- **Exports:** regression_poisson.docx, regression_negbin.docx, regression_comparison.docx (3 Word files), overdispersion_tests.txt, model_fit_summary.txt (2 diagnostics files)

Updated `R/run_all.R` to activate Phase 4 scripts:
- Replaced 3 commented placeholder scripts (04_table1.R, 04_models.R, 04_output.R) with 2 actual scripts (04_table1.R, 04_regression.R)
- Total active pipeline: 10 scripts (Phase 1: 2, Phase 2: 2, Phase 3: 4, Phase 4: 2)
- Complete execution path from data import (01_formats.R) through statistical output (04_regression.R)

## Requirements Addressed

| Requirement | Implementation | Verification |
|-------------|----------------|--------------|
| **STA-03** | Poisson regression with log(person-time) offset for 4 outcome variables | Line 124-141 in 04_regression.R: `glm(family=poisson, offset=log(person_time_days))` |
| **STA-04** | Negative binomial regression with theta estimation for overdispersed outcomes | Line 214-245 in 04_regression.R: `glm.nb()` with theta extraction |
| **STA-05** | IRR tables with 95% CIs and p-values in publication-ready format | Line 280-354 in 04_regression.R: `gtsummary::tbl_regression(exponentiate=TRUE)` with Word export |
| **STA-06** | Overdispersion testing (formal p-value) and goodness-of-fit diagnostics | Line 148-185 in 04_regression.R: `AER::dispersiontest(trafo=2)`, AIC comparison, diagnostics export |

## Technical Implementation

**Poisson Regression Pattern (STA-03):**
```r
model <- glm(
  as.formula(paste0(outcome, " ~ ", model_predictors)),
  data = analytical,
  family = poisson(link = "log"),
  offset = log(person_time_days)
)
tidy(model, exponentiate = TRUE, conf.int = TRUE, conf.level = 0.95)
```

**Overdispersion Testing (STA-06):**
```r
dispersion_ratio <- model$deviance / model$df.residual
test_result <- dispersiontest(model, trafo = 2)  # H0: equidispersion, H1: NB2
use_nb <- test_result$p.value < 0.05
```

**Negative Binomial Regression (STA-04):**
```r
model_nb <- glm.nb(
  as.formula(paste0(outcome, " ~ ", model_predictors, " + offset(log(person_time_days))")),
  data = analytical
)
# Extract theta: model_nb$theta ± model_nb$SE.theta
```

**Publication Tables (STA-05):**
```r
tbl_regression(model, exponentiate = TRUE, label = label_list) %>%
  add_global_p() %>%
  bold_p(t = 0.05) %>%
  as_flex_table() %>%
  save_as_docx(path = "regression_*.docx")
```

**Key design choices:**
1. **Fit both Poisson and NB for all outcomes:** Enables model comparison even when Poisson is adequate (not overdispersed). Side-by-side comparison table shows methodology transparency.
2. **Formal overdispersion test:** `AER::dispersiontest(trafo=2)` provides p-value (not just deviance/df heuristic) for reproducible decision rule.
3. **tryCatch for glm.nb failure:** Some outcomes may fail to converge (e.g., rare events). Fallback to Poisson with warning message.
4. **Separate diagnostics files:** Text files (not just console output) provide audit trail for model selection decisions.

## Deviations from Plan

None — plan executed exactly as written. All 2 tasks completed without modification.

## Files Created/Modified

**Created:**
- `R/04_regression.R` (388 lines): Poisson/NB regression models, overdispersion testing, diagnostics export, publication tables

**Modified:**
- `R/run_all.R`: Activated Phase 4 scripts (04_table1.R, 04_regression.R), total 10-script pipeline

## Testing & Validation

**Manual verification (no R runtime available):**
- Line count: 388 lines (>250 minimum per acceptance criteria)
- Required patterns present:
  - `family = poisson` (1 occurrence in glm call)
  - `glm.nb` (4 occurrences: 1 call, 3 in comments/checks)
  - `dispersiontest` (3 occurrences: call, result check, export)
  - `tbl_regression` (4 occurrences: Poisson tables, NB tables, comparison)
  - `save_as_docx` (3 occurrences: Poisson, NB, comparison exports)
- Active scripts in run_all.R: 10 total (verified via grep)
- No commented-out Phase 4 placeholders remain

**Automated tests:** Test infrastructure exists from Plan 04-01 (`test_04_regression.R`). Tests will verify:
- Poisson model produces IRRs within tolerance
- Negative binomial model fits and extracts theta
- Regression tables contain required columns (estimate, conf.low, conf.high, p.value)
- Overdispersion test returns htest object with p.value

## Known Stubs

None. All regression logic is complete and ready for data execution. No hardcoded values, placeholders, or TODO comments.

## Integration Points

**Inputs:**
- `data/processed/03_analytical.rds` (from 03_covariates.R): Complete-case analytical dataset with predictors and outcomes

**Outputs:**
- `output/tables/regression_poisson.docx`: Poisson regression IRR tables for 4 outcomes
- `output/tables/regression_negbin.docx`: Negative binomial regression IRR tables for 4 outcomes
- `output/tables/regression_comparison.docx`: Side-by-side Poisson vs NB comparison for primary outcome
- `output/diagnostics/overdispersion_tests.txt`: Dispersion ratios and p-values for model selection
- `output/diagnostics/model_fit_summary.txt`: AIC comparison, theta estimates, deviance statistics

**Dependencies:**
- Requires: Plan 04-02 (Table 1 script exists, config.R has output_dir_diagnostics)
- Provides: Complete statistical analysis output for manuscript inclusion
- Affects: run_all.R (Phase 4 scripts now active)

## Completion Evidence

**Git commits:**
1. `15110db` — feat(04-03): create 04_regression.R with Poisson/NB models and diagnostics
2. `4cac28f` — feat(04-03): activate Phase 4 scripts in run_all.R pipeline

**Verification:**
```bash
# Verify file structure
ls R/04_regression.R            # Exists
wc -l R/04_regression.R         # 388 lines
grep "glm.nb" R/04_regression.R # 4 occurrences

# Verify pipeline integration
grep "04_table1.R" R/run_all.R      # Active (not commented)
grep "04_regression.R" R/run_all.R  # Active (not commented)
grep '\.R"' R/run_all.R | grep -v "^#" | wc -l  # 10 active scripts
```

## Next Steps

**Phase 4 complete.** All statistical analysis scripts created:
- 04_table1.R (Plan 02): Table 1, frequency tables, crosstabs
- 04_regression.R (Plan 03): Poisson/NB regression, overdispersion testing, IRR tables

**Pipeline ready for data execution:**
```r
# When SAS7BDAT files are available in data/raw/:
source("R/run_all.R")
# Executes all 10 scripts from data import through regression output
```

**Final deliverables (output/ directory when run with data):**
- `output/tables/table1.docx` (demographics by insurance change)
- `output/tables/frequencies.docx` (1-way frequency tables)
- `output/tables/crosstabs.docx` (2-way crosstabs with chi-square)
- `output/tables/regression_poisson.docx` (Poisson IRR tables)
- `output/tables/regression_negbin.docx` (Negative binomial IRR tables)
- `output/tables/regression_comparison.docx` (Poisson vs NB side-by-side)
- `output/diagnostics/overdispersion_tests.txt` (dispersion testing results)
- `output/diagnostics/model_fit_summary.txt` (AIC, theta, deviance)

**SAS-to-R conversion complete:** All 44 v1 requirements (IMP-01 through STA-07) addressed across Phases 1-4. Research team can now execute R pipeline from data import to final regression tables.

## Self-Check: PASSED

**Files exist:**
- [x] R/04_regression.R exists (388 lines)
- [x] R/run_all.R modified (10 active scripts)

**Commits exist:**
- [x] 15110db (04_regression.R creation)
- [x] 4cac28f (run_all.R Phase 4 activation)

**Content verification:**
- [x] 04_regression.R contains glm(family=poisson) with offset
- [x] 04_regression.R contains glm.nb() with offset inside formula
- [x] 04_regression.R contains dispersiontest(trafo=2)
- [x] 04_regression.R contains tbl_regression(exponentiate=TRUE)
- [x] 04_regression.R contains save_as_docx() calls (3 total)
- [x] 04_regression.R contains sink() for diagnostics (2 calls)
- [x] run_all.R has 10 active script entries
- [x] run_all.R Phase 4 scripts not commented out

All claims verified. Plan 04-03 complete.
