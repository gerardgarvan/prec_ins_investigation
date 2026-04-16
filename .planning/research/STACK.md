# Technology Stack

**Project:** Precision Cancer Survivorship — SAS-to-R Conversion
**Domain:** Clinical research data pipeline (PCORnet CDM, cancer survivorship)
**Researched:** 2026-04-16

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

**Confidence:** HIGH (verified via CRAN, current as of April 2026)

**Installation:**
```r
install.packages("tidyverse")
library(tidyverse)  # Loads all 9 core packages
```

**Rationale:** Tidyverse is the industry standard for R data pipelines in clinical research as of 2026. It provides a cohesive, pipe-friendly syntax that facilitates readable, maintainable code. For SAS users, the declarative style (apply formula to entire dataset) differs from SAS's sequential row-by-row processing, but produces more concise code for the same operations.

---

### SAS Data Import and Format Translation

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **haven** | 2.5.5 | Read SAS7BDAT files, import SAS formats | Official tidyverse package for SAS file import. `read_sas()` handles both .sas7bdat data files and .sas7bcat format catalogs. Preserves variable labels and converts SAS value formats to `labelled()` class. |

**Confidence:** HIGH (verified via CRAN, official tidyverse package)

**Installation:**
```r
install.packages("haven")
```

**Key Functions:**
- `read_sas("file.sas7bdat", catalog_file = "formats.sas7bcat")` — Read SAS data with formats
- `as_factor(data, levels = "labels")` — Convert labelled vectors to R factors
- `print_labels(variable)` — Inspect SAS format mappings

**Rationale:** haven is the authoritative tool for SAS-to-R data migration. It handles SAS's proprietary binary format and automatically imports user-defined formats (PROC FORMAT) as labelled metadata. The `as_factor()` function provides flexible conversion to R factors, which is essential for translating the Formats.sas file into R factor levels.

**Encoding Note:** If SAS files contain non-ASCII characters (patient names, free text), specify encoding: `read_sas("file.sas7bdat", encoding = "UTF-8")` or `encoding = "latin1"` depending on SAS file creation environment.

**Export Warning:** Do NOT use `write_sas()` to export R data back to SAS format. The function creates files that SAS often cannot read due to proprietary format restrictions. Use `write_xpt()` for SAS transport files if round-trip conversion is needed.

---

### Data Cleaning and Quality

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **janitor** | 2.2.1 | Column name standardization, duplicate detection, frequency tables | Clinical datasets (especially from EHR/CDM) have inconsistent naming conventions. `clean_names()` converts to snake_case. `get_dupes()` finds duplicate patient records. `tabyl()` creates crosstabs with totals/percentages. |

**Confidence:** HIGH (verified via CRAN)

**Installation:**
```r
install.packages("janitor")
```

**Key Functions:**
- `clean_names()` — Standardize column names (spaces → underscores, camelCase → snake_case)
- `get_dupes(patient_id, encounter_date)` — Identify duplicate records
- `tabyl(var1, var2)` — Frequency table with totals
- `remove_empty("rows")` or `remove_empty("cols")` — Drop empty rows/columns

**Rationale:** Essential for messy real-world clinical data. PCORnet CDM datasets are relatively clean, but encounter merging, insurance recoding, and data quality checks benefit from janitor's tidyverse-compatible functions. Particularly useful for exploring data quality issues before fixing them.

---

### Statistical Analysis: Descriptive Statistics and Table 1

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **gtsummary** | 2.5.0 | Table 1 creation, descriptive statistics, statistical test tables | Industry-leading package for clinical Table 1 as of 2025-2026. Automatically detects variable types (continuous, categorical, binary), calculates appropriate summary statistics (median/IQR, n/%), performs statistical tests (chi-square, Wilcoxon), and produces publication-ready tables. Replaces older `tableone` package. |
| **rstatix** | 0.7.3 | Pipe-friendly statistical tests (chi-square, Wilcoxon, t-test) | Tidyverse-compatible wrapper for base R statistical tests. Returns tidy data frames instead of messy test objects. Use for custom statistical testing workflows not covered by gtsummary. |

**Confidence:** HIGH (verified via CRAN, gtsummary is current best practice)

**Installation:**
```r
install.packages("gtsummary")
install.packages("rstatix")
```

**Key gtsummary Functions:**
- `tbl_summary(data, by = exposure_group)` — Create Table 1 stratified by groups
- `add_p()` — Add p-values from chi-square (categorical) or Wilcoxon (continuous) tests
- `add_overall()` — Add overall column
- `modify_header()`, `modify_spanning_header()` — Customize headers

**Key rstatix Functions:**
- `chisq_test(var ~ group)` — Chi-square test, tidy output
- `wilcox_test(value ~ group)` — Wilcoxon rank sum test
- `t_test(value ~ group)` — T-test
- `get_summary_stats(group_by = ...)` — Descriptive stats by group

