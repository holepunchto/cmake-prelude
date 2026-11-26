cmake_minimum_required(VERSION 4.0)

find_package(cmake-prelude REQUIRED)

project(foo LANGUAGES C VERSION 1.2.3)

add_library_targets(
  foo
  HEADERS
    include/foo.h
  BASE_DIRS
    include
  SOURCES
    foo.c
  EXPORTS
    foo
)
