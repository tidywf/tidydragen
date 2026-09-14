# tidydragen development plan

Derived from `nemo` (base R6) + `tidywigits` (reference child pkg). Covers 4
pipelines: DNA tumor-normal (somatic), DNA germline-only, RNA tumor-only, and
ctTSO500 (`cttso`, the DRAGEN TSO500 ctDNA app layer).

This is a design/status doc: the durable *why* behind the architecture. The
authoritative current *catalogue* (tools, source files, output tables) is the
architecture table in `.claude/CLAUDE.md` --- do not duplicate it here.

## Status

Build functionally complete: **6 tools** (`DragenMap`, `DragenFqc`, `DragenCov`,
`DragenVar`, `DragenRna`, `DragenTso`), every plain-metrics / plain-table DRAGEN
and cttso output parsed. 213 roxytests pass (as of the Phase 6 completion).

Condensed phase log (detail lives in git history):

- **Phases 0--5 --- core DRAGEN (done).** Scaffold + `DragenTool` base; the
  shared `dragen-metrics` parser + all M tables; coverage (`refine_files`,
  `csv-nohead`, the 1→N metrics/reportbed splits); misc (`fraglenhist`, `hrd`,
  `hethom`); the FastQC 8-table fan-out (later promoted to its own `DragenFqc`
  tool); JSON + VCF (`microsat`, native `ploidyvcf`).
- **Phase 6 --- cttso (Tier 1+2 done).** Region-enum fix (`exon`/`target_bed`);
  new DRAGEN-metrics tables (`trimmer`, `umi`, `gc`, `gvcf` splits); custom flat
  JSON (`contamination`); the new `DragenTso` tool (6 file-based app-layer
  tables
  - the 6-way SAR JSON fan-out).
- **Phase 6 Tier 3 --- deferred (parked by user 2026-09-10).** `cnv.vcf`,
  `hard-filtered.vcf.gz`, `SmallVariants_Annotated.json.gz`,
  `TMB_Annotated.json.gz`. The 2 VCFs need native VCF parsing (bcftools was
  rejected in Phase 5) or the bcftools dep; the 2 annotation JSONs have no
  dracarys port source. `events.csv` and `MetricsOutput.tsv` are permanently
  skipped (provenance / inconsistent, not warehouse metrics).

## Decisions (locked)

1. **Region + phenotype → `prefix` via `refine_files()`.** One schema table per
   file *format*; the coverage-region (`wgs` / `tmb` / `exon` / `target_bed` /
   `qc-coverage-region-{umccr,fcc}`) and phenotype (`normal` / `tumor`) are
   folded into the `prefix` column, so outputs land as e.g.
   `L2600516_wgs_tumor_dragencov_metrics.parquet`. Uses nemo's existing
   `refine_files` hook (same mechanism Linx uses for germline tagging).
2. **JSON + VCF are in scope (done).** `microsat_output.json`, `ploidy.vcf.gz`
   (native parse, no bcftools), `contamination.json`, and the SAR JSON are all
   parsed. Only Tier 3 (annotated JSONs + cnv/hard-filtered VCFs) stays
   deferred.
3. **Metrics pct → paired columns.** Each metric emits `<metric>` and, when a
   percentage is present, `<metric>_pct`.
4. **Layout = A″, category in the group name.** Domain tools carry the category
   so table names drop the redundant prefix (`dragenvar_vc`,
   `dragencov_finehist`, ...), trimmed case-by-case. Started as 4 metrics tools;
   FastQC was later split into its own `DragenFqc` tool and `DragenTso` was
   added for the cttso app-layer --- 6 tools total. All inherit the intermediate
   `DragenTool` base.
5. **All columns `versions: ['latest']`** for now --- add real versioned
   snapshots only when a second DRAGEN version appears.
6. **Tool `name` string == config dir name.** `Config` locates the schema via
   `name`, so `DragenCov$new()` calls `super$initialize(name = "dragencov", …)`,
   matching `inst/config/tools/dragencov/`. Class name PascalCase, `name`/dir
   lowercase.
7. **Tidy naming = hybrid, per-tool.** Reuse dracarys's `raw`→`tidy` maps as the
   authoritative metric inventory, but tidy names decided case-by-case: drop the
   `var_` prefix where redundant (`var_snp`→`snps`), keep the good descriptive
   ones (`reads_tot_input`, `cov_alignment_avg`).
