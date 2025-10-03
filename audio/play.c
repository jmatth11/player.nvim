#include "play.h"
#define MINIAUDIO_IMPLEMENTATION 1
#include "miniaudio.h"

struct player_t {
  bool is_playing;
  ma_device device;
  ma_decoder decoder;
  ma_device_config config;
};

static void data_callback(ma_device* pDevice, void *pOutput, const void* pInput, ma_uint32 frameCount) {
  (void)pInput;
  ma_decoder* pDecoder = (ma_decoder*)pDevice->pUserData;
  ma_result result = ma_decoder_read_pcm_frames(pDecoder, pOutput, frameCount, NULL);
  if (result != MA_SUCCESS) {
    fprintf(stderr, "ma_decoder_read_pcm_frames failed with code: (%d)\n", result);
  }
}

struct player_t * player_create() {
  struct player_t *result = malloc(sizeof(struct player_t));
  if (result == NULL) {
    return NULL;
  }
  result->is_playing = false;
  return result;
}

bool player_play(struct player_t *p, const char *file_name) {
  if (p->is_playing) {
    ma_device_uninit(&p->device);
    ma_decoder_uninit(&p->decoder);
    p->is_playing = false;
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
  p->config.pUserData         = &p->decoder;
  result = ma_device_init(NULL, &p->config, &p->device);
  if (result != MA_SUCCESS) {
    fprintf(stderr, "failed to init device: code(%d)\n", result);
    ma_decoder_uninit(&p->decoder);
    return false;
  }
  result = ma_device_start(&p->device);
  if (result != MA_SUCCESS) {
    fprintf(stderr, "failed to start device: code(%d)\n", result);
    ma_device_uninit(&p->device);
    ma_decoder_uninit(&p->decoder);
    return false;
  }
  p->is_playing = true;
  return true;
}

void player_destroy(struct player_t **p) {
  if (p == NULL) {
    return;
  }
  if ((*p) == NULL) {
    return;
  }
  ma_device_uninit(&(*p)->device);
  ma_decoder_uninit(&(*p)->decoder);
  free(*p);
  *p = NULL;
}
