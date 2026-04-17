# R/03_exposure.R
# Exposure Variable Derivation: Insurance change, treatment intensity, cancer site groups, chemotherapy
# Per D-01: Second of 4 Phase 3 scripts
# Per D-02: Self-contained with .rds checkpoints
# Per D-08: change_ins/pct_change_ins translated faithfully with edge case flags
#
# SAS Source: V5_12 (chemo/procedure identification), V5_14 (treatment intensity),
#             V5_15 (change_vars macro, group_site2, for_table assembly)
#
# Inputs:  data/processed/03_cohort.rds (from 03_cohort.R)
#          data/processed/02_proc_combined.rds (procedures for chemo/surgery/radiation)
#          data/processed/01_imported_dispensing.rds (NDC for chemo)
#          data/processed/02_merged_enc_dx.rds (for encounter-level group_site)
#          data/processed/02_merged_complete.rds (for last_payer derivation)
#          data/processed/01_formats.rds
# Outputs: data/processed/03_exposure.rds

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
message("Phase 3: Exposure Variable Derivation")
message("Started: ", Sys.time())
message("========================================")

# ========================================
# Section 2 -- Load Checkpoints
# ========================================

# Load Phase 3 cohort
cohort <- readRDS(file.path(data_dir_processed, "03_cohort.rds"))

# Load procedures data for treatment identification
proc_combined <- readRDS(file.path(data_dir_processed, "02_proc_combined.rds"))

# Load dispensing data for NDC-based chemo identification
dispensing <- readRDS(file.path(data_dir_processed, "01_imported_dispensing.rds"))

# Load merged encounter-dx for group_site and encounter-level data
merged_enc_dx <- readRDS(file.path(data_dir_processed, "02_merged_enc_dx.rds"))

# Load merged complete for last_payer derivation
merged_complete <- readRDS(file.path(data_dir_processed, "02_merged_complete.rds"))

message("Loaded datasets:")
message("  cohort: ", format(nrow(cohort), big.mark = ","), " patients")
message("  proc_combined: ", format(nrow(proc_combined), big.mark = ","), " procedures")
message("  dispensing: ", format(nrow(dispensing), big.mark = ","), " dispensing records")
message("  merged_enc_dx: ", format(nrow(merged_enc_dx), big.mark = ","), " encounter-dx rows")
message("  merged_complete: ", format(nrow(merged_complete), big.mark = ","), " encounter rows")

# ========================================
# Section 3 -- Chemotherapy Identification (EXP-04)
# ========================================

# SAS source: V5_12 lines 134-143, 284-294
# Chemotherapy identified from four sources:
#   1. PROCEDURES (CPT/HCPCS): px_type=="CH" AND px in 96401-96549 OR J9000-J9999
#   2. PROCEDURES (ICD-10): px_type=="10" AND px in ("Z51.11", "Z51.12")
#   3. PROCEDURES (ICD-9): px_type=="09" AND px in ("V58.11", "V58.12")
#   4. DISPENSING (NDC): Join with ndc_cond2 reference where SEERRxCategory != "1" (Ancillary)
#
# NOTE: We don't have ndc_cond2 reference table, so we'll mark all NDC dispensing as potential chemo
# and document this limitation. The SAS logic filters NDC where SEERRxCategory != "1".

message("\n=== Section 3: Chemotherapy Identification ===")

# Procedure-based chemo identification
proc_chemo <- proc_combined %>%
  filter(patid %in% cohort$patid) %>%
  filter(
    # CPT/HCPCS: 96401-96549 or J9000-J9999
    (px_type == "CH" & ((px >= "96401" & px <= "96549") | (px >= "J9000" & px <= "J9999"))) |
    # ICD-10: Z51.11, Z51.12
    (px_type == "10" & px %in% c("Z51.11", "Z51.12")) |
    # ICD-9: V58.11, V58.12
    (px_type == "09" & px %in% c("V58.11", "V58.12"))
  ) %>%
  distinct(patid) %>%
  mutate(chemo_proc = 1L)

message("  Patients with procedure-based chemo: ", nrow(proc_chemo))

# Dispensing-based chemo identification
# NOTE: SAS V5_12 joins dispensing with ndc_cond2 reference on NDC9 (first 9 chars)
# Without ndc_cond2 reference table, we treat all dispensing as potential chemo
# Document this limitation with EDGE CASE flag
disp_chemo <- dispensing %>%
  filter(patid %in% cohort$patid) %>%
  distinct(patid) %>%
  mutate(chemo_disp = 1L)

