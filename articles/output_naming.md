# Output Naming

When the same sample is processed more than once (e.g. repeat runs of a
tool over different dates), you end up with several sets of raw outputs
that share identical file names but live under different parent folders.
Here we show:

- how tidy outputs are named so that repeated runs avoid overwriting
  each other
- how to carry a run identifier into the data so the runs are still
  distinguishable once the files have been merged into a merged parquet
  dataset or database.

## Anatomy of a tidy filename

Every tidy file is named:

    {output_dir}/{prefix}_{tool}_{parser}.{ext}

- `{output_dir}`: the directory to output the tidy files in a flat
  structure.
- `{prefix}`: the input file’s basename with the table’s schema
  `pattern` stripped off. For `sampleA.tool1.table1.tsv` the `table1`
  pattern (`\.tool1\.table1\.tsv$`) is removed, leaving `sampleA`.
- `{tool}_{parser}`: the tool name and the matched table
  (e.g. `tool1_table1`).
- `{ext}`: driven by `format` (parquet, db, tsv, csv or rds).

So `sampleA.tool1.table1.tsv` tidied in parquet format becomes
`sampleA_tool1_table1.parquet`.

## A repeated sample

Let us simulate three runs of the same sample by copying one tool’s
outputs into separate folders. Each run holds the same files:

``` r

src <- system.file("extdata/tool1/latest", package = "nemo")
dir1 <- path(tempdir(), "naming-demo")
dir_runs <- path(dir1, "runs")
run_ids <- c("run1", "run2", "run3")

for (r in run_ids) {
  dest <- dir_create(path(dir_runs, r))
  file_copy(dir_ls(src, regexp = "table[12]\\.tsv$"), dest, overwrite = TRUE)
}

dir_tree(dir_runs)
#> /tmp/Rtmpix6eRO/naming-demo/runs
#> ├── run1
#> │   ├── sampleA.tool1.table1.tsv
#> │   └── sampleA.tool1.table2.tsv
#> ├── run2
#> │   ├── sampleA.tool1.table1.tsv
#> │   └── sampleA.tool1.table2.tsv
#> └── run3
#>     ├── sampleA.tool1.table1.tsv
#>     └── sampleA.tool1.table2.tsv
```

### Mode A: one recursive tidy

Point a single `Tool1` at the *parent* of the run folders.
`list_files()` recurses into all three and, because the basenames
collide, appends `_2` / `_3` to disambiguate the prefixes:

``` r

tool <- Tool1$new(path = dir_runs)
tool$list_files() |>
  dplyr::select(bname, parser, prefix)
#> # A tibble: 6 × 3
#>   bname                    parser prefix   
#>   <chr>                    <chr>  <chr>    
#> 1 sampleA.tool1.table1.tsv table1 sampleA  
#> 2 sampleA.tool1.table1.tsv table1 sampleA_2
#> 3 sampleA.tool1.table1.tsv table1 sampleA_3
#> 4 sampleA.tool1.table2.tsv table2 sampleA  
#> 5 sampleA.tool1.table2.tsv table2 sampleA_2
#> 6 sampleA.tool1.table2.tsv table2 sampleA_3
```

As you can see, the files share a basename but get prefixes `sampleA`,
`sampleA_2`, `sampleA_3`. Writing them out, nothing gets overwritten:

``` r

dir_outA <- dir_create(path(dir1, "outA"))
tool$run(
  input_id = "input1",
  output_dir = dir_outA,
  format = "parquet",
  prefix_include = TRUE
)

dir_tree(dir_outA)
#> /tmp/Rtmpix6eRO/naming-demo/outA
#> ├── metadata_tool1.parquet
#> ├── sampleA_2_tool1_table1.parquet
#> ├── sampleA_2_tool1_table2.parquet
#> ├── sampleA_3_tool1_table1.parquet
#> ├── sampleA_3_tool1_table2.parquet
#> ├── sampleA_tool1_table1.parquet
#> └── sampleA_tool1_table2.parquet
```

The `prefix_include` option also writes the prefix as an `input_prefix`
column in the output file itself, so the source run survives even after
the three files are read and stacked into one table:

