# DragenTso Object

Parses and tidies the TSO500 ctDNA (cttsov2) app-layer outputs that sit
alongside the DRAGEN metrics files: the CombinedVariantOutput small
variants, DNA fusions, TMB trace / MSAF, and per-exon / per-gene
coverage reports.

These files appear in both `Results/<sample>/` and a
`Logs_Intermediates/` subdirectory (byte-identical). nemo matches on
bname only, so the two copies would collide; `refine_files()` keeps the
`Results/` copy.

## Super classes

[`nemo::Tool`](https://tidywf.github.io/nemo/reference/Tool.html) -\>
[`tidydragen::DragenTool`](https://tidywf.github.io/tidydragen/reference/DragenTool.md)
-\> `DragenTso`

## Public fields

- `flat_tidy_names`:

  (`logical(1)`)  
  `TRUE`: outputs are named `<tool>_<table>` directly.

## Methods

### Public methods

- [`DragenTso$new()`](#method-DragenTso-new)

- [`DragenTso$parse_smallvariants()`](#method-DragenTso-parse_smallvariants)

- [`DragenTso$parse_fusions()`](#method-DragenTso-parse_fusions)

- [`DragenTso$parse_sarmain()`](#method-DragenTso-parse_sarmain)

- [`DragenTso$tidy_sarmain()`](#method-DragenTso-tidy_sarmain)

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

Parse only the `[Small Variants]` section of a
`CombinedVariantOutput.tsv` file, dropping the rest (sourced from the
SAR JSON instead).

#### Usage

    DragenTso$parse_smallvariants(x)

#### Arguments

- `x`:

  (`character(1)`)  
  Path to file.

------------------------------------------------------------------------

### Method `parse_fusions()`

Parse a `Fusions.csv` file (comment-prefixed header block, then a CSV
table; may hold zero data rows).

#### Usage

    DragenTso$parse_fusions(x)

#### Arguments

- `x`:

  (`character(1)`)  
  Path to file.

------------------------------------------------------------------------

### Method `parse_sarmain()`

Parse a `SampleAnalysisResults.json` file; returns its `data` block
wrapped in a one-row tibble list-column. `tidy_sarmain()` fans it out.

#### Usage

    DragenTso$parse_sarmain(x)

#### Arguments

- `x`:

  (`character(1)`)  
  Path to file.

------------------------------------------------------------------------

### Method `tidy_sarmain()`

Fan a `SampleAnalysisResults.json` `data` block into seven tables:
`sarmain` (sample + library info), `sarqc` (QC + expanded metrics +
TMB/MSI biomarkers, wide), `sarqcthr` (QC metrics with LSL/USL
thresholds, long), `sarswds` (Nirvana data sources), `sarsw` (software +
Nirvana config), `sarsnv` (per-transcript small variants), `sarcnv`
(CNVs).

#### Usage

    DragenTso$tidy_sarmain(x)

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
