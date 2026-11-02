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
# run_preflight(manifest_path, raw_dir, dx_dirs, report_dir, write_reports)
#
# Manifest-driven preflight checker. Reads file_manifest.csv and probes each
# SAS file via check_file_ci() and read_header_cols(). Returns a data.frame
# with one row per (file, candidate-directory) combination. Attaches overall
# result as attr(result, "overall"): PASS / FAIL / INCOMPLETE.
#
# Defaults use NULL and are resolved from config.R values inside the body
# (R cannot reference top-level variables in function signature defaults).
# ============================================================================
run_preflight <- function(
  manifest_path = NULL,
  raw_dir       = NULL,
  dx_dirs       = NULL,
  report_dir    = NULL,
  write_reports = TRUE
) {
  # Resolve NULL defaults from config.R globals
  if (is.null(manifest_path)) manifest_path <- here::here("docs", "file_manifest.csv")
  if (is.null(raw_dir))       raw_dir       <- data_dir_raw
  if (is.null(dx_dirs))       dx_dirs       <- c(
    data_dir_raw,
    file.path(data_dir_raw, "Dx"),
    "/blue/erin.mobley-precision/ResVault/f/Dx",
    "/orange/erin.mobley-precision/f/Dx"
  )
  if (is.null(report_dir))    report_dir    <- output_dir

  # Load manifest
  manifest <- read.csv(manifest_path, stringsAsFactors = FALSE)

  # Filter to rows with a concrete sas_filename (skip GROUP C summary rows)
  manifest <- manifest[!is.na(manifest$sas_filename) & nchar(manifest$sas_filename) > 0, ]

  # Build result rows
  rows <- list()

  for (i in seq_len(nrow(manifest))) {
    row <- manifest[i, ]
    # For WARN-tier rows, r_import_name may be NA — fall back to sas_filename
    r_import_name   <- if (!is.na(row$r_import_name) && nchar(row$r_import_name) > 0)
                         row$r_import_name else row$sas_filename
    manifest_status <- row$manifest_status
    exp_cols_raw    <- row$expected_raw_cols

    # Determine candidate directories for this row
    if (!is.na(row$alias) && row$alias == "dx" && length(dx_dirs) > 0) {
      candidate_dirs <- dx_dirs
    } else {
      candidate_dirs <- raw_dir
    }

    for (cdir in candidate_dirs) {
      path_probed <- file.path(cdir, r_import_name)

      if (!dir.exists(cdir)) {
        check_result      <- "INCOMPLETE"
        disk_name_found   <- NA_character_
        missing_cols      <- NA_character_
        row_notes         <- "Directory unreachable"
      } else {
        ci <- check_file_ci(cdir, r_import_name)

        if (!ci$found) {
          check_result    <- if (manifest_status == "missing_in_r") "WARN" else "FAIL"
          disk_name_found <- NA_character_
          missing_cols    <- NA_character_
          row_notes       <- "File not found"
        } else if (ci$disk_name != r_import_name && manifest_status != "missing_in_r") {
          # Case-only mismatch for imported file → FAIL
          check_result    <- "FAIL"
          disk_name_found <- ci$disk_name
          missing_cols    <- NA_character_
          row_notes       <- paste0("Case mismatch: R imports '", r_import_name,
                                    "' but disk has '", ci$disk_name, "'")
        } else {
          # File found; check columns if expected_raw_cols is not ALL/NA
          disk_name_found <- ci$disk_name
          actual_path     <- file.path(cdir, ci$disk_name)

          if (!is.na(exp_cols_raw) && nchar(exp_cols_raw) > 0 && exp_cols_raw != "ALL") {
            expected_cols <- strsplit(exp_cols_raw, "\\|")[[1]]
            actual_cols   <- read_header_cols(actual_path)
            missing       <- setdiff(expected_cols, actual_cols)
            missing_cols  <- if (length(missing) > 0) paste(missing, collapse = "|") else NA_character_

            if (length(missing) > 0) {
              check_result <- if (manifest_status == "missing_in_r") "WARN" else "FAIL"
              row_notes    <- paste0("Missing columns: ", paste(missing, collapse = ", "))
            } else {
              check_result <- "OK"
              row_notes    <- ""
            }
          } else {
            # ALL columns or no expectation — presence confirmed is OK
            missing_cols <- NA_character_
            check_result <- "OK"
            row_notes    <- ""
          }
        }
      }

      rows[[length(rows) + 1L]] <- data.frame(
        table_group          = row$table_group,
        sas_filename         = row$sas_filename,
        path_probed          = path_probed,
        manifest_status      = manifest_status,
        check_result         = check_result,
        disk_name            = disk_name_found,
        r_import_name        = r_import_name,
        expected_cols_missing = missing_cols,
        notes                = row_notes,
        stringsAsFactors     = FALSE
      )
    }
  }

  result_df <- do.call(rbind, rows)

  # Compute overall result
  overall <- if (any(result_df$check_result == "FAIL")) {
    "FAIL"
  } else if (any(result_df$check_result == "INCOMPLETE")) {
    "INCOMPLETE"
  } else {
    "PASS"
  }
  attr(result_df, "overall") <- overall

  # Write reports if requested
  if (write_reports) {
    dir.create(report_dir, recursive = TRUE, showWarnings = FALSE)

    # --- preflight_report.txt ---
    git_hash <- tryCatch(
      system("git rev-parse HEAD", intern = TRUE),
      error = function(e) "unknown"
    )
    txt_lines <- c(
      paste0("# Preflight Report — ", Sys.time()),
      paste0("# Git: ", git_hash),
      "",
      "## File Check Results",
      apply(result_df, 1, function(r) {
        sprintf("[%s] %s — %s", r["check_result"], r["sas_filename"], r["path_probed"])
      }),
      "",
      "=== MUST VERIFY ON HIPERGATOR ===",
      {
        must_verify_rows <- result_df[
          result_df$check_result == "INCOMPLETE" |
          result_df$manifest_status == "must_verify", , drop = FALSE
        ]
        if (nrow(must_verify_rows) > 0) {
          apply(must_verify_rows, 1, function(r) {
            sprintf("  [%s] %s — %s", r["manifest_status"], r["sas_filename"], r["path_probed"])
          })
        } else {
          "  (none)"
        }
      },
      "",
      paste0("OVERALL: ", overall)
    )
    writeLines(txt_lines, file.path(report_dir, "preflight_report.txt"))

    # --- preflight_report.csv ---
    write.csv(result_df, file.path(report_dir, "preflight_report.csv"), row.names = FALSE)
  }

  result_df
}

# ============================================================================
# Main invocation — runs run_preflight() when script is executed directly
# ============================================================================
if (!interactive() && sys.nframe() == 0) run_preflight()
