#include "graphics.h"
#include <SDL2/SDL.h>

static const int32_t display_scale = 10;

struct graphics* graphics_create(void) {
    struct graphics* graphics = malloc(sizeof(struct graphics));
    if (!graphics) {
        return NULL;
    }
    if (graphics_init(graphics) != 0) {
        free(graphics);
        return NULL;
    }
    return graphics;
}

int32_t graphics_init(struct graphics* graphics) {
    SDL_Window* window =
        SDL_CreateWindow("chip8", // window title
                         SDL_WINDOWPOS_UNDEFINED, // initial x position
                         SDL_WINDOWPOS_UNDEFINED, // initial y position
                         SCREEN_WIDTH * display_scale,  // width, in pixels
                         SCREEN_HEIGHT * display_scale, // height, in pixels
                         SDL_WINDOW_SHOWN               // flags
        );

    if (!window) {
        printf("SDL could not create window! SDL_Error: %s\n", SDL_GetError());
        return 1;
    }

    SDL_Renderer* renderer =
        SDL_CreateRenderer(window, -1, SDL_RENDERER_PRESENTVSYNC);
    if (!renderer) {
        printf("SDL could not create renderer! SDL_Error: %s\n",
               SDL_GetError());

        SDL_DestroyWindow(window);
        return 1;
    }

    *graphics = (struct graphics){
        .window = window,
        .renderer = renderer,
        .vram = {0},
        .draw_flag = false,
    };

    graphics->draw_flag = true;
    return 0;
}

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

void graphics_destroy(struct graphics* graphics) {
    if (!graphics) {
        return;
    }
    SDL_DestroyRenderer(graphics->renderer);
    SDL_DestroyWindow(graphics->window);
    free(graphics);
}
