# dummyosp

A minimal, throwaway R package whose only purpose is to demonstrate that a package **depending on the [Open Systems Pharmacology R-universe](https://open-systems-pharmacology.r-universe.dev) packages can be installed with its dependencies resolved from the universe**.

It does nothing useful. It `Imports: ospsuite, ospsuite.plots` and exports a single function, `ospVersions()`, that reports the versions of those two packages so you can confirm they were pulled in.

## Why this exists

OSP R packages ship pre-compiled .NET binaries, so they cannot live on CRAN and are instead published on an [R-universe](https://r-universe.dev). A recurring question is whether a *downstream* package (yours) that lists OSP packages in its `Imports` can be installed normally, with the OSP dependencies fetched from the universe rather than hand-installed first.

This repository is the runnable proof that it can.

## The mechanism

Two pieces combine to make the resolution work:

1. `dummyosp`'s [`DESCRIPTION`](DESCRIPTION) declares the OSP universe as a non-CRAN source:

   ```
   Additional_repositories:
       https://open-systems-pharmacology.r-universe.dev
   ```

   `Additional_repositories` is the standard `R CMD` mechanism for declaring where non-CRAN `Imports`/`Depends`/`Suggests` come from. It is honored by `R CMD check` and by base `install.packages()` when installing a source tarball that carries the field.

2. The active repository list must include the OSP universe when you run the install.

   One practical caveat, reflected in the snippets below: when installing straight from GitHub, neither `pak` nor `remotes::install_github()` reads `Additional_repositories` out of the fetched package to discover where the OSP dependencies live. You point them at the universe explicitly (via `options(repos = ...)` for `pak`, or the `repos =` argument for `remotes`). Once the universe is in the active repository list, both resolve `ospsuite` and `ospsuite.plots` from it automatically.

## Reproducible install

Run any **one** of the following in a clean R session. Each installs `dummyosp` and, transitively, `ospsuite` and `ospsuite.plots` (and their own dependencies) from the OSP R-universe, with everything else coming from CRAN.

To make this a genuine proof, each snippet installs into a **fresh, empty library** so that nothing you already have installed can be reused. The OSP dependencies *must* be resolved and downloaded from the universe for the install to succeed. Delete the temporary library afterward and your usual library is untouched.

Both snippets below were run end to end into a fresh library before being published here.

### Option 1: `pak` (recommended)

Put the OSP universe (and CRAN) on the repository list, then let `pak` resolve `dummyosp` and its OSP dependencies from it.

```r
install.packages("pak")

# Fresh, empty library so nothing already installed can be reused.
lib <- tempfile("dummyosp-lib-")
dir.create(lib)

# pak does NOT read Additional_repositories from the GitHub package,
# so name the universe explicitly on the repos list.
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
```

### Option 2: `remotes` with the universe as an explicit repo

If you prefer base-adjacent tooling, pass the universe and CRAN through `repos`. `dummyosp` is not on the universe itself, so install it from GitHub via `remotes`, and let `repos` supply the dependencies:

```r
install.packages(c("remotes", "withr"))

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

## What success looks like

The final `ospVersions()` call in each snippet returns the two versions without error:

```r
ospVersions()
#>      ospsuite ospsuite.plots
#> "12.4.3.9013"   "1.2.0.9004"
#> (exact versions match whatever the universe currently serves)
```

Because everything was installed into a fresh, empty library, those two packages could only have come from the R-universe. The downstream install worked end to end: `dummyosp` was installed, and its OSP `Imports` were resolved from the universe automatically.

Clean up the throwaway library when done:

```r
unlink(lib, recursive = TRUE)
```

## License

MIT. See [LICENSE](LICENSE).
