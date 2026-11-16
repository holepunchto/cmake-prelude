include_guard()

function(add_library_targets name)
  set(one_value_keywords
    SHARED
    INSTALL
  )

  set(multi_value_keywords
    HEADERS
    BASE_DIRS
    SOURCES
    FEATURES
    LINK
    STATIC_LINK
    SHARED_LINK
  )

  cmake_parse_arguments(
    PARSE_ARGV 1 ARGV "" "${one_value_keywords}" "${multi_value_keywords}"
  )

  if(ARGV_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR "Unknown arguments: ${ARGV_UNPARSED_ARGUMENTS}")
  endif()

  if(ARGV_SOURCES STREQUAL "NONE")
    set(header_only ON)

    foreach(keyword IN ITEMS STATIC_LINK SHARED_LINK SHARED)
      if(DEFINED ARGV_${keyword})
        message(FATAL_ERROR "${keyword} can't be used with SOURCES NONE")
      endif()
    endforeach()
  elseif("NONE" IN_LIST ARGV_SOURCES)
    message(FATAL_ERROR "SOURCES NONE can't be combined with other sources")
  else()
    set(header_only OFF)
  endif()

  if(NOT DEFINED ARGV_SHARED)
    set(ARGV_SHARED ON)
  endif()

  if(NOT DEFINED ARGV_INSTALL)
    set(ARGV_INSTALL ON)
  endif()

  if(NOT ARGV_BASE_DIRS)
    set(ARGV_BASE_DIRS include)
  endif()

  get_property(shared GLOBAL PROPERTY TARGET_SUPPORTS_SHARED_LIBS)

  string(MAKE_C_IDENTIFIER "${name}" macro)
  string(TOUPPER "${macro}" macro)

  set(headers_link)
  set(static_link)
  set(shared_link)
  set(packages)

  foreach(library IN LISTS ARGV_LINK)
    if(library MATCHES "^(.+)::<TYPE>$")
      if(header_only)
        message(FATAL_ERROR "${library} can't be used with SOURCES NONE, name the target to link instead")
      endif()

      list(APPEND headers_link "${CMAKE_MATCH_1}::headers")
      list(APPEND static_link "${CMAKE_MATCH_1}::static")
      list(APPEND shared_link "${CMAKE_MATCH_1}::shared")
      list(APPEND packages "${CMAKE_MATCH_1}")
    else()
      list(APPEND headers_link "${library}")

      if(library MATCHES "^(.+)::(headers|static|shared)$")
        list(APPEND packages "${CMAKE_MATCH_1}")
      endif()
    endif()
  endforeach()

  add_library(${name}_headers INTERFACE)

  add_library(${name}::headers ALIAS ${name}_headers)

  set_target_properties(
    ${name}_headers
    PROPERTIES
    EXPORT_NAME headers
    EXPORT_PROPERTIES PACKAGE_VERSION
    PACKAGE_VERSION "${PROJECT_VERSION}"
  )

  target_sources(
    ${name}_headers
    INTERFACE
      FILE_SET HEADERS
      BASE_DIRS ${ARGV_BASE_DIRS}
      FILES ${ARGV_HEADERS}
  )

  target_compile_features(
    ${name}_headers
    INTERFACE
      ${ARGV_FEATURES}
  )

  target_link_libraries(
    ${name}_headers
    INTERFACE
      ${headers_link}
  )

  if(header_only)
    add_library(${name} ALIAS ${name}_headers)

    if(ARGV_INSTALL)
      install(
        TARGETS ${name}_headers
        EXPORT ${name}
        FILE_SET HEADERS
      )

      _prelude_add_to_package(${name} ${packages})
    endif()

    return()
  endif()

  add_library(${name} OBJECT)

  set_target_properties(
    ${name}
    PROPERTIES
    C_VISIBILITY_PRESET hidden
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN ON
    POSITION_INDEPENDENT_CODE ${shared}
  )

  target_sources(
    ${name}
    PRIVATE
      ${ARGV_SOURCES}
  )

  target_link_libraries(
    ${name}
    PUBLIC
      ${name}_headers
  )

  add_library(${name}_static STATIC)

  add_library(${name}::static ALIAS ${name}_static)

  set_target_properties(
    ${name}_static
    PROPERTIES
    OUTPUT_NAME ${name}
    EXPORT_NAME static
    PREFIX lib
  )

  target_sources(
    ${name}_static
    PRIVATE
      $<TARGET_OBJECTS:${name}>
  )

  target_link_libraries(
    ${name}_static
    PUBLIC
      ${name}_headers
      ${static_link}
      ${ARGV_STATIC_LINK}
  )

  set(targets ${name}_headers ${name}_static)

  if(ARGV_SHARED AND shared)
    add_library(${name}_shared SHARED)

    add_library(${name}::shared ALIAS ${name}_shared)

    set_target_properties(
      ${name}_shared
      PROPERTIES
      OUTPUT_NAME ${name}
      EXPORT_NAME shared
      C_VISIBILITY_PRESET hidden
      CXX_VISIBILITY_PRESET hidden
      VISIBILITY_INLINES_HIDDEN ON
    )

    target_sources(
      ${name}_shared
      PRIVATE
        $<TARGET_PROPERTY:${name},SOURCES>
    )

    target_compile_definitions(
      ${name}_shared
      PRIVATE
        ${macro}_BUILDING
        $<TARGET_PROPERTY:${name},COMPILE_DEFINITIONS>
      INTERFACE
        ${macro}_SHARED
    )

    target_compile_options(
      ${name}_shared
      PRIVATE
        $<TARGET_PROPERTY:${name},COMPILE_OPTIONS>
    )

    target_include_directories(
      ${name}_shared
      PRIVATE
        $<TARGET_PROPERTY:${name},INCLUDE_DIRECTORIES>
    )

    target_compile_features(
      ${name}_shared
      PRIVATE
        $<TARGET_PROPERTY:${name},COMPILE_FEATURES>
    )

    target_link_libraries(
      ${name}_shared
      PUBLIC
        ${name}_headers
        ${shared_link}
        ${ARGV_SHARED_LINK}
    )

    list(APPEND targets ${name}_shared)
  endif()

  if(NOT ARGV_INSTALL)
    return()
  endif()

  install(
    TARGETS ${targets}
    EXPORT ${name}
    FILE_SET HEADERS
  )

  set_property(GLOBAL PROPERTY _prelude_${name}_libraries ON)

  _prelude_add_to_package(${name} ${packages})
