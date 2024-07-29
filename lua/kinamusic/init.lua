local M = {
    music_folder = "~/music",
    loop = true,
    max_loop = "inf",
}

local pause = require("kinamusic.pause")
local jump = require("kinamusic.jumplist")
local other_utils = require("kinamusic.other_utils")

local state = {
    job_id = nil,
    selected_music_files = nil,
    path = nil,
    stop_music = false,
}

-- 异步播放本地歌曲的函数
local function play_music_async(song_path, loop, shuffle)
    -- 检查歌曲文件是否存在
    if vim.fn.filereadable(song_path) == 0 and vim.fn.isdirectory(song_path) == 0 then
        print("Neither file or directory exists")
        return
    end

    local job = { "mpv", "--no-video", "--input-ipc-server=/tmp/mpvsocket", song_path }

    -- 设置 loop 和 shuffle
    if vim.fn.isdirectory(song_path) == 1 and shuffle then
        table.insert(job, "--shuffle")
    end
    if loop then
        if vim.fn.isdirectory(song_path) == 1 then
            table.insert(job, "--loop-playlist=" .. M.max_loop)
        else
            table.insert(job, "--loop=" .. M.max_loop)
        end
    end

    -- 如果已有播放任务在运行，先终止它
    if state.job_id then
        vim.fn.jobstop(state.job_id)
        state.job_id = nil
    end

    -- 异步执行命令来播放音乐
    state.job_id = vim.fn.jobstart(job, {
        on_stdout = function(_, data, _)
            if data then
                print(table.concat(data, "\n"))
            end
        end,
        on_stderr = function(_, data, _)
            if data then
                print(table.concat(data, "\n"))
            end
        end,
        on_exit = function(_, code, _)
            if code == 0 then
                print("Playing completed: " .. song_path)
            else
                if not state.stop_music then
                    print("Playing failed: " .. song_path)
                else
                    print("Playing stopped: " .. song_path)
                    state.stop_music = false
                end
            end
            state.job_id = nil
        end,
    })

    -- 检查任务是否启动成功
    if state.job_id <= 0 then
        print("Can't start playing.")
        state.job_id = nil
    else
        print("Playing currently: " .. song_path)
    end
end

-- 停止播放音乐的函数
local function stop_music()
    if state.job_id then
        vim.fn.jobstop(state.job_id)
        print("Playing has been stopped.")
        state.job_id = nil
        state.stop_music = true
        state.selected_music_files = nil
    else
        print("No music playing now.")
    end
end

-- 获取目录下的所有音乐文件
local function get_music_files(directory)
    local handle = io.popen('ls "' .. directory .. '"')
    local result = handle:read("*a")
    handle:close()
    local files = {}
    for file in string.gmatch(result, "[^\r\n]+") do
        if file:match("%.mp3$") or file:match("%.wav$") or file:match("%.flac$") then
            table.insert(files, directory .. "/" .. file)
        end
    end
    return files
end

-- 在默认音乐文件夹中搜索音乐文件
local function search_music_file(music_name)
    local music_files = get_music_files(vim.fn.expand(M.music_folder))
    files = {}
    for _, file in ipairs(music_files) do
        if file:match(music_name) then
            table.insert(files, file)
        end
    end
    if #files == 0 then
        return nil
    else
        return files
    end
end

-- 得到列表的最大长度
local function get_max_length(strings)
    local max_length = 0
    for _, str in ipairs(strings) do
        if #str > max_length then
            max_length = #str
        end
    end
    return max_length
end

