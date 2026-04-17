# tests/testthat/test_04_regression.R
# Test scaffolds for Phase 4 regression model requirements
# Covers STA-03 (Poisson), STA-04 (Negative Binomial), STA-05 (regression tables), STA-06 (diagnostics)
# Wave 0: Tests in RED state until production scripts (04_regression.R) implement regression models

library(testthat)
library(dplyr)
library(broom)
library(MASS)
library(AER)
library(gtsummary)

# ==============================================================================
# STA-03: Poisson regression with offset
# ==============================================================================

test_that("STA-03: Poisson regression with person-time offset runs without error", {
  skip_if_not_installed("broom")

  # Fit Poisson regression for survivorship visits
  # Outcome: n_Survivorship_visit
  # Exposure: change_ins
  # Covariates: sex, race2
  # Offset: log(person_time_days)
  model_poisson <- glm(
    n_Survivorship_visit ~ change_ins + sex + race2,
    family = poisson(link = "log"),
    offset = log(person_time_days),
    data = mock_p4_analytical
  )

  # Verify model family is Poisson
  expect_equal(model_poisson$family$family, "poisson")

  # Verify offset is present
  expect_true(!is.null(model_poisson$offset))

  # Extract IRRs (incidence rate ratios) with exponentiate=TRUE
  irr_tbl <- broom::tidy(model_poisson, exponentiate = TRUE)

  # All IRR estimates should be positive (>0)
  expect_true(all(irr_tbl$estimate > 0))

  # Should have term column with change_ins
  expect_true("change_ins" %in% irr_tbl$term)
})

# ==============================================================================
# STA-04: Negative binomial regression
# ==============================================================================

test_that("STA-04: Negative binomial regression handles overdispersion", {
  skip_if_not_installed("MASS")

  # Fit negative binomial regression
  # Same formula as Poisson but allows for overdispersion
  model_nb <- MASS::glm.nb(
    n_Survivorship_visit ~ change_ins + sex + offset(log(person_time_days)),
    data = mock_p4_analytical
  )

  # Verify dispersion parameter theta exists and is positive
  expect_true(!is.null(model_nb$theta))
  expect_true(model_nb$theta > 0)

  # Verify standard error of theta exists
  expect_true(!is.null(model_nb$SE.theta))

  # Extract coefficients
  coef_nb <- broom::tidy(model_nb, exponentiate = TRUE)

  # Should have term column with change_ins
  expect_true("change_ins" %in% coef_nb$term)

  # All IRR estimates should be positive
  expect_true(all(coef_nb$estimate > 0))
})

# ==============================================================================
# STA-05: Regression table format with broom::tidy
# ==============================================================================

test_that("STA-05: Regression table format contains required columns", {
  skip_if_not_installed("broom")

  # Fit Poisson model
  model_poisson <- glm(
    n_Survivorship_visit ~ change_ins + sex + race2,
    family = poisson(link = "log"),
    offset = log(person_time_days),
    data = mock_p4_analytical
  )

  # Extract tidy output with confidence intervals
  tidy_tbl <- broom::tidy(model_poisson, exponentiate = TRUE, conf.int = TRUE)

  # Required columns for regression table
  required_cols <- c("term", "estimate", "std.error", "statistic", "p.value", "conf.low", "conf.high")

  # All required columns should be present
  expect_true(all(required_cols %in% names(tidy_tbl)))

  # All estimates should be positive (IRRs)
  expect_true(all(tidy_tbl$estimate > 0))

  # Confidence intervals should be positive
  expect_true(all(tidy_tbl$conf.low > 0))
  expect_true(all(tidy_tbl$conf.high > 0))

  # conf.low should be less than estimate, estimate less than conf.high
  expect_true(all(tidy_tbl$conf.low <= tidy_tbl$estimate))
  expect_true(all(tidy_tbl$estimate <= tidy_tbl$conf.high))
})

# ==============================================================================
# STA-05: Regression table format with gtsummary::tbl_regression
# ==============================================================================

test_that("STA-05: gtsummary::tbl_regression produces formatted regression table", {
  skip_if_not_installed("gtsummary")

  # Fit Poisson model
  model_poisson <- glm(
    n_Survivorship_visit ~ change_ins + sex + race2,
    family = poisson(link = "log"),
    offset = log(person_time_days),
    data = mock_p4_analytical
  )

  # Create regression table
  tbl_reg <- gtsummary::tbl_regression(
    model_poisson,
    exponentiate = TRUE
  )

  # Verify tbl_regression object class
  expect_true("tbl_regression" %in% class(tbl_reg))

  # Convert to tibble
  tbl_reg_df <- as_tibble(tbl_reg)

  # Should have at least 3 columns (label, estimate, CI or p-value)
  expect_gte(ncol(tbl_reg_df), 3)
})

# ==============================================================================
# STA-06: Overdispersion diagnostics
# ==============================================================================

test_that("STA-06: Overdispersion test with AER::dispersiontest", {
  skip_if_not_installed("AER")

  # Fit Poisson model
  model_poisson <- glm(
    n_Survivorship_visit ~ change_ins + sex + race2,
    family = poisson(link = "log"),
    offset = log(person_time_days),
    data = mock_p4_analytical
  )

  # Run overdispersion test
  # trafo = 2 tests for variance = mu + alpha*mu^2 (NB2 alternative)
  disp_test <- AER::dispersiontest(model_poisson, trafo = 2)

  # Verify htest object class
  expect_true("htest" %in% class(disp_test))

  # Verify p-value exists and is numeric between 0 and 1
  expect_true(!is.null(disp_test$p.value))
  expect_true(is.numeric(disp_test$p.value))
  expect_true(disp_test$p.value >= 0 & disp_test$p.value <= 1)

  # Verify test statistic exists
  expect_true(!is.null(disp_test$statistic))
  expect_true(is.numeric(disp_test$statistic))
})

# ==============================================================================
# STA-06: Deviance-based overdispersion check
# ==============================================================================

test_that("STA-06: Deviance/df ratio calculable for overdispersion assessment", {
  # Fit Poisson model
  model_poisson <- glm(
    n_Survivorship_visit ~ change_ins + sex + race2,
    family = poisson(link = "log"),
    offset = log(person_time_days),
    data = mock_p4_analytical
  )

  # Calculate deviance/df ratio
  # Ratio > 1 suggests overdispersion
  # Ratio >> 1 (e.g., >2 or >3) indicates substantial overdispersion
  dev_ratio <- model_poisson$deviance / model_poisson$df.residual

  # Ratio should be finite numeric
  expect_true(is.finite(dev_ratio))
  expect_true(is.numeric(dev_ratio))

  # Ratio should be positive
  expect_true(dev_ratio > 0)

  # Deviance and df.residual should be present
  expect_true(!is.null(model_poisson$deviance))
  expect_true(!is.null(model_poisson$df.residual))
  expect_true(model_poisson$df.residual > 0)
})
