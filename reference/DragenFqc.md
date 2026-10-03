# DragenFqc Object

Parses and tidies the DRAGEN FASTQC metrics file (`fastqc_metrics.csv`).
Splits into 8 per-section sub-tables. Setting `flat_tidy_names = TRUE`
gives flat `dragenfqc_<section>` tables rather than the concatenated
form.

## Super classes

[`nemo::Tool`](https://tidywf.github.io/nemo/reference/Tool.html) -\>
[`tidydragen::DragenTool`](https://tidywf.github.io/tidydragen/reference/DragenTool.md)
-\> `DragenFqc`

## Public fields

- `flat_tidy_names`:

  (`logical(1)`)  
  drop the parser token so the 8 sub-tables are named
  `dragenfqc_<section>` (see
  [nemo::Tool](https://tidywf.github.io/nemo/reference/Tool.html)).

## Methods

### Public methods

- [`DragenFqc$new()`](#method-DragenFqc-new)

- [`DragenFqc$parse_posbasecontent()`](#method-DragenFqc-parse_posbasecontent)

- [`DragenFqc$tidy_posbasecontent()`](#method-DragenFqc-tidy_posbasecontent)

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

Create a new DragenFqc object.

#### Usage

    DragenFqc$new(path = NULL, files_tbl = NULL)

#### Arguments

- `path`:

  (`character(1)`)  
  Output directory of tool. If `files_tbl` is supplied, this is ignored.

- `files_tbl`:

  (`tibble(n)`)  
  Tibble of files from
  [`nemo::list_files_dir()`](https://tidywf.github.io/nemo/reference/list_files_dir.html).

------------------------------------------------------------------------

### Method `parse_posbasecontent()`

Parse headerless `section,mate,metric,value` `fastqc_metrics.csv` into a
long tibble.

#### Usage

    DragenFqc$parse_posbasecontent(x)

#### Arguments

- `x`:

  (`character(1)`)  
  Path to file.

------------------------------------------------------------------------

### Method `tidy_posbasecontent()`

Tidy `fastqc_metrics.csv` into 8 long per-section sub-tables.

#### Usage

    DragenFqc$tidy_posbasecontent(x)

#### Arguments

- `x`:

  (`character(1)` or `tibble()`)  
  Path to file or parsed tibble.

## Examples

``` r
cls <- DragenFqc; tool <- "dragenfqc"
indir <- system.file("extdata", tool, package = "tidydragen")
odir <- tempdir()
obj <- cls$new(indir)
obj$run(output_dir = odir, format = "parquet", input_id = "run1")
(lf <- list.files(odir, pattern = "dragenfqc_.*parquet", full.names = FALSE))
#> [1] "sampleA_dragenfqc_posbasecontent.parquet" 
#> [2] "sampleA_dragenfqc_posbasemeanqual.parquet"
#> [3] "sampleA_dragenfqc_posqual.parquet"        
#> [4] "sampleA_dragenfqc_readgc.parquet"         
#> [5] "sampleA_dragenfqc_readgcqual.parquet"     
#> [6] "sampleA_dragenfqc_readlen.parquet"        
#> [7] "sampleA_dragenfqc_readmeanqual.parquet"   
#> [8] "sampleA_dragenfqc_seqpos.parquet"         
```