**Rationale:** gtsummary has become the standard for clinical Table 1 creation since 2020, replacing tableone. It integrates seamlessly with tidyverse workflows and produces journal-ready output with minimal code. rstatix complements gtsummary for custom statistical workflows (e.g., stratified analyses, sensitivity analyses) where manual test execution is needed.

**Alternative NOT Recommended:** `tableone` package is older (pre-2020 standard) and less tidyverse-compatible. Use gtsummary instead.

---

### Statistical Analysis: Regression Models

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **MASS** | 7.3-65 | Negative binomial regression (`glm.nb()`) | Standard package for negative binomial GLM. Included with base R installation. Use for overdispersed count outcomes (visit rates) where variance exceeds mean. |
| **stats** (base R) | Built-in | Poisson regression (`glm(family = poisson)`) | Base R GLM framework. Use for count outcomes with person-time offset. Test Poisson first, then switch to negative binomial if overdispersion detected. |
| **broom** | 1.0.12 | Tidy regression output (coefficients, confidence intervals, model fit) | Converts messy regression objects (lm, glm, glm.nb) into tidy tibbles. Essential for extracting coefficients, standard errors, p-values, and confidence intervals into data frames for reporting or visualization. |

**Confidence:** HIGH (verified via CRAN and base R documentation)

**Installation:**
```r
# MASS is pre-installed with R
library(MASS)

# broom
install.packages("broom")
```

**Key Workflow:**
```r
# Poisson regression with person-time offset
poisson_model <- glm(visits ~ pct_change_ins + age_group + sex + race,
                     family = poisson(link = "log"),
                     offset = log(person_years),
                     data = cohort_data)

# Check for overdispersion (variance > mean)
# If overdispersed, use negative binomial:
library(MASS)
nb_model <- glm.nb(visits ~ pct_change_ins + age_group + sex + race + offset(log(person_years)),
                   data = cohort_data)

# Tidy output
library(broom)
tidy(nb_model, conf.int = TRUE, exponentiate = TRUE)  # Rate ratios with 95% CI
glance(nb_model)  # AIC, BIC, log-likelihood
```

**Rationale:** Poisson and negative binomial regression are standard for modeling count outcomes (cancer-related visits, survivorship care visits) with person-time exposure. MASS::glm.nb() is the authoritative implementation of negative binomial GLM. broom converts regression results to tidy format, eliminating manual extraction from summary() objects and enabling easy integration with dplyr/ggplot2 workflows.

**Note on Person-Time Offset:** Use `offset(log(person_years))` to model rates (visits per person-year) rather than raw counts. The log transformation is required because Poisson/negative binomial use log link function.

---

### Visualization

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **ggplot2** | 4.0.2 | Publication-quality graphics (bar charts, boxplots, scatter plots, forest plots) | De facto standard for R data visualization. Grammar of Graphics framework provides systematic approach to building complex plots. Used in clinical research for TFLs (Tables, Figures, Listings), forest plots for regression results, Kaplan-Meier curves, and data exploration. |

**Confidence:** HIGH (verified via CRAN)

**Installation:**
```r
# Included in tidyverse
library(tidyverse)
```

**Common Clinical Use Cases:**
- **Distributions:** `geom_histogram()`, `geom_density()`, `geom_boxplot()`
- **Categorical comparisons:** `geom_bar()`, `geom_col()`
- **Forest plots:** `geom_point()` + `geom_errorbarh()` for regression coefficients with confidence intervals
- **Survival curves:** `geom_step()` with survival package output
- **Faceting:** `facet_wrap(~ cancer_site)` for stratified plots

**Rationale:** ggplot2 is the industry standard for clinical research visualization. It produces publication-ready graphics with fine control over aesthetics, theming, and layout. The layered approach (data + aesthetics + geoms + facets + themes) is more systematic than base R plotting.

---

### Project Management and Reproducibility

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **renv** | 1.2.2 | Project-local package management, version locking | Freezes package versions for reproducibility. Creates project-specific library and renv.lock file documenting exact package versions. Essential for long-term clinical research projects where package updates may break code. |
| **here** | 1.0.2 | Project-relative file paths | Eliminates hardcoded paths and `setwd()` calls. `here("data", "raw", "encounters.sas7bdat")` always resolves relative to project root, regardless of where script is executed. Critical for modular scripts (01_clean.R, 02_merge.R, etc.) that run from master script. |

**Confidence:** HIGH (verified via CRAN)

**Installation:**
```r
install.packages("renv")
install.packages("here")
```

**renv Workflow:**
```r
# Initialize renv in project
renv::init()

# Install packages (tracked automatically)
install.packages("tidyverse")
install.packages("haven")

# Snapshot current package versions
renv::snapshot()

# Restore environment on different machine
renv::restore()
```

**here Workflow:**
```r
library(here)

# Declare project root (run once in main script)
here::i_am(".planning/PROJECT.md")

# Build paths relative to project root
encounters <- read_sas(here("data", "raw", "encounters.sas7bdat"))
write_csv(clean_data, here("data", "processed", "cohort_clean.csv"))
```

