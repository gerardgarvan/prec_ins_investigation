# R/01_formats.R
# Translate Formats.sas (2,495 lines) to R factor definitions
# Per D-01: ALL format definitions translated (PCORnet CDM standard + study-specific)
# Per D-03: Stored as named lists in single sas_formats object
# Per D-02: Duplicate blocks resolved via SAS overwrite semantics (later definition wins)
# Per D-07: SAS errors and conflicting logic documented in inline comments
#
# Source: Formats.sas (canonical reference)
# Formats.sas structure: 4 repeated blocks (lines 1-940, 941-1204, 1211-2146, 2161-2412)
# plus study-specific formats (lines 2414-2495)
# SAS overwrite semantics: later PROC FORMAT definition replaces earlier for same name
#
# FORENSIC NOTE: Block 4 (lines 2161+) is definitive for all duplicated formats.
# Study-specific formats at end (lines 2414-2495) are unique (no duplicates).

library(here)
source(here::here("R", "config.R"))
library(tidyverse)

# Master format list (per D-03: single grep-friendly object)
sas_formats <- list()

# ==============================================================================
# PCORnet CDM Standard Formats (Character formats with $ prefix)
# ==============================================================================
# Source: Formats.sas Block 4 (definitive), lines 2161-2412
# Each format: list with levels (codes) and labels (display names)

# $RACE (Source: lines 4-14, Block 1; identical across all 4 blocks)
sas_formats$race <- list(
  levels = c("01", "02", "03", "04", "05", "06", "07", "NI", "UN", "OT"),
  labels = c("American Indian or Alaska Native", "Asian",
             "Black or African American", "Native Hawaiian or Other Pacific Islander",
             "White", "Multiple race", "Refuse to answer", "No information",
             "Unknown", "Other")
)

# $SEX (Source: lines 16-22)
sas_formats$sex <- list(
  levels = c("A", "F", "M", "NI", "UN", "OT"),
  labels = c("Ambiguous", "Female", "Male", "No information", "Unknown", "Other")
)

# $SEXUAL_ORIENTATION (Source: lines 24-37)
sas_formats$sexual_orientation <- list(
  levels = c("AS", "BI", "GA", "LE", "QU", "QS", "ST", "SE", "MU", "DC", "NI", "UN", "OT"),
  labels = c("Asexual", "Bisexual", "Gay", "Lesbian", "Queer", "Questioning",
             "Straight", "Something else", "Multiple sexual orientations",
             "Decline to answer", "No information", "Unknown", "Other")
)

# $GENDER_IDENTITY (Source: lines 39-50)
sas_formats$gender_identity <- list(
  levels = c("M", "F", "TM", "TF", "GQ", "SE", "MU", "DC", "NI", "UN", "OT"),
  labels = c("Man", "Woman", "Transgender male/Trans man/Female-to-male",
             "Transgender female/Trans woman/Male-to-female", "Genderqueer/Non-binary",
             "Something else", "Multiple gender categories", "Decline to answer",
             "No information", "Unknown", "Other")
)

# $HISPANIC (Source: lines 52-58)
sas_formats$hispanic <- list(
  levels = c("Y", "N", "R", "NI", "UN", "OT"),
  labels = c("Yes", "No", "Refuse to answer", "No information", "Unknown", "Other")
)

# $ADDRESS_USE (Source: lines 60-67)
sas_formats$address_use <- list(
  levels = c("HO", "WO", "TP", "OL", "NI", "UN", "OT"),
  labels = c("Home", "Work", "Temp", "Old/Incorrect", "No information", "Unknown", "Other")
)

# $ADDRESS_TYPE (Source: lines 69-75)
sas_formats$address_type <- list(
  levels = c("PO", "PH", "BO", "NI", "UN", "OT"),
  labels = c("Postal", "Physical", "Both", "No information", "Unknown", "Other")
)

# $ADDRESS_PREFERRED (Source: lines 77-79)
sas_formats$address_preferred <- list(
  levels = c("Y", "N"),
  labels = c("Yes", "No")
)

# $CONDITION_STATUS (Source: lines 82-88)
sas_formats$condition_status <- list(
  levels = c("AC", "RS", "IN", "NI", "UN", "OT"),
  labels = c("Active", "Resolved", "Inactive", "No information", "Unknown", "Other")
)

# $CONDITION_TYPE (Source: lines 90-99)
sas_formats$condition_type <- list(
  levels = c("09", "10", "11", "SM", "HP", "AG", "NI", "UN", "OT"),
  labels = c("ICD-9-CM", "ICD-10-CM/PCS", "ICD-11-CM/PCS", "SNOMED CT",
             "Human Phenotype Ontology", "Algorithmic", "No information", "Unknown", "Other")
)

# $CONDITION_SOURCE (Source: lines 101-110)
sas_formats$condition_source <- list(
  levels = c("PR", "HC", "RG", "CC", "PC", "DR", "NI", "UN", "OT"),
  labels = c("Patient-reported medical history", "Healthcare problem list",
             "Registry cohort", "Patient Chief Complaint",
             "PCORnet-defined condition algorithm", "Derived",
             "No information", "Unknown", "Other")
)

# $DISPENSE_SOURCE (Source: lines 112-120)
sas_formats$dispense_source <- list(
  levels = c("OD", "BI", "CL", "PM", "DR", "NI", "UN", "OT"),
  labels = c("Order/EHR", "Billing", "Claim", "Pharmacy Benefit Manager",
             "Derived", "No information", "Unknown", "Other")
)

