local imgui = require "imgui.love"

love.load = function(table)
    -- for k, v in pairs(imgui.lib) do
    --     print(k)
    -- end
    -- print(imgui)
    -- print(imgui.lib)
    -- print(imgui.lib.igGetDrawData())
    print(imgui.CreateContext())
end

love.update = function(dt)
end

love.draw = function()
end

love.quit = function()
end