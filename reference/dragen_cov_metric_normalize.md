# Normalise DRAGEN coverage summary-metric names

Rewrites the `variable` column of the **summary rows** of a parsed
DRAGEN `*_coverage_metrics.csv` into region-agnostic names, so a single
schema serves every coverage region. Two rewrites are applied:

- **`over <region>` suffixes** (e.g.
  `Average alignment coverage over genome`) are stripped;

- **`in <region>` suffixes** (e.g. `Aligned bases in genome`) collapse
  to `in region`, keeping them distinct from the plain `Aligned bases`
  total.

The coverage-bin rows (`PCT of <region> with coverage [lo: hi)`) are
split off into the separate `bins` table by
[DragenCov](https://tidywf.github.io/tidydragen/reference/DragenCov.md)
and parsed with
[`dragen_cov_bin_split()`](https://tidywf.github.io/tidydragen/reference/dragen_cov_bin_split.md),
so they never pass through this function. The region itself is carried
in the output `prefix` (via `refine_files()`), so unlike the
variant-caller metrics no `region` column is emitted.

## Usage

``` r
dragen_cov_metric_normalize(v)
```

## Arguments

- v:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Vector of raw metric names.

## Value

([`character()`](https://rdrr.io/r/base/character.html)) Normalised
metric names.

## Examples

``` r
dragen_cov_metric_normalize(c(
  "Aligned bases",
  "Aligned bases in genome",
  "Average alignment coverage over QC coverage region"
))
#> [1] "Aligned bases"              "Aligned bases in region"   
#> [3] "Average alignment coverage"
```
