# Phase 2: Data Cleaning & Merging - Research

**Researched:** 2026-04-16
**Domain:** SAS-to-R data pipeline translation, clinical data merging (PCORnet CDM)
**Confidence:** HIGH (core merging), MEDIUM (encounter deduplication)

## Summary

Phase 2 translates SAS DATA step cleaning and MERGE operations to tidyverse dplyr joins for encounter-level PCORnet CDM data. The critical challenge: **SAS MERGE and dplyr joins have fundamentally different semantics**, especially for many-to-many relationships and missing value handling.

**Key discovery from forensics:** Encounter files (`encounter1_mobley_v5.sas7bdat`, `encounter2_mobley_v5.sas7bdat`) were missed in Phase 1 import. Phase 2 must import them first using the established `import_sas()` helper, then combine via `bind_rows()` before any cleaning or merging.

**Primary recommendation:** Use dplyr's `relationship` argument (introduced dplyr 1.1.0+) to enforce join cardinality explicitly. Validate row counts after every join using `message()` logging. Apply `janitor::clean_names()` only once (at import time) per Phase 1 pattern. Use `assertr` for data quality checks, not inline validation that clutters cleaning code.

## User Constraints (from CONTEXT.md)

### Locked Decisions (from Phase 1)
- **D-02:** Format duplicate resolution uses SAS overwrite semantics (Block 4 / later definition wins) — Phase 2 inherits payer format from Phase 1
- **D-06:** Forensic analysis across all ~122 SAS files to determine correct analytical logic
- **D-07:** SAS errors documented as inline R comments
- **D-08:** .rds checkpoints between pipeline stages
- **D-10:** V5 is primary target
- **Existing pattern:** `janitor::clean_names()` already applied at import time in `01_import.R` (lines 73, IMP-05 notes)
- **Validation pattern:** Warn-and-continue with `message()` logging (matching Phase 1)

### Claude's Discretion
- Script organization: one vs two scripts (02_clean.R vs 02_clean.R + 02_merge.R)
- Payer grouping implementation: follow SAS exactly, document issues but don't fix
- Dual Medicare/Medicaid detection: cross-reference PCORnet CDM payer type codes, fix only if clearly wrong

### Deferred Ideas (OUT OF SCOPE)
- None from Phase 1
- New: Advanced encounter deduplication (N3C/RECOVER "macrovisit" methods) — beyond scope for initial translation, note as future enhancement

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CLN-01 | Variable name standardization (janitor::clean_names) | **Already complete** — Phase 1 applies at import time (01_import.R lines 73) |
| CLN-02 | Encounter datasets combined into single dataset | `bind_rows()` after importing encounter1/encounter2 (SAS pattern: HL_IDS_1_9_2025.sas lines 73-74) |
| CLN-03 | Insurance payer type codes recoded to grouped categories | Use Phase 1 `sas_formats$p_payer` with `factor()` or `case_when()` |
| CLN-04 | Missing values handled explicitly with is.na() | SAS missing = -Inf semantics; R uses NA propagation — document all comparisons |
| CLN-05 | Encounter type, discharge status, discharge disposition recoded | Use Phase 1 `sas_formats$enc_type`, `sas_formats$discharge_status`, `sas_formats$discharge_disposition` |
| CLN-06 | Primary and secondary payer types derived with correct grouping logic | Cross-reference SAS code for `PAYER_TYPE_PRIMARY` / `PAYER_TYPE_SECONDARY` derivation against `sas_formats$payer` taxonomy |
| MRG-01 | Encounters merge correctly with diagnoses, procedures, provider data | PCORnet CDM join keys: `PATID` + `ENCOUNTERID` (primary), verified via PCORnet CDM v7.0 spec |
| MRG-02 | Row counts validated after every merge operation | `message()` logging pattern from Phase 1: before/after row counts, join type, keys used |
| MRG-03 | Many-to-many merge relationships identified and handled | dplyr `relationship` argument (1.1.0+) enforces cardinality; SAS MERGE is max(m,n), SQL/dplyr is m*n |
| MRG-04 | Data quality assertions verify key variables after merges | `assertr::verify()` / `assertr::assert()` for post-merge checks (missing values, range violations) |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| **dplyr** | 1.2.1+ | Data manipulation (filter, mutate, join) | De facto standard for data wrangling. `relationship` argument (1.1.0+) critical for enforcing join cardinality. |
| **tidyr** | 1.3.2 | Data reshaping (pivot, separate, unite) | Needed if encounter-level to patient-level aggregation required. |
| **janitor** | 2.2.1 | Column name standardization, duplicate detection, crosstabs | `clean_names()` already applied at import (Phase 1). Use `get_dupes()` for encounter deduplication, `tabyl()` for payer frequency checks. |
| **assertr** | 0.9+ | Data quality assertions (verify, assert, insist) | Enforces data quality contracts. Use post-merge checks for unexpected NAs, out-of-range values. More powerful than inline `stopifnot()`. |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **stringr** | 1.6.0 | String manipulation | Payer name recoding if raw strings need parsing. Already in tidyverse. |
| **forcats** | 1.0.1 | Factor level management | Reorder/collapse payer types, encounter types after recoding. Already in tidyverse. |
| **lubridate** | 1.9.5 | Date manipulation | Calculate date-based merge keys, encounter duration. Already in tidyverse. |

