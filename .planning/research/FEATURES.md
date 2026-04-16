# Feature Landscape: SAS-to-R Clinical Research Data Pipeline Conversion

**Domain:** Clinical research data pipeline conversion (SAS to R, PCORnet CDM)
**Project:** Precision Cancer Survivorship Insurance Investigation
**Researched:** 2026-04-16

## Executive Summary

SAS-to-R conversions for clinical research pipelines require three categories of features: **data transformation capabilities** (reading SAS files, recreating SAS logic), **analytical outputs** (tables, models, visualizations), and **pipeline infrastructure** (modular organization, documentation, validation). For cancer survivorship cohort studies using PCORnet CDM data, table stakes include accurate data import with format preservation, encounter deduplication, cohort construction with exclusion tracking, standard demographic tables (Table 1), bivariate tests, and regression models. Differentiators include automated data quality validation, reproducible pipeline orchestration, comprehensive audit trails for logic decisions, and CONSORT-style flowcharts showing cohort construction. Anti-features include full SAS feature parity, real-time data validation against live databases, and creating new analyses beyond the original study design.

## Table Stakes

Features users expect. Missing = pipeline is incomplete or untrustworthy.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **SAS file import with format preservation** | SAS7BDAT files are standard in clinical research; formats define categorical values | Medium | Use `haven::read_sas()` with catalog files; convert to R factors using `as_factor()` or manual recode |
| **SAS format translation to R factors** | Categorical variable labels (e.g., sex, race, insurance type) must match SAS output | Medium | Extract from SAS Formats.sas file; implement as factor levels or labelled() class |
| **Data cleaning pipeline** | Raw clinical data requires standardization, recoding, derived variables | High | Multiple steps: variable recoding, missing value handling, data type corrections |
| **Encounter deduplication/merging** | Overlapping clinical visits must be aggregated into meaningful episodes | High | Complex logic: merge overlapping dates, handle microvisit-to-macrovisit aggregation |
| **Cohort construction with exclusions** | Identify valid study population; document who's excluded and why | High | Sequential filtering with counts at each step; critical for reproducibility |
| **Demographic summary table (Table 1)** | Standard for all clinical research papers; shows baseline characteristics | Medium | By exposure group; includes continuous (mean, SD, median, IQR) and categorical (n, %) variables |
| **Bivariate statistical tests** | Chi-square for categorical, Wilcoxon rank-sum for continuous comparisons | Low | Standard R functions: `chisq.test()`, `wilcox.test()` |
| **Regression models for outcomes** | Poisson/negative binomial regression with person-time offset for visit rates | Medium | Use `glm()` family=poisson or `MASS::glm.nb()`; include offset for person-time |
| **Frequency tables and cross-tabulations** | Replicate SAS PROC FREQ outputs for key variables | Low | Use `table()`, `xtabs()`, or tidyverse equivalents |
| **Modular script organization** | Separate scripts for distinct pipeline stages (clean, merge, analyze) | Low | Numbered files: 01_clean.R, 02_merge.R, 03_cohort.R, etc. |
| **Master runner script** | Single entry point to execute entire pipeline in order | Low | Source all numbered scripts sequentially; parameterize file paths |
| **Covariate processing** | Demographics (age, sex, race/ethnicity), SDI, RUCA, cancer site groups | Medium | Recoding, categorization, factor level creation |
| **Exposure variable creation** | Insurance change (pct_change_ins), treatment intensity, cancer site | High | Complex derivations; must match SAS logic exactly |
| **Outcome variable creation** | Cancer-related visits, survivorship visits, non-acute care, person-time | High | Encounter classification, rate calculation with person-time denominators |
| **Code comments documenting logic decisions** | Every departure from original SAS, every error fix, every assumption | Low | Inline comments explaining "why" not just "what" |

## Differentiators

