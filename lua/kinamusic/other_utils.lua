local send_command = require("kinamusic.pause").send_command

-- 快进
local function forward_music()
    local is_playing = vim.fn.system("pgrep mpv")
    if is_playing ~= "" then
        send_command('{"command": ["seek", 5, "relative"]}\n')
    else
        print("No music playing now")
    end
end

-- 快退
local function rewind_music()
    local is_playing = vim.fn.system("pgrep mpv")
    if is_playing ~= "" then
        send_command('{"command": ["seek", -5, "relative"]}\n')
    else
        print("No music playing now")
    end
end

-- 增大音量
local function increase_volume()
    local is_playing = vim.fn.system("pgrep mpv")
    if is_playing ~= "" then
        send_command('{"command": ["add", "volume", 5]}\n')
    else
        print("No music playing now")
    end
end

-- 减小音量
local function decrease_volume()
    local is_playing = vim.fn.system("pgrep mpv")
    if is_playing ~= "" then
        send_command('{"command": ["add", "volume", -5]}\n')
    else
        print("No music playing now")
    end
end

return {
    forward_music = forward_music,
    rewind_music = rewind_music,
    increase_volume = increase_volume,
    decrease_volume = decrease_volume,
}