8. **Region-in-metric-name → strip; region lives in the prefix (cov) or a
   `region` column (vc).** See "Region reconciliation" below.
9. **Warn on unmapped metrics.** Port dracarys's `dirty_names_cleaned` idea as a
   warning (not silent drop) in `tidy_metrics`, to catch schema drift. (Now the
   `on_unmapped` fail-loud policy, default `"error"`.)

## Key component --- the shared DRAGEN metrics parser

The DRAGEN `*_metrics.csv` format is `section,rg,variable,count,pct`:

```
TUMOR MAPPING/ALIGNING SUMMARY,,Total input reads,2635326658,100.00
   ^section                    ^rg=""  ^variable      ^count     ^pct
READ MEAN QUALITY,Read1,Q12 Reads,3          # fastqc: rg populated
```

Parse → long tibble; tidy → pivot wide keyed by `section` + `rg`, mapping metric
names to tidy columns via `Config$get_col_map()`, emitting paired `_pct`
columns.

> **nemo context (as of the csv-nohead-long removal).** nemo previously shipped
> a `Tool1$parse_table5`/`tidy_table5` fixture doing exactly this pivot. That
> fixture and the `csv-nohead-long` ftype were **removed from nemo** --- the
> DRAGEN-specific conventions (empty `rg`, `,,` double-comma, TUMOR/NORMAL
> sections, pct-optional rows) belong here, not in the base package.
> `Config$get_col_map()` was **kept** in nemo (general raw→tidy mapping) ---
> this parser uses it. The deleted fixture's git history is the reference for
> the pivot logic.

→ **The parser lives entirely in tidydragen.** Implemented once on an
**intermediate R6 base** `DragenTool <- R6Class(inherit = nemo::Tool)` holding
`private$parse_metrics(x, tbl)` / `private$tidy_metrics(x, tbl)`; every metrics
tool inherits `DragenTool` instead of `nemo::Tool` directly. `refine_files()`
and the `csv-nohead` extra-ftype registration also live on `DragenTool`,
inherited everywhere.

**Dispatch:** metrics tables needing a custom tidy declare explicit one-liners
delegating to the inherited helpers --- the tidywigits per-table idiom:

```r
parse_mapmet = function(x) private$parse_metrics(x, "mapmet"),
tidy_mapmet  = function(x) private$tidy_metrics(x, "mapmet")
```

A plain metrics table needs **no method** --- `ftype: 'dragen-metrics'` in its
schema routes it through the shared parse/tidy automatically. The `csv-nohead`
coverage tables likewise need no custom tidy --- a plain schema rename
dispatched through `extra_ftypes()` + the standard inherited `tidy_file`.

Section (TUMOR/NORMAL, readgroup) is retained as a row key, so multi-section
files (mapping, vc) produce one row per section --- no phenotype-suffix needed
on those files.

## dracarys review --- reusable assets + edge cases

`../dracarys/R/dragen.R` is the older per-file parser implementation. It is the
authoritative source for the **metric-name→tidy-name maps** (mapping \~95, vc
\~34, cnv \~23, sv 4, coverage \~15 + coverage-bin logic, plus
trimmer/tmb/ploidy/gc/ umi/roh/msi). Ported into the schemas.

Edge cases it handles that the generic pivot does not:

- **Region embedded in metric names** (coverage, vc) --- see reconciliation
  below.
- **`hethom` is per-chromosome, not metrics-format** --- rows are
  `VARIANT CALLER PREFILTER,sample,chr1 Heterozygous,value`; splits `chrN` off
  the metric and pivots by chrom (custom parse).
- **cnv** --- optional `SEX GENOTYPER` preamble line (targeted/cttso) split into
  its own cols; `CNV SUMMARY` header on row 2; `as_numeric_na` coercion.
- **sv** --- drops the `Total number of structural variants` line; count-only.
- **coverage** --- `PCT of genome with coverage [100x:inf)` bin rows (range
  split) --- bespoke.
- **mapping** --- `TUMOR/NORMAL/SINGLE` phenotype split out of the category;
  `RG=""` → `"Total"`.