-- 创建浮窗选择器
local function create_float_win(files, callback)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
    vim.api.nvim_buf_set_option(buf, 'swapfile', false)

    local max_length = get_max_length(files)
    local width = max_length + 2
    local height = #files + 2
    local col = math.floor((vim.o.columns - width) / 2)
    local row = math.floor((vim.o.lines - height) / 2)
    local title = "Music"
    local title_pos = "center"

    local opts = {
        style = 'minimal',
        relative = 'editor',
        width = width,
        height = height,
        col = col,
        row = row,
        border = 'rounded',
        title = title,
        title_pos = title_pos,
    }

    local win = vim.api.nvim_open_win(buf, true, opts)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, files)
    vim.api.nvim_set_option_value('winhl', 'Normal:Normal,FloatBorder:Normal,Title:Normal', { win = win })

    -- 绑定回车和 ESC 键
    vim.api.nvim_buf_set_keymap(buf, 'n', '<CR>',
        ':lua select_file(' .. buf .. ',' .. win .. ', "' .. callback .. '")<CR>', { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', ':lua vim.api.nvim_win_close(' .. win .. ', true)<CR>',
        { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':lua vim.api.nvim_win_close(' .. win .. ', true)<CR>',
        { noremap = true, silent = true })

    return buf, win
end

-- 选择文件
function _G.select_file(buf, win, callback)
    local line = vim.api.nvim_win_get_cursor(win)[1]
    local choice = vim.api.nvim_buf_get_lines(buf, line - 1, line, false)[1]
    vim.api.nvim_win_close(win, true)
    if callback == "play_single_music" then
        play_music_async(choice, M.loop, false)
    elseif callback == "handle_folder_option" then
        handle_folder_option(choice)
    end
end

-- 处理文件夹选项
function _G.handle_folder_option(choice)
    if choice == "Play in sequence" then
        play_music_async(state.path, M.loop, false)
    elseif choice == "Play randomly" then
        play_music_async(state.path, M.loop, true)
    elseif choice == "Play single files" then
        -- 如果是目录，获取目录下的所有音乐文件
        if state.selected_music_files == nil then
            local path = vim.fn.expand(M.music_folder)
            local music_files = get_music_files(path)
            if #music_files == 0 then
                print("No music file found in the directory: " .. path)
                return
            end
            state.selected_music_files = music_files
        end
        create_float_win(state.selected_music_files, "play_single_music")
    end
end

M.setup = function(options)
    if options.music_folder then
        M.music_folder = options.music_folder
    end
    if options.loop then
        M.loop = options.loop
    end
    if options.max_loop then
        M.max_loop = options.max_loop
    end

    -- 创建 Neovim 命令
    vim.api.nvim_create_user_command('PlayMusicPause', function()
        pause.toggle_pause_music()
    end, {
        desc = 'Toggle music pause'
    })

    vim.api.nvim_create_user_command('PlayMusic', function(opts)
        path = opts.args
        if path == "" then
            state.path = vim.fn.expand(M.music_folder)
        else
            state.path = vim.fn.expand(path)
        end
        if vim.fn.isdirectory(state.path) == 1 then
            -- 提取文件夹内的音乐文件
            local music_files = get_music_files(state.path)
            if #music_files == 0 then
                print("No music file found in the directory: " .. state.path)
                return
            end
            state.selected_music_files = music_files
            -- 提供选项：随机播放或顺序播放或选择单一文件
            -- create_float_win({ "Play in sequence", "Play randomly", "Play single music" }, "handle_folder_option")
            create_float_win({ "Play in sequence", "Play randomly" }, "handle_folder_option")
        else
            -- 如果不是目录，检查是否为文件
            if vim.fn.filereadable(state.path) == 1 then
                play_music_async(state.path, M.loop, false)
            else
                -- 搜索默认音乐文件夹中的音乐文件
                local music_files = search_music_file(path)
                if music_files then
                    create_float_win(music_files, "play_single_music")
                else
                    print("No matching files found in the default music folder: " .. M.music_folder)
                end
            end
        end
    end, {
        nargs = '?', -- 参数为可选
        complete = 'file',
        desc = 'Play music asynchronously'
    })

    -- 选择播放音乐
    vim.api.nvim_create_user_command('PlayMusicChoose', function()
        local path = vim.fn.expand(M.music_folder)
        local music_files = get_music_files(path)
        if #music_files == 0 then
            print("No music file found in the directory: " .. path)
            return
        end
        state.selected_music_files = music_files
        create_float_win(state.selected_music_files, "play_single_music")
    end, { desc = "Choose music file in default folder" })

    -- 停止播放音乐
    vim.api.nvim_create_user_command('StopMusic', function()
        stop_music()
    end, {
        desc = 'Stop playing'
    })

    -- 下一首播放
    vim.api.nvim_create_user_command('PlayMusicNext', function()
        jump.next_music()
    end, { desc = 'Play next music in the playlist' })

    -- 上一首播放
    vim.api.nvim_create_user_command('PlayMusicPrev', function()
        jump.prev_music()
    end, { desc = 'Play previous music in the playlist' })

    -- 快进
    vim.api.nvim_create_user_command('PlayMusicForward', function()
        other_utils.forward_music()
    end, { desc = 'Fast forward the music' })

    -- 快退
    vim.api.nvim_create_user_command('PlayMusicRewind', function()
        other_utils.rewind_music()
    end, { desc = 'Rewind the music' })

    -- 增大音量
    vim.api.nvim_create_user_command('PlayMusicIncreaseVolume', function()
        other_utils.increase_volume()
    end, { desc = 'Increase the volume' })

    -- 减小音量
    vim.api.nvim_create_user_command('PlayMusicDecreaseVolume', function()
        other_utils.decrease_volume()
    end, { desc = 'Decrease the volume' })
end

return M
