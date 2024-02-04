#pragma once
#include <SDL2/SDL_audio.h>

static const double_t audio_frequency = 48000;
static const double_t audio_tone = 440;
static const int32_t audio_amplitude = 7;
static const int32_t audio_bias = 127;
static const int32_t audio_samples_per_frame =
    (int32_t)(audio_frequency / 60) * 3;

struct audio {
    SDL_AudioDeviceID device;
    double_t wave_position;
    double_t wave_increment;
    uint8_t buffer[72000]; // samples_per_frame * 30
} __attribute__((aligned(128)));

struct audio* audio_init(void);
void audio_beep(struct audio* audio, int32_t len);
void audio_sine(struct audio* audio, int32_t len);
void audio_terminate(struct audio* audio);
