# R/02_clean.R
# Data Cleaning: Import encounters, combine, recode variables, handle missing values
# Per D-01: First of two Phase 2 scripts (02_clean.R + 02_merge.R)
# Per D-07: Import encounter1/encounter2 at top using import_sas() from Phase 1
# Per D-03: Payer grouping uses factor() with sas_formats$p_payer (NOT hand-rolled case_when)
# Per D-04: Unmapped payer codes warn with message() and assign "Unknown"
# Per D-05: Data quality assertions use assertr (warn-and-continue mode)
#
# Inputs:  data/raw/encounter1_mobley_v5.sas7bdat
#          data/raw/encounter2_mobley_v5.sas7bdat
#          data/processed/01_formats.rds
#          data/processed/01_imported_dx_parts.rds
#          data/processed/01_imported_proc_parts.rds
# Outputs: data/processed/02_encounters_cleaned.rds
#          data/processed/02_dx_combined.rds
#          data/processed/02_proc_combined.rds

# ========================================
# Section 1 -- Setup
# ========================================

source(here::here("R", "config.R"))
library(tidyverse)
library(haven)
library(janitor)
library(assertr)

# Load Phase 1 format definitions
sas_formats <- readRDS(file.path(data_dir_processed, "01_formats.rds"))

message("========================================")
message("Phase 2: Data Cleaning")
message("Started: ", Sys.time())
message("========================================")

# ========================================
# Section 2 -- import_sas helper (replicated from 01_import.R)
# ========================================

# Replicated from 01_import.R to avoid re-executing all Phase 1 imports when sourcing
#' Import a SAS7BDAT file with standard validation
#' @param filename Character, the .sas7bdat filename (without path)
#' @param data_dir Character, directory containing the file (default: data_dir_raw)
#' @param description Character, human-readable description for logging
#' @return Tibble with clean names and preserved labels
import_sas <- function(filename, data_dir = data_dir_raw, description = filename) {
  filepath <- file.path(data_dir, filename)
  message("  Importing: ", description, " (", filename, ")")

  if (!file.exists(filepath)) {
    warning("File not found: ", filepath, " — skipping. ",
            "Place file in ", data_dir, " and rerun.")
    return(NULL)
  }

  df <- read_sas(data_file = filepath, encoding = sas_encoding)

  # Preserve original labels before clean_names potentially drops them
  original_labels <- purrr::map_chr(df, ~attr(.x, "label") %||% NA_character_)

  # Standardize column names (per CLN-01 prep, janitor convention)
  df <- janitor::clean_names(df)

  # Store original labels as an attribute on the data frame itself
  # (individual column labels may be lost during tidyverse operations per Research pitfall 5)
  attr(df, "sas_labels") <- original_labels

  # Per IMP-03: Check for date columns that should be Date class
  # SAS dates auto-convert via haven if they have DATE format metadata
  # Numeric dates (days since 1960-01-01) need manual conversion
  date_candidates <- names(df)[grepl("date|dt$|_dt$", names(df), ignore.case = TRUE)]
  for (col in date_candidates) {
    if (is.numeric(df[[col]]) && !inherits(df[[col]], "Date")) {
      # Check if values are in plausible SAS date range (days since 1960-01-01)
      # Year 1950 = -3653 days, Year 2030 = 25567 days from 1960 origin
      vals <- df[[col]][!is.na(df[[col]])]
      if (length(vals) > 0 && all(vals > -5000 & vals < 30000)) {
        message("    NOTE: Converting ", col, " from numeric to Date (SAS origin 1960-01-01)")
        message("    # SAS date variable without format metadata - manual conversion applied")
        df[[col]] <- as.Date(df[[col]], origin = "1960-01-01")
      }
    }
  }

  message("    Rows: ", format(nrow(df), big.mark = ","),
          " | Cols: ", ncol(df),
          " | Labels preserved: ", sum(!is.na(original_labels)), "/", length(original_labels))

  return(df)
}

# ========================================
# Section 3 -- Encounter Import (per D-07, CLN-02)
# ========================================

# Per D-07: Import encounter files at top of 02_clean.R (NOT in 01_import.R)
# SAS source: HL_IDS_1_9_2025.sas lines 73-74
# SAS pattern: data encounters; set v3.encounter1_mobley_v5 v3.encounter2_mobley_v5; run;
encounter1 <- import_sas("encounter1_mobley_v5.sas7bdat",
                          description = "Encounter part 1 of 2")
encounter2 <- import_sas("encounter2_mobley_v5.sas7bdat",
                          description = "Encounter part 2 of 2")

