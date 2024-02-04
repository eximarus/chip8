#include "graphics.h"
#include <SDL2/SDL.h>

static const int32_t display_scale = 10;

struct graphics* graphics_init(void) {
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO) < 0) {
        printf("SDL could not initialize! SDL_Error: %s\n", SDL_GetError());
        return NULL;
    }

    SDL_Window* window =
        SDL_CreateWindow("chip8", // window title
                                  // NOLINTBEGIN hicpp-signed-bitwise
                         SDL_WINDOWPOS_UNDEFINED, // initial x position
                         SDL_WINDOWPOS_UNDEFINED, // initial y position
                         // NOLINTEND
                         SCREEN_WIDTH * display_scale,  // width, in pixels
                         SCREEN_HEIGHT * display_scale, // height, in pixels
                         SDL_WINDOW_SHOWN               // flags
        );

    if (!window) {
        printf("SDL could not create window! SDL_Error: %s\n", SDL_GetError());
        SDL_Quit();
        return NULL;
    }

    SDL_Renderer* renderer =
        SDL_CreateRenderer(window, -1, SDL_RENDERER_PRESENTVSYNC);
    if (!renderer) {
        printf("SDL could not create renderer! SDL_Error: %s\n",
               SDL_GetError());

        SDL_DestroyWindow(window);
        SDL_Quit();
        return NULL;
    }

    struct graphics* graphics = malloc(sizeof(struct graphics));
    if (!graphics) {
        SDL_DestroyWindow(window);
        SDL_DestroyRenderer(renderer);
        SDL_Quit();
        return NULL;
    }

    *graphics = (struct graphics){
        .window = window,
        .renderer = renderer,
        .vram = {0},
        .draw_flag = false,
    };

    graphics_request_draw(graphics);
    return graphics;
}

void graphics_request_draw(struct graphics* graphics) { graphics->draw_flag = true; }

void graphics_draw(struct graphics* graphics) {
    if (!graphics->draw_flag) {
        return;
    }

    SDL_SetRenderDrawColor(graphics->renderer, 0, 0, 0, 0xFF);
    SDL_RenderClear(graphics->renderer);

    for (int32_t y = 0; y < SCREEN_HEIGHT; y++) {
        for (int32_t x = 0; x < SCREEN_WIDTH; x++) {
            int32_t addr = y * SCREEN_WIDTH + x;
            if (graphics->vram[addr]) {
                SDL_SetRenderDrawColor(graphics->renderer, 0xFF, 0xFF, 0xFF, 0xFF);
                SDL_Rect block = {x * display_scale, y * display_scale,
                                  display_scale, display_scale};
                SDL_RenderDrawRect(graphics->renderer, &block);
                SDL_RenderFillRect(graphics->renderer, &block);
            }
        }
    }

    SDL_RenderPresent(graphics->renderer);
    graphics->draw_flag = false;
}

void graphics_terminate(struct graphics* graphics) {
    if (!graphics) {
        return;
    }
    SDL_DestroyRenderer(graphics->renderer);
    SDL_DestroyWindow(graphics->window);
    SDL_Quit();
    free(graphics);
}
