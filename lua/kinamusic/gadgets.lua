local M = {}
M.split = function(str, reps)
    local resultStrList = {}
    string.gsub(str, '[^' .. reps .. ']+', function(w)
        table.insert(resultStrList, w)
    end)
    return resultStrList
end

M.containSpace = function(str)
    local pos = string.find(str, " ")
    if pos then
        return true
    else
        return false
    end
end

return M
