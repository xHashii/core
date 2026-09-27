--[[----------------------------------------------------------------------------
    Hardcore Badge  --  Classic Era 1.14.2 (build 42597) client build

    The server flags a Hardcore character with a permanent, effect-less aura:
    spell id 5 (SPELL_PLAYER_HARDCORE_INDICATOR, src/game/Objects/Player.h).
    That id is not arbitrary: a client builds its buff frame from its own
    Spell.dbc and silently drops auras whose spell id has no record there, so
    the badge has to reuse an id the client already knows - and the one used by
    this core is Blizzard's unused GM test spell "Death Touch" (which the 1.14
    client even draws with a placeholder icon).

    For the same reason no server side change can ever rename that buff: an
    aura packet only carries the spell id, the flags, the level and the
    duration. Name, rank, icon and description always come from the client's
    Spell.dbc. So the label is fixed here, on the client:

      * the badge icon is replaced (default: INV_Misc_Bone_HumanSkull_01, a
        texture that exists in the vanilla and in the Classic Era client);
      * the tooltip reads "Hardcore" plus what the flag actually means;
      * Blizzard's stack/duration text is suppressed on that button.

    Everything that matters gameplay wise (the aura itself, its permanence, the
    .hardcore command) is server side and works without this addon - only the
    label is cosmetic.

    This file is written for the 1.14.x UI (Lua 5.1 + secure/taint system):
      * handlers receive the frame as the first argument (`self`), no `this`
      * Blizzard functions are never replaced - only post-hooked with
        hooksecurefunc(), so the buff frame stays secure
      * SendChatMessage() to SAY needs a hardware event: the .hardcore query is
        only sent from inside the slash command, never from a timer

    Do NOT use this file on the 1.12.1 client; use the 1.12.1 build instead.
------------------------------------------------------------------------------]]

HARDCORE_BADGE_VERSION = "1.0"

-- Spell id the server uses for the indicator. Must match
-- SPELL_PLAYER_HARDCORE_INDICATOR in src/game/Objects/Player.h.
local INDICATOR_SPELL_ID = 5

-- What this client's own Spell.dbc calls spell 5 ("Death Touch" and its
-- translations). Used as a fallback key; the spell id itself is the primary
-- one because UnitAura() reports it on this client. Resolved lazily: the
-- client's DBC data is not guaranteed to be ready while the addon loads.
local CLIENT_SPELL_NAME
local function ClientSpellName()
    if ( CLIENT_SPELL_NAME == nil ) then
        CLIENT_SPELL_NAME = GetSpellInfo(INDICATOR_SPELL_ID) or false
    end
    return CLIENT_SPELL_NAME or nil
end

-- Extra keys for exotic clients (/hardcore match <name or texture>).
local INDICATOR_TEXTURES = { "inv_misc_bone_humanskull_01" }

-- Icon presets. "skull" is the icon the 1.12.1 client draws for spell 5 and it
-- still ships with the Classic Era client, so it cannot be a missing texture.
-- "auto" keeps whatever the client draws for the aura.
local ICON_PRESETS = {
    skull   = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01",
    scream  = "Interface\\Icons\\Spell_Shadow_DeathScream",
    soulgem = "Interface\\Icons\\Spell_Shadow_SoulGem",
}

local BADGE_TITLE_COLOR = { 1.0, 0.25, 0.25 }
local BADGE_LINES = {
    "You have chosen the Hardcore path.",
    "One life only: if you die, you stay dead.",
    "This badge is permanent and cannot be removed.",
}
local BADGE_FOOTER = "/hardcore - status, /hardcore help - options"

-- NOTE: `enabled` is a real boolean. nil would be re-filled with the default
-- by DB() and 0 is truthy in Lua, so neither can express "off" here.
local DEFAULTS = {
    enabled = true,
    name    = "Hardcore",
    icon    = "skull",
}

local BUFF_BUTTON_MAX = 32

------------------------------------------------------------------------------
-- State
------------------------------------------------------------------------------
HardcoreBadge = {
    found     = false,  -- badge seen at least once this session
    announced = false,
    frame     = nil,
}

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------
local function Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff2020[Hardcore]|r " .. tostring(msg))
    end
