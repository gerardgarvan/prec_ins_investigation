# tests/testthat/helper-phase3-fixtures.R
# Mock data fixtures for Phase 3 analytical dataset construction test infrastructure
# Provides realistic PCORnet CDM patient-level data for testing cohort, exposure, outcome, and covariate logic
# without requiring actual data files
#
# Fixture design: 15 patients (P101-P115) with deterministic expected values for all Phase 3 requirements
# Uses mock_p3_* prefix to avoid collision with Phase 2 mock_* fixtures

library(tibble)
library(dplyr)
library(lubridate)

# ==============================================================================
# EXPECTED COHORT COUNTS (for test assertions)
# ==============================================================================
# Starting cohort: 15 patients
# After valid enrollment filter (COH-01): 13 patients (P114, P115 excluded — no valid enrollment)
# After cancer dx filter (COH-02): 10 patients (P111, P112, P113 excluded — no reportable cancer)
# After age >= 18 (COH-03): 9 patients (P109 excluded — age 12)
# After sex != "UN" (COH-03): 8 patients (P110 excluded — sex="UN")
# Final cohort: 8 patients (P101-P108)
#
# Change_ins distribution (EXP-01):
#   change_ins=1: P101 (Private->Medicare), P103 (Medicaid->Private), P105 (Private->Medicaid), P106 (Medicare->dual) = 4 patients
#   change_ins=0: P102 (Medicare->Medicare), P104 (Private->Private), P107 (Private->Private), P108 (Medicare->Medicare) = 4 patients
#
# Treatment intensity distribution (EXP-02):
#   intensity=0 (ancillary only): P108
#   intensity=1 (surgery only): P106
#   intensity=2 (chemo only): P104
#   intensity=3 (radiation only): P107
#   intensity=4 (surgery+chemo): P101
#   intensity=5 (surgery+radiation): P102
#   intensity=7 (surgery+chemo+radiation): P103
#   intensity=8 (sct): P105

# ==============================================================================
# Mock SAS Formats (subset needed for Phase 3 tests)
# ==============================================================================

mock_p3_sas_formats <- list()

# PCORnet CDM standard formats
mock_p3_sas_formats$race <- list(
  levels = c("01", "02", "03", "04", "05", "06", "07", "NI", "UN", "OT"),
  labels = c("American Indian or Alaska Native", "Asian",
             "Black or African American", "Native Hawaiian or Other Pacific Islander",
             "White", "Multiple race", "Refuse to answer", "No information",
             "Unknown", "Other")
)

mock_p3_sas_formats$sex <- list(
  levels = c("A", "F", "M", "NI", "UN", "OT"),
  labels = c("Ambiguous", "Female", "Male", "No information", "Unknown", "Other")
)

mock_p3_sas_formats$hispanic <- list(
  levels = c("Y", "N", "R", "NI", "UN", "OT"),
  labels = c("Yes", "No", "Refuse to answer", "No information", "Unknown", "Other")
)

mock_p3_sas_formats$enc_type <- list(
  levels = c("AV", "ED", "EI", "IP", "IS", "OS", "IC", "TH", "OA", "NI", "UN", "OT"),
  labels = c("Ambulatory Visit", "Emergency Department",
             "Emergency Department Admit to Inpatient Hospital Stay (permissible substitution)",
             "Inpatient Hospital Stay", "Non-Acute Institutional Stay", "Observation Stay",
             "Institutional Professional Consult (permissible substitution)", "Telehealth",
             "Other Ambulatory Visit", "No information", "Unknown", "Other")
)

# Study-specific formats
mock_p3_sas_formats$p_payer <- list(
  levels = c("5", "1", "2", "3", "4", "8", "9", "U"),
  labels = c("Private", "Medicare", "Medicaid", "Private", "Med_Medicaid",
             "Uninsured", "Other", "Unknown")
)

mock_p3_sas_formats$agef <- list(
  levels = c(1, 2, 3, 4, 5),
  labels = c("0-14", "15-39", "40-54", "55-64", "65-91")
)

