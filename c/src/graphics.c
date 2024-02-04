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

int32_t point_to_addr(struct point point, int32_t width) {
    return point.y * width + point.x;
}

void graphics_draw(struct graphics* graphics) {
    if (!graphics->draw_flag) {
        return;
    }

    SDL_SetRenderDrawColor(graphics->renderer, 0, 0, 0, 0xFF);
    SDL_RenderClear(graphics->renderer);

    for (int y = 0; y < SCREEN_HEIGHT; y++) {
        for (int x = 0; x < SCREEN_WIDTH; x++) {
            struct point point = {.x = x, .y = y};
            if (graphics->vram[point_to_addr(point, SCREEN_WIDTH)]) {
                graphics_draw_pixel(graphics, point);
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

void graphics_draw_pixel(struct graphics* graphics, struct point point) {
    SDL_SetRenderDrawColor(graphics->renderer, 0xFF, 0xFF, 0xFF, 0xFF);
    SDL_Rect block = {point.x * display_scale, point.y * display_scale,
                      display_scale, display_scale};
    SDL_RenderDrawRect(graphics->renderer, &block);
    SDL_RenderFillRect(graphics->renderer, &block);
}
