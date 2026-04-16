# Project Research Summary

**Project:** Precision Cancer Survivorship - SAS-to-R Conversion
**Domain:** Clinical research data pipeline (PCORnet CDM, observational cohort study)
**Researched:** 2026-04-16
**Confidence:** MEDIUM-HIGH

## Executive Summary

This project involves converting a 90-file SAS clinical research pipeline into a modern R implementation using tidyverse tools. The analysis investigates insurance changes and healthcare utilization in cancer survivors using PCORnet Common Data Model data. The recommended approach uses tidyverse ecosystem (dplyr, tidyr, haven for SAS import, gtsummary for clinical tables) with a modular numbered-script architecture (01_import.R, 02_clean.R, etc.) orchestrated by a master runner script. The pipeline must handle complex encounter deduplication, format translation from SAS catalogs, cohort construction with detailed exclusion tracking, and Poisson/negative binomial regression with person-time offsets.

The primary technical risks are SAS-to-R semantic differences that silently break logic: missing value handling differs fundamentally (SAS treats missing as negative infinity in comparisons, R propagates NA), BY-group merge semantics can create Cartesian products in R where SAS creates one-to-one matches, and SAS formats encode critical business logic that must be explicitly extracted. These are mitigated by systematic validation against SAS outputs at each pipeline stage, explicit documentation of all format translations, and row count verification for every merge operation.

The architectural recommendation is sequential numbered scripts with intermediate .rds checkpoints rather than sophisticated pipeline tools like targets. This prioritizes transparency and ease of debugging during initial translation. The project requires careful attention to person-time calculations for visit rate outcomes, as date arithmetic errors and offset miscalculations will invalidate regression results. Quality assurance through side-by-side SAS-R output comparison is essential given the complexity and potential for subtle logical errors.

## Key Findings

### Recommended Stack

The tidyverse ecosystem provides all necessary capabilities for this clinical research pipeline conversion. Modern R (4.1.0+) with core tidyverse packages (dplyr for data manipulation, tidyr for reshaping, lubridate for dates) handles the declarative transformations needed to replace SAS DATA steps and PROC SQL. The haven package (2.5.5) is the authoritative tool for importing SAS7BDAT files with format catalogs, converting SAS value labels to R factors. For statistical analysis, gtsummary (2.5.0) replaces the deprecated tableone package for publication-ready Table 1, while MASS::glm.nb provides negative binomial regression for overdispersed count outcomes. Project infrastructure requires renv for package version locking and here for portable file paths.

**Core technologies:**
- **tidyverse (2.0.0+)**: Data pipeline foundation — provides dplyr for manipulation, tidyr for reshaping, ggplot2 for visualization, lubridate for date operations; declarative pipe-based syntax replaces SAS DATA steps
- **haven (2.5.5)**: SAS data import — reads SAS7BDAT files with format catalogs, preserves value labels as metadata, converts to R factors; handles SAS-specific encoding issues
- **gtsummary (2.5.0)**: Clinical table generation — creates publication-ready Table 1 with automatic variable type detection, statistical tests, stratification; current best practice replacing tableone
- **MASS (7.3-65)**: Negative binomial regression — standard package for overdispersed count models (visit rates); pre-installed with R
- **broom (1.0.12)**: Model tidying — converts regression output to tibbles for dplyr/ggplot2 integration; extracts coefficients, confidence intervals, model fit statistics
- **janitor (2.2.1)**: Data quality utilities — standardizes column names, detects duplicates, creates frequency tables; essential for messy clinical data
- **renv (1.2.2)**: Package version control — freezes dependencies for reproducibility; critical for long-term clinical research projects
- **here (1.0.2)**: Portable file paths — eliminates hardcoded paths, project-relative references; essential for multi-environment execution

**Critical version requirements:**
- R 4.1.0+ (required by tidyverse packages)
- Avoid pharmaverse packages (admiral, sdtm.oak) — designed for CDISC SDTM/ADaM regulatory trials, not PCORnet CDM observational research

### Expected Features

