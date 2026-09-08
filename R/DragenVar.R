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
#' expect_equal(plo$cov_x_pctile, 45.99)
#' expect_false("cov_x_div_auto" %in% names(plo))
#' pcr <- arrow::read_parquet(file.path(odir, grep("sampleA_dragenvar_ploidyratio", lf, value = TRUE)))
#' expect_equal(names(pcr)[names(pcr) != "input_id"], c("chrom", "ratio"))
#' expect_equal(pcr$ratio[pcr$chrom == "X"], 0.99)
#' expect_equal(pcr$ratio[pcr$chrom == "1"], 1.00)
#' # sampleB: 'median coverage'/'median / Autosomal median' naming -> same tidy names
#' ploB <- arrow::read_parquet(file.path(odir, grep("sampleB_dragenvar_ploidystats", lf, value = TRUE)))
#' expect_equal(ploB$cov_x_median, 19.24)
#' expect_equal(ploB$ploidy_est, "XX")
#' expect_false("cov_skewness" %in% names(ploB))
#' pcrB <- arrow::read_parquet(file.path(odir, grep("sampleB_dragenvar_ploidyratio", lf, value = TRUE)))
#' expect_equal(pcrB$ratio[pcrB$chrom == "X"], 0.99)
#' # nuctrans: long, one row per transition code (e.g. AC)
#' nt <- arrow::read_parquet(file.path(odir, grep("sampleA_dragenvar_nuctrans", lf, value = TRUE)))
#' expect_equal(names(nt)[names(nt) != "input_id"], c("transition", "value"))
#' expect_equal(nrow(nt), 12L)
#' expect_equal(nt$value[nt$transition == "AC"], 63)
#' expect_equal(nt$value[nt$transition == "TG"], 45)
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
#' # microsat (JSON, 1 row): Settings dropped, numeric keys cast, result stays char
#' msi <- arrow::read_parquet(file.path(odir, grep("sampleA_dragenvar_microsat", lf, value = TRUE)))
#' expect_equal(nrow(msi), 1L)
#' expect_equal(msi$sites_assessed, 14783)
#' expect_equal(msi$sites_unstable, 204)
#' expect_equal(msi$pct_unstable, 1.38)
#' expect_equal(msi$result_valid, "true")
#' expect_equal(msi$sum_jsd, 12.34)
#' expect_false(any(c("command", "outputprefix") %in% tolower(names(msi))))
#' # ploidyvcf (native gz VCF parse): one row per contig, FORMAT DC:NDC split out
#' pv <- arrow::read_parquet(file.path(odir, grep("sampleA_dragenvar_ploidyvcf", lf, value = TRUE)))
#' expect_equal(names(pv)[names(pv) != "input_id"], c("chrom", "qual", "filter", "dc", "ndc"))
#' xrow <- pv[pv$chrom == "chrX", ]
#' expect_equal(xrow$dc, 45.1178)
#' expect_equal(xrow$ndc, 0.972261)
#' expect_equal(pv$filter[pv$chrom == "chrY"], "LowQual")
#' expect_true(all(pv$filter[pv$chrom != "chrY"] == "PASS"))
#' @export
DragenVar <- R6::R6Class(
  "DragenVar",
  cloneable = FALSE,
  inherit = DragenTool,
  public = list(
    #' @field flat_tidy_names (`logical(1)`)\cr
    #' `TRUE`: fanned-out sub-tables are named `<tool>_<tidy_name>` directly (the
    #' parser token is dropped). `tidy_ploidystats` fans one file into the
    #' `ploidystats` + `ploidyratio` tables, whose names are the final outputs; every
    #' other DragenVar table has `tidy_name == parser`, so its name is unchanged.
    flat_tidy_names = TRUE,
    #' @description Create a new DragenVar object.
    #' @param path (`character(1)`)\cr
    #' Output directory of tool. If `files_tbl` is supplied, this is ignored.
    #' @param files_tbl (`tibble(n)`)\cr
    #' Tibble of files from [nemo::list_files_dir()].
    initialize = function(path = NULL, files_tbl = NULL) {
      super$initialize(name = "dragenvar", pkg = pkg_name, path = path, files_tbl = files_tbl)
    },
    #' @description Tidy `vc_metrics.csv`. `rg` (sample id) kept raw; region moved
    #' from metric names into a `region` column.
    #' @param x (`character(1)` or `tibble()`)\cr Path to file or parsed tibble.
    tidy_vc = function(x) {
      private$tidy_metrics(x, "vc", drop_constant = character(), normalise = function(d) {
        # drop VARIANT CALLER SUMMARY (blank rg, duplicates prefilter)
        d <- d[!grepl("SUMMARY", d$section), , drop = FALSE]
        d$section <- dplyr::case_when(
          grepl("PREFILTER", d$section) ~ "prefilter",
          grepl("POSTFILTER", d$section) ~ "postfilter",
          TRUE ~ d$section
        )
        # region (genome vs target region) -> its own column
        r <- private$region_split(d)
        r$x$region <- r$region
        r$x
      })
    },
    #' @description Tidy `cnv_metrics.csv`.
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
    #' @description Tidy `vc_hethom_ratio_metrics.csv`.
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
    #' @description Tidy `ploidy_estimation_metrics.csv` into `ploidystats` (sample
    #' scalars) and `ploidyratio` (long, one row per chromosome ratio).
    #' @param x (`character(1)` or `tibble()`)\cr Path to file or parsed tibble.
    tidy_ploidystats = function(x) {
      if (!tibble::is_tibble(x)) {
        x <- private$parse_metrics(x)
      }
      is_ratio <- grepl("/", x$variable)
      # scalar col_map is on the file-matching "ploidystats" table; ratio col_map on
      # the sentinel "ploidyratio".
      stats <- private$tidy_metrics(x[!is_ratio, , drop = FALSE], "ploidystats")
      ratio <- private$tidy_metrics(
        x[is_ratio, , drop = FALSE],
        "ploidyratio",
        normalise = function(d) {
          d$chrom <- sub("^(\\S+).*$", "\\1", d$variable)
          d$variable <- "ratio"
          d
        }
      )
      # flat_tidy_names drops the parser token -> output is dragenvar_<name>, so the
      # sub-table names ARE the final output tables: dragenvar_ploidystats / _ploidyratio.
      stats$name <- "ploidystats"
      ratio$name <- "ploidyratio"
      dplyr::bind_rows(stats, ratio)
    },
    #' @description Tidy `allele_transition_noise_metrics.csv`
    #' @param x (`character(1)` or `tibble()`)\cr Path to file or parsed tibble.
    tidy_nuctrans = function(x) {
      private$tidy_metrics(x, "nuctrans", normalise = function(d) {
        d$transition <- gsub("->", "", d$variable)
        d$variable <- "value"
        d
      })
    },
    #' @description Parse `microsat_output.json` (MSI).
    #' @param x (`character(1)`)\cr Path to file.
    parse_microsat = function(x) {
      j <- jsonlite::fromJSON(x, simplifyVector = TRUE)
      # Settings = tool config (paths, thresholds), not a metric.
      j[["Settings"]] <- NULL
      j[["ResultMessage"]] <- j[["ResultMessage"]] %||% NA_character_
      if (identical(j[["PercentageUnstableSites"]], "NaN")) {
        j[["PercentageUnstableSites"]] <- NA_character_
      }
      expected <- c(
        "TotalMicrosatelliteSitesAssessed",
        "TotalMicrosatelliteSitesUnstable",
        "PercentageUnstableSites",
        "ResultIsValid",
        "ResultMessage",
        "SumDistance",
        "SumJsd"
      )
      for (k in setdiff(expected, names(j))) {
        j[[k]] <- NA_character_
      }
      num_cols <- c(
        "TotalMicrosatelliteSitesAssessed",
        "TotalMicrosatelliteSitesUnstable",
        "PercentageUnstableSites",
        "SumDistance",
        "SumJsd"
      )
      d <- tibble::as_tibble_row(j) |>
        dplyr::mutate(
          dplyr::across(dplyr::any_of(num_cols), as.numeric),
          ResultIsValid = as.character(.data$ResultIsValid)
        )
      attr(d, "file_version") <- "latest"
      d[]
    },
    #' @description Parse `ploidy.vcf.gz` depth-of-coverage `dc` and normalised
    #' depth `ndc`.
    #' @param x (`character(1)`)\cr Path to file.
    parse_ploidyvcf = function(x) {
      cnames <- list(
        all = c("chrom", "pos", "id", "ref", "alt", "qual", "filter", "info", "fmt", "sample"),
        num = c("qual", "dc", "ndc"),
        final = c("chrom", "qual", "filter", "dc", "ndc")
      )
      d <- readr::read_tsv(x, comment = "##", col_types = readr::cols(.default = "c")) |>
        setNames(cnames$all) |>
        tidyr::separate_wider_delim("sample", delim = ":", names = c("dc", "ndc")) |>
        dplyr::select(dplyr::all_of(cnames$final)) |>
        dplyr::mutate(dplyr::across(dplyr::all_of(cnames$num), as.numeric))
      attr(d, "file_version") <- "latest"
      d[]
    }
  )
)
