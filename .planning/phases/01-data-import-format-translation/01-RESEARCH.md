# Phase 1: Data Import & Format Translation - Research

**Researched:** 2026-04-16
**Domain:** SAS-to-R data migration with haven package, format catalog translation, project infrastructure
**Confidence:** HIGH

## Summary

Phase 1 establishes the foundation for SAS-to-R pipeline conversion by importing SAS7BDAT files, translating the 2,495-line Formats.sas catalog to R factor definitions, and setting up reproducible project infrastructure. The haven package (v2.5.5, official tidyverse solution) handles SAS file import with format catalog support. Primary technical challenges are: (1) SAS-R semantic differences in missing value handling, (2) date conversion verification, (3) resolving 4 duplicate $payer format blocks in Formats.sas, and (4) establishing modular script architecture without data access for validation.

**Primary recommendation:** Use haven::read_sas() with catalog_file parameter for format-aware import, store all format definitions as named lists in a single R object for grep-friendly reference, implement numbered modular scripts (01_import.R, 01_formats.R) with .rds checkpoints, use renv for package version locking, and create comprehensive inline documentation for all SAS-to-R translation decisions.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Format Translation:**
- **D-01:** Translate ALL format definitions from Formats.sas into R, not just study-specific ones. This includes both PCORnet CDM standard formats (~50+ blocks: $RACE, $SEX, $ENC_TYPE, $DISCHARGE_STATUS, etc.) and study-specific custom formats ($p, $gsite, sdif, $r, agef, $treament, yn, ruca_2cat, sdi).
- **D-02:** Format duplicate resolution is Claude's discretion. Formats.sas contains 4 duplicate $payer blocks with slight variations. Claude will forensically determine the correct version based on downstream usage and SAS overwrite semantics (later definition wins).
- **D-03:** Format definitions stored as named lists (e.g., `sas_formats$race`, `sas_formats$enc_type`) that can be used with `factor(x, levels=..., labels=...)`. Single list object, clean and grep-friendly.

**Config Structure:**
- **D-04:** Use a sourced config.R script for all path parameterization. No YAML or .Renviron dependencies. Example: `data_dir <- here("data", "raw")`.
- **D-05:** Config.R handles paths only (data directory, output directory, checkpoint directory). Study-specific parameters (date ranges, ICD code lists, age thresholds) stay in the analysis scripts where they're used for easier auditing.

**SAS Code Authority:**
- **D-06:** Forensic analysis across all ~122 SAS files (V4 series + V5 series + dated files + topic files) to determine the correct analytical logic for each step. Claude traces evolution across versions (March 2024 - January 2025), identifies the latest/correct logic, and resolves conflicts. No shortcuts to "latest file only."
- **D-07:** SAS errors and conflicting logic documented as inline R comments where the logic appears. Example: `# SAS BUG FIX: v4_3 had wrong payer code mapping, corrected per v4_8`. No separate changelog file.
- **D-10:** V5 is the primary target. The V5 series (SAS_CODE_FOR_V5_0.sas through SAS_CODE_FOR_V5_18.sas, plus MODELS and Table_1 variants) uses Data_v5 directory and represents the latest analytical evolution. V4 and dated files are referenced when V5 logic is incomplete or unclear, but V5 takes precedence.

**Pipeline Checkpoints:**
- **D-08:** Each script saves output as .rds checkpoint files (e.g., `data/processed/01_encounters.rds`). Subsequent scripts read from checkpoints. Enables re-running from any stage.
- **D-09:** run_all.R includes a `start_step` parameter to resume from any script number, leveraging .rds checkpoints. Supports both full pipeline and partial re-runs.

**Analytical Approach (from V5 evolution):**
- **D-11:** Include multiple imputation in the R pipeline. V5 uses PROC MIANALYZE with `mi_table` datasets — R equivalent will use the `mice` package (or similar). This is the more rigorous approach matching V5 intent.
- **D-12:** Advanced model selection is Claude's discretion. V5 uses PROC GLIMMIX (mixed effects with random intercept by SOURCE) and PROC COUNTREG (zero-truncated NB). Claude will forensically determine which models are used for final results vs. exploratory, and implement accordingly (candidates: lme4, glmmTMB, VGAM/countreg packages in R).

### Claude's Discretion

- D-02 (format duplicate resolution) — Claude determines correct version per duplicate format block
- D-12 (advanced model selection) — Claude determines which V5 models (GLIMMIX, COUNTREG) are used for final results and implements the appropriate R equivalents

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| IMP-01 | R code reads all required SAS7BDAT files using haven::read_sas() with correct encoding | haven package (v2.5.5) supports SAS7BDAT import with catalog_file parameter for format-aware loading. Default encoding="latin1" works for most clinical data; UTF-8 encoding available via encoding parameter if needed. |
| IMP-02 | All SAS format definitions from Formats.sas are translated to R factor levels with matching labels | Formats.sas contains 2,495 lines with ~60+ PROC FORMAT blocks. Translation approach: parse each value block into named list with levels/labels. Use haven::as_factor() for import-time conversion OR base R factor() with custom lists for manual control. |
| IMP-03 | SAS date values convert correctly to R Date objects (validated against known dates) | haven automatically converts SAS DATE formats to R Date class (not POSIXct). SAS dates are days since 1960-01-01; R Date is days since 1970-01-01. haven handles conversion internally. Validation requires checking known dates from SAS output against R imported values. |
| IMP-04 | All file paths are parameterized in a config file using here::here() — no hardcoded paths | here package (v1.0.2, last update Sep 2025) provides project-relative path construction. Config.R pattern: `data_dir <- here("data", "raw")`. here::here() always resolves from project root regardless of working directory. |
| IMP-05 | Variable labels from SAS datasets are preserved as R attributes | haven stores SAS variable labels as "label" attribute on each column. Access via attr(df$varname, "label"). Labels persist through dplyr operations. Use labelled package or sjlabelled for bulk label management if needed. |
| INF-01 | Code organized as numbered modular scripts (01_import.R through final output script) | Standard clinical research pattern: 01_import.R, 02_clean.R, 03_merge.R, etc. Each script sources config.R, reads from previous .rds checkpoint, performs single logical step, saves new checkpoint. Simpler than targets for this project size. |
| INF-02 | Master runner script (run_all.R) executes full pipeline from data import to final outputs | run_all.R sources all scripts in order. Include start_step parameter for partial reruns: `source(here("R", "01_import.R"))` wrapped in conditional. Log progress to console. |
| INF-03 | Config files separate file paths and study parameters from analysis code | config.R for paths (D-04), study parameters stay in analysis scripts (D-05). Single source() call at top of each script loads config. |
| INF-04 | All logic decisions and SAS error fixes documented in code comments | Inline comments at decision points (D-07). Pattern: `# SAS BUG FIX: [version] had [problem], corrected per [version]`. No separate changelog. |
| INF-05 | Intermediate datasets saved as .rds checkpoints between pipeline stages | saveRDS()/readRDS() for checkpoints (D-08). .rds preserves R object structure including attributes (labels, factors). Place in data/processed/ directory. |
| INF-06 | renv lockfile created for reproducible package management | renv::init() creates project-local library, renv.lock records package versions. Snapshot after initial setup. Restore with renv::restore() on new machine. Essential for long-term reproducibility. |

