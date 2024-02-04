#pragma once
#include <SDL2/SDL_audio.h>

#define AUDIO_FREQUENCY 48000
#define AUDIO_SAMPLES_PER_FRAME AUDIO_FREQUENCY / 60 * 3

static const double_t audio_frequency = AUDIO_FREQUENCY;
static const double_t audio_tone = 440;
static const int32_t audio_amplitude = 7;
static const int32_t audio_bias = 127;
static const int32_t audio_samples_per_frame = AUDIO_SAMPLES_PER_FRAME;

struct audio {
    SDL_AudioDeviceID device;
    double_t wave_position;
    double_t wave_increment;
    uint8_t buffer[AUDIO_SAMPLES_PER_FRAME * 30];
} __attribute__((aligned(128)));

struct audio* audio_create(void);
int32_t audio_init(struct audio* audio);
void audio_beep(struct audio* audio, int32_t len);
void audio_sine(struct audio* audio, int32_t len);
void audio_destroy(struct audio* audio);
