# Interop Object

Parses and tidies Illumina InterOp run-QC summaries. Not a DRAGEN
output, so it inherits
[nemo::Tool](https://tidywf.github.io/nemo/reference/Tool.html) rather
than
[DragenTool](https://tidywf.github.io/tidydragen/dev/reference/DragenTool.md);
housed here since it's typically co-located with BCLConvert outputs.

## Super class

[`nemo::Tool`](https://tidywf.github.io/nemo/reference/Tool.html) -\>
`Interop`

## Methods

### Public methods

- [`Interop$new()`](#method-Interop-new)

- [`Interop$parse_summary()`](#method-Interop-parse_summary)

- [`Interop$tidy_summary()`](#method-Interop-tidy_summary)

- [`Interop$parse_indexsummary()`](#method-Interop-parse_indexsummary)

- [`Interop$tidy_indexsummary()`](#method-Interop-tidy_indexsummary)

- [`Interop$parse_imagingtable()`](#method-Interop-parse_imagingtable)

- [`Interop$tidy_imagingtable()`](#method-Interop-tidy_imagingtable)

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

Create a new Interop object.

#### Usage

    Interop$new(path = NULL, files_tbl = NULL)

#### Arguments

- `path`:

  (`character(1)`)  
  Output directory of tool. If `files_tbl` is supplied, this is ignored.

- `files_tbl`:

  (`tibble(n)`)  
  Tibble of files from
  [`nemo::list_files_dir()`](https://tidywf.github.io/nemo/reference/list_files_dir.html).

------------------------------------------------------------------------

### Method `parse_summary()`

Parse `<run>_summary.csv` into a one-row list-column tibble.

#### Usage

    Interop$parse_summary(x)

#### Arguments

- `x`:

  (`character(1)`)  
  Path to file.

------------------------------------------------------------------------

### Method `tidy_summary()`

Tidy `<run>_summary.csv`.

#### Usage

    Interop$tidy_summary(x)

#### Arguments

- `x`:

  (`character(1)` or `tibble()`)  
  Path to file or parsed tibble.

------------------------------------------------------------------------

### Method `parse_indexsummary()`

Parse `<run>-index_summary.csv` into a one-row list-column tibble.

#### Usage

    Interop$parse_indexsummary(x)

#### Arguments

- `x`:

  (`character(1)`)  
  Path to file.

------------------------------------------------------------------------

### Method `tidy_indexsummary()`

Tidy `<run>-index_summary.csv`.

#### Usage

    Interop$tidy_indexsummary(x)

#### Arguments

- `x`:

  (`character(1)` or `tibble()`)  
  Path to file or parsed tibble.

------------------------------------------------------------------------

### Method `parse_imagingtable()`

Parse `imaging_table.csv[.gz]` positionally, skipping its header:
grouped columns (e.g. `Corrected<A;C;G;T>`) have one label for 4 data
columns.

#### Usage

    Interop$parse_imagingtable(x)

#### Arguments

- `x`:

  (`character(1)`)  
  Path to file.

------------------------------------------------------------------------

### Method `tidy_imagingtable()`

Tidy `imaging_table.csv[.gz]`.

#### Usage

    Interop$tidy_imagingtable(x)

#### Arguments

- `x`:

  (`character(1)` or `tibble()`)  
  Path to file or parsed tibble.

## Examples

``` r
cls <- Interop; tool <- "interop"
# imaging_tables/ holds a .csv and a .csv.gz copy, so its run also
# exercises nemo's `_2` same-table disambiguation.
odir <- tempdir()
obj_sum <- cls$new(system.file("extdata", tool, "summaries", package = "tidydragen"))
obj_sum$run(output_dir = odir, format = "parquet", input_id = "run1")
obj_it <- cls$new(system.file("extdata", tool, "imaging_tables", package = "tidydragen"))
obj_it$run(output_dir = odir, format = "parquet", input_id = "run1")
(lf <- list.files(odir, pattern = "interop_.*parquet", full.names = FALSE))
#> [1] "interop_imagingtable.parquet"           
#> [2] "interop_imagingtable_2.parquet"         
#> [3] "runA_interop_indexsummarydetail.parquet"
#> [4] "runA_interop_indexsummarymain.parquet"  
#> [5] "runA_interop_summarymain.parquet"       
#> [6] "runA_interop_summaryreadlane.parquet"   
```