</phase_requirements>

## Project Constraints (from CLAUDE.md)

**CRITICAL: Research must align with these project-level directives:**

- **Language:** R with tidyverse (dplyr, tidyr, ggplot2, readr, haven for SAS import) — no Python, no SAS
- **No data access:** Code must be written without running against data — parameterize all file paths, design for structure not content
- **Preserve intent:** Fix logic errors but don't change study design or variable definitions
- **PCORnet CDM compliance:** Variable names and coding must align with PCORnet Common Data Model conventions
- **SAS7BDAT input:** Data files are in SAS format — use haven::read_sas() for import
- **Stack constraints (from STACK.md):**
  - haven (v2.5.5) for SAS import — REQUIRED, not optional
  - tidyverse meta-package for all data manipulation — REQUIRED
  - renv (v1.2.2) for package management — REQUIRED
  - here (v1.0.2) for path management — REQUIRED
  - DO NOT use pharmaverse packages (CDISC-focused, not PCORnet)

## Standard Stack

### Core: SAS Data Import
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| **haven** | 2.5.5 | Read SAS7BDAT files and SAS7BCAT format catalogs | Official tidyverse package for SAS import. read_sas() handles both data files and format catalogs. as_factor() converts labelled vectors to R factors. Actively maintained (last update May 2025). Only viable option for SAS7BDAT with full format support. |
| **tidyverse** | 2.0.0+ | Meta-package loading dplyr, tidyr, readr, purrr, tibble, stringr, forcats, lubridate | Standard for modern R data science. Loads all essential packages in one command. All downstream scripts depend on tidyverse functions. |
| **readr** | 2.2.0 | Write intermediate CSV files if needed | Fast, type-safe CSV I/O. Use for human-readable intermediate outputs (not primary checkpoint format). |

### Core: Project Infrastructure
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| **here** | 1.0.2 | Project-relative path construction | Eliminates hardcoded paths and setwd() calls. here("data", "raw") always resolves from project root regardless of script location. Essential for modular scripts. Last update Sep 2025. |
| **renv** | 1.2.2 | Project-local package management and version locking | Freezes package versions for reproducibility. Creates renv.lock documenting exact versions. Critical for long-term clinical research projects. Industry best practice as of 2026. |
| **janitor** | 2.2.1 | Column name standardization via clean_names() | Clinical datasets have inconsistent naming. clean_names() converts to snake_case. get_dupes() finds duplicates. Not strictly needed for Phase 1 but establish pattern early. |

### Supporting: Data Quality
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **assertthat** | 0.2.1 | Data quality assertions | Validate data structure after import (e.g., assert_that(all(is.Date(df$date)))). Use in import scripts to catch format conversion failures early. |
| **labelled** | 2.13.0 | Bulk SAS label management | If need to manipulate/remove/copy variable labels across datasets. haven provides basic label support; labelled adds convenience functions. |

### Not Recommended for Phase 1
- **foreign** package — Deprecated (last update 2022). Use haven instead.
- **sas7bdat** package — Limited format catalog support. Use haven instead.
- **targets** package — Overkill for Phase 1. Start with simple run_all.R; migrate to targets later if pipeline becomes unwieldy.
- **mice** package — Needed for Phase 4 (multiple imputation), not Phase 1.

**Installation:**
```r
# Install core packages
install.packages("tidyverse")  # Includes dplyr, tidyr, readr, ggplot2, etc.
install.packages("haven")      # SAS import
install.packages("here")       # Path management
install.packages("renv")       # Package version control
install.packages("janitor")    # Data cleaning

# Supporting packages (optional for Phase 1)
install.packages("assertthat")
install.packages("labelled")

# Initialize renv for version control
renv::init()
renv::snapshot()
```

**Version verification:** All versions verified against CRAN as of April 2026.

## Architecture Patterns

### Recommended Project Structure
```
prec_ins_investigation/
├── .planning/                    # GSD planning artifacts (already exists)
├── data/
│   ├── raw/                      # SAS7BDAT files (not in git)
│   │   ├── demographic_mobley_v5.sas7bdat
│   │   ├── enrollment_mobley_v5.sas7bdat
│   │   └── ...
│   └── processed/                # .rds checkpoints (not in git)
│       ├── 01_formats.rds
│       ├── 01_imported_demo.rds
│       └── ...
├── R/
│   ├── config.R                  # Path configuration (sourced by all scripts)
│   ├── 01_formats.R              # Translate Formats.sas to R lists
│   ├── 01_import.R               # Import all SAS7BDAT files
│   └── run_all.R                 # Master runner script
├── output/                       # Final outputs (tables, figures)
├── renv/                         # renv package library (not in git except renv.lock)
├── renv.lock                     # Package version lockfile (IN GIT)
├── .Rprofile                     # renv activation (created by renv::init())
├── .gitignore                    # Exclude data/, output/, renv/library/
└── CLAUDE.md                     # Project instructions (already exists)
```

