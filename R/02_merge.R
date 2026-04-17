# R/02_merge.R
# Data Merging: Join encounters with diagnoses, procedures, and provider data
# Per D-01: Second of two Phase 2 scripts (02_clean.R -> 02_merge.R)
# Per D-05: Post-merge data quality assertions use assertr (warn-and-continue)
# Per MRG-02: Row counts logged before/after every merge operation
# Per MRG-03: dplyr relationship argument enforces join cardinality
#
# CRITICAL: SAS MERGE vs dplyr join semantics differ for many-to-many:
#   SAS MERGE: max(m, n) rows
#   dplyr join: m * n rows (Cartesian product)
#   FIX: Use relationship argument on every join
#
# Inputs:  data/processed/02_encounters_cleaned.rds (from 02_clean.R)
#          data/processed/02_dx_combined.rds (from 02_clean.R)
#          data/processed/02_proc_combined.rds (from 02_clean.R)
#          data/processed/01_imported_provider.rds (from Phase 1)
#          data/processed/01_imported_prov_spec.rds (from Phase 1)
# Outputs: data/processed/02_merged_enc_dx.rds
#          data/processed/02_merged_enc_proc.rds
#          data/processed/02_provider_full.rds
#          data/processed/02_merged_complete.rds

# ========================================
# Section 1 -- Setup
# ========================================

source("/home/ggarvan/prec_ins_investigation/R/config.R")
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

# Load Phase 2 cleaning outputs
encounters <- readRDS(file.path(data_dir_processed, "02_encounters_cleaned.rds"))
dx_combined <- readRDS(file.path(data_dir_processed, "02_dx_combined.rds"))
proc_combined <- readRDS(file.path(data_dir_processed, "02_proc_combined.rds"))

# Load Phase 1 provider data
provider <- readRDS(file.path(data_dir_processed, "01_imported_provider.rds"))
prov_spec <- readRDS(file.path(data_dir_processed, "01_imported_prov_spec.rds"))

message("Loaded datasets:")
message("  encounters: ", format(nrow(encounters), big.mark = ","), " rows")
message("  dx_combined: ", format(nrow(dx_combined), big.mark = ","), " rows")
message("  proc_combined: ", format(nrow(proc_combined), big.mark = ","), " rows")
message("  provider: ", format(nrow(provider), big.mark = ","), " rows")
message("  prov_spec: ", format(nrow(prov_spec), big.mark = ","), " rows")

# ========================================
# Section 3 -- logged_join() Helper (per MRG-02)
# ========================================

# MRG-02: Logged join helper — wraps every merge with row count tracking
# Per Research Pattern 6: Log before/after counts for every join operation
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
  growth <- round(n_result / n_x, 2)
  message("  Result rows: ", format(n_result, big.mark = ","))
  message("  Growth: ", growth, "x")

  # MRG-03: Warn on suspicious growth (possible Cartesian product)
  if (growth > 20) {
    warning("MERGE WARNING: Row count grew by >20x (",
            growth, "x). Possible Cartesian product. ",
            "Check for duplicate join keys or incorrect relationship specification.")
  }

  return(result)
}

# ========================================
# Section 4 -- Pre-Merge Duplicate Detection (per MRG-03)
# ========================================

# MRG-03: Check for duplicate join keys BEFORE merging
# Prevents silent Cartesian products from undetected duplicates

# Check encounter uniqueness on encounterid
enc_dupes <- encounters %>% janitor::get_dupes(encounterid)
if (nrow(enc_dupes) > 0) {
  message("WARNING: Non-unique ENCOUNTERID in encounters:")
  message("  Duplicate rows: ", nrow(enc_dupes))
  message("  Affected encounters: ", n_distinct(enc_dupes$encounterid))
  # Keep first occurrence (SAS behavior with PROC SORT NODUPKEY)
  encounters <- encounters %>% distinct(encounterid, .keep_all = TRUE)
  message("  After dedup: ", format(nrow(encounters), big.mark = ","), " rows")
} else {
  message("Encounter ENCOUNTERID uniqueness: OK")
}

# Check diagnosis for expected one-to-many relationship
dx_per_enc <- dx_combined %>%
  count(encounterid, name = "n_dx") %>%
  summarise(
    mean_dx = mean(n_dx),
    max_dx = max(n_dx),
    median_dx = median(n_dx)
  )
message("Diagnoses per encounter: mean=", round(dx_per_enc$mean_dx, 1),
        ", median=", dx_per_enc$median_dx,
        ", max=", dx_per_enc$max_dx)

# ========================================
# Section 5 -- Merge 1: Encounters + Diagnoses (per MRG-01)
# ========================================

# MRG-01: Merge encounters with diagnoses
# PCORnet CDM join keys: patid + encounterid
# Relationship: one encounter to many diagnoses (one-to-many)
# SAS source: V5_3 lines 11-27 (demo inner join diagnosis on id)
enc_with_dx <- logged_join(
  encounters, dx_combined,
  by = c("patid", "encounterid"),
  type = "left",
  relationship = "one-to-many",
  desc = "Encounters + Diagnoses (MRG-01)"
)

