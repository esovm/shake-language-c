# Changelog for shake-language-c

## v0.13.0

* Add "Asm" source language
* Add "None" OS

## v0.12.0

* Support GHC 8.4.1

## v0.11.0

* Support shake 0.16

## v0.10.1

* Add support for Linux ARMv7

## v0.10.0

* Add mkConfig function that caches dependencies

## v0.9.1

* Fix host architecture detection on Windows 10

## v0.9.0

* Add support for the Android *arm64-v8a* target architecture and drop support for specifying the toolchain version; this API breaking change requires a minimum Android NDK revision 11c

## v0.8.6

* Fix Windows host target
* Get host architecture from environment on Windows

## v0.8.3

* Allow to set linker command via `LD` environment variable

## v0.8.2

* Fix compiler and linker commands for Clang toolchain on Linux

## v0.8.1

* Use `-I` compiler flag for the `userIncludes` of `BuildFlags` and `-isystem` for `systemIncludes`; semantics should be as before for `gcc` and `clang` but `-isystem` suppresses warnings in system headers

## v0.8.0

* Refactor NMF file creation in NaCl module

## v0.7.1

* Fix compilation error with GHC 7.10 in test suite (#25)

## v0.7.0

* Add `arm64` ARM version
* Add support for `arm64` to OSX toolchains
* Fix compilation error with GHC 7.10 (#25)

## v0.6.4

* Fix Android toolchain definition for `x86` architecture

## v0.6.3

* Fix bug in `Development.Shake.Language.C.Target.OSX`: `getPlatformVersionsWithRoot` works correctly now with SDK directories without version number, as introduced by Xcode 6

## v0.6.2

Bug fix release.

## v0.6.1

Bug fix release.

## v0.6.0

### Added

* Add `Data.Default.Class.Default` instances for some data types; add dependency on package `data-default-class`.

### Changed

* Don't export the entire module `Development.Shake.Language.C.ToolChain` from `Development.Shake.Language.C`; expose `Development.Shake.Language.C.ToolChain` for toolchain writers.
* Export `Development.Shake.Language.C.Language.Language` from `Development.Shake.Language.C.BuildFlags` instead of `Development.Shake.Language.C`.
* Export `Development.Shake.Language.C.Rules` from `Development.Shake.Language.C`; hide `Development.Shake.Language.C.Rules` in Cabal file.
* **Android**: Add `libcxxabi` include directory instead of `gabi++` to include path when compiling with `libcxx`. Fixes `error: no member named '__cxa_demangle' in namespace '__cxxabiv1'`.

### Removed

* Remove `libppapi`, `libppapi_cpp`, `libnacl_io`, `libppapi_simple` from `Development.Shake.Language.C.Target.NaCl`.
* Remove `Development.Shake.Language.C.Target.archString`.

## v0.5.0

First released version.