### Pattern 1: Config.R for Path Parameterization

**What:** Single sourced config file containing all path definitions using here::here()

**When to use:** Every script in pipeline sources config.R first

**Example:**
```r
# R/config.R
# Path configuration for Precision Cancer Survivorship pipeline
# Source: User decision D-04

library(here)

# Declare project root (run once at start)
# Place this file in R/ subdirectory of project root
# here() will automatically detect project root from .Rproj, .git, or .here file

# Data directories
data_dir_raw <- here("data", "raw")
data_dir_processed <- here("data", "processed")

# Output directories
output_dir <- here("output")
output_dir_tables <- here("output", "tables")
output_dir_figures <- here("output", "figures")

# Verify directories exist (create if missing)
if (!dir.exists(data_dir_processed)) dir.create(data_dir_processed, recursive = TRUE)
if (!dir.exists(output_dir_tables)) dir.create(output_dir_tables, recursive = TRUE)
if (!dir.exists(output_dir_figures)) dir.create(output_dir_figures, recursive = TRUE)

# NOTE: Study-specific parameters (date ranges, ICD codes, age thresholds)
# are NOT in this file per D-05. Keep those in analysis scripts for auditing.
```

**Usage in scripts:**
```r
# R/01_import.R
source(here::here("R", "config.R"))  # Load paths
library(haven)
library(tidyverse)

# Now use paths from config
demo <- read_sas(file.path(data_dir_raw, "demographic_mobley_v5.sas7bdat"))
```

### Pattern 2: Formats.sas Translation to Named Lists

**What:** Convert SAS PROC FORMAT blocks to R named lists for factor creation

**When to use:** Once at pipeline start, stored as checkpoint for reuse

**Example:**
```r
# R/01_formats.R
# Translate Formats.sas (2,495 lines) to R factor definitions
# Source: User decision D-03, Formats.sas canonical reference

source(here::here("R", "config.R"))
library(tidyverse)

# Create master format list (grep-friendly single object per D-03)
sas_formats <- list()

# PCORnet CDM Standard Formats
# Source: Formats.sas lines 5-15
sas_formats$race <- list(
  levels = c("01", "02", "03", "04", "05", "06", "07", "NI", "UN", "OT"),
  labels = c("American Indian or Alaska Native", "Asian",
             "Black or African American", "Native Hawaiian or Other Pacific Islander",
             "White", "Multiple race", "Refuse to answer",
             "No information", "Unknown", "Other")
)

# Source: Formats.sas lines 17-23
sas_formats$sex <- list(
  levels = c("A", "F", "M", "NI", "UN", "OT"),
  labels = c("Ambiguous", "Female", "Male", "No information", "Unknown", "Other")
)

# Source: Formats.sas lines 53-59
sas_formats$hispanic <- list(
  levels = c("Y", "N", "R", "NI", "UN", "OT"),
  labels = c("Yes", "No", "Refuse to answer", "No information", "Unknown", "Other")
)

# ... [Continue for all ~60+ format blocks] ...

# Study-Specific Custom Formats
# TODO: Resolve duplicate $payer blocks (D-02)
# Formats.sas has 4 definitions at lines 693, 955, 1899, 2161
# SAS semantics: later definition wins (line 2161 is active)
# FORENSIC TASK: Verify line 2161 matches downstream usage in V5 files
sas_formats$payer <- list(
  levels = c("01", "02", "03", "04", "05", "NI", "UN", "OT"),
  labels = c("Medicare", "Medicaid", "Private", "Self-pay", "Other",
             "No information", "Unknown", "Other")
  # NOTE: This is PLACEHOLDER — actual values require forensic analysis of line 2161
)

# Save for use by downstream scripts
saveRDS(sas_formats, file.path(data_dir_processed, "01_formats.rds"))

message("Format translation complete: ", length(sas_formats), " formats saved")
```

**Usage in data processing:**
```r
# Apply format to variable
demo <- demo %>%
  mutate(
    race_factor = factor(RACE,
                        levels = sas_formats$race$levels,
                        labels = sas_formats$race$labels)
  )

# Or use haven's labelled class (preserves codes)
demo <- demo %>%
  mutate(race_labelled = labelled(RACE,
                                  labels = setNames(sas_formats$race$levels,
                                                   sas_formats$race$labels)))
```

### Pattern 3: Modular Script with Checkpoint Pattern

**What:** Each script performs single logical step, reads previous checkpoint, writes new checkpoint

**When to use:** All pipeline scripts (01_import.R, 02_clean.R, etc.)

**Example:**
```r
# R/01_import.R
# Import all required SAS7BDAT files for V5 analysis
# Outputs: data/processed/01_*.rds checkpoints
# Source: User decision D-08 (checkpoint pattern)

source(here::here("R", "config.R"))
library(haven)
library(tidyverse)
library(janitor)

# Load format definitions
sas_formats <- readRDS(file.path(data_dir_processed, "01_formats.rds"))

message("Starting SAS data import at ", Sys.time())

# Import demographic data
# Source: V5 files reference "demographic_mobley_v5" table
message("Importing demographic data...")
demo <- read_sas(
  data_file = file.path(data_dir_raw, "demographic_mobley_v5.sas7bdat"),
  # NOTE: No catalog_file needed here — formats applied separately via 01_formats.rds
  encoding = "latin1"  # Default for clinical data; change to "UTF-8" if needed
)

# Standardize column names (janitor convention)
demo <- demo %>% clean_names()

# Preserve original SAS variable labels as attributes
# (haven automatically stores these, just verify they exist)
demo_labels <- map_chr(demo, ~attr(.x, "label") %||% NA_character_)
message("Imported ", nrow(demo), " rows, ", ncol(demo), " columns from demographic table")

# Import enrollment data
message("Importing enrollment data...")
enroll <- read_sas(
  data_file = file.path(data_dir_raw, "Enrollment_mobley_v5.sas7bdat"),
  encoding = "latin1"
)
enroll <- enroll %>% clean_names()
message("Imported ", nrow(enroll), " rows, ", ncol(enroll), " columns from enrollment table")

# ... [Continue for all required V5 tables] ...

# Save checkpoints (D-08)
saveRDS(demo, file.path(data_dir_processed, "01_imported_demo.rds"))
saveRDS(enroll, file.path(data_dir_processed, "01_imported_enroll.rds"))

message("Import complete at ", Sys.time())
message("Checkpoints saved to: ", data_dir_processed)
```

