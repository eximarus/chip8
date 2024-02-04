#pragma once
#include <stdbool.h>
#include <stdint.h>
#include <SDL2/SDL_events.h>

#include "audio.h"
#include "graphics.h"

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
