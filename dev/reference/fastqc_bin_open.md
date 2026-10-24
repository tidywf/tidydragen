# Normalise open-ended DRAGEN FASTQC position/length bin tokens

Strips open-ended bin markers from FASTQC position/length tokens
(`256+`, `>=255` -\> `256`, `255`), which would otherwise coerce to `NA`
and drop the top bin. Closed ranges (`A-B`) are left for
[`fastqc_bin_expand()`](https://tidywf.github.io/tidydragen/dev/reference/fastqc_bin_expand.md).

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
