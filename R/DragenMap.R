#' @title DragenMap Object
#'
#' @description
#' Parses and tidies DRAGEN mapping/alignment outputs: mapping metrics, run-time
#' metrics, the fragment-length histogram, and run provenance (`replay.json`).
#'
#' @examples
#' cls <- DragenMap; tool <- "dragenmap"
#' indir <- system.file("extdata", tool, package = "tidydragen")
#' odir <- tempdir()
#' obj <- cls$new(indir)
#' obj$run(output_dir = odir, format = "parquet", input_id = "run1")
#' (lf <- list.files(odir, pattern = "dragenmap_.*parquet", full.names = FALSE))
#' @testexamples
#' mapf <- arrow::read_parquet(file.path(odir, grep("sampleA_dragenmap_metrics", lf, value = TRUE)))
#' # section stripped to phenotype; blank SUMMARY rg -> Total
#' expect_true(all(mapf$section %in% c("TUMOR", "NORMAL", "SINGLE")))
#' summ <- mapf[mapf$section == "TUMOR" & mapf$rg == "Total", ]
#' expect_equal(summ$reads_tot_input, 2635326658)
#' expect_equal(summ$reads_mapped_pct, 97.64)
#' # run-time metrics: seconds land as the value (not the HH:MM:SS string)
#' tf <- arrow::read_parquet(file.path(odir, grep("sampleA_dragenmap_time", lf, value = TRUE)))
#' expect_equal(tf$total_runtime, 8189.85)
#' expect_equal(tf$time_aligning_reads, 2240.12)
#' expect_equal(tf$time_variant_calling, 3725.68)
#' # fraglenhist: per-#Sample: blocks split, sample id kept, headers dropped
#' fl <- arrow::read_parquet(file.path(odir, grep("sampleA_dragenmap_fraglenhist", lf, value = TRUE)))
#' expect_setequal(unique(fl$sample), c("sampleA", "sampleA_tn"))
#' expect_equal(fl$count[fl$fraglen == 150 & fl$sample == "sampleA"], 51)
#' expect_equal(fl$count[fl$fraglen == 150 & fl$sample == "sampleA_tn"], 36)
#' # trimmer metrics (cttso): plain dragen-metrics table, pct auto-paired
#' tr <- arrow::read_parquet(file.path(odir, grep("sampleA_dragenmap_trimmer", lf, value = TRUE)))
#' expect_equal(tr$reads_tot_input, 157866430)
#' expect_equal(tr$polygkmers3r1_remaining, 54953)
#' expect_equal(tr$polygkmers3r1_remaining_pct, 0.07)
#' # umi split: summary (umimain, wide) + histograms (umihist, long)
#' um <- arrow::read_parquet(file.path(odir, grep("sampleA_dragenmap_umimain", lf, value = TRUE)))
#' expect_equal(nrow(um), 1L)
#' expect_equal(um$reads_tot, 849205054)
#' expect_equal(um$reads_umi_valid_correctable_pct, 99.85)
#' expect_equal(um$avg_family_depth, 4.89)
#' expect_equal(um$reads_tot_ontarget, 606111466)
#' uh <- arrow::read_parquet(file.path(odir, grep("sampleA_dragenmap_umihist", lf, value = TRUE)))
#' expect_true(is.integer(uh$bin))
#' expect_setequal(unique(uh$hist_type), c("num_supporting_fragments", "num_supporting_fragments_ontarget", "unique_umis_per_fragpos"))
#' nsf <- uh[uh$hist_type == "num_supporting_fragments", ]
#' expect_equal(nsf$count[nsf$bin == 2], 22645846)
#' uu <- uh[uh$hist_type == "unique_umis_per_fragpos", ]
#' expect_equal(uu$count[uu$bin == 1], 95680458)
#' # gc split: summary (gcmain, wide) + per-GC-window (gcbias, long)
#' gc <- arrow::read_parquet(file.path(odir, grep("sampleA_dragenmap_gcmain", lf, value = TRUE)))
#' expect_equal(nrow(gc), 1L)
#' expect_true(is.integer(gc$window_size))
#' expect_equal(gc$gc_ref_avg, 40.90)
#' expect_equal(gc$at_dropout, 29.40)
#' gb <- arrow::read_parquet(file.path(odir, grep("sampleA_dragenmap_gcbias", lf, value = TRUE)))
#' expect_true(is.integer(gb$gc_window))
#' expect_equal(nrow(gb), 101L)
#' expect_equal(gb$windows[gb$gc_window == 0], 132617)
#' expect_equal(gb$pct[gb$gc_window == 40], 3.595)
#' expect_equal(gb$cov_norm[gb$gc_window == 0], 0.0120)
#' # replaymain: run provenance (version, hash-table build, config dump)
#' rp <- arrow::read_parquet(file.path(odir, grep("sampleA_dragenmap_replaymain\\.parquet$", lf, value = TRUE)))
#' expect_equal(rp$dragen_version, "13.021.779.4.4.4")
#' rc <- arrow::read_parquet(file.path(odir, grep("sampleA_dragenmap_replayconfig\\.parquet$", lf, value = TRUE)))
#' expect_equal(rc$value[rc$name == "Aligner.align-direction"], "4")
#' # cttso emits one replay.json + time_metrics.csv PER DRAGEN invocation stage
#' # (DragenCaller, Tmb); same basename, genuinely different content -> lands
#' # as 2 rows via nemo's generic same-basename disambiguation, not a dedup
#' expect_equal(length(grep("sampleB.*_dragenmap_replaymain\\.parquet$", lf, value = TRUE)), 2L)
#' expect_equal(length(grep("sampleB.*_dragenmap_time\\.parquet$", lf, value = TRUE)), 2L)
#' @export
DragenMap <- R6::R6Class(
  "DragenMap",
  cloneable = FALSE,
  inherit = DragenTool,
  public = list(
    #' @field flat_tidy_names (`logical(1)`)\cr
    #' `TRUE`: fan-out sub-tables are named `<tool>_<tidy_name>` (parser token
    #' dropped). Needed for the `umimain`/`umihist` and `gcmain`/`gcbias` splits.
    flat_tidy_names = TRUE,
    #' @description Create a new DragenMap object.
    #' @param path (`character(1)`)\cr
    #' Output directory of tool. If `files_tbl` is supplied, this is ignored.
    #' @param files_tbl (`tibble(n)`)\cr
    #' Tibble of files from [nemo::list_files_dir()].
    initialize = function(path = NULL, files_tbl = NULL) {
      super$initialize(name = "dragenmap", pkg = pkg_name, path = path, files_tbl = files_tbl)
    },
    #' @description Tidy `mapping_metrics.csv`. Both id columns retained
    #' (`drop_constant = character()`).
    #' @param x (`character(1)` or `tibble()`)\cr Path to file or parsed tibble.
    tidy_metrics = function(x) {
      private$tidy_metrics(x, "metrics", drop_constant = character(), normalise = function(d) {
        # section -> phenotype (SINGLE for single-sample); blank SUMMARY rg -> Total
        d$section <- trimws(sub("MAPPING/ALIGNING (SUMMARY|PER RG)", "", d$section))
        d$section[d$section == ""] <- "SINGLE"
        d$rg[d$rg == ""] <- "Total"
        d
      })
    },
    #' @description Tidy `umi_metrics.csv` into `umimain` (summary, wide) and
    #' `umihist` (the `{a|b|c}` histograms, long).
    #' @param x (`character(1)` or `tibble()`)\cr Path to file or parsed tibble.
    tidy_umimain = function(x) {
      if (!tibble::is_tibble(x)) {
        x <- private$parse_metrics(x)
      }
      is_hist <- grepl("istogram", x$variable)
      stats <- private$tidy_metrics(x[!is_hist, , drop = FALSE], "umimain")
      stats$name <- "umimain"
      # "{a|b|c}" -> long, 0-based bin; on-target variant encoded in hist_type
      htype <- c(
        "Histogram of num supporting fragments" = "num_supporting_fragments",
        "On target histogram of num supporting fragments" = "num_supporting_fragments_ontarget",
        "Histogram of unique UMIs per fragment position" = "unique_umis_per_fragpos"
      )
      hx <- x[is_hist, , drop = FALSE]
      hist_tbl <- tibble::tibble(
        hist_type = unname(htype[hx$variable]),
        count = strsplit(gsub("[{}]", "", hx$count), "\\|")
      ) |>
        dplyr::mutate(bin = lapply(.data$count, \(v) seq_along(v) - 1L)) |>
        tidyr::unnest(c("bin", "count")) |>
        dplyr::transmute(
          .data$hist_type,
          bin = as.integer(.data$bin),
          count = as.double(.data$count)
        )
      attr(hist_tbl, "file_version") <- "latest"
      dplyr::bind_rows(stats, tibble::tibble(name = "umihist", data = list(hist_tbl)))
    },
    #' @description Tidy `gc_metrics.csv` into `gcmain` (GC METRICS SUMMARY, wide)
    #' and `gcbias` (per-GC-window GC BIAS DETAILS, long — GC 0-100).
    #' @param x (`character(1)` or `tibble()`)\cr Path to file or parsed tibble.
    tidy_gcmain = function(x) {
      if (!tibble::is_tibble(x)) {
        x <- private$parse_metrics(x)
      }
      is_detail <- x$section == "GC BIAS DETAILS"
      stats <- private$tidy_metrics(x[!is_detail, , drop = FALSE], "gcmain")
      stats$name <- "gcmain"
      # two per-GC series -> merge on GC value: window count + pct, and normalized cov
      det <- x[is_detail, , drop = FALSE]
      win <- det[grepl("^Windows at GC ", det$variable), , drop = FALSE]
      cov <- det[grepl("^Normalized coverage at GC ", det$variable), , drop = FALSE]
      windows_tbl <- tibble::tibble(
        gc_window = as.integer(sub("^Windows at GC ", "", win$variable)),
        windows = as.double(win$count),
        pct = as.double(win$pct)
      )
      cov_tbl <- tibble::tibble(
        gc_window = as.integer(sub("^Normalized coverage at GC ", "", cov$variable)),
        cov_norm = as.double(cov$count)
      )
      bias_tbl <- dplyr::full_join(windows_tbl, cov_tbl, by = "gc_window") |>
        dplyr::arrange(.data$gc_window)
      attr(bias_tbl, "file_version") <- "latest"
      dplyr::bind_rows(stats, tibble::tibble(name = "gcbias", data = list(bias_tbl)))
    },
    #' @description Tidy `time_metrics.csv`, using seconds (not HH:MM:SS) as the
    #' metric value and surfacing `total_runtime` first.
    #' @param x (`character(1)` or `tibble()`)\cr Path to file or parsed tibble.
    tidy_time = function(x) {
      # value = seconds (pct col), not the HH:MM:SS count col
      r <- private$tidy_metrics(x, "time", normalise = function(d) {
        d$count <- as.character(d$pct)
        d$pct <- NA_real_
        d
      })
      # keep overall runtime first
      r$data[[1]] <- dplyr::relocate(r$data[[1]], dplyr::any_of("total_runtime"))
      r
    },
    #' @description Parse `fragment_length_hist.csv` into a long tibble.
    #' @param x (`character(1)`)\cr Path to file.
    parse_fraglenhist = function(x) {
      lines <- readr::read_lines(x)
      # somatic files concatenate one histogram per sample, each led by "#Sample: <id>"
      starts <- grep("^#Sample:", lines)
      ids <- trimws(sub("^#Sample:", "", lines[starts]))
      ends <- c(starts[-1] - 1L, length(lines))
      blocks <- Map(
        function(s, e) {
          body <- lines[(s + 1L):e]
          body <- body[!grepl("^FragmentLength,Count$", body)]
          readr::read_csv(
            I(body),
            col_names = c("FragmentLength", "Count"),
            col_types = readr::cols(
              FragmentLength = readr::col_integer(),
              Count = readr::col_double()
            )
          )
        },
        starts,
        ends
      )
      names(blocks) <- ids
      d <- dplyr::bind_rows(blocks, .id = "sample")
      attr(d, "file_version") <- "latest"
      d[]
    },
    #' @description Parse a `replay.json` file; returns the whole
    #' parsed JSON wrapped in a one-row tibble list-column. `tidy_replaymain()`
    #' fans it out.
    #' @param x (`character(1)`)\cr Path to file.
    parse_replaymain = function(x) {
      j <- jsonlite::fromJSON(x, simplifyVector = FALSE)
      d <- tibble::tibble(data = list(j))
      attr(d, "file_version") <- "latest"
      d[]
    },
    #' @description Fan a `replay.json` file into `replaymain` (run
    #' provenance, 1 row) and `replayconfig` (the full `dragen_config` dump,
    #' long).
    #' @param x (`character(1)` or `tibble()`)\cr Path to file or parsed tibble.
    tidy_replaymain = function(x) {
      if (!tibble::is_tibble(x)) {
        x <- self$parse_replaymain(x)
      }
      j <- x$data[[1]]
      sys <- j[["system"]] %||% list()
      htb <- j[["hash_table_build"]] %||% list()
      replaymain <- tibble::tibble(
        dragen_version = sys[["dragen_version"]] %||% NA_character_,
        nodename = sys[["nodename"]] %||% NA_character_,
        kernel_release = sys[["kernel_release"]] %||% NA_character_,
        ht_sw_version = htb[["sw_version"]] %||% NA_character_,
        hash_table_version = htb[["hash_table_version"]] %||% NA_character_,
        ht_command_line = htb[["command_line_options"]] %||% NA_character_,
        command_line = j[["command_line"]] %||% NA_character_
      )
      attr(replaymain, "file_version") <- "latest"
      cfg <- j[["dragen_config"]] %||% list()
      if (length(cfg) > 0) {
        replayconfig <- purrr::map(cfg, \(e) {
          tibble::tibble(
            name = e[["name"]] %||% NA_character_,
            value = e[["value"]] %||% NA_character_
          )
        }) |>
          purrr::list_rbind()
      } else {
        replayconfig <- nemo::empty_tbl(cnames = c("name", "value"))
      }
      attr(replayconfig, "file_version") <- "latest"
      list(replaymain = replaymain, replayconfig = replayconfig) |>
        nemo::nemo_enframe()
    }
  )
)
