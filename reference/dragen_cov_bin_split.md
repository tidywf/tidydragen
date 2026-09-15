# Split DRAGEN coverage-bin metric names into numeric bounds

Parses the coverage-bin rows of a DRAGEN `*_coverage_metrics.csv`
(`PCT of <region> with coverage [lo: hi)`) into their numeric depth
bounds. The open, cumulative bins (`[Nx: inf)`) return `NA` for the
upper bound, which distinguishes them from the bucketed bins
(`[lo: hi)`).
[DragenCov](https://tidywf.github.io/tidydragen/reference/DragenCov.md)
uses this `NA` to partition the bins into the `metricsbins` (bucketed)
and `metricscumu` (cumulative) long tables.

## Usage

``` r
dragen_cov_bin_split(v)
```

## Arguments

- v:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Vector of raw coverage-bin metric names.

## Value

(`tibble`) with integer columns `cov_lo` and `cov_hi` (`cov_hi` is `NA`
for the open `inf` upper bound).

## Examples

``` r
dragen_cov_bin_split(c(
  "PCT of genome with coverage [ 100x: inf)",
  "PCT of QC coverage region with coverage [  20x:  50x)"
))
#> # A tibble: 2 × 2
#>   cov_lo cov_hi
#>    <int>  <int>
#> 1    100     NA
#> 2     20     50
```