end

local function DB()
    if type(HardcoreBadgeDB) ~= "table" then
        HardcoreBadgeDB = {}
    end
    for key, value in pairs(DEFAULTS) do
        if HardcoreBadgeDB[key] == nil then
            HardcoreBadgeDB[key] = value
        end
    end
    if type(HardcoreBadgeDB.extra) ~= "table" then
        HardcoreBadgeDB.extra = {}
    end
    return HardcoreBadgeDB
end

local function Trim(s)
    if not s then
        return ""
    end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- "Interface\Icons\INV_Misc_Bone_HumanSkull_01" -> "inv_misc_bone_humanskull_01"
local function TextureKey(texture)
    if not texture or type(texture) ~= "string" then
        return nil
    end
    local key = texture:lower():gsub("/", "\\")
    return (key:match("([^\\]+)$") or key)
end

local matchCache = nil
local matchCacheCount = nil

local function ExtraSets()
    local db = DB()
    if ( matchCache and matchCacheCount == #db.extra ) then
        return matchCache.textures, matchCache.names
    end

    local textures, names = {}, {}
    for _, value in ipairs(INDICATOR_TEXTURES) do
        textures[value:lower()] = true
    end
    for _, value in ipairs(db.extra) do
        if type(value) == "string" and value ~= "" then
            if value:find("\\") or value:find("/") then
                textures[TextureKey(value)] = true
            else
                names[value] = true
            end
        end
    end

    matchCache = { textures = textures, names = names }
    matchCacheCount = #db.extra
    return textures, names
end

local function InvalidateMatchCache()
    matchCache = nil
    matchCacheCount = nil
end

-- True when the aura at `index` (in `filter` order) is the server's badge.
local function AuraIsIndicator(index, filter)
    local name, texture, count, debuffType, duration, expirationTime,
          unitCaster, canStealOrPurge, nameplateShowPersonal, spellId =
          UnitAura("player", index, filter or "HELPFUL")

    if not name then
        return false
    end

    -- Primary: the spell id, which this client reports for every aura.
    if type(spellId) == "number" and spellId == INDICATOR_SPELL_ID then
        return true
    end

    -- Fallback: the name this client's own Spell.dbc gives to spell 5.
    local clientName = ClientSpellName()
    if clientName and name == clientName then
        return true
    end

    local textures, names = ExtraSets()
    if names[name] then
        return true
    end

    -- Last resort, for a client that renamed and re-iconed spell 5: match the
    -- texture, but only for a permanent aura (duration 0 = no expiration),
    -- since placeholder icons are shared by many unknown spells.
    local key = TextureKey(texture)
    if key and textures[key] and (not duration or duration == 0) then
        return true
    end

    return false
end

-- Index of the badge inside the buff frame's own list, or nil.
local function FindButtonIndex(filter)
    for index = 1, BUFF_BUTTON_MAX do
        local name = UnitAura("player", index, filter)
        if not name then
            return nil
        end
        if AuraIsIndicator(index, filter) then
            return index
        end
    end
    return nil
end

local function IsEnabled()
    return DB().enabled and true or false
end

local function BadgeIcon()
    local db = DB()
    if not db.icon or db.icon == "auto" then
        return nil
    end
    return ICON_PRESETS[db.icon] or db.icon
end

local function DressButton(button, index)
    if not button then
        return
    end
    local iconPath = BadgeIcon()
    if iconPath then
        local icon = _G[button:GetName() .. "Icon"]
        if icon then
            icon:SetTexture(iconPath)
        end
    end
    local count = button.count or _G[button:GetName() .. "Count"]
    if count then
        count:Hide()
    end
    local duration = button.duration or _G[button:GetName() .. "Duration"]
    if duration then
        duration:Hide()
    end
    if not HardcoreBadge.announced then
        HardcoreBadge.announced = true
        Print("badge active - shown as \"" .. tostring(DB().name) .. "\" instead of the client's own spell "
              .. INDICATOR_SPELL_ID .. " name (/hardcore help)")
    end
end

local function RewriteTooltip(tooltip)
    local db = DB()
    tooltip:ClearLines()
    tooltip:SetText(db.name, BADGE_TITLE_COLOR[1], BADGE_TITLE_COLOR[2], BADGE_TITLE_COLOR[3], 1.0)
    for _, line in ipairs(BADGE_LINES) do
        tooltip:AddLine(line, 1.0, 1.0, 1.0, true)
    end
    tooltip:AddLine(" ", 1.0, 1.0, 1.0, true)
    tooltip:AddLine(BADGE_FOOTER, 0.6, 0.6, 0.6, true)
    tooltip:Show()
end

-- Repaint every visible buff button (used after an option change).
local function RefreshButtons()
    if BuffFrame_Update then
        BuffFrame_Update()
    end
end

local function Apply()
    RefreshButtons()
end

------------------------------------------------------------------------------
-- Buff frame integration
------------------------------------------------------------------------------
-- Icon: post-hook Blizzard's per-button update, then repaint our button.
if AuraButton_Update then
    hooksecurefunc("AuraButton_Update", function(buttonName, index, filter)
        if buttonName ~= "BuffButton" or not IsEnabled() then
            return
        end
        if AuraIsIndicator(index, filter) then
            DressButton(_G[buttonName .. index], index)
        end
    end)
end

-- Fallback for clients/builds whose buff frame does not expose
-- AuraButton_Update: repaint after a full buff frame update.
if BuffFrame_Update then
    hooksecurefunc("BuffFrame_Update", function()
        if not IsEnabled() then
            return
        end
        for index = 1, BUFF_BUTTON_MAX do
            local button = _G["BuffButton" .. index]
            if button and button:IsShown() and AuraIsIndicator(index, button.filter or "HELPFUL") then
                DressButton(button, index)
            end
        end
    end)
end

-- Tooltip: the buff button's OnEnter (and Blizzard's periodic refresh while it
-- stays hovered, AuraButton_OnUpdate) both end up in
-- GameTooltip:SetUnitAura(), so rewriting the lines right after it covers both.
hooksecurefunc(GameTooltip, "SetUnitAura", function(tooltip, unit, index, filter)
    if tooltip ~= GameTooltip then
        return
    end
    if unit and unit ~= "player" then
        return
    end
    if not IsEnabled() then
        return
    end
    -- Only the tooltip Blizzard's own buff button asked for: an addon that
    -- scans auras through a hidden GameTooltip (owner = UIParent) keeps reading
    -- the client's own name and icon. Deliberately not IsShown(): SetOwner()
    -- is what makes a GameTooltip visible, the buff frame never calls Show().
    local owner = tooltip:GetOwner()
    if not owner or owner ~= _G["BuffButton" .. tostring(index)] then
        return
    end
    if AuraIsIndicator(index, filter or "HELPFUL") then
        RewriteTooltip(tooltip)
    end
end)

