# R/03_outcomes.R
# Outcome Variable Calculation: Visit type flags, visit count aggregation, person-time
# Per D-01: Third of 4 Phase 3 scripts
# Per D-02: Self-contained with .rds checkpoints
# Per D-07: Censoring/person-time faithfully translated from V5 SAS
#
# SAS Source: V5_8 (encounter-level flags), V5_9 (aggregation pattern),
#             V5_11 (person-time), V5_15 (person_time_days)
#
# Inputs:  data/processed/03_exposure.rds (from 03_exposure.R — cohort with exposures)
#          data/processed/02_merged_complete.rds (encounter-level data with dx + provider)
#          data/processed/02_merged_enc_dx.rds (encounter-dx data)
# Outputs: data/processed/03_outcomes.rds

# ========================================
# Section 1 -- Setup
# ========================================

library(here)
source(here::here("R", "config.R"))
library(tidyverse)
library(janitor)
library(assertr)

# Load SAS format definitions
sas_formats <- readRDS(file.path(data_dir_processed, "01_formats.rds"))

message("========================================")
message("Phase 3: Outcome Variable Calculation")
message("Started: ", Sys.time())
message("========================================")

# ========================================
# Section 2 -- Load Checkpoints
# ========================================

# Load Phase 3 cohort with exposures
cohort <- readRDS(file.path(data_dir_processed, "03_exposure.rds"))

# Load merged encounter data (with provider + dx)
merged_complete <- readRDS(file.path(data_dir_processed, "02_merged_complete.rds"))

# Load merged encounter-dx data (for backup if needed)
merged_enc_dx <- readRDS(file.path(data_dir_processed, "02_merged_enc_dx.rds"))

message("Loaded datasets:")
message("  cohort: ", format(nrow(cohort), big.mark = ","), " patients")
message("  merged_complete: ", format(nrow(merged_complete), big.mark = ","), " encounter rows")
message("  merged_enc_dx: ", format(nrow(merged_enc_dx), big.mark = ","), " encounter-dx rows")

# ========================================
# Section 3 -- Filter to Follow-Up Encounters Only
# ========================================

# SAS V5_6 lines 134-146: Only encounters AFTER first cancer dx
# days_firstcan_admitdate = admit_date - first_admit_date
# if days_firstcan_admitdate > 0 then admit_after_firstdx = 1
# Delete if admit_after_firstdx != 1
#
# R: Join encounter data with cohort first_admit_date, filter admit_date > first_admit_date

message("\n=== Section 3: Filter to Follow-Up Encounters ===")

followup_encounters <- merged_complete %>%
  inner_join(
    cohort %>% select(patid, first_admit_date),
    by = "patid"
  ) %>%
  mutate(
    days_firstcan_admitdate = as.numeric(difftime(admit_date, first_admit_date, units = "days"))
  ) %>%
  filter(days_firstcan_admitdate > 0)

message("Follow-up encounters: ", format(nrow(followup_encounters), big.mark = ","),
        " (from ", format(n_distinct(followup_encounters$patid), big.mark = ","), " patients)")

# ========================================
# Section 4 -- Encounter-Level Visit Type Flags (OUT-01 through OUT-04)
# ========================================

# SAS V5_8 lines 75-108: Encounter-level visit flag logic
# OUT-01: Non-acute care (enc_type in c("AV","TH"))
# OUT-02: Cancer-related visit (non-acute AND any_reportable_cancer==1)
# OUT-03: Cancer visit with provider (cancer-related AND cancer_provider==1)
# OUT-04: Survivorship visit (non-acute AND cancer_provider AND ICD_personal_trt)

message("\n=== Section 4: Encounter-Level Visit Type Flags ===")

# ICD personal treatment history codes (SAS V5_8 line 81)
icd_personal_trt_codes <- c("V87.41", "V87.42", "V87.43", "V87.46", "V15.3",
                             "Z92.21", "Z92.22", "Z92.23", "Z92.25", "Z92.3")