endfunction()

function(add_executable_target name)
  set(one_value_keywords
    TYPE
    INSTALL
    DESTINATION
    STRIP
    EXPORTS_FILE
  )

  set(multi_value_keywords
    SOURCES
    LINK
    EXPORTS
    RPATH
  )

  cmake_parse_arguments(
    PARSE_ARGV 1 ARGV "" "${one_value_keywords}" "${multi_value_keywords}"
  )

  if(ARGV_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR "Unknown arguments: ${ARGV_UNPARSED_ARGUMENTS}")
  endif()

  include(GNUInstallDirs)

  if(NOT ARGV_TYPE)
    set(ARGV_TYPE STATIC)
  endif()

  if(NOT ARGV_TYPE MATCHES "^(STATIC|SHARED)$")
    message(FATAL_ERROR "Unknown type: ${ARGV_TYPE}")
  endif()

  if(NOT DEFINED ARGV_INSTALL)
    set(ARGV_INSTALL ON)
  endif()

  if(NOT ARGV_DESTINATION)
    set(ARGV_DESTINATION "${CMAKE_INSTALL_BINDIR}")
  endif()

  if(NOT DEFINED ARGV_STRIP)
    set(ARGV_STRIP ON)
  endif()

  if(NOT DEFINED ARGV_RPATH)
    cmake_path(ABSOLUTE_PATH ARGV_DESTINATION BASE_DIRECTORY "${CMAKE_INSTALL_PREFIX}" OUTPUT_VARIABLE destination)
    cmake_path(RELATIVE_PATH CMAKE_INSTALL_FULL_LIBDIR BASE_DIRECTORY "${destination}" OUTPUT_VARIABLE ARGV_RPATH)
  endif()

  if(ARGV_EXPORTS_FILE)
    cmake_path(ABSOLUTE_PATH ARGV_EXPORTS_FILE NORMALIZE)

    file(STRINGS "${ARGV_EXPORTS_FILE}" symbols)

    list(APPEND ARGV_EXPORTS ${symbols})

    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${ARGV_EXPORTS_FILE}")
  endif()

  string(TOLOWER "${ARGV_TYPE}" type)

  list(TRANSFORM ARGV_LINK REPLACE "::<TYPE>$" "::${type}")

  set(target ${name}_executable)

  add_executable(${target})

  add_executable(${name}::executable ALIAS ${target})

  set_target_properties(
    ${target}
    PROPERTIES
    OUTPUT_NAME ${name}
    EXPORT_NAME executable
  )

  target_sources(
    ${target}
    PRIVATE
      ${ARGV_SOURCES}
  )

  target_link_libraries(
    ${target}
    PRIVATE
      ${ARGV_LINK}
  )

  get_property(shared GLOBAL PROPERTY TARGET_SUPPORTS_SHARED_LIBS)

  if(ARGV_EXPORTS AND shared)
    _prelude_export_symbols(${target} ${ARGV_EXPORTS})
  endif()

  if(ARGV_STRIP)
    if(APPLE)
      target_link_options(
        ${target}
        PRIVATE
          $<$<CONFIG:Release,MinSizeRel>:-Wl,-dead_strip,-S,-x>
      )
    elseif(NOT WIN32)
      target_link_options(
        ${target}
        PRIVATE
          $<$<CONFIG:Release,MinSizeRel>:-Wl,--gc-sections,--strip-all>
      )
    endif()
  endif()

  if(ARGV_RPATH AND shared AND NOT WIN32)
    if(APPLE)
      set(origin "@loader_path")
    else()
      set(origin "$ORIGIN")
    endif()

    set(rpath)

    foreach(path IN LISTS ARGV_RPATH)
      if(IS_ABSOLUTE "${path}")
        list(APPEND rpath "${path}")
      else()
        list(APPEND rpath "${origin}/${path}")
      endif()
    endforeach()

    set_target_properties(
      ${target}
      PROPERTIES
      INSTALL_RPATH "${rpath}"
    )

    # Store the rpath as RPATH rather than RUNPATH, as only the former also
    # applies to the dependencies of the libraries that the executable loads.
    if(LINUX)
      target_link_options(
        ${target}
        PRIVATE
          -Wl,--disable-new-dtags
      )
    endif()
  endif()

  if(NOT ARGV_INSTALL)
    return()
  endif()

  install(
    TARGETS ${target}
    EXPORT ${name}
    RUNTIME DESTINATION "${ARGV_DESTINATION}"
  )

  _prelude_add_to_package(${name})
