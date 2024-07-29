# kinamusic

A simple local music player inside neovim, using [mpv](https://mpv.io/). I love music so I created it.

## Requirements

- neovim (I am using 0.10)
- [mpv](https://mpv.io/)

## Installation

Using lazy.nvim:

```lua
{
    "KinnariyaMamaTanha/kinamusic",
    opts = {
        -- The default music folder is
        -- music_folder = "~/music"
    },
    cmd = {
        "PlayMusic",
        "StopMusic"
    },
}
```

## Configuration

There is only one option so far, using `music_folder` as a string to customize your own music folder.

## Commands

- `PlayMusic`:
    - `:PlayMusic /path/to/your/song.mp3`: play given music file.
    - `:PlayMusic [/path/to/your/music_directory]`: when given a directory, you can choose to play single file in it or play in sequence or randomly. Default the `music_folder`
    - `:PlayMusic song_name_in_music_folder`: if the arg is neither a file or a directory, try to search it in the music_folder and play the first match.
- `StopMusic`: Stop playing current music.

## TODOs

- [ ] Enable pausing the music.
- [ ] Enable multiple matching.
- [ ] Enable multiple music folders.
- [ ] Enable jump in the playlist.
- [ ] Enable loop.
- [ ] Enable fast forward and rewind.
- [ ] Better UI interface.
