# Output Naming

Repeat runs of the same sample produce identical file names in different
folders. Below: how tidy outputs avoid overwriting each other, and how
to keep runs distinguishable after merging.

## Anatomy of a tidy filename

    {output_dir}/{prefix}_{tool}_{parser}.{ext}

- `{output_dir}`: flat output directory
- `{prefix}`: input basename minus the schema `pattern`
  (`sampleA.tool1.table1.tsv` =\> `sampleA`)
- `{tool}_{parser}`: e.g. `tool1_table1`
- `{ext}`: from `format` (parquet, db, tsv, csv or rds)

`sampleA.tool1.table1.tsv` =\> `sampleA_tool1_table1.parquet`.

## A repeated sample

Three runs, same input files:

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
#> /tmp/RtmpXhTjHX/naming-demo/runs
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

Point `Tool1` at the parent folder. Colliding prefixes get `_2`/`_3`:

``` r

tool <- Tool1$new(path = dir_runs)
tool$list_files() |>
  dplyr::select(path, prefix, parser) |>
  dplyr::arrange(parser)
#> # A tibble: 6 × 3
#>   path                                                           prefix   parser
#>   <chr>                                                          <chr>    <chr> 
#> 1 /tmp/RtmpXhTjHX/naming-demo/runs/run1/sampleA.tool1.table1.tsv sampleA  table1
#> 2 /tmp/RtmpXhTjHX/naming-demo/runs/run2/sampleA.tool1.table1.tsv sampleA… table1
#> 3 /tmp/RtmpXhTjHX/naming-demo/runs/run3/sampleA.tool1.table1.tsv sampleA… table1
#> 4 /tmp/RtmpXhTjHX/naming-demo/runs/run1/sampleA.tool1.table2.tsv sampleA  table2
#> 5 /tmp/RtmpXhTjHX/naming-demo/runs/run2/sampleA.tool1.table2.tsv sampleA… table2
#> 6 /tmp/RtmpXhTjHX/naming-demo/runs/run3/sampleA.tool1.table2.tsv sampleA… table2
```

No overwrites:

``` r

dir_outA <- dir_create(path(dir1, "outA"))
tool$run(
  input_id = "input1",
  output_dir = dir_outA,
  format = "parquet",
  prefix_include = TRUE
)

dir_tree(dir_outA)
#> /tmp/RtmpXhTjHX/naming-demo/outA
#> ├── metadata_tool1.parquet
#> ├── sampleA_2_tool1_table1.parquet
#> ├── sampleA_2_tool1_table2.parquet
#> ├── sampleA_3_tool1_table1.parquet
#> ├── sampleA_3_tool1_table2.parquet
#> ├── sampleA_tool1_table1.parquet
#> └── sampleA_tool1_table2.parquet
```

`prefix_include = TRUE` adds an `input_prefix` column, so runs stay
distinct after stacking:

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

Limit: one shared `input_id`; the only per-run key is `input_prefix`.

### Mode B: per-run tidy

Tidy each run separately with its own `input_id` and output subfolder:

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
#> /tmp/RtmpXhTjHX/naming-demo/outB
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

Same file names per subfolder; `input_id` separates them once merged:

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

For a globally-unique key, set `output_id`, e.g. to a
[ULID](https://wiki.tcl-lang.org/page/ULID "What is ULID") (CLI:
`--ulid`, via the
[ulid](https://github.com/eddelbuettel/ulid "ULID in R") R package).

## Rule of thumb

- On disk: `_2`/`_3` suffixes (Mode A) or per-run folders (Mode B)
- After merging: `input_prefix`, `input_id`, `output_id` columns
- One recursive tidy is enough =\> `prefix_include`
- Want named runs =\> `input_id` / `output_id`

## Special cases: region and phenotype prefixes

DRAGEN coverage emits the same table per region (`wgs`, `tmb`, `exon`,
`target_bed`, `--qc-coverage-region-N`) and, for tumor-normal, per
phenotype. These strip to the same prefix (`sampleA` / `sampleA_2`).
Subclasses override the private `refine_files()` hook (runs *before*
disambiguation) to put the region/phenotype in the prefix. Remaining
`_2`/`_3` = repeat runs.

### DragenCov: region + phenotype folded into the prefix

- Problem: `sampleA.{wgs,target_bed,exon}_coverage_metrics.csv` all
  strip to `sampleA` via the same parser; somatic
  `..._normal.csv`/`..._tumor.csv` contig-mean files collide too.
- Fix: prefix becomes `sampleA_<region>[_<pheno>]`, e.g.
  `sampleA_wgs_dragencov_metricsmain`, `sampleA_wgs_normal_...`.

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

One file per region (and phenotype):

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

`input_prefix` carries the same distinction:

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

`DragenVar` `vc` metrics keep region (`genome`/`targetreg`/`qccovreg`)
as a `region` column (private `region_split()`), since one file holds
several regions: a within-file dimension, not a between-file collision.

### When to reach for the hook

- Prefer schema `pattern`s that already separate variants
- Use `refine_files()` when one parser matches files needing a real
  label, not `_2` (DragenCov)
- Use a column when it varies *within* a file (DragenVar `vc`)