# CLN-02: Combine encounters (R equivalent of SAS SET statement)
encounters <- bind_rows(encounter1, encounter2)
message("Encounter rows: ", format(nrow(encounters), big.mark = ","),
        " (", format(nrow(encounter1), big.mark = ","), " + ",
        format(nrow(encounter2), big.mark = ","), ")")

# NOTE: janitor::clean_names() already applied in import_sas() -- do NOT reapply
# Phase 1 pattern: column names are already lowercase snake_case

# ========================================
# Section 4 -- Diagnosis and Procedure Concatenation (per D-02, Claude's discretion)
# ========================================

# Per D-02 (Claude's discretion): dx/proc concatenation placed in 02_clean.R
# Rationale: (1) combining multi-part files is data prep, not a merge/join operation;
# (2) combined datasets are prerequisites for 02_merge.R joins;
# (3) keeps 02_merge.R focused solely on relational join operations.

# Combine multi-part diagnosis data (7 parts -> 1 dataset)
# SAS source: SAS_CODE_FOR_V5_2.sas lines 100-108
# SAS pattern: data v3.diagnosis; set v3.diagnosis_mobley1_v5 ... v3.diagnosis_mobley7_v5; run;
dx_parts <- readRDS(file.path(data_dir_processed, "01_imported_dx_parts.rds"))
dx_combined <- bind_rows(dx_parts)
message("Diagnosis rows: ", format(nrow(dx_combined), big.mark = ","),
        " (from ", length(dx_parts), " parts)")

# Combine multi-part procedure data (4 parts -> 1 dataset)
# SAS source: SAS_CODE_FOR_V5_12.sas line 149
proc_parts <- readRDS(file.path(data_dir_processed, "01_imported_proc_parts.rds"))
proc_combined <- bind_rows(proc_parts)
message("Procedure rows: ", format(nrow(proc_combined), big.mark = ","),
        " (from ", length(proc_parts), " parts)")

# ========================================
# Sections 5-8: Variable recoding and checkpoints (below)
# ========================================

# CLN-04: Document missing value handling strategy
# SAS BUG FIX: SAS treats missing as -Inf in comparisons (missing < any_value is TRUE)
# R uses NA propagation (NA < any_value is NA, filtered out by default)
# RULE: Every filter/conditional in this script uses explicit is.na() checks
# RULE: Document intended behavior for each missing value decision

# Report missing values in key fields
message("\n--- Missing Value Report ---")
message("  encounters$payer_type_primary: ",
        sum(is.na(encounters$payer_type_primary)), " NA / ",
        nrow(encounters), " total")
message("  encounters$enc_type: ",
        sum(is.na(encounters$enc_type)), " NA / ",
        nrow(encounters), " total")
message("  encounters$admit_date: ",
        sum(is.na(encounters$admit_date)), " NA / ",
        nrow(encounters), " total")
message("  encounters$discharge_status: ",
        sum(is.na(encounters$discharge_status)), " NA / ",
        nrow(encounters), " total")

# ========================================
# Section 6 -- CLN-05: Encounter Type and Discharge Recoding
# ========================================

# CLN-05: Recode encounter type, discharge status, discharge disposition
# SAS source: V5_2 lines 62-97 (format enc_type $ENC_TYPE.)
encounters <- encounters %>%
  mutate(
    enc_type_label = factor(enc_type,
                            levels = sas_formats$enc_type$levels,
                            labels = sas_formats$enc_type$labels),
    discharge_status_label = factor(discharge_status,
                                    levels = sas_formats$discharge_status$levels,
                                    labels = sas_formats$discharge_status$labels),
    discharge_disposition_label = factor(discharge_disposition,
                                        levels = sas_formats$discharge_disposition$levels,
                                        labels = sas_formats$discharge_disposition$labels)
  )

# Validate: Check for unlabeled codes (codes not in format definition)
unlabeled_enc <- encounters %>%
  filter(is.na(enc_type_label) & !is.na(enc_type)) %>%
  count(enc_type, name = "n_unlabeled")
if (nrow(unlabeled_enc) > 0) {
  message("WARNING: Unlabeled ENC_TYPE codes found:")
  print(unlabeled_enc)
}

unlabeled_disch <- encounters %>%
  filter(is.na(discharge_status_label) & !is.na(discharge_status)) %>%
  count(discharge_status, name = "n_unlabeled")
if (nrow(unlabeled_disch) > 0) {
  message("WARNING: Unlabeled DISCHARGE_STATUS codes found:")
  print(unlabeled_disch)
}

message("  ENC_TYPE distribution:")
print(janitor::tabyl(encounters, enc_type_label))

