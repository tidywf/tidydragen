# PostgreSQL

`format = "db"` + a DBI connection. Example uses
[RPostgres](https://rpostgres.r-dbi.org/); any DBI backend works.

## Writing a run to the database

``` r

dbconn <- DBI::dbConnect(
  drv = RPostgres::Postgres(),
  dbname = "tidydragen",
  user = "me"
)

indir <- system.file("extdata", package = "tidydragen")
d <- Dragen$new(indir)
d$run(
  format = "db",
  input_id = "run1",
  output_id = "out1",
  prefix_include = TRUE,
  dbconn = dbconn
)

DBI::dbDisconnect(dbconn)
```

Tables are named `<tool>_<table>` (e.g. `dragenmap_metrics`). Use the
[ID
columns](https://tidywf.github.io/tidydragen/articles/quickstart.html#id-columns)
to trace rows across samples/runs.

## Schema generation

Write once, then dump:

``` shell
pg_dump --schema-only tidydragen > schema.sql
```

Diff successive dumps before applying to a shared database.
