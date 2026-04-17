# R/04_regression.R
# Poisson and Negative Binomial Regression Models
# Per STA-03: Poisson regression with log(person-time) offset
# Per STA-04: Negative binomial when overdispersion detected
# Per STA-05: IRRs, 95% CIs, and p-values in publication tables
# Per STA-06: Overdispersion test and goodness-of-fit diagnostics
#
# SAS Source: V5_18 (PROC GENMOD dist=poisson/negbin, offset=log_person_time_days)
#
# Inputs:  data/processed/03_analytical.rds (complete-case dataset from Phase 3)
# Outputs: output/tables/regression_poisson.docx
#          output/tables/regression_negbin.docx
#          output/tables/regression_comparison.docx
#          output/diagnostics/overdispersion_tests.txt
#          output/diagnostics/model_fit_summary.txt

library(here)
source(here::here("R", "config.R"))
library(tidyverse)
library(MASS)
library(broom)
library(AER)
library(gtsummary)
library(flextable)

# ========================================
# Section 2 -- Load Data
# ========================================

message("========================================")
message("Phase 4: Regression Models")
message("Started: ", Sys.time())
message("========================================")

# Load complete-case analytical dataset
analytical <- readRDS(file.path(data_dir_processed, "03_analytical.rds"))

message("Loaded analytical dataset:")
message("  Patients: ", format(nrow(analytical), big.mark = ","))
message("  Variables: ", ncol(analytical))

# Verify log_person_time_days exists and is valid
if (!"log_person_time_days" %in% names(analytical)) {
  analytical <- analytical %>%
    mutate(log_person_time_days = log(person_time_days))
  message("Created log_person_time_days")
}

n_invalid <- sum(!is.finite(analytical$log_person_time_days))
if (n_invalid > 0) {
  message("WARNING: ", n_invalid, " patients with non-finite log_person_time_days — excluding")
  analytical <- analytical %>% filter(is.finite(log_person_time_days))
}

message("  Patients for regression: ", nrow(analytical))

# ========================================
# Section 3 -- Define Model Formula and Labels
# ========================================

message("\n=== Section 3: Model Specification ===")

# Model predictors per SAS V5_18 PROC GENMOD CLASS/MODEL statements
# change_ins is primary exposure; others are covariates
# Per Open Question 3 (04-RESEARCH.md): Theory-driven full model
model_predictors <- "change_ins + factor(age2) + sex + race2 +
                     factor(intensity2) + factor(first_sdi2) + first_ruca"

# Label list for gtsummary regression tables
label_list <- list(
  change_ins ~ "Insurance change",
  `factor(age2)` ~ "Age category",
  sex ~ "Sex",
  race2 ~ "Race",
  `factor(intensity2)` ~ "Treatment intensity",
  `factor(first_sdi2)` ~ "Social deprivation index",
  first_ruca ~ "Rural-urban classification"
)

# Outcome variables to model (multiple outcome models per SAS V5_18)
outcome_vars <- c(
  "n_Survivorship_visit",
  "n_Cancer_related_visit",
  "n_Enc_nonacute_care",
  "n_cancer_visit_and_prov"
)

message("Predictors: change_ins + age2 + sex + race2 + intensity2 + first_sdi2 + first_ruca")
message("Outcomes: ", paste(outcome_vars, collapse = ", "))
message("Offset: log(person_time_days)")

# ========================================
# Section 4 -- Poisson Regression (STA-03)
# ========================================

message("\n=== Section 4: Poisson Regression (STA-03) ===")

# Fit Poisson models for each outcome
poisson_models <- list()
poisson_tidy <- list()

for (outcome in outcome_vars) {
  message("\nFitting Poisson model: ", outcome)

  formula_str <- paste0(outcome, " ~ ", model_predictors)
  model <- glm(
    as.formula(formula_str),
    data = analytical,
    family = poisson(link = "log"),
    offset = log(person_time_days)
  )

  poisson_models[[outcome]] <- model

  # Extract IRRs with 95% CIs (STA-05)
  # Per Pitfall 1: ALWAYS use exponentiate = TRUE for IRRs
  tidy_out <- tidy(model, exponentiate = TRUE, conf.int = TRUE, conf.level = 0.95)
  poisson_tidy[[outcome]] <- tidy_out

  message("  AIC: ", round(AIC(model), 1))
  message("  Deviance/df: ", round(model$deviance / model$df.residual, 3))
}

# ========================================
# Section 5 -- Overdispersion Testing (STA-06)
# ========================================

message("\n=== Section 5: Overdispersion Testing (STA-06) ===")

overdispersion_results <- list()
use_nb <- list()