Features that set the R pipeline apart from original SAS code. Not expected, but highly valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Automated data quality validation** | Proactively catch data issues before analysis; increase trustworthiness | Medium | Use `pointblank` package for assertion-based validation rules |
| **CONSORT-style cohort flowchart** | Visual diagram showing exclusions at each step; publication-ready | Medium | Track counts through cohort construction; generate with ggplot2 or DiagrammeR |
| **Reproducible pipeline orchestration** | Ensure entire analysis runs top-to-bottom without manual intervention | Medium | Use `targets` package or master script with dependency tracking |
| **Comparative SAS-vs-R output validation** | Side-by-side comparison tables proving R reproduces SAS results | High | Requires running SAS code to generate comparison baseline |
| **Comprehensive audit trail** | Document every logic decision, error found, version discrepancy resolved | Low | Dedicated AUDIT.md or inline comments with standardized tags |
| **Tidyverse-native implementation** | Readable, pipe-based code; easier to maintain than base R | Low | dplyr for transformations, ggplot2 for plots, readr/haven for I/O |
| **Publication-ready tables** | Direct output to journals without manual reformatting | Medium | Use `gtsummary` for Table 1, `gt` or `flextable` for formatted output |
| **Parameterized file paths** | No hardcoded paths; easy to run on different systems/data versions | Low | Use config file or function parameters for all data locations |
| **Version control friendly structure** | Modular files, no binary outputs in repo, clear naming | Low | .gitignore for data/results; document expected directory structure |
| **Explicit handling of data version conflicts** | Code documents which data version (v3/v4/v5) each step assumes | Low | Comments or assertions checking version-specific variables |
| **Statistical model diagnostics** | Check overdispersion, residuals, model fit for Poisson/NB regression | Medium | Standard diagnostic plots and tests (dispersion test, residual plots) |
| **Cohort construction validation report** | Summary showing n at each step matches expectations/SAS output | Low | Automated report showing counts, percentages excluded, final N |

## Anti-Features

Features to explicitly NOT build.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Full SAS feature parity** | Not all SAS features are needed; many are legacy/unused in this code | Implement only what's actually used in the specific analysis |
| **Interactive data exploration tools** | Scope is reconstruction of specific analysis, not general exploration | Provide clear code that analysts can modify; document structure |
| **Real-time data validation** | No data access; code written to point at data later | Use assertions that will run when data is available; document expected structure |
| **Automated SAS-to-R translation** | SAS code is too tangled; requires human judgment to fix errors | Manual translation with careful review and logic reconstruction |
| **New analyses beyond SAS code** | Out of scope; project is reconstruction not extension | Document potential future analyses separately; keep in scope |
| **SAS code preservation/archival** | R code replaces SAS entirely; no need to maintain both | Document decisions in R code; SAS is reference only |
| **Production database connections** | Data source is file-based (SAS7BDAT); no live DB | Read from static files; parameterize paths |
| **Regulatory submission packages** | Research study, not clinical trial requiring FDA submission | Standard reproducible research practices sufficient |
| **Graphical user interface** | Code-based pipeline for analysts comfortable with R | Command-line execution via master script |
| **Multi-language polyglot pipeline** | Tidyverse R provides all needed capabilities | Pure R implementation; use haven for SAS import only |
| **Retrospective correction of study design** | Preserve original intent even if suboptimal | Fix errors, document design limitations, but don't change design |

## Feature Dependencies

```
SAS file import → Format translation → Data cleaning
                                     → Encounter merging → Cohort construction → Outcomes
                                                                               → Exposures
                                                                               → Covariates

Cohort construction → Table 1 (demographics)
                   → Bivariate tests
                   → Regression models

Modular scripts → Master runner script
Data quality validation → Cohort validation report

Format translation → All categorical variable analyses
Encounter merging → Outcome variables (visit counts)
Person-time calculation → Regression models (offset term)
```

## Feature Complexity Breakdown

### Low Complexity (1-2 days)
- Master runner script
- Bivariate tests
- Frequency tables
- Code commenting discipline
- Parameterized paths
- Audit trail documentation

### Medium Complexity (3-7 days)
- SAS file import with formats
- Format translation system
- Table 1 with gtsummary
- Regression models
- Covariate processing
- Data quality validation with pointblank
- CONSORT flowchart
- Publication-ready table formatting
- Statistical model diagnostics

### High Complexity (1-2 weeks)
- Data cleaning pipeline (many variables, many rules)
- Encounter deduplication (complex business logic)
- Cohort construction (sequential exclusions, multiple criteria)
- Exposure variable creation (insurance change logic)
- Outcome variable creation (visit classification, person-time)
- Comparative SAS-R validation (requires SAS execution)

## MVP Recommendation

**Prioritize for initial implementation:**

1. **SAS file import with format preservation** — Foundation for everything; validates data access pattern
2. **Modular script structure with master runner** — Establishes organization early; easy to extend
3. **Data cleaning pipeline** — Core transformation logic; most time-intensive
4. **Encounter merging** — Required for visit-based outcomes
5. **Cohort construction with exclusion tracking** — Defines analysis population; enables all downstream analyses
6. **Exposure and outcome variable creation** — Study-specific analytical variables
7. **Table 1 (demographics)** — Quick validation that cohort looks reasonable
8. **Regression models** — Primary analytical outputs
9. **Code comments documenting all logic decisions** — Continuous throughout development

**Defer to Phase 2 (if needed):**