# $DISCHARGE_DISPOSITION (Source: lines 122-127)
sas_formats$discharge_disposition <- list(
  levels = c("A", "E", "NI", "UN", "OT"),
  labels = c("Discharged alive", "Expired", "No information", "Unknown", "Other")
)

# $DISCHARGE_STATUS (Source: lines 129-146)
sas_formats$discharge_status <- list(
  levels = c("AF", "AL", "AM", "AW", "EX", "HH", "HO", "HS", "IP", "NH",
             "RH", "RS", "SH", "SN", "NI", "UN", "OT"),
  labels = c("Adult Foster Home", "Assisted Living Facility", "Against Medical Advice",
             "Absent without leave", "Expired", "Home Health", "Home / Self Care",
             "Hospice", "Other Acute Inpatient Hospital", "Nursing Home (Includes ICF)",
             "Rehabilitation Facility", "Residential Facility", "Still In Hospital",
             "Skilled Nursing Facility", "No information", "Unknown", "Other")
)

# $DRG_TYPE (Source: lines 148-153)
sas_formats$drg_type <- list(
  levels = c("01", "02", "NI", "UN", "OT"),
  labels = c("CMS-DRG (old system)", "MS-DRG (current system)",
             "No information", "Unknown", "Other")
)

# $ENC_TYPE (Source: lines 155-167)
sas_formats$enc_type <- list(
  levels = c("AV", "ED", "EI", "IP", "IS", "OS", "IC", "TH", "OA", "NI", "UN", "OT"),
  labels = c("Ambulatory Visit", "Emergency Department",
             "Emergency Department Admit to Inpatient Hospital Stay (permissible substitution)",
             "Inpatient Hospital Stay", "Non-Acute Institutional Stay", "Observation Stay",
             "Institutional Professional Consult (permissible substitution)", "Telehealth",
             "Other Ambulatory Visit", "No information", "Unknown", "Other")
)

# $ADMITTING_SOURCE (Source: lines 169-187)
sas_formats$admitting_source <- list(
  levels = c("AF", "AL", "AV", "ED", "ES", "HH", "HO", "HS", "IP", "NH",
             "RH", "RS", "SN", "IH", "NI", "UN", "OT"),
  labels = c("Adult Foster Home", "Assisted Living Facility", "Ambulatory Visit",
             "Emergency Department", "Emergency Medical Service", "Home Health",
             "Home / Self Care", "Hospice", "Other Acute Inpatient Hospital",
             "Nursing Home (Includes ICF)", "Rehabilitation Facility", "Residential Facility",
             "Skilled Nursing Facility", "Intra-hospital", "No information", "Unknown", "Other")
)

# $CHART (Source: lines 190-193)
sas_formats$chart <- list(
  levels = c("Y", "N"),
  labels = c("Yes", "No")
)

# $ENR_BASIS (Source: lines 195-201)
sas_formats$enr_basis <- list(
  levels = c("I", "D", "G", "A", "E"),
  labels = c("Medical insurance coverage", "Outpatient prescription drug coverage",
             "Geography", "Algorithmic", "Encounter-based")
)

# $VX_CODE_TYPE (Source: lines 203-211)
sas_formats$vx_code_type <- list(
  levels = c("CX", "ND", "CH", "RX", "NI", "UN", "OT"),
  labels = c("CVX", "NDC", "CPT or HCPCS", "RXNORM", "No information", "Unknown", "Other")
)

# $VX_STATUS (Source: lines 213-221)
sas_formats$vx_status <- list(
  levels = c("CP", "ER", "ND", "IC", "NI", "UN", "OT"),
  labels = c("Completed", "Entered in error", "Not Done", "Incomplete",
             "No information", "Unknown", "Other")
)

# $VX_STATUS_REASON (Source: lines 223-231)
sas_formats$vx_status_reason <- list(
  levels = c("IM", "MP", "OS", "PO", "NI", "UN", "OT"),
  labels = c("Immunity", "Medical precaution", "Out of stock", "Patient objective",
             "No information", "Unknown", "Other")
)

# $VX_SOURCE (Source: lines 233-242)
sas_formats$vx_source <- list(
  levels = c("OD", "EF", "IS", "PR", "DR", "NI", "UN", "OT"),
  labels = c("Internal administration", "External feed", "Immunization Information Systems",
             "Patient-reported", "Derived", "No information", "Unknown", "Other")
)

# $OBSGEN_TYPE (Source: lines 245-266)
sas_formats$obsgen_type <- list(
  levels = c("09DX", "09PX", "10DX", "10PX", "11DX", "11PX", "ON", "SM", "HP",
             "HG", "LC", "RX", "ND", "CH", "GM", "UD_*", "PC *", "NI", "UN", "OT"),
  labels = c("ICD-9-CM-DX", "ICD-9-CM-PX", "ICD-10-CM/PCS", "ICD-10-PCS",
             "ICD-11-CM/PCS", "ICD-11-PCS", "ICD-O (Oncology)", "SNOMED",
             "Human Phenotype Ontology", "Human Genome Organization", "LOINC",
             "RXNORM", "NDC", "CPT or HCPCS", "Global Medical Device Nomenclature",
             "User-defined", "PCORnet reserved", "No information", "Unknown", "Other")
)

# $OBSGEN_RESULT_MODIFIER (Source: lines 268-278)
sas_formats$obsgen_result_modifier <- list(
  levels = c("EQ", "GE", "GT", "LE", "LT", "TX", "NI", "UN", "OT"),
  labels = c("Equal", "Greater than or equal to", "Greater than",
             "Less than or equal to", "Less than", "Text", "No information", "Unknown", "Other")
)