SAS-to-R clinical research conversions require three feature categories: data transformation (reading, cleaning, merging), analytical outputs (tables, models, visualizations), and pipeline infrastructure (modularity, documentation, validation). The complexity lies not in individual operations but in cumulative business logic embedded across 90 files with multiple data versions and commented-out code blocks.

**Must have (table stakes):**
- SAS file import with format preservation (haven::read_sas with catalog files)
- Format translation to R factors (extract from Formats.sas, implement as explicit recodes)
- Encounter deduplication and merging (complex microvisit-to-macrovisit aggregation logic)
- Cohort construction with exclusion tracking (sequential filters with counts at each step)
- Exposure/outcome/covariate derivation (insurance change, visit rates, demographics)
- Person-time calculation for rate outcomes (follow-up tracking with censoring)
- Demographic summary table (Table 1 stratified by groups with statistical tests)
- Poisson/negative binomial regression (with person-time offset for visit rates)
- Modular script organization (numbered files with clear responsibilities)
- Master runner script (single entry point for full pipeline execution)
- Code documentation for logic decisions (every departure from SAS, every error fix)

**Should have (differentiators):**
- Automated data quality validation (pointblank assertions for proactive error detection)
- CONSORT-style cohort flowchart (visual exclusion diagram for publications)
- Comparative SAS-R output validation (side-by-side tables proving concordance)
- Comprehensive audit trail (document version conflicts, logic corrections)
- Publication-ready table formatting (direct journal submission without manual editing)
- Statistical model diagnostics (overdispersion tests, residual checks for Poisson/NB)

**Defer (v2+):**
- Reproducible pipeline orchestration with targets (start with master script, migrate later if needed)
- Interactive data exploration tools (provide clear code analysts can modify)
- Real-time validation against live databases (file-based analysis only)

