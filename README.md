# dummyosp

**A minimal downstream R package that verifies its Open Systems Pharmacology dependencies can be installed and resolved from the [OSP R-universe](https://open-systems-pharmacology.r-universe.dev).**

`dummyosp` does nothing useful on its own. It `Imports: ospsuite, ospsuite.plots` and exports one function, `ospVersions()`, that reports the versions of those packages. Its value is as a test fixture: a real package whose only dependencies are OSP packages, used to answer one question and record the answer.

## Goal

Evaluate whether the [R-universe](https://r-universe.dev) is a sound basis for **distributing** the Open Systems Pharmacology R packages and for **resolving dependencies between them**, from the point of view of a downstream package that depends on the OSP stack. Concretely: can such a package be installed with its OSP dependencies fetched and version-resolved automatically from the universe, on the platforms its users run, and under continuous integration, and where are the boundaries of that approach.

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

That single input puts the universe on `repos` for the runner; `setup-r-dependencies` (which uses `pak`) then resolves the OSP `Imports` from it. No `Remotes:` field and no custom workflows are involved. The check runs on Ubuntu, Windows, and macOS. Dependency **installation** from the universe succeeds on all three; the R CMD check as a whole passes on Ubuntu and Windows but fails on macOS, for a runtime reason unrelated to the universe (see [Discussion](#discussion)).

## Discussion

**The installer matters because of how `Remotes:` is scoped.** `ospsuite`'s own `DESCRIPTION` contains a `Remotes:` field pointing its dependencies back at GitHub (`rSharp`, `ospsuite.utils`, `tlf`, `ospsuite.plots`, all `@*release`). That field has no effect on the install above: `pak` honors `Remotes:` only for the *root* package requested, never for the `Remotes:` of packages pulled in transitively. Because `dummyosp` declares no `Remotes:`, nothing steers resolution to GitHub and the universe on `repos` supplies the whole tree. This is precisely why `remotes::install_github()` behaves differently: `remotes` *does* follow a dependency's `Remotes:` and rebuilds the OSP packages from GitHub source, bypassing the universe. Use `pak` (or base `install.packages()`) to get the universe install.

**Binaries are platform-specific; Linux resolves to source.** An R-universe publishes pre-built binaries for Windows and macOS only. There is no generic Linux binary, so on Linux the same packages resolve to `src/contrib/*.tar.gz` and compile from source. Same universe and same command, different artifact per OS. This is visible in CI: the Windows job installs `ospsuite` as a `.zip` binary in seconds, while the Ubuntu job compiles it from the source tarball (slower, but successful). For a large package with a .NET component this is the main cost difference between the two platforms.

**Installing is not the same as running: `rSharp` needs a .NET runtime.** The macOS CI job installs every OSP package from the universe without trouble, then fails during the tests, because `rSharp` calls into .NET and the `macos-latest` runner ships no usable .NET runtime:

```
── Failure ('test-ospsuite.R:2:3'): dotnet runtime is available ──
Expected `rSharp::dotnetAvailable()` to be TRUE.
── Error ('test-ospsuite.R:13:3'): the Aciclovir example simulation loads ──
Error: The .NET runtime could not be initialised.
rSharp is installed, but calls into .NET will fail until a working runtime is available.
Install .NET 8: ...  Details: Failure: load_hostfxr()
```

Windows passes because its runner has a compatible .NET; macOS does not. Adding a `.NET 8` install step (`actions/setup-dotnet`) fixes it: with that one step the macOS job goes green while nothing else changes. This is worth separating clearly: the universe resolution and download work on every platform, but *using* the OSP packages needs the .NET 8 runtime present, which is a machine prerequisite independent of how the packages were obtained.

**The universe route does not require the upstream machinery.** The production OSP packages resolve dependencies through a dedicated reusable-workflows repository that pins and unpins the `Remotes:` field on every pull request. None of that is needed simply to install from the universe; the one `extra-repositories` line above is sufficient for a downstream package.

**The OSP reusable workflow can be reused directly, with one caveat.** A downstream package can call the workflow instead of writing its own, and get the OSP-specific setup for free:

```yaml
jobs:
  R-CMD-check:
    uses: Open-Systems-Pharmacology/Workflows/.github/workflows/R-CMD-check-build.yaml@main
```

It exposes inputs for `os-matrix`, `dotnet-version` (defaulting to `8.0.x`, so the .NET runtime problem above is handled out of the box), `extra-packages`, and a few others. To supply the OSP dependencies through it there are two working routes: a `Remotes:` field in `DESCRIPTION` (the upstream default), or the OSP GitHub refs passed via the `extra-packages` input (for a package without renv, that input is forwarded to `setup-r-dependencies`, which accepts `owner/repo` refs). The **caveat** is the R-universe: the workflow exposes no `extra-repositories` input and does not put the universe on `repos`, so the universe route specifically is not reachable through it. That is the one reason this repository inlines a flattened copy of the workflow (see [`.github/workflows/pull-request.yaml`](.github/workflows/pull-request.yaml)) and adds `extra-repositories` itself: to keep the universe resolution while borrowing the .NET setup and check flags. If you resolve via `Remotes:` or `extra-packages` instead, call the reusable workflow directly and skip the copy.

**A `Remotes:` field is a fallback source, not an override.** Suppose you want to develop against the *development* version of one dependency, e.g. `ospsuite.plots` from GitHub rather than the released build the universe serves. The [R Packages book](https://r-pkgs.org/dependencies-in-practice.html#depending-on-the-development-version-of-a-package) prescribes two coordinated edits (made by `usethis::use_dev_package()`): a `Remotes:` entry for the GitHub repo, *and* a minimum-version floor in `Imports` that only the dev build satisfies, e.g. `ospsuite.plots (>= 1.3.0.9001)`. The floor is essential: `pak` treats `Remotes:` purely as a *source hint* and will still prefer the released repository build (`1.3.0` from the universe) whenever it satisfies the requirement. Only a floor the released build fails forces `pak` to fall through to the GitHub dev build.

**Dev versions cascade across the OSP stack.** Even with the floor set correctly, `dummyosp` depending on dev `ospsuite.plots` alongside a universe-served `ospsuite` does **not** resolve. Dev `ospsuite.plots` carries its *own* `Remotes:` pinning dev `ospsuite.utils` (`1.11.1.9001`) from GitHub, which `pak` follows because that package now comes from GitHub. Meanwhile `ospsuite` still comes from the universe as a released build wanting released `ospsuite.utils` (`1.11.1`). The two requirements on `ospsuite.utils` cannot both be met, and resolution fails with `Can't install dependency ospsuite.plots (>= 1.3.0.9001)`. The practical consequence: you cannot take a single OSP package at its dev version in isolation; the dev builds pin each other, so going dev on one generally means going dev on the connected set.

## Conclusion

For its stated goal, the R-universe is a sound basis for distributing the OSP packages and resolving the dependencies between them, with clear and well-behaved boundaries.

**Distribution and inter-package resolution work.** A downstream package that lists OSP packages in `Imports` installs cleanly, with the whole OSP dependency graph (`ospsuite`, `ospsuite.plots`, `ospsuite.utils`, `rSharp`, `tlf`, ...) fetched and version-resolved automatically from the universe once it is on `repos`. This holds for a single added line, `Additional_repositories` for `R CMD check` and `extra-repositories` for CI, and needs no `Remotes:` field and no custom reusable-workflow machinery. It is confirmed end to end in continuous integration on Ubuntu, Windows, and macOS.

**The boundaries are two, and neither is a flaw in the universe.** First, binaries are platform-specific: the universe serves pre-built binaries for Windows and macOS but source for Linux, so Linux installs compile (slower, still successful). Second, and separate from distribution, *running* the OSP packages needs the .NET 8 runtime present on the machine; a runner without it (macOS by default) installs everything fine but fails at runtime until .NET is added.

**Released versus development.** The universe distributes released builds, and for the ordinary "depend on the released stack" case that is exactly what is wanted. Depending on a *development* version of one OSP package is where the universe stops being sufficient on its own: it requires the `Remotes:`-plus-version-floor mechanism, and because the OSP dev builds pin one another, a single dev dependency cascades into taking the connected set at dev. That is a property of the packages' mutual dev pinning, not of the universe, but it is the practical limit of mixing universe releases with a GitHub dev build.

**Recommendation.** Use the R-universe as the distribution and dependency-resolution channel for downstream OSP work against released versions; it is simpler and more robust than the `Remotes:`/reusable-workflow path. Reserve `Remotes:` for genuine development against unreleased OSP code, and expect it to pull the connected dev set rather than a single package. On any machine or runner that will *run* OSP models, provision the .NET 8 runtime independently of how the packages are obtained.
