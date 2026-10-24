# Normalise DRAGEN coverage summary-metric names

Makes DRAGEN coverage summary-metric names region-agnostic, so one
schema serves every region: `over <region>` suffixes are stripped,
`in <region>` collapses to `in region` (distinct from the plain
`Aligned bases` total).

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
