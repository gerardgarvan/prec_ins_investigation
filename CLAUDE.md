<!-- GSD:project-start source:PROJECT.md -->
## Project

**Precision Cancer Survivorship — Insurance Investigation (SAS-to-R Conversion)**

A code forensics and translation project: untangle ~90 SAS files from the Precision Cancer Survivorship Cohort insurance investigation study, identify the correct analytical logic across multiple file versions, fix errors, and produce a clean modular R pipeline (tidyverse) that reproduces the intended analysis. The original SAS code runs on University of Florida HiPerGator using OneFlorida+/PCORnet CDM data.

**Core Value:** Produce a trustworthy, readable R pipeline where every analytical step has clear logic, so the research team can confidently understand and reproduce the insurance investigation results.

### Constraints

- **Language**: R with tidyverse (dplyr, tidyr, ggplot2, readr, haven for SAS import)
- **No data access**: Code must be written without running against data — parameterize all file paths
- **Preserve intent**: Fix logic errors but don't change the study design or variable definitions
- **PCORnet CDM compliance**: Variable names and coding must align with PCORnet Common Data Model conventions
- **SAS7BDAT input**: Data files are in SAS format — use haven::read_sas() for import
<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->
## Technology Stack

## Recommended Stack
### Core Framework: Tidyverse Ecosystem
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **tidyverse** | 2.0.0+ | Meta-package loading core ecosystem | Loads all essential packages (dplyr, tidyr, ggplot2, readr, purrr, tibble, stringr, forcats, lubridate) in one command. Standard for modern R data science. |
| **dplyr** | 1.2.1 | Data manipulation (filter, select, mutate, summarize, join) | De facto standard for data wrangling. Pipe-friendly syntax (`%>%` or `|>`) mirrors SAS DATA step logic but uses declarative rather than sequential processing. |
| **tidyr** | 1.3.2 | Data reshaping (pivot, separate, unite) | Converts between long/wide formats. Essential for PCORnet CDM table joining and reshaping encounter-level to patient-level data. |
| **readr** | 2.2.0 | CSV/TSV import with type detection | Fast, consistent rectangular data import. Use for intermediate CSV outputs between pipeline stages. |
| **purrr** | 1.2.2 | Functional programming (map, reduce) | Apply functions across lists/vectors. Useful for batch processing multiple datasets or iterating analyses across stratified groups. |
| **tibble** | 3.3.1 | Modern data frame (enhanced printing, strict subsetting) | Safer than base data.frame. Better printing for wide/long clinical datasets. Auto-loaded with tidyverse. |
| **stringr** | 1.6.0 | String manipulation | Consistent string functions (str_detect, str_replace, str_extract). Use for recoding insurance names, parsing diagnosis codes, cleaning free-text fields. |
| **forcats** | 1.0.1 | Factor/categorical variable management | Reorder, collapse, recode factor levels. Critical for converting SAS formats to R factors and managing categorical variables (race, cancer site, insurance type). |
| **lubridate** | 1.9.5 | Date/time manipulation | Parse dates, calculate intervals, extract components. Essential for enrollment periods, follow-up time, person-time calculations. |
### SAS Data Import and Format Translation
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **haven** | 2.5.5 | Read SAS7BDAT files, import SAS formats | Official tidyverse package for SAS file import. `read_sas()` handles both .sas7bdat data files and .sas7bcat format catalogs. Preserves variable labels and converts SAS value formats to `labelled()` class. |
- `read_sas("file.sas7bdat", catalog_file = "formats.sas7bcat")` — Read SAS data with formats
- `as_factor(data, levels = "labels")` — Convert labelled vectors to R factors
- `print_labels(variable)` — Inspect SAS format mappings
### Data Cleaning and Quality
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **janitor** | 2.2.1 | Column name standardization, duplicate detection, frequency tables | Clinical datasets (especially from EHR/CDM) have inconsistent naming conventions. `clean_names()` converts to snake_case. `get_dupes()` finds duplicate patient records. `tabyl()` creates crosstabs with totals/percentages. |
- `clean_names()` — Standardize column names (spaces → underscores, camelCase → snake_case)
- `get_dupes(patient_id, encounter_date)` — Identify duplicate records
- `tabyl(var1, var2)` — Frequency table with totals
- `remove_empty("rows")` or `remove_empty("cols")` — Drop empty rows/columns
### Statistical Analysis: Descriptive Statistics and Table 1
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **gtsummary** | 2.5.0 | Table 1 creation, descriptive statistics, statistical test tables | Industry-leading package for clinical Table 1 as of 2025-2026. Automatically detects variable types (continuous, categorical, binary), calculates appropriate summary statistics (median/IQR, n/%), performs statistical tests (chi-square, Wilcoxon), and produces publication-ready tables. Replaces older `tableone` package. |
| **rstatix** | 0.7.3 | Pipe-friendly statistical tests (chi-square, Wilcoxon, t-test) | Tidyverse-compatible wrapper for base R statistical tests. Returns tidy data frames instead of messy test objects. Use for custom statistical testing workflows not covered by gtsummary. |
- `tbl_summary(data, by = exposure_group)` — Create Table 1 stratified by groups
- `add_p()` — Add p-values from chi-square (categorical) or Wilcoxon (continuous) tests
- `add_overall()` — Add overall column
- `modify_header()`, `modify_spanning_header()` — Customize headers
- `chisq_test(var ~ group)` — Chi-square test, tidy output
- `wilcox_test(value ~ group)` — Wilcoxon rank sum test
- `t_test(value ~ group)` — T-test
- `get_summary_stats(group_by = ...)` — Descriptive stats by group
### Statistical Analysis: Regression Models
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **MASS** | 7.3-65 | Negative binomial regression (`glm.nb()`) | Standard package for negative binomial GLM. Included with base R installation. Use for overdispersed count outcomes (visit rates) where variance exceeds mean. |
| **stats** (base R) | Built-in | Poisson regression (`glm(family = poisson)`) | Base R GLM framework. Use for count outcomes with person-time offset. Test Poisson first, then switch to negative binomial if overdispersion detected. |
| **broom** | 1.0.12 | Tidy regression output (coefficients, confidence intervals, model fit) | Converts messy regression objects (lm, glm, glm.nb) into tidy tibbles. Essential for extracting coefficients, standard errors, p-values, and confidence intervals into data frames for reporting or visualization. |
# MASS is pre-installed with R
# broom
# Poisson regression with person-time offset
# Check for overdispersion (variance > mean)
# If overdispersed, use negative binomial:
# Tidy output
### Visualization
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **ggplot2** | 4.0.2 | Publication-quality graphics (bar charts, boxplots, scatter plots, forest plots) | De facto standard for R data visualization. Grammar of Graphics framework provides systematic approach to building complex plots. Used in clinical research for TFLs (Tables, Figures, Listings), forest plots for regression results, Kaplan-Meier curves, and data exploration. |
# Included in tidyverse
- **Distributions:** `geom_histogram()`, `geom_density()`, `geom_boxplot()`
- **Categorical comparisons:** `geom_bar()`, `geom_col()`
- **Forest plots:** `geom_point()` + `geom_errorbarh()` for regression coefficients with confidence intervals
- **Survival curves:** `geom_step()` with survival package output
- **Faceting:** `facet_wrap(~ cancer_site)` for stratified plots
### Project Management and Reproducibility
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **renv** | 1.2.2 | Project-local package management, version locking | Freezes package versions for reproducibility. Creates project-specific library and renv.lock file documenting exact package versions. Essential for long-term clinical research projects where package updates may break code. |
| **here** | 1.0.2 | Project-relative file paths | Eliminates hardcoded paths and `setwd()` calls. `here("data", "raw", "encounters.sas7bdat")` always resolves relative to project root, regardless of where script is executed. Critical for modular scripts (01_clean.R, 02_merge.R, etc.) that run from master script. |
# Initialize renv in project
# Install packages (tracked automatically)
# Snapshot current package versions
# Restore environment on different machine
# Declare project root (run once in main script)
# Build paths relative to project root
### Supporting Tools (Optional but Recommended)
| Technology | Version | Purpose | When to Use |
|------------|---------|---------|-------------|
| **survival** | 3.8-6 | Survival analysis (Kaplan-Meier, Cox regression) | If analyzing time-to-event outcomes (time to insurance loss, time to survivorship care visit). Not required for baseline cross-sectional analysis but useful for longitudinal follow-up. |
| **targets** | Latest | Pipeline workflow automation, dependency tracking | Advanced: Automates pipeline execution, skips up-to-date steps, parallelizes independent tasks. Consider for complex multi-stage pipelines. May be overkill for this project's 10-15 modular scripts. |
- **survival:** Standard package for time-to-event analysis in cancer research. Includes Kaplan-Meier curves, log-rank tests, Cox proportional hazards models. Only needed if project expands to survival outcomes.
- **targets:** Make-like pipeline tool. Tracks dependencies between scripts, only reruns changed steps. Useful for large pipelines with expensive computation, but adds complexity. Start with simple master runner script; migrate to targets if pipeline becomes unwieldy.
## Alternatives Considered
| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| **Table 1** | gtsummary | tableone | tableone was pre-2020 standard. gtsummary offers better tidyverse integration, cleaner syntax, and is actively maintained. |
| **SAS Import** | haven | foreign, sas7bdat | foreign is deprecated (last update 2022). sas7bdat package has limited format support. haven is official tidyverse solution with active maintenance. |
| **Data Manipulation** | dplyr + tidyr | data.table, base R | data.table is faster for very large datasets (millions of rows) but has different syntax. Base R (transform, subset, merge) is verbose and less readable. Tidyverse is clinical research standard. |
| **String Processing** | stringr | base R (grep, gsub, substr) | Base R string functions have inconsistent argument order and return types. stringr provides consistent str_* function family. |
| **Pipeline Automation** | Manual scripts | targets, drake | drake is superseded by targets. targets adds complexity; delay adoption until pipeline stability is proven. |
| **Statistical Tests** | gtsummary + rstatix | base R (chisq.test, wilcox.test) | Base R test functions return complex objects requiring manual extraction. rstatix/gtsummary return tidy data frames compatible with dplyr/ggplot2. |
## NOT Recommended: Pharmaverse Packages
## Installation Script
# Install tidyverse (includes dplyr, tidyr, ggplot2, readr, purrr, tibble, stringr, forcats, lubridate)
# SAS import and format translation
# Data cleaning
# Table 1 and descriptive statistics
# Statistical tests (pipe-friendly)
# Regression model tidying
# MASS for negative binomial (pre-installed with R, but load explicitly)
# Project management
# Optional: survival analysis
# Initialize renv for version control
## Version Notes
- **Core tidyverse packages** (dplyr, tidyr, ggplot2, readr): Updated 2-4 times per year. Breaking changes are rare and well-documented.
- **haven, gtsummary, broom:** Updated 1-2 times per year.
- **renv:** Use renv.lock to freeze versions. Do not update packages mid-project unless critical bug fixes are needed.
## Sources
### Tidyverse Ecosystem
- [Tidyverse Official Documentation](https://tidyverse.org/packages/)
- [dplyr CRAN Package](https://cran.r-project.org/web/packages/dplyr/index.html)
- [tidyr CRAN Package](https://cran.r-project.org/web/packages/tidyr/index.html)
- [readr CRAN Package](https://cran.r-project.org/web/packages/readr/index.html)
- [purrr CRAN Package](https://cran.r-project.org/web/packages/purrr/index.html)
- [tibble CRAN Package](https://cran.r-project.org/web/packages/tibble/index.html)
- [stringr CRAN Package](https://cran.r-project.org/web/packages/stringr/index.html)
- [forcats CRAN Package](https://cran.r-project.org/web/packages/forcats/index.html)
- [lubridate CRAN Package](https://cran.r-project.org/web/packages/lubridate/index.html)
- [Clinical Data Wrangling with tidyverse](https://www.atorusresearch.com/r-programming-for-clinical-trial-analytics/)
### SAS Data Import
- [haven Official Documentation](https://haven.tidyverse.org/)
- [haven CRAN Package](https://cran.r-project.org/web/packages/haven/index.html)
- [haven: Read SAS Files Reference](https://haven.tidyverse.org/reference/read_sas.html)
- [SAS to R Migration Guide](https://www.appsilon.com/post/transitioning-from-sas-to-r)
- [haven Conversion Semantics](https://haven.tidyverse.org/articles/semantics.html)
### Data Cleaning
- [janitor CRAN Package](https://cran.r-project.org/web/packages/janitor/index.html)
- [janitor Official Documentation](https://sfirke.r-universe.dev/janitor)
- [Must-Know janitor Functions](https://medium.com/@sridharansrini13/must-know-janitor-functions-every-data-analyst-should-learn-454cac3f20ba)
### Statistical Analysis (Table 1)
- [gtsummary Official Documentation](https://www.danieldsjoberg.com/gtsummary/)
- [gtsummary CRAN Package](https://cran.r-project.org/web/packages/gtsummary/index.html)
- [Building Table One with gtsummary](https://bookdown.org/pdr_higgins/rmrwr/building-your-table-one-with-the-gtsummary-package.html)
- [gtsummary tbl_summary Tutorial](https://www.danieldsjoberg.com/gtsummary/articles/tbl_summary.html)
- [rstatix CRAN Package](https://cran.r-project.org/web/packages/rstatix/index.html)
- [rstatix Official Documentation](https://rpkgs.datanovia.com/rstatix/)
### Statistical Analysis (Regression)
- [MASS Package Documentation](https://stat.ethz.ch/R-manual/R-devel/library/MASS/html/00Index.html)
- [glm.nb Reference](https://stat.ethz.ch/R-manual/R-devel/library/MASS/html/glm.nb.html)
- [Negative Binomial Regression in R](https://stats.oarc.ucla.edu/r/dae/negative-binomial-regression/)
- [Poisson and Negative Binomial Regression Guide](https://francish.net/post/poisson-and-negative-binomial-regression-using-r/)
- [broom CRAN Package](https://cran.r-project.org/web/packages/broom/index.html)
- [broom Official Documentation](https://broom.tidymodels.org/)
- [Linear Regression and Broom](https://bookdown.org/pdr_higgins/rmrwr/linear-regression-and-broom-for-tidying-models.html)
### Visualization
- [ggplot2 Official Documentation](https://ggplot2.tidyverse.org/)
- [ggplot2 CRAN Package](https://cran.r-project.org/web/packages/ggplot2/index.html)
- [Clinical Data Visualization with ggplot2](https://www.atorusresearch.com/open-source-data-visualization-enhancing-tfl-creation-with-r-for-clinical-data-analysis/)
- [Application of ggplot2 to Pharmacometric Graphics](https://pmc.ncbi.nlm.nih.gov/articles/PMC3817376/)
### Project Management
- [renv Official Documentation](https://rstudio.github.io/renv/)
- [renv CRAN Package](https://cran.r-project.org/web/packages/renv/index.html)
- [Introduction to renv](https://rstudio.github.io/renv/articles/renv.html)
- [here Official Documentation](https://here.r-lib.org/)
- [here CRAN Package](https://cran.r-project.org/web/packages/here/index.html)
- [How to Use the here Package](https://jenrichmond.rbind.io/post/how-to-use-the-here-package/)
### SAS-to-R Clinical Research
- [Bilingual Clinical Programmer: SAS + R in 2026](https://www.acldigital.com/blogs/bilingual-clinical-programmer-sas-r-clinical-trials)
- [Transitioning from SAS to R: Pharmaverse Ecosystem](https://procogia.com/transitioning-clinical-research-from-sas-to-r-an-introduction-to-the-pharmaverse-ecosystem/)
- [SAS to R Migration in Clinical Research](https://inductivequotient.com/sas-to-r-migration-in-clinical-trials/)
- [Using R for Clinical Trial Data Analysis](https://www.quanticate.com/blog/r-programming-in-clinical-trials)
### PCORnet Common Data Model
- [PCORnet Common Data Model Overview](https://pcornet.org/data/common-data-model/)
- [PCORnet CDM Specification v7.0](https://pcornet.org/wp-content/uploads/2025/05/PCORnet_Common_Data_Model_v70_2025_05_01.pdf)
### Optional Tools
- [survival CRAN Package](https://cran.r-project.org/web/packages/survival/index.html)
- [Survival Analysis in R](https://www.emilyzabor.com/tutorials/survival_analysis_in_r_tutorial.html)
- [targets Official Documentation](https://books.ropensci.org/targets/)
- [Reproducible Pipelines with targets](https://www.appsilon.com/post/r-targets-reproducible-data-science-pipeline)
## Confidence Assessment
| Area | Confidence | Rationale |
|------|------------|-----------|
| **Tidyverse packages** | HIGH | Verified via CRAN (April 2026). Industry standard for R data science. Extensive documentation and clinical research use cases. |
| **haven for SAS import** | HIGH | Official tidyverse package. Verified current version (2.5.5, May 2025) via CRAN. Authoritative for SAS7BDAT import. |
| **gtsummary for Table 1** | HIGH | Current best practice (replaced tableone post-2020). Verified version (2.5.0, December 2025) via CRAN. |
| **MASS for negative binomial** | HIGH | Standard R package for negative binomial GLM. Pre-installed with R. Well-documented for clinical research. |
| **renv and here** | HIGH | Best practices for reproducibility and project organization. Verified versions via CRAN. |
| **Pharmaverse exclusion** | HIGH | Domain mismatch confirmed: pharmaverse targets CDISC SDTM/ADaM for regulatory trials, not PCORnet CDM observational research. |
| **Package versions** | HIGH | All versions verified via CRAN WebFetch as of April 2026. |
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd:quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd:debug` for investigation and bug fixing
- `/gsd:execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd:profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
