# Quickstart

tidydragen turns raw [Illumina
DRAGEN](https://www.illumina.com/products/by-type/informatics-products/dragen-secondary-analysis.html)
output directories into consistently structured, versioned,
analysis-ready tables/files. This vignette walks through the core usage
patterns.

## Test data

Example input files ship in `inst/extdata/`, one subdirectory per tool.
Larger real-world DRAGEN results are tracked separately via
[DVC](https://dvc.org/) and can be downloaded with either:

- `dvc pull`: requires dvc installation and cloned tidydragen source
  repo.
- `?nemo::dvc_download_all()`: no additional requirements, uses
  [`download.file()`](https://rdrr.io/r/utils/download.file.html)
  internally.

No credentials are required since the remote is a public Cloudflare R2
bucket.

## Input

Example DRAGEN results (one subdirectory per tool):

View input files

``` r

indir <- system.file("extdata", package = "tidydragen")
dir_tree(indir)
#> /home/runner/miniconda3/envs/pkgdown_env/lib/R/library/tidydragen/extdata
#> ├── dragenbcl
#> │   ├── Adapter_Cycle_Metrics.csv
#> │   ├── Adapter_Cycle_Metrics.csv.dvc
#> │   ├── Adapter_Metrics.csv
#> │   ├── Adapter_Metrics.csv.dvc
#> │   ├── Demultiplex_Stats.csv
#> │   ├── Demultiplex_Stats.csv.dvc
#> │   ├── Demultiplex_Tile_Stats.csv
#> │   ├── Demultiplex_Tile_Stats.csv.dvc
#> │   ├── Index_Hopping_Counts.csv
#> │   ├── Index_Hopping_Counts.csv.dvc
#> │   ├── Quality_Metrics.csv
#> │   ├── Quality_Metrics.csv.dvc
#> │   ├── Quality_Tile_Metrics.csv
#> │   ├── Quality_Tile_Metrics.csv.dvc
#> │   ├── RunInfo.xml
#> │   ├── RunInfo.xml.dvc
#> │   ├── Top_Unknown_Barcodes.csv
#> │   ├── Top_Unknown_Barcodes.csv.dvc
#> │   ├── fastq_list.csv
#> │   └── fastq_list.csv.dvc
#> ├── dragencov
#> │   ├── sampleA.exon_coverage_metrics.csv
#> │   ├── sampleA.exon_coverage_metrics.csv.dvc
#> │   ├── sampleA.qc-coverage-region-umccr_cov_report.bed
#> │   ├── sampleA.qc-coverage-region-umccr_cov_report.bed.dvc
#> │   ├── sampleA.qc-coverage-region-umccr_read_cov_report.bed
#> │   ├── sampleA.qc-coverage-region-umccr_read_cov_report.bed.dvc
#> │   ├── sampleA.target_bed_coverage_metrics.csv
#> │   ├── sampleA.target_bed_coverage_metrics.csv.dvc
#> │   ├── sampleA.wgs_contig_mean_cov.csv
#> │   ├── sampleA.wgs_contig_mean_cov.csv.dvc
#> │   ├── sampleA.wgs_contig_mean_cov_normal.csv
#> │   ├── sampleA.wgs_contig_mean_cov_normal.csv.dvc
#> │   ├── sampleA.wgs_contig_mean_cov_tumor.csv
#> │   ├── sampleA.wgs_contig_mean_cov_tumor.csv.dvc
#> │   ├── sampleA.wgs_coverage_metrics.csv
#> │   ├── sampleA.wgs_coverage_metrics.csv.dvc
#> │   ├── sampleA.wgs_fine_hist.csv
#> │   └── sampleA.wgs_fine_hist.csv.dvc
#> ├── dragenfqc
#> │   ├── sampleA.fastqc_metrics.csv
#> │   └── sampleA.fastqc_metrics.csv.dvc
#> ├── dragenmap
#> │   ├── cttso-dragencaller
#> │   │   ├── sampleB-replay.json
#> │   │   ├── sampleB-replay.json.dvc
#> │   │   ├── sampleB.time_metrics.csv
#> │   │   └── sampleB.time_metrics.csv.dvc
#> │   ├── cttso-tmb
#> │   │   ├── sampleB-replay.json
#> │   │   ├── sampleB-replay.json.dvc
#> │   │   ├── sampleB.time_metrics.csv
#> │   │   └── sampleB.time_metrics.csv.dvc
#> │   ├── sampleA-replay.json
#> │   ├── sampleA-replay.json.dvc
#> │   ├── sampleA.fragment_length_hist.csv
#> │   ├── sampleA.fragment_length_hist.csv.dvc
#> │   ├── sampleA.gc_metrics.csv
#> │   ├── sampleA.gc_metrics.csv.dvc
#> │   ├── sampleA.mapping_metrics.csv
#> │   ├── sampleA.mapping_metrics.csv.dvc
#> │   ├── sampleA.time_metrics.csv
#> │   ├── sampleA.time_metrics.csv.dvc
#> │   ├── sampleA.trimmer_metrics.csv
#> │   ├── sampleA.trimmer_metrics.csv.dvc
#> │   ├── sampleA.umi_metrics.csv
#> │   └── sampleA.umi_metrics.csv.dvc
#> ├── dragenrna
#> │   ├── sampleA.fusion_metrics.csv
#> │   ├── sampleA.fusion_metrics.csv.dvc
#> │   ├── sampleA.quant_metrics.csv
#> │   └── sampleA.quant_metrics.csv.dvc
#> ├── dragentso
#> │   ├── sampleA.exon_cov_report.tsv
#> │   ├── sampleA.exon_cov_report.tsv.dvc
#> │   ├── sampleA.gene_cov_report.tsv
#> │   ├── sampleA.gene_cov_report.tsv.dvc
#> │   ├── sampleA.tmb.msaf.csv
#> │   ├── sampleA.tmb.msaf.csv.dvc
#> │   ├── sampleA.tmb.trace.tsv
#> │   ├── sampleA.tmb.trace.tsv.dvc
#> │   ├── sampleA_CombinedVariantOutput.tsv
#> │   ├── sampleA_CombinedVariantOutput.tsv.dvc
#> │   ├── sampleA_Fusions.csv
#> │   ├── sampleA_Fusions.csv.dvc
#> │   ├── sampleA_SampleAnalysisResults.json
#> │   └── sampleA_SampleAnalysisResults.json.dvc
#> ├── dragenvar
#> │   ├── sampleA.allele_transition_noise_metrics.csv
#> │   ├── sampleA.allele_transition_noise_metrics.csv.dvc
#> │   ├── sampleA.cnv_metrics.csv
#> │   ├── sampleA.cnv_metrics.csv.dvc
#> │   ├── sampleA.contamination.json
#> │   ├── sampleA.contamination.json.dvc
#> │   ├── sampleA.gvcf_metrics.csv
#> │   ├── sampleA.gvcf_metrics.csv.dvc
#> │   ├── sampleA.hrdscore.csv
#> │   ├── sampleA.hrdscore.csv.dvc
#> │   ├── sampleA.microsat_output.json
#> │   ├── sampleA.microsat_output.json.dvc
#> │   ├── sampleA.ploidy.vcf.gz
#> │   ├── sampleA.ploidy.vcf.gz.dvc
#> │   ├── sampleA.ploidy_estimation_metrics.csv
#> │   ├── sampleA.ploidy_estimation_metrics.csv.dvc
#> │   ├── sampleA.sv_metrics.csv
#> │   ├── sampleA.sv_metrics.csv.dvc
#> │   ├── sampleA.tmb.metrics.csv
#> │   ├── sampleA.tmb.metrics.csv.dvc
#> │   ├── sampleA.vc_hethom_ratio_metrics.csv
#> │   ├── sampleA.vc_hethom_ratio_metrics.csv.dvc
#> │   ├── sampleA.vc_metrics.csv
#> │   ├── sampleA.vc_metrics.csv.dvc
#> │   ├── sampleB.cnv_metrics.csv
#> │   ├── sampleB.cnv_metrics.csv.dvc
#> │   ├── sampleB.ploidy_estimation_metrics.csv
#> │   ├── sampleB.ploidy_estimation_metrics.csv.dvc
#> │   ├── sampleB.vc_metrics.csv
#> │   └── sampleB.vc_metrics.csv.dvc
#> └── interop
#>     ├── imaging_tables
#>     │   ├── compressed
#>     │   │   ├── imaging_table.csv.gz
#>     │   │   └── imaging_table.csv.gz.dvc
#>     │   └── uncompressed
#>     │       ├── imaging_table.csv
#>     │       └── imaging_table.csv.dvc
#>     └── summaries
#>         ├── runA-index_summary.csv
#>         ├── runA-index_summary.csv.dvc
#>         ├── runA_summary.csv
#>         └── runA_summary.csv.dvc
```

## Output - Single Tool

Each tool has its own R6 class. Construct it with the tool’s output
directory, then call `run()` to parse, tidy, and write in one step:

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

Output files follow the pattern `{prefix}_{tool}_{table}.parquet`, where
`prefix` is derived from the input filenames (here `sampleA`). A single
input file can fan out into several tables (e.g. the mapping outputs
yield `metrics`, `time`, `fraglenhist`, and more). The
`metadata.parquet` file is always written alongside the data files and
records input/output paths and package versions.

### Reading a table back

``` r

m <- read_parquet(file.path(outdir, "sampleA_dragenmap_metrics.parquet"))
m |> str()
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
#>  $ reads_w_mate_seq                         : num [1:4] 2.64e+09 9.39e+08 2.64e+09 9.39e+08
#>  $ reads_w_mate_seq_pct                     : num [1:4] 100 100 100 100
#>  $ reads_wo_mate_seq                        : num [1:4] 0 0 0 0
#>  $ reads_wo_mate_seq_pct                    : num [1:4] 0 0 0 0
#>  $ reads_qcfail                             : num [1:4] 0 0 0 0
#>  $ reads_qcfail_pct                         : num [1:4] 0 0 0 0
#>  $ reads_mapped                             : num [1:4] 2.57e+09 9.19e+08 2.57e+09 9.19e+08
#>  $ reads_mapped_pct                         : num [1:4] 97.6 97.9 97.6 97.9
#>  $ reads_mapped_r1                          : num [1:4] 1.29e+09 4.61e+08 1.29e+09 4.61e+08
#>  $ reads_mapped_r1_pct                      : num [1:4] 98.1 98.2 98.1 98.2
#>  $ reads_mapped_r2                          : num [1:4] 1.28e+09 4.58e+08 1.28e+09 4.58e+08
#>  $ reads_mapped_r2_pct                      : num [1:4] 97.2 97.6 97.2 97.6
#>  $ reads_mapped_pai                         : num [1:4] 0 0 0 0
#>  $ reads_mapped_pai_pct                     : num [1:4] 0 0 0 0
#>  $ reads_mapped_nrd                         : num [1:4] 45892511 16234720 45892511 16234720
#>  $ reads_mapped_nrd_pct                     : num [1:4] 1.74 1.73 1.74 1.73
#>  $ reads_mapped_pai_nrd                     : num [1:4] 45892511 16234720 45892511 16234720
#>  $ reads_mapped_pai_nrd_pct                 : num [1:4] 1.74 1.73 1.74 1.73
#>  $ reads_mapped_rna_rrna_filt               : num [1:4] NA NA NA NA
#>  $ reads_mapped_rna_chrm_excl               : num [1:4] NA NA NA NA
#>  $ reads_mapped_incl_refext_filt_excl       : num [1:4] 2.62e+09 9.35e+08 2.62e+09 9.35e+08
#>  $ reads_mapped_incl_refext_filt_excl_pct   : num [1:4] 99.4 99.6 99.4 99.6
#>  $ reads_unmapped                           : num [1:4] 62134158 19917093 62134158 19917093
#>  $ reads_unmapped_pct                       : num [1:4] 2.36 2.12 2.36 2.12
#>  $ reads_unmapped_minus_refext              : num [1:4] 16241647 3682373 16241647 3682373
#>  $ reads_unmapped_minus_refext_pct          : num [1:4] 0.62 0.39 0.62 0.39
#>  $ reads_unmapped_minus_filt                : num [1:4] 62134158 19917093 62134158 19917093
#>  $ reads_unmapped_minus_filt_pct            : num [1:4] 2.36 2.12 2.36 2.12
#>  $ reads_unmapped_minus_excl                : num [1:4] 62134158 19917093 62134158 19917093
#>  $ reads_unmapped_minus_excl_pct            : num [1:4] 2.36 2.12 2.36 2.12
#>  $ reads_unmapped_minus_refext_filt_excl    : num [1:4] 16241647 3682373 16241647 3682373
#>  $ reads_unmapped_minus_refext_filt_excl_pct: num [1:4] 0.62 0.39 0.62 0.39
#>  $ reads_singleton                          : num [1:4] 14289628 3295781 14289628 3295781
#>  $ reads_singleton_pct                      : num [1:4] 0.54 0.35 0.54 0.35
#>  $ reads_paired                             : num [1:4] 2.56e+09 9.16e+08 2.56e+09 9.16e+08
#>  $ reads_paired_pct                         : num [1:4] 97.1 97.5 97.1 97.5
#>  $ reads_paired_proper                      : num [1:4] 2.55e+09 9.12e+08 2.55e+09 9.12e+08
#>  $ reads_paired_proper_pct                  : num [1:4] 96.7 97.1 96.7 97.1
#>  $ reads_discordant                         : num [1:4] 11520728 3939608 11520728 3939608
#>  $ reads_discordant_pct                     : num [1:4] 0.44 0.42 0.44 0.42
#>  $ reads_paired_mapped_diff_chrom           : num [1:4] 3992370 1220540 3992370 1220540
#>  $ reads_paired_mapped_diff_chrom_pct       : num [1:4] 0.16 0.13 0.16 0.13
#>  $ reads_paired_mapped_diff_chrom_mapq10    : num [1:4] 2933157 846318 2933157 846318
#>  $ reads_paired_mapped_diff_chrom_mapq10_pct: num [1:4] 0.11 0.09 0.11 0.09
#>  $ reads_map_multiloc                       : num [1:4] 1.10e+08 3.84e+07 1.10e+08 3.84e+07
#>  $ reads_map_multiloc_pct                   : num [1:4] 4.16 4.09 4.16 4.09
#>  $ reads_mapq_40_inf                        : num [1:4] 2.40e+09 8.57e+08 2.40e+09 8.57e+08
#>  $ reads_mapq_40_inf_pct                    : num [1:4] 90.9 91.3 90.9 91.3
#>  $ reads_mapq_30_40                         : num [1:4] 7124864 2469532 7124864 2469532
#>  $ reads_mapq_30_40_pct                     : num [1:4] 0.27 0.26 0.27 0.26
#>  $ reads_mapq_20_30                         : num [1:4] 17744796 6147077 17744796 6147077
#>  $ reads_mapq_20_30_pct                     : num [1:4] 0.67 0.65 0.67 0.65
#>  $ reads_mapq_10_20                         : num [1:4] 28433795 10003292 28433795 10003292
#>  $ reads_mapq_10_20_pct                     : num [1:4] 1.08 1.07 1.08 1.07
#>  $ reads_mapq_0_10                          : num [1:4] 1.24e+08 4.32e+07 1.24e+08 4.32e+07
#>  $ reads_mapq_0_10_pct                      : num [1:4] 4.7 4.6 4.7 4.6
#>  $ reads_mapq_na_unmapped                   : num [1:4] 62134158 19917093 62134158 19917093
#>  $ reads_mapq_na_unmapped_pct               : num [1:4] 2.36 2.12 2.36 2.12
#>  $ reads_indel_r1                           : num [1:4] 40110680 14217155 40110680 14217155
#>  $ reads_indel_r1_pct                       : num [1:4] 3.1 3.08 3.1 3.08
#>  $ reads_indel_r2                           : num [1:4] 37398760 13618249 37398760 13618249
#>  $ reads_indel_r2_pct                       : num [1:4] 2.92 2.97 2.92 2.97
#>  $ reads_splicejunc                         : num [1:4] NA NA NA NA
#>  $ bases_tot                                : num [1:4] 3.98e+11 1.42e+11 3.98e+11 1.42e+11
#>  $ bases_tot_r1                             : num [1:4] 1.99e+11 7.09e+10 1.99e+11 7.09e+10
#>  $ bases_tot_r2                             : num [1:4] 1.99e+11 7.09e+10 1.99e+11 7.09e+10
#>  $ bases_mapped                             : num [1:4] 3.89e+11 1.39e+11 3.89e+11 1.39e+11
#>  $ bases_mapped_r1                          : num [1:4] 1.95e+11 6.96e+10 1.95e+11 6.96e+10
#>  $ bases_mapped_r2                          : num [1:4] 1.93e+11 6.92e+10 1.93e+11 6.92e+10
#>  $ bases_softclip                           : num [1:4] 4.57e+09 1.28e+09 4.57e+09 1.28e+09
#>  $ bases_softclip_pct                       : num [1:4] 1.18 0.93 1.18 0.93
#>  $ bases_softclip_r1                        : num [1:4] 1.49e+09 4.82e+08 1.49e+09 4.82e+08
#>  $ bases_softclip_r1_pct                    : num [1:4] 0.76 0.69 0.76 0.69
#>  $ bases_softclip_r2                        : num [1:4] 3.08e+09 8.03e+08 3.08e+09 8.03e+08
#>  $ bases_softclip_r2_pct                    : num [1:4] 1.59 1.16 1.59 1.16
#>  $ bases_hardclip                           : num [1:4] 0 0 0 0
#>  $ bases_hardclip_pct                       : num [1:4] 0 0 0 0
#>  $ bases_hardclip_r1                        : num [1:4] 0 0 0 0
#>  $ bases_hardclip_r1_pct                    : num [1:4] 0 0 0 0
#>  $ bases_hardclip_r2                        : num [1:4] 0 0 0 0
#>  $ bases_hardclip_r2_pct                    : num [1:4] 0 0 0 0
#>  $ bases_mismatched_r1                      : num [1:4] 8.57e+08 3.16e+08 8.57e+08 3.16e+08
#>  $ bases_mismatched_r1_pct                  : num [1:4] 0.44 0.45 0.44 0.45
#>  $ bases_mismatched_r2                      : num [1:4] 1.83e+09 4.77e+08 1.83e+09 4.77e+08
#>  $ bases_mismatched_r2_pct                  : num [1:4] 0.94 0.69 0.94 0.69
#>  $ bases_mismatched_r1_noindels             : num [1:4] 7.35e+08 2.72e+08 7.35e+08 2.72e+08
#>  $ bases_mismatched_r1_noindels_pct         : num [1:4] 0.38 0.39 0.38 0.39
#>  $ bases_mismatched_r2_noindels             : num [1:4] 1.72e+09 4.37e+08 1.72e+09 4.37e+08
#>  $ bases_mismatched_r2_noindels_pct         : num [1:4] 0.89 0.63 0.89 0.63
#>   [list output truncated]
```

## Output - Full DRAGEN run

`Dragen` processes all supported tools in one call. Point it at a
directory containing DRAGEN results; tools whose files are absent simply
contribute nothing, so the same call works across e.g. the germline,
somatic tumor-normal, RNA and ctTSO500 pipelines:

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

Three optional columns can be prepended to every written table. All are
off by default:

| Argument | Column added | Contains |
|----|----|----|
| `input_id = "x"` | `input_id` | sample or run identifier you supply |
| `output_id = "x"` | `output_id` | processing run identifier you supply |
| `prefix_include = TRUE` | `input_prefix` | filename prefix extracted from input files |

These are useful when loading results from multiple samples into the
same database table or combined data frame:

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
  str()
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
#>  $ reads_num_uniq                           : num [1:4] 2.11e+09 8.08e+08 2.11e+09 8.08e+08
#>  $ reads_num_uniq_pct                       : num [1:4] 80.1 86.1 80.1 86.1
#>  $ reads_w_mate_seq                         : num [1:4] 2.64e+09 9.39e+08 2.64e+09 9.39e+08
#>  $ reads_w_mate_seq_pct                     : num [1:4] 100 100 100 100
#>  $ reads_wo_mate_seq                        : num [1:4] 0 0 0 0
#>  $ reads_wo_mate_seq_pct                    : num [1:4] 0 0 0 0
#>  $ reads_qcfail                             : num [1:4] 0 0 0 0
#>  $ reads_qcfail_pct                         : num [1:4] 0 0 0 0
#>  $ reads_mapped                             : num [1:4] 2.57e+09 9.19e+08 2.57e+09 9.19e+08
#>  $ reads_mapped_pct                         : num [1:4] 97.6 97.9 97.6 97.9
#>  $ reads_mapped_r1                          : num [1:4] 1.29e+09 4.61e+08 1.29e+09 4.61e+08
#>  $ reads_mapped_r1_pct                      : num [1:4] 98.1 98.2 98.1 98.2
#>  $ reads_mapped_r2                          : num [1:4] 1.28e+09 4.58e+08 1.28e+09 4.58e+08
#>  $ reads_mapped_r2_pct                      : num [1:4] 97.2 97.6 97.2 97.6
#>  $ reads_mapped_pai                         : num [1:4] 0 0 0 0
#>  $ reads_mapped_pai_pct                     : num [1:4] 0 0 0 0
#>  $ reads_mapped_nrd                         : num [1:4] 45892511 16234720 45892511 16234720
#>  $ reads_mapped_nrd_pct                     : num [1:4] 1.74 1.73 1.74 1.73
#>  $ reads_mapped_pai_nrd                     : num [1:4] 45892511 16234720 45892511 16234720
#>  $ reads_mapped_pai_nrd_pct                 : num [1:4] 1.74 1.73 1.74 1.73
#>  $ reads_mapped_rna_rrna_filt               : num [1:4] NA NA NA NA
#>  $ reads_mapped_rna_chrm_excl               : num [1:4] NA NA NA NA
#>  $ reads_mapped_incl_refext_filt_excl       : num [1:4] 2.62e+09 9.35e+08 2.62e+09 9.35e+08
#>  $ reads_mapped_incl_refext_filt_excl_pct   : num [1:4] 99.4 99.6 99.4 99.6
#>  $ reads_unmapped                           : num [1:4] 62134158 19917093 62134158 19917093
#>  $ reads_unmapped_pct                       : num [1:4] 2.36 2.12 2.36 2.12
#>  $ reads_unmapped_minus_refext              : num [1:4] 16241647 3682373 16241647 3682373
#>  $ reads_unmapped_minus_refext_pct          : num [1:4] 0.62 0.39 0.62 0.39
#>  $ reads_unmapped_minus_filt                : num [1:4] 62134158 19917093 62134158 19917093
#>  $ reads_unmapped_minus_filt_pct            : num [1:4] 2.36 2.12 2.36 2.12
#>  $ reads_unmapped_minus_excl                : num [1:4] 62134158 19917093 62134158 19917093
#>  $ reads_unmapped_minus_excl_pct            : num [1:4] 2.36 2.12 2.36 2.12
#>  $ reads_unmapped_minus_refext_filt_excl    : num [1:4] 16241647 3682373 16241647 3682373
#>  $ reads_unmapped_minus_refext_filt_excl_pct: num [1:4] 0.62 0.39 0.62 0.39
#>  $ reads_singleton                          : num [1:4] 14289628 3295781 14289628 3295781
#>  $ reads_singleton_pct                      : num [1:4] 0.54 0.35 0.54 0.35
#>  $ reads_paired                             : num [1:4] 2.56e+09 9.16e+08 2.56e+09 9.16e+08
#>  $ reads_paired_pct                         : num [1:4] 97.1 97.5 97.1 97.5
#>  $ reads_paired_proper                      : num [1:4] 2.55e+09 9.12e+08 2.55e+09 9.12e+08
#>  $ reads_paired_proper_pct                  : num [1:4] 96.7 97.1 96.7 97.1
#>  $ reads_discordant                         : num [1:4] 11520728 3939608 11520728 3939608
#>  $ reads_discordant_pct                     : num [1:4] 0.44 0.42 0.44 0.42
#>  $ reads_paired_mapped_diff_chrom           : num [1:4] 3992370 1220540 3992370 1220540
#>  $ reads_paired_mapped_diff_chrom_pct       : num [1:4] 0.16 0.13 0.16 0.13
#>  $ reads_paired_mapped_diff_chrom_mapq10    : num [1:4] 2933157 846318 2933157 846318
#>  $ reads_paired_mapped_diff_chrom_mapq10_pct: num [1:4] 0.11 0.09 0.11 0.09
#>  $ reads_map_multiloc                       : num [1:4] 1.10e+08 3.84e+07 1.10e+08 3.84e+07
#>  $ reads_map_multiloc_pct                   : num [1:4] 4.16 4.09 4.16 4.09
#>  $ reads_mapq_40_inf                        : num [1:4] 2.40e+09 8.57e+08 2.40e+09 8.57e+08
#>  $ reads_mapq_40_inf_pct                    : num [1:4] 90.9 91.3 90.9 91.3
#>  $ reads_mapq_30_40                         : num [1:4] 7124864 2469532 7124864 2469532
#>  $ reads_mapq_30_40_pct                     : num [1:4] 0.27 0.26 0.27 0.26
#>  $ reads_mapq_20_30                         : num [1:4] 17744796 6147077 17744796 6147077
#>  $ reads_mapq_20_30_pct                     : num [1:4] 0.67 0.65 0.67 0.65
#>  $ reads_mapq_10_20                         : num [1:4] 28433795 10003292 28433795 10003292
#>  $ reads_mapq_10_20_pct                     : num [1:4] 1.08 1.07 1.08 1.07
#>  $ reads_mapq_0_10                          : num [1:4] 1.24e+08 4.32e+07 1.24e+08 4.32e+07
#>  $ reads_mapq_0_10_pct                      : num [1:4] 4.7 4.6 4.7 4.6
#>  $ reads_mapq_na_unmapped                   : num [1:4] 62134158 19917093 62134158 19917093
#>  $ reads_mapq_na_unmapped_pct               : num [1:4] 2.36 2.12 2.36 2.12
#>  $ reads_indel_r1                           : num [1:4] 40110680 14217155 40110680 14217155
#>  $ reads_indel_r1_pct                       : num [1:4] 3.1 3.08 3.1 3.08
#>  $ reads_indel_r2                           : num [1:4] 37398760 13618249 37398760 13618249
#>  $ reads_indel_r2_pct                       : num [1:4] 2.92 2.97 2.92 2.97
#>  $ reads_splicejunc                         : num [1:4] NA NA NA NA
#>  $ bases_tot                                : num [1:4] 3.98e+11 1.42e+11 3.98e+11 1.42e+11
#>  $ bases_tot_r1                             : num [1:4] 1.99e+11 7.09e+10 1.99e+11 7.09e+10
#>  $ bases_tot_r2                             : num [1:4] 1.99e+11 7.09e+10 1.99e+11 7.09e+10
#>  $ bases_mapped                             : num [1:4] 3.89e+11 1.39e+11 3.89e+11 1.39e+11
#>  $ bases_mapped_r1                          : num [1:4] 1.95e+11 6.96e+10 1.95e+11 6.96e+10
#>  $ bases_mapped_r2                          : num [1:4] 1.93e+11 6.92e+10 1.93e+11 6.92e+10
#>  $ bases_softclip                           : num [1:4] 4.57e+09 1.28e+09 4.57e+09 1.28e+09
#>  $ bases_softclip_pct                       : num [1:4] 1.18 0.93 1.18 0.93
#>  $ bases_softclip_r1                        : num [1:4] 1.49e+09 4.82e+08 1.49e+09 4.82e+08
#>  $ bases_softclip_r1_pct                    : num [1:4] 0.76 0.69 0.76 0.69
#>  $ bases_softclip_r2                        : num [1:4] 3.08e+09 8.03e+08 3.08e+09 8.03e+08
#>  $ bases_softclip_r2_pct                    : num [1:4] 1.59 1.16 1.59 1.16
#>  $ bases_hardclip                           : num [1:4] 0 0 0 0
#>  $ bases_hardclip_pct                       : num [1:4] 0 0 0 0
#>  $ bases_hardclip_r1                        : num [1:4] 0 0 0 0
#>  $ bases_hardclip_r1_pct                    : num [1:4] 0 0 0 0
#>  $ bases_hardclip_r2                        : num [1:4] 0 0 0 0
#>  $ bases_hardclip_r2_pct                    : num [1:4] 0 0 0 0
#>  $ bases_mismatched_r1                      : num [1:4] 8.57e+08 3.16e+08 8.57e+08 3.16e+08
#>  $ bases_mismatched_r1_pct                  : num [1:4] 0.44 0.45 0.44 0.45
#>  $ bases_mismatched_r2                      : num [1:4] 1.83e+09 4.77e+08 1.83e+09 4.77e+08
#>  $ bases_mismatched_r2_pct                  : num [1:4] 0.94 0.69 0.94 0.69
#>  $ bases_mismatched_r1_noindels             : num [1:4] 7.35e+08 2.72e+08 7.35e+08 2.72e+08
#>  $ bases_mismatched_r1_noindels_pct         : num [1:4] 0.38 0.39 0.38 0.39
#>   [list output truncated]
```

## Metadata

Every `run()` writes a `metadata.parquet` alongside the data files. It
records the input directory, output directory, IDs, and the versions of
R packages used:

``` r

read_parquet(file.path(outdir_d, "metadata.parquet")) |> str()
#> tibble [1 × 6] (S3: tbl_df/tbl/data.frame)
#>  $ input_id    : chr NA
#>  $ output_id   : chr NA
#>  $ input_dirs  : list<character> [1:1] 
#>   ..$ : chr "/home/runner/miniconda3/envs/pkgdown_env/lib/R/library/tidydragen/extdata"
#>   ..@ ptype: chr(0) 
#>  $ output_dir  : chr "/tmp/RtmpMA5bJu/qs_dragen"
#>  $ pkg_versions: list<
#>   tbl_df<
#>     name   : character
#>     version: character
#>   >
#> > [1:1] 
#>   ..$ : tibble [2 × 2] (S3: tbl_df/tbl/data.frame)
#>   .. ..$ name   : chr [1:2] "nemo" "tidydragen"
#>   .. ..$ version: chr [1:2] "0.1.0.9005" "0.0.0.9003"
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
  how schemas, versioning, and the Tool/Workflow class hierarchy work
- [Output
  naming](https://tidywf.github.io/tidydragen/articles/output_naming.md):
  how region/phenotype variants are folded into the output prefix
- [PostgreSQL](https://tidywf.github.io/tidydragen/articles/postgresql.md):
  writing results to a database
