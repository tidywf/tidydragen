#' @title DragenTool Object
#'
#' @description
#' Base class for the DRAGEN tools, adding the shared `dragen-metrics` ftype
#' to [nemo::Tool]. A plain metrics table needs only `ftype: 'dragen-metrics'`
#' in its schema; one needing `normalise`/`drop_constant` declares a
#' `tidy_<tbl>()` that delegates to `tidy_metrics()`.
#'
#' @details
#' DRAGEN `*_metrics.csv` files are headerless `section,rg,variable,count[,pct]`.
#' `count` is read as character (string values such as `"XX"`, counts beyond
#' 32-bit) and coerced to its schema `type` after the wide pivot.
#'
#' @examples
#' # Abstract base: normally you use a subclass (e.g. DragenVar).
#' indir <- system.file("extdata/dragenmap", package = "tidydragen")
#' tool <- DragenTool$new(name = "dragenmap", pkg = "tidydragen", path = indir)
#' tool$list_files()      # inherited nemo::Tool file discovery
#' tool$on_unmapped       # "error": unmapped metrics abort rather than drop
#' tool$on_coerce_fail    # "error": values that fail type coercion abort
#'
#' # flip a policy to be lenient (drop/keep-NA with a warning instead)
#' tool$on_unmapped <- "warn"
#'
#' # fail-loud paths, via a corrupted copy of the DragenRna fixture
#' rna_dir <- system.file("extdata/dragenrna", package = "tidydragen")
#' bad_dir <- tempfile()
#' dir.create(bad_dir)
#' file.copy(list.files(rna_dir, full.names = TRUE), bad_dir)
#' qf <- file.path(bad_dir, "sampleA.quant_metrics.csv")
#' lines <- readLines(qf)
#' @testexamples
#' expect_true(inherits(tool, "Tool"))
#' expect_gt(nrow(tool$list_files()), 0)
#' expect_equal(tool$on_coerce_fail, "error")
#' expect_equal(tool$on_unexpected_col, "error")
#' expect_equal(tool$on_unmapped, "warn")
#'
#' # on_unmapped: a metric name absent from the schema
#' writeLines(c(lines, "RNA QUANTIFICATION STATISTICS,,Bogus New Metric,42"), qf)
#' bad <- DragenRna$new(bad_dir)
#' expect_error(bad$run(output_dir = tempfile(), format = "parquet"), "unmapped metric")
#' bad$on_unmapped <- "warn"
#' od2 <- tempfile()
#' expect_warning(bad$run(output_dir = od2, format = "parquet"), "unmapped metric")
#' lf2 <- list.files(od2, pattern = "dragenrna_.*parquet")
#' qnt2 <- nemo::read_parquet_grep(od2, lf2, "quant")
#' expect_false("Bogus New Metric" %in% names(qnt2))
#'
#' # on_coerce_fail: a numeric metric's value replaced with non-numeric text
#' writeLines(sub("Total Genes,62700", "Total Genes,notanumber", lines), qf)
#' bad2 <- DragenRna$new(bad_dir)
#' expect_error(bad2$run(output_dir = tempfile(), format = "parquet"), "coercion")
#' bad2$on_coerce_fail <- "warn"
#' od3 <- tempfile()
#' expect_warning(bad2$run(output_dir = od3, format = "parquet"), "coercion")
#' lf3 <- list.files(od3, pattern = "dragenrna_.*parquet")
#' qnt3 <- nemo::read_parquet_grep(od3, lf3, "quant")
#' expect_true(is.na(qnt3$genes_tot))
#'
#' # on_unexpected_col: a normally-constant `rg` that now varies
#' writeLines(c(lines, "RNA QUANTIFICATION STATISTICS,RG1,Total Genes,100"), qf)
#' bad3 <- DragenRna$new(bad_dir)
#' expect_error(bad3$run(output_dir = tempfile(), format = "parquet"), "varying")
#' bad3$on_unexpected_col <- "warn"
#' od4 <- tempfile()
#' expect_warning(bad3$run(output_dir = od4, format = "parquet"), "varying")
#' lf4 <- list.files(od4, pattern = "dragenrna_.*parquet")
#' qnt4 <- nemo::read_parquet_grep(od4, lf4, "quant")
#' expect_true("rg" %in% names(qnt4))
#' expect_equal(nrow(qnt4), 2L)
#' @export
DragenTool <- R6::R6Class(
  "DragenTool",
  cloneable = FALSE,
  inherit = Tool,
  public = list(
    #' @field on_unmapped (`character(1)`)\cr
    #' Policy for file metrics absent from the schema: `error` (default) or
    #' `warn` (drop them).
    on_unmapped = "error",
    #' @field on_coerce_fail (`character(1)`)\cr
    #' Policy for a non-empty value that coerces to `NA` under its schema `type`:
    #' `error` (default) or `warn` (keep the `NA`).
    on_coerce_fail = "error",
    #' @field on_unexpected_col (`character(1)`)\cr
    #' Policy for a `drop_constant` id column that varies across rows: `error`
    #' (default) or `warn` (keep the column).
    on_unexpected_col = "error"
  ),
  private = list(
    # pkg-specific ftype parsers (dragen-metrics tidy is routed in tidy_file)
    extra_ftypes = function() {
      list(
        "dragen-metrics" = function(x, table_name) private$parse_metrics(x),
        "csv-nohead" = function(x, table_name) {
          # trim_ws: some DRAGEN csv-nohead rows have a space after the comma
          # (", 37.32") that breaks double parsing.
          private$parse_file_nohead(x, table_name, delim = ",", trim_ws = TRUE)
        }
      )
    },
    # nemo's tidy dispatch has no ftype hook, so route plain `dragen-metrics`
    # tables (no `tidy_<tbl>()`) to the shared pivot here.
    tidy_file = function(x, table_name, convert_types = FALSE) {
      if (identical(self$config$get_ftype(table_name), "dragen-metrics")) {
        return(private$tidy_metrics(x, table_name))
      }
      super$tidy_file(x, table_name, convert_types = convert_types)
    },
    # Fold the coverage region and phenotype from the filename into `prefix`:
    # `sampleA.wgs_coverage_metrics_tumor.csv` -> `sampleA_wgs_tumor_...`.
    # No-op on non-coverage files. qc-coverage-region-<label> keeps only the
    # user's label.
    refine_files = function(files) {
      if (nrow(files) == 0) {
        return(files)
      }
      # region must be followed by a known coverage subtype so non-coverage files
      # never match.
      region_re <- paste0(
        "(wgs|tmb|exon|target_bed|qc-coverage-region-[A-Za-z0-9-]+)_",
        "(?:contig_mean_cov|coverage_metrics|fine_hist|",
        "read_cov_report|cov_report)"
      )
      # "_<region>[_<pheno>]", or "" for a non-coverage file
      suffix_for <- function(bname) {
        m <- regmatches(bname, regexec(region_re, bname))[[1]]
        if (length(m) < 2) {
          return("")
        }
        region <- sub("^qc-coverage-region-", "", m[2])
        # phenotype only in somatic files ("..._tumor.csv")
        ph <- regmatches(bname, regexec("_(normal|tumor)\\.[^.]+$", bname))[[1]]
        if (length(ph) >= 2) {
          paste0("_", region, "_", ph[2])
        } else {
          paste0("_", region)
        }
      }
      files[["prefix"]] <- paste0(
        files[["prefix"]],
        vapply(files[["bname"]], suffix_for, character(1))
      )
      files
    },
    # Read a DRAGEN metrics file (section,rg,variable,count[,pct]) into a long
    # tibble. `count` kept character (time strings, >32-bit counts); `pct` numeric.
    parse_metrics = function(x) {
      d <- utils::read.csv(
        x,
        header = FALSE,
        col.names = c("section", "rg", "variable", "count", "pct"),
        colClasses = "character",
        fill = TRUE,
        strip.white = TRUE,
        quote = "",
        na.strings = "NA",
        blank.lines.skip = TRUE
      )
      d <- tibble::as_tibble(d)
      d[["pct"]] <- as.double(d[["pct"]])
      attr(d, "file_version") <- "latest"
      d[]
    },
    # `type` is the readr code from Config's remap (char->c, int->i, float->d)
    coerce_by_type = function(vec, type) {
      switch(
        type,
        i = as.integer(vec),
        d = as.double(vec),
        c = as.character(vec),
        vec
      )
    },
    # Strip " over <region>" from metric names; returns list(x, region code or NA).
    region_split = function(x) {
      pat <- " over (genome|target region|QC coverage region)$"
      codes <- c(
        "genome" = "genome",
        "target region" = "targetreg",
        "QC coverage region" = "qccovreg"
      )
      hits <- regmatches(x$variable, regexpr(pat, x$variable))
      region_txt <- unique(sub("^ over ", "", hits))
      region <- if (length(region_txt) >= 1) unname(codes[region_txt[1]]) else NA_character_
      x$variable <- sub(pat, "", x$variable)
      list(x = x, region = region)
    },
    # Pivot long metrics wide: one row per id cols, one column per mapped metric
    # (+ `<metric>_pct`). `normalise` rewrites the long tibble before mapping.
    tidy_metrics = function(
      x,
      table_name,
      normalise = NULL,
      on_unmapped = NULL,
      on_coerce_fail = NULL,
      on_unexpected_col = NULL,
      drop_constant = c("section", "rg")
    ) {
      if (!tibble::is_tibble(x)) {
        x <- private$parse_metrics(x)
      }
      if (!is.null(normalise)) {
        x <- normalise(x)
      }
      version <- nemo::get_tbl_version_attr(x)
      col_map <- self$config$get_col_map(table_name, version = version)
      raw_to_tidy <- col_map |> dplyr::select("raw", "tidy") |> tibble::deframe()
      tidy_to_type <- col_map |> dplyr::select("tidy", "type") |> tibble::deframe()

      # file metrics absent from the schema, per `on_unmapped`
      unmapped <- setdiff(unique(x$variable), names(raw_to_tidy))
      if (length(unmapped) > 0) {
        mode <- rlang::arg_match0(on_unmapped %||% self$on_unmapped, c("error", "warn"))
        detail <- glue(
          "tidydragen: {length(unmapped)} unmapped metric(s) in '{table_name}': ",
          "{glue::glue_collapse(unmapped, sep = '; ')}"
        )
        if (identical(mode, "error")) {
          nemo::nemo_stop(
            glue(
              "{detail}. Refusing to drop data. Add these to the schema, or set ",
              "the tool's `on_unmapped = \"warn\"` field to drop them with a warning."
            )
          )
        }
        warning(glue("{detail} (dropped)"), call. = FALSE)
      }

      # id columns = everything that isn't the metric name or its values
      id_cols <- setdiff(colnames(x), c("variable", "count", "pct"))

      d_count <- x |>
        dplyr::filter(.data$variable %in% names(raw_to_tidy)) |>
        dplyr::mutate(tidy_var = raw_to_tidy[.data$variable]) |>
        dplyr::select(dplyr::all_of(id_cols), "tidy_var", value = "count") |>
        tidyr::pivot_wider(names_from = "tidy_var", values_from = "value")

      # coerce to schema type; non-empty -> NA is data loss, per `on_coerce_fail`
      present <- intersect(names(tidy_to_type), colnames(d_count))
      coerce_fails <- character()
      for (nm in present) {
        orig <- d_count[[nm]]
        new <- suppressWarnings(private$coerce_by_type(orig, tidy_to_type[[nm]]))
        # DRAGEN "nan" (e.g. 0/0 het-hom ratio) -> NaN is valid, not lost
        lost <- !is.na(orig) & nzchar(trimws(orig)) & is.na(new) & !is.nan(new)
        if (any(lost)) {
          coerce_fails <- c(
            coerce_fails,
            glue("{nm}={glue::glue_collapse(unique(orig[lost]), sep = '/')}")
          )
        }
        d_count[[nm]] <- new
      }
      if (length(coerce_fails) > 0) {
        mode <- rlang::arg_match0(on_coerce_fail %||% self$on_coerce_fail, c("error", "warn"))
        detail <- glue(
          "tidydragen: {length(coerce_fails)} value(s) in '{table_name}' failed ",
          "coercion to their schema type (-> NA): ",
          "{glue::glue_collapse(coerce_fails, sep = '; ')}"
        )
        if (identical(mode, "error")) {
          nemo::nemo_stop(
            glue(
              "{detail}. Fix the schema `type` (likely should be char), or set the ",
              "tool's `on_coerce_fail = \"warn\"` field to keep the NA."
            )
          )
        }
        warning(glue("{detail}"), call. = FALSE)
      }

      d_pct <- x |>
        dplyr::filter(.data$variable %in% names(raw_to_tidy), !is.na(.data$pct)) |>
        dplyr::mutate(tidy_var = paste0(raw_to_tidy[.data$variable], "_pct")) |>
        dplyr::select(dplyr::all_of(id_cols), "tidy_var", value = "pct") |>
        tidyr::pivot_wider(names_from = "tidy_var", values_from = "value")

      d_tidy <- dplyr::left_join(d_count, d_pct, by = id_cols)

      # drop constant `drop_constant` id cols; one that varies would add a
      # surprise column, per `on_unexpected_col`
      unexpected <- character()
      for (col in intersect(drop_constant, colnames(d_tidy))) {
        if (dplyr::n_distinct(d_tidy[[col]]) <= 1L) {
          d_tidy[[col]] <- NULL
        } else {
          unexpected <- c(unexpected, col)
        }
      }
      if (length(unexpected) > 0) {
        mode <- rlang::arg_match0(on_unexpected_col %||% self$on_unexpected_col, c("error", "warn"))
        detail <- glue(
          "tidydragen: id column(s) expected constant in '{table_name}' but found ",
          "varying: {glue::glue_collapse(unexpected, sep = '; ')}"
        )
        if (identical(mode, "error")) {
          nemo::nemo_stop(
            glue(
              "{detail}. This would add an unexpected column to the output. Add the ",
              "column to the schema handling, or set the tool's `on_unexpected_col = ",
              "\"warn\"` field (or pass `drop_constant` explicitly) to keep it with a warning."
            )
          )
        }
        warning(glue("{detail} (kept)"), call. = FALSE)
      }

      # interleave each metric with its `_pct` twin, id cols first
      count_names <- setdiff(colnames(d_count), id_cols)
      paired <- unlist(lapply(count_names, function(nm) {
        pct <- paste0(nm, "_pct")
        if (pct %in% colnames(d_tidy)) c(nm, pct) else nm
      }))
      keep_ids <- intersect(colnames(d_tidy), id_cols)
      d_tidy <- d_tidy[, c(keep_ids, paired), drop = FALSE]

      list(d_tidy) |>
        rlang::set_names(table_name) |>
        nemo::nemo_enframe()
    }
  )
)