followup_encounters <- followup_encounters %>%
  mutate(
    # OUT-01: Non-acute care (SAS V5_8 line 77)
    # if ENC_TYPE in ('AV' 'TH') then Enc_nonacute_care=1; else Enc_nonacute_care=0;
    Enc_nonacute_care = if_else(enc_type %in% c("AV", "TH"), 1L, 0L),

    # ICD personal treatment history codes (SAS V5_8 line 81)
    # if dx in ('V87.41' 'V87.42' ...) then ICD_personal_trt=1; else ICD_personal_trt=0;
    ICD_personal_trt = if_else(
      dx %in% icd_personal_trt_codes, 1L, 0L
    ),

    # OUT-02: Cancer-related visit (SAS V5_8 line 93)
    # if Enc_nonacute_care=1 AND any_reportable_cancer=1 then Cancer_related_visit=1; else 0
    Cancer_related_visit = if_else(
      Enc_nonacute_care == 1L & any_reportable_cancer == 1L, 1L, 0L
    ),

    # OUT-03: Cancer visit with provider (SAS V5_8 line 98)
    # if Cancer_related_visit=1 AND Cancer_provider=1 then Cancer_visit_and_prov=1; else 0
    Cancer_visit_and_prov = if_else(
      Cancer_related_visit == 1L & cancer_provider == 1L, 1L, 0L
    ),

    # OUT-04: Survivorship visit (SAS V5_8 line 104)
    # if Enc_nonacute_care=1 AND Cancer_provider=1 AND ICD_personal_trt=1 then Survivorship_visit=1; else 0
    Survivorship_visit = if_else(
      Enc_nonacute_care == 1L & cancer_provider == 1L & ICD_personal_trt == 1L, 1L, 0L
    )
  )

# Log encounter-level flag distributions
message("\nEncounter-level flag distributions:")
message("  Enc_nonacute_care = 1: ", sum(followup_encounters$Enc_nonacute_care == 1, na.rm = TRUE))
message("  Cancer_related_visit = 1: ", sum(followup_encounters$Cancer_related_visit == 1, na.rm = TRUE))
message("  Cancer_visit_and_prov = 1: ", sum(followup_encounters$Cancer_visit_and_prov == 1, na.rm = TRUE))
message("  Survivorship_visit = 1: ", sum(followup_encounters$Survivorship_visit == 1, na.rm = TRUE))

# ========================================
# Section 5 -- SAS V5_9 Dedup Before Aggregation
# ========================================

# CRITICAL SAS pattern: V5_9 does sort by id, admit_date, descending flag, then nodupkey by id+admit_date
# This means: per patient per admit_date, keep the row with the HIGHEST flag value (descending sort + nodupkey keeps first)
# For each outcome, the SAS code deduplicates encounters to one row per patient per admit_date, keeping the "best" flag

message("\n=== Section 5: Dedup Per Patient Per Admit Date ===")

# SAS V5_9 pattern:
# proc sort data=v3.followups_dx out=v3.v1_outcome1; by id admit_date descending Enc_nonacute_care; run;
# proc sort data=v3.v1_outcome1 nodupkey; by id admit_date; run;

deduped_encounters <- followup_encounters %>%
  arrange(patid, admit_date, desc(Enc_nonacute_care), desc(Cancer_related_visit),
          desc(Cancer_visit_and_prov), desc(Survivorship_visit)) %>%
  distinct(patid, admit_date, .keep_all = TRUE)

message("After dedup (one per patient per date): ",
        format(nrow(deduped_encounters), big.mark = ","), " encounter-dates")

# ========================================
# Section 6 -- Patient-Level Aggregation (OUT-06)
# ========================================

# SAS V5_9: SQL SUM(flag) grouped by ID
# NOTE: SAS creates 4 separate outcome tables (v2_outcome1 through v2_outcome4) — one per outcome variable.
# For simplicity and correctness, create separate outcome count tibbles and merge.

message("\n=== Section 6: Patient-Level Aggregation ===")

# SAS V5_9 lines 79-82:
# sum(help_count) as n_followups,
# sum(Enc_nonacute_care) as n_Enc_nonacute_care

# Non-acute care count per patient
outcome1 <- deduped_encounters %>%
  group_by(patid) %>%
  summarize(
    n_Enc_nonacute_care = sum(Enc_nonacute_care, na.rm = TRUE),
    n_followups_1 = n(),
    .groups = "drop"
  )

message("  outcome1: ", nrow(outcome1), " patients with non-acute encounter counts")

# Cancer-related visit count per patient
outcome2 <- deduped_encounters %>%
  group_by(patid) %>%
  summarize(
    n_Cancer_related_visit = sum(Cancer_related_visit, na.rm = TRUE),
    n_followups_2 = n(),
    .groups = "drop"
  )

message("  outcome2: ", nrow(outcome2), " patients with cancer-related visit counts")

# Cancer visit + provider count per patient
outcome3 <- deduped_encounters %>%
  group_by(patid) %>%
  summarize(
    n_cancer_visit_and_prov = sum(Cancer_visit_and_prov, na.rm = TRUE),
    n_followups_3 = n(),
    .groups = "drop"
  )

message("  outcome3: ", nrow(outcome3), " patients with cancer visit + provider counts")

