-- =========================================================================
-- Mak'gora (Duel to the Death) - Right-Click Menu Integration
--
-- Supported clients:
--   * Vanilla WoW / Classic 1.12.1   (Interface 11200)
--   * Classic WoW 1.14.2.42597       (Interface 11402)
--
-- The unit popup menu globals (UnitPopupButtons / UnitPopupMenus /
-- UnitPopup_OnClick / UIDROPDOWNMENU_INIT_MENU_NAME) are present in both
-- client lines, so the same file works on either. Guards below make the
-- addon a safe no-op on any client where a piece of the menu system is
-- missing, instead of throwing.
-- =========================================================================

-- Menu entry definition (1.12.1 and 1.14.2 both use this table).
if (UnitPopupButtons and not UnitPopupButtons["MAKGORA"]) then
    UnitPopupButtons["MAKGORA"] = { text = "Challenge to Mak'gora", dist = 0 };
end

local function AddMakgoraOption(menu)
    if (not menu) then return end
    -- Insert right after "DUEL" when present, otherwise append at the end.
    for i, button in ipairs(menu) do
        if (button == "DUEL") then
            table.insert(menu, i + 1, "MAKGORA");
            return;
        end
    end
    table.insert(menu, "MAKGORA");
end

-- Inject the option into every right-click unit menu that can exist.
if (UnitPopupMenus) then
    AddMakgoraOption(UnitPopupMenus["PLAYER"]);
    AddMakgoraOption(UnitPopupMenus["FRIEND"]);
    AddMakgoraOption(UnitPopupMenus["PARTY"]);
    AddMakgoraOption(UnitPopupMenus["RAID_PLAYER"]);
end

-- Hook the menu click handler. UnitPopup_OnClick exists in both the 1.12.1
-- and the 1.14.2 client UI and is invoked with `this` pointing at the
-- clicked dropdown button; the dropdown frame name comes from the
-- UIDropDownMenu init menu (global UIDROPDOWNMENU_INIT_MENU_NAME).
if (type(UnitPopup_OnClick) == "function") then
    local orig_UnitPopup_OnClick = UnitPopup_OnClick;
    function UnitPopup_OnClick()
        local dropdownFrame = getglobal(UIDROPDOWNMENU_INIT_MENU_NAME);
        local button = this.value;
        local name = dropdownFrame and dropdownFrame.name;

        if (button == "MAKGORA") then
            if (name) then
                SendChatMessage(".makgora challenge " .. name, "SAY");
            end
            return;
        end

        orig_UnitPopup_OnClick();
    end
end
