# tidydragen development plan

Derived from `nemo` (base R6) + `tidywigits` (reference child pkg). Covers 4
pipelines: DNA tumor-normal (somatic), DNA germline-only, RNA tumor-only, and
ctTSO500 (`cttso`); plus run-level BCLConvert and Illumina InterOp QC.

This is a design/status doc: the durable *why* behind the architecture. The
authoritative tool/table catalogue lives in `.claude/CLAUDE.md` --- do not
duplicate it here.

## Status

Build functionally complete: **8 tools** (`DragenMap`, `DragenFqc`, `DragenCov`,
`DragenVar`, `DragenRna`, `DragenTso`, `DragenBcl`, `Interop`). 239 roxytests
pass.

| Phase                    | Status                 | Notes                                                                                                                                                                          |
| ------------------------ | ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 0--5: core DRAGEN        | done                   | `DragenTool` base, shared `dragen-metrics` parser, coverage `refine_files`/`csv-nohead`, FastQC 8-table fan-out (→ own `DragenFqc`), JSON+VCF (`microsat`, native `ploidyvcf`) |
| 6 Tier 1+2: cttso        | done                   | region-enum fix, new M tables (`trimmer`/`umi`/`gc`/`gvcf`), flat JSON `contamination`, `DragenTso` (6 file tables + 6-way SAR fan-out)                                        |
| 6 Tier 3: `cnv.vcf` etc. | resolved, out of scope | see Scope decisions below                                                                                                                                                      |
| BCLConvert (`DragenBcl`) | done                   | see below                                                                                                                                                                      |
| InterOp (`Interop`)      | done                   | see below                                                                                                                                                                      |
| `replay.json` provenance | done                   | on `DragenMap`, see below                                                                                                                                                      |

## Scope decisions (locked)

| Item                                                                  | Decision                   | Why                                                                                                                                                         |
| --------------------------------------------------------------------- | -------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `cnv.vcf`, `hard-filtered.vcf.gz`                                     | out of tidydragen entirely | handled by a separate VCF pipeline elsewhere, not this repo                                                                                                 |
| `SmallVariants_Annotated.json.gz`, `TMB_Annotated.json.gz`            | dropped                    | variant data covered by that VCF pipeline; no dracarys port source anyway                                                                                   |
| `events.csv`, `MetricsOutput.tsv` (incl. cttso `*_MetricsOutput.tsv`) | permanently skipped        | dracarys: "terribly inconsistent for programmatic parsing"; reconstruct any needed metric from the metrics files + SAR JSON + CombinedVariantOutput instead |
| `imaging_plot.png` (InterOp)                                          | out of scope               | plot image, not data                                                                                                                                        |

## Architectural decisions (locked)

