#' @title DragenBcl Object
#'
#' @description
#' Parses and tidies DRAGEN BCLConvert demultiplexing outputs from a `Reports/`
#' directory. Most tables are plain header CSVs handled by the nemo `csv` ftype.
#'
#' @examples
#' cls <- DragenBcl; tool <- "dragenbcl"
#' indir <- system.file("extdata", tool, package = "tidydragen")
#' odir <- tempdir()
#' obj <- cls$new(indir)
#' obj$run(output_dir = odir, format = "parquet", input_id = "run1", output_id = "out1")
#' (lf <- list.files(odir, pattern = "dragenbcl_.*parquet", full.names = FALSE))
#' @testexamples
#' dm <- arrow::read_parquet(file.path(odir, "dragenbcl_demultiplexstats.parquet"))
#' fq <- arrow::read_parquet(file.path(odir, "dragenbcl_fastqlist.parquet"))
#' ri <- arrow::read_parquet(file.path(odir, "dragenbcl_runinfo.parquet"))
#' expect_setequal(unique(dm$lane), 1:4)
#' expect_setequal(unique(fq$read), 1:2)
#' expect_setequal(unique(fq$lane), 1:4)
#' expect_equal(nrow(ri), 1L)
#' expect_equal(ri$read1_cycles, 151L)
#' expect_equal(ri$input_id, "run1")
#' @export
DragenBcl <- R6::R6Class(
  "DragenBcl",
  cloneable = FALSE,
  inherit = DragenTool,
  public = list(
    #' @description Create a new DragenBcl object.
    #' @param path (`character(1)`)\cr
    #' Path to a BCLConvert `Reports/` directory. If `files_tbl` is supplied, this
    #' is ignored.
    #' @param files_tbl (`tibble(n)`)\cr
    #' Tibble of files from [nemo::list_files_dir()].
    initialize = function(path = NULL, files_tbl = NULL) {
      super$initialize(name = "dragenbcl", pkg = pkg_name, path = path, files_tbl = files_tbl)
    },

    #' @description Parse Demultiplex_Stats.csv (splits combined `Index`).
    #' @param x (`character(1)`)\cr Path to Demultiplex_Stats.csv.
    parse_demultiplexstats = function(x) {
      private$parse_demux(x, tile = FALSE)
    },

    #' @description Parse Demultiplex_Tile_Stats.csv (splits combined `Index`).
    #' @param x (`character(1)`)\cr Path to Demultiplex_Tile_Stats.csv.
    parse_demultiplextilestats = function(x) {
      private$parse_demux(x, tile = TRUE)
    },

    #' @description Parse fastq_list.csv (pivots Read1File/Read2File long).
    #' @param x (`character(1)`)\cr Path to fastq_list.csv.
    parse_fastqlist = function(x) {
      # RGID, RGSM, RGLB, Lane, Read1File, Read2File
      d <- readr::read_csv(x, col_types = "cccicc")
      d <- d |>
        tidyr::pivot_longer(
          c("Read1File", "Read2File"),
          names_to = "read",
          values_to = "filepath"
        ) |>
        dplyr::mutate(read = as.integer(sub("^Read(\\d)File$", "\\1", .data$read)))
      attr(d, "file_version") <- "latest"
      d[]
    },

    #' @description Parse RunInfo.xml into a one-row run-metadata table.
    #' @param x (`character(1)`)\cr Path to RunInfo.xml.
    parse_runinfo = function(x) {
      doc <- xml2::read_xml(x)
      run <- xml2::xml_find_first(doc, ".//Run")
      reads <- xml2::xml_find_all(doc, ".//Reads/Read")
      ncyc <- as.integer(xml2::xml_attr(reads, "NumCycles"))
      idx <- xml2::xml_attr(reads, "IsIndexedRead")
      # data reads (IsIndexedRead=N) -> read1/read2; index reads (=Y) -> index1/index2.
      # Out-of-range subscripts return NA (single-end / single-index).
      data_cyc <- ncyc[idx == "N"]
      index_cyc <- ncyc[idx == "Y"]
      fl <- xml2::xml_find_first(doc, ".//FlowcellLayout")
      ts <- xml2::xml_find_first(doc, ".//TileSet")
      txt <- function(xpath) {
        node <- xml2::xml_find_first(doc, xpath)
        if (inherits(node, "xml_missing")) NA_character_ else xml2::xml_text(node)
      }
      fl_int <- function(attr) {
        if (inherits(fl, "xml_missing")) NA_integer_ else as.integer(xml2::xml_attr(fl, attr))
      }
      d <- tibble::tibble(
        run_id = xml2::xml_attr(run, "Id"),
        run_number = as.integer(xml2::xml_attr(run, "Number")),
        flowcell = txt(".//Flowcell"),
        instrument = txt(".//Instrument"),
        date = txt(".//Date"),
        read1_cycles = data_cyc[1],
        read2_cycles = data_cyc[2],
        index1_cycles = index_cyc[1],
        index2_cycles = index_cyc[2],
        lane_count = fl_int("LaneCount"),
        surface_count = fl_int("SurfaceCount"),
        swath_count = fl_int("SwathCount"),
        tile_count = fl_int("TileCount"),
        flowcell_side = fl_int("FlowcellSide"),
        tile_naming_convention = if (inherits(ts, "xml_missing")) {
          NA_character_
        } else {
          xml2::xml_attr(ts, "TileNamingConvention")
        }
      )
      attr(d, "file_version") <- "latest"
      d[]
    }
  ),
  private = list(
    # Run-scoped: no sample id in the basename, so blank the prefix. nemo then
    # names outputs `dragenbcl_<table>` (with `_2`/`_3` disambiguation when a run
    # spans several Reports/ dirs). Overrides DragenTool's coverage refine_files;
    # BCLConvert files never match the coverage regex anyway.
    refine_files = function(files) {
      if (nrow(files) > 0) {
        files[["prefix"]] <- ""
      }
      files
    },
    # Shared reader for Demultiplex_Stats.csv / Demultiplex_Tile_Stats.csv:
    # splits Index (i7-i5) into index/index2
    parse_demux = function(x, tile) {
      # Lane, SampleID, Index[, Tile], then 8 count/pct metrics.
      ct <- if (tile) "iccidddddddd" else "iccdddddddd"
      d <- readr::read_csv(x, col_types = ct)
      parts <- strsplit(d[["Index"]], "-", fixed = TRUE)
      d[["index"]] <- vapply(
        parts,
        \(p) if (length(p) >= 1 && nzchar(p[[1]])) p[[1]] else NA_character_,
        character(1)
      )
      d[["index2"]] <- vapply(
        parts,
        \(p) if (length(p) >= 2) p[[2]] else NA_character_,
        character(1)
      )
      d <- d |>
        dplyr::select(-"Index") |>
        dplyr::relocate("index", "index2", .after = "SampleID")
      attr(d, "file_version") <- "latest"
      d[]
    }
  )
)
