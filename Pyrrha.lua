script_name("Pyrrha")
script_author("rmux")
script_version("1.1")
script_dependencies("SAMP")

require "lib.moonloader"
local sampev = require 'lib.samp.events'
local akey = require('vkeys')
local imgui = require 'imgui'
local encoding = require 'encoding'
local memory = require 'memory'
local ffi = require 'ffi'
local lfs = require 'lfs'
local dlstatus = require('moonloader').download_status

encoding.default = 'CP1251'
local u8 = encoding.UTF8

-- ===============================================================================
-- [FFI DEFINITIONS]
-- ===============================================================================
local getBonePosition = ffi.cast("int (__thiscall*)(void*, float*, int, bool)", 0x5E4280)
local bonePosVec = ffi.new("float[3]")

-- ===============================================================================
-- [CONFIGURATION & CONSTANTS]
-- ===============================================================================
local CONSTANTS = {
    MIN_DRIFT_SPEED = 5.0,
    SPEED_CALIBRATION = 0.847,
    HIGH_SPEED_THRESHOLD = 150.0,
    GROUND_STICK_FORCE = 0.15,
    LOG_FILE = "moonloader/Pyrrha_log.txt",
    CONFIG_FILE = "moonloader/Pyrrha_keybinds.cfg",
    SETTINGS_DIR = "moonloader/config/Pyrrha/",
    DEFAULT_SETTINGS = "default.cfg"
}

-- ===============================================================================
-- [STATE MANAGEMENT]
-- ===============================================================================
local Features = {
    Global = {
        scriptEnabled = true,
        reconnectDelay = 5,
        activeTab = 1,
        checkUpdate = true
    },
    Weapon = {
        spread = false,
        norl = false,
        instantCrosshair = false,
        patch_showCrosshairInstantly = nil,
        hitsound = false
    },
    Visual = {
        espEnabled = false,
        linesEnabled = false,
        skeletonEnabled = false,
        headDot = false,
        infoBarEnabled = false,
        boxThickness = 0.005,
        fovEnabled = false,
        fovRadius = 100,
        nameTags = false,
        distanceTags = false,
        espStyle = 0
    },
    Car = {
        driftMode = false,
        driftType = "toggle",
        accelMode = false,
        targetSpeed = 0,
        currentTargetSpeed = 0,
        speedIncrement = 10,
        damageMult = 1.0,
        groundStick = true,
        perfectHandling = false,
        tankMode = false,
        gmCar = false,
        gmWheels = false,
        antiBoom = false,
        waterDrive = false,
        fireCar = false,
        fixWheels = false,
        fastExit = false,
        lastHP = 1000,
        justGotInCar = true,
        shiftPressed = false
    },
    Misc = {
        antiStun = false,
        fakeAfk = false,
        fakeLag = false,
        noFall = false,
        oxygen = false,
        megaJump = false,
        bmxMegaJump = false,
        godMode = false,
        noBikeFall = false,
        quickStop = false
    },
    Config = {
        list = {},
        selected = 0
    }
}

-- ImGui Buffers
local UI_Buffers = {
    mainWindow = imgui.ImBool(false),
    damageMult = imgui.ImFloat(1.0),
    targetSpeed = imgui.ImInt(0),
    driftType = imgui.ImInt(1),
    boxThickness = imgui.ImFloat(0.005),
    infoBar = imgui.ImBool(false),
    hitsound = imgui.ImBool(false),
    nameTags = imgui.ImBool(false),
    distanceTags = imgui.ImBool(false),
    headDot = imgui.ImBool(false),
    espStyle = imgui.ImInt(0),
    speedIncrement = imgui.ImInt(10),
    antiBoom = imgui.ImBool(false),
    quickStop = imgui.ImBool(false),
    gmWheels = imgui.ImBool(false),
    perfectHandling = imgui.ImBool(false),
    tankMode = imgui.ImBool(false),
    groundStick = imgui.ImBool(true),
    fastExit = imgui.ImBool(false),
    noFall = imgui.ImBool(false),
    oxygen = imgui.ImBool(false),
    megaJump = imgui.ImBool(false),
    bmxMegaJump = imgui.ImBool(false),
    godMode = imgui.ImBool(false),
    reconnectDelay = imgui.ImInt(5),
    configName = imgui.ImBuffer(256),
    configSelect = imgui.ImInt(0)
}

-- ===============================================================================
-- [KEYBINDS]
-- ===============================================================================
local font_info = renderCreateFont("Arial", 9, 5)

local keybinds = {
    menu_toggle = VK_U,
    esp_toggle = VK_F4,
    lines_toggle = VK_F5,
    drift_toggle = VK_LSHIFT,
    speed_boost = VK_LCONTROL,
    speed_increase = VK_P,
    speed_decrease = VK_L,
    speed_toggle = VK_O,
    antistun_toggle = VK_F3,
    fakeafk_toggle = VK_F6,
    fakelag_toggle = VK_F7,
    nospread_toggle = VK_F8,
    godmode_toggle = VK_F9,
    waterdrive_toggle = VK_F10,
    firecar_toggle = VK_F11,
    instant_crosshair_toggle = VK_F12,
    noreload_toggle = VK_F2,
    reconnect_key = VK_0
}

local keybind_names = {
    menu_toggle = "Menu Toggle", esp_toggle = "ESP Toggle", lines_toggle = "Lines Toggle",
    drift_toggle = "Drift Key", speed_boost = "Speed Boost", speed_increase = "Speed Increase",
    speed_decrease = "Speed Decrease", speed_toggle = "Speed Control Toggle",
    antistun_toggle = "AntiStun Toggle", fakeafk_toggle = "FakeAFK Toggle",
    fakelag_toggle = "FakeLag Toggle", nospread_toggle = "NoSpread Toggle",
    godmode_toggle = "GodMode Toggle", waterdrive_toggle = "WaterDrive Toggle",
    firecar_toggle = "FireCar Toggle", instant_crosshair_toggle = "Instant Crosshair Toggle",
    noreload_toggle = "NoReload Toggle", reconnect_key = "Reconnect (Hold LShift)"
}

local key_names = {
    [VK_LBUTTON] = "LMB", [VK_RBUTTON] = "RMB", [VK_MBUTTON] = "MMB", [VK_BACK] = "Backspace", 
    [VK_TAB] = "Tab", [VK_RETURN] = "Enter", [VK_LSHIFT] = "L.Shift", [VK_RSHIFT] = "R.Shift", 
    [VK_LCONTROL] = "L.Ctrl", [VK_RCONTROL] = "R.Ctrl", [VK_LMENU] = "L.Alt", [VK_RMENU] = "R.Alt",
    [VK_SPACE] = "Space", [VK_PRIOR] = "Page Up", [VK_NEXT] = "Page Down", [VK_END] = "End", 
    [VK_HOME] = "Home", [VK_LEFT] = "Left", [VK_UP] = "Up", [VK_RIGHT] = "Right", 
    [VK_DOWN] = "Down", [VK_INSERT] = "Insert", [VK_DELETE] = "Delete", [VK_F1] = "F1",
    [VK_F2] = "F2", [VK_F3] = "F3", [VK_F4] = "F4", [VK_F5] = "F5", [VK_F6] = "F6", [VK_F7] = "F7",
    [VK_F8] = "F8", [VK_F9] = "F9", [VK_F10] = "F10", [VK_F11] = "F11", [VK_F12] = "F12"
}
for i = 48, 57 do key_names[i] = string.char(i) end
for i = 65, 90 do key_names[i] = string.char(i) end
for i = 96, 105 do key_names[i] = "Num " .. (i-96) end

local waiting_for_key = nil

-- ===============================================================================
-- [CORE FUNCTIONS]
-- ===============================================================================
function writeLog(message)
    local file = io.open(CONSTANTS.LOG_FILE, "a")
    if file then
        file:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. message .. "\n")
        file:close()
    end
end

function ensureConfigDir()
    if not lfs.attributes("moonloader/config", "mode") then lfs.mkdir("moonloader/config") end
    if not lfs.attributes(CONSTANTS.SETTINGS_DIR, "mode") then lfs.mkdir(CONSTANTS.SETTINGS_DIR) end
end

