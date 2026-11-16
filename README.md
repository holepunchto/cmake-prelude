# cmake-prelude

```
npm i cmake-prelude
```

```cmake
find_package(cmake-prelude REQUIRED PATHS node_modules/cmake-prelude)
```

## API

#### `add_library_targets(<name> [HEADERS <files>...] [BASE_DIRS <dirs>...] [SOURCES <files>...] [FEATURES <features>...] [LINK <libraries>...] [STATIC_LINK <libraries>...] [SHARED_LINK <libraries>...] [SHARED <bool>] [INSTALL <bool>])`

Creates the targets of a library:

- `<name>_headers`, aliased as `<name>::headers`, holds the public headers and compile features. `BASE_DIRS` defaults to `include`.
- `<name>` is an object library that compiles the sources.
- `<name>_static`, aliased as `<name>::static`, is a static library built from the objects of `<name>`.
- `<name>_shared`, aliased as `<name>::shared`, is a shared library, created only when the platform supports shared libraries and `SHARED` isn't off.

Symbols are hidden by default. The shared library is compiled with `<NAME>_BUILDING` defined, and its consumers see `<NAME>_SHARED`, where `<NAME>` is the upper case name of the library. Public headers use these to mark exported symbols.

`LINK` entries of the form `<package>::<TYPE>` link `<package>::headers`, `<package>::static`, and `<package>::shared` to the matching targets, and become dependencies of the installed package. The installed package requires a version of each dependency compatible with the one it was built against. Entries of the form `<package>::headers` are header-only dependencies. Like those of the form `<package>::static` and `<package>::shared`, they also become dependencies of the installed package. These and all other `LINK` entries are linked to every target, including `<name>::headers`. Use `$<COMPILE_ONLY:<target>>` for header-only dependencies that don't follow the `<package>::headers` convention. To add a dependency after the call, such as one for a single platform, link it to `<name>_headers` with `target_link_libraries(<name>_headers INTERFACE ...)`, which reaches every target in the same way. Linking it to `<name>` instead would not reach the static and shared library. `STATIC_LINK` and `SHARED_LINK` are linked to the static and shared library only.

Unless `INSTALL` is off, the libraries and headers are installed and added to the `<name>` package.

For a header-only library, pass `SOURCES NONE`. Only `<name>_headers` is then created, which `<name>` also refers to. `STATIC_LINK`, `SHARED_LINK`, `SHARED`, and `<package>::<TYPE>` entries can't be used with it.

The shared library compiles the same sources as `<name>` and follows its compile definitions, compile options, include directories, and compile features, including those added after the call. Configure compilation on `<name>` with the usual `target_*()` commands, such as `harden(<name>)` from `cmake-harden`. Other target properties are not followed; use `FEATURES` to require a language standard.

#### `add_executable_target(<name> [SOURCES <files>...] [LINK <libraries>...] [TYPE STATIC|SHARED] [EXPORTS <symbols>...] [EXPORTS_FILE <path>] [STRIP <bool>] [RPATH <paths>...] [INSTALL <bool>] [DESTINATION <dir>])`

Creates `<name>_executable`, aliased as `<name>::executable`, with the output name `<name>`.

`LINK` entries of the form `<package>::<TYPE>` link `<package>::static`, or `<package>::shared` if `TYPE` is `SHARED`.

`EXPORTS` and `EXPORTS_FILE`, a file with one symbol per line, list the symbols the executable exports, such as those used by native addons it loads at runtime. Other symbols are not exported.

Unless `STRIP` is off, release builds remove unused code and strip symbols that aren't exported.

`RPATH` lists where to look for shared libraries at runtime, relative to the installed executable. It defaults to the library directory.

Unless `INSTALL` is off, the executable is installed to `DESTINATION`, which defaults to `CMAKE_INSTALL_BINDIR`, and added to the `<name>` package.

### Packages

Libraries and executables with the same name share a package, which is installed as `<name>-config.cmake` once the project's top-level directory has been processed. It exports the `<name>::` targets, finds the dependencies of the libraries, and takes its version from the project version. Like the `^` range of npm, a requested version is compatible with newer versions up to the next change of its first non-zero component: `1.2` accepts `1.9.0` but not `2.0.0`, `0.2` accepts `0.2.9` but not `0.3.0`, and `0.0.3` accepts only `0.0.3`. Version ranges, such as `1.2...<3.0`, are taken as given.

## License

Apache-2.0
