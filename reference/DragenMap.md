# DragenMap Object

Parses and tidies DRAGEN mapping/alignment outputs: mapping metrics,
run-time metrics, and the fragment-length histogram.

## Super classes

[`nemo::Tool`](https://tidywf.github.io/nemo/reference/Tool.html) -\>
[`tidydragen::DragenTool`](https://tidywf.github.io/tidydragen/reference/DragenTool.md)
-\> `DragenMap`

## Public fields

- `flat_tidy_names`:

  (`logical(1)`)  
  `TRUE`: fan-out sub-tables are named `<tool>_<tidy_name>` (parser
  token dropped). Needed for the `umimain`/`umihist` and
  `gcmain`/`gcbias` splits.

## Methods

### Public methods

- [`DragenMap$new()`](#method-DragenMap-new)

- [`DragenMap$tidy_metrics()`](#method-DragenMap-tidy_metrics)

- [`DragenMap$tidy_umimain()`](#method-DragenMap-tidy_umimain)

- [`DragenMap$tidy_gcmain()`](#method-DragenMap-tidy_gcmain)

- [`DragenMap$tidy_time()`](#method-DragenMap-tidy_time)

- [`DragenMap$parse_fraglenhist()`](#method-DragenMap-parse_fraglenhist)

Inherited methods

- [`nemo::Tool$filter_files()`](https://tidywf.github.io/nemo/reference/Tool.html#method-filter_files)
- [`nemo::Tool$get_metadata()`](https://tidywf.github.io/nemo/reference/Tool.html#method-get_metadata)
- [`nemo::Tool$get_tbls()`](https://tidywf.github.io/nemo/reference/Tool.html#method-get_tbls)
- [`nemo::Tool$list_files()`](https://tidywf.github.io/nemo/reference/Tool.html#method-list_files)
- [`nemo::Tool$print()`](https://tidywf.github.io/nemo/reference/Tool.html#method-print)
- [`nemo::Tool$run()`](https://tidywf.github.io/nemo/reference/Tool.html#method-run)
- [`nemo::Tool$tidy()`](https://tidywf.github.io/nemo/reference/Tool.html#method-tidy)
- [`nemo::Tool$write()`](https://tidywf.github.io/nemo/reference/Tool.html#method-write)

------------------------------------------------------------------------

### Method `new()`

Create a new DragenMap object.

#### Usage

    DragenMap$new(path = NULL, files_tbl = NULL)

#### Arguments

- `path`:

  (`character(1)`)  
  Output directory of tool. If `files_tbl` is supplied, this is ignored.

- `files_tbl`:

  (`tibble(n)`)  
  Tibble of files from
  [`nemo::list_files_dir()`](https://tidywf.github.io/nemo/reference/list_files_dir.html).

------------------------------------------------------------------------

### Method `tidy_metrics()`

Tidy `mapping_metrics.csv`. Both id columns retained
(`drop_constant = character()`).

#### Usage

    DragenMap$tidy_metrics(x)

#### Arguments

- `x`:

  (`character(1)` or `tibble()`)  
  Path to file or parsed tibble.

------------------------------------------------------------------------

### Method `tidy_umimain()`

Tidy `umi_metrics.csv` into `umimain` (summary, wide) and `umihist` (the
`{a|b|c}` histograms, long).

#### Usage

    DragenMap$tidy_umimain(x)

#### Arguments

- `x`:

  (`character(1)` or `tibble()`)  
  Path to file or parsed tibble.

------------------------------------------------------------------------

### Method `tidy_gcmain()`

Tidy `gc_metrics.csv` into `gcmain` (GC METRICS SUMMARY, wide) and
`gcbias` (per-GC-window GC BIAS DETAILS, long — GC 0-100).

#### Usage

    DragenMap$tidy_gcmain(x)

#### Arguments

- `x`:

  (`character(1)` or `tibble()`)  
  Path to file or parsed tibble.

------------------------------------------------------------------------

### Method `tidy_time()`

Tidy `time_metrics.csv`, using seconds (not HH:MM:SS) as the metric
value and surfacing `total_runtime` first.

#### Usage

    DragenMap$tidy_time(x)

#### Arguments

- `x`:

  (`character(1)` or `tibble()`)  
  Path to file or parsed tibble.

------------------------------------------------------------------------

### Method `parse_fraglenhist()`

Parse `fragment_length_hist.csv` into a long tibble.

#### Usage

    DragenMap$parse_fraglenhist(x)

#### Arguments

- `x`:

  (`character(1)`)  
  Path to file.

## Examples

``` r
cls <- DragenMap; tool <- "dragenmap"
indir <- system.file("extdata", tool, package = "tidydragen")
odir <- tempdir()
obj <- cls$new(indir)
obj$run(output_dir = odir, format = "parquet", input_id = "run1")
(lf <- list.files(odir, pattern = "dragenmap_.*parquet", full.names = FALSE))
#> [1] "sampleA_dragenmap_fraglenhist.parquet"
#> [2] "sampleA_dragenmap_gcbias.parquet"     
#> [3] "sampleA_dragenmap_gcmain.parquet"     
#> [4] "sampleA_dragenmap_metrics.parquet"    
#> [5] "sampleA_dragenmap_time.parquet"       
#> [6] "sampleA_dragenmap_trimmer.parquet"    
#> [7] "sampleA_dragenmap_umihist.parquet"    
#> [8] "sampleA_dragenmap_umimain.parquet"    
```
