# Architecture Research

**Domain:** Clinical Research R Data Pipeline (Observational Cohort Study)
**Researched:** 2026-04-16
**Confidence:** MEDIUM

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           OUTPUTS                                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐                │
│  │ Table 1  │  │ Bivariate│  │Regression│  │ Formatted│                │
│  │          │  │  Tests   │  │  Models  │  │  Tables  │                │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘                │
├───────┴──────────────┴──────────────┴──────────────┴──────────────────────┤
│                        ANALYSIS LAYER                                    │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ Statistical Analysis Scripts (models, tests, summaries)           │  │
│  └───────────────────────────────────────────────────────────────────┘  │
├──────────────────────────────────────────────────────────────────────────┤
│                     ANALYTICAL DATASET LAYER                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐                │
│  │ Cohort   │  │ Exposures│  │ Outcomes │  │Covariates│                │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘                │
├───────┴──────────────┴──────────────┴──────────────┴──────────────────────┤
│                    DATA PROCESSING LAYER                                 │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │  Cleaning → Merging → Derivation → Quality Checks                 │  │
│  └───────────────────────────────────────────────────────────────────┘  │
├──────────────────────────────────────────────────────────────────────────┤
│                          DATA IMPORT LAYER                               │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐                │
│  │ PCORnet  │  │ External │  │  Format  │  │  Encoded │                │
│  │   CDM    │  │ Reference│  │ Catalog  │  │  Lookups │                │
│  │(SAS7BDAT)│  │  Data    │  │  (SAS)   │  │          │                │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘                │
└──────────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| Data Import | Read raw data files (SAS7BDAT), apply formats, initial type conversion | haven::read_sas(), readr::read_csv(), variable labeling |
| Data Cleaning | Standardize variables, handle missing data, recode values, remove duplicates | dplyr::mutate(), tidyr::drop_na(), case_when() |
| Data Merging | Join multiple data sources (encounters, diagnoses, demographics) | dplyr::left_join(), inner_join(), anti_join() |
| Variable Derivation | Create computed variables (age categories, time windows, flags) | dplyr::mutate(), lubridate for dates |
| Cohort Construction | Apply inclusion/exclusion criteria, define study population | dplyr::filter(), semi_join() |
| Exposure Creation | Define treatment/intervention variables and groupings | dplyr::mutate(), case_when(), factor() |
| Outcome Creation | Calculate endpoints (visit counts, person-time, binary outcomes) | dplyr::summarize(), group_by(), time calculations |
| Covariate Processing | Prepare adjustment variables for modeling (demographics, geography, clinical) | mutate(), factor(), reference category assignment |
| Statistical Analysis | Descriptive statistics, hypothesis tests, regression models | gtsummary::tbl_summary(), stats::glm(), MASS::glm.nb() |
| Output Generation | Formatted tables, model summaries, export to publication formats | gtsummary, gt, flextable, export functions |

## Recommended Project Structure

