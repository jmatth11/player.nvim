#ifndef PLAYER_NVIM_PLAY_H
#define PLAYER_NVIM_PLAY_H

#include <stdbool.h>

struct player_t;

struct player_t * player_create();
bool player_play(struct player_t *p, const char *file_name);
void player_destroy(struct player_t **p);

#endif
