--[[----------------------------------------------------------------------------
    Hardcore Badge  --  Vanilla 1.12.1 client build (build 5875)

    The server flags a Hardcore character with a permanent, effect-less aura:
    spell id 5 (SPELL_PLAYER_HARDCORE_INDICATOR, src/game/Objects/Player.h).
    That id is not arbitrary: a 1.12.1 client builds its buff frame from its
    own Spell.dbc and silently drops auras whose spell id has no record there,
    so the badge has to reuse an id the client already knows - and the one used
    by this core is Blizzard's unused GM test spell "Death Touch".

    For the same reason no server side change can ever rename that buff: an
    aura packet only carries the spell id, the flags, the level and the
    duration. Name, rank, icon and description always come from the client's
    Spell.dbc. So the label is fixed here, on the client:

      * the badge icon is replaced (default: the very same human skull the
        client already draws for entry 5, so it cannot be a missing texture);
      * the tooltip reads "Hardcore" plus what the flag actually means;
      * Blizzard's stack/duration text is suppressed on that button.

    Everything that matters gameplay wise (the aura itself, its permanence,
    the .hardcore command) is server side and works without this addon - only
    the label is cosmetic.

    This file is written for the 1.12.1 UI (Lua 5.0):
      * event/click handlers receive the frame in the global `this`
      * getglobal() instead of _G, table.getn() instead of #
      * no hooksecurefunc / taint system -> plain function wrapping is fine
      * the buff button's OnEnter is inline XML, so it is replaced with
        SetScript() and Blizzard's two lines are reproduced for other buffs

    Do NOT use this file on the 1.14.x client; use the 1.14.2 build instead.
------------------------------------------------------------------------------]]

HARDCORE_BADGE_VERSION = "1.0"

-- Spell id the server uses for the indicator. Must match
-- SPELL_PLAYER_HARDCORE_INDICATOR in src/game/Objects/Player.h.
local INDICATOR_SPELL_ID = 5

-- Keys used to find the badge in the buff list. Texture paths do not depend on
-- the client language, so they are the primary key; the localized names the
-- 1.12.1 client gives to spell 5 are the fallback (a custom client may have
-- re-iconed it). Add your own with /hardcore match <name or texture>.
local INDICATOR_TEXTURES = { "inv_misc_bone_humanskull_01" }
local INDICATOR_NAMES = {
    "Death Touch",        -- enUS / enGB
    "Todesberührung",     -- deDE
    "Toucher mortel",     -- frFR
    "Toque mortífero",    -- esES
    "Касание смерти",     -- ruRU
}

-- Icon presets. Every one of them is a texture that shipped with the vanilla
-- client, so none of them can show up as a missing/blank icon. "auto" keeps
-- whatever the client draws for the aura.
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

------------------------------------------------------------------------------
-- State
------------------------------------------------------------------------------
HardcoreBadge = {
    buffIndex  = nil,   -- buffIndex (all-auras index) of the badge, nil = none
    mode       = nil,   -- "texture" or "name": which key matched
    dirty      = 1,     -- rescan before the next use
    announced  = nil,   -- load line printed once per session
    scanTip    = nil,
    frame      = nil,
}

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------
local function Print(msg)
    if ( DEFAULT_CHAT_FRAME ) then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff2020[Hardcore]|r " .. tostring(msg))
    end
end

local function DB()
    if ( type(HardcoreBadgeDB) ~= "table" ) then
        HardcoreBadgeDB = {}
    end
    for key, value in pairs(DEFAULTS) do
        if ( HardcoreBadgeDB[key] == nil ) then
            HardcoreBadgeDB[key] = value
        end
    end
    if ( type(HardcoreBadgeDB.extra) ~= "table" ) then
        HardcoreBadgeDB.extra = {}
    end
    return HardcoreBadgeDB
end

local function Trim(s)
    if ( not s ) then
        return ""
    end
    local _, _, trimmed = string.find(s, "^%s*(.-)%s*$")
    return trimmed or ""
end

-- "Interface\Icons\INV_Misc_Bone_HumanSkull_01" -> "inv_misc_bone_humanskull_01"
local function TextureKey(texture)
    if ( not texture ) then
        return nil
    end
    local key = string.lower(string.gsub(texture, "/", "\\"))
    local _, _, base = string.find(key, "([^\\]+)$")
    return base or key
end

