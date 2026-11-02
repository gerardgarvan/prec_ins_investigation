# R/03_exposure.R
# Exposure Variable Derivation: Insurance change, treatment intensity, cancer site groups, chemotherapy
# Per D-01: Second of 4 Phase 3 scripts
# Per D-02: Self-contained with .rds checkpoints
# Per D-08: change_ins/pct_change_ins translated faithfully with edge case flags
#
# SAS Source: V5_12 (chemo/procedure identification), V5_14 (treatment intensity),
#             V5_15 (change_vars macro, group_site2, for_table assembly)
#
# Inputs:  data/processed/03_cohort.rds           (from 03_cohort.R)
#          data/processed/02_proc_patient_flags.rds (replaces 02_proc_combined.rds)
#          data/processed/02_dispensing_patids.rds  (backward-compat; patid only)
#          data/processed/02_dispensing_ndc.rds     (new: distinct patid + ndc9 for NDC join)
#          data/processed/01_imported_ndc.rds       (new: SEER*Rx NDC reference from 00_build_ndc.R)
#          data/processed/02_merged_complete.rds    (encounter rows; carries group_site)
#          data/processed/01_formats.rds
# Outputs: data/processed/03_exposure.rds

# ========================================
# Section 1 -- Setup
# ========================================

library(here)
source(here::here("R", "config.R"))
source(here::here("R", "utils_import.R"))
library(tidyverse)
library(janitor)
library(assertr)

# Load SAS format definitions
sas_formats <- readRDS(file.path(data_dir_processed, "01_formats.rds"))

message("========================================")
message("Phase 3: Exposure Variable Derivation")
message("Started: ", Sys.time())
message("========================================")

# ========================================
# Section 2 -- Load Checkpoints
# ========================================

# Load Phase 3 cohort
cohort <- read_checkpoint(file.path(data_dir_processed, "03_cohort.rds"))

# Pre-computed patient-level treatment flags (chemo/surgery/radiation/sct).
# Derived per proc part in 02_clean.R — replaces loading 02_proc_combined.rds.
proc_patient_flags <- read_checkpoint(file.path(data_dir_processed, "02_proc_patient_flags.rds"))

# SEER*Rx NDC reference table (ndc9 key + seer_cat_code 1-6).
# Built by 00_build_ndc.R from reference/ndconc_results_new.csv.
ndc_ref <- readRDS(file.path(data_dir_processed, "01_imported_ndc.rds"))

# Dispensing with normalized ndc9 (distinct patid + ndc9, built in 02_clean.R Section 4c).
dispensing_ndc <- read_checkpoint(file.path(data_dir_processed, "02_dispensing_ndc.rds"))

# merged_complete: one row per encounter; carries group_site from dx_encounter.
# Replaces merged_enc_dx (which was one row per encounter-dx pair).
merged_complete <- read_checkpoint(file.path(data_dir_processed, "02_merged_complete.rds"))

message("Loaded datasets:")
message("  cohort:              ", format(nrow(cohort),              big.mark = ","), " patients")
message("  proc_patient_flags:  ", format(nrow(proc_patient_flags),  big.mark = ","), " patients with proc records")
message("  ndc_ref:             ", format(nrow(ndc_ref),             big.mark = ","), " distinct ndc9 x seer_cat_code pairs")
message("  dispensing_ndc:      ", format(nrow(dispensing_ndc),      big.mark = ","), " distinct patid x ndc9 rows")
message("  merged_complete:     ", format(nrow(merged_complete),     big.mark = ","), " encounter rows")

# ========================================
# Section 3 -- Treatment Flags from Pre-Computed Proc Patient Flags
# ========================================
#
# SAS source: V5_12 lines 134-143 (chemo), 497-567 (radiation),
#             607-655 (surgery), 663-720 (SCT)
# Procedure codes were applied per-part in 02_clean.R and the patient-level
# max was saved to 02_proc_patient_flags.rds.  Join here instead of re-scanning
# the full proc tables.

message("\n=== Section 3-6: Treatment Flags (from 02_proc_patient_flags.rds) ===")

# Filter proc flags to cohort patients and join
cohort_proc_flags <- proc_patient_flags %>%
  filter(patid %in% cohort$patid)

cohort <- cohort %>%
  left_join(cohort_proc_flags, by = "patid") %>%
  mutate(
    chemo_proc     = replace_na(chemo_proc,     0L),
    surgery_proc   = replace_na(surgery_proc,   0L),
    radiation_proc = replace_na(radiation_proc, 0L),
    sct_proc       = replace_na(sct_proc,       0L)
  )

