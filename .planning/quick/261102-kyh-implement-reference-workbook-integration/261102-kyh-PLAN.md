---
phase: quick
plan: 261102-kyh
type: execute
wave: 1
depends_on: []
files_modified:
  - R/config.R
  - R/00_build_icd_groups.R
  - R/00_build_prov_spec.R
  - R/01_import.R
  - R/02_clean.R
  - R/02_merge.R
  - R/03_outcomes.R
  - docs/DATA_LINEAGE.md
  - docs/plans/fix-list.md
  - reference/README.md
  - .gitignore
autonomous: true
requirements: []

must_haves:
  truths:
    - "reference_dir points to reference/ in both normal and PIPELINE_TEST modes"
    - "00_build_icd_groups.R reads CancerSiteCategories.xlsx and produces 01_imported_icd_groups.rds with icd9_10 + group_site columns"
    - "02_clean.R uses two-pass join (exact then 5-char truncation) so C50.911 maps to C50.9 entry, C91.10 maps to C91.1, etc."
    - "00_build_prov_spec.R reads nucc_taxonomy_210.xlsx and produces 01_imported_prov_spec.rds with provider_specialty_primary + cancer_provider (integer) columns"
    - "02_merge.R joins prov_spec on trimmed/uppercased PROVIDER_SPECIALTY_PRIMARY and fills cancer_provider=0 when missing"
    - "03_outcomes.R stop() guard replaced by assertr::verify(cancer_provider %in% c(0L,1L)) now that column is guaranteed"
    - "Tests pass: 207RX0202X->1, 207R00000X->0, NA->0, unknown code->0, lowercase/whitespace variant->0"
  artifacts:
    - path: "R/00_build_icd_groups.R"
      provides: "Excel -> icd_groups RDS (icd9_10, group_site)"
    - path: "R/00_build_prov_spec.R"
      provides: "Excel -> prov_spec RDS (provider_specialty_primary, cancer_provider)"
    - path: "reference/README.md"
      provides: "Reference file manifest with source, destination, date"
  key_links:
    - from: "R/01_import.R"
      to: "R/00_build_icd_groups.R + R/00_build_prov_spec.R"
      via: "source() calls"
    - from: "R/02_merge.R"
      to: "01_imported_prov_spec.rds"
      via: "readRDS + left_join on provider_specialty_primary"
    - from: "R/03_outcomes.R"
      to: "cancer_provider column in followup_encounters"
      via: "assertr::verify(cancer_provider %in% c(0L, 1L) & !is.na(cancer_provider))"
---

<objective>
Implement reference workbook integration: replace the blocked ICD-group lookup (currently
reads a missing SAS7BDAT) with CancerSiteCategories.xlsx, and add the missing cancer_provider
flag by integrating nucc_taxonomy_210.xlsx into the provider merge step.

Purpose: These are the two known blockers preventing 03_outcomes.R from running. The
cancer_provider stop() blocks execution entirely. The ICD join produces no matches because
real dx codes (5-7 chars) never exactly match 4-char lookup keys. Fixing both unblocks
the full pipeline.

Output:
  R/00_build_icd_groups.R    -- xlsx reader -> 01_imported_icd_groups.rds
  R/00_build_prov_spec.R     -- xlsx reader -> 01_imported_prov_spec.rds
  reference/README.md        -- manifest of reference workbooks
  config.R updated with reference_dir
  .gitignore updated with !reference/*.xlsx exception
  01_import.R updated to source both build scripts
  02_clean.R updated with two-pass ICD join
  02_merge.R updated with prov_spec join + fill
  03_outcomes.R updated: stop() replaced with assertr check
  DATA_LINEAGE.md updated with gap TODOs and 21 flagged codes
  docs/plans/fix-list.md updated with items 12 and 13
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@R/config.R
@R/01_import.R
@R/02_clean.R
@R/02_merge.R
@R/03_outcomes.R
@docs/DATA_LINEAGE.md
@docs/plans/fix-list.md
@.gitignore

<interfaces>
<!-- SAS forensics — executor must not re-search. Key findings quoted from SAS files. -->

## SAS: ICD lookup construction (dx and tumor 5 30 2024.sas lines 18-143)

```sas
-- Step 1: import ICD-9 crosswalk using cols D-E (1,129 pairs)
proc import out=dx.icd9_icd10 datafile=F:\Jax_Ascent\CancerSiteCategories.xlsx
  dbms=xlsx replace;
  range = ForSAS_ICD9toICD10$D1:E2917;
  getnames=yes;
run;

-- Step 2: manual add-back of .0 codes Excel drops from numeric cells
data dx.add;
  input icd9_10 $ icd10 $;
  datalines;
  140.0 C00.0  142.0 C07.0  143.0 C03.0  ...
  ;
data dx.icd9_icd10; set dx.icd9_icd10 dx.add; run;

-- Step 3: import ForSAS_ICD10 sheet (A1:D1018)
proc import out=dx.icd10_groups datafile=F:\Jax_Ascent\CancerSiteCategories.xlsx
  dbms=xlsx replace;
  range = ForSAS_ICD10$A1:D1018;  /* cols: icd10 | Group_primary_disease_site | Group_detailed_site | Group_Site */
  getnames=yes;
