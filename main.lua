local imgui = require "imgui"

local instance
love.load = function(table)
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

love.keypressed = function(button)
    instance:__keyPressed(button)
end

love.keyreleased = function(button)
    instance:__keyReleased(button)
end

love.mousemoved = function(x, y)
    instance:__mouseMoved(x, y)

end

love.mousepressed = function(x, y, button, istouch, presses)
    instance:__mousePressed(button)
end

love.mousereleased = function(x, y, button)
    instance:__mouseReleased(button)
end

love.wheelmoved = function(y)
    instance:__wheelMoved(y)
end

love.textinput = function(text)
    instance:__textInput(text)
end

love.quit = function()
end