#ifndef PLAYER_NVIM_PLAY_H
#define PLAYER_NVIM_PLAY_H

#include <stdbool.h>

/**
 * Opaque player structure.
 */
struct player_t;

/**
 * Create a player.
 */
struct player_t * player_create();

/**
 * Play the given song file.
 *
 * @param[in] p The player structure.
 * @param[in] file_name The song's file name. Must be full/relative path.
 * @return True if successful, false otherwise.
 */
bool player_play(struct player_t *p, const char *file_name);

/**
 * Get the volume of the player.
 */
float player_get_volume(struct player_t *p);

/**
 * Set the volume of the player.
 */
void player_set_volume(struct player_t *p, float volume);

/**
 * Pause the player.
 */
void player_pause(struct player_t *p);
/**
 * Resume the player.
 */
void player_resume(struct player_t *p);

/**
 * Stop the player.
 */
bool player_stop(struct player_t *p);

/**
 * Destroy the player.
 */
void player_destroy(struct player_t **p);

#endif