- **`too_few = "align_start"`** on `separate_wider_delim` is dracarys's
  readr-native way to handle ragged 4/5-field rows --- equivalent to our base
  `read.csv(fill=)`.

### Region reconciliation (decision 8)

Region appears in the coverage filename AND in the metric text (3-way: genome /
target region / QC coverage region). The filename is higher-resolution (`umccr`
vs `fcc` both read "QC coverage region"). So:

- **coverage_metrics** --- strip the region text from metric names (uniform
  columns like `cov_alignment_avg`); the **prefix** (via `refine_files`) carries
  region.
- **vc_metrics** --- region is only in the metric text and genuinely varies (WGS
  → genome, cttso → "target region"), with no region in the filename → **strip
  it from names AND stash it as a `region` column**.

### Mechanics: `normalize` hook

`parse_metrics` stays generic. `tidy_metrics(x, table, normalize = NULL)` takes
an optional `normalize` fn applied to the `variable` column before the col_map
lookup. `DragenCov`/vc pass a region-stripper (vc's also records the detected
region); every other table passes `NULL`.

## File-format taxonomy → ftype

| Format                         | Example                        | ftype              | Handling                                    |
| ------------------------------ | ------------------------------ | ------------------ | ------------------------------------------- |
| DRAGEN metrics                 | `mapping_metrics.csv`          | `dragen-metrics` † | shared `parse/tidy_metrics` on `DragenTool` |
| contig mean cov (3-col nohead) | `wgs_contig_mean_cov.csv`      | `csv-nohead` *     | `chrom,bases,coverage` per contig           |
| coverage hist (2-col nohead)   | `wgs_hist.csv`                 | `csv-nohead` *     | dropped as redundant (see below)            |
| fine hist (2-col, header)      | `wgs_fine_hist.csv`            | `csv`              | `Depth,Overall`                             |
| cov report bed (tsv, header)   | `*_cov_report.bed`             | `tsv`/custom       | region coverage stats                       |
| fragment length hist           | `fragment_length_hist.csv`     | custom parse       | skip `#Sample:` comment                     |
| hrd score (csv, header, 1 row) | `hrdscore.csv`                 | `csv`              | `Sample,LOH_Score,...`                      |
| microsat                       | `microsat_output.json`         | custom             | JSON (done)                                 |
| ploidy vcf                     | `ploidy.vcf.gz`                | custom             | native VCF parse (done)                     |
| contamination                  | `contamination.json`           | custom             | flat JSON (done)                            |
| SAR                            | `*_SampleAnalysisResults.json` | custom             | 1→6 fan-out (done)                          |

\* `csv-nohead` is not a built-in nemo ftype. Registered once via
`private$extra_ftypes()` (mirrors the `equal-keyvalue` / `dsv` extras in
tidywigits).

† `dragen-metrics` is a real ftype (registered via `extra_ftypes()`): a plain
metrics table dispatches through it with no R method; only tables needing a
custom pivot declare explicit `parse_<tbl>`/`tidy_<tbl>` one-liners. (`nemo`'s
former `csv-nohead-long` ftype and its `Tool1` metrics fixture were removed;
tidydragen owns this format.)

> **Dropped as redundant with `coverage_metrics` (verified 0 mismatches on real
> files):** `overallmean` (= `metricsmain$cov_alignment_avg`) and `hist` (its
> bins are value-identical to `metricsbins` + the top `metricscumu` row). Not
> added for cttso either. `fine_hist` IS kept (separate table).

## Tool grouping + ftype classification

6 domain Tools, each its own dir + `schema.yaml`, all inheriting the
intermediate `DragenTool` base (carries `parse_metrics`/`tidy_metrics`,
`refine_files`, the `csv-nohead` + `dragen-metrics` extra-ftypes, and the `on_*`
fail-loud policies). Registered in one `Dragen` `Workflow` (`R/Dragen.R`,
exported `DRAGEN_TOOLS`), which tolerates absent files (each pipeline exposes a
different subset) as zero-row tibbles. Output name = `<prefix>_<tool>_<table>`.

ftype classes used in the schemas:

- **M** = `dragen-metrics` (shared parse; custom `tidy_` only when a pivot/split
  or `normalize` hook is needed).
