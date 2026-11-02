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

# --- Load SAS reference tables ---
sas_baseline <- read_sas(file.path(data_dir_raw, "baseline.sas7bdat")) |>
  rename_with(tolower)

sas_co <- lapply(1:4, function(i)
  read_sas(file.path(data_dir_raw, paste0("change_outcome", i, ".sas7bdat"))) |>
    rename_with(tolower) |>
    mutate(outcome_num = i))

# --- Load R checkpoints ---
r_cohort   <- readRDS(file.path(data_dir_processed, "03_cohort.rds"))
r_outcomes <- readRDS(file.path(data_dir_processed, "03_outcomes.rds"))

# -----------------------------------------------------------
# CHECK 1: Cohort membership
# -----------------------------------------------------------
sas_ids <- sas_baseline$id
r_ids   <- r_cohort$patid

n_sas      <- length(sas_ids)
n_r        <- length(r_ids)
n_both     <- length(intersect(sas_ids, r_ids))
n_sas_only <- length(setdiff(sas_ids, r_ids))
n_r_only   <- length(setdiff(r_ids, sas_ids))

message("=== CHECK 1: Cohort membership ===")
message("  SAS baseline N: ", n_sas)
message("  R cohort    N: ", n_r)
message("  Agreement (in both): ", n_both, " (", round(100 * n_both / n_sas, 2), "% of SAS)")
message("  In SAS only: ", n_sas_only)
message("  In R only:   ", n_r_only)
# Expected: n_sas_only driven by R/03_cohort.R:199 age>=18 filter (confirmed SAS deviation).
# n_r_only should be 0.

# -----------------------------------------------------------
# CHECK 2: ENCOUNTERID match on shared IDs
# -----------------------------------------------------------
# NOTE: baseline.ENCOUNTERID is the LAST follow-up encounter per patient
# (NODUPKEY by descending admit_date in SAS_CODE_FOR_V5_9.sas), NOT the
# first cancer encounter. R currently stores first_can_encounterid.
# A mismatch here is EXPECTED until R is updated to track the last encounter.
shared <- inner_join(
  sas_baseline |> select(id, encounterid),
  r_cohort     |> select(patid, first_can_encounterid),
  by = c("id" = "patid")
)
enc_match <- mean(shared$encounterid == shared$first_can_encounterid, na.rm = TRUE)
message("=== CHECK 2: ENCOUNTERID match (SAS last vs R first) ===")
message("  Agreement rate: ", round(100 * enc_match, 2), "%")
message("  (Mismatch expected — SAS stores last encounter, R stores first cancer encounter)")

# -----------------------------------------------------------
# CHECK 3: Covariate agreement on shared IDs
# -----------------------------------------------------------
cov_cols <- c("first_can_sexx", "first_can_racee", "first_can_hispanicc",
              "first_can_payer_type_primary", "age2")

sas_cov <- sas_baseline |> select(id, all_of(cov_cols))
r_cov   <- r_cohort     |> select(patid, all_of(cov_cols)) |>
  rename(id = patid)

cov_shared <- inner_join(sas_cov, r_cov, by = "id", suffix = c("_sas", "_r"))

message("=== CHECK 3: Covariate agreement ===")
for (col in cov_cols) {
  sas_col <- paste0(col, "_sas")
  r_col   <- paste0(col, "_r")
  if (sas_col %in% names(cov_shared) && r_col %in% names(cov_shared)) {
    rate <- mean(cov_shared[[sas_col]] == cov_shared[[r_col]], na.rm = TRUE)
    message("  ", col, ": ", round(100 * rate, 2), "% agreement")
  }
}
# Expected degraded agreement on first_can_payer_type_primary from M1-M4 mis-mappings
# (14x, 4xx, 6xx, 7x, 'OT') documented in DATA_LINEAGE.md Task 2.

# -----------------------------------------------------------
# CHECK 4: change_outcome* — patient-level membership
# -----------------------------------------------------------
# change_outcome*.sas7bdat is encounter-level (multi-row per ID — see DATA_LINEAGE.md
# Task 1 CONFLICT). Must deduplicate to ID level before comparing to R cohort.
message("=== CHECK 4: change_outcome membership (patient-level) ===")
for (i in 1:4) {
  sas_co_ids <- sas_co[[i]] |> distinct(id) |> pull(id)
  # r_last_ids: derive from r_outcomes filtered to outcome_type == i.
  # Adjust column/filter when 03_outcomes.rds structure is confirmed.
  # r_last_ids <- r_outcomes |> filter(outcome_num == i) |> distinct(patid) |> pull(patid)
  message("  change_outcome", i, " SAS unique IDs: ", length(sas_co_ids),
          "  (R comparison pending 03_outcomes.rds structure)")
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
demo_path <- file.path(data_dir_raw, "demographic_mobley_v5.sas7bdat")
if (file.exists(demo_path)) {
  demo_raw <- read_sas(demo_path) |> rename_with(tolower)
  co_only_sex <- demo_raw |>
    filter(patid %in% co_only) |>
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

message("=== Validation complete ===")
