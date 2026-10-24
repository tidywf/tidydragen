# AWS S3 Sync Helper

Syncs the parse-relevant DRAGEN outputs (any pipeline, incl. BCLConvert
`Reports/`) from `src` to `dest`. Include patterns come from the tool
schemas (see
[`nemo::wf_sync_patterns()`](https://tidywf.github.io/nemo/reference/wf_sync_patterns.html)),
followed by
[DRAGEN_SYNC_EXCLUDE](https://tidywf.github.io/tidydragen/dev/reference/DRAGEN_SYNC_EXCLUDE.md).

## Usage

``` r
s3sync(src, dest, pats = NULL, dryrun = FALSE)
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
  columns. If `NULL` and `workflow` is given, the workflow's
  schema-derived patterns are used (see
  [`wf_sync_patterns()`](https://tidywf.github.io/nemo/reference/wf_sync_patterns.html));
  if both are `NULL`, everything is excluded.

- dryrun:

  (`logical(1)`)  
  If `TRUE`, passes `--dryrun` to `aws s3 sync` so operations are
  displayed without being executed.

## Examples

``` r
if (FALSE) { # \dontrun{
src <- "s3://my-awesome-bucket/path/to/run1"
dest <- sub("s3:/", "~/s3", src)
s3sync(src, dest, dryrun = TRUE)

# inspect what would be pulled down
nemo::wf_sync_patterns("dragen")

# override with your own patterns
pats <- tibble::tribble(
  ~inex, ~pat,
  "ex", "*",
  "in", "*.mapping_metrics.csv"
)
s3sync(src, dest, pats)
} # }
```
