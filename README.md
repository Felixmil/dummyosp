# dummyosp

**A minimal downstream R package that verifies its Open Systems Pharmacology dependencies can be installed and resolved from the [OSP R-universe](https://open-systems-pharmacology.r-universe.dev).**

`dummyosp` does nothing useful on its own. It `Imports: ospsuite, ospsuite.plots` and exports one function, `ospVersions()`, that reports the versions of those packages. Its value is as a test fixture: a real package whose only dependencies are OSP packages, used to answer one question and record the answer.

## Background

OSP R packages ship pre-compiled .NET binaries, so they cannot go on CRAN and are published on an [R-universe](https://r-universe.dev) instead. This raises a practical question for anyone building on top of them: can a *downstream* package that lists OSP packages in its `Imports` be installed normally, with those dependencies fetched automatically from the universe, rather than requiring each user to hand-install the OSP stack first? `dummyosp` exists to test that end to end and to document the conditions under which it holds.

## Method

Two conditions are needed for automatic resolution:

1. **The universe on the repository list.** At install time the OSP universe must be on `options(repos = ...)`. With it there, `ospsuite`, `ospsuite.plots`, `rSharp`, and the rest are ordinary repository packages installable by name, like any CRAN package.
2. **`Additional_repositories` in `DESCRIPTION`.** `dummyosp`'s [`DESCRIPTION`](DESCRIPTION) declares the universe via `Additional_repositories`, the standard field that tells `R CMD check` where non-CRAN `Imports` live.

Installation uses `pak` (or base `install.packages()`). The choice of installer is not incidental; see [Discussion](#discussion).

The install below targets a **fresh, empty library** so that nothing already present on the machine can be reused. This makes the outcome a genuine test: the OSP dependencies must be resolved and downloaded from the universe for the install to succeed at all.

```r
install.packages("pak")

lib <- tempfile("dummyosp-lib-") # fresh, empty library
dir.create(lib)

# pak does not read Additional_repositories from the fetched package,
# so the universe is named on repos here.
options(repos = c(
  OSP  = "https://open-systems-pharmacology.r-universe.dev",
  CRAN = "https://cloud.r-project.org"
))

pak::pak("Felixmil/dummyosp", lib = lib, dependencies = TRUE, upgrade = TRUE)

library(dummyosp, lib.loc = lib)
ospVersions()
#>       ospsuite ospsuite.plots
#>       "12.4.4"        "1.3.0"
#> (versions match whatever the universe currently serves)

unlink(lib, recursive = TRUE)
```

The OSP packages themselves need no `pak`: with the universe on `repos`, plain `install.packages("ospsuite", dependencies = TRUE)` fetches them too. `dummyosp` needs `pak` only because it is hosted on GitHub rather than in a repository.

## Results

**The downstream install succeeds and the dependencies come from the universe.** A matching version string alone is not proof (the universe and GitHub HEAD can momentarily agree), so the source is confirmed by resolving the plan without installing and reading the `type` column:

```r
plan <- pak::pkg_deps("Felixmil/dummyosp", dependencies = TRUE)
plan[plan$package %in% c("dummyosp", "ospsuite", "ospsuite.plots", "rSharp"),
     c("package", "version", "type")]
#>          package  version     type
#>         dummyosp    0.0.1   github
#>         ospsuite  12.4.4 standard
#>   ospsuite.plots   1.3.0 standard
#>           rSharp   1.2.2 standard
```

`dummyosp` resolves as `github` (it is not on the universe). Every OSP dependency resolves as `standard`, a regular repository package, with its `plan$sources` URL pointing at the universe, e.g. `https://open-systems-pharmacology.r-universe.dev/bin/windows/contrib/4.6/ospsuite_12.4.4.zip`.

**Continuous integration confirms the same on clean runners.** [`.github/workflows/R-CMD-check.yaml`](.github/workflows/R-CMD-check.yaml) is the stock [r-lib](https://github.com/r-lib/actions) `check-standard` workflow with one addition on the `setup-r` step:

```yaml
- uses: r-lib/actions/setup-r@v2
  with:
    extra-repositories: https://open-systems-pharmacology.r-universe.dev
```

That single input puts the universe on `repos` for the runner; `setup-r-dependencies` (which uses `pak`) then resolves the OSP `Imports` from it. No `Remotes:` field and no custom workflows are involved. The check runs on Ubuntu and Windows and passes on both.

## Discussion

**The installer matters because of how `Remotes:` is scoped.** `ospsuite`'s own `DESCRIPTION` contains a `Remotes:` field pointing its dependencies back at GitHub (`rSharp`, `ospsuite.utils`, `tlf`, `ospsuite.plots`, all `@*release`). That field has no effect on the install above: `pak` honors `Remotes:` only for the *root* package requested, never for the `Remotes:` of packages pulled in transitively. Because `dummyosp` declares no `Remotes:`, nothing steers resolution to GitHub and the universe on `repos` supplies the whole tree. This is precisely why `remotes::install_github()` behaves differently: `remotes` *does* follow a dependency's `Remotes:` and rebuilds the OSP packages from GitHub source, bypassing the universe. Use `pak` (or base `install.packages()`) to get the universe install.

**Binaries are platform-specific; Linux resolves to source.** An R-universe publishes pre-built binaries for Windows and macOS only. There is no generic Linux binary, so on Linux the same packages resolve to `src/contrib/*.tar.gz` and compile from source. Same universe and same command, different artifact per OS. This is visible in CI: the Windows job installs `ospsuite` as a `.zip` binary in seconds, while the Ubuntu job compiles it from the source tarball (slower, but successful). For a large package with a .NET component this is the main cost difference between the two platforms.

**CI does not require the upstream machinery.** The production OSP packages resolve dependencies through a dedicated reusable-workflows repository that pins and unpins the `Remotes:` field on every pull request. None of that is needed simply to install from the universe; the one `extra-repositories` line above is sufficient for a downstream package.

## License

MIT. See [LICENSE](LICENSE).
