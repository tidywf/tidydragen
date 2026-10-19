# DragenTso Object

Parses and tidies TSO500 ctDNA (cttsov2) app-layer outputs.

These files are duplicated under `Results/` and `Logs_Intermediates/`;
`refine_files()` keeps the `Results/` copy.

## Super classes

[`nemo::Tool`](https://tidywf.github.io/nemo/reference/Tool.html) -\>
[`tidydragen::DragenTool`](https://tidywf.github.io/tidydragen/reference/DragenTool.md)
-\> `DragenTso`

## Methods

### Public methods

- [`DragenTso$new()`](#method-DragenTso-new)

- [`DragenTso$parse_smallvariants()`](#method-DragenTso-parse_smallvariants)

- [`DragenTso$parse_fusions()`](#method-DragenTso-parse_fusions)

- [`DragenTso$parse_sar()`](#method-DragenTso-parse_sar)

- [`DragenTso$tidy_sar()`](#method-DragenTso-tidy_sar)

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

Create a new DragenTso object.

#### Usage

    DragenTso$new(path = NULL, files_tbl = NULL)

#### Arguments

- `path`:

  (`character(1)`)  
  Output directory of tool. If `files_tbl` is supplied, this is ignored.

- `files_tbl`:

  (`tibble(n)`)  
  Tibble of files from
  [`nemo::list_files_dir()`](https://tidywf.github.io/nemo/reference/list_files_dir.html).

------------------------------------------------------------------------

### Method `parse_smallvariants()`

Parse the `[Small Variants]` section of `CombinedVariantOutput.tsv` (the
rest comes from the SAR JSON).

#### Usage

    DragenTso$parse_smallvariants(x)

#### Arguments

- `x`:

  (`character(1)`)  
  Path to file.

------------------------------------------------------------------------

### Method `parse_fusions()`

Parse `Fusions.csv`.

#### Usage

    DragenTso$parse_fusions(x)

#### Arguments

- `x`:

  (`character(1)`)  
  Path to file.

------------------------------------------------------------------------

### Method `parse_sar()`

Parse `SampleAnalysisResults.json` into a one-row list-column tibble.

#### Usage

    DragenTso$parse_sar(x)

#### Arguments

- `x`:

  (`character(1)`)  
  Path to file.

------------------------------------------------------------------------

### Method `tidy_sar()`

Tidy `SampleAnalysisResults.json`.

#### Usage

    DragenTso$tidy_sar(x)

#### Arguments

- `x`:

  (`character(1)` or `tibble()`)  
  Path to file or parsed tibble.

## Examples

``` r
cls <- DragenTso; tool <- "dragentso"
indir <- system.file("extdata", tool, package = "tidydragen")
odir <- tempdir()
obj <- cls$new(indir)
obj$run(output_dir = odir, format = "parquet", input_id = "run1")
(lf <- list.files(odir, pattern = "dragentso_.*parquet", full.names = FALSE))
#>  [1] "sampleA_dragentso_exoncov.parquet"      
#>  [2] "sampleA_dragentso_fusions.parquet"      
#>  [3] "sampleA_dragentso_genecov.parquet"      
#>  [4] "sampleA_dragentso_sarcnv.parquet"       
#>  [5] "sampleA_dragentso_sarmain.parquet"      
#>  [6] "sampleA_dragentso_sarqc.parquet"        
#>  [7] "sampleA_dragentso_sarqcthr.parquet"     
#>  [8] "sampleA_dragentso_sarsnv.parquet"       
#>  [9] "sampleA_dragentso_sarsw.parquet"        
#> [10] "sampleA_dragentso_sarswds.parquet"      
#> [11] "sampleA_dragentso_smallvariants.parquet"
#> [12] "sampleA_dragentso_tmbmsaf.parquet"      
#> [13] "sampleA_dragentso_tmbtrace.parquet"     
```
