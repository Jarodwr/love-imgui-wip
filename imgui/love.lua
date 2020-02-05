local cimguimodule = "cimgui" --set imgui directory location
local ffi = require "ffi"
local cdecl = require "imgui.cdefs"

local ffi_cdef = function(code)
    local ret, err = pcall(ffi.cdef, code)
    if not ret then
        local lineN = 1
        for line in code:gmatch("([^\n\r]*)\r?\n") do
            print(lineN, line)
            lineN = lineN + 1
        end
        print(err)
        error "bad cdef"
    end
end

assert(cdecl, "imgui.lua not properly build")
ffi.cdef(cdecl)

--load dll
local lib = ffi.load(cimguimodule)

-----------ImVec2 definition
local ImVec2
ImVec2 =
    ffi.metatype(
    "ImVec2",
    {
        __add = function(a, b)
            return ImVec2(a.x + b.x, a.y + b.y)
        end,
        __sub = function(a, b)
            return ImVec2(a.x - b.x, a.y - b.y)
        end,
        __unm = function(a)
            return ImVec2(-a.x, -a.y)
        end,
        __mul = function(a, b) --scalar mult
            if not ffi.istype(ImVec2, b) then
                return ImVec2(a.x * b, a.y * b)
            end
            return ImVec2(a * b.x, a * b.y)
        end,
        __tostring = function(v)
            return "ImVec2<" .. v.x .. "," .. v.y .. ">"
        end
    }
)
local ImVec4 = {}
ImVec4.__index = ImVec4
ImVec4 = ffi.metatype("ImVec4", ImVec4)
--the module
local M = {ImVec2 = ImVec2, ImVec4 = ImVec4, lib = lib}

if jit.os == "Windows" then
    function M.ToUTF(unc_str)
        local buf_len = lib.igImTextCountUtf8BytesFromStr(unc_str, nil) + 1
        local buf_local = ffi.new("char[?]", buf_len)
        lib.igImTextStrToUtf8(buf_local, buf_len, unc_str, nil)
        return buf_local
    end

    function M.FromUTF(utf_str)
        local wbuf_length = lib.igImTextCountCharsFromUtf8(utf_str, nil) + 1
        local buf_local = ffi.new("ImWchar[?]", wbuf_length)
        lib.igImTextStrFromUtf8(buf_local, wbuf_length, utf_str, nil, nil)
        return buf_local
    end
end

M.FLT_MAX = lib.igGET_FLT_MAX()

-----------ImGui_ImplLove2D
local ImGui_ImplLove2D = {}
ImGui_ImplLove2D.__index = ImGui_ImplLove2D

function ImGui_ImplLove2D.__new(sharedFontAtlas)
    local context = lib.igCreateContext(sharedFontAtlas)
    local io = lib.igGetIO()

    local state = {
        textureObject = love.graphics.newImage(
            love.image.newImageData(
                io.Fonts.TexWidth, io.Fonts.TexHeight, 'rgba8', io.Fonts.TexPixelsRGBA32
            )
        ),
        vertexFormat = { 
            {"VertexPosition", "float", 2}, 
            {"VertexTexCoord", "float", 2}, 
            {"VertexColor", "byte", 4}
        }
    }
    return state
end

function ImGui_ImplLove2D.__shutdown()
    lib.igShutDown()
end

function ImGui_ImplLove2D.__newFrame()
    local height, width = love.graphics.getDimensions()
    local io = lib.igGetIO()

    io.DisplaySize = ImVec2(width, height)
    io.DisplayFrameBufferScale = ImVec2(1.0, 1.0)

    io.DeltaTime = love.timer.getDelta()

    io.MouseDown[0] = self.mouse.pressed(1)
    io.MouseDown[1] = self.mouse.pressed(2)
    io.MouseDown[2] = self.mouse.pressed(3)

    io.MouseWheel = self.mouse.wheel
    self.mouse.wheel = 0

    -- io.MouseDrawCursor
    -- love.mouse.setVisible(not imgui.mouseDrawCursor)
    lib.igNewFrame()
end

function ImGui_ImplLove2D.__mouseMoved(x, y)
    lib.igGetIO().MousePos = love.window.hasMouseFocus() > 0 and ImVec2(x, y) or ImVec2(-1, -1)
end

function ImGui_ImplLove2D.__mousePressed(button)
    self.mouse.pressed[button] = true
end

function ImGui_ImplLove2D.__mouseReleased(button)
    self.mouse.pressed[button] = false
end

function ImGui_ImplLove2D.__wheelMoved(y)
    self.mouse.wheel = y > 0 and 1 or y < 0 and -1 or 0
end

local keymap = {
    ["tab"] = 1,
    ["left"] = 2,
    ["right"] = 3,
    ["up"] = 4,
    ["down"] = 5,
    ["pageup"] = 6,
    ["pagedown"] = 7,
    ["home"] = 8,
    ["end"] = 9,
    ["delete"] = 10,
    ["backspace"] = 11,
    ["return"] = 12,
    ["escape"] = 13,
    ["a"] = 14,
    ["c"] = 15,
    ["v"] = 16,
    ["x"] = 17,
    ["y"] = 18,
    ["z"] = 19
}

local function update_key(button, pressed)
    local io = lib.igGetIO()
    io.KeysDown[keymap[button]] = pressed
    io.KeyShift = love.keyboard.isDown("rshift") or love.keyboard.isDown("lshift")
    io.KeyCtrl = love.keyboard.isDown("rctrl") or love.keyboard.isDown("lctrl")
    io.KeyAlt = love.keyboard.isDown("ralt") or love.keyboard.isDown("lalt")
    io.KeySuper = love.keyboard.isDown("rsuper") or love.keyboard.isDown("lgui")
end

function ImGui_ImplLove2D.__keyPressed(button)
    update_key(button, true)
end

function ImGui_ImplLove2D.__keyReleased(button)
    update_key(button, false)
end

function ImGui_ImplLove2D.__textInput(text)
    lib.igGetIO().AddInputCharactersUTF8(text)
end

function ImGui_ImplLove2D.__getWantCapturedMouse()
    return lib.igGetIO().WantCapturedMouse
end

function ImGui_ImplLove2D.__getWantCapturedKeyboard()
    return lib.igGetIO().WantCapturedKeyboard
end

function ImGui_ImplLove2D.__getWantTextInput()
    return lib.igGetIO().WantTextInput
end

function ImGui_ImplLove2D.__setGlobalFontFromFileTTF()
    local io = lib.igGetIO()
end

function ImGui_ImplLove2D.__getClipboardText()
    return love.system.getClipboardText()
end

function ImGui_Impl_SetClipboardText(text)
    
end

M.CreateContext = function(sharedFontAtlas)
    return ImGui_ImplLove2D.__new(sharedFontAtlas)
end

return M