``` r

dir_ls(dir_outA, regexp = "tool1_table1\\.parquet") |>
  purrr::map(arrow::read_parquet) |>
  purrr::list_rbind()
#> # A tibble: 9 × 8
#>   input_id input_prefix sample_id chromosome start   end metric_y metric_z
#>   <chr>    <chr>        <chr>     <chr>      <int> <int>    <dbl>    <dbl>
#> 1 input1   sampleA_2    sampleA   chr1          10    50      0.4      0.7
#> 2 input1   sampleA_2    sampleA   chr2         100   500      0.5      0.8
#> 3 input1   sampleA_2    sampleA   chr3        1000  5000      0.6      0.9
#> 4 input1   sampleA_3    sampleA   chr1          10    50      0.4      0.7
#> 5 input1   sampleA_3    sampleA   chr2         100   500      0.5      0.8
#> 6 input1   sampleA_3    sampleA   chr3        1000  5000      0.6      0.9
#> 7 input1   sampleA      sampleA   chr1          10    50      0.4      0.7
#> 8 input1   sampleA      sampleA   chr2         100   500      0.5      0.8
#> 9 input1   sampleA      sampleA   chr3        1000  5000      0.6      0.9
```

Mode A is the simplest way to dump every tidy run into one folder
without overwriting each other. Its limit: the tidy call shares a single
`input_id`, so the only per-run key is the filename-derived
`input_prefix`.

### Mode B: per-run tidy

When you want a more meaningful run identifier than e.g. `sampleA_2`,
you should tidy each run separately and pass a distinct `input_id`.
Because the output basenames are now identical across runs, write each
run to its own output subfolder so they don’t get overwritten:

``` r

dir_outB <- dir_create(path(dir1, "outB"))
for (r in run_ids) {
  Tool1$new(path = path(dir_runs, r))$run(
    input_id = r,
    output_dir = path(dir_outB, r),
    format = "parquet",
    prefix_include = TRUE
  )
}

dir_tree(dir_outB)
#> /tmp/Rtmpix6eRO/naming-demo/outB
#> ├── run1
#> │   ├── metadata_tool1.parquet
#> │   ├── sampleA_tool1_table1.parquet
#> │   └── sampleA_tool1_table2.parquet
#> ├── run2
#> │   ├── metadata_tool1.parquet
#> │   ├── sampleA_tool1_table1.parquet
#> │   └── sampleA_tool1_table2.parquet
#> └── run3
#>     ├── metadata_tool1.parquet
#>     ├── sampleA_tool1_table1.parquet
#>     └── sampleA_tool1_table2.parquet
```

Note the same file names in each subfolder. The folder separates them on
disk, and the `input_id` column keeps them apart once merged:

``` r

fs::dir_ls(dir_outB, recurse = TRUE, glob = "*tool1_table1.parquet") |>
  purrr::map(arrow::read_parquet) |>
  purrr::list_rbind()
#> # A tibble: 9 × 8
#>   input_id input_prefix sample_id chromosome start   end metric_y metric_z
#>   <chr>    <chr>        <chr>     <chr>      <int> <int>    <dbl>    <dbl>
#> 1 run1     sampleA      sampleA   chr1          10    50      0.4      0.7
#> 2 run1     sampleA      sampleA   chr2         100   500      0.5      0.8
#> 3 run1     sampleA      sampleA   chr3        1000  5000      0.6      0.9
#> 4 run2     sampleA      sampleA   chr1          10    50      0.4      0.7
#> 5 run2     sampleA      sampleA   chr2         100   500      0.5      0.8
#> 6 run2     sampleA      sampleA   chr3        1000  5000      0.6      0.9
#> 7 run3     sampleA      sampleA   chr1          10    50      0.4      0.7
#> 8 run3     sampleA      sampleA   chr2         100   500      0.5      0.8
#> 9 run3     sampleA      sampleA   chr3        1000  5000      0.6      0.9
```