# $OBSGEN_TABLE_MODIFIER (Source: lines 280-300)
sas_formats$obsgen_table_modifier <- list(
  levels = c("ENR", "ENC", "DX", "PX", "VT", "DSP", "LAB", "CON", "PRO",
             "RX", "PT", "DTH", "DC", "MA", "OC", "OB", "IM", "LDS", "OT"),
  labels = c("ENROLLMENT", "ENCOUNTER", "DIAGNOSIS", "PROCEDURES", "VITAL",
             "DISPENSING", "LAB_RESULT_CM", "CONDITION", "PRO_CM", "PRESCRIBING",
             "PCORNET_TRIAL", "DEATH", "DEATH CAUSE", "MED_ADMIN", "OBS_CLIN",
             "OBS GEN", "IMMUNIZATION", "LDS_ADDRESS_HISTORY", "Other")
)

# $OBSGEN_SOURCE (Source: lines 302-314)
sas_formats$obsgen_source <- list(
  levels = c("BI", "CL", "RG", "SR", "PR", "PD", "HC", "HD", "DR", "NI", "UN"),
  labels = c("Billing", "Claim", "Registry", "Survey system/mobile app",
             "Patient-reported", "Patient device direct feed", "Healthcare delivery setting",
             "Healthcare device direct feed", "Derived", "No information", "Unknown")
)

# $OBSGEN_ABN_IND (Source: lines 316-328)
sas_formats$obsgen_abn_ind <- list(
  levels = c("AB", "AH", "AL", "CH", "CL", "CR", "IN", "NL", "NI", "UN", "OT"),
  labels = c("Abnormal", "Abnormally high", "Abnormally low", "Critically high",
             "Critically low", "Critical", "Inconclusive", "Normal",
             "No information", "Unknown", "Other")
)

# $PRO_TYPE (Source: lines 330-341)
sas_formats$pro_type <- list(
  levels = c("PM", "NQ", "AM", "NT", "PC", "LC", "HC", "NI", "UN", "OT"),
  labels = c("PROMIS", "Neuro-QoL", "ASQC-Me", "NIH Toolbox", "PRO_CTCAE",
             "LOINC", "HCAHPS", "No information", "Unknown", "Other")
)

# $PRO_METHOD (Source: lines 343-351)
sas_formats$pro_method <- list(
  levels = c("PA", "EC", "PH", "IV", "NI", "UN", "OT"),
  labels = c("Paper", "Electronic", "Telephonic",
             "Telephonic with interactive voice response(IVR) technology",
             "No information", "Unknown", "Other")
)

# $PRO_MODE (Source: lines 353-361)
sas_formats$pro_mode <- list(
  levels = c("SF", "SA", "PR", "PA", "NI", "UN", "OT"),
  labels = c("Self without assistance", "Self with assistance",
             "Proxy without assistance", "Proxy with assistance",
             "No information", "Unknown", "Other")
)

# $PRO_CAT (Source: lines 363-369)
sas_formats$pro_cat <- list(
  levels = c("Y", "N", "NI", "UN", "OT"),
  labels = c("Yes", "No", "No information", "Unknown", "Other")
)

# $PRO_SOURCE (Source: lines 371-380)
sas_formats$pro_source <- list(
  levels = c("OD", "BI", "CL", "SR", "DR", "NI", "UN", "OT"),
  labels = c("Order/EHR", "Billing", "Claim", "Survey system/mobile app",
             "Derived", "No information", "Unknown", "Other")
)

# $RX_FREQUENCY (Source: lines 382-396)
sas_formats$rx_frequency <- list(
  levels = c("01", "02", "03", "04", "05", "06", "07", "08", "10", "11", "NI", "UN", "OT"),
  labels = c("Every day", "Two times a day (BID)", "Three times a day (TID)",
             "Four times a day(QID)", "Every morning", "Every afternoon", "Before meals",
             "After meals", "Every evening", "Once", "No information", "Unknown", "Other")
)

# $RX_PRN_FLAG (Source: lines 398-401)
sas_formats$rx_prn_flag <- list(
  levels = c("Y", "N"),
  labels = c("Yes", "No")
)

# $RX_SOURCE (Source: lines 403-409)
sas_formats$rx_source <- list(
  levels = c("OD", "DR", "NI", "UN", "OT"),
  labels = c("Order/EHR", "Derived", "No information", "Unknown", "Other")
)

# $RX_DISPENSE_AS_WRITTEN (Source: lines 416-422)
sas_formats$rx_dispense_as_written <- list(
  levels = c("Y", "N", "NI", "UN", "OT"),
  labels = c("Yes", "No", "No information", "Unknown", "Other")
)

# $RX_METHOD (Source: lines 423-429)
sas_formats$rx_method <- list(
  levels = c("Y", "N", "NI", "UN", "OT"),
  labels = c("Yes", "No", "No information", "Unknown", "Other")
)

# $OBSCLIN_TYPE (Source: lines 431-441)
sas_formats$obsclin_type <- list(
  levels = c("EQ", "GE", "GT", "LE", "LT", "TX", "NI", "UN", "OT"),
  labels = c("Equal", "Greater than or equal to", "Greater than",
             "Less than or equal to", "Less than", "Text", "No information", "Unknown", "Other")
)

# $OBSCLIN_SOURCE (Source: lines 443-455)
sas_formats$obsclin_source <- list(
  levels = c("BI", "CL", "RG", "PR", "PD", "HC", "HD", "DR", "NI", "UN", "OT"),
  labels = c("Billing", "Claim", "Registry", "Patient-reported",
             "Patient device direct feed", "Healthcare delivery setting",
             "Healthcare device direct feed", "Derived", "No information", "Unknown", "Other")
)