mock_p3_sas_formats$gsite <- list(
  levels = c("Bones, joints, soft tissue", "Breast", "Digestive",
             "Eye, brain, CNS, endocrine", "Hematologic", "Oral, respiratory",
             "Skin", "Urinary", "Female Genital System", "Male Genital System",
             "Reportable but not mapped above", "Other", "In situ"),
  labels = c("Bones, joints, soft tissue", "Breast", "Digestive",
             "Eye, brain, CNS, endocrine", "Hematologic", "Oral, respiratory",
             "Skin", "Genitourinary", "Genitourinary", "Genitourinary",
             "Other", "Other", "Other")
)

mock_p3_sas_formats$r <- list(
  levels = c("05", "03", "01", "02", "04", "06", "NI", "UN", "OT"),
  labels = c("WH", "AA", "OT", "OT", "OT", "OT", "UN", "UN", "OT")
)

mock_p3_sas_formats$int <- list(
  levels = c(0, 1, 2, 3, 4),
  labels = c("0", "1", "2", "3", "4")
)

# ==============================================================================
# Mock Demographics (15 patients)
# ==============================================================================

mock_p3_demo <- tibble(
  patid = c("P101", "P102", "P103", "P104", "P105", "P106", "P107", "P108", "P109", "P110",
            "P111", "P112", "P113", "P114", "P115"),
  birth_date = as.Date(c("1960-03-15", "1952-06-20", "1977-11-08", "1967-04-12", "1984-09-25",
                         "1950-01-30", "1972-05-17", "1954-08-22", "2010-02-14", "1962-07-19",
                         "1965-10-05", "1958-12-11", "1980-03-28", "1970-06-15", "1975-09-03")),
  sex = c("F", "M", "F", "M", "F", "M", "F", "M", "F", "UN",
          "F", "M", "F", "M", "F"),
  race = c("05", "03", "05", "01", "05", "03", "02", "05", "05", "UN",
           "05", "03", "05", "05", "05"),
  hispanic = c("N", "N", "Y", "N", "N", "N", "N", "UN", "N", "N",
               "N", "N", "N", "N", "N"),
  deceased = c(NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA),
  source = rep("EHR", 15),
  age = c(62, 70, 45, 55, 38, 72, 50, 68, 12, 60,
          57, 64, 42, 52, 47),
  age2 = c(4, 5, 3, 4, 2, 5, 3, 5, 1, 4,
           4, 5, 3, 4, 3),  # agef categories: 1=0-14, 2=15-39, 3=40-54, 4=55-64, 5=65+
  valid_id = c(1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
               1, 1, 1, 0, 0),  # P114, P115 fail valid enrollment
  gender_identity = rep("NI", 15),
  sexual_orientation = rep("NI", 15),
  new_pt = c(0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0),
  enr_end_date = as.Date(c("2022-12-31", "2022-12-31", "2022-12-31", "2022-12-31", "2022-12-31",
                           "2022-12-31", "2022-12-31", "2022-12-31", "2022-12-31", "2022-12-31",
                           "2022-12-31", "2022-12-31", "2022-12-31", NA, NA))
)

# ==============================================================================
# Mock Enrollment (13 patients with valid enrollment)
# ==============================================================================

mock_p3_enrollment <- tibble(
  patid = c("P101", "P102", "P103", "P104", "P105", "P106", "P107", "P108", "P109", "P110",
            "P111", "P112", "P113"),
  enr_start_date = as.Date(c("2019-01-01", "2019-01-01", "2019-06-01", "2019-01-01", "2019-03-01",
                             "2019-01-01", "2019-01-01", "2019-01-01", "2019-01-01", "2019-01-01",
                             "2019-01-01", "2019-01-01", "2019-01-01")),
  enr_end_date = as.Date(c("2022-12-31", "2022-12-31", "2022-12-31", "2022-12-31", "2022-12-31",
                           "2022-12-31", "2022-12-31", "2022-12-31", "2022-12-31", "2022-12-31",
                           "2022-12-31", "2022-12-31", "2022-12-31")),
  valid_id = rep(1, 13)
)

# ==============================================================================
# Mock Encounters (2-4 encounters per cohort patient)
# ==============================================================================

