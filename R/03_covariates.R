# R/03_covariates.R
# Covariate Processing & Final Dataset Assembly
# Per D-01: Fourth (final) Phase 3 script
# Per D-02: Self-contained with .rds checkpoints
# Per D-05: Final output is one wide patient-level tibble (for_table equivalent)
# Per D-06: Produce both complete-case AND MI-ready datasets
#
# SAS Source: V5_17 (race2, intensity2), V5_18 (first_sdi2),
#             V5_15 (for_table assembly, person_time_days, change_vars),
#             V5_16 (PROC MI variable lists)
#
# Inputs:  data/processed/03_outcomes.rds (from 03_outcomes.R)
#          data/processed/01_formats.rds
# Outputs: data/processed/03_analytical.rds (complete-case)
#          data/processed/03_analytical_mi.rds (MI-ready with missing values)

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
message("Phase 3: Covariate Processing & Final Dataset Assembly")
message("Started: ", Sys.time())
message("========================================")

# ========================================
# Section 2 -- Load Checkpoint
# ========================================

# Load Phase 3 cohort with exposures + outcomes
analytical <- readRDS(file.path(data_dir_processed, "03_outcomes.rds"))

message("Loaded datasets:")
message("  analytical (from 03_outcomes.rds): ", format(nrow(analytical), big.mark = ","), " patients")
message("  Variables: ", ncol(analytical))

# ========================================
# Section 3 -- Race Recoding (COV-01, per V5_17)
# ========================================

# SAS V5_17 race2 macro: Collapse race to 3 categories
# race='05' -> 'WH' (White)
# race='03' -> 'AA' (African American)
# race in ('01','02','04','06') -> 'OT' (Other)

message("\n=== Section 3: Race Recoding ===")

analytical <- analytical %>%
  mutate(
    # SAS V5_17: race2 recoding
    race2 = case_when(
      race == "05" ~ "WH",
      race == "03" ~ "AA",
      race %in% c("01", "02", "04", "06") ~ "OT",
      TRUE ~ NA_character_  # SAS: race2=' ' for unmapped values
    ),
    # SAS V5_15 line 154: if race='UN' then race=' ' (set to missing for MI)
    race = if_else(race == "UN", NA_character_, race)
  )

message("Race2 distribution:")
print(janitor::tabyl(analytical, race2))

# ========================================
# Section 4 -- Hispanic Cleaning (COV-01, per V5_15)
# ========================================

# SAS V5_15 line 153: if hispanic='UN' then hispanic=' ' (set to missing)

message("\n=== Section 4: Hispanic Cleaning ===")

analytical <- analytical %>%
  mutate(
    hispanic = if_else(hispanic == "UN", NA_character_, hispanic)
  )

message("Hispanic distribution (after cleaning):")
print(janitor::tabyl(analytical, hispanic))

# ========================================
# Section 5 -- Sex Factor (COV-01)
# ========================================

# Sex already filtered (sex!="UN" in 03_cohort.R)
# Apply factor with sas_formats$sex for labeled output
# NOTE: Keep character for now; convert to factor in MI-ready dataset

message("\n=== Section 5: Sex Factor ===")

# Sex is already character code; will be converted to factor in MI-ready dataset
# Log distribution
message("Sex distribution:")
print(janitor::tabyl(analytical, sex))

# ========================================
# Section 6 -- Age Categories (COV-02, per SAS agef format)
# ========================================

# SAS agef format: age categories
# From Formats.sas study-specific section (lines 2494-2495):
# value agef  1='0-14'
#             2='15-39'
#             3='40-54'
#             4='55-64'
#             5='65-91';
# R: Use case_when matching SAS logic

message("\n=== Section 6: Age Categories ===")

analytical <- analytical %>%
  mutate(
    age2 = case_when(
      age < 15 ~ 1L,
      age >= 15 & age < 40 ~ 2L,   # SAS: 15-39 means 15 <= age < 40
      age >= 40 & age < 55 ~ 3L,   # 40-54 means 40 <= age < 55
      age >= 55 & age < 65 ~ 4L,   # 55-64 means 55 <= age < 65
      age >= 65 ~ 5L,
      TRUE ~ NA_integer_
    )
  )

message("Age2 distribution:")
print(janitor::tabyl(analytical, age2))

