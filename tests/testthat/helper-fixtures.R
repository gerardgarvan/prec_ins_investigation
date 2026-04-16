# tests/testthat/helper-fixtures.R
# Mock data fixtures for Phase 2 test infrastructure
# Provides realistic PCORnet CDM encounter, diagnosis, procedure, provider data
# for testing cleaning and merging logic without requiring actual data files

library(tibble)

# ==============================================================================
# Mock SAS Formats (subset needed for Phase 2 tests)
# ==============================================================================

mock_sas_formats <- list()

# Payer formats from 01_formats.R
mock_sas_formats$p_payer <- list(
  levels = c("5", "1", "2", "3", "4", "8", "9", "U"),
  labels = c("Private", "Medicare", "Medicaid", "Private", "Med_Medicaid",
             "Uninsured", "Other", "Unknown")
)

mock_sas_formats$payerr <- list(
  levels = c("5", "1", "2", "3", "4", "8", "9", "U"),
  labels = c("Private", "Medicare", "Medicaid", "Goverment", "Med_Medicaid",
             "None", "Other", "Unknown")
)

# Encounter type format
mock_sas_formats$enc_type <- list(
  levels = c("AV", "ED", "EI", "IP", "IS", "OS", "IC", "TH", "OA", "NI", "UN", "OT"),
  labels = c("Ambulatory Visit", "Emergency Department",
             "Emergency Department Admit to Inpatient Hospital Stay (permissible substitution)",
             "Inpatient Hospital Stay", "Non-Acute Institutional Stay", "Observation Stay",
             "Institutional Professional Consult (permissible substitution)", "Telehealth",
             "Other Ambulatory Visit", "No information", "Unknown", "Other")
)

# Discharge status format
mock_sas_formats$discharge_status <- list(
  levels = c("AF", "AL", "AM", "AW", "EX", "HH", "HO", "HS", "IP", "NH",
             "RH", "RS", "SH", "SN", "NI", "UN", "OT"),
  labels = c("Adult Foster Home", "Assisted Living Facility", "Against Medical Advice",
             "Absent without leave", "Expired", "Home Health", "Home / Self Care",
             "Hospice", "Other Acute Inpatient Hospital", "Nursing Home (Includes ICF)",
             "Rehabilitation Facility", "Residential Facility", "Still In Hospital",
             "Skilled Nursing Facility", "No information", "Unknown", "Other")
)

# Discharge disposition format
mock_sas_formats$discharge_disposition <- list(
  levels = c("A", "E", "NI", "UN", "OT"),
  labels = c("Discharged alive", "Expired", "No information", "Unknown", "Other")
)

# ==============================================================================
# Mock Encounter Data (PCORnet CDM ENCOUNTER table)
# ==============================================================================

# Encounter dataset 1 (5 rows)
mock_encounter1 <- tibble(
  patid = c("P001", "P002", "P003", "P004", "P005"),
  encounterid = c("E001", "E002", "E003", "E004", "E005"),
  enc_type = c("AV", "IP", "ED", "AV", "IP"),
  admit_date = as.Date(c("2020-01-15", "2020-02-10", "2020-03-05", "2020-04-12", "2020-05-20")),
  discharge_date = as.Date(c("2020-01-15", "2020-02-17", "2020-03-05", "2020-04-12", "2020-05-27")),
  discharge_status = c("HO", "HO", "HO", "HO", "HO"),
  discharge_disposition = c("A", "A", "A", "A", "A"),
  payer_type_primary = c("1", "2", "5", NA, "5"),  # Medicare, Medicaid, Private, Missing, Private
  payer_type_secondary = c(NA, NA, "1", NA, NA),
  providerid = c("PROV001", "PROV002", "PROV001", "PROV003", "PROV002"),
  facility_type = c("CLINIC", "HOSPITAL", "ED", "CLINIC", "HOSPITAL")
)

