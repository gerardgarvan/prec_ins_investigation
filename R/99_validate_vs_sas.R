# ============================================================
# R/99_validate_vs_sas.R
# ============================================================
# Compare R pipeline outputs against SAS-produced SAS7BDAT
# files on HiPerGator. Reads only aggregate SAS tables +
# R checkpoints — no patient-level raw data written out.
#
# Run on HiPerGator after 03_cohort.R and 03_outcomes.R complete.
# ============================================================

library(here); source(here("R", "config.R"))
library(haven)
library(tidyverse)

# --- Helper: stop with a clear message if a required file is missing ---
require_file <- function(path) {
  if (!file.exists(path)) stop("Required file not found: ", path, call. = FALSE)
  path
}

# --- Load SAS reference tables ---
sas_baseline <- read_sas(require_file(file.path(data_dir_raw, "baseline.sas7bdat"))) |>
  rename_with(tolower)

sas_co <- lapply(1:4, function(i)
  read_sas(require_file(
    file.path(data_dir_raw, paste0("change_outcome", i, ".sas7bdat"))
  )) |>
    rename_with(tolower) |>
    mutate(outcome_num = i))

# --- Load R checkpoints (must run 03_cohort.R and 03_outcomes.R first) ---
cohort_path   <- file.path(data_dir_processed, "03_cohort.rds")
outcomes_path <- file.path(data_dir_processed, "03_outcomes.rds")

r_checkpoints_ready <- file.exists(cohort_path) && file.exists(outcomes_path)
if (!r_checkpoints_ready) {
  missing <- c(cohort_path, outcomes_path)[!file.exists(c(cohort_path, outcomes_path))]
  message("=== R checkpoints not yet available ===")
  message("  Missing: ", paste(missing, collapse = "\n           "))
  message("  Run the pipeline through 03_outcomes.R first, then re-run this script.")
  message("  SAS-only checks (CHECK 4 membership counts) will still run below.")
}

r_cohort   <- if (file.exists(cohort_path))   readRDS(cohort_path)   else NULL
r_outcomes <- if (file.exists(outcomes_path)) readRDS(outcomes_path) else NULL

# -----------------------------------------------------------
# CHECK 1: Cohort membership (requires 03_cohort.rds)
# -----------------------------------------------------------
message("=== CHECK 1: Cohort membership ===")
if (is.null(r_cohort)) {
  message("  SKIPPED — 03_cohort.rds not available")
} else {
  sas_ids <- sas_baseline$id
  r_ids   <- r_cohort$patid

  n_sas      <- length(sas_ids)
  n_r        <- length(r_ids)
  n_both     <- length(intersect(sas_ids, r_ids))
  n_sas_only <- length(setdiff(sas_ids, r_ids))
  n_r_only   <- length(setdiff(r_ids, sas_ids))

  message("  SAS baseline N: ", n_sas)
  message("  R cohort    N: ", n_r)
  message("  Agreement (in both): ", n_both, " (", round(100 * n_both / n_sas, 2), "% of SAS)")
  message("  In SAS only: ", n_sas_only)
  message("  In R only:   ", n_r_only)
  # Expected: n_sas_only driven by R/03_cohort.R:199 age>=18 filter (confirmed SAS deviation).
  # n_r_only should be 0.
}

# -----------------------------------------------------------
# CHECK 2: ENCOUNTERID match on shared IDs (requires 03_cohort.rds)
# -----------------------------------------------------------
# INFERRED: baseline.ENCOUNTERID is believed to be the LAST follow-up encounter
# per patient (NODUPKEY by descending admit_date in SAS_CODE_FOR_V5_9.sas),
# NOT the first cancer encounter. R currently stores first_can_encounterid.
# A mismatch here is EXPECTED until this inference is confirmed on HiPerGator.
message("=== CHECK 2: ENCOUNTERID match (SAS last [INFERRED] vs R first) ===")
if (is.null(r_cohort)) {
  message("  SKIPPED — 03_cohort.rds not available")
} else {
  shared <- inner_join(
    sas_baseline |> select(id, encounterid),
    r_cohort     |> select(patid, first_can_encounterid),
    by = c("id" = "patid")
  )
  enc_match <- mean(shared$encounterid == shared$first_can_encounterid, na.rm = TRUE)
  message("  Agreement rate: ", round(100 * enc_match, 2), "%")
  message("  (Mismatch expected — SAS stores last encounter, R stores first cancer encounter)")
}

