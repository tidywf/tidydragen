<!-- README.md is generated from README.qmd. Please edit that file -->

<a href="https://tidywf.github.io/tidydragen"><img src="man/figures/logo.png" alt="logo" align="left" height="100" /></a>

# Tidy Illumina DRAGEN Outputs

[![conda-latest1](https://anaconda.org/tidywf/r-tidydragen/badges/latest_release_date.svg "Conda latest release date")](https://anaconda.org/tidywf/r-tidydragen)
[![gha](https://github.com/tidywf/tidydragen/actions/workflows/deploy.yaml/badge.svg "GitHub Actions Status")](https://github.com/tidywf/tidydragen/actions/workflows/deploy.yaml)
[![ghcr-latest](https://ghcr-badge.egpl.dev/tidywf/tidydragen/latest_tag?color=%2344cc11&ignore=latest&label=image-latest&trim=.png "Docker latest release")](https://github.com/tidywf/tidydragen/pkgs/container/tidydragen)

## Contents

- [tidydragen](#tidydragen)
- [Documentation](#documentation)
- [Quick Start](#quickstart)
  - [Single tool](#single-tool)
  - [Full DRAGEN run](#full-dragen-run)
- [Installation](#installation)
- [CLI](#cli)

## tidydragen

tidydragen is an R package for parsing and tidying output from Illumina's
[DRAGEN](https://www.illumina.com/products/by-type/informatics-products/dragen-secondary-analysis.html "Illumina DRAGEN")
secondary-analysis pipelines. The following pipelines are supported: DNA
tumor-normal (somatic), DNA germline-only, RNA tumor-only, and TSO500 ctDNA.

A DRAGEN run produces dozens of files per sample across mapping, coverage,
variant calling, RNA quantification, and (for the ctTSO500 app) combined-variant
and coverage reports. Consuming them downstream is fragile: most metrics land in
headerless `section,rg,variable,count[,pct]` CSVs, some files fan out into
several logical tables, region/phenotype variants share basenames, and column
layouts drift between DRAGEN versions.

tidydragen addresses this with a schema-driven parsing layer built on the
[nemo](https://github.com/tidywf/nemo "nemo") base R6 classes, supplying
DRAGEN-specific schemas and parsers that turn raw outputs into consistently
structured, versioned, analysis-ready tables. These can be written to Apache
Parquet, PostgreSQL, TSV, CSV, or RDS. Each run also produces a
`metadata.parquet` file alongside the tidy tables, capturing IDs, paths, and R
package versions.

## Documentation

- Installation: <https://tidywf.github.io/tidydragen/articles/installation>
- Quickstart: <https://tidywf.github.io/tidydragen/articles/quickstart>
- Files supported: <https://tidywf.github.io/tidydragen/articles/schema_table>
- Output naming: <https://tidywf.github.io/tidydragen/articles/output_naming>
- Structure: <https://tidywf.github.io/tidydragen/articles/structure>
- Changelog: <https://tidywf.github.io/tidydragen/articles/NEWS>
- R6: <https://tidywf.github.io/nemo/articles/structure>

## Quickstart

### Single tool

Each DRAGEN tool has its own R6 class. Most DRAGEN metrics files share a
headerless `section,rg,variable,count[,pct]` layout e.g.:

```r
indir_map <- system.file("extdata/dragenmap", package = "tidydragen")
writeLines(head(
  readLines(
    file.path(indir_map, "sampleA.mapping_metrics.csv")
  ),
  5
))
#> TUMOR MAPPING/ALIGNING SUMMARY,,Total input reads,2635326658,100.00
#> TUMOR MAPPING/ALIGNING SUMMARY,,Number of duplicate marked reads,524058237,19.89
#> TUMOR MAPPING/ALIGNING SUMMARY,,Mapped reads,2573192500,97.64
#> TUMOR MAPPING/ALIGNING SUMMARY,,Number of duplicate marked and mate reads removed,NA
#> NORMAL MAPPING/ALIGNING SUMMARY,,Total input reads,938927988,100.00
```

We can use the `DragenMap` class to parse, tidy, and write these files in one
call via its `run()` method:

```r
outdir_map <- file.path(tempdir(), "map_out")
DragenMap$new(indir_map)$run(
  output_dir = outdir_map,
  format = "parquet",
  input_id = "run1"
)
list.files(outdir_map, pattern = "\\.parquet$")
#> [1] "metadata_dragenmap.parquet"            "sampleA_dragenmap_fraglenhist.parquet"
#> [3] "sampleA_dragenmap_gcbias.parquet"      "sampleA_dragenmap_gcmain.parquet"
#> [5] "sampleA_dragenmap_metrics.parquet"     "sampleA_dragenmap_time.parquet"
#> [7] "sampleA_dragenmap_trimmer.parquet"     "sampleA_dragenmap_umihist.parquet"
#> [9] "sampleA_dragenmap_umimain.parquet"
```

Now read back one tidied table:

```r
file.path(outdir_map, "sampleA_dragenmap_metrics.parquet") |>
  arrow::read_parquet() |>
  str()
#> tibble [2 × 10] (S3: tbl_df/tbl/data.frame)
#>  $ input_id                              : chr [1:2] "run1" "run1"
#>  $ section                               : chr [1:2] "TUMOR" "NORMAL"
#>  $ rg                                    : chr [1:2] "Total" "Total"
#>  $ reads_tot_input                       : num [1:2] 2.64e+09 9.39e+08
#>  $ reads_tot_input_pct                   : num [1:2] 100 100
#>  $ reads_num_dupmarked                   : num [1:2] 5.24e+08 NA
#>  $ reads_num_dupmarked_pct               : num [1:2] 19.9 NA
#>  $ reads_mapped                          : num [1:2] 2.57e+09 9.19e+08
#>  $ reads_mapped_pct                      : num [1:2] 97.6 97.9
#>  $ reads_num_dupmarked_mate_reads_removed: num [1:2] NA NA
```

### Full DRAGEN run

A whole DRAGEN results directory can be processed with the `Dragen` workflow
class. Tools whose files are absent contribute nothing, so the same call works
across the germline, somatic tumor-normal, and RNA pipelines:

<details class="code-fold">
<summary>View input files</summary>

``` r
indir_d <- system.file("extdata", package = "tidydragen")
dir_tree(indir_d)
/Users/pdiakumis/Library/R/arm64/4.6/library/tidydragen/extdata
├── dragencov
│   ├── sampleA.exon_coverage_metrics.csv
│   ├── sampleA.qc-coverage-region-umccr_cov_report.bed
│   ├── sampleA.qc-coverage-region-umccr_read_cov_report.bed
│   ├── sampleA.target_bed_coverage_metrics.csv
│   ├── sampleA.wgs_contig_mean_cov.csv
│   ├── sampleA.wgs_contig_mean_cov_normal.csv
│   ├── sampleA.wgs_contig_mean_cov_tumor.csv
│   ├── sampleA.wgs_coverage_metrics.csv
│   └── sampleA.wgs_fine_hist.csv
├── dragenfqc
│   └── sampleA.fastqc_metrics.csv
├── dragenmap
│   ├── sampleA.fragment_length_hist.csv
│   ├── sampleA.gc_metrics.csv
│   ├── sampleA.mapping_metrics.csv
│   ├── sampleA.time_metrics.csv
│   ├── sampleA.trimmer_metrics.csv
│   └── sampleA.umi_metrics.csv
├── dragenrna
│   ├── sampleA.fusion_metrics.csv
│   └── sampleA.quant_metrics.csv
├── dragentso
│   ├── sampleA.exon_cov_report.tsv
│   ├── sampleA.gene_cov_report.tsv
│   ├── sampleA.tmb.msaf.csv
│   ├── sampleA.tmb.trace.tsv
│   ├── sampleA_CombinedVariantOutput.tsv
│   ├── sampleA_Fusions.csv
│   └── sampleA_SampleAnalysisResults.json
└── dragenvar
    ├── sampleA.allele_transition_noise_metrics.csv
    ├── sampleA.cnv_metrics.csv
    ├── sampleA.contamination.json
    ├── sampleA.gvcf_metrics.csv
    ├── sampleA.hrdscore.csv
    ├── sampleA.microsat_output.json
    ├── sampleA.ploidy.vcf.gz
    ├── sampleA.ploidy_estimation_metrics.csv
    ├── sampleA.sv_metrics.csv
    ├── sampleA.tmb.metrics.csv
    ├── sampleA.vc_hethom_ratio_metrics.csv
    ├── sampleA.vc_metrics.csv
    ├── sampleB.ploidy_estimation_metrics.csv
    └── sampleB.vc_metrics.csv
```

</details>

We can parse, tidy, and write the results into e.g. Parquet format as follows:

```r
outdir_d <- file.path(tempdir(), "dragen_out_parquet")
d <- Dragen$new(indir_d)
res <- d$run(
  output_dir = outdir_d,
  format = "parquet",
  input_id = "run1",
  output_id = "out1",
  prefix_include = TRUE
)
res # shows summary of Dragen object
#> #--- Workflow Dragen ---#
#>
#> |var           |value                                                           |
#> |:-------------|:---------------------------------------------------------------|
#> |name          |Dragen                                                          |
#> |path          |/Users/pdiakumis/Library/R/arm64/4.6/library/tidydragen/extdata |
#> |ntools        |6                                                               |
#> |files_total   |39                                                              |
#> |files_matched |39                                                              |
#> |tidied        |true                                                            |
#> |written       |true                                                            |
list.files(outdir_d, pattern = "\\.parquet$") |> sort() |> str()
#>  chr [1:63] "metadata.parquet" "sampleA_dragenfqc_posbasecontent.parquet" ...
```

Results can also be written to a PostgreSQL database with `format = "db"` and a
DBI connection (see the [PostgreSQL
article](https://tidywf.github.io/tidydragen/articles/postgresql)).

Three optional columns can be prepended to every written table to support
downstream tracing and joining. All are opt-in and off by default, but highly
recommended for any multi-sample or multi-run pipeline:

| Column         | Purpose                                  | User-supplied or auto-generated? |
| -------------- | ---------------------------------------- | -------------------------------- |
| `input_id`     | identifies the sample or input run       | user                             |
| `output_id`    | identifies the tidydragen processing run | user or auto (ULID)              |
| `input_prefix` | filename prefix (e.g. sample name)       | auto                             |

## Installation

Using {remotes} directly from GitHub:

```r
install.packages("remotes")
remotes::install_github("tidywf/tidydragen") # latest main commit
remotes::install_github("tidywf/tidydragen@v0.0.0.9000") # specific version
```

Alternatively:

- conda package: <https://anaconda.org/tidywf/r-tidydragen>
- Docker image: <https://github.com/tidywf/tidydragen/pkgs/container/tidydragen>

For more details see:
<https://tidywf.github.io/tidydragen/articles/installation>

## CLI

A `tidydragen.R` command line interface is available for convenience.

- If you're using the conda package, the `tidydragen.R` command will already be
  available inside the activated conda environment.
- If you're *not* using the conda package, you need to export the
  `tidydragen/inst/cli/` directory to your `PATH` in order to use
  `tidydragen.R`.

```bash
td_cli=$(Rscript -e 'x = system.file("cli", package = "tidydragen"); cat(x, "\n")' | xargs)
export PATH="${td_cli}:${PATH}"
```

```
$ tidydragen.R --version
tidydragen 0.0.0.9000

#-----------------------------------#
$ tidydragen.R --help
usage: tidydragen.R [-h] [-v] {tidy,list} ...

✨ DRAGEN Output Tidying ✨

positional arguments:
  {tidy,list}    sub-command help
    tidy         Tidy Workflow Outputs
    list         List Parsable Workflow Outputs

options:
  -h, --help     show this help message and exit
  -v, --version  show program's version number and exit
'
#-----------------------------------#
#------- Tidy ----------------------#
$ tidydragen.R tidy --help
usage: tidydragen.R tidy [-h] -d IN_DIR [-o OUTPUT_DIR] [-f FORMAT]
                         [--input_id INPUT_ID]
                         [--output_id OUTPUT_ID | --ulid] [--dbname DBNAME]
                         [--dbuser DBUSER] [--include INCLUDE]
                         [--exclude EXCLUDE] [--prefix_include] [-q]

options:
  -h, --help            show this help message and exit
  -d IN_DIR, --in_dir IN_DIR
                        Input directory.
  -o OUTPUT_DIR, --output_dir OUTPUT_DIR
                        Output directory.
  -f FORMAT, --format FORMAT
                        Format of output [def: parquet] (parquet, db, tsv,
                        csv, rds)
  --input_id INPUT_ID   Input ID for this run.
  --output_id OUTPUT_ID
                        Output ID for this run.
  --ulid                Generate a ULID as output ID.
  --dbname DBNAME       Database name.
  --dbuser DBUSER       Database user.
  --include INCLUDE     Include only these files (comma sep tool_parsers).
  --exclude EXCLUDE     Exclude only these files (comma sep tool_parsers).
  --prefix_include      Include input prefix column in output tables.
  -q, --quiet           Shush all the logs.

#-----------------------------------#
#------- List ----------------------#
$ tidydragen.R list --help
usage: tidydragen.R list [-h] -d IN_DIR [-f FORMAT] [-m MAX] [-q]

options:
  -h, --help            show this help message and exit
  -d IN_DIR, --in_dir IN_DIR
                        Input directory.
  -f FORMAT, --format FORMAT
                        Format of list output [def: pretty] (tsv, pretty)
  -m MAX, --max MAX     Max rows to show.
  -q, --quiet           Shush all the logs.
```