```
project_root/
├── _run_all.R              # Master script to execute full pipeline
├── renv.lock               # Package version lock file for reproducibility
├── .Rprofile               # renv activation
├── config/
│   ├── file_paths.R        # Parameterized file locations (no data access)
│   └── study_parameters.R  # Study-specific constants (dates, thresholds)
├── R/
│   ├── utils/              # Reusable helper functions
│   │   ├── data_quality.R  # Quality check functions
│   │   ├── formatting.R    # Output formatting helpers
│   │   └── pcornet_helpers.R # PCORnet CDM-specific functions
│   └── functions/          # Analysis-specific functions
│       ├── cohort_functions.R
│       ├── exposure_functions.R
│       └── outcome_functions.R
├── scripts/
│   ├── 01_import_raw_data.R          # Import SAS files with haven
│   ├── 02_clean_core_tables.R        # Clean encounters, demographics, etc.
│   ├── 03_merge_encounters.R         # Merge encounter-related data
│   ├── 04_derive_variables.R         # Create computed variables
│   ├── 05_construct_cohort.R         # Apply inclusion/exclusion criteria
│   ├── 06_create_exposures.R         # Define exposure variables
│   ├── 07_create_outcomes.R          # Calculate outcome variables
│   ├── 08_process_covariates.R       # Prepare covariates for modeling
│   ├── 09_data_quality_checks.R      # Validation and quality assurance
│   ├── 10_create_table1.R            # Baseline characteristics table
│   ├── 11_bivariate_tests.R          # Chi-square, Wilcoxon tests
│   ├── 12_regression_models.R        # Poisson/negative binomial models
│   └── 13_format_outputs.R           # Final table formatting and export
├── data/                   # NOT in version control
│   ├── raw/                # Original SAS7BDAT files (read-only)
│   ├── processed/          # Intermediate cleaned datasets (.rds files)
│   └── analytical/         # Final analytical datasets (.rds files)
├── output/                 # Generated outputs
│   ├── tables/             # Table 1, descriptive tables
│   ├── models/             # Regression model results
│   └── logs/               # Execution logs, QC reports
├── docs/
│   ├── data_dictionary.md  # Variable definitions
│   ├── logic_decisions.md  # Documented logic corrections from SAS
│   └── analysis_plan.md    # Reconstructed analysis intent
└── tests/                  # Optional: Unit tests for functions
    └── test_cohort_construction.R
```

### Structure Rationale

- **Numbered scripts (01-13):** Clear execution order, explicit dependencies. File names indicate pipeline stage. Numbering makes workflow self-documenting.
- **Separation of functions from scripts:** Functions in R/ are reusable and testable. Scripts in scripts/ orchestrate the workflow using those functions. This follows R package conventions.
- **config/ for parameters:** All file paths and study-specific constants in one place. Makes transition to real data straightforward (update paths once, not throughout scripts).
- **data/ split by processing stage:** Raw data is read-only and never modified. Processed data is intermediate checkpoints. Analytical data is ready for analysis. Allows resuming workflow at any stage.
- **Modular script design:** Each script has a single responsibility (import, clean, merge, etc.). Easier to debug, test, and modify individual components without breaking the entire pipeline.
- **_run_all.R master script:** Single entry point to execute entire pipeline sequentially. Uses source() to run numbered scripts in order.

## Architectural Patterns

### Pattern 1: Sequential Numbered Scripts with Master Runner

**What:** Analysis pipeline organized as numbered scripts (01, 02, 03...) executed sequentially by a master script. Each script reads from previous stage, performs one transformation, writes to next stage.

**When to use:** Complex multi-stage data pipelines with clear sequential dependencies. Typical in observational research where data flows: raw → cleaned → merged → analytical → results.

**Trade-offs:**
- **Pros:** Clear execution order, easy to understand workflow, can resume at any stage, each script testable independently
- **Cons:** Less sophisticated than targets/drake for dependency management, no automatic skip-if-unchanged, manual coordination of intermediate files

**Example:**
```r
# _run_all.R
source("scripts/01_import_raw_data.R")
source("scripts/02_clean_core_tables.R")
source("scripts/03_merge_encounters.R")
source("scripts/04_derive_variables.R")
# ... continue through 13

# Each script follows pattern:
# 01_import_raw_data.R
library(tidyverse)
library(haven)
source("config/file_paths.R")

# Read SAS data
encounters_raw <- read_sas(path_encounters, catalog_file = path_formats)

# Save intermediate
saveRDS(encounters_raw, "data/processed/encounters_raw.rds")
```

### Pattern 2: Targets/Drake Pipeline (Alternative Modern Approach)

**What:** Function-oriented pipeline where each step is defined as a target (output) with explicit dependencies. The targets package automatically determines what needs to re-run when code or data changes.

**When to use:** Long-running pipelines where partial re-execution saves time. Teams familiar with Make-like workflows. Projects with complex branching dependencies (not strictly linear).