# -----------------------------------------------------------
# CHECK 3: Covariate agreement on shared IDs (requires 03_cohort.rds)
# -----------------------------------------------------------
message("=== CHECK 3: Covariate agreement ===")
if (is.null(r_cohort)) {
  message("  SKIPPED — 03_cohort.rds not available")
} else {
  # Demographic covariates (direct column match)
  demo_cols <- c("first_can_sexx", "first_can_racee", "first_can_hispanicc")
  sas_demo <- sas_baseline |> select(id, all_of(demo_cols))
  r_demo   <- r_cohort     |> select(patid, all_of(demo_cols)) |> rename(id = patid)
  demo_shared <- inner_join(sas_demo, r_demo, by = "id", suffix = c("_sas", "_r"))
  for (col in demo_cols) {
    rate <- mean(demo_shared[[paste0(col, "_sas")]] == demo_shared[[paste0(col, "_r")]],
                 na.rm = TRUE)
    message("  ", col, ": ", round(100 * rate, 2), "% agreement")
  }

  # Age: SAS age2 is in YEARS (floor((first_admit_date-BIRTH_DATE)/365.25), capped >=120->91)
  # Compare to R age_at_dx (same formula). SAS column name is "age2" in baseline.
  if ("age2" %in% names(sas_baseline) && "age_at_dx" %in% names(r_cohort)) {
    age_shared <- inner_join(
      sas_baseline |> select(id, sas_age_yrs = age2),
      r_cohort     |> select(patid, r_age_at_dx = age_at_dx),
      by = c("id" = "patid")
    )
    age_agree <- mean(age_shared$sas_age_yrs == age_shared$r_age_at_dx, na.rm = TRUE)
    message("  age (SAS age2 years vs R age_at_dx): ", round(100 * age_agree, 2), "% agreement")
    if (age_agree < 0.99) message("  WARNING: age mismatch — check >=120->91 cap in 03_cohort.R")
  } else {
    message("  age: SKIPPED — age2 not in SAS baseline or age_at_dx not in R cohort")
  }

  # Payer: compare SAS first_can_payer_type_primary (raw) to R first_can_payer_recoded (category).
  # Expected agreement ~ 80% due to multi-character SAS codes recoded to single-digit categories.
  if ("first_can_payer_type_primary" %in% names(sas_baseline) &&
      "first_can_payer_recoded" %in% names(r_cohort)) {
    payer_shared <- inner_join(
      sas_baseline |> select(id, sas_payer = first_can_payer_type_primary),
      r_cohort     |> select(patid, r_payer  = first_can_payer_recoded),
      by = c("id" = "patid")
    )
    # SAS payer is already recoded in baseline; compare as-is
    payer_agree <- mean(payer_shared$sas_payer == payer_shared$r_payer, na.rm = TRUE)
    message("  payer (SAS recoded vs R recoded): ", round(100 * payer_agree, 2), "% agreement")
    if (payer_agree < 0.80) message("  WARNING: payer mismatch >20% — review recode_payer() in 02_clean.R")
  } else {
    message("  payer: SKIPPED — first_can_payer_type_primary not in SAS baseline or ",
            "first_can_payer_recoded not in R cohort")
  }
}

