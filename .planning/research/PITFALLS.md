# Domain Pitfalls: SAS-to-R Clinical Research Conversion

**Domain:** Clinical research data pipeline conversion (SAS to R)
**Project:** Precision Cancer Survivorship Insurance Investigation
**Researched:** 2026-04-16

---

## Critical Pitfalls

These mistakes cause data integrity failures, incorrect research results, or require major rework.

### Pitfall 1: Missing Value Semantics Break Analytical Logic

**What goes wrong:** SAS and R handle missing values fundamentally differently, causing silent logic errors in comparisons, merges, and statistical calculations.

**Why it happens:**
- In SAS, missing numeric values (`.`) are treated as **negative infinity** in comparisons (e.g., `. < 5` is `TRUE`)
- In R, missing values (`NA`) **propagate** through comparisons (e.g., `NA < 5` returns `NA`, not `TRUE`)
- When importing SAS data with `haven::read_sas()`, missing values convert to `NA`, but legacy logic expects SAS comparison behavior
- String literals `"NA"` from CSV exports get misinterpreted as missing vs. text

**Consequences:**
- Filter conditions produce different patient subsets between SAS and R
- Cohort construction logic (e.g., "exclude patients with missing enrollment dates") behaves differently
- Regression models drop observations unexpectedly due to `NA` propagation
- Merge operations fail to match records that would have matched in SAS

**Prevention:**
- **Audit all comparison logic** that involves potentially-missing variables (enrollment dates, insurance changes, visit counts)
- Use explicit `is.na()` checks rather than relying on implicit comparison behavior
- Test filters with known edge cases (patients with missing values) in both systems
- Document original SAS behavior and R equivalent for each comparison

**Detection:**
- Row counts differ between SAS and R outputs for same filter
- Statistical models report different N than expected
- Merge operations produce fewer matches than SAS version
- Summary statistics differ (e.g., `mean()` without `na.rm = TRUE` returns `NA`)

**Phase mapping:** Address in **Data Cleaning/Import Phase** — set `na.rm` defaults, add validation checks for row counts.

---

### Pitfall 2: Implicit Retain in DATA Steps Creates Hidden State

**What goes wrong:** SAS DATA step variables automatically retain values from previous iterations for variables read via `SET`, but newly-created variables reset to missing. R has no equivalent implicit behavior, causing cumulative calculations and group processing logic to fail.

**Why it happens:**
- SAS DATA step is **imperative** with a Program Data Vector (PDV) that persists values across loop iterations
- R tidyverse is **declarative** — each row is independent by default
- Variables created with assignment in SAS DATA steps implicitly retain unless explicitly reset
- BY-group processing in SAS uses implicit first/last flags and retained values

**Consequences:**
- Cumulative sums (e.g., person-time accumulation, running totals of visits) produce wrong results
- Group processing logic (e.g., "flag first encounter per patient") fails
- Conditional updates (e.g., "carry forward last known insurance type") don't persist
- Row-wise calculations that depend on previous row state break

**Prevention:**
- Map SAS `RETAIN` statements to R's `dplyr::lag()`, `dplyr::lead()`, or `cumsum()` window functions
- Use `group_by() %>% mutate()` for BY-group processing instead of assuming implicit grouping
- Explicitly identify "first" and "last" records with `row_number()`, `first()`, `last()`
- Test cumulative calculations against known totals (e.g., total person-time by patient)

**Detection:**
- Cumulative variables (person-time, running counts) don't match SAS
- First/last flags produce different counts
- Carry-forward logic missing values when it shouldn't
- GROUP BY aggregations produce different results

**Phase mapping:** Address in **Cohort Construction & Variable Derivation Phases** — map all `RETAIN`, `first.`, `last.` logic explicitly.

---

### Pitfall 3: BY-Group Merge Semantics Differ Catastrophically

**What goes wrong:** SAS `MERGE` with `BY` statement and R `dplyr::left_join()` handle duplicate keys, merge order, and missing BY variables differently, causing wrong record matches and Cartesian products.

**Why it happens:**
- SAS `MERGE` requires pre-sorted data and creates one output row per unique BY-group combination
- R joins are **set-based** (SQL-like) and create Cartesian products for many-to-many matches
- SAS `MERGE` with multiple datasets uses **last value wins** for overlapping variables
- R joins require explicit suffixes for duplicated column names
- SAS BY-group processing expects sorted data; R joins work on unsorted data but may produce different row order

