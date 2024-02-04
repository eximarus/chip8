#include "chip8.h"
#include "instr.h"
#include <SDL2/SDL.h>
#include <time.h>

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

struct chip8* chip8_init(void) {
    struct graphics* graphics = graphics_init();
    if (!graphics) {
        return NULL;
    }

    struct audio* audio = audio_init();
    struct input* input = input_init();
    if (!input) {
        audio_terminate(audio);
        graphics_terminate(graphics);
        return NULL;
    }

    struct chip8* chip8 = malloc(sizeof(struct chip8));
    if (chip8 == NULL) {
        audio_terminate(audio);
        graphics_terminate(graphics);
        free(input);
        return NULL;
    }

    *chip8 = (struct chip8){
        .cpu =
            {
                .pc = 0x200,
                .i = 0,
                .sp = 0,
                .v = {0},
                .dt = 0,
                .st = 0,
                .ram = {0},
                .stack = {0},
                .input = input,
                .graphics = graphics,
                .audio = audio,
            },
    };

    const size_t fontset_size =
        sizeof(chip8_fontset) / sizeof(chip8_fontset[0]);
    for (size_t i = 0; i < fontset_size; ++i) {
        chip8->cpu.ram[i] = chip8_fontset[i];
    }

    srandom(time(NULL));
    return chip8;
}

void chip8_terminate(struct chip8* chip8) {
    if (!chip8) {
        return;
    }
    audio_terminate(chip8->cpu.audio);
    graphics_terminate(chip8->cpu.graphics);
    free(chip8->cpu.input);
    free(chip8);
}

static int64_t get_file_size(FILE* file) {
    const int32_t result = fseek(file, 0, SEEK_END);
    if (result != 0) {
        return -1;
    }

    long file_size = ftell(file);
    rewind(file);
    return file_size;
}

bool chip8_load_application(struct chip8* chip8, const char* filename) {
    FILE* file = fopen(filename, "rbe");
    if (file == NULL) {
        // NOLINTNEXTLINE
        fputs("File error", stderr);
        return false;
    }

    int64_t file_size = get_file_size(file);
    if (file_size < 0) {
        printf("Error: failed to get ROM size");
        // NOLINTNEXTLINE
        fclose(file);
        return false;
    }

    if (file_size > 4096 - 512) {
        printf("Error: ROM too big for memory");
        // NOLINTNEXTLINE
        fclose(file);
        return false;
    }

    uint8_t* buffer = (uint8_t*)malloc(sizeof(uint8_t) * file_size);
    if (buffer == NULL) {
        // NOLINTNEXTLINE
        fputs("Memory error", stderr);
        // NOLINTNEXTLINE
        fclose(file);
        return false;
    }

    size_t len = fread(buffer, 1, file_size, file);
    if (len != (uint64_t)file_size) {
        // NOLINTNEXTLINE
        fputs("Reading error", stderr);
        // NOLINTNEXTLINE
        fclose(file);
        free(buffer);
        return false;
    }

    memmove(&chip8->cpu.ram[512], buffer, file_size * sizeof(uint8_t));

    // NOLINTNEXTLINE
    fclose(file);
    free(buffer);
    return true;
}
