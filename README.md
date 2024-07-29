# kinamusic

A simple local music player inside neovim, using [mpv](https://mpv.io/). I love music so I created it. It now support .mp3, .wav and .flac files.

## Requirements

- neovim (I am using 0.10)
- [mpv](https://mpv.io/)

## Installation

Using lazy.nvim:

```lua
{
    "KinnariyaMamaTanha/kinamusic",
    opts = {
        -- default options
        music_folder = "~/music",
        loop = true,
        max_loop = "inf"
    },
    cmd = {
        "PlayMusic",
        "PlayMusicChoose",
    },
}
```

## Configuration

- `music_folder`: `string`. The default music directory. Both absolute path and relative path are OK.
- `loop`: `boolean`. Whether or not enable loop.
- `max_loop`: `"inf" | int`. The max loop number where `"inf"` means infinite.

## Commands

- `:PlayMusic`:
    - `:PlayMusic /path/to/your/song.mp3`: play given music file.
    - `:PlayMusic [/path/to/your/music_directory]`: when given a directory, you can choose to play single file in it or play in sequence or randomly. Default the `music_folder`
    - `:PlayMusic song_name_in_music_folder`: if the arg is neither a file or a directory, try to search it in the music_folder and play the first match.
- `:PlayMusicChoose`: Choose music files in `music_folder`
- `:PlayMusicPause`: Pause the music.
- `:StopMusic`: Stop playing current music.
- `:PlayMusicNext`: Jump to next music if playing music list.
- `:PlayMusicPrev`: Jump to prev music if playing music list.
- `:PlayMusicForward`: Forward music for 5s.
- `:PlayMusicRewind`: Rewind music for 5s.
- `:PlayMusicIncreaseVolume`: Increase music volume.
- `:PlayMusicDecreaseVolume`: Decrease music volume.

## TODOs

- [x] Enable pausing the music.
- [x] Enable multiple matching.
- [x] Enable jump in the playlist.
- [x] Enable loop.
- [x] Enable fast forward and rewind.
~~Better UI interface.~~
