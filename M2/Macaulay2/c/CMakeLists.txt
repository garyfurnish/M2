cmake_minimum_required(VERSION 2.8.1)
add_compile_options(-Wall -Werror -Wno-unknown-attributes)

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -std=c99 -Wimplicit-function-declaration")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++1y")
include_directories(${CMAKE_SOURCE_DIR})
include_directories(${CMAKE_SOURCE_DIR}/../../include)
include_directories(${CMAKE_BINARY_DIR}/../../include)
include_directories(${CGC1_ROOT}/include)
FIND_PACKAGE(Boost)
include_directories(${Boost_INCLUDE_DIRS})

add_executable(scc1 scc1.cpp readfile.c error.c dictionary.c list.c cprint.cpp type.c chk.c compat.c debugging.c grammar.c)
target_link_libraries(scc1 ${CGC1_ROOT}/lib/libcgc1.a ${CGC1_ROOT}/lib/libmcppalloc_slab_allocator.a gdbm m pthread stdc++)