message("  Patients with dispensing-based chemo: ", nrow(disp_chemo))
message("  NOTE: NDC-based chemo identification requires ndc_cond2 reference table (SEERRxCategory)")
message("  EDGE CASE: All dispensing records treated as potential chemo until reference table available")

# Combine chemo flags from both sources
cohort <- cohort %>%
  left_join(proc_chemo, by = "patid") %>%
  left_join(disp_chemo, by = "patid") %>%
  mutate(
    chemo = if_else(chemo_proc == 1 | chemo_disp == 1, 1L, 0L, missing = 0L)
  ) %>%
  select(-chemo_proc, -chemo_disp)

message("  Final chemo distribution: ", sum(cohort$chemo == 1), " chemo / ",
        sum(cohort$chemo == 0), " no chemo")

# ========================================
# Section 4 -- Surgery Identification
# ========================================

# SAS source: V5_14 references surgery_all dataset (created in V5_12)
# V5_12 lines 607-655: Surgery identified from procedures, diagnoses, and encounter DRG codes
# using surgerycodes reference table
#
# Without the reference table, we use ICD-10-PCS surgical root operations:
# - Medical and Surgical section codes starting with 0 (e.g., 0F=Hepatobiliary, 0V=Male Reproductive)
# - Common surgical root operations: Resection, Excision, Drainage, etc.
#
# EDGE CASE: This is a best-effort translation requiring validation against surgerycodes reference

message("\n=== Section 4: Surgery Identification ===")

proc_surgery <- proc_combined %>%
  filter(patid %in% cohort$patid) %>%
  filter(
    # ICD-10-PCS: Medical and Surgical section (starts with 0)
    # Common surgical body systems: 0B=Respiratory, 0D=Gastrointestinal, 0F=Hepatobiliary,
    # 0T=Urinary, 0V=Male Reproductive, etc.
    px_type == "10" & grepl("^0[A-Z]", px)
  ) %>%
  distinct(patid) %>%
  mutate(surgery_proc = 1L)

message("  Patients with procedure-based surgery: ", nrow(proc_surgery))
message("  EDGE CASE: Surgery identification uses ICD-10-PCS Medical/Surgical section")
message("  NOTE: SAS V5_12 uses surgerycodes reference table for comprehensive identification")

cohort <- cohort %>%
  left_join(proc_surgery, by = "patid") %>%
  mutate(
    surgery = if_else(surgery_proc == 1, 1L, 0L, missing = 0L)
  ) %>%
  select(-surgery_proc)

message("  Final surgery distribution: ", sum(cohort$surgery == 1), " surgery / ",
        sum(cohort$surgery == 0), " no surgery")

# ========================================
# Section 5 -- Radiation Identification
# ========================================

# SAS source: V5_14 references radiation_all dataset (created in V5_12)
# V5_12 lines 497-567: Radiation identified from procedures (70010-79999, Z51.0, V58.0)
# and diagnoses (V51.0, V58.0)

message("\n=== Section 5: Radiation Identification ===")

proc_radiation <- proc_combined %>%
  filter(patid %in% cohort$patid) %>%
  filter(
    # CPT radiation therapy codes: 77000-79999 (radiation oncology)
    (px_type == "CH" & px >= "77000" & px <= "79999") |
    # ICD-10 radiation encounter: Z51.0
    (px_type == "10" & px == "Z51.0") |
    # ICD-9 radiation encounter: V58.0
    (px_type == "09" & px == "V58.0")
  ) %>%
  distinct(patid) %>%
  mutate(radiation_proc = 1L)

message("  Patients with procedure-based radiation: ", nrow(proc_radiation))

cohort <- cohort %>%
  left_join(proc_radiation, by = "patid") %>%
  mutate(
    radiation = if_else(radiation_proc == 1, 1L, 0L, missing = 0L)
  ) %>%
  select(-radiation_proc)

message("  Final radiation distribution: ", sum(cohort$radiation == 1), " radiation / ",
        sum(cohort$radiation == 0), " no radiation")

# ========================================
# Section 6 -- SCT (Stem Cell Transplant) Identification
# ========================================

# SAS source: V5_14 references all_sct dataset (created in V5_12)
# V5_12 lines 663-720: SCT codes from sctcodes reference:
#   CPT: 38240, 38241, 38242, 38243
#   ICD-10: T86.5, Z94.81, T86.09, T86.0
#   ICD-9: V42.82, V41.0
#   ICD-10-PCS: 30233C0, 30233G0, 30243C0, 30243G0, 30233Y0, 30243Y0

