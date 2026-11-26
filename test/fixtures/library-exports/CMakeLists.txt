cmake_minimum_required(VERSION 4.0)

find_package(cmake-prelude REQUIRED)

project(library_exports C)

enable_testing()

# Nothing in the library calls into this static library, so only the exports
# can pull in its objects.
add_library(dep STATIC)

set_target_properties(
  dep
  PROPERTIES
  POSITION_INDEPENDENT_CODE ON
)

target_sources(
  dep
  PRIVATE
    dep.c
)

target_include_directories(
  dep
  PRIVATE
    ..
)

add_library_targets(
  foo
  SOURCES
    foo.c
  LINK
    PRIVATE
      dep
  EXPORTS_FROM
    exports.json
  INSTALL OFF
)

target_include_directories(
  foo
  PRIVATE
    ..
)

add_executable(check)

target_sources(
  check
  PRIVATE
    check.c
)

target_include_directories(
  check
  PRIVATE
    ..
)

target_link_libraries(
  check
  PRIVATE
    ${CMAKE_DL_LIBS}
)

add_test(
  NAME library-exports
  COMMAND check $<TARGET_FILE:foo_shared>
)