### Installation
```bash
# Core tidyverse (includes dplyr, tidyr, stringr, forcats, lubridate)
install.packages("tidyverse")

# Data cleaning and validation
install.packages("janitor")
install.packages("assertr")
```

**Version verification:** As of 2026-04-16, verified via CRAN:
- dplyr 1.2.1 (March 2025 release) — `relationship` argument available
- janitor 2.2.1 (March 2026 release) — active maintenance
- assertr 0.9 (stable release) — mature package, no breaking changes expected

## Architecture Patterns

### Recommended Script Structure
```
R/
├── config.R              # Already exists (Phase 1)
├── 01_formats.R          # Already exists (Phase 1)
├── 01_import.R           # Already exists (Phase 1)
├── 02_clean.R            # NEW: Encounter import, cleaning, recoding
├── 02_merge.R            # NEW (optional): Merge encounters with dx/proc/provider
└── run_all.R             # Update with Phase 2 scripts
```

**Single vs two scripts:** Phase 2 can use one script (`02_clean_merge.R`) if merge logic is straightforward. Split into two (`02_clean.R` + `02_merge.R`) if merges are complex or need intermediate validation. Recommend **two scripts** for this project based on:
1. Encounter import/cleaning is distinct from multi-table merging
2. Intermediate .rds checkpoint between cleaning and merging aids debugging
3. SAS code structure suggests separate cleaning (V5_2) and merging (V5_3+) steps

### Pattern 1: Encounter Import and Combination (CLN-02)
**What:** Import missed encounter files, combine into single dataset.
**When to use:** At start of Phase 2, before any cleaning.
**Example:**
```r
# Source: HL_IDS_1_9_2025.sas lines 73-74
# SAS pattern: data encounters; set v3.encounter1_mobley_v5 v3.encounter2_mobley_v5; run;

# Import encounter files (missed in Phase 1)
encounter1 <- import_sas("encounter1_mobley_v5.sas7bdat",
                          description = "Encounter part 1 of 2")
encounter2 <- import_sas("encounter2_mobley_v5.sas7bdat",
                          description = "Encounter part 2 of 2")

# Combine (dplyr equivalent to SAS SET statement)
encounters <- bind_rows(encounter1, encounter2)

# Validate row count
message("Encounter rows: ", format(nrow(encounters), big.mark = ","),
        " (", format(nrow(encounter1), big.mark = ","), " + ",
        format(nrow(encounter2), big.mark = ","), ")")

# Save checkpoint
saveRDS(encounters, file.path(data_dir_processed, "02_encounters_combined.rds"))
```

**Critical note:** `janitor::clean_names()` is **already applied** in Phase 1 `import_sas()` helper. Do NOT reapply in Phase 2 or column names will double-transform.

### Pattern 2: Payer Type Recoding (CLN-03, CLN-06)
**What:** Recode raw PCORnet payer codes to grouped analysis categories.
**When to use:** After encounter/enrollment data loaded, before merging.
**Example:**
```r
# Source: 01_formats.R lines 695-700 ($p_payer format)
# SAS pattern: format PAYER_TYPE_PRIMARY $p.;

# Load format from Phase 1
sas_formats <- readRDS(file.path(data_dir_processed, "01_formats.rds"))

# Apply payer grouping (CLN-03)
# Option 1: Use factor() with format definition
encounters <- encounters %>%
  mutate(
    payer_primary_grouped = factor(
      payer_type_primary,
      levels = sas_formats$p_payer$levels,
      labels = sas_formats$p_payer$labels
    )
  )

# Option 2: Use case_when() for explicit logic (more auditable)
encounters <- encounters %>%
  mutate(
    payer_primary_grouped = case_when(
      substr(payer_type_primary, 1, 1) == "5" ~ "Private",
      substr(payer_type_primary, 1, 1) == "1" ~ "Medicare",
      substr(payer_type_primary, 1, 1) == "2" ~ "Medicaid",
      substr(payer_type_primary, 1, 1) == "3" ~ "Private",  # Government -> Private per format
      payer_type_primary == "4" ~ "Med_Medicaid",           # Dual eligibility
      substr(payer_type_primary, 1, 1) == "8" ~ "Uninsured",
      substr(payer_type_primary, 1, 1) == "9" ~ "Other",
      is.na(payer_type_primary) | payer_type_primary %in% c("NI", "UN", "OT") ~ "Unknown",
      TRUE ~ "Unknown"
    )
  )

# Validate recoding (CLN-03 verification)
message("Payer primary grouped distribution:")
print(janitor::tabyl(encounters, payer_primary_grouped))

# SAS BUG CHECK: Dual Medicare/Medicaid detection (CLN-06)
# SAS format line 519: "14=Dual Eligibility Medicare/Medicaid Organization"
# Verify payer_type_primary == "4" or "14" maps correctly
dual_check <- encounters %>%
  filter(payer_type_primary %in% c("4", "14")) %>%
  count(payer_type_primary, payer_primary_grouped)
message("Dual eligibility mapping check:")
print(dual_check)
# Expected: both "4" and "14" -> "Med_Medicaid"
```

