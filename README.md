# dummyosp

A minimal, throwaway R package whose only purpose is to demonstrate that a package **depending on the [Open Systems Pharmacology R-universe](https://open-systems-pharmacology.r-universe.dev) packages can be installed with its dependencies resolved automatically from the universe**.

It does nothing useful. It `Imports: ospsuite, ospsuite.plots` and exports a single function, `ospVersions()`, that reports the versions of those two packages so you can confirm they were pulled in.

## Why this exists

OSP R packages ship pre-compiled .NET binaries, so they cannot live on CRAN and are instead published on an [R-universe](https://r-universe.dev). A recurring question is whether a *downstream* package (yours) that lists OSP packages in its `Imports` can be installed normally, with the OSP dependencies fetched from the universe rather than hand-installed first.

This repository is the runnable proof that it can.

## The one thing that makes it work

The dependency resolution is enabled by a single field in [`DESCRIPTION`](DESCRIPTION):

```
Additional_repositories:
    https://open-systems-pharmacology.r-universe.dev
```

`Additional_repositories` is the standard `R CMD` mechanism for declaring a non-CRAN source for `Imports`/`Depends`/`Suggests` that are not on CRAN. Both `install.packages()` and `pak` honor it.

## Reproducible install

Run any **one** of the following in a clean R session. Each installs `dummyosp` and, transitively, `ospsuite` and `ospsuite.plots` (and their own dependencies) from the OSP R-universe, with everything else coming from CRAN.

To make this a genuine proof, each snippet installs into a **fresh, empty library** so that nothing you already have installed can be reused. The OSP dependencies *must* be resolved and downloaded from the universe for the install to succeed. Delete the temporary library afterward and your usual library is untouched.

### Option 1 — `pak` (recommended)

`pak` reads `Additional_repositories` from the package on GitHub and resolves the OSP dependencies from the universe with no extra configuration.

```r
install.packages("pak")

# Fresh, empty library so nothing already installed can be reused.
lib <- tempfile("dummyosp-lib-")
dir.create(lib)

pak::pak(
  "Felixmil/dummyosp",
  lib = lib,
  dependencies = TRUE,
  upgrade = TRUE # ignore any cached/older copies; take what the universe serves
)

# Load and verify strictly from the fresh library.
library(dummyosp, lib.loc = lib)
ospVersions()
```

### Option 2 — `install.packages()` with the universe as an explicit repo

If you prefer base tooling, point `repos` at both the OSP universe and CRAN. `dummyosp` is not on the universe itself, so install it from source via `remotes`, and let `repos` supply the dependencies:

```r
install.packages("remotes")

# Fresh, empty library so nothing already installed can be reused.
lib <- tempfile("dummyosp-lib-")
dir.create(lib)

withr::with_libpaths(lib, action = "prefix", {
  remotes::install_github(
    "Felixmil/dummyosp",
    repos = c(
      OSP  = "https://open-systems-pharmacology.r-universe.dev",
      CRAN = "https://cloud.r-project.org"
    ),
    dependencies = TRUE,
    upgrade = "always", # do not reuse already-installed versions
    force = TRUE
  )
})

# Load and verify strictly from the fresh library.
library(dummyosp, lib.loc = lib)
ospVersions()
```

> If you do not have `withr`, replace the `with_libpaths()` wrapper with a manual
> `old <- .libPaths(); .libPaths(c(lib, old)); ...; .libPaths(old)`.

## What success looks like

The final `ospVersions()` call in each snippet returns the two versions without error:

```r
ospVersions()
#>       ospsuite ospsuite.plots
#>  "12.4.3.9014"     "1.2.0.9005"
#> (exact versions match whatever the universe currently serves)
```

Because everything was installed into a fresh, empty library, those two packages could only have come from the R-universe. The downstream install worked end to end: `dummyosp` was installed, and its OSP `Imports` were resolved from the universe automatically.

Clean up the throwaway library when done:

```r
unlink(lib, recursive = TRUE)
```

## License

MIT. See [LICENSE](LICENSE).
