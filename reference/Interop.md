# Interop Object

Parses and tidies Illumina InterOp run-QC summary outputs:
`<run>_summary.csv` (per-read/lane/surface run metrics),
`<run>-index_summary.csv` (per-lane/index demux QC), and
`imaging_table.csv`/`imaging_table.csv.gz` (per-lane/tile/cycle imaging
metrics; gzipped or not, both accepted). InterOp is Illumina run-level
QC, not a DRAGEN output, so unlike the other tools this one inherits
[`nemo::Tool`](https://tidywf.github.io/nemo/reference/Tool.html)
directly rather than the DRAGEN-shared `DragenTool` base; it's housed
here for convenience (typically co-located with BCLConvert). The run id
for `summary.csv`/`index_summary.csv` lives in the filename itself, so
the usual prefix extraction just works with no `refine_files()` override
needed there; `imaging_table.csv[.gz]` carries no run id in its filename
at all, so that one is handled explicitly.

## Super class

[`nemo::Tool`](https://tidywf.github.io/nemo/reference/Tool.html) -\>
`Interop`

## Public fields

- `flat_tidy_names`:

  (`logical(1)`)  
  `TRUE`: fan-out sub-tables are named `<tool>_<tidy_name>` (parser
  token dropped). Needed for the `summarymain`/`summaryreadlane` and
  `indexsummarymain`/`indexsummarydetail` splits.

## Methods

### Public methods

- [`Interop$new()`](#method-Interop-new)

- [`Interop$parse_summarymain()`](#method-Interop-parse_summarymain)

- [`Interop$tidy_summarymain()`](#method-Interop-tidy_summarymain)

- [`Interop$parse_indexsummarymain()`](#method-Interop-parse_indexsummarymain)

- [`Interop$tidy_indexsummarymain()`](#method-Interop-tidy_indexsummarymain)

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

### Method `parse_summarymain()`

Parse `<run>_summary.csv`; returns the raw level table and the raw
per-read/lane/surface table (both still character), wrapped in a one-row
tibble list-column. `tidy_summarymain()` types and splits them.

#### Usage

    Interop$parse_summarymain(x)

#### Arguments

- `x`:

  (`character(1)`)  
  Path to file.

------------------------------------------------------------------------

### Method `tidy_summarymain()`

Fan `<run>_summary.csv` into `summarymain` (level table, wide, 6 rows)
and `summaryreadlane` (per-read/lane/surface detail, long).
`"nan"`/`"-"` sentinel values -\> NA throughout; `"mean +/- sd"` and
`"a / b"` cells are split into paired columns.

#### Usage

    Interop$tidy_summarymain(x)

#### Arguments

- `x`:

  (`character(1)` or `tibble()`)  
  Path to file or parsed tibble.

------------------------------------------------------------------------

### Method `parse_indexsummarymain()`

Parse `<run>-index_summary.csv`; returns the raw per-lane totals and the
raw per-index table (both still character), wrapped in a one-row tibble
list-column. `tidy_indexsummarymain()` types them.

#### Usage

    Interop$parse_indexsummarymain(x)

#### Arguments

- `x`:

  (`character(1)`)  
  Path to file.

------------------------------------------------------------------------

### Method `tidy_indexsummarymain()`

Fan `<run>-index_summary.csv` into `indexsummarymain` (per-lane totals,
wide) and `indexsummarydetail` (per-index rows, long).

#### Usage

    Interop$tidy_indexsummarymain(x)

#### Arguments

- `x`:

  (`character(1)` or `tibble()`)  
  Path to file or parsed tibble.

------------------------------------------------------------------------

### Method `parse_imagingtable()`

Parse `imaging_table.csv`/`imaging_table.csv.gz` (`readr` decompresses
`.gz` transparently by extension — no branching needed here). Its header
is unreliable for grouped columns (e.g. `"Corrected<A;C;G;T>"` prints
one label but is followed by 4 data columns), so this bypasses the
header entirely (`skip = 3`, past the 2 `#` comment lines + the header
row) and reads 49 positional character columns; `"nan"` -\> `NA` at
parse time so `tidy_imagingtable()`'s `type_convert()` yields `NA`, not
`NaN`.

#### Usage

    Interop$parse_imagingtable(x)

#### Arguments

- `x`:

  (`character(1)`)  
  Path to file.

------------------------------------------------------------------------

### Method `tidy_imagingtable()`

Type `imaging_table.csv[.gz]`'s 49 positional columns via the schema
(rename + `type_convert()`); no fan-out, one flat table.

#### Usage

    Interop$tidy_imagingtable(x)

#### Arguments

- `x`:

  (`character(1)` or `tibble()`)  
  Path to file or parsed tibble.

## Examples

``` r
cls <- Interop; tool <- "interop"
# summaries/ kept separate from imaging_tables/ so scanning for one never
# also matches the other (list_files_dir() recurses; `imaging_table.csv`
# and `.csv.gz` both match the imagingtable pattern, so a single run over
# imaging_tables/ picks up BOTH compressed/ and uncompressed/ at once and
# nemo's generic same-table collision handling disambiguates them, `_2`
# suffix --- exercised deliberately below, not avoided).
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
