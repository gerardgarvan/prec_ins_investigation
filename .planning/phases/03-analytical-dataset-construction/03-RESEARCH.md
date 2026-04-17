# Phase 3: Analytical Dataset Construction - Research

**Researched:** 2026-04-16
**Domain:** Clinical cohort construction, exposure/outcome variable derivation, person-time calculation
**Confidence:** HIGH

## Summary

Phase 3 constructs the study cohort through sequential exclusion criteria, derives exposure variables (insurance change, treatment intensity, cancer site groups, chemotherapy), calculates outcome variables (visit counts, person-time), processes covariates (demographics, SDI, RUCA, age categories), and produces a single wide patient-level analytical dataset ready for statistical analysis. This phase follows standard observational cohort study patterns: encounter-level data aggregates to patient-level, sequential filtering logs attrition, and all variables needed for regression models appear in one row per patient.

The tidyverse ecosystem (dplyr, tidyr, lubridate) provides all required capabilities for this transformation. Primary technical challenges are: (1) faithful SAS logic translation (especially for edge cases in pct_change_ins calculation), (2) person-time calculation with correct censoring rules, (3) CONSORT flowchart generation without additional package dependencies, and (4) multiple imputation dataset preparation using the mice package.

**Primary recommendation:** Use dplyr group_by/summarize for encounter-to-patient aggregation, lubridate for date arithmetic and person-time calculation, custom ggplot2 for CONSORT flowchart (geom_rect + geom_text + geom_segment per CONTEXT.md D-03), and mice package for MI-ready dataset preparation. Track attrition with a cohort_flow tibble that logs patient counts after each exclusion step. Produce both complete-case analytical dataset (for_table1-4 equivalent) and MI-ready dataset (mi_table1-4 equivalent) per Phase 1 D-11.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Keep 4 scripts matching run_all.R placeholders: `03_cohort.R` -> `03_exposure.R` -> `03_outcomes.R` -> `03_covariates.R`. Linear dependency chain.
- **D-02:** Each script is self-contained: reads .rds checkpoint inputs, writes .rds checkpoint outputs. Can rerun any script independently without running predecessors in the same R session.
- **D-03:** Generate CONSORT-style exclusion flowchart using ggplot2 custom (geom_rect + geom_text + geom_segment). No additional package dependency.
- **D-04:** Save flowchart in both PNG and PDF formats to `output/figures/` directory.
- **D-05:** Final output is one wide patient-level tibble: one row per patient with all exposure, outcome counts, covariates, and person-time columns. Matches SAS `for_table1` pattern.
- **D-06:** Produce both complete-case analytical dataset AND MI-ready dataset. Matches SAS `for_table1-4` + `mi_table1-4` structure. Phase 4 runs analyses on both per Phase 1 D-11.
- **D-07:** Censoring rules extracted faithfully from V5 SAS code. Translate exactly as SAS defines them. Do not redesign censoring logic.
- **D-08:** Exposure variable (pct_change_ins) translated faithfully from SAS, with inline comments flagging edge cases (single-observation patients, undefined denominators, etc.) for research team review.

### Claude's Discretion
- Execution order within each script (section sequencing)
- Specific assertr assertions to include at each checkpoint
- How to structure the MI-ready dataset (mice-compatible format vs. pre-imputed)
- CONSORT flowchart visual layout and styling choices
- Resolution of conflicting logic between SAS file versions (using V5-primary rule from Phase 1 D-10)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| COH-01 | Valid enrollment criteria filter patients correctly (matching SAS valid_id logic) | Standard dplyr filter() with assertr verification; log counts before/after |
| COH-02 | Cancer diagnosis identification uses correct ICD-9/ICD-10 codes for reportable cancers | Use existing icd_groups dataset from Phase 1; SEER casefinding lists provide authoritative code sets |
| COH-03 | Sequential exclusion criteria are applied with patient counts logged at each step | Cohort attrition tracking tibble pattern (visR package approach); manual logging with message() |
| COH-04 | CONSORT-style exclusion flowchart is generated as a publication-ready figure | Custom ggplot2 using geom_rect (boxes) + geom_text (labels/counts) + geom_segment (arrows) — no package dependency |
| COH-05 | Baseline (first cancer diagnosis date) is correctly identified per patient | group_by(id) %>% filter(any_reportable_cancer == 1) %>% slice_min(admit_date) pattern from SAS V5_4 |
| EXP-01 | Insurance change variable (pct_change_ins) calculated correctly from first cancer payer to follow-up payer | Requires forensic SAS translation with edge case handling (division by zero, single-observation patients); flag for review |
| EXP-02 | Treatment intensity derived from SCT, radiation, surgery, and chemotherapy data matching SAS logic | Multi-source aggregation (encounters, procedures, dispensing); use existing Phase 1 datasets |
| EXP-03 | Cancer site groups (group_site) created with correct ICD code-to-site mapping | Use icd_groups dataset; factor() with sas_formats from Phase 1 |
| EXP-04 | Chemotherapy identification uses correct NDC codes and procedure codes | Filter dispensing dataset by NDC range; filter procedures by chemo-specific codes from SAS |
| OUT-01 | Non-acute care encounters (Enc_nonacute_care) correctly flagged using ENC_TYPE in ('AV','TH') | Simple filter on enc_type; aggregate counts per patient with group_by/summarize |
| OUT-02 | Cancer-related visits correctly require non-acute care + any_reportable_cancer diagnosis | Encounter-diagnosis join; flag if both conditions met; aggregate per patient |
| OUT-03 | Cancer visit with provider correctly requires cancer-related visit + cancer provider specialty | Three-way join (encounter-dx-provider); specialty filter from provider dataset |
| OUT-04 | Survivorship visits correctly require non-acute care + cancer provider + ICD personal treatment history codes | Four-way logic (enc_type + provider specialty + ICD Z85/V10 codes + reportable cancer); most restrictive definition |
| OUT-05 | Person-time (days from first cancer dx to follow-up) calculated correctly with appropriate censoring | lubridate interval() or as.numeric(difftime()); censoring rules from V5 SAS — translate faithfully per D-07 |
| OUT-06 | Visit counts are aggregated per patient for use as count outcomes in regression | group_by(id) %>% summarize(n_visits = n()) standard pattern; multiple outcome columns in final dataset |
| COV-01 | Sex, race, and Hispanic ethnicity recoded with correct PCORnet CDM factor labels | Use sas_formats from Phase 1; factor() with explicit levels matching PCORnet CDM spec |
| COV-02 | Age categories derived correctly (matching SAS age2 groupings: <15, 15-40, 40-54, 55-64, 65+) | cut() or case_when() with breaks matching SAS; factor with ordered levels |
| COV-03 | SDI score processed with correct formatting/categories | Continuous SDI from Phase 1; tertile or quartile categorization if needed (SAS shows first_sdi2 with 3 groups: <=45, <74, <=100) |
| COV-04 | RUCA classification processed with correct urban-rural categories | Use ruca dataset from Phase 1; factor() with sas_formats |

