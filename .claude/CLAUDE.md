# CLAUDE.md --- tidydragen

nemo child R package that parses and tidies Illumina DRAGEN pipeline outputs.

The parent `tidywf/.claude/CLAUDE.md` has the ecosystem map + a routing table;
read `tidywf/docs/r-pkg/schema.md` (schema.yaml/ftype/Config) and
`tidywf/docs/r-pkg/tool-authoring.md` (Tool/Workflow patterns) there before deep
schema or tool work. This file covers the tidydragen-specific architecture and
conventions.

Several analysis pipelines are in scope: DNA tumor-normal (somatic), DNA
germline-only, RNA tumor-only, and ctTSO500 (`cttso`, the DRAGEN TSO500 ctDNA
app layer --- see `DragenTso`); plus the run-level **BCLConvert** demultiplexing
outputs (`Reports/` --- see `DragenBcl`) and **Illumina InterOp** run-QC
summaries (see `Interop` --- not a DRAGEN output, but housed here for
convenience).

## Architecture

`DragenTool` (`R/DragenTool.R`, R6, `inherit = Tool`) is an intermediate base
carrying the DRAGEN-shared logic. **All DRAGEN domain tools inherit
`DragenTool`**, not `nemo::Tool` directly. `Interop` (below) is the one
exception --- it isn't a DRAGEN output, so it inherits `Tool` directly instead.
Each tool has its own `inst/config/tools/<tool>/schema.yaml`.

| Tool        | Source                                                                                                                                                                                                      | Output tables                                                                                                                                                                                                    |
| ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `DragenMap` | `*.mapping_metrics.csv`, `*.time_metrics.csv`, `*.fragment_length_hist.csv`, `*.trimmer/umi/gc_metrics.csv` (cttso), `*-replay.json`                                                                        | `metrics`, `time`, `fraglenhist`, `trimmer`, `umimain`/`umihist`, `gcmain`/`gcbias`, `replaymain`/`replayconfig`                                                                                                 |
| `DragenFqc` | `*.fastqc_metrics.csv`                                                                                                                                                                                      | 8 flat per-section tables (`dragenfqc_posbasecontent` … `_seqpos`)                                                                                                                                               |
| `DragenCov` | coverage `*.csv`/`*.bed` (region {wgs/tmb/exon/target_bed/qc-coverage-region-*} + pheno variants)                                                                                                           | `metricsmain`/`metricsbins`/`metricscumu`, `contigmean`, `finehist`, `reportbedmain`/`reportbedcumu`, `readreportbed`                                                                                            |
| `DragenVar` | `*.vc/sv/cnv/ploidy/tmb/allele_transition_noise/vc_hethom_ratio/hrdscore/gvcf_metrics.csv`, `*.microsat_output.json`, `*.ploidy.vcf.gz`, `*.contamination.json`                                             | `vc`, `sv`, `cnv`, `ploidymain`/`ploidyratio`, `tmb`, `nuctrans`, `hethom`, `hrd`, `gvcf`, `microsat` (JSON), `ploidyvcf` (native VCF parse), `contamination` (JSON)                                             |
| `DragenRna` | `*.fusion_metrics.csv`, `*.quant_metrics.csv`                                                                                                                                                               | `fusion`, `quant`                                                                                                                                                                                                |
| `DragenTso` | cttso app-layer: `*_CombinedVariantOutput.tsv`, `*_Fusions.csv`, `*.tmb.trace/msaf`, `*.{exon,gene}_cov_report.tsv`, `*_SampleAnalysisResults.json`                                                         | `smallvariants`, `fusions`, `tmbtrace`, `tmbmsaf`, `exoncov`, `genecov`, + SAR fan-out (file `sar`) → `sarmain`, `sar{qc,qcthr,snv,cnv,swds,sw}`                                                                 |
| `DragenBcl` | BCLConvert `Reports/`: `Adapter[_Cycle]_Metrics.csv`, `Demultiplex[_Tile]_Stats.csv`, `Index_Hopping_Counts.csv`, `Quality[_Tile]_Metrics.csv`, `Top_Unknown_Barcodes.csv`, `fastq_list.csv`, `RunInfo.xml` | `adaptercyclemetrics`, `adaptermetrics`, `demultiplexstats`, `demultiplextilestats`, `indexhoppingcounts`, `qualitymetrics`, `qualitytilemetrics`, `topunknownbarcodes`, `fastqlist`, `runinfo` (XML via `xml2`) |
| `Interop`   | Illumina InterOp run-QC (NOT a DRAGEN output --- see below): `<run>_summary.csv`, `<run>-index_summary.csv`, `imaging_table.csv[.gz]`                                                                       | `summarymain`/`summaryreadlane`, `indexsummarymain`/`indexsummarydetail`, `imagingtable`                                                                                                                         |

Output name = `<prefix>_<tool>_<table>`, or `<prefix>_<tool>_<output>` for a
fan-out file (the `a/b` pairs above are a file's `outputs:`; its file table is
named after the file, see gotchas); `prefix` is the sample id (+ region/pheno
for coverage).

