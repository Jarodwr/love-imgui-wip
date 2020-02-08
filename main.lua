local imgui = require "imgui.love"

local instance
love.load = function(table)
    -- for k, v in pairs(imgui.lib) do
    --     print(k)
    -- end
    -- print(imgui)
    -- print(imgui.lib)
    -- print(imgui.lib.igGetDrawData())
    instance = imgui.CreateContext()
    print(instance)
end

love.update = function(dt)
    instance:newFrame()
    imgui.lib.igButton("Hello!", imgui.ImVec2(20, 20))
end

love.draw = function()
    instance:render()
end

love.quit = function()
end