function refreshConfigList()
    ensureConfigDir()
    Features.Config.list = {}
    for file in lfs.dir(CONSTANTS.SETTINGS_DIR) do
        if file ~= "." and file ~= ".." and file:match("%.cfg$") then
            table.insert(Features.Config.list, file)
        end
    end
end

function syncUIBuffers()
    UI_Buffers.damageMult.v = Features.Car.damageMult
    UI_Buffers.targetSpeed.v = Features.Car.currentTargetSpeed
    
    local dTypes = {hold=0, toggle=1, always=2}
    if dTypes[Features.Car.driftType] then UI_Buffers.driftType.v = dTypes[Features.Car.driftType] end
    
    UI_Buffers.boxThickness.v = Features.Visual.boxThickness
    UI_Buffers.infoBar.v = Features.Visual.infoBarEnabled
    UI_Buffers.hitsound.v = Features.Weapon.hitsound
    UI_Buffers.nameTags.v = Features.Visual.nameTags
    UI_Buffers.distanceTags.v = Features.Visual.distanceTags
    UI_Buffers.headDot.v = Features.Visual.headDot
    UI_Buffers.espStyle.v = Features.Visual.espStyle
    UI_Buffers.speedIncrement.v = Features.Car.speedIncrement
    UI_Buffers.antiBoom.v = Features.Car.antiBoom
    UI_Buffers.quickStop.v = Features.Misc.quickStop
    UI_Buffers.gmWheels.v = Features.Car.gmWheels
    UI_Buffers.perfectHandling.v = Features.Car.perfectHandling
    UI_Buffers.tankMode.v = Features.Car.tankMode
    UI_Buffers.groundStick.v = Features.Car.groundStick
    UI_Buffers.fastExit.v = Features.Car.fastExit
    UI_Buffers.noFall.v = Features.Misc.noFall
    UI_Buffers.oxygen.v = Features.Misc.oxygen
    UI_Buffers.megaJump.v = Features.Misc.megaJump
    UI_Buffers.bmxMegaJump.v = Features.Misc.bmxMegaJump
    UI_Buffers.godMode.v = Features.Misc.godMode
    UI_Buffers.reconnectDelay.v = Features.Global.reconnectDelay
end

function saveSettings(filename)
    ensureConfigDir()
    local name = filename or CONSTANTS.DEFAULT_SETTINGS
    local path = CONSTANTS.SETTINGS_DIR .. name
    local file = io.open(path, "w")
    if file then
        for catName, catTable in pairs(Features) do
            if catName ~= "Config" then
                for key, value in pairs(catTable) do
                    -- Exclude runtime variables and patches from saving
                    if type(value) ~= "function" and type(value) ~= "table" 
                    and key ~= "patch_showCrosshairInstantly" 
                    and key ~= "lastHP" 
                    and key ~= "justGotInCar" 
                    and key ~= "shiftPressed" then
                        file:write(catName .. "." .. key .. "=" .. tostring(value) .. "\n")
                    end
                end
            end
        end
        file:close()
        sampAddChatMessage("{00FF00}[Pyrrha] Settings saved to " .. name, -1)
        refreshConfigList()
    end
end

function loadSettings(filename)
    local path = CONSTANTS.SETTINGS_DIR .. (filename or CONSTANTS.DEFAULT_SETTINGS)
    
    -- Fallback for legacy settings file
    if not filename and not lfs.attributes(path, "mode") then
        local oldPath = "moonloader/Pyrrha_settings.cfg"
        if lfs.attributes(oldPath, "mode") then path = oldPath end
    end

    local file = io.open(path, "r")
    if file then
        for line in file:lines() do
            local cat, key, value = line:match("([^%.]+)%.([^=]+)=(.+)")
            if cat and key and value and Features[cat] then
                if value == "true" then value = true
                elseif value == "false" then value = false
                elseif tonumber(value) then value = tonumber(value) end
                Features[cat][key] = value
            end
        end
        file:close()
        
        -- Apply side effects (hooks/patches) that aren't handled in the main loop
        nopHook('onSendPlayerSync', Features.Misc.fakeAfk)
        nopHook('onSendVehicleSync', Features.Misc.fakeAfk)
        nopHook('onSendPassengerSync', Features.Misc.fakeAfk)
        showCrosshairInstantlyPatch(Features.Weapon.instantCrosshair)
        
        syncUIBuffers()
        writeLog("Settings loaded from " .. path)
        if filename then sampAddChatMessage("{00FF00}[Pyrrha] Loaded config: " .. filename, -1) end
    else
        if filename then sampAddChatMessage("{FF0000}[Pyrrha] Config not found: " .. filename, -1) end
    end
end

function getKeyName(keyCode) return key_names[keyCode] or "Key " .. keyCode end
function getFPS() return memory.getfloat(0xB7CB50, 4, false) end

function performReconnect(delay)
    lua_thread.create(function()
        local ip, port = sampGetCurrentServerAddress()
        local sname = sampGetCurrentServerName()
        sampAddChatMessage("{AAAAAA}[Pyrrha] {FFFFFF}Reconnecting in {FF0000}" .. delay .. "{FFFFFF} seconds...", -1)
        sampSetGamestate(0)
        sampDisconnectWithReason(1)
        wait(delay * 1000)
        sampConnectToServer(ip, port)
        sampAddChatMessage("{AAAAAA}[Pyrrha] {FFFFFF}Connecting to {00FF00}" .. sname, -1)
        writeLog("Performed reconnect to " .. ip .. ":" .. port)
    end)
end

function showCrosshairInstantlyPatch(enable)
    if enable then
        if not Features.Weapon.patch_showCrosshairInstantly then
            Features.Weapon.patch_showCrosshairInstantly = memory.read(0x0058E1D9, 1, true)
        end
        memory.write(0x0058E1D9, 0xEB, 1, true)
    elseif Features.Weapon.patch_showCrosshairInstantly ~= nil then
        memory.write(0x0058E1D9, Features.Weapon.patch_showCrosshairInstantly, 1, true)
        Features.Weapon.patch_showCrosshairInstantly = nil
    end
end

function getVehicleRotationVelocity(vehicle)
    local ptr = getCarPointer(vehicle)
    if ptr == 0 then return 0, 0, 0 end
    return memory.getfloat(ptr + 0x50), memory.getfloat(ptr + 0x54), memory.getfloat(ptr + 0x58)
end

function setVehicleRotationVelocity(vehicle, x, y, z)
    local ptr = getCarPointer(vehicle)
    if ptr == 0 then return end
    memory.setfloat(ptr + 0x50, x)
    memory.setfloat(ptr + 0x54, y)
    memory.setfloat(ptr + 0x58, z)
end

function nopHook(name, bool)
    sampev[name] = function()
        if bool then return false end
    end
end

function getBodyPartCoordinates(id, handle)
    local pedptr = getCharPointer(handle)
    if pedptr == 0 then return 0,0,0 end
    getBonePosition(ffi.cast("void*", pedptr), bonePosVec, id, true)
    return bonePosVec[0], bonePosVec[1], bonePosVec[2]
end

function check_for_update(force)
    -- Only run the check if the configuration setting is enabled or forced via button
    if not Features.Global.checkUpdate and not force then return end

    local url = 'https://raw.githubusercontent.com/Project-Pyrrha/Pyrrha/refs/heads/main/info/version.json'
    local filePath = os.getenv('TEMP') .. '\\version.json'

    downloadUrlToFile(url, filePath, function(id, status, p1, p2)
        if status == dlstatus.STATUS_ENDDOWNLOADDATA then
            local f = io.open(filePath, 'r')
            if f then
                local response = f:read('*a')
                f:close()
                os.remove(filePath)
                
                local info = decodeJson(response)
                local tag = "{00FF00}[Pyrrha] "
                local local_version = 1.1 -- Matches script_version
                
                if info and info.version then
                    local remote_version = tonumber(info.version)
                    
                    if local_version and remote_version then
                        if local_version == remote_version then
                            sampAddChatMessage(tag .. 'You are using {0E8604}the current {888EA0}version of the script', -1)
                        elseif local_version > remote_version then
                            sampAddChatMessage(tag .. 'You are using {F9D82F}the experimental {888EA0}version of the script', -1)
                        elseif local_version < remote_version then
                            sampAddChatMessage(tag .. 'A {F9D82F}new update {888EA0}is available!', -1)
                            sampAddChatMessage(
                                string.format(
                                    '{888EA0}Version: {F9D82F}%s {888EA0}| Codename: {F9D82F}%s {888EA0}| Date: {F9D82F}%s',
                                    info.version,
                                    info.codename or "Unknown",
                                    info.date or "Unknown"
                                ), 
                                -1
                            )
                            sampAddChatMessage(tag .. 'Download: {0E8604}https://github.com/Project-Pyrrha/Pyrrha', -1)
                        end
                    else
                        sampAddChatMessage(tag .. '{B31A06}Error: {888EA0}could not compare version numbers', -1)
                    end
                else
                    sampAddChatMessage(tag .. '{B31A06}Error: {888EA0}invalid JSON format', -1)
                end
            else
                sampAddChatMessage("{00FF00}[Pyrrha] {B31A06}Error: {888EA0}failed to read version file", -1)
            end
        end
    end)