**Explicitly exclude (anti-features):**
- Full SAS feature parity (implement only what's used in this analysis)
- Automated SAS-to-R translation (code too tangled, requires human judgment)
- New analyses beyond original scope (reconstruction, not extension)
- Regulatory submission packages (research study, not clinical trial)

### Architecture Approach

The standard architecture for clinical research R pipelines uses a layered approach: data import layer (SAS7BDAT files), data processing layer (cleaning, merging, derivation), analytical dataset layer (cohort with exposures/outcomes/covariates), analysis layer (models, tests), and output layer (formatted tables). For SAS conversions, the sequential numbered scripts pattern (01_import.R, 02_clean.R, 03_merge.R, etc.) provides clarity and transparency over sophisticated pipeline automation tools like targets. Each script reads from the previous stage (.rds intermediate files), performs one transformation, and writes to the next stage. This enables resuming at any checkpoint and debugging individual components without re-running the entire pipeline.

**Major components:**
1. **Data Import (01_import.R)** — Read SAS7BDAT files with haven::read_sas(), apply format catalogs, preserve variable labels; save raw R objects to data/processed/
2. **Format Translation (01_formats.R)** — Extract SAS format definitions from Formats.sas, implement as explicit factor recodes or lookup tables; validate against PROC FREQ output
3. **Data Cleaning (02_clean.R)** — Standardize variable names (janitor::clean_names), recode values, handle missing data, correct types; write cleaned tables
4. **Encounter Merging (03_merge.R)** — Join encounters with diagnoses, procedures, insurance data; handle many-to-many relationships; validate row counts
5. **Cohort Construction (05_cohort.R)** — Apply sequential inclusion/exclusion criteria with counts at each step; document who's excluded and why
6. **Analytical Dataset Assembly (06_exposures.R, 07_outcomes.R, 08_covariates.R)** — Create study-specific variables (insurance change, visit counts, person-time, demographics); merge into single patient-level analytical dataset
7. **Statistical Analysis (10_table1.R, 12_regression.R)** — Generate Table 1 with gtsummary, fit Poisson/negative binomial models with MASS, extract results with broom
8. **Output Generation (13_format.R)** — Format tables for publication, export to .docx/.csv/.html

**Key architectural patterns:**
- **Config-driven parameterization** (config/file_paths.R, config/study_parameters.R) — all paths and thresholds in one place
- **Tidy data principles** — long format, pipe-based transformations with dplyr/tidyr
- **Project-relative paths** — here::here() for portability across machines
- **Version control from day one** — Git for tracking decisions, not commented-out code
- **Progressive filtering with validation** — check row counts after every merge/filter

### Critical Pitfalls

The most dangerous failures in SAS-to-R clinical research conversions are semantic differences that produce silently wrong results rather than errors. These require systematic validation against SAS outputs at each pipeline stage.

1. **Missing value semantics break analytical logic** — SAS treats missing numeric (.) as negative infinity in comparisons (. < 5 is TRUE), R propagates NA (NA < 5 is NA). Filter conditions produce different patient subsets. Fix: explicit is.na() checks, audit all comparisons involving potentially-missing variables, test with edge cases.

2. **BY-group merge semantics create Cartesian products** — SAS MERGE with BY statement creates one row per unique BY-group combination; R joins create Cartesian products for many-to-many matches. Many-to-many encounter-diagnosis joins explode row counts by 100x. Fix: identify all many-to-many relationships in SAS code, use anti_join() to check for unexpected matches, validate row counts rigorously.

3. **SAS formats encode hidden business logic** — Format catalogs (Formats.sas) define categorical groupings used in analysis (insurance codes → types, ICD codes → cancer sites); haven imports raw codes by default. Frequency tables show numbers instead of labels, regressions use wrong variable types. Fix: extract all format definitions before analysis, create explicit R factor levels, verify against PROC FREQ output.

4. **Date/time conversions shift values** — SAS dates (days since 1960-01-01) convert to R Date with potential timezone issues; haven defaults to UTC which can shift displayed dates. Person-time calculations off by 1 day break regression offsets. Fix: validate date conversions with known test cases, use difftime(units = "days") explicitly, verify person-time totals against SAS.

5. **Implicit RETAIN in DATA steps creates hidden state** — SAS DATA step variables persist across iterations (implicit retain for variables from SET, BY-group first/last flags); R tidyverse processes each row independently. Cumulative sums, carry-forward logic, group processing fail. Fix: map RETAIN to lag()/lead()/cumsum() window functions, use group_by() %>% mutate() for BY-groups, test cumulative calculations against known totals.

6. **Person-time offset calculation errors invalidate regressions** — Poisson/NB models require log(person-time) offset, but date arithmetic, censoring logic, unit mismatches (days vs years) cause errors. Rate ratios off by 365x. Fix: verify person-time totals before modeling, use difftime(units = "days") explicitly, test with edge cases (zero follow-up, censoring), cross-check against PROC GENMOD output.

7. **Hardcoded paths prevent reproducibility** — 90 SAS files with paths like "/blue/erin.mobley-precision/", "F:\Data_v4", "E:\Refreshed_data_v3" break when moving machines. Fix: parameterize all paths in config/file_paths.R using here::here(), document expected directory structure.

## Implications for Roadmap

Based on research, the conversion requires 4 major phases ordered by technical dependencies. Early phases establish foundational capabilities (import, format translation, cleaning) that all subsequent work depends on. Middle phases implement the core analytical logic (cohort construction, variable derivation). Late phases produce outputs (tables, models). This ordering mitigates the highest-risk pitfalls early while deferring optimization and polish.

### Phase 1: Foundation - Data Import & Format Translation
**Rationale:** All downstream work depends on correctly reading SAS files and translating formats. Pitfalls 3 (formats as hidden logic) and 5 (date conversions) must be resolved before any analysis. This phase validates the fundamental import pattern and establishes the format translation system that will be used throughout.

**Delivers:**
- SAS file import pipeline with haven (01_import.R)
- Format catalog extraction and R factor translation (01_formats.R)
- Date/time conversion validation
- Raw-to-processed data flow established

**Addresses features:**
- SAS file import with format preservation (table stakes)
- Format translation to R factors (table stakes)
- Parameterized file paths (differentiator)

**Avoids pitfalls:**
- Pitfall 3: SAS formats as hidden business logic
- Pitfall 5: Date/time conversions shift values
- Pitfall 8: Hardcoded paths prevent reproducibility
- Pitfall 11: Case sensitivity breaks variable names
- Pitfall 12: Automatic type coercion errors

**Research flag:** LOW — well-documented haven workflow, standard practice. Skip phase-level research.

### Phase 2: Data Processing - Cleaning & Merging
**Rationale:** Must establish clean, merged encounter-level data before cohort construction. Pitfalls 1 (missing values), 2 (merge semantics), and 6 (PROC SQL join defaults) are highest risk here. This phase implements the complex encounter deduplication logic and validates merge operations.

**Delivers:**
- Standardized variable names and types (02_clean.R)
- Encounter-diagnosis-insurance merged dataset (03_merge.R)
- Encounter deduplication/aggregation logic (microvisit → macrovisit)
- Data quality validation checks (09_quality_checks.R)

**Addresses features:**
- Data cleaning pipeline (table stakes)
- Encounter deduplication/merging (table stakes)
- Automated data quality validation (differentiator)

**Avoids pitfalls:**
- Pitfall 1: Missing value semantics break logic
- Pitfall 2: BY-group merge semantics create Cartesian products
- Pitfall 6: PROC SQL vs dplyr join defaults differ
- Pitfall 10: Commented-out code hides authoritative logic

**Research flag:** MEDIUM — encounter deduplication has domain-specific complexity. May need phase research for N3C/RECOVER methods if SAS logic is ambiguous.

### Phase 3: Analytical Dataset Construction
**Rationale:** With clean merged data, can now construct study cohort and derive analytical variables. Pitfall 2 (implicit RETAIN) and 7 (person-time calculations) are critical here. Sequential exclusion tracking is essential for reproducibility.

**Delivers:**
- Cohort construction with exclusion counts (05_cohort.R)
- Exposure variables (insurance change) (06_exposures.R)
- Outcome variables (visit counts, person-time) (07_outcomes.R)
- Covariate processing (demographics, SDI, RUCA) (08_covariates.R)
- Single patient-level analytical dataset

**Addresses features:**
- Cohort construction with exclusions (table stakes)
- Exposure variable creation (table stakes)
- Outcome variable creation (table stakes)
- Covariate processing (table stakes)
- Person-time calculation (table stakes)
- CONSORT flowchart (differentiator)

**Avoids pitfalls:**
- Pitfall 2: Implicit RETAIN creates hidden state
- Pitfall 7: Person-time offset calculation errors

**Research flag:** LOW — standard cohort construction patterns, well-documented in epidemiology R handbooks.

### Phase 4: Statistical Analysis & Output
**Rationale:** With analytical dataset finalized, can produce statistical outputs. This phase implements Table 1, bivariate tests, and regression models. Validation against SAS outputs is the acceptance criteria.

**Delivers:**
- Table 1 with gtsummary (10_table1.R)
- Bivariate tests (11_bivariate.R)
- Poisson/negative binomial regression models (12_regression.R)
- Publication-ready formatted tables (13_format.R)
- Comparative SAS-R validation report

**Addresses features:**
- Demographic summary table (table stakes)
- Bivariate statistical tests (table stakes)
- Regression models for outcomes (table stakes)
- Publication-ready tables (differentiator)
- Statistical model diagnostics (differentiator)
- Comparative SAS-R validation (differentiator)

**Avoids pitfalls:**
- Pitfall 7: Person-time offset calculation errors (validation)
- Pitfall 9: PROC FREQ vs table() output mismatch
- Pitfall 14: PROC MEANS vs summary() output format

**Research flag:** LOW — gtsummary and MASS well-documented, standard clinical research workflow.

### Phase Ordering Rationale

- **Phase 1 before 2:** Cannot clean or merge data without correctly importing it and translating formats. Date conversion errors would propagate through entire pipeline.
- **Phase 2 before 3:** Cannot construct cohort without clean, merged encounter data. Merge errors would invalidate all downstream analysis.
- **Phase 3 before 4:** Cannot run statistical models without analytical dataset. Person-time calculation errors would invalidate regression results.
- **Sequential validation:** Each phase validates against SAS outputs before proceeding. Catches errors early when they're easier to fix.

**Dependency structure:**
```
Phase 1 (Import + Formats)
    ↓
Phase 2 (Clean + Merge)
    ↓
Phase 3 (Cohort + Variables)
    ↓
Phase 4 (Analysis + Output)
```

This linear dependency chain justifies sequential numbered scripts over targets-based pipeline. Each phase is a natural checkpoint with clear success criteria (row counts match SAS, formats verified, person-time totals correct, regression replicates SAS).

### Research Flags

**Phases needing deeper research during planning:**
- **Phase 2 (Encounter Merging):** Complex microvisit-to-macrovisit deduplication may require domain-specific literature (N3C/RECOVER methods) if SAS logic is unclear. Use /gsd:research-phase if encounter aggregation rules need clarification.

**Phases with standard patterns (skip research):**
- **Phase 1:** haven workflow well-documented, CRAN vignettes sufficient
- **Phase 3:** Standard cohort construction in epidemiology R handbooks (epirhandbook.com)
- **Phase 4:** gtsummary and MASS official docs comprehensive, clinical research TFLs widely documented

**Cross-phase validation requirements:**
All phases require comparative validation against SAS outputs. This is not research but systematic testing. Create validation checklist early (row counts, summary statistics, date ranges, factor levels, merge keys, person-time totals, regression coefficients).

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All packages verified via CRAN April 2026. Tidyverse is established standard for clinical R. Haven authoritative for SAS import. gtsummary current best practice for Table 1. MASS stable for negative binomial. |
| Features | HIGH | SAS-to-R feature requirements well-documented in pharmaverse migration guides and clinical research literature. Table stakes vs differentiators clear from academic workflow sources. |
| Architecture | MEDIUM | Sequential numbered scripts pattern widely used but not formally standardized. No single authoritative source for "clinical R pipeline architecture" — synthesized from multiple domain sources. PCORnet CDM R implementation examples sparse (most use SAS). |
| Pitfalls | HIGH | SAS-R semantic differences extensively documented in migration guides. Missing value, merge, format, and date conversion pitfalls are well-known failure modes. Person-time offset errors common in observational studies. |

**Overall confidence:** MEDIUM-HIGH

Stack and pitfall recommendations are HIGH confidence based on official documentation and verified sources. Features are HIGH confidence based on clinical research best practices. Architecture is MEDIUM confidence due to lack of single authoritative pattern for PCORnet CDM in R, though general observational research workflows are well-established.

### Gaps to Address

**PCORnet CDM R package ecosystem:** No R-specific packages found for PCORnet CDM analysis (unlike CDISC pharmaverse for clinical trials). Standard tidyverse approaches apply, but no domain-specific helpers for CDM table joins, variable validation, or coding system lookups. Address by: create utility functions in R/utils/pcornet_helpers.R as needed during development.

**Encounter deduplication methodology:** Academic papers document the problem (N3C, RECOVER studies on EHR microvisits) but don't provide reference implementations. SAS code contains the ground truth but may be undocumented. Address by: careful forensic analysis of SAS encounter merge logic, potentially use /gsd:research-phase for Phase 2 if logic is ambiguous.

**Multi-version data file handling:** 90 SAS files reference v3, v4, v5 data with inconsistent paths and commented-out version switches. No clear documentation of which version each file expects. Address by: early audit phase to map file → data version dependencies, create version-specific config files if needed.

**SAS code forensics methodology:** No established pattern for extracting intent from heavily-commented legacy SAS with multiple versions. Address by: systematic review of each file, document active vs commented logic in separate audit file, prioritize most recent timestamps as authoritative unless proven wrong.

**Comparative validation baseline:** Assumes SAS code can be re-run to generate comparison outputs. If SAS environment unavailable or data access restricted, cannot validate concordance. Address by: confirm data and SAS environment access before Phase 1, if unavailable downgrade comparative validation from "should have" to "defer."

## Sources

### Primary (HIGH confidence)

**Tidyverse Ecosystem:**
- [Tidyverse Official Documentation](https://tidyverse.org/packages/) — comprehensive package reference
- [dplyr](https://cran.r-project.org/web/packages/dplyr/), [tidyr](https://cran.r-project.org/web/packages/tidyr/), [lubridate](https://cran.r-project.org/web/packages/lubridate/) CRAN packages — verified versions April 2026

**SAS Data Import:**
- [haven Official Documentation](https://haven.tidyverse.org/) — SAS file import reference
- [haven CRAN Package 2.5.5](https://cran.r-project.org/web/packages/haven/) — verified current version

**Clinical Table Generation:**
- [gtsummary Official Documentation](https://www.danieldsjoberg.com/gtsummary/) — Table 1 creation
- [Building Table One with gtsummary](https://bookdown.org/pdr_higgins/rmrwr/building-your-table-one-with-the-gtsummary-package.html) — clinical research tutorial

**Statistical Modeling:**
- [MASS Package glm.nb](https://stat.ethz.ch/R-manual/R-devel/library/MASS/html/glm.nb.html) — negative binomial regression
- [UCLA Stats: Negative Binomial Regression in R](https://stats.oarc.ucla.edu/r/dae/negative-binomial-regression/) — worked examples

**Project Organization:**
- [R for Clinical Study Reports and Submission](https://r4csr.org/project-folder.html) — industry standard structure
- [renv Documentation](https://rstudio.github.io/renv/) — package version control
- [here Package](https://here.r-lib.org/) — portable file paths

### Secondary (MEDIUM confidence)

**SAS-to-R Conversion:**
- [Transitioning Clinical Research from SAS to R: Pharmaverse](https://procogia.com/transitioning-clinical-research-from-sas-to-r-an-introduction-to-the-pharmaverse-ecosystem/) — migration patterns
- [Appsilon: SAS to R Migration](https://www.appsilon.com/post/transitioning-from-sas-to-r) — semantic differences

**Observational Research Workflows:**
- [The Epidemiologist R Handbook](https://www.epirhandbook.com/en/) — cohort construction, cleaning patterns
- [Reproducible Medical Research with R](https://bookdown.org/pdr_higgins/rmrwr/) — clinical research best practices

**PCORnet CDM:**
- [PCORnet Common Data Model v7.0 Specification](https://pcornet.org/wp-content/uploads/2025/05/PCORnet_Common_Data_Model_v70_2025_05_01.pdf) — table schemas
- [PCORnet CDM Overview](https://pcornet.org/data/common-data-model/) — documentation portal

**Domain Pitfalls:**
- [SAS Support: Merge with Caution](https://support.sas.com/resources/papers/proceedings18/1746-2018.pdf) — merge semantics
- [Paul Dickman: SAS Tips - Missing Values](https://www.pauldickman.com/sastips/missing/) — missing value handling
- [haven Conversion Semantics](https://cran.r-project.org/web/packages/haven/vignettes/semantics.html) — SAS-R type mapping

**Encounter Deduplication:**
- [Clinical encounter heterogeneity in networked EHR data (N3C/RECOVER)](https://www.medrxiv.org/content/10.1101/2022.10.14.22281106v2) — microvisit problem
- [De-duplication – The Epidemiologist R Handbook](https://www.epirhandbook.com/en/new_pages/deduplication.html) — deduplication strategies

### Tertiary (LOW confidence)

**Code Forensics:**
- General digital forensics and legacy code modernization sources — no SAS-specific methodology found; requires manual review

**PCORnet R Implementation:**
- No R-specific PCORnet CDM packages identified — standard tidyverse approaches apply but no domain-specific tooling

---
*Research completed: 2026-04-16*
*Ready for roadmap: yes*
