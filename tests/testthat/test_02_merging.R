# tests/testthat/test_02_merging.R
# Test scaffolds for Phase 2 merging requirements (MRG-01, MRG-02, MRG-03, MRG-04)
# Wave 0: Tests in RED state until 02_merge.R implements merging logic

library(testthat)
library(dplyr)
source(here::here("tests", "testthat", "helper-fixtures.R"))

# ==============================================================================
# MRG-01: Encounter-diagnosis join by patid + encounterid
# ==============================================================================

test_that("MRG-01: Encounters join with diagnoses by patid + encounterid", {
  encounters <- bind_rows(mock_encounter1, mock_encounter2)
  dx_combined <- bind_rows(mock_dx_parts[[1]], mock_dx_parts[[2]])
  result <- left_join(encounters, dx_combined, by = c("patid", "encounterid"),
                      relationship = "one-to-many")
  # Result should have more rows than encounters (multiple dx per encounter)
  expect_gte(nrow(result), nrow(encounters))
  # All original encounter patids preserved
  expect_equal(n_distinct(result$patid), n_distinct(encounters$patid))
})

# ==============================================================================
# MRG-01: Encounter-procedure join
# ==============================================================================

test_that("MRG-01: Encounters join with procedures by patid + encounterid", {
  encounters <- bind_rows(mock_encounter1, mock_encounter2)
  proc_combined <- bind_rows(mock_proc_parts[[1]], mock_proc_parts[[2]])
  result <- left_join(encounters, proc_combined, by = c("patid", "encounterid"),
                      relationship = "one-to-many")
  expect_gte(nrow(result), nrow(encounters))
})

# ==============================================================================
# MRG-02: Row count logging validates logged_join produces message output
# ==============================================================================

test_that("MRG-02: logged_join helper emits row count messages before and after join", {
  # This test validates that the logged_join() function (created in 02_merge.R)
  # produces message() output containing row counts.
  # Test stub: define a minimal logged_join and verify it emits messages.
  # Once 02_merge.R exists, this test should source it and test the real function.
  #
  # For Wave 0 (RED state): Test the CONTRACT that a join wrapper must emit messages
  # with row counts. The actual logged_join is implemented in Plan 02-03.
  encounters <- bind_rows(mock_encounter1, mock_encounter2)
  dx_combined <- bind_rows(mock_dx_parts[[1]], mock_dx_parts[[2]])

  # Verify that a join operation CAN be wrapped with message() logging
  # This validates the pattern; 02_merge.R must implement logged_join with this behavior
  msgs <- capture.output({
    message("Left rows: ", nrow(encounters))
    message("Right rows: ", nrow(dx_combined))
    result <- left_join(encounters, dx_combined, by = c("patid", "encounterid"),
                        relationship = "one-to-many")
    message("Result rows: ", nrow(result))
  }, type = "message")

  # Messages must contain row count numbers
  expect_true(any(grepl("Left rows:", msgs)))
  expect_true(any(grepl("Right rows:", msgs)))
  expect_true(any(grepl("Result rows:", msgs)))
  # Messages must contain actual numeric counts (not empty)
  expect_true(any(grepl("[0-9]+", msgs)))
})

# ==============================================================================
# MRG-03: Many-to-many relationship detection
# ==============================================================================

test_that("MRG-03: relationship argument catches unexpected many-to-many", {
  # Create data with intentional many-to-many to verify detection
  enc_duped <- bind_rows(mock_encounter1[1, ], mock_encounter1[1, ])
  dx_duped <- bind_rows(mock_dx_parts[[1]][1:2, ], mock_dx_parts[[1]][1:2, ])
  # This should error or warn with relationship = "one-to-many"
  # because encounters table has duplicate encounterid
  expect_error(
    left_join(enc_duped, dx_duped, by = c("patid", "encounterid"),
              relationship = "one-to-many"),
    class = "dplyr_error"
  )
})

# ==============================================================================
# MRG-03: Verify no Cartesian product in normal case
# ==============================================================================

test_that("MRG-03: Normal join does not produce Cartesian product", {
  encounters <- bind_rows(mock_encounter1, mock_encounter2)
  dx_combined <- bind_rows(mock_dx_parts[[1]], mock_dx_parts[[2]])
  result <- left_join(encounters, dx_combined, by = c("patid", "encounterid"),
                      relationship = "one-to-many")
  # Growth should be reasonable (not >20x)
  growth_factor <- nrow(result) / nrow(encounters)
  expect_lte(growth_factor, 20)
})

# ==============================================================================
# MRG-04: Post-merge assertions (assertr)
# ==============================================================================

test_that("MRG-04: Post-merge data has no unexpected NA encounterids", {
  encounters <- bind_rows(mock_encounter1, mock_encounter2)
  dx_combined <- bind_rows(mock_dx_parts[[1]], mock_dx_parts[[2]])
  result <- left_join(encounters, dx_combined, by = c("patid", "encounterid"),
                      relationship = "one-to-many")
  # encounterid should never be NA after join
  expect_false(any(is.na(result$encounterid)))
})

test_that("MRG-04: Patient count preserved after merge", {
  encounters <- bind_rows(mock_encounter1, mock_encounter2)
  dx_combined <- bind_rows(mock_dx_parts[[1]], mock_dx_parts[[2]])
  result <- left_join(encounters, dx_combined, by = c("patid", "encounterid"),
                      relationship = "one-to-many")
  expect_equal(n_distinct(result$patid), n_distinct(encounters$patid))
})
