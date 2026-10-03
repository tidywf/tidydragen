# DragenCov Object

Parses and tidies DRAGEN coverage outputs (per-contig mean coverage,
coverage metrics, fine histograms, and coverage-report BEDs). Some files
fan out into multiple output tables: `tidy_metricsmain` splits the
coverage metrics into `metricsmain`/`metricsbins`/`metricscumu`, and
`tidy_reportbedmain` splits the coverage-report BED into
`reportbedmain`/`reportbedcumu`. Every other table has
`tidy_name == parser`, so its name is unchanged. The per-method docs
below cover each table's specifics.

The coverage region (`wgs` / `tmb` /`qc-coverage-region-{<region>}`) and
phenotype (`normal` / `tumor`) are folded from the filename into the
output `prefix` by `DragenTool`'s `refine_files()` hook, so one schema
table serves every region/phenotype variant.

## Super classes

[`nemo::Tool`](https://tidywf.github.io/nemo/reference/Tool.html) -\>
[`tidydragen::DragenTool`](https://tidywf.github.io/tidydragen/reference/DragenTool.md)
-\> `DragenCov`

## Public fields

- `flat_tidy_names`:

  (`logical(1)`)  
  `TRUE`: fanned-out sub-tables are named `<tool>_<tidy_name>` directly
  (parser token dropped), so each sub-table's `name` is its final output
  table. See the class description for the fan-out map.

## Methods

### Public methods

- [`DragenCov$new()`](#method-DragenCov-new)

- [`DragenCov$tidy_metricsmain()`](#method-DragenCov-tidy_metricsmain)

- [`DragenCov$parse_finehist()`](#method-DragenCov-parse_finehist)

- [`DragenCov$parse_reportbedmain()`](#method-DragenCov-parse_reportbedmain)

- [`DragenCov$tidy_reportbedmain()`](#method-DragenCov-tidy_reportbedmain)

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

### Method `tidy_metricsmain()`

Tidy `*_coverage_metrics.csv` into `metricsmain` (wide summary),
`metricsbins` (bucketed depth histogram), and `metricscumu`
(cumulative).

#### Usage

    DragenCov$tidy_metricsmain(x)

#### Arguments

- `x`:

  (`character(1)` or `tibble()`)  
  Path to file or parsed tibble.

------------------------------------------------------------------------

### Method `parse_finehist()`

Parse `*_fine_hist.csv`, returning `depth` as an integer.

#### Usage

    DragenCov$parse_finehist(x)

#### Arguments

- `x`:

  (`character(1)`)  
  Path to file.

------------------------------------------------------------------------

### Method `parse_reportbedmain()`

Parse `*_cov_report.bed`; `tidy_reportbedmain()` types and splits it.

#### Usage

    DragenCov$parse_reportbedmain(x)

#### Arguments

- `x`:

  (`character(1)`)  
  Path to file.

------------------------------------------------------------------------

### Method `tidy_reportbedmain()`

Tidy `*_cov_report.bed` into `reportbedmain` (per-interval distribution
stats, wide) and `reportbedcumu` (coverage thresholds, long).

#### Usage

    DragenCov$tidy_reportbedmain(x)

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
