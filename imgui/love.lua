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

-----------imgui
local imgui = {}
imgui.__index = imgui

function imgui.__shutdown()
    lib.igShutDown()
end

function imgui:render()
    lib.igRender()
    local drawData = lib.igGetDrawData()
    do --Check if the frame buffer dimensions are both above 0
        local io = lib.igGetIO()
        local frameBufferWidth = io.DisplaySize.x * io.DisplayFramebufferScale.x
        local frameBufferHeight = io.DisplaySize.y * io.DisplayFramebufferScale.y

        if frameBufferWidth == 0 or frameBufferHeight == 0 then
            return
        end
        lib.ImDrawData_ScaleClipRects(drawData, io.DisplayFramebufferScale)
    end

    for i = 0, drawData.CmdListsCount - 1 do
        local cmdList = drawData.CmdLists[i]

        local idx = {}
        for j = 1, cmdList.IdxBuffer.Size do
            idx[j] = cmdList.IdxBuffer.Data[j - 1] + 1
        end

        local verticesSize = cmdList.VtxBuffer.Size * ffi.sizeof "ImDrawVert"
        local verticesData = ffi.string(cmdList.VtxBuffer.Data, verticesSize)

        local renderMesh =
            love.graphics.newMesh(
            {
                {"VertexPosition", "float", 2},
                {"VertexTexCoord", "float", 2},
                {"VertexColor", "byte", 4}
            },
            love.image.newImageData(verticesSize / 4, 1, "rgba8", verticesData)
        )
        renderMesh:setTexture(self.textureObject)
        renderMesh:setVertexMap(idx)

        local position = 1

        for cmd_i = 0, cmdList.CmdBuffer.Size-1 do
            local pcmd = cmdList.CmdBuffer.Data[cmd_i]
            local vertexCount = pcmd.ElemCount
            local vertexPosition = position
            position = position + pcmd.ElemCount

            love.graphics.setBlendMode "alpha"
            if pcmd.TextureId == nil then
                renderMesh:setTexture(self.textureObject)
            else
                local currentTexture = pcmd.TextureId[0]
                local texture = self.textures[currentTexture]
                if texture:typeOf "Canvas" then
                    love.graphics.setBlendMode("alpha", "premultiplied")
                end
                renderMesh:setTexture(texture)
            end

            love.graphics.setScissor(
                pcmd.ClipRect.x,
                pcmd.ClipRect.y,
                pcmd.ClipRect.z - pcmd.ClipRect.x,
                pcmd.ClipRect.w - pcmd.ClipRect.y
            )
            
            renderMesh:setDrawRange(vertexPosition, vertexCount)
            love.graphics.draw(renderMesh)
        end

        love.graphics.setScissor()
    end
end

function imgui:newFrame()
    local height, width = love.graphics.getDimensions()
    local io = lib.igGetIO()

    io.DisplaySize = ImVec2(width, height)
    io.DisplayFramebufferScale = ImVec2(1.0, 1.0)

    io.DeltaTime = love.timer.getDelta()

    io.MouseDown[0] = self.mouse.pressed[1]
    io.MouseDown[1] = self.mouse.pressed[2]
    io.MouseDown[2] = self.mouse.pressed[3]

    io.MouseWheel = self.mouse.wheel
    self.mouse.wheel = 0

    love.mouse.setVisible(not io.MouseDrawCursor)
    
    self.textures = nil

    lib.igNewFrame()
end

function imgui:__mouseMoved(x, y)
    lib.igGetIO().MousePos = love.window.hasMouseFocus() and ImVec2(x, y) or ImVec2(-1, -1)
end

function imgui:__mousePressed(button)
    self.mouse.pressed[button] = true
end

function imgui:__mouseReleased(button)
    self.mouse.pressed[button] = false
end

function imgui:__wheelMoved(y)
    self.mouse.wheel = y > 0 and 1 or y < 0 and -1 or 0
end

local function update_key(button, pressed)
    local io = lib.igGetIO()
    if keymap[button] then
        io.KeysDown[keymap[button]] = pressed
    end
    io.KeyShift = love.keyboard.isDown("rshift") or love.keyboard.isDown("lshift")
    io.KeyCtrl = love.keyboard.isDown("rctrl") or love.keyboard.isDown("lctrl")
    io.KeyAlt = love.keyboard.isDown("ralt") or love.keyboard.isDown("lalt")
    io.KeySuper = love.keyboard.isDown("rgui") or love.keyboard.isDown("lgui")
