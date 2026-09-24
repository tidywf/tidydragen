#' AWS S3 Sync Helper
#'
#' Syncs the parse-relevant DRAGEN outputs from `src` to `dest`. The default
#' include patterns are **generated from the tool schemas** under
#' `inst/config/tools/*/schema.yaml` (see [nemo::wf_sync_patterns()]), so adding
#' a table to a schema automatically adds it here — there is no hand-maintained
#' file list to keep in sync.
#'
#' This single helper replaces the former `s3sync()`/`s3sync_bcl()`/
#' `s3sync_cttso()` trio: the schemas of [DragenBcl], [DragenTso] and the rest
#' are all part of the [Dragen] workflow, so one pattern set covers BCLConvert
#' `Reports/` directories, ctTSO runs and ordinary DRAGEN runs alike. Point
#' `src` at whichever directory you have; patterns that do not apply simply
#' match nothing.
#'
#' The ctTSO `Logs_Intermediates/` duplicates are dropped via
#' `Dragen$sync_exclude` (see [DRAGEN_SYNC_EXCLUDE]), keeping the `Results/`
#' copy only. `aws s3 sync` filters are ordered and last-match wins, so those
#' excludes are applied after the schema-derived includes.
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
