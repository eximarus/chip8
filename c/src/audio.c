#include "audio.h"
#include <math.h>

struct audio* audio_init(void) {
    SDL_AudioSpec spec = {
        .freq = (int32_t)audio_frequency,
        .format = AUDIO_U8,
        .channels = 1,
        .samples = 2048,
        .callback = NULL,
        .userdata = NULL,
    };

    SDL_AudioDeviceID device =
        // NOLINTNEXTLINE hicpp-signed-bitwise
        SDL_OpenAudioDevice(NULL, 0, &spec, NULL, SDL_AUDIO_ALLOW_ANY_CHANGE);

    if (!device) {
        printf("SDL could not get audio device! SDL_Error: %s\n",
               SDL_GetError());
        return NULL;
    }

    struct audio* audio = malloc(sizeof(struct audio));
    if (!audio) {
        SDL_CloseAudioDevice(device);
        return NULL;
    }

    SDL_PauseAudioDevice(device, 0);
    *audio = (struct audio){
        .buffer = {0},
        .device = device,
        .wave_position = 0,
        .wave_increment = (audio_tone * (2.0 * M_PI)) / audio_frequency,
    };
    return audio;
}

void audio_beep(struct audio* audio, int len) {
    if (!audio || SDL_GetQueuedAudioSize(audio->device) >=
                      (audio_samples_per_frame * 2)) {
        return;
    }
    audio_sine(audio, len);
    SDL_QueueAudio(audio->device, audio->buffer, len);
}

void audio_sine(struct audio* audio, int len) {
    for (int32_t i = 0; i < len; i++) {
        audio->buffer[i] = (uint8_t)((
            audio_amplitude * sin(audio->wave_position) + audio_bias));
        audio->wave_position += audio->wave_increment;
    }
}

void audio_terminate(struct audio* audio) {
    if (!audio) {
        return;
    }
    SDL_PauseAudioDevice(audio->device, 1);
    if (audio->device) {
        SDL_CloseAudioDevice(audio->device);
    }
    free(audio);
}
