#' AWS S3 Sync Helper
#'
#' @inheritParams nemo::s3sync
#'
#' @examples
#' \dontrun{
#' src <- "s3://my-awesome-bucket/path/to/run1"
#' dest <- sub("s3:/", "~/s3", src)
#' pats <- tibble::tribble(
#'   ~inex, ~pat,
#'   "ex", "*",
#'   "in", "*.mapping_metrics.csv"
#' )
#' s3sync(src, dest, pats)
#' }
#' @export
s3sync <- function(src, dest, pats = NULL, dryrun = FALSE) {
  pats_default <- tibble::tribble(
    ~inex , ~pat                                    ,
    "ex"  , "*"                                     ,
    "in"  , "*.allele_transition_noise_metrics.csv" ,
    "in"  , "*.cnv_metrics.csv"                     ,
    "in"  , "*.fastqc_metrics.csv"                  ,
    "in"  , "*.fragment_length_hist.csv"            ,
    "in"  , "*.hrdscore.csv"                        ,
    "in"  , "*.mapping_metrics.csv"                 ,
    "in"  , "*.microsat_output.json"                ,
    "in"  , "*.ploidy.vcf.gz"                       ,
    "in"  , "*.ploidy_estimation_metrics.csv"       ,
    "in"  , "*_contig_mean_cov_tumor.csv"           ,
    "in"  , "*_contig_mean_cov_normal.csv"          ,
    "in"  , "*_contig_mean_cov.csv"                 ,
    "in"  , "*_cov_report_tumor.bed"                ,
    "in"  , "*_cov_report_normal.bed"               ,
    "in"  , "*_cov_report.bed"                      ,
    "in"  , "*_coverage_metrics_tumor.csv"          ,
    "in"  , "*_coverage_metrics_normal.csv"         ,
    "in"  , "*_coverage_metrics.csv"                ,
    "in"  , "*_fine_hist_normal.csv"                ,
    "in"  , "*_fine_hist_tumor.csv"                 ,
    "in"  , "*_fine_hist.csv"                       ,
    "in"  , "*_read_cov_report_normal.bed"          ,
    "in"  , "*_read_cov_report_tumor.bed"           ,
    "in"  , "*_read_cov_report.bed"                 ,
    "in"  , "*.sv_metrics.csv"                      ,
    "in"  , "*.time_metrics.csv"                    ,
    "in"  , "*.tmb.metrics.csv"                     ,
    "in"  , "*.tmb.trace.csv"                       ,
    "in"  , "*.trimmer.metrics.csv"                 ,
    "in"  , "*.vc_metrics.csv"                      ,
    "in"  , "*.fusion_metrics.csv"                  ,
    "in"  , "*.quant_metrics.csv"                   ,
    "in"  , "*.vc_hethom_ratio_metrics.csv"
  )
  pats <- pats %||% pats_default
  nemo::s3sync(src = src, dest = dest, pats = pats, dryrun = dryrun)
}

#' AWS S3 Sync Helper (BCLConvert `Reports/`)
#'
#' Sync only the parse-relevant CSVs from a DRAGEN BCLConvert `Reports/`
#' directory (plus `RunInfo.xml` for run metadata). Excludes the binaries
#' (`IndexMetricsOut.bin`), `SampleSheet.csv`, and `report.html`. The two tile-level CSVs
#' (`Demultiplex_Tile_Stats.csv`, `Quality_Tile_Metrics.csv`) are large
#' (tens of MB) but still parse-relevant; override `pats` to drop them.
#'
#' @inheritParams nemo::s3sync
#'
#' @examples
#' \dontrun{
#' d1 <- "s3://pipeline-prod-cache-503977275616-ap-southeast-2/byob-icav2/production/primary"
#' src <- file.path(d1, "260618_A01052_0309_BHTYNGDSXF/20260619ec753acc/Reports")
#' dest <- sub(d1, here::here("nogit", "bclconvert"), src)
#' s3sync_bcl(src, dest, dryrun = TRUE)
#' }
#' @export
s3sync_bcl <- function(src, dest, pats = NULL, dryrun = FALSE) {
  pats_default <- tibble::tribble(
    ~inex , ~pat                         ,
    "ex"  , "*"                          ,
    "in"  , "Adapter_Cycle_Metrics.csv"  ,
    "in"  , "Adapter_Metrics.csv"        ,
    "in"  , "Demultiplex_Stats.csv"      ,
    "in"  , "Demultiplex_Tile_Stats.csv" ,
    "in"  , "Index_Hopping_Counts.csv"   ,
    "in"  , "Quality_Metrics.csv"        ,
    "in"  , "Quality_Tile_Metrics.csv"   ,
    "in"  , "Top_Unknown_Barcodes.csv"   ,
    "in"  , "fastq_list.csv"             ,
    "in"  , "RunInfo.xml"
  )
  pats <- pats %||% pats_default
  nemo::s3sync(src = src, dest = dest, pats = pats, dryrun = dryrun)
}

