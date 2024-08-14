local M = {
    music_folder = "~/Music",
    loop = true,
    max_loop = "inf",
}

local pause = require("kinamusic.pause")
local jump = require("kinamusic.jumplist")
local other_utils = require("kinamusic.other_utils")
local gadgets = require("kinamusic.gadgets")

local state = {
    job_id = nil,
    stop_music = false,
}

-- 停止播放音乐的函数
local function stop_music()
    if state.job_id then
        vim.fn.jobstop(state.job_id)
        state.job_id = nil
        state.stop_music = true
    else
        print("No music playing now.")
    end
end


-- 异步播放本地歌曲的函数
local function play_music_async(path_or_list, loop, shuffle)
    -- 如果已有播放任务在运行，先终止它
    if state.job_id then
        stop_music()
    end

    local job = { "mpv", "--no-video", "--input-ipc-server=/tmp/mpvsocket" }
    if type(path_or_list) == "table" then
        for i = 1, #path_or_list do
            table.insert(job, path_or_list[i])
        end
        if loop then
            table.insert(job, "--loop-playlist=" .. M.max_loop)
        end
    else
        -- 检查歌曲文件是否存在
        if vim.fn.filereadable(path_or_list) == 0 and vim.fn.isdirectory(path_or_list) == 0 then
            print("Neither file or directory exists")
            return
        end

        -- 设置 loop 和 shuffle
        if vim.fn.isdirectory(path_or_list) == 1 and shuffle then
            table.insert(job, "--shuffle")
        end
        table.insert(job, path_or_list)
        if loop then
            if vim.fn.isdirectory(path_or_list) == 1 then
                table.insert(job, "--loop-playlist=" .. M.max_loop)
            else
                table.insert(job, "--loop=" .. M.max_loop)
            end
        end
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
                print("Playing completed: " .. path_or_list)
            else
                if not state.stop_music then
                    print("Playing failed: " .. path_or_list)
                else
                    print("Playing stopped: " .. path_or_list)
                    state.stop_music = false
                end
            end
        end,
    })

    -- 检查任务是否启动成功
    if state.job_id <= 0 then
        print("Can't start playing.")
        state.job_id = nil
    else
        print("Playing currently: " .. path_or_list)
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


-- telescope support
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values

local function select_music_file(opt)
    local music_list = nil
    if type(opt) == "table" then
        music_list = opt
    elseif vim.fn.isdirectory(opt) then
        music_list = get_music_files(opt)
        if #music_list == 0 then
            print("No music file found in the directory: " .. opt)
            return
        end
    end

    pickers.new({}, {
        prompt_title = 'Select Music File',
        finder = finders.new_table {
            results = music_list
        },
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr, map)
            local play_selected_music = function()
                local selection = action_state.get_selected_entry()
                if selection then
                    actions.close(prompt_bufnr)
                    play_music_async(selection.value, M.loop, false)
                end
            end
            map('i', '<CR>', play_selected_music)
            map('n', '<CR>', play_selected_music)
            return true
        end,
    }):find()
end

local function select_music_mode(expanded_path)
    if not expanded_path then
        print("No path provided.")
    end

    local choices = {
        "Play Single File",
        "Play Sequentially",
        "Play Randomly"
    }

    pickers.new({}, {
        prompt_title = 'Select Music Mode',
        finder = finders.new_table {
            results = choices
        },
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr, map)
            local play_selected_mode = function()
                local selection = action_state.get_selected_entry()
                if selection then
                    actions.close(prompt_bufnr)
                    if selection.value == "Play Single File" then
                        select_music_file(expanded_path)
                    elseif selection.value == "Play Sequentially" then
                        play_music_async(expanded_path, M.loop, false)
                    elseif selection.value == "Play Randomly" then
                        play_music_async(expanded_path, M.loop, true)
                    end
                end
            end
            map('i', '<CR>', play_selected_mode)
            map('n', '<CR>', play_selected_mode)
            return true
        end,
    }):find()
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
    vim.api.nvim_create_user_command('PlayMusic', function(opts)
        if gadgets.containSpace(opts.args) then
            local music_list = gadgets.split(opts.args, " ")
            for i = 1, #music_list do
                if vim.fn.filereadable(music_list[i]) == 0 then
                    print(music_list[i] .. "is not a file")
                end
                music_list[i] = vim.fn.expand(music_list[i])
            end
            play_music_async(music_list, M.loop, false)
            return
        end
        local path = opts.args
        local expanded_path = nil
        if path == "" then
            expanded_path = vim.fn.expand(M.music_folder)
        else
            expanded_path = vim.fn.expand(path)
        end
        if vim.fn.isdirectory(expanded_path) == 1 then
            select_music_mode(expanded_path)
        elseif vim.fn.filereadable(expanded_path) == 1 then
            -- 如果不是目录，检查是否为文件
            play_music_async(expanded_path, M.loop, false)
        else
            local music_list = search_music_file(opts.args)
            if music_list then
                select_music_file(music_list)
            else
                print(opts.args .. "is not a directory, file, or filename.")
            end
        end
    end, {
        nargs = '?', -- 参数为可选
        complete = 'file',
        desc = 'Play music asynchronously'
    })

    -- 暂停播放
    vim.api.nvim_create_user_command('PlayMusicPause', function()
        pause.toggle_pause_music()
    end, { desc = 'Toggle music pause' })

    -- 停止播放音乐
    vim.api.nvim_create_user_command('StopMusic', function()
        stop_music()
    end, { desc = 'Stop playing' })

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
