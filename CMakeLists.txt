cmake_minimum_required(VERSION 3.25)
project(rockband3deluxe LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
include(cmake/ReXGlue.cmake)

add_executable(rockband3deluxe WIN32
    src/main.cpp
    src/math_compat.cpp
    src/guitar_input.cpp
    src/input_lock.cpp
    src/physical_input.cpp
    src/network_compat.cpp
    src/random_compat.cpp
    src/precise_sleep.cpp
    src/windows_audio.cpp
    src/file_trace.cpp
)
rexglue_setup_target(rockband3deluxe GPU_PLUGINS xenos)
target_link_options(rockband3deluxe PRIVATE /DEBUG /OPT:REF /OPT:ICF)

add_library(beatles-input SHARED src/controller_bridge.cpp)
target_link_libraries(beatles-input PRIVATE SDL3::SDL3-static)
target_compile_definitions(beatles-input PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
target_link_libraries(rockband3deluxe PRIVATE beatles-input bcrypt synchronization xaudio2 ole32)

add_executable(rb3-content src/content_import.cpp)
target_link_libraries(rb3-content PRIVATE rex::runtime)
target_compile_definitions(rb3-content PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
