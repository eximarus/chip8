#pragma once
#include <stdbool.h>
#include <stdint.h>
#include <SDL2/SDL_events.h>

#include "audio.h"
#include "graphics.h"

static const uint8_t chip8_fontset[80] = {
    0xF0U, 0x90U, 0x90U, 0x90U, 0xF0U, // 0
    0x20U, 0x60U, 0x20U, 0x20U, 0x70U, // 1
    0xF0U, 0x10U, 0xF0U, 0x80U, 0xF0U, // 2
    0xF0U, 0x10U, 0xF0U, 0x10U, 0xF0U, // 3
    0x90U, 0x90U, 0xF0U, 0x10U, 0x10U, // 4
    0xF0U, 0x80U, 0xF0U, 0x10U, 0xF0U, // 5
    0xF0U, 0x80U, 0xF0U, 0x90U, 0xF0U, // 6
    0xF0U, 0x10U, 0x20U, 0x40U, 0x40U, // 7
    0xF0U, 0x90U, 0xF0U, 0x90U, 0xF0U, // 8
    0xF0U, 0x90U, 0xF0U, 0x10U, 0xF0U, // 9
    0xF0U, 0x90U, 0xF0U, 0x90U, 0x90U, // A
    0xE0U, 0x90U, 0xE0U, 0x90U, 0xE0U, // B
    0xF0U, 0x80U, 0x80U, 0x80U, 0xF0U, // C
    0xE0U, 0x90U, 0x90U, 0x90U, 0xE0U, // D
    0xF0U, 0x80U, 0xF0U, 0x80U, 0xF0U, // E
    0xF0U, 0x80U, 0xF0U, 0x80U, 0x80U  // F
};

struct cpu {
    // registers
    // 15 8bit general purpose registers named V0,V1->VE.
    // 16th register is used for the 'carry flag'
    uint8_t v[16];
    uint16_t i : 12;
    uint16_t pc : 12;
    uint8_t sp : 4;

    // timers count at 60hz. when set above zero they will start counting down
    uint8_t dt;
    uint8_t st;

    /*
    memory map:
        0x000-0x1FF - Chip 8 interpreter (contains font set in emu)
        0x050-0x0A0 - Used for the built in 4x5 pixel font set (0-F)
        0x200-0xFFF - Program ROM and work RAM
    */
    uint8_t ram[4096];
    uint16_t stack[16];

    bool key[16];

    struct graphics* graphics;
    struct audio* audio;
} __attribute__((aligned(128)));


struct cpu* cpu_create(void);

int32_t cpu_init(struct cpu* cpu);

void cpu_emulate_cycle(struct cpu* cpu);

void cpu_update_timers(struct cpu* cpu);

bool cpu_load_application(struct cpu* cpu, const char* filename);

void cpu_handle_sdl_key_event(struct cpu* cpu, SDL_Event event);

void cpu_destroy(struct cpu* cpu);