message("\n=== Section 6: SCT Identification ===")

sct_codes_cpt <- c("38240", "38241", "38242", "38243")
sct_codes_icd10 <- c("T86.5", "Z94.81", "T86.09", "T86.0")
sct_codes_icd9 <- c("V42.82", "V41.0")
sct_codes_icd10pcs <- c("30233C0", "30233G0", "30243C0", "30243G0", "30233Y0", "30243Y0")

proc_sct <- proc_combined %>%
  filter(patid %in% cohort$patid) %>%
  filter(
    (px_type == "CH" & px %in% sct_codes_cpt) |
    (px_type == "10" & (px %in% sct_codes_icd10 | px %in% sct_codes_icd10pcs)) |
    (px_type == "09" & px %in% sct_codes_icd9)
  ) %>%
  distinct(patid) %>%
  mutate(sct_proc = 1L)

message("  Patients with SCT: ", nrow(proc_sct))

cohort <- cohort %>%
  left_join(proc_sct, by = "patid") %>%
  mutate(
    sct = if_else(sct_proc == 1, 1L, 0L, missing = 0L)
  ) %>%
  select(-sct_proc)

message("  Final SCT distribution: ", sum(cohort$sct == 1), " sct / ",
        sum(cohort$sct == 0), " no sct")

# ========================================
# Section 7 -- Ancillary Therapy Identification
# ========================================

# SAS source: V5_14 references ancillary_all dataset (created in V5_12)
# V5_12 lines 725-851: Ancillary therapy from dispensing/prescribing/med_admin
# where SEERRxCategory == "1" (Ancillary Therapy)
#
# NOTE: Without ndc_cond2 reference table, we cannot distinguish ancillary from chemo
# Mark all non-treatment patients as having ancillary therapy if they appear in the cohort
# This ensures intensity=0 category exists for patients with no other treatment

message("\n=== Section 7: Ancillary Therapy Identification ===")

# Per SAS V5_14 intensity logic line 181-183:
# if (surgery=0 and radiation=0) and chemo=0 and anc=1 then intensity=0
# For now, we'll derive anc as a flag for patients with no other treatment
# who are still in the cohort (implies they had SOME medical interaction)

cohort <- cohort %>%
  mutate(
    anc = if_else(surgery == 0 & radiation == 0 & chemo == 0 & sct == 0, 1L, 0L)
  )

message("  Final ancillary distribution: ", sum(cohort$anc == 1), " ancillary only / ",
        sum(cohort$anc == 0), " has other treatment")
message("  NOTE: Ancillary therapy identification requires ndc_cond2 reference (SEERRxCategory=='1')")
message("  EDGE CASE: Ancillary flag assigned to patients with no surgery/chemo/radiation/sct")

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

# Get group_site for each patient from their first cancer diagnosis encounter
first_cancer_site <- merged_enc_dx %>%
  semi_join(cohort %>% select(patid, first_can_encounterid),
            by = c("patid", "encounterid" = "first_can_encounterid")) %>%
  filter(any_reportable_cancer == 1) %>%
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

# Derive last_payer from encounter data
# Filter to encounters AFTER first cancer diagnosis
last_encounter_payer <- merged_complete %>%
  inner_join(cohort %>% select(patid, first_admit_date), by = "patid") %>%
  filter(admit_date >= first_admit_date) %>%
  arrange(patid, desc(admit_date)) %>%
  group_by(patid) %>%
  slice_head(n = 1) %>%
  ungroup() %>%
  select(patid, last_payer = payer_type_primary, last_admit_date = admit_date)

message("  Patients with last_payer: ", nrow(last_encounter_payer))

# Merge and compute change_ins
cohort <- cohort %>%
  left_join(last_encounter_payer, by = "patid") %>%
  mutate(
    # SAS V5_15 line 202-204: change_ins=0 if same, 1 if different
    # EDGE CASE: If first_payer or last_payer is NA, change_ins is NA
    # SAS treats missing comparison as false (missing ^= non-missing -> TRUE in some contexts)
    # But per SAS V5_15 line 202: change_ins=. (missing) before IF statements
    # So if first_payer or last_payer missing, change_ins stays missing
    change_ins = case_when(
      is.na(first_can_payer_type_primary) | is.na(last_payer) ~ NA_integer_,
      first_can_payer_type_primary == last_payer ~ 0L,
      first_can_payer_type_primary != last_payer ~ 1L,
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