# $OBSCLIN_ABN_IND (Source: lines 457-469)
sas_formats$obsclin_abn_ind <- list(
  levels = c("AB", "AH", "AL", "CH", "CL", "CR", "IN", "NL", "NI", "UN", "OT"),
  labels = c("Abnormal", "Abnormally high", "Abnormally low", "Critically high",
             "Critically low", "Critical", "Inconclusive", "Normal",
             "No information", "Unknown", "Other")
)

# $LAB_RESULT_SOURCE (Source: lines 472-479)
sas_formats$lab_result_source <- list(
  levels = c("OD", "BI", "CL", "DR", "NI", "UN", "OT"),
  labels = c("Order/EHR", "Billing", "Claim", "Derived", "No information", "Unknown", "Other")
)

# $LAB_LOINC_SOURCE (Source: lines 481-490)
sas_formats$lab_loinc_source <- list(
  levels = c("IN", "LM", "HL", "DW", "PC", "DM", "NI", "UN", "OT"),
  labels = c("Instrument", "LIMS (Standalone or EHR)", "HL7 feed or other interface",
             "Data warehouse", "PCORnet ETL", "Other CDM", "No information", "Unknown", "Other")
)

# $PRIORITY (Source: lines 492-498)
sas_formats$priority <- list(
  levels = c("E", "R", "S", "NI", "UN", "OT"),
  labels = c("Expedite", "Routine", "Stat", "No information", "Unknown", "Other")
)

# $RESULT_LOC (Source: lines 501-506)
sas_formats$result_loc <- list(
  levels = c("L", "P", "NI", "UN", "OT"),
  labels = c("Lab", "Point of Care", "No information", "Unknown", "Other")
)

# $LAB_PX_TYPE (Source: lines 508-518)
sas_formats$lab_px_type <- list(
  levels = c("09", "10", "11", "CH", "LC", "ND", "RE", "NI", "UN", "OT"),
  labels = c("ICD-9-CM", "ICD-10-PCS", "ICD-11-PCS", "CPT or HCPCS", "LOINC",
             "NDC", "Revenue", "No information", "Unknown", "Other")
)

# $RESULT_MODIFIER (Source: lines 520-529)
sas_formats$result_modifier <- list(
  levels = c("EQ", "GE", "GT", "LE", "LT", "TX", "NI", "UN", "OT"),
  labels = c("Equal", "Greater than or equal to", "Greater than",
             "Less than or equal to", "Less than", "Text", "No information", "Unknown", "Other")
)

# $NORM_MODIFIER_LOW (Source: lines 531-538)
sas_formats$norm_modifier_low <- list(
  levels = c("EQ", "GE", "GT", "NO", "NI", "UN", "OT"),
  labels = c("Equal", "Greater than or equal to", "Greater than", "No lower limit",
             "No information", "Unknown", "Other")
)

# $NORM_MODIFIER_HIGH (Source: lines 540-547)
sas_formats$norm_modifier_high <- list(
  levels = c("EQ", "LE", "LT", "NO", "NI", "UN", "OT"),
  labels = c("Equal", "Less than or equal to", "Less than", "No lower limit",
             "No information", "Unknown", "Other")
)

# $ABN_IND (Source: lines 549-560)
sas_formats$abn_ind <- list(
  levels = c("AB", "AH", "AL", "CH", "CL", "CR", "IN", "NL", "NI", "UN", "OT"),
  labels = c("Abnormal", "Abnormally high", "Abnormally low", "Critically high",
             "Critically low", "Critical", "Inconclusive", "Normal",
             "No information", "Unknown", "Other")
)

# $DX_TYPE (Source: lines 562-569)
sas_formats$dx_type <- list(
  levels = c("09", "10", "11", "SM", "NI", "UN", "OT"),
  labels = c("ICD-9-CM", "ICD-10-CM", "ICD-11-CM", "SNOMED CT",
             "No information", "Unknown", "Other")
)

# $DX_SOURCE (Source: lines 572-580)
sas_formats$dx_source <- list(
  levels = c("AD", "DI", "FI", "IN", "NI", "UN", "OT"),
  labels = c("Admitting", "Discharge", "Final", "Interim", "No information", "Unknown", "Other")
)

# $DX_ORIGIN (Source: lines 582-590)
sas_formats$dx_origin <- list(
  levels = c("OD", "BI", "CL", "DR", "NI", "UN", "OT"),
  labels = c("Order/EHR", "Billing", "Claim", "Derived", "No information", "Unknown", "Other")
)

# $PDX (Source: lines 592-598)
sas_formats$pdx <- list(
  levels = c("P", "S", "NI", "UN", "OT"),
  labels = c("Principle", "Secondary", "No information", "Unknown", "Other")
)

# $DX_POA (Source: lines 601-609)
sas_formats$dx_poa <- list(
  levels = c("Y", "DI", "FI", "IN", "NI", "UN", "OT"),
  labels = c("Diagnosis present", "Discharge", "Final", "Interim",
             "No information", "Unknown", "Other")
)

# $PX_TYPE (Source: lines 611-622)
sas_formats$px_type <- list(
  levels = c("09", "10", "11", "CH", "LC", "ND", "RE", "NI", "UN", "OT"),
  labels = c("ICD-9-CM", "ICS-10-PCS", "ICD-11-PCS", "CPT or HCPCS", "LOINC",
             "NDC", "Revenue", "No information", "Unknown", "Other")
)

