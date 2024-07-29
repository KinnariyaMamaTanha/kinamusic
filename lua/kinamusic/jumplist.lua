local M = {}
local send_command = require("kinamusic.pause").send_command

-- 下一首音乐
local function next_music()
    local is_playing = vim.fn.system("pgrep mpv")
    if is_playing ~= "" then
        send_command('{"command": ["playlist-next"]}\n')
        print("Next music")
    else
        print("No music list playing now")
    end
end

-- 上一首音乐
local function prev_music()
    local is_playing = vim.fn.system("pgrep mpv")
    if is_playing ~= "" then
        send_command('{"command": ["playlist-prev"]}\n')
        print("Prev music")
    else
        print("No music list playing now")
    end
end

M.next_music = next_music
M.prev_music = prev_music

return M
