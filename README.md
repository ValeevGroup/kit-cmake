# kit-cmake
cmake modules and toolchains

## FindOrFetchBoost

`modules/FindOrFetchBoost.cmake` imports Boost for a project, or builds it from source.

- **Found Boost**: `find_package(Boost ${Boost_OLDEST_BOOST_VERSION} CONFIG)` — any Boost >= 1.81 that ships
  `BoostConfig.cmake` (b2 installs, distro packages, Homebrew, vcpkg, Boost installed by this module).
  `Boost::X` is defined for every found component `X` (component `test` is target `Boost::unit_test_framework`);
  for header-only components of b2-built Boost older than 1.92 the module defines `Boost::X` linking `Boost::headers`,
  as Boost 1.92's own b2 configs do.
- **Fetched Boost**: if no Boost is found and `Boost_FETCH_IF_MISSING` is ON, Boost 1.92.0 is built from source via
  FetchContent. All of Boost is configured, so subprojects of a superbuild can use any library; the libraries requested
  by any project (plus their dependencies) are built and installed along with the project, together with
  `BoostConfig.cmake`, so the install can later be found like any other Boost.
- **Errors** (no fallback to fetching): a found Boost lacking a required component; an install made by an older version
  of this module (per-library `boost_X` configs only, no `BoostConfig.cmake`) — reinstall it with the current kit.

Inputs: `Boost_REQUIRED_COMPONENTS`, `Boost_OPTIONAL_COMPONENTS`, `Boost_OLDEST_BOOST_VERSION`, `Boost_FETCH_IF_MISSING`,
`BOOST_EXCLUDE_LIBRARIES`; hints `Boost_ROOT`/`BOOST_ROOT`, `BOOST_INCLUDEDIR`.
Outputs: `Boost_BUILT_FROM_SOURCE`, `Boost_USE_CONFIG`, `Boost_CONFIG`, `Boost_IS_MODULARIZED` (ON),
`Boost_FOUND_COMPONENTS`, `Boost_FOUND_TARGETS`, `Boost_CONFIG_FILE_CONTENTS` (paste into the project's package config
file to re-import the same Boost), `Boost_MODULAR_TARGETS_NOT_BUILT_BY_INSTALL` (now always empty).

Tests: `cmake -S tests -B build-tests && ctest --test-dir build-tests -L hermetic` (fast); labels `fetch` (downloads and
builds Boost) and `system` (the installed Boost; pass `-DSYSTEM_BOOST_PREFIX=...` for a non-default location).