- **N** = `csv-nohead` (extra-ftype + standard `tidy_file`).
- **csv** / **tsv** = builtin, plain-header delimited (positional rename via
  `tidy_file`, no type conversion --- the custom `parse_` must emit typed
  columns in schema order).
- **C** = custom `parse_` (JSON, VCF, per-chromosome, multi-section, or 1→N
  fan-out).

The current per-tool table catalogue (source files + output tables) is the
architecture table in `CLAUDE.md`. Design notes on the non-trivial (C / split)
tables:

- **1→N splits** (ploidy pattern): coverage
  `metrics`→`metricsmain`/`metricsbins`/ `metricscumu` and
  `reportbed`→`reportbedmain`/`reportbedcumu`; DragenMap
  `umi`→`umimain`/`umihist`, `gc`→`gcmain`/`gcbias`; DragenFqc 8 sub-tables; the
  SAR JSON→6 tables. Each builds a named list of tibbles →
  `nemo::nemo_enframe()`, `$name` per sub-table, `flat_tidy_names = TRUE`.
- **Sentinel tables** (`pattern: "__no_file_match__<x>"`) supply a col_map /
  documentation for a fan-out sub-table that has no file of its own.
- **Custom parse specifics:** `hethom` (per-chromosome pivot); `finehist` (strip
  terminal `2000+`→2000, depth int); `fraglenhist` (skip `#Sample:`); `microsat`
  / `contamination` (flat JSON, drop per-SNP arrays, `"NaN"`→NA); `ploidyvcf`
  (native per-contig VCF summary); DragenTso `smallvariants` (CVO
  `[Small Variants]` section only), `fusions` (`comment="#"`), SAR fan-out.

### `refine_files()` for dragencov

Each coverage table uses ONE regex matching all region/phenotype variants, e.g.:

```
pattern: "\\.(?:wgs|tmb|exon|target_bed|qc-coverage-region-(?:umccr|fcc))_coverage_metrics(?:_normal|_tumor)?\\.csv$"
```

`refine_files(files)` re-parses `bname` to extract `region` + `phenotype`,
appends `_<region>_<pheno>` to `prefix` (drop `_none` when no suffix). nemo
strips the matched pattern to leave the sample id, then this hook disambiguates
the collisions before the `_2/_3` fallback fires. Lives on `DragenTool`; a no-op
on non-coverage files (regex never matches).

## ctTSO scope + file classification

A cttso run (`dragen-tso500-ctdna/<run>`) emits many outputs beyond the DRAGEN
metrics it shares with WGS/WGTS. Reference runs `20260827e81c2a44` (L2600560)
and `20260904efefcb94` (L2600570) synced under `nogit/dragen-tso500-ctdna/`; the
full S3 listing + per-file parse decision is in
`nogit/aws-s3-ls-dragen-tso500-ctdna-*.{md,csv}`. Pull the parse-relevant subset
with `tidydragen::s3sync_cttso()` (excludes BAM/gVCF/bigwig/logs; see `R/s3.R`).

**Authoritative prior art:** dracarys PR
[umccr/dracarys#135](https://github.com/umccr/dracarys/pull/135) (class
`Wf_tso_ctdna_tumor_only_v2`) + `../dracarys/R/tsov2.R`/`tso.R`/`tso_sar.R` ---
the tidy-name port source (`dracarys_tidy/`).

Run layout (per sample `<S>`):

```
<run>/Results/<S>/                                # TSO500 app-layer outputs (NOT DRAGEN format)
<run>/Logs_Intermediates/DragenCaller/<S>/        # DRAGEN per-sample metrics + VCFs
<run>/Logs_Intermediates/SampleAnalysisResults/   # <S>_SampleAnalysisResults.json
```

Only two `Logs_Intermediates/` subdirs are worth pulling: `DragenCaller` (DRAGEN
metrics + VCFs) and `SampleAnalysisResults` (the SAR JSON). Everything else
either surfaces in `Results/` or is junk.

> **Do NOT parse `*_MetricsOutput.tsv`** (either copy) --- dracarys skips it as
> "terribly inconsistent for programmatic parsing." Reconstruct any needed
> metric from the DRAGEN metrics files + SAR JSON + CombinedVariantOutput
> instead.

### File classification (what maps where)

