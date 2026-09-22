--[[----------------------------------------------------------------------------
    Mak'gora (Duel to the Death)  --  Classic Era 1.14.2 (build 42597) client build

    Adds a "Challenge to Mak'gora" entry directly below "Duel" in the
    right-click menu of players (target frame, party frames, raid frames).
    Choosing it sends the server command

        .makgora challenge <name>

    on the SAY channel. The server intercepts the dot-command (it is never
    broadcast as chat) and immediately sends the target a regular duel
    request, flagged as Mak'gora: the loser of the duel really dies.

    This file is written for the 1.14.x UI (Lua 5.1 + secure/taint system):
      * handlers receive the frame as the first argument (`self`), no `this`
      * UIDROPDOWNMENU_INIT_MENU holds the dropdown frame OBJECT (not a name)
      * Blizzard functions are never replaced - only post-hooked with
        hooksecurefunc() so protected actions (Follow, Target, ...) stay secure
      * SendChatMessage() to SAY needs a hardware event: the send happens
        synchronously inside the menu click / slash command, never from a timer

    Do NOT use this file on the 1.12.1 client; use the 1.12.1 build instead.
------------------------------------------------------------------------------]]

MAKGORA_VERSION = "2.0"
MAKGORA_MENU_KEY = "MAKGORA"
MAKGORA_MENU_TEXT = "Challenge to Mak'gora"

local MAKGORA_CMD_CHALLENGE = ".makgora challenge "
local MAKGORA_CMD_ACCEPT    = ".makgora accept"
local MAKGORA_CMD_DECLINE   = ".makgora decline"
local MAKGORA_CMD_STATUS    = ".makgora status"

-- Menus that get the new entry (inserted right after "DUEL").
local MAKGORA_MENUS = { "PLAYER", "PARTY", "RAID_PLAYER" }

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------
local function Makgora_Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Mak'gora]|r " .. tostring(msg))
    end
end

local function Makgora_Trim(s)
    if not s then
        return ""
    end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function Makgora_SendCommand(cmd)
    -- Server-side dot-commands are parsed from any chat type; SAY is the
    -- most robust choice (no whisper target validation involved).
    SendChatMessage(cmd, "SAY")
end

-- Returns true when `unit` is a player we could challenge.
local function Makgora_IsValidUnit(unit)
    if not unit or not UnitExists(unit) then
        return false
    end
    if not UnitIsPlayer(unit) then
        return false
    end
    if UnitIsUnit(unit, "player") then
        return false
    end
    if not UnitCanCooperate("player", unit) then
        return false
    end
    return true
end

-- Issue a challenge to `unit` (preferred) or to the character called `name`.
function Makgora_Challenge(unit, name)
    if unit and UnitExists(unit) then
        if not UnitIsPlayer(unit) then
            Makgora_Print("Only players can be challenged to a Mak'gora.")
            return
        end
        if UnitIsUnit(unit, "player") then
            Makgora_Print("You cannot challenge yourself.")
            return
        end
        if UnitIsDeadOrGhost(unit) then
            Makgora_Print((UnitName(unit) or "Target") .. " is dead.")
            return
        end
        name = UnitName(unit)
    end

    name = Makgora_Trim(name)
    -- strip a "-Realm" suffix should one ever be passed in
    name = name:match("^([^%-]+)") or name
    if name == "" or name == UNKNOWNOBJECT then
        Makgora_Print("No valid target. Usage: /makgora <name>  (or select a player)")
        return
    end

    if UnitIsDeadOrGhost("player") then
        Makgora_Print("You cannot issue a challenge while dead.")
        return
    end

    Makgora_SendCommand(MAKGORA_CMD_CHALLENGE .. name)
end

------------------------------------------------------------------------------
-- Unit popup menu integration
------------------------------------------------------------------------------
-- dist = 3 is the same interact distance the "Duel" button uses
-- (UnitPopup_IsEnabled greys the entry out when the unit is too far away).
UnitPopupButtons[MAKGORA_MENU_KEY] = { text = MAKGORA_MENU_TEXT, dist = 3, disabledInKioskMode = false }

