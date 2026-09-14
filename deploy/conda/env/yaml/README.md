Conda environment definitions, one per CI job:

- `tidydragen.yaml`: the runtime package env (`r-tidydragen`); source for the
  conda lockfiles.
- `condabuild.yaml`: build tools (`rattler-build` + `conda-lock`).
- `bump.yaml`: version bumping (`bump-my-version`).
- `pkgdown.yaml`: docs site build (`r-pkgdown` + Quarto).