run;

-- Step 4: merge crosswalk + icd10_groups on icd10 (exact match at ForSAS_ICD10 key level)
proc sql;
  create table dx.icd10_groups1 as
  select * from dx.icd9_icd10 as a
  left join dx.icd10_groups as b on (a.icd10 = b.icd10);
quit;

-- Step 5: fill blanks -> 'Reportable but not mapped above'
-- Step 6: dedup by icd9_10 nodupkey -> dx.icd10_groups2

-- V5_3 line 49 join (the final lookup):
left join dx.Icd10_groups2 as b on (a.dx = b.ICD9_10);
```

Key matching insight:
  - ICD9_10 column contains EITHER full ICD-9 codes (e.g. "174.9", "230.0", "209.25")
    OR 4-char-with-dot ICD-10 codes like "C50.9", "C81.1", "C90.0" (from ForSAS_ICD10)
  - Real PCORnet dx values are 5-7 chars: "C50.911", "C91.10", "C90.00", "C81.10"
  - The SAS exact join works because icd9_10 truncates to the level stored in ForSAS_ICD10.
  - R must replicate with a two-pass approach: (1) exact join, (2) 5-char substr join for misses.
  - ICD-9 codes pass exact join. ICD-10 5-7 char codes pass the 5-char substr join.
  - V5_3 overrides (startsWith) fire on the original dx, not on the truncated key -- no change needed.

## SAS: prov_spec import and join (SAS_CODE_FOR_v5_1.sas lines 45-54; SAS_CODE_FOR_V5_2.sas lines 11-19)

```sas
-- Import (v5_1 lines 45-50):
proc import out=v3.prov_spec
  datafile="/blue/erin.mobley-precision/ResVault/f/Jax_Ascent/nucc_taxonomy_210.xlsx"
  dbms=xlsx replace;
  range = "sas$A1:D866";   /* 865 data rows, 4 cols */
  getnames=yes;
run;

-- Join (v5_2 lines 11-19):
select a.*, b.PROVIDER_SPECIALTY_PRIMARY, b.Cancer_provider
from v3.provider as a
left join v3.prov_spec b on (a.PROVIDER_SPECIALTY_PRIMARY = b.PROVIDER_SPECIALTY_PRIMARY);
```

Join key: PROVIDER_SPECIALTY_PRIMARY (text, e.g. "207RX0202X").
Missing join -> cancer_provider left as NULL -> treated as 0 downstream.
The "sas" sheet has 4 columns A-D. Column A is PROVIDER_SPECIALTY_PRIMARY (= Code),
Column D is Cancer_provider ("1" or "0" as text). 21 rows have Cancer_provider = "1".

## Current 02_merge.R comment on cancer_provider (line 132-134):
"NOTE: cancer_provider is NOT in this table -- it requires joining prov_spec
(nucc_taxonomy_210.xlsx). See DATA_LINEAGE.md 'Blocking: cancer_provider'."

## Current 03_outcomes.R guard (lines 99-106):
stop("cancer_provider column is missing from followup_encounters...")
-- This must be REMOVED and replaced by a post-join assertion.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Repo setup -- config.R, .gitignore, reference/README.md, readxl</name>
  <files>R/config.R, .gitignore, reference/README.md</files>
  <action>
**R/config.R**: Add `reference_dir` in two places:

1. After `data_dir_raw` in the production block:
```r
# Reference workbooks (committed to repo -- analytical lookup files, not patient data)
reference_dir <- here::here("reference")
```

2. Inside the `if (isTRUE(...PIPELINE_TEST...))` block, after the existing assignments:
```r
  reference_dir <- here::here("reference")  # same value -- reference/ is repo-local always