**Trade-offs:**
- **Pros:** Intelligent caching (skips up-to-date targets), dependency graph visualization, implicit parallelization, better for iterative development
- **Cons:** Steeper learning curve, requires refactoring code into functions, less transparent execution order for unfamiliar users, harder to debug for non-experts

**Example:**
```r
# _targets.R
library(targets)
library(tarchetypes)

list(
  tar_target(encounters_raw, read_sas(path_encounters)),
  tar_target(encounters_clean, clean_encounters(encounters_raw)),
  tar_target(cohort, construct_cohort(encounters_clean, demographics)),
  tar_target(table1, create_table1(cohort))
)

# Run with: tar_make()
# Visualize with: tar_visnetwork()
```

**Recommendation for this project:** Start with Pattern 1 (numbered scripts) for transparency and ease of understanding during SAS-to-R translation. Consider migrating to Pattern 2 (targets) in a future refactor if re-running the full pipeline becomes time-prohibitive.

### Pattern 3: Tidy Data and Functional Pipelines

**What:** Keep data in tidy format (each variable a column, each observation a row, each table a type of observational unit) and use functional pipelines (dplyr/tidyr verbs chained with pipes).

**When to use:** Always in tidyverse-based projects. Core organizing principle for data structure and transformation.

**Trade-offs:**
- **Pros:** Readable, composable transformations. Consistent interface across packages. Easier to understand what data looks like at each step.
- **Cons:** Can be verbose for simple operations. Memory overhead for large datasets (though usually fine for clinical research scale).

**Example:**
```r
# Tidy pipeline for cohort construction
cohort <- encounters_clean |>
  filter(admit_date >= study_start_date, admit_date <= study_end_date) |>
  left_join(diagnoses, by = "encounter_id") |>
  filter(str_detect(dx_code, "^C")) |>  # Cancer diagnoses (ICD-10 C codes)
  group_by(patid) |>
  filter(n() >= 1) |>  # At least one cancer diagnosis
  ungroup() |>
  select(patid, admit_date, dx_code, insurance_type) |>
  distinct()
```

### Pattern 4: Config-Driven Parameterization

**What:** All file paths, dates, thresholds, and study-specific parameters defined in config files, not hardcoded in analysis scripts.

**When to use:** When code will be reused with different data sources or when file paths change (common in multi-environment research: local, HPC cluster, different data versions).

**Trade-offs:**
- **Pros:** Easy to adapt to new data locations. Clear documentation of assumptions. Prevents errors from scattered hardcoded values.
- **Cons:** Extra indirection. Need to remember to update config files instead of scripts.

**Example:**
```r
# config/file_paths.R
path_data_root <- "/blue/erin.mobley-precision/"
path_encounters <- file.path(path_data_root, "encounters.sas7bdat")
path_diagnoses <- file.path(path_data_root, "diagnoses.sas7bdat")

# config/study_parameters.R
study_start_date <- as.Date("2015-01-01")
study_end_date <- as.Date("2020-12-31")
followup_months <- 24
min_age <- 18
```

## Data Flow

### Pipeline Execution Flow

```
Raw Data (SAS7BDAT)
    ↓ [01_import]
Raw R Objects (.rds)
    ↓ [02_clean]
Cleaned Tables (.rds)
    ↓ [03_merge]
Merged Encounters (.rds)
    ↓ [04_derive]
Derived Variables (.rds)
    ↓ [05_cohort]
Study Cohort (.rds)
    ↓ [06_exposures] [07_outcomes] [08_covariates] (parallel branches)
Analytical Dataset (.rds)
    ↓ [10_table1] [11_bivariate] [12_regression] (parallel analyses)
Statistical Outputs
    ↓ [13_format]
Publication Tables (.docx, .csv, .html)
```

### Cohort Construction Data Flow

```
All Patients (demographics)
    ↓ [join]
Encounter History
    ↓ [filter: valid enrollment]
Enrolled Patients
    ↓ [filter: cancer diagnosis]
Cancer Survivors
    ↓ [filter: study period]
Study-Eligible Cohort
    ↓ [filter: data quality checks]
Final Analytical Cohort
```