------------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------------
local frame = CreateFrame("Frame", "HardcoreBadgeFrame")
HardcoreBadge.frame = frame
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(self, event)
    -- Aura changes need no handling here: Blizzard refreshes the buff frame on
    -- UNIT_AURA and the hooks above repaint the badge. This only makes sure
    -- the badge is painted right after login and after zoning.
    HardcoreBadge.found = IsEnabled() and (FindButtonIndex("HELPFUL") ~= nil)
    Apply()
end)

------------------------------------------------------------------------------
-- /hardcore
------------------------------------------------------------------------------
local function PrintHelp()
    Print("Badge v" .. HARDCORE_BADGE_VERSION .. " (1.14.2) - renames the server's Hardcore indicator buff")
    Print("/hardcore            - ask the server for your Hardcore status")
    Print("/hardcore on|off     - enable/disable the badge relabeling")
    Print("/hardcore name <txt> - badge title (default: Hardcore)")
    Print("/hardcore icon <skull|scream|soulgem|auto|path> - badge icon")
    Print("/hardcore match <name or texture> - extra key to recognize the buff")
    Print("/hardcore reset      - restore the defaults")
    Print("/hardcore debug      - list your buffs as this addon sees them")
end

local function PrintDebug()
    local db = DB()
    local major, minor, patch, build = GetBuildInfo()
    Print("debug: client " .. tostring(major) .. "." .. tostring(minor) .. "." .. tostring(patch)
          .. " (build " .. tostring(build) .. "), addon v" .. HARDCORE_BADGE_VERSION
          .. ", enabled=" .. tostring(db.enabled) .. ", name=\"" .. tostring(db.name) .. "\", icon=" .. tostring(db.icon))
    Print("debug: indicator spell id " .. INDICATOR_SPELL_ID
          .. ", client name \"" .. tostring(ClientSpellName()) .. "\""
          .. ", buff index " .. tostring(FindButtonIndex("HELPFUL") or "NOT FOUND"))
    for index = 1, BUFF_BUTTON_MAX do
        local name, texture, count, debuffType, duration, expirationTime,
              unitCaster, canStealOrPurge, nameplateShowPersonal, spellId = UnitAura("player", index, "HELPFUL")
        if not name then
            break
        end
        Print("debug: buff " .. index .. " -> name \"" .. tostring(name) .. "\""
              .. ", spellId " .. tostring(spellId)
              .. ", texture " .. tostring(texture)
              .. ", duration " .. tostring(duration))
    end
