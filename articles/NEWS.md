# NEWS

## v0.0.0.9002 (current dev)

Initial development release. `tidydragen` is a
[nemo](https://github.com/tidywf/nemo) child package that parses and
tidies Illumina DRAGEN outputs into tidy tables, written to parquet,
TSV, CSV, RDS, or PostgreSQL.

- Pipelines: DNA tumor-normal, DNA germline, RNA tumor-only, ctTSO500,
  BCLConvert demultiplexing, and Illumina InterOp run QC.
- Tools: `DragenMap`, `DragenFqc`, `DragenCov`, `DragenVar`,
  `DragenRna`, `DragenTso`, `DragenBcl`, `Interop`, orchestrated by the
  `Dragen` workflow.
- [`s3sync()`](https://tidywf.github.io/tidydragen/reference/s3sync.md)
  for pulling DRAGEN run outputs from S3.
- CLI (`tidydragen.R`), conda package, and multi-arch Docker image.