local function MatchSets()
    local db = DB()
    local textures, names = {}, {}

    for i = 1, table.getn(INDICATOR_TEXTURES) do
        textures[string.lower(INDICATOR_TEXTURES[i])] = 1
    end
    for i = 1, table.getn(INDICATOR_NAMES) do
        names[INDICATOR_NAMES[i]] = 1
        names[string.lower(INDICATOR_NAMES[i])] = 1
    end
    for i = 1, table.getn(db.extra) do
        local value = db.extra[i]
        if ( type(value) == "string" and value ~= "" ) then
            if ( string.find(value, "\\") or string.find(value, "/") ) then
                textures[TextureKey(value)] = 1
            else
                names[value] = 1
                names[string.lower(value)] = 1
            end
        end
    end

    return textures, names
end

-- Hidden tooltip used to read a buff's (localized) name from the client's DBC.
local function ScanTooltipName(buffIndex)
    local tip = HardcoreBadge.scanTip
    if ( not tip ) then
        return nil
    end
    tip:SetOwner(UIParent, "ANCHOR_NONE")
    tip:ClearLines()
    tip:SetPlayerBuff(buffIndex)
    local line = getglobal("HardcoreBadgeScanTooltipTextLeft1")
    local name = line and line:GetText()
    tip:Hide()
    return name
end

-- Texture learned at runtime when the name fallback matched, so that later
-- scans stay on the cheap (tooltip free) texture path.
local LearnedTexture = nil

-- Returns the buffIndex of the Hardcore badge, or nil.
local function Scan()
    local db = DB()
    if ( not db.enabled ) then
        return nil, nil
    end

    local textures, names = MatchSets()
    if ( LearnedTexture ) then
        textures[LearnedTexture] = 1
    end
    local notPermanent = nil

    -- Primary: the icon the client itself draws for spell 5. Cheap - no
    -- tooltip is involved, so this is what runs on every aura change.
    for buffId = 0, 31 do
        local buffIndex = GetPlayerBuff(buffId, "HELPFUL")
        if ( not buffIndex or buffIndex < 0 ) then
            break
        end
        local key = TextureKey(GetPlayerBuffTexture(buffIndex))
        if ( key and textures[key] ) then
            local timeLeft = GetPlayerBuffTimeLeft(buffIndex)
            if ( not timeLeft or timeLeft < 0 ) then
                return buffIndex, "texture" -- permanent, like the server badge
            elseif ( not notPermanent ) then
                notPermanent = buffIndex
            end
        end
    end
    if ( notPermanent ) then
        return notPermanent, "texture"
    end

    -- Fallback for clients that re-iconed spell 5: the localized name the
    -- client gives it. Only permanent auras are inspected (the badge always
    -- is), which keeps this to a handful of tooltip lookups.
    for buffId = 0, 31 do
        local buffIndex = GetPlayerBuff(buffId, "HELPFUL")
        if ( not buffIndex or buffIndex < 0 ) then
            break
        end
        local timeLeft = GetPlayerBuffTimeLeft(buffIndex)
        if ( not timeLeft or timeLeft < 0 ) then
            local name = ScanTooltipName(buffIndex)
            if ( name and names[name] ) then
                LearnedTexture = TextureKey(GetPlayerBuffTexture(buffIndex))
                return buffIndex, "name"
            end
        end
    end

    return nil, nil
end

local function Refresh()
    HardcoreBadge.dirty = nil
    HardcoreBadge.buffIndex, HardcoreBadge.mode = Scan()
    if ( HardcoreBadge.buffIndex and not HardcoreBadge.announced ) then
        HardcoreBadge.announced = 1
        Print("badge active - shown as \"" .. tostring(DB().name) .. "\" instead of the client's own spell "
              .. INDICATOR_SPELL_ID .. " name (/hardcore help)")
    end
end

local function IndicatorIndex()
    if ( HardcoreBadge.dirty ) then
        Refresh()
    end
    return HardcoreBadge.buffIndex
end

local function BadgeIcon()
    local db = DB()
    if ( not db.icon or db.icon == "auto" ) then
        return nil
    end
    if ( ICON_PRESETS[db.icon] ) then
        return ICON_PRESETS[db.icon]
    end
    return db.icon
end

local function DressButton(btn)
    if ( not btn ) then
        return
    end
    HardcoreBadge.dressedButton = btn
    local iconPath = BadgeIcon()
    if ( iconPath ) then
        local icon = getglobal(btn:GetName() .. "Icon")
        if ( icon ) then
            icon:SetTexture(iconPath)
        end
    end
    local count = getglobal(btn:GetName() .. "Count")
    if ( count ) then
        count:Hide()
    end
    local duration = getglobal(btn:GetName() .. "Duration")
    if ( duration ) then
        duration:Hide()
    end
end