# ========================================
# Section 7 -- SDI Categorization (COV-03, per V5_18)
# ========================================

# SAS V5_18 lines 14-16: SDI tertile-like categories
# first_sdi <=45 -> first_sdi2=1
# first_sdi < 74 -> first_sdi2=2
# first_sdi <=100 -> first_sdi2=3

message("\n=== Section 7: SDI Categorization ===")

analytical <- analytical %>%
  mutate(
    # Rename for model variable naming (SAS V5_15 line 23: first_can_sdi_score as first_sdi)
    first_sdi = first_can_sdi_score,
    first_sdi2 = case_when(
      first_sdi <= 45 ~ 1L,
      first_sdi < 74 ~ 2L,
      first_sdi <= 100 ~ 3L,
      TRUE ~ NA_integer_
    )
  )

message("SDI category distribution:")
print(janitor::tabyl(analytical, first_sdi2))

# ========================================
# Section 8 -- RUCA Classification (COV-04)
# ========================================

# RUCA variable from cohort (first_can_ruca) — rename for model variable naming
# SAS V5_15 line 22: first_can_ruca as first_ruca

message("\n=== Section 8: RUCA Classification ===")

analytical <- analytical %>%
  mutate(
    first_ruca = first_can_ruca  # Rename for model variable naming
  )

message("RUCA distribution:")
print(janitor::tabyl(analytical, first_ruca))

# ========================================
# Section 9 -- Intensity2 Recoding (per V5_17)
# ========================================

# SAS V5_17 intensity2 macro: Collapse intensity to 5 categories
# intensity=0 -> intensity2=0
# intensity=1 -> intensity2=1
# intensity=2 or 3 -> intensity2=2
# intensity=4 or 5 -> intensity2=3
# intensity=6 or 7 or 8 -> intensity2=4

message("\n=== Section 9: Intensity2 Recoding ===")

analytical <- analytical %>%
  mutate(
    intensity2 = case_when(
      intensity == 0 ~ 0L,
      intensity == 1 ~ 1L,
      intensity %in% c(2, 3) ~ 2L,
      intensity %in% c(4, 5) ~ 3L,
      intensity %in% c(6, 7, 8) ~ 4L,
      TRUE ~ NA_integer_
    )
  )

message("Intensity2 distribution:")
print(janitor::tabyl(analytical, intensity2))

# ========================================
# Section 10 -- Rename Variables to Match SAS for_table Naming (per V5_15)
# ========================================

# SAS V5_15 for_table SELECT aliases:
# first_can_hispanicc -> hispanic (already done in cohort)
# first_can_payer_type_primary -> first_payer
# first_can_racee -> race (already done)
# first_can_ruca -> first_ruca (done above)
# first_can_sdi_score -> first_sdi (done above)
# first_can_sexx -> sex (already done)
# age2 -> age (SAS aliases age2 as "age" in model; keep both)

message("\n=== Section 10: Rename Variables ===")

analytical <- analytical %>%
  mutate(
    # SAS V5_15 line 20: first_can_payer_type_primary as first_payer
    first_payer = first_can_payer_type_primary
    # All other renames done in previous sections
  )

# ========================================
# Section 11 -- Ensure log_person_time_days Exists (per V5_18)
# ========================================

# SAS V5_18 line 17: log_person_time_days=log(person_time_days)
# Already computed in 03_outcomes.R, but verify

message("\n=== Section 11: Verify log_person_time_days ===")

if (!"log_person_time_days" %in% names(analytical)) {
  analytical <- analytical %>%
    mutate(log_person_time_days = log(person_time_days))
  message("Created log_person_time_days")
} else {
  message("log_person_time_days already exists")
}

# Warn on non-finite values
n_inf <- sum(is.infinite(analytical$log_person_time_days) | is.na(analytical$log_person_time_days))
if (n_inf > 0) {
  message("WARNING: ", n_inf, " patients with non-finite log_person_time_days")
}

# ========================================
# Section 12 -- Select Final Analytical Columns (per D-05, V5_15/V5_18)
# ========================================

# Final wide dataset per D-05: one row per patient
# Columns match SAS for_table + mi_table variable set (V5_16 PROC MI VAR list)

message("\n=== Section 12: Select Final Analytical Columns ===")

