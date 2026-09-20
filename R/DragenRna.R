#' @title DragenRna Object
#'
#' @description
#' Parses and tidies DRAGEN RNA outputs (gene-fusion statistics, quantification
#' statistics).
#'
#' @examples
#' cls <- DragenRna; tool <- "dragenrna"
#' indir <- system.file("extdata", tool, package = "tidydragen")
#' odir <- tempdir()
#' obj <- cls$new(indir)
#' obj$run(output_dir = odir, format = "parquet", input_id = "run1", output_id = "out1")
#' (lf <- list.files(odir, pattern = "dragenrna_.*parquet", full.names = FALSE))
#' @testexamples
#' fus <- nemo::read_parquet_grep(odir, lf, "sampleA_dragenrna_fusion")
#' expect_equal(fus$fusions_all_unfiltered, 7008)
#' expect_equal(fus$fusions_unique_passing, 20)
#' qnt <- nemo::read_parquet_grep(odir, lf, "sampleA_dragenrna_quant")
#' expect_equal(qnt$library_orientation, "ISR")
#' expect_equal(qnt$genes_tot, 62700)
#' expect_equal(qnt$genes_cov_gt1x_pct, 36.94)
#' @export
DragenRna <- R6::R6Class(
  "DragenRna",
  cloneable = FALSE,
  inherit = DragenTool,
  public = list(
    #' @description Create a new DragenRna object.
    #' @param path (`character(1)`)\cr
    #' Output directory of tool. If `files_tbl` is supplied, this is ignored.
    #' @param files_tbl (`tibble(n)`)\cr
    #' Tibble of files from [nemo::list_files_dir()].
    initialize = function(path = NULL, files_tbl = NULL) {
      super$initialize(name = "dragenrna", pkg = pkg_name, path = path, files_tbl = files_tbl)
    }
    # `fusion` and `quant` are plain `dragen-metrics` tables — parsed and tidied
    # via the ftype dispatch on DragenTool, so they need no methods here.
  )
)
