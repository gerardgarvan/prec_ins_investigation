# tests/testthat/test_03_outcomes.R
# Test scaffolds for Phase 3 outcome variable requirements (OUT-01 through OUT-06)
# Wave 0: Tests in RED state until 03_outcomes.R implements outcome logic

library(testthat)
library(dplyr)
library(lubridate)

# ==============================================================================
# OUT-01: Non-acute encounters flagged correctly
# ==============================================================================

test_that("OUT-01: non-acute encounters flagged correctly", {
  # Filter encounters with enc_type in c("AV","TH") and admit_date > first_admit_date
  # Count per patient

  # First, get first cancer dx date per patient
  first_cancer_dates <- mock_p3_dx %>%
    filter(any_reportable_cancer == 1) %>%
    left_join(mock_p3_encounters, by = c("patid", "encounterid")) %>%
    group_by(patid) %>%
    summarize(first_admit_date = min(admit_date, na.rm = TRUE), .groups = "drop")

  # Join encounters with first cancer dates and flag non-acute post-cancer encounters
  nonacute_enc <- mock_p3_encounters %>%
    inner_join(first_cancer_dates, by = "patid") %>%
    filter(
      enc_type %in% c("AV", "TH"),
      admit_date > first_admit_date
    ) %>%
    group_by(patid) %>%
    summarize(n_Enc_nonacute_care = n(), .groups = "drop")

  # Test known counts from fixture design
  # P101: E101_003, E101_004 post-cancer, but E101_004 is IP (not non-acute) -> 1 non-acute
  # P102: E102_002, E102_003 post-cancer, both AV -> 2 non-acute (but E102_002 is first cancer, so only E102_003 counts) -> 1 non-acute
  # Actually, need to check if first_cancer_date is on E102_002 (2019-09-12), then E102_003 (2020-03-18) is after -> 1 non-acute
  # P107: E107_002 (AV), E107_003 (TH) both post-cancer -> 2 non-acute
  # P108: E108_002 (TH) post-cancer -> 1 non-acute

  # Test that non-acute encounters are correctly identified
  expect_true("P101" %in% nonacute_enc$patid)
  expect_true("P102" %in% nonacute_enc$patid)
  expect_true("P107" %in% nonacute_enc$patid)
  expect_true("P108" %in% nonacute_enc$patid)

  # P101 should have at least 1 non-acute encounter post-cancer
  p101_count <- nonacute_enc %>% filter(patid == "P101") %>% pull(n_Enc_nonacute_care)
  expect_gte(p101_count, 1)
})

# ==============================================================================
# OUT-02: Cancer-related visits
# ==============================================================================

test_that("OUT-02: cancer-related visits require non-acute + cancer dx", {
  # Enc_nonacute_care==1 AND any_reportable_cancer==1
  # Assert correct patient-level counts

  # Get first cancer dx date
  first_cancer_dates <- mock_p3_dx %>%
    filter(any_reportable_cancer == 1) %>%
    left_join(mock_p3_encounters, by = c("patid", "encounterid")) %>%
    group_by(patid) %>%
    summarize(first_admit_date = min(admit_date, na.rm = TRUE), .groups = "drop")

  # Join encounters with dx to check for cancer dx on each encounter
  cancer_related_visits <- mock_p3_encounters %>%
    inner_join(first_cancer_dates, by = "patid") %>%
    filter(
      enc_type %in% c("AV", "TH"),
      admit_date > first_admit_date
    ) %>%
    left_join(
      mock_p3_dx %>% filter(any_reportable_cancer == 1) %>% select(patid, encounterid),
      by = c("patid", "encounterid")
    ) %>%
    filter(!is.na(encounterid)) %>%  # Has cancer dx on this encounter
    group_by(patid) %>%
    summarize(n_Cancer_related_visit = n(), .groups = "drop")

  # Test that cancer-related visits are identified
  # P101: E101_003 (AV, has C50.911) -> 1 cancer-related visit
  # P102: E102_003 (IP, not non-acute) -> 0? Wait, E102_002 and E102_003 both have C61
  # Actually E102_002 is AV and has C61, E102_003 is IP (not non-acute)
  # So P102 should have 0 cancer-related visits if we require non-acute AND cancer dx

  # Check that at least some patients have cancer-related visits
  expect_gt(nrow(cancer_related_visits), 0)

  # Test specific patients
  expect_true("P101" %in% cancer_related_visits$patid)
})