endfunction()

function(_prelude_export_symbols target)
  set(symbols ${ARGN})

  set(file "${CMAKE_CURRENT_BINARY_DIR}/${target}")

  if(WIN32)
    list(JOIN symbols "\n  " symbols)

    file(CONFIGURE OUTPUT "${file}.def" CONTENT "EXPORTS\n  ${symbols}\n" @ONLY)

    target_sources(
      ${target}
      PRIVATE
        "${file}.def"
    )

    set_target_properties(
      ${target}
      PROPERTIES
      ENABLE_EXPORTS ON
    )
  elseif(APPLE)
    list(TRANSFORM symbols PREPEND "_")
    list(JOIN symbols "\n" symbols)

    file(CONFIGURE OUTPUT "${file}.exp" CONTENT "${symbols}\n" @ONLY)

    set_target_properties(
      ${target}
      PROPERTIES
      ENABLE_EXPORTS ON
      LINK_DEPENDS "${file}.exp"
    )

    target_link_options(
      ${target}
      PRIVATE
        "-Wl,-exported_symbols_list,${file}.exp"
    )
  else()
    list(JOIN symbols ";\n  " symbols)

    file(CONFIGURE OUTPUT "${file}.dynamic" CONTENT "{\n  ${symbols};\n};\n" @ONLY)

    set_target_properties(
      ${target}
      PROPERTIES
      LINK_DEPENDS "${file}.dynamic"
    )

    target_link_options(
      ${target}
      PRIVATE
        "-Wl,--dynamic-list=${file}.dynamic"
    )
  endif()
endfunction()

function(_prelude_add_to_package package)
  set_property(GLOBAL APPEND PROPERTY _prelude_${package}_dependencies ${ARGN})

  get_property(scheduled GLOBAL PROPERTY _prelude_${package}_scheduled)

  if(scheduled)
    return()
  endif()

  set_property(GLOBAL PROPERTY _prelude_${package}_scheduled ON)

  # Write the package once the project's top-level directory is processed, so
  # that every target added to it, in any directory, is known by then.
  cmake_language(
    EVAL CODE
    "cmake_language(DEFER DIRECTORY [[${PROJECT_SOURCE_DIR}]] CALL _prelude_install_package [[${package}]])"
  )
endfunction()