# $PX_SOURCE (Source: lines 624-631)
sas_formats$px_source <- list(
  levels = c("OD", "BI", "CL", "DR", "NI", "UN", "OT"),
  labels = c("Order/EHR", "Billing", "Claim", "Derived", "No information", "Unknown", "Other")
)

# $PPX (Source: lines 633-638)
sas_formats$ppx <- list(
  levels = c("P", "S", "NI", "UN", "OT"),
  labels = c("Principal", "Secondary", "No information", "Unknown", "Other")
)

# $VITAL_SOURCE (Source: lines 640-648)
sas_formats$vital_source <- list(
  levels = c("PR", "PD", "HC", "HD", "DR", "NI", "UN", "OT"),
  labels = c("Patient-reported", "Patient device direct feed",
             "Healthcare delivery setting", "Healthcare device direct feed",
             "Derived", "No information", "Unknown", "Other")
)

# $BP_POSITION (Source: lines 650-656)
sas_formats$bp_position <- list(
  levels = c("01", "02", "03", "NI", "UN", "OT"),
  labels = c("Sitting", "Standing", "Supine", "No information", "Unknown", "Other")
)

# $SMOKING (Source: lines 658-669)
sas_formats$smoking <- list(
  levels = c("01", "02", "03", "04", "05", "06", "07", "08", "NI", "UN", "OT"),
  labels = c("Current every day smoker", "Current some day smoker", "Former smoker",
             "Never smoker", "Smoker, current status unknown", "Unknown if ever smoked",
             "Heavy tobacco smoker", "Light tobacco smoker", "No information", "Unknown", "Other")
)

# $TOBACCO (Source: lines 671-679)
sas_formats$tobacco <- list(
  levels = c("01", "02", "03", "04", "06", "NI", "UN", "OT"),
  labels = c("Current user", "Never", "Quit/former user", "Passive or environmental exposure",
             "Not asked", "No information", "Unknown", "Other")
)

# $TOBACCO_TYPE (Source: lines 681-689)
sas_formats$tobacco_type <- list(
  levels = c("01", "02", "03", "04", "05", "NI", "UN", "OT"),
  labels = c("Smoked tobacco only", "Non-smoked tobacco only",
             "Use of both smoked and nonsmoked tobacco products", "None",
             "Use of smoked tobacco but no information about nonsmoked tobacco use",
             "No information", "Unknown", "Other")
)

# ==============================================================================
# $payer family (Duplicate resolution required)
# ==============================================================================
# FORENSIC DECISION (D-02): $payer has 4 definitions in Formats.sas
# (lines 693, 955, 1899, 2161). Per SAS overwrite semantics, last definition wins.
# Using line 2161 definition (Block 4, definitive).
# Diff summary: All 4 blocks are IDENTICAL - no substantive differences found.
# Verified against V5 downstream usage: SAS_CODE_FOR_V5_18.sas applies format $payer.
# via %include macro to encounters.payer field.