end

function unfreeze_player()
    if isCharInAnyCar(PLAYER_PED) then
        local car = storeCarCharIsInNoSave(PLAYER_PED)
        freezeCarPosition(car, false)
    else
        setPlayerControl(PLAYER_HANDLE, true)
        freezeCharPosition(PLAYER_PED, false)
        clearCharTasksImmediately(PLAYER_PED)
    end
    restoreCameraJumpcut()
    sampAddChatMessage('{00FF00}[Pyrrha] You have been {29C730}unfrozen{FFFFFF}.', -1)
end

function explode_argb(argb)
    local a = bit.band(bit.rshift(argb, 24), 0xFF)
    local r = bit.band(bit.rshift(argb, 16), 0xFF)
    local g = bit.band(bit.rshift(argb, 8), 0xFF)
    local b = bit.band(argb, 0xFF)
    return a, r, g, b
end

function join_argb(a, r, g, b)
    return bit.bor(b, bit.lshift(g, 8), bit.lshift(r, 16), bit.lshift(a, 24))
end

-- ===============================================================================
-- [RENDERING & UI]
-- ===============================================================================
function drawVisuals()
    -- Combined visual loop for efficiency
    local visuals = Features.Visual
    if not visuals.espEnabled and not visuals.linesEnabled and not visuals.skeletonEnabled and not visuals.infoBarEnabled and not visuals.headDot then return end

    -- 1. Info Bar
    if visuals.infoBarEnabled then
        local sw, sh = getScreenResolution()
        local myX, myY, myZ = getCharCoordinates(PLAYER_PED)
        local fps = math.floor(getFPS())
        local ping = sampGetPlayerPing(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)))
        local time = os.date('%H:%M:%S')
        local text = string.format("FPS: %d | Ping: %d | Time: %s | Pos: %.1f, %.1f, %.1f", fps, ping, time, myX, myY, myZ)
        local tLen = renderGetFontDrawTextLength(font_info, text)
        renderDrawBoxWithBorder(sw/2 - tLen/2 - 10, sh - 30, tLen + 20, 20, 0xCC000000, 1, 0xFF800000)
        renderFontDrawText(font_info, text, sw/2 - tLen/2, sh - 28, 0xFFFFFFFF)
    end

    -- 2. Player Loop (ESP, Lines, Skeleton)
    if visuals.espEnabled or visuals.linesEnabled or visuals.skeletonEnabled or visuals.headDot then
        local sw, sh = getScreenResolution()
        local myX, myY, myZ = getCharCoordinates(PLAYER_PED)
        local myScreenX, myScreenY = convert3DCoordsToScreen(myX, myY, myZ)

        for id = 0, sampGetMaxPlayerId(true) do
            if sampIsPlayerConnected(id) then
                local exists, handle = sampGetCharHandleBySampPlayerId(id)
                if exists and doesCharExist(handle) and isCharOnScreen(handle) and handle ~= PLAYER_PED then
                    local x, y, z = getCharCoordinates(handle)
                    local dist = math.sqrt((x-myX)^2 + (y-myY)^2 + (z-myZ)^2)
                    
                    -- Standard Box ESP / Lines Data
                    local headx, heady = convert3DCoordsToScreen(x, y, z + 1.0)
                    local footx, footy = convert3DCoordsToScreen(x, y, z - 1.0)

                    -- Color Calculation
                    local color = sampGetPlayerColor(id)
                    local aa, rr, gg, bb = explode_argb(color)
                    local skelColor = join_argb(255, rr, gg, bb)
                    local espColor = join_argb(255, rr, gg, bb)

                    -- DRAW HEAD DOT
                    if visuals.headDot then
                        local hX, hY, hZ = getBodyPartCoordinates(8, handle)
                        local hSX, hSY = convert3DCoordsToScreen(hX, hY, hZ)
                        if hSX and hSY then
                            renderDrawBoxWithBorder(hSX - 4, hSY - 4, 8, 8, espColor, 1, 0xFF000000)
                        end
                    end

                    -- DRAW BOX ESP
                    if visuals.espEnabled and headx and heady then
                        local height = math.abs(footy - heady)
                        local width = math.abs(height * -0.25)
                        local borderThick = sh * visuals.boxThickness
                        
                        if visuals.espStyle == 0 then
                            -- Full Box
                            renderDrawBoxWithBorder(headx - width, heady, math.abs(2 * width), height, 0, borderThick, espColor)
                        else
                            -- Corner Box
                            local w = math.abs(2 * width)
                            local h = height
                            local x1, y1 = headx - width, heady
                            local lineL = w / 4
                            local lineH = h / 4
                            local T = 2

                            -- Top Left
                            renderDrawLine(x1, y1, x1 + lineL, y1, T, espColor)
                            renderDrawLine(x1, y1, x1, y1 + lineH, T, espColor)
                            -- Top Right
                            renderDrawLine(x1 + w, y1, x1 + w - lineL, y1, T, espColor)
                            renderDrawLine(x1 + w, y1, x1 + w, y1 + lineH, T, espColor)
                            -- Bottom Left
                            renderDrawLine(x1, y1 + h, x1 + lineL, y1 + h, T, espColor)
                            renderDrawLine(x1, y1 + h, x1, y1 + h - lineH, T, espColor)
                            -- Bottom Right
                            renderDrawLine(x1 + w, y1 + h, x1 + w - lineL, y1 + h, T, espColor)
                            renderDrawLine(x1 + w, y1 + h, x1 + w, y1 + h - lineH, T, espColor)
                        end
                        
                        -- HP/Armor Bars
                        local health = sampGetPlayerHealth(id)
                        local hpWidth = math.abs(2 * width) * math.min(math.max(health / 100.0, 0.0), 1.0)
                        renderDrawLine(headx - width, footy + 7, headx - width + hpWidth, footy + 7, 3, 0xFFFF0000)
                        
                        local armor = sampGetPlayerArmor(id)
                        if armor > 0 then
                            local armorWidth = math.abs(2 * width) * math.min(math.max(armor / 100.0, 0.0), 1.0)
                            renderDrawLine(headx - width, footy + 12, headx - width + armorWidth, footy + 12, 3, 0xFFFFFFFF)
                        end

                        -- Name Tags
                        if visuals.nameTags then
                            local name = sampGetPlayerNickname(id)
                            local tLen = renderGetFontDrawTextLength(font_info, name)
                            renderFontDrawText(font_info, name, headx - tLen/2, sh - 28, 0xFFFFFFFF)
                        end

                        -- Distance Tags
                        if visuals.distanceTags then
                            local dText = string.format("%.1fm", dist)
                            local tLen = renderGetFontDrawTextLength(font_info, dText)
                            local yOffset = (sampGetPlayerArmor(id) > 0) and 17 or 12
                            renderFontDrawText(font_info, dText, headx - tLen/2, footy + yOffset, 0xFFFFFFFF)
                        end
                    end

                    -- DRAW LINES
                    if visuals.linesEnabled and headx and myScreenX then
                        local height = math.abs(footy - heady)
                        renderDrawLine(sw / 2, sh, headx, heady + height / 2, 2.0, 0xFF00FFFF)
                    end

                    -- DRAW SKELETON (Ported from Zuwi)
                    if visuals.skeletonEnabled then
                        -- Main body parts linkage
                        local t = {3, 4, 5, 51, 52, 41, 42, 31, 32, 33, 21, 22, 23, 2}
                        for v = 1, #t do
                            local pos1X, pos1Y, pos1Z = getBodyPartCoordinates(t[v], handle)
                            local pos2X, pos2Y, pos2Z = getBodyPartCoordinates(t[v] + 1, handle)
                            local pos1_sX, pos1_sY = convert3DCoordsToScreen(pos1X, pos1Y, pos1Z)
                            local pos2_sX, pos2_sY = convert3DCoordsToScreen(pos2X, pos2Y, pos2Z)
                            
                            if pos1_sX and pos2_sX then
                                renderDrawLine(pos1_sX, pos1_sY, pos2_sX, pos2_sY, 1, skelColor)
                            end
                        end
                        
                        -- Connecting shoulders/hips to spine
                        for v = 4, 5 do
                            local pos2X, pos2Y, pos2Z = getBodyPartCoordinates(v * 10 + 1, handle)
                            local pos2_sX, pos2_sY = convert3DCoordsToScreen(pos2X, pos2Y, pos2Z)
                            local spineX, spineY, spineZ = getBodyPartCoordinates(4, handle) 
                            local spine_sX, spine_sY = convert3DCoordsToScreen(spineX, spineY, spineZ)

                            if pos2_sX and spine_sX then
                                renderDrawLine(spine_sX, spine_sY, pos2_sX, pos2_sY, 1, skelColor)
                            end
                        end

                        -- Draw Joints
                        local joints = {5, 4, 3, 2, 51, 52, 53, 41, 42, 43, 31, 32, 33, 21, 22, 23}
                        for _, jID in ipairs(joints) do
                            local jX, jY, jZ = getBodyPartCoordinates(jID, handle)
                            local jSX, jSY = convert3DCoordsToScreen(jX, jY, jZ)
                            if jSX and jSY then
                                renderDrawBoxWithBorder(jSX - 2, jSY - 2, 4, 4, skelColor, 1, 0xFF000000)
                            end
                        end
                    end
                end
            end
        end
    end
