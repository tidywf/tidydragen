# NEWS

## v0.0.0.9000 (dev)

Initial development release. `tidydragen` is a
[nemo](https://github.com/tidywf/nemo) child package that parses and
tidies outputs from Illumina DRAGEN pipelines into wide-format tidy
tibbles ready for a data warehouse, writing to parquet, TSV, CSV, RDS,
or a database. Pipelines supported so far: DNA tumor-normal (somatic),
DNA germline-only, RNA tumor-only, BCLConvert, ctTSO500 (the DRAGEN
TSO500 ctDNA app layer), and Illumina InterOp run QC.

### Tools

The following Tools, each with its own
`inst/config/tools/<tool>/schema.yaml` and orchestrated by the `Dragen`
workflow class (exported `DRAGEN_TOOLS`), which tolerates absent files
so each pipeline can expose a different subset. All the DRAGEN tools
inherit an intermediate `DragenTool` base (itself
`inherit = nemo::Tool`); `Interop` isn’t a DRAGEN output, so it inherits
[`nemo::Tool`](https://tidywf.github.io/nemo/reference/Tool.html)
directly and is included purely because InterOp summaries are typically
co-located with BCLConvert/DRAGEN outputs under the same run dir.

| Tool | Outputs |
|----|----|
| `DragenMap` | Mapping/time metrics, fragment-length histogram, cttso trimmer / UMI / GC-bias metrics, and run provenance (`replay.json`: DRAGEN version, hash-table build version, config dump). |
| `DragenFqc` | The 8 flat per-section FastQC tables. |
| `DragenCov` | Coverage metrics/bins/cumulative, contig mean, fine histogram, and cov-report-bed tables across every region (`wgs`/`tmb`/`exon`/`target_bed`/`qc-coverage-region-*`) and phenotype. |
| `DragenVar` | Variant/SV/CNV/ploidy/TMB/HRD/gVCF metrics plus microsatellite (JSON), native ploidy-VCF parse, and contamination (JSON). |
| `DragenRna` | Fusion and quant metrics. |
| `DragenTso` | The ctTSO app-layer. |
| `DragenBcl` | The BCLConvert `Reports/` demultiplexing outputs. |
| `Interop` | Illumina InterOp run-QC summaries and per-tile imaging metrics (not a DRAGEN output). |

### The DRAGEN metrics parser

Most `*_metrics.csv` files share a headerless
`section,rg,variable,count[,pct]` shape. `DragenTool` registers a
`dragen-metrics` ftype: a plain metrics table is parsed and pivoted wide
(one column per mapped metric plus a paired `<metric>_pct`) with no
per-table code; only tables needing a custom split or a region/chrom
`normalise` hook declare explicit `tidy_<table>()` one-liners. Fail-loud
policies (`on_unmapped`, `on_coerce_fail`, `on_unexpected_col`) catch
schema drift instead of silently dropping data.

### ctTSO app-layer support

- [pr3](https://github.com/tidywf/tidydragen/pull/3)

`DragenTso` parses the TSO500 ctDNA outputs beyond the shared DRAGEN
metrics: CombinedVariantOutput small variants, Fusions, TMB trace/msaf,
exon/gene coverage, and a 6-way fan-out of the
`SampleAnalysisResults.json`.

### BCLConvert support

`DragenBcl` parses a BCLConvert `Reports/` directory into 10 tables —
nine per-lane / per-index CSVs plus `runinfo` from `RunInfo.xml`:

| Output table           | Source file                  |
|------------------------|------------------------------|
| `adaptercyclemetrics`  | `Adapter_Cycle_Metrics.csv`  |
| `adaptermetrics`       | `Adapter_Metrics.csv`        |
| `demultiplexstats`     | `Demultiplex_Stats.csv`      |
| `demultiplextilestats` | `Demultiplex_Tile_Stats.csv` |
| `indexhoppingcounts`   | `Index_Hopping_Counts.csv`   |
| `qualitymetrics`       | `Quality_Metrics.csv`        |
| `qualitytilemetrics`   | `Quality_Tile_Metrics.csv`   |
| `topunknownbarcodes`   | `Top_Unknown_Barcodes.csv`   |
| `fastqlist`            | `fastq_list.csv`             |
| `runinfo`              | `RunInfo.xml`                |

`runinfo` is one-row run metadata (canonical run id, flow cell,
instrument, and read lengths) parsed with `xml2`. The combined `Index`
column is split into `index`/`index2` throughout, and the FASTQ list’s
`Read1File`/`Read2File` are pivoted long into `read`/`filepath`.

Unlike the sample-scoped tools these outputs are **run-scoped** with no
sample id in the file name, so outputs are named `dragenbcl_<table>` (no
prefix); a run spanning several `Reports/` directories disambiguates
collisions as `dragenbcl_<table>_2`, each traceable to its source file
via the metadata table.

### InterOp support

`Interop` parses three groups of Illumina InterOp run-QC outputs
(tidydragen never decodes the underlying `InterOp/*.bin` binaries
itself). The two summary CSVs the `interop` toolchain’s
`summary`/`index-summary` apps emit: `<run>_summary.csv` fans into
`summarymain` (overall metrics by read) and `summaryreadlane`
(per-read/lane/surface detail), and `<run>-index_summary.csv` fans into
`indexsummarymain` (per-lane totals) and `indexsummarydetail` (per-index
demux rows) — many source cells here are `"mean +/- sd"` or `"a / b"`
pairs, split into paired tidy columns. And `imaging_table.csv` /
`imaging_table.csv.gz` (per-lane/tile/cycle imaging metrics, gzipped or
not, both accepted): its header is unreliable for grouped columns (e.g.
`"Corrected<A;C;G;T>"` prints one label but is followed by 4 data
columns), so it’s parsed positionally into a single flat `imagingtable`
table instead of trusting the header.

Unlike the DRAGEN tools, `Interop` isn’t a DRAGEN output, so it inherits
[`nemo::Tool`](https://tidywf.github.io/nemo/reference/Tool.html)
directly rather than the shared `DragenTool` base; it’s included in the
`Dragen` workflow anyway since InterOp summaries are typically
co-located with BCLConvert/DRAGEN outputs under the same run directory.
`imaging_table` carries no run id in its filename at all (unlike the two
summary CSVs), so — like `DragenBcl` — its output is named plain
`interop_imagingtable` rather than prefixed with a run id.

### Test data

- [pr8](https://github.com/tidywf/tidydragen/pull/8)

Test fixtures rebuilt from real DRAGEN pipeline outputs (trimmed per
file), with real sample IDs scrubbed to `sampleA`/`sampleB`, and tracked
with [DVC](https://dvc.org) on a Cloudflare R2 remote. The default
remote is public-read, so a fresh clone or CI run fetches fixtures with
`dvc pull` and no credentials. The `@testexamples` assertions were
updated to the real-data values; the roxytest suite passes.

### Infrastructure

- CLI, conda recipe, and multi-arch (amd64 + arm64) Docker image
  ([pr6](https://github.com/tidywf/tidydragen/pull/6)).
- GitHub Actions for version bumping and deploy, refactored to the
  reusable `tidywf/actions` workflows and tag-triggered
  ([pr4](https://github.com/tidywf/tidydragen/pull/4),
  [pr5](https://github.com/tidywf/tidydragen/pull/5)).
- Vignettes: installation, quickstart, structure, schema table, output
  naming, PostgreSQL, CI/CD, and UML.
