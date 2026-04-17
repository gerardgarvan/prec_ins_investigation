---
status: partial
phase: 03-analytical-dataset-construction
source: [03-VERIFICATION.md]
started: 2026-04-17T12:35:00Z
updated: 2026-04-17T12:35:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Run full pipeline with real data (Phases 1-3)
expected: 03_analytical.rds and 03_analytical_mi.rds created with expected patient counts matching SAS output
result: [pending]

### 2. Verify CONSORT flowchart visual quality
expected: PNG and PDF show clear attrition boxes with correct counts, readable labels, proper spacing
result: [pending]

### 3. Compare cohort attrition counts to SAS PROC SQL counts
expected: Each exclusion step produces patient counts within expected range based on SAS V5 output
result: [pending]

### 4. Validate insurance change variable distribution against SAS PROC FREQ
expected: change_ins distribution matches SAS V5_15 output (proportion with change_ins=1)
result: [pending]

### 5. Verify treatment intensity distribution against SAS PROC FREQ
expected: Intensity categories 0-8 match SAS V5_14 distribution
result: [pending]

### 6. Check visit count aggregations against SAS PROC MEANS
expected: n_Enc_nonacute_care, n_Cancer_related_visit, etc. match SAS sums
result: [pending]

### 7. Validate person-time calculation against SAS sum(person_time_days)
expected: Total person-time within 1% of SAS V5_15 sum
result: [pending]

## Summary

total: 7
passed: 0
issues: 0
pending: 7
skipped: 0
blocked: 0

## Gaps
