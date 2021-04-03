-- Shim accross some methods only in Creator Tools
local sep = package.config:sub(1,1)

scriptPath = '.'

filesystem = {
    preferred = function(path)
        return path:gsub('/', sep)
    end
}