# R/03_geo.R
# Geographic covariate derivation: first_can_ruca and first_can_sdi_score
# Per D-01: Runs after 03_cohort.R; output read by 03_covariates.R
#
# SAS source: SAS_CODE_FOR_V5_5 (1).sas (primary), confirmed against SAS_CODE_FOR_v5_5.sas
#
# Three-step address window selection (SAS V5_5 lines 113-313):
#   1. ADDRESS_PERIOD_START <= first_admit_date <= ADDRESS_PERIOD_END  (exact coverage)
#   2. Closest earlier start: ADDRESS_PERIOD_START <= first_admit_date (days_START_can <= 0)
#   3. Start within 30 days after: 0 <= days_START_can <= 30
#
# ruca3 derivation (SAS V5_5 lines 141-145, 244-251, 298-305):
#   RUCA1 in {1, 2, 3, 1.1, 2.1}  -> ruca3 = 0  (urban/metropolitan)
#   RUCA1 = 99                     -> ruca3 = NA  (water/territories — excluded)
#   RUCA1 not in lookup            -> excluded (zip with no RUCA match)
#   all others                     -> ruca3 = 1  (rural)
#
# SDI derivation (SAS V5_5 lines 359-383):
#   ADDRESS_ZIP5 -> zcta (via 01_imported_zcta.rds)
#   zcta -> sdi_score (via 01_imported_sdi.rds, from 00_build_sdi.R, RGC SDI 2011-2015 by ZCTA)
#   Patients with sdi_score = NA are deleted (SAS line 383)
#   Note: ZIPs that yield "No ZCTA" or NA from the zcta lookup also produce NA sdi_score
#         and are dropped by the filter(!is.na(sdi_score)) — satisfies SAS "drop No ZCTA" step.
#
# Inputs:  data/processed/01_imported_address.rds
#          data/processed/01_imported_ruca.rds
#          data/processed/01_imported_zcta.rds
#          data/processed/01_imported_sdi.rds  (SDI source — produced by 00_build_sdi.R)
#          data/processed/03_cohort.rds
# Outputs: data/processed/03_geo.rds  (one row per patient with RUCA; SDI if available)
#          data/processed/03_geo_attrition.rds

library(here)
source(here::here("R", "config.R"))
library(tidyverse)

message("========================================")
message("Phase 3: Geographic Covariate Derivation")
message("Started: ", Sys.time())
message("========================================")

# ========================================
# Section 1 -- Load Inputs
# ========================================

address <- readRDS(file.path(data_dir_processed, "01_imported_address.rds"))
ruca    <- readRDS(file.path(data_dir_processed, "01_imported_ruca.rds"))
cohort  <- readRDS(file.path(data_dir_processed, "03_cohort.rds"))

# Normalise column names — SAS imports ID; R pipeline uses patid
if ("id" %in% names(address) && !"patid" %in% names(address)) {
  address <- rename(address, patid = id)
} else if ("ID" %in% names(address) && !"patid" %in% names(address)) {
  address <- rename(address, patid = ID)
}
address <- rename_with(address, tolower)
# Re-capitalise RUCA-specific columns that the join expects in upper case
# (ADDRESS_ZIP5, ADDRESS_PERIOD_START, ADDRESS_PERIOD_END are upper in SAS)
names(address) <- toupper(names(address))
address <- rename(address, patid = PATID)

message("Loaded:")
message("  address: ", nrow(address), " rows, ", n_distinct(address$patid), " patients")
message("  ruca:    ", nrow(ruca), " ZIP codes")
message("  cohort:  ", nrow(cohort), " patients")

# ========================================
# Section 2 -- Prepare Address + RUCA base (SAS V5_5 lines 65-109)
# ========================================
# SAS line 66: drop blank ADDRESS_ZIP5
# SAS line 67: default ADDRESS_PERIOD_END to 31AUG2023 if missing
# Then count n_unique_zip and n_zip_foreach per id

END_DATE_DEFAULT <- as.Date("2023-08-31")  # SAS: '31AUG2023'd

