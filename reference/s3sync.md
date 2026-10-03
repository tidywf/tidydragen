# AWS S3 Sync Helper

Syncs the parse-relevant DRAGEN outputs from `src` to `dest`. The
default include patterns are **generated from the tool schemas** under
`inst/config/tools/*/schema.yaml` (see
[`nemo::wf_sync_patterns()`](https://tidywf.github.io/nemo/reference/wf_sync_patterns.html)),
so adding a table to a schema automatically adds it here — there is no
hand-maintained file list to keep in sync.

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

## Details

This single helper replaces the former `s3sync()`/`s3sync_bcl()`/
`s3sync_cttso()` trio: the schemas of
[DragenBcl](https://tidywf.github.io/tidydragen/reference/DragenBcl.md),
[DragenTso](https://tidywf.github.io/tidydragen/reference/DragenTso.md)
and the rest are all part of the
[Dragen](https://tidywf.github.io/tidydragen/reference/Dragen.md)
workflow, so one pattern set covers BCLConvert `Reports/` directories,
ctTSO runs and ordinary DRAGEN runs alike. Point `src` at whichever
directory you have; patterns that do not apply simply match nothing.

The ctTSO `Logs_Intermediates/` duplicates are dropped via
`Dragen$sync_exclude` (see
[DRAGEN_SYNC_EXCLUDE](https://tidywf.github.io/tidydragen/reference/DRAGEN_SYNC_EXCLUDE.md)),
keeping the `Results/` copy only. `aws s3 sync` filters are ordered and
last-match wins, so those excludes are applied after the schema-derived
includes.

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
