#' @title DragenVar Object
#'
#' @description
#' Parses and tidies DRAGEN variant-related metric outputs (variant caller, SV,
#' CNV, ploidy, TMB, HRD, etc.).
#'
#' @examples
#' cls <- DragenVar; tool <- "dragenvar"
#' indir <- system.file("extdata", tool, package = "tidydragen")
#' odir <- tempdir()
#' obj <- cls$new(indir)
#' obj$run(output_dir = odir, format = "parquet", input_id = "run1")
#' (lf <- list.files(odir, pattern = "dragenvar_.*parquet", full.names = FALSE))
#' @testexamples
#' # sampleA: whole-genome vc; SUMMARY section dropped, only prefilter/postfilter
#' vcA <- arrow::read_parquet(file.path(odir, grep("sampleA_dragenvar_vc", lf, value = TRUE)))
#' expect_equal(nrow(vcA), 2L)
#' expect_setequal(vcA$section, c("prefilter", "postfilter"))
#' expect_true(all(c("section", "rg", "region", "total", "total_pct", "chrx_snps") %in% names(vcA)))
#' expect_equal(vcA$mnps[vcA$section == "prefilter"], 318)
#' # SUMMARY-only metrics are gone with the dropped section
#' expect_false("child_sample" %in% names(vcA))
#' expect_true(all(vcA$region == "genome"))
#' post <- vcA[vcA$section == "postfilter", ]
#' expect_equal(post$total, 1145323)
#' expect_equal(post$total_pct, 100)
#' expect_equal(post$chrx_snps, 20569)
#' # sampleB: targeted vc — region stripped to same tidy col, region col = targetreg
#' vcB <- arrow::read_parquet(file.path(odir, grep("sampleB_dragenvar_vc", lf, value = TRUE)))
#' expect_true(all(vcB$region == "targetreg"))
#' expect_true(all(c("chrx_snps", "qc_region_callability_region1_pct") %in% names(vcB)))
#' expect_equal(vcB[vcB$section == "prefilter", ]$chrx_snps, 300)
#' # sv: count-only total + pct-paired PASS breakdown
#' sv <- arrow::read_parquet(file.path(odir, grep("sampleA_dragenvar_sv", lf, value = TRUE)))
#' expect_equal(sv$total_pass, 169)
#' expect_equal(sv$del, 50)
#' expect_equal(sv$del_pct, 29.59)
#' # cnv
#' cnv <- arrow::read_parquet(file.path(odir, grep("sampleA_dragenvar_cnv", lf, value = TRUE)))
#' expect_equal(cnv$purity_tumor, 0.54)
#' expect_equal(cnv$n_amp_pass_pct, 86.54)
#' # SEX GENOTYPER preamble captured (not dropped) as two columns on the one cnv row
#' expect_equal(nrow(cnv), 1L)
#' expect_equal(cnv$sex_karyotype, "XY")
#' expect_equal(cnv$sex_genotyper_confidence, 0.95)
#' expect_equal(cnv$beta_binomial_overdispersion_m, 200)
#' # tmb (4-col, no pct)
#' tmb <- arrow::read_parquet(file.path(odir, grep("sampleA_dragenvar_tmb", lf, value = TRUE)))
#' expect_equal(tmb$tmb, 3.46)
#' expect_equal(tmb$vars_tot_input, 12004)
#' # ploidy: split into `ploidystats` (sample scalars) + `ploidyratio` (per-chrom, long)
#' plo <- arrow::read_parquet(file.path(odir, grep("sampleA_dragenvar_ploidystats", lf, value = TRUE)))
#' expect_equal(plo$ploidy_est, "XX")
#' expect_equal(plo$cov_x, 45.99)
#' expect_false("cov_x_div_auto" %in% names(plo))
#' pcr <- arrow::read_parquet(file.path(odir, grep("sampleA_dragenvar_ploidyratio", lf, value = TRUE)))
#' expect_equal(names(pcr)[names(pcr) != "input_id"], c("chrom", "autosomal_ratio"))
#' expect_equal(pcr$autosomal_ratio[pcr$chrom == "X"], 0.99)
#' expect_equal(pcr$autosomal_ratio[pcr$chrom == "1"], 1.00)
#' # sampleB: 'median coverage'/'median / Autosomal median' naming -> same tidy names
#' ploB <- arrow::read_parquet(file.path(odir, grep("sampleB_dragenvar_ploidystats", lf, value = TRUE)))
#' expect_equal(ploB$cov_x, 19.24)
#' expect_equal(ploB$ploidy_est, "XX")
#' expect_false("cov_skewness" %in% names(ploB))
#' pcrB <- arrow::read_parquet(file.path(odir, grep("sampleB_dragenvar_ploidyratio", lf, value = TRUE)))
#' expect_equal(pcrB$autosomal_ratio[pcrB$chrom == "X"], 0.99)
#' # nuctrans: long, one row per from->to transition
#' nt <- arrow::read_parquet(file.path(odir, grep("sampleA_dragenvar_nuctrans", lf, value = TRUE)))
#' expect_equal(names(nt)[names(nt) != "input_id"], c("from", "to", "count"))
#' expect_equal(nrow(nt), 12L)
#' expect_equal(nt$count[nt$from == "A" & nt$to == "C"], 63)
#' expect_equal(nt$count[nt$from == "T" & nt$to == "G"], 45)
#' # hethom: per-chromosome, one row per section/rg/chrom; nan ratio preserved
#' hh <- arrow::read_parquet(file.path(odir, grep("sampleA_dragenvar_hethom", lf, value = TRUE)))
#' expect_true(all(c("section", "rg", "chrom", "het", "hom", "het_hom_ratio") %in% names(hh)))
#' pre1 <- hh[hh$section == "prefilter" & hh$chrom == "1", ]
#' expect_equal(pre1$het, 233196)
#' expect_equal(pre1$het_hom_ratio, 1.348)
#' postY <- hh[hh$section == "postfilter" & hh$chrom == "Y", ]
#' expect_true(is.nan(postY$het_hom_ratio))
#' # hrd (csv, 1 row)
#' hrd <- arrow::read_parquet(file.path(odir, grep("sampleA_dragenvar_hrd", lf, value = TRUE)))
#' expect_equal(hrd$hrd_score, 5L)
#' expect_equal(hrd$loh_score, 2L)
#' @export
DragenVar <- R6::R6Class(
  "DragenVar",
  cloneable = FALSE,
  inherit = DragenTool,
  public = list(
    #' @description Create a new DragenVar object.
    #' @param path (`character(1)`)\cr
    #' Output directory of tool. If `files_tbl` is supplied, this is ignored.
    #' @param files_tbl (`tibble(n)`)\cr
    #' Tibble of files from [nemo::list_files_dir()].
    initialize = function(path = NULL, files_tbl = NULL) {
      super$initialize(name = "dragenvar", pkg = pkg_name, path = path, files_tbl = files_tbl)
    },
    #' @description Tidy `vc_metrics.csv`. Drops `VARIANT CALLER SUMMARY` (blank
    #' `rg`, duplicates prefilter), keeping `PREFILTER`/`POSTFILTER` as `section`;
    #' `rg` (the sample id) is kept raw. Strips the region from metric names into a
    #' `region` column (genome vs target region).
    #' @param x (`character(1)` or `tibble()`)\cr Path to file or parsed tibble.
    tidy_vc = function(x) {
      private$tidy_metrics(x, "vc", drop_constant = character(), normalise = function(d) {
        d <- d[!grepl("SUMMARY", d$section), , drop = FALSE]
        d$section <- dplyr::case_when(
          grepl("PREFILTER", d$section) ~ "prefilter",
          grepl("POSTFILTER", d$section) ~ "postfilter",
          TRUE ~ d$section
        )
        r <- private$region_split(d)
        r$x$region <- r$region
        r$x
      })
    },
    #' @description Tidy `cnv_metrics.csv`. The `SEX GENOTYPER` preamble row carries
    #' the sample id as its metric name
    #' (`SEX GENOTYPER,,<sample>,<karyotype>,<confidence>`), so the generic pivot
    #' would drop it as an unmapped (per-sample-varying) metric. This rewrites that
    #' row into two stable `CNV SUMMARY` metrics — `sex_karyotype` (XX/XY, or a
    #' MALE/FEMALE gender for non-WGS) and `sex_genotyper_confidence` (0-1 score,
    #' 0.0 when the sex was set via `--sample-sex`) — so the call lands on the single
    #' wide cnv row instead of being lost. A cnv file without the preamble (e.g.
    #' germline WGS) is unchanged.
    #' @param x (`character(1)` or `tibble()`)\cr Path to file or parsed tibble.
    tidy_cnv = function(x) {
      private$tidy_metrics(x, "cnv", normalise = function(d) {
        is_sex <- grepl("SEX GENOTYPER", d$section)
        if (any(is_sex)) {
          # one SEX GENOTYPER row per file (the case sample); take the first if a
          # panel-of-normals run ever emits more.
          sx <- d[is_sex, , drop = FALSE][1, , drop = FALSE]
          add <- tibble::tibble(
            section = "CNV SUMMARY",
            rg = sx$rg,
            variable = c("sex_karyotype", "sex_genotyper_confidence"),
            count = c(sx$count, as.character(sx$pct)),
            pct = NA_real_
          )
          d <- dplyr::bind_rows(d[!is_sex, , drop = FALSE], add)
        }
        d
      })
    },
    #' @description Tidy `vc_hethom_ratio_metrics.csv`. Metric names are
    #' `"<chrom> <metric>"` (e.g. `"1 Heterozygous"`); `chrom` is split into an id
    #' column, giving one row per section/rg/chrom.
    #' @param x (`character(1)` or `tibble()`)\cr Path to file or parsed tibble.
    tidy_hethom = function(x) {
      private$tidy_metrics(x, "hethom", drop_constant = character(), normalise = function(d) {
        d$section <- dplyr::case_when(
          grepl("PREFILTER", d$section) ~ "prefilter",
          grepl("POSTFILTER", d$section) ~ "postfilter",
          TRUE ~ d$section
        )
        d$chrom <- sub("^(\\S+)\\s.*$", "\\1", d$variable)
        d$variable <- sub("^\\S+\\s+", "", d$variable)
        d
      })
    },
    #' @description Tidy `ploidy_estimation_metrics.csv` into two tables:
    #' `ploidystats` (sample scalars: `ploidy_est`, `cov_skewness`,
    #' `cov_{autosomal,x,y}`) and `ploidyratio` (long, one row per chromosome
    #' ratio). Ratio rows (those with `/`) are split off and the chromosome parsed
    #' from the metric name, handling both `"1 / Autosomal ratio"` and
    #' `"1 median / Autosomal median"` namings.
    #' @param x (`character(1)` or `tibble()`)\cr Path to file or parsed tibble.
    tidy_ploidy = function(x) {
      if (!tibble::is_tibble(x)) {
        x <- private$parse_metrics(x)
      }
      is_ratio <- grepl("/", x$variable)
      # scalar col_map is on the file-matching "ploidy" table; ratio col_map on the
      # sentinel "ploidyratio".
      stats <- private$tidy_metrics(x[!is_ratio, , drop = FALSE], "ploidy")
      ratio <- private$tidy_metrics(
        x[is_ratio, , drop = FALSE],
        "ploidyratio",
        normalise = function(d) {
          d$chrom <- sub("^(\\S+).*$", "\\1", d$variable)
          d$variable <- "autosomal_ratio"
          d
        }
      )
      # sub-table name concatenates onto the parser -> dragenvar_ploidystats / _ploidyratio
      stats$name <- "stats"
      ratio$name <- "ratio"
      dplyr::bind_rows(stats, ratio)
    },
    #' @description Tidy `allele_transition_noise_metrics.csv` to long form: one row
    #' per nucleotide transition with `from`/`to` base id columns and its `count`.
    #' The metric name (e.g. `"A->C"`) is split into the two bases.
    #' @param x (`character(1)` or `tibble()`)\cr Path to file or parsed tibble.
    tidy_nuctrans = function(x) {
      private$tidy_metrics(x, "nuctrans", normalise = function(d) {
        d$from <- sub("->.*$", "", d$variable)
        d$to <- sub("^.*->", "", d$variable)
        d$variable <- "count"
        d
      })
    }
  )
)