end

function imgui:__keyPressed(button)
    update_key(button, true)
end

function imgui:__keyReleased(button)
    update_key(button, false)
end

function imgui:__textInput(text)
    lib.igGetIO().AddInputCharactersUTF8(text)
end

function imgui:__getWantCapturedMouse()
    return lib.igGetIO().WantCapturedMouse
end

function imgui:__getWantCapturedKeyboard()
    return lib.igGetIO().WantCapturedKeyboard
end

function imgui:__getWantTextInput()
    return lib.igGetIO().WantTextInput
end

-- function imgui.__setGlobalFontFromFileTTF()
--     local io = lib.igGetIO()
-- end

-- function imgui.__getClipboardText()
--     return love.system.getClipboardText()
-- end

-- function imgui.__SetClipboardText(text)
-- end

local function generateTextureObject(texture)
    local pi = ffi.new("unsigned char*[1]")
    local wi, hi = ffi.new("int[1]"), ffi.new("int[1]")
    local bpp = ffi.new("int[1]")

    lib.ImFontAtlas_GetTexDataAsRGBA32(texture, pi, wi, hi, bpp)

    local width, height = wi[0], hi[0]
    local pixels = ffi.string(pi[0], width * height * 4)
    return love.graphics.newImage(love.image.newImageData(width, height, "rgba8", pixels))
end

M.CreateContext = function(sharedFontAtlas)
    local context = lib.igCreateContext(sharedFontAtlas)
    local io = lib.igGetIO()

    local wrapper =
        setmetatable(
        {
            context = context,
            textures = {},
            textureObject = generateTextureObject(io.Fonts),
            time = 0,
            mouse = {
                pressed = {false, false, false},
                justPressed = {false, false, false, false, false},
                cursors = {},
                wheel = 0
            },
            fontTexture = nil,
            handle = {
                shader = 0,
                vert = 0,
                frag = 0,
                vbo = 0,
                vao = 0,
                elements = 0
            },
            attribLocation = {
                tex = 0,
                projMtx = 0,
                position = 0,
                uv = 0,
                color = 0
            }
        },
        imgui
    )

    for cursor_n = 0, lib.ImGuiMouseCursor_COUNT do
        wrapper.mouse.cursors[cursor_n] = 0
    end

    io.KeyMap[lib.ImGuiKey_Tab] = keymap["tab"]
    io.KeyMap[lib.ImGuiKey_LeftArrow] = keymap["left"]
    io.KeyMap[lib.ImGuiKey_RightArrow] = keymap["right"]
    io.KeyMap[lib.ImGuiKey_UpArrow] = keymap["up"]
    io.KeyMap[lib.ImGuiKey_DownArrow] = keymap["down"]
    io.KeyMap[lib.ImGuiKey_PageUp] = keymap["pageup"]
    io.KeyMap[lib.ImGuiKey_PageDown] = keymap["pagedown"]
    io.KeyMap[lib.ImGuiKey_Home] = keymap["home"]
    io.KeyMap[lib.ImGuiKey_End] = keymap["end"]
    io.KeyMap[lib.ImGuiKey_Delete] = keymap["delete"]
    io.KeyMap[lib.ImGuiKey_Backspace] = keymap["backspace"]
    io.KeyMap[lib.ImGuiKey_Enter] = keymap["return"]
    io.KeyMap[lib.ImGuiKey_Escape] = keymap["escape"]
    io.KeyMap[lib.ImGuiKey_A] = keymap["a"]
    io.KeyMap[lib.ImGuiKey_C] = keymap["c"]
    io.KeyMap[lib.ImGuiKey_V] = keymap["v"]
    io.KeyMap[lib.ImGuiKey_X] = keymap["x"]
    io.KeyMap[lib.ImGuiKey_Y] = keymap["y"]
    io.KeyMap[lib.ImGuiKey_Z] = keymap["z"]

    -- io.SetClipboardTextFn = ImGui_Impl_SetClipboardText;
    -- io.GetClipboardTextFn = ImGui_Impl_GetClipboardText;

    io.Fonts.TexID = nil

    love.filesystem.createDirectory("/")
    io.IniFilename = love.filesystem.getSaveDirectory() .. "/imgui.ini"

    return wrapper
end

return M
