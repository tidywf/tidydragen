# DragenBcl Object

Parses and tidies DRAGEN BCLConvert demultiplexing outputs from a
`Reports/` directory. Most tables are plain header CSVs handled by the
nemo `csv` ftype.

## Super classes

[`nemo::Tool`](https://tidywf.github.io/nemo/reference/Tool.html) -\>
[`tidydragen::DragenTool`](https://tidywf.github.io/tidydragen/reference/DragenTool.md)
-\> `DragenBcl`

## Methods

### Public methods

- [`DragenBcl$new()`](#method-DragenBcl-new)

- [`DragenBcl$parse_demultiplexstats()`](#method-DragenBcl-parse_demultiplexstats)

- [`DragenBcl$parse_demultiplextilestats()`](#method-DragenBcl-parse_demultiplextilestats)

- [`DragenBcl$parse_fastqlist()`](#method-DragenBcl-parse_fastqlist)

- [`DragenBcl$parse_runinfo()`](#method-DragenBcl-parse_runinfo)

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

Create a new DragenBcl object.

#### Usage

    DragenBcl$new(path = NULL, files_tbl = NULL)

#### Arguments

- `path`:

  (`character(1)`)  
  Path to a BCLConvert `Reports/` directory. If `files_tbl` is supplied,
  this is ignored.

- `files_tbl`:

  (`tibble(n)`)  
  Tibble of files from
  [`nemo::list_files_dir()`](https://tidywf.github.io/nemo/reference/list_files_dir.html).

------------------------------------------------------------------------

### Method `parse_demultiplexstats()`

Parse Demultiplex_Stats.csv (splits combined `Index`).

#### Usage

    DragenBcl$parse_demultiplexstats(x)

#### Arguments

- `x`:

  (`character(1)`)  
  Path to Demultiplex_Stats.csv.

------------------------------------------------------------------------

### Method `parse_demultiplextilestats()`

Parse Demultiplex_Tile_Stats.csv (splits combined `Index`).

#### Usage

    DragenBcl$parse_demultiplextilestats(x)

#### Arguments

- `x`:

  (`character(1)`)  
  Path to Demultiplex_Tile_Stats.csv.

------------------------------------------------------------------------

### Method `parse_fastqlist()`

Parse fastq_list.csv (pivots Read1File/Read2File long).

#### Usage

    DragenBcl$parse_fastqlist(x)

#### Arguments

- `x`:

  (`character(1)`)  
  Path to fastq_list.csv.

------------------------------------------------------------------------

### Method `parse_runinfo()`

Parse RunInfo.xml into a one-row run-metadata table.

#### Usage

    DragenBcl$parse_runinfo(x)

#### Arguments

- `x`:

  (`character(1)`)  
  Path to RunInfo.xml.

## Examples

``` r
cls <- DragenBcl; tool <- "dragenbcl"
indir <- system.file("extdata", tool, package = "tidydragen")
odir <- tempdir()
obj <- cls$new(indir)
obj$run(output_dir = odir, format = "parquet", input_id = "run1", output_id = "out1")
(lf <- list.files(odir, pattern = "dragenbcl_.*parquet", full.names = FALSE))
#>  [1] "dragenbcl_adaptercyclemetrics.parquet" 
#>  [2] "dragenbcl_adaptermetrics.parquet"      
#>  [3] "dragenbcl_demultiplexstats.parquet"    
#>  [4] "dragenbcl_demultiplextilestats.parquet"
#>  [5] "dragenbcl_fastqlist.parquet"           
#>  [6] "dragenbcl_indexhoppingcounts.parquet"  
#>  [7] "dragenbcl_qualitymetrics.parquet"      
#>  [8] "dragenbcl_qualitytilemetrics.parquet"  
#>  [9] "dragenbcl_runinfo.parquet"             
#> [10] "dragenbcl_topunknownbarcodes.parquet"  
```