-- Undo the dressing, straight from the client's own data, so that
-- /hardcore off (or another icon choice) is visible immediately.
local function RestoreButton(btn)
    if ( not btn ) then
        return
    end
    local icon = getglobal(btn:GetName() .. "Icon")
    if ( icon and btn.buffIndex ) then
        icon:SetTexture(GetPlayerBuffTexture(btn.buffIndex))
    end
    local count = getglobal(btn:GetName() .. "Count")
    if ( count ) then
        count:SetText("")
        count:Show()
    end
    local duration = getglobal(btn:GetName() .. "Duration")
    if ( duration ) then
        duration:SetText("")
        duration:Show()
    end
end

local function BadgeTooltip(btn)
    local db = DB()
    GameTooltip:SetOwner(btn, "ANCHOR_BOTTOMLEFT")
    GameTooltip:SetText(db.name, BADGE_TITLE_COLOR[1], BADGE_TITLE_COLOR[2], BADGE_TITLE_COLOR[3], 1)
    for i = 1, table.getn(BADGE_LINES) do
        GameTooltip:AddLine(BADGE_LINES[i], 1, 1, 1, 1)
    end
    GameTooltip:AddLine(" ", 1, 1, 1, 1)
    GameTooltip:AddLine(BADGE_FOOTER, 0.6, 0.6, 0.6, 1)
    GameTooltip:Show()
end

-- Let Blizzard rebuild every buff button, so an option change (or /hardcore
-- off) is visible immediately. `this` is a plain global in the 1.12 UI and
-- BuffButton_Update() reads the button it works on from it.
local function RefreshButtons()
    local oldThis = this
    for i = 0, 31 do
        local btn = getglobal("BuffButton" .. i)
        if ( btn and BuffButton_Update ) then
            this = btn
            BuffButton_Update()
        end
    end
    this = oldThis
end

local function Apply()
    local previous = HardcoreBadge.dressedButton
    HardcoreBadge.dressedButton = nil
    Refresh()
    if ( previous ) then
        -- Undo the previous dressing first: it is the reliable half of the
        -- repaint (RefreshButtons() relies on `this` being assignable).
        RestoreButton(previous)
    end
    RefreshButtons()
end

------------------------------------------------------------------------------
-- Buff frame integration
------------------------------------------------------------------------------
-- Icon: Blizzard sets the texture inside BuffButton_Update(), which is a plain
-- global called from the button's OnLoad/OnEvent XML handlers, so wrapping it
-- is enough to repaint our button after every aura change.
if ( BuffButton_Update ) then
    local OrigBuffButtonUpdate = BuffButton_Update
    function BuffButton_Update()
        local btn = this
        OrigBuffButtonUpdate()
        if ( btn ) then
            local index = IndicatorIndex()
            if ( index and btn.buffIndex == index ) then
                DressButton(btn)
            end
        end
    end
end

-- Tooltip: the 1.12 BuffButtonTemplate sets it inline in XML
-- (SetOwner + SetPlayerBuff), so the handler itself has to be replaced.
local function BadgeOnEnter()
    local btn = this
    local index = IndicatorIndex()
    if ( btn and index and btn.buffIndex == index ) then
        BadgeTooltip(btn)
        return
    end
    if ( btn ) then
        -- Blizzard's own two lines, for every other buff
        GameTooltip:SetOwner(btn, "ANCHOR_BOTTOMLEFT")
        GameTooltip:SetPlayerBuff(btn.buffIndex)
    end
end

for i = 0, 31 do
    local btn = getglobal("BuffButton" .. i)
    if ( btn ) then
        btn:SetScript("OnEnter", BadgeOnEnter)
    end
end

-- Blizzard also refreshes the hovered tooltip every frame; keep ours instead.
-- (A permanent aura has no duration to tick, so nothing else is lost here.)
if ( BuffButton_OnUpdate ) then
    local OrigBuffButtonOnUpdate = BuffButton_OnUpdate
    function BuffButton_OnUpdate()
        local btn = this
        local index = IndicatorIndex()
        if ( btn and index and btn.buffIndex == index ) then
            if ( GameTooltip:IsOwned(btn) ) then
                BadgeTooltip(btn)
            end
            return
        end
        OrigBuffButtonOnUpdate()
    end
end

------------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------------
HardcoreBadge.scanTip = CreateFrame("GameTooltip", "HardcoreBadgeScanTooltip", UIParent, "GameTooltipTemplate")
HardcoreBadge.scanTip:SetOwner(UIParent, "ANCHOR_NONE")

local frame = CreateFrame("Frame", "HardcoreBadgeFrame")
HardcoreBadge.frame = frame
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_AURAS_CHANGED")
frame:SetScript("OnEvent", function()
    HardcoreBadge.dirty = 1
    if ( event == "PLAYER_AURAS_CHANGED" ) then
        -- Blizzard updates its own buttons for this event as well and the
        -- wrapped BuffButton_Update() picks the badge up lazily.
        return
    end
    Apply()
end)

