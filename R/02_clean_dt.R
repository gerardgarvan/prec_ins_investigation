# R/02_clean_dt.R
# Data Cleaning — data.table version of 02_clean.R
# Drop-in replacement if dplyr version OOMs on encounter bind + recode.
#
# Key differences from 02_clean.R:
#   - rbindlist() instead of bind_rows() (faster, lower overhead)
#   - := operator recodes in place — no data copy during mutate
#   - Outputs identical files: 02_encounters_cleaned.rds, 02_dx_combined.rds,
#     02_proc_combined.rds — downstream scripts (02_merge.R etc.) are unchanged
#
# To activate: rename this file to 02_clean.R (back up the original first)

# ========================================
# Section 1 -- Setup
# ========================================

library(here)
source(here::here("R", "config.R"))
library(tidyverse)   # still needed for downstream scripts and format objects
library(data.table)
library(haven)
library(janitor)
library(assertr)

# Load Phase 1 format definitions
sas_formats <- readRDS(file.path(data_dir_processed, "01_formats.rds"))

message("========================================")
message("Phase 2: Data Cleaning (data.table)")
message("Started: ", Sys.time())
message("========================================")

# ========================================
# Section 2 -- Import helpers
# ========================================

source(here::here("R", "utils_import.R"))

# ========================================
# Section 3 -- Encounter Load (CLN-02)
# ========================================

enc_cols_needed <- c(
  "patid", "encounterid", "providerid",
  "enc_type", "admit_date", "discharge_date",
  "discharge_status", "discharge_disposition",
  "payer_type_primary", "payer_type_secondary"
)

enc_part_files <- sort(list.files(data_dir_processed,
                                   pattern = "01_imported_enc_part\\d+\\.rds",
                                   full.names = TRUE))

# Read each part, narrow to needed columns, convert to data.table in one pass.
# rbindlist() allocates the final table once — no intermediate copies.
encounters <- rbindlist(
  lapply(enc_part_files, function(f) {
    part <- readRDS(f)
    as.data.table(part)[, intersect(enc_cols_needed, names(part)), with = FALSE]
  }),
  use.names = TRUE, fill = TRUE
)
rm(enc_part_files); gc(verbose = FALSE)
message("Encounter rows: ", format(nrow(encounters), big.mark = ","),
        " | cols: ", ncol(encounters))

# ========================================
# Section 4 -- Diagnosis and Procedure Concatenation
# ========================================

dx_part_files <- sort(list.files(data_dir_processed,
                                  pattern = "01_imported_dx_part\\d+\\.rds",
                                  full.names = TRUE))
dx_combined <- rbindlist(lapply(dx_part_files, function(f) as.data.table(readRDS(f))),
                          use.names = TRUE, fill = TRUE)
message("Diagnosis rows: ", format(nrow(dx_combined), big.mark = ","),
        " (from ", length(dx_part_files), " parts)")
saveRDS(dx_combined, file.path(data_dir_processed, "02_dx_combined.rds"))
message("Saved: 02_dx_combined.rds")
rm(dx_combined, dx_part_files); gc(verbose = FALSE)

proc_part_files <- sort(list.files(data_dir_processed,
                                    pattern = "01_imported_proc_part\\d+\\.rds",
                                    full.names = TRUE))
proc_combined <- rbindlist(lapply(proc_part_files, function(f) as.data.table(readRDS(f))),
                            use.names = TRUE, fill = TRUE)
message("Procedure rows: ", format(nrow(proc_combined), big.mark = ","),
        " (from ", length(proc_part_files), " parts)")
saveRDS(proc_combined, file.path(data_dir_processed, "02_proc_combined.rds"))
message("Saved: 02_proc_combined.rds")
rm(proc_combined, proc_part_files); gc(verbose = FALSE)

# ========================================
# Section 5 -- Missing Value Report (CLN-04)
# ========================================

# SAS BUG FIX: SAS treats missing as -Inf; R uses NA propagation.
# Every filter/conditional uses explicit is.na() checks.

message("\n--- Missing Value Report ---")
for (col in c("payer_type_primary", "enc_type", "admit_date", "discharge_status")) {
  if (col %in% names(encounters)) {
    message("  encounters$", col, ": ",
            sum(is.na(encounters[[col]])), " NA / ",
            nrow(encounters), " total")
  }
}

