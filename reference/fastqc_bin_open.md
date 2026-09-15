# Normalise open-ended DRAGEN FASTQC position/length bin tokens

DRAGEN FASTQC `fastqc_metrics.csv` position and read-length tokens are
usually a single integer (`150`) or a closed range (`145-152`), but with
a coarser `--fastqc-granularity` (or reads longer than the top bin)
DRAGEN also emits open-ended terminal bins: `256+` (positions) and
`>=255` (read lengths). This strips the open-bin markers (`+`, `>=`,
`>`, `=`) so the token collapses to its single integer bound. Closed
ranges (`A-B`) are left untouched for a subsequent
`separate_longer_delim("-")` to expand.

Without this, `as.integer("256+")` / `as.integer(">=255")` would
silently coerce to `NA` and drop the top position/length bin.

## Usage

``` r
fastqc_bin_open(v)
```

## Arguments

- v:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Vector of raw position/length bin tokens (with any trailing `bp`
  already removed).

## Value

([`character()`](https://rdrr.io/r/base/character.html)) Tokens with
open-bin markers stripped.

## Examples

``` r
fastqc_bin_open(c("150", "145-152", "256+", ">=255"))
#> [1] "150"     "145-152" "256"     "255"    
```
