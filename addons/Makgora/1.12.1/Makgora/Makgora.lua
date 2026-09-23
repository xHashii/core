--[[----------------------------------------------------------------------------
    Mak'gora (Duel to the Death)  --  Vanilla 1.12.1 client build

    Adds a "Challenge to Mak'gora" entry directly below "Duel" in the
    right-click menu of players (target frame and party frames).
    Choosing it sends the server command

        .makgora challenge <name>

    on the SAY channel. The server intercepts the dot-command (it is never
    broadcast as chat) and immediately sends the target a regular duel
    request, flagged as Mak'gora: the loser of the duel really dies.

    This file is written for the 1.12.1 UI (Lua 5.0):
      * event/click handlers receive the frame in the global `this`
      * UIDROPDOWNMENU_INIT_MENU holds the *name* of the dropdown frame
      * getglobal() instead of _G, table.getn() instead of #
      * no hooksecurefunc / taint system -> plain function wrapping is fine

    Do NOT use this file on the 1.14.x client; use the 1.14.2 build instead.
------------------------------------------------------------------------------]]

MAKGORA_VERSION = "2.0"
MAKGORA_MENU_KEY = "MAKGORA"
MAKGORA_MENU_TEXT = "Challenge to Mak'gora"

local MAKGORA_CMD_CHALLENGE = ".makgora challenge "
local MAKGORA_CMD_ACCEPT    = ".makgora accept"
local MAKGORA_CMD_DECLINE   = ".makgora decline"
local MAKGORA_CMD_STATUS    = ".makgora status"

-- Menus that get the new entry (inserted right after "DUEL").
local MAKGORA_MENUS = { "PLAYER", "PARTY" }

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------
local function Makgora_Print(msg)
    if ( DEFAULT_CHAT_FRAME ) then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Mak'gora]|r " .. tostring(msg))
    end
end

local function Makgora_Trim(s)
    if ( not s ) then
        return ""
    end
    local _, _, trimmed = string.find(s, "^%s*(.-)%s*$")
    return trimmed or ""
end

local function Makgora_SendCommand(cmd)
    -- Server-side dot-commands are parsed from any chat type; SAY is the
    -- most robust choice (no whisper target validation involved).
    SendChatMessage(cmd, "SAY")
end

-- Returns true when `unit` is a player we could challenge.
local function Makgora_IsValidUnit(unit)
    if ( not unit or not UnitExists(unit) ) then
        return nil
    end
    if ( not UnitIsPlayer(unit) ) then
        return nil
    end
    if ( UnitIsUnit(unit, "player") ) then
        return nil
    end
    if ( not UnitCanCooperate("player", unit) ) then
        return nil
    end
    return 1
end

-- Issue a challenge to `unit` (preferred) or to the character called `name`.
function Makgora_Challenge(unit, name)
    if ( unit and UnitExists(unit) ) then
        if ( not UnitIsPlayer(unit) ) then
            Makgora_Print("Only players can be challenged to a Mak'gora.")
            return
        end
        if ( UnitIsUnit(unit, "player") ) then
            Makgora_Print("You cannot challenge yourself.")
            return
        end
        if ( UnitIsDeadOrGhost(unit) ) then
            Makgora_Print(UnitName(unit) .. " is dead.")
            return
        end
        name = UnitName(unit)
    end

    name = Makgora_Trim(name)
    if ( name == "" or name == UNKNOWNOBJECT ) then
        Makgora_Print("No valid target. Usage: /makgora <name>  (or select a player)")
        return
    end

    if ( UnitIsDeadOrGhost("player") ) then
        Makgora_Print("You cannot issue a challenge while dead.")
        return
    end

    Makgora_SendCommand(MAKGORA_CMD_CHALLENGE .. name)
end

------------------------------------------------------------------------------
-- Unit popup menu integration
------------------------------------------------------------------------------
-- Every UnitPopupButtons entry MUST carry a numeric `dist`:
-- UnitPopup_OnUpdate does `UnitPopupButtons[value].dist > 0` unguarded.
-- dist = 3 is the same interact distance the "Duel" button uses.
UnitPopupButtons[MAKGORA_MENU_KEY] = { text = MAKGORA_MENU_TEXT, dist = 3 }