local function Makgora_InsertMenuEntry(menuName)
    local menu = UnitPopupMenus[menuName]
    if not menu then
        return
    end
    if tContains(menu, MAKGORA_MENU_KEY) then
        return
    end
    for i = 1, #menu do
        if menu[i] == "DUEL" then
            table.insert(menu, i + 1, MAKGORA_MENU_KEY)
            return
        end
    end
    -- no "Duel" entry in this menu: put it just above "Cancel"
    local n = #menu
    if n > 0 and menu[n] == "CANCEL" then
        table.insert(menu, n, MAKGORA_MENU_KEY)
    else
        table.insert(menu, MAKGORA_MENU_KEY)
    end
end

for _, menuName in ipairs(MAKGORA_MENUS) do
    Makgora_InsertMenuEntry(menuName)
end

-- Visibility: mirror the "Duel" rules (hide for non-cooperative units, NPCs
-- and ourselves). UnitPopup_HideButtons() only knows Blizzard's own keys and
-- leaves unknown entries shown, so post-process its result for our entry.
hooksecurefunc("UnitPopup_HideButtons", function()
    local dropdownMenu = UIDROPDOWNMENU_INIT_MENU
    if type(dropdownMenu) ~= "table" or not dropdownMenu.which then
        return
    end
    local level = UIDROPDOWNMENU_MENU_LEVEL or 1
    local menu = UnitPopupMenus[UIDROPDOWNMENU_MENU_VALUE] or UnitPopupMenus[dropdownMenu.which]
    if not menu or not UnitPopupShown[level] then
        return
    end
    for index = 1, #menu do
        if menu[index] == MAKGORA_MENU_KEY then
            if not Makgora_IsValidUnit(dropdownMenu.unit) then
                UnitPopupShown[level][index] = 0
            end
            return
        end
    end
end)

-- Click handling. The original UnitPopup_OnClick(self) simply falls through
-- for a value it does not know, so a secure post-hook is all that is needed.
hooksecurefunc("UnitPopup_OnClick", function(self)
    if not self or self.value ~= MAKGORA_MENU_KEY then
        return
    end
    local dropdownFrame = UIDROPDOWNMENU_INIT_MENU
    local unit, name
    if type(dropdownFrame) == "table" then
        unit = dropdownFrame.unit
        name = dropdownFrame.name
    end
    Makgora_Challenge(unit, name)
end)

------------------------------------------------------------------------------
-- /makgora slash command (fallback when a custom unit frame has no menu)
------------------------------------------------------------------------------
SLASH_MAKGORA1 = "/makgora"
SLASH_MAKGORA2 = "/mak"
SlashCmdList["MAKGORA"] = function(msg)
    msg = Makgora_Trim(msg)
    local lower = msg:lower()

    if lower == "accept" then
        Makgora_SendCommand(MAKGORA_CMD_ACCEPT)
    elseif lower == "decline" then
        Makgora_SendCommand(MAKGORA_CMD_DECLINE)
    elseif lower == "status" then
        Makgora_SendCommand(MAKGORA_CMD_STATUS)
    elseif lower == "help" or lower == "?" then
        Makgora_Print("Mak'gora v" .. MAKGORA_VERSION .. " - Duel to the Death")
        Makgora_Print("/makgora            - challenge your current target")
        Makgora_Print("/makgora <name>     - challenge a player by name")
        Makgora_Print("/makgora accept     - accept a pending challenge")
        Makgora_Print("/makgora decline    - decline a pending challenge")
        Makgora_Print("/makgora status     - show your Mak'gora record")
        Makgora_Print("Right-click a player: Duel / Challenge to Mak'gora")
    elseif lower == "" then
        if UnitExists("target") then
            Makgora_Challenge("target", nil)
        else
            Makgora_Print("Select a player or use: /makgora <name>   (/makgora help)")
        end
    else
        Makgora_Challenge(nil, msg)
    end
end

------------------------------------------------------------------------------
-- Load message
------------------------------------------------------------------------------
local Makgora_Frame = CreateFrame("Frame", "MakgoraFrame")
Makgora_Frame:RegisterEvent("PLAYER_LOGIN")
Makgora_Frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        Makgora_Print("v" .. MAKGORA_VERSION .. " loaded (1.14.2). Right-click a player -> Challenge to Mak'gora, or /makgora help")
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)
