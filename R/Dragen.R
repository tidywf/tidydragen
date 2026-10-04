#' DRAGEN S3 Sync Excludes
#'
#' Trailing `--exclude` globs applied after the schema-derived includes when
#' syncing a DRAGEN run (see [s3sync()]). A ctTSO run writes the same
#' app-layer outputs twice — once under `Logs_Intermediates/<sample>/` and once
#' under `Results/<sample>/` — so these drop the `Logs_Intermediates/` copy and
#' keep the `Results/` one. `aws s3 sync` filters are ordered and last-match
#' wins, hence these must come last.
#'
#' @export
DRAGEN_SYNC_EXCLUDE <- c(
  "*Logs_Intermediates/*_CombinedVariantOutput.tsv",
  "*Logs_Intermediates/*_Fusions.csv",
  "*Logs_Intermediates/*.tmb.trace.tsv",
  "*Logs_Intermediates/*.exon_cov_report.tsv",
  "*Logs_Intermediates/*.gene_cov_report.tsv",
  "*Logs_Intermediates/*_SampleAnalysisResults.json",
  "*Logs_Intermediates/*.microsat_output.json"
)

#' @title Dragen Object
#'
#' @description
#' Orchestrates all DRAGEN tools ([DragenMap], [DragenFqc], [DragenCov],
#' [DragenVar], [DragenRna], [DragenTso], [DragenBcl]) plus [Interop] for
#' convenience. A DRAGEN run exposes a different subset of files depending on
#' the pipeline; tools whose files are absent contribute nothing, so a single
#' `Dragen$run()` works across all pipelines.
#'
#' @examples
#' indir <- system.file("extdata", package = "tidydragen")
#' odir <- tempdir()
#' d <- Dragen$new(indir)
#' d$run(output_dir = odir, format = "parquet", input_id = "run1")
#' (lf <- list.files(odir, pattern = "\\.parquet$", full.names = FALSE))
#' (pats <- d$get_sync_patterns())
#' @testexamples
#' # every registered tool emits at least one table from the combined fixtures
#' expect_true(any(grepl("_dragenmap_", lf)))
#' expect_true(any(grepl("_dragenfqc_", lf)))
#' expect_true(any(grepl("_dragencov_", lf)))
#' expect_true(any(grepl("_dragenvar_", lf)))
#' expect_true(any(grepl("_dragenrna_", lf)))
#' expect_true(any(grepl("_dragentso_", lf)))
#' expect_true(any(grepl("dragenbcl_", lf)))
#' expect_true(any(grepl("_interop_", lf)))
#' # a metadata file is written alongside the tidy outputs
#' expect_true(file.exists(file.path(odir, "metadata.parquet")))
#' # spot-check one output round-trips
#' mapf <- nemo::read_parquet_grep(odir, lf, "sampleA_dragenmap_metrics")
#' expect_gt(nrow(mapf), 0L)
#' # `aws s3 sync` filters are ordered and last-match wins, so the pattern
#' # tibble must read: deny-all, then the schema includes, then the excludes
#' # that carve the Logs_Intermediates/ duplicates back out. Reordering any of
#' # the three blocks silently changes what gets synced.
#' nex <- length(DRAGEN_SYNC_EXCLUDE)
#' expect_equal(pats$inex[1], "ex")
#' expect_equal(pats$pat[1], "*")
#' expect_true(all(utils::head(pats$inex[-1], -nex) == "in"))
#' expect_true(all(utils::tail(pats$inex, nex) == "ex"))
#' expect_equal(utils::tail(pats$pat, nex), DRAGEN_SYNC_EXCLUDE)
#' @include DragenMap.R DragenFqc.R DragenCov.R DragenVar.R DragenRna.R DragenTso.R DragenBcl.R Interop.R
#' @export
Dragen <- R6::R6Class(
  "Dragen",
  cloneable = FALSE,
  inherit = Workflow,
  public = list(
    #' @field sync_exclude (`character(n)`)\cr
    #' Trailing `aws s3 sync` excludes, see [DRAGEN_SYNC_EXCLUDE].
    sync_exclude = DRAGEN_SYNC_EXCLUDE,
    #' @description Create a new Dragen object.
    #' @param path (`character(n)`)\cr
    #' Path(s) to DRAGEN results.
    initialize = function(path = NULL) {
      super$initialize(
        name = "Dragen",
        path = path,
        tools = DRAGEN_TOOLS,
        metapkg = c("nemo", "tidydragen")
      )
    }
  )
)

#' DRAGEN Tools Supported
#'
#' List of all tools the [Dragen] workflow runs: the DRAGEN pipeline tools plus
#' [Interop].
#'
#' @export
DRAGEN_TOOLS <- list(
  dragenmap = DragenMap,
  dragenfqc = DragenFqc,
  dragencov = DragenCov,
  dragenvar = DragenVar,
  dragenrna = DragenRna,
  dragentso = DragenTso,
  dragenbcl = DragenBcl,
  interop = Interop
)

#' DRAGEN Tool Colours
#'
#' CSS colours for DRAGEN tools, used for the tool pills in
#' [nemo::nemo_schema_reactable()]. Other tools fall back to grey.
#'
#' @export
DRAGEN_TOOL_COLOURS <- c(
  dragenmap = "#3b82f6", # blue
  dragenfqc = "#d946ef", # fuchsia
  dragencov = "#14b8a6", # teal
  dragenvar = "#ef4444", # red
  dragenrna = "#8b5cf6", # violet
  dragentso = "#f59e0b", # amber
  dragenbcl = "#65a30d", # lime
  interop = "#4f46e5" # indigo
)