- Automated data quality validation with pointblank (can validate manually initially)
- CONSORT-style flowchart (cohort construction counts sufficient initially)
- Comparative SAS-R validation (requires SAS environment access)
- Publication-ready table formatting (focus on correctness first, formatting later)
- Statistical model diagnostics (add after models run successfully)

**Explicitly exclude:**

- Interactive tools, GUIs, real-time validation, new analyses, SAS preservation

## Domain-Specific Notes

### PCORnet Common Data Model
- Standard table names: DEMOGRAPHIC, ENCOUNTER, DIAGNOSIS, PROCEDURES, ENROLLMENT, etc.
- Standard variable naming conventions (e.g., PATID, ENCOUNTERID, ADMIT_DATE)
- Coding systems: diagnosis uses ICD-9/ICD-10; procedures use CPT/HCPCS/ICD-10-PCS
- No built-in data quality rules in CDM specification (populate as-is from source)
- **Note:** Search did not identify R packages specific to PCORnet CDM analysis (LOW confidence); standard tidyverse approaches apply

### Cancer Survivorship Research
- Typical visit categories: cancer-related, survivorship care, non-acute preventive
- Follow-up periods: Often 1-3 years post-diagnosis
- Survivorship care models: Variable across institutions (MD-led, APP-led, PCP-led, shared, virtual)
- Key evaluation metrics: Healthcare utilization patterns, treatment adherence, quality of life
- Person-time calculation critical for rate-based outcomes (accounts for variable follow-up)

### SAS-to-R Translation Patterns
- **PROC FREQ → table() or dplyr::count()** for frequencies
- **PROC MEANS → dplyr::summarise()** for descriptive statistics
- **PROC SQL → dplyr verbs** for data manipulation
- **DATA step → dplyr::mutate()** for variable derivation
- **SAS formats → factor() or haven::labelled()** for categorical labels
- **PROC LOGISTIC/GENMOD → glm() or specialized packages** for regression

### Validation and Documentation
- Regulatory environments require documented Statistical Analysis Plan (SAP) before analysis
- This project: Reconstruct intent from code (no separate SAP exists)
- Best practice: Document decisions in code comments and separate audit trail
- Compare outputs to SAS results where possible (validation by concordance)

## Implementation Priority Matrix

| Feature | Impact | Complexity | Priority |
|---------|--------|-----------|----------|
| SAS file import | High | Medium | **P0 - Critical** |
| Format translation | High | Medium | **P0 - Critical** |
| Data cleaning | High | High | **P0 - Critical** |
| Encounter merging | High | High | **P0 - Critical** |
| Cohort construction | High | High | **P0 - Critical** |
| Exposure/outcome variables | High | High | **P0 - Critical** |
| Modular organization | High | Low | **P0 - Critical** |
| Master runner | High | Low | **P0 - Critical** |
| Code documentation | High | Low | **P0 - Critical** |
| Table 1 | Medium | Medium | **P1 - High** |
| Regression models | High | Medium | **P1 - High** |
| Bivariate tests | Medium | Low | **P1 - High** |
| Covariate processing | High | Medium | **P1 - High** |
| Frequency tables | Low | Low | **P2 - Medium** |
| Data quality validation | Medium | Medium | **P2 - Medium** |
| CONSORT flowchart | Medium | Medium | **P2 - Medium** |
| Publication tables | Low | Medium | **P3 - Low** |
| Model diagnostics | Medium | Medium | **P3 - Low** |
| SAS-R comparison | Low | High | **P3 - Low** |

## Confidence Assessment

| Area | Confidence | Sources |
|------|------------|---------|
| SAS-to-R translation patterns | **HIGH** | Context7 (haven docs), pharmaverse ecosystem, tidytlg documentation |
| Clinical trial table/reporting features | **HIGH** | gtsummary official docs, multiple clinical research sources |
| Statistical modeling (Poisson/NB) | **HIGH** | UCLA stats, multiple academic sources on count models |
| PCORnet CDM specifics | **MEDIUM** | Official PCORnet documentation, but no R package found |
| Encounter deduplication methods | **MEDIUM** | Academic papers (N3C, RECOVER), Epidemiologist R Handbook |
| Data quality validation tools | **HIGH** | pointblank official documentation, R Consortium materials |
| Cancer survivorship features | **MEDIUM** | Recent 2025-2026 academic literature, but limited R-specific guidance |
| Code forensics/reconstruction | **LOW** | General digital forensics sources; no SAS-specific methodology found |

## Sources

