# tests/testthat/test_prov_spec.R
# Unit tests for cancer_provider assignment logic from prov_spec join
# Tests replicate 02_merge.R Section 7b logic as a local function (offline, no xlsx).
# Mock prov_spec: 3 rows covering a known cancer code, a non-cancer code, and an extra.

library(testthat)
library(dplyr)
library(stringr)
library(tidyr)

# ---- Local helper: replicates 02_merge.R Section 7b join + fill logic ----
assign_cancer_provider <- function(provider_specialty_primary_vec, prov_spec_df) {
  # Normalize input (same as 02_merge.R): str_trim + toupper
  key_vec <- str_trim(toupper(provider_specialty_primary_vec))
  # Build a tibble to left_join
  input_tbl <- tibble(
    provider_specialty_primary_key = key_vec,
    row_id = seq_along(key_vec)
  )
  result <- input_tbl %>%
    left_join(
      prov_spec_df %>% rename(provider_specialty_primary_key = provider_specialty_primary),
      by = "provider_specialty_primary_key"
    ) %>%
    mutate(cancer_provider = replace_na(cancer_provider, 0L)) %>%
    arrange(row_id) %>%
    pull(cancer_provider)
  result
}

# ---- Mock prov_spec fixture ----
# Reflects the normalized form stored in 01_imported_prov_spec.rds:
#   provider_specialty_primary: character (upper, trimmed)
#   cancer_provider: integer 0 or 1
mock_prov_spec <- tibble::tibble(
  provider_specialty_primary = c("207RX0202X", "207R00000X", "207RC0000X"),
  cancer_provider            = c(1L,           0L,           0L)
)

# ---- Tests ----

test_that("known cancer specialty code 207RX0202X -> 1", {
  result <- assign_cancer_provider("207RX0202X", mock_prov_spec)
  expect_equal(result, 1L)
})

test_that("non-cancer code 207R00000X -> 0", {
  result <- assign_cancer_provider("207R00000X", mock_prov_spec)
  expect_equal(result, 0L)
})

test_that("NA specialty -> 0 (missing join filled to 0)", {
  result <- assign_cancer_provider(NA_character_, mock_prov_spec)
  expect_equal(result, 0L)
})

test_that("unknown code not in prov_spec -> 0", {
  result <- assign_cancer_provider("XXXXXXXXXX", mock_prov_spec)
  expect_equal(result, 0L)
})

test_that("lowercase variant matches after toupper (207rx0202x -> 1)", {
  result <- assign_cancer_provider("207rx0202x", mock_prov_spec)
  expect_equal(result, 1L)
})

test_that("whitespace variant matches after str_trim ('  207RX0202X  ' -> 1)", {
  result <- assign_cancer_provider("  207RX0202X  ", mock_prov_spec)
  expect_equal(result, 1L)
})

test_that("all results in c(0L, 1L) with no NA for a mixed vector", {
  mixed_vec <- c("207RX0202X", "207R00000X", NA_character_, "UNKNOWN", "207rx0202x", "  207RX0202X  ", "207RC0000X")
  result <- assign_cancer_provider(mixed_vec, mock_prov_spec)
  expect_true(all(result %in% c(0L, 1L)))
  expect_false(any(is.na(result)))
  # Check expected values for each element
  expect_equal(result, c(1L, 0L, 0L, 0L, 1L, 1L, 0L))
})
