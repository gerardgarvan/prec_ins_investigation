# R/config.R
# Path configuration for Precision Cancer Survivorship pipeline
# Per D-04: sourced config.R for all path parameterization (no YAML, no .Renviron)
# Per D-05: paths only — study parameters stay in analysis scripts for auditing

# SAS BUG FIX: SAS code uses confusing library aliases (v3 for Data_v5). See note below.

# Project root — hardcoded for HiPerGator reliability
project_root <- "/home/ggarvan/prec_ins_investigation"

# Data directory paths
# Where SAS7BDAT files live
data_dir_raw <- file.path(project_root, "data", "raw")

# Where .rds checkpoints go
data_dir_processed <- file.path(project_root, "data", "processed")

# Output directory paths
output_dir <- file.path(project_root, "output")
output_dir_tables <- file.path(project_root, "output", "tables")
output_dir_figures <- file.path(project_root, "output", "figures")

# SAS encoding parameter (per Research pitfall 6)
# Default for clinical data; change to "UTF-8" if text corruption detected
sas_encoding <- "latin1"

# Directory creation block
dir.create(data_dir_raw, recursive = TRUE, showWarnings = FALSE)
dir.create(data_dir_processed, recursive = TRUE, showWarnings = FALSE)
dir.create(output_dir_tables, recursive = TRUE, showWarnings = FALSE)
dir.create(output_dir_figures, recursive = TRUE, showWarnings = FALSE)

# NOTE: SAS library alias confusion (per D-10, Research pitfall 4):
#   SAS "libname v3" alias actually points to Data_v5 directory
#   SAS "libname v4" alias points to Data_v4 directory
#   SAS "libname dx" alias points to Dx directory
#   R config uses clear names: data_dir_raw (= V5 data), no ambiguous aliases

message("Config loaded. Project root: ", project_root)