mock_p3_encounters <- bind_rows(
  # P101: 4 encounters (1 pre-cancer, 3 post-cancer)
  tibble(
    patid = rep("P101", 4),
    encounterid = c("E101_001", "E101_002", "E101_003", "E101_004"),
    enc_type = c("AV", "AV", "AV", "IP"),
    admit_date = as.Date(c("2019-03-10", "2019-08-15", "2020-02-20", "2020-06-10")),
    discharge_date = as.Date(c("2019-03-10", "2019-08-15", "2020-02-20", "2020-06-15")),
    providerid = c("PROV001", "PROV002", "PROV002", "PROV003"),
    payer_type_primary = c("5", "5", "1", "1"),  # Private -> Medicare (change_ins=1)
    payer_type_primary2 = c("Private", "Private", "Medicare", "Medicare")
  ),
  # P102: 3 encounters (1 pre-cancer, 2 post-cancer)
  tibble(
    patid = rep("P102", 3),
    encounterid = c("E102_001", "E102_002", "E102_003"),
    enc_type = c("AV", "AV", "IP"),
    admit_date = as.Date(c("2019-02-05", "2019-09-12", "2020-03-18")),
    discharge_date = as.Date(c("2019-02-05", "2019-09-12", "2020-03-25")),
    providerid = c("PROV002", "PROV002", "PROV003"),
    payer_type_primary = c("1", "1", "1"),  # Medicare -> Medicare (change_ins=0)
    payer_type_primary2 = c("Medicare", "Medicare", "Medicare")
  ),
  # P103: 3 encounters (1 pre-cancer, 2 post-cancer)
  tibble(
    patid = rep("P103", 3),
    encounterid = c("E103_001", "E103_002", "E103_003"),
    enc_type = c("TH", "TH", "AV"),
    admit_date = as.Date(c("2019-07-08", "2019-12-20", "2020-05-15")),
    discharge_date = as.Date(c("2019-07-08", "2019-12-20", "2020-05-15")),
    providerid = c("PROV004", "PROV004", "PROV005"),
    payer_type_primary = c("2", "5", "5"),  # Medicaid -> Private (change_ins=1)
    payer_type_primary2 = c("Medicaid", "Private", "Private")
  ),
  # P104: 2 encounters (1 pre-cancer, 1 post-cancer)
  tibble(
    patid = rep("P104", 2),
    encounterid = c("E104_001", "E104_002"),
    enc_type = c("AV", "AV"),
    admit_date = as.Date(c("2019-04-22", "2019-11-10")),
    discharge_date = as.Date(c("2019-04-22", "2019-11-10")),
    providerid = c("PROV002", "PROV002"),
    payer_type_primary = c("5", "5"),  # Private -> Private (change_ins=0)
    payer_type_primary2 = c("Private", "Private")
  ),
  # P105: 3 encounters (1 pre-cancer, 2 post-cancer)
  tibble(
    patid = rep("P105", 3),
    encounterid = c("E105_001", "E105_002", "E105_003"),
    enc_type = c("AV", "AV", "IP"),
    admit_date = as.Date(c("2019-06-15", "2020-01-08", "2020-07-22")),
    discharge_date = as.Date(c("2019-06-15", "2020-01-08", "2020-07-28")),
    providerid = c("PROV002", "PROV002", "PROV003"),
    payer_type_primary = c("5", "2", "2"),  # Private -> Medicaid (change_ins=1)
    payer_type_primary2 = c("Private", "Medicaid", "Medicaid")
  ),
  # P106: 2 encounters (1 pre-cancer, 1 post-cancer)
  tibble(
    patid = rep("P106", 2),
    encounterid = c("E106_001", "E106_002"),
    enc_type = c("IP", "IP"),
    admit_date = as.Date(c("2019-05-10", "2020-02-14")),
    discharge_date = as.Date(c("2019-05-17", "2020-02-20")),
    providerid = c("PROV003", "PROV005"),
    payer_type_primary = c("1", "4"),  # Medicare -> dual Med_Medicaid (change_ins=1)
    payer_type_primary2 = c("Medicare", "Med_Medicaid")
  ),
  # P107: 3 encounters (1 pre-cancer, 2 post-cancer)
  tibble(
    patid = rep("P107", 3),
    encounterid = c("E107_001", "E107_002", "E107_003"),
    enc_type = c("AV", "AV", "TH"),
    admit_date = as.Date(c("2019-08-20", "2020-01-15", "2020-06-30")),
    discharge_date = as.Date(c("2019-08-20", "2020-01-15", "2020-06-30")),
    providerid = c("PROV002", "PROV002", "PROV002"),
    payer_type_primary = c("5", "5", "5"),  # Private -> Private (change_ins=0)
    payer_type_primary2 = c("Private", "Private", "Private")
  ),
  # P108: 2 encounters (1 pre-cancer, 1 post-cancer)
  tibble(
    patid = rep("P108", 2),
    encounterid = c("E108_001", "E108_002"),
    enc_type = c("TH", "TH"),
    admit_date = as.Date(c("2019-09-05", "2020-03-12")),
    discharge_date = as.Date(c("2019-09-05", "2020-03-12")),
    providerid = c("PROV005", "PROV005"),
    payer_type_primary = c("1", "1"),  # Medicare -> Medicare (change_ins=0)
    payer_type_primary2 = c("Medicare", "Medicare")
  )
)