```

Also add `dir.create(reference_dir, recursive = TRUE, showWarnings = FALSE)` to both blocks
so the directory is created on first run.

**.gitignore**: Add these lines after the existing `data/` block (the current file has no xlsx rule):
```
# Allow committed reference workbooks (analytical lookup files, not patient data)
!reference/
!reference/*.xlsx
!reference/README.md
```

**reference/README.md** (new file):
```markdown
# Reference Workbooks

These files are committed to version control. They are analytical lookup tables,
not patient data, and do not contain HIPAA-protected information.

| File | Source | Feeds | Date Added |
|------|--------|-------|------------|
| CancerSiteCategories.xlsx | /orange/erin.mobley-precision/ (originally F:\Jax_Ascent\) | R/00_build_icd_groups.R -> 01_imported_icd_groups.rds -> 02_clean.R ICD site grouping | 2026-11-02 |
| nucc_taxonomy_210.xlsx | Supplied by Gerard, originally F:\Jax_Ascent\ | R/00_build_prov_spec.R -> 01_imported_prov_spec.rds -> 02_merge.R cancer_provider flag | 2026-11-02 |

## Sheets used

**CancerSiteCategories.xlsx**
- `ForSAS_ICD10` A1:D1018 -- 4-column ICD-10 code -> site group lookup (966 data rows)
- `ForSAS_ICD9toICD10` D1:E2917 -- ICD-9 to ICD-10 crosswalk (1,129+ pairs; cols D-E used per SAS range)

**nucc_taxonomy_210.xlsx**
- `sas` A1:D866 -- NUCC taxonomy code -> Cancer_provider flag (865 data rows, 21 codes flagged as 1)
```

**readxl**: If the project has renv.lock, run `renv::install("readxl")` then `renv::snapshot()` to add readxl. If renv is not active, document that `install.packages("readxl")` is required.
  </action>
  <verify>
    <automated>Rscript -e "source('R/config.R'); stopifnot(exists('reference_dir')); cat('reference_dir OK:', reference_dir, '\n')"</automated>
  </verify>
  <done>reference_dir exists in config.R (both modes); .gitignore has !reference/*.xlsx; reference/README.md created</done>
</task>

<task type="auto">
  <name>Task 2: R/00_build_icd_groups.R -- read CancerSiteCategories.xlsx, produce icd_groups RDS; update 02_clean.R join</name>
  <files>R/00_build_icd_groups.R, R/01_import.R, R/02_clean.R</files>
  <action>
Create `R/00_build_icd_groups.R`:

```r
# R/00_build_icd_groups.R
# Build ICD cancer-site group lookup from CancerSiteCategories.xlsx
# SAS source: "dx and tumor 5 30 2024.sas" (also dxandtmr.sas, SAS_CODE_FOR_V5_13)
# Output: {data_dir_processed}/01_imported_icd_groups.rds
#   Columns: icd9_10 (character), group_site (character)
#
# fix_lookup_gaps flag (default FALSE = SAS-faithful):
#   FALSE: reproduce SAS exactly, including known missing codes
#   TRUE:  add C19/C20/C23/C65/C66/C50.0/C7A.00 and fix "Unrinary" typo
#   Set via: options(prec_ins.fix_lookup_gaps = TRUE) before sourcing.

library(here)
if (!exists("reference_dir")) source(here::here("R", "config.R"))
if (!requireNamespace("readxl", quietly = TRUE)) stop("readxl not installed. Run: install.packages('readxl')")
library(readxl)
library(dplyr)
library(stringr)

fix_lookup_gaps <- isTRUE(getOption("prec_ins.fix_lookup_gaps", default = FALSE))

xlsx_path <- file.path(reference_dir, "CancerSiteCategories.xlsx")
if (!file.exists(xlsx_path)) {
  stop(
    "CancerSiteCategories.xlsx not found at: ", xlsx_path, "\n",
    "Copy from /orange/erin.mobley-precision/ to reference/"
  )
}

# ---- Step 1: ICD-9 -> ICD-10 crosswalk (cols D-E of ForSAS_ICD9toICD10 per SAS range D1:E2917) ----
# Force text: ICD-9 values like "140.1" and "230" are numeric in Excel.
crosswalk_raw <- read_excel(
  xlsx_path, sheet = "ForSAS_ICD9toICD10",
  range = "D1:E2917", col_types = "text"
)
names(crosswalk_raw) <- c("icd9_10", "icd10")

crosswalk <- crosswalk_raw %>%
  filter(!is.na(icd9_10), str_trim(icd9_10) != "") %>%
  mutate(
    icd9_10 = str_trim(icd9_10),
    icd10   = str_trim(icd10),
    # Excel stores "140.0" as numeric 140; restore canonical string form.
    # Rule: if no "." AND starts with a digit AND 2-3 chars -> add ".0"
    # (ICD-9 codes without .0 are the truncated roots; SAS datalines add them back)
    icd9_10 = if_else(
      !str_detect(icd9_10, fixed(".")) & str_detect(icd9_10, "^[0-9]") & nchar(icd9_10) <= 3L,
      paste0(icd9_10, ".0"),
      icd9_10
    )
  ) %>%
  filter(!is.na(icd10), icd10 != "")

message("crosswalk: ", nrow(crosswalk), " ICD-9->ICD-10 pairs after cleanup")

# ---- Step 2: ForSAS_ICD10 (A1:D1018, 4-col: icd10 | primary_site | detailed_site | Group_Site) ----
icd10_raw <- read_excel(
  xlsx_path, sheet = "ForSAS_ICD10",
  range = "A1:D1018", col_types = "text"
)
names(icd10_raw) <- c("icd10", "group_primary_disease_site", "group_detailed_site", "group_site")
icd10_lookup <- icd10_raw %>%
  filter(!is.na(icd10), str_trim(icd10) != "") %>%
  mutate(across(everything(), str_trim),
         group_site = if_else(is.na(group_site) | group_site == "",
                              "Reportable but not mapped above", group_site))
message("ForSAS_ICD10: ", nrow(icd10_lookup), " rows")

# ---- Step 3: merge crosswalk + icd10_lookup on icd10 (SAS: dx.icd10_groups1) ----
icd10_groups1 <- crosswalk %>%
  left_join(icd10_lookup %>% select(icd10, group_site), by = "icd10") %>%
  mutate(group_site = if_else(is.na(group_site) | group_site == "",
                              "Reportable but not mapped above", group_site))

# ---- Step 4: dedup by icd9_10 (SAS: nodupkey) ----
icd10_groups2 <- icd10_groups1 %>%
  arrange(icd9_10) %>%
  distinct(icd9_10, .keep_all = TRUE) %>%
  select(icd9_10, group_site)
message("icd10_groups2 (final lookup): ", nrow(icd10_groups2), " rows")

# ---- Step 5: gap handling (TODO(ERIN)) ----
# DATA_LINEAGE gap codes: C19, C20 (rectum); C23 (gallbladder); C65 (renal pelvis);
# C66 (ureter); C50.0 (central breast); C7A.00 (neuroendocrine unspec).
# Typo: "Unrinary System" in some Group_Site labels should be "Urinary System".
if (fix_lookup_gaps) {
  message("fix_lookup_gaps=TRUE: adding known missing codes + fixing typos")
  gap_rows <- tibble::tibble(
    icd9_10    = c("C19",    "C20",      "C23",         "C65",           "C66",           "C50.0",  "C7A.00"),
    group_site = c("Digestive","Digestive","Digestive","Urinary System","Urinary System","Breast", "Other")
  )
  icd10_groups2 <- bind_rows(
    icd10_groups2 %>% filter(!icd9_10 %in% gap_rows$icd9_10),
    gap_rows
  ) %>%
    arrange(icd9_10) %>%
    mutate(group_site = str_replace_all(group_site, "Unrinary", "Urinary"))
  message("  After gap patch: ", nrow(icd10_groups2), " rows")
} else {
  message("fix_lookup_gaps=FALSE (default, SAS-faithful).")
  message("  TODO(ERIN): known gaps not in ForSAS_ICD10: C19, C20, C23, C65, C66, C50.0, C7A.00")
  message("  TODO(ERIN): typo 'Unrinary System' present in some Group_Site labels")
  message("  Set options(prec_ins.fix_lookup_gaps=TRUE) before sourcing to patch.")
}

saveRDS(icd10_groups2, file.path(data_dir_processed, "01_imported_icd_groups.rds"))
message("Saved: 01_imported_icd_groups.rds (", nrow(icd10_groups2),
        " rows | cols: ", paste(names(icd10_groups2), collapse = ", "), ")")
```

**Update R/01_import.R**: Find any existing import of `Icd10_groups2.sas7bdat` and replace it.
If 01_import.R has a section that does `import_sas("Icd10_groups2.sas7bdat")` or
`haven::read_sas(...Icd10_groups2...)`, replace it with:
```r
# ICD cancer-site group lookup from CancerSiteCategories.xlsx (per Step 1 note in SAS source)
# Replaces Icd10_groups2.sas7bdat import. See DATA_LINEAGE.md for context.
source(here::here("R", "00_build_icd_groups.R"))
```
If no such import exists, add the source() call in a new "Reference Lookups" section near the
top of 01_import.R (after config.R is sourced, before encounter/dx imports).

**Update R/02_clean.R -- fix the ICD join (Section 4, around line 169)**:

The current exact join misses 5-7 char ICD-10 dx codes. Replace the merge call with a two-pass
join. Find this block:
```r
  part <- merge(part, icd_groups[, .(icd9_10, group_site)],
                by.x = "dx", by.y = "icd9_10", all.x = TRUE)
```

Replace with:
```r
  # Two-pass join (SAS matching rule):
  # Pass 1: exact join covers full ICD-9 codes ("174.9") and any exact ICD-10 matches.
  # Pass 2: 5-char substr join covers 5-7 char ICD-10 dx codes ("C50.911" -> "C50.9").
  # ForSAS_ICD10 keys are 5 chars max with dot (e.g. "C50.9", "C81.1").
  part <- merge(part, icd_groups[, .(icd9_10, group_site)],
                by.x = "dx", by.y = "icd9_10", all.x = TRUE)
  n_exact <- sum(!is.na(part$group_site))

  unmatched <- is.na(part$group_site)
  if (any(unmatched)) {
    part[, dx5 := substr(dx, 1L, 5L)]
    gs_prefix <- icd_groups[part[unmatched, .(dx5)],
                             on = .(icd9_10 = dx5), .(group_site)]$group_site
    part[unmatched, group_site := gs_prefix]
    part[, dx5 := NULL]
  }
  message("    ICD join -- exact: ", n_exact,
          " | prefix-fill: ", sum(!is.na(part$group_site)) - n_exact,
          " | unmatched: ", sum(is.na(part$group_site)))
```

Test codes to verify manually when running against real data:
  - C50.911 -> should hit "C50.9" in lookup -> Breast
  - C91.10  -> "C91.1" -> Hematologic
  - C90.00  -> "C90.0" -> Hematologic
  - C81.10  -> "C81.1" -> Hematologic (then overridden to Hematologic by apply_icd_overrides C82/C83/C85 block -- confirm C81 is in override)
  - C20     -> exact match "C20" or substr "C20" (only 3 chars) -> Digestive (gap if fix_lookup_gaps=FALSE)
  - 174.9   -> exact match in ICD-9 crosswalk -> Breast
  - 230.0   -> exact match ICD-9 -> In situ (then overridden by apply_icd_overrides)
  - 209.25  -> exact match ICD-9 (cols Q-R of crosswalk for neuroendocrine) -> check if in crosswalk
  </action>
  <verify>
    <automated>Rscript -e "
library(here); source(here::here('R','config.R'))
source(here::here('R','00_build_icd_groups.R'))
rds <- readRDS(file.path(data_dir_processed,'01_imported_icd_groups.rds'))
stopifnot(is.data.frame(rds))
stopifnot(all(c('icd9_10','group_site') %in% names(rds)))
stopifnot(nrow(rds) > 900)  # expect ~1000+ rows from crosswalk
cat('PASS: icd_groups', nrow(rds), 'rows\n')
" 2>&1  </verify>
  <done>00_build_icd_groups.R exists and writes 01_imported_icd_groups.rds with icd9_10 + group_site; 02_clean.R uses two-pass join; 01_import.R sources the build script</done>
</task>

<task type="auto">
  <name>Task 3: R/00_build_prov_spec.R -- read nucc_taxonomy_210.xlsx; update 02_merge.R and 03_outcomes.R</name>
  <files>R/00_build_prov_spec.R, R/01_import.R, R/02_merge.R, R/03_outcomes.R</files>
  <action>
Create R/00_build_prov_spec.R. The script reads the "sas" sheet (A1:D866) from nucc_taxonomy_210.xlsx,
normalizes PROVIDER_SPECIALTY_PRIMARY to upper-trimmed text, converts Cancer_provider text "1"/"0" to
integer, fills blank/NA as 0, and saves 01_imported_prov_spec.rds with two columns:
provider_specialty_primary (character) and cancer_provider (integer 0/1).

Key implementation notes:
- SAS PROC IMPORT range: "sas$A1:D866" (sheet named "sas", 4 cols, 865 data rows)
- SAS join: left join prov_spec on PROVIDER_SPECIALTY_PRIMARY = PROVIDER_SPECIALTY_PRIMARY
- Column A of sheet = PROVIDER_SPECIALTY_PRIMARY (the taxonomy Code)
- Column D of sheet = Cancer_provider ("1" or "0" as text)
- 21 rows have Cancer_provider = "1"
- Missing join (no match) -> cancer_provider stays NA -> fill 0 downstream
- readxl must read all columns as text (col_types = "text") to avoid numeric coercion

Add a warning if the count of flagged codes is not 21 (data integrity check).

Log all 21 flagged codes to console so they can be recorded in DATA_LINEAGE.md.

Update R/01_import.R: add source(here::here("R", "00_build_prov_spec.R")) near the icd_groups
source call added in Task 2.

Update R/02_merge.R -- insert Section 7b after the enc_dx_prov creation (before saveRDS):
- Load 01_imported_prov_spec.rds
- Normalize the provider_specialty_primary join key in enc_dx_prov: str_trim(toupper(...))
- left_join prov_spec with relationship="many-to-one"
- mutate cancer_provider = replace_na(cancer_provider, 0L)
- Log count of encounters with cancer_provider==1
- Log count of encounters with a specialty code NOT in prov_spec (filled 0) -- use setdiff
- stopifnot(all(enc_dx_prov$cancer_provider %in% c(0L, 1L))) and !any(is.na(...))
- Remove the existing NOTE comment that says cancer_provider is not available

Update R/03_outcomes.R -- lines 99-106: remove the stop() block that fires when cancer_provider
is missing. Replace with an assertr::verify check:
  - verify(cancer_provider %in% c(0L, 1L), description="cancer_provider must be 0 or 1")
  - verify(!is.na(cancer_provider), description="cancer_provider must have no NA")
  - Wrap in tryCatch; on error, stop with a clear message pointing to 02_merge.R
  </action>
  <verify>
    <automated>Rscript -e "library(here); source(here::here('R','config.R')); source(here::here('R','00_build_prov_spec.R')); rds <- readRDS(file.path(data_dir_processed,'01_imported_prov_spec.rds')); stopifnot(all(c('provider_specialty_primary','cancer_provider') %in% names(rds))); stopifnot(all(rds[['cancer_provider']] %in% c(0L,1L))); cat('PASS: prov_spec', nrow(rds), 'rows,', sum(rds[['cancer_provider']]==1L), 'flagged\n')"</automated>
  </verify>
  <done>00_build_prov_spec.R writes 01_imported_prov_spec.rds (provider_specialty_primary + cancer_provider int 0/1); 02_merge.R joins and fills cancer_provider=0 for misses with row-count logging; 03_outcomes.R stop() replaced by assertr verify</done>
</task>

<task type="auto">
  <name>Task 4: Tests, DATA_LINEAGE.md, fix-list.md, commit and push</name>
  <files>tests/testthat/test_prov_spec.R, docs/DATA_LINEAGE.md, docs/plans/fix-list.md</files>
  <action>
Create tests/testthat/test_prov_spec.R with 7 unit tests covering the cancer_provider
assignment logic (steps 10 of spec). Tests use a minimal 3-row mock_prov_spec fixture
(not the real xlsx -- tests must run offline):
  1. Known cancer specialty code 207RX0202X -> 1
  2. Non-cancer code 207R00000X -> 0
  3. NA specialty -> 0
  4. Unknown code not in prov_spec -> 0
  5. Lowercase variant matches after toupper (207rx0202x -> 1)
  6. Whitespace variant matches after str_trim ("  207RX0202X  " -> 1)
  7. All results in c(0L, 1L) with no NA for a mixed vector

The test helper should replicate the join + fill logic from 02_merge.R as a local function
(not source the script -- keep tests self-contained).

Update docs/DATA_LINEAGE.md:
  A) Mark the "Blocking: cancer_provider" section as RESOLVED (status: RESOLVED 2026-11-02).
  B) Add a new subsection "ICD Lookup Gaps -- TODO(ERIN)" listing the 7 missing codes
     (C19, C20, C23, C65, C66, C50.0, C7A.00) in a table with Expected Group_Site and Status=MISSING.
     Note the "Unrinary System" typo and trailing-space label issue.
     Note the fix_lookup_gaps flag.
  C) Add a new subsection "Provider Specialty Cancer Flags" noting that 21 codes are flagged
     in nucc_taxonomy_210.xlsx and listing a TODO(ERIN) to verify them against current NUCC
     taxonomy. Actual code list prints to console when 00_build_prov_spec.R runs.

Update docs/plans/fix-list.md -- add two new rows:
  Row 12: R/00_build_icd_groups.R + 02_clean.R + 01_import.R | ICD cancer site groups from xlsx;
           two-pass join (exact + 5-char substr) replicating SAS matching rule | DONE
  Row 13: R/00_build_prov_spec.R + 02_merge.R + 03_outcomes.R | cancer_provider from nucc_taxonomy_210;
           prov_spec left join fill-0 for misses; 03_outcomes stop() -> assertr verify | DONE

Run full test suite:
  Rscript -e "testthat::test_dir('tests/testthat', reporter='progress')"

Commit in two commits per spec step 12:
  Commit 1 (workbooks only):
    git add reference/CancerSiteCategories.xlsx reference/nucc_taxonomy_210.xlsx reference/README.md
    git commit -m "feat(reference): add CancerSiteCategories.xlsx and nucc_taxonomy_210.xlsx lookup workbooks"

  Commit 2 (code changes):
    git add R/config.R R/00_build_icd_groups.R R/00_build_prov_spec.R R/01_import.R
    git add R/02_clean.R R/02_merge.R R/03_outcomes.R .gitignore
    git add tests/testthat/test_prov_spec.R docs/DATA_LINEAGE.md docs/plans/fix-list.md
    git commit -m "feat(02,03): integrate xlsx workbooks for ICD groups and cancer_provider

- config.R: add reference_dir (production + PIPELINE_TEST)
- .gitignore: add !reference/*.xlsx exception
- 00_build_icd_groups.R: CancerSiteCategories.xlsx -> 01_imported_icd_groups.rds
- 02_clean.R: two-pass ICD join (exact then 5-char substr) replicates SAS matching rule
- 00_build_prov_spec.R: nucc_taxonomy_210.xlsx -> 01_imported_prov_spec.rds
- 02_merge.R: left join prov_spec, fill cancer_provider=0 for misses, log unmatched codes
- 03_outcomes.R: replace stop() guard with assertr::verify on cancer_provider 0/1 no-NA
- test_prov_spec.R: 7 unit tests for cancer_provider join logic"

  git push origin master
  </action>
  <verify>
    <automated>Rscript -e "testthat::test_dir('tests/testthat', reporter='progress')" 2>&1 | tail -5</automated>
  </verify>
  <done>All tests pass; DATA_LINEAGE.md has ICD gap table + RESOLVED cancer_provider entry; fix-list.md items 12-13 added as DONE; two commits on master and pushed to origin</done>
</task>

</tasks>

<verification>
After all tasks complete:
1. Rscript -e "source('R/config.R'); cat(reference_dir, '\n')" -- prints reference/ path
2. Rscript -e "source('R/00_build_icd_groups.R')" -- succeeds, prints row count
3. Rscript -e "source('R/00_build_prov_spec.R')" -- succeeds, prints 21 flagged codes
4. Rscript -e "testthat::test_dir('tests/testthat')" -- all tests pass
5. git log --oneline -3 -- shows two new commits (workbooks + code)
</verification>

<success_criteria>
- reference_dir defined in config.R for both modes
- CancerSiteCategories.xlsx drives ICD group lookup; two-pass join maps long dx codes correctly
- nucc_taxonomy_210.xlsx drives cancer_provider via 02_merge.R; 03_outcomes.R stop() removed
- 7 prov_spec unit tests pass
- DATA_LINEAGE.md documents ICD gaps with TODO(ERIN) and lists provider flag TODO
- fix-list.md items 12 and 13 added
</success_criteria>

<output>
No SUMMARY.md needed for quick tasks. Return results to user directly.
</output>
