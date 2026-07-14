# dummyosp

A minimal, throwaway R package whose only purpose is to demonstrate that a package **depending on the [Open Systems Pharmacology R-universe](https://open-systems-pharmacology.r-universe.dev) packages can be installed with its dependencies resolved from the universe**.

It does nothing useful. It `Imports: ospsuite, ospsuite.plots` and exports a single function, `ospVersions()`, that reports the versions of those two packages so you can confirm they were pulled in.

## Why this exists

OSP R packages ship pre-compiled .NET binaries, so they cannot live on CRAN and are instead published on an [R-universe](https://r-universe.dev). A recurring question is whether a *downstream* package (yours) that lists OSP packages in its `Imports` can be installed normally, with the OSP dependencies fetched from the universe rather than hand-installed first.

This repository is the runnable proof that it can.

## The mechanism

Two pieces combine to make the resolution work:

1. `dummyosp`'s [`DESCRIPTION`](DESCRIPTION) declares the OSP universe as a non-CRAN source via `Additional_repositories`. This is the standard `R CMD` field that tells tooling where non-CRAN `Imports` live, and it is honored by `R CMD check`.

2. The OSP universe must be on the active repository list when you install. `pak` then treats `ospsuite`, `ospsuite.plots`, and `rSharp` as ordinary repository packages and pulls them from the universe as **pre-built binaries**.

Use `pak`, not `remotes::install_github()`. `remotes` recognizes the OSP packages as GitHub-hosted (from their `Remotes:`/repo origin) and rebuilds them from GitHub source, bypassing the universe entirely. `pak` resolves them from the universe as binaries, which is the R-universe install experience this repository is meant to show.

## Reproducible install

Run the following in a clean R session. It installs `dummyosp` and, transitively, `ospsuite` and `ospsuite.plots` (plus `rSharp` and the rest) from the OSP R-universe, with everything else coming from CRAN.

To make this a genuine proof, the snippet installs into a **fresh, empty library** so that nothing you already have installed can be reused. The OSP dependencies *must* be resolved and downloaded from the universe for the install to succeed. Delete the temporary library afterward and your usual library is untouched.

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

pak::pak(
  "Felixmil/dummyosp",
  lib = lib,
  dependencies = TRUE,
  upgrade = TRUE # take what the universe serves, do not reuse older copies
)

# Load and verify strictly from the fresh library.
library(dummyosp, lib.loc = lib)
ospVersions()
#>      ospsuite ospsuite.plots
#> "12.4.3.9014"   "1.2.0.9005"
#> (exact versions match whatever the universe currently serves)

unlink(lib, recursive = TRUE) # clean up the throwaway library
```

## Proving where the dependencies came from

The version string alone is not proof (the universe and GitHub HEAD can momentarily match). To see the actual source of each package, ask `pak` to resolve the plan without installing anything:

```r
options(repos = c(
  OSP  = "https://open-systems-pharmacology.r-universe.dev",
  CRAN = "https://cloud.r-project.org"
))

plan <- pak::pkg_deps("Felixmil/dummyosp", dependencies = TRUE)
plan[plan$package %in% c("dummyosp", "ospsuite", "ospsuite.plots", "rSharp"),
     c("package", "version", "type")]
```

Which returns:

```
         package      version     type
1       dummyosp        0.0.1   github
2       ospsuite  12.4.3.9014 standard
3 ospsuite.plots   1.2.0.9005 standard
4         rSharp        1.2.2 standard
```

`dummyosp` itself is `github` (it is not on the universe). Every OSP dependency is `standard`, meaning a regular repository package, and its resolved `sources` URL points at the universe, for example:

```
https://open-systems-pharmacology.r-universe.dev/bin/macosx/sonoma-arm64/contrib/4.6/ospsuite_12.4.3.9014.tgz
```

That is a pre-built R-universe binary, not a GitHub source build. The downstream install works end to end: `dummyosp` is installed, and its OSP `Imports` are resolved from the universe automatically.

## The OSP packages are directly installable with base `install.packages()`

No `pak` or `remotes` needed to get the OSP packages themselves: once the universe is on the `repos` list, plain base R installs them by name, as pre-built binaries, exactly like any CRAN package.

```r
install.packages(
  "ospsuite", # or ospsuite.plots, rSharp, ...
  repos = c(
    OSP  = "https://open-systems-pharmacology.r-universe.dev",
    CRAN = "https://cloud.r-project.org"
  ),
  dependencies = TRUE
)
```

To confirm the packages resolve from the universe (rather than relying on what is already installed on your machine), inspect the repository index and fetch directly:

```r
repos <- c(
  OSP  = "https://open-systems-pharmacology.r-universe.dev",
  CRAN = "https://cloud.r-project.org"
)

# 1. Base R sees the OSP packages in the repository list:
ap <- available.packages(repos = repos)
ap[c("ospsuite", "ospsuite.plots", "rSharp"), "Version"]
#>       ospsuite ospsuite.plots         rSharp
#>  "12.4.3.9014"   "1.2.0.9005"        "1.2.2"

ap["ospsuite", "Repository"]
#> "https://open-systems-pharmacology.r-universe.dev/src/contrib/ospsuite_12.4.3.9014.tar.gz?sha256=..."

# 2. download.packages() fetches from the universe regardless of what is
#    already installed, so the source is unambiguous:
download.packages("ospsuite", destdir = tempdir(), repos = repos)
#> [1] "ospsuite"
#> [2] ".../ospsuite_12.4.3.9014.tar.gz"   # downloaded from the universe
```

This is the "install a package with R-universe dependencies normally" case in its simplest form: base `install.packages()` with the universe named in `repos`. `dummyosp` cannot be installed this way only because it is hosted on GitHub, not in a repository; its OSP dependencies, which *are* in the universe, install with plain base tooling.

## License

MIT. See [LICENSE](LICENSE).