**SAS vs R gotcha:** SAS formats apply automatically via `format` statement. R requires explicit `factor()` or `case_when()`. Recommend `case_when()` for transparency in forensic audit.

### Pattern 3: Encounter Type Recoding (CLN-05)
**What:** Apply PCORnet CDM standard formats to categorical variables.
**When to use:** After encounters loaded, before outcome derivation.
**Example:**
```r
# Source: 01_formats.R lines 138-145 ($ENC_TYPE format)
# SAS pattern: format ENC_TYPE $ENC_TYPE.;

encounters <- encounters %>%
  mutate(
    enc_type_label = factor(
      enc_type,
      levels = sas_formats$enc_type$levels,
      labels = sas_formats$enc_type$labels
    ),
    discharge_status_label = factor(
      discharge_status,
      levels = sas_formats$discharge_status$levels,
      labels = sas_formats$discharge_status$labels
    ),
    discharge_disposition_label = factor(
      discharge_disposition,
      levels = sas_formats$discharge_disposition$levels,
      labels = sas_formats$discharge_disposition$labels
    )
  )

# Validate levels (check for unlabeled codes)
unlabeled_enc_type <- encounters %>%
  filter(is.na(enc_type_label) & !is.na(enc_type)) %>%
  count(enc_type, name = "n_unlabeled")

if (nrow(unlabeled_enc_type) > 0) {
  message("WARNING: Unlabeled ENC_TYPE codes found:")
  print(unlabeled_enc_type)
}
```

### Pattern 4: Explicit Missing Value Handling (CLN-04)
**What:** Replace SAS-style implicit missing comparisons with explicit `is.na()`.
**When to use:** Any conditional logic involving potentially missing values.
**Example:**
```r
# SAS pattern: if PAYER_TYPE_PRIMARY = ' ' then delete;
# SAS BUG: Missing values treated as -Inf in numeric comparisons
#          SAS: if AGE < 18 includes missing ages (missing < 18 is TRUE)
#          R:   if AGE < 18 excludes missing ages (NA < 18 is NA, filtered out)

# WRONG (SAS semantics don't translate):
encounters <- encounters %>%
  filter(age >= 18)  # Silently drops NA ages

# CORRECT (explicit NA handling):
encounters <- encounters %>%
  filter(age >= 18 | is.na(age))  # Keep NA ages if study design requires
# OR
encounters <- encounters %>%
  filter(!is.na(age) & age >= 18)  # Drop NA ages explicitly

# Document decision:
# SAS BUG FIX: SAS missing values treated as -Inf in comparisons.
# R uses NA propagation. Explicit is.na() check required for correct filtering.
```

**Critical pitfall:** SAS `WHERE age < 18` includes missing ages. R `filter(age < 18)` excludes them. Always document the intended behavior.