# ========================================
# Section 7 -- CLN-03 / CLN-06: Payer Type Recoding (per D-03)
# ========================================

# CLN-03: Recode payer types using sas_formats$p_payer (per D-03)
# Per D-03: Use factor() with Phase 1 sas_formats$p_payer as SINGLE SOURCE OF TRUTH
# Do NOT use hand-rolled case_when() for 170+ payer codes
# SAS source: V5_6 line 30: format payer_type_primary2 $p.;

# Step 1: Extract first character of payer_type_primary for grouping
# SAS $p format maps the FIRST character: "5" -> Private, "1" -> Medicare, etc.
# PCORnet raw codes are multi-digit (e.g., "511" = Commercial HMO)
# The $p format uses single-digit keys that match the FIRST digit of the raw code
encounters <- encounters %>%
  mutate(
    # Extract first character for p_payer grouping
    payer_primary_code = substr(payer_type_primary, 1, 1),
    # CLN-06: Also handle dual eligibility (code starts with "4")
    # Special case: NA payer_type_primary -> use "U" (Unknown) per D-04
    payer_primary_code = case_when(
      is.na(payer_type_primary) ~ "U",
      TRUE ~ payer_primary_code
    )
  )

# Apply the $p format via factor()
encounters <- encounters %>%
  mutate(
    payer_primary_grouped = factor(payer_primary_code,
                                   levels = sas_formats$p_payer$levels,
                                   labels = sas_formats$p_payer$labels)
  )

# Per D-04: Unmapped codes -> warn with message() and assign "Unknown"
unmapped_payer <- encounters %>%
  filter(is.na(payer_primary_grouped) & !is.na(payer_type_primary)) %>%
  count(payer_type_primary, name = "n_unmapped")

if (nrow(unmapped_payer) > 0) {
  message("WARNING: Unmapped payer codes found (assigning 'Unknown' per D-04):")
  print(unmapped_payer)
  encounters <- encounters %>%
    mutate(
      payer_primary_grouped = if_else(
        is.na(payer_primary_grouped) & !is.na(payer_type_primary),
        factor("Unknown", levels = levels(payer_primary_grouped)),
        payer_primary_grouped
      )
    )
}

# CLN-06: Apply same grouping to secondary payer
encounters <- encounters %>%
  mutate(
    payer_secondary_code = case_when(
      is.na(payer_type_secondary) ~ "U",
      TRUE ~ substr(payer_type_secondary, 1, 1)
    ),
    payer_secondary_grouped = factor(payer_secondary_code,
                                     levels = sas_formats$p_payer$levels,
                                     labels = sas_formats$p_payer$labels)
  )

# CLN-06: Also apply the payerr collapsed classification
encounters <- encounters %>%
  mutate(
    payer_primary_collapsed = factor(payer_primary_code,
                                     levels = sas_formats$payerr$levels,
                                     labels = sas_formats$payerr$labels),
    payer_primary_public = factor(payer_primary_code,
                                  levels = sas_formats$payerrr$levels,
                                  labels = sas_formats$payerrr$labels)
  )

# CLN-06 validation: Dual Medicare/Medicaid check
dual_check <- encounters %>%
  filter(payer_primary_code == "4") %>%
  count(payer_primary_grouped, name = "n_dual")
message("\nDual Medicare/Medicaid mapping check:")
if (nrow(dual_check) > 0) {
  print(dual_check)
} else {
  message("  No dual eligibility codes found in data")
}

message("\nPayer primary grouped distribution:")
print(janitor::tabyl(encounters, payer_primary_grouped))

# ========================================
# Section 8 -- Save Checkpoints
# ========================================

# Save cleaned encounters checkpoint (per D-01: intermediate .rds between scripts)
saveRDS(encounters, file.path(data_dir_processed, "02_encounters_cleaned.rds"))
message("\nSaved: 02_encounters_cleaned.rds (",
        format(nrow(encounters), big.mark = ","), " rows, ",
        ncol(encounters), " cols)")

# Save combined diagnosis and procedure datasets
saveRDS(dx_combined, file.path(data_dir_processed, "02_dx_combined.rds"))
message("Saved: 02_dx_combined.rds (",
        format(nrow(dx_combined), big.mark = ","), " rows)")

saveRDS(proc_combined, file.path(data_dir_processed, "02_proc_combined.rds"))
message("Saved: 02_proc_combined.rds (",
        format(nrow(proc_combined), big.mark = ","), " rows)")

message("\n========================================")
message("Phase 2 Cleaning complete: ", Sys.time())
message("========================================")
message("Next step: R/02_merge.R")
