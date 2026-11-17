include_guard()

function(add_library_targets name)
  set(one_value_keywords
    INSTALL
    EXPORT
    EXPORTS_FROM
    STRIP
  )

  set(multi_value_keywords
    HEADERS
    BASE_DIRS
    SOURCES
    FEATURES
    LINK
    TYPE
    EXPORTS
  )

  cmake_parse_arguments(
    PARSE_ARGV 1 ARGV "" "${one_value_keywords}" "${multi_value_keywords}"
  )

  if(ARGV_SOURCES STREQUAL "NONE")
    set(header_only ON)

    foreach(keyword IN ITEMS TYPE EXPORTS EXPORTS_FROM STRIP)
      if(DEFINED ARGV_${keyword})
        message(FATAL_ERROR "${keyword} can't be used with SOURCES NONE")
      endif()
    endforeach()
  elseif("NONE" IN_LIST ARGV_SOURCES)
    message(FATAL_ERROR "SOURCES NONE can't be combined with other sources")
  else()
    set(header_only OFF)
  endif()

  if(NOT DEFINED ARGV_TYPE)
    set(ARGV_TYPE STATIC SHARED)
  endif()

  foreach(type IN LISTS ARGV_TYPE)
    if(NOT type MATCHES "^(STATIC|SHARED)$")
      message(FATAL_ERROR "Unknown type: ${type}")
    endif()
  endforeach()

  if(NOT DEFINED ARGV_INSTALL)
    set(ARGV_INSTALL ON)
  endif()

  if(NOT DEFINED ARGV_EXPORT)
    set(ARGV_EXPORT ON)
  endif()

  if(ARGV_EXPORT)
    set(export EXPORT ${name})
  else()
    set(export)
  endif()

  if(NOT ARGV_BASE_DIRS)
    set(ARGV_BASE_DIRS include)
  endif()

  get_property(shared GLOBAL PROPERTY TARGET_SUPPORTS_SHARED_LIBS)

  set(types)

  if(NOT header_only)
    if("STATIC" IN_LIST ARGV_TYPE)
      list(APPEND types static)
    endif()

    if("SHARED" IN_LIST ARGV_TYPE)
      if(shared)
        list(APPEND types shared)
      elseif(NOT "STATIC" IN_LIST ARGV_TYPE)
        message(FATAL_ERROR "Shared libraries aren't supported by the target platform")
      endif()
    endif()
  endif()

  string(MAKE_C_IDENTIFIER "${name}" macro)
  string(TOUPPER "${macro}" macro)

  set(headers_link)
  set(object_link)
  set(packages)

  foreach(type IN ITEMS static shared)
    foreach(scope IN ITEMS public private interface)
      set(${type}_${scope}_link)
    endforeach()

    set(${type}_embed)
  endforeach()

  # A run of keywords sets the type and scope of the entries that follow it,
  # starting from both types and PUBLIC.
  set(keywords OFF)
  set(link_type)
  set(link_scope)

  foreach(library IN LISTS ARGV_LINK)
    if(library MATCHES "^(PUBLIC|PRIVATE|INTERFACE|EMBED)$")
      if(NOT keywords)
        set(keywords ON)
        set(link_type)
        set(link_scope)
      endif()

      if(link_scope)
        message(FATAL_ERROR "${library} can't follow ${link_scope}")
      endif()

      set(link_scope ${library})

      continue()
    endif()

    if(library MATCHES "^(STATIC|SHARED)$")
      if(NOT keywords)
        set(keywords ON)
        set(link_type)
        set(link_scope)
      endif()

      if(link_type)
        message(FATAL_ERROR "${library} can't follow ${link_type}")
      endif()

      set(link_type ${library})

      continue()
    endif()

    set(keywords OFF)

    if(NOT link_scope)
      set(scope public)
    else()
      string(TOLOWER "${link_scope}" scope)
    endif()

    if(header_only)
      if(link_type)
        message(FATAL_ERROR "${link_type} can't be used with SOURCES NONE")
      endif()

      if(scope MATCHES "^(private|embed)$")
        message(FATAL_ERROR "${link_scope} can't be used with SOURCES NONE")
      endif()

      if(library MATCHES "^(.+)::<TYPE>$")
        message(FATAL_ERROR "${library} can't be used with SOURCES NONE, name the target to link instead")
      endif()

      list(APPEND headers_link "${library}")

      if(library MATCHES "^(.+)::(headers|static|shared)$")
        list(APPEND packages "${CMAKE_MATCH_1}")
      endif()

      continue()
    endif()

    if(link_type)
      string(TOLOWER "${link_type}" link_types)
    else()
      set(link_types static shared)
    endif()

    if(scope STREQUAL "embed")
      if(library MATCHES "::<TYPE>$")
        message(FATAL_ERROR "${library} can't be embedded, name the target to embed instead")
      endif()

      foreach(type IN LISTS link_types)
        list(APPEND ${type}_embed "${library}")
      endforeach()

      if("static" IN_LIST link_types)
        list(APPEND object_link "$<COMPILE_ONLY:${library}>")
      endif()

      continue()
    endif()

    if(library MATCHES "^(.+)::<TYPE>$")
      set(package "${CMAKE_MATCH_1}")
      set(compile "${package}::headers")
      set(typed ON)

      list(APPEND packages "${package}")
    else()
      set(package)
      set(compile "${library}")
      set(typed OFF)

      if(library MATCHES "^(.+)::(headers|static|shared)$")
        list(APPEND packages "${CMAKE_MATCH_1}")
      endif()
    endif()

    if(scope STREQUAL "public" AND NOT link_type)
      list(APPEND headers_link "${compile}")
    elseif(NOT scope STREQUAL "interface" AND "static" IN_LIST link_types)
      list(APPEND object_link "${compile}")
    endif()

    foreach(type IN LISTS link_types)
      if(typed)
        set(target "${package}::${type}")
      else()
        set(target "${library}")
      endif()

      if(scope STREQUAL "public" AND NOT link_type AND NOT typed)
        continue()
      endif()

      list(APPEND ${type}_${scope}_link "${target}")
    endforeach()
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

  if(ARGV_HEADERS)
    target_sources(
      ${name}_headers
      INTERFACE
        FILE_SET HEADERS
        BASE_DIRS ${ARGV_BASE_DIRS}
        FILES ${ARGV_HEADERS}
    )
  endif()

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
      _prelude_install_targets(
        ${name}_headers
        ${export}
        FILE_SET HEADERS
      )

      if(ARGV_EXPORT)
        _prelude_add_to_package(${name} ${packages})
      endif()
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

  # Without a static library, the object library only holds the settings that
  # the shared library follows, so there's nothing to build.
  if(NOT "static" IN_LIST types)
    set_target_properties(
      ${name}
      PROPERTIES
      EXCLUDE_FROM_ALL ON
    )
  endif()

  target_sources(
    ${name}
    PRIVATE
      ${ARGV_SOURCES}
  )

  target_link_libraries(
    ${name}
    PUBLIC
      ${name}_headers
    PRIVATE
      ${object_link}
  )

  set(targets ${name}_headers)

  if("static" IN_LIST types)
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
        ${static_public_link}
      PRIVATE
        ${static_private_link}
      INTERFACE
        ${static_interface_link}
    )

    _prelude_embed(${name}_static ${static_embed})

    list(APPEND targets ${name}_static)
  endif()

  if("shared" IN_LIST types)
    add_library(${name}_shared SHARED)

    add_library(${name}::shared ALIAS ${name}_shared)

    set_target_properties(
      ${name}_shared
      PROPERTIES
      OUTPUT_NAME ${name}
      EXPORT_NAME shared
      ENABLE_EXPORTS ON
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
        ${shared_public_link}
      PRIVATE
        ${shared_private_link}
      INTERFACE
        ${shared_interface_link}
    )

    _prelude_embed(${name}_shared ${shared_embed})

    if(ARGV_STRIP)
      _prelude_strip(${name}_shared)
    endif()

    list(APPEND targets ${name}_shared)
  endif()

  if(ARGV_EXPORTS_FROM)
    _prelude_read_exports("${ARGV_EXPORTS_FROM}" symbols)

    list(APPEND ARGV_EXPORTS ${symbols})
  endif()

  if(ARGV_EXPORTS)
    _prelude_add_exports_target(${name} ${ARGV_EXPORTS})

    if("shared" IN_LIST types)
      target_link_libraries(
        ${name}_shared
        PRIVATE
          ${name}_exports
      )
    endif()
  endif()

  if(NOT ARGV_INSTALL)
    return()
  endif()

  _prelude_install_targets(
    ${targets}
    ${export}
    FILE_SET HEADERS
  )

  if(NOT ARGV_EXPORT)
    return()
  endif()

  set_property(GLOBAL PROPERTY _prelude_${name}_libraries ON)

  _prelude_add_to_package(${name} ${packages})
