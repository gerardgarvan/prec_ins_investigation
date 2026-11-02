# tests/make_fixtures.R
# Build synthetic RDS fixtures under tests/testdata/processed/ and raw/.
# Run once (or re-run to regenerate).  Does NOT require real data or HiPerGator.
#
# Usage:
#   Rscript tests/make_fixtures.R
#
# Edge cases covered:
#   - Same encounterid (E008) appears in dx_part1 AND dx_part2 (cross-part merge)
#   - Patient P004 has no cancer dx (any_reportable_cancer must stay 0)
#   - Patient P005 has an icd_personal_trt code (Z92.21)
#   - Patient P006 has sex="UN" (excluded by 03_cohort.R)
#   - Patient P007 has age=12 (excluded by 03_cohort.R age>=18 filter)
#   - Encounter E009 has NA payer
#   - Patient P010 has two encounters with different payers (change_ins test)
#   - Encounter E011 is a follow-up (admit_date > first_admit_date) for P001

library(here)

outdir <- here::here("tests", "testdata", "processed")
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
dir.create(here::here("tests", "testdata", "raw"), recursive = TRUE, showWarnings = FALSE)
dir.create(here::here("tests", "testdata", "output", "tables"),    recursive = TRUE, showWarnings = FALSE)
dir.create(here::here("tests", "testdata", "output", "figures"),   recursive = TRUE, showWarnings = FALSE)
dir.create(here::here("tests", "testdata", "output", "diagnostics"), recursive = TRUE, showWarnings = FALSE)

# ============================================================
# 01_formats.rds (minimal subset needed by 02_clean.R)
# ============================================================
sas_formats <- list(
  enc_type = list(
    levels = c("AV","ED","EI","IP","IS","OS","IC","TH","OA","NI","UN","OT"),
    labels = c("Ambulatory Visit","Emergency Department",
               "ED Admit to IP","Inpatient Hospital Stay",
               "Non-Acute Institutional","Observation Stay",
               "Institutional Consult","Telehealth",
               "Other Ambulatory","No information","Unknown","Other")
  ),
  discharge_status = list(
    levels = c("HO","EX","NI","UN","OT"),
    labels = c("Home / Self Care","Expired","No information","Unknown","Other")
  ),
  discharge_disposition = list(
    levels = c("A","E","NI","UN","OT"),
    labels = c("Discharged alive","Expired","No information","Unknown","Other")
  ),
  p_payer = list(
    levels = c("5","1","2","3","4","8","9","U"),
    labels = c("Private","Medicare","Medicaid","Private","Med_Medicaid",
               "Uninsured","Other","Unknown")
  ),
  payerr = list(
    levels = c("5","1","2","3","4","8","9","U"),
    labels = c("Private","Medicare","Medicaid","Government","Med_Medicaid",
               "None","Other","Unknown")
  ),
  payerrr = list(
    levels = c("5","1","2","3","4","8","9","U"),
    labels = c("Private","Public","Public","Government","Public",
               "None","Other","Unknown")
  )
)
saveRDS(sas_formats, file.path(outdir, "01_formats.rds"))
message("Saved 01_formats.rds")

# ============================================================
# 01_imported_icd_groups.rds
# Columns (after clean_names on SAS ICD9_10 / Group_Site):
#   icd9_10, group_site, group_detailed_site, group_primary_disease_site
# Must verify actual column names on HiPerGator:
#   names(readRDS(file.path(data_dir_processed, "01_imported_icd_groups.rds")))
# ============================================================
icd_groups <- data.frame(
  icd9_10 = c("C50.911","C50.912","C50.919","C50.9",
               "C61",
               "C18.7","C20",
               "C64.9",
               "C91.10","C91.1",
               "C79.51",
               "C56.3"),
  group_site = c("Breast","Breast","Breast","Breast",
                 "Male Genital System",
                 "Digestive","Digestive",
                 "Urinary",
                 "Hematologic","Hematologic",
                 "Bones, joints, and soft tissue",
                 "Female Genital System"),
  group_detailed_site = c("Breast","Breast","Breast","Breast",
                           "Prostate","Colon","Rectum",
                           "Kidney","Non-Hodgkin Lymphoma","Non-Hodgkin Lymphoma",
                           "Bone Mets","Ovary"),
  group_primary_disease_site = c("Breast","Breast","Breast","Breast",
                                  "Prostate","Colon","Rectum",
                                  "Kidney","NHL","NHL",
                                  "Bone Metastasis","Ovary"),
  stringsAsFactors = FALSE
)
saveRDS(icd_groups, file.path(outdir, "01_imported_icd_groups.rds"))
message("Saved 01_imported_icd_groups.rds")

