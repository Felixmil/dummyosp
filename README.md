# dummyosp

A minimal, throwaway R package whose only purpose is to demonstrate that a package **depending on the [Open Systems Pharmacology R-universe](https://open-systems-pharmacology.r-universe.dev) packages can be installed with its dependencies resolved from the universe**.

It does nothing useful. It `Imports: ospsuite, ospsuite.plots` and exports a single function, `ospVersions()`, that reports the versions of those two packages so you can confirm they were pulled in.

## Why this exists

OSP R packages ship pre-compiled .NET binaries, so they cannot live on CRAN and are published on an [R-universe](https://r-universe.dev) instead. The recurring question is whether a *downstream* package (yours) that lists OSP packages in its `Imports` can be installed normally, with the OSP dependencies fetched from the universe rather than hand-installed first. This repository is the runnable proof that it can.

## The mechanism

Two things make the resolution work:

1. The OSP universe must be on the active repository list (`options(repos = ...)`) when you install. With it there, `ospsuite`, `ospsuite.plots`, `rSharp`, and the rest are ordinary repository packages that install by name, like any CRAN package.
2. `dummyosp`'s [`DESCRIPTION`](DESCRIPTION) also declares the universe via `Additional_repositories`. This is the standard field that tells `R CMD check` where non-CRAN `Imports` live.

Use `pak` (or base `install.packages()`), **not** `remotes::install_github()`. This turns out to matter, and the reason is the interesting part of this repository, see [What we learned](#what-we-learned) below.

## Reproducible install

Run this in a clean R session. It installs `dummyosp` and, transitively, `ospsuite` / `ospsuite.plots` (plus `rSharp` and the rest) from the OSP universe, with everything else coming from CRAN. To make it a genuine proof, it installs into a **fresh, empty library** so nothing already on your machine can be reused: the OSP dependencies *must* come from the universe for the install to succeed.

```r
install.packages("pak")

# Fresh, empty library so nothing already installed can be reused.
lib <- tempfile("dummyosp-lib-")
dir.create(lib)

# Put the OSP universe (and CRAN) on the repository list. pak does not read
# Additional_repositories from the fetched package, so name the universe here.
options(repos = c(
  OSP  = "https://open-systems-pharmacology.r-universe.dev",
  CRAN = "https://cloud.r-project.org"
))

pak::pak("Felixmil/dummyosp", lib = lib, dependencies = TRUE, upgrade = TRUE)

library(dummyosp, lib.loc = lib)
ospVersions()
#>       ospsuite ospsuite.plots
#>       "12.4.4"        "1.3.0"
#> (exact versions match whatever the universe currently serves)

unlink(lib, recursive = TRUE) # clean up the throwaway library
```

The OSP packages *themselves* need no `pak` at all: with the universe on `repos`, plain `install.packages("ospsuite", dependencies = TRUE)` fetches them as pre-built binaries too. `dummyosp` needs `pak` only because it lives on GitHub, not in a repository.

## Proving where the dependencies came from

A matching version string is not proof (the universe and GitHub HEAD can momentarily agree). Ask `pak` to resolve the plan *without installing*, and read the `type` column:

```r
options(repos = c(
  OSP  = "https://open-systems-pharmacology.r-universe.dev",
  CRAN = "https://cloud.r-project.org"
))

plan <- pak::pkg_deps("Felixmil/dummyosp", dependencies = TRUE)
plan[plan$package %in% c("dummyosp", "ospsuite", "ospsuite.plots", "rSharp"),
     c("package", "version", "type")]
#>          package  version     type
#>         dummyosp    0.0.1   github
#>         ospsuite  12.4.4 standard
#>   ospsuite.plots   1.3.0 standard
#>           rSharp   1.2.2 standard
```

`dummyosp` is `github` (it is not on the universe). Every OSP dependency is `standard`, meaning a regular repository package, and its resolved `sources` URL points at the universe. `plan$sources` shows the exact file, e.g. `https://open-systems-pharmacology.r-universe.dev/bin/windows/contrib/4.6/ospsuite_12.4.4.zip`: a pre-built universe binary, not a GitHub source build.

## What we learned

Working through this (and the CI below) surfaced three things worth writing down.

**`pak` ignores a dependency's `Remotes:` field.** `ospsuite`'s own `DESCRIPTION` has a `Remotes:` field pointing its OSP dependencies back at GitHub (`rSharp`, `ospsuite.utils`, `tlf`, `ospsuite.plots`, all `@*release`). That field has **no effect** here: `pak` honors `Remotes:` only for the *root* package you asked for, never for the `Remotes:` of packages it pulls in transitively. Since `dummyosp` has no `Remotes:` field, nothing steers anything to GitHub, and the universe on `repos` supplies the whole tree. This is exactly why `pak` gives the universe install and `remotes::install_github()` does not: `remotes` *does* follow those dependency `Remotes:` fields and rebuilds the OSP packages from GitHub source, bypassing the universe.

**Binaries are per-platform; Linux gets source.** An R-universe publishes pre-built binaries for Windows and macOS only. There is no generic Linux binary, so on Linux the same packages resolve to `src/contrib/*.tar.gz` and are compiled from source. Same universe, same install command, different artifact per OS. For `ospsuite` (a large package with a .NET component) that source build is slow but succeeds.

**CI is one extra line, not a framework.** The real OSP packages resolve dependencies through a dedicated reusable-workflows repository that pins and unpins the `Remotes:` field on every pull request. None of that is needed to install from the universe. The [`.github/workflows/R-CMD-check.yaml`](.github/workflows/R-CMD-check.yaml) here is the stock [r-lib](https://github.com/r-lib/actions) `check-standard` workflow with a single addition on the `setup-r` step:

```yaml
- uses: r-lib/actions/setup-r@v2
  with:
    extra-repositories: https://open-systems-pharmacology.r-universe.dev
```

That one input puts the universe on `repos` for the runner, and `setup-r-dependencies` (which uses `pak`) resolves the OSP `Imports` from it: no `Remotes:` field, no custom workflows. The workflow runs on Ubuntu (source build) and Windows (universe binaries), confirming both paths.

## License

MIT. See [LICENSE](LICENSE).
