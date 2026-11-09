# NEWS

## dev

## v0.1.1 (2026-11-09)

- CLI: `sync` subcommand renamed to `s3sync`, with repeatable
  `--include` and `--exclude` globs (via nemo 0.2.1).
- CLI: `tidy`/`list` `--in_dir` renamed to `--input_dir` (via nemo
  0.2.1).
- [`s3sync()`](https://tidywf.github.io/tidydragen/reference/s3sync.md):
  no longer excludes `*_SampleAnalysisResults.json`, as
  `Logs_Intermediates/` holds the only copy.

## v0.1.0 (2026-10-24)

Initial release. `tidydragen` is a
[nemo](https://github.com/tidywf/nemo) child package that parses and
tidies Illumina DRAGEN outputs into tidy tables, written to parquet,
TSV, CSV, RDS, or PostgreSQL.

- Pipelines:
  - DNA tumor-normal (somatic)
  - DNA germline-only
  - RNA tumor-only
  - ctTSO500
  - BCLConvert demultiplexing reports
  - Illumina InterOp run QC summaries
- One tool per output group: `DragenMap`, `DragenFqc`, `DragenCov`,
  `DragenVar`, `DragenRna`, `DragenTso`, `DragenBcl`, `Interop`);
- `Dragen` workflow runs all tools over a directory and ingests any
  matching patterns it detects
- Run as an R package, CLI (`tidydragen.R`), conda package, or
  multi-arch Docker image. See
  [Installation](https://tidywf.github.io/tidydragen/articles/installation.md)
  and
  [Quickstart](https://tidywf.github.io/tidydragen/articles/quickstart.md).
