#include "play.h"
#define MINIAUDIO_IMPLEMENTATION 1
#include "miniaudio.h"

struct player_t {
  bool is_playing;
  ma_device device;
  ma_decoder decoder;
  ma_device_config config;
  bool configured;
};

static void unconfigure(struct player_t *p) {
    ma_device_uninit(&p->device);
    ma_decoder_uninit(&p->decoder);
    p->is_playing = false;
    p->configured = false;
}

static void data_callback(ma_device* pDevice, void *pOutput, const void* pInput, ma_uint32 frameCount) {
  (void)pInput;
  struct player_t* player = (struct player_t*)pDevice->pUserData;
  if (player->is_playing) {
    ma_result result = ma_decoder_read_pcm_frames(&player->decoder, pOutput, frameCount, NULL);
    if (result != MA_SUCCESS) {
      fprintf(stderr, "ma_decoder_read_pcm_frames failed with code: (%d)\n", result);
    }
  }
}

struct player_t * player_create() {
  struct player_t *result = malloc(sizeof(struct player_t));
  if (result == NULL) {
    return NULL;
  }
  result->is_playing = false;
  result->configured = false;
  return result;
}

bool player_play(struct player_t *p, const char *file_name) {
  if (p == NULL) return false;
  if (p->configured) {
    unconfigure(p);
  }
  ma_result result = ma_decoder_init_file(file_name, NULL, &p->decoder);
  if (result != MA_SUCCESS) {
    fprintf(stderr, "failed to init decoder file: code(%d)\n", result);
    return false;
  }
  p->config = ma_device_config_init(ma_device_type_playback);
  p->config.playback.format = p->decoder.outputFormat;
  p->config.playback.channels = p->decoder.outputChannels;
  p->config.sampleRate        = p->decoder.outputSampleRate;
  p->config.dataCallback      = data_callback;
  p->config.pUserData         = p;
  result = ma_device_init(NULL, &p->config, &p->device);
  if (result != MA_SUCCESS) {
    fprintf(stderr, "failed to init device: code(%d)\n", result);
    ma_decoder_uninit(&p->decoder);
    return false;
  }
  ma_result start_result = ma_device_start(&p->device);
  if (start_result != MA_SUCCESS) {
    fprintf(stderr, "failed to start device: code(%d)\n", start_result);
    unconfigure(p);
    return false;
  }
  p->is_playing = true;
  p->configured = true;
  return true;
}

void player_pause(struct player_t *p) {
  if (p == NULL) return;
  p->is_playing = false;
}
void player_resume(struct player_t *p) {
  if (p == NULL) return;
  p->is_playing = true;
}
bool player_stop(struct player_t *p) {
  if (p == NULL) return false;
  ma_result result = ma_device_stop(&p->device);
  if (result != MA_SUCCESS) {
    fprintf(stderr, "failed to stop device. code(%d)\n", result);
    return false;
  }
  return true;
}

float player_get_volume(struct player_t *p) {
  float out = 0.0;
  if (p == NULL || !p->is_playing) {
    return out;
  }
  ma_result result = ma_device_get_master_volume(&p->device, &out);
  if (result != MA_SUCCESS) {
    fprintf(stderr, "failed to get master volume for device: code(%d).\n", result);
    return 0.0;
  }
  return out;
}

void player_set_volume(struct player_t *p, float volume) {
  if (p == NULL) return;
  ma_result result = ma_device_set_master_volume(&p->device, volume);
  if (result != MA_SUCCESS) {
    fprintf(stderr, "failed to set master volume for device: code(%d).\n", result);
  }
}

void player_destroy(struct player_t **p) {
  if (p == NULL) {
    return;
  }
  if ((*p) == NULL) {
    return;
  }
  if ((*p)->configured) {
    unconfigure(*p);
  }
  free(*p);
  *p = NULL;
}