### Pattern 5: PCORnet CDM Join Keys (MRG-01)
**What:** Merge encounters with diagnosis, procedures, provider using correct keys.
**When to use:** After encounter cleaning complete.
**Example:**
```r
# Source: PCORnet CDM v7.0 spec (2025-01-23)
# "ENCOUNTERID, PROVIDERID, ENCOUNTER_TYPE, and ADMIT_DATE from the
#  associated ENCOUNTER record should be included [in DIAGNOSIS/PROCEDURES]"
# Primary join key: ENCOUNTERID
# Additional keys for validation: PATID (every encounter belongs to one patient)

# Load cleaned encounters and diagnoses
encounters <- readRDS(file.path(data_dir_processed, "02_encounters_cleaned.rds"))
dx_combined <- readRDS(file.path(data_dir_processed, "01_imported_dx_parts.rds")) %>%
  bind_rows()

# Validate join key uniqueness BEFORE merging (MRG-03)
encounter_key_check <- encounters %>%
  janitor::get_dupes(encounterid)

if (nrow(encounter_key_check) > 0) {
  message("WARNING: Non-unique ENCOUNTERID in encounters table:")
  message("  Duplicate rows: ", nrow(encounter_key_check))
  message("  Affected encounters: ", n_distinct(encounter_key_check$encounterid))
  # Decision: Keep first occurrence or investigate duplicates?
}

# Pre-merge row counts (MRG-02)
n_enc_before <- nrow(encounters)
n_dx_before <- nrow(dx_combined)
message("Pre-merge: encounters = ", format(n_enc_before, big.mark = ","),
        ", dx = ", format(n_dx_before, big.mark = ","))

# Perform left join (keep all encounters, add dx info)
# Use relationship argument to enforce cardinality (MRG-03)
enc_with_dx <- encounters %>%
  left_join(
    dx_combined,
    by = c("patid", "encounterid"),
    relationship = "one-to-many"  # One encounter can have many diagnoses
  )

# Post-merge row count validation (MRG-02)
n_after <- nrow(enc_with_dx)
message("Post-merge: ", format(n_after, big.mark = ","), " rows")
message("  Expected: ", n_enc_before, " (encounters) * avg diagnoses per encounter")
message("  Growth factor: ", round(n_after / n_enc_before, 2), "x")

# Check for unexpected Cartesian product (MRG-03)
if (n_after > n_enc_before * 20) {
  warning("MERGE WARNING: Row count grew by >20x. Possible Cartesian product.")
  warning("  Check for duplicate join keys or incorrect relationship specification.")
}

# Data quality assertions (MRG-04)
enc_with_dx %>%
  assertr::verify(
    n_distinct(patid) == n_distinct(encounters$patid),
    description = "Patient count preserved after merge"
  ) %>%
  assertr::assert(
    assertr::not_na, encounterid,
    description = "No missing ENCOUNTERIDs after merge"
  )

# Save checkpoint
saveRDS(enc_with_dx, file.path(data_dir_processed, "02_encounters_with_dx.rds"))
```

**SAS vs dplyr join semantics (CRITICAL):**
- **SAS MERGE (many-to-many):** Produces `max(m, n)` rows — walks through both datasets sequentially, keeps last match from shorter dataset
- **SQL/dplyr join (many-to-many):** Produces `m * n` rows — Cartesian product of all matching combinations
- **Fix:** Use `relationship` argument to detect and error on unintended many-to-many joins

### Pattern 6: Row Count Validation Logging (MRG-02)
**What:** Log before/after row counts for every merge operation.
**When to use:** Wrap every join operation.
**Example:**
```r
# Helper function for logged joins
logged_join <- function(x, y, by, type = "left", relationship = NULL, desc = "") {
  n_x <- nrow(x)
  n_y <- nrow(y)
  message("\n=== Join: ", desc, " ===")
  message("  Type: ", type, "_join")
  message("  Keys: ", paste(by, collapse = ", "))
  message("  Left rows: ", format(n_x, big.mark = ","))
  message("  Right rows: ", format(n_y, big.mark = ","))

  result <- switch(type,
    "left" = left_join(x, y, by = by, relationship = relationship),
    "inner" = inner_join(x, y, by = by, relationship = relationship),
    "right" = right_join(x, y, by = by, relationship = relationship),
    "full" = full_join(x, y, by = by, relationship = relationship)
  )

  n_result <- nrow(result)
  message("  Result rows: ", format(n_result, big.mark = ","))
  message("  Growth: ", round(n_result / n_x, 2), "x")

  return(result)
}

# Usage
enc_with_dx <- logged_join(
  encounters, dx_combined,
  by = c("patid", "encounterid"),
  type = "left",
  relationship = "one-to-many",
  desc = "Encounters + Diagnoses"
)
```