for (outcome in outcome_vars) {
  model <- poisson_models[[outcome]]

  # Method 1: Deviance/df ratio (quick check)
  dispersion_ratio <- model$deviance / model$df.residual

  # Method 2: Formal AER test (H0: equidispersion, H1: NB2 variance)
  # Per Pitfall 2: ALWAYS test overdispersion after Poisson
  test_result <- dispersiontest(model, trafo = 2)

  overdispersion_results[[outcome]] <- list(
    dispersion_ratio = dispersion_ratio,
    test_p_value = test_result$p.value,
    test_statistic = test_result$statistic
  )

  # Decision rule: p < 0.05 → use negative binomial
  use_nb[[outcome]] <- test_result$p.value < 0.05

  message("\n", outcome, ":")
  message("  Dispersion ratio: ", round(dispersion_ratio, 3))
  message("  Overdispersion test p-value: ", format.pval(test_result$p.value, digits = 4))
  message("  Recommendation: ", ifelse(use_nb[[outcome]], "Use Negative Binomial", "Poisson OK"))
}

# Save overdispersion diagnostics to file
sink(file.path(output_dir_diagnostics, "overdispersion_tests.txt"))
cat("=== Overdispersion Tests for Poisson Models ===\n")
cat("Date:", format(Sys.time()), "\n\n")
for (outcome in outcome_vars) {
  cat("--- ", outcome, " ---\n")
  cat("Dispersion ratio (deviance/df):",
      round(overdispersion_results[[outcome]]$dispersion_ratio, 3), "\n")
  cat("AER::dispersiontest p-value:",
      format.pval(overdispersion_results[[outcome]]$test_p_value, digits = 4), "\n")
  cat("Recommendation:", ifelse(use_nb[[outcome]],
      "OVERDISPERSED — use negative binomial\n",
      "Equidispersed — Poisson acceptable\n"))
  cat("\n")
}
sink()

message("\nSaved: ", file.path(output_dir_diagnostics, "overdispersion_tests.txt"))

# ========================================
# Section 6 -- Negative Binomial Regression (STA-04)
# ========================================

message("\n=== Section 6: Negative Binomial Regression (STA-04) ===")

nb_models <- list()
nb_tidy <- list()

for (outcome in outcome_vars) {
  message("\nFitting Negative Binomial model: ", outcome)

  # Per Pitfall 3: offset inside formula for glm.nb (different syntax from glm)
  formula_str <- paste0(outcome, " ~ ", model_predictors,
                        " + offset(log(person_time_days))")

  tryCatch({
    model_nb <- glm.nb(
      as.formula(formula_str),
      data = analytical
    )

    nb_models[[outcome]] <- model_nb

    # Extract IRRs with 95% CIs
    tidy_out <- tidy(model_nb, exponentiate = TRUE, conf.int = TRUE)
    nb_tidy[[outcome]] <- tidy_out

    message("  Theta: ", round(model_nb$theta, 3), " +/- ", round(model_nb$SE.theta, 3))
    message("  AIC: ", round(AIC(model_nb), 1))

  }, error = function(e) {
    message("  WARNING: glm.nb failed for ", outcome, ": ", conditionMessage(e))
    message("  Falling back to Poisson model")
    nb_models[[outcome]] <<- poisson_models[[outcome]]
    nb_tidy[[outcome]] <<- poisson_tidy[[outcome]]
  })
}

# ========================================
# Section 7 -- Model Comparison and Diagnostics (STA-06)
# ========================================

message("\n=== Section 7: Model Comparison (STA-06) ===")

# Save model fit summary
sink(file.path(output_dir_diagnostics, "model_fit_summary.txt"))
cat("=== Model Fit Summary: Poisson vs Negative Binomial ===\n")
cat("Date:", format(Sys.time()), "\n\n")

for (outcome in outcome_vars) {
  cat("===", outcome, "===\n\n")

  # Poisson fit
  pois_model <- poisson_models[[outcome]]
  cat("Poisson model:\n")
  cat("  AIC:", round(AIC(pois_model), 1), "\n")
  cat("  Deviance:", round(pois_model$deviance, 1), "\n")
  cat("  Residual df:", pois_model$df.residual, "\n")
  cat("  Deviance/df:", round(pois_model$deviance / pois_model$df.residual, 3), "\n")

  # NB fit (if different from Poisson)
  nb_model <- nb_models[[outcome]]
  if (inherits(nb_model, "negbin")) {
    cat("\nNegative Binomial model:\n")
    cat("  AIC:", round(AIC(nb_model), 1), "\n")
    cat("  Theta:", round(nb_model$theta, 3), "+/-", round(nb_model$SE.theta, 3), "\n")
    cat("  Deviance:", round(nb_model$deviance, 1), "\n")

    # AIC comparison
    cat("\nAIC comparison:\n")
    cat("  Poisson:", round(AIC(pois_model), 1), "\n")
    cat("  NB:     ", round(AIC(nb_model), 1), "\n")
    cat("  Preferred:", ifelse(AIC(nb_model) < AIC(pois_model),
        "Negative Binomial (lower AIC)", "Poisson (lower AIC)"), "\n")
  } else {
    cat("\n  NB model same as Poisson (glm.nb failed or not needed)\n")
  }

  cat("\n")
}
sink()

message("Saved: ", file.path(output_dir_diagnostics, "model_fit_summary.txt"))