### Analytical Dataset Assembly Flow

```
                 Study Cohort (N patients)
                        ↓
        ┌───────────────┼───────────────┐
        ↓               ↓               ↓
   Exposures       Outcomes        Covariates
(insurance      (visit counts,   (demographics,
 change,         person-time,     SDI, RUCA,
 treatment       survivorship     age groups)
 intensity)      encounters)
        ↓               ↓               ↓
        └───────────────┼───────────────┘
                        ↓
            Analytical Dataset (1 row per patient)
```

### Key Data Flows

1. **Import with format preservation:** haven::read_sas() imports SAS7BDAT files with catalog_file for value labels → convert to factors with haven::as_factor() → preserve metadata as attributes
2. **Progressive filtering for cohort:** Start with all patients → filter valid enrollment → filter cancer diagnosis → filter study period → filter data quality → produces progressively smaller datasets with clear inclusion counts
3. **Horizontal merge for analytical dataset:** Cohort (patid) + exposures (patid-level) + outcomes (patid-level) + covariates (patid-level) → single wide table ready for modeling
4. **Statistical output generation:** Analytical dataset → gtsummary::tbl_summary() for Table 1 → stats::glm() or MASS::glm.nb() for models → format and export tables

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| <10k patients | Standard numbered scripts. Read full datasets into memory. Single-threaded execution. Expected runtime: minutes to hours. |
| 10k-1M patients | Consider data.table for faster operations on large data. Use arrow/parquet for faster intermediate storage instead of .rds. Parallelize independent analyses (table1, bivariate, models) with furrr or parallel. Expected runtime: hours. |
| 1M+ patients | Database backend (DuckDB, SQLite) for data that exceeds memory. Use dbplyr for dplyr syntax with database queries. Targets/drake for intelligent caching. Cluster computing (HPC) for model fitting. Expected runtime: hours to days. |

### Scaling Priorities

1. **First bottleneck:** Reading large SAS files repeatedly. **Fix:** Save cleaned data as .rds or parquet after initial import. Read intermediate files in subsequent scripts instead of re-importing raw SAS every time.
2. **Second bottleneck:** Memory limits on large merged datasets. **Fix:** Use data.table or arrow for memory-efficient operations. Filter to necessary variables early. Consider database backend (DuckDB) for SQL-based joins and aggregations.
3. **Third bottleneck:** Long-running regression models. **Fix:** Parallelize model fitting across multiple cores (furrr::future_map()). Use HPC resources if available. Targets for caching completed models.

**Note for this project:** With ~90 SAS files to consolidate, expect data to be manageable in-memory on modern workstations. Initial focus should be correctness and clarity, not performance optimization.

## Anti-Patterns

### Anti-Pattern 1: Hardcoded File Paths in Every Script

**What people do:** Each script has `read_sas("/blue/erin.mobley-precision/encounters.sas7bdat")` scattered throughout.

**Why it's wrong:** When data location changes (moving from HiPerGator to local, switching to v5 data), must find and update dozens of hardcoded paths. High risk of errors (forgetting to update one, typos in paths).

**Do this instead:** Centralize all file paths in `config/file_paths.R`. Scripts source this config and reference variables like `path_encounters`. Update path once, all scripts use new location.

### Anti-Pattern 2: Monolithic Script Files

**What people do:** Single 3000-line script that imports, cleans, merges, analyzes, and outputs results.

**Why it's wrong:** Difficult to debug (must re-run everything to test one section). Hard to understand workflow. Impossible to resume at intermediate stage if early steps already completed. Collaboration nightmare (merge conflicts).

**Do this instead:** Modular numbered scripts with single responsibilities. Save intermediate outputs (.rds files). Each script can be run independently if prerequisites exist.

### Anti-Pattern 3: Overwriting Raw Data

**What people do:** Read raw SAS file → clean → save back to same filename or in same folder.

**Why it's wrong:** Irreversible. If cleaning logic is wrong, original data is lost. Violates principle of raw data as read-only source of truth.

