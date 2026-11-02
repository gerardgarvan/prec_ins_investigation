# tests/testthat/helper-phase4-fixtures.R
# Mock data fixtures for Phase 4 Statistical Analysis & Output test infrastructure
# Provides 8-patient analytical dataset with known statistical properties for testing
# Table 1, regression, and frequency table requirements (STA-01 through STA-07)
#
# Fixture design: 8 patients with deterministic expected values for all statistical tests
# Uses mock_p4_* prefix to avoid collision with Phase 2 mock_* and Phase 3 mock_p3_* fixtures

library(tibble)
library(dplyr)

# ==============================================================================
# Mock Phase 4 Analytical Dataset (8 patients, mirrors 03_analytical.rds schema)
# ==============================================================================

mock_p4_analytical <- tibble(
  # Patient 1 (P201): Female, WH, non-Hispanic, age 62, SDI tertile 1, RUCA 1,
  # Private->Medicare insurance change, surgery+chemo (intensity 4), Breast cancer,
  # 5 non-acute encounters, 3 cancer visits, 2 with provider, 1 survivorship visit
  patid = "P201",
  sex = "F",
  race = "05",
  race2 = "WH",
  hispanic = "N",
  age = 62,
  age_cat = 4L,
  first_sdi = 30,
  first_sdi2 = 1L,
  first_ruca = "1",
  first_payer = "Private",
  last_payer = "Medicare",
  change_ins = 1L,
  chemo = 1L,
  surgery = 1L,
  radiation = 0L,
  sct = 0L,
  intensity = 4L,
  intensity2 = 3L,
  group_site = "Breast",
  group_site2 = "breast",
  source = "UF",
  n_Enc_nonacute_care = 5L,
  n_Cancer_related_visit = 3L,
  n_cancer_visit_and_prov = 2L,
  n_Survivorship_visit = 1L,
  enc_nonacute_ind = 1L,
  cancer_related_ind = 1L,
  cancer_visit_and_prov_ind = 1L,
  Survivorship_visit_ind = 1L,
  person_time_days = 365,
  log_person_time_days = log(365),
  first_admit_date = as.Date("2018-01-15"),
  last_admit_date = as.Date("2019-01-15")
) %>%
  bind_rows(
    # Patient 2 (P202): Male, AA, non-Hispanic, age 70, SDI tertile 2, RUCA 1,
    # Medicare->Medicare no change, surgery+radiation (intensity 5), Prostate cancer,
    # 8 non-acute encounters, 6 cancer visits, 4 with provider, 3 survivorship visits
    tibble(
      patid = "P202",
      sex = "M",
      race = "03",
      race2 = "AA",
      hispanic = "N",
      age = 70,
      age_cat = 5L,
      first_sdi = 50,
      first_sdi2 = 2L,
      first_ruca = "1",
      first_payer = "Medicare",
      last_payer = "Medicare",
      change_ins = 0L,
      chemo = 0L,
      surgery = 1L,
      radiation = 1L,
      sct = 0L,
      intensity = 5L,
      intensity2 = 3L,
      group_site = "Prostate",
      group_site2 = "prostate",
      source = "UF",
      n_Enc_nonacute_care = 8L,
      n_Cancer_related_visit = 6L,
      n_cancer_visit_and_prov = 4L,
      n_Survivorship_visit = 3L,
      enc_nonacute_ind = 1L,
      cancer_related_ind = 1L,
      cancer_visit_and_prov_ind = 1L,
      Survivorship_visit_ind = 1L,
      person_time_days = 730,
      log_person_time_days = log(730),
      first_admit_date = as.Date("2017-06-01"),
      last_admit_date = as.Date("2019-06-01")
    )
  ) %>%
  bind_rows(
    # Patient 3 (P203): Female, WH, Hispanic, age 45, SDI tertile 3, RUCA 4,
    # Medicaid->Private insurance change, surgery+chemo+radiation (intensity 7), Colorectal cancer,
    # 3 non-acute encounters, 2 cancer visits, 1 with provider, 0 survivorship visits
    tibble(
      patid = "P203",
      sex = "F",
      race = "05",
      race2 = "WH",
      hispanic = "Y",
      age = 45,
      age_cat = 3L,
      first_sdi = 80,
      first_sdi2 = 3L,
      first_ruca = "4",
      first_payer = "Medicaid",
      last_payer = "Private",
      change_ins = 1L,
      chemo = 1L,
      surgery = 1L,
      radiation = 1L,
      sct = 0L,
      intensity = 7L,
      intensity2 = 4L,
      group_site = "Colorectal",
      group_site2 = "digestive",
      source = "Jax",
      n_Enc_nonacute_care = 3L,
      n_Cancer_related_visit = 2L,
      n_cancer_visit_and_prov = 1L,
      n_Survivorship_visit = 0L,
      enc_nonacute_ind = 1L,
      cancer_related_ind = 1L,
      cancer_visit_and_prov_ind = 1L,
      Survivorship_visit_ind = 0L,
      person_time_days = 200,
      log_person_time_days = log(200),
      first_admit_date = as.Date("2019-03-01"),
      last_admit_date = as.Date("2019-09-17")
    )
  ) %>%
  bind_rows(
    # Patient 4 (P204): Male, OT, non-Hispanic, age 55, SDI tertile 1, RUCA 1,
    # Private->Private no change, chemo only (intensity 2), Lung cancer,
    # 4 non-acute encounters, 2 cancer visits, 1 with provider, 0 survivorship visits
    tibble(
      patid = "P204",
      sex = "M",
      race = "01",
      race2 = "OT",
      hispanic = "N",
      age = 55,
      age_cat = 4L,
      first_sdi = 40,
      first_sdi2 = 1L,
      first_ruca = "1",
      first_payer = "Private",
      last_payer = "Private",
      change_ins = 0L,
      chemo = 1L,
      surgery = 0L,
      radiation = 0L,
      sct = 0L,
      intensity = 2L,
      intensity2 = 2L,
      group_site = "Lung",
      group_site2 = "respiratory",
      source = "UF",
      n_Enc_nonacute_care = 4L,
      n_Cancer_related_visit = 2L,
      n_cancer_visit_and_prov = 1L,
      n_Survivorship_visit = 0L,
      enc_nonacute_ind = 1L,
      cancer_related_ind = 1L,
      cancer_visit_and_prov_ind = 1L,
      Survivorship_visit_ind = 0L,
      person_time_days = 500,
      log_person_time_days = log(500),
      first_admit_date = as.Date("2018-07-15"),
      last_admit_date = as.Date("2019-11-27")
    )
  ) %>%
  bind_rows(
    # Patient 5 (P205): Female, WH, non-Hispanic, age 38, SDI tertile 2, RUCA 1,
    # Private->Medicaid insurance change, SCT (intensity 8), Leukemia,
    # 10 non-acute encounters, 8 cancer visits, 6 with provider, 4 survivorship visits
    tibble(
      patid = "P205",
      sex = "F",
      race = "05",
      race2 = "WH",
      hispanic = "N",
      age = 38,
      age_cat = 2L,
      first_sdi = 60,
      first_sdi2 = 2L,
      first_ruca = "1",
      first_payer = "Private",
      last_payer = "Medicaid",
      change_ins = 1L,
      chemo = 0L,
      surgery = 0L,
      radiation = 0L,
      sct = 1L,
      intensity = 8L,
      intensity2 = 4L,
      group_site = "Leukemia",
      group_site2 = "hematologic",
      source = "UF",
      n_Enc_nonacute_care = 10L,
      n_Cancer_related_visit = 8L,
      n_cancer_visit_and_prov = 6L,
      n_Survivorship_visit = 4L,
      enc_nonacute_ind = 1L,
      cancer_related_ind = 1L,
      cancer_visit_and_prov_ind = 1L,
      Survivorship_visit_ind = 1L,
      person_time_days = 1000,
      log_person_time_days = log(1000),
      first_admit_date = as.Date("2017-01-10"),
      last_admit_date = as.Date("2019-10-06")
    )
  ) %>%
  bind_rows(
    # Patient 6 (P206): Male, AA, non-Hispanic, age 72, SDI tertile 3, RUCA 7,
    # Medicare->Dual insurance change, surgery only (intensity 1), Kidney cancer,
    # 2 non-acute encounters, 1 cancer visit, 0 with provider, 0 survivorship visits
    tibble(
      patid = "P206",
      sex = "M",
      race = "03",
      race2 = "AA",
      hispanic = "N",
      age = 72,
      age_cat = 5L,
      first_sdi = 90,
      first_sdi2 = 3L,
      first_ruca = "7",
      first_payer = "Medicare",
      last_payer = "Dual",
      change_ins = 1L,
      chemo = 0L,
      surgery = 1L,
      radiation = 0L,
      sct = 0L,
      intensity = 1L,
      intensity2 = 1L,
      group_site = "Kidney",
      group_site2 = "urological",
      source = "Jax",
      n_Enc_nonacute_care = 2L,
      n_Cancer_related_visit = 1L,
      n_cancer_visit_and_prov = 0L,
      n_Survivorship_visit = 0L,
      enc_nonacute_ind = 1L,
      cancer_related_ind = 1L,
      cancer_visit_and_prov_ind = 0L,
      Survivorship_visit_ind = 0L,
      person_time_days = 150,
      log_person_time_days = log(150),
      first_admit_date = as.Date("2019-06-01"),
      last_admit_date = as.Date("2019-10-29")
    )
  ) %>%
  bind_rows(
    # Patient 7 (P207): Female, OT, non-Hispanic, age 50, SDI tertile 1, RUCA 1,
    # Private->Private no change, radiation only (intensity 3), Breast cancer,
    # 6 non-acute encounters, 4 cancer visits, 3 with provider, 2 survivorship visits
    tibble(
      patid = "P207",
      sex = "F",
      race = "02",
      race2 = "OT",
      hispanic = "N",
      age = 50,
      age_cat = 3L,
      first_sdi = 45,
      first_sdi2 = 1L,
      first_ruca = "1",
      first_payer = "Private",
      last_payer = "Private",
      change_ins = 0L,
      chemo = 0L,
      surgery = 0L,
      radiation = 1L,
      sct = 0L,
      intensity = 3L,
      intensity2 = 2L,
      group_site = "Breast",
      group_site2 = "breast",
      source = "UF",
      n_Enc_nonacute_care = 6L,
      n_Cancer_related_visit = 4L,
      n_cancer_visit_and_prov = 3L,
      n_Survivorship_visit = 2L,
      enc_nonacute_ind = 1L,
      cancer_related_ind = 1L,
      cancer_visit_and_prov_ind = 1L,
      Survivorship_visit_ind = 1L,
      person_time_days = 600,
      log_person_time_days = log(600),
      first_admit_date = as.Date("2018-04-01"),
      last_admit_date = as.Date("2019-11-22")
    )
  ) %>%
  bind_rows(
    # Patient 8 (P208): Male, WH, non-Hispanic, age 68, SDI tertile 1, RUCA 4,
    # Medicare->Medicare no change, no treatment (intensity 0), Colorectal cancer,
    # 1 non-acute encounter, 0 cancer visits, 0 with provider, 0 survivorship visits
    tibble(
      patid = "P208",
      sex = "M",
      race = "05",
      race2 = "WH",
      hispanic = "N",
      age = 68,
      age_cat = 5L,
      first_sdi = 35,
      first_sdi2 = 1L,
      first_ruca = "4",
      first_payer = "Medicare",
      last_payer = "Medicare",
      change_ins = 0L,
      chemo = 0L,
      surgery = 0L,
      radiation = 0L,
      sct = 0L,
      intensity = 0L,
      intensity2 = 0L,
      group_site = "Colorectal",
      group_site2 = "digestive",
      source = "Jax",
      n_Enc_nonacute_care = 1L,
      n_Cancer_related_visit = 0L,
      n_cancer_visit_and_prov = 0L,
      n_Survivorship_visit = 0L,
      enc_nonacute_ind = 1L,
      cancer_related_ind = 0L,
      cancer_visit_and_prov_ind = 0L,
      Survivorship_visit_ind = 0L,
      person_time_days = 90,
      log_person_time_days = log(90),
      first_admit_date = as.Date("2019-09-01"),
      last_admit_date = as.Date("2019-11-30")
    )
  )

