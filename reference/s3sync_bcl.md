# AWS S3 Sync Helper (BCLConvert `Reports/`)

Sync only the parse-relevant CSVs from a DRAGEN BCLConvert `Reports/`
directory (plus `RunInfo.xml` for run metadata). Excludes the binaries
(`IndexMetricsOut.bin`), `SampleSheet.csv`, and `report.html`. The two
tile-level CSVs (`Demultiplex_Tile_Stats.csv`,
`Quality_Tile_Metrics.csv`) are large (tens of MB) but still
parse-relevant; override `pats` to drop them.

## Usage

``` r
s3sync_bcl(src, dest, pats = NULL, dryrun = FALSE)
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

## Examples

``` r
if (FALSE) { # \dontrun{
d1 <- "s3://pipeline-prod-cache-503977275616-ap-southeast-2/byob-icav2/production/primary"
src <- file.path(d1, "260618_A01052_0309_BHTYNGDSXF/20260619ec753acc/Reports")
dest <- sub(d1, here::here("nogit", "bclconvert"), src)
s3sync_bcl(src, dest, dryrun = TRUE)
} # }
```
