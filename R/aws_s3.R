#' AWS S3 Sync Helper
#'
#' Syncs the parse-relevant DRAGEN outputs (any pipeline, incl. BCLConvert
#' `Reports/`) from `src` to `dest`. Include patterns come from the tool schemas
#' (see [nemo::wf_sync_patterns()]), followed by [DRAGEN_SYNC_EXCLUDE].
#'
#' @inheritParams nemo::s3sync
#'
#' @examples
#' \dontrun{
#' src <- "s3://my-awesome-bucket/path/to/run1"
#' dest <- sub("s3:/", "~/s3", src)
#' s3sync(src, dest, dryrun = TRUE)
#'
#' # inspect what would be pulled down
#' nemo::wf_sync_patterns("dragen")
#'
#' # override with your own patterns
#' pats <- tibble::tribble(
#'   ~inex, ~pat,
#'   "ex", "*",
#'   "in", "*.mapping_metrics.csv"
#' )
#' s3sync(src, dest, pats)
#' }
#' @export
s3sync <- function(src, dest, pats = NULL, dryrun = FALSE) {
  nemo::s3sync(src = src, dest = dest, pats = pats, workflow = "dragen", dryrun = dryrun)
}