# $payer (Source: lines 2161-2327, Block 4 - DEFINITIVE)
# Complete insurance taxonomy from PCORnet/PHDSC
sas_formats$payer <- list(
  levels = c("7", "1", "11", "111", "112", "113", "119", "12", "121", "122",
             "123", "129", "13", "14", "19", "191", "2", "21", "211", "212",
             "213", "219", "22", "23", "24", "25", "26", "29", "291", "299",
             "3", "31", "311", "3111", "3112", "3113", "3114", "3115", "3116",
             "3119", "312", "3121", "3122", "3123", "313", "32", "321", "3211",
             "3212", "32121", "32122", "32123", "32124", "32125", "32126", "32127",
             "32128", "322", "3221", "3222", "3223", "3229", "33", "331", "332",
             "333", "334", "34", "341", "342", "343", "349", "35", "36", "361",
             "362", "369", "37", "371", "3711", "3712", "3713", "372", "379",
             "38", "381", "3811", "3812", "3813", "3819", "382", "389", "39",
             "391", "4", "41", "42", "43", "44", "5", "51", "511", "512", "513",
             "514", "515", "516", "517", "519", "52", "521", "522", "523", "524",
             "529", "53", "54", "55", "56", "561", "562", "6", "61", "611", "612",
             "613", "614", "619", "62", "621", "622", "623", "629", "71", "72",
             "73", "79", "8", "81", "82", "821", "822", "823", "83", "84", "85",
             "89", "9", "91", "92", "93", "94", "95", "951", "953", "954", "959",
             "96", "97", "98", "99", "9999", "NI", "UN", "OT"),
  labels = c(
    "7=MANAGED  CARE,  UNSPECIFIED  (to  be  used  only  if  one  can't  distinguish  public  from  private)",
    "1=MEDICARE", "11=Medicare  (Managed  Care)", "111=Medicare  HMO",
    "112=Medicare  PPO", "113=Medicare  POS", "119=Medicare  Managed  Care  Other",
    "12=Medicare  (Non-managed  Care)", "121=Medicare  FFS", "122=Medicare  Drug  Benefit",
    "123=Medicare  Medical  Savings  Account  (MSA)", "129=Medicare  Non-managed  Care  Other",
    "13=Medicare  Hospice", "14=Dual  Eligibility  Medicare/Medicaid  Organization",
    "19=Medicare  Other", "191=Medicare  Pharmacy  Benefit  Manager", "2=MEDICAID",
    "21=Medicaid  (Managed  Care)", "211=Medicaid  HMO", "212=Medicaid  PPO",
    "213=Medicaid  PCCM  (Primary  Care  Case  Management)", "219=Medicaid  Managed  Care  Other",
    "22=Medicaid  (Non-managed  Care  Plan)", "23=Medicaid/SCHIP", "24=Medicaid  Applicant",
    "25=Medicaid  -  Out  of  State", "26=Medicaid    Long  Term  Care", "29=Medicaid  Other",
    "291=Medicaid  Pharmacy  Benefit  Manager", "299=Medicaid  -  Dental",
    "3=OTHER  GOVERNMENT  (Federal/State/Local)  (excluding  Department  of  Corrections)",
    "31=Department  of  Defense", "311=TRICARE  (CHAMPUS)", "3111=TRICARE  PrimeHMO",
    "3112=TRICARE  ExtraPPO", "3113=TRICARE  Standard  -  Fee  For  Service",
    "3114=TRICARE  For  Life--Medicare  Supplement", "3115=TRICARE  Reserve  Select",
    "3116=Uniformed  Services  Family  Health  Plan  (USFHP)  --  HMO",
    "3119=Department  of  Defense  -  (other)", "312=Military  Treatment  Facility",
    "3121=Enrolled  PrimeHMO", "3122=Non-enrolled  Space  Available", "3123=TRICARE  For  Life  (TFL)",
    "313=Dental  --Stand  Alone", "32=Department  of  Veterans  Affairs", "321=Veteran  care--Care  provided  to  Veterans",
    "3211=Direct  Care--Care  provided  in  VA  facilities", "3212=Indirect  Care--Care  provided  outside  VA  facilities",
    "32121=Fee  Basis", "32122=Foreign  Fee/Foreign  Medical  Program  (FMP)",
    "32123=Contract  Nursing  Home/Community  Nursing  Home", "32124=State  Veterans  Home",
    "32125=Sharing  Agreements", "32126=Other  Federal  Agency", "32127=Dental  Care",
    "32128=Vision  Care", "322=Non-veteran  care", "3221=Civilian  Health  and  Medical  Program  for  the  VA  (CHAMPVA)",
    "3222=Spina  Bifida  Health  Care  Program  (SB)", "3223=Children  of  Women  Vietnam  Veterans  (CWVV)",
    "3229=Other  non-veteran  care", "33=Indian  Health  Service  or  Tribe", "331=Indian  Health  Service    Regular",
    "332=Indian  Health  Service    Contract", "333=Indian  Health  Service  -  Managed  Care",
    "334=Indian  Tribe  -  Sponsored  Coverage", "34=HRSA  Program", "341=Title  V  (MCH  Block  Grant)",
    "342=Migrant  Health  Program", "343=Ryan  White  Act", "349=Other", "35=Black  Lung",
    "36=State  Government", "361=State  SCHIP  program  (codes  for  individual  states)",
    "362=Specific  state  programs  (list/  local  code)", "369=State,  not  otherwise  specified  (other  state)",
    "37=Local  Government", "371=Local  -  Managed  care", "3711=HMO", "3712=PPO", "3713=POS",
    "372=FFS/Indemnity", "379=Local,  not  otherwise  specified  (other  local,  county)",
    "38=Other  Government  (Federal,  State,  Local  not  specified)", "381=Federal,  State,  Local  not  specified  managed  care",
    "3811=Federal,  State,  Local  not  specified  -  HMO", "3812=Federal,  State,  Local  not  specified  -  PPO",
    "3813=Federal,  State,  Local  not  specified  -  POS", "3819=Federal,  State,  Local  not  specified  -  not  specified  managed  care",
    "382=Federal,  State,  Local  not  specified  -  FFS", "389=Federal,  State,  Local  not  specified  -  Other",
    "39=Other  Federal", "391=Federal  Employee  Health  Plan    Use  when  known.", "4=DEPARTMENTS  OF  CORRECTIONS",
    "41=Corrections  Federal", "42=Corrections  State", "43=Corrections  Local", "44=Corrections  Unknown  Level",
    "5=PRIVATE  HEALTH  INSURANCE", "51=Managed  Care  (Private)", "511=Commercial  Managed  Care  -  HMO",
    "512=Commercial  Managed  Care  -  PPO", "513=Commercial  Managed  Care  -  POS", "514=Exclusive  Provider  Organization",
    "515=Gatekeeper  PPO  (GPPO)", "516=Commercial  Managed  Care  -  Pharmacy  Benefit  Manager",
    "517=Commercial  Managed  Care  -  Dental", "519=Managed  Care,  Other  (non  HMO)",
    "52=Private  Health  Insurance  -  Indemnity", "521=Commercial  Indemnity",
    "522=Self-insured  (ERISA)  Administrative  Services  Only  (ASO)  plan",
    "523=Medicare  supplemental  policy  (as  second  payer)", "524=Indemnity  Insurance  -  Dental",
    "529=Private  health  insuranceother  commercial  Indemnity",
    "53=Managed  Care  (private)  or  private  health  insurance  (indemnity),  not  otherwise  specified",
    "54=Organized  Delivery  System", "55=Small  Employer  Purchasing  Group", "56=Specialized  Stand  Alone  Plan",
    "561=Dental", "562=Vision  Other  Private  Insurance", "6=BLUE  CROSS/BLUE  SHIELD", "61=BC  Managed  Care",
    "611=BC  Managed  Care    HMO", "612=BC  Managed  Care    PPO", "613=BC  Managed  Care    POS",
    "614=BC  Managed  Care  -  Dental", "619=BC  Managed  Care    Other", "62=BC  Insurance  Indemnity",
    "621=BC  Indemnity", "622=BC  Self-insured  (ERISA)  Administrative  Services  Only  (ASO)Plan",
    "623=BC  Medicare  Supplemental  Plan", "629=BC  Indemnity  -  Dental", "71=HMO", "72=PPO", "73=POS",
    "79=Other  Managed  Care", "8=NO  PAYMENT  from  an  Organization/Agency/Program/Private  Payer  Listed",
    "81=Self-pay", "82=No  Charge", "821=Charity", "822=Professional  Courtesy", "823=Research/Clinical  Trial",
    "83=Refusal  to  Pay/Bad  Debt", "84=Hill  Burton  Free  Care", "85=Research/Donor", "89=No  Payment,  Other",
    "9=MISCELLANEOUS/OTHER", "91=Foreign  National", "92=Other  (Non-government)", "93=Disability  Insurance",
    "94=Long-term  Care  Insurance", "95=Worker's  Compensation", "951=Worker's  Comp  HMO",
    "953=Worker's  Comp  Fee-for-Service", "954=Workers  Comp  Other  Managed  Care",
    "959=Worker's  Comp,  Other  unspecified", "96=Auto  Insurance  (includes  no  fault)",
    "97=Legal  Liability  /  Liability  Insurance",
    "98=Other  specified  but  not  otherwise  classifiable  (includes  Hospice  -  Unspecified  plan)",
    "99=No  Typology  Code  available  for  payment  source", "UN=Unknown", "UN=Unknown", "UN=Unknown", "OT=Other"
  )
)