# ============================================================
# Encounter parts (2 parts, 6 encounters each)
# SAS column ID -> patid after import_sas() rename
# ============================================================
enc_base <- data.frame(
  patid = c("P001","P002","P003","P004","P005","P006",
            "P007","P008","P009","P010","P001","P010"),
  encounterid = c("E001","E002","E003","E004","E005","E006",
                  "E007","E008","E009","E010","E011","E012"),
  enc_type = c("AV","IP","AV","AV","TH","AV",
               "AV","AV","AV","AV","AV","AV"),
  admit_date = as.Date(c("2020-01-15","2020-02-10","2020-03-05","2020-04-12",
                         "2020-05-20","2020-06-10","2020-07-15","2020-08-20",
                         "2020-09-05","2020-10-12","2021-02-01","2021-03-15")),
  discharge_date = as.Date(c("2020-01-15","2020-02-17","2020-03-05","2020-04-12",
                             "2020-05-20","2020-06-10","2020-07-15","2020-08-20",
                             "2020-09-05","2020-10-12","2021-02-01","2021-03-15")),
  discharge_status = rep("HO", 12),
  discharge_disposition = rep("A", 12),
  payer_type_primary = c("5","1","2","5","1","2","5","1",NA,"5","1","2"),
  payer_type_secondary = rep(NA_character_, 12),
  providerid = c("PROV001","PROV002","PROV001","PROV003","PROV001","PROV002",
                 "PROV003","PROV001","PROV002","PROV001","PROV001","PROV002"),
  stringsAsFactors = FALSE
)
saveRDS(enc_base[1:6, ],  file.path(outdir, "01_imported_enc_part1.rds"))
saveRDS(enc_base[7:12, ], file.path(outdir, "01_imported_enc_part2.rds"))
message("Saved 01_imported_enc_part1.rds + part2.rds")

# ============================================================
# Diagnosis parts (2 parts)
# Edge case: E008 appears in BOTH parts (cross-part aggregation test)
# ============================================================
dx_part1 <- data.frame(
  patid      = c("P001","P001","P002","P003","P004","P004","P005","P008"),
  encounterid = c("E001","E001","E002","E003","E004","E004","E005","E008"),
  diagnosisid = paste0("DX", sprintf("%02d", 1:8)),
  dx         = c("C50.911","I10",   # P001-E001: cancer + comorbidity
                 "C34.90",           # P002-E002: lung (prefix override -> Oral/resp)
                 "C18.7",            # P003-E003: colon -> Digestive (via icd_groups)
                 "I10","E11.9",      # P004-E004: no cancer
                 "Z92.21",           # P005-E005: icd_personal_trt code (ICD-10 Z92.21)
                 "C64.9"),           # P008-E008: kidney -> Urinary (via icd_groups)
  dx_type    = c("10","10","10","10","10","10","10","10"),
  dx_date    = as.Date(c("2020-01-15","2020-01-15","2020-02-10","2020-03-05",
                         "2020-04-12","2020-04-12","2020-05-20","2020-08-20")),
  dx_source  = rep("FI", 8),
  pdx        = c("P","S","P","P","P","S","P","P"),
  stringsAsFactors = FALSE
)

dx_part2 <- data.frame(
  patid       = c("P006","P007","P008","P009","P010","P010","P001"),
  encounterid = c("E006","E007","E008","E009","E010","E012","E011"),
  diagnosisid = paste0("DX", sprintf("%02d", 9:15)),
  dx          = c("C91.10",   # P006-E006: cancer (but patient excluded by sex=UN)
                  "C50.911",  # P007-E007: cancer (but patient excluded by age<18)
                  "Z92.21",   # P008-E008: icd_personal_trt (CROSS-PART: same encounter)
                  "C79.51",   # P009-E009: bone mets -> Bones/joints/soft tissue
                  "C20",      # P010-E010: rectal -> Digestive
                  "I10",      # P010-E012: follow-up, no cancer
                  "C50.911"), # P001-E011: follow-up cancer encounter
  dx_type     = rep("10", 7),
  dx_date     = as.Date(c("2020-06-10","2020-07-15","2020-08-20","2020-09-05",
                           "2020-10-12","2021-03-15","2021-02-01")),
  dx_source   = rep("FI", 7),
  pdx         = c("P","P","S","P","P","S","P"),
  stringsAsFactors = FALSE
)

saveRDS(dx_part1, file.path(outdir, "01_imported_dx_part1.rds"))
saveRDS(dx_part2, file.path(outdir, "01_imported_dx_part2.rds"))
message("Saved 01_imported_dx_part1.rds + part2.rds")

