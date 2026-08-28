#' @title DragenTool Object
#'
#' @description
#' Intermediate base class for all tidydragen tools. Inherits [nemo::Tool] and
#' adds DRAGEN-specific shared logic e.g. the metrics parser/tidier used
#' by every `*_metrics.csv` table. Tools like `DragenCov` inherit from
#' `DragenTool` rather than `nemo::Tool` directly. The `dragen-metrics` ftype is
#' registered here (parse via `extra_ftypes()`, tidy via the `tidy_file`
#' override), so a plain metrics table needs no methods — just `ftype:
#' 'dragen-metrics'` in its schema. A table needing a `normalise`/`drop_constant`
#' still declares an explicit `tidy_<tbl>()` that delegates to `tidy_metrics`.
#'
#' @details
#' DRAGEN `*_metrics.csv` files share a headerless 4/5-column shape:
#' `section, rg, variable, count[, pct]`. `rg` (read-group / sample) is empty for
#' most sections but populated for e.g. fastqc and per-sample variant sections.
#' The value column (`count`) is read as character since some metrics carry
#' string values (e.g. `Ploidy estimation` = `"XX"`) and counts can exceed 32-bit
#' range; each tidy column is coerced to its schema `type` after the wide pivot.
#'
#' @examples
#' # Abstract base — normally you use a subclass (e.g. DragenVar). The parser/tidier
#' # are private; here we just inspect the inherited surface + policy fields.
#' indir <- system.file("extdata/dragenmap", package = "tidydragen")
#' tool <- DragenTool$new(name = "dragenmap", pkg = "tidydragen", path = indir)
#' tool$list_files()      # inherited nemo::Tool file discovery
#' tool$on_unmapped       # "error": unmapped metrics abort rather than drop
#' tool$on_coerce_fail    # "error": values that fail type coercion abort
#'
#' # flip a policy to be lenient (drop/keep-NA with a warning instead)
#' tool$on_unmapped <- "warn"
#' @testexamples
#' expect_true(inherits(tool, "Tool"))
#' expect_gt(nrow(tool$list_files()), 0)
#' expect_equal(tool$on_coerce_fail, "error")
#' expect_equal(tool$on_unexpected_col, "error")
#' expect_equal(tool$on_unmapped, "warn")
#' @export
DragenTool <- R6::R6Class(
  "DragenTool",
  cloneable = FALSE,
  inherit = nemo::Tool,
  public = list(
    #' @field on_unmapped (`character(1)`)\cr
    #' Policy for metrics present in a `*_metrics.csv` file but absent from the
    #' schema. `error` refuses to drop data and aborts, so schema
    #' drift (e.g. a new DRAGEN version adds a metric) fails loudly rather than
    #' silently omitting a column. Set to `warn` to instead drop the unmapped
    #' metrics with a warning.
    on_unmapped = "error",
    #' @field on_coerce_fail (`character(1)`)\cr
    #' Policy for a non-empty metric value that fails coercion to its schema
    #' numeric `type` (becomes `NA`). `error` aborts rather than
    #' losing the value; usually a wrong schema `type` (should be `char`) or an
    #' unexpected string. Set to `warn` to keep the `NA` with a warning. Genuine
    #' missings (`NA`/empty in the file) never trigger this.
    on_coerce_fail = "error",
    #' @field on_unexpected_col (`character(1)`)\cr
    #' Policy for an id column named in `tidy_metrics(drop_constant=)` that was
    #' expected to be constant (and so dropped) but instead varies across rows.
    #' `error` aborts rather than letting a surprise extra column appear in the
    #' output table (schema drift into a data lake). Set to `warn` to keep the
    #' unexpected column with a warning. Tables that legitimately vary in
    #' `section`/`rg` opt out via `drop_constant = character()` and never trip this.
    on_unexpected_col = "error"
  ),
  private = list(
    # Register pkg-specific ftype parsers. `dragen-metrics` routes every
    # `*_metrics.csv` table through the shared `parse_metrics`, so simple metrics
    # tables need no `parse_<tbl>` one-liner (tidy is routed in `tidy_file` below).
    # `csv-nohead` is used by certain coverage tables.
    extra_ftypes = function() {
      list(
        "dragen-metrics" = function(x, table_name) private$parse_metrics(x),
        "csv-nohead" = function(x, table_name) {
          # trim_ws: overall-mean/hist rows have a space after the comma
          # (", 37.32") that breaks double parsing.
          private$parse_file_nohead(x, table_name, delim = ",", trim_ws = TRUE)
        }
      )
    },
    # nemo's tidy dispatch has no ftype hook (custom `tidy_<tbl>()` or else
    # `tidy_file`), so route `dragen-metrics` tables to the shared pivot here.
    # Tables needing a `normalise`/`drop_constant` still declare an explicit
    # `tidy_<tbl>()`; the plain ones fall through to this.
    tidy_file = function(x, table_name, convert_types = FALSE) {
      if (identical(self$config$get_ftype(table_name), "dragen-metrics")) {
        return(private$tidy_metrics(x, table_name))
      }
      super$tidy_file(x, table_name, convert_types = convert_types)
    },
    # Fold the coverage region (wgs / tmb / qc-coverage-region-<label>) and
    # phenotype (normal / tumor) from the filename into `prefix`, so
    # `sampleA.wgs_coverage_metrics_tumor.csv` -> `sampleA_wgs_tumor_dragencov_metrics`.
    # Appends `_<region>[_<pheno>]` before nemo's `_2/_3` collision fallback fires.
    # No-op on non-coverage files (regex never matches). The qc-coverage-region
    # <label> is the user's `--qc-coverage-region-N` name, matched generically and
    # the stem dropped to leave the label; wgs/tmb are fixed keywords, enumerated.
    refine_files = function(files) {
      if (nrow(files) == 0) {
        return(files)
      }
      # region must be followed by a known coverage subtype so non-coverage files
      # never match.
      region_re <- paste0(
        "(wgs|tmb|qc-coverage-region-[A-Za-z0-9-]+)_",
        "(?:contig_mean_cov|overall_mean_cov|coverage_metrics|fine_hist|hist|",
        "read_cov_report|cov_report)"
      )
      # Build the "_<region>[_<pheno>]" suffix for one basename. Returns "" for a
      # non-coverage file so its prefix is left untouched.
      suffix_for <- function(bname) {
        # m[2] = region group; length(m) < 2 means non-coverage file, no suffix.
        m <- regmatches(bname, regexec(region_re, bname))[[1]]
        if (length(m) < 2) {
          return("")
        }
        region <- sub("^qc-coverage-region-", "", m[2])
        # phenotype present only in somatic files ("..._tumor.csv"); ph[2] is the
        # matched group, else empty.
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
    # Coerce a character vector to the schema type for its column. `type` is the
    # readr type code from Config's remap (char->c, int->i, float->d).
    coerce_by_type = function(vec, type) {
      switch(
        type,
        i = as.integer(vec),
        d = as.double(vec),
        c = as.character(vec),
        vec
      )
    },
    # Detect the coverage/variant region embedded in metric names and strip the
    # " over <region>" suffix so names normalise across regions. Returns the
    # modified tibble plus the detected region code (or NA if none present).
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
    # Pivot a long metrics tibble wide: one row per (section, rg [, extra id cols]),
    # one column per mapped metric plus a paired `<metric>_pct`. `normalise`
    # rewrites the long tibble before mapping (e.g. region stripping for vc).
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

      # metrics present in the file but absent from the schema: error (default,
      # never drop data) or warn-and-drop, per `on_unmapped`.
      unmapped <- setdiff(unique(x$variable), names(raw_to_tidy))
      if (length(unmapped) > 0) {
        mode <- rlang::arg_match0(on_unmapped %||% self$on_unmapped, c("error", "warn"))
        detail <- glue(
          "tidydragen: {length(unmapped)} unmapped metric(s) in '{table_name}': ",
          "{glue::glue_collapse(unmapped, sep = '; ')}"
        )
        if (identical(mode, "error")) {
          stop(
            glue(
              "{detail}. Refusing to drop data — add these to the schema, or set ",
              "the tool's `on_unmapped = \"warn\"` field to drop them with a warning."
            ),
            call. = FALSE
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

      # coerce each metric column to its schema type. A non-empty value that
      # coerces to NA is data loss (wrong schema type / unexpected string);
      # collect and error/warn per on_coerce_fail.
      present <- intersect(names(tidy_to_type), colnames(d_count))
      coerce_fails <- character()
      for (nm in present) {
        orig <- d_count[[nm]]
        new <- suppressWarnings(private$coerce_by_type(orig, tidy_to_type[[nm]]))
        # is.nan guard: DRAGEN's "nan" (e.g. 0/0 het-hom ratio) parses to a valid
        # NaN, not a failure. Only a plain NA (as.numeric("abc")) is lost data.
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
          stop(
            glue(
              "{detail}. Fix the schema `type` (likely should be char), or set the ",
              "tool's `on_coerce_fail = \"warn\"` field to keep the NA."
            ),
            call. = FALSE
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

      # Drop the `drop_constant` id cols, expected constant so carrying no grouping
      # info. One that VARIES is schema drift (would add a surprise output column)
      # -> error/warn per `on_unexpected_col`. Provenance cols added by `normalise`
      # (region, chrom) aren't eligible; tables that legitimately vary (mapping, vc,
      # hethom) pass `drop_constant = character()`.
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
          stop(
            glue(
              "{detail}. This would add an unexpected column to the output. Add the ",
              "column to the schema handling, or set the tool's `on_unexpected_col = ",
              "\"warn\"` field (or pass `drop_constant` explicitly) to keep it with a warning."
            ),
            call. = FALSE
          )
        }
        warning(glue("{detail} (kept)"), call. = FALSE)
      }

      # Interleave each metric with its paired `_pct` (counts and pcts are pivoted
      # separately then joined, which would otherwise leave all pcts in a block
      # after all counts). Retained id cols stay in front, in order.
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
