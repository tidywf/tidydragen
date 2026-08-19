#' AWS S3 Sync Helper
#'
#' @param src (`character(1)`)\cr
#' S3 source path.
#' @param dest (`character(1)`)\cr
#' Local destination path.
#' @param pats (`tibble()`)\cr
#' Patterns tibble with `inex` ("in" or "ex") and `pat` (pattern) columns.
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
s3sync <- function(src, dest, pats = NULL) {
  pats_default <- tibble::tribble(
    ~inex , ~pat                                    ,
    "ex"  , "*"                                     ,
    "in"  , "*-replay.json"                         ,
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
    "in"  , "*_hist_normal.csv"                     ,
    "in"  , "*_hist_tumor.csv"                      ,
    "in"  , "*_hist.csv"                            ,
    "in"  , "*_overall_mean_cov_tumor.csv"          ,
    "in"  , "*_overall_mean_cov_normal.csv"         ,
    "in"  , "*_overall_mean_cov.csv"                ,
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
  nemo::s3sync(src = src, dest = dest, pats = pats)
}
