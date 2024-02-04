#include <SDL2/SDL.h>
#include <SDL2/SDL_events.h>
#include <SDL2/SDL_timer.h>
#include "chip8.h"

#define MILLISECONDS_PER_GPU_CYCLE 1000.0f / 60.0f
#define MILLISECONDS_PER_TIMER_CYCLE 1000.0f / 60.0f

int main(int argc, char* argv[]) {
    if (argc < 2) {
        printf("please provide a path to a chip8 application\n\n");
        return EXIT_FAILURE;
    }

    struct chip8* chip8 = chip8_init();
    if (!chip8_load_application(chip8, argv[1])) {
        printf("Failed to load chip8 application");
        chip8_terminate(chip8);
        return EXIT_FAILURE;
    }

    uint32_t last_ticks = SDL_GetTicks();
    uint32_t last_delta = 0;
    uint32_t cycle_delta = 0;
    float_t render_delta = 0;
    float_t timer_delta = 0;

    while (true) {
        SDL_Event sdlEvent;
        while (SDL_PollEvent(&sdlEvent) != 0) {
            switch (sdlEvent.type) {
            case SDL_QUIT:
                goto QUIT;
            case SDL_KEYDOWN:
            case SDL_KEYUP: {
                input_handle_event(chip8->cpu.input, sdlEvent);
                break;
            }
            }
        }

        last_delta = SDL_GetTicks() - last_ticks;
        last_ticks = SDL_GetTicks();
        cycle_delta += last_delta;
        render_delta += (float_t)last_delta;
        timer_delta += (float_t)last_delta;

        // 10 cycles per second
        while (cycle_delta >= 1) {
            cpu_emulate_cycle(&chip8->cpu);
            cycle_delta -= 1;
        }

        while (timer_delta >= MILLISECONDS_PER_TIMER_CYCLE) {
            cpu_update_timers(&chip8->cpu);
            timer_delta -= MILLISECONDS_PER_TIMER_CYCLE;
        }

        while (render_delta >= MILLISECONDS_PER_GPU_CYCLE) {
            graphics_draw(chip8->cpu.graphics);
            render_delta -= MILLISECONDS_PER_GPU_CYCLE;
        }
    }

QUIT:
    chip8_terminate(chip8);
    return 0;
}