endfunction()

function(add_executable_target name)
  set(one_value_keywords
    TYPE
    INSTALL
    EXPORT
    DESTINATION
    OUTPUT_DIRECTORY
    STRIP
    EXPORTS_FROM
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

  if(NOT DEFINED ARGV_EXPORT)
    set(ARGV_EXPORT ON)
  endif()

  if(ARGV_EXPORT)
    set(export EXPORT ${name})
  else()
    set(export)
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

  if(ARGV_EXPORTS_FROM)
    _prelude_read_exports("${ARGV_EXPORTS_FROM}" symbols)

    list(APPEND ARGV_EXPORTS ${symbols})
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

  if(ARGV_OUTPUT_DIRECTORY)
    cmake_path(ABSOLUTE_PATH ARGV_OUTPUT_DIRECTORY BASE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}" NORMALIZE)

    # The import library of an executable with exports is an archive rather
    # than a runtime file, so it needs moving too to not collide with that of a
    # library of the same name.
    set_target_properties(
      ${target}
      PROPERTIES
      RUNTIME_OUTPUT_DIRECTORY "${ARGV_OUTPUT_DIRECTORY}"
      ARCHIVE_OUTPUT_DIRECTORY "${ARGV_OUTPUT_DIRECTORY}"
    )
  endif()

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
    _prelude_strip(${target})
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

  _prelude_install_targets(
    ${target}
    ${export}
    RUNTIME DESTINATION "${ARGV_DESTINATION}"
  )

  if(ARGV_EXPORT)
    _prelude_add_to_package(${name})
  endif()
endfunction()

# Removes unused code and the symbols that aren't exported from release builds.
function(_prelude_strip target)
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
endfunction()

# Install the targets once the calling directory is processed, as install() only
# considers the properties that the targets have when it's called. Properties
# set after creating the targets, such as ENABLE_EXPORTS, are then respected.
function(_prelude_install_targets)
  set(arguments)

  # Deferred calls only evaluate their arguments once they run, so pass them
  # as bracket arguments evaluated now.
  foreach(argument IN LISTS ARGN)
    string(APPEND arguments " [==[${argument}]==]")
  endforeach()

  cmake_language(EVAL CODE "cmake_language(DEFER CALL install TARGETS${arguments})")
endfunction()

# Builds the objects of each target into the library, along with the link
# dependencies they need. The dependencies are read when the library is
# created, so that an installed package names them instead of the embedded
# target. A shared library also compiles its own sources, so it needs the
# compile settings of each target as well.
function(_prelude_embed library)
  get_target_property(type ${library} TYPE)

  foreach(target IN LISTS ARGN)
    if(NOT TARGET ${target})
      message(FATAL_ERROR "${target} must be created before it's embedded")
    endif()

    get_target_property(dependencies ${target} INTERFACE_LINK_LIBRARIES)

    if(NOT dependencies)
      set(dependencies)
    endif()

    target_sources(
      ${library}
      PRIVATE
        $<TARGET_OBJECTS:${target}>
    )

    target_link_libraries(
      ${library}
      PRIVATE
        ${dependencies}
    )

    if(type STREQUAL "SHARED_LIBRARY")
      target_link_libraries(
        ${library}
        PRIVATE
          $<COMPILE_ONLY:${target}>
      )
    endif()
  endforeach()
endfunction()

# Reads a list of symbols from a JSON array of strings, or from a file with one
# symbol per line.
function(_prelude_read_exports file result)
  cmake_path(ABSOLUTE_PATH file NORMALIZE)

  set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${file}")

  if(file MATCHES "\\.json$")
    file(READ "${file}" json)

    string(JSON length LENGTH "${json}")

    set(symbols)

    if(length GREATER 0)
      math(EXPR last "${length} - 1")

      foreach(i RANGE ${last})
        string(JSON symbol GET "${json}" ${i})

        list(APPEND symbols "${symbol}")
      endforeach()
    endif()
  else()
    file(STRINGS "${file}" symbols)
  endif()

  set(${result} ${symbols} PARENT_SCOPE)
endfunction()

# Creates an interface target that limits the exports of whatever links it to
# the given symbols.
function(_prelude_add_exports_target name)
  set(target ${name}_exports)
  set(symbols ${ARGN})

  add_library(${target} INTERFACE)

  add_library(${name}::exports ALIAS ${target})

  set(file "${CMAKE_CURRENT_BINARY_DIR}/${name}")

  set(executable "$<STREQUAL:$<TARGET_PROPERTY:TYPE>,EXECUTABLE>")

  if(WIN32)
    set(options ${symbols})

    list(TRANSFORM options PREPEND "/EXPORT:")
    list(JOIN options "\n" options)
    list(JOIN symbols "\n  " symbols)

    file(CONFIGURE OUTPUT "${file}.def" CONTENT "EXPORTS\n  ${symbols}\n" @ONLY)
    file(CONFIGURE OUTPUT "${file}.rsp" CONTENT "${options}\n" @ONLY)

    # CMake only applies module definition files to executables that have
    # ENABLE_EXPORTS, so executables are given the exports as linker options
    # instead, read from a response file to keep the command line short.
    target_sources(
      ${target}
      INTERFACE
        "$<$<NOT:${executable}>:${file}.def>"
    )

    target_link_options(
      ${target}
      INTERFACE
        "$<${executable}:@${file}.rsp>"
    )

    set(file "$<IF:${executable},${file}.rsp,${file}.def>")
  elseif(APPLE)
    set(file "${file}.exp")

    list(TRANSFORM symbols PREPEND "_")
    list(JOIN symbols "\n" symbols)

    file(CONFIGURE OUTPUT "${file}" CONTENT "${symbols}\n" @ONLY)

    target_link_options(
      ${target}
      INTERFACE
        "-Wl,-exported_symbols_list,${file}"
    )
  else()
    list(JOIN symbols ";\n    " symbols)

    # Shared libraries hide everything else with a version script, while
    # executables only export what a dynamic list names.
    file(CONFIGURE OUTPUT "${file}.map" CONTENT "{\n  global:\n    ${symbols};\n\n  local:\n    *;\n};\n" @ONLY)
    file(CONFIGURE OUTPUT "${file}.dynamic" CONTENT "{\n    ${symbols};\n};\n" @ONLY)

    set(file "$<IF:${executable},${file}.dynamic,${file}.map>")

    target_link_options(
      ${target}
      INTERFACE
        "$<IF:${executable},-Wl$<COMMA>--dynamic-list=,-Wl$<COMMA>--version-script=>${file}"
    )
  endif()

  set_target_properties(
    ${target}
    PROPERTIES
    INTERFACE_LINK_DEPENDS "${file}"
  )
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