### Pattern 7: Data Quality Assertions (MRG-04)
**What:** Post-merge checks for unexpected missing values, range violations.
**When to use:** After every merge, before saving checkpoint.
**Example:**
```r
# Source: assertr package documentation
# Use verify() for logical conditions, assert() for column-level checks

enc_with_dx %>%
  # Check: All encounters should have at least one diagnosis
  assertr::verify(
    nrow(filter(., is.na(dx))) / nrow(.) < 0.05,
    description = "< 5% encounters missing diagnosis"
  ) %>%
  # Check: ADMIT_DATE should be present for inpatient encounters
  assertr::insist(
    assertr::within_bounds(as.Date("2000-01-01"), Sys.Date()),
    admit_date,
    description = "ADMIT_DATE within plausible range"
  ) %>%
  # Check: ENC_TYPE should only contain valid codes
  assertr::assert(
    assertr::in_set(sas_formats$enc_type$levels),
    enc_type,
    description = "ENC_TYPE uses valid PCORnet codes"
  )

# If assertion fails, pipeline halts with descriptive error
# Alternative: Use success/error handlers for warn-and-continue
enc_with_dx %>%
  assertr::assert(
    assertr::not_na, payer_type_primary,
    success_fun = assertr::success_continue,
    error_fun = assertr::error_report
  )
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Column name standardization | Custom regex for camelCase/snake_case conversion | `janitor::clean_names()` | Handles dozens of edge cases (spaces, special chars, Unicode, duplicate names). Already applied in Phase 1. |
| Duplicate record detection | Manual `group_by()` + `filter(n() > 1)` | `janitor::get_dupes()` | Returns duplicates with count column, handles multiple key columns, cleaner output. |
| Frequency tables with totals | Base `table()` + manual totals | `janitor::tabyl()` | Adds row/column totals, percentages, works with dplyr pipes, cleaner output. |
| Join cardinality enforcement | Manual row count checks + warnings | dplyr `relationship` argument | Built-in error on unexpected many-to-many, enforces "one-to-one", "one-to-many", "many-to-one" contracts. |
| Data validation pipelines | Scattered `stopifnot()` calls | `assertr::verify()` / `assert()` | Descriptive errors, pipeline integration, success/error handlers, better debugging. |
| PCORnet payer code lookup | Custom case_when() with hardcoded codes | Use Phase 1 `sas_formats$payer` list | Centralized format definitions, already translated from Formats.sas, matches SAS overwrite semantics. |

**Key insight:** PCORnet CDM has 170+ payer codes (lines 495-580 in 01_formats.R). Hand-rolling this as `case_when()` is error-prone and unmaintainable. Use the centralized format list.

## Runtime State Inventory

> Not applicable — Phase 2 is data transformation only, no external state.

## Common Pitfalls

### Pitfall 1: SAS MERGE vs dplyr Join Semantics (Many-to-Many)
**What goes wrong:** SAS MERGE with many-to-many produces `max(m, n)` rows. dplyr join produces `m * n` rows (Cartesian product). Result: Unexplained row explosion, memory errors.

**Why it happens:** Fundamental semantic difference. SAS walks through both datasets sequentially; SQL/dplyr creates all matching combinations.

**How to avoid:**
1. Use `relationship` argument on every join: `left_join(..., relationship = "one-to-many")`
2. Validate join key uniqueness BEFORE merging with `janitor::get_dupes()`
3. Log row counts before/after (Pattern 6)

**Warning signs:**
- Row count grows by >10x after join
- Memory usage spikes
- Warning: "Detected an unexpected many-to-many relationship"

**Example:**
```r
# BAD: Silent Cartesian product
enc_with_dx <- left_join(encounters, dx, by = "encounterid")
# If dx has duplicate encounterid, row count explodes

# GOOD: Explicit relationship enforcement
enc_with_dx <- left_join(
  encounters, dx,
  by = "encounterid",
  relationship = "one-to-many"  # Error if dx has dupe encounterid
)
```

### Pitfall 2: SAS Missing Value Comparison Semantics
**What goes wrong:** SAS treats missing as `-Inf` in comparisons. R treats missing as `NA`, which propagates. Result: Filters that work in SAS silently drop rows in R.

**Why it happens:** Different missing value philosophies. SAS: "missing is less than everything". R: "missing is unknown, propagates to any operation".

**How to avoid:**
1. Wrap every conditional with explicit `is.na()` check
2. Document SAS behavior in comments: `# SAS BUG FIX: Missing treated as -Inf`
3. Validate row counts after filters against SAS output

**Warning signs:**
- Fewer rows than SAS output after filtering
- Missing values disappear from filtered dataset

**Example:**
```r
# SAS code: if AGE < 18 then group = 'pediatric';
# SAS behavior: Missing ages are < 18, included in 'pediatric'

# WRONG R translation:
encounters <- encounters %>%
  mutate(group = if_else(age < 18, "pediatric", "adult"))
# Missing ages become NA, not "pediatric"

# CORRECT R translation:
encounters <- encounters %>%
  mutate(
    group = case_when(
      is.na(age) ~ "pediatric",  # Explicit: SAS treats missing as < 18
      age < 18 ~ "pediatric",
      TRUE ~ "adult"
    )
  )
# SAS BUG FIX: SAS missing values treated as -Inf in age comparisons
```

### Pitfall 3: Applying clean_names() Multiple Times
**What goes wrong:** Column names transform twice. `PAYER_TYPE_PRIMARY` becomes `payer_type_primary` (Phase 1), then `payer_type_primary` again (no change) OR triggers error if intermediate transformations applied.

**Why it happens:** Phase 1 `import_sas()` already applies `janitor::clean_names()`. Reapplying is redundant and may cause issues.

**How to avoid:**
1. Read existing R code (01_import.R) to check if standardization already done
2. Never call `clean_names()` in Phase 2
3. Use `names()` to inspect column names early in script

**Warning signs:**
- Column names don't match Phase 1 checkpoint
- Join failures due to key name mismatch