address_clean <- address %>%
  filter(!is.na(ADDRESS_ZIP5) & ADDRESS_ZIP5 != "") %>%
  mutate(
    ADDRESS_PERIOD_END = if_else(is.na(ADDRESS_PERIOD_END), END_DATE_DEFAULT, ADDRESS_PERIOD_END)
  )

# Join address with RUCA lookup by zip code
zip_ruca <- address_clean %>%
  left_join(
    ruca %>% select(ADDRESS_ZIP5, STATE_ruca, ZIP_TYPE_ruca, RUCA1, RUCA2),
    by = "ADDRESS_ZIP5"
  )

message("  zip_ruca (address x ruca join): ", nrow(zip_ruca), " rows")

# Restrict to cohort patients only (SAS uses demo_validEnroll_dx_3_ as left table)
cohort_ids <- cohort %>% select(patid, first_admit_date)

# ========================================
# Section 3 -- Step 1: Address covers dx date (SAS V5_5 lines 113-146)
# ========================================
# Join: first_admit_date BETWEEN ADDRESS_PERIOD_START AND ADDRESS_PERIOD_END

step1_join <- cohort_ids %>%
  left_join(zip_ruca, by = "patid") %>%
  filter(
    is.na(ADDRESS_PERIOD_START) |  # keep NAs initially (left join)
      (first_admit_date >= ADDRESS_PERIOD_START & first_admit_date <= ADDRESS_PERIOD_END)
  )

# Compute days_START_can = ADDRESS_PERIOD_START - first_admit_date
# SAS: days_START_can = ADDRESS_PERIOD_START - first_admit_date
# (negative = start is before dx date; positive = start is after)
step1_calc <- step1_join %>%
  mutate(
    days_START_can = if_else(
      !is.na(ADDRESS_PERIOD_START),
      as.numeric(ADDRESS_PERIOD_START - first_admit_date),
      NA_real_
    )
  )

# Deduplicate: keep row with highest days_START_can (closest to 0 from negative side)
# SAS: proc sort by id descending days_START_can; nodupkey by id
step1_dedup <- step1_calc %>%
  arrange(patid, desc(days_START_can)) %>%
  distinct(patid, .keep_all = TRUE)

# Derive ruca3 for those with a ZIP and RUCA match
# SAS lines 139-145: delete RUCA1=99; delete ADDRESS_ZIP5 not empty + RUCA1=.
step1_ruca <- step1_dedup %>%
  filter(!(RUCA1 == 99 & !is.na(RUCA1))) %>%  # delete RUCA1=99
  filter(!(ADDRESS_ZIP5 != "" & !is.na(ADDRESS_ZIP5) & is.na(RUCA1))) %>%  # zip with no RUCA
  mutate(
    ruca3 = case_when(
      is.na(RUCA1)                                    ~ NA_integer_,
      RUCA1 %in% c(1, 2, 3, 1.1, 2.1)               ~ 0L,
      TRUE                                            ~ 1L
    )
  )

# Patients matched in step 1 (have ADDRESS_ZIP5)
step1_matched <- step1_ruca %>% filter(!is.na(ADDRESS_ZIP5) & ADDRESS_ZIP5 != "")
# Patients not matched in step 1 (no address coverage at dx date)
step1_unmatched <- step1_dedup %>%
  filter(!patid %in% step1_matched$patid)

message("\nStep 1 (address covers dx date): ", n_distinct(step1_matched$patid), " patients matched")
message("  Unmatched (need step 2/3):     ", n_distinct(step1_unmatched$patid), " patients")

# ========================================
# Section 4 -- Step 2: Closest earlier address (SAS V5_5 lines 160-253)
# ========================================
# For unmatched patients: re-join ALL address records, then keep prior starts only
# days_START_can <= 0 means ADDRESS_PERIOD_START <= first_admit_date