end

function apply_flux_style()
    imgui.SwitchContext()
    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col
    local ImVec4 = imgui.ImVec4

    -- PYRRHA THEME (Red Flame)
    style.WindowRounding = 10.0
    style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    style.ChildWindowRounding = 8.0
    style.FrameRounding = 6.0
    style.ItemSpacing = imgui.ImVec2(10, 8)
    style.ScrollbarSize = 12.0
    style.ScrollbarRounding = 12.0
    style.GrabMinSize = 12.0
    style.GrabRounding = 6.0
    
    -- Darker, cleaner background
    colors[clr.Text] = ImVec4(0.90, 0.90, 0.93, 1.00)
    colors[clr.TextDisabled] = ImVec4(0.40, 0.40, 0.45, 1.00)
    colors[clr.WindowBg] = ImVec4(0.07, 0.07, 0.09, 0.85)
    colors[clr.ChildWindowBg] = ImVec4(0.10, 0.10, 0.12, 0.60)
    colors[clr.PopupBg] = ImVec4(0.07, 0.07, 0.09, 0.90)
    colors[clr.Border] = ImVec4(0.25, 0.25, 0.30, 0.50)
    colors[clr.BorderShadow] = ImVec4(0.00, 0.00, 0.00, 0.00)
    
    -- Input fields
    colors[clr.FrameBg] = ImVec4(0.15, 0.15, 0.18, 1.00)
    colors[clr.FrameBgHovered] = ImVec4(0.20, 0.20, 0.24, 1.00)
    colors[clr.FrameBgActive] = ImVec4(0.25, 0.25, 0.30, 1.00)
    
    -- Title bar
    colors[clr.TitleBg] = ImVec4(0.07, 0.07, 0.09, 1.00)
    colors[clr.TitleBgActive] = ImVec4(0.07, 0.07, 0.09, 1.00)
    colors[clr.TitleBgCollapsed] = ImVec4(0.07, 0.07, 0.09, 1.00)
    
    -- Accents (Darker Red / Crimson)
    local accent = ImVec4(0.60, 0.00, 0.00, 1.00)
    local accent_hover = ImVec4(0.75, 0.05, 0.05, 1.00)
    local accent_active = ImVec4(0.90, 0.10, 0.10, 1.00)

    colors[clr.CheckMark] = accent
    colors[clr.SliderGrab] = accent
    colors[clr.SliderGrabActive] = accent_active
    colors[clr.Button] = ImVec4(0.15, 0.15, 0.18, 1.00)
    colors[clr.ButtonHovered] = accent_hover
    colors[clr.ButtonActive] = accent_active
    colors[clr.Header] = accent
    colors[clr.HeaderHovered] = accent_hover
    colors[clr.HeaderActive] = accent_active
    colors[clr.Separator] = ImVec4(0.25, 0.25, 0.30, 0.50)
    colors[clr.ResizeGrip] = ImVec4(0.26, 0.59, 0.98, 0.25)
    colors[clr.ResizeGripHovered] = ImVec4(0.26, 0.59, 0.98, 0.67)
    colors[clr.ResizeGripActive] = ImVec4(0.26, 0.59, 0.98, 0.95)
    colors[clr.TextSelectedBg] = ImVec4(0.26, 0.59, 0.98, 0.35)
    colors[clr.ModalWindowDarkening] = ImVec4(0.80, 0.80, 0.80, 0.35)
end

function CenterText(text)
    local width = imgui.GetWindowWidth()
    local calc = imgui.CalcTextSize(text)
    imgui.SetCursorPosX( width / 2 - calc.x / 2 )
    imgui.Text(text)
end

