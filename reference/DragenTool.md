# DragenTool Object

Base class for the DRAGEN tools, adding the shared `dragen-metrics`
ftype to
[nemo::Tool](https://tidywf.github.io/nemo/reference/Tool.html). A plain
metrics table needs only `ftype: 'dragen-metrics'` in its schema; one
needing `normalise`/`drop_constant` declares a `tidy_<tbl>()` that
delegates to `tidy_metrics()`.

## Details

DRAGEN `*_metrics.csv` files are headerless
`section,rg,variable,count[,pct]`. `count` is read as character (string
values such as `"XX"`, counts beyond 32-bit) and coerced to its schema
`type` after the wide pivot.

## Super class

[`nemo::Tool`](https://tidywf.github.io/nemo/reference/Tool.html) -\>
`DragenTool`

## Public fields

- `on_unmapped`:

  (`character(1)`)  
  Policy for file metrics absent from the schema: `error` (default) or
  `warn` (drop them).

- `on_coerce_fail`:

  (`character(1)`)  
  Policy for a non-empty value that coerces to `NA` under its schema
  `type`: `error` (default) or `warn` (keep the `NA`).

- `on_unexpected_col`:

  (`character(1)`)  
  Policy for a `drop_constant` id column that varies across rows:
  `error` (default) or `warn` (keep the column).

## Examples

``` r
# Abstract base: normally you use a subclass (e.g. DragenVar).
indir <- system.file("extdata/dragenmap", package = "tidydragen")
tool <- DragenTool$new(name = "dragenmap", pkg = "tidydragen", path = indir)
tool$list_files()      # inherited nemo::Tool file discovery
#> # A tibble: 11 × 9
#>    tool_parser     parser bname    size lastmodified        path  pattern prefix
#>    <chr>           <chr>  <chr> <fs::b> <dttm>              <chr> <chr>   <chr> 
#>  1 dragenmap_repl… replay samp…   3.94K 2026-10-24 07:30:33 /hom… "-repl… sampl…
#>  2 dragenmap_time  time   samp…     944 2026-10-24 07:30:33 /hom… "\\.ti… sampl…
#>  3 dragenmap_repl… replay samp…   2.44K 2026-10-24 07:30:33 /hom… "-repl… sampl…
#>  4 dragenmap_time  time   samp…      92 2026-10-24 07:30:33 /hom… "\\.ti… sampl…
#>  5 dragenmap_repl… replay samp…   1.82K 2026-10-24 07:30:33 /hom… "-repl… sampl…
#>  6 dragenmap_frag… fragl… samp…  19.39K 2026-10-24 07:30:33 /hom… "\\.fr… sampl…
#>  7 dragenmap_gc    gc     samp…  10.52K 2026-10-24 07:30:33 /hom… "\\.gc… sampl…
#>  8 dragenmap_metr… metri… samp…  27.03K 2026-10-24 07:30:33 /hom… "\\.ma… sampl…
#>  9 dragenmap_time  time   samp…    1.3K 2026-10-24 07:30:33 /hom… "\\.ti… sampl…
#> 10 dragenmap_trim… trimm… samp…   1.35K 2026-10-24 07:30:33 /hom… "\\.tr… sampl…
#> 11 dragenmap_umi   umi    samp…   5.22K 2026-10-24 07:30:33 /hom… "\\.um… sampl…
#> # ℹ 1 more variable: prefix_suffix <chr>
tool$on_unmapped       # "error": unmapped metrics abort rather than drop
#> [1] "error"
tool$on_coerce_fail    # "error": values that fail type coercion abort
#> [1] "error"

# flip a policy to be lenient (drop/keep-NA with a warning instead)
tool$on_unmapped <- "warn"

# fail-loud paths, via a corrupted copy of the DragenRna fixture
rna_dir <- system.file("extdata/dragenrna", package = "tidydragen")
bad_dir <- tempfile()
dir.create(bad_dir)
file.copy(list.files(rna_dir, full.names = TRUE), bad_dir)
#> [1] TRUE TRUE TRUE TRUE
qf <- file.path(bad_dir, "sampleA.quant_metrics.csv")
lines <- readLines(qf)
```
