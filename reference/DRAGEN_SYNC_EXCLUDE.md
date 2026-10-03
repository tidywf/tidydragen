# DRAGEN S3 Sync Excludes

Trailing `--exclude` globs applied after the schema-derived includes
when syncing a DRAGEN run (see
[`s3sync()`](https://tidywf.github.io/tidydragen/reference/s3sync.md)).
A ctTSO run writes the same app-layer outputs twice — once under
`Logs_Intermediates/<sample>/` and once under `Results/<sample>/` — so
these drop the `Logs_Intermediates/` copy and keep the `Results/` one.
`aws s3 sync` filters are ordered and last-match wins, hence these must
come last.

## Usage

``` r
DRAGEN_SYNC_EXCLUDE
```

## Format

An object of class `character` of length 7.
