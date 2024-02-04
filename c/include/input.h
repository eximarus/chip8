#pragma once
#include <SDL2/SDL_events.h>
#include <stdbool.h>

struct input {
    bool key[16];
} __attribute__((aligned(16)));

struct input* input_init(void);
void input_handle_event(struct input* input, SDL_Event event);
void input_set_key(struct input* input, uint8_t keycode, bool key_value);
bool input_get_key(struct input* input, uint8_t keycode);