-- ===============================================================================
-- [IMGUI DRAW FRAME]
-- ===============================================================================
function imgui.OnDrawFrame()
    if UI_Buffers.mainWindow.v then
        imgui.SetNextWindowSize(imgui.ImVec2(720, 550), imgui.Cond.FirstUseEver)
        imgui.Begin(u8'Pyrrha Panel', UI_Buffers.mainWindow)

        imgui.BeginChild('##sidebar', imgui.ImVec2(160, -1), true)
            imgui.PushItemWidth(-1)
            if imgui.Button(Features.Global.activeTab == 1 and u8'> Weapon' or u8'Weapon', imgui.ImVec2(-1, 40)) then Features.Global.activeTab = 1 end
            if imgui.Button(Features.Global.activeTab == 2 and u8'> Visual' or u8'Visual', imgui.ImVec2(-1, 40)) then Features.Global.activeTab = 2 end
            if imgui.Button(Features.Global.activeTab == 3 and u8'> Car' or u8'Car', imgui.ImVec2(-1, 40)) then Features.Global.activeTab = 3 end
            if imgui.Button(Features.Global.activeTab == 4 and u8'> Misc' or u8'Misc', imgui.ImVec2(-1, 40)) then Features.Global.activeTab = 4 end
            if imgui.Button(Features.Global.activeTab == 5 and u8'> Keybinds' or u8'Keybinds', imgui.ImVec2(-1, 40)) then Features.Global.activeTab = 5 end
            if imgui.Button(Features.Global.activeTab == 7 and u8'> Configs' or u8'Configs', imgui.ImVec2(-1, 40)) then 
                Features.Global.activeTab = 7 
                refreshConfigList()
            end
            if imgui.Button(Features.Global.activeTab == 6 and u8'> About' or u8'About', imgui.ImVec2(-1, 40)) then Features.Global.activeTab = 6 end
            
            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()
            imgui.TextColored(imgui.ImVec4(0.80, 0.00, 0.00, 1.0), u8"Quick Actions")
            if imgui.Button(u8'Reconnect', imgui.ImVec2(-1, 30)) then performReconnect(Features.Global.reconnectDelay) end
            if imgui.Button(u8'Unfreeze', imgui.ImVec2(-1, 30)) then unfreeze_player() end
            if imgui.Button(u8'Fix Wheels', imgui.ImVec2(-1, 30)) then
                if isCharInAnyCar(PLAYER_PED) then
                    local veh = storeCarCharIsInNoSave(PLAYER_PED)
                    for i = 0, 3 do fixCarTire(veh, i) end
                    sampAddChatMessage("{00FF00}[Pyrrha] Wheels fixed!", -1)
                else
                    sampAddChatMessage("{FF0000}[Pyrrha] Not in vehicle!", -1)
                end
            end
            if imgui.Button(u8'Suicide', imgui.ImVec2(-1, 30)) then
                if not isCharInAnyCar(PLAYER_PED) then
                    setCharHealth(PLAYER_PED, 0)
                else
                    local myCar = storeCarCharIsInNoSave(PLAYER_PED)
                    setCarHealth(myCar, 0)
                end
            end
            imgui.PopItemWidth()
        imgui.EndChild()

        imgui.SameLine()

        imgui.BeginChild('##content', imgui.ImVec2(-1, -1), true)

        if Features.Global.activeTab == 1 then -- WEAPON
            CenterText(u8'WEAPON CONFIGURATION')
            imgui.Separator()
            imgui.Spacing()
            
            -- Checkboxes
            if imgui.Checkbox(u8'NoSpread', imgui.ImBool(Features.Weapon.spread)) then
                Features.Weapon.spread = not Features.Weapon.spread
                sampAddChatMessage(Features.Weapon.spread and '{00FF00}NoSpread ON' or '{FF0000}NoSpread OFF', -1)
            end
            imgui.SameLine()
            imgui.TextDisabled("(F8)")

            if imgui.Checkbox(u8'NoReload', imgui.ImBool(Features.Weapon.norl)) then
                Features.Weapon.norl = not Features.Weapon.norl
                sampAddChatMessage(Features.Weapon.norl and '{00FF00}NoReload ON' or '{FF0000}NoReload OFF', -1)
            end
            imgui.SameLine()
            imgui.TextDisabled("(F2)")

            if imgui.Checkbox(u8'Instant Crosshair', imgui.ImBool(Features.Weapon.instantCrosshair)) then
                Features.Weapon.instantCrosshair = not Features.Weapon.instantCrosshair
                showCrosshairInstantlyPatch(Features.Weapon.instantCrosshair)
                sampAddChatMessage(Features.Weapon.instantCrosshair and '{00FF00}Instant Crosshair ON' or '{FF0000}Instant Crosshair OFF', -1)
            end
            imgui.SameLine()
            imgui.TextDisabled("(F12)")

            if imgui.Checkbox(u8'Hitsound', UI_Buffers.hitsound) then
                Features.Weapon.hitsound = UI_Buffers.hitsound.v
            end

        elseif Features.Global.activeTab == 2 then -- VISUAL
            CenterText(u8'VISUAL CONFIGURATION')
            imgui.Separator()
            imgui.Spacing()

            -- Toggles
            if imgui.Checkbox(u8'Enable ESP (F4)', imgui.ImBool(Features.Visual.espEnabled)) then
                Features.Visual.espEnabled = not Features.Visual.espEnabled
            end
            if imgui.Checkbox(u8'Show Lines (F5)', imgui.ImBool(Features.Visual.linesEnabled)) then
                Features.Visual.linesEnabled = not Features.Visual.linesEnabled
            end
            if imgui.Checkbox(u8'Show Skeleton', imgui.ImBool(Features.Visual.skeletonEnabled)) then
                Features.Visual.skeletonEnabled = not Features.Visual.skeletonEnabled
            end
            if imgui.Checkbox(u8'Show Info Bar', UI_Buffers.infoBar) then
                Features.Visual.infoBarEnabled = UI_Buffers.infoBar.v
            end

            imgui.Spacing()
            imgui.Separator()
            imgui.Text("ESP Settings")
            
            -- ESP Specific Toggles
            imgui.Indent(20)
            if imgui.Checkbox(u8'Name Tags', UI_Buffers.nameTags) then Features.Visual.nameTags = UI_Buffers.nameTags.v end
            if imgui.Checkbox(u8'Distance Tags', UI_Buffers.distanceTags) then Features.Visual.distanceTags = UI_Buffers.distanceTags.v end
            if imgui.Checkbox(u8'Head Dot', UI_Buffers.headDot) then Features.Visual.headDot = UI_Buffers.headDot.v end
            imgui.Unindent(20)

            imgui.Spacing()
            
            -- Selectors & Sliders
            local styles = {u8'Full Box', u8'Corners'}
            imgui.PushItemWidth(150)
            if imgui.Combo(u8'ESP Style', UI_Buffers.espStyle, styles) then
                Features.Visual.espStyle = UI_Buffers.espStyle.v
            end
            imgui.PopItemWidth()

            if imgui.SliderFloat(u8'Box Thickness', UI_Buffers.boxThickness, 0.001, 0.01, "%.3f") then
                Features.Visual.boxThickness = UI_Buffers.boxThickness.v
            end

        elseif Features.Global.activeTab == 3 then -- CAR
            CenterText(u8'VEHICLE MANAGER')
            imgui.Separator()
            imgui.Columns(2, "CarCols", true)
            
            -- Left Column: Info & Speed
            imgui.TextColored(imgui.ImVec4(0.80, 0.00, 0.00, 1.0), u8"[ Vehicle Information ]")
            if isCharInAnyCar(PLAYER_PED) then
                local car = storeCarCharIsInNoSave(PLAYER_PED)
                local model = getCarModel(car)
                local speed = getCarSpeed(car)
                local health = getCarHealth(car)

                local carPtr = getCarPointer(car)
                local currentGear = 0
                if carPtr ~= 0 then
                    currentGear = memory.getint8(carPtr + 0x49C)
                end

                -- Calculate Handling Pointer
                local address = callFunction(0x00403DA0,1,1,model)
                local phandling = readMemory((address + 0x4A),2,false) * 0xE0 + 0xC2B9DC
                local maxGears = readMemory(phandling + 0x76, 1, false)

                imgui.Text(u8'Model ID: ' .. model)
                imgui.Text(u8'Gear: ' .. currentGear .. ' / ' .. maxGears) 
                imgui.Text(u8'Speed: ' .. string.format("%.1f", speed))
                
                local hp_frac = math.min(math.max(health / 1000.0, 0.0), 1.0)
                imgui.ProgressBar(hp_frac, imgui.ImVec2(-1, 0), string.format("%.0f HP", health))

                if imgui.Button(u8'Remove Gear Limit', imgui.ImVec2(-1, 20)) then
                    writeMemory(phandling + 0x76, 1, 20, false)
                    sampAddChatMessage("{00FF00}[Pyrrha] Gear limit set to 20!", -1)
                end
            else
                imgui.TextColored(imgui.ImVec4(1, 0, 0, 1), u8'Not in a vehicle')
            end
            
            imgui.Spacing()
            imgui.Separator()
            imgui.TextColored(imgui.ImVec4(0.80, 0.00, 0.00, 1.0), u8"[ Speed Control ]")
            
            -- Speed Toggles
            if imgui.Checkbox(u8'Auto Speed (O)', imgui.ImBool(Features.Car.accelMode)) then
                Features.Car.accelMode = not Features.Car.accelMode
            end
            
            -- Speed Inputs
            imgui.PushItemWidth(100)
            if imgui.InputInt(u8'Step', UI_Buffers.speedIncrement) then
                if UI_Buffers.speedIncrement.v < 1 then UI_Buffers.speedIncrement.v = 1 end
                Features.Car.speedIncrement = UI_Buffers.speedIncrement.v
            end
            if imgui.InputInt(u8'Target', UI_Buffers.targetSpeed) then
                if UI_Buffers.targetSpeed.v < 1 then UI_Buffers.targetSpeed.v = 1 end
                Features.Car.targetSpeed = UI_Buffers.targetSpeed.v
            end
            imgui.PopItemWidth()
            
            -- Speed Buttons
            if imgui.Button(u8'Apply Speed', imgui.ImVec2(-1, 20)) then
                if isCharInAnyCar(PLAYER_PED) and UI_Buffers.targetSpeed.v > 0 then
                    Features.Car.accelMode = true
                    Features.Car.targetSpeed = math.floor(UI_Buffers.targetSpeed.v / CONSTANTS.SPEED_CALIBRATION)
                    Features.Car.currentTargetSpeed = UI_Buffers.targetSpeed.v
                    sampAddChatMessage("{00FF00}[Pyrrha] Speed control enabled - Target: " .. Features.Car.currentTargetSpeed, -1)
                else
                    sampAddChatMessage("{FF0000}[Pyrrha] Invalid speed or not in car!", -1)
                end
            end

            imgui.NextColumn() -- Right Column: Toggles & Sliders
            imgui.TextColored(imgui.ImVec4(0.80, 0.00, 0.00, 1.0), u8"[ Physics & Handling ]")
            
            -- Handling Toggles
            if imgui.Checkbox(u8'Drift Mode', imgui.ImBool(Features.Car.driftMode)) then
                Features.Car.driftMode = not Features.Car.driftMode
            end
            if imgui.Checkbox(u8'Perfect Handling', UI_Buffers.perfectHandling) then
                Features.Car.perfectHandling = UI_Buffers.perfectHandling.v
            end
            if imgui.Checkbox(u8'Tank Mode', UI_Buffers.tankMode) then
                Features.Car.tankMode = UI_Buffers.tankMode.v
            end
            if imgui.Checkbox(u8'Ground Stick', UI_Buffers.groundStick) then Features.Car.groundStick = UI_Buffers.groundStick.v end
            if imgui.Checkbox(u8'Fast Exit', UI_Buffers.fastExit) then Features.Car.fastExit = UI_Buffers.fastExit.v end

            -- Handling Selectors
            local drift_types = {u8'Hold Shift', u8'Toggle Shift', u8'Always On'}
            imgui.PushItemWidth(-1)
            if imgui.Combo(u8'##DriftType', UI_Buffers.driftType, drift_types) then
                local types = {"hold", "toggle", "always"}
                Features.Car.driftType = types[UI_Buffers.driftType.v + 1]
                if Features.Car.driftType == "always" then Features.Car.driftMode = true 
                elseif Features.Car.driftType == "hold" then Features.Car.driftMode = false end
            end
            imgui.PopItemWidth()
            
            imgui.Spacing()
            imgui.TextColored(imgui.ImVec4(0.80, 0.00, 0.00, 1.0), u8"[ Cheats ]")
            
            -- Cheat Toggles
            if imgui.Checkbox(u8'GM InCar', imgui.ImBool(Features.Car.gmCar)) then Features.Car.gmCar = not Features.Car.gmCar end
            if imgui.Checkbox(u8'GM Wheels', UI_Buffers.gmWheels) then Features.Car.gmWheels = UI_Buffers.gmWheels.v end
            if imgui.Checkbox(u8'AntiBoom', UI_Buffers.antiBoom) then Features.Car.antiBoom = UI_Buffers.antiBoom.v end
            if imgui.Checkbox(u8'NoBike Fall', imgui.ImBool(Features.Misc.noBikeFall)) then Features.Misc.noBikeFall = not Features.Misc.noBikeFall end
            if imgui.Checkbox(u8'WaterDrive', imgui.ImBool(Features.Car.waterDrive)) then Features.Car.waterDrive = not Features.Car.waterDrive end
            if imgui.Checkbox(u8'FireCar', imgui.ImBool(Features.Car.fireCar)) then Features.Car.fireCar = not Features.Car.fireCar end

            -- Cheat Sliders
            imgui.Text(u8'Damage Mult:')
            imgui.PushItemWidth(-1)
            if imgui.SliderFloat(u8'##DmgMult', UI_Buffers.damageMult, 0.0, 1.0, "%.2f") then Features.Car.damageMult = UI_Buffers.damageMult.v end
            imgui.PopItemWidth()
            imgui.Columns(1)

        elseif Features.Global.activeTab == 4 then -- MISC
            CenterText(u8'MISCELLANEOUS')
            imgui.Separator()
            imgui.Columns(2, "MiscCols", false)
            
            -- Left Column Toggles
            if imgui.Checkbox(u8'AntiStun (F3)', imgui.ImBool(Features.Misc.antiStun)) then Features.Misc.antiStun = not Features.Misc.antiStun end
            if imgui.Checkbox(u8'Infinite Oxygen', UI_Buffers.oxygen) then Features.Misc.oxygen = UI_Buffers.oxygen.v end
            if imgui.Checkbox(u8'Mega Jump', UI_Buffers.megaJump) then Features.Misc.megaJump = UI_Buffers.megaJump.v end
            if imgui.Checkbox(u8'BMX Mega Jump', UI_Buffers.bmxMegaJump) then Features.Misc.bmxMegaJump = UI_Buffers.bmxMegaJump.v end
            if imgui.Checkbox(u8'GodMode (F9)', UI_Buffers.godMode) then Features.Misc.godMode = UI_Buffers.godMode.v end
            
            imgui.NextColumn()
            
            -- Right Column Toggles
            if imgui.Checkbox(u8'QuickStop', UI_Buffers.quickStop) then Features.Misc.quickStop = UI_Buffers.quickStop.v end
            if imgui.Checkbox(u8'FakeAFK (F6)', imgui.ImBool(Features.Misc.fakeAfk)) then
                Features.Misc.fakeAfk = not Features.Misc.fakeAfk
                nopHook('onSendPlayerSync', Features.Misc.fakeAfk)
                nopHook('onSendVehicleSync', Features.Misc.fakeAfk)
                nopHook('onSendPassengerSync', Features.Misc.fakeAfk)
            end
            if imgui.Checkbox(u8'FakeLag (F7)', imgui.ImBool(Features.Misc.fakeLag)) then Features.Misc.fakeLag = not Features.Misc.fakeLag end
            if imgui.Checkbox(u8'No Fall', UI_Buffers.noFall) then Features.Misc.noFall = UI_Buffers.noFall.v end
            
            imgui.Columns(1)
            imgui.Separator()
            
            -- Sliders & Inputs
            imgui.Text("Reconnect Delay (sec):")
            if imgui.SliderInt("##recon_delay", UI_Buffers.reconnectDelay, 1, 30) then Features.Global.reconnectDelay = UI_Buffers.reconnectDelay.v end
            
            imgui.Spacing()
            
            -- Buttons
            if imgui.Button(u8'Reconnect Now', imgui.ImVec2(-1, 25)) then performReconnect(Features.Global.reconnectDelay) end
            if imgui.Button(u8'Fix Wheels', imgui.ImVec2(-1, 25)) then
                if isCharInAnyCar(PLAYER_PED) then
                    local veh = storeCarCharIsInNoSave(PLAYER_PED)
                    for i = 0, 3 do fixCarTire(veh, i) end
                else sampAddChatMessage("{FF0000}Not in vehicle!", -1) end
            end
            if imgui.Button(u8'Save Default Settings', imgui.ImVec2(-1, 25)) then saveSettings() end

        elseif Features.Global.activeTab == 5 then -- KEYBINDS
            CenterText(u8'KEYBIND MANAGER')
            imgui.Separator()
            imgui.TextColored(imgui.ImVec4(0.8, 0.8, 0.8, 1), u8'Press ESC to cancel key binding')
            imgui.BeginChild("KeybindScroll", imgui.ImVec2(0, 300), true)
            for bind_name, key_code in pairs(keybinds) do
                local display_name = keybind_names[bind_name] or bind_name
                imgui.PushID(bind_name)
                imgui.AlignTextToFramePadding()
                imgui.TextColored(imgui.ImVec4(0.9, 0.9, 0.9, 1), u8(display_name))
                imgui.SameLine(250)
                local key_color = waiting_for_key == bind_name and imgui.ImVec4(1, 1, 0, 1) or imgui.ImVec4(0.5, 0.8, 1, 1)
                imgui.TextColored(key_color, getKeyName(key_code))
                imgui.SameLine(320)
                local button_text = waiting_for_key == bind_name and u8'...' or u8'Set'
                local button_color = waiting_for_key == bind_name and imgui.ImVec4(1, 1, 0, 1) or imgui.ImVec4(0.2, 0.6, 0.2, 1)
                imgui.PushStyleColor(imgui.Col.Button, button_color)
                if imgui.Button(button_text, imgui.ImVec2(50, 0)) then waiting_for_key = bind_name end
                imgui.PopStyleColor()
                imgui.SameLine()
                if imgui.Button(u8'X', imgui.ImVec2(30, 0)) then waiting_for_key = nil end
                imgui.PopID()
            end
            imgui.EndChild()
            imgui.Separator()
            if imgui.Button(u8'Save Config', imgui.ImVec2(100, 30)) then
                local file = io.open(CONSTANTS.CONFIG_FILE, "w")
                if file then
                    for k, v in pairs(keybinds) do file:write(k .. "=" .. v .. "\n") end
                    file:close()
                    sampAddChatMessage("{00FF00}[Pyrrha] Keybinds saved!", -1)
                end
            end
            if waiting_for_key then
                for vkey = 1, 255 do
                    if wasKeyPressed(vkey) and vkey ~= VK_ESCAPE then
                        keybinds[waiting_for_key] = vkey
                        waiting_for_key = nil
                        break
                    elseif wasKeyPressed(VK_ESCAPE) then
                        waiting_for_key = nil
                        break
                    end
                end
            end

        elseif Features.Global.activeTab == 7 then -- CONFIGURATION
            CenterText(u8'CONFIGURATION MANAGER')
            imgui.Separator()
            imgui.Spacing()
            
            imgui.Text(u8"Create New Config:")
            imgui.PushItemWidth(-1)
            imgui.InputText(u8'##configname', UI_Buffers.configName)
            imgui.PopItemWidth()
            
            if imgui.Button(u8'Create & Save', imgui.ImVec2(-1, 30)) then
                local name = UI_Buffers.configName.v
                if #name > 0 then
                    if not name:match("%.cfg$") then name = name .. ".cfg" end
                    saveSettings(name)
                else
                    sampAddChatMessage("{FF0000}[Pyrrha] Please enter a config name!", -1)
                end
            end
            
            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()
            
            imgui.Text(u8"Available Configs:")
            local items = Features.Config.list
            
            -- Scrollable List
            imgui.BeginChild("ConfigList", imgui.ImVec2(-1, 150), true)
            if #items > 0 then
                for i, name in ipairs(items) do
                    if imgui.Selectable(name, UI_Buffers.configSelect.v == i - 1) then
                        UI_Buffers.configSelect.v = i - 1
                    end
                end
            else
                imgui.TextDisabled(u8"No configurations found.")
            end
            imgui.EndChild()
            
            imgui.Spacing()
            
            if #items > 0 then
                if imgui.Button(u8'Load Selected', imgui.ImVec2(150, 30)) then
                    local selectedName = items[UI_Buffers.configSelect.v + 1]
                    if selectedName then loadSettings(selectedName) end
                end
                imgui.SameLine()
                if imgui.Button(u8'Delete Selected', imgui.ImVec2(150, 30)) then
                    local selectedName = items[UI_Buffers.configSelect.v + 1]
                    if selectedName then
                        local path = CONSTANTS.SETTINGS_DIR .. selectedName
                        os.remove(path)
                        refreshConfigList()
                        -- Reset selection if out of bounds
                        if UI_Buffers.configSelect.v >= #Features.Config.list then
                            UI_Buffers.configSelect.v = math.max(0, #Features.Config.list - 1)
                        end
                        sampAddChatMessage("{FFFF00}[Pyrrha] Deleted config: " .. selectedName, -1)
                    end
                end
                imgui.SameLine()
                if imgui.Button(u8'Overwrite Selected', imgui.ImVec2(150, 30)) then
                    local selectedName = items[UI_Buffers.configSelect.v + 1]
                    if selectedName then saveSettings(selectedName) end
                end
            end
            
            imgui.Spacing()
            imgui.Separator()
            imgui.TextWrapped(u8"Configs are saved in: " .. CONSTANTS.SETTINGS_DIR)

        elseif Features.Global.activeTab == 6 then -- ABOUT
            CenterText(u8'ABOUT PYRRHA')
            imgui.Separator()
            imgui.Text(u8'Pyrrha - Multi-purpose Utility Script')
            imgui.Text(u8'Version: 1.0 (Head Dot & Visuals)')
            imgui.Text(u8'Author: rmux')

            imgui.Spacing()
            imgui.Separator()
            
            if imgui.Checkbox(u8'Check Updates on Startup', imgui.ImBool(Features.Global.checkUpdate)) then
                Features.Global.checkUpdate = not Features.Global.checkUpdate
            end
            
            if imgui.Button(u8'Check for Updates', imgui.ImVec2(-1, 30)) then
                check_for_update(true)
            end
        end
        imgui.EndChild()
        imgui.End()
    end
end

-- ===============================================================================
-- [HOOKS]
-- ===============================================================================
function sampev.onSendPlayerSync() Features.Car.justGotInCar = true end

function sampev.onSendVehicleSync(data)
    if data == nil or data.vehicleHealth == nil then return end
    if Features.Car.fireCar then data.vehicleHealth = 4 end
    
    if Features.Car.justGotInCar then
        Features.Car.justGotInCar = false
        Features.Car.lastHP = data.vehicleHealth
        return
    end
    
    local newHP = data.vehicleHealth
    if newHP < Features.Car.lastHP then
        local damage = Features.Car.lastHP - newHP
        local reducedDamage = damage * Features.Car.damageMult
        local hp = Features.Car.lastHP - reducedDamage
        if isCharInAnyCar(PLAYER_PED) then
            local car = storeCarCharIsInNoSave(PLAYER_PED)
            if doesVehicleExist(car) then
                setCarHealth(car, hp)
                data.vehicleHealth = hp
            end
        end
    end
    Features.Car.lastHP = data.vehicleHealth or Features.Car.lastHP
end

function sampev.onSendGiveDamage(playerId, damage, weapon, bodypart)
    if Features.Weapon.hitsound then
        local audio = loadAudioStream('moonloader/resource/pyrrha/tick.mp3')
        if audio then setAudioStreamState(audio, 1) end
    end
end

-- ===============================================================================
-- [LOGIC PROCESSORS]
-- ===============================================================================
local function HandleKeybinds()
    -- Menu
    if wasKeyPressed(keybinds.menu_toggle) then
        UI_Buffers.mainWindow.v = not UI_Buffers.mainWindow.v
        imgui.Process = UI_Buffers.mainWindow.v
    end
    -- Reconnect
    if isKeyDown(VK_LSHIFT) and wasKeyPressed(keybinds.reconnect_key) then
        performReconnect(Features.Global.reconnectDelay)
    end
    -- Speed Control
    if wasKeyPressed(keybinds.speed_toggle) then
        Features.Car.accelMode = not Features.Car.accelMode
        sampAddChatMessage(Features.Car.accelMode and "{00FF00}[Pyrrha] Speed ON" or "{FF0000}[Pyrrha] Speed OFF", -1)
        syncUIBuffers()
    end
    if wasKeyPressed(keybinds.speed_increase) then
        Features.Car.currentTargetSpeed = math.min(Features.Car.currentTargetSpeed + Features.Car.speedIncrement, 600)
        Features.Car.targetSpeed = math.floor(Features.Car.currentTargetSpeed / CONSTANTS.SPEED_CALIBRATION)
        UI_Buffers.targetSpeed.v = Features.Car.currentTargetSpeed
        sampAddChatMessage("{00FF00}[Pyrrha] Target speed: " .. Features.Car.currentTargetSpeed, -1)
    end
    if wasKeyPressed(keybinds.speed_decrease) then
        Features.Car.currentTargetSpeed = math.max(Features.Car.currentTargetSpeed - Features.Car.speedIncrement, 1)
        Features.Car.targetSpeed = math.floor(Features.Car.currentTargetSpeed / CONSTANTS.SPEED_CALIBRATION)
        UI_Buffers.targetSpeed.v = Features.Car.currentTargetSpeed
        sampAddChatMessage("{00FF00}[Pyrrha] Target speed: " .. Features.Car.currentTargetSpeed, -1)
    end
    -- Toggles
    local function toggleFeature(key, featureTable, keyName, msgName, hookName)
        if wasKeyPressed(key) then
            featureTable[keyName] = not featureTable[keyName]
            local state = featureTable[keyName]
            sampAddChatMessage((state and "{00FF00}" or "{FF0000}") .. "[Pyrrha] " .. msgName .. (state and " ON" or " OFF"), -1)
            if hookName then
                nopHook('onSendPlayerSync', state)
                nopHook('onSendVehicleSync', state)
                nopHook('onSendPassengerSync', state)
            end
            if keyName == 'instantCrosshair' then showCrosshairInstantlyPatch(state) end
            syncUIBuffers()
        end
    end

    toggleFeature(keybinds.esp_toggle, Features.Visual, 'espEnabled', 'ESP')
    toggleFeature(keybinds.lines_toggle, Features.Visual, 'linesEnabled', 'ESP Lines')
    toggleFeature(keybinds.antistun_toggle, Features.Misc, 'antiStun', 'AntiStun')
    toggleFeature(keybinds.fakeafk_toggle, Features.Misc, 'fakeAfk', 'FakeAFK', true)
    toggleFeature(keybinds.fakelag_toggle, Features.Misc, 'fakeLag', 'FakeLag')
    toggleFeature(keybinds.nospread_toggle, Features.Weapon, 'spread', 'NoSpread')
    toggleFeature(keybinds.godmode_toggle, Features.Misc, 'godMode', 'GodMode')
    toggleFeature(keybinds.waterdrive_toggle, Features.Car, 'waterDrive', 'WaterDrive')
    toggleFeature(keybinds.firecar_toggle, Features.Car, 'fireCar', 'FireCar')
    toggleFeature(keybinds.instant_crosshair_toggle, Features.Weapon, 'instantCrosshair', 'Instant Crosshair')
    toggleFeature(keybinds.noreload_toggle, Features.Weapon, 'norl', 'NoReload')
end

local function RunVehicleLogic()
    if not Features.Global.scriptEnabled or not isCharInAnyCar(PLAYER_PED) then return end

    local car = storeCarCharIsInNoSave(PLAYER_PED)
    local speed = getCarSpeed(car)
    
    -- 1. Speed Boost
    if isKeyDown(keybinds.speed_boost) and Features.Car.accelMode then
        setCarForwardSpeed(car, speed * 1.5)
    end

    -- 2. Auto Speed
    if Features.Car.accelMode then
        local speedDiff = Features.Car.targetSpeed - speed
        if math.abs(speedDiff) > 2 then
            setCarForwardSpeed(car, speed + (speedDiff * (speedDiff > 0 and 0.1 or 0.05)))
        end
        
        -- Ground Stick
        if Features.Car.groundStick and speed > CONSTANTS.HIGH_SPEED_THRESHOLD then
            local rx, ry, rz = getVehicleRotationVelocity(car)
            setVehicleRotationVelocity(car, rx * 0.8, ry * 0.8, rz)
            if not isVehicleOnAllWheels(car) and isCarInAirProper(car) then
                local vx, vy, vz = getCarSpeedVector(car)
                setCarSpeedVector(car, vx, vy, vz - CONSTANTS.GROUND_STICK_FORCE)
            end
        end
    end

    -- 3. Drift Logic
    local lshift = isKeyDown(keybinds.drift_toggle)
    if Features.Car.driftType == "hold" then Features.Car.driftMode = lshift
    elseif Features.Car.driftType == "toggle" and lshift and not Features.Car.shiftPressed then
        Features.Car.driftMode = not Features.Car.driftMode
        sampAddChatMessage(Features.Car.driftMode and "{FFFF00}[Pyrrha] Drift Enabled" or "{FFFF00}[Pyrrha] Drift Disabled", -1)
    end
    Features.Car.shiftPressed = lshift

    if Features.Car.driftMode and isVehicleOnAllWheels(car) and doesVehicleExist(car) and speed > CONSTANTS.MIN_DRIFT_SPEED then
        setCarCollision(car, false)
        if isCarInAirProper(car) then setCarCollision(car, true) end
        if isKeyDown(VK_A) then addToCarRotationVelocity(car, 0, 0, 0.03) end
        if isKeyDown(VK_D) then addToCarRotationVelocity(car, 0, 0, -0.03) end
    else
        setCarCollision(car, true)
    end

    -- 4. Car Cheats
    if Features.Car.gmCar then setCarProofs(car, true, true, true, true, true) end
    if Features.Car.gmWheels then setCanBurstCarTires(car, false) end
    if Features.Car.antiBoom and isCarUpsidedown(car) then setCarHealth(car, 1000) end
    if Features.Car.waterDrive then memory.write(9867602, 1, 4) else memory.write(9867602, 0, 4) end
    if Features.Car.fixWheels then for i = 0, 3 do fixCarTire(car, i) end end

    if Features.Car.fastExit and wasKeyPressed(VK_F) then
        clearCharTasksImmediately(PLAYER_PED)
        local x, y, z = getCharCoordinates(PLAYER_PED)
        setCharCoordinates(PLAYER_PED, x, y, z + 2)
    end
end

local function RunCharacterLogic()
    -- 1. Weapon/Combat
    if Features.Misc.antiStun and not isCharDead(PLAYER_PED) then
        local anims = {'DAM_armL_frmBK', 'DAM_armL_frmFT', 'DAM_armL_frmLT', 'DAM_armR_frmBK', 'DAM_armR_frmFT', 'DAM_armR_frmRT', 'DAM_LegL_frmBK', 'DAM_LegL_frmFT', 'DAM_LegL_frmLT', 'DAM_LegR_frmBK', 'DAM_LegR_frmFT', 'DAM_LegR_frmRT', 'DAM_stomach_frmBK', 'DAM_stomach_frmFT', 'DAM_stomach_frmLT', 'DAM_stomach_frmRT'}
        for _, v in pairs(anims) do
            if isCharPlayingAnim(PLAYER_PED, v) then setCharAnimSpeed(PLAYER_PED, v, 999) end
        end
    end

    if Features.Weapon.spread then memory.setfloat(0x8D2E64, 0.0) else memory.setfloat(0x8D2E64, 1.0) end

    if Features.Weapon.norl then
        local weapon = getCurrentCharWeapon(PLAYER_PED)
        local nbs = raknetNewBitStream()
        raknetBitStreamWriteInt32(nbs, weapon)
        raknetBitStreamWriteInt32(nbs, 0)
        raknetEmulRpcReceiveBitStream(22, nbs)
        raknetDeleteBitStream(nbs)
    end
    
    if Features.Weapon.instantCrosshair then showCrosshairInstantlyPatch(true) end

    -- 2. Movement/Misc
    if Features.Misc.quickStop and (isCharPlayingAnim(PLAYER_PED, 'RUN_STOP') or isCharPlayingAnim(PLAYER_PED, 'RUN_STOPR')) then
        clearCharTasksImmediately(PLAYER_PED)
    end

    setCharCanBeKnockedOffBike(PLAYER_PED, Features.Misc.noBikeFall)
    
    if Features.Misc.fakeLag then for i = 1,3 do sampSetSendrate(i, 1000) end
    else for i = 1,3 do sampSetSendrate(i, 0) end end

    if Features.Misc.noFall and not isCharDead(PLAYER_PED) then
        if isCharPlayingAnim(PLAYER_PED, 'KO_SKID_BACK') or isCharPlayingAnim(PLAYER_PED, 'FALL_COLLAPSE') then
            clearCharTasksImmediately(PLAYER_PED)
        end
    end

    memory.setint8(0x96916E, Features.Misc.oxygen and 1 or 0, false)
    memory.setint8(0x96916C, Features.Misc.megaJump and 1 or 0, false)
    memory.setint8(0x969161, Features.Misc.bmxMegaJump and 1 or 0, false)
    memory.setint8(0x96914C, Features.Car.perfectHandling and 1 or 0, false)
    memory.setint8(0x969164, Features.Car.tankMode and 1 or 0, false)
    
    if Features.Misc.godMode then setCharProofs(PLAYER_PED, true, true, true, true, true)
    else setCharProofs(PLAYER_PED, false, false, false, false, false) end
end

-- ===============================================================================
-- [MAIN LOOP]
-- ===============================================================================
function main()
    -- Load Config
    local file = io.open(CONSTANTS.CONFIG_FILE, "r")
    if file then
        for line in file:lines() do
            local key, value = line:match("([^=]+)=([^=]+)")
            if key and value then keybinds[key] = tonumber(value) end
        end
        file:close()
        writeLog("Keybinds loaded from config")
    end
    
    ensureConfigDir()
    loadSettings()

    while not isSampLoaded() or not isSampAvailable() do wait(100) end
    
    apply_flux_style()
    sampAddChatMessage("{00FF00}[Pyrrha 1.1] Script loaded! Press 'U' for menu.", -1)
    writeLog("Script loaded successfully!")
    
    check_for_update()

    imgui.Process = false
    
    while true do
        wait(0)
        local success, error = pcall(function()
            drawVisuals()
            HandleKeybinds()
            RunVehicleLogic()
            RunCharacterLogic()
        end)
        
        if not success then
            local errorMsg = "[Pyrrha] Error: " .. tostring(error)
            sampAddChatMessage("{FF0000}" .. errorMsg, -1)
            writeLog(errorMsg)
        end
    end
end