local function Makgora_InsertMenuEntry(menuName)
    local menu = UnitPopupMenus[menuName]
    if ( not menu ) then
        return
    end
    -- already present (e.g. after a /reload of a modified UI)
    for i = 1, table.getn(menu) do
        if ( menu[i] == MAKGORA_MENU_KEY ) then
            return
        end
    end
    for i = 1, table.getn(menu) do
        if ( menu[i] == "DUEL" ) then
            table.insert(menu, i + 1, MAKGORA_MENU_KEY)
            return
        end
    end
    -- no "Duel" entry in this menu: put it just above "Cancel"
    local n = table.getn(menu)
    if ( n > 0 and menu[n] == "CANCEL" ) then
        table.insert(menu, n, MAKGORA_MENU_KEY)
    else
        table.insert(menu, MAKGORA_MENU_KEY)
    end
end

for _, menuName in ipairs(MAKGORA_MENUS) do
    Makgora_InsertMenuEntry(menuName)
end

-- Visibility: mirror the "Duel" rules (hide for non-cooperative units, NPCs
-- and ourselves). UnitPopup_HideButtons() resets UnitPopupShown[index] = 1
-- for every entry and only knows Blizzard's own keys, so we post-process.
local Makgora_Orig_UnitPopup_HideButtons = UnitPopup_HideButtons
function UnitPopup_HideButtons()
    Makgora_Orig_UnitPopup_HideButtons()

    local dropdownMenu = getglobal(UIDROPDOWNMENU_INIT_MENU)
    if ( not dropdownMenu or not dropdownMenu.which ) then
        return
    end
    local menu = UnitPopupMenus[dropdownMenu.which]
    if ( not menu ) then
        return
    end
    for index = 1, table.getn(menu) do
        if ( menu[index] == MAKGORA_MENU_KEY ) then
            if ( not Makgora_IsValidUnit(dropdownMenu.unit) ) then
                UnitPopupShown[index] = 0
            end
            return
        end
    end
end

-- Click handling. In 1.12.1 the menu button's OnClick calls the stored
-- function with the button frame in `this`; the chosen entry is `this.value`
-- and the owning dropdown is looked up by NAME through UIDROPDOWNMENU_INIT_MENU.
local Makgora_Orig_UnitPopup_OnClick = UnitPopup_OnClick
function UnitPopup_OnClick()
    if ( this and this.value == MAKGORA_MENU_KEY ) then
        local dropdownFrame = getglobal(UIDROPDOWNMENU_INIT_MENU)
        local unit, name
        if ( dropdownFrame ) then
            unit = dropdownFrame.unit
            name = dropdownFrame.name
        end
        Makgora_Challenge(unit, name)
        PlaySound("UChatScrollButton")
        return
    end
    Makgora_Orig_UnitPopup_OnClick()
end

------------------------------------------------------------------------------
-- /makgora slash command (fallback when a custom unit frame has no menu)
------------------------------------------------------------------------------
SLASH_MAKGORA1 = "/makgora"
SLASH_MAKGORA2 = "/mak"
SlashCmdList["MAKGORA"] = function(msg)
    msg = Makgora_Trim(msg)
    local lower = string.lower(msg)

    if ( lower == "accept" ) then
        Makgora_SendCommand(MAKGORA_CMD_ACCEPT)
    elseif ( lower == "decline" ) then
        Makgora_SendCommand(MAKGORA_CMD_DECLINE)
    elseif ( lower == "status" ) then
        Makgora_SendCommand(MAKGORA_CMD_STATUS)
    elseif ( lower == "help" or lower == "?" ) then
        Makgora_Print("Mak'gora v" .. MAKGORA_VERSION .. " - Duel to the Death")
        Makgora_Print("/makgora            - challenge your current target")
        Makgora_Print("/makgora <name>     - challenge a player by name")
        Makgora_Print("/makgora accept     - accept a pending challenge")
        Makgora_Print("/makgora decline    - decline a pending challenge")
        Makgora_Print("/makgora status     - show your Mak'gora record")
        Makgora_Print("Right-click a player: Duel / Challenge to Mak'gora")
    elseif ( lower == "" ) then
        if ( UnitExists("target") ) then
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
Makgora_Frame:SetScript("OnEvent", function()
    if ( event == "PLAYER_LOGIN" ) then
        Makgora_Print("v" .. MAKGORA_VERSION .. " loaded (1.12.1). Right-click a player -> Challenge to Mak'gora, or /makgora help")
        this:UnregisterEvent("PLAYER_LOGIN")
    end
end)