# Encounter dataset 2 (5 rows)
mock_encounter2 <- tibble(
  patid = c("P006", "P007", "P008", "P009", "P010"),
  encounterid = c("E006", "E007", "E008", "E009", "E010"),
  enc_type = c("AV", "ED", "IP", "AV", "AV"),
  admit_date = as.Date(c("2020-06-10", "2020-07-15", "2020-08-20", "2020-09-05", "2020-10-12")),
  discharge_date = as.Date(c("2020-06-10", "2020-07-15", "2020-08-25", "2020-09-05", "2020-10-12")),
  discharge_status = c("HO", "HO", "HO", "HO", "HO"),
  discharge_disposition = c("A", "A", "A", "A", "A"),
  payer_type_primary = c("4", "1", "2", "ZZ", "5"),  # Dual, Medicare, Medicaid, Unmapped, Private
  payer_type_secondary = c(NA, NA, NA, NA, "1"),
  providerid = c("PROV004", "PROV005", "PROV003", "PROV001", "PROV002"),
  facility_type = c("CLINIC", "ED", "HOSPITAL", "CLINIC", "CLINIC")
)

# ==============================================================================
# Mock Diagnosis Data (PCORnet CDM DIAGNOSIS table, 7 parts → simplified to 2)
# ==============================================================================

# Part 1: 15 diagnoses for encounters E001-E005 (3 dx per encounter)
mock_dx_parts <- list()
mock_dx_parts[[1]] <- tibble(
  patid = rep(c("P001", "P002", "P003", "P004", "P005"), each = 3),
  encounterid = rep(c("E001", "E002", "E003", "E004", "E005"), each = 3),
  diagnosisid = paste0("DX", sprintf("%03d", 1:15)),
  dx = c("C50.911", "I10", "E11.9",
         "C61", "I10", "E78.5",
         "C18.7", "K21.9", "I10",
         "C50.912", "E11.9", "I10",
         "C20", "K58.9", "I10"),
  dx_type = rep(c("10", "10", "10"), 5),
  dx_source = rep("FI", 15),
  dx_origin = rep("BI", 15),
  dx_date = rep(as.Date(c("2020-01-15", "2020-02-10", "2020-03-05", "2020-04-12", "2020-05-20")), each = 3),
  dx_poa = rep(c("Y", "Y", "N"), 5),
  pdx = c("P", "S", "S", "P", "S", "S", "P", "S", "S", "P", "S", "S", "P", "S", "S"),
  admit_date = rep(as.Date(c("2020-01-15", "2020-02-10", "2020-03-05", "2020-04-12", "2020-05-20")), each = 3),
  enc_type = rep(c("AV", "IP", "ED", "AV", "IP"), each = 3),
  providerid = rep(c("PROV001", "PROV002", "PROV001", "PROV003", "PROV002"), each = 3),
  source = rep("encounter_dx", 15)
)

# Part 2: 15 diagnoses for encounters E006-E010 (3 dx per encounter)
mock_dx_parts[[2]] <- tibble(
  patid = rep(c("P006", "P007", "P008", "P009", "P010"), each = 3),
  encounterid = rep(c("E006", "E007", "E008", "E009", "E010"), each = 3),
  diagnosisid = paste0("DX", sprintf("%03d", 16:30)),
  dx = c("C34.90", "J44.0", "I10",
         "C79.51", "R07.9", "I10",
         "C64.9", "N18.3", "E11.9",
         "C50.919", "E78.5", "I10",
         "C91.10", "D64.9", "I10"),
  dx_type = rep(c("10", "10", "09"), 5),
  dx_source = rep("FI", 15),
  dx_origin = rep("BI", 15),
  dx_date = rep(as.Date(c("2020-06-10", "2020-07-15", "2020-08-20", "2020-09-05", "2020-10-12")), each = 3),
  dx_poa = rep(c("Y", "N", "Y"), 5),
  pdx = c("P", "S", "S", "P", "S", "S", "P", "S", "S", "P", "S", "S", "P", "S", "S"),
  admit_date = rep(as.Date(c("2020-06-10", "2020-07-15", "2020-08-20", "2020-09-05", "2020-10-12")), each = 3),
  enc_type = rep(c("AV", "ED", "IP", "AV", "AV"), each = 3),
  providerid = rep(c("PROV004", "PROV005", "PROV003", "PROV001", "PROV002"), each = 3),
  source = rep("encounter_dx", 15)
)

