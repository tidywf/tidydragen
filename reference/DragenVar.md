# DragenVar Object

Parses and tidies DRAGEN variant-related metric outputs (variant caller,
SV, CNV, ploidy, TMB, HRD, etc.).

## Super classes

[`nemo::Tool`](https://tidywf.github.io/nemo/reference/Tool.html) -\>
[`tidydragen::DragenTool`](https://tidywf.github.io/tidydragen/reference/DragenTool.md)
-\> `DragenVar`

## Public fields

- `flat_tidy_names`:

  (`logical(1)`)  
  `TRUE`: fan-out sub-tables are named `<tool>_<tidy_name>` (parser
  token dropped). Needed for the `ploidymain`/`ploidyratio` split.

## Methods

### Public methods

- [`DragenVar$new()`](#method-DragenVar-new)

- [`DragenVar$tidy_vc()`](#method-DragenVar-tidy_vc)

- [`DragenVar$tidy_gvcf()`](#method-DragenVar-tidy_gvcf)

- [`DragenVar$tidy_cnv()`](#method-DragenVar-tidy_cnv)

- [`DragenVar$tidy_hethom()`](#method-DragenVar-tidy_hethom)

- [`DragenVar$tidy_ploidymain()`](#method-DragenVar-tidy_ploidymain)

- [`DragenVar$tidy_nuctrans()`](#method-DragenVar-tidy_nuctrans)

- [`DragenVar$parse_microsat()`](#method-DragenVar-parse_microsat)

- [`DragenVar$parse_contamination()`](#method-DragenVar-parse_contamination)

- [`DragenVar$parse_ploidyvcf()`](#method-DragenVar-parse_ploidyvcf)

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

Create a new DragenVar object.

#### Usage

    DragenVar$new(path = NULL, files_tbl = NULL)

#### Arguments

- `path`:

  (`character(1)`)  
  Output directory of tool. If `files_tbl` is supplied, this is ignored.

- `files_tbl`:

  (`tibble(n)`)  
  Tibble of files from
  [`nemo::list_files_dir()`](https://tidywf.github.io/nemo/reference/list_files_dir.html).

------------------------------------------------------------------------

### Method `tidy_vc()`

Tidy `vc_metrics.csv`. `rg` (sample id) kept raw; region moved from
metric names into a `region` column.

#### Usage

    DragenVar$tidy_vc(x)

#### Arguments

- `x`:

  (`character(1)` or `tibble()`)  
  Path to file or parsed tibble.

------------------------------------------------------------------------

### Method `tidy_gvcf()`

Tidy `gvcf_metrics.csv` (gVCF postfilter). Same shape as `vc_metrics`;
region moved into a `region` column.

#### Usage

    DragenVar$tidy_gvcf(x)

#### Arguments

- `x`:

  (`character(1)` or `tibble()`)  
  Path to file or parsed tibble.

------------------------------------------------------------------------

### Method `tidy_cnv()`

Tidy `cnv_metrics.csv`.

#### Usage

    DragenVar$tidy_cnv(x)

#### Arguments

- `x`:

  (`character(1)` or `tibble()`)  
  Path to file or parsed tibble.

------------------------------------------------------------------------

### Method `tidy_hethom()`

Tidy `vc_hethom_ratio_metrics.csv`.

#### Usage

    DragenVar$tidy_hethom(x)

#### Arguments

- `x`:

  (`character(1)` or `tibble()`)  
  Path to file or parsed tibble.

------------------------------------------------------------------------

### Method `tidy_ploidymain()`

Tidy `ploidy_estimation_metrics.csv` into `ploidymain` (sample scalars)
and `ploidyratio` (long, one row per chromosome ratio).

#### Usage

    DragenVar$tidy_ploidymain(x)

#### Arguments

- `x`:

  (`character(1)` or `tibble()`)  
  Path to file or parsed tibble.

------------------------------------------------------------------------

### Method `tidy_nuctrans()`

Tidy `allele_transition_noise_metrics.csv`

#### Usage

    DragenVar$tidy_nuctrans(x)

#### Arguments

- `x`:

  (`character(1)` or `tibble()`)  
  Path to file or parsed tibble.

------------------------------------------------------------------------

### Method `parse_microsat()`

Parse `microsat_output.json` (MSI).

#### Usage

    DragenVar$parse_microsat(x)

#### Arguments

- `x`:

  (`character(1)`)  
  Path to file.

------------------------------------------------------------------------

### Method `parse_contamination()`

Parse `contamination.json` (cttso cross-sample contamination). Flat
JSON; the per-SNP `SNPsUsed` array is dropped, `NaN` p-value -\> NA.

#### Usage

    DragenVar$parse_contamination(x)

#### Arguments

- `x`:

  (`character(1)`)  
  Path to file.

------------------------------------------------------------------------

### Method `parse_ploidyvcf()`

Parse `ploidy.vcf.gz` depth-of-coverage `dc` and normalised depth `ndc`.

#### Usage

    DragenVar$parse_ploidyvcf(x)

#### Arguments

- `x`:

  (`character(1)`)  
  Path to file.

## Examples

``` r
cls <- DragenVar; tool <- "dragenvar"
indir <- system.file("extdata", tool, package = "tidydragen")
odir <- tempdir()
obj <- cls$new(indir)
obj$run(output_dir = odir, format = "parquet", input_id = "run1")
(lf <- list.files(odir, pattern = "dragenvar_.*parquet", full.names = FALSE))
#>  [1] "sampleA_dragenvar_cnv.parquet"          
#>  [2] "sampleA_dragenvar_contamination.parquet"
#>  [3] "sampleA_dragenvar_gvcf.parquet"         
#>  [4] "sampleA_dragenvar_hethom.parquet"       
#>  [5] "sampleA_dragenvar_hrd.parquet"          
#>  [6] "sampleA_dragenvar_microsat.parquet"     
#>  [7] "sampleA_dragenvar_nuctrans.parquet"     
#>  [8] "sampleA_dragenvar_ploidymain.parquet"   
#>  [9] "sampleA_dragenvar_ploidyratio.parquet"  
#> [10] "sampleA_dragenvar_ploidyvcf.parquet"    
#> [11] "sampleA_dragenvar_sv.parquet"           
#> [12] "sampleA_dragenvar_tmb.parquet"          
#> [13] "sampleA_dragenvar_vc.parquet"           
#> [14] "sampleB_dragenvar_cnv.parquet"          
#> [15] "sampleB_dragenvar_ploidymain.parquet"   
#> [16] "sampleB_dragenvar_ploidyratio.parquet"  
#> [17] "sampleB_dragenvar_vc.parquet"           
```