# ==============================================================================
# Mock Diagnoses (cancer codes + ICD personal treatment history codes)
# ==============================================================================

mock_p3_dx <- bind_rows(
  # P101: Breast cancer C50.911, has Z92.21 (personal history of chemo)
  tibble(
    patid = rep("P101", 3),
    encounterid = c("E101_002", "E101_003", "E101_003"),
    dx = c("C50.911", "C50.911", "Z92.21"),
    dx_type = c("10", "10", "10"),
    any_reportable_cancer = c(1, 1, 0),
    group_site = c("Breast", "Breast", NA),
    group_detailed_site = c("Breast - Female", "Breast - Female", NA),
    group_primary_disease_site = c("Breast", "Breast", NA)
  ),
  # P102: Prostate cancer C61, has Z92.3 (personal history of radiation)
  tibble(
    patid = rep("P102", 3),
    encounterid = c("E102_002", "E102_003", "E102_003"),
    dx = c("C61", "C61", "Z92.3"),
    dx_type = c("10", "10", "10"),
    any_reportable_cancer = c(1, 1, 0),
    group_site = c("Male Genital System", "Male Genital System", NA),
    group_detailed_site = c("Prostate", "Prostate", NA),
    group_primary_disease_site = c("Prostate", "Prostate", NA)
  ),
  # P103: Colon cancer C18.7, no ICD personal treatment history
  tibble(
    patid = rep("P103", 2),
    encounterid = c("E103_002", "E103_003"),
    dx = c("C18.7", "C18.7"),
    dx_type = c("10", "10"),
    any_reportable_cancer = c(1, 1),
    group_site = c("Digestive", "Digestive"),
    group_detailed_site = c("Colon", "Colon"),
    group_primary_disease_site = c("Colon", "Colon")
  ),
  # P104: Lung cancer C34.90, no ICD personal treatment history
  tibble(
    patid = rep("P104", 1),
    encounterid = c("E104_002"),
    dx = c("C34.90"),
    dx_type = c("10"),
    any_reportable_cancer = c(1),
    group_site = c("Oral, respiratory"),
    group_detailed_site = c("Lung and Bronchus"),
    group_primary_disease_site = c("Lung")
  ),
  # P105: Leukemia C91.10, has V15.3 (personal history of surgery)
  tibble(
    patid = rep("P105", 3),
    encounterid = c("E105_002", "E105_003", "E105_002"),
    dx = c("C91.10", "C91.10", "V15.3"),
    dx_type = c("10", "10", "09"),
    any_reportable_cancer = c(1, 1, 0),
    group_site = c("Hematologic", "Hematologic", NA),
    group_detailed_site = c("Leukemia", "Leukemia", NA),
    group_primary_disease_site = c("Leukemia", "Leukemia", NA)
  ),
  # P106: Kidney cancer C64.9, no ICD personal treatment history
  tibble(
    patid = rep("P106", 1),
    encounterid = c("E106_002"),
    dx = c("C64.9"),
    dx_type = c("10"),
    any_reportable_cancer = c(1),
    group_site = c("Urinary"),
    group_detailed_site = c("Kidney and Renal Pelvis"),
    group_primary_disease_site = c("Kidney")
  ),
  # P107: Breast cancer C50.912, has Z92.21
  tibble(
    patid = rep("P107", 3),
    encounterid = c("E107_002", "E107_003", "E107_002"),
    dx = c("C50.912", "C50.912", "Z92.21"),
    dx_type = c("10", "10", "10"),
    any_reportable_cancer = c(1, 1, 0),
    group_site = c("Breast", "Breast", NA),
    group_detailed_site = c("Breast - Female", "Breast - Female", NA),
    group_primary_disease_site = c("Breast", "Breast", NA)
  ),
  # P108: Rectal cancer C20, no ICD personal treatment history
  tibble(
    patid = rep("P108", 1),
    encounterid = c("E108_002"),
    dx = c("C20"),
    dx_type = c("10"),
    any_reportable_cancer = c(1),
    group_site = c("Digestive"),
    group_detailed_site = c("Rectum and Rectosigmoid Junction"),
    group_primary_disease_site = c("Rectum")
  ),
  # P111-P113: No cancer dx (will be excluded at cancer dx step)
  # P109, P110: Have cancer dx but will be excluded by age/sex criteria
  tibble(
    patid = "P109",
    encounterid = "E109_001",
    dx = "C91.10",
    dx_type = "10",
    any_reportable_cancer = 1,
    group_site = "Hematologic",
    group_detailed_site = "Leukemia",
    group_primary_disease_site = "Leukemia"
  ),
  tibble(
    patid = "P110",
    encounterid = "E110_001",
    dx = "C50.911",
    dx_type = "10",
    any_reportable_cancer = 1,
    group_site = "Breast",
    group_detailed_site = "Breast - Male",
    group_primary_disease_site = "Breast"
  )
)

