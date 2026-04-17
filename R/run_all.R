# R/run_all.R
# Master runner for Precision Cancer Survivorship pipeline
# Per D-09: Supports start_step parameter for partial reruns from .rds checkpoints
# Per INF-02: Executes full pipeline from data import to final outputs
# Usage: source("R/run_all.R") or Rscript R/run_all.R

# Project root — hardcoded for HiPerGator reliability
project_root <- "/home/ggarvan/prec_ins_investigation"

# Change start_step to resume from a later step (leveraging .rds checkpoints per D-08)
# Example: start_step <- 2 skips format translation, loads from checkpoint
start_step <- 1

# Pipeline scripts in execution order
# Per D-04: paths constructed via file.path(), hardcoded project root
# Per INF-01: numbered modular scripts, each performs single logical step
scripts <- c(
  "01_formats.R",     # Translate Formats.sas to R factor definitions
  "01_import.R",      # Import all V5 SAS7BDAT files
  "02_clean.R",       # Data cleaning: encounter import, combine, payer/enc_type recoding
  "02_merge.R"        # Data merging: encounter-dx-proc-provider joins with validation
  # Phase 3 scripts:
  # "03_cohort.R",    # Cohort construction and exclusion criteria
  # "03_exposure.R",  # Exposure variable derivation
  # "03_outcomes.R",  # Outcome variable calculation
  # "03_covariates.R",# Covariate processing
  # Phase 4 scripts:
  # "04_table1.R",    # Descriptive statistics and Table 1
  # "04_models.R",    # Regression models
  # "04_output.R"     # Final tables and figures
)

message("========================================")
message("Precision Cancer Survivorship Pipeline")
message("Started: ", Sys.time())
message("Starting from step: ", start_step)
message("Total scripts: ", length(scripts))
message("========================================")

# Execute scripts with error handling
# Per D-09: start_step enables partial reruns from checkpoints
# tryCatch provides graceful error handling with resume guidance
for (i in seq_along(scripts)) {
  if (i >= start_step) {
    script_path <- file.path(project_root, "R", scripts[i])
    if (!file.exists(script_path)) {
      message("WARNING: Script not found, skipping: ", scripts[i])
      next
    }
    message("\n>>> Step ", i, "/", length(scripts), ": Running ", scripts[i], " <<<")
    tryCatch({
      # Execute in isolated environment to prevent namespace pollution
      # local = new.env(parent = globalenv()) keeps package access while isolating variables
      source(script_path, local = new.env(parent = globalenv()))
      message("Completed: ", scripts[i], " at ", Sys.time())
    }, error = function(e) {
      message("ERROR in ", scripts[i], ": ", conditionMessage(e))
      message("Pipeline halted. Fix error and rerun with start_step <- ", i)
      stop(e)
    })
  } else {
    message("Skipped (start_step=", start_step, "): ", scripts[i])
  }
}

message("\n========================================")
message("Pipeline complete: ", Sys.time())
message("========================================")
