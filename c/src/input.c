#include "input.h"

struct input* input_init(void) {
    struct input* input = malloc(sizeof(struct input));
    if (!input) {
        return NULL;
    }
    *input = (struct input){.key = {0}};
    return input;
}

void input_handle_event(struct input* input, SDL_Event event) {
    bool key_value = false;
    if (event.type == SDL_KEYDOWN) {
        key_value = true;
    } else if (event.type != SDL_KEYUP) {
        printf("Unknown input event: %d", event.type);
        return;
    }

    uint8_t keycode = 0;
    switch (event.key.keysym.sym) {
    case SDLK_1:
        keycode = 0x1;
        break;
    case SDLK_2:
        keycode = 0x2;
        break;
    case SDLK_3:
        keycode = 0x3;
        break;
    case SDLK_4:
        keycode = 0xC;
        break;
    case SDLK_q:
        keycode = 0x4;
        break;
    case SDLK_w:
        keycode = 0x5;
        break;
    case SDLK_e:
        keycode = 0x6;
        break;
    case SDLK_r:
        keycode = 0xD;
        break;
    case SDLK_a:
        keycode = 0x7;
        break;
    case SDLK_s:
        keycode = 0x8;
        break;
    case SDLK_d:
        keycode = 0x9;
        break;
    case SDLK_f:
        keycode = 0xE;
        break;
    case SDLK_z:
        keycode = 0xA;
        break;
    case SDLK_x:
        keycode = 0x0;
        break;
    case SDLK_c:
        keycode = 0xB;
        break;
    case SDLK_v:
        keycode = 0xF;
        break;
    default:
        return;
    }
    input->key[keycode] = key_value;
}

void input_set_key(struct input* input, uint8_t keycode, bool key_value) {
    input->key[keycode] = key_value;
}

bool input_get_key(struct input* input, uint8_t keycode) {
    return input->key[keycode];
}