### Pattern 4: Master Runner with start_step Support

**What:** run_all.R executes full pipeline or partial reruns from checkpoints

**When to use:** Main entry point for pipeline execution

**Example:**
```r
# R/run_all.R
# Master runner for Precision Cancer Survivorship pipeline
# Executes all scripts in sequence with optional start_step for partial reruns
# Source: User decision D-09

library(here)

# Configuration
start_step <- 1  # Change to resume from later step (e.g., 2 skips import)
scripts <- c(
  "01_formats.R",
  "01_import.R"
  # "02_clean.R",    # Add in Phase 2
  # "03_merge.R",    # Add in Phase 2
  # etc.
)

message("========================================")
message("Precision Cancer Survivorship Pipeline")
message("Started: ", Sys.time())
message("Starting from step: ", start_step)
message("========================================")

# Execute scripts
for (i in seq_along(scripts)) {
  if (i >= start_step) {
    script_path <- here("R", scripts[i])
    message("\n>>> Running: ", scripts[i], " <<<")
    source(script_path)
    message("✓ Completed: ", scripts[i])
  } else {
    message("✗ Skipped: ", scripts[i])
  }
}

message("\n========================================")
message("Pipeline complete: ", Sys.time())
message("========================================")
```

### Anti-Patterns to Avoid

**Anti-pattern 1: Hardcoded absolute paths**
```r
# BAD
demo <- read_sas("C:/Users/Owner/Documents/data/demographic.sas7bdat")

# GOOD
demo <- read_sas(file.path(data_dir_raw, "demographic_mobley_v5.sas7bdat"))
```

**Anti-pattern 2: Changing working directory**
```r
# BAD
setwd("C:/Users/Owner/Documents/prec_ins_investigation/R")
source("config.R")

# GOOD
source(here::here("R", "config.R"))
```

**Anti-pattern 3: No checkpoint saving**
```r
# BAD — forces full pipeline rerun for any downstream change
# [import data]
# [clean data]
# [analyze data]
# (No intermediate saves)

# GOOD — checkpoint after each major step
saveRDS(demo_clean, file.path(data_dir_processed, "02_clean_demo.rds"))
```

**Anti-pattern 4: Format catalog ignorance**
```r
# BAD — loses SAS value labels
demo <- read_sas("demographic.sas7bdat")
# Result: RACE is "05" not "White"

# GOOD — apply formats from translated list
demo <- demo %>%
  mutate(race = factor(RACE,
                      levels = sas_formats$race$levels,
                      labels = sas_formats$race$labels))
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| SAS7BDAT file parsing | Custom binary file reader | haven::read_sas() | SAS7BDAT is proprietary binary format with version-specific compression, encoding variations, and platform differences. haven is maintained by RStudio/Posit team with C++ backend. Building custom parser risks data corruption. |
| SAS date conversion | Manual date arithmetic (days since 1960) | Let haven auto-convert to Date class | SAS dates are days since 1960-01-01, R Date is days since 1970-01-01. Off-by-one errors and leap year bugs are common. haven handles this internally with tested code. |
| Format catalog parsing | Parse .sas7bcat binary files | haven::read_sas(catalog_file = "...") or manual list translation | SAS format catalogs are binary files with complex structure. haven can read them, but manual translation to R lists (Pattern 2) gives more control for duplicate resolution. |
| Project path management | Relative paths with paste0("../data/...") | here::here("data", "...") | Relative paths break when scripts run from different locations. here() always resolves from project root, works across platforms (Windows/Mac/Linux), and handles spaces in paths correctly. |
| Package version control | Manual library() calls with no version tracking | renv::init() and renv::snapshot() | Package updates break code. Manual tracking via comments is error-prone. renv creates machine-readable lockfile, enables exact reproduction on new machines, and is industry standard as of 2026. |
| Missing value comparisons | Direct equality checks (x == NA) | is.na(x) | In SAS, missing (.) is smallest possible number (. < 10 is TRUE). In R, any comparison with NA returns NA, not TRUE/FALSE. This is the #1 source of logic errors in SAS-to-R translation. Always use is.na() explicitly. |

**Key insight:** SAS-to-R translation has mature tooling (haven, here, renv) that solves 90% of common problems. Custom solutions for these problems introduce bugs, not value. Invest forensic effort in translating LOGIC (Formats.sas, analytical algorithms), not re-implementing INFRASTRUCTURE (file I/O, path management).

## Runtime State Inventory

**NOT APPLICABLE — Phase 1 is greenfield code creation, not refactoring/migration.**

No runtime state to inventory. All work is writing new R scripts from scratch based on SAS code analysis.

## Common Pitfalls

### Pitfall 1: Missing Value Semantic Mismatch
**What goes wrong:** SAS code uses `if var then` (TRUE when non-missing) or `if var < 10` (includes missing as smallest value). Direct R translation breaks because R's NA propagates through comparisons, returning NA not TRUE/FALSE.

**Why it happens:** Fundamental difference in missing value semantics. SAS treats `.` as negative infinity in numeric comparisons. R treats NA as "unknown" that propagates.

**How to avoid:**
1. Audit all SAS conditional logic for implicit missing value handling
2. Translate SAS `if var then` to R `if (!is.na(var) && var)`
3. Translate SAS `if var1 = var2 then` to R `if (!is.na(var1) && !is.na(var2) && var1 == var2)`
4. Use explicit is.na() checks before all comparisons involving potentially missing data
5. Document each translation with inline comment: `# SAS implicit missing check translated to explicit is.na()`

