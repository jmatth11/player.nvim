#include "play.h"
#define MINIAUDIO_IMPLEMENTATION 1
#include "miniaudio.h"
#include <stdint.h>

/**
 * Player structure
 */
struct player_t {
  /* Playback callback for audio updates. */
  playback_cb cb;
  /* playback device. */
  ma_device device;
  /* Decoder for reading the audio file. */
  ma_decoder decoder;
  /* Device configuration. */
  ma_device_config config;
  /* Is playing flag. */
  bool is_playing;
  /* Has ended flag. */
  bool has_ended;
  /* Configured flag. */
  bool configured;
};

/**
 * Free the device and decoder objects.
 */
static void unconfigure(struct player_t *p) {
  ma_device_uninit(&p->device);
  ma_decoder_uninit(&p->decoder);
  p->is_playing = false;
  p->configured = false;
}

static void data_callback(ma_device *pDevice, void *pOutput, const void *pInput,
                          ma_uint32 frameCount) {
  (void)pInput;
  struct player_t *player = (struct player_t *)pDevice->pUserData;
  // pause the player by not decoding more.
  if (player->is_playing) {
    ma_uint64 framesRead = 0;
    ma_result result = ma_decoder_read_pcm_frames(&player->decoder, pOutput,
                                                  frameCount, &framesRead);
    if (result != MA_SUCCESS) {
      if (result != MA_AT_END) {
        fprintf(stderr, "ma_decoder_read_pcm_frames failed with code: (%d)\n",
                result);
      }
      // audio has ended.
      player->has_ended = true;
      player->is_playing = false;
    } else {
      if (player->cb != NULL) {
        // get the elapsed time in seconds with frames / sample_rate
        player->cb((double)framesRead /
                       (double)player->decoder.outputSampleRate,
                   player->has_ended);
      }
    }
  }
}

/**
 * Create a player with the given callback function.
 */
struct player_t *player_create(playback_cb cb) {
  struct player_t *result = malloc(sizeof(struct player_t));
  if (result == NULL) {
    return NULL;
  }
  result->is_playing = false;
  result->has_ended = false;
  result->configured = false;
  result->cb = cb;
  return result;
}

/**
 * Play the given audio file with the player.
 *
 * @param p The player structure.
 * @param file_name The audio file.
 * @return true for success, false for failure.
 */
bool player_play(struct player_t *p, const char *file_name) {
  if (p == NULL)
    return false;
  // deinitialize the old device and decoder.
  if (p->configured) {
    unconfigure(p);
  }
  // init decoder with audio file.
  ma_result result = ma_decoder_init_file(file_name, NULL, &p->decoder);
  if (result != MA_SUCCESS) {
    fprintf(stderr, "failed to init decoder file: code(%d)\n", result);
    return false;
  }
  // setup device config.
  p->config = ma_device_config_init(ma_device_type_playback);
  p->config.playback.format = p->decoder.outputFormat;
  p->config.playback.channels = p->decoder.outputChannels;
  p->config.sampleRate = p->decoder.outputSampleRate;
  p->config.dataCallback = data_callback;
  p->config.pUserData = p;
  result = ma_device_init(NULL, &p->config, &p->device);
  if (result != MA_SUCCESS) {
    fprintf(stderr, "failed to init device: code(%d)\n", result);
    ma_decoder_uninit(&p->decoder);
    return false;
  }
  // start the device to start playback.
  ma_result start_result = ma_device_start(&p->device);
  if (start_result != MA_SUCCESS) {
    fprintf(stderr, "failed to start device: code(%d)\n", start_result);
    unconfigure(p);
    return false;
  }
  // setup flags.
  p->is_playing = true;
  p->configured = true;
  p->has_ended = false;
  return true;
}

/**
 * Pause the player.
 */
void player_pause(struct player_t *p) {
  if (p == NULL)
    return;
  p->is_playing = false;
}
/**
 * Resume the player.
 */
void player_resume(struct player_t *p) {
  if (p == NULL)
    return;
  p->is_playing = true;
}
/**
 * Stop the player.
 *
 * @param p The player structure.
 * @return True for success, false otherwise.
 */
bool player_stop(struct player_t *p) {
  if (p == NULL)
    return false;
  ma_result result = ma_device_stop(&p->device);
  if (result != MA_SUCCESS) {
    fprintf(stderr, "failed to stop device. code(%d)\n", result);
    return false;
  }
  return true;
}

/**
 * Get the flag for if the player has been stopped.
 */
bool player_has_stopped(struct player_t *p) {
  if (p == NULL) {
    return true;
  }
  return p->has_ended;
}

/**
 * Get the volume of the player.
 *
 * @return float value between 0 - 1.
 */
float player_get_volume(struct player_t *p) {
  float out = 0.0;
  if (p == NULL || !p->is_playing) {
    return out;
  }
  ma_result result = ma_device_get_master_volume(&p->device, &out);
  if (result != MA_SUCCESS) {
    fprintf(stderr, "failed to get master volume for device: code(%d).\n",
            result);
    return 0.0;
  }
  return out;
}

/**
 * Set the volume of the player.
 *
 * @param p The player structure.
 * @param volume The volume to set. Value must be between 0 - 1.
 */
void player_set_volume(struct player_t *p, float volume) {
  if (p == NULL)
    return;
  ma_result result = ma_device_set_master_volume(&p->device, volume);
  if (result != MA_SUCCESS) {
    fprintf(stderr, "failed to set master volume for device: code(%d).\n",
            result);
  }
}

/**
 * Get the current playtime of the audio in seconds.
 *
 * @param p The player structure.
 * @param[out] playtime The playtime in seconds.
 * @return True on success, false otherwise.
 */
bool player_get_current_playtime(struct player_t *p, uint64_t *playtime) {
  if (p == NULL)
    return false;
  if (!p->configured)
    return false;
  // get the current frame the decoder is on.
  ma_uint64 currentFrame = 0;
  ma_result result =
      ma_decoder_get_cursor_in_pcm_frames(&p->decoder, &currentFrame);
  if (result != MA_SUCCESS) {
    return false;
  }
  ma_uint32 sampleRate = p->decoder.outputSampleRate;
  if (sampleRate == 0) {
    fprintf(stderr, "player_get_length: sample rate was 0.\n");
    return false;
  }
  // calc the seconds from the sample rate
  *playtime = currentFrame / sampleRate;
  return true;
}

/**
 * Get the total length of the audio in seconds.
 *
 * @param p The player structure.
 * @param length The length of the audio in seconds.
 * @return True on success, false otherwise.
 */
bool player_get_length(struct player_t *p, uint64_t *length) {
  if (p == NULL)
    return false;
  if (!p->configured)
    return false;
  // get the total amount of frames.
  ma_uint64 totalFrames = 0;
  ma_result result =
      ma_decoder_get_length_in_pcm_frames(&p->decoder, &totalFrames);
  if (result != MA_SUCCESS) {
    return false;
  }
  ma_uint32 sample_rate = p->decoder.outputSampleRate;
  if (sample_rate == 0) {
    fprintf(stderr, "player_get_length: sample rate was 0.\n");
    return false;
  }
  // calc the seconds from the sample rate.
  *length = totalFrames / sample_rate;
  return true;
}

/**
 * Destroy the player.
 */
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
