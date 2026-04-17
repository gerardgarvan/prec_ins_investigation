# tests/testthat/test_03_cohort.R
# Test scaffolds for Phase 3 cohort construction requirements (COH-01 through COH-05)
# Wave 0: Tests in RED state until 03_cohort.R implements cohort logic

library(testthat)
library(dplyr)

# ==============================================================================
# COH-01: Valid enrollment criteria filter
# ==============================================================================

test_that("COH-01: valid enrollment filters correctly", {
  # Filter mock_p3_demo by valid_id==1
  # Expected: 13 patients remain (P114, P115 excluded — no valid enrollment)
  cohort_valid_enr <- mock_p3_demo %>%
    filter(valid_id == 1)

  expect_equal(nrow(cohort_valid_enr), 13)
  expect_true("P101" %in% cohort_valid_enr$patid)
  expect_false("P114" %in% cohort_valid_enr$patid)
  expect_false("P115" %in% cohort_valid_enr$patid)
})

# ==============================================================================
# COH-02: Cancer diagnosis identification
# ==============================================================================

test_that("COH-02: cancer diagnosis identification uses ICD codes", {
  # Filter mock_p3_dx for any_reportable_cancer==1, get distinct patients
  # Expected: 10 unique patient IDs (P111-P113 have no cancer dx among the 15)
  cancer_patients <- mock_p3_dx %>%
    filter(any_reportable_cancer == 1) %>%
    distinct(patid)

  expect_equal(nrow(cancer_patients), 10)
  expect_true("P101" %in% cancer_patients$patid)
  expect_true("P102" %in% cancer_patients$patid)
  expect_false("P111" %in% cancer_patients$patid)
  expect_false("P112" %in% cancer_patients$patid)
  expect_false("P113" %in% cancer_patients$patid)
})

# ==============================================================================
# COH-03: Sequential exclusion with logged patient counts
# ==============================================================================

test_that("COH-03: sequential exclusion logs patient counts", {
  # Apply exclusions in sequence: valid enrollment -> cancer dx -> age>=18 -> sex!="UN"
  # Build attrition tibble

  # Step 1: Starting cohort
  step1 <- mock_p3_demo
  n1 <- nrow(step1)

  # Step 2: Valid enrollment
  step2 <- step1 %>% filter(valid_id == 1)
  n2 <- nrow(step2)

  # Step 3: Cancer diagnosis (join with dx data)
  cancer_patients <- mock_p3_dx %>%
    filter(any_reportable_cancer == 1) %>%
    distinct(patid)
  step3 <- step2 %>%
    semi_join(cancer_patients, by = "patid")
  n3 <- nrow(step3)

  # Step 4: Age >= 18
  step4 <- step3 %>% filter(age >= 18)
  n4 <- nrow(step4)

  # Step 5: Sex != "UN"
  step5 <- step4 %>% filter(sex != "UN")
  n5 <- nrow(step5)

  # Build attrition table
  attrition <- tibble(
    step = 1:5,
    description = c("Starting cohort",
                    "Valid enrollment",
                    "Cancer diagnosis",
                    "Age >= 18",
                    "Sex != UN"),
    n_patients = c(n1, n2, n3, n4, n5),
    n_excluded = c(0, n1 - n2, n2 - n3, n3 - n4, n4 - n5)
  )

  # Assertions
  expect_equal(nrow(attrition), 5)
  expect_true("step" %in% names(attrition))
  expect_true("description" %in% names(attrition))
  expect_true("n_patients" %in% names(attrition))
  expect_true("n_excluded" %in% names(attrition))
  expect_equal(attrition$n_patients[1], 15)  # Starting
  expect_equal(attrition$n_patients[2], 13)  # Valid enrollment
  expect_equal(attrition$n_patients[3], 10)  # Cancer dx
  expect_equal(attrition$n_patients[4], 9)   # Age >= 18
  expect_equal(attrition$n_patients[5], 8)   # Final
})

# ==============================================================================
# COH-04: CONSORT flowchart generation
# ==============================================================================

test_that("COH-04: CONSORT flowchart generates PNG and PDF", {
  # Given an attrition tibble, call CONSORT generation function/code
  # Assert file.exists() for both PNG and PDF in a temp directory

  # Build sample attrition table (from COH-03 logic)
  attrition <- tibble(
    step = 1:5,
    description = c("Starting cohort", "Valid enrollment", "Cancer diagnosis",
                    "Age >= 18", "Sex != UN"),
    n_patients = c(15, 13, 10, 9, 8),
    n_excluded = c(0, 2, 3, 1, 1)
  )

  # Use temporary directory for output
  temp_dir <- tempdir()
  png_path <- file.path(temp_dir, "consort_flowchart.png")
  pdf_path <- file.path(temp_dir, "consort_flowchart.pdf")

  # Placeholder: CONSORT generation function will be implemented in 03_cohort.R
  # For now, create dummy files to test file existence pattern
  # TODO: Replace with actual CONSORT generation function call once implemented

  # Skip test until CONSORT function is implemented
  skip("CONSORT generation function not yet implemented in 03_cohort.R")

  # expect_true(file.exists(png_path))
  # expect_true(file.exists(pdf_path))
})

# ==============================================================================
# COH-05: First cancer diagnosis date identification
# ==============================================================================

test_that("COH-05: first cancer diagnosis date identified correctly", {
  # For each patient, first cancer dx is earliest admit_date where any_reportable_cancer==1
  # Test P101's first_admit_date matches known earliest cancer encounter from fixtures

  # Join dx with encounters to get admit_date for cancer diagnoses
  first_cancer_dates <- mock_p3_dx %>%
    filter(any_reportable_cancer == 1) %>%
    left_join(mock_p3_encounters, by = c("patid", "encounterid")) %>%
    group_by(patid) %>%
    summarize(first_admit_date = min(admit_date, na.rm = TRUE), .groups = "drop")

  # P101's first cancer dx is on E101_002 (2019-08-15 per fixture design)
  p101_first <- first_cancer_dates %>%
    filter(patid == "P101") %>%
    pull(first_admit_date)

  expect_equal(p101_first, as.Date("2019-08-15"))

  # P102's first cancer dx is on E102_002 (2019-09-12)
  p102_first <- first_cancer_dates %>%
    filter(patid == "P102") %>%
    pull(first_admit_date)

  expect_equal(p102_first, as.Date("2019-09-12"))

  # All final cohort patients should have a first_admit_date
  final_cohort_ids <- c("P101", "P102", "P103", "P104", "P105", "P106", "P107", "P108")
  expect_true(all(final_cohort_ids %in% first_cancer_dates$patid))
})
