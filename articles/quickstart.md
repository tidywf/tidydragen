# Quickstart

tidydragen turns raw [Illumina
DRAGEN](https://www.illumina.com/products/by-type/informatics-products/dragen-secondary-analysis.html)
output directories into versioned, analysis-ready tables.

## Test data

Example inputs live in `inst/extdata/`, one subdirectory per tool.
Larger files are tracked via [DVC](https://dvc.org/) on a public
Cloudflare R2 bucket (no credentials). Fetch them with `dvc pull` from a
cloned repo, or from R with
[`nemo::dvc_download_all()`](https://tidywf.github.io/nemo/reference/dvc_download_all.html):

``` r

input_dir <- system.file("extdata/dragencov", package = "tidydragen")
nemo::dvc_download_all(input_dir, file.path(tempdir(), "dvc_test"))
```

## Input

Example DRAGEN results (one subdirectory per tool):

View input files

``` r

indir <- system.file("extdata", package = "tidydragen")
dir_tree(indir, invert = TRUE, glob = "*.dvc")
#> /home/runner/miniconda3/envs/pkgdown_env/lib/R/library/tidydragen/extdata
#> ├── dragenbcl
#> │   ├── Adapter_Cycle_Metrics.csv
#> │   ├── Adapter_Metrics.csv
#> │   ├── Demultiplex_Stats.csv
#> │   ├── Demultiplex_Tile_Stats.csv
#> │   ├── Index_Hopping_Counts.csv
#> │   ├── Quality_Metrics.csv
#> │   ├── Quality_Tile_Metrics.csv
#> │   ├── RunInfo.xml
#> │   ├── Top_Unknown_Barcodes.csv
#> │   └── fastq_list.csv
#> ├── dragencov
#> │   ├── sampleA.exon_coverage_metrics.csv
#> │   ├── sampleA.qc-coverage-region-umccr_cov_report.bed
#> │   ├── sampleA.qc-coverage-region-umccr_read_cov_report.bed
#> │   ├── sampleA.target_bed_coverage_metrics.csv
#> │   ├── sampleA.wgs_contig_mean_cov.csv
#> │   ├── sampleA.wgs_contig_mean_cov_normal.csv
#> │   ├── sampleA.wgs_contig_mean_cov_tumor.csv
#> │   ├── sampleA.wgs_coverage_metrics.csv
#> │   └── sampleA.wgs_fine_hist.csv
#> ├── dragenfqc
#> │   └── sampleA.fastqc_metrics.csv
#> ├── dragenmap
#> │   ├── cttso-dragencaller
#> │   │   ├── sampleB-replay.json
#> │   │   └── sampleB.time_metrics.csv
#> │   ├── cttso-tmb
#> │   │   ├── sampleB-replay.json
#> │   │   └── sampleB.time_metrics.csv
#> │   ├── sampleA-replay.json
#> │   ├── sampleA.fragment_length_hist.csv
#> │   ├── sampleA.gc_metrics.csv
#> │   ├── sampleA.mapping_metrics.csv
#> │   ├── sampleA.time_metrics.csv
#> │   ├── sampleA.trimmer_metrics.csv
#> │   └── sampleA.umi_metrics.csv
#> ├── dragenrna
#> │   ├── sampleA.fusion_metrics.csv
#> │   └── sampleA.quant_metrics.csv
#> ├── dragentso
#> │   ├── sampleA.exon_cov_report.tsv
#> │   ├── sampleA.gene_cov_report.tsv
#> │   ├── sampleA.tmb.msaf.csv
#> │   ├── sampleA.tmb.trace.tsv
#> │   ├── sampleA_CombinedVariantOutput.tsv
#> │   ├── sampleA_Fusions.csv
#> │   └── sampleA_SampleAnalysisResults.json
#> ├── dragenvar
#> │   ├── sampleA.allele_transition_noise_metrics.csv
#> │   ├── sampleA.cnv_metrics.csv
#> │   ├── sampleA.contamination.json
#> │   ├── sampleA.gvcf_metrics.csv
#> │   ├── sampleA.hrdscore.csv
#> │   ├── sampleA.microsat_output.json
#> │   ├── sampleA.ploidy.vcf.gz
#> │   ├── sampleA.ploidy_estimation_metrics.csv
#> │   ├── sampleA.sv_metrics.csv
#> │   ├── sampleA.tmb.metrics.csv
#> │   ├── sampleA.vc_hethom_ratio_metrics.csv
#> │   ├── sampleA.vc_metrics.csv
#> │   ├── sampleB.cnv_metrics.csv
#> │   ├── sampleB.ploidy_estimation_metrics.csv
#> │   └── sampleB.vc_metrics.csv
#> └── interop
#>     ├── imaging_tables
#>     │   ├── compressed
#>     │   │   └── imaging_table.csv.gz
#>     │   └── uncompressed
#>     │       └── imaging_table.csv
#>     └── summaries
#>         ├── runA-index_summary.csv
#>         └── runA_summary.csv
```

## Output - Single Tool

Each tool has its own R6 class. `run()` parses, tidies and writes in one
step:

``` r

outdir <- file.path(tempdir(), "qs_map")
DragenMap$new(file.path(indir, "dragenmap"))$run(
  output_dir = outdir,
  format = "parquet",
  input_id = "sampleA_id"
)
list.files(outdir, pattern = "\\.parquet$")
#>  [1] "metadata_dragenmap.parquet"               "sampleA_dragenmap_fraglenhist.parquet"   
#>  [3] "sampleA_dragenmap_gcbias.parquet"         "sampleA_dragenmap_gcmain.parquet"        
#>  [5] "sampleA_dragenmap_metrics.parquet"        "sampleA_dragenmap_replayconfig.parquet"  
#>  [7] "sampleA_dragenmap_replaymain.parquet"     "sampleA_dragenmap_time.parquet"          
#>  [9] "sampleA_dragenmap_trimmer.parquet"        "sampleA_dragenmap_umihist.parquet"       
#> [11] "sampleA_dragenmap_umimain.parquet"        "sampleB_2_dragenmap_replayconfig.parquet"
#> [13] "sampleB_2_dragenmap_replaymain.parquet"   "sampleB_2_dragenmap_time.parquet"        
#> [15] "sampleB_dragenmap_replayconfig.parquet"   "sampleB_dragenmap_replaymain.parquet"    
#> [17] "sampleB_dragenmap_time.parquet"
```

### File naming

Output files follow `{prefix}_{tool}_{table}.parquet`, where `prefix`
comes from the input filenames (here `sampleA`). One input file can fan
out into several tables. See [Output
Naming](https://tidywf.github.io/tidydragen/articles/output_naming.md)
for region/phenotype prefixes and collision handling.

### Reading a table back

``` r

m <- read_parquet(file.path(outdir, "sampleA_dragenmap_metrics.parquet"))
m |> str(list.len = 10)
#> tibble [4 × 131] (S3: tbl_df/tbl/data.frame)
#>  $ input_id                                 : chr [1:4] "sampleA_id" "sampleA_id" "sampleA_id" "sampleA_id"
#>  $ section                                  : chr [1:4] "TUMOR" "NORMAL" "TUMOR" "NORMAL"
#>  $ rg                                       : chr [1:4] "Total" "Total" "CAAGCTAG+CGCTATGT.4.260813_A01052_0316_AHTYNTDSXF" "CAGTAGGC+ATTCGTCA.3.260813_A01052_0316_AHTYNTDSXF"
#>  $ reads_tot_input                          : num [1:4] 2.64e+09 9.39e+08 NA NA
#>  $ reads_tot_input_pct                      : num [1:4] 100 100 NA NA
#>  $ reads_num_dupmarked                      : num [1:4] 5.24e+08 1.31e+08 5.24e+08 1.31e+08
#>  $ reads_num_dupmarked_pct                  : num [1:4] 19.9 13.9 19.9 13.9
#>  $ reads_num_dupmarked_mate_reads_removed   : num [1:4] NA NA NA NA
#>  $ reads_num_uniq                           : num [1:4] 2.11e+09 8.08e+08 2.11e+09 8.08e+08
#>  $ reads_num_uniq_pct                       : num [1:4] 80.1 86.1 80.1 86.1
#>   [list output truncated]
```

## Output - Full DRAGEN run

`Dragen` runs all supported tools on a parent directory. Tools whose
files are absent contribute nothing, so the same call works across the
germline, somatic, RNA and ctTSO500 pipelines:

``` r

outdir_d <- file.path(tempdir(), "qs_dragen")
d <- Dragen$new(indir)
d$run(
  output_dir = outdir_d,
  format = "parquet"
)
list.files(outdir_d, pattern = "\\.parquet$") |> sort() |> str()
#>  chr [1:89] "dragenbcl_adaptercyclemetrics.parquet" ...
```

## ID columns

Optional columns prepended to every written table (all off by default),
useful when combining samples into one table:

| Argument | Column added | Contains |
|----|----|----|
| `input_id = "x"` | `input_id` | sample or run identifier you supply |
| `output_id = "x"` | `output_id` | processing run identifier you supply |
| `prefix_include = TRUE` | `input_prefix` | filename prefix extracted from input files |

``` r

outdir_id <- file.path(tempdir(), "qs_map_id")
DragenMap$new(file.path(indir, "dragenmap"))$run(
  output_dir = outdir_id,
  format = "parquet",
  input_id = "sampleA",
  output_id = "out1",
  prefix_include = TRUE
)
read_parquet(file.path(outdir_id, "sampleA_dragenmap_metrics.parquet")) |>
  str(list.len = 10)
#> tibble [4 × 133] (S3: tbl_df/tbl/data.frame)
#>  $ input_id                                 : chr [1:4] "sampleA" "sampleA" "sampleA" "sampleA"
#>  $ input_prefix                             : chr [1:4] "sampleA" "sampleA" "sampleA" "sampleA"
#>  $ output_id                                : chr [1:4] "out1" "out1" "out1" "out1"
#>  $ section                                  : chr [1:4] "TUMOR" "NORMAL" "TUMOR" "NORMAL"
#>  $ rg                                       : chr [1:4] "Total" "Total" "CAAGCTAG+CGCTATGT.4.260813_A01052_0316_AHTYNTDSXF" "CAGTAGGC+ATTCGTCA.3.260813_A01052_0316_AHTYNTDSXF"
#>  $ reads_tot_input                          : num [1:4] 2.64e+09 9.39e+08 NA NA
#>  $ reads_tot_input_pct                      : num [1:4] 100 100 NA NA
#>  $ reads_num_dupmarked                      : num [1:4] 5.24e+08 1.31e+08 5.24e+08 1.31e+08
#>  $ reads_num_dupmarked_pct                  : num [1:4] 19.9 13.9 19.9 13.9
#>  $ reads_num_dupmarked_mate_reads_removed   : num [1:4] NA NA NA NA
#>   [list output truncated]
```

## Metadata

Every `run()` also writes metadata (input/output dirs, IDs, R package
versions): `metadata.parquet` for `Dragen`, `metadata_<tool>.parquet`
for a single tool.

``` r

read_parquet(file.path(outdir_d, "metadata.parquet")) |> str()
#> tibble [1 × 6] (S3: tbl_df/tbl/data.frame)
#>  $ input_id    : chr NA
#>  $ output_id   : chr NA
#>  $ input_dirs  : list<character> [1:1] 
#>   ..$ : chr "/home/runner/miniconda3/envs/pkgdown_env/lib/R/library/tidydragen/extdata"
#>   ..@ ptype: chr(0) 
#>  $ output_dir  : chr "/tmp/Rtmp3bMAO2/qs_dragen"
#>  $ pkg_versions: list<
#>   tbl_df<
#>     name   : character
#>     version: character
#>   >
#> > [1:1] 
#>   ..$ : tibble [2 × 2] (S3: tbl_df/tbl/data.frame)
#>   .. ..$ name   : chr [1:2] "nemo" "tidydragen"
#>   .. ..$ version: chr [1:2] "0.1.0.9006" "0.0.0.9004"
#>   ..@ ptype: tibble [0 × 2] (S3: tbl_df/tbl/data.frame)
#>   .. ..$ name   : chr(0) 
#>   .. ..$ version: chr(0) 
#>  $ files       : list<
#>   tbl_df<
#>     tbl   : character
#>     prefix: character
#>     fout  : character
#>     fin   : character
#>   >
#> > [1:1] 
#>   ..$ : tibble [88 × 4] (S3: tbl_df/tbl/data.frame)
#>   .. ..$ tbl   : chr [1:88] "dragenmap_replaymain" "dragenmap_replayconfig" "dragenmap_time" "dragenmap_replaymain" ...
#>   .. ..$ prefix: chr [1:88] "sampleB" "sampleB" "sampleB" "sampleB_2" ...
#>   .. ..$ fout  : chr [1:88] "sampleB_dragenmap_replaymain.parquet" "sampleB_dragenmap_replayconfig.parquet" "sampleB_dragenmap_time.parquet" "sampleB_2_dragenmap_replaymain.parquet" ...
#>   .. ..$ fin   : chr [1:88] "/home/runner/miniconda3/envs/pkgdown_env/lib/R/library/tidydragen/extdata/dragenmap/cttso-dragencaller/sampleB-replay.json" "/home/runner/miniconda3/envs/pkgdown_env/lib/R/library/tidydragen/extdata/dragenmap/cttso-dragencaller/sampleB-replay.json" "/home/runner/miniconda3/envs/pkgdown_env/lib/R/library/tidydragen/extdata/dragenmap/cttso-dragencaller/sampleB."| __truncated__ "/home/runner/miniconda3/envs/pkgdown_env/lib/R/library/tidydragen/extdata/dragenmap/cttso-tmb/sampleB-replay.json" ...
#>   ..@ ptype: tibble [0 × 4] (S3: tbl_df/tbl/data.frame)
#>   .. ..$ tbl   : chr(0) 
#>   .. ..$ prefix: chr(0) 
#>   .. ..$ fout  : chr(0) 
#>   .. ..$ fin   : chr(0)
```

## Other useful articles

- [Schema
  table](https://tidywf.github.io/tidydragen/articles/schema_table.md):
  browse every table and column for all supported DRAGEN tools
- [Structure](https://tidywf.github.io/tidydragen/articles/structure.md):
  schemas, versioning, and the Tool/Workflow class hierarchy (nemo)
- [PostgreSQL](https://tidywf.github.io/tidydragen/articles/postgresql.md):
  writing results to a database
