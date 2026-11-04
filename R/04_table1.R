# R/04_table1.R
# Descriptive Statistics, Table 1, and Frequency Tables
# Per STA-01: Table 1 stratified by insurance change (change_ins)
# Per STA-02: Bivariate tests (chi-square categorical, Wilcoxon continuous)
# Per STA-07: Frequency and cross-tabulation tables
#
# SAS Source: V5_17 (PROC FREQ), V5_18 (PROC MEANS, PROC NPAR1WAY)
#
# Inputs:  data/processed/03_analytical.rds (complete-case dataset from Phase 3)
# Outputs: output/tables/table1.docx
#          output/tables/frequencies.docx
#          output/tables/crosstabs.docx

library(here)
source(here::here("R", "config.R"))
library(tidyverse)
library(gtsummary)
library(janitor)
library(flextable)

# ========================================
# Section 2 -- Load Data
# ========================================

message("========================================")
message("Phase 4: Descriptive Statistics & Table 1")
message("Started: ", Sys.time())
message("========================================")

# Load complete-case analytical dataset (from Phase 3)
# Per Pitfall 4 (04-RESEARCH.md): Use complete-case dataset, NOT MI-ready
analytical <- readRDS(file.path(data_dir_processed, "03_analytical.rds"))

message("Loaded analytical dataset:")
message("  Patients: ", format(nrow(analytical), big.mark = ","))
message("  Variables: ", ncol(analytical))

# Verify no missing values in key covariates (complete-case guarantee)
key_vars <- c("sex", "race2", "hispanic", "age_cat", "first_sdi2",
              "first_ruca", "intensity2", "change_ins", "person_time_days")
n_missing <- analytical %>%
  summarize(across(all_of(key_vars), ~sum(is.na(.x)))) %>%
  pivot_longer(everything()) %>%
  filter(value > 0)

if (nrow(n_missing) > 0) {
  message("WARNING: Missing values found in key covariates:")
  print(n_missing)
} else {
  message("  No missing values in key covariates (complete-case verified)")
}

# ========================================
# Section 3 -- Convert Variables to Factors (for gtsummary)
# ========================================

# Convert character/integer coded variables to labeled factors for Table 1
# Per Research Pattern 1: gtsummary auto-detects types; factors display as categorical
analytical_tbl <- analytical %>%
  mutate(
    change_ins = factor(change_ins, levels = c(0, 1),
                        labels = c("No change", "Changed")),
    sex = factor(sex, levels = c("F", "M"),
                 labels = c("Female", "Male")),
    race2 = factor(race2, levels = c("WH", "AA", "OT"),
                   labels = c("White", "African American", "Other")),
    hispanic = factor(hispanic, levels = c("N", "Y"),
                      labels = c("Non-Hispanic", "Hispanic")),
    age_cat = factor(age_cat, levels = 1:5,
                  labels = c("0-14", "15-39", "40-54", "55-64", "65+")),
    first_sdi2 = factor(first_sdi2, levels = 1:3,
                        labels = c("Low (<=45)", "Medium (46-73)", "High (>=74)")),
    intensity2 = factor(intensity2, levels = 0:4,
                        labels = c("Ancillary only", "Surgery only",
                                   "Chemo/Radiation", "Surgery+Chemo/Rad",
                                   "Multi-modal/SCT"))
  )

# ========================================
# Section 4 -- Table 1 (STA-01 + STA-02)
# ========================================

message("\n=== Section 4: Table 1 (STA-01, STA-02) ===")

table1 <- analytical_tbl %>%
  select(
    change_ins,
    # Demographics
    age_at_dx, sex, race2, hispanic,
    # Clinical
    group_site, intensity2,
    # Covariates
    first_sdi2, first_ruca,
    # Outcomes (count)
    n_Enc_nonacute_care, n_Survivorship_visit,
    # Person-time
    person_time_days
  ) %>%
  tbl_summary(
    by = change_ins,
    statistic = list(
      all_continuous() ~ "{median} ({p25}, {p75})",
      all_categorical() ~ "{n} ({p}%)"
    ),
    digits = list(
      all_continuous() ~ c(1, 1, 1),
      all_categorical() ~ c(0, 1)
    ),
    label = list(
      age_at_dx ~ "Age (years)",
      sex ~ "Sex",
      race2 ~ "Race",
      hispanic ~ "Hispanic ethnicity",
      group_site ~ "Cancer site",
      intensity2 ~ "Treatment intensity",
      first_sdi2 ~ "Social deprivation index",
      first_ruca ~ "Rural-urban classification",
      n_Enc_nonacute_care ~ "Non-acute care encounters (n)",
      n_Survivorship_visit ~ "Survivorship visits (n)",
      person_time_days ~ "Follow-up (days)"
    ),
    missing = "no"
  ) %>%
  add_p(
    test = list(
      all_continuous() ~ "wilcox.test",
      all_categorical() ~ "chisq.test.no.correct"
    ),
    pvalue_fun = ~style_pvalue(.x, digits = 3)
  ) %>%
  add_overall() %>%
  bold_labels() %>%
  modify_header(label ~ "**Characteristic**") %>%
  modify_spanning_header(all_stat_cols() ~ "**Insurance Change Status**") %>%
  modify_footnote(
    all_stat_cols() ~ "Median (IQR) for continuous; n (%) for categorical"
  )