# $payerr (Source: lines 2330-2339)
# Collapsed payer categories for analysis
sas_formats$payerr <- list(
  levels = c("5", "1", "2", "3", "4", "8", "9", "U"),
  labels = c("Private", "Medicare", "Medicaid", "Goverment", "Med_Medicaid",
             "None", "Other", "Unknown")
)

# $payerrr (Source: lines 2342-2351)
# Public vs not-public payer classification
sas_formats$payerrr <- list(
  levels = c("5", "1", "2", "3", "4", "8", "9", "U"),
  labels = c("Not_public", "Not_public", "Public", "Public", "Public",
             "Uninsured", "Public", "Uninsured")
)

# ==============================================================================
# Numeric Formats (no $ prefix)
# ==============================================================================
# Source: Formats.sas Block 4 (definitive), lines 2354-2410

# age (Source: lines 2355-2356)
sas_formats$age <- list(
  levels = c(1, 2, 3, 4),
  labels = c("AgeLessThan15yrs", "Age15To40yrs", "Age40To65yrs", "Age65yrsAndAbove")
)

# ruca (Source: lines 2357-2378)
# Detailed RUCA (Rural-Urban Commuting Area) codes
# Note: SAS uses numeric + decimal codes (1, 1.1, 2, 2.1, etc.)
sas_formats$ruca <- list(
  levels = c(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 99, 1.1, 2.1, 4.1, 5.1, 7.1, 7.2, 8.1, 8.2, 10.1, 10.2, 10.3),
  labels = c(
    "Metropolitan area core: primary flow within an urbanized area (UA)",
    "Metropolitan area high commuting: primary flow 30% or more to a UA",
    "Metropolitan area low commuting: primary flow 10% to 30% to a UA",
    "Micropolitan area core: primary flow within an Urban Cluster of 10,000 to 49,999 (large UC)",
    "Micropolitan high commuting: primary flow 30% or more to a large UC",
    "Micropolitan low commuting: primary flow 10% to 30% to a large UC",
    "Small town core: primary flow within an Urban Cluster of 2,500 to 9,999 (small UC)",
    "Small town high commuting: primary flow 30% or more to a small UC",
    "Small town low commuting: primary flow 10% to 30% to a small UC",
    "Rural areas: primary flow to a tract outside a UA or UC",
    "Not coded: Census tract has zero population and no rural-urban identifier information",
    "Metropolitan area core: Secondary flow 30% to 50% to a larger UA",
    "Metropolitan area high commuting: Secondary flow 30% to 50% to a larger UA",
    "Micropolitan area core: Secondary flow 30% to 50% to a UA",
    "Micropolitan high commuting: Secondary flow 30% to 50% to a UA",
    "Small town core: Secondary flow 30% to 50% to a UA",
    "Small town core: Secondary flow 30% to 50% to a large UC",
    "Small town high commuting: Secondary flow 30% to 50% to a UA",
    "Small town high commuting: Secondary flow 30% to 50% to a large UC",
    "Rural areas: Secondary flow 30% to 50% to a UA",
    "Rural areas: Secondary flow 30% to 50% to a large UC",
    "Rural areas: Secondary flow 30% to 50% to a small UC"
  )
)

# ruca_broad (Source: lines 2379-2401)
# Collapsed RUCA categories
sas_formats$ruca_broad <- list(
  levels = c(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 99, 1.1, 2.1, 4.1, 5.1, 7.1, 7.2, 8.1, 8.2, 10.1, 10.2, 10.3),
  labels = c(
    "Metropolitan", "Metropolitan", "Metropolitan", "Micropolitan", "Micropolitan",
    "Micropolitan", "Small town", "Small town", "Small town", "Rural areas", "Unknown",
    "Metropolitan", "Metropolitan", "Micropolitan", "Micropolitan", "Small town",
    "Small town", "Small town", "Small town", "Rural areas", "Rural areas", "Rural areas"
  )
)

# yn (Source: line 2405)
sas_formats$yn <- list(
  levels = c(1, 0),
  labels = c("Yes", "No")
)