**Warning signs:** Unexpected NA results in mutate() operations, filter() returning fewer rows than expected, logical operations producing NA vectors

### Pitfall 2: SAS Date Format Auto-Conversion Assumptions
**What goes wrong:** Assuming all SAS date variables will auto-convert to R Date class. Some SAS date variables lack explicit DATE format and import as numeric (days since 1960-01-01) rather than Date objects.

**Why it happens:** haven only auto-converts variables with explicit SAS date formats (DATE, ADATE, EDATE, JDATE, SDATE). Variables created via date arithmetic in SAS DATA steps may lose format metadata.

**How to avoid:**
1. After import, check date variable classes with `class(df$date_var)`
2. For numeric dates, manually convert: `df$date_var <- as.Date(df$date_var, origin = "1960-01-01")`
3. Validate known dates from SAS output against R imported values
4. Document expected date variables and their formats in 01_import.R comments
5. Add assertions: `assertthat::assert_that(all(is.Date(df$date_var)) || all(is.na(df$date_var)))`

**Warning signs:** Date variables showing as numeric with values ~20000-25000 range (days since 1960), date arithmetic producing nonsensical results, join failures on date keys

### Pitfall 3: Format Catalog Duplicate Resolution Without Forensics
**What goes wrong:** Formats.sas has 4 duplicate $payer format blocks (lines 693, 955, 1899, 2161). Taking first definition or last definition without forensic verification of downstream usage produces incorrect factor labels.

**Why it happens:** SAS semantics: later PROC FORMAT definition wins. But each duplicate may have been used in different versions of the analysis code. V5 code may reference a specific version.

**How to avoid:**
1. Extract all 4 $payer blocks from Formats.sas with line numbers
2. Search V5 SAS files for payer variable usage: grep "format.*payer" and "payer.*format"
3. Check which definition matches actual payer codes in V5 data dictionaries or PROC FREQ outputs
4. Document decision in 01_formats.R: `# FORENSIC DECISION: Using line 2161 definition (4th occurrence) because...`
5. Cross-reference with PCORnet CDM payer codes if available

**Warning signs:** Factor levels in R don't match SAS PROC FREQ output labels, unexpected "Other" categories, join failures on payer type

### Pitfall 4: Confusing V3/V4/V5 Library References
**What goes wrong:** V5 files use confusing library aliases. V5 code has `libname v3 "&path/Data_v5";` — the alias is `v3` but it points to `Data_v5` directory. Translating this literally causes wrong data file references.

**Why it happens:** Legacy naming from iterative analysis evolution. Researcher reused old library alias (`v3`) when creating new data version (`Data_v5`) to minimize code changes.

**How to avoid:**
1. In config.R, name paths clearly: `data_dir_v5 <- here("data", "raw", "v5")`
2. Document SAS library alias confusion: `# NOTE: SAS code uses "v3" alias for Data_v5 directory`
3. Map all SAS library references to actual directories before importing:
   - `libname v3` → Data_v5 → `data_dir_v5`
   - `libname v4` → Data_v4 → `data_dir_v4`
   - `libname dx` → Dx → `data_dir_dx`
4. Never use ambiguous names like `v3` in R code

**Warning signs:** File not found errors when looking for data_v3 files, wrong data version imported, patient counts don't match V5 SAS output

### Pitfall 5: Losing Variable Labels During Data Manipulation
**What goes wrong:** SAS variable labels are stored as attributes in haven import. dplyr operations (especially select(), rename(), mutate() with transformations) can drop label attributes silently.

**Why it happens:** R attributes are fragile and not all tidyverse functions preserve them consistently. Labels are metadata, not core data structure.

**How to avoid:**
1. Extract labels immediately after import: `demo_labels <- map_chr(demo, ~attr(.x, "label") %||% NA_character_)`
2. Store labels as checkpoint: `saveRDS(demo_labels, file.path(data_dir_processed, "01_demo_labels.rds"))`
3. Use labelled package functions (e.g., `var_label()`, `copy_labels()`) for bulk label management
4. Reapply labels after transformations if needed
5. For critical variables, verify labels exist: `assertthat::assert_that(!is.null(attr(df$patid, "label")))`

**Warning signs:** Variable labels missing in output tables, documentation references labels that don't exist in R objects, difficulty identifying variable meanings

### Pitfall 6: Encoding Issues with Clinical Text Data
**What goes wrong:** SAS data contains clinical text with special characters (names, diagnoses, notes). Default encoding mismatch causes mojibake (garbled text) or import errors.

**Why it happens:** SAS data created on Windows often uses latin1 encoding. R defaults to system encoding (UTF-8 on Mac/Linux, often Windows-1252 on Windows). Mismatch corrupts non-ASCII characters.

**How to avoid:**
1. Check existing SAS output for special characters (accented names, symbols)
2. Start with haven default (latin1): `read_sas(data_file, encoding = "latin1")`
3. If text garbled, try: `read_sas(data_file, encoding = "UTF-8")`
4. Test on variables with known special characters (e.g., Hispanic patient names)
5. Document encoding choice in 01_import.R
6. Use same encoding consistently across all files

**Warning signs:** Names with accents show as ????, PROC FREQ labels don't match R factor labels character-by-character, join failures on text keys despite apparent match

### Pitfall 7: No Validation Against SAS Output Without Data Access
**What goes wrong:** Phase 1 writes import code without access to actual data. Code may have logic errors (wrong file names, wrong formats applied) that only surface when data is available, forcing rework.

**Why it happens:** Constraint from project: "Code written without running against data." But forensic analysis can still extract validation metadata from SAS files.

**How to avoid:**
1. Extract expected row counts from SAS comments: `/* 514252 */` in keytodatasets.sas
2. Extract expected variable lists from PROC CONTENTS outputs in SAS files
3. Create validation checklist in 01_import.R comments:
   ```r
   # VALIDATION CHECKLIST (run when data available):
   # - demo: expect ~514252 rows, ~25 columns
   # - demo$RACE: expect levels 01-05, NI, UN, OT (no 06, 07 per V5 data)
   # - demo$BIRTH_DATE: expect Date class, range 1940-2010
   ```