function(_prelude_install_package package)
  include(GNUInstallDirs)

  set(destination "${CMAKE_INSTALL_LIBDIR}/cmake/${package}")

  install(
    EXPORT ${package}
    FILE ${package}-targets.cmake
    NAMESPACE ${package}::
    DESTINATION "${destination}"
  )

  get_property(dependencies GLOBAL PROPERTY _prelude_${package}_dependencies)

  list(REMOVE_DUPLICATES dependencies)

  set(config)

  if(dependencies)
    string(APPEND config "include(CMakeFindDependencyMacro)\n\n")

    foreach(dependency IN LISTS dependencies)
      string(APPEND config "find_dependency(${dependency} $<TARGET_PROPERTY:${dependency}::headers,PACKAGE_VERSION>)\n")
    endforeach()

    string(APPEND config "\n")
  endif()

  string(APPEND config "include(\"\${CMAKE_CURRENT_LIST_DIR}/${package}-targets.cmake\")\n")

  file(
    GENERATE
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${package}-config.cmake"
    CONTENT "${config}"
  )

  get_property(libraries GLOBAL PROPERTY _prelude_${package}_libraries)

  if(libraries)
    set(libraries ON)
  else()
    set(libraries OFF)
  endif()

  file(
    CONFIGURE
    OUTPUT ${package}-config-version.cmake
    CONTENT [=[
set(PACKAGE_VERSION "@PROJECT_VERSION@")

if(PACKAGE_FIND_VERSION STREQUAL "")
  set(PACKAGE_VERSION_COMPATIBLE TRUE)
elseif(PACKAGE_FIND_VERSION_RANGE)
  if(PACKAGE_VERSION VERSION_LESS PACKAGE_FIND_VERSION_MIN)
    set(PACKAGE_VERSION_COMPATIBLE FALSE)
  elseif(PACKAGE_FIND_VERSION_RANGE_MAX STREQUAL "INCLUDE" AND PACKAGE_VERSION VERSION_GREATER PACKAGE_FIND_VERSION_MAX)
    set(PACKAGE_VERSION_COMPATIBLE FALSE)
  elseif(PACKAGE_FIND_VERSION_RANGE_MAX STREQUAL "EXCLUDE" AND PACKAGE_VERSION VERSION_GREATER_EQUAL PACKAGE_FIND_VERSION_MAX)
    set(PACKAGE_VERSION_COMPATIBLE FALSE)
  else()
    set(PACKAGE_VERSION_COMPATIBLE TRUE)
  endif()
elseif(PACKAGE_VERSION VERSION_LESS PACKAGE_FIND_VERSION)
  set(PACKAGE_VERSION_COMPATIBLE FALSE)
else()
  # Like the ^ range of npm, lock the requested components up to and including
  # the first one that isn't zero.
  set(PACKAGE_VERSION_COMPATIBLE TRUE)

  string(REPLACE "." ";" components "${PACKAGE_VERSION}")

  list(LENGTH components length)

  set(index 0)

  foreach(name IN ITEMS MAJOR MINOR PATCH TWEAK)
    if(index EQUAL PACKAGE_FIND_VERSION_COUNT)
      break()
    endif()

    set(component 0)

    if(index LESS length)
      list(GET components ${index} component)
    endif()

    if(NOT component EQUAL PACKAGE_FIND_VERSION_${name})
      set(PACKAGE_VERSION_COMPATIBLE FALSE)
      break()
    endif()

    if(NOT PACKAGE_FIND_VERSION_${name} EQUAL 0)
      break()
    endif()

    math(EXPR index "${index} + 1")
  endforeach()
endif()

if(PACKAGE_FIND_VERSION STREQUAL PACKAGE_VERSION)
  set(PACKAGE_VERSION_EXACT TRUE)
endif()

# Libraries built for a different pointer size can't be linked.
if(@libraries@ AND NOT CMAKE_SIZEOF_VOID_P STREQUAL "" AND NOT CMAKE_SIZEOF_VOID_P STREQUAL "@CMAKE_SIZEOF_VOID_P@")
  set(PACKAGE_VERSION_UNSUITABLE TRUE)
endif()
]=]
    @ONLY
  )

  install(
    FILES
      "${CMAKE_CURRENT_BINARY_DIR}/${package}-config.cmake"
      "${CMAKE_CURRENT_BINARY_DIR}/${package}-config-version.cmake"
    DESTINATION "${destination}"
  )
endfunction()
