# Roadmap: Precision Cancer Survivorship — SAS-to-R Conversion

**Project:** SAS clinical research pipeline conversion to R
**Milestone:** v1
**Granularity:** Standard (4 phases)
**Created:** 2026-04-16

## Core Value

Produce a trustworthy, readable R pipeline where every analytical step has clear logic, so the research team can confidently understand and reproduce the insurance investigation results.

## Phases

- [ ] **Phase 1: Data Import & Format Translation** - Establish SAS-to-R data pipeline foundation with validated format conversion
- [ ] **Phase 2: Data Cleaning & Merging** - Clean and merge encounter-level datasets with validated join logic
- [ ] **Phase 3: Analytical Dataset Construction** - Build study cohort with exposure, outcome, and covariate variables
- [ ] **Phase 4: Statistical Analysis & Output** - Produce publication-ready tables and regression models

## Phase Details

### Phase 1: Data Import & Format Translation

**Goal:** Establish SAS-to-R data pipeline foundation with validated format conversion and project infrastructure

**Depends on:** Nothing (first phase)

**Requirements:** IMP-01, IMP-02, IMP-03, IMP-04, IMP-05, INF-01, INF-02, INF-03, INF-04, INF-05, INF-06

**Success Criteria** (what must be TRUE):
1. All required SAS7BDAT files load into R without errors using haven::read_sas()
2. SAS date values convert to R Date objects and match known dates from SAS output
3. All SAS format definitions from Formats.sas exist as R factor levels with matching labels
4. File paths are parameterized in config files — no hardcoded paths in scripts
5. Modular script structure exists (01_import.R, 01_formats.R, run_all.R) and executes without errors

**Plans:** 3 plans

Plans:
- [x] 01-01-PLAN.md — Project infrastructure (config.R, run_all.R, .gitignore, directory structure)
- [x] 01-02-PLAN.md — Format translation (Formats.sas to R named lists with forensic duplicate resolution)
- [x] 01-03-PLAN.md — SAS data import (all V5 SAS7BDAT files, date conversion, label preservation, checkpoints)

### Phase 2: Data Cleaning & Merging

**Goal:** Clean and merge encounter-level datasets with validated join logic and row count tracking

**Depends on:** Phase 1

**Requirements:** CLN-01, CLN-02, CLN-03, CLN-04, CLN-05, CLN-06, MRG-01, MRG-02, MRG-03, MRG-04

**Success Criteria** (what must be TRUE):
1. All variable names are standardized to consistent lowercase naming (janitor::clean_names applied)
2. Encounter datasets combine into single dataset with row count matching SAS output
3. Insurance payer codes recode to grouped categories matching SAS PROC FREQ distributions
4. Encounter-diagnosis-procedure-insurance merges produce row counts within 1% of SAS JOIN output
5. Data quality assertions run after all merges and flag any unexpected missing values or range violations

**Plans:** 1/4 plans executed

Plans:
- [x] 02-01-PLAN.md — Test infrastructure (Wave 0 fixtures + test scaffolds for all CLN/MRG requirements)
- [x] 02-02-PLAN.md — Encounter cleaning (02_clean.R: import, combine, payer/enc_type recoding, dx/proc concat)
- [x] 02-03-PLAN.md — Data merging (02_merge.R: encounter-dx-proc-provider joins with row count validation)
- [x] 02-04-PLAN.md — Pipeline integration (update run_all.R, full test suite verification)

### Phase 3: Analytical Dataset Construction

**Goal:** Build study cohort with exposure, outcome, and covariate variables ready for statistical analysis

**Depends on:** Phase 2

**Requirements:** COH-01, COH-02, COH-03, COH-04, COH-05, EXP-01, EXP-02, EXP-03, EXP-04, OUT-01, OUT-02, OUT-03, OUT-04, OUT-05, OUT-06, COV-01, COV-02, COV-03, COV-04

**Success Criteria** (what must be TRUE):
1. Cohort construction applies sequential exclusion criteria with patient counts logged at each step matching SAS PROC SQL counts
2. Cancer diagnosis identification produces patient list matching SAS reportable cancer cohort
3. Insurance change variable (pct_change_ins) calculates correctly and matches SAS PROC MEANS distribution
4. Visit count outcomes (cancer-related, survivorship, non-acute) aggregate per patient matching SAS frequency tables
5. Person-time calculation (days from first cancer dx to follow-up) produces totals within 1% of SAS sum
6. Demographics, SDI, and RUCA variables recode to factor levels matching SAS PROC FREQ output

**Plans:** TBD

### Phase 4: Statistical Analysis & Output

**Goal:** Produce publication-ready statistical tables and regression models validated against SAS output

**Depends on:** Phase 3

**Requirements:** STA-01, STA-02, STA-03, STA-04, STA-05, STA-06, STA-07

**Success Criteria** (what must be TRUE):
1. Table 1 shows patient characteristics stratified by exposure groups with correct statistics (counts, percentages, medians)
2. Bivariate tests (chi-square, Wilcoxon) produce p-values matching SAS PROC FREQ/PROC NPAR1WAY output
3. Poisson regression models with person-time offset produce IRRs and 95% CIs within 1% of SAS PROC GENMOD output
4. Negative binomial models fit when overdispersion detected and match SAS NB regression results
5. Publication-ready formatted tables export to .docx format without manual editing required

**Plans:** TBD

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Data Import & Format Translation | 3/3 | Complete | 2026-04-16 |
| 2. Data Cleaning & Merging | 1/4 | In Progress|  |
| 3. Analytical Dataset Construction | 0/0 | Not started | - |
| 4. Statistical Analysis & Output | 0/0 | Not started | - |

## Coverage

**Total v1 requirements:** 44
**Mapped to phases:** 44
**Unmapped:** 0

All requirements mapped to phases. No orphans.

## Dependencies

```
Phase 1: Data Import & Format Translation
    |
Phase 2: Data Cleaning & Merging
    |
Phase 3: Analytical Dataset Construction
    |
Phase 4: Statistical Analysis & Output
```

Linear dependency chain: each phase requires completion of previous phase. This supports sequential numbered scripts architecture over parallel pipeline automation.

---
*Roadmap created: 2026-04-16*
*Phase 1 planned: 2026-04-16 (3 plans, 3 waves)*
*Phase 2 planned: 2026-04-16 (4 plans, 4 waves)*
