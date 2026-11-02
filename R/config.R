# R/config.R
# Path configuration for Precision Cancer Survivorship pipeline
# Per D-04: sourced config.R for all path parameterization (no YAML, no .Renviron)
# Per D-05: paths only — study parameters stay in analysis scripts for auditing

# SAS BUG FIX: SAS code uses confusing library aliases (v3 for Data_v5). See note below.

library(here)

# Data directory paths
# Where SAS7BDAT files live
data_dir_raw <- "/orange/erin.mobley-precision/Data_v5"

# Where .rds checkpoints go
data_dir_processed <- "/blue/erin.mobley-precision/ggarvan/data/processed"

# Reference workbooks (committed to repo -- analytical lookup files, not patient data)
reference_dir <- here::here("reference")

# Output directory paths
output_dir <- "/blue/erin.mobley-precision/ggarvan/output"
output_dir_tables <- "/blue/erin.mobley-precision/ggarvan/output/tables"
output_dir_figures <- "/blue/erin.mobley-precision/ggarvan/output/figures"
output_dir_diagnostics <- "/blue/erin.mobley-precision/ggarvan/output/diagnostics"

# SAS encoding parameter (per Research pitfall 6)
# Default for clinical data; change to "UTF-8" if text corruption detected
sas_encoding <- "latin1"

# Directory creation block (data_dir_raw is read-only orange storage — do not create)
dir.create(data_dir_processed, recursive = TRUE, showWarnings = FALSE)
dir.create(output_dir_tables, recursive = TRUE, showWarnings = FALSE)
dir.create(output_dir_figures, recursive = TRUE, showWarnings = FALSE)
dir.create(output_dir_diagnostics, recursive = TRUE, showWarnings = FALSE)
dir.create(reference_dir, recursive = TRUE, showWarnings = FALSE)

# PIPELINE_TEST switch: set env var PIPELINE_TEST=TRUE to point all dirs at
# local test fixtures under tests/testdata/ (no HiPerGator connection required).
# Default FALSE uses the HiPerGator paths above.
if (isTRUE(as.logical(Sys.getenv("PIPELINE_TEST", "FALSE")))) {
  data_dir_raw           <- here::here("tests", "testdata", "raw")
  data_dir_processed     <- here::here("tests", "testdata", "processed")
  output_dir             <- here::here("tests", "testdata", "output")
  output_dir_tables      <- file.path(output_dir, "tables")
  output_dir_figures     <- file.path(output_dir, "figures")
  output_dir_diagnostics <- file.path(output_dir, "diagnostics")
  reference_dir <- here::here("reference")  # same value -- reference/ is repo-local always
  message("PIPELINE_TEST=TRUE — using local test fixtures under tests/testdata/")
  dir.create(data_dir_processed,      recursive = TRUE, showWarnings = FALSE)
  dir.create(output_dir_tables,       recursive = TRUE, showWarnings = FALSE)
  dir.create(output_dir_figures,      recursive = TRUE, showWarnings = FALSE)
  dir.create(output_dir_diagnostics,  recursive = TRUE, showWarnings = FALSE)
  dir.create(reference_dir,           recursive = TRUE, showWarnings = FALSE)
}

# NOTE: SAS library alias confusion (per D-10, Research pitfall 4):
#   SAS "libname v3" alias actually points to Data_v5 directory
#   SAS "libname v4" alias points to Data_v4 directory
#   SAS "libname dx" alias points to Dx directory
#   R config uses clear names: data_dir_raw (= V5 data), no ambiguous aliases

message("Config loaded. Project root: ", here::here())
