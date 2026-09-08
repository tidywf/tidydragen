#' @title DragenFastqc Object
#'
#' @description
#' Parses and tidies the DRAGEN FASTQC metrics file (`fastqc_metrics.csv`).
#' Splits into 8 per-section sub-tables. Setting `flat_tidy_names = TRUE`
#' gives flat `dragenfastqc_<section>` tables rather than the concatenated form.
#'
#' @examples
#' cls <- DragenFastqc; tool <- "dragenfastqc"
#' indir <- system.file("extdata", tool, package = "tidydragen")
#' odir <- tempdir()
#' obj <- cls$new(indir)
#' obj$run(output_dir = odir, format = "parquet", input_id = "run1")
#' (lf <- list.files(odir, pattern = "dragenfastqc_.*parquet", full.names = FALSE))
#' @testexamples
#' # one file -> 8 flat per-section sub-tables (parser token dropped)
#' fqc <- grep("sampleA_dragenfastqc_", lf, value = TRUE)
#' expect_length(fqc, 8)
#' expect_true(all(c(
#'   "sampleA_dragenfastqc_posbasecontent", "sampleA_dragenfastqc_posbasemeanqual",
#'   "sampleA_dragenfastqc_posqual", "sampleA_dragenfastqc_readgc",
#'   "sampleA_dragenfastqc_readgcqual", "sampleA_dragenfastqc_readlen",
#'   "sampleA_dragenfastqc_readmeanqual", "sampleA_dragenfastqc_seqpos"
#' ) %in% sub("\\.parquet$", "", fqc)))
#' pbc <- arrow::read_parquet(file.path(odir, grep("posbasecontent", fqc, value = TRUE)))
#' expect_equal(names(pbc)[names(pbc) != "input_id"], c("mate", "pos", "base", "prop"))
#' # base proportion at Read1 pos1: A = 60/(60+20+15+5) = 0.6
#' expect_equal(pbc$prop[pbc$mate == "Read1" & pbc$pos == 1 & pbc$base == "A"], 0.6)
#' # binned "2-3" position expands to pos 2 and 3; open "256+" -> single pos 256
#' expect_setequal(pbc$pos[pbc$mate == "Read1"], c(1, 2, 3, 256))
#' expect_true(is.integer(pbc$pos))
#' # binned read-length count divided evenly across the span: 40 over 149-150 -> 20 each
#' rl <- arrow::read_parquet(file.path(odir, grep("readlen", fqc, value = TRUE)))
#' expect_equal(rl$reads[rl$mate == "Read1" & rl$bp == 150], 20)
#' expect_equal(rl$reads[rl$mate == "Read1" & rl$bp == 100], 80)
#' # open ">=255bp" bin -> single length 255, count kept (not divided)
#' expect_equal(rl$reads[rl$mate == "Read1" & rl$bp == 255], 4)
#' # positional quality quantile
#' pq <- arrow::read_parquet(file.path(odir, grep("posqual", fqc, value = TRUE)))
#' expect_equal(pq$qv[pq$mate == "Read1" & pq$pos == 1 & pq$pct == 25], 30)
#' # seqpos: "Total Sequence Starts" summary rows dropped; per-position kept
#' sp <- arrow::read_parquet(file.path(odir, grep("seqpos", fqc, value = TRUE)))
#' expect_equal(sp$starts[sp$mate == "Read1" & sp$bp == 1], 26)
#' expect_false(any(sp$starts == 254687))
#' # binned "137-140" count split evenly across the 4 positions: 40 -> 10 each
#' expect_equal(sp$starts[sp$mate == "Read1" & sp$bp == 138], 10)
#' expect_setequal(sp$bp[sp$mate == "Read1"], c(1, 137, 138, 139, 140))
#' # empty seqpos (adapter never found at a position, only a Total row) still
#' # yields an integer bp column; also exercises the path-input branch of tidy_posbasecontent
#' d2 <- file.path(tempdir(), "fqempty"); dir.create(d2, showWarnings = FALSE)
#' writeLines(c(
#'   "READ MEAN QUALITY,Read1,Q30 Reads,10",
#'   "SEQUENCE POSITIONS,Read1,'AGATCGGAAGAG' Total Sequence Starts,5,0.01"
#' ), file.path(d2, "sampleZ.fastqc_metrics.csv"))
#' ez <- DragenFastqc$new(d2)$tidy_posbasecontent(list.files(d2, full.names = TRUE))
#' ezsp <- ez$data[[which(ez$name == "seqpos")]]
#' expect_equal(nrow(ezsp), 0L)
#' expect_true(is.integer(ezsp$bp))
#' @export
DragenFastqc <- R6::R6Class(
  "DragenFastqc",
  cloneable = FALSE,
  inherit = DragenTool,
  public = list(
    #' @field flat_tidy_names (`logical(1)`)\cr
    #' drop the parser token so the 8 sub-tables are named
    #' `dragenfastqc_<section>` (see [nemo::Tool]).
    flat_tidy_names = TRUE,
    #' @description Create a new DragenFastqc object.
    #' @param path (`character(1)`)\cr
    #' Output directory of tool. If `files_tbl` is supplied, this is ignored.
    #' @param files_tbl (`tibble(n)`)\cr
    #' Tibble of files from [nemo::list_files_dir()].
    initialize = function(path = NULL, files_tbl = NULL) {
      super$initialize(name = "dragenfastqc", pkg = pkg_name, path = path, files_tbl = files_tbl)
    },
    #' @description Parse headerless `section,mate,metric,value` `fastqc_metrics.csv`
    #' into a long tibble.
    #' @param x (`character(1)`)\cr Path to file.
    parse_posbasecontent = function(x) {
      d <- readr::read_lines(x) |>
        tibble::as_tibble_col(column_name = "raw") |>
        # drop "Total Sequence Starts" rows: extra field, derivable from the rest
        # of the SEQUENCE POSITIONS section
        dplyr::filter(!grepl("Total Sequence Starts", .data$raw)) |>
        tidyr::separate_wider_delim(
          "raw",
          delim = ",",
          names = c("section", "mate", "metric", "value")
        ) |>
        dplyr::mutate(
          value = dplyr::na_if(.data$value, "NA"),
          value = as.numeric(.data$value)
        )
      attr(d, "file_version") <- "latest"
      d[]
    },
    #' @description Tidy `fastqc_metrics.csv` into 8 long per-section sub-tables.
    #' @param x (`character(1)` or `tibble()`)\cr Path to file or parsed tibble.
    tidy_posbasecontent = function(x) {
      if (!tibble::is_tibble(x)) {
        x <- self$parse_posbasecontent(x)
      }
      # count: expand binned positions, divide count across grains, then express
      # each base as a proportion of the total bases at that (mate, pos).
      posbasecontent <- x |>
        dplyr::filter(.data$section == "POSITIONAL BASE CONTENT") |>
        tidyr::separate_wider_delim(
          "metric",
          delim = " ",
          names = c("readpos", "pos", "base", "bases")
        ) |>
        dplyr::mutate(
          bin_group = dplyr::row_number(),
          pos = fastqc_bin_expand(fastqc_bin_open(.data$pos))
        ) |>
        tidyr::unnest_longer("pos") |>
        dplyr::mutate(value = .data$value / dplyr::n(), .by = "bin_group") |>
        dplyr::mutate(pos = as.integer(.data$pos)) |>
        dplyr::mutate(
          tot = sum(.data$value),
          prop = ifelse(.data$tot == 0, 0, round(.data$value / .data$tot, 3)),
          .by = c("mate", "pos")
        ) |>
        dplyr::select("mate", "pos", "base", "prop")
      # per-base mean quality: an average, so kept as-is across expanded bins.
      posbasemeanqual <- x |>
        dplyr::filter(.data$section == "POSITIONAL BASE MEAN QUALITY") |>
        tidyr::separate_wider_delim(
          "metric",
          delim = " ",
          names = c("readpos", "pos", "base", "avg", "qual")
        ) |>
        dplyr::mutate(pos = fastqc_bin_expand(fastqc_bin_open(.data$pos))) |>
        tidyr::unnest_longer("pos") |>
        dplyr::mutate(avg_qual = round(.data$value, 2), pos = as.integer(.data$pos)) |>
        dplyr::select("mate", "pos", "base", "avg_qual")
      # per-position quality quantiles (QV): kept as-is across expanded bins.
      posqual <- x |>
        dplyr::filter(.data$section == "POSITIONAL QUALITY") |>
        tidyr::separate_wider_delim(
          "metric",
          delim = " ",
          names = c("readpos", "pos", "pct", "quant", "qv")
        ) |>
        dplyr::mutate(pos = fastqc_bin_expand(fastqc_bin_open(.data$pos))) |>
        tidyr::unnest_longer("pos") |>
        dplyr::mutate(
          pct = as.integer(sub("%", "", .data$pct)),
          pos = as.integer(.data$pos),
          qv = .data$value
        ) |>
        dplyr::select("mate", "pos", "pct", "qv")
      # read count per %GC bin (not position-binned; no split).
      readgc <- x |>
        dplyr::filter(.data$section == "READ GC CONTENT") |>
        tidyr::separate_wider_delim(
          "metric",
          delim = " ",
          names = c("pct", "gc", "reads")
        ) |>
        dplyr::mutate(gc_pct = as.integer(sub("%", "", .data$pct)), reads = .data$value) |>
        dplyr::select("mate", "gc_pct", "reads")
      # mean read quality per %GC bin.
      readgcqual <- x |>
        dplyr::filter(.data$section == "READ GC CONTENT QUALITY") |>
        tidyr::separate_wider_delim(
          "metric",
          delim = " ",
          names = c("pct", "gc", "reads", "avg", "qual")
        ) |>
        dplyr::mutate(
          gc_pct = as.integer(sub("%", "", .data$pct)),
          avg_qual = round(.data$value, 2)
        ) |>
        dplyr::select("mate", "gc_pct", "avg_qual")
      # count: expand binned lengths, divide count across grains.
      readlen <- x |>
        dplyr::filter(.data$section == "READ LENGTHS") |>
        tidyr::separate_wider_delim(
          "metric",
          delim = " ",
          names = c("bp", "len", "reads")
        ) |>
        dplyr::mutate(
          bp = fastqc_bin_expand(fastqc_bin_open(sub("bp", "", .data$bp))),
          bin_group = dplyr::row_number()
        ) |>
        tidyr::unnest_longer("bp") |>
        dplyr::mutate(reads = .data$value / dplyr::n(), .by = "bin_group") |>
        dplyr::mutate(bp = as.integer(.data$bp)) |>
        dplyr::select("mate", "bp", "reads")
      # read count per mean-quality (Q) bin (not position-binned; no split).
      readmeanqual <- x |>
        dplyr::filter(.data$section == "READ MEAN QUALITY") |>
        tidyr::separate_wider_delim(
          "metric",
          delim = " ",
          names = c("q", "reads")
        ) |>
        dplyr::mutate(q = as.integer(sub("Q", "", .data$q)), reads = .data$value) |>
        dplyr::select("mate", "q", "reads")
      # count: per-sequence start counts by position; positions can be binned
      # (e.g. "137-140bp"), so expand and divide the count across grains.
      seqpos <- x |>
        dplyr::filter(.data$section == "SEQUENCE POSITIONS") |>
        tidyr::separate_wider_delim(
          "metric",
          delim = " ",
          names = c("seq", "bp", "starts")
        ) |>
        dplyr::mutate(
          bp = fastqc_bin_expand(fastqc_bin_open(sub("bp", "", .data$bp))),
          bin_group = dplyr::row_number()
        ) |>
        tidyr::unnest_longer("bp") |>
        dplyr::mutate(starts = .data$value / dplyr::n(), .by = "bin_group") |>
        dplyr::mutate(bp = as.integer(.data$bp)) |>
        dplyr::select("mate", "seq", "bp", "starts")
      list(
        posbasecontent = posbasecontent,
        posbasemeanqual = posbasemeanqual,
        posqual = posqual,
        readgc = readgc,
        readgcqual = readgcqual,
        readlen = readlen,
        readmeanqual = readmeanqual,
        seqpos = seqpos
      ) |>
        nemo::nemo_enframe()
    }
  )
)