**Example:**
```r
# Phase 1 already did this (01_import.R line 73):
df <- janitor::clean_names(df)

# Phase 2 should NOT repeat:
# encounters <- janitor::clean_names(encounters)  # WRONG

# Instead, load checkpoint directly:
encounters <- readRDS(file.path(data_dir_processed, "02_encounters_combined.rds"))
# Column names already clean from import_sas() helper
```

### Pitfall 4: Undetected Join Key Duplicates
**What goes wrong:** Duplicate `encounterid` values in diagnosis table cause row explosion when joined to encounters. Result: 1M encounters + 5M diagnoses with 10% dupe rate = 15M+ output rows instead of expected 5M.

**Why it happens:** PCORnet CDM allows multiple diagnoses per encounter (expected), but data errors can create duplicate `encounterid` within diagnosis table (unexpected).

**How to avoid:**
1. Run `janitor::get_dupes()` on BOTH tables before join
2. Use dplyr `relationship` argument to error on unexpected cardinality
3. Validate: "Result rows should be ≤ left rows * max right matches per key"

**Warning signs:**
- Row count grows by >20x
- Same encounter appears hundreds of times in output

**Example:**
```r
# Check for duplicates BEFORE join
dx_dupes <- dx_combined %>%
  janitor::get_dupes(patid, encounterid, dx)

if (nrow(dx_dupes) > 0) {
  message("WARNING: Duplicate diagnosis records found:")
  message("  Rows: ", nrow(dx_dupes))
  message("  Affected encounters: ", n_distinct(dx_dupes$encounterid))
  # Decision: Remove exact duplicates or keep for audit?
  dx_combined <- dx_combined %>% distinct()
}

# Enforce cardinality during join
enc_with_dx <- encounters %>%
  left_join(
    dx_combined,
    by = c("patid", "encounterid"),
    relationship = "one-to-many"  # Errors if dx has duplicate patid+encounterid combos
  )
```

### Pitfall 5: Payer Code Grouping Logic Errors
**What goes wrong:** Custom `case_when()` misses edge cases. Example: `PAYER_TYPE_PRIMARY == "14"` (Dual Medicare/Medicaid) not mapped, becomes `NA`.

**Why it happens:** 170+ payer codes in PCORnet CDM. Hand-rolling grouping logic is error-prone.

**How to avoid:**
1. Use Phase 1 `sas_formats$p_payer` as single source of truth
2. Validate ALL input codes have a mapping: `anti_join()` to find unmapped codes
3. Cross-reference SAS format definition (01_formats.R lines 693-700)

**Warning signs:**
- Unexpected `NA` values in grouped payer column
- Row counts don't match SAS PROC FREQ output

**Example:**
```r
# Load format definition
sas_formats <- readRDS(file.path(data_dir_processed, "01_formats.rds"))

# Apply grouping
encounters <- encounters %>%
  mutate(
    payer_grouped = factor(
      payer_type_primary,
      levels = sas_formats$p_payer$levels,
      labels = sas_formats$p_payer$labels
    )
  )

# Validate: Check for unmapped codes
unmapped <- encounters %>%
  filter(is.na(payer_grouped) & !is.na(payer_type_primary)) %>%
  count(payer_type_primary, name = "n_unmapped")

if (nrow(unmapped) > 0) {
  message("WARNING: Unmapped payer codes found:")
  print(unmapped)
  # Update sas_formats$p_payer or document as data error
}
```

### Pitfall 6: Forgetting Intermediate Checkpoints
**What goes wrong:** Merge fails 2 hours into script. No checkpoint saved. Must rerun entire cleaning pipeline from scratch.

**Why it happens:** .rds checkpoints skipped to "save time".

**How to avoid:**
1. Save checkpoint after every major step (encounter import, cleaning, each merge)
2. Follow Phase 1 pattern: `saveRDS(df, file.path(data_dir_processed, "02_stepname.rds"))`
3. run_all.R should support resuming from any checkpoint

**Warning signs:**
- Long script runtime with no intermediate outputs
- Manual reruns after errors

**Example:**
```r
# After each major step:
saveRDS(encounters_combined, file.path(data_dir_processed, "02_encounters_combined.rds"))
saveRDS(encounters_cleaned, file.path(data_dir_processed, "02_encounters_cleaned.rds"))
saveRDS(enc_with_dx, file.path(data_dir_processed, "02_encounters_with_dx.rds"))

# Enable resume in run_all.R:
if (start_step <= 2) {
  source(here("R", "02_clean.R"))
}
if (start_step <= 3) {
  source(here("R", "02_merge.R"))
}
```

## Environment Availability

