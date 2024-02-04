#include <SDL2/SDL.h>
#include <SDL2/SDL_events.h>
#include <SDL2/SDL_timer.h>
#include "cpu.h"

#define MILLISECONDS_PER_FRAME 1000.0f / 60.0f

int main(int argc, char* argv[]) {
    if (argc < 2) {
        printf("please provide a path to a chip8 application\n\n");
        return EXIT_FAILURE;
    }

    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO) < 0) {
        printf("SDL could not initialize! SDL_Error: %s\n", SDL_GetError());
        return EXIT_FAILURE;
    }

    struct cpu* cpu = cpu_create();
    if (!cpu) {
        return EXIT_FAILURE;
    }

    if (!cpu_load_application(cpu, argv[1])) {
        printf("Failed to load chip8 application");
        cpu_destroy(cpu);
        return EXIT_FAILURE;
    }

    uint32_t last_ticks = SDL_GetTicks();
    uint32_t last_delta = 0;
    uint32_t cycle_delta = 0;
    float_t frame_delta = 0;

    while (true) {
        SDL_Event sdlEvent;
        while (SDL_PollEvent(&sdlEvent) != 0) {
            switch (sdlEvent.type) {
            case SDL_QUIT:
                goto QUIT;
            case SDL_KEYDOWN:
            case SDL_KEYUP: {
                cpu_handle_sdl_key_event(cpu, sdlEvent);
                break;
            }
            }
        }

        last_delta = SDL_GetTicks() - last_ticks;
        last_ticks = SDL_GetTicks();
        cycle_delta += last_delta;
        frame_delta += (float_t)last_delta;

        // 10 cycles per second
        while (cycle_delta >= 1) {
            cpu_emulate_cycle(cpu);
            cycle_delta -= 1;
        }

        while (frame_delta >= MILLISECONDS_PER_FRAME) {
            cpu_update_timers(cpu);
            graphics_draw(cpu->graphics);
            frame_delta -= MILLISECONDS_PER_FRAME;
        }
    }

QUIT:
    cpu_destroy(cpu);
    SDL_Quit();
    return 0;
}