4. Build assertions into code so first data run auto-validates structure
5. Document data structure assumptions from SAS forensics

**Warning signs:** First data run produces file not found errors, wrong number of columns, factor levels don't match SAS PROC FREQ, date ranges implausible

## Code Examples

### Example 1: Import SAS7BDAT with Format Awareness
```r
# Source: haven official documentation, https://haven.tidyverse.org/reference/read_sas.html
library(haven)
library(tidyverse)

# Basic import (no format catalog)
demo <- read_sas("demographic_mobley_v5.sas7bdat")

# Import with format catalog (if .sas7bcat available)
demo <- read_sas(
  data_file = "demographic_mobley_v5.sas7bdat",
  catalog_file = "formats.sas7bcat",  # Optional
  encoding = "latin1"  # Default for clinical data
)

# Check what got imported
glimpse(demo)

# Check variable labels (preserved as attributes)
map_chr(demo, ~attr(.x, "label") %||% "No label")

# Convert labelled variables to factors
demo <- demo %>%
  mutate(across(where(haven::is.labelled), haven::as_factor))
```

### Example 2: Manual Date Conversion for Non-Formatted Dates
```r
# Source: janitor::sas_numeric_to_date, https://rdrr.io/cran/janitor/man/sas_numeric_to_date.html
library(tidyverse)

# If date imported as numeric (haven didn't auto-convert)
# Check first:
class(demo$birth_date)  # "numeric" not "Date"
head(demo$birth_date)   # Values like 20450, 18293 (days since 1960-01-01)

# Manual conversion
demo <- demo %>%
  mutate(
    birth_date = as.Date(birth_date, origin = "1960-01-01")
  )

# Validate known date
# From SAS output: PATID=12345 has BIRTH_DATE='15JAN1975'd (SAS date literal)
demo %>%
  filter(patid == "12345") %>%
  pull(birth_date)
# Should show: "1975-01-15"

# Alternative: use janitor helper (same result)
library(janitor)
demo <- demo %>%
  mutate(birth_date = sas_numeric_to_date(birth_date))
```

### Example 3: Apply Format from Translated List
```r
# Source: base R factor() with custom levels/labels
library(tidyverse)

# Load format definitions (from 01_formats.R)
sas_formats <- readRDS("data/processed/01_formats.rds")

# Apply race format
demo <- demo %>%
  mutate(
    race_factor = factor(
      RACE,
      levels = sas_formats$race$levels,
      labels = sas_formats$race$labels
    )
  )

# Verify
demo %>% count(RACE, race_factor)
# Should match SAS PROC FREQ output for RACE variable

# Apply multiple formats at once
demo <- demo %>%
  mutate(
    race = factor(RACE,
                 levels = sas_formats$race$levels,
                 labels = sas_formats$race$labels),
    sex = factor(SEX,
                levels = sas_formats$sex$levels,
                labels = sas_formats$sex$labels),
    hispanic = factor(HISPANIC,
                     levels = sas_formats$hispanic$levels,
                     labels = sas_formats$hispanic$labels)
  )
```

### Example 4: Explicit Missing Value Handling
```r
# Source: SAS-to-R semantic conversion best practices
library(tidyverse)

# SAS code:
#   if payer_primary then do;
#     ... (executes when payer_primary is not missing)
#   end;

# WRONG R translation:
demo %>%
  filter(payer_primary) %>%  # This breaks! payer_primary might be NA
  mutate(...)

# CORRECT R translation:
demo %>%
  filter(!is.na(payer_primary)) %>%  # Explicit missing check
  mutate(...)

# SAS code:
#   if age < 18 then age_group = 'Child';

# WRONG R translation:
demo %>%
  mutate(age_group = ifelse(age < 18, "Child", "Adult"))
# Problem: ifelse returns NA when age is NA, not "Adult"

# CORRECT R translation:
demo %>%
  mutate(age_group = case_when(
    is.na(age) ~ NA_character_,  # Explicit handling
    age < 18 ~ "Child",
    TRUE ~ "Adult"
  ))
```

