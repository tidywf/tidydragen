# Structure

One `schema.yaml` per tool under `inst/config/tools/<tool>/`.
Class/schema walkthrough: [nemo
structure](https://tidywf.github.io/nemo/articles/structure.html).

DRAGEN tools extend `DragenTool`
([`nemo::Tool`](https://tidywf.github.io/nemo/reference/Tool.html)
child), which holds shared parsing, notably the `dragen-metrics` ftype
for headerless `section,rg,variable,count[,pct]` `*_metrics.csv` files.
`Interop` (Illumina run QC, not a DRAGEN output) extends
[`nemo::Tool`](https://tidywf.github.io/nemo/reference/Tool.html)
directly. See
[UML](https://tidywf.github.io/tidydragen/articles/uml.md).

## Why several tools, not one

One tool per output group: `DragenMap`, `DragenCov`, `DragenVar`,
`DragenRna`, `DragenFqc`, `DragenTso`, `DragenBcl`, `Interop`.

- Pipelines produce different subsets; `Dragen` skips absent tools
- One tool = one `schema.yaml` = one output token (e.g.
  `<prefix>_dragencov_finehist`)
- Schemas evolve independently
- Shared logic (`dragen-metrics`/`csv-nohead` ftypes, `refine_files`,
  fail-loud policies) lives on `DragenTool`, so no duplication

## Fan-out

Some files split into several output tables, declared under `outputs:`
in their tool’s `schema.yaml` and written as `<prefix>_<tool>_<output>`:

| Tool | File table | Outputs |
|:---|:---|:---|
| dragenmap | `umi` | `umimain`, `umihist` |
| dragenmap | `gc` | `gcmain`, `gcbias` |
| dragenmap | `replay` | `replaymain`, `replayconfig` |
| dragenfqc | `fastqc` | `posbasecontent`, `posbasemeanqual`, `posqual`, `readgc`, `readgcqual`, `readlen`, `readmeanqual`, `seqpos` |
| dragencov | `covmetrics` | `metricsmain`, `metricsbins`, `metricscumu` |
| dragencov | `reportbed` | `reportbedmain`, `reportbedcumu` |
| dragenvar | `ploidy` | `ploidymain`, `ploidyratio` |
| dragentso | `sar` | `sarmain`, `sarqc`, `sarqcthr`, `sarswds`, `sarsw`, `sarsnv`, `sarcnv` |
| interop | `summary` | `summarymain`, `summaryreadlane` |
| interop | `indexsummary` | `indexsummarymain`, `indexsummarydetail` |
