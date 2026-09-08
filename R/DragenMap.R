#' @title DragenMap Object
#'
#' @description
#' Parses and tidies DRAGEN mapping/alignment outputs: mapping metrics, run-time
#' metrics, and the fragment-length histogram.
#'
#' @examples
#' cls <- DragenMap; tool <- "dragenmap"
#' indir <- system.file("extdata", tool, package = "tidydragen")
#' odir <- tempdir()
#' obj <- cls$new(indir)
#' obj$run(output_dir = odir, format = "parquet", input_id = "run1")
#' (lf <- list.files(odir, pattern = "dragenmap_.*parquet", full.names = FALSE))
#' @testexamples
#' mapf <- arrow::read_parquet(file.path(odir, grep("sampleA_dragenmap_metrics", lf, value = TRUE)))
#' expect_true(all(c("section", "rg", "reads_tot_input", "reads_tot_input_pct", "reads_mapped_pct") %in% names(mapf)))
#' # section stripped to phenotype; blank SUMMARY rg -> Total
#' expect_true(all(mapf$section %in% c("TUMOR", "NORMAL", "SINGLE")))
#' summ <- mapf[mapf$section == "TUMOR" & mapf$rg == "Total", ]
#' expect_equal(summ$reads_tot_input, 2635326658)
#' expect_equal(summ$reads_mapped_pct, 97.64)
#' # run-time metrics: seconds land as the value (not the HH:MM:SS string)
#' tf <- arrow::read_parquet(file.path(odir, grep("sampleA_dragenmap_time", lf, value = TRUE)))
#' expect_equal(names(tf)[names(tf) != "input_id"][1], "total_runtime")
#' expect_equal(tf$total_runtime, 8189.85)
#' expect_equal(tf$time_aligning_reads, 2240.12)
#' expect_equal(tf$time_sorting, 120)
#' expect_equal(tf$time_umi_read_collapsing_and_remapping, 90)
#' expect_equal(tf$time_estimating_beta_binomial_overdispersion_wgs, 5)
#' # fraglenhist: per-#Sample: blocks split, sample id kept, headers dropped
#' fl <- arrow::read_parquet(file.path(odir, grep("sampleA_dragenmap_fraglenhist", lf, value = TRUE)))
#' expect_equal(names(fl)[names(fl) != "input_id"], c("sample", "fraglen", "count"))
#' expect_setequal(unique(fl$sample), c("sampleA", "sampleA_tn"))
#' expect_equal(fl$count[fl$fraglen == 150 & fl$sample == "sampleA"], 12345)
#' expect_equal(fl$count[fl$fraglen == 150 & fl$sample == "sampleA_tn"], 999)
#' @export
DragenMap <- R6::R6Class(
  "DragenMap",
  cloneable = FALSE,
  inherit = DragenTool,
  public = list(
    #' @description Create a new DragenMap object.
    #' @param path (`character(1)`)\cr
    #' Output directory of tool. If `files_tbl` is supplied, this is ignored.
    #' @param files_tbl (`tibble(n)`)\cr
    #' Tibble of files from [nemo::list_files_dir()].
    initialize = function(path = NULL, files_tbl = NULL) {
      super$initialize(name = "dragenmap", pkg = pkg_name, path = path, files_tbl = files_tbl)
    },
    #' @description Tidy `mapping_metrics.csv`. Both id columns retained
    #' (`drop_constant = character()`).
    #' @param x (`character(1)` or `tibble()`)\cr Path to file or parsed tibble.
    tidy_metrics = function(x) {
      private$tidy_metrics(x, "metrics", drop_constant = character(), normalise = function(d) {
        # strip boilerplate: section -> phenotype (SINGLE for single-sample runs),
        # blank rg (SUMMARY rows) -> Total
        d$section <- trimws(sub("MAPPING/ALIGNING (SUMMARY|PER RG)", "", d$section))
        d$section[d$section == ""] <- "SINGLE"
        d$rg[d$rg == ""] <- "Total"
        d
      })
    },
    #' @description Tidy `time_metrics.csv`, using seconds (not HH:MM:SS) as the
    #' metric value and surfacing `total_runtime` first.
    #' @param x (`character(1)` or `tibble()`)\cr Path to file or parsed tibble.
    tidy_time = function(x) {
      # use seconds col instead of HH:MM:SS col
      r <- private$tidy_metrics(x, "time", normalise = function(d) {
        d$count <- as.character(d$pct)
        d$pct <- NA_real_
        d
      })
      # keep overall runtime first
      r$data[[1]] <- dplyr::relocate(r$data[[1]], dplyr::any_of("total_runtime"))
      r
    },
    #' @description Parse `fragment_length_hist.csv` into a long tibble.
    #' @param x (`character(1)`)\cr Path to file.
    parse_fraglenhist = function(x) {
      lines <- readr::read_lines(x)
      # somatic files concatenate one histogram per sample, each opening with a
      # "#Sample: <id>" line; split on markers
      starts <- grep("^#Sample:", lines)
      ids <- trimws(sub("^#Sample:", "", lines[starts]))
      ends <- c(starts[-1] - 1L, length(lines))
      blocks <- Map(
        function(s, e) {
          body <- lines[(s + 1L):e]
          body <- body[!grepl("^FragmentLength,Count$", body)]
          readr::read_csv(
            I(body),
            col_names = c("FragmentLength", "Count"),
            col_types = readr::cols(
              FragmentLength = readr::col_integer(),
              Count = readr::col_double()
            )
          )
        },
        starts,
        ends
      )
      names(blocks) <- ids
      d <- dplyr::bind_rows(blocks, .id = "sample")
      attr(d, "file_version") <- "latest"
      d[]
    }
  )
)