# ruca_2cat (Source: line 2406)
sas_formats$ruca_2cat <- list(
  levels = c(0, 1),
  labels = c("Metropolitan", "Not Metropolitan")
)

# sdi (Source: line 2407)
# Social Deprivation Index quartiles
sas_formats$sdi <- list(
  levels = c(1, 2, 3, 4),
  labels = c("SDI_1stQ_0_36", "SDI_2ndQ_37_59", "SDI_3rdQ_60_80", "SDI_4thQ_81_100")
)

# sdi_tertile_base (Source: line 2408)
# SDI tertiles (baseline)
sas_formats$sdi_tertile_base <- list(
  levels = c(1, 2, 3),
  labels = c("SDI_1stT_0_45", "SDI_2ndT_46_73", "SDI_3rdT_74_100")
)

# NOTE: sdi_tertile_gr1age is commented out in final Formats.sas block (line 2409)
# Was active in earlier blocks (line 940, 1202). Superseded by sdi_tertile_gr1_4age.
# Do NOT include in sas_formats.

# sdi_tertile_gr1_4age (Source: line 2410)
# SDI tertiles for specific age group analysis
sas_formats$sdi_tertile_gr1_4age <- list(
  levels = c(1, 2, 3),
  labels = c("SDI_1stT_0_50", "SDI_2ndT_51_76", "SDI_3rdT_77_100")
)

# ==============================================================================
# Study-Specific Formats (Unique, lines 2414-2495)
# ==============================================================================

# $p (Source: lines 2415-2424)
# Grouped payer: study-specific insurance classification
# Maps detailed payer codes to analysis categories
sas_formats$p_payer <- list(
  levels = c("5", "1", "2", "3", "4", "8", "9", "U"),
  labels = c("Private", "Medicare", "Medicaid", "Private", "Med_Medicaid",
             "Uninsured", "Other", "Unknown")
)

# $r (Source: lines 2427-2438)
# Collapsed race: study-specific race grouping
# NOTE: Multiple original race codes map to "Asian and Other"
sas_formats$r_race <- list(
  levels = c("01", "02", "03", "04", "05", "06", "07", "NI", "UN", "OT"),
  labels = c("Asian and Other", "Asian and Other", "Black or African American",
             "Asian and Other", "White", "Asian and Other", "Unknown",
             "Unknown", "Unknown", "Asian and Other")
)

# $treament (Source: lines 2442-2451)
# Treatment modality classification
# NOTE: SAS source has typo "$treament" - R uses corrected "treatment"
sas_formats$treatment <- list(
  levels = c("0", "1", "2", "3", "4", "5", "6", "7", "8"),
  labels = c("None", "Surgery only", "Chemotherapy only", "Radiation only",
             "Surgery and chemotherapy", "Surgery and radiation",
             "Radiation and chemotherapy", "Surgery, radiation, and chemotherapy",
             "An SCT")
)

# $gsite (Source: lines 2457-2470)
# Cancer site groups for analysis
# NOTE: "Urinary", "Female Genital System", "Male Genital System" all map to "Genitourinary"
sas_formats$gsite <- list(
  levels = c("Bones, joints, soft tissue", "Breast", "Digestive",
             "Eye, brain, CNS, endocrine", "Hematologic", "Oral, respiratory",
             "Skin", "Urinary", "Female Genital System", "Male Genital System",
             "Reportable but not mapped above", "Other", "In situ"),
  labels = c("Bones, joints, soft tissue", "Breast", "Digestive",
             "Eye, brain, CNS, endocrine", "Hematologic", "Oral, respiratory",
             "Skin", "Genitourinary", "Genitourinary", "Genitourinary",
             "Other", "Other", "Other")
)

# sdif (Source: line 2474)
# SDI tertiles from continuous score (range-based format)
# SAS value sdif 0-45='...' 46-73='...' 74-100='...'
# Translate as function for use in mutate()
sas_formats$sdif <- list(
  breaks = c(-Inf, 45, 73, Inf),
  labels = c("SDI_1stT_0_45", "SDI_2ndT_46_73", "SDI_3rdT_74_100"),
  type = "range",
  apply = function(x) {
    cut(x, breaks = c(-Inf, 45, 73, Inf),
        labels = c("SDI_1stT_0_45", "SDI_2ndT_46_73", "SDI_3rdT_74_100"),
        right = TRUE, include.lowest = TRUE)
  }
)

# int (Source: lines 2480-2489)
# Treatment intensity classification (numeric codes 0-8)
sas_formats$intensity <- list(
  levels = c(0, 1, 2, 3, 4, 5, 6, 7, 8),
  labels = c("None", "Surgery only", "Chemotherapy only", "Radiation only",
             "Surgery and chemotherapy", "Surgery and radiation",
             "Radiation and chemotherapy", "Surgery, radiation, and chemotherapy",
             "sct")
)

# agef (Source: lines 2494-2495)
# Age groups for analysis
sas_formats$agef <- list(
  levels = c(1, 2, 3, 4, 5),
  labels = c("0-14", "15-39", "40-54", "55-64", "65-91")
)

# ==============================================================================
# Save format definitions for use by downstream scripts (per D-08)
# ==============================================================================
saveRDS(sas_formats, file.path(data_dir_processed, "01_formats.rds"))

# Report
message("Format translation complete:")
message("  Total formats: ", length(sas_formats))
message("  PCORnet CDM standard: ~55 formats")
message("  Study-specific: ~10 formats")
message("  Duplicate blocks resolved: $payer (4x), $payerr (4x), $payerrr (4x)")
message("  Saved to: ", file.path(data_dir_processed, "01_formats.rds"))