# ==============================================================================
# Mock Procedures Data (PCORnet CDM PROCEDURES table, 4 parts → simplified to 2)
# ==============================================================================

# Part 1: 10 procedures for encounters E001-E005 (2 px per encounter)
mock_proc_parts <- list()
mock_proc_parts[[1]] <- tibble(
  patid = rep(c("P001", "P002", "P003", "P004", "P005"), each = 2),
  encounterid = rep(c("E001", "E002", "E003", "E004", "E005"), each = 2),
  proceduresid = paste0("PX", sprintf("%03d", 1:10)),
  px = c("99213", "36415",
         "0F128ZZ", "BB13ZZZ",
         "99284", "71020",
         "99213", "80053",
         "0DB74ZZ", "BB23ZZZ"),
  px_type = c("CH", "CH", "10", "10", "CH", "CH", "CH", "CH", "10", "10"),
  px_source = rep("BI", 10),
  px_date = rep(as.Date(c("2020-01-15", "2020-02-10", "2020-03-05", "2020-04-12", "2020-05-20")), each = 2),
  enc_type = rep(c("AV", "IP", "ED", "AV", "IP"), each = 2),
  providerid = rep(c("PROV001", "PROV002", "PROV001", "PROV003", "PROV002"), each = 2)
)

# Part 2: 10 procedures for encounters E006-E010 (2 px per encounter)
mock_proc_parts[[2]] <- tibble(
  patid = rep(c("P006", "P007", "P008", "P009", "P010"), each = 2),
  encounterid = rep(c("E006", "E007", "E008", "E009", "E010"), each = 2),
  proceduresid = paste0("PX", sprintf("%03d", 11:20)),
  px = c("99213", "93000",
         "99285", "71045",
         "0FT04ZZ", "BB14ZZZ",
         "99213", "85025",
         "99213", "80061"),
  px_type = c("CH", "CH", "CH", "CH", "10", "10", "CH", "CH", "CH", "CH"),
  px_source = rep("BI", 10),
  px_date = rep(as.Date(c("2020-06-10", "2020-07-15", "2020-08-20", "2020-09-05", "2020-10-12")), each = 2),
  enc_type = rep(c("AV", "ED", "IP", "AV", "AV"), each = 2),
  providerid = rep(c("PROV004", "PROV005", "PROV003", "PROV001", "PROV002"), each = 2)
)

# ==============================================================================
# Mock Provider Data (PCORnet CDM PROVIDER table)
# ==============================================================================

mock_provider <- tibble(
  providerid = c("PROV001", "PROV002", "PROV003", "PROV004", "PROV005"),
  provider_specialty_primary = c("207RC0000X", "207RX0202X", "207Q00000X",
                                   "207RC0000X", "207V00000X")
)

# ==============================================================================
# Mock Provider Specialty Reference (study-specific cancer provider flag)
# ==============================================================================

mock_prov_spec <- tibble(
  provider_specialty_primary = c("207RC0000X", "207RX0202X", "207Q00000X",
                                  "207V00000X", "208D00000X"),
  cancer_provider = c(1, 1, 0, 0, 0),
  provider_classification = c("Oncology", "Oncology", "Family Medicine",
                               "Ophthalmology", "General Practice"),
  provider_specialization = c("Medical Oncology", "Radiation Oncology",
                               "Family Practice", "Ophthalmology",
                               "General Practice")
)