**SAS-to-R Ecosystem:**
- [Transitioning Clinical Research from SAS to R: Pharmaverse Ecosystem](https://procogia.com/transitioning-clinical-research-from-sas-to-r-an-introduction-to-the-pharmaverse-ecosystem/)
- [From SAS to R in Regulatory Biostatistics](https://www.lucid-analytics.ai/2026/lucid-life/from-sas-to-r-in-regulatory-biostatistics-why-the-shift-is-happening/)
- [Tidytlg: R Package for Clinical Reporting using Tidyverse](https://medium.com/johnson-johnson-open-source/tidytlg-an-r-package-for-clinical-reporting-using-tidyverse-8e56ab2e8ffb)

**Clinical Reporting & Tables:**
- [gtsummary: tbl_summary() tutorial](https://www.danieldsjoberg.com/gtsummary/articles/tbl_summary.html)
- [Building Your Table One with gtsummary](https://bookdown.org/pdr_higgins/rmrwr/building-your-table-one-with-the-gtsummary-package.html)
- [Demographic Table – pharmaverse examples](https://pharmaverse.github.io/examples/tlg/demographic.html)

**Statistical Methods:**
- [Negative Binomial Regression | UCLA R Examples](https://stats.oarc.ucla.edu/r/dae/negative-binomial-regression/)
- [Count Data in Medical Research: Poisson and Negative Binomial](https://pubmed.ncbi.nlm.nih.gov/33857979/)
- [Poisson vs. Negative Binomial Regression](https://www.statology.org/negative-binomial-vs-poisson/)

**SAS File Import:**
- [haven: Import and Export SPSS, Stata and SAS Files](https://haven.tidyverse.org/)
- [Read SAS files — read_sas • haven](https://haven.tidyverse.org/reference/read_sas.html)
- [How to Read a SAS Dataset Into R – The Right Way](https://berd.uthsc.edu/how-to-read-a-sas-dataset-into-r-the-right-way/)

**Data Quality & Validation:**
- [Introduction to pointblank Data Quality Workflow](https://rstudio.github.io/pointblank/articles/VALID-I.html)
- [R: Regulatory Compliance and Validation Issues (FDA)](https://www.r-project.org/doc/R-FDA.pdf)
- [R Packages for Data Quality Assessments](https://mdpi.com/2076-3417/12/9/4238/htm)

**PCORnet:**
- [PCORnet Common Data Model](https://pcornet.org/data/common-data-model/)
- [PCORnet CDM Specification v7.0](https://pcornet.org/wp-content/uploads/2025/05/PCORnet_Common_Data_Model_v70_2025_05_01.pdf)

**Encounter Deduplication:**
- [Clinical encounter heterogeneity in networked EHR data (N3C/RECOVER)](https://www.medrxiv.org/content/10.1101/2022.10.14.22281106v2)
- [De-duplication – The Epidemiologist R Handbook](https://www.epirhandbook.com/en/new_pages/deduplication.html)

**Reproducible Pipelines:**
- [Reproducible Research Pipelines Using R and RStudio](https://melindahiggins2000.github.io/SNRS2018_ReproducibleResearch/module_01.html)
- [Building Reproducible Research Pipelines in R](https://www.statology.org/building-reproducible-research-pipelines-in-r-from-data-collection-to-reporting/)
- [Reproducible Medical Research with R](https://bookdown.org/pdr_higgins/rmrwr/)

**Script Organization:**
- [Intermediate Steps Toward Reproducibility](https://bookdown.org/pdr_higgins/rmrwr/intermediate-steps-toward-reproducibility.html)
- [Workflow: scripts and projects – R for Data Science](https://r4ds.hadley.nz/workflow-scripts.html)

**Cancer Survivorship:**
- [Survivorship Is Expanding Cancer Care (2026)](https://reconstrategy.com/2026/01/survivorship-is-expanding-cancer-care-how-are-oncology-providers-responding/)
- [Cancer treatment and survivorship statistics, 2025](https://pmc.ncbi.nlm.nih.gov/articles/PMC12223361/)

**CONSORT & Cohort Construction:**
- [CONSORT 2025 Statement: updated guideline](https://www.equator-network.org/reporting-guidelines/consort/)
- [CONSORT extension for cohorts and routinely collected data](https://pubmed.ncbi.nlm.nih.gov/33926904/)

**Statistical Analysis Plans:**
- [A template for authoring statistical analysis plans](https://pmc.ncbi.nlm.nih.gov/articles/PMC10300078/)
- [How to Develop a Statistical Analysis Plan For Clinical Trials](https://www.kolabtree.com/blog/how-to-develop-a-statistical-analysis-plan-sap-for-clinical-trials/)

---
*Research complete: 2026-04-16*
*Overall confidence: MEDIUM-HIGH (strong on R methods, moderate on domain specifics)*
