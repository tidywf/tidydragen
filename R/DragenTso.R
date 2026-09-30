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
#' sv <- nemo::read_parquet_grep(odir, lf, "sampleA_dragentso_smallvariants")
#' expect_equal(nrow(sv), 1287L)
#' expect_equal(sv$gene[sv$pos == 2488153], "TNFRSF14")
#' expect_true(is.na(sv$gene[sv$pos == 4367323]))
#' expect_equal(sv$vaf[sv$pos == 2488153], 0.4768)
#' expect_equal(sv$pos[1], 2488153L)
#' # fusions: v2 18-column shape, lowercase tidy names
#' fu <- nemo::read_parquet_grep(odir, lf, "sampleA_dragentso_fusions")
#' expect_equal(fu$gene1[1], "EML4")
#' expect_equal(fu$vaf[1], 0.00682348716107)
#' # tmbtrace: 27 v2 columns
#' tt <- nemo::read_parquet_grep(odir, lf, "sampleA_dragentso_tmbtrace")
#' expect_equal(tt$gene[1], "TNFRSF14")
#' expect_equal(tt$consequence[1], "missense_variant")
#' # tmbmsaf: leading max_somatic_af + variant columns
#' tm <- nemo::read_parquet_grep(odir, lf, "sampleA_dragentso_tmbmsaf")
#' expect_equal(tm$gene[1], "TP53")
#' # exoncov / genecov
#' ec <- nemo::read_parquet_grep(odir, lf, "sampleA_dragentso_exoncov")
#' expect_equal(ec$mean[1], 3004.16)
#' gc <- nemo::read_parquet_grep(odir, lf, "sampleA_dragentso_genecov")
#' expect_false("median" %in% names(gc))
#' expect_equal(gc$gene[1], "TNFRSF14")
#' # SAR fan-out: sarmain / sarqc / sarqcthr / sarsnv / sarcnv / sarswds / sarsw
#' si <- nemo::read_parquet_grep(odir, lf, "sampleA_dragentso_sarmain")
#' expect_equal(si$sample_id, "sampleA")
#' expect_equal(nrow(si), 1L)
#' qc <- nemo::read_parquet_grep(odir, lf, "sampleA_dragentso_sarqc\\.parquet")
#' expect_equal(nrow(qc), 1L)
#' expect_equal(qc$contamination_score, 50)
#' expect_equal(qc$tmb_per_mb, 2.4)
#' expect_equal(qc$msi_pct_unstable_sites, 0)
#' expect_equal(qc$pct_target_04x_mean, 94.7)
#' expect_equal(si$library_type, "DNA")
#' expect_true(si$analysis_completed)
#' expect_equal(si$schema_version, "7.0.0")
#' # sarqcthr: 6 QC metric rows (median_exon_coverage in two groups) with limits
#' th <- nemo::read_parquet_grep(odir, lf, "sampleA_dragentso_sarqcthr")
#' expect_equal(nrow(th), 6L)
#' gsm <- th[th$metric == "gene_scaled_mad", ]
#' expect_equal(c(gsm$lsl, gsm$usl), c(0, 0.059))
#' expect_true(is.na(th$usl[th$metric == "pct_exon_1000x"]))
#' expect_true(is.na(th$uom[th$metric == "contamination_score"]))
#' sn <- nemo::read_parquet_grep(odir, lf, "sampleA_dragentso_sarsnv")
#' expect_equal(nrow(sn), 10L)
#' expect_equal(sn$hgnc[sn$pos == 2488153], "TNFRSF14")
#' expect_equal(sn$consequence[sn$pos == 2488153], "missense_variant")
#' expect_true(all(c("biotype", "iscanonical", "proteinid", "introns", "isjunctionpreserving") %in% names(sn)))
#' expect_equal(sn$variant_type[sn$pos == 2488153], "SNV")
#' expect_equal(sn$hgvsg[sn$pos == 2488153], "NC_000001.10:g.2488153A>G")
#' # this sample reports no CNVs -> sarcnv is an empty (0-row) table with the schema cols
#' cn <- nemo::read_parquet_grep(odir, lf, "sampleA_dragentso_sarcnv")
#' expect_equal(nrow(cn), 0L)
#' expect_true(all(c("gene", "cn_type") %in% names(cn)))
#' ds <- nemo::read_parquet_grep(odir, lf, "sampleA_dragentso_sarswds")
#' expect_equal(nrow(ds), 7L)
#' expect_true("RefSeq" %in% ds$name)
#' sw <- nemo::read_parquet_grep(odir, lf, "sampleA_dragentso_sarsw\\.parquet")
#' expect_equal(nrow(sw), 1L)
#' expect_true(!is.na(sw$software_version))
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
        # bound the block at the next "[Section]" header (if any) so trailing
        # sections are never read as data rows; usually last, so falls to EOF.
        nxt <- grep("^\\[", ln)
        nxt <- nxt[nxt > hdr]
        eob <- if (length(nxt) > 0) min(nxt) - 1L else length(ln)
        d <- ln[(hdr + 1):eob] |>
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
    },
    #' @description Parse a `SampleAnalysisResults.json` file; returns its `data`
    #' block wrapped in a one-row tibble list-column. `tidy_sarmain()` fans it out.
    #' @param x (`character(1)`)\cr Path to file.
    parse_sarmain = function(x) {
      j <- jsonlite::fromJSON(x, simplifyVector = FALSE)
      d <- tibble::tibble(data = list(j[["data"]]))
      attr(d, "file_version") <- "latest"
      d[]
    },
    #' @description Fan a `SampleAnalysisResults.json` `data` block into seven
    #' tables: `sarmain` (sample + library info), `sarqc` (QC + expanded metrics +
    #' TMB/MSI biomarkers, wide), `sarqcthr` (QC metrics with LSL/USL thresholds,
    #' long), `sarswds` (Nirvana data sources), `sarsw` (software +
    #' Nirvana config), `sarsnv` (per-transcript small variants), `sarcnv` (CNVs).
    #' @param x (`character(1)` or `tibble()`)\cr Path to file or parsed tibble.
    tidy_sarmain = function(x) {
      if (!tibble::is_tibble(x)) {
        x <- self$parse_sarmain(x)
      }
      dat <- x$data[[1]]
      ## sampleInformation
      si <- dat[["sampleInformation"]]
      sarmain <- tibble::tibble(
        sample_id = si[["sampleId"]] %||% NA_character_,
        analysis_date = si[["analysisDate"]] %||% NA_character_,
        analysis_time = si[["analysisTime"]] %||% NA_character_,
        analysis_run_name = si[["analysisRunName"]] %||% NA_character_,
        analysis_name = si[["analysisName"]] %||% NA_character_,
        schema_version = dat[["schemaVersion"]] %||% NA_character_
      )
      ## sampleMetrics
      sm <- dat[["sampleMetrics"]]
      # sequencingLibraries: one DNA library for ctTSO500 -> keep the first
      sl <- sm[["sequencingLibraries"]][[1]]
      sarmain <- tibble::tibble(
        !!!sarmain,
        library_type = sl[["libraryType"]] %||% NA_character_,
        library_id = sl[["libraryId"]] %||% NA_character_,
        analysis_completed = sl[["analysisCompleted"]] %||% NA
      )
      ## qualityControlMetrics -> long table with the LSL/USL thresholds
      num <- function(v) as.numeric(v %||% NA)
      sarqcthr <- purrr::map(sm[["qualityControlMetrics"]], \(g) {
        purrr::map(g[["metrics"]], \(m) {
          uom <- m[["UOM"]] %||% NA_character_
          tibble::tibble(
            group = g[["name"]] %||% NA_character_,
            metric = sub("\\.", "", tolower(m[["name"]])),
            value = num(m[["value"]]),
            uom = if (identical(uom, "NA")) NA_character_ else uom,
            lsl = num(m[["LSL"]]),
            usl = num(m[["USL"]])
          )
        }) |>
          purrr::list_rbind()
      }) |>
        purrr::list_rbind()
      if (nrow(sarqcthr) == 0) {
        sarqcthr <- nemo::empty_tbl(cnames = c("group", "metric", "value", "uom", "lsl", "usl"))
      }
      ## qualityControlMetrics + expandedMetrics (long -> wide)
      # failed samples (analysisCompleted: false) omit `value` -> NA, not a dropped col
      m2row <- function(m) tibble::tibble(name = m[["name"]], value = m[["value"]] %||% NA)
      qc_rows <- purrr::map(sm[["qualityControlMetrics"]], \(g) {
        purrr::map(g[["metrics"]], m2row) |> purrr::list_rbind()
      }) |>
        purrr::list_rbind()
      em_rows <- purrr::map(sm[["expandedMetrics"]][[1]][["metrics"]], m2row) |>
        purrr::list_rbind()
      sarqc <- dplyr::bind_rows(qc_rows, em_rows) |>
        dplyr::mutate(
          name = sub("\\.", "", tolower(.data$name)),
          value = as.numeric(.data$value)
        ) |>
        dplyr::distinct() |>
        tidyr::pivot_wider(names_from = "name", values_from = "value")
      ## biomarkers -> folded into sarqc
      biom <- dat[["biomarkers"]]
      # always emit the five columns (NA when biomarkers is `{}`, e.g. failed samples)
      msi <- biom[["microsatelliteInstability"]]
      tmb <- biom[["tumorMutationalBurden"]]
      am_msi <- private$sar_amet(msi[["additionalMetrics"]])
      am_tmb <- private$sar_amet(tmb[["additionalMetrics"]])
      bl <- list(
        msi_pct_unstable_sites = msi[["msiPercentUnstableSites"]],
        msi_sum_jsd = am_msi[["SumJsd"]],
        tmb_per_mb = tmb[["tumorMutationalBurdenPerMegabase"]],
        tmb_coding_region_size_mb = am_tmb[["CodingRegionSizeMb"]],
        tmb_somatic_coding_variants_count = am_tmb[["SomaticCodingVariantsCount"]]
      )
      sarqc <- tibble::tibble(!!!sarqc, !!!lapply(bl, \(v) as.numeric(v %||% NA)))
      ## softwareConfiguration
      sc <- dat[["softwareConfiguration"]]
      nvl <- sc[["nirvanaVersionList"]]
      if (length(nvl) >= 1) {
        sarswds <- purrr::map(nvl[[1]][["dataSources"]], function(s) {
          tibble::tibble(
            name = s[["name"]] %||% NA_character_,
            version = s[["version"]] %||% NA_character_,
            description = s[["description"]] %||% NA_character_,
            release_date = s[["releaseDate"]] %||% NA_character_
          )
        }) |>
          purrr::list_rbind()
        nv <- nvl[[1]]
        nrest <- tibble::tibble(
          instance_name = nv[["instanceName"]] %||% NA_character_,
          nirvana_software_version = nv[["nirvanaSoftwareVersion"]] %||% NA_character_,
          genome_assembly = nv[["genomeAssembly"]] %||% NA_character_,
          refseq_version = nv[["refseqVersion"]] %||% NA_character_
        )
      } else {
        sarswds <- nemo::empty_tbl(cnames = c("name", "version", "description", "release_date"))
        nrest <- tibble::tibble(
          instance_name = NA_character_,
          nirvana_software_version = NA_character_,
          genome_assembly = NA_character_,
          refseq_version = NA_character_
        )
      }
      sarsw <- tibble::tibble(
        software_display_name = sc[["analysisSoftwareDisplayName"]] %||% NA_character_,
        software_name = sc[["analysisSoftwareName"]] %||% NA_character_,
        software_version = sc[["analysisSoftwareVersion"]] %||% NA_character_,
        genome_build = sc[["genomeBuild"]] %||% NA_character_,
        !!!nrest
      )
      ## variants
      sarsnv <- private$sar_snv(dat[["variants"]][["smallVariants"]])
      cnvs <- dat[["variants"]][["copyNumberVariants"]]
      cnv_ren <- c(
        chrom = "chromosome",
        cn_type = "copynumbertype",
        start = "startposition",
        end = "endposition"
      )
      if (length(cnvs) > 0) {
        sarcnv <- purrr::map(cnvs, tibble::as_tibble_row) |>
          purrr::list_rbind() |>
          dplyr::rename_with(tolower) |>
          dplyr::rename(dplyr::any_of(cnv_ren))
      } else {
        sarcnv <- nemo::empty_tbl(
          cnames = c("foldchange", "qual", "cn_type", "gene", "chrom", "start", "end")
        )
      }
      list(
        sarmain = sarmain,
        sarqc = sarqc,
        sarqcthr = sarqcthr,
        sarsnv = sarsnv,
        sarcnv = sarcnv,
        sarswds = sarswds,
        sarsw = sarsw
      ) |>
        purrr::map(function(t) {
          attr(t, "file_version") <- "latest"
          t
        }) |>
        nemo::nemo_enframe()
    }
  ),
  private = list(
    # name/value pairs from an additionalMetrics array -> named list
    sar_amet = function(am) {
      stats::setNames(
        lapply(am, function(m) m[["value"]]),
        vapply(am, function(m) m[["name"]], character(1))
      )
    },
    # small variants -> one row per (variant x transcript), lowercased columns
    sar_snv = function(snvs) {
      cols <- c(
        "chrom",
        "pos",
        "ref",
        "alt",
        "af",
        "qual",
        "dp_tot",
        "dp_alt",
        "variant_type",
        "hgvsg",
        "transcript",
        "source",
        "biotype",
        "codons",
        "aminoacids",
        "cdnapos",
        "cdspos",
        "exons",
        "proteinpos",
        "geneid",
        "hgnc",
        "hgvsc",
        "hgvsp",
        "iscanonical",
        "proteinid",
        "introns",
        "isjunctionpreserving",
        "consequence"
      )
      if (length(snvs) == 0) {
        return(nemo::empty_tbl(cnames = cols))
      }
      # Transcripts fanned out first: one row per (variant x transcript), a single
      # NA placeholder row for a variant with no transcripts.
      txs_list <- lapply(snvs, \(snv) {
        txs <- snv[["nirvana"]][[1]][["transcripts"]]
        if (length(txs) == 0) {
          return(list(list(transcript = NA_character_)))
        }
        lapply(txs, \(tx) {
          tx[["consequence"]] <- paste(unlist(tx[["consequence"]]), collapse = ",")
          tx
        })
      })
      txt <- dplyr::bind_rows(unlist(txs_list, recursive = FALSE))
      idx <- rep(seq_along(snvs), lengths(txs_list))
      main <- tibble::tibble(
        chrom = vapply(snvs, \(s) s[["vcfChromosome"]] %||% NA_character_, character(1)),
        pos = vapply(snvs, \(s) as.numeric(s[["vcfPosition"]] %||% NA), numeric(1)),
        ref = vapply(snvs, \(s) s[["vcfRefAllele"]] %||% NA_character_, character(1)),
        alt = vapply(snvs, \(s) s[["vcfAltAllele"]] %||% NA_character_, character(1)),
        af = vapply(snvs, \(s) as.numeric(s[["vcfVariantFrequency"]] %||% NA), numeric(1)),
        qual = vapply(snvs, \(s) as.numeric(s[["quality"]] %||% NA), numeric(1)),
        dp_tot = vapply(snvs, \(s) as.numeric(s[["totalDepth"]] %||% NA), numeric(1)),
        dp_alt = vapply(snvs, \(s) as.numeric(s[["altAlleleDepth"]] %||% NA), numeric(1)),
        variant_type = vapply(
          snvs,
          \(s) s[["nirvana"]][[1]][["variantType"]] %||% NA_character_,
          character(1)
        ),
        hgvsg = vapply(snvs, \(s) s[["nirvana"]][[1]][["hgvsg"]] %||% NA_character_, character(1))
      )[idx, , drop = FALSE]
      # main is pre-expanded by idx so the two are already row-aligned
      res <- tibble::tibble(!!!main, !!!txt) |>
        dplyr::rename_with(tolower)
      # transcript fields are sparse (e.g. introns) -> pad so the shape is stable
      res[setdiff(cols, names(res))] <- NA_character_
      res
    },
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
        dplyr::select(-c(".in_results", ".keep_row"))
    }
  )
)