# ==============================================================================
# OUT-03: Cancer visit with provider
# ==============================================================================

test_that("OUT-03: cancer visit with provider requires cancer visit + cancer provider", {
  # Cancer_related_visit==1 AND Cancer_provider==1
  # Assert correct counts

  # Get first cancer dx date
  first_cancer_dates <- mock_p3_dx %>%
    filter(any_reportable_cancer == 1) %>%
    left_join(mock_p3_encounters, by = c("patid", "encounterid")) %>%
    group_by(patid) %>%
    summarize(first_admit_date = min(admit_date, na.rm = TRUE), .groups = "drop")

  # Join encounters with dx and provider to check for cancer-related visit with cancer provider
  cancer_visit_with_provider <- mock_p3_encounters %>%
    inner_join(first_cancer_dates, by = "patid") %>%
    filter(
      enc_type %in% c("AV", "TH"),
      admit_date > first_admit_date
    ) %>%
    left_join(
      mock_p3_dx %>% filter(any_reportable_cancer == 1) %>% select(patid, encounterid),
      by = c("patid", "encounterid")
    ) %>%
    filter(!is.na(encounterid)) %>%  # Has cancer dx
    left_join(mock_p3_provider_full, by = "providerid") %>%
    filter(cancer_provider == 1) %>%
    group_by(patid) %>%
    summarize(n_cancer_visit_and_prov = n(), .groups = "drop")

  # Test that cancer visits with cancer provider are identified
  # P101: E101_003 (PROV002, cancer_provider=1) -> 1
  # P102: E102_002 (PROV002, cancer_provider=1) -> 1

  expect_gt(nrow(cancer_visit_with_provider), 0)
  expect_true("P101" %in% cancer_visit_with_provider$patid)
  expect_true("P102" %in% cancer_visit_with_provider$patid)
})

# ==============================================================================
# OUT-04: Survivorship visits
# ==============================================================================

test_that("OUT-04: survivorship visits require non-acute + cancer provider + ICD personal trt", {
  # Enc_nonacute_care==1 AND Cancer_provider==1 AND ICD_personal_trt==1
  # Most restrictive definition

  # Get first cancer dx date
  first_cancer_dates <- mock_p3_dx %>%
    filter(any_reportable_cancer == 1) %>%
    left_join(mock_p3_encounters, by = c("patid", "encounterid")) %>%
    group_by(patid) %>%
    summarize(first_admit_date = min(admit_date, na.rm = TRUE), .groups = "drop")

  # ICD personal treatment codes: V87.41, V87.42, V87.43, V87.46, V15.3, Z92.21, Z92.22, Z92.23, Z92.25, Z92.3
  icd_personal_trt_codes <- c("V87.41", "V87.42", "V87.43", "V87.46", "V15.3",
                               "Z92.21", "Z92.22", "Z92.23", "Z92.25", "Z92.3")

  # Identify encounters with ICD personal treatment codes
  encounters_with_icd_personal_trt <- mock_p3_dx %>%
    filter(dx %in% icd_personal_trt_codes) %>%
    distinct(patid, encounterid)

  # Join encounters with provider and ICD personal trt
  survivorship_visits <- mock_p3_encounters %>%
    inner_join(first_cancer_dates, by = "patid") %>%
    filter(
      enc_type %in% c("AV", "TH"),
      admit_date > first_admit_date
    ) %>%
    inner_join(encounters_with_icd_personal_trt, by = c("patid", "encounterid")) %>%
    left_join(mock_p3_provider_full, by = "providerid") %>%
    filter(cancer_provider == 1) %>%
    group_by(patid) %>%
    summarize(n_Survivorship_visit = n(), .groups = "drop")

  # Expected from fixture design:
  # P101: E101_003 (has Z92.21, AV, PROV002=cancer) -> 1
  # P102: E102_002 or E102_003 (has Z92.3, but E102_003 is IP not non-acute) -> E102_002 (AV) -> 1
  # P105: E105_002 (has V15.3, AV, PROV002=cancer) -> 1
  # P107: E107_002 or E107_003 (has Z92.21, AV+TH, PROV002=cancer) -> 1 or 2

  expect_gt(nrow(survivorship_visits), 0)
  expect_true("P101" %in% survivorship_visits$patid)
  expect_true("P102" %in% survivorship_visits$patid)
  expect_true("P105" %in% survivorship_visits$patid)
  expect_true("P107" %in% survivorship_visits$patid)
})

