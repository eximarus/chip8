cmake_minimum_required(VERSION 3.16.3)
project(chip8)

set(CMAKE_C_STANDARD 99)

if(!NDEBUG)
    add_compile_options(
        -Wall
        -O3
        -funroll-loops
        -finline-functions
        -flto
        -s
    )
else()
    add_compile_options(
        -Wall
    )
endif()

include_directories(include)

add_executable(
    ${PROJECT_NAME}
    src/main.c
    src/cpu.c
    src/graphics.c
    src/audio.c
)

target_link_libraries(
    ${PROJECT_NAME}
    m
    SDL2
    SDL2main
)
