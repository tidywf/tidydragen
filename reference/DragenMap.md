# DragenMap Object

Parses and tidies DRAGEN mapping/alignment outputs.

## Super classes

[`nemo::Tool`](https://tidywf.github.io/nemo/reference/Tool.html) -\>
[`tidydragen::DragenTool`](https://tidywf.github.io/tidydragen/reference/DragenTool.md)
-\> `DragenMap`

## Methods

### Public methods

- [`DragenMap$new()`](#method-DragenMap-new)

- [`DragenMap$tidy_metrics()`](#method-DragenMap-tidy_metrics)

- [`DragenMap$tidy_umi()`](#method-DragenMap-tidy_umi)

- [`DragenMap$tidy_gc()`](#method-DragenMap-tidy_gc)

- [`DragenMap$tidy_time()`](#method-DragenMap-tidy_time)

- [`DragenMap$parse_fraglenhist()`](#method-DragenMap-parse_fraglenhist)

- [`DragenMap$parse_replay()`](#method-DragenMap-parse_replay)

- [`DragenMap$tidy_replay()`](#method-DragenMap-tidy_replay)

Inherited methods

- [`nemo::Tool$filter_files()`](https://tidywf.github.io/nemo/reference/Tool.html#method-filter_files)
- [`nemo::Tool$get_globs()`](https://tidywf.github.io/nemo/reference/Tool.html#method-get_globs)
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

Tidy `mapping_metrics.csv`.

#### Usage

    DragenMap$tidy_metrics(x)

#### Arguments

- `x`:

  (`character(1)` or `tibble()`)  
  Path to file or parsed tibble.

------------------------------------------------------------------------

### Method `tidy_umi()`

Tidy `umi_metrics.csv`.

#### Usage

    DragenMap$tidy_umi(x)

#### Arguments

- `x`:

  (`character(1)` or `tibble()`)  
  Path to file or parsed tibble.

------------------------------------------------------------------------

### Method `tidy_gc()`

Tidy `gc_metrics.csv`.

#### Usage

    DragenMap$tidy_gc(x)

#### Arguments

- `x`:

  (`character(1)` or `tibble()`)  
  Path to file or parsed tibble.

------------------------------------------------------------------------

### Method `tidy_time()`

Tidy `time_metrics.csv`.

#### Usage

    DragenMap$tidy_time(x)

#### Arguments

- `x`:

  (`character(1)` or `tibble()`)  
  Path to file or parsed tibble.

------------------------------------------------------------------------

### Method `parse_fraglenhist()`

Parse `fragment_length_hist.csv`.

#### Usage

    DragenMap$parse_fraglenhist(x)

#### Arguments

- `x`:

  (`character(1)`)  
  Path to file.

------------------------------------------------------------------------

### Method `parse_replay()`

Parse `replay.json` into a one-row list-column tibble.

#### Usage

    DragenMap$parse_replay(x)

#### Arguments

- `x`:

  (`character(1)`)  
  Path to file.

------------------------------------------------------------------------

### Method `tidy_replay()`

Tidy `replay.json`.

#### Usage

    DragenMap$tidy_replay(x)

#### Arguments

- `x`:

  (`character(1)` or `tibble()`)  
  Path to file or parsed tibble.

## Examples

``` r
cls <- DragenMap; tool <- "dragenmap"
indir <- system.file("extdata", tool, package = "tidydragen")
odir <- tempdir()
obj <- cls$new(indir)
obj$run(output_dir = odir, format = "parquet", input_id = "run1")
(lf <- list.files(odir, pattern = "dragenmap_.*parquet", full.names = FALSE))
#>  [1] "sampleA_dragenmap_fraglenhist.parquet"   
#>  [2] "sampleA_dragenmap_gcbias.parquet"        
#>  [3] "sampleA_dragenmap_gcmain.parquet"        
#>  [4] "sampleA_dragenmap_metrics.parquet"       
#>  [5] "sampleA_dragenmap_replayconfig.parquet"  
#>  [6] "sampleA_dragenmap_replaymain.parquet"    
#>  [7] "sampleA_dragenmap_time.parquet"          
#>  [8] "sampleA_dragenmap_trimmer.parquet"       
#>  [9] "sampleA_dragenmap_umihist.parquet"       
#> [10] "sampleA_dragenmap_umimain.parquet"       
#> [11] "sampleB_2_dragenmap_replayconfig.parquet"
#> [12] "sampleB_2_dragenmap_replaymain.parquet"  
#> [13] "sampleB_2_dragenmap_time.parquet"        
#> [14] "sampleB_dragenmap_replayconfig.parquet"  
#> [15] "sampleB_dragenmap_replaymain.parquet"    
#> [16] "sampleB_dragenmap_time.parquet"          
```