step2_join <- step1_unmatched %>%
  select(patid, first_admit_date) %>%
  left_join(zip_ruca, by = "patid") %>%
  mutate(
    days_START_can = if_else(
      !is.na(ADDRESS_PERIOD_START),
      as.numeric(ADDRESS_PERIOD_START - first_admit_date),
      NA_real_
    )
  ) %>%
  # SAS line 239: keep only negative days (start before dx date); exclude NA and ZIP w/no RUCA
  filter(!is.na(days_START_can) & days_START_can <= 0) %>%
  filter(!is.na(ADDRESS_ZIP5) & ADDRESS_ZIP5 != "") %>%
  filter(!is.na(RUCA1)) %>%
  filter(RUCA1 != 99)

# Deduplicate: highest days_START_can (closest prior = least negative)
step2_dedup <- step2_join %>%
  arrange(patid, desc(days_START_can)) %>%
  distinct(patid, .keep_all = TRUE) %>%
  mutate(
    ruca3 = case_when(
      RUCA1 %in% c(1, 2, 3, 1.1, 2.1) ~ 0L,
      TRUE                              ~ 1L
    )
  )

step2_matched <- step2_dedup
step2_still_unmatched <- step1_unmatched %>%
  filter(!patid %in% step2_matched$patid)

message("Step 2 (closest earlier address): ", n_distinct(step2_matched$patid), " patients matched")
message("  Still unmatched:                ", n_distinct(step2_still_unmatched$patid), " patients")

# ========================================
# Section 5 -- Step 3: Address start within 30 days after dx (SAS V5_5 lines 258-309)
# ========================================

step3_join <- step2_still_unmatched %>%
  select(patid, first_admit_date) %>%
  left_join(zip_ruca, by = "patid") %>%
  mutate(
    days_START_can = if_else(
      !is.na(ADDRESS_PERIOD_START),
      as.numeric(ADDRESS_PERIOD_START - first_admit_date),
      NA_real_
    )
  ) %>%
  # SAS line 293: delete if days_START_can < 0 OR days_START_can > 30
  filter(!is.na(days_START_can) & days_START_can >= 0 & days_START_can <= 30) %>%
  filter(!is.na(ADDRESS_ZIP5) & ADDRESS_ZIP5 != "") %>%
  filter(!is.na(RUCA1)) %>%
  filter(RUCA1 != 99)

# Deduplicate: lowest days_START_can (earliest start = closest to dx date from after)
step3_dedup <- step3_join %>%
  arrange(patid, days_START_can) %>%
  distinct(patid, .keep_all = TRUE) %>%
  mutate(
    ruca3 = case_when(
      RUCA1 %in% c(1, 2, 3, 1.1, 2.1) ~ 0L,
      TRUE                              ~ 1L
    )
  )

step3_matched <- step3_dedup %>% filter(!is.na(ruca3))
step3_no_ruca <- step2_still_unmatched %>%
  filter(!patid %in% step3_matched$patid)

message("Step 3 (start within 30 days after): ", n_distinct(step3_matched$patid), " patients matched")
message("  No RUCA at baseline:               ", n_distinct(step3_no_ruca$patid), " patients")

# ========================================
# Section 6 -- Combine Steps 1-3 (SAS V5_5 lines 313-314)
# ========================================

keep_cols <- c("patid", "first_admit_date", "ADDRESS_ZIP5", "RUCA1", "RUCA2",
               "STATE_ruca", "ZIP_TYPE_ruca", "days_START_can", "ruca3")

ruca_combined <- bind_rows(
  step1_matched %>% select(any_of(keep_cols)),
  step2_matched %>% select(any_of(keep_cols)),
  step3_matched %>% select(any_of(keep_cols))
) %>%
  # Final ruca3 clean-up (SAS V5_5 lines 350-356)
  mutate(
    ruca3 = if_else(RUCA1 == 99 | is.na(RUCA1), NA_integer_, ruca3)
  )

message("\nCombined RUCA dataset: ", nrow(ruca_combined), " patients")
message("  ruca3=0 (urban):  ", sum(ruca_combined$ruca3 == 0, na.rm = TRUE))
message("  ruca3=1 (rural):  ", sum(ruca_combined$ruca3 == 1, na.rm = TRUE))
message("  ruca3=NA:         ", sum(is.na(ruca_combined$ruca3)))

