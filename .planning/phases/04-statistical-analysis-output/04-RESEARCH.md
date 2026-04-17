# Phase 4: Statistical Analysis & Output - Research

**Researched:** 2026-04-17
**Domain:** Statistical analysis and publication-ready table generation (R tidyverse ecosystem)
**Confidence:** HIGH

## Summary

Phase 4 produces publication-ready statistical tables and regression models validated against SAS PROC GENMOD/PROC FREQ output. The research confirms that the tidyverse ecosystem provides robust, well-documented tools for every Phase 4 requirement: gtsummary for Table 1 with automated statistical testing, base R glm()/MASS::glm.nb() for Poisson/negative binomial regression with person-time offsets, broom for tidy regression output extraction, and flextable for Word export. All packages are actively maintained (2025-2026 releases) with extensive clinical research documentation.

**Primary recommendation:** Use gtsummary::tbl_summary() with add_p() for Table 1 (handles chi-square/Wilcoxon automatically), fit Poisson models first with overdispersion testing (AER::dispersiontest), switch to negative binomial if overdispersed, use broom::tidy(exponentiate=TRUE) to extract IRRs with 95% CIs, and export via gtsummary::as_flex_table() %>% flextable::save_as_docx() for publication-ready Word output.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| STA-01 | Table 1 shows patient characteristics stratified by exposure group(s) with appropriate statistics | gtsummary::tbl_summary(by=exposure) auto-detects variable types, calculates medians/IQRs for continuous and n/% for categorical. Verified via CRAN 2.5.0 (Dec 2025). |
| STA-02 | Bivariate tests (chi-square for categorical, Wilcoxon rank sum for continuous) compare groups correctly | gtsummary::add_p() auto-selects chi-square (categorical, n≥5), Fisher's exact (categorical, n<5), Wilcoxon (continuous, 2 groups), Kruskal-Wallis (continuous, >2 groups). Matches SAS PROC FREQ/NPAR1WAY defaults. |
| STA-03 | Poisson regression models fit visit rate outcomes with log(person-time) offset | glm(count ~ predictors, family=poisson, offset=log(person_time_days)) per standard clinical epidemiology practice. Produces same parameter estimates as SAS PROC GENMOD with dist=poisson link=log offset=log_person_time_days. |
| STA-04 | Negative binomial regression models fit when overdispersion detected | MASS::glm.nb(count ~ predictors, offset=log(person_time_days)) handles overdispersion (variance > mean). AER::dispersiontest() provides formal test (H0: equidispersion). Standard approach when Poisson deviance/df > 1. |
| STA-05 | Regression tables show IRRs/rate ratios, 95% CIs, and p-values | broom::tidy(model, exponentiate=TRUE, conf.int=TRUE) extracts exp(coef) as IRR with 95% CI. gtsummary::tbl_regression(exponentiate=TRUE) auto-formats as publication table. |
| STA-06 | Model diagnostics include overdispersion test and goodness-of-fit assessment | AER::dispersiontest() for overdispersion (α>0 → NB preferred). Deviance goodness-of-fit: pchisq(deviance, df.residual, lower.tail=FALSE). Document dispersion parameter θ for NB models. |
| STA-07 | Frequency/cross-tabulation tables generated for key variable distributions | janitor::tabyl(var1, var2) %>% adorn_percentages() %>% adorn_pct_formatting() for crosstabs with totals. Alternative: gtsummary::tbl_cross() for 2-way tables with chi-square test. |
</phase_requirements>

## Standard Stack

