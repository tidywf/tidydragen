#' @title Dragen Object
#'
#' @description
#' Orchestrates all DRAGEN tools ([DragenMap], [DragenFqc], [DragenCov],
#' [DragenVar], [DragenRna], [DragenTso]) over a shared results directory. A DRAGEN run
#' exposes a different subset of files depending on the pipeline (germline,
#' somatic tumor-normal, RNA); tools whose files are absent contribute nothing,
#' so a single `Dragen$run()` works across all pipelines.
#'
#' @examples
#' indir <- system.file("extdata", package = "tidydragen")
#' odir <- tempdir()
#' d <- Dragen$new(indir)
#' d$run(output_dir = odir, format = "parquet", input_id = "run1")
#' (lf <- list.files(odir, pattern = "dragen.*parquet", full.names = FALSE))
#' @testexamples
#' # every registered tool emits at least one table from the combined fixtures
#' expect_true(any(grepl("_dragenmap_", lf)))
#' expect_true(any(grepl("_dragenfqc_", lf)))
#' expect_true(any(grepl("_dragencov_", lf)))
#' expect_true(any(grepl("_dragenvar_", lf)))
#' expect_true(any(grepl("_dragenrna_", lf)))
#' expect_true(any(grepl("_dragentso_", lf)))
#' # a metadata file is written alongside the tidy outputs
#' expect_true(file.exists(file.path(odir, "metadata.parquet")))
#' # spot-check one output round-trips
#' mapf <- arrow::read_parquet(file.path(odir, grep("sampleA_dragenmap_metrics", lf, value = TRUE)))
#' expect_true(all(c("section", "rg") %in% names(mapf)))
#' @include DragenMap.R DragenFqc.R DragenCov.R DragenVar.R DragenRna.R DragenTso.R
#' @export
Dragen <- R6::R6Class(
  "Dragen",
  cloneable = FALSE,
  inherit = Workflow,
  public = list(
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
#' List of all supported DRAGEN tools.
#'
#' @export
DRAGEN_TOOLS <- list(
  dragenmap = DragenMap,
  dragenfqc = DragenFqc,
  dragencov = DragenCov,
  dragenvar = DragenVar,
  dragenrna = DragenRna,
  dragentso = DragenTso
)
