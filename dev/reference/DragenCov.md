# DragenCov Object

Parses and tidies DRAGEN coverage outputs.

The coverage region (`wgs` / `tmb` /`qc-coverage-region-{<region>}`) and
phenotype (`normal` / `tumor`) are folded from the filename into the
output `prefix` by `DragenTool`'s `refine_files()` hook, so one schema
table serves every region/phenotype variant.

## Super classes

[`nemo::Tool`](https://tidywf.github.io/nemo/reference/Tool.html) -\>
[`tidydragen::DragenTool`](https://tidywf.github.io/tidydragen/dev/reference/DragenTool.md)
-\> `DragenCov`

## Methods

### Public methods

- [`DragenCov$new()`](#method-DragenCov-new)

- [`DragenCov$tidy_covmetrics()`](#method-DragenCov-tidy_covmetrics)

- [`DragenCov$parse_finehist()`](#method-DragenCov-parse_finehist)

- [`DragenCov$parse_reportbed()`](#method-DragenCov-parse_reportbed)

- [`DragenCov$tidy_reportbed()`](#method-DragenCov-tidy_reportbed)

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

Create a new DragenCov object.

#### Usage

    DragenCov$new(path = NULL, files_tbl = NULL)

#### Arguments

- `path`:

  (`character(1)`)  
  Output directory of tool. If `files_tbl` is supplied, this is ignored.

- `files_tbl`:

  (`tibble(n)`)  
  Tibble of files from
  [`nemo::list_files_dir()`](https://tidywf.github.io/nemo/reference/list_files_dir.html).

------------------------------------------------------------------------

### Method `tidy_covmetrics()`

Tidy `*_coverage_metrics.csv`.

#### Usage

    DragenCov$tidy_covmetrics(x)

#### Arguments

- `x`:

  (`character(1)` or `tibble()`)  
  Path to file or parsed tibble.

------------------------------------------------------------------------

### Method `parse_finehist()`

Parse `*_fine_hist.csv`.

#### Usage

    DragenCov$parse_finehist(x)

#### Arguments

- `x`:

  (`character(1)`)  
  Path to file.

------------------------------------------------------------------------

### Method `parse_reportbed()`

Parse `*_cov_report.bed`.

#### Usage

    DragenCov$parse_reportbed(x)

#### Arguments

- `x`:

  (`character(1)`)  
  Path to file.

------------------------------------------------------------------------

### Method `tidy_reportbed()`

Tidy `*_cov_report.bed`.

#### Usage

    DragenCov$tidy_reportbed(x)

#### Arguments

- `x`:

  (`character(1)` or `tibble()`)  
  Path to file or parsed tibble.

## Examples

``` r
cls <- DragenCov; tool <- "dragencov"
indir <- system.file("extdata", tool, package = "tidydragen")
odir <- tempdir()
obj <- cls$new(indir)
obj$run(output_dir = odir, format = "parquet", input_id = "run1")
(lf <- list.files(odir, pattern = "dragencov_.*parquet", full.names = FALSE))
#>  [1] "sampleA_exon_dragencov_metricsbins.parquet"      
#>  [2] "sampleA_exon_dragencov_metricscumu.parquet"      
#>  [3] "sampleA_exon_dragencov_metricsmain.parquet"      
#>  [4] "sampleA_target_bed_dragencov_metricsbins.parquet"
#>  [5] "sampleA_target_bed_dragencov_metricscumu.parquet"
#>  [6] "sampleA_target_bed_dragencov_metricsmain.parquet"
#>  [7] "sampleA_umccr_dragencov_readreportbed.parquet"   
#>  [8] "sampleA_umccr_dragencov_reportbedcumu.parquet"   
#>  [9] "sampleA_umccr_dragencov_reportbedmain.parquet"   
#> [10] "sampleA_wgs_dragencov_contigmean.parquet"        
#> [11] "sampleA_wgs_dragencov_finehist.parquet"          
#> [12] "sampleA_wgs_dragencov_metricsbins.parquet"       
#> [13] "sampleA_wgs_dragencov_metricscumu.parquet"       
#> [14] "sampleA_wgs_dragencov_metricsmain.parquet"       
#> [15] "sampleA_wgs_normal_dragencov_contigmean.parquet" 
#> [16] "sampleA_wgs_tumor_dragencov_contigmean.parquet"  
```