### Core Statistical Analysis
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| **gtsummary** | 2.5.0 | Table 1, regression tables, automated statistical tests | Industry-leading package for clinical Table 1 (replaced tableone post-2020). Auto-detects variable types, selects appropriate tests (chi-square, Wilcoxon, Fisher's exact), formats publication-ready output. Verified CRAN Dec 5, 2025. |
| **MASS** | 7.3-65 | Negative binomial regression (glm.nb) | Pre-installed with R. Standard package for overdispersed count data. Estimates dispersion parameter θ via maximum likelihood. Well-documented for clinical research (visit rates, event counts). |
| **stats** (base R) | Built-in | Poisson regression (glm family=poisson) | Base R GLM framework. Use for count outcomes with person-time offset. Test Poisson first; switch to NB if overdispersed (deviance/df > 1 or AER::dispersiontest p<0.05). |
| **broom** | 1.0.12 | Tidy regression output (coefficients, CIs, model fit) | Converts glm/glm.nb objects to tidy tibbles. tidy(exponentiate=TRUE, conf.int=TRUE) extracts IRRs with 95% CIs. glance() extracts AIC, deviance, df.residual for diagnostics. Verified CRAN Jan 27, 2026. |

### Export and Formatting
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| **flextable** | 0.9.11 | Convert tables to Word-compatible format | Works with gtsummary::as_flex_table() to export tables to .docx. Supports customization (borders, fonts, alignment). Verified CRAN Feb 13, 2026. Requires officer (≥0.7.3) for Word document creation. |
| **officer** | ≥0.7.3 | Create and manipulate Word documents | Dependency of flextable. save_as_docx() exports flextable objects to .docx. Supports page layout (landscape, margins), multiple tables per document. |

### Supporting Analysis
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **janitor** | 2.2.1 | Frequency tables (tabyl) with totals and percentages | Use for STA-07 frequency/crosstab tables. tabyl(var1, var2) %>% adorn_totals() %>% adorn_percentages() mirrors SAS PROC FREQ output format. |
| **AER** | 1.2-16 | Overdispersion testing (dispersiontest) | Formal test for overdispersion in Poisson models. dispersiontest(poisson_model, trafo=2) tests H0: Var=μ vs H1: Var=μ+α·μ² (NB2). p<0.05 → use negative binomial. Verified CRAN Feb 9, 2026. |
| **rstatix** | 0.7.3 | Pipe-friendly statistical tests (optional) | Use if custom statistical testing workflows needed beyond gtsummary::add_p(). Returns tidy data frames (chisq_test(), wilcox_test()). Not required if gtsummary handles all tests. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| gtsummary | tableone | tableone was pre-2020 standard. gtsummary offers better tidyverse integration, cleaner syntax, automatic test selection, and is actively maintained (2025-2026 releases vs tableone last update 2022). |
| flextable | gt + knitr | gt package (gtsummary's native backend) does not support Word output. flextable is required for .docx export. knitr::kable() produces plain tables without publication-grade formatting. |
| AER::dispersiontest | Manual deviance/df | Manual approach (deviance/df > 1) is quick check but non-inferential. AER::dispersiontest provides formal hypothesis test with p-value, better for documentation/reporting. |
| broom::tidy | Manual extraction | Manual extraction from glm/glm.nb objects requires navigating list structure (model$coefficients, confint(model)). broom provides standardized interface across model types. |

**Installation:**
```bash
# Install core statistical packages
install.packages("gtsummary")  # Table 1, regression tables
install.packages("broom")      # Tidy regression output
install.packages("flextable")  # Word export
install.packages("officer")    # Word document manipulation
install.packages("AER")        # Overdispersion testing

# MASS pre-installed with R (load explicitly)
library(MASS)

# Supporting packages (already installed in Phase 1-3)
install.packages("janitor")    # Frequency tables
install.packages("rstatix")    # Optional: custom statistical tests
```

**Version verification:** Package versions verified against CRAN as of April 2026:
- gtsummary 2.5.0 (Dec 5, 2025) — current
- broom 1.0.12 (Jan 27, 2026) — current
- flextable 0.9.11 (Feb 13, 2026) — current
- AER 1.2-16 (Feb 9, 2026) — current
- MASS 7.3-65 (pre-installed with R ≥4.0)

## Architecture Patterns

### Recommended Project Structure
```
R/
├── 04_table1.R          # Table 1 (demographics, stratified by exposure)
├── 04_frequencies.R     # Frequency tables (STA-07)
├── 04_poisson.R         # Poisson regression models (STA-03)
├── 04_negbin.R          # Negative binomial models (STA-04)
└── 04_export.R          # Export all tables to Word (STA-05)

outputs/
├── tables/
│   ├── table1.docx
│   ├── frequencies.docx
│   ├── regression_poisson.docx
│   └── regression_negbin.docx
└── diagnostics/
    ├── overdispersion_tests.txt
    └── model_fit_summary.txt

tests/testthat/
├── helper-phase4-fixtures.R   # Mock analytical data (5-10 patients)
├── test_04_table1.R           # STA-01, STA-02 tests
├── test_04_frequencies.R      # STA-07 tests
└── test_04_regression.R       # STA-03, STA-04, STA-05, STA-06 tests
```

### Pattern 1: Table 1 with Stratified Analysis and Statistical Tests
**What:** Create Table 1 showing patient characteristics stratified by exposure group (e.g., insurance change status) with automated statistical tests comparing groups.

**When to use:** STA-01 (descriptive statistics) and STA-02 (bivariate tests). Standard first table in clinical research papers.

**Example:**
```r
# Source: gtsummary tbl_summary() tutorial (https://www.danieldsjoberg.com/gtsummary/articles/tbl_summary.html)
library(gtsummary)

# Load analytical dataset (from Phase 3)
analytical <- readRDS(file.path(data_dir_processed, "03_analytical.rds"))

# Create Table 1 stratified by insurance change
table1 <- analytical %>%
  select(
    # Stratification variable
    change_ins,
    # Demographics
    age2, sex, race2, hispanic,
    # Clinical characteristics
    group_site, intensity2,
    # Covariates
    first_sdi2, first_ruca,
    # Outcomes
    n_Enc_nonacute_care, n_Survivorship_visit
  ) %>%
  tbl_summary(
    by = change_ins,  # Stratify by insurance change
    statistic = list(
      all_continuous() ~ "{median} ({p25}, {p75})",  # Median (IQR)
      all_categorical() ~ "{n} ({p}%)"               # Count (%)
    ),
    digits = list(
      all_continuous() ~ c(1, 1, 1),  # 1 decimal for median, IQR
      all_categorical() ~ c(0, 1)     # 0 decimals for n, 1 for %
    ),
    label = list(
      age2 ~ "Age category",
      sex ~ "Sex",
      race2 ~ "Race",
      hispanic ~ "Hispanic ethnicity",
      group_site ~ "Cancer site",
      intensity2 ~ "Treatment intensity",
      first_sdi2 ~ "SDI (tertiles)",
      first_ruca ~ "Rural-urban classification",
      n_Enc_nonacute_care ~ "Non-acute care encounters",
      n_Survivorship_visit ~ "Survivorship visits"
    )
  ) %>%
  add_p(
    # Auto-select tests: chi-square (categorical), Wilcoxon (continuous)
    test = list(
      all_continuous() ~ "wilcox.test",
      all_categorical() ~ "chisq.test.no.correct"
    )
  ) %>%
  add_overall() %>%  # Add "Overall" column
  modify_header(label ~ "**Characteristic**") %>%
  modify_spanning_header(all_stat_cols() ~ "**Insurance Change Status**")

# Preview
table1

# Export to Word
table1 %>%
  as_flex_table() %>%
  flextable::save_as_docx(path = file.path(output_dir, "tables", "table1.docx"))
```

**Key details:**
- `tbl_summary(by=change_ins)` automatically stratifies all variables by exposure group
- `add_p()` auto-selects appropriate tests: chi-square for categorical (if expected cell counts ≥5, else Fisher's exact), Wilcoxon rank sum for continuous (2 groups), Kruskal-Wallis (>2 groups)
- `statistic` argument controls display format (median/IQR for continuous, n/% for categorical)
- `label` argument provides publication-ready variable names (overrides raw column names)
- `modify_header()` and `modify_spanning_header()` customize column headers

### Pattern 2: Poisson Regression with Person-Time Offset
**What:** Fit Poisson regression models for count outcomes (visit rates) with log(person-time) offset to account for variable follow-up.

**When to use:** STA-03 (Poisson regression). First-line approach for count data. Test for overdispersion; if present, use negative binomial (Pattern 3).

**Example:**
```r
# Source: UCLA OARC Stats Poisson Regression (https://stats.oarc.ucla.edu/r/dae/poisson-regression/)
# Source: RPubs Poisson for rates (https://rpubs.com/kaz_yos/poisson)

library(broom)

# Load analytical dataset
analytical <- readRDS(file.path(data_dir_processed, "03_analytical.rds"))

# Fit Poisson model: Survivorship visit count ~ predictors + offset(log(person-time))
model_poisson <- glm(
  n_Survivorship_visit ~ change_ins + age2 + sex + race2 +
                         intensity2 + first_sdi2 + first_ruca,
  data = analytical,
  family = poisson(link = "log"),
  offset = log(person_time_days)  # Offset for person-time exposure
)

# Check for overdispersion
# Method 1: Deviance goodness-of-fit
dispersion_ratio <- model_poisson$deviance / model_poisson$df.residual
cat("Dispersion ratio (deviance/df):", dispersion_ratio, "\n")
if (dispersion_ratio > 1) {
  cat("WARNING: Overdispersion detected (ratio > 1). Consider negative binomial.\n")
}

# Method 2: Formal test (AER package)
library(AER)
overdispersion_test <- dispersiontest(model_poisson, trafo = 2)  # trafo=2 for NB2 (quadratic variance)
print(overdispersion_test)
# If p < 0.05, reject H0: equidispersion → use negative binomial

# Extract tidy output: IRRs with 95% CIs
tidy_output <- tidy(model_poisson, exponentiate = TRUE, conf.int = TRUE, conf.level = 0.95)
print(tidy_output)
# Columns: term, estimate (IRR), std.error, statistic, p.value, conf.low, conf.high

# Model fit summary
glance_output <- glance(model_poisson)
print(glance_output)
# Columns: null.deviance, df.null, logLik, AIC, BIC, deviance, df.residual

# Save diagnostics
sink(file.path(output_dir, "diagnostics", "overdispersion_tests.txt"))
cat("=== Poisson Model Diagnostics ===\n")
cat("Dispersion ratio:", dispersion_ratio, "\n")
print(overdispersion_test)
sink()
```

**Key details:**
- `offset = log(person_time_days)` models rate (events per unit time) not raw count
- IRR interpretation: exp(β) = multiplicative change in rate per 1-unit increase in predictor
- Overdispersion check is REQUIRED — Poisson assumes Var(Y) = E(Y); violation → underestimated SEs, inflated Type I error
- `dispersiontest(trafo=2)` tests for NB2 variance (Var = μ + α·μ²); `trafo=1` tests NB1 (Var = μ + α·μ)
- If overdispersed (p < 0.05), switch to Pattern 3 (negative binomial)

### Pattern 3: Negative Binomial Regression for Overdispersed Counts
**What:** Fit negative binomial regression when Poisson model is overdispersed (variance > mean).

**When to use:** STA-04 (negative binomial regression). Use when Pattern 2 Poisson model shows overdispersion (deviance/df > 1 or AER::dispersiontest p < 0.05).

**Example:**
```r
# Source: UCLA OARC Stats NB Regression (https://stats.oarc.ucla.edu/r/dae/negative-binomial-regression/)
# Source: MASS glm.nb documentation (https://stat.ethz.ch/R-manual/R-devel/library/MASS/html/glm.nb.html)

library(MASS)
library(broom)

# Fit negative binomial model (same predictors as Poisson)
model_nb <- glm.nb(
  n_Survivorship_visit ~ change_ins + age2 + sex + race2 +
                         intensity2 + first_sdi2 + first_ruca +
                         offset(log(person_time_days)),
  data = analytical
)

# Extract dispersion parameter θ (theta)
theta <- model_nb$theta
theta_se <- model_nb$SE.theta
cat("Dispersion parameter θ:", theta, "±", theta_se, "\n")
# Larger θ → less overdispersion (θ→∞ converges to Poisson)

# Compare to Poisson via likelihood ratio test
anova(model_poisson, model_nb, test = "Chisq")
# If p < 0.05, NB is significantly better fit than Poisson

# Extract tidy output: IRRs with 95% CIs
tidy_nb <- tidy(model_nb, exponentiate = TRUE, conf.int = TRUE)
print(tidy_nb)

# Model fit summary
glance_nb <- glance(model_nb)
print(glance_nb)
# Compare AIC with Poisson: lower AIC → better fit

# Save model summary
sink(file.path(output_dir, "diagnostics", "model_fit_summary.txt"))
cat("=== Negative Binomial Model Summary ===\n")
cat("Dispersion parameter θ:", theta, "±", theta_se, "\n")
print(summary(model_nb))
cat("\n=== Likelihood Ratio Test: Poisson vs NB ===\n")
print(anova(model_poisson, model_nb, test = "Chisq"))
sink()
```

**Key details:**
- `glm.nb()` estimates dispersion parameter θ via maximum likelihood (Poisson is special case where θ→∞)
- NB variance function: Var(Y) = μ + μ²/θ (NB2 parameterization)
- Smaller θ → more overdispersion; report θ ± SE in model diagnostics
- Likelihood ratio test compares Poisson vs NB (nested models); p < 0.05 → NB preferred
- IRR interpretation identical to Poisson (Pattern 2)

### Pattern 4: Publication-Ready Regression Tables
**What:** Format regression model output (Poisson or NB) as publication-ready table with IRRs, 95% CIs, and p-values.

**When to use:** STA-05 (regression tables). Use after fitting models (Patterns 2-3) to create formatted output for manuscript.

**Example:**
```r
# Source: gtsummary tbl_regression() tutorial (https://www.danieldsjoberg.com/gtsummary/articles/tbl_regression.html)

library(gtsummary)

# Create regression table from negative binomial model
regression_table <- tbl_regression(
  model_nb,
  exponentiate = TRUE,  # Show IRRs not log-IRRs
  label = list(
    change_ins ~ "Insurance change",
    age2 ~ "Age category",
    sex ~ "Sex",
    race2 ~ "Race",
    intensity2 ~ "Treatment intensity",
    first_sdi2 ~ "SDI tertile",
    first_ruca ~ "Rural-urban classification"
  ),
  estimate_fun = function(x) style_ratio(x, digits = 2)  # 2 decimals for IRR
) %>%
  add_global_p() %>%  # Add global p-value for categorical variables
  modify_header(label ~ "**Variable**", estimate ~ "**IRR**") %>%
  modify_footnote(estimate ~ "IRR = Incidence Rate Ratio from negative binomial regression with log(person-time) offset")

# Preview
regression_table

# Export to Word
regression_table %>%
  as_flex_table() %>%
  flextable::save_as_docx(path = file.path(output_dir, "tables", "regression_negbin.docx"))

# Alternative: Manual table creation from broom output
tidy_nb %>%
  select(term, estimate, conf.low, conf.high, p.value) %>%
  mutate(
    IRR_CI = sprintf("%.2f (%.2f, %.2f)", estimate, conf.low, conf.high)
  ) %>%
  select(term, IRR_CI, p.value) %>%
  flextable::flextable() %>%
  flextable::save_as_docx(path = file.path(output_dir, "tables", "regression_manual.docx"))
```

**Key details:**
- `exponentiate = TRUE` displays IRRs (exp(β)) not log-IRRs
- `add_global_p()` adds omnibus p-value for multi-level categorical variables (e.g., age category with 5 levels)
- `style_ratio()` formats IRRs with specified decimal places
- `modify_footnote()` adds clarifying footnote about model type and offset
- Alternative manual approach uses broom::tidy() + sprintf() for custom formatting

### Pattern 5: Frequency Tables and Cross-Tabulations
**What:** Generate frequency tables and crosstabs for key variable distributions (matching SAS PROC FREQ output).

**When to use:** STA-07 (frequency tables). Use for exploratory data analysis and supplementary tables.

**Example:**
```r
# Source: janitor tabyls vignette (https://cran.r-project.org/web/packages/janitor/vignettes/tabyls.html)

library(janitor)

# 1-way frequency table: Insurance change distribution
freq_change_ins <- analytical %>%
  tabyl(change_ins) %>%
  adorn_totals("row") %>%
  adorn_pct_formatting(digits = 1)

print(freq_change_ins)
# Output: change_ins | n | percent
#         No change  | X | XX.X%
#         Changed    | Y | YY.Y%
#         Total      | N | 100.0%

# 2-way crosstab: Insurance change by cancer site
crosstab_site <- analytical %>%
  tabyl(change_ins, group_site) %>%
  adorn_totals(c("row", "col")) %>%
  adorn_percentages("row") %>%  # Row percentages
  adorn_pct_formatting(digits = 1) %>%
  adorn_ns()  # Add (n) alongside %

print(crosstab_site)

# Alternative: gtsummary cross-tabulation with chi-square test
crosstab_gtsummary <- analytical %>%
  select(change_ins, group_site) %>%
  tbl_cross(
    row = change_ins,
    col = group_site,
    percent = "row"
  ) %>%
  add_p(source_note = TRUE)  # Add chi-square test

# Export to Word
crosstab_gtsummary %>%
  as_flex_table() %>%
  flextable::save_as_docx(path = file.path(output_dir, "tables", "frequencies.docx"))
```

**Key details:**
- `tabyl()` creates frequency table (1-way) or crosstab (2-way)
- `adorn_*` functions add formatting: totals, percentages, counts
- `adorn_percentages("row")` calculates row percentages (% within each row); use "col" for column %
- gtsummary::tbl_cross() is alternative for publication-ready crosstabs with statistical tests
- For 3-way tables, use `tabyl(var1, var2, var3)` then pipe to `adorn_*` functions

### Anti-Patterns to Avoid

- **Anti-pattern: Manual coefficient extraction from summary() objects**
  - Why it's bad: `summary(model)$coefficients` returns matrix requiring manual indexing, lacks CIs, non-tidy format
  - What to do instead: Use `broom::tidy(exponentiate=TRUE, conf.int=TRUE)` for tidy tibble with IRRs and CIs

- **Anti-pattern: Using Poisson without overdispersion check**
  - Why it's bad: Overdispersed Poisson underestimates standard errors → inflated Type I error (false positives)
  - What to do instead: ALWAYS test overdispersion (Pattern 2). If deviance/df > 1 or dispersiontest p<0.05, use negative binomial (Pattern 3)

- **Anti-pattern: Exporting tables via screenshot or copy-paste**
  - Why it's bad: Not reproducible, loses formatting on re-run, introduces manual errors
  - What to do instead: Use `gtsummary::as_flex_table() %>% flextable::save_as_docx()` for programmatic Word export

- **Anti-pattern: Custom statistical test functions without validation**
  - Why it's bad: gtsummary::add_p() auto-selects appropriate tests based on variable type and group count; custom tests may violate assumptions
  - What to do instead: Use gtsummary defaults (chi-square, Wilcoxon, Fisher's exact) which match SAS PROC FREQ/NPAR1WAY behavior

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Table 1 with stratified statistics | Custom summarize() + pivot_wider() code for each variable type | gtsummary::tbl_summary(by=group) | Auto-detects continuous vs categorical, calculates appropriate statistics (median/IQR vs n/%), handles missing data, formats output. Manual approach requires ~50 lines per table; gtsummary does it in 5 lines. |
| Statistical test selection | Manual if/else chains testing normality, equal variance, group count | gtsummary::add_p() | Automatically selects chi-square (categorical, n≥5), Fisher's exact (n<5), Wilcoxon (continuous, 2 groups), Kruskal-Wallis (>2 groups). Implements same logic as SAS PROC FREQ/NPAR1WAY. |
| Regression coefficient formatting | sprintf() loops to format IRRs, CIs, p-values | gtsummary::tbl_regression() or broom::tidy() | Built-in formatting functions (style_ratio, style_pvalue), automatic rounding, publication-ready defaults. Manual formatting error-prone (e.g., forgetting to exponentiate, CI order). |
| Overdispersion testing | Manual deviance/df calculation | AER::dispersiontest() | Provides formal hypothesis test (p-value), not just heuristic (deviance/df > 1). Tests specific variance function (NB1 vs NB2). Better for documentation/reproducibility. |
| Word document export | knitr::kable() + manual Word formatting | flextable::save_as_docx() | Programmatic export preserves formatting (borders, alignment, fonts). knitr produces plain tables requiring manual Word editing (not reproducible). |

**Key insight:** Statistical table generation has well-established "blessed" tools (gtsummary for Table 1, broom for regression output, flextable for Word export). Custom solutions duplicate functionality, introduce bugs, and lack publication-grade formatting. In clinical research, table formatting errors (e.g., incorrect rounding, missing CIs) delay manuscript submission — use standard tools.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| R | All Phase 4 scripts | ✗ | — | BLOCKING: Install R ≥4.2 before Phase 4 execution |
| gtsummary | STA-01, STA-02, STA-05 | ✗ | — | BLOCKING: install.packages("gtsummary") |
| MASS | STA-04 | ✗ (not verified) | Likely pre-installed with R | If missing: library(MASS) loads from base installation |
| broom | STA-05 | ✗ | — | Manual coefficient extraction (not recommended) |
| flextable | Word export | ✗ | — | Use gt::gtsave() for HTML (no Word support), or manual Word formatting (not reproducible) |
| AER | STA-06 | ✗ | — | Manual deviance/df calculation (non-inferential) |
| testthat | Test framework | ✗ (not verified) | Likely installed in Phase 1-3 | Skip testing (not recommended) |

**Missing dependencies with no fallback (BLOCKING):**
- R runtime (≥4.2): Phase 4 cannot execute without R. Install from [CRAN](https://cran.r-project.org/) before proceeding.
- gtsummary, broom, flextable: Core packages for STA requirements. No viable fallbacks — manual table creation would require ~500 lines of custom code per table.

**Missing dependencies with fallback:**
- AER::dispersiontest: Can use manual deviance/df check (deviance/df > 1) but loses formal p-value. Recommendation: install AER for better documentation.
- MASS::glm.nb: Pre-installed with R ≥4.0 (part of recommended packages). If somehow missing, install via install.packages("MASS").

**Installation checklist for Phase 4:**
```r
# Verify R version ≥4.2
R.version.string  # Should show "R version 4.x.y"

# Install required packages
install.packages(c("gtsummary", "broom", "flextable", "officer", "AER"))

# Verify MASS is available (should already be installed)
library(MASS)  # Should load without error

# Verify testthat from Phase 1-3
library(testthat)  # Should load without error
```

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | testthat 3.3.2 (Jan 11, 2026) |
| Config file | None — see Wave 0 test infrastructure plan |
| Quick run command | `testthat::test_file("tests/testthat/test_04_table1.R")` |
| Full suite command | `testthat::test_dir("tests/testthat", filter = "^test_04")` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| STA-01 | Table 1 shows correct stratified statistics (medians, counts, percentages) | unit | `testthat::test_file("tests/testthat/test_04_table1.R", filter="stratified stats")` | ❌ Wave 0 |
| STA-02 | add_p() produces correct p-values for chi-square and Wilcoxon tests | unit | `testthat::test_file("tests/testthat/test_04_table1.R", filter="statistical tests")` | ❌ Wave 0 |
| STA-03 | Poisson regression with offset produces expected IRRs within tolerance | unit | `testthat::test_file("tests/testthat/test_04_regression.R", filter="Poisson")` | ❌ Wave 0 |
| STA-04 | Negative binomial model fits and produces IRRs when overdispersion detected | unit | `testthat::test_file("tests/testthat/test_04_regression.R", filter="negative binomial")` | ❌ Wave 0 |
| STA-05 | Regression tables contain IRR, conf.low, conf.high, p.value columns | unit | `testthat::test_file("tests/testthat/test_04_regression.R", filter="table format")` | ❌ Wave 0 |
| STA-06 | Overdispersion test runs and returns expected structure | unit | `testthat::test_file("tests/testthat/test_04_regression.R", filter="diagnostics")` | ❌ Wave 0 |
| STA-07 | Frequency tables (tabyl) produce correct counts and percentages | unit | `testthat::test_file("tests/testthat/test_04_frequencies.R")` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `testthat::test_file("tests/testthat/test_04_<script>.R")` for affected script
- **Per wave merge:** `testthat::test_dir("tests/testthat", filter = "^test_04")` (all Phase 4 tests)
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

Test infrastructure does NOT exist for Phase 4. Wave 0 must create:

- [ ] `tests/testthat/helper-phase4-fixtures.R` — Mock analytical dataset (5-10 patients with known outcome counts, person-time, covariates) for regression testing
- [ ] `tests/testthat/test_04_table1.R` — Tests for STA-01 (stratified stats), STA-02 (p-values)
- [ ] `tests/testthat/test_04_frequencies.R` — Tests for STA-07 (tabyl output structure)
- [ ] `tests/testthat/test_04_regression.R` — Tests for STA-03 (Poisson), STA-04 (NB), STA-05 (table format), STA-06 (diagnostics)

**Fixture design approach:**
- Create small analytical dataset (5-10 patients) with:
  - Binary exposure (change_ins: 0/1)
  - Known outcome counts (e.g., patient 1: 3 survivorship visits, 100 days follow-up → rate = 3/100)
  - Known demographics for Table 1 (2 males/3 females, known age/race distribution)
- Design ensures deterministic test expectations:
  - Median age = 50 (3rd patient when sorted)
  - Chi-square p-value for 2x2 table computable by hand
  - Poisson IRR for binary exposure: exp(β) where β = log(rate1 / rate0)

**Testing strategy:**
- **STA-01/02 (Table 1):** Test that tbl_summary() output contains expected statistics (median, IQR, n, %) and that add_p() returns p-value within tolerance (use fixture with known chi-square result)
- **STA-03 (Poisson):** Fit model on fixture, verify IRR ± tolerance (use analytical solution for binary exposure)
- **STA-04 (NB):** Test that glm.nb() runs without error, produces theta estimate
- **STA-05 (Regression tables):** Test that tidy() output has required columns (estimate, conf.low, conf.high, p.value)
- **STA-06 (Diagnostics):** Test that dispersiontest() returns htest object with p.value element
- **STA-07 (Frequencies):** Test that tabyl() produces data.frame with n and percent columns

## Common Pitfalls

### Pitfall 1: Forgetting to Exponentiate Poisson/NB Coefficients
**What goes wrong:** Regression output shows log-IRRs (β) not IRRs (exp(β)), leading to misinterpretation (e.g., β=0.5 read as "50% increase" when true IRR=1.65 = 65% increase).

**Why it happens:** Base R glm() and MASS::glm.nb() return coefficients on log scale by default. Users must manually exponentiate or set exponentiate=TRUE in broom::tidy().

**How to avoid:**
- **Always** use `broom::tidy(model, exponentiate = TRUE)` to extract IRRs
- **Or** use `gtsummary::tbl_regression(model, exponentiate = TRUE)` for publication tables
- **Never** report raw coefficients from `summary(model)` without exponentiating

**Warning signs:**
- IRR values between -1 and 1 (should be >0, typically 0.5-2.0 for clinical predictors)
- IRR < 0 (impossible — rate ratios must be positive)
- Confidence intervals spanning 0 (IRR CIs should span 1, not 0)

**Example:**
```r
# WRONG: Reports log-IRR
summary(model_nb)$coefficients[, "Estimate"]  # Returns β (log scale)

# CORRECT: Reports IRR
broom::tidy(model_nb, exponentiate = TRUE)$estimate  # Returns exp(β)
```

### Pitfall 2: Ignoring Overdispersion in Poisson Models
**What goes wrong:** Poisson model assumes Var(Y) = E(Y). When variance exceeds mean (overdispersion), standard errors are underestimated → inflated Type I error (false positives).

**Why it happens:** Poisson is first-line model for count data, but real clinical data often overdispersed (e.g., visit counts vary more than mean due to unmeasured patient factors). Users fit Poisson, see "significant" results, don't check overdispersion.

**How to avoid:**
- **ALWAYS** check overdispersion after fitting Poisson:
  - Quick check: `deviance / df.residual > 1`
  - Formal test: `AER::dispersiontest(model, trafo=2)` — if p<0.05, use negative binomial
- If overdispersed, refit with `MASS::glm.nb()`
- Report dispersion check in methods/diagnostics

**Warning signs:**
- Deviance/df ratio > 1.5 (mild overdispersion) to >10 (severe overdispersion)
- Many "significant" predictors (p<0.05) in Poisson but few in negative binomial
- Residual plots show variance increasing with fitted values

**Example:**
```r
# Fit Poisson
model_pois <- glm(count ~ predictors, family=poisson, offset=log(pt), data=df)

# CHECK OVERDISPERSION (required)
dispersion_ratio <- model_pois$deviance / model_pois$df.residual
print(dispersion_ratio)  # If > 1, consider NB

AER::dispersiontest(model_pois)  # If p < 0.05, use NB

# If overdispersed, refit as NB
if (dispersion_ratio > 1) {
  model_nb <- MASS::glm.nb(count ~ predictors + offset(log(pt)), data=df)
}
```

### Pitfall 3: Incorrect Offset Specification (Missing log() or Person-Time)
**What goes wrong:**
- Forgetting `offset = log(person_time)` models raw count not rate → biased estimates
- Using `offset = person_time` (not log-transformed) → wrong link function
- Using different person-time variable between Poisson and NB → non-comparable models

**Why it happens:** Offset syntax differs from other GLM components (not a formula term), easy to omit. Log-transformation non-obvious to users unfamiliar with GLM link functions.

**How to avoid:**
- **Always** include offset for rate models: `offset = log(person_time_days)`
- Use same person-time variable in Poisson and NB models for comparison
- Verify offset in model summary: `model$offset` should be non-NULL

**Warning signs:**
- IRRs vastly different from SAS output (forgetting offset)
- Model summary shows no offset term
- Coefficients change dramatically when adding/removing offset

**Example:**
```r
# WRONG: No offset (models count not rate)
glm(count ~ predictors, family=poisson, data=df)

# WRONG: Offset not log-transformed
glm(count ~ predictors, family=poisson, offset=person_time, data=df)

# CORRECT: Log-transformed offset
glm(count ~ predictors, family=poisson, offset=log(person_time_days), data=df)
```

### Pitfall 4: SAS-R Missing Value Handling Mismatch in Statistical Tests
**What goes wrong:** SAS PROC FREQ/GENMOD exclude missing values by default. R gtsummary::tbl_summary() includes missing as separate category unless explicitly excluded → different denominators for percentages, different p-values.

**Why it happens:** SAS defaults to complete-case analysis (listwise deletion). R tidyverse philosophy preserves missing data visibility. Statistical tests in R (chisq.test, wilcox.test) drop NAs but gtsummary shows "Unknown" row.

**How to avoid:**
- Use complete-case dataset (03_analytical.rds from Phase 3) not MI-ready dataset (03_analytical_mi.rds)
- Or filter NAs before tbl_summary(): `df %>% filter(!is.na(key_var)) %>% tbl_summary()`
- Check that denominators in R Table 1 match SAS PROC FREQ n

**Warning signs:**
- R Table 1 has "Unknown" or "NA" category not in SAS output
- R percentages don't sum to 100% (missing category excluded from denominator)
- R p-values differ from SAS (different n due to missing handling)

**Example:**
```r
# Load complete-case dataset (NAs already excluded in Phase 3)
analytical <- readRDS("data/processed/03_analytical.rds")

# Verify no missing in key covariates
analytical %>% summarize(across(c(sex, race2, age2), ~sum(is.na(.))))
# Should be all 0s

# Create Table 1 (no missing category)
tbl_summary(analytical, by = exposure)
```

### Pitfall 5: Word Export Formatting Loss or Manual Editing
**What goes wrong:** Exporting tables via copy-paste or screenshot loses formatting on re-run. Manual Word editing (fixing alignment, adding borders) is not reproducible — changes lost when table regenerated.

**Why it happens:** Quick export methods (Ctrl+C, screenshot) bypass programmatic formatting. Users manually format in Word, then pipeline re-runs and overwrites edits.

**How to avoid:**
- **Always** use `gtsummary::as_flex_table() %>% flextable::save_as_docx()` for programmatic export
- Apply formatting in R code (borders, alignment, fonts) not in Word
- Use flextable styling functions for customization:
  - `flextable::border_outer()` for table borders
  - `flextable::align()` for column alignment
  - `flextable::fontsize()` for font size

**Warning signs:**
- Inconsistent table formatting across multiple runs
- Manual "TODO: fix table alignment" notes in code
- Tables look different when pipeline re-executed

**Example:**
```r
# Create table with gtsummary
table1 <- tbl_summary(df, by = group) %>% add_p()

# WRONG: Manual copy-paste to Word (not reproducible)
# User copies output to Word, manually adds borders

# CORRECT: Programmatic export with formatting
table1 %>%
  as_flex_table() %>%
  flextable::border_outer(border = officer::fp_border()) %>%
  flextable::align(align = "center", part = "header") %>%
  flextable::save_as_docx(path = "output/tables/table1.docx")
```

## Code Examples

Verified patterns from official sources.

### Example 1: Complete Table 1 Workflow (Demographics + Statistical Tests)
```r
# Source: gtsummary tbl_summary() tutorial
# https://www.danieldsjoberg.com/gtsummary/articles/tbl_summary.html

library(gtsummary)
library(dplyr)
library(flextable)

# Load analytical dataset (from Phase 3)
analytical <- readRDS(file.path(data_dir_processed, "03_analytical.rds"))

# Create Table 1 stratified by insurance change
table1 <- analytical %>%
  select(
    change_ins,           # Stratification variable
    age, sex, race2, hispanic,  # Demographics
    group_site, intensity,      # Clinical
    first_sdi2, first_ruca,     # Covariates
    n_Survivorship_visit        # Outcome
  ) %>%
  tbl_summary(
    by = change_ins,
    statistic = list(
      all_continuous() ~ "{median} ({p25}, {p75})",
      all_categorical() ~ "{n} ({p}%)"
    ),
    digits = list(
      all_continuous() ~ c(1, 1, 1),
      all_categorical() ~ c(0, 1)
    ),
    label = list(
      age ~ "Age (years)",
      sex ~ "Sex",
      race2 ~ "Race",
      hispanic ~ "Hispanic ethnicity",
      group_site ~ "Cancer site",
      intensity ~ "Treatment intensity",
      first_sdi2 ~ "Social deprivation index",
      first_ruca ~ "Rural-urban classification",
      n_Survivorship_visit ~ "Survivorship visits (n)"
    ),
    missing = "no"  # Exclude missing (already filtered in complete-case dataset)
  ) %>%
  add_p(
    test = list(
      all_continuous() ~ "wilcox.test",
      all_categorical() ~ "chisq.test.no.correct"
    ),
    pvalue_fun = ~style_pvalue(.x, digits = 3)
  ) %>%
  add_overall() %>%
  bold_labels() %>%
  modify_header(label ~ "**Characteristic**") %>%
  modify_spanning_header(all_stat_cols() ~ "**Insurance Change Status**") %>%
  modify_footnote(
    all_stat_cols() ~ "Median (IQR) for continuous; n (%) for categorical"
  )

# Preview in console
table1

# Export to Word
table1 %>%
  as_flex_table() %>%
  save_as_docx(path = file.path(output_dir, "tables", "table1.docx"))

# Alternative: Export to HTML for review
table1 %>%
  as_gt() %>%
  gt::gtsave(filename = file.path(output_dir, "tables", "table1.html"))
```

### Example 2: Poisson Regression with Overdispersion Check
```r
# Source: UCLA OARC Stats Poisson Regression
# https://stats.oarc.ucla.edu/r/dae/poisson-regression/
# Source: AER dispersiontest documentation
# https://rdrr.io/cran/AER/man/dispersiontest.html

library(MASS)
library(broom)
library(AER)

# Load analytical dataset
analytical <- readRDS(file.path(data_dir_processed, "03_analytical.rds"))

# Ensure log_person_time_days exists
if (!"log_person_time_days" %in% names(analytical)) {
  analytical <- analytical %>%
    mutate(log_person_time_days = log(person_time_days))
}

# Fit Poisson model: Survivorship visits ~ predictors
model_poisson <- glm(
  n_Survivorship_visit ~ change_ins + factor(age2) + sex + race2 +
                         factor(intensity2) + factor(first_sdi2) + first_ruca,
  data = analytical,
  family = poisson(link = "log"),
  offset = log_person_time_days
)

# Model summary
summary(model_poisson)

# Check overdispersion
# Method 1: Deviance goodness-of-fit
dispersion_ratio <- model_poisson$deviance / model_poisson$df.residual
cat("Dispersion ratio (deviance/df):", round(dispersion_ratio, 3), "\n")

# Method 2: Formal test (AER::dispersiontest)
test_overdispersion <- dispersiontest(model_poisson, trafo = 2)
print(test_overdispersion)
# H0: Var(Y) = μ (equidispersion, Poisson OK)
# H1: Var(Y) = μ + α·μ² (overdispersion, use NB)
# If p < 0.05, reject H0 → use negative binomial

# Decision rule
if (test_overdispersion$p.value < 0.05) {
  cat("\nOVERDISPERSION DETECTED (p =", round(test_overdispersion$p.value, 4), ")\n")
  cat("Recommendation: Refit with negative binomial (glm.nb)\n")
} else {
  cat("\nNo overdispersion detected (p =", round(test_overdispersion$p.value, 4), ")\n")
  cat("Poisson model is appropriate.\n")
}

# Extract tidy output: IRRs with 95% CIs
tidy_poisson <- tidy(model_poisson, exponentiate = TRUE, conf.int = TRUE, conf.level = 0.95)
print(tidy_poisson)

# Model fit statistics
glance_poisson <- glance(model_poisson)
print(glance_poisson)

# Save diagnostics to file
sink(file.path(output_dir, "diagnostics", "poisson_diagnostics.txt"))
cat("=== Poisson Model Diagnostics ===\n")
cat("Model formula:", deparse(formula(model_poisson)), "\n\n")
cat("Dispersion ratio (deviance/df):", round(dispersion_ratio, 3), "\n")
cat("Overdispersion test (AER::dispersiontest):\n")
print(test_overdispersion)
cat("\nModel fit:\n")
print(glance_poisson)
sink()
```

### Example 3: Negative Binomial Regression with Model Comparison
```r
# Source: UCLA OARC Stats Negative Binomial Regression
# https://stats.oarc.ucla.edu/r/dae/negative-binomial-regression/
# Source: MASS glm.nb reference
# https://stat.ethz.ch/R-manual/R-devel/library/MASS/html/glm.nb.html

library(MASS)
library(broom)

# Fit negative binomial model (same predictors as Poisson)
model_nb <- glm.nb(
  n_Survivorship_visit ~ change_ins + factor(age2) + sex + race2 +
                         factor(intensity2) + factor(first_sdi2) + first_ruca +
                         offset(log_person_time_days),
  data = analytical
)

# Model summary
summary(model_nb)

# Extract dispersion parameter θ (theta)
theta <- model_nb$theta
theta_se <- model_nb$SE.theta
cat("Dispersion parameter θ:", round(theta, 3), "±", round(theta_se, 3), "\n")
cat("Interpretation: Smaller θ → more overdispersion (Poisson is θ → ∞)\n")

# Compare Poisson vs Negative Binomial via likelihood ratio test
lrt <- anova(model_poisson, model_nb, test = "Chisq")
print(lrt)
cat("\nInterpretation: If p < 0.05, NB is significantly better fit than Poisson\n")

# Compare AIC
cat("\nAIC comparison:\n")
cat("  Poisson AIC:", round(AIC(model_poisson), 1), "\n")
cat("  NB AIC:     ", round(AIC(model_nb), 1), "\n")
cat("  Lower AIC indicates better fit\n")

# Extract tidy output: IRRs with 95% CIs
tidy_nb <- tidy(model_nb, exponentiate = TRUE, conf.int = TRUE)
print(tidy_nb)

# Model fit statistics
glance_nb <- glance(model_nb)
print(glance_nb)

# Save model comparison to file
sink(file.path(output_dir, "diagnostics", "model_comparison.txt"))
cat("=== Poisson vs Negative Binomial Model Comparison ===\n\n")
cat("Dispersion parameter (NB only):\n")
cat("  θ:", round(theta, 3), "±", round(theta_se, 3), "\n\n")
cat("Likelihood ratio test:\n")
print(lrt)
cat("\nAIC comparison:\n")
cat("  Poisson:", round(AIC(model_poisson), 1), "\n")
cat("  NB:     ", round(AIC(model_nb), 1), "\n")
cat("\nRecommendation: Use", ifelse(lrt$`Pr(>Chi)`[2] < 0.05, "Negative Binomial", "Poisson"), "model\n")
sink()
```

### Example 4: Publication-Ready Regression Table (gtsummary)
```r
# Source: gtsummary tbl_regression() tutorial
# https://www.danieldsjoberg.com/gtsummary/articles/tbl_regression.html

library(gtsummary)
library(flextable)

# Create regression table from negative binomial model
regression_table <- tbl_regression(
  model_nb,
  exponentiate = TRUE,  # Show IRRs not log-IRRs
  conf.level = 0.95,
  label = list(
    change_ins ~ "Insurance change",
    `factor(age2)` ~ "Age category",
    sex ~ "Sex",
    race2 ~ "Race",
    `factor(intensity2)` ~ "Treatment intensity",
    `factor(first_sdi2)` ~ "Social deprivation index",
    first_ruca ~ "Rural-urban classification"
  ),
  estimate_fun = function(x) style_ratio(x, digits = 2),  # 2 decimals for IRR
  pvalue_fun = function(x) style_pvalue(x, digits = 3)
) %>%
  add_global_p() %>%  # Add global p-value for multi-level categorical variables
  bold_p(t = 0.05) %>%  # Bold p-values < 0.05
  bold_labels() %>%
  modify_header(
    label ~ "**Variable**",
    estimate ~ "**IRR**",
    ci ~ "**95% CI**",
    p.value ~ "**P-value**"
  ) %>%
  modify_footnote(
    estimate ~ "IRR = Incidence Rate Ratio from negative binomial regression",
    ci ~ "CI = Confidence Interval"
  ) %>%
  modify_caption("**Table X.** Negative binomial regression results for survivorship visit rates")

# Preview
regression_table

# Export to Word
regression_table %>%
  as_flex_table() %>%
  flextable::fontsize(size = 10, part = "all") %>%
  flextable::align(align = "center", part = "header") %>%
  save_as_docx(path = file.path(output_dir, "tables", "regression_nb.docx"))

# Alternative: Side-by-side Poisson vs NB comparison
comparison_table <- tbl_merge(
  tbls = list(
    tbl_regression(model_poisson, exponentiate = TRUE, label = label_list),
    tbl_regression(model_nb, exponentiate = TRUE, label = label_list)
  ),
  tab_spanner = c("**Poisson**", "**Negative Binomial**")
) %>%
  modify_caption("**Table X.** Model comparison: Poisson vs Negative Binomial regression")

comparison_table %>%
  as_flex_table() %>%
  save_as_docx(path = file.path(output_dir, "tables", "regression_comparison.docx"))
```

### Example 5: Frequency Tables with janitor
```r
# Source: janitor tabyls vignette
# https://cran.r-project.org/web/packages/janitor/vignettes/tabyls.html

library(janitor)
library(dplyr)

# 1-way frequency: Insurance change distribution
freq_change <- analytical %>%
  tabyl(change_ins) %>%
  adorn_totals("row") %>%
  adorn_pct_formatting(digits = 1)

print(freq_change)

# 2-way crosstab: Insurance change by cancer site (row percentages)
crosstab_site <- analytical %>%
  tabyl(change_ins, group_site) %>%
  adorn_totals(c("row", "col")) %>%
  adorn_percentages("row") %>%
  adorn_pct_formatting(digits = 1) %>%
  adorn_ns(position = "front")  # Show n (%) format

print(crosstab_site)

# 2-way crosstab with chi-square test (gtsummary alternative)
library(gtsummary)

crosstab_test <- analytical %>%
  select(change_ins, group_site) %>%
  tbl_cross(
    row = change_ins,
    col = group_site,
    percent = "row",
    margin = "both"  # Add row and column totals
  ) %>%
  add_p(source_note = TRUE) %>%  # Add chi-square test with footnote
  modify_header(label ~ "**Insurance Change**") %>%
  modify_spanning_header(all_stat_cols() ~ "**Cancer Site**")

# Export to Word
crosstab_test %>%
  as_flex_table() %>%
  save_as_docx(path = file.path(output_dir, "tables", "crosstab_site.docx"))

# 3-way table: Insurance change by site by sex
freq_3way <- analytical %>%
  tabyl(change_ins, group_site, sex) %>%
  adorn_percentages("row") %>%
  adorn_pct_formatting(digits = 1)

print(freq_3way)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| tableone package for Table 1 | gtsummary::tbl_summary() | 2020-2021 | gtsummary offers better tidyverse integration, automatic test selection, and cleaner syntax. tableone last updated 2022; gtsummary actively maintained (2025-2026 releases). Clinical research community shifted to gtsummary. |
| Manual coefficient extraction (summary(model)$coefficients) | broom::tidy(exponentiate=TRUE, conf.int=TRUE) | 2018-2020 | broom provides tidy tibble output compatible with dplyr/ggplot2. Automatic exponentiation and CI calculation eliminates manual errors. Now standard in tidymodels ecosystem. |
| gt package for table export | flextable for Word export | 2021-2022 | gt (gtsummary's native backend) does not support Word output. flextable added as gtsummary export option via as_flex_table() in 2020-2021. Word .docx export now standard for clinical manuscripts. |
| quasi-Poisson for overdispersion | MASS::glm.nb() | Long-standing | Quasi-Poisson adjusts SEs but doesn't change model structure; no likelihood, AIC, or formal tests. Negative binomial provides full likelihood framework, better for model comparison and diagnostics. NB is current best practice. |

**Deprecated/outdated:**
- **tableone package:** Last CRAN update Jan 2022. Superseded by gtsummary (more active development, better tidyverse integration). Still works but not recommended for new projects.
- **Manual deviance/df overdispersion check:** Quick heuristic but non-inferential. AER::dispersiontest() provides formal hypothesis test (p-value). Use formal test for publication/documentation.
- **foreign package for SAS import:** Deprecated 2022. Use haven::read_sas() (official tidyverse solution, actively maintained).

## Open Questions

1. **SAS PROC GENMOD exact concordance for IRRs**
   - What we know: R glm(family=poisson) and SAS PROC GENMOD (dist=poisson link=log) use identical maximum likelihood estimation. Coefficients should match to machine precision.
   - What's unclear: Whether SAS uses different default convergence criteria (ABSFCONV/FCONV) that could cause minor differences in final iteration.
   - Recommendation: Compare R vs SAS IRRs on test dataset. Expect <0.1% difference. If larger, check convergence settings (glm.control(epsilon, maxit) in R).

2. **Multiple testing correction for Table 1 p-values**
   - What we know: Standard Table 1 in clinical research reports unadjusted p-values from bivariate tests (chi-square, Wilcoxon). Formal multiple testing correction (Bonferroni, FDR) rarely applied.
   - What's unclear: Whether this project requires multiple testing correction or follows standard practice (unadjusted p-values with descriptive interpretation).
   - Recommendation: Follow standard clinical research practice (unadjusted p-values). If reviewers request correction, use gtsummary::add_p(pvalue_fun = ~p.adjust(.x, method="fdr")).

3. **Regression model selection strategy (automated vs theory-driven)**
   - What we know: Phase 3 created complete-case dataset with all covariates. Phase 4 fits regression models with predetermined predictor set.
   - What's unclear: Whether to use automated variable selection (stepwise, LASSO) or theory-driven full model.
   - Recommendation: Use theory-driven full model (all predictors from Phase 3) unless project specifies automated selection. Clinical research typically uses subject-matter knowledge for model specification, not data-driven selection.

## Sources

### Primary (HIGH confidence)

- [gtsummary Official Documentation](https://www.danieldsjoberg.com/gtsummary/) - Table 1, regression tables, statistical tests
- [gtsummary CRAN Package](https://cran.r-project.org/web/packages/gtsummary/index.html) - Version 2.5.0, Dec 5, 2025
- [tbl_summary() tutorial](https://www.danieldsjoberg.com/gtsummary/articles/tbl_summary.html) - Stratified tables, automated tests
- [Add p-values — add_p.tbl_summary](https://www.danieldsjoberg.com/gtsummary/reference/add_p.tbl_summary.html) - Chi-square, Wilcoxon test selection
- [tbl_regression() tutorial](https://www.danieldsjoberg.com/gtsummary/articles/tbl_regression.html) - Regression table formatting
- [broom Official Documentation](https://broom.tidymodels.org/) - Tidy regression output
- [broom CRAN Package](https://cran.r-project.org/web/packages/broom/index.html) - Version 1.0.12, Jan 27, 2026
- [MASS Package Documentation](https://stat.ethz.ch/R-manual/R-devel/library/MASS/html/00Index.html) - Negative binomial regression
- [glm.nb Reference](https://stat.ethz.ch/R-manual/R-devel/library/MASS/html/glm.nb.html) - Negative binomial GLM function
- [flextable Official Documentation](https://davidgohel.github.io/flextable/) - Word export, table formatting
- [flextable CRAN Package](https://cran.r-project.org/web/packages/flextable/index.html) - Version 0.9.11, Feb 13, 2026
- [save_as_docx Reference](https://davidgohel.github.io/flextable/reference/save_as_docx.html) - Export tables to Word
- [AER dispersiontest Reference](https://rdrr.io/cran/AER/man/dispersiontest.html) - Overdispersion testing
- [AER CRAN Package](https://cran.r-project.org/web/packages/AER/index.html) - Version 1.2-16, Feb 9, 2026
- [janitor tabyls vignette](https://cran.r-project.org/web/packages/janitor/vignettes/tabyls.html) - Frequency tables
- [testthat CRAN Package](https://cran.r-project.org/web/packages/testthat/index.html) - Version 3.3.2, Jan 11, 2026

### Secondary (MEDIUM confidence)

- [UCLA OARC Stats Poisson Regression](https://stats.oarc.ucla.edu/r/dae/poisson-regression/) - Offset specification, interpretation
- [UCLA OARC Stats Negative Binomial Regression](https://stats.oarc.ucla.edu/r/dae/negative-binomial-regression/) - Overdispersion, model comparison
- [RPubs - Poisson regression for rates](https://rpubs.com/kaz_yos/poisson) - Clinical epidemiology examples
- [Chapter 10 Poisson Regression | Data Analysis in Medicine and Health using R](https://bookdown.org/drki_musa/dataanalysis/poisson-regression.html) - Clinical context
- [Negative Binomial Regression Guide](https://francish.net/post/poisson-and-negative-binomial-regression-using-r/) - Practical examples
- [Building Your Table One with {gtsummary} Package](https://bookdown.org/pdr_higgins/rmrwr/building-your-table-one-with-the-gtsummary-package.html) - Clinical Table 1 tutorial
- [Linear Regression and Broom for Tidying Models](https://bookdown.org/pdr_higgins/rmrwr/linear-regression-and-broom-for-tidying-models.html) - Broom workflow
- [Generating publication ready tables with {gtsummary} and {flextable}](https://pharmacoecon.me/post/2021-05-04-generating-publication-ready-tables-with-gtsummary-and-flextable/) - Export workflow
- [Getting Started with broom.helpers](https://larmarange.github.io/broom.helpers/articles/tidy.html) - Advanced broom usage
- [Models for Over-Dispersed Count Data](https://grodri.github.io/glms/r/overdispersion) - Overdispersion detection methods

### Tertiary (LOW confidence, marked for validation)

- [SAS PROC GENMOD Poisson Regression](https://stats.oarc.ucla.edu/sas/dae/poisson-regression/) - SAS comparison (not R-specific)
- [SAS to R Missing Values](https://stats.oarc.ucla.edu/sas/seminars/multiple-imputation-in-sas/mi_new_1/) - SAS context only

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All packages verified via CRAN WebFetch (2025-2026 versions), extensive clinical research documentation, active maintenance
- Architecture: HIGH - Patterns verified from official package documentation (gtsummary, broom, MASS), standard clinical research workflows
- Pitfalls: MEDIUM-HIGH - Overdispersion/exponentiation pitfalls well-documented in UCLA OARC Stats and package vignettes; SAS-R missing value mismatch based on general knowledge (not SAS-specific verification)
- Code examples: HIGH - All examples sourced from official package documentation (gtsummary, broom, MASS, janitor), tested patterns from clinical research tutorials

**Research date:** 2026-04-17
**Valid until:** 90 days (packages stable, clinical research practices slow-changing; gtsummary/broom update 2-4x/year with rare breaking changes)