analytical_final <- analytical %>%
  select(
    # ID
    patid,
    # Demographics (COV-01)
    sex, race, race2, hispanic,
    # Age (COV-02)
    age, age2,
    # SDI (COV-03)
    first_sdi, first_sdi2,
    # RUCA (COV-04)
    first_ruca,
    # Insurance (EXP-01)
    first_payer, last_payer, change_ins,
    # Treatment (EXP-02)
    chemo, surgery, radiation, sct, intensity, intensity2,
    # Cancer site (EXP-03)
    group_site, group_site2,
    # Data source
    source,
    # Outcome counts
    n_Enc_nonacute_care, n_Cancer_related_visit,
    n_cancer_visit_and_prov, n_Survivorship_visit,
    # Binary indicators
    enc_nonacute_ind, cancer_related_ind,
    cancer_visit_and_prov_ind, Survivorship_visit_ind,
    # Person-time
    person_time_days, log_person_time_days,
    # Dates (for reference)
    first_admit_date, last_admit_date
  )

message("Analytical dataset dimensions: ", nrow(analytical_final), " patients x ", ncol(analytical_final), " variables")

# ========================================
# Section 13 -- Complete-Case Dataset (per D-06)
# ========================================

# Complete-case: remove patients with missing key covariates
# SAS for_table datasets contain all patients; complete-case filtering is implicit
# Key covariates for regression: sex, race2, hispanic, first_payer, first_ruca, first_sdi2, age2, intensity

message("\n=== Section 13: Complete-Case Dataset ===")

analytical_complete <- analytical_final %>%
  filter(
    !is.na(sex), !is.na(race2), !is.na(hispanic),
    !is.na(first_payer), !is.na(first_ruca), !is.na(first_sdi2),
    !is.na(age2), !is.na(intensity),
    !is.na(person_time_days), person_time_days > 0
  )

message("Complete-case dataset: ", nrow(analytical_complete), " patients (from ",
        nrow(analytical_final), " total)")
message("Excluded: ", nrow(analytical_final) - nrow(analytical_complete), " patients with missing covariates")

saveRDS(analytical_complete, file.path(data_dir_processed, "03_analytical.rds"))
message("Saved: 03_analytical.rds")

# ========================================
# Section 14 -- MI-Ready Dataset (per D-06)
# ========================================

# MI-ready: ALL patients, missing values intact for imputation in Phase 4
# Phase 4 will call mice::mice() on this dataset
# Per Research: mice expects factors as factors, numerics as numeric

message("\n=== Section 14: MI-Ready Dataset ===")

analytical_mi <- analytical_final %>%
  mutate(
    # Convert character covariates to factors for mice compatibility
    across(c(sex, race, race2, hispanic, first_payer, last_payer,
             first_ruca, group_site, group_site2, source), as.factor)
  )

message("MI-ready dataset: ", nrow(analytical_mi), " patients")
message("Missing value counts:")
analytical_mi %>%
  summarize(across(everything(), ~sum(is.na(.x)))) %>%
  pivot_longer(everything(), names_to = "variable", values_to = "n_missing") %>%
  filter(n_missing > 0) %>%
  arrange(desc(n_missing)) %>%
  print()

saveRDS(analytical_mi, file.path(data_dir_processed, "03_analytical_mi.rds"))
message("Saved: 03_analytical_mi.rds")

# ========================================
# Section 15 -- Summary
# ========================================

message("\n========================================")
message("Phase 3: Covariate Processing Complete")
message("Completed: ", Sys.time())
message("========================================")
message("\nCovariate Variables Created:")
message("  race2: 3-category race (WH, AA, OT) per V5_17")
message("  age2: 5-category age groups per agef format")
message("  first_sdi2: SDI tertiles (<=45, <74, <=100) per V5_18")
message("  first_ruca: RUCA classification (from first_can_ruca)")
message("  intensity2: 5-category treatment intensity per V5_17")
message("\nFinal Datasets:")
message("  03_analytical.rds: Complete-case (", nrow(analytical_complete), " patients)")
message("  03_analytical_mi.rds: MI-ready (", nrow(analytical_mi), " patients)")
message("\nCheckpoint files:")
message("  ", file.path(data_dir_processed, "03_analytical.rds"))
message("  ", file.path(data_dir_processed, "03_analytical_mi.rds"))
message("\nNext step: Phase 4 (Statistical Analysis & Output)")
message("  R/04_table1.R")