### Example 5: Checkpoint Pattern with Validation
```r
# Source: User decision D-08, clinical research best practices
library(tidyverse)
library(here)
library(assertthat)

source(here("R", "config.R"))

# Import
demo <- read_sas(file.path(data_dir_raw, "demographic_mobley_v5.sas7bdat"))

# Validation assertions (from SAS forensics)
assert_that(
  nrow(demo) > 500000,  # Expect ~514252 per keytodatasets.sas
  "PATID" %in% names(demo),
  "BIRTH_DATE" %in% names(demo),
  msg = "Demographic data structure validation failed"
)

# Save checkpoint
saveRDS(demo, file.path(data_dir_processed, "01_imported_demo.rds"))
message("Saved checkpoint: 01_imported_demo.rds (", nrow(demo), " rows)")

# Later script loads checkpoint
demo <- readRDS(file.path(data_dir_processed, "01_imported_demo.rds"))
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| **foreign::read.xport()** for SAS transport files | **haven::read_sas()** for native SAS7BDAT files | 2015-2016 (haven 1.0 released) | Eliminates need for SAS to export .xpt files. Reads SAS data directly with format catalogs. foreign deprecated 2022. |
| **Manual factor creation** with hardcoded levels/labels | **haven::as_factor()** with labelled class | 2020-2021 (haven 2.4+) | Preserves SAS format metadata automatically. Reduces manual translation errors. |
| **targets package** for all pipelines | **Simple run_all.R** for small-medium projects | 2023-2026 (maturation of targets) | targets adds complexity for projects <20 scripts. run_all.R with checkpoints is sufficient for this 4-phase project. Migrate to targets if pipeline grows. |
| **setwd() + relative paths** | **here::here()** for project-relative paths | 2020+ (here package adoption) | Eliminates "works on my machine" path errors. Standard practice as of 2026. |
| **Manual package.txt version list** | **renv lockfile** | 2019+ (renv replaced packrat) | Machine-readable, auto-generated version manifest. Industry standard for reproducibility. |
| **SAS missing values as smallest number** | **R NA propagation** | Always (fundamental difference) | Not a temporal change, but critical semantic difference. All SAS-to-R translations must address explicitly. |

**Deprecated/outdated:**
- **foreign package** (last update 2022): Use haven instead for SAS import
- **sas7bdat package** (limited format support): Use haven instead
- **packrat package** (replaced by renv in 2019): Use renv for package management
- **setwd() path management**: Use here::here() for project-relative paths
- **SAS transport format (.xpt)**: Direct .sas7bdat import with haven is now standard

## Open Questions

### Question 1: V5 Data File Inventory
**What we know:** V5 SAS code references ~10+ datasets with `_v5` suffix (demographic_mobley_v5, Enrollment_mobley_v5, Address_history_mobley_v5, etc.). keytodatasets.sas shows library structure but doesn't list all V5-specific tables.

**What's unclear:** Complete list of required V5 .sas7bdat files and their expected locations (Data_v5 vs. Dx vs. other directories).

**Recommendation:**
1. During Wave 0 of Phase 1 planning, grep all 23 V5 SAS files for dataset references
2. Extract pattern: `set v3.tablename` or `data v3.tablename` (remember v3 alias = Data_v5)
3. Create master import checklist in 01_import.R comments
4. Document expected file locations based on libname statements across V5 files
5. Flag missing files for user verification before first data run

### Question 2: Format Catalog .sas7bcat Availability
**What we know:** Formats.sas contains PROC FORMAT source code (text). haven can read compiled .sas7bcat catalogs OR we can manually translate PROC FORMAT to R lists.

**What's unclear:** Does a compiled formats.sas7bcat file exist alongside the SAS data files, or do we need manual translation?

**Recommendation:**
1. Check data directory for formats.sas7bcat when data access available
2. If exists: Use `read_sas(catalog_file = "formats.sas7bcat")` to auto-apply formats at import
3. If not exists: Use manual translation to named lists (Pattern 2) — gives more control for duplicate resolution anyway
4. Default plan: Manual translation (D-03 user decision already specifies named list approach)

### Question 3: Duplicate $payer Format Forensic Analysis
**What we know:** Formats.sas has 4 $payer definitions (lines 693, 955, 1899, 2161). SAS semantics: later wins (line 2161 active). But different versions may have been used during V4 vs V5 development.

**What's unclear:** Which $payer definition matches actual payer codes in V5 datasets? Do all 4 have same levels but different labels, or different structures entirely?

**Recommendation:**
1. Extract all 4 $payer blocks with diff comparison
2. Grep V5 files for `format.*payer` to see how/where applied
3. If V5 has PROC FREQ output for payer, match labels to one of the 4 blocks
4. Check PCORnet CDM v7.0 payer codes (if available) as ground truth
5. Document decision with line-by-line comparison in 01_formats.R comments
6. This is HIGH PRIORITY for Wave 0 — blocking for all downstream payer-related analysis

### Question 4: Encoding for Clinical Text Fields
**What we know:** Default encoding="latin1" works for most clinical data. UTF-8 alternative available. Hispanic patient names may contain accented characters.

**What's unclear:** Actual encoding of SAS files created on UF HiPerGator. Text corruption risk unknown until first data run.

**Recommendation:**
1. Default to encoding="latin1" in 01_import.R (haven default, most common for SAS)
2. Add validation check for text fields with known special characters (if identifiable from SAS output)
3. Document encoding choice and testing steps in import script comments
4. Build encoding parameter into config.R for easy change if corruption detected: `sas_encoding <- "latin1"`
5. LOW PRIORITY — address only if corruption observed in validation

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| R | All Phase 1 scripts | ✗ | — | **BLOCKS EXECUTION** — must install R 4.3+ |
| haven package | IMP-01 (SAS import) | ✗ | — | **BLOCKS EXECUTION** — must install via install.packages("haven") |
| tidyverse | All data manipulation | ✗ | — | **BLOCKS EXECUTION** — must install via install.packages("tidyverse") |
| here | INF-04 (path management) | ✗ | — | **BLOCKS EXECUTION** — must install via install.packages("here") |
| renv | INF-06 (reproducibility) | ✗ | — | **BLOCKS EXECUTION** — must install via install.packages("renv") |
| Git | Version control | ✓ | 2.28.0 | — |
| Python | Not required | ✓ | 3.14.2 | — |

**Missing dependencies with no fallback:**
- **R 4.3+** — Core requirement. Entire Phase 1 blocked without R installation.
- **haven, tidyverse, here, renv packages** — Install via R after R installation. Standard CRAN packages, no compilation required on Windows.

**Installation steps for user:**
1. Install R 4.3+ from https://cran.r-project.org/ (Windows binary)
2. Open R console, run: `install.packages(c("tidyverse", "haven", "here", "renv", "janitor"))`
3. Test installation: `library(haven); library(tidyverse); library(here); library(renv)`
4. In project directory, run: `renv::init()` to set up reproducible environment

**Note:** Git available — can commit R scripts and renv.lock for version control as planning proceeds.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | testthat 3.2.2+ |
| Config file | tests/testthat.R — see Wave 0 |
| Quick run command | `testthat::test_dir("tests/testthat", filter = "phase01", stop_on_failure = TRUE)` |
| Full suite command | `testthat::test_dir("tests/testthat")` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| IMP-01 | SAS7BDAT files load without errors, encoding correct | unit | `testthat::test_file("tests/testthat/test-01-import.R", filter = "IMP-01")` | ❌ Wave 0 |
| IMP-02 | All Formats.sas blocks translated to named lists with correct levels/labels | unit | `testthat::test_file("tests/testthat/test-01-formats.R", filter = "IMP-02")` | ❌ Wave 0 |
| IMP-03 | SAS date values convert to Date class, match known dates from SAS output | unit | `testthat::test_file("tests/testthat/test-01-import.R", filter = "IMP-03")` | ❌ Wave 0 |
| IMP-04 | No hardcoded paths in scripts, all use here::here() | unit | `testthat::test_file("tests/testthat/test-01-config.R", filter = "IMP-04")` | ❌ Wave 0 |
| IMP-05 | Variable labels preserved as attributes after import | unit | `testthat::test_file("tests/testthat/test-01-import.R", filter = "IMP-05")` | ❌ Wave 0 |
| INF-01 | Scripts numbered sequentially, each performs single logical step | manual | `grep -E "^# R/[0-9]{2}_.*\.R" R/*.R` — human audit | N/A |
| INF-02 | run_all.R executes all scripts in order with start_step support | integration | `testthat::test_file("tests/testthat/test-01-runner.R", filter = "INF-02")` | ❌ Wave 0 |
| INF-03 | config.R separates paths from logic, sourced by all scripts | manual | `grep "source.*config.R" R/*.R` — verify all scripts source config | N/A |
| INF-04 | SAS logic decisions documented in inline comments | manual | Code review — verify D-06, D-07 compliance | N/A |
| INF-05 | Checkpoint .rds files created after each script | unit | `testthat::test_file("tests/testthat/test-01-checkpoints.R", filter = "INF-05")` | ❌ Wave 0 |
| INF-06 | renv.lock exists and contains all required packages | unit | `testthat::test_file("tests/testthat/test-01-renv.R", filter = "INF-06")` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `testthat::test_file("tests/testthat/test-01-*.R", stop_on_failure = TRUE)` — run tests for files changed in commit
- **Per wave merge:** `testthat::test_dir("tests/testthat", filter = "phase01")` — full Phase 1 test suite
- **Phase gate:** Full suite green + manual audits (INF-01, INF-03, INF-04) before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/testthat/test-01-import.R` — covers IMP-01, IMP-03, IMP-05 (SAS import validation)
- [ ] `tests/testthat/test-01-formats.R` — covers IMP-02 (format translation correctness)
- [ ] `tests/testthat/test-01-config.R` — covers IMP-04 (path parameterization)
- [ ] `tests/testthat/test-01-runner.R` — covers INF-02 (run_all.R execution)
- [ ] `tests/testthat/test-01-checkpoints.R` — covers INF-05 (checkpoint file creation)
- [ ] `tests/testthat/test-01-renv.R` — covers INF-06 (renv.lock validity)
- [ ] `tests/testthat.R` — test runner setup
- [ ] Framework install: `install.packages("testthat")` — R package manager

**Test data strategy:** No actual SAS7BDAT files in tests (too large, HIPAA concerns). Use mock data:
- Create minimal synthetic .sas7bdat files with haven::write_sas() in tests/fixtures/
- Mock files: 10 rows, 5 columns, include date variable + formatted categorical
- Tests validate structure/logic, not actual clinical data content

## Sources

### Primary (HIGH confidence)
- [haven CRAN Package](https://cran.r-project.org/web/packages/haven/index.html) - Current version 2.5.5 verified
- [haven Official Documentation](https://haven.tidyverse.org/) - read_sas(), as_factor(), labelled class
- [haven::read_sas Reference](https://haven.tidyverse.org/reference/read_sas.html) - SAS7BDAT import with catalog_file
- [haven Conversion Semantics](https://cran.r-project.org/web/packages/haven/vignettes/semantics.html) - Date conversion, missing values
- [haven Datetimes Vignette](https://rdrr.io/cran/haven/f/vignettes/datetimes.Rmd) - SAS date/datetime conversion details
- [renv Official Documentation](https://rstudio.github.io/renv/) - Package management workflow
- [renv CRAN Package](https://cran.r-project.org/web/packages/renv/index.html) - Version 1.2.2 verified
- [here Official Documentation](https://here.r-lib.org/) - Project-relative paths
- [here CRAN Package](https://cran.r-project.org/web/packages/here/index.html) - Version 1.0.2 verified
- [PCORnet Common Data Model v7.0 Specification](https://pcornet.org/wp-content/uploads/2025/01/PCORnet-Common-Data-Model-v70-2025_01_23.pdf) - Official CDM field definitions

### Secondary (MEDIUM confidence)
- [SAS to R Migration: Appsilon Guide](https://www.appsilon.com/post/transitioning-from-sas-to-r) - Best practices for SAS-to-R conversion
- [Mapping SAS Formats to R – Part 1](https://katalyzedata.com/tips-tricks/mapping-sas-formats-to-r-part-1/) - Format translation strategies
- [janitor::sas_numeric_to_date](https://rdrr.io/cran/janitor/man/sas_numeric_to_date.html) - Manual date conversion helper
- [R Project Structure Best Practices](https://www.r-bloggers.com/2018/08/structuring-r-projects/) - Modular script organization
- [targets Package User Manual](https://books.ropensci.org/targets/) - Advanced pipeline automation (for future consideration)

### Tertiary (LOW confidence — verify before citing)
- [SAS Missing Values vs R NA](https://blogs.sas.com/content/iml/2024/09/16/sas-display-missing-values.html) - Semantic differences (SAS blog, not R-specific)
- [Clinical Data Pipelines with targets](https://bookdown.org/pdr_higgins/rmrwr/building-data-pipelines-with-targets.html) - targets in clinical research (overkill for Phase 1)

## Metadata

**Confidence breakdown:**
- **Standard stack:** HIGH - All packages verified on CRAN with current versions (April 2026). haven is official tidyverse solution with active maintenance.
- **Architecture patterns:** HIGH - Modular script + checkpoint pattern is standard for clinical research pipelines. Verified through multiple sources and clinical research best practices.
- **Format translation:** MEDIUM - Manual translation approach is well-documented, but duplicate $payer forensics requires case-specific analysis not covered in general documentation.
- **Pitfalls:** HIGH - SAS-R semantic differences (missing values, date conversion) are well-documented across multiple authoritative sources. Encoding issues are standard SAS import concern.
- **Environment availability:** HIGH - Verified via direct system checks. R not installed, must be added before execution.

**Research date:** 2026-04-16
**Valid until:** 90 days (July 2026) — haven, renv, here are stable packages with infrequent breaking changes. Revalidate if major R version update (e.g., R 5.0) released.