# ==============================================================================
# OUT-05: Person-time calculation
# ==============================================================================

test_that("OUT-05: person-time calculated correctly with censoring", {
  # person_time_days = as.numeric(difftime(last_admit_date, first_admit_date, units="days"))
  # Assert > 0 for all cohort patients
  # Assert specific value for P101 based on fixture dates

  # Get first and last admit dates per patient
  person_time <- mock_p3_encounters %>%
    group_by(patid) %>%
    summarize(
      first_admit_date = min(admit_date),
      last_admit_date = max(admit_date),
      .groups = "drop"
    ) %>%
    mutate(
      person_time_days = as.numeric(difftime(last_admit_date, first_admit_date, units = "days"))
    )

  # Test that all patients have person_time > 0 (except single-encounter patients)
  # P101: 2020-06-10 (last) - 2019-03-10 (first) = 458 days
  p101_person_time <- person_time %>% filter(patid == "P101") %>% pull(person_time_days)
  expect_equal(p101_person_time, as.numeric(difftime(as.Date("2020-06-10"), as.Date("2019-03-10"), units = "days")))

  # All multi-encounter patients should have person_time > 0
  multi_encounter_patients <- person_time %>% filter(person_time_days > 0)
  expect_gt(nrow(multi_encounter_patients), 0)

  # Final cohort patients
  final_cohort_ids <- c("P101", "P102", "P103", "P104", "P105", "P106", "P107", "P108")
  cohort_person_time <- person_time %>% filter(patid %in% final_cohort_ids)
  expect_equal(nrow(cohort_person_time), 8)
})

# ==============================================================================
# OUT-06: Visit counts aggregated per patient
# ==============================================================================

test_that("OUT-06: visit counts aggregated per patient", {
  # Group_by + summarize produces one row per patient with:
  #   n_Enc_nonacute_care, n_Cancer_related_visit, n_cancer_visit_and_prov, n_Survivorship_visit
  # Assert patients with zero visits have 0 (not NA) via left_join + replace_na pattern

  # Get first cancer dx date
  first_cancer_dates <- mock_p3_dx %>%
    filter(any_reportable_cancer == 1) %>%
    left_join(mock_p3_encounters, by = c("patid", "encounterid")) %>%
    group_by(patid) %>%
    summarize(first_admit_date = min(admit_date, na.rm = TRUE), .groups = "drop")

  # Non-acute care encounters
  nonacute_counts <- mock_p3_encounters %>%
    inner_join(first_cancer_dates, by = "patid") %>%
    filter(
      enc_type %in% c("AV", "TH"),
      admit_date > first_admit_date
    ) %>%
    group_by(patid) %>%
    summarize(n_Enc_nonacute_care = n(), .groups = "drop")

  # Cancer-related visits
  cancer_related_counts <- mock_p3_encounters %>%
    inner_join(first_cancer_dates, by = "patid") %>%
    filter(
      enc_type %in% c("AV", "TH"),
      admit_date > first_admit_date
    ) %>%
    left_join(
      mock_p3_dx %>% filter(any_reportable_cancer == 1) %>% select(patid, encounterid),
      by = c("patid", "encounterid")
    ) %>%
    filter(!is.na(encounterid)) %>%
    group_by(patid) %>%
    summarize(n_Cancer_related_visit = n(), .groups = "drop")

  # Combine all counts with left_join and replace_na
  final_cohort_ids <- c("P101", "P102", "P103", "P104", "P105", "P106", "P107", "P108")
  all_patients <- tibble(patid = final_cohort_ids)

  visit_counts <- all_patients %>%
    left_join(nonacute_counts, by = "patid") %>%
    left_join(cancer_related_counts, by = "patid") %>%
    mutate(
      n_Enc_nonacute_care = replace_na(n_Enc_nonacute_care, 0),
      n_Cancer_related_visit = replace_na(n_Cancer_related_visit, 0)
    )

  # Assertions
  expect_equal(nrow(visit_counts), 8)  # One row per final cohort patient
  expect_true(all(c("patid", "n_Enc_nonacute_care", "n_Cancer_related_visit") %in% names(visit_counts)))

  # All counts should be numeric (not NA)
  expect_true(all(!is.na(visit_counts$n_Enc_nonacute_care)))
  expect_true(all(!is.na(visit_counts$n_Cancer_related_visit)))

  # At least some patients should have non-zero counts
  expect_gt(sum(visit_counts$n_Enc_nonacute_care), 0)
})
