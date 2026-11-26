cmake_minimum_required(VERSION 4.0)

project(consumer C)

enable_testing()

find_package(foo 1 REQUIRED)

foreach(type IN ITEMS static shared)
  add_executable(${type})

  target_sources(
    ${type}
    PRIVATE
      main.c
  )

  target_link_libraries(
    ${type}
    PRIVATE
      foo::${type}
  )

  add_test(
    NAME package-${type}
    COMMAND ${type}
  )
endforeach()

# Windows has no rpath, so the shared library must be on the search path.
set_tests_properties(
  package-shared
  PROPERTIES
  ENVIRONMENT_MODIFICATION "PATH=path_list_prepend:$<TARGET_FILE_DIR:foo::shared>"
)
