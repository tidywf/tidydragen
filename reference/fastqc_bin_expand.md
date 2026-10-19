# Expand DRAGEN FASTQC position/length bin tokens to integer grains

Expands each position/length token to the integers it covers
(`"137-140"` -\> `137:140`), for
[`tidyr::unnest_longer()`](https://tidyr.tidyverse.org/reference/unnest_longer.html).
Not
[`tidyr::separate_longer_delim()`](https://tidyr.tidyverse.org/reference/separate_longer_delim.html),
which keeps only the endpoints. Run
[`fastqc_bin_open()`](https://tidywf.github.io/tidydragen/reference/fastqc_bin_open.md)
first.

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
