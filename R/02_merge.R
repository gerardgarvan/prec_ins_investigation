# R/02_merge.R
# Data Merging: Join encounters with per-encounter dx flags and provider data
# Per D-01: Second of two Phase 2 scripts (02_clean.R -> 02_merge.R)
# Per D-05: Post-merge data quality assertions use assertr (warn-and-continue)
# Per MRG-02: Row counts logged before/after every merge operation
# Per MRG-03: dplyr relationship argument enforces join cardinality
#
# OOM change vs. prior version:
#   - No longer loads 02_dx_combined.rds or 02_proc_combined.rds (50+ GB each)
#   - Joins encounters to 02_dx_encounter.rds (one row per patid+encounterid)
#     with relationship = "one-to-one" — result is same shape as encounters
#   - Removes 02_merged_enc_dx.rds and 02_merged_enc_proc.rds (no longer produced)
#
# Inputs:  data/processed/02_encounters_cleaned.rds   (from 02_clean.R)
#          data/processed/02_dx_encounter.rds          (from 02_clean.R)
#          data/processed/01_imported_provider.rds      (from Phase 1)
# Outputs: data/processed/02_provider_full.rds
#          data/processed/02_merged_complete.rds
#            One row per encounter.  Carries all encounter columns plus:
#            any_reportable_cancer, icd_personal_trt, cancer_dx, group_site
#            (from dx_encounter) and provider specialty columns (from provider).

# ========================================
# Section 1 -- Setup
# ========================================

library(here)
source(here::here("R", "config.R"))
library(tidyverse)
library(janitor)
library(assertr)

message("========================================")
message("Phase 2: Data Merging")
message("Started: ", Sys.time())
message("========================================")

# ========================================
# Section 2 -- Load Checkpoints
# ========================================

encounters  <- readRDS(file.path(data_dir_processed, "02_encounters_cleaned.rds"))
dx_encounter <- readRDS(file.path(data_dir_processed, "02_dx_encounter.rds"))
provider    <- readRDS(file.path(data_dir_processed, "01_imported_provider.rds"))

message("Loaded datasets:")
message("  encounters:   ", format(nrow(encounters),   big.mark = ","), " rows")
message("  dx_encounter: ", format(nrow(dx_encounter), big.mark = ","), " rows (unique patid+encounterid)")
message("  provider:     ", format(nrow(provider),     big.mark = ","), " rows")

# ========================================
# Section 3 -- logged_join() Helper (per MRG-02)
# ========================================

logged_join <- function(x, y, by, type = "left", relationship = NULL, desc = "") {
  n_x <- nrow(x)
  n_y <- nrow(y)
  message("\n=== Join: ", desc, " ===")
  message("  Type: ", type, "_join")
  message("  Keys: ", paste(by, collapse = ", "))
  message("  Left rows: ",  format(n_x, big.mark = ","))
  message("  Right rows: ", format(n_y, big.mark = ","))

  result <- switch(type,
    "left"  = left_join(x, y,  by = by, relationship = relationship),
    "inner" = inner_join(x, y, by = by, relationship = relationship),
    "right" = right_join(x, y, by = by, relationship = relationship),
    "full"  = full_join(x, y,  by = by, relationship = relationship)
  )

  n_result <- nrow(result)
  growth   <- round(n_result / n_x, 2)
  message("  Result rows: ", format(n_result, big.mark = ","))
  message("  Growth: ", growth, "x")

  if (growth > 5) {
    warning("MERGE WARNING: Row count grew by >5x (", growth, "x). ",
            "Check for duplicate join keys or incorrect relationship specification.")
  }
  result
}

# ========================================
# Section 4 -- Pre-Merge Duplicate Detection (per MRG-03)
# ========================================

enc_dupes <- encounters %>% janitor::get_dupes(encounterid)
if (nrow(enc_dupes) > 0) {
  message("WARNING: Non-unique ENCOUNTERID in encounters (",
          n_distinct(enc_dupes$encounterid), " affected). Deduplicating.")
  encounters <- encounters %>% distinct(encounterid, .keep_all = TRUE)
  message("  After dedup: ", format(nrow(encounters), big.mark = ","), " rows")
} else {
  message("Encounter ENCOUNTERID uniqueness: OK")
}

# dx_encounter should be unique by (patid, encounterid) — verify
dx_dupes <- dx_encounter %>% janitor::get_dupes(patid, encounterid)
if (nrow(dx_dupes) > 0) {
  message("WARNING: Non-unique (patid, encounterid) in dx_encounter. Deduplicating.")
  dx_encounter <- dx_encounter %>% distinct(patid, encounterid, .keep_all = TRUE)
}

# ========================================
# Section 5 -- Merge 1: Encounters + dx_encounter (one-to-one)
# ========================================