**Rationale:** renv ensures reproducibility by locking package versions. Without it, updating packages (e.g., dplyr 1.2.1 → 1.3.0) could break code months later. here eliminates fragile hardcoded paths (e.g., `"C:/Users/Owner/Documents/..."`) and makes code portable across machines and operating systems. Both are best practices for clinical research pipelines.

---

### Supporting Tools (Optional but Recommended)

| Technology | Version | Purpose | When to Use |
|------------|---------|---------|-------------|
| **survival** | 3.8-6 | Survival analysis (Kaplan-Meier, Cox regression) | If analyzing time-to-event outcomes (time to insurance loss, time to survivorship care visit). Not required for baseline cross-sectional analysis but useful for longitudinal follow-up. |
| **targets** | Latest | Pipeline workflow automation, dependency tracking | Advanced: Automates pipeline execution, skips up-to-date steps, parallelizes independent tasks. Consider for complex multi-stage pipelines. May be overkill for this project's 10-15 modular scripts. |

**Confidence:** MEDIUM (survival is HIGH confidence for survival analysis; targets is optional/advanced)

**Rationale:**
- **survival:** Standard package for time-to-event analysis in cancer research. Includes Kaplan-Meier curves, log-rank tests, Cox proportional hazards models. Only needed if project expands to survival outcomes.
- **targets:** Make-like pipeline tool. Tracks dependencies between scripts, only reruns changed steps. Useful for large pipelines with expensive computation, but adds complexity. Start with simple master runner script; migrate to targets if pipeline becomes unwieldy.

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| **Table 1** | gtsummary | tableone | tableone was pre-2020 standard. gtsummary offers better tidyverse integration, cleaner syntax, and is actively maintained. |
| **SAS Import** | haven | foreign, sas7bdat | foreign is deprecated (last update 2022). sas7bdat package has limited format support. haven is official tidyverse solution with active maintenance. |
| **Data Manipulation** | dplyr + tidyr | data.table, base R | data.table is faster for very large datasets (millions of rows) but has different syntax. Base R (transform, subset, merge) is verbose and less readable. Tidyverse is clinical research standard. |
| **String Processing** | stringr | base R (grep, gsub, substr) | Base R string functions have inconsistent argument order and return types. stringr provides consistent str_* function family. |
| **Pipeline Automation** | Manual scripts | targets, drake | drake is superseded by targets. targets adds complexity; delay adoption until pipeline stability is proven. |
| **Statistical Tests** | gtsummary + rstatix | base R (chisq.test, wilcox.test) | Base R test functions return complex objects requiring manual extraction. rstatix/gtsummary return tidy data frames compatible with dplyr/ggplot2. |

---

## NOT Recommended: Pharmaverse Packages

**Packages:** admiral, sdtm.oak, xportr, rtables

**Why Avoid:** These packages target CDISC SDTM/ADaM standards for regulatory submissions to FDA/EMA. This project uses PCORnet Common Data Model, not CDISC. Pharmaverse tools are designed for pharmaceutical clinical trials (CRF data, SDTM mapping), not observational research with EHR-derived CDM data. Using pharmaverse would introduce unnecessary complexity and mismatched assumptions.

**When to Use:** Only if future work involves regulatory submissions or collaboration with pharma partners requiring CDISC compliance.

**Confidence:** HIGH (pharmaverse is domain-specific to pharma clinical trials)

---

## Installation Script

```r
# Install tidyverse (includes dplyr, tidyr, ggplot2, readr, purrr, tibble, stringr, forcats, lubridate)
install.packages("tidyverse")

# SAS import and format translation
install.packages("haven")

# Data cleaning
install.packages("janitor")

# Table 1 and descriptive statistics
install.packages("gtsummary")

# Statistical tests (pipe-friendly)
install.packages("rstatix")

# Regression model tidying
install.packages("broom")

# MASS for negative binomial (pre-installed with R, but load explicitly)
library(MASS)

# Project management
install.packages("renv")
install.packages("here")

# Optional: survival analysis
install.packages("survival")

# Initialize renv for version control
renv::init()
renv::snapshot()
```

---

## Version Notes

**R Version Requirement:** R 4.1.0 or higher (required by most tidyverse packages)

**Package Update Frequency:**
- **Core tidyverse packages** (dplyr, tidyr, ggplot2, readr): Updated 2-4 times per year. Breaking changes are rare and well-documented.
- **haven, gtsummary, broom:** Updated 1-2 times per year.
- **renv:** Use renv.lock to freeze versions. Do not update packages mid-project unless critical bug fixes are needed.

**Checking Package Versions:**
```r
packageVersion("dplyr")
packageVersion("gtsummary")
sessionInfo()  # List all loaded packages with versions
```

---

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

---

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

**Overall Confidence:** HIGH

All recommendations are based on official CRAN documentation, current best practices in clinical research R programming, and verified package versions as of April 2026.