**Do this instead:** Raw data in `data/raw/` (read-only, never modified). Processed data in `data/processed/`. Analytical data in `data/analytical/`. Clear separation and audit trail.

### Anti-Pattern 4: Implicit Assumptions Without Documentation

**What people do:** Code has logic like `filter(days_since_dx > 30)` without explanation why 30 days.

**Why it's wrong:** Future readers (including future you) don't know if 30 is arbitrary, required by IRB, standard in literature, or a bug. Cannot validate correctness.

**Do this instead:** Comment the reasoning: `# Exclude diagnoses within 30 days of enrollment (capture prevalent cases per protocol)`. Use named constants in config: `min_dx_days <- 30`.

### Anti-Pattern 5: Recreating Helper Functions in Every Script

**What people do:** Each script re-defines the same custom function (e.g., age calculation, format cleaning).

**Why it's wrong:** Code duplication. If bug found or logic updated, must fix in multiple places. Inconsistent behavior if functions diverge.

**Do this instead:** Define helper functions once in `R/utils/` or `R/functions/`. Scripts source and call those functions. Single source of truth for shared logic.

### Anti-Pattern 6: No Data Quality Checks

**What people do:** Import data → analyze → export results. Trust that data is correct.

**Why it's wrong:** Clinical data is messy (missing values, impossible dates, duplicate records, inconsistent coding). Silently wrong results are worse than errors.

**Do this instead:** Dedicated quality check script (`09_data_quality_checks.R`). Validate expected ranges, check for duplicates, flag missing data, assert business rules. Log check results. Fail loudly if critical checks fail.

### Anti-Pattern 7: Using Base R merge() for Complex Joins

**What people do:** `merge(df1, merge(df2, df3, by="id"), by="id", all.x=TRUE)` with nested merges and unclear join types.

**Why it's wrong:** Hard to read. Unclear join type (left, inner, full?). Order of operations confusing. Difficult to debug mismatches.

**Do this instead:** dplyr joins with explicit type: `df1 |> left_join(df2, by="id") |> left_join(df3, by="id")`. Pipe makes order clear. Join type explicit. Easier to inspect intermediate results.

## Integration Points

### External Data Sources

| Source | Integration Pattern | Notes |
|--------|---------------------|-------|
| PCORnet CDM (SAS7BDAT) | haven::read_sas() with catalog_file for formats | Encoding may need specification (UTF-8, latin1). Check with encoding = NULL to use file's encoding. |
| SDI Score (CSV) | readr::read_csv() | External reference data. Join by geographic identifier (ZIP, county FIPS). |
| RUCA Codes (CSV) | readr::read_csv() | Rural-Urban Commuting Area codes. Join by ZIP code. |
| Cancer Site Groups (Excel) | readxl::read_excel() | Custom groupings. May need manual data entry or import from existing definitions. |
| Chemotherapy NDC Codes (CSV) | readr::read_csv() | National Drug Codes for identifying chemotherapy. Join with procedure/medication tables. |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| Import ↔ Cleaning | .rds files in data/processed/ | Raw imported objects with minimal transformation. Variable names, types preserved from SAS. |
| Cleaning ↔ Merging | .rds files in data/processed/ | Cleaned tables (standardized names, recoded values, removed duplicates). Ready for joins. |
| Merging ↔ Derivation | .rds files in data/processed/ | Merged encounter-level data. Still observational unit = encounter or diagnosis record. |
| Derivation ↔ Cohort | .rds files in data/analytical/ | Derived variables added (age groups, time windows, flags). Ready for cohort filtering. |
| Cohort ↔ Exposures/Outcomes/Covariates | .rds files in data/analytical/ | Study cohort defined. Branches into parallel analytical variable creation. |
| Analytical Dataset ↔ Statistical Analysis | .rds file in data/analytical/ | Single analytical dataset (1 row per patient). All variables needed for modeling. |
| Statistical Analysis ↔ Output | R objects (tibbles, model fits) | In-memory results from gtsummary, glm(). Passed to formatting functions. |
| Output ↔ Export | Files in output/tables/, output/models/ | Formatted tables (.docx, .csv, .html). Model summaries (.txt, .rds for later use). |