end

SLASH_HARDCOREBADGE1 = "/hardcore"
SlashCmdList["HARDCOREBADGE"] = function(msg)
    local db = DB()
    msg = Trim(msg)
    local cmd, rest = msg:match("^(%S*)%s*(.*)$")
    cmd = (cmd or ""):lower()
    rest = Trim(rest)

    if cmd == "" or cmd == "status" then
        -- Authoritative answer comes from the core (.hardcore status); the
        -- dot-command is intercepted by the server and never broadcast. Sent
        -- synchronously from the slash command: SAY needs a hardware event on
        -- this client.
        SendChatMessage(".hardcore status", "SAY")
        local index = FindButtonIndex("HELPFUL")
        Print("badge: " .. (index
              and ("found (spell " .. INDICATOR_SPELL_ID .. ", buff index " .. index .. ")")
              or "not found - this character has no Hardcore indicator aura"))
        Print("badge label \"" .. tostring(db.name) .. "\", icon " .. tostring(db.icon))

    elseif cmd == "on" or cmd == "enable" then
        db.enabled = true
        Apply()
        Print("badge relabeling enabled.")

    elseif cmd == "off" or cmd == "disable" then
        db.enabled = false
        Apply()
        Print("badge relabeling disabled - the buff shows the client's own name again.")

    elseif cmd == "name" then
        if rest == "" then
            Print("usage: /hardcore name <text>")
            return
        end
        db.name = rest
        Print("badge title set to \"" .. rest .. "\".")

    elseif cmd == "icon" then
        if rest == "" then
            Print("usage: /hardcore icon <skull|scream|soulgem|auto|Interface\\Icons\\...>")
            return
        end
        -- Accept a bare file name ("INV_Misc_Bone_HumanSkull_01") as well.
        if not ICON_PRESETS[rest] and rest ~= "auto" and not rest:find("\\") then
            db.icon = "Interface\\Icons\\" .. rest
        else
            db.icon = rest
        end
        Apply()
        Print("badge icon set to " .. tostring(BadgeIcon() or "the client's own icon") .. ".")

    elseif cmd == "match" then
        if rest == "" then
            Print("usage: /hardcore match <buff name or texture path>")
            return
        end
        local found = false
        for _, value in ipairs(db.extra) do
            if value == rest then
                found = true
            end
        end
        if not found then
            table.insert(db.extra, rest)
            InvalidateMatchCache()
        end
        Apply()
        Print("extra match key \"" .. rest .. "\" added.")

    elseif cmd == "reset" then
        HardcoreBadgeDB = {}
        DB()
        InvalidateMatchCache()
        Apply()
        Print("defaults restored.")

    elseif cmd == "debug" then
        PrintDebug()

    else
        PrintHelp()
    end
end