> Not applicable — Phase 2 uses only R packages (tidyverse, janitor, assertr), no external tools/services.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | testthat 3.3.2 (January 2026) |
| Config file | None — see Wave 0 gap |
| Quick run command | `testthat::test_file("tests/testthat/test_02_cleaning.R")` |
| Full suite command | `testthat::test_dir("tests/testthat")` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CLN-01 | Variable names standardized | unit | `test_file("tests/testthat/test_02_cleaning.R")` | ❌ Wave 0 |
| CLN-02 | Encounters combined correctly | unit | `test_file("tests/testthat/test_02_cleaning.R")` | ❌ Wave 0 |
| CLN-03 | Payer codes recoded to groups | unit | `test_file("tests/testthat/test_02_cleaning.R")` | ❌ Wave 0 |
| CLN-04 | Missing values handled explicitly | unit | `test_file("tests/testthat/test_02_cleaning.R")` | ❌ Wave 0 |
| CLN-05 | Encounter type/discharge recoded | unit | `test_file("tests/testthat/test_02_cleaning.R")` | ❌ Wave 0 |
| CLN-06 | Primary/secondary payer derived | unit | `test_file("tests/testthat/test_02_cleaning.R")` | ❌ Wave 0 |
| MRG-01 | Encounter-dx-proc-provider joins | unit | `test_file("tests/testthat/test_02_merging.R")` | ❌ Wave 0 |
| MRG-02 | Row counts logged after merges | manual | Visual inspection of console output | N/A (logging) |
| MRG-03 | Many-to-many relationships handled | unit | `test_file("tests/testthat/test_02_merging.R")` | ❌ Wave 0 |
| MRG-04 | Data quality assertions verify | unit | `test_file("tests/testthat/test_02_merging.R")` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `testthat::test_file("tests/testthat/test_02_cleaning.R")` (< 30 sec)
- **Per wave merge:** `testthat::test_dir("tests/testthat")` (full suite, all phases)
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/testthat/test_02_cleaning.R` — covers CLN-01 through CLN-06
  - Test: encounter1 + encounter2 row sum equals combined dataset
  - Test: all payer_type_primary codes map to grouped categories
  - Test: missing values handled explicitly (no implicit NA propagation)
  - Test: encounter type/discharge status factor levels match SAS formats
- [ ] `tests/testthat/test_02_merging.R` — covers MRG-01, MRG-03, MRG-04
  - Test: encounter-diagnosis join produces expected row count
  - Test: relationship argument prevents Cartesian product
  - Test: post-merge assertions verify no unexpected NAs
- [ ] `tests/conftest.R` or `tests/testthat/helper-fixtures.R` — shared test fixtures
  - Fixture: mock encounter dataset (10 rows)
  - Fixture: mock diagnosis dataset (30 rows, 3 dx per encounter)
  - Fixture: expected join output (30 rows)
- [ ] Framework install: Already available via tidyverse, no install needed

**Testing approach:** Use testthat's `expect_equal()` for exact row counts, `expect_true()` / `expect_false()` for logical checks, `expect_error()` for assertr violations. Mock data avoids dependency on actual SAS files.

## Code Examples

Verified patterns from official sources and project forensics:

### Encounter Combination (SAS SET equivalent)
```r
# Source: HL_IDS_1_9_2025.sas lines 73-74
# SAS: data encounters; set v3.encounter1_mobley_v5 v3.encounter2_mobley_v5; run;

encounter1 <- import_sas("encounter1_mobley_v5.sas7bdat")
encounter2 <- import_sas("encounter2_mobley_v5.sas7bdat")

encounters <- bind_rows(encounter1, encounter2)
# bind_rows() is exact dplyr equivalent to SAS SET statement
```

### Left Join with Cardinality Enforcement
```r
# Source: dplyr 1.1.0+ documentation (relationship argument)
# PCORnet CDM v7.0: ENCOUNTERID is join key

enc_with_dx <- encounters %>%
  left_join(
    dx_combined,
    by = c("patid", "encounterid"),
    relationship = "one-to-many"  # One encounter, many diagnoses
  )
# Errors if unexpected many-to-many detected
```

### Post-Merge Assertions
```r
# Source: assertr package documentation
# https://docs.ropensci.org/assertr/

enc_with_dx %>%
  assertr::verify(
    n_distinct(patid) == n_distinct(encounters$patid),
    description = "Patient count preserved"
  ) %>%
  assertr::assert(
    assertr::not_na, encounterid,
    description = "No missing ENCOUNTERIDs"
  ) %>%
  assertr::insist(
    assertr::within_bounds(as.Date("2000-01-01"), Sys.Date()),
    admit_date,
    description = "ADMIT_DATE in plausible range"
  )
```

### Duplicate Detection Before Join
```r
# Source: janitor package documentation
# https://sfirke.github.io/janitor/

dx_dupes <- dx_combined %>%
  janitor::get_dupes(patid, encounterid, dx)

