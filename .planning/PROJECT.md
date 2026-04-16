# Precision Cancer Survivorship — Insurance Investigation (SAS-to-R Conversion)

## What This Is

A code forensics and translation project: untangle ~90 SAS files from the Precision Cancer Survivorship Cohort insurance investigation study, identify the correct analytical logic across multiple file versions, fix errors, and produce a clean modular R pipeline (tidyverse) that reproduces the intended analysis. The original SAS code runs on University of Florida HiPerGator using OneFlorida+/PCORnet CDM data.

## Core Value

Produce a trustworthy, readable R pipeline where every analytical step has clear logic, so the research team can confidently understand and reproduce the insurance investigation results.

## Requirements

### Validated

- [x] Translate SAS format definitions (Formats.sas) to R factor labels — *Validated in Phase 1: Data Import & Format Translation*
- [x] Structure as modular R scripts (01_clean.R, 02_merge.R, etc.) with master runner script — *Validated in Phase 1: Data Import & Format Translation*
- [x] Document all logic decisions and error fixes in code comments — *Validated in Phase 1: Data Import & Format Translation*

### Active

- [ ] Forensically map the logic across all SAS file versions to determine the intended data processing pipeline
- [ ] Identify and fix logic errors, conflicting approaches, and data quality issues in the original SAS code
- [ ] Translate SAS data cleaning (encounter merging, insurance recoding, variable derivation) to tidyverse R
- [ ] Translate cohort construction (valid enrollment, cancer diagnosis, follow-up periods) to R
- [ ] Translate exposure variable creation: insurance change (pct_change_ins), treatment intensity, cancer site groups
- [ ] Translate outcome variable creation: cancer-related visits, survivorship visits, non-acute care encounters, person-time calculation
- [ ] Translate covariate processing: demographics (sex, race, Hispanic), SDI score, RUCA, age categories
- [ ] Create Table 1 (patient characteristics by exposure groups)
- [ ] Create bivariate test outputs (chi-square, Wilcoxon rank sum)
- [ ] Create regression models (Poisson/negative binomial with person-time offset) for visit rate outcomes
- [ ] Create frequency/cross-tabulation tables for key variables

### Out of Scope

- Running the code against actual data — R code will be written to point at data later
- Modifying the study design or analysis plan — reconstruct what was intended
- Creating new analyses beyond what exists in the SAS code
- Data collection, IRB, or recruitment (covered by separate methods paper)
- SAS code preservation — the R code replaces it entirely

## Context

- **Study**: Precision Cancer Survivorship Cohort (PI: Erin M. Mobley, University of Florida)
- **Funding**: NIH/NIA 5R33AG056540
- **Data source**: OneFlorida+ Clinical Research Consortium, PCORnet Common Data Model
- **Data location**: Originally on UF HiPerGator (/blue/erin.mobley-precision/), also local drives (F:\Data_v4, E:\Refreshed_data_v3)
- **Data versions**: Multiple (v3, v4, v5) — code references change across file iterations
- **Key datasets**: encounters, diagnoses, demographics, enrollment, insurance/payer, procedures, providers, SDI, RUCA, chemotherapy/NDC, cancer site groups
- **Population**: Cancer survivors identified through OneFlorida+ with valid enrollment
- **Manuscript for context**: Manuscript_2025.02.03.docx (methods/baseline paper, not the analytic paper)
- **SAS code state**: ~90 files, many dated iterations (March 2024 — January 2025), heavy commenting-out of old code, hardcoded paths, logic spread across versions, unclear which version is authoritative
- **Code author note**: "Thanks to Carmen Smotherman for creating original code" — suggests inherited codebase with modifications

## Constraints

- **Language**: R with tidyverse (dplyr, tidyr, ggplot2, readr, haven for SAS import)
- **No data access**: Code must be written without running against data — parameterize all file paths
- **Preserve intent**: Fix logic errors but don't change the study design or variable definitions
- **PCORnet CDM compliance**: Variable names and coding must align with PCORnet Common Data Model conventions
- **SAS7BDAT input**: Data files are in SAS format — use haven::read_sas() for import

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Tidyverse over base R | User preference, readability | -- Pending |
| Modular scripts over monolithic | Maintainability, easier debugging | -- Pending |
| Fix errors with best judgment | User trusts process, code is too tangled for case-by-case review | -- Pending |
| Poisson/NB regression for visit rates | Person-time adjusted outcomes suggest rate models with offset | -- Pending |
| Reconstruct intent from code, not from protocol | No separate analysis plan exists | -- Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? -> Move to Out of Scope with reason
2. Requirements validated? -> Move to Validated with phase reference
3. New requirements emerged? -> Add to Active
4. Decisions to log? -> Add to Key Decisions
5. "What This Is" still accurate? -> Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check -- still the right priority?
3. Audit Out of Scope -- reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-16 after Phase 1 completion*
