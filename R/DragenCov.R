#' @title DragenCov Object
#'
#' @description
#' Parses and tidies DRAGEN coverage outputs (per-contig mean coverage, coverage
#' metrics, fine histograms, and coverage-report BEDs).
#' The coverage region (`wgs` / `tmb` /`qc-coverage-region-{<region>}`) and
#' phenotype (`normal` / `tumor`) are folded from the filename into the output
#' `prefix` by `DragenTool`'s `refine_files()` hook, so one schema table serves
#' every region/phenotype variant.
#'
#' Several tables carry custom `parse_`/`tidy_` methods: the coverage metrics
#' split into `metricsmain`/`metricsbins`/`metricscumu`; the fine histogram
#' strips its terminal `2000+` bin to an integer; and the coverage-report BED
#' splits its user-configurable `pct_above` thresholds into a long `reportbedcumu`
#' table. The rest - the headless contig-mean CSV (`csv-nohead` extra ftype) and
#' the per-gene read-report BED (`tsv`) - dispatch through nemo's ftype parser and
#' the standard positional `tidy_file` rename.
#'
#' @examples
#' cls <- DragenCov; tool <- "dragencov"
#' indir <- system.file("extdata", tool, package = "tidydragen")
#' odir <- tempdir()
#' obj <- cls$new(indir)
#' obj$run(output_dir = odir, format = "parquet", input_id = "run1")
#' (lf <- list.files(odir, pattern = "dragencov_.*parquet", full.names = FALSE))
#' @testexamples
#' # region + phenotype are folded into the prefix by refine_files()
#' expect_true(any(grepl("sampleA_wgs_dragencov_contigmean", lf)))
#' expect_true(any(grepl("sampleA_wgs_tumor_dragencov_contigmean", lf)))
#' expect_true(any(grepl("sampleA_wgs_normal_dragencov_contigmean", lf)))
#' cm <- arrow::read_parquet(file.path(odir, grep("sampleA_wgs_dragencov_contigmean", lf, value = TRUE)))
#' expect_true(all(c("chrom", "bases", "cov_mean") %in% names(cm)))
#' expect_equal(cm$cov_mean[cm$chrom == "chr1"], 38.9244)
#' fh <- arrow::read_parquet(file.path(odir, grep("sampleA_wgs_dragencov_finehist", lf, value = TRUE)))
#' expect_true(all(c("depth", "count") %in% names(fh)))
#' expect_true(is.integer(fh$depth))
#' expect_equal(fh$count[fh$depth == 0], 143287543)
#' # terminal "2000+" bin -> integer 2000
#' expect_equal(fh$count[fh$depth == 2000], 80656)
#' # cov_report BED split: distribution stats -> reportbedmain, configurable pct thresholds -> reportbedcumu (long)
#' rb <- arrow::read_parquet(file.path(odir, grep("umccr_dragencov_reportbedmain", lf, value = TRUE)))
#' expect_true(all(c("chrom", "start", "end", "mean_cvg", "max_cvg") %in% names(rb)))
#' expect_false(any(grepl("^pct_above", names(rb))))
#' rc <- arrow::read_parquet(file.path(odir, grep("umccr_dragencov_reportbedcumu", lf, value = TRUE)))
#' expect_true(all(c("chrom", "start", "end", "cov_min", "pct_above") %in% names(rc)))
#' expect_true(is.integer(rc$cov_min))
#' # threshold pct_above_20 for chr1:2555638-2565382 = 98.96
#' expect_equal(rc$pct_above[rc$cov_min == 20 & rc$start == 2555638], 98.96)
#' # read_cov_report BED (per-gene) stays a single table
#' rr <- arrow::read_parquet(file.path(odir, grep("umccr_dragencov_readreportbed", lf, value = TRUE)))
#' expect_true(all(c("gene_id", "read1_cvg", "read2_cvg") %in% names(rr)))
#' # coverage metrics split: summary -> metricsmain, bucketed -> metricsbins, cumulative -> metricscumu
#' cvm <- arrow::read_parquet(file.path(odir, grep("sampleA_wgs_dragencov_metricsmain", lf, value = TRUE)))
#' expect_equal(cvm$cov_alignment_avg, 37.32)
#' expect_equal(cvm$bases_aligned_tot, 112632383850)
#' expect_equal(cvm$bases_aligned_in_region, 112632383850)
#' expect_equal(cvm$bases_aligned_in_region_pct, 100)
#' expect_equal(cvm$cov_x_median_ign0, 39)
#' # bucketed bins: finite [cov_lo, cov_hi), e.g. [20x: 50x) = 84.25; no NA upper bound
#' cvb <- arrow::read_parquet(file.path(odir, grep("sampleA_wgs_dragencov_metricsbins", lf, value = TRUE)))
#' expect_true(all(c("cov_lo", "cov_hi", "pct") %in% names(cvb)))
#' expect_false(any(is.na(cvb$cov_hi)))
#' expect_equal(cvb$pct[cvb$cov_lo == 20 & cvb$cov_hi == 50], 84.25)
#' # cumulative: cov_min only (coverage >= threshold), e.g. >= 100x = 0.07; no cov_hi column
#' cvc <- arrow::read_parquet(file.path(odir, grep("sampleA_wgs_dragencov_metricscumu", lf, value = TRUE)))
#' expect_true(all(c("cov_min", "pct") %in% names(cvc)))
#' expect_false("cov_hi" %in% names(cvc))
#' expect_equal(cvc$pct[cvc$cov_min == 100], 0.07)
#' @export
DragenCov <- R6::R6Class(
  "DragenCov",
  cloneable = FALSE,
  inherit = DragenTool,
  public = list(
    #' @description Create a new DragenCov object.
    #' @param path (`character(1)`)\cr
    #' Output directory of tool. If `files_tbl` is supplied, this is ignored.
    #' @param files_tbl (`tibble(n)`)\cr
    #' Tibble of files from [nemo::list_files_dir()].
    initialize = function(path = NULL, files_tbl = NULL) {
      super$initialize(name = "dragencov", pkg = pkg_name, path = path, files_tbl = files_tbl)
    },
    #' @description Tidy `*_coverage_metrics.csv` into three tables: the summary
    #' metrics (`metricsmain`, wide); the bucketed coverage-depth histogram
    #' (`metricsbins`, long - one row per finite `(cov_lo, cov_hi)` bin); and the
    #' cumulative coverage (`metricscumu`, long - one row per open `(cov_min, inf)`
    #' bin, i.e. PCT of bases with coverage >= cov_min). The two bin families are
    #' kept in separate tables so each is homogeneous (no infinite/NA upper bound,
    #' and `sum(pct)` is meaningful within a table). The region is stripped from the
    #' summary names (it is carried in the prefix via `refine_files()`) with
    #' [dragen_cov_metric_normalize()]; bin bounds are parsed with
    #' [dragen_cov_bin_split()].
    #' @param x (`character(1)` or `tibble()`)\cr Path to file or parsed tibble.
    tidy_metrics = function(x) {
      if (!tibble::is_tibble(x)) {
        x <- private$parse_metrics(x)
      }
      # separate the coverage-depth bin rows from the summary metrics.
      is_bin <- grepl(
        "^PCT of (?:genome|target region|QC coverage region) with coverage \\[",
        x$variable
      )
      main <- private$tidy_metrics(
        x[!is_bin, , drop = FALSE],
        "metrics",
        normalise = function(d) {
          d$variable <- dragen_cov_metric_normalize(d$variable)
          d
        }
      )
      # attach bin bounds, then partition: bucketed [lo:hi) vs cumulative [N:inf)
      # (the open bins, where cov_hi is NA).
      binx <- x[is_bin, , drop = FALSE]
      bnd <- dragen_cov_bin_split(binx$variable)
      binx$cov_lo <- bnd$cov_lo
      binx$cov_hi <- bnd$cov_hi
      is_cumu <- is.na(binx$cov_hi)
      bins <- private$tidy_metrics(
        binx[!is_cumu, , drop = FALSE],
        "bins",
        normalise = function(d) {
          d$variable <- "cov_pct"
          d
        }
      )
      cumu <- private$tidy_metrics(
        binx[is_cumu, , drop = FALSE],
        "cumu",
        normalise = function(d) {
          d$cov_min <- d$cov_lo
          d$cov_lo <- NULL
          d$cov_hi <- NULL
          d$variable <- "cov_pct"
          d
        }
      )
      # sub-table names concatenate onto the parser "metrics" ->
      # dragencov_metricsmain / dragencov_metricsbins / dragencov_metricscumu
      main$name <- "main"
      bins$name <- "bins"
      cumu$name <- "cumu"
      dplyr::bind_rows(main, bins, cumu)
    },
    #' @description Parse `*_fine_hist.csv`. The terminal depth bin is written as
    #' e.g. `2000+` ("2000 or more"); the trailing `+` is stripped and `depth`
    #' returned as an integer so downstream numeric use needs no cast. `2000+`
    #' collapses to `2000` - DRAGEN never emits a bare `2000` row alongside it.
    #' @param x (`character(1)`)\cr Path to file.
    parse_finehist = function(x) {
      d <- readr::read_csv(
        x,
        col_types = readr::cols(
          Depth = readr::col_character(),
          Overall = readr::col_double()
        )
      )
      d[["Depth"]] <- as.integer(sub("\\+$", "", d[["Depth"]]))
      attr(d, "file_version") <- "latest"
      d[]
    },
    #' @description Parse `*_cov_report.bed`. Read generically (all columns as
    #' character) rather than through the fixed `tsv` schema, because the trailing
    #' `pct_above_<N>` threshold columns are user-configurable and so vary between
    #' runs; `tidy_reportbed()` types and splits the frame.
    #' @param x (`character(1)`)\cr Path to file.
    parse_reportbed = function(x) {
      d <- readr::read_tsv(x, col_types = readr::cols(.default = readr::col_character()))
      attr(d, "file_version") <- "latest"
      d[]
    },
    #' @description Tidy `*_cov_report.bed` into two tables: the per-interval
    #' distribution stats (`reportbedmain`, wide) and the cumulative coverage
    #' thresholds (`reportbedcumu`, long - one row per interval x `pct_above_<N>`
    #' column, with `cov_min` = N and `pct_above` the value). The thresholds are
    #' split off rather than kept as wide columns because they are user-configurable
    #' and so vary between runs.
    #' @param x (`character(1)` or `tibble()`)\cr Path to file or parsed tibble.
    tidy_reportbed = function(x) {
      if (!tibble::is_tibble(x)) {
        x <- private$parse_reportbed(x)
      }
      main <- x |>
        dplyr::transmute(
          chrom = .data[["#chrom"]],
          start = as.integer(.data$start),
          end = as.integer(.data$end),
          total_cvg = as.double(.data$total_cvg),
          mean_cvg = as.double(.data$mean_cvg),
          q1_cvg = as.double(.data$Q1_cvg),
          median_cvg = as.double(.data$median_cvg),
          q3_cvg = as.double(.data$Q3_cvg),
          min_cvg = as.double(.data$min_cvg),
          max_cvg = as.double(.data$max_cvg)
        )
      cumu <- x |>
        dplyr::select(chrom = "#chrom", "start", "end", dplyr::starts_with("pct_above_")) |>
        tidyr::pivot_longer(
          cols = dplyr::starts_with("pct_above_"),
          names_to = "cov_min",
          names_prefix = "pct_above_",
          values_to = "pct_above"
        ) |>
        dplyr::transmute(
          chrom = .data$chrom,
          start = as.integer(.data$start),
          end = as.integer(.data$end),
          cov_min = as.integer(.data$cov_min),
          pct_above = as.double(.data$pct_above)
        )
      main <- list(main) |> rlang::set_names("main") |> nemo::nemo_enframe()
      cumu <- list(cumu) |> rlang::set_names("cumu") |> nemo::nemo_enframe()
      dplyr::bind_rows(main, cumu)
    }
  )
)
