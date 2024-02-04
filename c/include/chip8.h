#pragma once
#include "audio.h"
#include "graphics.h"
#include "input.h"
#include "cpu.h"

struct chip8 {
    struct cpu cpu;
} __attribute__((aligned(128)));

struct chip8* chip8_init(void);

bool chip8_load_application(struct chip8* chip8, const char* filename);

void chip8_terminate(struct chip8* chip8);