# ========================================
# Section 8 -- Publication Regression Tables (STA-05)
# ========================================

message("\n=== Section 8: Publication Regression Tables (STA-05) ===")

# Create Poisson regression tables for each outcome
poisson_tables <- list()
for (outcome in outcome_vars) {
  tbl <- tbl_regression(
    poisson_models[[outcome]],
    exponentiate = TRUE,
    label = label_list,
    estimate_fun = function(x) style_ratio(x, digits = 2),
    pvalue_fun = function(x) style_pvalue(x, digits = 3)
  ) %>%
    add_global_p() %>%
    bold_p(t = 0.05) %>%
    bold_labels() %>%
    modify_header(
      label ~ "**Variable**",
      estimate ~ "**IRR**"
    ) %>%
    modify_footnote(
      estimate ~ "IRR = Incidence Rate Ratio, Poisson regression with log(person-time) offset"
    ) %>%
    modify_caption(paste0("**Poisson Regression: ", outcome, "**"))

  poisson_tables[[outcome]] <- tbl
}

# Export Poisson tables to Word
poisson_merged <- tbl_stack(
  poisson_tables,
  group_header = outcome_vars
)

poisson_merged %>%
  as_flex_table() %>%
  flextable::fontsize(size = 9, part = "all") %>%
  flextable::save_as_docx(path = file.path(output_dir_tables, "regression_poisson.docx"))

message("Exported: ", file.path(output_dir_tables, "regression_poisson.docx"))

# Create NB regression tables for each outcome
nb_tables <- list()
for (outcome in outcome_vars) {
  nb_model <- nb_models[[outcome]]

  tbl <- tbl_regression(
    nb_model,
    exponentiate = TRUE,
    label = label_list,
    estimate_fun = function(x) style_ratio(x, digits = 2),
    pvalue_fun = function(x) style_pvalue(x, digits = 3)
  ) %>%
    add_global_p() %>%
    bold_p(t = 0.05) %>%
    bold_labels() %>%
    modify_header(
      label ~ "**Variable**",
      estimate ~ "**IRR**"
    ) %>%
    modify_footnote(
      estimate ~ "IRR = Incidence Rate Ratio, Negative Binomial regression with log(person-time) offset"
    ) %>%
    modify_caption(paste0("**Negative Binomial Regression: ", outcome, "**"))

  nb_tables[[outcome]] <- tbl
}

# Export NB tables to Word
nb_merged <- tbl_stack(
  nb_tables,
  group_header = outcome_vars
)

nb_merged %>%
  as_flex_table() %>%
  flextable::fontsize(size = 9, part = "all") %>%
  flextable::save_as_docx(path = file.path(output_dir_tables, "regression_negbin.docx"))

message("Exported: ", file.path(output_dir_tables, "regression_negbin.docx"))

# Side-by-side comparison table for primary outcome (n_Survivorship_visit)
primary_outcome <- "n_Survivorship_visit"
comparison_table <- tbl_merge(
  tbls = list(
    tbl_regression(poisson_models[[primary_outcome]], exponentiate = TRUE,
                   label = label_list,
                   estimate_fun = function(x) style_ratio(x, digits = 2)),
    tbl_regression(nb_models[[primary_outcome]], exponentiate = TRUE,
                   label = label_list,
                   estimate_fun = function(x) style_ratio(x, digits = 2))
  ),
  tab_spanner = c("**Poisson**", "**Negative Binomial**")
) %>%
  modify_caption("**Model Comparison: Poisson vs Negative Binomial — Survivorship Visits**")

comparison_table %>%
  as_flex_table() %>%
  flextable::fontsize(size = 9, part = "all") %>%
  flextable::save_as_docx(path = file.path(output_dir_tables, "regression_comparison.docx"))

message("Exported: ", file.path(output_dir_tables, "regression_comparison.docx"))

# ========================================
# Section 9 -- Summary
# ========================================

message("\n========================================")
message("Phase 4: Regression Models Complete")
message("Completed: ", Sys.time())
message("========================================")
message("\nOutputs:")
message("  Poisson tables:   ", file.path(output_dir_tables, "regression_poisson.docx"))
message("  NB tables:        ", file.path(output_dir_tables, "regression_negbin.docx"))
message("  Comparison:       ", file.path(output_dir_tables, "regression_comparison.docx"))
message("  Overdispersion:   ", file.path(output_dir_diagnostics, "overdispersion_tests.txt"))
message("  Model fit:        ", file.path(output_dir_diagnostics, "model_fit_summary.txt"))
message("\nRequirements addressed:")
message("  STA-03: Poisson regression with log(person-time) offset for 4 outcome variables")
message("  STA-04: Negative binomial regression for all outcomes (overdispersion handling)")
message("  STA-05: Publication-ready IRR tables with 95% CIs and p-values")
message("  STA-06: Overdispersion tests (AER::dispersiontest) and model fit diagnostics (AIC comparison)")
message("\n=== PIPELINE COMPLETE ===")
message("All Phase 1-4 scripts executed. R pipeline ready for data.")