# ========================================
# Section 6 -- CLN-05: Encounter Type and Discharge Recoding
# ========================================

# := recodes in place — no copy of encounters is made
encounters[, enc_type_label := factor(enc_type,
                                       levels = sas_formats$enc_type$levels,
                                       labels = sas_formats$enc_type$labels)]

encounters[, discharge_status_label := factor(discharge_status,
                                               levels = sas_formats$discharge_status$levels,
                                               labels = sas_formats$discharge_status$labels)]

encounters[, discharge_disposition_label := factor(discharge_disposition,
                                                    levels = sas_formats$discharge_disposition$levels,
                                                    labels = sas_formats$discharge_disposition$labels)]

# Validate unlabeled codes
unlabeled_enc <- encounters[is.na(enc_type_label) & !is.na(enc_type),
                             .N, by = enc_type]
if (nrow(unlabeled_enc) > 0) {
  message("WARNING: Unlabeled ENC_TYPE codes found:")
  print(unlabeled_enc)
}

unlabeled_disch <- encounters[is.na(discharge_status_label) & !is.na(discharge_status),
                               .N, by = discharge_status]
if (nrow(unlabeled_disch) > 0) {
  message("WARNING: Unlabeled DISCHARGE_STATUS codes found:")
  print(unlabeled_disch)
}

message("  ENC_TYPE distribution:")
print(janitor::tabyl(encounters, enc_type_label))

# ========================================
# Section 7 -- CLN-03 / CLN-06: Payer Type Recoding (per D-03)
# ========================================

# Extract first character; NA payer -> "U" per D-04
encounters[, payer_primary_code := fifelse(
  is.na(payer_type_primary), "U", substr(payer_type_primary, 1, 1)
)]

encounters[, payer_primary_grouped := factor(payer_primary_code,
                                              levels = sas_formats$p_payer$levels,
                                              labels = sas_formats$p_payer$labels)]

# Per D-04: unmapped codes -> warn and assign "Unknown"
unmapped_payer <- encounters[is.na(payer_primary_grouped) & !is.na(payer_type_primary),
                              .N, by = payer_type_primary]
if (nrow(unmapped_payer) > 0) {
  message("WARNING: Unmapped payer codes found (assigning 'Unknown' per D-04):")
  print(unmapped_payer)
  encounters[is.na(payer_primary_grouped) & !is.na(payer_type_primary),
             payer_primary_grouped := factor("Unknown",
                                             levels = levels(encounters$payer_primary_grouped))]
}

# CLN-06: Secondary payer
encounters[, payer_secondary_code := fifelse(
  is.na(payer_type_secondary), "U", substr(payer_type_secondary, 1, 1)
)]
encounters[, payer_secondary_grouped := factor(payer_secondary_code,
                                                levels = sas_formats$p_payer$levels,
                                                labels = sas_formats$p_payer$labels)]

# CLN-06: Collapsed and public payer classifications
encounters[, payer_primary_collapsed := factor(payer_primary_code,
                                                levels = sas_formats$payerr$levels,
                                                labels = sas_formats$payerr$labels)]
encounters[, payer_primary_public := factor(payer_primary_code,
                                             levels = sas_formats$payerrr$levels,
                                             labels = sas_formats$payerrr$labels)]

# Dual Medicare/Medicaid check
dual_check <- encounters[payer_primary_code == "4", .N, by = payer_primary_grouped]
message("\nDual Medicare/Medicaid mapping check:")
if (nrow(dual_check) > 0) print(dual_check) else message("  No dual eligibility codes found")

message("\nPayer primary grouped distribution:")
print(janitor::tabyl(encounters, payer_primary_grouped))

# ========================================
# Section 8 -- Save Checkpoints
# ========================================

# Convert back to plain data.frame for RDS compatibility with downstream dplyr scripts
saveRDS(as.data.frame(encounters),
        file.path(data_dir_processed, "02_encounters_cleaned.rds"))
message("\nSaved: 02_encounters_cleaned.rds (",
        format(nrow(encounters), big.mark = ","), " rows, ",
        ncol(encounters), " cols)")

# dx_combined and proc_combined already saved and freed after Section 4

message("\n========================================")
message("Phase 2 Cleaning complete: ", Sys.time())
message("========================================")
message("Next step: R/02_merge.R")