**Consequences:**
- **Many-to-many joins explode row counts** (e.g., merging encounters with diagnoses where both have duplicates)
- Merge order differences cause different values for overlapping variables
- Missing BY variable handling differs (SAS matches missing-to-missing; R typically doesn't)
- Wrong patients get matched due to unsorted data or merge type mismatch

**Prevention:**
- **Identify all many-to-many relationships** in SAS code (look for `MERGE` statements with datasets that both have duplicate BY values)
- Use `anti_join()`, `semi_join()` to check for unexpected matches before merging
- Explicitly check row counts: `nrow(left) * nrow(right)` should not equal `nrow(result)` unless Cartesian product intended
- Document merge type (one-to-one, one-to-many, many-to-many) for each join
- Use `dplyr::count(BY_var)` to verify uniqueness before joins

**Detection:**
- Output row counts are 10x, 100x, or 1000x larger than SAS
- Summary statistics wildly different (e.g., mean visits per patient = 500 instead of 5)
- Duplicate patient records in output when expecting one row per patient
- SAS log shows "MERGE statement has more than one data set with repeats of BY values" — flag for R conversion

**Phase mapping:** Address in **Data Merging Phase (encounter + diagnosis + insurance)** — audit all joins, add row count validation tests.

---

### Pitfall 4: SAS Formats as Hidden Business Logic

**What goes wrong:** SAS formats (e.g., from `Formats.sas`) encode critical business logic (insurance type recoding, cancer site groupings, age categories) that disappears when raw data is imported to R.

**Why it happens:**
- SAS formats are **external to data** — stored in format libraries, applied at display/analysis time
- `haven::read_sas()` imports **raw coded values** by default, not formatted labels
- Formats define groupings (e.g., insurance codes 1-5 → "Commercial", 6-10 → "Medicaid") used in analytical logic
- PROC FREQ and PROC MEANS use formatted values for tabulation, but R sees raw numbers

**Consequences:**
- Frequency tables report wrong categories (raw codes instead of meaningful labels)
- Cross-tabulations break (comparing "1, 2, 3" instead of "Commercial, Medicaid, Medicare")
- Regression models use numeric codes instead of factors, misinterpreting ordinal vs. categorical
- Table 1 demographic summaries are unreadable (sex = 1/2 instead of Male/Female)

**Prevention:**
- **Extract all SAS format definitions** from `Formats.sas` into explicit R recode logic or lookup tables
- Use `haven::read_sas()` with `col_select` and apply `as_factor()` where formats are needed
- Create named R factor levels that match SAS format logic
- Verify factor levels against SAS `PROC FREQ` output for all categorical variables
- Document which variables require format mapping (demographics, insurance types, cancer sites)

**Detection:**
- Frequency tables show numeric codes instead of labels
- Regression output references "1, 2, 3" instead of meaningful categories
- Table 1 is unreadable or doesn't match SAS version
- `class(variable)` is `numeric` when it should be `factor`

**Phase mapping:** Address in **Format Translation Phase** — create `01_formats.R` script with all recode logic before any analysis.

---

### Pitfall 5: Date/Time Conversions Lose Precision or Shift Values

**What goes wrong:** SAS dates (days since 1960-01-01) and datetimes (seconds since 1960-01-01 00:00:00) convert to R Date/POSIXct with timezone issues, precision loss, and off-by-one errors.

**Why it happens:**
- SAS date origin is **1960-01-01**, R date origin is **1970-01-01**
- SAS datetimes are in **seconds**, R `POSIXct` is in **seconds** but assumes UTC unless specified
- `haven::read_sas()` auto-converts dates but **defaults to UTC timezone**, which can shift displayed dates
- Partial dates (e.g., "missing day") are handled differently in SAS (special missing `.A`, `.B`) vs. R (`NA`)

**Consequences:**
- Enrollment dates shift by one day due to timezone conversion
- Follow-up period calculations are off by 1 day (affects person-time for Poisson regression)
- Cohort inclusion criteria based on date ranges (e.g., "enrolled after 2015-01-01") miss patients
- Age calculations at diagnosis are wrong due to date shifts

**Prevention:**
- Use `haven::read_sas()` with `col_select` and verify datetime conversion with known test cases
- Set timezone explicitly: `as.Date(x, tz = "America/New_York")` if data is in local time
- For person-time calculations, use `difftime()` with `units = "days"` and verify against SAS totals
- Test with boundary cases: leap years, daylight saving transitions, missing date components
- Document expected behavior for partial dates (e.g., missing day → first of month? `NA`?)

**Detection:**
- Cohort sizes differ by small amounts (1-5% off)
- Person-time totals don't match SAS
- Date-based filters produce different row counts
- Age calculations off by 1 year at year boundaries

**Phase mapping:** Address in **Data Import Phase** — validate all date conversions before downstream processing.

---

### Pitfall 6: PROC SQL vs. dplyr Join Defaults Differ

**What goes wrong:** SAS `PROC SQL` defaults to **inner joins** unless `LEFT JOIN`, `RIGHT JOIN`, or `FULL JOIN` is specified. R `dplyr` has explicit join functions (`left_join()`, `inner_join()`, etc.) but analysts often guess wrong based on SAS intuition.

**Why it happens:**
- SAS `PROC SQL` without explicit join type defaults to inner join
- Analysts may not recognize implicit join types in legacy SAS code
- R requires explicit join function choice, no default
- Many-to-many behavior differs (SAS creates all combinations; R warns but does the same)

**Consequences:**
- Switching from `PROC SQL` inner join to `left_join()` includes unmatched records (increases row count)
- Switching from `LEFT JOIN` to `inner_join()` drops unmatched records (decreases row count)
- Cohort inclusion/exclusion logic changes silently
- Patients with missing insurance records get dropped when they shouldn't (or vice versa)

**Prevention:**
- **Audit every `PROC SQL` join** to identify join type (inner, left, right, full)
- Look for `WHERE` clauses that filter out unmatched records — these may indicate intended inner join
- Test join with known edge cases (patients with no insurance records, patients with no encounters)
- Add assertions for expected row counts post-join

**Detection:**
- Row counts differ significantly (10-30% off)
- Cohort sizes change unexpectedly
- Patients with incomplete records appear or disappear

**Phase mapping:** Address in **Data Merging Phase** — document join types for every merge operation.

---

### Pitfall 7: Person-Time Offset Calculation Errors in Poisson Regression

**What goes wrong:** Person-time calculations (follow-up days per patient) for Poisson/negative binomial regression with `offset()` are sensitive to date arithmetic, censoring logic, and unit mismatches (days vs. years).

**Why it happens:**
- SAS calculates person-time using date subtraction (automatic day-level precision)
- R `difftime()` requires explicit `units` parameter (can default to wrong unit)
- Censoring logic (end of follow-up = min(death, end of study, loss to follow-up)) may differ between SAS and R
- Offset in R regression requires **log(person-time)** but may be applied to raw person-time by mistake

**Consequences:**
- Visit rate estimates are wrong (off by 10x if using years instead of days)
- Confidence intervals are too wide or too narrow
- Regression fails to converge if person-time is zero for some patients
- Results don't replicate SAS Poisson output

**Prevention:**
- **Verify person-time totals** against SAS before running regressions
- Use `difftime(end, start, units = "days")` explicitly
- Test with edge cases: patients with zero follow-up, patients censored at enrollment
- Apply `log()` to person-time for offset: `glm(outcome ~ exposure + offset(log(person_time)), family = poisson())`
- Cross-check rate estimates (events / person-time) against SAS PROC GENMOD output

**Detection:**
- Rate ratio estimates differ by 10x, 100x, or 365x (unit conversion error)
- Regression output shows very different confidence intervals
- Total person-time sum is off by orders of magnitude

**Phase mapping:** Address in **Outcome Variable Creation & Regression Modeling Phases** — validate person-time before regression.

---

## Moderate Pitfalls

These create maintenance burden, confusion, or subtle errors but don't immediately break results.

### Pitfall 8: Hardcoded Paths Prevent Reproducibility

**What goes wrong:** SAS code has hardcoded paths (`/blue/erin.mobley-precision/`, `F:\Data_v4`, `E:\Refreshed_data_v3`) that break when moving to different machines or users.

**Why it happens:**
- Legacy SAS code written for single-user, single-machine execution on HiPerGator
- Paths embedded in `LIBNAME`, `FILENAME`, and `%LET` statements throughout 90+ files
- Multiple data versions (v3, v4, v5) reference different paths

**Prevention:**
- **Parameterize all paths** using R's `here::here()` package for project-relative paths
- Define path variables in a single `00_config.R` script
- Use RStudio Projects to anchor working directory
- Document expected directory structure in README

**Detection:**
- Code fails with "file not found" on different machine
- User must manually edit paths in multiple files

**Phase mapping:** Address in **Project Setup Phase** — create `00_config.R` with parameterized paths.

---

### Pitfall 9: PROC FREQ vs. table() Output Doesn't Match

**What goes wrong:** SAS `PROC FREQ` produces formatted cross-tabulations with percentages, chi-square tests, and specific layouts. R `table()` produces raw counts in different format.

**Why it happens:**
- `PROC FREQ` is a specialized tabulation procedure with built-in formatting
- R `table()` is minimal — just cross-tabulated counts
- R requires additional packages (`gmodels::CrossTable()`, `procs::proc_freq()`) to match SAS output

**Prevention:**
- Use `gmodels::CrossTable()` for SAS-like crosstabs with chi-square tests
- Use `procs::proc_freq()` from the `procs` package for closest match to SAS
- Add `prop.table()` for percentage calculations
- Document which SAS `PROC FREQ` options are replicated (e.g., `CHISQ`, `MISSING`, `LIST`)

**Detection:**
- Frequency tables don't include percentages, chi-square, or expected counts
- Output format doesn't match SAS (row vs. list format)

**Phase mapping:** Address in **Table 1 & Bivariate Testing Phase** — use `CrossTable()` or `proc_freq()`.

---

### Pitfall 10: Commented-Out Code Hides Authoritative Logic

**What goes wrong:** 90 SAS files with multiple versions (v3, v4, v5) contain heavily commented-out code. The correct logic may be commented out, or old logic may still be active.

**Why it happens:**
- Code evolved over time (March 2024 — January 2025) without version control
- Analysts commented out old code rather than deleting it
- No clear indicator of which version is authoritative

**Prevention:**
- **Use Git for version control** from the start of R conversion
- Delete commented-out code in R version (rely on Git history instead)
- Document logic decisions in commit messages
- Create a "logic audit" document tracking which SAS file version was used for each step

**Detection:**
- Multiple conflicting approaches in same SAS file
- Uncertainty about which code block is "correct"
- Different results when running different file versions

**Phase mapping:** Address in **Code Forensics Phase** — map logic across versions before translating to R.

---

### Pitfall 11: Case Sensitivity Breaks Variable Names

**What goes wrong:** SAS is **case-insensitive** for variable names (`patid`, `PATID`, `PatID` are identical). R is **case-sensitive** (`patid != PATID`).

**Why it happens:**
- SAS code uses inconsistent capitalization across files
- R imports preserve original case from SAS datasets

**Prevention:**
- Standardize variable names to lowercase using `rename_with(tolower)` immediately after import
- Use `janitor::clean_names()` to standardize all variable names
- Document naming convention (e.g., "all lowercase, snake_case")

**Detection:**
- "Object not found" errors for variables that exist with different case
- Merge failures due to mismatched BY variable case

**Phase mapping:** Address in **Data Import Phase** — standardize names on import.

---

### Pitfall 12: Automatic Type Coercion Errors (Numeric vs. Character)

**What goes wrong:** SAS only has two types (character, numeric). R has many (`character`, `numeric`, `integer`, `factor`, `Date`, etc.) and auto-coercion rules differ.

**Why it happens:**
- SAS `INPUT()` and `PUT()` functions explicitly convert between character and numeric
- R `as.numeric()`, `as.character()` behave differently (e.g., factors convert to level integers, not labels)
- `haven::read_sas()` may import character IDs as factors or numeric

**Prevention:**
- Explicitly check imported data types: `str(data)` or `glimpse(data)`
- Convert factors to character before recoding: `as.character(factor_var)`
- Use `readr::type_convert()` to re-infer types after import if needed
- Test type conversions with edge cases (leading zeros, missing values, scientific notation)

**Detection:**
- Patient IDs change (e.g., "001" becomes `1`)
- Factor levels convert to integers instead of labels
- Merge fails due to type mismatch (character vs. numeric ID)

**Phase mapping:** Address in **Data Import Phase** — validate types for all key variables.

---

## Minor Pitfalls

These are nuisances or style issues but don't break logic.

### Pitfall 13: Semicolons and Syntax Style Differences

**What goes wrong:** SAS requires semicolons to terminate statements. R doesn't. SAS uses `RUN;` to execute procedures. R uses function calls.

**Why it happens:**
- Muscle memory from SAS syntax
- Copy-pasting SAS code structure into R

**Prevention:**
- Use RStudio's code formatter to catch syntax errors early
- Use `lintr` and `styler` packages to enforce R style conventions

**Detection:**
- Syntax errors on semicolons
- Unnecessary `run()` or `quit()` statements in R code

**Phase mapping:** Not critical — catch during code review.

---

### Pitfall 14: PROC MEANS vs. summary() Output Format

**What goes wrong:** `PROC MEANS` produces formatted summary statistics (N, mean, std, min, max) in specific layout. R `summary()` produces different format and statistics.

**Why it happens:**
- Different default statistics
- Different output formats

**Prevention:**
- Use `procs::proc_means()` for SAS-like output
- Use `dplyr::summarise()` with explicit statistics for full control
- Use `skimr::skim()` for comprehensive summary statistics

**Detection:**
- Summary tables don't match SAS layout
- Missing or different statistics (e.g., median vs. mean)

**Phase mapping:** Address in **Summary Statistics Phase** — use appropriate R function.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| **Data Import** | Missing value handling, date/time conversion, type coercion | Use `haven::read_sas()` with explicit checks; validate dates and types |
| **Format Translation** | SAS formats as hidden business logic | Extract all format definitions from `Formats.sas` to `01_formats.R` |
| **Data Cleaning** | Hardcoded paths, case sensitivity | Parameterize paths with `here()`; standardize variable names with `clean_names()` |
| **Data Merging (encounters + insurance + diagnoses)** | BY-group merge semantics, many-to-many joins, PROC SQL join type differences | Audit all joins; check for Cartesian products; validate row counts |
| **Cohort Construction** | Implicit retain in BY-groups, missing value comparisons | Map `RETAIN`, `first.`, `last.` to window functions; explicit `is.na()` checks |
| **Variable Derivation** | Implicit retain for cumulative calculations | Use `cumsum()`, `lag()`, `lead()` window functions |
| **Outcome Calculation (person-time)** | Date arithmetic, person-time offset errors | Verify person-time totals; use `difftime(units = "days")` |
| **Table 1 / Bivariate Testing** | PROC FREQ output format differences | Use `CrossTable()` or `proc_freq()` |
| **Regression Modeling** | Person-time offset calculation, missing value propagation | Validate person-time; apply `log(person_time)` for offset |
| **Code Organization** | Commented-out code hides logic | Use Git; delete old code; document decisions |

---

## Validation Checklist (Use Before Finalizing R Pipeline)

- [ ] **Row counts match** between SAS and R for all intermediate datasets
- [ ] **Summary statistics match** for key variables (mean age, total person-time, visit counts)
- [ ] **Date variables validated** (no off-by-one errors, timezone issues resolved)
- [ ] **Missing values handled consistently** (explicit `is.na()` checks, `na.rm` where appropriate)
- [ ] **All joins audited** (join type documented, many-to-many checked, row counts validated)
- [ ] **Format translations verified** (factor levels match SAS formatted output)
- [ ] **Person-time calculations correct** (difftime units explicit, totals match SAS)
- [ ] **Regression output replicates SAS** (rate ratios, confidence intervals, model convergence)
- [ ] **Table 1 matches SAS** (demographics, percentages, chi-square tests)
- [ ] **Paths parameterized** (no hardcoded paths, `here()` used throughout)

---

## Sources

### SAS-to-R Conversion & Clinical Research
- [Cytel: SAS vs. R in Clinical Development](https://cytel.com/perspectives/sas-vs-r-in-clinical-development/)
- [Instem: How R and SAS Can Coexist in Clinical Study Reporting](https://www.instem.com/how_sas_and_r_can_coexist/)
- [ProCogia: Transitioning Clinical Research from SAS to R](https://procogia.com/transitioning-clinical-research-from-sas-to-r-an-introduction-to-the-pharmaverse-ecosystem/)
- [Appsilon: SAS vs R Programming - How to Switch](https://www.appsilon.com/post/sas-vs-r-programming)
- [Quanticate: R Programming Datasets - Reliability for SAS Datasets](https://www.quanticate.com/blog/r-programming-datastes)
- [Quanticate: First Steps in Laboratory Dataset Handling - SAS to R](https://www.quanticate.com/blog/laboratory-dataset-in-sas)
- [Lucid Analytics: From SAS to R in Regulatory Biostatistics](https://www.lucid-analytics.ai/2026/lucid-life/from-sas-to-r-in-regulatory-biostatistics-why-the-shift-is-happening/)

### PROC SQL, dplyr, and Data Handling
- [LinkedIn: Common Pitfalls in SAS DATA Step and PROC SQL](https://www.linkedin.com/advice/1/what-some-common-pitfalls-errors-avoid)
- [Katalyze Data: R for SAS Programmers](https://katalyzedata.com/insights/r-for-sas-programmers-2/)
- [SAS Support: Merge with Caution - Common Errors](https://support.sas.com/resources/papers/proceedings18/1746-2018.pdf)
- [ProCogia: Understanding the SAS DATA Step](https://procogia.com/understanding-the-sas-data-step/)

### PCORnet CDM
- [PCORnet: Common Data Model](https://pcornet.org/data/common-data-model/)
- [GitHub: PCORnet CDM Guidance](https://github.com/CDMFORUM/CDM-GUIDANCE)
- [PCORnet: CDM Data Quality Validation](https://pcornet.org/news/resources-common-data-model-cdm-data-quality-validation/)
- [PMC: Tailoring Rule-Based Data Quality Assessment to PCORnet CDM](https://pmc.ncbi.nlm.nih.gov/articles/PMC10148276/)

### Missing Values & Data Type Conversions
- [haven: Conversion Semantics](https://cran.r-project.org/web/packages/haven/vignettes/semantics.html)
- [Paul Dickman: SAS Tips - Missing Values](https://www.pauldickman.com/sastips/missing/)
- [UCLA Stats: How R Handles Missing Values](https://stats.oarc.ucla.edu/r/faq/how-does-r-handle-missing-values/)
- [Yu.Z: All You Need to Know About Date/Time in R and SAS](https://yuzhu.run/datetime-in-r-and-sas/)
- [haven: Date/Time Vignette](https://rdrr.io/cran/haven/f/vignettes/datetimes.Rmd)

### PROC FREQ, PROC MEANS, and Statistical Output
- [CRAN: procs Package - Frequency Function](https://cran.r-project.org/web/packages/procs/vignettes/procs-freq.html)
- [DataCamp: Frequencies and Crosstabs in R](https://www.datacamp.com/doc/r/frequencies)
- [OARC Stats: Poisson Regression in R](https://stats.oarc.ucla.edu/r/dae/poisson-regression/)
- [PMC: Methods for Stratification of Person-Time - Poisson Regression](https://pmc.ncbi.nlm.nih.gov/articles/PMC2615420/)

### Reproducibility & Best Practices
- [UCL: Best Practices for Writing R Code](http://github-pages.arc.ucl.ac.uk/r-amr-epidemiology/best-practices-R.html)
- [Medium: Please Stop Hard-Coding File Paths](https://medium.com/@jordan.l.edmunds/please-stop-hard-coding-file-paths-609c769f9537)
- [Software Carpentry: Best Practices for R Code](https://swcarpentry.github.io/r-novice-inflammation/06-best-practices-R.html)
- [Bookdown: Intermediate Steps Toward Reproducibility](https://bookdown.org/pdr_higgins/rmrwr/intermediate-steps-toward-reproducibility.html)

### Legacy Code Modernization
- [Made with Love: Legacy Code Modernization](https://madewithlove.com/legacy-code/)
- [Understand Legacy Code: Change Messy Software Without Breaking It](https://understandlegacycode.com/)
- [Adamant Code: Your Guide to Legacy Code Modernization in 2026](https://www.adamantcode.com/blog/legacy-code-modernization)
- [ModLogix: Legacy Code Refactoring - Tips, Steps, Best Practices](https://modlogix.com/blog/legacy-code-refactoring-tips-steps-and-best-practices/)

### Cancer Survivorship & EHR Research
- [PMC: CASIDE Data Model for Cancer Survivorship](https://pmc.ncbi.nlm.nih.gov/articles/PMC9930408/)
- [ScienceDirect: Integration of EHR and Cancer Registry Data](https://www.sciencedirect.com/science/article/pii/S0006497118734642)
- [PMC: Use of Electronic Medical Records for Oncology Outcomes Research](https://pmc.ncbi.nlm.nih.gov/articles/PMC3224632/)

---

**Confidence Level: HIGH** — Sources include clinical research migration guides, technical documentation, academic publications, and vendor resources specific to SAS-to-R conversion, PCORnet CDM, and cancer survivorship EHR research.