For a globally-unique key with no coordination between runs, use
`output_id = "<your id>"` with e.g. an auto-generated
[ULID](https://wiki.tcl-lang.org/page/ULID "What is ULID") (done
automatically with the CLI’s `--ulid` flag via the
[ulid](https://github.com/eddelbuettel/ulid "ULID in R") R package),
which would generate an `output_id` column alongside `input_id`.

## Rule of thumb

- File names stop repeat runs from overwriting each other on disk
  automatically via `_2`/`_3` (Mode A), or by writing to per-run folders
  (Mode B).
- Provenance columns (`input_prefix`, `input_id`, `output_id`) let you
  tell the runs apart after the files are merged into one parquet
  dataset or loaded into a database, where the filename is no longer
  visible.
- Use `prefix_include` when one recursive tidy is enough
- Use `input_id` / `output_id` when each run is better described by an
  explicitly specified name you can control.

## Special cases: region and phenotype prefixes

The disambiguation above (`_2`, `_3`) keeps files from overwriting each
other but tells you nothing about *why* two inputs collided. DRAGEN’s
coverage stage emits the same logical table for several genomic regions
(`wgs`, `tmb`, `exon`, `target_bed`, and one per user-defined
`--qc-coverage-region-N`), and, in the somatic tumor-normal pipeline,
once per phenotype (`normal` / `tumor`). After the schema `pattern` is
stripped these would collapse to the same prefix and overwrite one
another (or land as a lossy `sampleA_2`), so you could no longer tell
which region or phenotype a file came from.

A `Tool` subclass fixes this by overriding the private `refine_files`
hook, which runs on the base prefix *before* the generic disambiguation
passes. So a subclass can fold a meaningful distinction into the prefix
itself. Once each region/phenotype carries a different prefix they no
longer collide, and any remaining `_2`/`_3` is a genuine repeat-run
marker.

### DragenCov: region + phenotype folded into the prefix

- Problem: `sampleA.wgs_coverage_metrics.csv`,
  `sampleA.target_bed_coverage_metrics.csv`, and
  `sampleA.exon_coverage_metrics.csv` all strip to the prefix `sampleA`
  and all route through the same coverage parser. In a somatic run the
  per-phenotype contig-mean files (`..._normal.csv` / `..._tumor.csv`)
  collide too.
- Fix: the `DragenCov` hook rewrites the prefix to
  `sampleA_<region>[_<pheno>]` *before* the collision check, so
  `sampleA.wgs_coverage_metrics.csv` becomes
  `sampleA_wgs_dragencov_metricsmain` and the normal/tumor contig-mean
  files become `sampleA_wgs_normal_...` / `sampleA_wgs_tumor_...`, never
  a lossy `sampleA_2`.

Point a `DragenCov` object at the bundled coverage fixtures:

``` r

dir_inC <- path(ex, "dragencov")
dir_tree(dir_inC)
#> /home/runner/miniconda3/envs/pkgdown_env/lib/R/library/tidydragen/extdata/dragencov
#> ├── sampleA.exon_coverage_metrics.csv
#> ├── sampleA.exon_coverage_metrics.csv.dvc
#> ├── sampleA.qc-coverage-region-umccr_cov_report.bed
#> ├── sampleA.qc-coverage-region-umccr_cov_report.bed.dvc
#> ├── sampleA.qc-coverage-region-umccr_read_cov_report.bed
#> ├── sampleA.qc-coverage-region-umccr_read_cov_report.bed.dvc
#> ├── sampleA.target_bed_coverage_metrics.csv
#> ├── sampleA.target_bed_coverage_metrics.csv.dvc
#> ├── sampleA.wgs_contig_mean_cov.csv
#> ├── sampleA.wgs_contig_mean_cov.csv.dvc
#> ├── sampleA.wgs_contig_mean_cov_normal.csv
#> ├── sampleA.wgs_contig_mean_cov_normal.csv.dvc
#> ├── sampleA.wgs_contig_mean_cov_tumor.csv
#> ├── sampleA.wgs_contig_mean_cov_tumor.csv.dvc
#> ├── sampleA.wgs_coverage_metrics.csv
#> ├── sampleA.wgs_coverage_metrics.csv.dvc
#> ├── sampleA.wgs_fine_hist.csv
#> └── sampleA.wgs_fine_hist.csv.dvc
cv <- DragenCov$new(path = dir_inC)
```

Now tidy it. Each region (and, for the contig-mean tables, each
phenotype) lands in its own file, distinguished by the prefix rather
than a positional `_2`:

``` r

dir_outC <- dir_create(path(tempdir(), "cov-out"))
cv$run(
  input_id = "input1",
  output_id = "output1",
  output_dir = dir_outC,
  format = "parquet",
  prefix_include = TRUE
)
list.files(dir_outC, pattern = "\\.parquet$") |> sort()
#>  [1] "metadata_dragencov.parquet"                      
#>  [2] "sampleA_exon_dragencov_metricsbins.parquet"      
#>  [3] "sampleA_exon_dragencov_metricscumu.parquet"      
#>  [4] "sampleA_exon_dragencov_metricsmain.parquet"      
#>  [5] "sampleA_target_bed_dragencov_metricsbins.parquet"
#>  [6] "sampleA_target_bed_dragencov_metricscumu.parquet"
#>  [7] "sampleA_target_bed_dragencov_metricsmain.parquet"
#>  [8] "sampleA_umccr_dragencov_readreportbed.parquet"   
#>  [9] "sampleA_umccr_dragencov_reportbedcumu.parquet"   
#> [10] "sampleA_umccr_dragencov_reportbedmain.parquet"   
#> [11] "sampleA_wgs_dragencov_contigmean.parquet"        
#> [12] "sampleA_wgs_dragencov_finehist.parquet"          
#> [13] "sampleA_wgs_dragencov_metricsbins.parquet"       
#> [14] "sampleA_wgs_dragencov_metricscumu.parquet"       
#> [15] "sampleA_wgs_dragencov_metricsmain.parquet"       
#> [16] "sampleA_wgs_normal_dragencov_contigmean.parquet" 
#> [17] "sampleA_wgs_tumor_dragencov_contigmean.parquet"
```

Note how the region (and phenotype where present) is carried in the
filename prefix, and the `input_prefix` column records the same
distinction inside each table:

``` r

dir_ls(dir_outC, regexp = "dragencov_contigmean\\.parquet") |>
  purrr::map(\(x) arrow::read_parquet(x) |> dplyr::slice_head(n = 2)) |>
  purrr::list_rbind() |>
  dplyr::select(input_id, input_prefix, output_id, dplyr::everything()) |>
  dplyr::slice_head(n = 6)
#> # A tibble: 6 × 6
#>   input_id input_prefix       output_id chrom       bases cov_mean
#>   <chr>    <chr>              <chr>     <chr>       <dbl>    <dbl>
#> 1 input1   sampleA_wgs        output1   chr1   8971334241     38.9
#> 2 input1   sampleA_wgs        output1   chr2   9451361935     39.3
#> 3 input1   sampleA_wgs_normal output1   chr1   9034582953     39.2
#> 4 input1   sampleA_wgs_normal output1   chr2   9445168027     39.3
#> 5 input1   sampleA_wgs_tumor  output1   chr1  23320283831    101. 
#> 6 input1   sampleA_wgs_tumor  output1   chr2  24261002510    101.
```

### Variant calling: region kept as a column

`DragenVar`’s variant-caller metrics (`vc`) take the opposite approach:
rather than folding the region into the prefix, they keep it as an
explicit `region` column via the private `region_split()` helper, since
a single file legitimately carries metrics for more than one region
(`genome` / `targetreg` / `qccovreg`). This is the right call when the
distinction is a *within-file* dimension rather than a *between-file*
collision.

### When to reach for the hook

- Prefer schema `pattern`s that already separate variants where you can;
  the generic pipeline then needs no help.
- Use `refine_files()` when a single parser matches multiple input files
  that must stay apart with a meaningful label rather than a positional
  `_2` (DragenCov region/phenotype).
- Keep the distinction as a column when it varies *within* a single file
  (DragenVar `vc` region).