# Dispensing-based chemo and ancillary flags (NDC join to SEER*Rx reference)
# SAS V5_12 lines 22-42: join dispensing NDC9 to ndc_cond2 (SEER*Rx table) on ndc9.
# chemo_disp = 1 if any matched category code in {"2","3","4","5","6"} (i.e. != "1")
# anc_disp   = 1 if any matched category code == "1" (Ancillary Therapy)
# No date window applied (V5_12 dispensing join has no dispense_date filter).

disp_cat <- dispensing_ndc %>%
  filter(patid %in% cohort$patid) %>%
  left_join(ndc_ref %>% distinct(ndc9, seer_cat_code), by = "ndc9")

# Log unmatched NDC lengths (7/8-char non-standard codes + 9-char no-match)
unmatched <- disp_cat %>% filter(is.na(seer_cat_code))
message("  Dispensing NDC unmatched to SEER*Rx reference: ", nrow(unmatched))
if (nrow(unmatched) > 0) {
  print(unmatched %>% dplyr::count(ndc_len = nchar(ndc9)))
}

# Patient-level flags: chemo_disp (codes 2-6) and anc_disp (code 1)
disp_flags <- disp_cat %>%
  group_by(patid) %>%
  summarise(
    chemo_disp = as.integer(any(seer_cat_code %in% c("2", "3", "4", "5", "6"), na.rm = TRUE)),
    anc_disp   = as.integer(any(seer_cat_code == "1", na.rm = TRUE)),
    .groups    = "drop"
  )
message("  Patients with dispensing-based chemo (codes 2-6): ", sum(disp_flags$chemo_disp))
message("  Patients with dispensing-based ancillary (code 1): ", sum(disp_flags$anc_disp))

cohort <- cohort %>%
  left_join(disp_flags, by = "patid") %>%
  mutate(
    chemo_disp = replace_na(chemo_disp, 0L),
    anc_disp   = replace_na(anc_disp,   0L),
    chemo     = if_else(chemo_proc == 1L | chemo_disp == 1L, 1L, 0L),
    surgery   = surgery_proc,
    radiation = radiation_proc,
    sct       = sct_proc
  ) %>%
  select(-chemo_proc, -surgery_proc, -radiation_proc, -sct_proc)

message("  chemo:     ", sum(cohort$chemo    == 1L), " / ", nrow(cohort), " patients")
message("  surgery:   ", sum(cohort$surgery  == 1L), " / ", nrow(cohort), " patients")
message("  radiation: ", sum(cohort$radiation == 1L), " / ", nrow(cohort), " patients")
message("  sct:       ", sum(cohort$sct       == 1L), " / ", nrow(cohort), " patients")
message("  NOTE: Surgery uses ICD-10-PCS Medical/Surgical section (V5_12 surgerycodes ref needed)")

# ========================================
# Section 7 -- Ancillary Therapy Identification
# ========================================

# SAS source: V5_14 references ancillary_all dataset (created in V5_12)
# V5_12 lines 725-851: Ancillary therapy from dispensing/prescribing/med_admin
# where SEERRxCategory == "1" (Ancillary Therapy)
#
# anc_disp was derived in Section 3 from the SEER*Rx NDC join (seer_cat_code == "1").
# Per SAS V5_12 != "1" rule: anc = 1 if patient has any dispensing record with
# SEERRxCategory "Ancillary Therapy" (code "1").

message("\n=== Section 7: Ancillary Therapy Identification ===")

# Per SAS V5_14 intensity logic line 181-183:
# if (surgery=0 and radiation=0) and chemo=0 and anc=1 then intensity=0
# anc_disp (code "1") is the dispensing-based ancillary flag from Section 3.

cohort <- cohort %>%
  mutate(
    anc = if_else(anc_disp == 1L, 1L, 0L)
  ) %>%
  select(-anc_disp, -chemo_disp)

message("  Final ancillary distribution: ", sum(cohort$anc == 1), " ancillary / ",
        sum(cohort$anc == 0), " no ancillary dispensing")

# ========================================
# Section 8 -- Treatment Intensity (EXP-02)
# ========================================

# SAS source: V5_14 lines 163-186
# Intensity coding (exact SAS priority order):
#   8: sct=1
#   7: surgery=1 AND radiation=1 AND chemo=1
#   6: surgery=0 AND radiation=1 AND chemo=1
#   5: surgery=1 AND radiation=1 AND chemo=0
#   4: surgery=1 AND radiation=0 AND chemo=1
#   3: surgery=0 AND radiation=1 AND chemo=0
#   2: surgery=0 AND radiation=0 AND chemo=1
#   1: surgery=1 AND radiation=0 AND chemo=0
#   0: surgery=0 AND radiation=0 AND chemo=0 AND anc=1
#   NA: otherwise (shouldn't happen if flags correct)

message("\n=== Section 8: Treatment Intensity ===")

