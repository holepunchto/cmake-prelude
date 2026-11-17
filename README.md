# cmake-prelude

```
npm i cmake-prelude
```

```cmake
find_package(cmake-prelude REQUIRED PATHS node_modules/cmake-prelude)
```

## API

#### `add_library_targets(<name> [HEADERS <files>...] [BASE_DIRS <dirs>...] [SOURCES <files>...] [FEATURES <features>...] [LINK <libraries>...] [TYPE STATIC|SHARED...] [EXPORTS <symbols>...] [EXPORTS_FILE <path>] [INSTALL <bool>] [EXPORT <bool>])`

Creates the targets of a library:

- `<name>_headers`, aliased as `<name>::headers`, holds the public headers and compile features. `BASE_DIRS` defaults to `include`. Without `HEADERS`, no headers are added, so they can instead be added after the call with `target_sources(<name>_headers INTERFACE FILE_SET HEADERS ...)`, such as when they come from another project.
- `<name>` is an object library that compiles the sources.
- `<name>_static`, aliased as `<name>::static`, is a static library built from the objects of `<name>`.
- `<name>_shared`, aliased as `<name>::shared`, is a shared library.

`TYPE` lists the libraries to create and defaults to `STATIC SHARED`. On platforms without shared libraries, the shared library is left out, unless `TYPE` asks for only a shared library, which is then an error.

Symbols are hidden by default. The shared library is compiled with `<NAME>_BUILDING` defined, and its consumers see `<NAME>_SHARED`, where `<NAME>` is the upper case name of the library. Public headers use these to mark exported symbols.

`LINK` entries are linked with a type and a scope, which the keywords `STATIC` or `SHARED`, and `PUBLIC`, `PRIVATE`, `INTERFACE`, or `EMBED`, set for the entries that follow them. Each run of keywords starts over from both libraries and `PUBLIC`:

```cmake
LINK
  utf::<TYPE>
  PRIVATE
    v8
  STATIC
    uv_a
  SHARED
    uv
```

The scopes work like those of `target_link_libraries()`. `PUBLIC` entries for both libraries are linked to `<name>::headers`, which every target links. `PRIVATE` entries are linked to `<name>`, to compile it, and to the libraries, but not to their consumers, except as link dependencies of the static library. `INTERFACE` entries are linked to the consumers of the libraries only. Entries for one library type only reach that library, and `<name>` if it's the static library, as that library is built from the objects of `<name>`. Entries for a library that isn't created are left out.

`EMBED` entries name targets whose objects are built into the libraries, such as object libraries, or static libraries that should not be installed alongside. The libraries are compiled with their compile settings and linked with their link dependencies, which the static library passes on to its consumers. The targets must exist when `add_library_targets()` is called, and don't become dependencies of the installed package.

Entries of the form `<package>::<TYPE>` link `<package>::static` or `<package>::shared` to the matching library, and `<package>::headers` wherever headers are needed. Entries of the form `<package>::headers` are header-only dependencies. Use `$<COMPILE_ONLY:<target>>` for header-only dependencies that don't follow the `<package>::headers` convention. All entries that name a `<package>::` target become dependencies of the installed package, which requires a version of each dependency compatible with the one it was built against.

`EXPORTS` and `EXPORTS_FILE`, a JSON array of strings or a file with one symbol per line, list the symbols the shared library exports. Other symbols are not exported, even those of embedded targets, and only symbols with default visibility can be exported. They also create `<name>_exports`, aliased as `<name>::exports`, which limits the exports of the executables and shared libraries that link it to the same symbols, such as those that embed the static library.

To add a dependency after the call, such as one for a single platform, link it to `<name>_headers` with `target_link_libraries(<name>_headers INTERFACE ...)`, which reaches every target in the same way. Linking it to `<name>` instead would not reach the static and shared library.

Unless `INSTALL` is off, the libraries and headers are installed, and unless `EXPORT` is also off, added to the `<name>` package. They are installed once the calling directory has been processed, so properties that change what gets installed, such as `ENABLE_EXPORTS`, can still be set after the call.

For a header-only library, pass `SOURCES NONE`. Only `<name>_headers` is then created, which `<name>` also refers to. `TYPE`, `EXPORTS`, `EXPORTS_FILE`, the `STATIC`, `SHARED`, `PRIVATE`, and `EMBED` keywords of `LINK`, and `<package>::<TYPE>` entries can't be used with it.

The shared library compiles the same sources as `<name>` and follows its compile definitions, compile options, include directories, and compile features, including those added after the call. Configure compilation on `<name>` with the usual `target_*()` commands, such as `harden(<name>)` from `cmake-harden`. Other target properties are not followed; use `FEATURES` to require a language standard.

#### `add_executable_target(<name> [SOURCES <files>...] [LINK <libraries>...] [TYPE STATIC|SHARED] [EXPORTS <symbols>...] [EXPORTS_FILE <path>] [STRIP <bool>] [RPATH <paths>...] [INSTALL <bool>] [EXPORT <bool>] [DESTINATION <dir>] [OUTPUT_DIRECTORY <dir>])`

Creates `<name>_executable`, aliased as `<name>::executable`, with the output name `<name>`.

`OUTPUT_DIRECTORY` sets where the executable is built, along with its import library if it has exports, relative to the current build directory. Ninja names a build target after every target, so an executable built in the same directory as a target named `<name>`, such as the object library of `add_library_targets(<name>)`, collides with it. Build the executable in another directory, such as `bin`, or create it from a subdirectory.

`LINK` entries of the form `<package>::<TYPE>` link `<package>::static`, or `<package>::shared` if `TYPE` is `SHARED`.

`EXPORTS` and `EXPORTS_FILE`, a JSON array of strings or a file with one symbol per line, list the symbols the executable exports, such as those used by native addons it loads at runtime. Other symbols are not exported.

Unless `STRIP` is off, release builds remove unused code and strip symbols that aren't exported.

`RPATH` lists where to look for shared libraries at runtime, relative to the installed executable. It defaults to the library directory.

Unless `INSTALL` is off, the executable is installed to `DESTINATION`, which defaults to `CMAKE_INSTALL_BINDIR`, and unless `EXPORT` is also off, added to the `<name>` package. Like libraries, it is installed once the calling directory has been processed.

### Packages

Turn `EXPORT` off for targets that depend on targets that can't be exported, such as imported targets without a package of their own. The files are then still installed, but not as part of a package.

Libraries and executables with the same name share a package, which is installed as `<name>-config.cmake` once the project's top-level directory has been processed. It exports the `<name>::` targets, finds the dependencies of the libraries, and takes its version from the project version. Like the `^` range of npm, a requested version is compatible with newer versions up to the next change of its first non-zero component: `1.2` accepts `1.9.0` but not `2.0.0`, `0.2` accepts `0.2.9` but not `0.3.0`, and `0.0.3` accepts only `0.0.3`. Version ranges, such as `1.2...<3.0`, are taken as given.

## License

Apache-2.0
