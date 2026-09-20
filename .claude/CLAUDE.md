# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/claude-code) when working
with code in this repository.

## Project Overview

`tidydragen` is a nemo 'child' R package that parses and tidies outputs from
Illumina DRAGEN pipelines, producing wide-format tidy tibbles suitable for
ingestion into data warehouses. It can write to parquet, TSV, CSV, RDS, or
database formats. Four analysis pipelines are in scope: DNA tumor-normal
(somatic), DNA germline-only, RNA tumor-only, and ctTSO500 (`cttso`, the DRAGEN
TSO500 ctDNA app layer --- see `DragenTso`); plus the run-level **BCLConvert**
demultiplexing outputs (`Reports/` --- see `DragenBcl`) and **Illumina InterOp**
run-QC summaries (see `Interop` --- not a DRAGEN output, but housed here for
convenience).

The parent `../.claude/CLAUDE.md` has the ecosystem map + a routing table; read
`docs/r-pkg/schema.md` (schema.yaml/ftype/Config) and
`docs/r-pkg/tool-authoring.md` (Tool/Workflow patterns) there before deep schema
or tool work. This file covers the tidydragen-specific architecture and
conventions.

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
| `DragenVar` | `*.vc/sv/cnv/ploidy/tmb/allele_transition_noise/vc_hethom_ratio/hrdscore/gvcf_metrics.csv`, `*.microsat_output.json`, `*.ploidy.vcf.gz`, `*.contamination.json`                                             | `vc`, `sv`, `cnv`, `ploidystats`/`ploidyratio`, `tmb`, `nuctrans`, `hethom`, `hrd`, `gvcf`, `microsat` (JSON), `ploidyvcf` (native VCF parse), `contamination` (JSON)                                            |
| `DragenRna` | `*.fusion_metrics.csv`, `*.quant_metrics.csv`                                                                                                                                                               | `fusion`, `quant`                                                                                                                                                                                                |
| `DragenTso` | cttso app-layer: `*_CombinedVariantOutput.tsv`, `*_Fusions.csv`, `*.tmb.trace/msaf`, `*.{exon,gene}_cov_report.tsv`, `*_SampleAnalysisResults.json`                                                         | `smallvariants`, `fusions`, `tmbtrace`, `tmbmsaf`, `exoncov`, `genecov`, + SAR fan-out `sar{info,qc,snv,cnv,swds,sw}`                                                                                            |
| `DragenBcl` | BCLConvert `Reports/`: `Adapter[_Cycle]_Metrics.csv`, `Demultiplex[_Tile]_Stats.csv`, `Index_Hopping_Counts.csv`, `Quality[_Tile]_Metrics.csv`, `Top_Unknown_Barcodes.csv`, `fastq_list.csv`, `RunInfo.xml` | `adaptercyclemetrics`, `adaptermetrics`, `demultiplexstats`, `demultiplextilestats`, `indexhoppingcounts`, `qualitymetrics`, `qualitytilemetrics`, `topunknownbarcodes`, `fastqlist`, `runinfo` (XML via `xml2`) |
| `Interop`   | Illumina InterOp run-QC summaries (NOT a DRAGEN output --- see below): `<run>_summary.csv`, `<run>-index_summary.csv`                                                                                       | `summary`/`summaryreadlane`, `indexsummary`/`indexsummarydetail`                                                                                                                                                 |

