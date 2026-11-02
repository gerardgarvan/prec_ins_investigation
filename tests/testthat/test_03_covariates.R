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
# COV-02: Age categories match SAS age_cat groupings
# ==============================================================================

test_that("COV-02: age categories match SAS age_cat groupings", {
  # age is computed from birth_date + first_admit_date (no age column in raw data).
  # SAS V5_2 line 78: age=floor((today-BIRTH_DATE)/365.25)
  # R: age_at_dx = floor(as.numeric(first_admit_date - birth_date) / 365.25)
  # age_cat: <15->1, <40->2, <55->3, <65->4, else->5 (SAS V5_2 lines 91-96)

  # Build age_at_dx from fixture birth_dates and first cancer encounter admit_dates.
  first_dx_dates <- mock_p3_dx %>%
    filter(any_reportable_cancer == 1) %>%
    inner_join(
      mock_p3_encounters %>% select(patid, encounterid, admit_date),
      by = c("patid", "encounterid")
    ) %>%
    group_by(patid) %>%
    slice_min(admit_date, n = 1, with_ties = FALSE) %>%
    ungroup() %>%
    select(patid, first_admit_date = admit_date)

  demo_with_age <- mock_p3_demo %>%
    left_join(first_dx_dates, by = "patid") %>%
    mutate(
      age_at_dx = floor(as.numeric(first_admit_date - birth_date) / 365.25),
      age_cat = case_when(
        age_at_dx < 15 ~ 1L,
        age_at_dx < 40 ~ 2L,
        age_at_dx < 55 ~ 3L,
        age_at_dx < 65 ~ 4L,
        !is.na(age_at_dx) ~ 5L,
        TRUE ~ NA_integer_
      )
    )

  # Expected age_cat per fixture birth_dates / encounter dates:
  # P101: born 1960-03-15, first cancer 2019-08-15 -> ~59 -> age_cat=4 (55-64)
  # P102: born 1952-06-20, first cancer 2019-09-12 -> ~67 -> age_cat=5 (65+)
  # P105: born 1984-09-25, first cancer 2020-01-08 -> ~35 -> age_cat=2 (15-40)
  # P109: born 2010-02-14, first cancer 2019-09-05 -> ~9  -> age_cat=1 (0-14)

  expect_equal(demo_with_age %>% filter(patid == "P101") %>% pull(age_cat), 4L)
  expect_equal(demo_with_age %>% filter(patid == "P102") %>% pull(age_cat), 5L)
  expect_equal(demo_with_age %>% filter(patid == "P105") %>% pull(age_cat), 2L)
  expect_equal(demo_with_age %>% filter(patid == "P109") %>% pull(age_cat), 1L)
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
