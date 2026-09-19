#' @title DragenCov Object
#'
#' @description
#' Parses and tidies DRAGEN coverage outputs (per-contig mean coverage, coverage
#' metrics, fine histograms, and coverage-report BEDs). Some files fan out into
#' multiple output tables: `tidy_metricsmain` splits the coverage metrics into
#' `metricsmain`/`metricsbins`/`metricscumu`, and `tidy_reportbedmain` splits the
#' coverage-report BED into `reportbedmain`/`reportbedcumu`. Every other table has
#' `tidy_name == parser`, so its name is unchanged. The per-method docs below cover
#' each table's specifics.
#'
#' The coverage region (`wgs` / `tmb` /`qc-coverage-region-{<region>}`) and
#' phenotype (`normal` / `tumor`) are folded from the filename into the output
#' `prefix` by `DragenTool`'s `refine_files()` hook, so one schema table serves
#' every region/phenotype variant.
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
#' expect_equal(cm$cov_mean[cm$chrom == "chr1"], 38.9244)
#' fh <- arrow::read_parquet(file.path(odir, grep("sampleA_wgs_dragencov_finehist", lf, value = TRUE)))
#' expect_true(is.integer(fh$depth))
#' expect_equal(fh$count[fh$depth == 0], 143287543)
#' # terminal "2000+" bin -> integer 2000
#' expect_equal(fh$count[fh$depth == 2000], 80656)
#' # cov_report BED split: distribution stats -> reportbedmain, configurable pct thresholds -> reportbedcumu (long)
#' rb <- arrow::read_parquet(file.path(odir, grep("umccr_dragencov_reportbedmain", lf, value = TRUE)))
#' expect_true(is.numeric(rb$mean_cvg))
#' expect_false(any(grepl("^pct_above", names(rb))))
#' rc <- arrow::read_parquet(file.path(odir, grep("umccr_dragencov_reportbedcumu", lf, value = TRUE)))
#' expect_true(is.integer(rc$cov_min))
#' # threshold pct_above_20 for the region starting at 470290 = 99.11
#' expect_equal(rc$pct_above[rc$cov_min == 20 & rc$start == 470290], 99.11)
#' # read_cov_report BED (per-gene) stays a single table
#' rr <- arrow::read_parquet(file.path(odir, grep("umccr_dragencov_readreportbed", lf, value = TRUE)))
#' expect_gt(nrow(rr), 0L)
#' expect_true(is.numeric(rr$read1_cvg))
#' # coverage metrics split: summary -> metricsmain, bucketed -> metricsbins, cumulative -> metricscumu
#' cvm <- arrow::read_parquet(file.path(odir, grep("sampleA_wgs_dragencov_metricsmain", lf, value = TRUE)))
#' expect_equal(cvm$cov_alignment_avg, 37.32)
#' expect_equal(cvm$bases_aligned_tot, 112632383850)
#' expect_equal(cvm$bases_aligned_in_region, 112632383850)
#' expect_equal(cvm$bases_aligned_in_region_pct, 100)
#' expect_equal(cvm$cov_x_median_ign0, 39)
#' # bucketed bins: finite [cov_lo, cov_hi), e.g. [20x: 50x) = 84.25; no NA upper bound
#' cvb <- arrow::read_parquet(file.path(odir, grep("sampleA_wgs_dragencov_metricsbins", lf, value = TRUE)))
#' expect_false(any(is.na(cvb$cov_hi)))
#' expect_equal(cvb$pct[cvb$cov_lo == 20 & cvb$cov_hi == 50], 84.25)
#' # cumulative: cov_min only (coverage >= threshold), e.g. >= 100x = 0.07; no cov_hi column
#' cvc <- arrow::read_parquet(file.path(odir, grep("sampleA_wgs_dragencov_metricscumu", lf, value = TRUE)))
#' expect_false("cov_hi" %in% names(cvc))
#' expect_equal(cvc$pct[cvc$cov_min == 100], 0.07)
#' # cttso ctDNA regions (exon, target_bed) fold into the prefix like wgs/tmb
#' expect_true(any(grepl("sampleA_exon_dragencov_metricsmain", lf)))
#' expect_true(any(grepl("sampleA_target_bed_dragencov_metricsmain", lf)))
#' exm <- arrow::read_parquet(file.path(odir, grep("sampleA_exon_dragencov_metricsmain", lf, value = TRUE)))
#' expect_equal(exm$cov_alignment_avg, 3211.57)
#' expect_equal(exm$bases_aligned_in_region, 4793826014)
#' expect_equal(exm$bases_aligned_in_region_pct, 36.25)
#' @export
DragenCov <- R6::R6Class(
  "DragenCov",
  cloneable = FALSE,
  inherit = DragenTool,
  public = list(
    #' @field flat_tidy_names (`logical(1)`)\cr
    #' `TRUE`: fanned-out sub-tables are named `<tool>_<tidy_name>` directly (parser
    #' token dropped), so each sub-table's `name` is its final output table. See the
    #' class description for the fan-out map.
    flat_tidy_names = TRUE,
    #' @description Create a new DragenCov object.
    #' @param path (`character(1)`)\cr
    #' Output directory of tool. If `files_tbl` is supplied, this is ignored.
    #' @param files_tbl (`tibble(n)`)\cr
    #' Tibble of files from [nemo::list_files_dir()].
    initialize = function(path = NULL, files_tbl = NULL) {
      super$initialize(name = "dragencov", pkg = pkg_name, path = path, files_tbl = files_tbl)
    },
    #' @description Tidy `*_coverage_metrics.csv` into `metricsmain` (wide summary),
    #' `metricsbins` (bucketed depth histogram), and `metricscumu` (cumulative).
    #' @param x (`character(1)` or `tibble()`)\cr Path to file or parsed tibble.
    tidy_metricsmain = function(x) {
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
        "metricsmain",
        # strip region from names (carried in prefix via refine_files())
        normalise = function(d) {
          d$variable <- dragen_cov_metric_normalize(d$variable)
          d
        }
      )
      # attach bin bounds, then partition into two tables kept separate so each is
      # homogeneous (no NA upper bound, sum(pct) meaningful within a table):
      # bucketed [lo:hi) vs cumulative [N:inf) (open bins, where cov_hi is NA).
      binx <- x[is_bin, , drop = FALSE]
      bnd <- dragen_cov_bin_split(binx$variable)
      binx$cov_lo <- bnd$cov_lo
      binx$cov_hi <- bnd$cov_hi
      is_cumu <- is.na(binx$cov_hi)
      bins <- private$tidy_metrics(
        binx[!is_cumu, , drop = FALSE],
        "metricsbins",
        normalise = function(d) {
          d$variable <- "cov_pct"
          d
        }
      )
      cumu <- private$tidy_metrics(
        binx[is_cumu, , drop = FALSE],
        "metricscumu",
        normalise = function(d) {
          d$cov_min <- d$cov_lo
          d$cov_lo <- NULL
          d$cov_hi <- NULL
          d$variable <- "cov_pct"
          d
        }
      )
      # flat_tidy_names drops the parser token -> output is dragencov_<name>, so the
      # sub-table names ARE the output tables
      main$name <- "metricsmain"
      bins$name <- "metricsbins"
      cumu$name <- "metricscumu"
      dplyr::bind_rows(main, bins, cumu)
    },
    #' @description Parse `*_fine_hist.csv`, returning `depth` as an integer.
    #' @param x (`character(1)`)\cr Path to file.
    parse_finehist = function(x) {
      d <- readr::read_csv(
        x,
        col_types = readr::cols(
          Depth = readr::col_character(),
          Overall = readr::col_double()
        )
      )
      # "2000+" -> 2000
      d[["Depth"]] <- as.integer(sub("\\+$", "", d[["Depth"]]))
      attr(d, "file_version") <- "latest"
      d[]
    },
    #' @description Parse `*_cov_report.bed`; `tidy_reportbedmain()` types and splits it.
    #' @param x (`character(1)`)\cr Path to file.
    parse_reportbedmain = function(x) {
      # all-character: trailing pct_above_<N> columns are user-configurable, so can't use
      # the fixed tsv schema
      d <- readr::read_tsv(x, col_types = readr::cols(.default = readr::col_character()))
      attr(d, "file_version") <- "latest"
      d[]
    },
    #' @description Tidy `*_cov_report.bed` into `reportbedmain` (per-interval
    #' distribution stats, wide) and `reportbedcumu` (coverage thresholds, long).
    #' @param x (`character(1)` or `tibble()`)\cr Path to file or parsed tibble.
    tidy_reportbedmain = function(x) {
      if (!tibble::is_tibble(x)) {
        x <- private$parse_reportbedmain(x)
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
      # split thresholds long (one row per interval x pct_above_<N>) rather than wide,
      # since the column set is user-configurable
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
      main <- list(main) |> rlang::set_names("reportbedmain") |> nemo::nemo_enframe()
      cumu <- list(cumu) |> rlang::set_names("reportbedcumu") |> nemo::nemo_enframe()
      dplyr::bind_rows(main, cumu)
    }
  )
)