Output name = `<prefix>_<tool>_<table>`; `prefix` is the sample id (+
region/pheno for coverage). **`DragenBcl` is run-scoped** --- no sample id in
the basename, so its `refine_files()` blanks `prefix` → outputs are
`dragenbcl_<table>` (a run over several `Reports/` dirs disambiguates as
`_2`/`_3`, appended to the end by a nemo `Tool$run()` accommodation for blank
prefixes; run id lands in the `input_id` column, traceable via
`metadata_dragenbcl`). **`Interop` is Illumina run-level QC, not a DRAGEN tool** ---
the `interop` toolchain's `summary`/ `index-summary` apps decode the run's
`InterOp/*.bin` binaries upstream; tidydragen only parses their CSV output. It
inherits `Tool` directly (none of `DragenTool`'s shared logic applies) and its
run id lives in the filename already, so no `refine_files()` override is needed
either. It's registered in `DRAGEN_TOOLS`/orchestrated by the `Dragen` workflow
anyway, purely because InterOp summaries are typically co-located with
BCLConvert/DRAGEN outputs under the same run dir. The `Dragen` `Workflow`
(`R/Dragen.R`, exported `DRAGEN_TOOLS`) registers all 8 tools and tolerates
absent files (each missing tool → 0 tables). Current status, decisions, and
phase log live in **`.claude/dev-plan.md`** --- read it first on resume.

## The DRAGEN metrics parser (the core mechanic)

Most `*_metrics.csv` files share a headerless `section,rg,variable,count[,pct]`
shape. `DragenTool` registers a `dragen-metrics` ftype (via `extra_ftypes()`) →
`private$parse_metrics()` (base `read.csv(fill=TRUE)`, `count` kept
**character**) and `private$tidy_metrics()` (pivot wide keyed by `section`+`rg`,
one column per mapped metric plus a paired `<metric>_pct`, then coerce each
column to its schema `type`).

- A table needing custom logic declares `tidy_<table>()` delegating to
  `private$tidy_metrics(x, "<table>", normalise = ...)`. The `normalise` hook
  rewrites the long tibble before the col_map lookup (region strip, chrom split,
  etc.).
- A plain metrics table needs **no method** --- `ftype: 'dragen-metrics'` in its
  schema routes it through the shared parse/tidy automatically.
- **Fail-loud policies** (public fields on `DragenTool`, default `"error"`,
  overridable per `tidy_metrics()` call): `on_unmapped` (a file metric absent
  from the schema --- never silently dropped), `on_coerce_fail` (a non-empty
  value coercing to `NA`), `on_unexpected_col` (a `drop_constant` id column that
  unexpectedly varies).

## Conventions specific to this package

- **1 file → N tables:** fan out by building a named list of tibbles →
  `nemo::nemo_enframe()`; set `$name` per sub-table. All fan-out tools set
  `flat_tidy_names = TRUE` (nemo Tool field) → output is `<tool>_<name>` (parser
  token dropped), so each sub-table's `$name` IS its output table.
- **Schema table name == output table name** (minus the `<prefix>_<tool>_` stem)
  for every tool; the only schema-less output is nemo's `metadata_<tool>`
  provenance table. Achieve it on fan-out tools by naming sub-tables to their
  full output name and renaming the file-matching table to the **primary**
  sub-table (e.g. DragenVar `ploidystats`+`ploidyratio`, DragenCov
  `metricsmain`/`metricsbins`/`metricscumu` + `reportbedmain`/`reportbedcumu`,
  DragenFqc `posbasecontent`+7). **The `parse_`/`tidy_` method name is bound to
  the file-matching table name** by nemo dispatch (`glue("tidy_{table_name}")`),
  so renaming that table forces renaming its methods --- not a style choice; a
  mismatch silently falls back to `tidy_file` and breaks.
- **Sentinel tables:** a schema table with `pattern: "__no_file_match__<x>"` is
  never matched to a file; it exists only to supply a `col_map`/documentation
  for a fan-out sub-table. See `dragen-multitable-from-one-file` in memory.
- **Region + phenotype (coverage):** folded into `prefix` by `refine_files()` on
  `DragenTool` (`wgs`/`tmb`/`qc-coverage-region-<label>` + `normal`/`tumor`), so
  one schema table serves every variant. Variant-caller `vc` instead keeps
  region as a `region` column via `region_split()`.
- **`csv-nohead` ftype** is registered on `DragenTool` (`trim_ws=TRUE`) for
  headerless coverage CSVs.
- **Run-scoped tools (`DragenBcl`):** files carry no sample id, so
  `refine_files()` blanks `prefix` → `dragenbcl_<table>` outputs. Relies on a
  nemo `Tool$run()` accommodation that, for a blank/`_N` prefix, appends the
  collision disambiguator to the end (no leading `_`). Reusable for InterOp. See
  `dragenbcl-run-scoped-no-prefix` in memory.
- **Same-basename, genuinely-different files (cttso `replaymain`/`time`) → no
  dedup needed.** cttso runs one DRAGEN invocation per stage (`DragenCaller`,
  `Tmb`, ...), each writing its own `<S>-replay.json` and `<S>.time_metrics.csv` ---
  same basename, different content (not the byte-identical
  `Results/`-vs-`Logs_Intermediates/` case `DragenTso$refine_files` dedupes).
  nemo's generic same-basename collision handling (`Tool.R` `compute_files()`)
  already assigns them distinct prefixes (`<S>` / `<S>_2`) with no override;
  match rows by content (e.g. `grepl("Tmb", command_line)`), not by which
  physical file got the `_2` suffix --- that ordering isn't a guaranteed API.
- **`ftype` is nominal for a custom-parsed table.** When a `parse_<table>()`
  method exists, nemo dispatch calls it first and never consults `ftype` (and
  `Config` doesn't validate the value), so the schema `ftype` is documentation
  only --- name it for the real format: `runinfo` = `xml`,
  `microsat`/`contamination`/`sarinfo` = `json`, `ploidyvcf` = `vcf`.
- **Ragged metrics rows → base `read.csv(fill=TRUE)`, NOT readr** --- readr
  infers the column count from the first (4-field) row and silently merges `pct`
  into `count`.
- Numeric counts are typed **`float`** in schemas (avoid 32-bit overflow);
  reserve `int` for small bounded counts. `get_col_map()` returns readr type
  codes `c`/`i`/`d`.

## Key files

- `R/DragenTool.R` --- base: `parse_metrics`/`tidy_metrics`/`coerce_by_type`/
  `region_split`/`refine_files`, `extra_ftypes` (`dragen-metrics`,
  `csv-nohead`), the `on_*` policy fields.
- `R/utils.R` --- `dragen_cov_metric_normalize()`, `dragen_cov_bin_split()`,
  `fastqc_bin_open()` (strip open-bin markers `+`/`>=`), `fastqc_bin_expand()`
  (range token → full integer sequence; `separate_longer_delim("-")` gives only
  the endpoints --- wrong for coarse-granularity bins), `pkg_name`.
- `R/s3.R` --- `s3sync()` (sync test data).

## Build loop

`edit → make roxydoc → make build → make test`. **`make build` is required after
any `schema.yaml` change** (not just `devtools::load_all()`): `nemo::Config`
calls `system.file('config/tools', package = 'tidydragen')`, which only resolves
for an installed package. Makefile also has `check`, `pkgdown`, `bump`, `full`.

Some changes depend on `nemo` itself; if you edit `../nemo`, rebuild it
(`cd ../nemo && make build`) before rebuilding tidydragen, since it is installed
(not `load_all`ed).

## Deployment (CLI, conda, Docker)

The package has three run surfaces beyond `library(tidydragen)`. The CI/CD
pipeline (version bumping, conda build, docker/pkgdown publish) is documented in
the parent routing table's `docs/infra/cicd.md`; the tidydragen-specific facts:

- **CLI:** `inst/cli/tidydragen.R` is a thin `nemo::nemo_cli(wf = "dragen")`
  wrapper exposing the `tidy`/`list` subcommands. `deploy/conda/recipe/build.sh`
  copies it into the conda env `bin` (`chmod +x`), so it lands on `PATH` as
  `tidydragen.R` after a conda install.
- **conda:** recipe in `deploy/conda/recipe/`; per-job env yamls under
  `deploy/conda/env/yaml/` (`tidydragen`/`condabuild`/`bump`/`pkgdown`).
- **Docker:** `Dockerfile` is a 2-stage conda build (miniforge builder → slim
  base), multi-arch (amd64 + arm64). **`ENTRYPOINT` is `tidydragen.R`**, `CMD`
  is `--help`, so `docker run <img> tidy -d …` appends to the binary (do NOT
  repeat the executable in args; use `--entrypoint` for a raw shell). Build
  needs the conda lockfiles `conda-linux-64.lock` + `conda-linux-aarch64.lock`
  in the repo root --- **not committed**, fetched from the release assets at
  build time (see the `Dockerfile` COPY comment). `.dockerignore` allowlists
  only those two files into the build context.
- **`docker-compose.yaml`:** convenience wrapper --- mounts `./in` (ro) +
  `./out`, runs `tidy` to parquet by default;
  `IMAGE_TAG`/`IN_DIR`/`OUT_DIR`/`FORMAT` are overridable via env or a `.env`
  file.
- **Versioning:** `.bumpversion.toml` bumps DESCRIPTION, the conda recipe + env
  yamls, and the pinned compose image tag together (`make bump VERSION=…`).

## Testing

Tests are generated automatically by
[roxytest](https://github.com/mikldk/roxytest) from `@testexamples` blocks in
roxygen documentation. **Don't write test files manually** --- add `@examples`
(a runnable example, typically `obj$run(format="parquet")`) and `@testexamples`
(assertions on the output) to the roxygen block, then run `make roxydoc` to
regenerate `tests/`. Fixtures live in `inst/extdata/<tool>/` (currently
untracked by design); `nogit/` holds real DRAGEN sample dirs for manual smoke
tests. The DRAGEN docs MCP server (`mcp__dragen__*`) grounds schema authoring
against official metric definitions.
