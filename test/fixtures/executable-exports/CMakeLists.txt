cmake_minimum_required(VERSION 4.0)

find_package(cmake-prelude REQUIRED)

project(executable_exports C)

enable_testing()

# Nothing in the executables calls into these libraries, so only the exports
# can pull in their objects.
add_library(dep STATIC)

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
  EXPORTS
    foo
  TYPE STATIC
  INSTALL OFF
)

target_include_directories(
  foo
  PRIVATE
    ..
)

add_executable_target(
  app
  SOURCES
    app.c
  LINK
    dep
    ${CMAKE_DL_LIBS}
  EXPORTS
    app
    dep
  INSTALL OFF
)

target_include_directories(
  app_executable
  PRIVATE
    ..
)

add_executable_target(
  linked
  SOURCES
    linked.c
  LINK
    foo::static
    foo::exports
    ${CMAKE_DL_LIBS}
  INSTALL OFF
)

target_include_directories(
  linked_executable
  PRIVATE
    ..
)

add_test(
  NAME executable-exports
  COMMAND app_executable
)

add_test(
  NAME executable-exports-target
  COMMAND linked_executable
)