if (nrow(dx_dupes) > 0) {
  message("WARNING: ", nrow(dx_dupes), " duplicate diagnosis records")
  # Remove exact duplicates
  dx_combined <- dx_combined %>% distinct()
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Base merge() function | dplyr joins | dplyr 0.1 (2014) | Faster, pipe-friendly, better syntax |
| Manual join validation | relationship argument | dplyr 1.1.0 (2023) | Built-in cardinality checks, explicit contracts |
| Base stopifnot() | assertr package | assertr 0.5 (2016) | Descriptive errors, pipeline integration |
| tableone package | gtsummary package | gtsummary 1.0 (2019) | Better tidyverse integration (not used until Phase 4) |
| Manual duplicate detection | janitor::get_dupes() | janitor 1.0 (2017) | Cleaner syntax, pipe-friendly |

**Deprecated/outdated:**
- **dplyr join warnings:** dplyr 1.0 warned on all many-to-many joins. dplyr 1.1.1+ only warns on unexpected many-to-many (reduced noise).
- **Base merge() for large data:** Performance gap widened. dplyr joins are 5-10x faster for clinical datasets (millions of rows).

## Open Questions

1. **Encounter deduplication methodology**
   - What we know: N3C/RECOVER use "macrovisit" aggregation to handle atomic encounter heterogeneity across sites
   - What's unclear: Does this project's SAS code use any deduplication? Forensic analysis of V5 files has not revealed encounter dedup logic
   - Recommendation: Defer advanced deduplication to future enhancement. Phase 2 translates existing SAS logic only. If SAS doesn't deduplicate, R shouldn't either. Document as known limitation.

2. **PAYER_TYPE_PRIMARY vs enrollment-level payer**
   - What we know: PCORnet CDM has encounter-level `PAYER_TYPE_PRIMARY` field (v7.0). Enrollment table likely has separate payer tracking.
   - What's unclear: Which table is the source of truth for payer grouping (CLN-06)?
   - Recommendation: Forensically trace payer derivation in V5 SAS files. If enrollment is source, Phase 2 must merge enrollment before payer recoding.

3. **Exact row count targets from SAS output**
   - What we know: Phase 2 should produce row counts "within 1% of SAS JOIN output" (success criteria)
   - What's unclear: No SAS output baseline available yet
   - Recommendation: Run V5 SAS code on HiPerGator to generate baseline PROC FREQ outputs. Store as `.planning/validation/sas_baseline_counts.txt` for Phase 2 validation.

## Sources

### Primary (HIGH confidence)
- [PCORnet Common Data Model v7.0 Specification](https://pcornet.org/wp-content/uploads/2025/01/PCORnet-Common-Data-Model-v70-2025_01_23.pdf) — Join keys for ENCOUNTER, DIAGNOSIS, PROCEDURES
- [dplyr Mutating Joins Documentation](https://dplyr.tidyverse.org/reference/mutate-joins.html) — relationship argument, cardinality enforcement
- [janitor Package Documentation](https://sfirke.github.io/janitor/) — clean_names(), get_dupes(), tabyl()
- [assertr Package Documentation](https://docs.ropensci.org/assertr/) — verify(), assert(), insist() for data quality
- [testthat Package Documentation](https://testthat.r-lib.org/) — Unit testing framework (v3.3.2, January 2026)
- [haven Conversion Semantics](https://cran.r-project.org/web/packages/haven/vignettes/semantics.html) — SAS missing value handling vs R NA

### Secondary (MEDIUM confidence)
- [Clinical Encounter Heterogeneity (N3C/RECOVER study)](https://www.medrxiv.org/content/10.1101/2022.10.14.22281106v1.full) — Macrovisit aggregation methods
- [SAS MERGE vs SQL JOIN](https://support.sas.com/resources/papers/proceedings/proceedings/sugi30/249-30.pdf) — Semantic differences (SUGI 30, verified 2026)
- [R for Data Science (2e) - Chapter 19 Joins](https://r4ds.hadley.nz/joins.html) — dplyr join best practices
- [Data Manipulation in R with dplyr (2026)](https://thelinuxcode.com/data-manipulation-in-r-with-dplyr-2026-practical-patterns-for-clean-reliable-pipelines/) — Validation patterns

### Tertiary (LOW confidence)
- [Mapping SAS Formats to R – Part 1](https://katalyzedata.com/tips-tricks/mapping-sas-formats-to-r-part-1/) — General guidance (not project-specific)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — dplyr, janitor, assertr are mature, well-documented packages with stable APIs
- Architecture patterns: HIGH — SAS-to-dplyr translation is well-established, relationship argument is production-ready (dplyr 1.1.0+)
- PCORnet CDM join keys: HIGH — Verified from official v7.0 spec (January 2025)
- SAS merge semantics: HIGH — Documented in authoritative SAS/SQL comparison papers
- Encounter deduplication: MEDIUM — N3C/RECOVER methods identified but unclear if needed for this project

**Research date:** 2026-04-16
**Valid until:** 60 days (2026-06-15) — dplyr/tidyverse update cycle is 3-4 months, no breaking changes expected