- **`DragenBcl` is run-scoped** --- no sample id in the basename, so
  `refine_files()` blanks `prefix` → outputs are `dragenbcl_<table>` (a run over
  several `Reports/` dirs disambiguates as `_2`/`_3`; run id lands in
  `input_id`, traceable via `metadata_dragenbcl`).
- **`Interop` is Illumina run-QC, not a DRAGEN tool** --- `InterOp/*.bin` is
  decoded upstream by the `interop` toolchain; tidydragen only parses its CSV
  output. Inherits `Tool` directly (its two fan-outs, `summary` and
  `indexsummary`, are plain `outputs:`). The summary files carry the run id in
  the filename; `imaging_table.csv[.gz]` doesn't, so `refine_files()` blanks its
  `prefix` (run-scoped, like `DragenBcl`) → `interop_imagingtable`. Registered
  in `DRAGEN_TOOLS` anyway since it's typically co-located with
  BCLConvert/DRAGEN outputs.

The `Dragen` `Workflow` (`R/Dragen.R`, exported `DRAGEN_TOOLS`) registers all 8
tools and tolerates absent files (each missing tool → 0 tables). Current status,
decisions, and phase log live in **`.claude/dev-plan.md`** --- read it first on
resume.

## The DRAGEN metrics parser (the core mechanic)

Most `*_metrics.csv` files share a headerless `section,rg,variable,count[,pct]`
shape. `DragenTool` registers a `dragen-metrics` ftype (via `extra_ftypes()`) →
`private$parse_metrics()` (base `read.csv(fill=TRUE)`, `count` kept
**character**) and `private$tidy_metrics()` (pivot wide keyed by `section`+`rg`,
one column per mapped metric plus a paired `<metric>_pct`, then coerce each
column to its schema `type`).

- Custom logic: declare `tidy_<table>()` delegating to
  `private$tidy_metrics(x, "<table>", normalise = ...)` (region strip, chrom
  split, etc.).
- Plain metrics table: **no method needed** --- `ftype: 'dragen-metrics'` in the
  schema routes it through automatically.
- **Fail-loud policies** (`DragenTool` public fields, default `"error"`):
  `on_unmapped` (file metric absent from schema), `on_coerce_fail` (non-empty
  value → `NA`), `on_unexpected_col` (`drop_constant` id column varies
  unexpectedly).

## Critical gotchas

- **1 file → N tables:** the file table declares its sub-tables under `outputs:`
  in `schema.yaml`; `tidy_<file table>()` returns them via
  `nemo::nemo_enframe()`, keyed by output name, written as `<tool>_<output>`.
  nemo checks every result against the declared outputs. Full rules (shared with
  tidywigits) in `docs/r-pkg/schema.md` → *Fan-out*; tidydragen-specific parts
  below.
- **File table names:** `umi`, `gc`, `replay` (dragenmap), `fastqc` (dragenfqc),
  `covmetrics`, `reportbed` (dragencov), `ploidy` (dragenvar), `sar`
  (dragentso), `summary`, `indexsummary` (interop). Output names are the old
  `<stem>main` + siblings (`umimain`, `metricsmain`, ...). Not `metrics` for
  dragencov: a public `tidy_metrics()` would clash with `DragenTool`'s private
  one.
- **`dragen-metrics` outputs use `shape: 'subset'`:** `tidy_metrics()` emits
  only the metrics present (file order) plus a `<metric>_pct` twin where the
  file has a pct, so the declared columns are a superset. Twins seen in the
  fixtures are declared; a new one errors (undeclared column), in keeping with
  `on_unmapped`. JSON pivots (`sarqc`, `sarsnv`, `sarcnv`) are `subset` too.
- **File tables without `columns:`:** `fastqc`, `reportbed`, `replay`, `sar`,
  `summary`, `indexsummary` are read by their own `parse_*()` (JSON,
  multi-section, configurable columns), so they omit `columns:`; only their
  outputs carry columns.
- **Output `raw:`** is kept only where `tidy_metrics(x, "<output>")` maps metric
  names through `get_col_map()` (`metricsbins`, `metricscumu`, `ploidyratio`);
  other outputs have tidy-only columns.
- **No `bool` type:** JSON true/false flags are coerced to character
  (`sarmain.analysis_completed`, `sarsnv` flags) to match their `char` type.
- **Region + phenotype (coverage):** folded into `prefix` by `refine_files()`
  (`wgs`/`tmb`/`exon`/`target_bed`/`qc-coverage-region-<label>` +
  `normal`/`tumor`). `vc` instead keeps region as a `region` column via
  `region_split()`.
- **`csv-nohead` ftype** registered on `DragenTool` (`trim_ws=TRUE`) for
  headerless coverage CSVs.
- **Run-scoped tools (`DragenBcl`):** no sample id in filenames, so
  `refine_files()` blanks `prefix` → `dragenbcl_<table>`; relies on a nemo
  `Tool$run()` accommodation appending the disambiguator with no leading `_`.
  `Interop` reuses it for `imagingtable`. Design notes: *BCLConvert* in
  `.claude/dev-plan.md`.