# ==============================================================================
# Variable Label List for gtsummary
# ==============================================================================

mock_p4_label_list <- list(
  change_ins ~ "Insurance change",
  age_cat ~ "Age category",
  sex ~ "Sex",
  race2 ~ "Race",
  hispanic ~ "Hispanic ethnicity",
  group_site ~ "Cancer site",
  intensity2 ~ "Treatment intensity",
  first_sdi2 ~ "SDI (tertiles)",
  first_ruca ~ "Rural-urban classification",
  n_Enc_nonacute_care ~ "Non-acute care encounters",
  n_Survivorship_visit ~ "Survivorship visits"
)

# ==============================================================================
# === Expected Values for Tests ===
# ==============================================================================
# Fixture design: 8 patients, 4 change_ins=1 (P201, P203, P205, P206), 4 change_ins=0 (P202, P204, P207, P208)
#
# Table 1 expected values (STA-01):
#   Total N = 8
#   change_ins=1 group: n=4 (P201, P203, P205, P206)
#   change_ins=0 group: n=4 (P202, P204, P207, P208)
#   Sex distribution: Female=4 (P201,P203,P205,P207), Male=4 (P202,P204,P206,P208)
#   Race2: WH=4 (P201,P203,P205,P208), AA=2 (P202,P206), OT=2 (P204,P207)
#   Median age overall (sorted): 38,45,50,55,62,68,70,72 -> median = (55+62)/2 = 58.5
#
# Bivariate test expected (STA-02):
#   Sex by change_ins 2x2 table:
#     change_ins=1: F=3(P201,P203,P205), M=1(P206)
#     change_ins=0: F=1(P207), M=3(P202,P204,P208)
#   (chi-square test computable from 2x2)
#
# Survivorship visit rates for Poisson (STA-03):
#   change_ins=1: total visits=1+0+4+0=5, total PT=365+200+1000+150=1715 days
#   change_ins=0: total visits=3+0+2+0=5, total PT=730+500+600+90=1920 days
#   rate_1 = 5/1715 = 0.002915, rate_0 = 5/1920 = 0.002604
#   crude IRR = rate_1/rate_0 = 1.12 (approximately)
#
# Frequency table expected (STA-07):
#   group_site distribution: Breast=2, Colorectal=2, Prostate=1, Lung=1, Leukemia=1, Kidney=1
#   intensity2 distribution: 0=1, 1=1, 2=2, 3=2, 4=2

message("Phase 4 mock fixtures loaded: 8 patients (mock_p4_analytical)")
message("Expected: 4 change_ins=1, 4 change_ins=0")
message("Fixture objects: mock_p4_analytical, mock_p4_label_list")