# MRG-01: Join encounters to per-encounter dx flags.
# relationship = "one-to-one": every encounterid in dx_encounter maps to at most
# one row in encounters (and vice versa).  Row count does NOT grow.
# Encounters without any diagnosis rows will have NA dx columns (left join).
enc_with_dx <- logged_join(
  encounters, dx_encounter,
  by   = c("patid", "encounterid"),
  type = "left",
  relationship = "one-to-one",
  desc = "Encounters + dx_encounter flags (one-to-one)"
)

message("  any_reportable_cancer=1 in merged: ",
        sum(enc_with_dx$any_reportable_cancer == 1L, na.rm = TRUE))

# ========================================
# Section 6 -- Merge 2: Provider
# ========================================

# Consolidate provider data (no separate prov_spec file in V5 — provider table
# already includes specialty; see 01_import.R Group 3 comment).
# Keep provider as-is for the providerid join.
provider_full <- provider
saveRDS(provider_full, file.path(data_dir_processed, "02_provider_full.rds"))
message("Saved: 02_provider_full.rds (", format(nrow(provider_full), big.mark = ","), " rows)")

# ========================================
# Section 7 -- Merge 3: Encounters+Dx + Provider (many-to-one)
# ========================================

# MRG-01: Add provider info.  Many encounters may share a provider.
enc_dx_prov <- logged_join(
  enc_with_dx, provider_full,
  by   = "providerid",
  type = "left",
  relationship = "many-to-one",
  desc = "Enc+Dx + Provider (MRG-01)"
)

saveRDS(enc_dx_prov, file.path(data_dir_processed, "02_merged_complete.rds"))
message("Saved: 02_merged_complete.rds")

# ========================================
# Section 8 -- Post-Merge Data Quality Assertions (per MRG-04, D-05)
# ========================================

message("\n=== Post-Merge Data Quality Assertions ===")

n_patients_original <- n_distinct(encounters$patid)
n_patients_merged   <- n_distinct(enc_dx_prov$patid)
message("Patient count: original=", n_patients_original,
        ", after merge=", n_patients_merged)
if (n_patients_original != n_patients_merged) {
  warning("MRG-04 ASSERTION FAILED: Patient count changed after merge! ",
          "Original: ", n_patients_original, ", Merged: ", n_patients_merged)
}

tryCatch({
  enc_dx_prov %>%
    assertr::verify(!is.na(encounterid),
                    description = "No missing ENCOUNTERIDs after merge")
  message("PASS: No missing ENCOUNTERIDs")
}, error = function(e) {
  warning("MRG-04 ASSERTION FAILED: Missing ENCOUNTERIDs detected. ", conditionMessage(e))
})

tryCatch({
  enc_dx_prov %>%
    assertr::verify(!is.na(patid),
                    description = "No missing PATIDs after merge")
  message("PASS: No missing PATIDs")
}, error = function(e) {
  warning("MRG-04 ASSERTION FAILED: Missing PATIDs detected. ", conditionMessage(e))
})

tryCatch({
  enc_dx_prov %>%
    filter(!is.na(admit_date)) %>%
    assertr::insist(
      assertr::within_bounds(as.Date("2000-01-01"), Sys.Date()),
      admit_date,
      description = "ADMIT_DATE within plausible range (2000-present)"
    )
  message("PASS: ADMIT_DATE within plausible range")
}, error = function(e) {
  warning("MRG-04 ASSERTION FAILED: ADMIT_DATE out of range. ", conditionMessage(e))
})

sas_formats <- readRDS(file.path(data_dir_processed, "01_formats.rds"))
valid_enc_types <- c(sas_formats$enc_type$levels, NA_character_)
invalid_enc_types <- enc_dx_prov %>%
  filter(!enc_type %in% valid_enc_types) %>%
  count(enc_type, name = "n_invalid")
if (nrow(invalid_enc_types) > 0) {
  warning("MRG-04 ASSERTION: Invalid ENC_TYPE codes found:")
  print(invalid_enc_types)
} else {
  message("PASS: All ENC_TYPE values are valid PCORnet codes")
}

# ========================================
# Section 9 -- Summary Report
# ========================================

message("\n========================================")
message("Phase 2 Merging complete: ", Sys.time())
message("========================================")
message("\nMERGED DATASET SUMMARY:")
message("  02_merged_complete.rds:  ", format(nrow(enc_dx_prov), big.mark = ","), " rows",
        " (one per encounter; no row inflation from dx join)")
message("  02_provider_full.rds:    ", format(nrow(provider_full), big.mark = ","), " rows")
message("  Unique patients:          ", format(n_distinct(enc_dx_prov$patid), big.mark = ","))
message("  Unique encounters:        ", format(n_distinct(enc_dx_prov$encounterid), big.mark = ","))
message("  Encounters with cancer dx:", format(sum(enc_dx_prov$any_reportable_cancer == 1L, na.rm = TRUE), big.mark = ","))
message("\nNOTE: 02_merged_enc_dx.rds and 02_merged_enc_proc.rds are no longer produced.")
message("  Use 02_merged_complete.rds (one row per encounter) for all Phase 3 scripts.")
message("\nNext step: Phase 3 (Analytical Dataset Construction)")
