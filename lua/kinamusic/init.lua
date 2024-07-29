local M = {
    music_folder = "~/music",
}
-- 存储当前播放作业的 ID
local current_job_id = nil
M.music_folder = "~/music"
_G.stop_music = false

-- 异步播放本地歌曲的函数
local function play_music_async(song_path)
    -- 检查歌曲文件是否存在
    if vim.fn.filereadable(song_path) == 0 then
        print("File doesn't exist: " .. song_path)
        return
    end

    -- 如果已有播放作业在运行，先终止它
    if current_job_id then
        vim.fn.jobstop(current_job_id)
        current_job_id = nil
    end

    -- 异步执行命令来播放音乐
    current_job_id = vim.fn.jobstart({ "mpv", "--no-video", song_path }, {
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
                if not _G.stop_music then
                    print("Playing failed: " .. song_path)
                else
                    print("Playing stopped: " .. song_path)
                    _G.stop_music = false
                end
            end
            current_job_id = nil
        end,
    })

    -- 检查作业是否启动成功
    if current_job_id <= 0 then
        print("Can't start playing.")
        current_job_id = nil
    else
        print("Playing currently: " .. song_path)
    end
end

-- 停止播放音乐的函数
local function stop_music()
    if current_job_id then
        vim.fn.jobstop(current_job_id)
        print("Playing has been stopped.")
        current_job_id = nil
        _G.stop_music = true
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
    for _, file in ipairs(music_files) do
        if file:match(music_name) then
            return file
        end
    end
    return nil
end

-- 顺序或随机播放文件夹中的音乐文件
local function play_music_files_in_order(order)
    local music_files = _G.selected_music_files
    if order == "Play in sequence" then
        for _, file in ipairs(music_files) do
            play_music_async(file)
        end
    elseif order == "Play randomly" then
        -- 随机打乱文件列表
        math.randomseed(os.time())
        for i = #music_files, 2, -1 do
            local j = math.random(i)
            music_files[i], music_files[j] = music_files[j], music_files[i]
        end
        for _, file in ipairs(music_files) do
            play_music_async(file)
        end
    end
end

-- 创建浮窗选择器
local function create_float_win(files, callback)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
    vim.api.nvim_buf_set_option(buf, 'swapfile', false)

    local width = 80
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

    -- 绑定回车和 ESC 键
    vim.api.nvim_buf_set_keymap(buf, 'n', '<CR>',
        ':lua select_file(' .. buf .. ',' .. win .. ', "' .. callback .. '")<CR>', { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', ':lua vim.api.nvim_win_close(' .. win .. ', true)<CR>',
        { noremap = true, silent = true })

    return buf, win
end

-- 选择文件
function _G.select_file(buf, win, callback)
    local line = vim.api.nvim_win_get_cursor(win)[1]
    local choice = vim.api.nvim_buf_get_lines(buf, line - 1, line, false)[1]
    vim.api.nvim_win_close(win, true)
    if callback == "play_music_async" then
        play_music_async(choice)
    elseif callback == "handle_folder_option" then
        handle_folder_option(choice)
    end
end

-- 处理文件夹选项
function _G.handle_folder_option(option)
    if option == "Play in sequence" or option == "Play randomly" then
        play_music_files_in_order(option)
    elseif option == "Play single files" then
        create_float_win(_G.selected_music_files, "play_music_async")
    end
end

M.setup = function(options)
    if options.music_folder then
        M.music_folder = options.music_folder
    end

    -- 创建 Neovim 命令
    vim.api.nvim_create_user_command('PlayMusic', function(opts)
        local path = opts.args
        if path == "" then
            path = vim.fn.expand(M.music_folder)
        else
            path = vim.fn.expand(path)
        end
        if vim.fn.isdirectory(path) == 1 then
            -- 如果是目录，获取目录下的所有音乐文件
            local music_files = get_music_files(path)
            if #music_files == 0 then
                print("No music file found in the directory: " .. path)
                return
            end
            _G.selected_music_files = music_files
            -- 提供选项：随机播放或顺序播放
            create_float_win({ "Play in sequence", "Play randomly", "Play single files" }, "handle_folder_option")
        else
            -- 如果不是目录，检查是否为文件
            if vim.fn.filereadable(path) == 1 then
                play_music_async(path)
            else
                -- 搜索默认音乐文件夹中的音乐文件
                local music_file = search_music_file(path)
                if music_file then
                    play_music_async(music_file)
                else
                    print("No matching files found in the default music folder: " .. path)
                end
            end
        end
    end, {
        nargs = '?', -- 参数为可选
        complete = 'file',
        desc = 'Play music asynchronously'
    })

    -- 停止播放音乐
    vim.api.nvim_create_user_command('StopMusic', function()
        stop_music()
    end, {
        desc = 'Stop playing'
    })
end

return M