------------------------------------------------------------------------------
-- /hardcore
------------------------------------------------------------------------------
local function PrintHelp()
    Print("Badge v" .. HARDCORE_BADGE_VERSION .. " (1.12.1) - renames the server's Hardcore indicator buff")
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
    local build1, build2, build3, build4 = GetBuildInfo()
    Print("debug: client " .. tostring(build1) .. "." .. tostring(build2) .. "." .. tostring(build3)
          .. " (build " .. tostring(build4) .. "), addon v" .. HARDCORE_BADGE_VERSION
          .. ", enabled=" .. tostring(db.enabled) .. ", name=\"" .. tostring(db.name) .. "\", icon=" .. tostring(db.icon))
    Print("debug: indicator spell id " .. INDICATOR_SPELL_ID .. " -> "
          .. (HardcoreBadge.buffIndex and ("buffIndex " .. HardcoreBadge.buffIndex .. " (" .. tostring(HardcoreBadge.mode) .. " match)") or "NOT FOUND"))
    for buffId = 0, 31 do
        local buffIndex = GetPlayerBuff(buffId, "HELPFUL")
        if ( not buffIndex or buffIndex < 0 ) then
            break
        end
        Print("debug: buff " .. buffId .. " -> index " .. buffIndex
              .. ", name \"" .. tostring(ScanTooltipName(buffIndex)) .. "\""
              .. ", texture " .. tostring(GetPlayerBuffTexture(buffIndex))
              .. ", left " .. tostring(GetPlayerBuffTimeLeft(buffIndex)))
    end
end

SLASH_HARDCOREBADGE1 = "/hardcore"
SlashCmdList["HARDCOREBADGE"] = function(msg)
    local db = DB()
    msg = Trim(msg)
    local _, _, cmd, rest = string.find(msg, "^(%S*)%s*(.*)$")
    cmd = string.lower(cmd or "")
    rest = Trim(rest)

    if ( cmd == "" or cmd == "status" ) then
        -- Authoritative answer comes from the core (.hardcore status); the
        -- dot-command is intercepted by the server and never broadcast.
        SendChatMessage(".hardcore status", "SAY")
        Refresh()
        Print("badge: " .. (HardcoreBadge.buffIndex
              and ("found (spell " .. INDICATOR_SPELL_ID .. ", " .. tostring(HardcoreBadge.mode) .. " match)")
              or "not found - this character has no Hardcore indicator aura"))
        Print("badge label \"" .. tostring(db.name) .. "\", icon " .. tostring(db.icon))

    elseif ( cmd == "on" or cmd == "enable" ) then
        db.enabled = true
        HardcoreBadge.dirty = 1
        Apply()
        Print("badge relabeling enabled.")

    elseif ( cmd == "off" or cmd == "disable" ) then
        db.enabled = false
        HardcoreBadge.buffIndex = nil
        HardcoreBadge.dirty = 1
        Apply()
        Print("badge relabeling disabled - the buff shows the client's own name again.")

    elseif ( cmd == "name" ) then
        if ( rest == "" ) then
            Print("usage: /hardcore name <text>")
            return
        end
        db.name = rest
        Apply()
        Print("badge title set to \"" .. rest .. "\".")

    elseif ( cmd == "icon" ) then
        if ( rest == "" ) then
            Print("usage: /hardcore icon <skull|scream|soulgem|auto|Interface\\Icons\\...>")
            return
        end
        -- Accept a bare file name ("INV_Misc_Bone_HumanSkull_01") as well.
        if ( not ICON_PRESETS[rest] and rest ~= "auto" and not string.find(rest, "\\") ) then
            db.icon = "Interface\\Icons\\" .. rest
        else
            db.icon = rest
        end
        Apply()
        Print("badge icon set to " .. tostring(BadgeIcon() or "the client's own icon") .. ".")

    elseif ( cmd == "match" ) then
        if ( rest == "" ) then
            Print("usage: /hardcore match <buff name or texture path>")
            return
        end
        local found = nil
        for i = 1, table.getn(db.extra) do
            if ( db.extra[i] == rest ) then
                found = 1
            end
        end
        if ( not found ) then
            table.insert(db.extra, rest)
        end
        Apply()
        Print("extra match key \"" .. rest .. "\" added.")

    elseif ( cmd == "reset" ) then
        HardcoreBadgeDB = {}
        DB()
        HardcoreBadge.dirty = 1
        Apply()
        Print("defaults restored.")

    elseif ( cmd == "debug" ) then
        Refresh()
        PrintDebug()

    else
        PrintHelp()
    end
end
