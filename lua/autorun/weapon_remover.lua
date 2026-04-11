-- =====================================================
-- Weapon Remover v1.0
-- Author: Not a Person
-- =====================================================

-- =========================
-- Language system
-- =========================
local RW_Text = {
    en = {
        menu_cat = "Weapon Remover",
        settings = "Settings",
        about = "About",
        rem_all = "Remove all weapons",
        spawn_dis = "Disable weapons on spawn",
        hint_en = "Enable hint",
        welc_en = "Enable welcome message",
        binds = "Key binds",
        welc_msg = "Weapon Remover Activated",
        hint_txt = "Remove weapon: ",
        k_prim = "Primary Key:",
        k_sec = "Secondary Key:",
        done = "Weapon removed",
        all_done = "All weapons removed",
        info = "A simple tool to quickly strip weapons using key combinations.",
        testers = "Beta Testers:",
        github = "Visit GitHub Repository"
    },
    ru = {
        menu_cat = "Weapon Remover",
        settings = "Настройки",
        about = "О моде",
        rem_all = "Удалить всё оружие",
        spawn_dis = "Отключить оружие при спавне",
        hint_en = "Включить подсказку",
        welc_en = "Включить приветствие",
        binds = "Назначение клавиш",
        welc_msg = "Weapon Remover активирован",
        hint_txt = "Удалить оружие: ",
        k_prim = "Основная клавиша:",
        k_sec = "Дополнительная клавиша:",
        done = "Оружие удалено",
        all_done = "Всё оружие удалено",
        info = "Простой инструмент для быстрого удаления оружия комбинацией клавиш.",
        testers = "Бета-тестеры:",
        github = "Открыть репозиторий GitHub"
    }
}

local function L(k)
    local lang = CLIENT and GetConVar("gmod_language"):GetString() or "en"
    if not RW_Text[lang] then lang = "en" end
    return RW_Text[lang][k] or RW_Text["en"][k] or k
end

-- =========================
-- Settings (Updated ConVars)
-- =========================
CreateConVar("rw_disable_spawn_weapons", "0", FCVAR_ARCHIVE)
CreateConVar("rw_message_enabled", "1", FCVAR_ARCHIVE) -- Renamed as requested
CreateConVar("rw_hint_enabled", "1", FCVAR_ARCHIVE)
CreateConVar("rw_key_1", "16", FCVAR_ARCHIVE)
CreateConVar("rw_key_2", "108", FCVAR_ARCHIVE)

-- =========================
-- Network
-- =========================
if SERVER then
    util.AddNetworkString("RW_RemoveWeapon")
    util.AddNetworkString("RW_RemoveAllWeapons")
end

-- =========================
-- CLIENT
-- =========================
if CLIENT then

    local nextUse = 0

    -- Fixed Input Logic (No more chat.GetChatActive nil errors)
    hook.Add("Think", "RW_FinalInputCheck", function()
        -- Stable check for busy state
        if vgui.GetKeyboardFocus() or vgui.CursorVisible() or gui.IsConsoleVisible() then return end

        local k1 = GetConVar("rw_key_1"):GetInt()
        local k2 = GetConVar("rw_key_2"):GetInt()

        if input.IsButtonDown(k1) and input.IsButtonDown(k2) then
            if CurTime() < nextUse then return end
            nextUse = CurTime() + 0.5

            net.Start("RW_RemoveWeapon")
            net.SendToServer()

            notification.AddLegacy("[Weapon Remover] " .. L("done"), NOTIFY_GENERIC, 2)
        end
    end)

    -- HUD
    hook.Add("HUDPaint", "RW_HUD", function()
        if not GetConVar("rw_hint_enabled"):GetBool() then return end
        local k1, k2 = GetConVar("rw_key_1"):GetInt(), GetConVar("rw_key_2"):GetInt()
        local n1, n2 = string.upper(input.GetKeyName(k1) or ""), string.upper(input.GetKeyName(k2) or "")
        draw.SimpleText(L("hint_txt") .. n1 .. " + " .. n2, "DermaDefault", 25, 25, Color(255, 255, 255), TEXT_ALIGN_LEFT)
    end)

    -- Fixed Welcome Message
    hook.Add("InitPostEntity", "RW_Welcome_Msg", function()
        timer.Simple(5, function()
            if IsValid(LocalPlayer()) and GetConVar("rw_message_enabled"):GetBool() then
                chat.AddText(Color(80, 200, 255), "[Weapon Remover] ", Color(255, 255, 255), L("welc_msg"))
            end
        end)
    end)

    -- MENU SYSTEM
    hook.Add("PopulateToolMenu", "RW_CustomMenu", function()
        -- Settings Tab
        spawnmenu.AddToolMenuOption("Options", L("menu_cat"), "RW_S", L("settings"), "", "", function(p)
            p:ClearControls()
            p:CheckBox(L("spawn_dis"), "rw_disable_spawn_weapons")
            p:CheckBox(L("welc_en"), "rw_message_enabled")
            p:CheckBox(L("hint_en"), "rw_hint_enabled")
            p:Help(L("binds"))
            p:Help(L("k_prim"))
            local b1 = vgui.Create("DBinder", p) b1:SetConVar("rw_key_1") p:AddItem(b1)
            p:Help(L("k_sec"))
            local b2 = vgui.Create("DBinder", p) b2:SetConVar("rw_key_2") p:AddItem(b2)
            p:Button(L("rem_all"), "rw_remove_all")
        end)

        -- About Tab (Updated)
        spawnmenu.AddToolMenuOption("Options", L("menu_cat"), "RW_A", L("about"), "", "", function(p)
            p:ClearControls()
            p:Help("Weapon Remover")
            p:ControlHelp("Author: Not a Person")
            p:ControlHelp("Version: v1.0")
            p:Help(L("info"))
            
            p:Help("") -- Spacer
            p:Help(L("testers"))
            p:ControlHelp(" - Daniel64FX")
            
            p:Help("") -- Spacer
            local btn = p:Button(L("github"))
            btn.DoClick = function()
                gui.OpenURL("https://github.com/thechumersh/WeaponRemover-Addon-src/") -- Замени на свою ссылку
            end
            btn:SetIcon("icon16/link.png")
        end)
    end)

    concommand.Add("rw_remove_all", function()
        net.Start("RW_RemoveAllWeapons")
        net.SendToServer()
        notification.AddLegacy("[Weapon Remover] " .. L("all_done"), NOTIFY_GENERIC, 3)
    end)
end

-- =========================
-- SERVER
-- =========================
if SERVER then
    net.Receive("RW_RemoveWeapon", function(_, ply)
        if not IsValid(ply) or not ply:Alive() then return end
        local wep = ply:GetActiveWeapon()
        if IsValid(wep) then
            ply:StripWeapon(wep:GetClass())
            ply:EmitSound("buttons/button15.wav", 60, 100)
        end
    end)

    net.Receive("RW_RemoveAllWeapons", function(_, ply)
        if not IsValid(ply) then return end
        ply:StripWeapons()
        ply:EmitSound("buttons/button15.wav", 60, 100)
    end)

    hook.Add("PlayerLoadout", "RW_LoadoutBlock", function(ply)
        if GetConVar("rw_disable_spawn_weapons"):GetBool() then return true end
    end)
end