**Key principle:** Each boundary represents a clear checkpoint. Downstream scripts can start from saved intermediate files without re-running entire pipeline. Enables iterative development and debugging.

## Domain-Specific Patterns

### Pattern: PCORnet CDM Table Structure

**What:** PCORnet Common Data Model defines standardized table schemas (ENCOUNTER, DIAGNOSIS, DEMOGRAPHIC, ENROLLMENT, etc.) with required and optional variables, standard coding systems (ICD-10, CPT, NDC), and common data types.

**When to use:** When working with data from PCORnet Clinical Research Networks. Data already conforms to CDM schema.

**Trade-offs:**
- **Pros:** Standardized variable names and codes. Documentation available. Multi-site studies use same structure.
- **Cons:** May include many variables not needed for specific analysis. Some site-specific variations. Format catalog may be needed for coded values.

**Key tables for this project:**
- **DEMOGRAPHIC:** patid, birth_date, sex, race, hispanic
- **ENROLLMENT:** patid, enr_start_date, enr_end_date, chart (chart review flag), valid (valid enrollment flag)
- **ENCOUNTER:** encounterid, patid, admit_date, discharge_date, enc_type, provider_id
- **DIAGNOSIS:** diagnosisid, patid, encounterid, dx, dx_type, dx_date
- **PROCEDURES:** proceduresid, patid, encounterid, px, px_type, px_date
- **DISPENSING:** dispensingid, patid, ndc, dispense_date
- **PAYER/INSURANCE:** Custom table for insurance type coding (may vary by site)

**Best practice:** Keep PCORnet variable names intact during import and cleaning. Create derived variables with new names. Enables cross-referencing with CDM documentation.

### Pattern: Person-Time Calculation for Rate Outcomes

**What:** Calculate person-time denominator for visit rate outcomes (visits per person-year). Requires tracking enrollment periods, censoring events (death, end of follow-up), and accumulating time at risk.

**When to use:** Outcome is a count (number of visits) and exposure time varies between patients. Poisson or negative binomial regression with offset term.

**Example:**
```r
# Calculate person-time for each patient
person_time <- cohort |>
  group_by(patid) |>
  summarize(
    followup_start = min(enr_start_date, study_start_date, na.rm = TRUE),
    followup_end = min(enr_end_date, study_end_date, death_date, na.rm = TRUE),
    person_years = as.numeric(followup_end - followup_start) / 365.25
  ) |>
  ungroup()

# Poisson model with person-time offset
model <- glm(visit_count ~ exposure_group + age + sex + offset(log(person_years)),
             family = poisson(link = "log"),
             data = analytical_data)
```

### Pattern: Exposure Definition from Insurance Change

**What:** Define exposure as change in insurance type between baseline and follow-up. Requires longitudinal insurance data with temporal ordering.

**When to use:** Studying effect of insurance transitions on outcomes. Need to capture direction and magnitude of change.

**Example:**
```r
# Calculate insurance change (percentage change exposure)
insurance_change <- enrollment |>
  arrange(patid, enr_start_date) |>
  group_by(patid) |>
  mutate(
    baseline_insurance = first(insurance_type),
    followup_insurance = last(insurance_type),
    insurance_changed = baseline_insurance != followup_insurance,
    pct_change_ins = case_when(
      insurance_changed ~ 100,  # 100% change if type changed
      !insurance_changed ~ 0    # 0% change if type stayed same
    )
  ) |>
  ungroup()
```

## Sources

**MEDIUM Confidence Sources:**