#' AWS S3 Sync Helper (ctTSO / dragen-tso500-ctdna)
#'
#' Sync only the small, parse-relevant files from a DRAGEN TSO500 ctDNA run.
#' Excludes the large binaries (BAM, gVCF, bigwig etc.) and the
#' pipeline/nextflow logs. Files live deep under `Logs_Intermediates/DragenCaller/<sample>/`
#' and `Results/<sample>/`.
#'
#' Folder-prefix excludes: `aws s3 sync` filters are ordered and last-match wins,
#' so an `"ex"` row placed *after* an `"in"` row carves a subset back out (e.g.
#' `"in", "*Tmb/*"` then `"ex", "*Tmb/*.tmb.trace.tsv"`). The default patterns use
#' this to drop the `Logs_Intermediates/` duplicates while keeping the `Results/`
#' copy.
#'
#' @inheritParams nemo::s3sync
#'
#' @examples
#' \dontrun{
#' d1 <- "s3://pipeline-prod-cache-503977275616-ap-southeast-2/byob-icav2/production/analysis"
#' src <- file.path(d1, "dragen-tso500-ctdna/20260827e81c2a44")
#' dest <- sub(d1, here::here("nogit"), src)
#' s3sync_cttso(src, dest, dryrun = TRUE)
#'
#' # custom: whole Results/ folder except one file (folder-prefix exclude)
#' pats <- tibble::tribble(
#'   ~inex, ~pat,
#'   "ex", "*",
#'   "in", "*Results/*",
#'   "ex", "*Results/*_MetricsOutput.tsv"
#' )
#' s3sync_cttso(src, dest, pats = pats, dryrun = TRUE)
#' }
#' @export
s3sync_cttso <- function(src, dest, pats = NULL, dryrun = FALSE) {
  pats_default <- tibble::tribble(
    ~inex , ~pat                                              ,
    "ex"  , "*"                                               ,
    # --- DRAGEN metrics (existing M-tables) ---
    "in"  , "*.mapping_metrics.csv"                           ,
    "in"  , "*.time_metrics.csv"                              ,
    "in"  , "*.fastqc_metrics.csv"                            ,
    "in"  , "*.fragment_length_hist.csv"                      ,
    "in"  , "*.cnv_metrics.csv"                               ,
    "in"  , "*.sv_metrics.csv"                                ,
    "in"  , "*.vc_metrics.csv"                                ,
    "in"  , "*.microsat_output.json"                          ,
    # --- DRAGEN metrics (new Tier-1 cttso M-tables) ---
    "in"  , "*.trimmer_metrics.csv"                           ,
    "in"  , "*.umi_metrics.csv"                               ,
    "in"  , "*.gc_metrics.csv"                                ,
    "in"  , "*.gvcf_metrics.csv"                              ,
    # --- small non-metrics smalls (Tier 1c) ---
    "in"  , "*.contamination.json"                            , # p-value not in SAR
    # --- coverage (all 4 regions: wgs / tmb / exon / target_bed) ---
    "in"  , "*_coverage_metrics.csv"                          ,
    "in"  , "*_contig_mean_cov.csv"                           ,
    "in"  , "*_fine_hist.csv"                                 ,
    "in"  , "*read_cov_report.bed"                            ,
    "in"  , "*_cov_report.bed"                                ,
    # --- tmb (Tmb/ subdir) ---
    "in"  , "*.tmb.metrics.csv"                               ,
    "in"  , "*.tmb.msaf.csv"                                  ,
    # --- Tier-2 TSO500 app-layer (custom parsers; NOT dragen-metrics) ---
    "in"  , "*_CombinedVariantOutput.tsv"                     ,
    "in"  , "*_Fusions.csv"                                   ,
    "in"  , "*.tmb.trace.tsv"                                 ,
    "in"  , "*.exon_cov_report.tsv"                           ,
    "in"  , "*.gene_cov_report.tsv"                           ,
    "in"  , "*_SampleAnalysisResults.json"                    ,
    # --- drop the Logs_Intermediates/ duplicates; keep the Results/ copy ---
    "ex"  , "*Logs_Intermediates/*_CombinedVariantOutput.tsv" ,
    "ex"  , "*Logs_Intermediates/*_Fusions.csv"               ,
    "ex"  , "*Logs_Intermediates/*.tmb.trace.tsv"             ,
    "ex"  , "*Logs_Intermediates/*.exon_cov_report.tsv"       ,
    "ex"  , "*Logs_Intermediates/*.gene_cov_report.tsv"       ,
    "ex"  , "*Logs_Intermediates/*.microsat_output.json"
  )
  pats <- pats %||% pats_default
  nemo::s3sync(src = src, dest = dest, pats = pats, dryrun = dryrun)
}
