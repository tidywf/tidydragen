# Split DRAGEN coverage-bin metric names into numeric bounds

Parses DRAGEN coverage-bin names
(`PCT of <region> with coverage [lo: hi)`) into their depth bounds. Open
bins (`[Nx: inf)`) get an `NA` upper bound.

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
