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

#' Normalise open-ended DRAGEN FASTQC position/length bin tokens
#'
#' @description
#' DRAGEN FASTQC `fastqc_metrics.csv` position and read-length tokens are usually a
#' single integer (`150`) or a closed range (`145-152`), but with a coarser
#' `--fastqc-granularity` (or reads longer than the top bin) DRAGEN also emits
#' open-ended terminal bins: `256+` (positions) and `>=255` (read lengths). This
#' strips the open-bin markers (`+`, `>=`, `>`, `=`) so the token collapses to its
#' single integer bound. Closed ranges (`A-B`) are left untouched for a subsequent
#' `separate_longer_delim("-")` to expand.
#'
#' Without this, `as.integer("256+")` / `as.integer(">=255")` would silently coerce
#' to `NA` and drop the top position/length bin.
#'
#' @param v (`character()`)\cr Vector of raw position/length bin tokens (with any
#'   trailing `bp` already removed).
#' @return (`character()`) Tokens with open-bin markers stripped.
#'
#' @examples
#' fastqc_bin_open(c("150", "145-152", "256+", ">=255"))
#'
#' @testexamples
#' expect_equal(fastqc_bin_open(c("150", "145-152", "256+", ">=255")),
#'   c("150", "145-152", "256", "255"))
#' @export
fastqc_bin_open <- function(v) {
  gsub("[<>=+]", "", v)
}

#' Expand DRAGEN FASTQC position/length bin tokens to integer grains
#'
#' @description
#' Turns each position/length token into the full integer sequence it covers: a
#' single value (`"150"`) becomes `150L`, a closed range (`"137-140"`) becomes
#' the whole span `137:140`. Returns a list-column, one integer vector per input,
#' for a subsequent [tidyr::unnest_longer()].
#'
#' Note that [tidyr::separate_longer_delim()] on `"-"` is **not** a substitute: it
#' yields only the two endpoints (`137`, `140`), silently dropping the interior
#' positions and giving the wrong grain count when the count is divided across the
#' span. Feed tokens through [fastqc_bin_open()] first so open-ended bins (`256+`,
#' `>=255`) have collapsed to a single bound.
#'
#' @param v (`character()`)\cr Vector of position/length bin tokens, open-bin
#'   markers already stripped (single value or `lo-hi` range).
#' @return (`list()`) One integer vector per input token.
#'
#' @examples
#' fastqc_bin_expand(c("150", "2-3", "137-140"))
#'
#' @testexamples
#' out <- fastqc_bin_expand(c("150", "2-3", "137-140"))
#' expect_equal(out[[1]], 150L)
#' expect_equal(out[[2]], 2:3)
#' expect_equal(out[[3]], 137:140)
#' @export
fastqc_bin_expand <- function(v) {
  parts <- strsplit(v, "-", fixed = TRUE)
  lapply(parts, function(p) {
    b <- as.integer(p)
    if (length(b) == 1L) b else seq(b[1], b[2])
  })
}