# ========================================
# Section 7 -- SDI Derivation (SAS V5_5 lines 359-383)
# ========================================
# ADDRESS_ZIP5 -> zcta (01_imported_zcta.rds) -> sdi_score (01_imported_sdi.rds)
# SDI source: RGC SDI 2011-2015 by ZCTA (produced by 00_build_sdi.R from
#   reference/asset_rgc_sdi_2011_through_2015_zcta.csv).

message("\n=== Section 7: SDI Derivation ===")

# ZCTA lookup: ADDRESS_ZIP5 -> zcta
zcta <- readRDS(file.path(data_dir_processed, "01_imported_zcta.rds"))
if ("id" %in% names(zcta)) zcta <- rename(zcta, patid = id)
# zcta table has at minimum: ADDRESS_ZIP5, zcta

sdi_path <- file.path(data_dir_processed, "01_imported_sdi.rds")
if (!file.exists(sdi_path)) {
  stop("SDI lookup missing: 01_imported_sdi.rds\n",
       "Run R/00_build_sdi.R (sourced from 01_import.R) first.")
}
sdi_raw <- readRDS(sdi_path)   # columns: zcta (5-char text), sdi_score (1-100 percentile)

message("  SDI lookup rows: ", nrow(sdi_raw))

# Join: ruca_combined -> zcta by ADDRESS_ZIP5 -> sdi by zcta
ruca_zcta <- ruca_combined %>%
  left_join(
    zcta %>% select(ADDRESS_ZIP5, zcta),
    by = "ADDRESS_ZIP5"
  )

ruca_zcta_sdi <- ruca_zcta %>%
  left_join(sdi_raw, by = "zcta")

# SAS line 383: delete if sdi_score=.
n_before_sdi <- nrow(ruca_zcta_sdi)
ruca_zcta_sdi <- ruca_zcta_sdi %>% filter(!is.na(sdi_score))
message("  SDI-linked patients: ", nrow(ruca_zcta_sdi),
        " (dropped ", n_before_sdi - nrow(ruca_zcta_sdi), " with missing SDI)")

geo_final <- ruca_zcta_sdi %>%
  rename(first_can_ruca = ruca3, first_can_sdi_score = sdi_score) %>%
  select(patid, ADDRESS_ZIP5, zcta, RUCA1, RUCA2,
         first_can_ruca, first_can_sdi_score)

# ========================================
# Section 8 -- Attrition
# ========================================

n_cohort  <- nrow(cohort)
n_ruca    <- n_distinct(ruca_combined$patid)
n_no_ruca <- n_distinct(step3_no_ruca$patid)
n_sdi     <- nrow(geo_final)

geo_attrition <- tibble(
  step        = 1:4,
  description = c("Cohort entering geo derivation",
                  "RUCA matched (steps 1-3)",
                  "No RUCA at baseline",
                  "RUCA + SDI linked"),
  n_patients  = c(n_cohort, n_ruca, n_no_ruca, n_sdi),
  n_excluded  = c(0L,
                  n_cohort - n_ruca,
                  NA_integer_,
                  n_ruca - n_sdi)
)

message("\nGeo attrition:")
print(geo_attrition)

# ========================================
# Section 9 -- Save
# ========================================

saveRDS(geo_final,     file.path(data_dir_processed, "03_geo.rds"))
saveRDS(geo_attrition, file.path(data_dir_processed, "03_geo_attrition.rds"))

message("\nSaved: 03_geo.rds (", nrow(geo_final), " patients)")
message("Saved: 03_geo_attrition.rds")
message("\nVariables produced:")
message("  first_can_ruca:       0=urban, 1=rural, NA=no RUCA match")
message("  first_can_sdi_score:  social deprivation index (continuous)")
message("\nNext step: 03_covariates.R reads 03_geo.rds")
message("Completed: ", Sys.time())