# ============================================================
# Procedure parts (2 parts)
# P002-E002: chemo CPT code (96413)
# P003-E003: surgery ICD-10-PCS (0DB74ZZ starts with 0+letter)
# P005-E005: SCT CPT (38240)
# ============================================================
proc_part1 <- data.frame(
  patid       = c("P001","P002","P003","P004","P005"),
  encounterid = c("E001","E002","E003","E004","E005"),
  proceduresid = paste0("PX", sprintf("%02d", 1:5)),
  px          = c("99213",  "96413",  "0DB74ZZ","99213","38240"),
  px_type     = c("CH",     "CH",     "10",     "CH",   "CH"),
  px_source   = rep("BI", 5),
  px_date     = as.Date(c("2020-01-15","2020-02-10","2020-03-05","2020-04-12","2020-05-20")),
  stringsAsFactors = FALSE
)

proc_part2 <- data.frame(
  patid       = c("P006","P007","P008","P009","P010"),
  encounterid = c("E006","E007","E008","E009","E010"),
  proceduresid = paste0("PX", sprintf("%02d", 6:10)),
  px          = c("77300", "99213","77050","99213","Z51.0"),
  px_type     = c("CH",    "CH",   "CH",   "CH",   "10"),
  px_source   = rep("BI", 5),
  px_date     = as.Date(c("2020-06-10","2020-07-15","2020-08-20","2020-09-05","2020-10-12")),
  stringsAsFactors = FALSE
)
# P006: radiation CPT 77300; P010: radiation ICD-10 Z51.0

saveRDS(proc_part1, file.path(outdir, "01_imported_proc_part1.rds"))
saveRDS(proc_part2, file.path(outdir, "01_imported_proc_part2.rds"))
message("Saved 01_imported_proc_part1.rds + part2.rds")

# ============================================================
# Dispensing (P002 and P005 have dispensing records)
# ============================================================
dispensing <- data.frame(
  patid = c("P002","P002","P005"),
  dispensingid = c("DISP01","DISP02","DISP03"),
  ndc = c("59148011506","59148011506","00069311020"),
  dispense_date = as.Date(c("2020-02-15","2020-03-01","2020-05-25")),
  dispense_sup = c(30L, 30L, 28L),
  dispense_amt = c(1.0, 1.0, 1.0),
  stringsAsFactors = FALSE
)
saveRDS(dispensing, file.path(outdir, "01_imported_dispensing.rds"))
message("Saved 01_imported_dispensing.rds")

# ============================================================
# Provider (minimal)
# PROV001 = oncology, PROV002 = oncology, PROV003 = primary care
# ============================================================
provider <- data.frame(
  patid = NA_character_,  # provider table does not have patid in PCORnet CDM
  providerid = c("PROV001","PROV002","PROV003"),
  provider_specialty_primary = c("207RX0202X","207RX0202X","207Q00000X"),
  cancer_provider = c(1L, 1L, 0L),  # oncology specialty = cancer provider
  stringsAsFactors = FALSE
)
# Remove patid from provider (it's a provider-level table)
provider <- provider[, c("providerid","provider_specialty_primary","cancer_provider")]
saveRDS(provider, file.path(outdir, "01_imported_provider.rds"))
message("Saved 01_imported_provider.rds")

# ============================================================
# Demographics (01_imported_demo.rds)
# P006: sex="UN"; P007: age=12
# ============================================================
demo <- data.frame(
  patid = paste0("P", sprintf("%03d", 1:10)),
  sex   = c("F","M","F","M","F","F","M","F","M","F"),  # P006 sex set below
  race  = rep("05", 10),
  hispanic = rep("N", 10),
  age   = c(55,62,48,71,39,44,12,58,67,53),
  valid_id = rep(1L, 10),
  birth_date = as.Date(c("1965-01-01","1958-01-01","1972-01-01","1949-01-01",
                         "1981-01-01","1976-01-01","2008-01-01","1962-01-01",
                         "1953-01-01","1967-01-01")),
  stringsAsFactors = FALSE
)
demo$sex[demo$patid == "P006"] <- "UN"
saveRDS(demo, file.path(outdir, "01_imported_demo.rds"))
message("Saved 01_imported_demo.rds")

# ============================================================
# Enrollment
# ============================================================
enroll <- data.frame(
  patid = paste0("P", sprintf("%03d", 1:10)),
  enr_start_date = as.Date("2019-01-01"),
  enr_end_date   = as.Date("2022-12-31"),
  stringsAsFactors = FALSE
)
saveRDS(enroll, file.path(outdir, "01_imported_enroll.rds"))
message("Saved 01_imported_enroll.rds")

message("\nAll fixtures written to: ", outdir)
message("Run with PIPELINE_TEST=TRUE to point the pipeline at these fixtures.")