# ==============================================================================
# Mock Provider + Specialty (merged)
# ==============================================================================

mock_p3_provider_full <- tibble(
  providerid = c("PROV001", "PROV002", "PROV003", "PROV004", "PROV005"),
  provider_specialty_primary = c("207RC0000X", "207RX0202X", "207Q00000X",
                                  "207V00000X", "208D00000X"),
  cancer_provider = c(1, 1, 0, 0, 0),
  provider_classification = c("Oncology", "Oncology", "Family Medicine",
                               "Ophthalmology", "General Practice"),
  provider_specialization = c("Medical Oncology", "Radiation Oncology",
                               "Family Practice", "Ophthalmology",
                               "General Practice")
)

# ==============================================================================
# Mock Dispensing (chemotherapy NDC codes)
# ==============================================================================

mock_p3_dispensing <- tibble(
  patid = c("P101", "P101", "P103", "P104"),
  ndc = c("00069012001", "00069012001", "00024581620", "00015321701"),  # Example chemo NDCs
  dispense_date = as.Date(c("2019-09-01", "2019-10-01", "2019-12-25", "2019-11-15"))
)

# ==============================================================================
# Mock Procedures (surgery, radiation, chemo procedure codes)
# ==============================================================================

mock_p3_proc <- bind_rows(
  # P101: Surgery (0F128ZZ breast), Chemo (96413)
  tibble(
    patid = rep("P101", 2),
    encounterid = c("E101_002", "E101_003"),
    px = c("0F128ZZ", "96413"),
    px_type = c("10", "CH"),
    px_date = as.Date(c("2019-08-15", "2020-02-20"))
  ),
  # P102: Surgery (0VT08ZZ prostate), Radiation (77301)
  tibble(
    patid = rep("P102", 2),
    encounterid = c("E102_002", "E102_003"),
    px = c("0VT08ZZ", "77301"),
    px_type = c("10", "CH"),
    px_date = as.Date(c("2019-09-12", "2020-03-18"))
  ),
  # P103: Surgery (0DB74ZZ colon), Chemo, Radiation
  tibble(
    patid = rep("P103", 3),
    encounterid = c("E103_002", "E103_002", "E103_003"),
    px = c("0DB74ZZ", "96413", "77301"),
    px_type = c("10", "CH", "CH"),
    px_date = as.Date(c("2019-12-20", "2019-12-20", "2020-05-15"))
  ),
  # P104: Chemo only
  tibble(
    patid = "P104",
    encounterid = "E104_002",
    px = "96413",
    px_type = "CH",
    px_date = as.Date("2019-11-10")
  ),
  # P105: SCT (00HE33Z1 stem cell transplant)
  tibble(
    patid = "P105",
    encounterid = "E105_003",
    px = "00HE33Z1",
    px_type = "10",
    px_date = as.Date("2020-07-22")
  ),
  # P106: Surgery only (0TT08ZZ kidney)
  tibble(
    patid = "P106",
    encounterid = "E106_002",
    px = "0TT08ZZ",
    px_type = "10",
    px_date = as.Date("2020-02-14")
  ),
  # P107: Radiation only
  tibble(
    patid = "P107",
    encounterid = "E107_002",
    px = "77301",
    px_type = "CH",
    px_date = as.Date("2020-01-15")
  )
  # P108: Ancillary only (no surgery/chemo/radiation/sct) — intensity=0
)

