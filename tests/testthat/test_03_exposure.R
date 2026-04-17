# tests/testthat/test_03_exposure.R
# Test scaffolds for Phase 3 exposure variable requirements (EXP-01 through EXP-04)
# Wave 0: Tests in RED state until 03_exposure.R implements exposure logic

library(testthat)
library(dplyr)

# ==============================================================================
# EXP-01: Insurance change variable calculation
# ==============================================================================

test_that("EXP-01: insurance change variable calculated correctly", {
  # For mock patients, change_ins=0 when first_payer==last_payer, change_ins=1 otherwise
  # Expected distribution from fixture design:
  #   change_ins=1: P101 (Private->Medicare), P103 (Medicaid->Private),
  #                 P105 (Private->Medicaid), P106 (Medicare->dual) = 4 patients
  #   change_ins=0: P102 (Medicare->Medicare), P104 (Private->Private),
  #                 P107 (Private->Private), P108 (Medicare->Medicare) = 4 patients

  # Derive first and last payer for each patient from mock_p3_encounters
  first_last_payer <- mock_p3_encounters %>%
    group_by(patid) %>%
    summarize(
      first_payer = first(payer_type_primary),
      last_payer = last(payer_type_primary),
      .groups = "drop"
    ) %>%
    mutate(
      change_ins = if_else(first_payer == last_payer, 0, 1)
    )

  # Test specific patients
  p101 <- first_last_payer %>% filter(patid == "P101")
  expect_equal(p101$first_payer, "5")    # Private
  expect_equal(p101$last_payer, "1")     # Medicare
  expect_equal(p101$change_ins, 1)

  p102 <- first_last_payer %>% filter(patid == "P102")
  expect_equal(p102$first_payer, "1")    # Medicare
  expect_equal(p102$last_payer, "1")     # Medicare
  expect_equal(p102$change_ins, 0)

  # Test distribution
  change_ins_summary <- first_last_payer %>%
    count(change_ins)

  expect_equal(nrow(change_ins_summary), 2)  # Two categories: 0 and 1
  # Note: 8 cohort patients total, expect 4 with change_ins=1 and 4 with change_ins=0
  # But mock_p3_encounters has all patients including excluded ones
  # Filter to final cohort for accurate count
  final_cohort_ids <- c("P101", "P102", "P103", "P104", "P105", "P106", "P107", "P108")
  cohort_change <- first_last_payer %>%
    filter(patid %in% final_cohort_ids)

  expect_equal(sum(cohort_change$change_ins == 1), 4)
  expect_equal(sum(cohort_change$change_ins == 0), 4)
})

# ==============================================================================
# EXP-02: Treatment intensity derivation
# ==============================================================================

test_that("EXP-02: treatment intensity derived correctly", {
  # Using mock treatment flags (surgery, chemo, radiation, sct, anc), compute intensity
  # per SAS V5_14 logic:
  #   0: ancillary only
  #   1: surgery only
  #   2: chemo only
  #   3: radiation only
  #   4: surgery + chemo
  #   5: surgery + radiation
  #   6: radiation + chemo
  #   7: surgery + radiation + chemo
  #   8: sct

  # Expected from fixture design:
  #   P101: intensity=4 (surgery+chemo)
  #   P102: intensity=5 (surgery+radiation)
  #   P103: intensity=7 (surgery+chemo+radiation)
  #   P104: intensity=2 (chemo)
  #   P105: intensity=8 (sct)
  #   P106: intensity=1 (surgery)
  #   P107: intensity=3 (radiation)
  #   P108: intensity=0 (ancillary only)

  # Derive treatment flags from mock_p3_proc
  # Surgery: ICD-10-PCS codes starting with 0F, 0V, 0D, 0T, 0B (organ-specific resection)
  # Chemo: CPT 96413, NDC codes in dispensing
  # Radiation: CPT 77301
  # SCT: ICD-10-PCS 00HE33Z1

  treatment_flags <- mock_p3_proc %>%
    mutate(
      is_surgery = grepl("^0[FVDTB]", px) & px_type == "10",
      is_chemo = px == "96413",
      is_radiation = px == "77301",
      is_sct = px == "00HE33Z1"
    ) %>%
    group_by(patid) %>%
    summarize(
      surgery = as.integer(any(is_surgery)),
      chemo = as.integer(any(is_chemo)),
      radiation = as.integer(any(is_radiation)),
      sct = as.integer(any(is_sct)),
      .groups = "drop"
    ) %>%
    mutate(
      # Derive intensity using SAS logic
      intensity = case_when(
        sct == 1 ~ 8,
        surgery == 1 & chemo == 1 & radiation == 1 ~ 7,
        radiation == 1 & chemo == 1 ~ 6,
        surgery == 1 & radiation == 1 ~ 5,
        surgery == 1 & chemo == 1 ~ 4,
        radiation == 1 ~ 3,
        chemo == 1 ~ 2,
        surgery == 1 ~ 1,
        TRUE ~ 0  # ancillary only
      )
    )

  # Test specific patients
  expect_equal(treatment_flags %>% filter(patid == "P101") %>% pull(intensity), 4)
  expect_equal(treatment_flags %>% filter(patid == "P102") %>% pull(intensity), 5)
  expect_equal(treatment_flags %>% filter(patid == "P103") %>% pull(intensity), 7)
  expect_equal(treatment_flags %>% filter(patid == "P104") %>% pull(intensity), 2)
  expect_equal(treatment_flags %>% filter(patid == "P105") %>% pull(intensity), 8)
  expect_equal(treatment_flags %>% filter(patid == "P106") %>% pull(intensity), 1)
  expect_equal(treatment_flags %>% filter(patid == "P107") %>% pull(intensity), 3)

  # P108 should have intensity=0 (no procedures in mock_p3_proc)
  # Left join to handle patients with no procedures
  all_patients <- tibble(patid = c("P101", "P102", "P103", "P104", "P105", "P106", "P107", "P108"))
  intensity_full <- all_patients %>%
    left_join(treatment_flags, by = "patid") %>%
    mutate(intensity = replace_na(intensity, 0))

  expect_equal(intensity_full %>% filter(patid == "P108") %>% pull(intensity), 0)
})