</phase_requirements>

## Standard Stack

### Core (Already Established)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| **dplyr** | 1.2.1 | Data manipulation (filter, select, mutate, group_by, summarize) | De facto standard for clinical cohort construction. group_by/summarize aggregates encounter-level to patient-level. |
| **tidyr** | 1.3.2 | Data reshaping (pivot_wider for wide analytical dataset) | Converts long encounter data to wide patient-level format with one column per outcome variable. |
| **lubridate** | 1.9.5 | Date arithmetic, interval calculation, person-time | interval() or as.numeric(difftime()) calculates days between dates. Essential for person-time and censoring logic. |
| **stringr** | 1.6.0 | String manipulation for code matching | str_detect() for ICD code pattern matching (e.g., Z85.*, V10.*). |
| **forcats** | 1.0.1 | Factor recoding for categorical variables | fct_recode(), fct_collapse() for demographics and cancer site grouping. |
| **ggplot2** | 4.0.2 | CONSORT flowchart generation (custom graphics) | geom_rect + geom_text + geom_segment for publication-ready CONSORT diagram without additional packages. |
| **assertr** | 2.8 | Data quality checks at each cohort filtering step | verify(), assert() with warn_report for non-stopping validation. Tracks assertion failures without halting pipeline. |

### Supporting (New for Phase 3)
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **mice** | 3.16.0 | Multiple imputation dataset preparation | Required for MI-ready dataset (mi_table1-4 equivalent). Handles missing data in covariates and exposure variables. |

**Installation:**
```bash
# mice package (new for Phase 3)
install.packages("mice")
```

**Version verification:** As of April 2026, mice version 3.16.0 is current (CRAN verified). All other packages already installed in Phases 1-2.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom ggplot2 CONSORT | ggconsort, consort, flowchart packages | Additional dependencies; CONTEXT.md D-03 requires custom ggplot2 only |
| Manual attrition logging | visR::get_attrition() | visR adds dependency; manual tibble logging is lightweight and sufficient |
| lubridate intervals | base R difftime() | lubridate more readable (`interval(start, end) / days(1)`); both work |
| mice for MI prep | Manual dummy coding | mice automates variable selection, imputation model specification, and pooling — standard in clinical research |

## Architecture Patterns

### Recommended Project Structure (Phase 3 Scripts)
```
R/
├── 03_cohort.R         # Sequential exclusion, attrition tracking, CONSORT flowchart
├── 03_exposure.R       # Insurance change, treatment intensity, cancer site, chemo
├── 03_outcomes.R       # Visit counts, person-time calculation, censoring
└── 03_covariates.R     # Demographics, age categories, SDI, RUCA; final wide dataset assembly
```

### Pattern 1: Sequential Cohort Exclusion with Attrition Tracking
**What:** Apply exclusion criteria one at a time, logging patient count after each step. Store in a tibble for CONSORT flowchart.

**When to use:** Cohort construction with multiple exclusion criteria (COH-03, COH-04).

**Example:**
```r
# Initialize attrition tracker
attrition <- tibble(
  step = character(),
  description = character(),
  n_patients = integer(),
  n_excluded = integer()
)

# Starting cohort
cohort <- demo_validEnroll
attrition <- attrition %>% add_row(
  step = "1",
  description = "Valid enrollment",
  n_patients = nrow(cohort),
  n_excluded = NA_integer_
)

# Exclusion 1: No cancer diagnosis
cohort_cancer <- cohort %>% filter(!is.na(first_admit_date_forcancer))
attrition <- attrition %>% add_row(
  step = "2",
  description = "Has reportable cancer diagnosis",
  n_patients = nrow(cohort_cancer),
  n_excluded = nrow(cohort) - nrow(cohort_cancer)
)

# Continue for all exclusion criteria...
message("Cohort attrition logged: ", nrow(attrition), " steps")
```

**Source:** Adapted from visR attrition table pattern and CONSORT guidelines.

### Pattern 2: Encounter-to-Patient Aggregation (Visit Counts)
**What:** Aggregate encounter-level flags to patient-level counts using group_by/summarize.

