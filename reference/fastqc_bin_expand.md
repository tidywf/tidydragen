# Expand DRAGEN FASTQC position/length bin tokens to integer grains

Turns each position/length token into the full integer sequence it
covers: a single value (`"150"`) becomes `150L`, a closed range
(`"137-140"`) becomes the whole span `137:140`. Returns a list-column,
one integer vector per input, for a subsequent
[`tidyr::unnest_longer()`](https://tidyr.tidyverse.org/reference/unnest_longer.html).

Note that
[`tidyr::separate_longer_delim()`](https://tidyr.tidyverse.org/reference/separate_longer_delim.html)
on `"-"` is **not** a substitute: it yields only the two endpoints
(`137`, `140`), silently dropping the interior positions and giving the
wrong grain count when the count is divided across the span. Feed tokens
through
[`fastqc_bin_open()`](https://tidywf.github.io/tidydragen/reference/fastqc_bin_open.md)
first so open-ended bins (`256+`, `>=255`) have collapsed to a single
bound.

## Usage

``` r
fastqc_bin_expand(v)
```

## Arguments

- v:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Vector of position/length bin tokens, open-bin markers already
  stripped (single value or `lo-hi` range).

## Value

([`list()`](https://rdrr.io/r/base/list.html)) One integer vector per
input token.

## Examples

``` r
fastqc_bin_expand(c("150", "2-3", "137-140"))
#> [[1]]
#> [1] 150
#> 
#> [[2]]
#> [1] 2 3
#> 
#> [[3]]
#> [1] 137 138 139 140
#> 
```