- **Same-basename, different-content files (cttso `replay`/`time`) need no
  dedup** --- nemo's generic collision handling already assigns distinct
  prefixes; match rows by content (e.g. `grepl("Tmb", command_line)`), not by
  which file got the `_2` suffix.
- **`ftype` is nominal once a `parse_<table>()` method exists** --- nemo calls
  it first and never consults `ftype`, so name it for the real format: `runinfo` =
  `xml`, `microsat`/`contamination`/`sar`/`replay` = `json`, `ploidyvcf` =
  `vcf`.
- **Ragged metrics rows → base `read.csv(fill=TRUE)`, NOT readr** --- readr
  infers column count from the first row and silently merges `pct` into `count`.
- Numeric counts typed **`float`** in schemas (avoid 32-bit overflow); `int` for
  small bounded counts only.

## Key files

- `R/DragenTool.R` --- base: `parse_metrics`/`tidy_metrics`/`coerce_by_type`/
  `region_split`/`refine_files`, `extra_ftypes` (`dragen-metrics`,
  `csv-nohead`), the `on_*` policy fields.
- `R/utils.R` --- `dragen_cov_metric_normalize()`, `dragen_cov_bin_split()`,
  `fastqc_bin_open()`/`fastqc_bin_expand()` (bin-range decoding), `pkg_name`.
- `R/s3.R` --- `s3sync()` (sync test data). One function for every pipeline
  (DNA/RNA/ctTSO/BCLConvert); the former `s3sync_bcl()`/`s3sync_cttso()` are
  gone. Delegates to `nemo::s3sync(workflow = "dragen")`, whose include/exclude
  patterns are **declared in the tool schemas** (a `glob` field per table,
  collected by `nemo::wf_sync_patterns()`; `nemo::schema_glob_check()` guards it
  against drifting from `pattern`). ctTSO writes its app-layer outputs twice, so
  `DRAGEN_SYNC_EXCLUDE` (in `R/Dragen.R`, wired via `Dragen$sync_exclude`) drops
  the `Logs_Intermediates/` copies and keeps the `Results/` ones.

## Deployment (CLI, conda, Docker)

Three run surfaces beyond `library(tidydragen)`. CI/CD (version bumping, conda
build, docker/pkgdown publish) is documented in the parent routing table's
`docs/infra/cicd.md`; tidydragen-specific facts:

- **CLI:** `inst/cli/tidydragen.R` --- thin `nemo::nemo_cli(wf = "dragen")`
  wrapper. `deploy/conda/recipe/build.sh` copies it onto conda `PATH` as
  `tidydragen.R`.
- **conda:** recipe in `deploy/conda/recipe/`; env yamls under
  `deploy/conda/env/yaml/` (`tidydragen`/`condabuild`/`bump`/`pkgdown`).
- **Docker:** 2-stage conda build (miniforge builder → slim base), multi-arch
  (amd64 + arm64). **`ENTRYPOINT` is `tidydragen.R`**, `CMD` is `--help`, so
  `docker run <img> tidy -d …` appends to the binary (use `--entrypoint` for a
  raw shell). Build needs `conda-linux-64.lock` + `conda-linux-aarch64.lock` at
  repo root --- not committed, fetched from release assets at build time.
- **`docker-compose.yaml`:** mounts `./in`(ro)+`./out`, runs `tidy` to parquet
  by default; `IMAGE_TAG`/`IN_DIR`/`OUT_DIR`/`FORMAT` overridable via
  env/`.env`.
- **Versioning:** `.bumpversion.toml` bumps DESCRIPTION, conda recipe+env yamls,
  and compose image tag together (`make bump VERSION=…`).

## Testing

See `tidywf/docs/r-pkg/testing.md` for the roxytest convention (`make roxydoc`
regenerates `tests/`) and fixture location (`inst/extdata/<tool>/`,
DVC-tracked). `nogit/` holds real DRAGEN sample dirs for manual smoke tests. The
DRAGEN docs MCP server (`mcp__dragen__*`) grounds schema authoring against
official metric definitions.

## Dev commands

Full Makefile target list (shared with nemo/tidywigits):
`tidywf/docs/r-pkg/dev-commands.md`.

Dev loop (`make install` after schema edits, reinstall `../nemo` after editing
it): *Dev loop* in that same doc. Run `make fmt` (also run by `make test`)
before committing, so the pre-commit air/panache hooks have nothing left to
reformat.

`devtools::load_all()` (no make equivalent) to load package interactively:

```r
devtools::load_all()

indir <- system.file("extdata/dragenmap", package = "tidydragen")
DragenMap$new(indir)$run(
  output_dir = tempdir(),
  format = "parquet",
  input_id = "run1"
)
Dragen$new(indir)$run(
  output_dir = tempdir(),
  format = "parquet",
  input_id = "run1"
)
```
