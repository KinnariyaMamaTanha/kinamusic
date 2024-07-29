local M = {}
-- 发送命令到 mpv
local function send_command(command)
    local ipc_path = "/tmp/mpvsocket"
    local chan = vim.fn.sockconnect("pipe", ipc_path, { rpc = false })
    if chan > 0 then
        vim.api.nvim_chan_send(chan, command)
        vim.fn.chanclose(chan)
    else
        print("Failed to connect to mpv IPC server")
    end
end

-- 暂停或恢复音乐播放的函数
local function toggle_pause_music()
    local is_playing = vim.fn.system("pgrep mpv")
    if is_playing ~= "" then
        local command = '{"command": ["cycle", "pause"]}\n'
        send_command(command)
        print("Toggle pause state")
    else
        print("No music playing now")
    end
end

M.toggle_pause_music = toggle_pause_music
M.send_command = send_command
return M