cohort <- cohort %>%
  mutate(
    intensity = case_when(
      sct == 1 ~ 8L,
      surgery == 1 & radiation == 1 & chemo == 1 ~ 7L,
      surgery == 0 & radiation == 1 & chemo == 1 ~ 6L,
      surgery == 1 & radiation == 1 & chemo == 0 ~ 5L,
      surgery == 1 & radiation == 0 & chemo == 1 ~ 4L,
      surgery == 0 & radiation == 1 & chemo == 0 ~ 3L,
      surgery == 0 & radiation == 0 & chemo == 1 ~ 2L,
      surgery == 1 & radiation == 0 & chemo == 0 ~ 1L,
      surgery == 0 & radiation == 0 & chemo == 0 & anc == 1 ~ 0L,
      TRUE ~ NA_integer_  # SAS: intensity=. (missing)
    )
  )

message("  Intensity distribution:")
intensity_dist <- cohort %>%
  count(intensity) %>%
  arrange(intensity)
for (i in 1:nrow(intensity_dist)) {
  message("    intensity=", intensity_dist$intensity[i], ": ",
          intensity_dist$n[i], " patients")
}

# SAS source: V5_14 lines 163-186
# Intensity labels from SAS format int.:
#   0='ancillary only'
#   1='Surgery only'
#   2='Chemotherapy only'
#   3='Radiation only'
#   4='Surgery and chemotherapy'
#   5='Surgery and radiation'
#   6='Radiation and chemotherapy'
#   7='Surgery, radiation, and chemotherapy'
#   8='sct'

# ========================================
# Section 9 -- Cancer Site Groups (EXP-03)
# ========================================

# SAS source: V5_15 change_vars macro lines 186-205
# Maps text group_site to numeric group_site2 codes:
#   "Bones, joints, and soft tissue" -> "1"
#   "Breast" -> "2"
#   "Digestive" -> "3"
#   "Eye, brain, CNS, endocrine" -> "4"
#   "Hematologic" -> "5"
#   "Oral and respiratory" -> "6"
#   "Skin" -> "7"
#   "Urinary" -> "8"
#   "Female Genital System" -> "8"
#   "Male Genital System" -> "8"
#   "Reportable but not mapped above" -> "9"
#   "Other" -> "9"
#   "In situ" -> "9"
#
# R: Get group_site from merged_enc_dx at first cancer encounter

message("\n=== Section 9: Cancer Site Groups ===")

# Get group_site for each patient from their first cancer encounter.
# merged_complete (one row per encounter) carries group_site from 02_dx_encounter.rds.
first_cancer_site <- merged_complete %>%
  semi_join(cohort %>% select(patid, first_can_encounterid),
            by = c("patid", "encounterid" = "first_can_encounterid")) %>%
  filter(any_reportable_cancer == 1L) %>%
  select(patid, group_site) %>%
  distinct(patid, .keep_all = TRUE)

message("  Patients with group_site: ", nrow(first_cancer_site))

# Join to cohort and derive group_site2
cohort <- cohort %>%
  left_join(first_cancer_site, by = "patid") %>%
  mutate(
    # SAS uses =: (starts-with comparison). R uses str_detect with ^ anchor.
    group_site2 = case_when(
      str_detect(group_site, "^Bones, joints") ~ "1",
      str_detect(group_site, "^Breast") ~ "2",
      str_detect(group_site, "^Digestive") ~ "3",
      str_detect(group_site, "^Eye, brain") ~ "4",
      str_detect(group_site, "^Hematologic") ~ "5",
      str_detect(group_site, "^Oral and respiratory") ~ "6",
      str_detect(group_site, "^Skin") ~ "7",
      str_detect(group_site, "^Urinary") ~ "8",
      str_detect(group_site, "^Female Genital") ~ "8",
      str_detect(group_site, "^Male Genital") ~ "8",
      str_detect(group_site, "^Reportable but") ~ "9",
      str_detect(group_site, "^Other") ~ "9",
      str_detect(group_site, "^In situ") ~ "9",
      TRUE ~ NA_character_
    )
  )

message("  Cancer site group distribution:")
site_dist <- cohort %>%
  count(group_site2) %>%
  arrange(group_site2)
for (i in 1:nrow(site_dist)) {
  message("    group_site2=", site_dist$group_site2[i], ": ",
          site_dist$n[i], " patients")
}

# SAS source: V5_15 change_vars macro lines 186-201

# ========================================
# Section 10 -- Insurance Change Variable (EXP-01, per D-08)
# ========================================

# SAS source: V5_15 change_vars macro lines 202-204
# Derive last_payer: the payer_type_primary at the LAST encounter (by admit_date) for each patient
# SAS V5_15 references change_out1 which contains last_payer_type_primary
#
# R: From merged_complete, get last payer per patient (max admit_date after first cancer dx)