1. **Region + phenotype → `prefix`.** One schema table per file *format*; the
   coverage region (`wgs`/`tmb`/`exon`/`target_bed`/`qc-coverage-region-*`) and
   phenotype (`normal`/`tumor`) fold into `prefix` via `refine_files()` (same
   mechanism tidywigits' Linx uses for germline tagging).
2. **Metrics pct → paired columns.** Each metric emits `<metric>` and, when a
   percentage is present, `<metric>_pct`.
3. **Layout A″.** Domain tools carry the category in the table name
   (`dragenvar_vc`, `dragencov_finehist`, not a redundant prefix).
4. **All columns `versions: ['latest']`** for now --- add real versioned
   snapshots only when a second DRAGEN version appears.
5. **Tool `name` == config dir name.** `Config` resolves the schema via `name`;
   class PascalCase, `name`/dir lowercase.
6. **Tidy naming = hybrid, per-tool.** dracarys's raw→tidy maps are the
   authoritative metric inventory; names decided case-by-case (drop the
   redundant `var_` prefix, keep good descriptive ones like `reads_tot_input`).
7. **Region-in-metric-name → strip.** Coverage: region moves to `prefix`. VC:
   region moves to `prefix` AND is kept as a `region` column --- see Region
   reconciliation below.
8. **Unmapped metrics fail loud.** `on_unmapped` policy (default `"error"`) ---
   catches schema drift instead of silently dropping a metric.

## Shared DRAGEN metrics parser

Most `*_metrics.csv` share a headerless `section,rg,variable,count[,pct]` shape:

```
TUMOR MAPPING/ALIGNING SUMMARY,,Total input reads,2635326658,100.00
READ MEAN QUALITY,Read1,Q12 Reads,3          # fastqc: rg populated
```

Parse → long tibble; tidy → pivot wide keyed by `section`+`rg`, mapping names to
tidy columns via `Config$get_col_map()`, emitting paired `_pct` columns.

Implemented once on an intermediate base
`DragenTool <- R6Class(inherit = nemo::Tool)`
(`private$parse_metrics()`/`tidy_metrics()`, `refine_files()`, the `csv-nohead`
and `dragen-metrics` extra-ftypes). A plain metrics table needs **no method**
(`ftype: 'dragen-metrics'` routes it automatically); a table needing a
pivot/split declares one-liners:

```r
parse_mapmet = function(x) private$parse_metrics(x, "mapmet"),
tidy_mapmet  = function(x) private$tidy_metrics(x, "mapmet")
```

`normalise` hook: `tidy_metrics(x, table, normalise = fn)` rewrites `variable`
before the col_map lookup (used for the region-strip below).

> nemo previously shipped a `Tool1$parse_table5`/`tidy_table5` fixture doing
> this same pivot, plus the `csv-nohead-long` ftype --- both **removed from
> nemo**; the DRAGEN-specific conventions (empty `rg`, `,,` double-comma,
> TUMOR/NORMAL sections) belong here, not the base package.
> `Config$get_col_map()` stayed in nemo (general raw→tidy mapping); this parser
> uses it.

### Region reconciliation (coverage vs vc)

Region appears in the coverage filename AND the metric text (genome / target
region / QC coverage region); the filename is higher-resolution (`umccr` vs
`fcc` both read "QC coverage region"). So:

- **coverage_metrics** --- strip region from metric names; `prefix` carries it.
- **vc_metrics** --- region is only in the metric text, no filename signal →
  strip from names AND keep a `region` column.

## ftype taxonomy

| ftype            | Built-in?            | Handling                                                                                                        |
| ---------------- | -------------------- | --------------------------------------------------------------------------------------------------------------- |
| `dragen-metrics` | no, `extra_ftypes()` | shared `parse/tidy_metrics` on `DragenTool`; plain tables need no method                                        |
| `csv-nohead`     | no, `extra_ftypes()` | 3-col contig-mean-cov etc.; standard `tidy_file`                                                                |
| `csv` / `tsv`    | yes                  | plain header, positional rename, no type conversion --- custom `parse_` must emit typed columns in schema order |
| custom `parse_*` | ---                  | JSON, VCF, per-chromosome, multi-section, or 1→N fan-out                                                        |

Dropped as redundant with `coverage_metrics` (0 mismatches verified on real
files): `overallmean` (= `metricsmain$cov_alignment_avg`), `hist` (bins
value-identical to `metricsbins` + top `metricscumu` row). `fine_hist` IS kept
(separate table).

## BCLConvert (`DragenBcl`)

Run-scoped: files carry no sample id, so `refine_files()` blanks `prefix` →
`dragenbcl_<table>`; cross-run collisions disambiguate as `_2`/`_3`, traceable
to the source CSV via `metadata_dragenbcl.parquet` (`fin`→`fout`). **Required a
nemo tweak:** `Tool$run()` now appends the `_2`/`_3` disambiguator to the *end*
of a blank-prefix name (was a leading `_`).

`runinfo` (custom XML parse via `xml2`) is the authoritative run-scoping join
key: one row, canonical `run_id`, read lengths pivoted wide (data reads →
read1/read2, index reads → index1/index2), flow-cell geometry.

Index columns: 6 tables carry `index`/`index2` natively; the 2 Demultiplex
tables split a combined `Index` column (`Undetermined` → NA); `fastqlist` pivots
`Read1File`/`Read2File` long. Pcts are kept as raw 0--1 fractions (not ×100),
per the DRAGEN docs.

**MultiQC cross-check** (`../multiqc/.../bclconvert.py`, 2026-09-16): MultiQC is
an aggregator (report tables/barplots); on *parsing* we're a strict superset ---
it only touches `Demultiplex_Stats`, `Quality_Metrics`, `Top_Unknown_Barcodes`
and `RunInfo.xml`, every column it reads we capture.

| Finding                                                               | Action                                                                                                                             |
| --------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| Pre-v3.9.3 moved 2 cols from `Demultiplex_Stats` → `Quality_Metrics`  | `demultiplexstats` is locked to the v4.x 11-col shape; an old run errors --- add a schema version only if UMCCR has pre-3.9.3 data |
| Optional `Sample_Name`/`Sample_Project` cols (future BCL option)      | not yet in schema --- same future-version fix                                                                                      |
| MultiQC excludes+recomputes `Undetermined`; we keep raw rows          | no change --- correct for a warehouse, filter/aggregate downstream                                                                 |
| Derived metrics (depth, percent_*) all recomputable from emitted cols | not a parser gap                                                                                                                   |

## InterOp (`Interop`)

Two summary files per run (from the `interop` toolchain's `summary`/
`index-summary` apps over `InterOp/*.bin` --- tidydragen never decodes the
binaries) + `imaging_table.csv[.gz]`.

- Genuinely not a DRAGEN output → named plain `Interop`, inherits `Tool`
  directly (none of `DragenTool`'s metrics machinery applies). Registered in
  `DRAGEN_TOOLS`/orchestrated by the `Dragen` workflow purely for co-location
  convenience --- InterOp summaries typically sit next to BCLConvert/DRAGEN
  outputs in the same run dir.
- `summary.csv`/`index_summary.csv` carry the run id in the filename ---
  ordinary prefix extraction (unlike `DragenBcl`). `imaging_table.csv[.gz]` has
  no run id in the filename → run-scoped like `DragenBcl`, needs its own
  `refine_files()`.
- `imaging_table`: 49 real data columns but 36 header tokens --- grouped columns
  (e.g. `"P90<RED;GREEN>"`) print one label for N un-labelled data columns that
  follow positionally (verified against real data). Parser bypasses the header
  (`skip = 3`), reads 49 positional character columns.
- Many cells are `"mean +/- sd"` or `"a / b"` → split into paired columns;
  `"nan"`/`"-"` → NA (R's `as.numeric("nan")` gives `NaN` not `NA`, handled
  explicitly). Non-PhiX-spiked (index) reads have `nan` phasing/error columns ---
  expected, not a parse gap.
- `RunInfo.xml` turned out not needed --- the two summary files carry
  everything.
- Fixtures deliberately include two `imaging_table` copies (one gz, one plain)
  to exercise nemo's generic same-basename `_2` collision handling; tests match
  rows by content, not by which file gets the suffix (not a guaranteed ordering ---
  same rule as the `replay.json` collision below).

## `replay.json` provenance (`DragenMap`)

Every DRAGEN run writes `<prefix>-replay.json`; wasn't parsed before, so DRAGEN
version wasn't captured anywhere in the parquet output (nemo's `file_version`
attr doesn't survive parquet either). Shape: `command_line`,
`hash_table_build.*`, `dragen_config` (500+ name/value pairs), `system.*`
(`dragen_version`, `nodename`, `kernel_release`). Confirmed present in all 3
pipelines.

Fans into `replaymain` (wide, 1 row) + sentinel `replayconfig` (long
`name`/`value`, the full config dump). Missing keys (older DRAGEN) → NA, not an
error.

**cttso quirk:** two `-replay.json` + two `.time_metrics.csv` per sample
(`DragenCaller` stage vs `Tmb` stage) --- genuinely different files that share a
basename, not duplicates. `system`/`hash_table_build` are byte-identical (same
install); `command_line`/runtime metrics differ. No dedup override needed ---
nemo's generic same-basename disambiguator already assigns distinct prefixes
(`<S>`/`<S>_2`); tests match rows by content (`grepl("Tmb", command_line)`), not
by suffix (not a guaranteed ordering).

## ctTSO500 scope

Reference runs synced under `nogit/dragen-tso500-ctdna/`; full S3 listing +
per-file parse decisions in `nogit/aws-s3-ls-dragen-tso500-ctdna-*.{md,csv}`.
Pull the parse-relevant subset via `tidydragen::s3sync_cttso()`.

Authoritative prior art: dracarys [PR
#135](https://github.com/umccr/dracarys/pull/135) (`Wf_tso_ctdna_tumor_only_v2`,
`../dracarys/R/tsov2.R`/`tso.R`/`tso_sar.R`) --- the tidy-name port source.

Only `Results/<S>/` (TSO500 app-layer), `Logs_Intermediates/DragenCaller/<S>/`
(DRAGEN metrics+VCFs), and `Logs_Intermediates/SampleAnalysisResults/` (SAR
JSON) are worth pulling --- everything else surfaces in `Results/` or is junk.

**Dedup rule:** several parse-yes files exist byte-identical in both
`Results/<S>/` and a `Logs_Intermediates/*` subdir. nemo matches on basename
only, so a `DragenTso` `refine_files()` override keeps the `Results/` copy
(falls back to row 1 for single-copy basenames). The SAR JSON is
`Logs_Intermediates`-only, so its match is a dedup no-op.

`smallvariants` (CVO reported set) and `sarsnv` (SAR full-annotated superset,
n≈1287) are kept as separate granularities on purpose --- different scope, not
redundant.

## Testing

roxytest only --- `@examples`+`@testexamples`, `make roxydoc` regenerates
`tests/`. Fixtures under `inst/extdata/<tool>/`, DVC-tracked on Cloudflare R2
(public-read default remote for `dvc pull`; push needs
`AWS_PROFILE=umccr-cloudflare-r2`). Respect the 200 KB pre-commit large-file cap
(truncate histograms/beds/traces). The DRAGEN + TSO500 docs MCP servers
(`mcp__dragen__*`, `mcp__dragen-tso-500-*`) ground schema authoring against
official metric definitions --- prefer `searchDocumentation`/`getPage` over
`askQuestion`.

Fixtures rebuilt from real `nogit/` runs (+2 external `~/s3` files),
reproducible via `inst/scripts/build_fixtures.sh` (idempotent, seed 42; won't
clobber the hand-trimmed fastqc fixture). Real sample IDs scrubbed from
filenames AND contents → `sampleA`/`sampleB` (tumor→`sampleA`,
normal→`sampleA_tn`); `DragenBcl` is run-scoped so scrubbing doesn't apply
there.

| Edge case                                                                                                              | Fixture / mechanism                     |
| ---------------------------------------------------------------------------------------------------------------------- | --------------------------------------- |
| MNPs                                                                                                                   | `vcA` ← real accreditation germline run |
| cnv `SEX GENOTYPER` preamble                                                                                           | `sampleB.cnv` ← cttso source            |
| ploidy "median coverage" naming variant                                                                                | `sampleB.ploidy` ← edge-case run        |
| region+pheno coverage variants, per-chrom `hethom`, `"NaN"`→NA JSON, empty `sarcnv` (0-row), absent-key→NA (`sum_jsd`) | exercised across the existing fixtures  |

**Audit run (2026-09-20), local `nogit/` corpus:** `tool_audit.R`
(map/cov/var/rna, 29 runs) --- 0 errors, 0 warnings, zero
unmapped-metric/coerce-fail drift. `fastqc_audit.R` (8 files) --- 0 errors after
fixing a stale method-name call (`tidy_fastqc` → `tidy_posbasecontent`, left
behind when FastQC moved to its own tool); `cols_ok`/`int_ok`/`prop_ok` all
pass, 0 unknown sections, 0 silent-NA values. Caveat: this corpus is small
(8/32/35/4/8 files per tool) and every fastqc file has `max_span = 1` ---
DRAGEN's coarse-granularity open-ended bins (`256+`, `>=255`) are only exercised
by the unit-level fixture/tests, not by any real file audited here.

**`on_*` fail-loud paths --- done.** `DragenTool.R`'s `@testexamples` now
deliberately corrupts a copy of the `DragenRna` `quant` fixture (smallest real
schema) to trigger each policy end to end, in both `error` (default,
`expect_error`) and `warn` (`expect_warning` + checks the resulting table did
the right thing) mode: `on_unmapped` (append an unknown metric name),
`on_coerce_fail` (replace a numeric value with non-numeric text),
`on_unexpected_col` (a normally-constant `rg` made to vary).

## Implementation gotchas

- **Ragged rows → base `read.csv(fill=TRUE)`, not readr.** readr/vroom infers
  column count from the first line (often a 4-field SUMMARY row) and silently
  merges `pct` into `count`.
- **Value column read as character, coerced per schema after pivot** --- some
  metrics are strings (`Child Sample`), some counts exceed 2³¹.
- **`get_col_map()` returns readr type codes** (`c`/`i`/`d`); schema `type:`
  must be `char`/`int`/`float`, not `character` --- `Config` rejects it.
- Numeric counts typed `float` (avoid 32-bit overflow); `int` reserved for small
  bounded counts.
- Custom-parse tables go through `tidy_file`, which renames **by position**
  (`ncol` must equal schema rows) and does **no** type conversion --- a custom
  `parse_` must emit typed columns in schema order.
- **`make build` required after any `schema.yaml` change**, not just
  `load_all()` --- `Config` resolves `system.file('config/tools', ...)`, which
  only works for an installed package.