**When to use:** Calculating visit count outcomes (OUT-01, OUT-02, OUT-03, OUT-04, OUT-06).

**Example:**
```r
# Count non-acute care encounters per patient
outcome_nonacute <- encounters %>%
  filter(enc_type %in% c("AV", "TH")) %>%
  group_by(id) %>%
  summarize(
    n_Enc_nonacute_care = n(),
    enc_nonacute_ind = 1L,  # Binary indicator (anyone with >=1)
    .groups = "drop"
  )

# Count cancer-related visits (non-acute + any_reportable_cancer diagnosis)
outcome_cancer <- encounters %>%
  filter(enc_type %in% c("AV", "TH"), any_reportable_cancer == 1) %>%
  group_by(id) %>%
  summarize(
    n_Cancer_related_visit = n(),
    cancer_related_ind = 1L,
    .groups = "drop"
  )
```

**Source:** [dplyr group_by/summarize documentation](https://dplyr.tidyverse.org/reference/summarise.html), [clinical data aggregation guide](https://www.epirhandbook.com/en/new_pages/grouping.html).

### Pattern 3: Person-Time Calculation with Censoring
**What:** Calculate days from baseline (first cancer diagnosis) to follow-up end, applying censoring rules for death, loss to follow-up, or study end.

**When to use:** Person-time for Poisson/negative binomial regression offsets (OUT-05).

**Example:**
```r
# Person-time calculation with censoring
cohort <- cohort %>%
  mutate(
    # Censoring date: earliest of death, enrollment end, or study end
    censor_date = pmin(
      if_else(deceased == "Y", death_date, as.Date("2025-12-31")),
      enr_end_date,
      as.Date("2025-12-31"),  # Study end date
      na.rm = TRUE
    ),
    # Person-time in days
    person_time_days = as.numeric(difftime(censor_date, first_admit_date, units = "days")),
    # Log-transformed for regression offset
    log_person_time_days = log(person_time_days)
  ) %>%
  # Verify non-negative person-time
  verify(person_time_days >= 0) %>%
  # Flag edge cases (very short follow-up)
  verify(person_time_days > 0, warn_report)
```

**Source:** [lubridate date arithmetic](https://library.virginia.edu/data/articles/working-with-dates-and-time-in-r-using-the-lubridate-package), [censoring in cohort studies](https://pmc.ncbi.nlm.nih.gov/articles/PMC6248498/).

### Pattern 4: Custom CONSORT Flowchart with ggplot2
**What:** Build CONSORT diagram using ggplot2 primitives (geom_rect for boxes, geom_text for labels/counts, geom_segment for arrows).

**When to use:** COH-04 requirement; CONTEXT.md D-03 mandates no additional packages.

**Example:**
```r
# Define box positions and content from attrition tibble
consort_boxes <- tibble(
  box_id = 1:nrow(attrition),
  x = 0.5,  # Centered
  y = seq(nrow(attrition), 1, by = -1),  # Top to bottom
  label = paste0(attrition$description, "\nn = ", attrition$n_patients),
  excluded = if_else(is.na(attrition$n_excluded), "",
                     paste0("Excluded: ", attrition$n_excluded))
)

# Create flowchart
consort_plot <- ggplot() +
  # Boxes
  geom_rect(data = consort_boxes,
            aes(xmin = x - 0.3, xmax = x + 0.3,
                ymin = y - 0.3, ymax = y + 0.3),
            fill = "lightblue", color = "black") +
  # Box labels
  geom_text(data = consort_boxes,
            aes(x = x, y = y, label = label),
            size = 3, fontface = "bold") +
  # Arrows between boxes
  geom_segment(data = consort_boxes %>% filter(box_id < max(box_id)),
               aes(x = x, xend = x, y = y - 0.3, yend = y - 0.7),
               arrow = arrow(length = unit(0.2, "cm"))) +
  # Exclusion annotations (to the right)
  geom_text(data = consort_boxes %>% filter(excluded != ""),
            aes(x = x + 0.5, y = y, label = excluded),
            size = 2.5, hjust = 0, color = "red") +
  theme_void() +
  coord_cartesian(xlim = c(0, 1.5), ylim = c(0, nrow(attrition) + 1))

# Save in both formats per D-04
ggsave(file.path(output_dir_figures, "consort_flowchart.png"),
       consort_plot, width = 8, height = 10, dpi = 300)
ggsave(file.path(output_dir_figures, "consort_flowchart.pdf"),
       consort_plot, width = 8, height = 10)
```

**Source:** [Custom CONSORT with ggplot2](https://rpubs.com/phiggins/461686), [ggplot2 geom_rect reference](https://ggplot2.tidyverse.org/reference/geom_tile.html).

### Pattern 5: Multiple Imputation Dataset Preparation
**What:** Prepare MI-ready dataset for mice package. Retain all patients but flag missing covariates. mice imputes missing values across m datasets.

**When to use:** D-06 requires both complete-case and MI-ready datasets.

**Example:**
```r
library(mice)

# Complete-case analytical dataset (remove patients with missing covariates)
analytical_complete <- analytical %>%
  filter(complete.cases(sex, race, hispanic, first_payer, first_sdi, first_ruca))

message("Complete-case dataset: ", nrow(analytical_complete), " patients")

# MI-ready dataset (all patients, allow missing covariates)
analytical_mi <- analytical  # Keep all patients

# Verify mice compatibility
# mice expects: numeric covariates as numeric, factors as factors
analytical_mi <- analytical_mi %>%
  mutate(across(where(is.character), as.factor))

# Check missing data patterns (diagnostic only, not part of Phase 3)
# md.pattern(analytical_mi)  # Uncomment to view missing patterns

# Save MI-ready dataset for Phase 4 imputation
saveRDS(analytical_mi, file.path(data_dir_processed, "03_analytical_mi.rds"))
message("MI-ready dataset saved: ", nrow(analytical_mi), " patients")
```

**Source:** [mice package introduction](https://amices.org/mice/), [MI workflow in R](https://library.virginia.edu/data/articles/getting-started-with-multiple-imputation-in-r).

### Anti-Patterns to Avoid
- **Cartesian product on join without relationship specification:** Use `relationship = "many-to-many"` explicitly on all joins to avoid silent row explosion (Phase 2 MRG-03 pattern).
- **Overwriting cohort object without logging:** Always create new object (cohort -> cohort_cancer -> cohort_enrolled) to allow attrition tracking.
- **Assuming zero counts mean zero visits:** Patients not in outcome aggregation have zero visits — must use `left_join()` with cohort and fill NAs with 0.
- **Ignoring edge cases in pct_change_ins:** SAS code has undefined denominators for single-observation patients — must replicate exactly per D-08 with inline warnings.
- **Forgetting log offset:** Person-time MUST be log-transformed for Poisson/NB regression — create `log_person_time_days` column in analytical dataset.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Multiple imputation algorithm | Custom MCMC sampler for missing data | mice package | mice implements fully conditional specification (FCS) with 20+ years of validation. Handles mixed data types, passive imputation, convergence diagnostics. Rolling your own risks incorrect imputation models. |
| CONSORT flowchart auto-layout | Force-directed graph layout algorithm | Manual box positioning (pre-calculated y-coordinates) | CONSORT diagrams have standardized vertical layout. Manual positioning is simpler, more predictable, and matches publication standards. |
| Date interval arithmetic | Manual day counting from epoch | lubridate::interval() or difftime() | Leap years, time zones, daylight saving time create edge cases. lubridate handles all of these correctly. |
| Attrition tracking across steps | Global counter variables | Attrition tibble (tibble with step/description/n/excluded columns) | Tibble is pipe-friendly, auditable, and directly usable for CONSORT flowchart generation. |
| PCORnet CDM code validation | Regex patterns for ICD code validation | Existing icd_groups dataset from Phase 1 | SEER casefinding lists (already imported in Phase 1) provide authoritative reportable cancer definitions. Don't revalidate. |

**Key insight:** Clinical cohort construction involves complex censoring rules, date arithmetic edge cases, and missing data handling. Use validated packages (lubridate, mice) rather than reimplementing statistical algorithms. Custom solutions underestimate complexity of leap years, time zones, convergence diagnostics, and imputation model specification.

## Common Pitfalls

### Pitfall 1: SAS vs R Date Arithmetic Differences
**What goes wrong:** SAS calculates date differences as numeric days automatically. R difftime() returns a difftime object, not numeric, causing downstream errors in log() transformation.

**Why it happens:** R preserves units metadata on time differences. log() expects numeric input.

**How to avoid:** Always use `as.numeric(difftime(..., units = "days"))` or lubridate `interval() / days(1)` to get numeric days.

**Warning signs:** Error "non-numeric argument to mathematical function" when calculating log_person_time_days.

**Example:**
```r
# WRONG: difftime returns difftime object
person_time_days <- difftime(end_date, start_date, units = "days")
log_person_time <- log(person_time_days)  # ERROR

# CORRECT: Coerce to numeric
person_time_days <- as.numeric(difftime(end_date, start_date, units = "days"))
log_person_time <- log(person_time_days)  # Works
```

### Pitfall 2: Left Join vs Inner Join for Outcome Aggregation
**What goes wrong:** Using `inner_join()` to merge visit counts with cohort drops patients with zero visits. Final dataset loses patients who had no events, biasing analyses.

**Why it happens:** group_by/summarize only returns patients who appear in filtered data. Patients with zero qualifying visits don't appear in outcome tibble.

**How to avoid:** Always use `left_join()` when merging aggregated outcomes back to cohort. Fill NA counts with 0 using `replace_na()` or `coalesce()`.

**Warning signs:** Patient count drops unexpectedly after merging outcome variables. Patients with zero visits completely absent from analytical dataset.

**Example:**
```r
# Aggregate survivorship visits (only patients with >=1 visit appear)
survivorship_counts <- encounters %>%
  filter(survivorship_visit == 1) %>%
  group_by(id) %>%
  summarize(n_Survivorship_visit = n())

# WRONG: inner_join drops patients with zero visits
analytical <- cohort %>%
  inner_join(survivorship_counts, by = "id")  # Loses zero-visit patients

# CORRECT: left_join keeps all cohort patients, fill NAs with 0
analytical <- cohort %>%
  left_join(survivorship_counts, by = "id") %>%
  mutate(n_Survivorship_visit = replace_na(n_Survivorship_visit, 0))
```

**Source:** [dplyr join types](https://dplyr.tidyverse.org/reference/mutate-joins.html), Phase 2 logged_join pattern.

### Pitfall 3: Forgetting to Sort Before slice_min() for First Cancer Diagnosis
**What goes wrong:** slice_min(admit_date) without prior sorting by ID can return arbitrary row when ties exist (same patient, multiple encounters on same date).

**Why it happens:** slice_min() breaks ties arbitrarily. If patient has multiple encounters on first cancer diagnosis date, wrong encounter may be selected.

**How to avoid:** Use `arrange(id, admit_date, encounterid)` before slice_min() to ensure deterministic tie-breaking. Or use `slice_min(admit_date, n = 1, with_ties = FALSE)`.

**Warning signs:** First cancer diagnosis date correct, but associated encounter variables (enc_type, payer, provider) inconsistent across runs.

**Example:**
```r
# WRONG: Arbitrary tie-breaking
first_cancer <- encounters %>%
  filter(any_reportable_cancer == 1) %>%
  group_by(id) %>%
  slice_min(admit_date, n = 1)  # If multiple encounters on same date, picks arbitrarily

# CORRECT: Deterministic tie-breaking by encounter ID
first_cancer <- encounters %>%
  filter(any_reportable_cancer == 1) %>%
  arrange(id, admit_date, encounterid) %>%
  group_by(id) %>%
  slice_min(admit_date, n = 1, with_ties = FALSE)
```

### Pitfall 4: Division by Zero in pct_change_ins Calculation
**What goes wrong:** SAS code calculates percentage change in insurance. For patients with single observation (first_payer == follow_up_payer), denominator is zero, yielding Inf or NaN.

**Why it happens:** SAS . (missing) propagates silently. R Inf/NaN causes downstream errors in regression models.

**How to avoid:** Replicate SAS logic exactly per D-08, but add inline comment flagging edge case. Consider assigning NA for undefined cases with warning message.

**Warning signs:** Inf or NaN values in pct_change_ins column. Regression models fail with "non-finite values" error.

**Example:**
```r
# SAS-style calculation (may produce Inf/NaN)
cohort <- cohort %>%
  mutate(
    pct_change_ins = (follow_up_payer - first_payer) / first_payer * 100,
    # EDGE CASE FLAGGED: Single-observation patients have first_payer == follow_up_payer
    # Denominator is zero -> Inf. SAS treats as missing. Consider manual review.
    pct_change_ins = if_else(is.infinite(pct_change_ins), NA_real_, pct_change_ins)
  )

# Log edge cases for research team review
edge_cases <- cohort %>% filter(is.na(pct_change_ins))
message("WARNING: ", nrow(edge_cases), " patients with undefined pct_change_ins (division by zero)")
```

### Pitfall 5: Assuming mice Imputation Happens in Phase 3
**What goes wrong:** Phase 3 prepares MI-ready dataset but does NOT perform imputation. Imputation happens in Phase 4 using `mice::mice()` function before analysis.

**Why it happens:** Confusion between "MI-ready dataset" (all patients, allows missing values) and "imputed datasets" (m=5 datasets with missing values filled in by MICE algorithm).

**How to avoid:** Phase 3 creates `03_analytical_mi.rds` with missing values intact. Phase 4 reads this file, calls `mice(data, m = 5)`, analyzes each imputed dataset, and pools results with `pool()`.

**Warning signs:** Trying to use mice::mice() in 03_covariates.R. Missing values still present in MI-ready dataset (this is correct).

**Phase 3 scope:** Prepare data structure, flag missing patterns.
**Phase 4 scope:** Impute missing values, analyze, pool.

## Code Examples

Verified patterns from established sources:

### Sequential Cohort Filtering with Attrition Logging
```r
# Source: CONSORT guidelines + visR attrition pattern
library(dplyr)
library(assertr)

# Initialize attrition tracker
attrition <- tibble(
  step = character(),
  description = character(),
  n_patients = integer(),
  n_excluded = integer()
)

# Step 1: Starting cohort (valid enrollment)
cohort <- demo_validEnroll
attrition <- add_row(attrition,
  step = "1_start",
  description = "Valid enrollment criteria",
  n_patients = nrow(cohort),
  n_excluded = NA_integer_
)
message("Step 1: Valid enrollment — ", nrow(cohort), " patients")

# Step 2: Has reportable cancer diagnosis
cohort_cancer <- cohort %>%
  filter(!is.na(first_admit_date), first_admit_date_forcancer == 1)
attrition <- add_row(attrition,
  step = "2_cancer",
  description = "Reportable cancer diagnosis",
  n_patients = nrow(cohort_cancer),
  n_excluded = nrow(cohort) - nrow(cohort_cancer)
)
message("Step 2: Cancer diagnosis — ", nrow(cohort_cancer), " patients (",
        nrow(cohort) - nrow(cohort_cancer), " excluded)")

# Step 3: Age >= 18 at diagnosis
cohort_adult <- cohort_cancer %>%
  filter(age >= 18)
attrition <- add_row(attrition,
  step = "3_adult",
  description = "Age >= 18 at diagnosis",
  n_patients = nrow(cohort_adult),
  n_excluded = nrow(cohort_cancer) - nrow(cohort_adult)
)
message("Step 3: Adult patients — ", nrow(cohort_adult), " patients (",
        nrow(cohort_cancer) - nrow(cohort_adult), " excluded)")

# Continue for all exclusion criteria...

# Save attrition for CONSORT flowchart
saveRDS(attrition, file.path(data_dir_processed, "03_cohort_attrition.rds"))
message("Attrition logged: ", nrow(attrition), " steps")
```

### Aggregate Visit Counts Per Patient
```r
# Source: dplyr documentation + Epidemiologist R Handbook
library(dplyr)

# Non-acute care encounters
outcome_nonacute <- encounters %>%
  filter(enc_type %in% c("AV", "TH")) %>%
  group_by(id) %>%
  summarize(
    n_Enc_nonacute_care = n(),
    enc_nonacute_ind = 1L,
    .groups = "drop"
  )

# Cancer-related visits (non-acute + reportable cancer diagnosis)
outcome_cancer <- encounters %>%
  filter(enc_type %in% c("AV", "TH"), any_reportable_cancer == 1) %>%
  group_by(id) %>%
  summarize(
    n_Cancer_related_visit = n(),
    cancer_related_ind = 1L,
    .groups = "drop"
  )

# Survivorship visits (non-acute + cancer provider + ICD Z85/V10)
outcome_survivorship <- encounters %>%
  filter(
    enc_type %in% c("AV", "TH"),
    cancer_provider == 1,  # From provider specialty
    str_detect(dx, "^Z85|^V10")  # Personal history of cancer codes
  ) %>%
  group_by(id) %>%
  summarize(
    n_Survivorship_visit = n(),
    Survivorship_visit_ind = 1L,
    .groups = "drop"
  )

# Merge outcomes to cohort with left_join (keep all patients, fill zeros)
analytical <- cohort %>%
  left_join(outcome_nonacute, by = "id") %>%
  left_join(outcome_cancer, by = "id") %>%
  left_join(outcome_survivorship, by = "id") %>%
  mutate(across(starts_with("n_"), ~replace_na(.x, 0)),
         across(ends_with("_ind"), ~replace_na(.x, 0L)))

message("Analytical dataset with outcomes: ", nrow(analytical), " patients")
```

### Person-Time Calculation with Censoring
```r
# Source: lubridate documentation + censoring guidelines (NIH PMC6248498)
library(lubridate)
library(dplyr)

# Calculate person-time with multiple censoring rules
analytical <- analytical %>%
  mutate(
    # Censoring date: earliest of death, enrollment end, or study end
    censor_date = pmin(
      if_else(deceased == "Y" & !is.na(death_date), death_date, as.Date("2025-12-31")),
      enr_end_date,
      as.Date("2025-12-31"),  # Study administrative censoring
      na.rm = TRUE
    ),
    # Person-time in days from first cancer diagnosis to censoring
    person_time_days = as.numeric(difftime(censor_date, first_admit_date, units = "days")),
    # Log-transformed for Poisson/NB offset
    log_person_time_days = log(person_time_days)
  ) %>%
  # Data quality checks
  verify(person_time_days >= 0, error_fun = warn_report) %>%
  verify(person_time_days > 0, error_fun = warn_report) %>%  # Zero person-time is edge case
  verify(!is.infinite(log_person_time_days), error_fun = warn_report)

# Log summary statistics
message("Person-time summary:")
message("  Min: ", min(analytical$person_time_days, na.rm = TRUE), " days")
message("  Median: ", median(analytical$person_time_days, na.rm = TRUE), " days")
message("  Max: ", max(analytical$person_time_days, na.rm = TRUE), " days")
message("  Total: ", sum(analytical$person_time_days, na.rm = TRUE), " person-days")
```

### Custom CONSORT Flowchart
```r
# Source: Custom ggplot2 approach (RPubs phiggins/461686)
library(ggplot2)
library(dplyr)

# Read attrition tibble from 03_cohort.R
attrition <- readRDS(file.path(data_dir_processed, "03_cohort_attrition.rds"))

# Define box positions for flowchart
consort_boxes <- tibble(
  box_id = 1:nrow(attrition),
  x = 0.5,  # Centered horizontally
  y = seq(nrow(attrition), 1, by = -1),  # Top to bottom
  label = paste0(attrition$description, "\nn = ", format(attrition$n_patients, big.mark = ",")),
  excluded = if_else(is.na(attrition$n_excluded), "",
                     paste0("Excluded: ", format(attrition$n_excluded, big.mark = ",")))
)

# Create CONSORT diagram
consort_plot <- ggplot() +
  # Draw boxes
  geom_rect(data = consort_boxes,
            aes(xmin = x - 0.35, xmax = x + 0.35,
                ymin = y - 0.25, ymax = y + 0.25),
            fill = "#E8F4F8", color = "black", linewidth = 0.5) +
  # Box labels (step description + patient count)
  geom_text(data = consort_boxes,
            aes(x = x, y = y, label = label),
            size = 3.5, fontface = "bold") +
  # Arrows between consecutive boxes
  geom_segment(data = consort_boxes %>% filter(box_id < max(box_id)),
               aes(x = x, xend = x, y = y - 0.25, yend = y - 0.75),
               arrow = arrow(length = unit(0.3, "cm"), type = "closed"),
               linewidth = 0.8) +
  # Exclusion annotations (right side in red)
  geom_text(data = consort_boxes %>% filter(excluded != ""),
            aes(x = x + 0.55, y = y, label = excluded),
            size = 3, hjust = 0, color = "#D32F2F") +
  # Styling
  theme_void() +
  coord_cartesian(xlim = c(0, 1.5), ylim = c(0.5, nrow(attrition) + 0.5)) +
  labs(title = "CONSORT Flowchart: Cohort Construction",
       subtitle = paste0("Final cohort: n = ", format(tail(attrition$n_patients, 1), big.mark = ","))) +
  theme(plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
        plot.subtitle = element_text(hjust = 0.5, size = 12))

# Save in PNG and PDF formats per D-04
ggsave(file.path(output_dir_figures, "consort_flowchart.png"),
       consort_plot, width = 8, height = 10, dpi = 300)
ggsave(file.path(output_dir_figures, "consort_flowchart.pdf"),
       consort_plot, width = 8, height = 10)
message("CONSORT flowchart saved: PNG and PDF")
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| tableone package for Table 1 | gtsummary package | ~2020 | gtsummary offers better tidyverse integration, pipe-friendly syntax, more flexible formatting. tableone still works but less actively maintained. |
| Manual attrition counting with print statements | Attrition tibble + CONSORT packages (consort, ggconsort, flowchart) | ~2018-2022 | Structured attrition tracking enables automated CONSORT diagram generation. Phase 3 uses manual ggplot2 per D-03, but tibble structure aligns with modern tools. |
| mice 2.x (pre-2015) | mice 3.x (2015+) | 2015 | mice 3.0+ uses fully conditional specification (FCS) by default instead of joint modeling. More flexible for mixed data types. Current version 3.16.0. |
| Base R date arithmetic with POSIXct | lubridate package | ~2011 | lubridate simplifies date/interval operations. Base R difftime() still works but more verbose and error-prone (time zones, daylight saving). |
| SQL-style cohort construction in dbplyr | dplyr in-memory with attrition tracking | ~2020+ | For moderate-sized datasets (<1M patients), in-memory dplyr is simpler and allows easier attrition logging. dbplyr preferred for large databases. |

**Deprecated/outdated:**
- **tableone package:** Not deprecated but superseded by gtsummary for most use cases. Still used in older clinical research codebases.
- **mice 2.x joint modeling:** Replaced by FCS in mice 3.0+. Old code using `mice.impute.norm()` needs updating to `mice.impute.pmm()` or other FCS methods.

## Environment Availability

**Skip condition not met:** Phase 3 depends on R runtime for data processing.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| R | All Phase 3 scripts | ✗ | — | BLOCKING: Cannot execute R scripts without R runtime |
| Rscript | Command-line execution | ✗ | — | BLOCKING: run_all.R requires Rscript |
| tidyverse packages | Data manipulation | Unknown (requires R) | — | BLOCKING: Core dependencies |
| mice package | MI dataset prep | Unknown (requires R) | — | Skip MI dataset; produce complete-case only |

**Missing dependencies with no fallback:**
- R runtime (version 4.0+) — BLOCKING for all Phase 3 execution
- Rscript — BLOCKING for pipeline automation

**Missing dependencies with fallback:**
- mice package — Can skip MI-ready dataset preparation if mice not installed. Produce only complete-case analytical dataset. Phase 4 analyses would run on complete-case data only (reduces statistical power but allows phase completion).

**Note for planner:** Code must be written to run when R environment is available. Include installation instructions for mice package in Phase 3 Wave 0. If R is unavailable during development, structure code as "executable specification" with clear logic comments for later validation.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | testthat 3.2.1 (established in Phase 2) |
| Config file | tests/testthat.R (exists from Phase 2) |
| Quick run command | `Rscript -e "testthat::test_dir('tests/testthat', filter = 'phase3', stop_on_failure = TRUE)"` |
| Full suite command | `Rscript -e "testthat::test_dir('tests/testthat', stop_on_failure = TRUE)"` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| COH-01 | valid_id filter matches expected patient count | unit | `Rscript -e "testthat::test_file('tests/testthat/test_03_cohort.R')" -x` | ❌ Wave 0 |
| COH-02 | Reportable cancer identification from icd_groups | unit | `Rscript -e "testthat::test_file('tests/testthat/test_03_cohort.R')" -x` | ❌ Wave 0 |
| COH-03 | Attrition tibble logs all exclusion steps | unit | `Rscript -e "testthat::test_file('tests/testthat/test_03_cohort.R')" -x` | ❌ Wave 0 |
| COH-04 | CONSORT flowchart saves PNG + PDF | integration | `Rscript -e "testthat::test_file('tests/testthat/test_03_cohort.R')" -x` | ❌ Wave 0 |
| COH-05 | First cancer diagnosis date (slice_min pattern) | unit | `Rscript -e "testthat::test_file('tests/testthat/test_03_cohort.R')" -x` | ❌ Wave 0 |
| EXP-01 | pct_change_ins calculation handles edge cases | unit | `Rscript -e "testthat::test_file('tests/testthat/test_03_exposure.R')" -x` | ❌ Wave 0 |
| EXP-02 | Treatment intensity derivation from multi-source | unit | `Rscript -e "testthat::test_file('tests/testthat/test_03_exposure.R')" -x` | ❌ Wave 0 |
| EXP-03 | Cancer site groups map correctly | unit | `Rscript -e "testthat::test_file('tests/testthat/test_03_exposure.R')" -x` | ❌ Wave 0 |
| EXP-04 | Chemotherapy identification from NDC + procedure | unit | `Rscript -e "testthat::test_file('tests/testthat/test_03_exposure.R')" -x` | ❌ Wave 0 |
| OUT-01 | Non-acute care encounter count aggregation | unit | `Rscript -e "testthat::test_file('tests/testthat/test_03_outcomes.R')" -x` | ❌ Wave 0 |
| OUT-02 | Cancer-related visit flag logic | unit | `Rscript -e "testthat::test_file('tests/testthat/test_03_outcomes.R')" -x` | ❌ Wave 0 |
| OUT-03 | Cancer visit + provider join correctness | unit | `Rscript -e "testthat::test_file('tests/testthat/test_03_outcomes.R')" -x` | ❌ Wave 0 |
| OUT-04 | Survivorship visit restrictive definition | unit | `Rscript -e "testthat::test_file('tests/testthat/test_03_outcomes.R')" -x` | ❌ Wave 0 |
| OUT-05 | Person-time calculation with censoring rules | unit | `Rscript -e "testthat::test_file('tests/testthat/test_03_outcomes.R')" -x` | ❌ Wave 0 |
| OUT-06 | Visit count aggregation (left_join + replace_na) | unit | `Rscript -e "testthat::test_file('tests/testthat/test_03_outcomes.R')" -x` | ❌ Wave 0 |
| COV-01 | Demographics factor recoding with sas_formats | unit | `Rscript -e "testthat::test_file('tests/testthat/test_03_covariates.R')" -x` | ❌ Wave 0 |
| COV-02 | Age categories (cut with correct breaks) | unit | `Rscript -e "testthat::test_file('tests/testthat/test_03_covariates.R')" -x` | ❌ Wave 0 |
| COV-03 | SDI tertile categorization | unit | `Rscript -e "testthat::test_file('tests/testthat/test_03_covariates.R')" -x` | ❌ Wave 0 |
| COV-04 | RUCA classification factor levels | unit | `Rscript -e "testthat::test_file('tests/testthat/test_03_covariates.R')" -x` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `Rscript -e "testthat::test_dir('tests/testthat', filter = 'phase3_quick', stop_on_failure = TRUE)"` — runs fast unit tests only (<10s)
- **Per wave merge:** `Rscript -e "testthat::test_dir('tests/testthat', filter = 'phase3', stop_on_failure = TRUE)"` — full Phase 3 test suite including CONSORT generation
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/testthat/test_03_cohort.R` — covers COH-01 through COH-05 (sequential exclusion, attrition logging, CONSORT generation, first cancer diagnosis)
- [ ] `tests/testthat/test_03_exposure.R` — covers EXP-01 through EXP-04 (pct_change_ins, treatment intensity, cancer site, chemo identification)
- [ ] `tests/testthat/test_03_outcomes.R` — covers OUT-01 through OUT-06 (visit count aggregation, person-time calculation)
- [ ] `tests/testthat/test_03_covariates.R` — covers COV-01 through COV-04 (demographics, age categories, SDI, RUCA recoding)
- [ ] `tests/testthat/helper-phase3-fixtures.R` — mock cohort data with known counts for testing attrition logic

**Test data strategy:** Use simplified mock cohort (10-20 patients) with known exclusion counts, known first cancer dates, known visit types, and known person-time values. Verify aggregate functions produce expected counts. CONSORT flowchart test verifies file creation (PNG + PDF exist) but not visual layout.

## Sources

### Primary (HIGH confidence)
- [dplyr Official Documentation](https://dplyr.tidyverse.org/) — group_by/summarize patterns for encounter aggregation
- [lubridate Official Documentation](https://lubridate.tidyverse.org/) — date arithmetic and interval calculation
- [mice Package Official Site](https://amices.org/mice/) — multiple imputation methodology
- [assertr Official Documentation](https://docs.ropensci.org/assertr/) — data validation patterns
- [ggplot2 Official Documentation](https://ggplot2.tidyverse.org/) — custom graphics for CONSORT

### Secondary (MEDIUM confidence)
- [Working with Dates and Times in R Using the lubridate Package | UVA Library](https://library.virginia.edu/data/articles/working-with-dates-and-time-in-r-using-the-lubridate-package) — person-time calculation examples
- [When to Censor? - PMC NIH](https://pmc.ncbi.nlm.nih.gov/articles/PMC6248498/) — censoring guidelines for clinical cohorts
- [Grouping data – The Epidemiologist R Handbook](https://www.epirhandbook.com/en/new_pages/grouping.html) — clinical data aggregation patterns
- [Getting Started with Multiple Imputation in R | UVA Library](https://library.virginia.edu/data/articles/getting-started-with-multiple-imputation-in-r) — mice workflow
- [RPubs - CONSORT diagram in ggplot2](https://rpubs.com/phiggins/461686) — custom CONSORT flowchart examples
- [2026 ICD-10-CM Codes C00-D49: Neoplasms](https://www.icd10data.com/ICD10CM/Codes/C00-D49) — cancer diagnosis codes
- [SEER Casefinding List](https://seer.cancer.gov/tools/casefinding/) — reportable cancer definitions

### Tertiary (LOW confidence)
- [CDMConnector cohort building vignette](https://cran.r-project.org/web/packages/CDMConnector/vignettes/a02_cohorts.html) — OHDSI approach (different CDM but similar patterns)
- [visR get_attrition function](https://openpharma.github.io/visR/reference/get_attrition.html) — attrition table structure reference

## Metadata

**Confidence breakdown:**
- Standard stack (dplyr, tidyr, lubridate, mice): HIGH — Verified via CRAN, extensive clinical research usage, official documentation complete
- Architecture patterns (group_by/summarize, person-time calculation, CONSORT flowchart): HIGH — Multiple verified sources (UVA Library, Epidemiologist R Handbook, RPubs examples), standard clinical research patterns
- Pitfalls (date arithmetic, left_join for outcomes, slice_min sorting, division by zero, mice scope): HIGH — Identified from dplyr documentation warnings, clinical research best practices, and SAS-to-R conversion guides
- SAS V5 cohort logic: MEDIUM — Sample files reviewed but full cohort construction logic requires forensic analysis of multiple V5 files during implementation
- Environment availability: LOW — R not detected on system; actual installation status unknown

**Research date:** 2026-04-16
**Valid until:** 60 days (stack stability: tidyverse packages update 2-4x/year with backward compatibility; mice stable since 3.0 release in 2015)
