#' @title DragenTso Object
#'
#' @description
#' Parses and tidies the TSO500 ctDNA (cttsov2) app-layer outputs that sit
#' alongside the DRAGEN metrics files: the CombinedVariantOutput small variants,
#' DNA fusions, TMB trace / MSAF, and per-exon / per-gene coverage reports.
#'
#' These files appear in both `Results/<sample>/` and a `Logs_Intermediates/`
#' subdirectory (byte-identical). nemo matches on bname only, so the two
#' copies would collide; `refine_files()` keeps the `Results/` copy.
#'
#' @examples
#' cls <- DragenTso; tool <- "dragentso"
#' indir <- system.file("extdata", tool, package = "tidydragen")
#' odir <- tempdir()
#' obj <- cls$new(indir)
#' obj$run(output_dir = odir, format = "parquet", input_id = "run1")
#' (lf <- list.files(odir, pattern = "dragentso_.*parquet", full.names = FALSE))
#' @testexamples
#' # smallvariants: CVO [Small Variants] section only; empty-gene row kept
#' sv <- arrow::read_parquet(file.path(odir, grep("sampleA_dragentso_smallvariants", lf, value = TRUE)))
#' expect_equal(names(sv)[names(sv) != "input_id"],
#'   c("gene", "chrom", "pos", "ref", "alt", "vaf", "dp", "pdot", "cdot", "csq", "exons"))
#' expect_equal(nrow(sv), 3L)
#' expect_equal(sv$gene[sv$pos == 2488153], "TNFRSF14")
#' expect_true(is.na(sv$gene[sv$pos == 4367323]))
#' expect_equal(sv$vaf[sv$pos == 2488153], 0.4768)
#' expect_equal(sv$pos[1], 2488153L)
#' # fusions: v2 18-column shape, lowercase tidy names
#' fu <- arrow::read_parquet(file.path(odir, grep("sampleA_dragentso_fusions", lf, value = TRUE)))
#' expect_true(all(c("sample", "name", "chr1", "pos1", "vaf", "is_cosmic_genepair",
#'   "fusion_directionality_known") %in% names(fu)))
#' expect_equal(fu$gene1[1], "BCR")
#' expect_equal(fu$vaf[1], 0.28)
#' # tmbtrace: 27 v2 columns
#' tt <- arrow::read_parquet(file.path(odir, grep("sampleA_dragentso_tmbtrace", lf, value = TRUE)))
#' expect_equal(tt$gene[1], "TNFRSF14")
#' expect_equal(tt$consequence[1], "missense_variant")
#' expect_true("within_valid_tmb_region" %in% names(tt))
#' # tmbmsaf: leading max_somatic_af + variant columns
#' tm <- arrow::read_parquet(file.path(odir, grep("sampleA_dragentso_tmbmsaf", lf, value = TRUE)))
#' expect_equal(names(tm)[2], "max_somatic_af")
#' expect_equal(tm$gene[1], "TP53")
#' # exoncov / genecov
#' ec <- arrow::read_parquet(file.path(odir, grep("sampleA_dragentso_exoncov", lf, value = TRUE)))
#' expect_equal(names(ec)[names(ec) != "input_id"],
#'   c("chrom", "start", "end", "gene", "cov_mean", "cov_median", "cov_min", "cov_max"))
#' expect_equal(ec$cov_mean[1], 3004.16)
#' gc <- arrow::read_parquet(file.path(odir, grep("sampleA_dragentso_genecov", lf, value = TRUE)))
#' expect_false("cov_median" %in% names(gc))
#' expect_equal(gc$gene[1], "TNFRSF14")
#' @include DragenTool.R
#' @export
DragenTso <- R6::R6Class(
  "DragenTso",
  cloneable = FALSE,
  inherit = DragenTool,
  public = list(
    #' @field flat_tidy_names (`logical(1)`)\cr
    #' `TRUE`: outputs are named `<tool>_<table>` directly.
    flat_tidy_names = TRUE,
    #' @description Create a new DragenTso object.
    #' @param path (`character(1)`)\cr
    #' Output directory of tool. If `files_tbl` is supplied, this is ignored.
    #' @param files_tbl (`tibble(n)`)\cr
    #' Tibble of files from [nemo::list_files_dir()].
    initialize = function(path = NULL, files_tbl = NULL) {
      super$initialize(name = "dragentso", pkg = pkg_name, path = path, files_tbl = files_tbl)
    },
    #' @description Parse only the `[Small Variants]` section of a
    #' `CombinedVariantOutput.tsv` file, dropping the rest (sourced from the SAR
    #' JSON instead).
    #' @param x (`character(1)`)\cr Path to file.
    parse_smallvariants = function(x) {
      cols <- c(
        "Gene",
        "Chromosome",
        "Genomic Position",
        "Reference Call",
        "Alternative Call",
        "Allele Frequency",
        "Depth",
        "P-Dot Notation",
        "C-Dot Notation",
        "Consequence(s)",
        "Affected Exon(s)"
      )
      ct <- readr::cols(
        .default = "c",
        "Genomic Position" = "i",
        "Allele Frequency" = "d",
        "Depth" = "d"
      )
      ln <- readr::read_lines(x, skip_empty_rows = TRUE)
      hdr <- grep("\\[Small Variants\\]", ln)
      # no section, or the sentinel "NA\t\t" no-variants row -> typed empty tibble
      if (length(hdr) == 0 || (length(ln) >= hdr + 2 && grepl("^NA\t", ln[hdr + 2]))) {
        d <- nemo::empty_tbl(cnames = cols, ctypes = ct)
      } else {
        d <- ln[(hdr + 1):length(ln)] |>
          I() |>
          readr::read_tsv(col_names = TRUE, col_types = ct)
      }
      d <- readr::type_convert(d[, cols, drop = FALSE], col_types = ct)
      attr(d, "file_version") <- "latest"
      d[]
    },
    #' @description Parse a `Fusions.csv` file (comment-prefixed header block,
    #' then a CSV table; may hold zero data rows).
    #' @param x (`character(1)`)\cr Path to file.
    parse_fusions = function(x) {
      ct <- readr::cols(
        .default = "c",
        "Pos1" = "d",
        "Pos2" = "d",
        "Alt_Depth" = "d",
        "BP1_Depth" = "d",
        "BP2_Depth" = "d",
        "Total_Depth" = "d",
        "VAF" = "d"
      )
      d <- readr::read_csv(x, comment = "#", col_types = ct)
      attr(d, "file_version") <- "latest"
      d[]
    }
  ),
  private = list(
    # The CVO/Fusions/trace/coverage files are duplicated in Results/ and
    # Logs_Intermediates/; nemo matches on bname so both collide. Keep the
    # Results/ copy, and fall back to the first row for bnames that appear once.
    refine_files = function(files) {
      if (nrow(files) == 0) {
        return(files)
      }
      files |>
        dplyr::mutate(.in_results = grepl("/Results/", .data$path)) |>
        dplyr::mutate(
          .keep_row = if (any(.data$.in_results)) {
            .data$.in_results
          } else {
            dplyr::row_number() == 1L
          },
          .by = "bname"
        ) |>
        dplyr::filter(.data$.keep_row) |>
        dplyr::select(-".in_results", -".keep_row")
    }
  )
)