# -----------------------------------------------------------
# CHECK 4: change_outcome* — patient-level membership
# -----------------------------------------------------------
# change_outcome*.sas7bdat is encounter-level (multi-row per ID — see DATA_LINEAGE.md
# Task 1 CONFLICT). Must deduplicate to ID level before comparing to R cohort.
message("=== CHECK 4: change_outcome membership (patient-level) ===")
for (i in 1:4) {
  sas_co_ids <- sas_co[[i]] |> distinct(id) |> pull(id)
  if (is.null(r_outcomes)) {
    message("  change_outcome", i, " SAS unique IDs: ", length(sas_co_ids),
            "  (R comparison SKIPPED — 03_outcomes.rds not available)")
  } else {
    # r_last_ids: derive from r_outcomes filtered to outcome_type == i.
    # Adjust column/filter when 03_outcomes.rds structure is confirmed.
    # r_last_ids <- r_outcomes |> filter(outcome_num == i) |> distinct(patid) |> pull(patid)
    message("  change_outcome", i, " SAS unique IDs: ", length(sas_co_ids),
            "  (R comparison pending 03_outcomes.rds structure confirmation)")
  }
}

# -----------------------------------------------------------
# CHECK 5: Why are ~10.5k IDs in change_outcome1 but not baseline?
# -----------------------------------------------------------
# Two INFERRED causes (DATA_LINEAGE.md Task 5):
# Cause A: sex='UN' removed from baseline by SAS_CODE_FOR_V5_6.sas:38
# Cause B: missing SDI removed by SAS_CODE_FOR_V5_5_(1).sas:383
message("=== CHECK 5: IDs in change_outcome1 but not baseline ===")

co1_ids    <- sas_co[[1]] |> distinct(id) |> pull(id)
co_only    <- setdiff(co1_ids, sas_baseline$id)
message("  IDs in change_outcome1 but not baseline: ", length(co_only))

# Cause A: sex='UN' — requires demographic file
# Read only id + sex for the co_only IDs (avoids materialising full demo table).
demo_path <- file.path(data_dir_raw, "demographic_mobley_v5.sas7bdat")
if (file.exists(demo_path)) {
  demo_raw <- read_sas(demo_path, col_select = c("id", "sex")) |>
    rename_with(tolower) |>
    filter(id %in% co_only)
  co_only_sex <- demo_raw |>
    count(sex, name = "n") |>
    arrange(desc(n))
  message("  Sex distribution of change_outcome1-only IDs:")
  print(co_only_sex)
  n_sex_un <- co_only_sex |> filter(sex == "UN") |> pull(n) |> sum()
  message("  sex='UN' accounts for: ", n_sex_un, " (",
          round(100 * n_sex_un / length(co_only), 1), "% of gap)")
} else {
  message("  demographic file not found at: ", demo_path)
  message("  (Cause A — sex='UN' — cannot be tested without demographic file)")
}

# Cause B: missing SDI — requires address/ZCTA/SDI joined table on HiPerGator
message("  Cause B (missing SDI) requires address/ZCTA/SDI joined table — pending HiPerGator access.")

# -----------------------------------------------------------
# CHECK 6: SOURCE column — demographic SOURCE vs baseline SOURCE_DEMO
# -----------------------------------------------------------
# CONFIRMED (2026-11-02): demographic_mobley_v5 contains a SOURCE column.
# R/03_cohort.R carries it through as `source`. SAS baseline may name it SOURCE_DEMO.
message("=== CHECK 6: SOURCE agreement (demo SOURCE vs SAS SOURCE_DEMO) ===")
if (is.null(r_cohort)) {
  message("  SKIPPED — 03_cohort.rds not available")
} else {
  sas_source_col <- if ("source_demo" %in% names(sas_baseline)) "source_demo" else
                    if ("source"      %in% names(sas_baseline)) "source"      else NA_character_
  if (is.na(sas_source_col)) {
    message("  SKIPPED — neither source_demo nor source found in SAS baseline columns")
    message("  Available SAS columns: ", paste(names(sas_baseline), collapse = ", "))
  } else {
    shared_src <- inner_join(
      sas_baseline |> select(id, sas_source = !!sym(sas_source_col)),
      r_cohort     |> select(patid, r_source = source),
      by = c("id" = "patid")
    )
    rate <- mean(shared_src$sas_source == shared_src$r_source, na.rm = TRUE)
    message("  SOURCE agreement: ", round(100 * rate, 2), "% (column used: ", sas_source_col, ")")
    if (rate < 0.99) {
      message("  WARNING: SOURCE mismatch exceeds 1% — check demographic join in 01_import.R")
    }
  }
}

message("=== Validation complete ===")
