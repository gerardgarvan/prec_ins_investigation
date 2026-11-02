# ============================================================================
# R/00_check_inputs.R
# Standalone preflight checker for SAS input files
#
# Purpose: Verify that all required input files are available before
# launching the main pipeline. Does NOT execute the full pipeline — only
# reads headers via haven::read_sas(path, n_max = 0) to extract column names.
#
# Dependencies:
#   - Sources only R/config.R (which sets data directories)
#   - Never sources utils_import.R or calls import_sas()
#   - Uses haven::read_sas() with n_max=0 for header inspection
#
# Output:
#   - Prints file manifest and column inventory to console/log
#   - Writes preflight report to output_dir (Task 3)
# ============================================================================

library(here)
source(here::here("R", "config.R"))
library(haven)

# ============================================================================
# check_file_ci(dir_path, filename)
#
# Case-insensitive file existence checker for SAS files
# Returns a list: list(found = TRUE/FALSE, disk_name = actual_name_or_NA)
# ============================================================================
check_file_ci <- function(dir_path, filename) {
  # If directory doesn't exist, return found=FALSE with NA disk_name
  if (!dir.exists(dir_path)) {
    return(list(found = FALSE, disk_name = NA_character_))
  }

  # List files in directory
  files_in_dir <- list.files(dir_path, full.names = FALSE)

  # Case-insensitive search: match filename ignoring case
  idx <- tolower(files_in_dir) == tolower(filename)

  if (any(idx)) {
    # Found the file (case-insensitively)
    disk_name <- files_in_dir[idx][1]  # Return first match if duplicates
    return(list(found = TRUE, disk_name = disk_name))
  } else {
    # File not found
    return(list(found = FALSE, disk_name = NA_character_))
  }
}

# ============================================================================
# read_header_cols(path)
#
# Extract column names from a SAS7BDAT file by reading headers only.
# Attempts n_max=0 first; if that returns rows (rare edge case),
# falls back to n_max=1 and discards rows, returning only names().
# If read_sas() throws any error, returns character(0).
#
# Args:
#   path: full path to .sas7bdat file
#
# Returns:
#   character vector of column names, or character(0) on read error
# ============================================================================
read_header_cols <- function(path) {
  result <- tryCatch(
    {
      # Try to read with n_max=0 (should return empty data.frame with columns)
      df <- haven::read_sas(path, n_max = 0)

      # Check if we got rows back (edge case)
      if (nrow(df) > 0) {
        message("read_header_cols: n_max=0 returned ", nrow(df), " rows. Falling back to n_max=1.")
        # Fallback: read with n_max=1, but only return names
        df <- haven::read_sas(path, n_max = 1)
      }

      # Return column names
      names(df)
    },
    error = function(e) {
      # If read_sas throws, return empty character vector
      character(0)
    }
  )

  return(result)
}

# ============================================================================
# === PROBE LOOP: implemented in Task 3 ===
# ============================================================================

# ============================================================================
# Main invocation
# Only runs if script is executed directly (not sourced interactively)
# ============================================================================
if (!interactive() && sys.nframe() == 0) {
  message("Probe loop not yet implemented.")
}
