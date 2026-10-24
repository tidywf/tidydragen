# DRAGEN S3 Sync Excludes

Trailing `--exclude` globs for
[`s3sync()`](https://tidywf.github.io/tidydragen/dev/reference/s3sync.md),
dropping the ctTSO `Logs_Intermediates/` duplicates of `Results/`
outputs. `aws s3 sync` filters are last-match-wins, so these come after
the schema-derived includes.

## Usage

``` r
DRAGEN_SYNC_EXCLUDE
```

## Format

An object of class `character` of length 7.
