# DragenTool Object

Intermediate base class for all tidydragen tools. Inherits
[nemo::Tool](https://tidywf.github.io/nemo/reference/Tool.html) and adds
DRAGEN-specific shared logic e.g. the metrics parser/tidier used by
every `*_metrics.csv` table. Tools like `DragenCov` inherit from
`DragenTool` rather than
[`nemo::Tool`](https://tidywf.github.io/nemo/reference/Tool.html)
directly. The `dragen-metrics` ftype is registered here (parse via
`extra_ftypes()`, tidy via the `tidy_file` override), so a plain metrics
table needs no methods, just `ftype: 'dragen-metrics'` in its schema. A
table needing a `normalise`/`drop_constant` still declares an explicit
`tidy_<tbl>()` that delegates to `tidy_metrics`.

## Details

DRAGEN `*_metrics.csv` files share a headerless 4/5-column shape:
`section, rg, variable, count[, pct]`. `rg` (read-group / sample) is
empty for most sections but populated for e.g. fastqc and per-sample
variant sections. The value column (`count`) is read as character since
some metrics carry string values (e.g. `Ploidy estimation` = `"XX"`) and
counts can exceed 32-bit range; each tidy column is coerced to its
schema `type` after the wide pivot.

## Super class

[`nemo::Tool`](https://tidywf.github.io/nemo/reference/Tool.html) -\>
`DragenTool`

## Public fields

- `on_unmapped`:

  (`character(1)`)  
  Policy for metrics present in a `*_metrics.csv` file but absent from
  the schema. `error` refuses to drop data and aborts, so schema drift
  (e.g. a new DRAGEN version adds a metric) fails loudly rather than
  silently omitting a column. Set to `warn` to instead drop the unmapped
  metrics with a warning.

- `on_coerce_fail`:

  (`character(1)`)  
  Policy for a non-empty metric value that fails coercion to its schema
  numeric `type` (becomes `NA`). `error` aborts rather than losing the
  value; usually a wrong schema `type` (should be `char`) or an
  unexpected string. Set to `warn` to keep the `NA` with a warning.
  Genuine missings (`NA`/empty in the file) never trigger this.

- `on_unexpected_col`:

  (`character(1)`)  
  Policy for an id column named in `tidy_metrics(drop_constant=)` that
  was expected to be constant (and so dropped) but instead varies across
  rows. `error` aborts rather than letting a surprise extra column
  appear in the output table (schema drift into a data lake). Set to
  `warn` to keep the unexpected column with a warning. Tables that
  legitimately vary in `section`/`rg` opt out via
  `drop_constant = character()` and never trip this.

## Examples

``` r
# Abstract base. Normally you use a subclass (e.g. DragenVar). The parser/tidier
# are private; here we just inspect the inherited surface + policy fields.
indir <- system.file("extdata/dragenmap", package = "tidydragen")
tool <- DragenTool$new(name = "dragenmap", pkg = "tidydragen", path = indir)
tool$list_files()      # inherited nemo::Tool file discovery
#> # A tibble: 11 × 9
#>    tool_parser     parser bname    size lastmodified        path  pattern prefix
#>    <chr>           <chr>  <chr> <fs::b> <dttm>              <chr> <chr>   <chr> 
#>  1 dragenmap_repl… repla… samp…   3.94K 2026-10-04 07:23:36 /hom… "-repl… sampl…
#>  2 dragenmap_time  time   samp…     944 2026-10-04 07:23:36 /hom… "\\.ti… sampl…
#>  3 dragenmap_repl… repla… samp…   2.44K 2026-10-04 07:23:36 /hom… "-repl… sampl…
#>  4 dragenmap_time  time   samp…      92 2026-10-04 07:23:36 /hom… "\\.ti… sampl…
#>  5 dragenmap_repl… repla… samp…   1.82K 2026-10-04 07:23:36 /hom… "-repl… sampl…
#>  6 dragenmap_frag… fragl… samp…  19.39K 2026-10-04 07:23:36 /hom… "\\.fr… sampl…
#>  7 dragenmap_gcma… gcmain samp…  10.52K 2026-10-04 07:23:36 /hom… "\\.gc… sampl…
#>  8 dragenmap_metr… metri… samp…  27.03K 2026-10-04 07:23:36 /hom… "\\.ma… sampl…
#>  9 dragenmap_time  time   samp…    1.3K 2026-10-04 07:23:36 /hom… "\\.ti… sampl…
#> 10 dragenmap_trim… trimm… samp…   1.35K 2026-10-04 07:23:36 /hom… "\\.tr… sampl…
#> 11 dragenmap_umim… umima… samp…   5.22K 2026-10-04 07:23:36 /hom… "\\.um… sampl…
#> # ℹ 1 more variable: prefix_suffix <chr>
tool$on_unmapped       # "error": unmapped metrics abort rather than drop
#> [1] "error"
tool$on_coerce_fail    # "error": values that fail type coercion abort
#> [1] "error"

# flip a policy to be lenient (drop/keep-NA with a warning instead)
tool$on_unmapped <- "warn"

# Exercise the fail-loud paths end to end (not just the field above), via a
# deliberately-corrupted copy of a real DragenRna fixture (smallest schema).
rna_dir <- system.file("extdata/dragenrna", package = "tidydragen")
bad_dir <- tempfile()
dir.create(bad_dir)
file.copy(list.files(rna_dir, full.names = TRUE), bad_dir)
#> [1] TRUE TRUE TRUE TRUE
qf <- file.path(bad_dir, "sampleA.quant_metrics.csv")
lines <- readLines(qf)
```