# Save intermediate checkpoint
saveRDS(enc_with_dx, file.path(data_dir_processed, "02_merged_enc_dx.rds"))
message("Saved: 02_merged_enc_dx.rds")

# ========================================
# Section 6 -- Merge 2: Encounters + Procedures
# ========================================

# MRG-01: Add procedures to encounter-diagnosis merged data
# Join on encounterid. Since enc_with_dx already has multiple rows per encounter
# (from diagnosis join), this is now many-to-many on encounterid
# but one-to-many when considering the full key
# Strategy: Join procedures to the ORIGINAL encounters first, then combine

# Alternative approach: join procedures to original encounters separately,
# then combine diagnosis and procedure flags at patient level later (Phase 3)
# For now, store procedure data as separate merged checkpoint

enc_with_proc <- logged_join(
  encounters, proc_combined,
  by = c("patid", "encounterid"),
  type = "left",
  relationship = "one-to-many",
  desc = "Encounters + Procedures (MRG-01)"
)

saveRDS(enc_with_proc, file.path(data_dir_processed, "02_merged_enc_proc.rds"))
message("Saved: 02_merged_enc_proc.rds")

# ========================================
# Section 7 -- Merge 3: Provider + Provider Specialty
# ========================================

# MRG-01: Merge provider with provider specialty reference
# SAS source: V5_2 lines 11-20 (provider left join prov_spec on provider_specialty_primary)
provider_full <- logged_join(
  provider, prov_spec,
  by = "provider_specialty_primary",
  type = "left",
  relationship = "many-to-one",
  desc = "Provider + Provider Specialty (MRG-01)"
)

# Save provider reference for Phase 3 use
saveRDS(provider_full, file.path(data_dir_processed, "02_provider_full.rds"))
message("Saved: 02_provider_full.rds")

# ========================================
# Section 8 -- Merge 4: Encounters + Provider Info
# ========================================

# MRG-01: Add provider info to encounter-diagnosis data
enc_dx_prov <- logged_join(
  enc_with_dx, provider_full,
  by = "providerid",
  type = "left",
  relationship = "many-to-one",
  desc = "Enc+Dx + Provider (MRG-01)"
)

# This is the complete merged dataset for Phase 2
saveRDS(enc_dx_prov, file.path(data_dir_processed, "02_merged_complete.rds"))
message("Saved: 02_merged_complete.rds")

# ========================================
# Section 9 -- Post-Merge Data Quality Assertions (per MRG-04, D-05)
# ========================================

# MRG-04: Data quality assertions using assertr (per D-05)
# Per D-05: On assertion failure -> warn and continue (do not halt pipeline)
message("\n=== Post-Merge Data Quality Assertions ===")

# Assertion 1: Patient count preserved through merges
n_patients_original <- n_distinct(encounters$patid)
n_patients_merged <- n_distinct(enc_dx_prov$patid)
message("Patient count: original=", n_patients_original,
        ", after merge=", n_patients_merged)
if (n_patients_original != n_patients_merged) {
  warning("MRG-04 ASSERTION FAILED: Patient count changed after merge! ",
          "Original: ", n_patients_original, ", Merged: ", n_patients_merged)
}

# Assertion 2: No NA encounterids (should never happen after join)
tryCatch({
  enc_dx_prov %>%
    assertr::verify(
      !is.na(encounterid),
      description = "No missing ENCOUNTERIDs after merge"
    )
  message("PASS: No missing ENCOUNTERIDs")
}, error = function(e) {
  warning("MRG-04 ASSERTION FAILED: Missing ENCOUNTERIDs detected. ", conditionMessage(e))
})

# Assertion 3: No NA patids
tryCatch({
  enc_dx_prov %>%
    assertr::verify(
      !is.na(patid),
      description = "No missing PATIDs after merge"
    )
  message("PASS: No missing PATIDs")
}, error = function(e) {
  warning("MRG-04 ASSERTION FAILED: Missing PATIDs detected. ", conditionMessage(e))
})

# Assertion 4: admit_date within plausible range (if not NA)
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

# Assertion 5: enc_type values are valid PCORnet codes
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
# Section 10 -- Summary Report
# ========================================

# Final summary
message("\n========================================")
message("Phase 2 Merging complete: ", Sys.time())
message("========================================")
message("\nMERGED DATASETS SUMMARY:")
message("  02_merged_enc_dx.rds: ", format(nrow(enc_with_dx), big.mark = ","), " rows")
message("  02_merged_enc_proc.rds: ", format(nrow(enc_with_proc), big.mark = ","), " rows")
message("  02_provider_full.rds: ", format(nrow(provider_full), big.mark = ","), " rows")
message("  02_merged_complete.rds: ", format(nrow(enc_dx_prov), big.mark = ","), " rows")
message("  Unique patients: ", format(n_distinct(enc_dx_prov$patid), big.mark = ","))
message("  Unique encounters: ", format(n_distinct(enc_dx_prov$encounterid), big.mark = ","))
message("\nNext step: Phase 3 (Analytical Dataset Construction)")