- **DragenMap (metrics):** `trimmer` (plain M), `umi` (M, 1→N summary + 3 inline
  histograms), `gc` (M, 1→N summary + per-GC-window; GC BIAS DETAILS has two
  per-GC series --- Windows count/pct AND Normalized coverage --- merged on GC
  value).
- **DragenVar:** `gvcf` (M, `VARIANT CALLER POSTFILTER GVCF`, cols ⊆ vc);
  `contamination` (custom flat JSON --- `CONTAMINATION_P_VALUE` is *not* in the
  SAR JSON, so this file is parsed for it; ignore `SNPsUsed`).
- **DragenCov:** region-enum fix only (`exon` + `target_bed` added) --- no new
  tables. These region labels were silently dropped before the fix (no file
  match → no warning → audit-invisible).
- **DragenTso (NEW tool, `flat_tidy_names=TRUE`):** file-based ---
  `smallvariants` (CVO `[Small Variants]` section only; the TMB/MSI/CNV/Fusions
  sections are dropped, sourced from SAR per dracarys), `fusions`, `tmbtrace`,
  `tmbmsaf`, `exoncov`, `genecov`; SAR fan-out (1→6) --- `sarinfo`, `sarqc`
  (qualityControlMetrics + expandedMetrics + biomarkers folded into one wide
  row), `sarsnv` (full Nirvana per-transcript, n≈1287), `sarcnv`, `sarswds`,
  `sarsw`. `smallvariants` (CVO reported set) and `sarsnv` (SAR full-annotated
  superset) are kept as separate granularities on purpose.

### Dedup rule (Results/ vs Logs_Intermediates/)

Several parse-Yes files exist byte-identical in **both** `Results/<S>/` and a
`Logs_Intermediates/*` subdir. nemo matches on **basename only** (`Tool.R:85`),
so the copies collide → a private `refine_files` override on `DragenTso` keeps
the `/Results/` copy (falls back to row 1 for single-copy basenames). The SAR
JSON is `Logs_Intermediates`-only, so its match is a dedup no-op.

### Tier 3 --- deferred (parked)

`cnv.vcf` / `hard-filtered.vcf.gz` (dracarys parses these via bcftools
shell-out, which tidydragen rejected in Phase 5 --- needs native VCF parsing or
the bcftools dep) and `SmallVariants_Annotated.json.gz` /
`TMB_Annotated.json.gz` (gzipped annotation JSON, no dracarys port source;
reconcile vs CVO/SAR before adding).

## Testing

roxytest only --- `@examples` + `@testexamples` blocks, `make roxydoc`
regenerates `tests/`. Per-tool example runs `obj$run(format="parquet")` and
asserts table names + row counts. Fixtures under `inst/extdata/<tool>/`
(untracked by design), trimmed from real `nogit/` runs; respect the 200 KB
pre-commit large-file cap (truncate histograms/beds/traces). The DRAGEN and
TSO500 docs MCP servers (`mcp__dragen__*`, `mcp__dragen-tso-500-*`) ground
schema authoring against official metric definitions --- prefer
`searchDocumentation`/`getPage` over `askQuestion`.

## Implementation notes

- **Ragged rows → base `read.csv(fill=TRUE)`, not readr.** Metrics rows have 4
  or 5 fields; readr/vroom infers column count from the *first* line (a 4-field
  SUMMARY row) and silently merges `pct` into `count`. `parse_metrics` uses
  `utils::read.csv(fill=TRUE, colClasses="character")`, then casts per schema.
- **Value column read as character, coerced per schema after pivot** --- some
  metrics are strings (`Child Sample`), counts exceed 2³¹.
- **`get_col_map()` returns readr type codes `c`/`i`/`d`** (Config remaps from
  `char`/`int`/`float`). Schema type strings must be `char`/`int`/`float` (not
  `character` --- Config rejects it).
- Numeric counts typed **`float`** to avoid 32-bit overflow; reserve `int` for
  small bounded counts.
- Custom-parse tables go through `tidy_file`, which renames **by position**
  (`ncol` must equal schema rows) and does **no** type conversion --- a custom
  `parse_` must emit typed columns in schema order.

## Build note

Config resolves `system.file('config/tools', ...)` --- run **`make build` after
any `schema.yaml` change**, not just `load_all()`.
