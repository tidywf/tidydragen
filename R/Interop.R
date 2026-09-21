#' @title Interop Object
#'
#' @description
#' Parses and tidies Illumina InterOp run-QC summary outputs: `<run>_summary.csv`
#' (per-read/lane/surface run metrics), `<run>-index_summary.csv`
#' (per-lane/index demux QC), and `imaging_table.csv`/`imaging_table.csv.gz`
#' (per-lane/tile/cycle imaging metrics; gzipped or not, both accepted). InterOp
#' is Illumina run-level QC, not a DRAGEN output, so unlike the other tools this
#' one inherits `nemo::Tool` directly rather than the DRAGEN-shared `DragenTool`
#' base; it's housed here for convenience (typically co-located with
#' BCLConvert). The run id for `summary.csv`/`index_summary.csv` lives in the
#' filename itself, so the usual prefix extraction just works with no
#' `refine_files()` override needed there; `imaging_table.csv[.gz]` carries no
#' run id in its filename at all, so that one is handled explicitly.
#'
#' @examples
#' cls <- Interop; tool <- "interop"
#' # summaries/ kept separate from imaging_tables/ so scanning for one never
#' # also matches the other (list_files_dir() recurses; `imaging_table.csv`
#' # and `.csv.gz` both match the imagingtable pattern, so a single run over
#' # imaging_tables/ picks up BOTH compressed/ and uncompressed/ at once and
#' # nemo's generic same-table collision handling disambiguates them, `_2`
#' # suffix --- exercised deliberately below, not avoided).
#' odir <- tempdir()
#' obj_sum <- cls$new(system.file("extdata", tool, "summaries", package = "tidydragen"))
#' obj_sum$run(output_dir = odir, format = "parquet", input_id = "run1")
#' obj_it <- cls$new(system.file("extdata", tool, "imaging_tables", package = "tidydragen"))
#' obj_it$run(output_dir = odir, format = "parquet", input_id = "run1")
#' (lf <- list.files(odir, pattern = "interop_.*parquet", full.names = FALSE))
#' @testexamples
#' # summarymain: overall level table (Read1/Read2(I)/Read3(I)/Read4/Non-indexed/Total)
#' sm <- nemo::read_parquet_grep(odir, lf, "runA_interop_summarymain\\.parquet$")
#' expect_setequal(sm$level, c("Read 1", "Read 2 (I)", "Read 3 (I)", "Read 4", "Non-indexed", "Total"))
#' expect_equal(sm$yield[sm$level == "Total"], 4196.52)
#' # index reads have no PhiX alignment -> error_rate NA (raw "nan")
#' expect_true(is.na(sm$error_rate[sm$level == "Read 2 (I)"]))
#' # summaryreadlane: per-read x lane x surface detail, "mean +/- sd" / "a / b" cells split
#' rl <- nemo::read_parquet_grep(odir, lf, "runA_interop_summaryreadlane\\.parquet$")
#' expect_equal(nrow(rl), 48L)
#' r1l1 <- rl[rl$read == "Read 1" & rl$lane == 1 & is.na(rl$surface), ]
#' expect_equal(r1l1$density, 2961)
#' expect_equal(r1l1$density_sd, 0)
#' expect_equal(r1l1$legacy_phasing_rate, 0.089)
#' expect_equal(r1l1$legacy_prephasing_rate, 0.040)
#' # non-PhiX-spiked read -> phasing/prephasing rate NA (raw "nan / nan")
#' r2l1 <- rl[rl$read == "Read 2 (I)" & rl$lane == 1 & is.na(rl$surface), ]
#' expect_true(is.na(r2l1$legacy_phasing_rate))
#' # indexsummarymain: per-lane totals
#' ix <- nemo::read_parquet_grep(odir, lf, "runA_interop_indexsummarymain\\.parquet$")
#' expect_equal(nrow(ix), 4L)
#' expect_equal(ix$pct_identified[ix$lane == 1], 97.0617)
#' # indexsummarydetail: per-index rows
#' ixd <- nemo::read_parquet_grep(odir, lf, "runA_interop_indexsummarydetail\\.parquet$")
#' expect_equal(ixd$sample_id[ixd$lane == 1 & ixd$index_number == 1], "s2600353")
#' expect_equal(ixd$index2[ixd$lane == 1 & ixd$index_number == 1], "CTAATAACCG")
#' # imagingtable: run-scoped (no run id in filename) -> plain interop_imagingtable
#' # name, but compressed/ + uncompressed/ collide on it here -> nemo's `_2`
#' # disambiguation kicks in (2 files, identical content, one gz one plain)
#' it_files <- grep("^interop_imagingtable(_[0-9]+)?\\.parquet$", lf, value = TRUE)
#' expect_length(it_files, 2L)
#' it <- do.call(rbind, lapply(it_files, \(f) arrow::read_parquet(file.path(odir, f))))
#' expect_equal(nrow(it), 8L) # 4 rows x 2 (compressed + uncompressed)
#' r1 <- it[it$tile == 1101 & it$cycle == 1, ]
#' expect_equal(unique(r1$density), 2961.300049)
#' expect_true(all(is.na(r1$corrected_a))) # raw "nan" -> NA, not NaN
#' # PhiX-spiked tile has a real aligned_pct/error_rate; others are NA
#' r2 <- it[it$tile == 1103, ]
#' expect_true(all(r2$aligned_pct == 0.400000006))
#' expect_true(all(is.na(r1$aligned_pct)))
#' @export
Interop <- R6::R6Class(
  "Interop",
  cloneable = FALSE,
  inherit = Tool,
  public = list(
    #' @field flat_tidy_names (`logical(1)`)\cr
    #' `TRUE`: fan-out sub-tables are named `<tool>_<tidy_name>` (parser token
    #' dropped). Needed for the `summarymain`/`summaryreadlane` and
    #' `indexsummarymain`/`indexsummarydetail` splits.
    flat_tidy_names = TRUE,
    #' @description Create a new Interop object.
    #' @param path (`character(1)`)\cr
    #' Output directory of tool. If `files_tbl` is supplied, this is ignored.
    #' @param files_tbl (`tibble(n)`)\cr
    #' Tibble of files from [nemo::list_files_dir()].
    initialize = function(path = NULL, files_tbl = NULL) {
      super$initialize(name = "interop", pkg = pkg_name, path = path, files_tbl = files_tbl)
    },
    #' @description Parse `<run>_summary.csv`; returns the raw level table and
    #' the raw per-read/lane/surface table (both still character), wrapped in a
    #' one-row tibble list-column. `tidy_summarymain()` types and splits them.
    #' @param x (`character(1)`)\cr Path to file.
    parse_summarymain = function(x) {
      lines <- readr::read_lines(x)
      blank <- which(!nzchar(lines))
      level_raw <- readr::read_csv(
        I(lines[3:(blank[1] - 1L)]),
        col_types = readr::cols(.default = "c"),
        show_col_types = FALSE
      )
      body <- lines[(max(blank) + 1L):length(lines)]
      readlane_raw <- private$parse_labelled_blocks(
        body,
        id_name = "read",
        id_from_label = identity
      )
      d <- tibble::tibble(data = list(list(level = level_raw, readlane = readlane_raw)))
      attr(d, "file_version") <- "latest"
      d[]
    },
    #' @description Fan `<run>_summary.csv` into `summarymain` (level table, wide,
    #' 6 rows) and `summaryreadlane` (per-read/lane/surface detail, long).
    #' `"nan"`/`"-"` sentinel values -> NA throughout; `"mean +/- sd"` and
    #' `"a / b"` cells are split into paired columns.
    #' @param x (`character(1)` or `tibble()`)\cr Path to file or parsed tibble.
    tidy_summarymain = function(x) {
      if (!tibble::is_tibble(x)) {
        x <- self$parse_summarymain(x)
      }
      raw <- x$data[[1]]
      summary_tbl <- tibble::tibble(
        level = raw$level$Level,
        yield = as.double(raw$level$Yield),
        yield_projected = as.double(raw$level[["Projected Yield"]]),
        aligned_pct = as.double(raw$level$Aligned),
        error_rate = private$num(raw$level[["Error Rate"]]),
        intensity_c1 = as.double(raw$level[["Intensity C1"]]),
        pct_q30 = as.double(raw$level[["%>=Q30"]]),
        pct_occupied = as.double(raw$level[["% Occupied"]])
      )
      attr(summary_tbl, "file_version") <- "latest"
      rl <- raw$readlane
      dens <- private$split_pm(rl$Density)
      cpf <- private$split_pm(rl[["Cluster PF"]])
      legphas <- private$split_slash(rl[["Legacy Phasing/Prephasing Rate"]])
      phas <- private$split_slash(rl[["Phasing  slope/offset"]])
      prephas <- private$split_slash(rl[["Prephasing slope/offset"]])
      algn <- private$split_pm(rl$Aligned)
      err <- private$split_pm(rl$Error)
      err35 <- private$split_pm(rl[["Error (35)"]])
      err75 <- private$split_pm(rl[["Error (75)"]])
      err100 <- private$split_pm(rl[["Error (100)"]])
      occ <- private$split_pm(rl[["% Occupied"]])
      ic1 <- private$split_pm(rl[["Intensity C1"]])
      readlane_tbl <- tibble::tibble(
        read = rl$read,
        lane = as.integer(rl$Lane),
        surface = suppressWarnings(as.integer(rl$Surface)),
        tiles = as.integer(rl$Tiles),
        density = dens$mean,
        density_sd = dens$sd,
        cluster_pf_pct = cpf$mean,
        cluster_pf_pct_sd = cpf$sd,
        legacy_phasing_rate = legphas$a,
        legacy_prephasing_rate = legphas$b,
        phasing_slope = phas$a,
        phasing_offset = phas$b,
        prephasing_slope = prephas$a,
        prephasing_offset = prephas$b,
        reads = as.double(rl$Reads),
        reads_pf = as.double(rl[["Reads PF"]]),
        pct_q30 = as.double(rl[["%>=Q30"]]),
        yield = as.double(rl$Yield),
        cycles_error = rl[["Cycles Error"]],
        aligned_pct = algn$mean,
        aligned_pct_sd = algn$sd,
        error_pct = err$mean,
        error_pct_sd = err$sd,
        error35_pct = err35$mean,
        error35_pct_sd = err35$sd,
        error75_pct = err75$mean,
        error75_pct_sd = err75$sd,
        error100_pct = err100$mean,
        error100_pct_sd = err100$sd,
        pct_occupied = occ$mean,
        pct_occupied_sd = occ$sd,
        intensity_c1 = ic1$mean,
        intensity_c1_sd = ic1$sd
      )
      attr(readlane_tbl, "file_version") <- "latest"
      list(summarymain = summary_tbl, summaryreadlane = readlane_tbl) |>
        nemo::nemo_enframe()
    },
    #' @description Parse `<run>-index_summary.csv`; returns the raw per-lane
    #' totals and the raw per-index table (both still character), wrapped in a
    #' one-row tibble list-column. `tidy_indexsummarymain()` types them.
    #' @param x (`character(1)`)\cr Path to file.
    parse_indexsummarymain = function(x) {
      lines <- readr::read_lines(x)
      body <- lines[-1] # drop the "# Version: ..." comment
      d <- tibble::tibble(data = list(private$parse_index_blocks(body)))
      attr(d, "file_version") <- "latest"
      d[]
    },
    #' @description Fan `<run>-index_summary.csv` into `indexsummarymain` (per-lane
    #' totals, wide) and `indexsummarydetail` (per-index rows, long).
    #' @param x (`character(1)` or `tibble()`)\cr Path to file or parsed tibble.
    tidy_indexsummarymain = function(x) {
      if (!tibble::is_tibble(x)) {
        x <- self$parse_indexsummarymain(x)
      }
      raw <- x$data[[1]]
      indexsummary_tbl <- tibble::tibble(
        lane = as.integer(raw$lanetot$lane),
        reads_tot = as.double(raw$lanetot[["Total Reads"]]),
        reads_pf = as.double(raw$lanetot[["PF Reads"]]),
        pct_identified = as.double(raw$lanetot[["% Read Identified (PF)"]]),
        cv = as.double(raw$lanetot$CV),
        pct_identified_min = as.double(raw$lanetot$Min),
        pct_identified_max = as.double(raw$lanetot$Max)
      )
      attr(indexsummary_tbl, "file_version") <- "latest"
      detail_tbl <- tibble::tibble(
        lane = as.integer(raw$idx$lane),
        index_number = as.integer(raw$idx[["Index Number"]]),
        sample_id = raw$idx[["Sample Id"]],
        project = raw$idx$Project,
        index1 = raw$idx[["Index 1 (I7)"]],
        index2 = raw$idx[["Index 2 (I5)"]],
        pct_identified = as.double(raw$idx[["% Read Identified (PF)"]])
      )
      attr(detail_tbl, "file_version") <- "latest"
      list(indexsummarymain = indexsummary_tbl, indexsummarydetail = detail_tbl) |>
        nemo::nemo_enframe()
    },
    #' @description Parse `imaging_table.csv`/`imaging_table.csv.gz` (`readr`
    #' decompresses `.gz` transparently by extension --- no branching needed
    #' here). Its header is unreliable for grouped columns (e.g.
    #' `"Corrected<A;C;G;T>"` prints one label but is followed by 4 data
    #' columns), so this bypasses the header entirely (`skip = 3`, past the
    #' 2 `#` comment lines + the header row) and reads 49 positional character
    #' columns; `"nan"` -> `NA` at parse time so `tidy_imagingtable()`'s
    #' `type_convert()` yields `NA`, not `NaN`.
    #' @param x (`character(1)`)\cr Path to file.
    parse_imagingtable = function(x) {
      d <- readr::read_csv(
        x,
        skip = 3,
        col_names = FALSE,
        col_types = readr::cols(.default = "c"),
        na = c("", "NA", "nan"),
        show_col_types = FALSE
      )
      attr(d, "file_version") <- "latest"
      d[]
    },
    #' @description Type `imaging_table.csv[.gz]`'s 49 positional columns via
    #' the schema (rename + `type_convert()`); no fan-out, one flat table.
    #' @param x (`character(1)` or `tibble()`)\cr Path to file or parsed tibble.
    tidy_imagingtable = function(x) {
      if (!tibble::is_tibble(x)) {
        x <- self$parse_imagingtable(x)
      }
      private$tidy_file(x, "imagingtable", convert_types = TRUE)
    }
  ),
  private = list(
    # Run-scoped like DragenBcl: imaging_table.csv[.gz] carries no run id in its
    # filename (always literally "imaging_table.csv" or ".csv.gz"), so blank its
    # prefix -> nemo names the output plain "interop_imagingtable" instead of
    # collapsing the whole basename into the prefix (nemo's default when the
    # pattern consumes it entirely). summarymain/indexsummarymain keep their
    # filename-derived run-id prefix untouched.
    refine_files = function(files) {
      if (nrow(files) > 0) {
        files[["prefix"]][files[["parser"]] == "imagingtable"] <- ""
      }
      files
    },
    # "mean +/- sd" -> list(mean=, sd=); "nan +/- nan" -> NA/NA
    split_pm = function(x) {
      parts <- strsplit(x, " +/- ", fixed = TRUE)
      a <- vapply(parts, `[`, character(1), 1)
      b <- vapply(parts, function(p) if (length(p) > 1) p[2] else NA_character_, character(1))
      list(mean = private$num(a), sd = private$num(b))
    },
    # "a / b" -> list(a=, b=); "nan / nan" -> NA/NA
    split_slash = function(x) {
      parts <- strsplit(x, " / ", fixed = TRUE)
      a <- vapply(parts, `[`, character(1), 1)
      b <- vapply(parts, function(p) if (length(p) > 1) p[2] else NA_character_, character(1))
      list(a = private$num(a), b = private$num(b))
    },
    # as.double(), but "nan" (any case) -> NA rather than NaN
    num = function(x) {
      d <- suppressWarnings(as.double(x))
      d[is.nan(d)] <- NA_real_
      d
    },
    # summary.csv body: repeating [label line (no comma)][header][data rows].
    # id_from_label extracts the id (e.g. read name) from the label line.
    parse_labelled_blocks = function(body, id_name, id_from_label) {
      is_label <- !grepl(",", body, fixed = TRUE) & nzchar(body)
      label_idx <- which(is_label)
      ends <- c(label_idx[-1] - 1L, length(body))
      purrr::map2(label_idx, ends, function(s, e) {
        hdr <- strsplit(body[s + 1L], ",", fixed = TRUE)[[1]]
        tbl <- readr::read_csv(
          I(body[(s + 2L):e]),
          col_names = hdr,
          col_types = readr::cols(.default = "c"),
          show_col_types = FALSE
        )
        tbl[[id_name]] <- id_from_label(body[s])
        tbl
      }) |>
        purrr::list_rbind()
    },
    # index_summary.csv body: repeating [Lane N][lane-total header][1 row]
    # [per-index header][N rows]. Lane-total block is always exactly 1 row.
    parse_index_blocks = function(body) {
      is_label <- !grepl(",", body, fixed = TRUE) & nzchar(body)
      label_idx <- which(is_label)
      ends <- c(label_idx[-1] - 1L, length(body))
      blocks <- purrr::map2(label_idx, ends, function(s, e) {
        lane <- as.integer(sub("^Lane ", "", body[s]))
        hdr1 <- strsplit(body[s + 1L], ",", fixed = TRUE)[[1]]
        lanetot <- readr::read_csv(
          I(body[s + 2L]),
          col_names = hdr1,
          col_types = readr::cols(.default = "c"),
          show_col_types = FALSE
        )
        lanetot$lane <- lane
        hdr2 <- strsplit(body[s + 3L], ",", fixed = TRUE)[[1]]
        idx <- readr::read_csv(
          I(body[(s + 4L):e]),
          col_names = hdr2,
          col_types = readr::cols(.default = "c"),
          show_col_types = FALSE
        )
        idx$lane <- lane
        list(lanetot = lanetot, idx = idx)
      })
      list(
        lanetot = purrr::map(blocks, "lanetot") |> purrr::list_rbind(),
        idx = purrr::map(blocks, "idx") |> purrr::list_rbind()
      )
    }
  )
)