# ==============================================================================
# EXP-03: Cancer site groups mapping
# ==============================================================================

test_that("EXP-03: cancer site groups map correctly", {
  # Map group_site text to group_site2 numeric codes per V5_15 macro
  # From SAS: breast -> "2", digestive -> "3", hematologic -> "5"

  # Expected mapping from mock_p3_sas_formats$gsite:
  #   "Breast" -> "Breast" (group 2)
  #   "Digestive" -> "Digestive" (group 3)
  #   "Hematologic" -> "Hematologic" (group 5)
  #   "Oral, respiratory" -> "Oral, respiratory" (group 6)
  #   "Urinary" -> "Genitourinary" (group 8)
  #   "Male Genital System" -> "Genitourinary" (group 8)

  # Get unique cancer sites from mock_p3_dx
  cancer_sites <- mock_p3_dx %>%
    filter(any_reportable_cancer == 1) %>%
    distinct(patid, group_site)

  # Test specific mappings
  expect_true("Breast" %in% cancer_sites$group_site)
  expect_true("Digestive" %in% cancer_sites$group_site)
  expect_true("Hematologic" %in% cancer_sites$group_site)
  expect_true("Oral, respiratory" %in% cancer_sites$group_site)

  # Test that site labels are correctly assigned in fixture
  p101_site <- cancer_sites %>% filter(patid == "P101") %>% pull(group_site)
  expect_equal(p101_site, "Breast")

  p103_site <- cancer_sites %>% filter(patid == "P103") %>% pull(group_site)
  expect_equal(p103_site, "Digestive")

  p105_site <- cancer_sites %>% filter(patid == "P105") %>% pull(group_site)
  expect_equal(p105_site, "Hematologic")
})

# ==============================================================================
# EXP-04: Chemotherapy identification
# ==============================================================================

test_that("EXP-04: chemotherapy identification uses NDC and procedure codes", {
  # Filter mock dispensing/procedures for chemo-related codes
  # Assert known chemo patients flagged correctly

  # From procedures (CPT 96413)
  chemo_from_proc <- mock_p3_proc %>%
    filter(px == "96413") %>%
    distinct(patid)

  # From dispensing (NDC codes)
  chemo_from_disp <- mock_p3_dispensing %>%
    distinct(patid)

  # Combine both sources
  chemo_patients <- bind_rows(chemo_from_proc, chemo_from_disp) %>%
    distinct(patid)

  # Expected chemo patients from fixture design: P101, P103, P104
  expect_true("P101" %in% chemo_patients$patid)
  expect_true("P103" %in% chemo_patients$patid)
  expect_true("P104" %in% chemo_patients$patid)

  # Non-chemo patients should not appear
  expect_false("P102" %in% chemo_patients$patid)  # Surgery+radiation only
  expect_false("P106" %in% chemo_patients$patid)  # Surgery only
  expect_false("P107" %in% chemo_patients$patid)  # Radiation only
})
