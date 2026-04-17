# tests/testthat/test_03_covariates.R
# Test scaffolds for Phase 3 covariate processing requirements (COV-01 through COV-04)
# Wave 0: Tests in RED state until 03_covariates.R implements covariate logic

library(testthat)
library(dplyr)

# ==============================================================================
# COV-01: Demographics recoded with PCORnet CDM labels
# ==============================================================================

test_that("COV-01: demographics recoded with PCORnet CDM labels", {
  # sex, race, hispanic recoded to factors with sas_formats levels
  # Assert P101 sex=="F", race factor label matches "White", hispanic=="N" -> "No"

  # Recode sex
  sex_recoded <- factor(
    mock_p3_demo$sex,
    levels = mock_p3_sas_formats$sex$levels,
    labels = mock_p3_sas_formats$sex$labels
  )

  # Recode race
  race_recoded <- factor(
    mock_p3_demo$race,
    levels = mock_p3_sas_formats$race$levels,
    labels = mock_p3_sas_formats$race$labels
  )

  # Recode hispanic
  hispanic_recoded <- factor(
    mock_p3_demo$hispanic,
    levels = mock_p3_sas_formats$hispanic$levels,
    labels = mock_p3_sas_formats$hispanic$labels
  )

  # Test P101 (first patient)
  p101_idx <- which(mock_p3_demo$patid == "P101")
  expect_equal(as.character(sex_recoded[p101_idx]), "Female")
  expect_equal(as.character(race_recoded[p101_idx]), "White")
  expect_equal(as.character(hispanic_recoded[p101_idx]), "No")

  # Test P102 (Black male)
  p102_idx <- which(mock_p3_demo$patid == "P102")
  expect_equal(as.character(sex_recoded[p102_idx]), "Male")
  expect_equal(as.character(race_recoded[p102_idx]), "Black or African American")
  expect_equal(as.character(hispanic_recoded[p102_idx]), "No")

  # Test P103 (Hispanic White female)
  p103_idx <- which(mock_p3_demo$patid == "P103")
  expect_equal(as.character(sex_recoded[p103_idx]), "Female")
  expect_equal(as.character(race_recoded[p103_idx]), "White")
  expect_equal(as.character(hispanic_recoded[p103_idx]), "Yes")
})

# ==============================================================================
# COV-02: Age categories match SAS age2 groupings
# ==============================================================================

test_that("COV-02: age categories match SAS age2 groupings", {
  # age2: <15->1, 15-40->2, 40-54->3, 55-64->4, 65+->5
  # Assert P101 (age 62) -> age2==4, P102 (age 70) -> age2==5, P105 (age 38) -> age2==2

  # Expected from fixture design:
  # P101: age=62 -> age2=4 (55-64)
  # P102: age=70 -> age2=5 (65+)
  # P105: age=38 -> age2=2 (15-40)
  # P109: age=12 -> age2=1 (0-14)

  # Test specific patients
  p101 <- mock_p3_demo %>% filter(patid == "P101")
  expect_equal(p101$age2, 4)

  p102 <- mock_p3_demo %>% filter(patid == "P102")
  expect_equal(p102$age2, 5)

  p105 <- mock_p3_demo %>% filter(patid == "P105")
  expect_equal(p105$age2, 2)

  p109 <- mock_p3_demo %>% filter(patid == "P109")
  expect_equal(p109$age2, 1)

  # Test age2 derivation logic (if implementing from scratch)
  age2_derived <- mock_p3_demo %>%
    mutate(
      age2_calc = case_when(
        age < 15 ~ 1,
        age >= 15 & age < 40 ~ 2,
        age >= 40 & age < 55 ~ 3,
        age >= 55 & age < 65 ~ 4,
        age >= 65 ~ 5,
        TRUE ~ NA_real_
      )
    )

  # All age2 values should match age2_calc
  expect_equal(age2_derived$age2, age2_derived$age2_calc)
})

# ==============================================================================
# COV-03: SDI score categorized into tertiles
# ==============================================================================

test_that("COV-03: SDI score categorized into tertiles", {
  # first_sdi2: <=45->1, <74->2, <=100->3
  # Assert P101 (SDI 30) -> first_sdi2==1, P102 (SDI 55) -> first_sdi2==2, P103 (SDI 80) -> first_sdi2==3

  # Expected from fixture design:
  # P101: sdi_score=30 -> first_sdi2=1
  # P102: sdi_score=55 -> first_sdi2=2
  # P103: sdi_score=80 -> first_sdi2=3

  # Test specific patients
  p101 <- mock_p3_sdi %>% filter(patid == "P101")
  expect_equal(p101$first_sdi2, 1)

  p102 <- mock_p3_sdi %>% filter(patid == "P102")
  expect_equal(p102$first_sdi2, 2)

  p103 <- mock_p3_sdi %>% filter(patid == "P103")
  expect_equal(p103$first_sdi2, 3)

  # Test SDI categorization logic
  sdi_categorized <- mock_p3_sdi %>%
    mutate(
      first_sdi2_calc = case_when(
        sdi_score <= 45 ~ 1,
        sdi_score > 45 & sdi_score < 74 ~ 2,
        sdi_score >= 74 & sdi_score <= 100 ~ 3,
        TRUE ~ NA_real_
      )
    )

  # All first_sdi2 values should match first_sdi2_calc
  expect_equal(sdi_categorized$first_sdi2, sdi_categorized$first_sdi2_calc)
})

# ==============================================================================
# COV-04: RUCA classification processed correctly
# ==============================================================================

test_that("COV-04: RUCA classification processed correctly", {
  # Assert RUCA values mapped to factor levels using sas_formats

  # Expected RUCA values from fixture:
  # P101: ruca=1 (Micropolitan)
  # P102: ruca=0 (Metropolitan)
  # P103: ruca=2 (Small town)
  # P106: ruca=3 (Rural areas)

  # Test that RUCA values are present in fixture
  expect_true("ruca" %in% names(mock_p3_ruca))
  expect_true("ruca_broad" %in% names(mock_p3_ruca))

  # Test specific patients
  p101_ruca <- mock_p3_ruca %>% filter(patid == "P101")
  expect_equal(p101_ruca$ruca, 1)
  expect_equal(p101_ruca$ruca_broad, "Metropolitan")

  p102_ruca <- mock_p3_ruca %>% filter(patid == "P102")
  expect_equal(p102_ruca$ruca, 0)
  expect_equal(p102_ruca$ruca_broad, "Metropolitan")

  p103_ruca <- mock_p3_ruca %>% filter(patid == "P103")
  expect_equal(p103_ruca$ruca, 2)
  expect_equal(p103_ruca$ruca_broad, "Small town")

  p106_ruca <- mock_p3_ruca %>% filter(patid == "P106")
  expect_equal(p106_ruca$ruca, 3)
  expect_equal(p106_ruca$ruca_broad, "Rural areas")

  # Test that RUCA broad categories are correctly assigned
  ruca_categories <- unique(mock_p3_ruca$ruca_broad)
  expect_true("Metropolitan" %in% ruca_categories)
  expect_true("Small town" %in% ruca_categories)
  expect_true("Rural areas" %in% ruca_categories)
})
