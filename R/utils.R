pkg_name <- "tidydragen"

#' Normalise DRAGEN coverage summary-metric names
#'
#' @description
#' Makes DRAGEN coverage summary-metric names region-agnostic, so one schema
#' serves every region: `over <region>` suffixes are stripped, `in <region>`
#' collapses to `in region` (distinct from the plain `Aligned bases` total).
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
#' Parses DRAGEN coverage-bin names (`PCT of <region> with coverage [lo: hi)`)
#' into their depth bounds. Open bins (`[Nx: inf)`) get an `NA` upper bound.
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
#' Strips open-ended bin markers from FASTQC position/length tokens (`256+`,
#' `>=255` -> `256`, `255`), which would otherwise coerce to `NA` and drop the
#' top bin. Closed ranges (`A-B`) are left for [fastqc_bin_expand()].
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
#' Expands each position/length token to the integers it covers (`"137-140"` ->
#' `137:140`), for [tidyr::unnest_longer()]. Not [tidyr::separate_longer_delim()],
#' which keeps only the endpoints. Run [fastqc_bin_open()] first.
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
