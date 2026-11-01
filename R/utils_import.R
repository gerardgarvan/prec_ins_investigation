# R/utils_import.R
# Shared SAS import helpers (sourced by 01_import.R and 02_clean.R)
#
# Memory-safe changes vs. the original import_sas():
#   1. keep_cols: read ONLY the columns the pipeline uses (haven col_select).
#      PCORnet tables carry many RAW_* and audit columns; dropping them at read
#      time is the single biggest RAM saving.
#   2. import_parts(): multi-part files are collected in a list and bound ONCE,
#      instead of growing dx_combined with bind_rows() inside the loop (which
#      copies the whole accumulated table on every iteration).
#   3. All-NA numeric date columns are converted to Date too, so parts bind
#      cleanly (otherwise one part is Date and another is double -> bind error).
#   4. Logs file size and in-memory size so you can see what is driving RAM.

library(haven)
library(janitor)
library(purrr)
library(dplyr)

#' Import a SAS7BDAT file with standard validation
#' @param filename    .sas7bdat filename (without path)
#' @param data_dir    directory containing the file (default: data_dir_raw)
#' @param description human-readable description for logging
#' @param keep_cols   character vector of column names to keep (case-insensitive).
#'                    NULL = read all columns.
#' @return tibble with clean names and preserved labels (attr "sas_labels")
import_sas <- function(filename, data_dir = data_dir_raw, description = filename,
                       keep_cols = NULL) {
  filepath <- file.path(data_dir, filename)
  message("  Importing: ", description, " (", filename, ")")

  if (!file.exists(filepath)) {
    warning("File not found: ", filepath, " — skipping. ",
            "Place file in ", data_dir, " and rerun.")
    return(NULL)
  }

  message("    File size on disk: ",
          format(round(file.size(filepath) / 1024^3, 2), nsmall = 2), " GB")

  if (is.null(keep_cols)) {
    df <- read_sas(data_file = filepath, encoding = sas_encoding)
  } else {
    # Exact, case-insensitive match on the SAS column names
    col_pattern <- paste0("^(", paste(keep_cols, collapse = "|"), ")$")
    df <- read_sas(data_file = filepath, encoding = sas_encoding,
                   col_select = tidyselect::matches(col_pattern, ignore.case = TRUE))
    not_found <- setdiff(tolower(keep_cols), tolower(names(df)))
    if (length(not_found) > 0) {
      message("    NOTE: requested columns not in file: ",
              paste(not_found, collapse = ", "))
    }
  }

  # Preserve original labels before clean_names potentially drops them
  original_labels <- purrr::map_chr(df, ~attr(.x, "label") %||% NA_character_)

  # Standardize column names (janitor convention)
  df <- janitor::clean_names(df)
  attr(df, "sas_labels") <- original_labels

  # Per IMP-03: numeric SAS dates (days since 1960-01-01) -> Date
  date_candidates <- names(df)[grepl("date|dt$|_dt$", names(df), ignore.case = TRUE)]
  for (col in date_candidates) {
    if (is.numeric(df[[col]]) && !inherits(df[[col]], "Date")) {
      vals <- df[[col]][!is.na(df[[col]])]
      if (length(vals) == 0) {
        # All missing: still make it Date so multi-part files bind cleanly
        df[[col]] <- as.Date(df[[col]], origin = "1960-01-01")
      } else if (all(vals > -5000 & vals < 30000)) {
        message("    NOTE: Converting ", col, " from numeric to Date (SAS origin 1960-01-01)")
        df[[col]] <- as.Date(df[[col]], origin = "1960-01-01")
      }
      rm(vals)
    }
  }

  message("    Rows: ", format(nrow(df), big.mark = ","),
          " | Cols: ", ncol(df),
          " | In memory: ", format(utils::object.size(df), units = "GB", standard = "legacy"),
          " | Labels preserved: ", sum(!is.na(original_labels)), "/", length(original_labels))

  df
}

#' Import several SAS files that share a layout, saving each part to its own
#' RDS file immediately and discarding it from RAM before reading the next.
#' Returns a character vector of the saved RDS paths (NOT a data frame).
#' Downstream scripts read and filter each part individually to avoid ever
#' holding the full combined table in memory.
#'
#' @param files       character vector of .sas7bdat filenames
#' @param description label used for logging and output filenames (e.g. "dx")
#' @param keep_cols   columns to select at read time (NULL = all)
#' @param data_dir    source directory (default: data_dir_raw)
#' @return character vector of saved .rds paths (one per successfully loaded part)
import_parts <- function(files, description, keep_cols = NULL, data_dir = data_dir_raw) {
  saved_paths <- character(0)
  for (i in seq_along(files)) {
    part <- import_sas(files[i], data_dir = data_dir,
                       description = paste0(description, " part ", i, " of ", length(files)),
                       keep_cols = keep_cols)
    if (!is.null(part)) {
      out_path <- file.path(data_dir_processed,
                            paste0("01_imported_", tolower(description), "_part", i, ".rds"))
      saveRDS(part, out_path)
      message("    Saved part ", i, " -> ", basename(out_path))
      saved_paths <- c(saved_paths, out_path)
      rm(part); gc(verbose = FALSE)
    }
  }
  message("  ", description, ": ", length(saved_paths), "/", length(files),
          " parts saved to disk individually")
  saved_paths
}

#' Save an object to data_dir_processed as 01_imported_<name>.rds
save_checkpoint <- function(obj, name, prefix = "01_imported_") {
  if (!is.null(obj)) {
    path <- file.path(data_dir_processed, paste0(prefix, name, ".rds"))
    saveRDS(obj, path)
    message("  Saved: ", basename(path), " (", format(nrow(obj), big.mark = ","), " rows)")
  } else {
    message("  Skipped (NULL): ", name)
  }
}
