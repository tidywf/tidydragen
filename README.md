

<!-- README.md is generated from README.qmd. Please edit that file -->

<a href="https://tidywf.github.io/tidydragen"><img src="man/figures/logo.png" alt="logo" align="left" height="100" /></a>

# 🧬✨ Tidy Illumina DRAGEN Outputs

[![conda-latest1](https://anaconda.org/tidywf/r-tidydragen/badges/latest_release_date.svg "Conda Latest Release")](https://anaconda.org/tidywf/r-tidydragen)
[![gha](https://github.com/tidywf/tidydragen/actions/workflows/deploy.yaml/badge.svg "GitHub Actions")](https://github.com/tidywf/tidydragen/actions/workflows/deploy.yaml)

- 📚 Docs: <https://tidywf.github.io/tidydragen>:

## Overview

{tidydragen} is an R package that parses and tidies outputs from the
Illumina [DRAGEN](TODO "Illumina DRAGEN") platform.

In short, it traverses through a directory containing results from one
or more runs of DRAGEN workflows, parses any files it recognises, tidies
them up (which includes data reshaping, normalisation, column name
cleanup etc.), and writes them to the output format of choice
e.g. Apache Parquet, PostgreSQL, TSV, RDS.

## 🎨 Quick Start

The starting point of {tidydragen} is a directory with DRAGEN results.
Let’s look at some sample data (tracked via [DVC](https://dvc.org/))
under <https://github.com/tidywf/tidydragen/tree/main/inst/extdata/oa>:

<details class="code-fold">
<summary>Click here</summary>

``` r
system.file("extdata/oa", package = "tidywigits") |>
  fs::dir_tree(invert = TRUE, glob = "*.dvc")
```

</details>

We can parse, tidy up, and write the DRAGEN results into e.g. Parquet
format or a PostgreSQL database as follows:

- Parquet:

``` r
in_dir <- system.file("extdata/oa", package = "tidydragen")
out_dir <- tempdir() |> fs::dir_create("parquet_example")
w <- Dragen$new(in_dir)
res <- w$nemofy(diro = out_dir, format = "parquet", input_id = "parquet_example")
fs::dir_info(out_dir) |>
  dplyr::mutate(bname = basename(.data$path)) |>
  dplyr::select("bname", "size", "type")
```

- PostgreSQL:

``` r
in_dir <- system.file("extdata/oa", package = "tidydragen")
out_dir <- tempdir() |> fs::dir_create("parquet_example")
w <- Dragen$new(in_dir)
dbconn <- DBI::dbConnect(
  drv = RPostgres::Postgres(),
  dbname = "nemo",
  user = "orcabus"
)
res <- w$nemofy(
  format = "db",
  input_id = "db_example",
  dbconn = dbconn
)
```

## 🍕 Installation

Using {remotes} directly from GitHub:

``` r
install.packages("remotes")
remotes::install_github("tidywf/tidydragen") # latest main commit
remotes::install_github("tidywf/tidydragen@v0.0.0.9000") # latest tagged version
```

Alternatively:

- conda package: <https://anaconda.org/tidywf/r-tidydragen>
- Docker image:
  <https://github.com/tidywf/tidydragen/pkgs/container/tidydragen>

For more details see:
<https://tidywf.github.io/tidydragen/articles/installation>

## 🌀 CLI

A `tidydragen.R` command line interface is available for convenience.

- If you’re using the conda package, the `tidydragen.R` command will
  already be available inside the activated conda environment.
- If you’re *not* using the conda package, you need to export the
  `tidydragen/inst/cli/` directory to your `PATH` in order to use
  `tidydragen.R`.

``` bash
td_cli=$(Rscript -e 'x = system.file("cli", package = "tidydragen"); cat(x, "\n")' | xargs)
export PATH="${td_cli}:${PATH}"
```
