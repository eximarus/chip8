#pragma once
#include <SDL2/SDL_render.h>
#include <stdbool.h>

#define SCREEN_WIDTH 64
#define SCREEN_HEIGHT 32

struct graphics {
    uint32_t vram[64 * 32];
    SDL_Window* window;
    SDL_Renderer* renderer;
    bool draw_flag;
} __attribute__((aligned(128)));

struct graphics* graphics_init(void);
void graphics_request_draw(struct graphics* graphics);
void graphics_draw(struct graphics* graphics);
void graphics_terminate(struct graphics* graphics);
