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
#' dm <- nemo::read_parquet_grep(odir, lf, "dragenbcl_demultiplexstats.parquet")
#' fq <- nemo::read_parquet_grep(odir, lf, "dragenbcl_fastqlist.parquet")
#' ri <- nemo::read_parquet_grep(odir, lf, "dragenbcl_runinfo.parquet")
#' expect_setequal(unique(dm$lane), 1:4)
#' expect_setequal(unique(fq$read), 1:2)
#' expect_setequal(unique(fq$lane), 1:4)
#' expect_equal(nrow(ri), 1L)
#' expect_equal(ri$read1_cycles, 151L)
#' expect_equal(ri$input_id, "run1")
#' # adapter-trimming metrics (per sample/read)
#' am <- nemo::read_parquet_grep(odir, lf, "dragenbcl_adaptermetrics.parquet")
#' s1r1 <- am[am$sampleid == "s2600353" & am$read == 1, ]
#' expect_equal(s1r1$adapter_bases, 302203130)
#' expect_equal(s1r1$adapter_bases_pct, 0.005)
#' # per-cycle adapter-trimming metrics
#' ac <- nemo::read_parquet_grep(odir, lf, "dragenbcl_adaptercyclemetrics.parquet")
#' c0 <- ac[ac$sampleid == "s2600353" & ac$read == 1 & ac$cycle == 0, ]
#' expect_equal(c0$cluster_n, 248)
#' expect_equal(c0$cluster_pct, 0.000001)
#' # quality-score metrics (per sample/read), and the per-tile variant
#' qm <- nemo::read_parquet_grep(odir, lf, "dragenbcl_qualitymetrics.parquet")
#' q1 <- qm[qm$sampleid == "s2600353" & qm$read == 1, ]
#' expect_equal(q1$yield, 63339252977)
#' expect_equal(q1$q30_pct, 0.94)
#' qt <- nemo::read_parquet_grep(odir, lf, "dragenbcl_qualitytilemetrics.parquet")
#' qt1 <- qt[qt$sampleid == "s2600353" & qt$read == 1 & qt$tile == 1101, ]
#' expect_equal(qt1$yield, 66609114)
#' # per-tile demultiplexing stats: combined Index split into index/index2
#' dts <- nemo::read_parquet_grep(odir, lf, "dragenbcl_demultiplextilestats.parquet")
#' dt1 <- dts[dts$sampleid == "s2600353" & dts$tile == 1101, ]
#' expect_equal(dt1$index, "TACGTGAAGG")
#' expect_equal(dt1$index2, "CTAATAACCG")
#' expect_equal(dt1$reads_n, 465798)
#' expect_equal(dt1$perfect_idx_reads_n, 460268)
#' # index-hopping counts: unresolved (non-sample) index combos -> NA sampleid
#' ih <- nemo::read_parquet_grep(odir, lf, "dragenbcl_indexhoppingcounts.parquet")
#' ih1 <- ih[!is.na(ih$sampleid) & ih$sampleid == "s2600353", ]
#' expect_equal(ih1$reads_n, 442931839)
#' expect_equal(ih1$all_reads_pct, 0.131517)
#' expect_true(any(is.na(ih$sampleid)))
#' # most-common unlisted barcodes, sorted by descending count
#' tb <- nemo::read_parquet_grep(odir, lf, "dragenbcl_topunknownbarcodes.parquet")
#' expect_equal(tb$index[1], "GGGGGGGGGG")
#' expect_equal(tb$reads_n[1], 11599128)
#' expect_equal(tb$unknown_barcodes_pct[1], 0.117211)
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
