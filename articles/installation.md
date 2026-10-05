# Installation

### R

From GitHub:

``` r

install.packages("remotes")
remotes::install_github("tidywf/tidydragen") # latest main commit
remotes::install_github("tidywf/tidydragen@v0.0.0.9005") # specific version
```

### Conda

[![conda-version](https://anaconda.org/tidywf/r-tidydragen/badges/version.svg "Conda package version")![conda-latest](https://anaconda.org/tidywf/r-tidydragen/badges/latest_release_date.svg "Conda package latest release date")](https://anaconda.org/tidywf/r-tidydragen)

``` bash
conda create -n tidydragen_env -c tidywf -c conda-forge r-tidydragen==0.0.0.9005
conda activate tidydragen_env
```

### Docker

[![ghcr-latest](https://ghcr-badge.egpl.dev/tidywf/tidydragen/latest_tag?color=%2344cc11&ignore=latest&label=docker-version-latest&trim=.png "GHCR latest tag")![ghcr-size](https://ghcr-badge.egpl.dev/tidywf/tidydragen/size?tag=0.0.0.9005 "GHCR image size")](https://github.com/tidywf/tidydragen/pkgs/container/tidydragen)

``` bash
docker pull --platform linux/amd64 ghcr.io/tidywf/tidydragen:0.0.0.9005
```

#### Docker Compose

`docker-compose.yaml` mounts `./in` (read-only) and `./out`, and tidies
to parquet:

``` bash
mkdir -p in out
docker compose run --rm tidydragen
```

Env vars (or `.env`): `IMAGE_TAG` (default: pinned pkg version),
`IN_DIR`, `OUT_DIR`, `FORMAT` (`parquet` \| `tsv` \| `csv` \| `rds`).
`ENTRYPOINT` is `tidydragen.R`, so extra args pass through:

``` bash
IN_DIR=/path/to/samples docker compose run --rm tidydragen tidy -d /data/in -o /data/out -f tsv
```

### Pixi

With [Pixi](https://pixi.sh/):

``` bash
pixi init -c tidywf -c conda-forge ./tidy_env
cd ./tidy_env
pixi add r-tidydragen==0.0.0.9005
```

CLI task:

``` bash
pixi task add tidydragen "tidydragen.R"
pixi run tidydragen --help
```

Or from R:

``` bash
pixi shell
R
```

``` text
library(tidydragen)
```