# ==============================================================================
# Mock RUCA (Rural-Urban Commuting Area codes)
# ==============================================================================

mock_p3_ruca <- tibble(
  patid = c("P101", "P102", "P103", "P104", "P105", "P106", "P107", "P108"),
  ruca = c(1, 0, 2, 1, 0, 3, 1, 0),  # 0=Metropolitan, 1=Micropolitan, 2=Small town, 3=Rural
  ruca_broad = c("Metropolitan", "Metropolitan", "Small town", "Metropolitan",
                 "Metropolitan", "Rural areas", "Metropolitan", "Metropolitan")
)

# ==============================================================================
# Mock SDI (Social Deprivation Index scores)
# ==============================================================================

mock_p3_sdi <- tibble(
  patid = c("P101", "P102", "P103", "P104", "P105", "P106", "P107", "P108"),
  sdi_score = c(30, 55, 80, 42, 65, 90, 35, 48),
  first_sdi2 = c(1, 2, 3, 1, 2, 3, 1, 2)  # <=45->1, <74->2, <=100->3
)

# ==============================================================================
# DETERMINISTIC TEST VALUES SUMMARY
# ==============================================================================
# Cohort attrition:
#   15 patients -> 13 (valid enrollment) -> 10 (cancer dx) -> 9 (age>=18) -> 8 (sex!="UN")
#
# Change_ins:
#   P101=1, P102=0, P103=1, P104=0, P105=1, P106=1, P107=0, P108=0
#
# Intensity:
#   P101=4 (surgery+chemo), P102=5 (surgery+radiation), P103=7 (surgery+chemo+radiation),
#   P104=2 (chemo), P105=8 (sct), P106=1 (surgery), P107=3 (radiation), P108=0 (ancillary)
#
# Cancer provider encounters (post-first-cancer-dx, non-acute, cancer provider):
#   P101: E101_003 (AV, PROV002=cancer)
#   P102: E102_002, E102_003 (AV, PROV002=cancer)
#   P104: E104_002 (AV, PROV002=cancer)
#   P105: E105_002 (AV, PROV002=cancer)
#   P107: E107_002, E107_003 (AV+TH, PROV002=cancer)
#
# Survivorship visits (non-acute + cancer provider + ICD personal trt):
#   P101: E101_003 (has Z92.21, AV, PROV002)
#   P102: E102_002 or E102_003 (has Z92.3, AV, PROV002)
#   P105: E105_002 (has V15.3, AV, PROV002)
#   P107: E107_002 or E107_003 (has Z92.21, AV+TH, PROV002)
#
# Person-time examples:
#   P101: 2020-06-10 (last) - 2019-08-15 (first cancer dx) = 300 days
#   P102: 2020-03-18 (last) - 2019-09-12 (first) = 188 days

message("Phase 3 mock fixtures loaded: 15 patients (8 in final cohort)")
message("Expected counts: 13 valid enrollment, 10 cancer dx, 9 age>=18, 8 sex!='UN'")
message("Fixture objects: mock_p3_demo, mock_p3_enrollment, mock_p3_encounters, mock_p3_dx, mock_p3_provider_full, mock_p3_dispensing, mock_p3_proc, mock_p3_ruca, mock_p3_sdi, mock_p3_sas_formats")
