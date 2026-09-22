-- =========================================================================
-- Mak'gora (Duel to the Death) - Right-Click Menu Integration for 1.12
-- =========================================================================

UnitPopupButtons["MAKGORA"] = { text = "Challenge to Mak'gora", dist = 0 };

local function AddMakgoraOption(menu)
    if not menu then return end
    for i, button in ipairs(menu) do
        if button == "DUEL" then
            table.insert(menu, i + 1, "MAKGORA")
            return
        end
    end
    table.insert(menu, "MAKGORA")
end

AddMakgoraOption(UnitPopupMenus["PLAYER"])
AddMakgoraOption(UnitPopupMenus["FRIEND"])
AddMakgoraOption(UnitPopupMenus["PARTY"])
AddMakgoraOption(UnitPopupMenus["RAID_PLAYER"])

local orig_UnitPopup_OnClick = UnitPopup_OnClick;
function UnitPopup_OnClick()
    local dropdownFrame = getglobal(UIDROPDOWNMENU_INIT_MENU_NAME);
    local button = this.value;
    local name = dropdownFrame.name;

    if (button == "MAKGORA") then
        if (name) then
            SendChatMessage(".makgora challenge " .. name, "SAY");
        end
        return;
    end

    orig_UnitPopup_OnClick();
end