Clinical Research R Project Organization:
- [R for Clinical Study Reports and Submission](https://r4csr.org/project-folder.html)
- [R Programming for Clinical Trial Analytics | Atorus Research](https://www.atorusresearch.com/r-programming-for-clinical-trial-analytics/)

Epidemiology R Workflows:
- [The Epidemiologist R Handbook](https://www.epirhandbook.com/en/)
- [Cohort Studies in R: A Comprehensive Guide](https://www.numberanalytics.com/blog/cohort-studies-in-r-biomedical-data-analysis)
- [CRAN Task View: Epidemiology](https://cran.r-project.org/web/views/Epidemiology.html)

R Project Structure Best Practices:
- [R for Data Science (2e) - Workflow: scripts and projects](https://r4ds.hadley.nz/workflow-scripts.html)
- [Structuring R projects | R-bloggers](https://www.r-bloggers.com/2018/08/structuring-r-projects/)
- [How to organize your analyses with R Studio Projects](https://www.rforecology.com/post/organizing-your-r-studio-projects/)

Tidyverse and Data Cleaning:
- [Tidy data](https://cran.r-project.org/web/packages/tidyr/vignettes/tidy-data.html)
- [Cleaning data and core functions – The Epidemiologist R Handbook](https://www.epirhandbook.com/en/new_pages/cleaning.html)

Targets Package (Pipeline Automation):
- [The {targets} R package user manual](https://books.ropensci.org/targets/)
- [Building Data Pipelines with {targets} | Reproducible Medical Research with R](https://bookdown.org/pdr_higgins/rmrwr/building-data-pipelines-with-targets.html)

Drake Package (Legacy Pipeline Tool):
- [Drake: A Pipeline Toolkit for Reproducible Computation at Scale](https://docs.ropensci.org/drake/)

Statistical Tables and Summaries:
- [gtsummary - Presentation-Ready Data Summary and Analytic Result Tables](https://www.danieldsjoberg.com/gtsummary/)
- [Building Your Table One with the {gtsummary} Package](https://bookdown.org/pdr_higgins/rmrwr/building-your-table-one-with-the-gtsummary-package.html)

Package Management:
- [Introduction to renv](https://rstudio.github.io/renv/articles/renv.html)

Haven Package for SAS Import:
- [Import and Export SPSS, Stata and SAS Files • haven](https://haven.tidyverse.org/)
- [Read SAS files — read_sas • haven](https://haven.tidyverse.org/reference/read_sas.html)
- [SAS to R Migration: How to Import, Process, and Export SAS Files in R](https://www.appsilon.com/post/transitioning-from-sas-to-r)

Observational Study Methods:
- [Exposure Definition and Measurement - NCBI Bookshelf](https://www.ncbi.nlm.nih.gov/books/NBK126191/)
- [Covariate Selection - NCBI Bookshelf](https://www.ncbi.nlm.nih.gov/books/NBK126194/)
- [Considerations for Statistical Analysis - NCBI Bookshelf](https://www.ncbi.nlm.nih.gov/books/NBK126192/)

PCORnet Common Data Model:
- [PCORnet Common Data Model Overview](https://www.rushu.rush.edu/sites/default/files/_Rush%20PDFs%20and%20Files/Research/CAPriCORN/2017-01-06-PCORnet-CDM-Lay-Guide.pdf)
- [PCORnet® Common Data Model (CDM) Specification](https://pcornet.org/resources/)

Data Quality and Validation:
- [Facilitating harmonized data quality assessments - BMC Medical Research Methodology](https://bmcmedresmethodol.biomedcentral.com/articles/10.1186/s12874-021-01252-7)
- [A Framework for Data Quality Assessment in Clinical Research Datasets - PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC5977591/)

**Confidence Assessment:**
MEDIUM confidence overall. Research draws from established R/tidyverse documentation, clinical research best practices, and epidemiology-specific workflows. However, no single authoritative source exists for "clinical research R pipeline architecture" — recommendations synthesized from multiple domain-specific sources. PCORnet-specific R implementation details are less documented (PCORnet CDM is well-defined, but most examples use SAS). Modern pipeline tools (targets) well-documented but adoption in clinical research still emerging.

---
*Architecture research for: Clinical Research R Data Pipeline (SAS-to-R Conversion)*
*Researched: 2026-04-16*