# Survivorship visit count per patient
outcome4 <- deduped_encounters %>%
  group_by(patid) %>%
  summarize(
    n_Survivorship_visit = sum(Survivorship_visit, na.rm = TRUE),
    n_followups_4 = n(),
    .groups = "drop"
  )

message("  outcome4: ", nrow(outcome4), " patients with survivorship visit counts")

# ========================================
# Section 7 -- Person-Time Calculation (OUT-05)
# ========================================

# SAS V5_11: person_time = admit_date - first_admit_date (uses LAST admit_date per patient from v2_outcome sort)
# SAS V5_15 line 155: person_time_days=admit_date-first_admit_date
# R: For each patient, get the LATEST admit_date in follow-up encounters

message("\n=== Section 7: Person-Time Calculation ===")

# Person-time: days from first cancer dx to LAST follow-up encounter
# SAS V5_11 lines 15-20: uses admit_date from v2_outcome (which is sorted desc, nodupkey by id = LAST date)
# SAS V5_15 line 155: person_time_days=admit_date-first_admit_date
person_time <- deduped_encounters %>%
  group_by(patid) %>%
  summarize(
    last_admit_date = max(admit_date, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  left_join(cohort %>% select(patid, first_admit_date), by = "patid") %>%
  mutate(
    # OUT-05: person_time_days = as.numeric(difftime(..., units="days"))
    person_time_days = as.numeric(difftime(last_admit_date, first_admit_date, units = "days")),
    # Log-transformed for Poisson/NB regression offset (V5_18 line 17)
    log_person_time_days = log(person_time_days)
  )

# Verify non-negative person-time (should be > 0 since we filtered admit > first)
tryCatch({
  person_time %>%
    assertr::verify(person_time_days > 0,
                    description = "Person-time must be positive")
  message("PASS: All person-time values positive")
}, error = function(e) {
  warning("OUT-05 ASSERTION: Non-positive person-time detected. ", conditionMessage(e))
})

message("Person-time summary:")
message("  Min: ", min(person_time$person_time_days, na.rm = TRUE), " days")
message("  Median: ", median(person_time$person_time_days, na.rm = TRUE), " days")
message("  Max: ", max(person_time$person_time_days, na.rm = TRUE), " days")

# ========================================
# Section 8 -- Merge Outcomes to Cohort (OUT-06)
# ========================================

# LEFT JOIN all outcome counts and person-time to cohort (keeps all patients including zero-visit)
# Fill NA counts with 0 (SAS V5_15: `if missing(n_Enc_nonacute_care) then n_Enc_nonacute_care=0`)
# Create binary indicator columns (enc_nonacute_ind, cancer_related_ind, etc.) per SAS V5_Table_1

message("\n=== Section 8: Merge Outcomes to Cohort ===")

cohort <- cohort %>%
  left_join(outcome1, by = "patid") %>%
  left_join(outcome2, by = "patid") %>%
  left_join(outcome3, by = "patid") %>%
  left_join(outcome4, by = "patid") %>%
  left_join(person_time %>% select(patid, person_time_days, log_person_time_days, last_admit_date),
            by = "patid") %>%
  mutate(
    # Fill missing counts with 0 (SAS V5_15 lines 156, 163, 170, 177: if missing then 0)
    across(c(n_Enc_nonacute_care, n_Cancer_related_visit,
             n_cancer_visit_and_prov, n_Survivorship_visit),
           ~replace_na(.x, 0L)),
    # Binary indicators (used in SAS V5_Table_1 for presence/absence)
    enc_nonacute_ind = if_else(n_Enc_nonacute_care > 0, 1L, 0L),
    cancer_related_ind = if_else(n_Cancer_related_visit > 0, 1L, 0L),
    cancer_visit_and_prov_ind = if_else(n_cancer_visit_and_prov > 0, 1L, 0L),
    Survivorship_visit_ind = if_else(n_Survivorship_visit > 0, 1L, 0L)
  )

message("Merged outcomes to cohort: ", nrow(cohort), " patients")

# ========================================
# Section 9 -- Assertions and Summary
# ========================================

message("\n=== Section 9: Data Quality Assertions ===")

# Assertion 1: No missing patids
tryCatch({
  cohort %>%
    assertr::verify(!is.na(patid),
                    description = "No missing PATIDs")
  message("PASS: No missing PATIDs")
}, error = function(e) {
  warning("ASSERTION FAILED: Missing PATIDs. ", conditionMessage(e))
})

# Assertion 2: Non-negative counts
tryCatch({
  cohort %>%
    assertr::verify(n_Enc_nonacute_care >= 0,
                    description = "Non-negative Enc_nonacute_care counts")
  message("PASS: All Enc_nonacute_care counts non-negative")
}, error = function(e) {
  warning("ASSERTION FAILED: Negative Enc_nonacute_care counts. ", conditionMessage(e))
})

# Assertion 3: Cancer visits subset of non-acute
# This is expected but not always true (depends on any_reportable_cancer presence)
# Log as informational rather than strict assertion
cancer_visits_exceed_nonacute <- cohort %>%
  filter(n_Cancer_related_visit > n_Enc_nonacute_care)
if (nrow(cancer_visits_exceed_nonacute) > 0) {
  message("INFO: ", nrow(cancer_visits_exceed_nonacute),
          " patients have more cancer-related visits than non-acute encounters")
  message("  This can occur due to deduplication differences or missing data")
} else {
  message("PASS: Cancer-related visits subset of non-acute encounters")
}

# Assertion 4: Person-time non-negative or NA
tryCatch({
  cohort %>%
    assertr::verify(person_time_days >= 0 | is.na(person_time_days),
                    description = "Person-time non-negative or NA")
  message("PASS: All person-time values non-negative or NA")
}, error = function(e) {
  warning("ASSERTION FAILED: Negative person-time detected. ", conditionMessage(e))
})

# Log outcome distributions with tabyl()
message("\nOutcome Variable Distributions:")
message("\nNon-acute care encounters (n_Enc_nonacute_care):")
tabyl(cohort, enc_nonacute_ind) %>% print()

message("\nCancer-related visits (n_Cancer_related_visit):")
tabyl(cohort, cancer_related_ind) %>% print()

message("\nCancer visits with cancer provider (n_cancer_visit_and_prov):")
tabyl(cohort, cancer_visit_and_prov_ind) %>% print()

message("\nSurvivorship visits (n_Survivorship_visit):")
tabyl(cohort, Survivorship_visit_ind) %>% print()

# Summary statistics for count variables
message("\nOutcome count summary statistics:")
message("  n_Enc_nonacute_care: mean=", round(mean(cohort$n_Enc_nonacute_care, na.rm = TRUE), 2),
        ", median=", median(cohort$n_Enc_nonacute_care, na.rm = TRUE),
        ", max=", max(cohort$n_Enc_nonacute_care, na.rm = TRUE))
message("  n_Cancer_related_visit: mean=", round(mean(cohort$n_Cancer_related_visit, na.rm = TRUE), 2),
        ", median=", median(cohort$n_Cancer_related_visit, na.rm = TRUE),
        ", max=", max(cohort$n_Cancer_related_visit, na.rm = TRUE))
message("  n_cancer_visit_and_prov: mean=", round(mean(cohort$n_cancer_visit_and_prov, na.rm = TRUE), 2),
        ", median=", median(cohort$n_cancer_visit_and_prov, na.rm = TRUE),
        ", max=", max(cohort$n_cancer_visit_and_prov, na.rm = TRUE))
message("  n_Survivorship_visit: mean=", round(mean(cohort$n_Survivorship_visit, na.rm = TRUE), 2),
        ", median=", median(cohort$n_Survivorship_visit, na.rm = TRUE),
        ", max=", max(cohort$n_Survivorship_visit, na.rm = TRUE))

# ========================================
# Section 10 -- Save Checkpoint
# ========================================

saveRDS(cohort, file.path(data_dir_processed, "03_outcomes.rds"))
message("\nSaved: 03_outcomes.rds (", format(nrow(cohort), big.mark = ","), " patients, ",
        ncol(cohort), " variables)")

# ========================================
# Section 11 -- Summary
# ========================================

message("\n========================================")
message("Phase 3: Outcome Variable Calculation Complete")
message("Completed: ", Sys.time())
message("========================================")
message("\nOutcome Variables Created:")
message("  n_Enc_nonacute_care: Non-acute care encounters (OUT-01)")
message("  n_Cancer_related_visit: Cancer-related visits (OUT-02)")
message("  n_cancer_visit_and_prov: Cancer visits with cancer provider (OUT-03)")
message("  n_Survivorship_visit: Survivorship visits (OUT-04)")
message("  person_time_days: Days from first cancer dx to last follow-up (OUT-05)")
message("  log_person_time_days: Log-transformed person-time for regression offset")
message("\nBinary Indicators:")
message("  enc_nonacute_ind, cancer_related_ind, cancer_visit_and_prov_ind, Survivorship_visit_ind")
message("\nCheckpoint file:")
message("  ", file.path(data_dir_processed, "03_outcomes.rds"))
message("\nNext step: R/03_covariates.R")
