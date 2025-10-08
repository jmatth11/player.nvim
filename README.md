# Player.nvim

Simple plugin to play local audio files through neovim.

## Configure

Lazy.nvim
```lua
  'jmatth11/player.nvim',
  -- requires zig to build the plugin
  build = "zig build",
  -- Required to properly setup the player.
  config = true,
```

Setup options:

```lua
{
  -- Set the parent directory for your audio files.
  -- default is home directory
  parent_dir = vim.env.HOME,
  -- The scale at which the volume increments and decrements.
  -- default is 5
  volume_scale = 5,
}

## Usage

### Recommended Mappings

```lua
-- <leader>pp to toggle the player info window.
vim.keymap.set(
    "n",
    "<leader>pp",
    ":lua require('player').player_info()<CR>",
    {noremap = true},
)
```

Using the player info window is the recommended way to interact with this
plugin. It displays the keybindings to pause/resume the song and to increase or
lower the volume.

### Manual Controls

Play a song.

This function will prepend the parent directory set in the setup options.
So you only need to pass the filename relative to that point.

```lua
require('player').play(<song name>)
```

Controlling pause/resume.

```lua
require('player').pause()
require('player').resume()
```

Controlling volume.

```lua
require('player').volume_up()
require('player').volume_down()
```

!! TODO finish once I have file selection implemented. !!

## Screenshots

## Demo

## Known issues

- Audio playback on WSL is not great and sometimes becomes very choppy.
  [ref](https://github.com/microsoft/wslg/issues/908)
