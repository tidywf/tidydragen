# AWS S3 Sync Helper (ctTSO / dragen-tso500-ctdna)

Sync only the small, parse-relevant files from a DRAGEN TSO500 ctDNA
run. Excludes the large binaries (BAM, gVCF, bigwig etc.) and the
pipeline/nextflow logs. Files live deep under
`Logs_Intermediates/DragenCaller/<sample>/` and `Results/<sample>/`.

## Usage

``` r
s3sync_cttso(src, dest, pats = NULL, dryrun = FALSE)
```

## Arguments

- src:

  (`character(1)`)  
  S3 source path.

- dest:

  (`character(1)`)  
  Local destination path.

- pats:

  (`tibble()`)  
  Patterns tibble with `inex` ("in" or "ex") and `pat` (pattern)
  columns.

- dryrun:

  (`logical(1)`)  
  If `TRUE`, passes `--dryrun` to `aws s3 sync` so operations are
  displayed without being executed.

## Details

Folder-prefix excludes: `aws s3 sync` filters are ordered and last-match
wins, so an `"ex"` row placed *after* an `"in"` row carves a subset back
out (e.g. `"in", "*Tmb/*"` then `"ex", "*Tmb/*.tmb.trace.tsv"`). The
default patterns use this to drop the `Logs_Intermediates/` duplicates
while keeping the `Results/` copy.

## Examples

``` r
if (FALSE) { # \dontrun{
d1 <- "s3://pipeline-prod-cache-503977275616-ap-southeast-2/byob-icav2/production/analysis"
src <- file.path(d1, "dragen-tso500-ctdna/20260827e81c2a44")
dest <- sub(d1, here::here("nogit"), src)
s3sync_cttso(src, dest, dryrun = TRUE)

# custom: whole Results/ folder except one file (folder-prefix exclude)
pats <- tibble::tribble(
  ~inex, ~pat,
  "ex", "*",
  "in", "*Results/*",
  "ex", "*Results/*_MetricsOutput.tsv"
)
s3sync_cttso(src, dest, pats = pats, dryrun = TRUE)
} # }
```