message("\n=== Section 10: Insurance Change Variable ===")

# Derive last_payer from encounter data (recoded category — 511->512 is NOT a change)
# Filter to encounters AFTER first cancer diagnosis
last_encounter_payer <- merged_complete %>%
  inner_join(cohort %>% select(patid, first_admit_date), by = "patid") %>%
  filter(admit_date >= first_admit_date) %>%
  arrange(patid, desc(admit_date)) %>%
  group_by(patid) %>%
  slice_head(n = 1) %>%
  ungroup() %>%
  select(patid, last_payer_recoded = payer_primary_recoded, last_admit_date = admit_date)

message("  Patients with last_payer_recoded: ", nrow(last_encounter_payer))

# Merge and compute change_ins — compare RECODED categories, not raw codes.
# 511->512 both recode to '5' (private), so change_ins=0 for that transition.
cohort <- cohort %>%
  left_join(last_encounter_payer, by = "patid") %>%
  rename(last_payer = last_payer_recoded) %>%
  mutate(
    # SAS V5_15 line 202-204: change_ins=0 if same recoded category, 1 if different
    change_ins = case_when(
      is.na(first_can_payer_recoded) | is.na(last_payer) ~ NA_integer_,
      first_can_payer_recoded == last_payer ~ 0L,
      first_can_payer_recoded != last_payer ~ 1L,
      TRUE ~ NA_integer_
    )
  )

# SAS source: V5_15 change_vars macro lines 202-204
# EDGE CASE: Patients with only one encounter (first==last) have change_ins=0
# EDGE CASE: Patients with no follow-up encounters have NA last_payer -> NA change_ins

message("  Insurance change distribution:")
message("    change_ins=0 (no change): ", sum(cohort$change_ins == 0, na.rm = TRUE))
message("    change_ins=1 (changed): ", sum(cohort$change_ins == 1, na.rm = TRUE))
message("    change_ins=NA (undefined): ", sum(is.na(cohort$change_ins)))
if (sum(is.na(cohort$change_ins)) > 0) {
  message("  WARNING: ", sum(is.na(cohort$change_ins)), " patients with undefined change_ins")
  message("  EDGE CASE: NA change_ins occurs when first_payer or last_payer is missing")
}

# Also derive last_ruca and last_sdi for downstream use (per V5_15 for_table assembly)
# These are referenced in V5_15 for_table1-4 but not used in change_vars macro
# For now, we'll skip these as they're not in the current plan requirements

# ========================================
# Section 11 -- Save Checkpoint
# ========================================

saveRDS(cohort, file.path(data_dir_processed, "03_exposure.rds"))
message("\nSaved: 03_exposure.rds (", format(nrow(cohort), big.mark = ","), " patients, ",
        ncol(cohort), " variables)")

# ========================================
# Section 12 -- Summary
# ========================================

message("\n========================================")
message("Phase 3: Exposure Variable Derivation Complete")
message("Completed: ", Sys.time())
message("========================================")
message("\nExposure Variable Summary:")
message("  Chemotherapy (chemo): ", sum(cohort$chemo == 1), " / ", nrow(cohort), " patients")
message("  Surgery (surgery): ", sum(cohort$surgery == 1), " / ", nrow(cohort), " patients")
message("  Radiation (radiation): ", sum(cohort$radiation == 1), " / ", nrow(cohort), " patients")
message("  SCT (sct): ", sum(cohort$sct == 1), " / ", nrow(cohort), " patients")
message("  Ancillary only (anc): ", sum(cohort$anc == 1), " / ", nrow(cohort), " patients")
message("\nTreatment Intensity:")
for (i in 0:8) {
  n <- sum(cohort$intensity == i, na.rm = TRUE)
  if (n > 0) {
    label <- c("ancillary only", "Surgery only", "Chemotherapy only", "Radiation only",
               "Surgery and chemotherapy", "Surgery and radiation", "Radiation and chemotherapy",
               "Surgery, radiation, and chemotherapy", "sct")[i+1]
    message("  intensity=", i, " (", label, "): ", n, " patients")
  }
}
message("\nCancer Site Groups (group_site2):")
message("  Patients with site group: ", sum(!is.na(cohort$group_site2)), " / ", nrow(cohort))
message("\nInsurance Change (change_ins):")
message("  No change (0): ", sum(cohort$change_ins == 0, na.rm = TRUE))
message("  Changed (1): ", sum(cohort$change_ins == 1, na.rm = TRUE))
message("  Undefined (NA): ", sum(is.na(cohort$change_ins)))
message("\nCheckpoint file:")
message("  ", file.path(data_dir_processed, "03_exposure.rds"))
message("\nNext step: R/03_outcomes.R")