# Print to console
message("Table 1 created successfully")
table1

# Export to Word
table1 %>%
  as_flex_table() %>%
  flextable::save_as_docx(path = file.path(output_dir_tables, "table1.docx"))

message("Exported: ", file.path(output_dir_tables, "table1.docx"))

# ========================================
# Section 5 -- Frequency Tables (STA-07)
# ========================================

message("\n=== Section 5: Frequency Tables (STA-07) ===")

# 1-way: Insurance change distribution
freq_change <- analytical %>%
  tabyl(change_ins) %>%
  adorn_totals("row") %>%
  adorn_pct_formatting(digits = 1)

message("Insurance change distribution:")
print(freq_change)

# 1-way: Cancer site distribution
freq_site <- analytical %>%
  tabyl(group_site) %>%
  adorn_totals("row") %>%
  adorn_pct_formatting(digits = 1)

message("\nCancer site distribution:")
print(freq_site)

# 1-way: Treatment intensity distribution
freq_intensity <- analytical_tbl %>%
  tabyl(intensity2) %>%
  adorn_totals("row") %>%
  adorn_pct_formatting(digits = 1)

message("\nTreatment intensity distribution:")
print(freq_intensity)

# 1-way: Age category distribution
freq_age <- analytical_tbl %>%
  tabyl(age_cat) %>%
  adorn_totals("row") %>%
  adorn_pct_formatting(digits = 1)

message("\nAge category distribution:")
print(freq_age)

# 1-way: Race distribution
freq_race <- analytical_tbl %>%
  tabyl(race2) %>%
  adorn_totals("row") %>%
  adorn_pct_formatting(digits = 1)

message("\nRace distribution:")
print(freq_race)

# Combine frequency tables into a Word document
freq_list <- list(
  "Insurance Change" = freq_change,
  "Cancer Site" = freq_site,
  "Treatment Intensity" = freq_intensity,
  "Age Category" = freq_age,
  "Race" = freq_race
)

# Export individual tabyls as flextables to a single Word doc
freq_flex <- purrr::imap(freq_list, function(tbl, name) {
  flextable::flextable(tbl) %>%
    flextable::set_caption(caption = name) %>%
    flextable::autofit()
})

flextable::save_as_docx(
  values = freq_flex,
  path = file.path(output_dir_tables, "frequencies.docx")
)

message("Exported: ", file.path(output_dir_tables, "frequencies.docx"))

# ========================================
# Section 6 -- Cross-Tabulations (STA-07)
# ========================================

message("\n=== Section 6: Cross-Tabulations (STA-07) ===")

# 2-way: Insurance change by cancer site (with chi-square)
crosstab_site <- analytical_tbl %>%
  select(change_ins, group_site) %>%
  tbl_cross(
    row = change_ins,
    col = group_site,
    percent = "row"
  ) %>%
  add_p(source_note = TRUE) %>%
  modify_header(label ~ "**Insurance Change**") %>%
  modify_spanning_header(all_stat_cols() ~ "**Cancer Site**")

# 2-way: Insurance change by race
crosstab_race <- analytical_tbl %>%
  select(change_ins, race2) %>%
  tbl_cross(
    row = change_ins,
    col = race2,
    percent = "row"
  ) %>%
  add_p(source_note = TRUE) %>%
  modify_header(label ~ "**Insurance Change**") %>%
  modify_spanning_header(all_stat_cols() ~ "**Race**")

# 2-way: Insurance change by treatment intensity
crosstab_intensity <- analytical_tbl %>%
  select(change_ins, intensity2) %>%
  tbl_cross(
    row = change_ins,
    col = intensity2,
    percent = "row"
  ) %>%
  add_p(source_note = TRUE) %>%
  modify_header(label ~ "**Insurance Change**") %>%
  modify_spanning_header(all_stat_cols() ~ "**Treatment Intensity**")

# Merge crosstabs and export to Word
crosstab_merged <- tbl_stack(
  list(crosstab_site, crosstab_race, crosstab_intensity),
  group_header = c("Cancer Site", "Race", "Treatment Intensity")
)

crosstab_merged %>%
  as_flex_table() %>%
  flextable::save_as_docx(path = file.path(output_dir_tables, "crosstabs.docx"))

message("Exported: ", file.path(output_dir_tables, "crosstabs.docx"))

# ========================================
# Section 7 -- Summary
# ========================================

message("\n========================================")
message("Phase 4: Descriptive Statistics Complete")
message("Completed: ", Sys.time())
message("========================================")
message("\nOutputs:")
message("  Table 1:       ", file.path(output_dir_tables, "table1.docx"))
message("  Frequencies:   ", file.path(output_dir_tables, "frequencies.docx"))
message("  Crosstabs:     ", file.path(output_dir_tables, "crosstabs.docx"))
message("\nRequirements addressed:")
message("  STA-01: Table 1 stratified by change_ins with median/IQR and n/%")
message("  STA-02: chi-square (categorical) and Wilcoxon (continuous) p-values")
message("  STA-07: Frequency tables and cross-tabulations with chi-square tests")
message("\nNext step: 04_regression.R (Poisson/NB models)")
