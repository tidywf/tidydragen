pkg_name <- "tidydragen"

#' Normalise DRAGEN coverage summary-metric names
#'
#' @description
#' Rewrites the `variable` column of the **summary rows** of a parsed DRAGEN
#' `*_coverage_metrics.csv` into region-agnostic names, so a single schema serves
#' every coverage region. Two rewrites are applied:
#'
#' - **`over <region>` suffixes** (e.g. `Average alignment coverage over genome`)
#'   are stripped;
#' - **`in <region>` suffixes** (e.g. `Aligned bases in genome`) collapse to
#'   `in region`, keeping them distinct from the plain `Aligned bases` total.
#'
#' The coverage-bin rows (`PCT of <region> with coverage [lo: hi)`) are split off
#' into the separate `bins` table by [DragenCov] and parsed with
#' [dragen_cov_bin_split()], so they never pass through this function. The region
#' itself is carried in the output `prefix` (via `refine_files()`), so unlike the
#' variant-caller metrics no `region` column is emitted.
#'
#' @param v (`character()`)\cr Vector of raw metric names.
#' @return (`character()`) Normalised metric names.
#'
#' @examples
#' dragen_cov_metric_normalize(c(
#'   "Aligned bases",
#'   "Aligned bases in genome",
#'   "Average alignment coverage over QC coverage region"
#' ))
#'
#' @testexamples
#' out <- dragen_cov_metric_normalize(c(
#'   "Aligned bases",
#'   "Aligned bases in genome",
#'   "Average alignment coverage over QC coverage region"
#' ))
#' expect_equal(out, c(
#'   "Aligned bases",
#'   "Aligned bases in region",
#'   "Average alignment coverage"
#' ))
#' @export
dragen_cov_metric_normalize <- function(v) {
  region <- "(?:genome|QC coverage region|target region)"
  v <- sub(paste0(" in ", region, "$"), " in region", v, perl = TRUE)
  v <- sub(paste0(" over ", region, "$"), "", v, perl = TRUE)
  v
}

#' Split DRAGEN coverage-bin metric names into numeric bounds
#'
#' @description
#' Parses the coverage-bin rows of a DRAGEN `*_coverage_metrics.csv`
#' (`PCT of <region> with coverage [lo: hi)`) into their numeric depth bounds.
#' The open, cumulative bins (`[Nx: inf)`) return `NA` for the upper bound, which
#' distinguishes them from the bucketed bins (`[lo: hi)`). [DragenCov] uses this
#' `NA` to partition the bins into the `metricsbins` (bucketed) and `metricscumu`
#' (cumulative) long tables.
#'
#' @param v (`character()`)\cr Vector of raw coverage-bin metric names.
#' @return (`tibble`) with integer columns `cov_lo` and `cov_hi` (`cov_hi` is `NA`
#'   for the open `inf` upper bound).
#'
#' @examples
#' dragen_cov_bin_split(c(
#'   "PCT of genome with coverage [ 100x: inf)",
#'   "PCT of QC coverage region with coverage [  20x:  50x)"
#' ))
#'
#' @testexamples
#' out <- dragen_cov_bin_split(c(
#'   "PCT of genome with coverage [ 100x: inf)",
#'   "PCT of QC coverage region with coverage [  20x:  50x)"
#' ))
#' expect_equal(out$cov_lo, c(100L, 20L))
#' expect_equal(out$cov_hi, c(NA_integer_, 50L))
#' @export
dragen_cov_bin_split <- function(v) {
  m <- regmatches(v, regexec("\\[\\s*([0-9]+)x:\\s*([0-9]+|inf)x?\\)", v))
  grab <- function(z, i) if (length(z) == 3L) z[[i]] else NA_character_
  lo <- vapply(m, grab, character(1), 2L)
  hi <- vapply(m, grab, character(1), 3L)
  tibble::tibble(
    cov_lo = as.integer(lo),
    cov_hi = ifelse(hi == "inf", NA_integer_, suppressWarnings(as.integer(hi)))
  )
}
