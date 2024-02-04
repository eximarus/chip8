cmake_minimum_required(VERSION 3.16.3)
project(chip8)

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_COMPILER "/usr/bin/clang")


if(MSVC)
# warning level 4 and all warnings as errors
    add_compile_options(/W4 /WX)
else()
    # lots of warnings and all warnings as errors
    add_compile_options(
        -Wall
        -Wextra
        -pedantic
        -Werror
        -Warray-bounds
        -Wno-c11-extensions
        -g
        # -fstrict-flex-arrays
        -fsanitize=bounds
        -fsanitize=leak
        -fsanitize-undefined-trap-on-error
        -fsanitize=address
        -D_GLIBCXX_ASSERTIONS
        -fasynchronous-unwind-tables
        -fstack-protector-all
        -fstack-protector-strong
        -O2
        -pipe
        -fpie
    )
    add_link_options(
        -fsanitize=address
        -fsanitize=bounds
        -fsanitize=leak
        -fsanitize-undefined-trap-on-error
    )
endif()

include_directories(include)

add_executable(
    ${PROJECT_NAME}
    src/main.c
    src/chip8.c
    src/cpu.c
    src/input.c
    src/graphics.c
    src/audio.c
)

target_link_libraries(
    ${PROJECT_NAME}
    m
    SDL2
    SDL2main
)
