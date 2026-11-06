include("shared.lua")
local AccessButton = vgui.Create("DButton")
AccessButton:SetText("Total Statistics")
AccessButton:SetPos(ScrW() - 160, ScrH() - 60)
AccessButton:SetSize(150, 50)
AccessButton:Hide()
local ShowButton = false

hook.Add("TTTEndRound", "TotalStatistics_ShowButtonEndRound", function(result)
    ShowButton = true
end)

hook.Add("TTTPrepareRound", "TotalStatistics_HideButtonPrepareRound", function()
    ShowButton = false
end)

hook.Add("Think", "TotalStatistics_IsButtonVisible", function()
    if ((LocalPlayer():IsDeadTerror() or LocalPlayer():Team() == TEAM_SPEC) or ShowButton) then
        AccessButton:Show()
    else
        AccessButton:Hide()
    end
end)

surface.CreateFont("TotalStatistics_DefaultItalics", {
    italic = true,
    size = 14,
})

local PlayerStats = nil
local CustomRolesEnabled = false

if CR_VERSION then
    CustomRolesEnabled = true
end

local function GetPlayerData()
    net.Start("TotalStatistics_RequestPlayerStats")
    net.SendToServer()
end

net.Receive("TotalStatistics_PlayerStatsMessage", function()
    local len = net.ReadUInt(16)
    local compressedString = net.ReadData(len)
    local playerStatsJson = util.Decompress(compressedString)
    PlayerStats = util.JSONToTable(playerStatsJson)
end)

local function GetRoleRate(record, role)
    local wins = TotalStats.GetValue(record, role .. "Wins")
    local rounds = math.max(wins, TotalStats.GetValue(record, role .. "Rounds", 1))
    if rounds > 0 then return wins / rounds * 100 end

    return 1
end

local function DisplayWindow()
    GetPlayerData()
    local MainWindow = vgui.Create("DFrame")
    MainWindow:SetTitle("Total Statistics for Trouble in Terrorist Town")
    MainWindow:SetPos(ScrW() - 410, ScrH() - 495)
    MainWindow:SetSize(400, 425)
    MainWindow:SetDeleteOnClose(true)

    function MainWindow:OnClose()
        gui.EnableScreenClicker(false)
    end

    local DataDisplay = vgui.Create("DListView", MainWindow)
    DataDisplay:SetPos(15, 125)
    DataDisplay:SetSize(370, 240)
    DataDisplay:SetMultiSelect(false)
    DataDisplay:AddColumn("", 1)
    DataDisplay:AddColumn("", 2)
    DataDisplay:SetSortable(true)
    local RefreshButton = vgui.Create("DButton", MainWindow)
    RefreshButton:SetText("Refresh window")
    RefreshButton:SetPos(MainWindow:GetWide() - 115, MainWindow:GetTall() - 45)
    RefreshButton:SetSize(100, 30)

    RefreshButton.DoClick = function()
        MainWindow:Close()
        DisplayWindow()
    end

    local DescriptionLabel = vgui.Create("DLabel", MainWindow)
    DescriptionLabel:SetText("")
    DescriptionLabel:SetPos(20, 95)
    DescriptionLabel:SetSize(360, 25)
    DescriptionLabel:SetContentAlignment(4)
    DescriptionLabel:SetFont("TotalStatistics_DefaultItalics")
    local StatisticLabel = vgui.Create("DLabel", MainWindow)
    StatisticLabel:SetText("Select statistic:")
    StatisticLabel:SetPos(20, 35)
    StatisticLabel:SetSize(90, 25)
    local RoleLabel = vgui.Create("DLabel", MainWindow)
    RoleLabel:SetText("Select role:")
    RoleLabel:SetPos(20, 65)
    RoleLabel:SetSize(90, 25)
    RoleLabel:Hide()
    local RoleDropdown = vgui.Create("DComboBox", MainWindow)
    RoleDropdown:SetText("")
    RoleDropdown:SetPos(110, 65)
    RoleDropdown:SetSize(275, 25)
    RoleDropdown:SetSortItems(false)
    RoleDropdown:AddChoice("Detective")
    RoleDropdown:AddChoice("Innocent")
    RoleDropdown:AddChoice("Traitor")
    local rolestring
    local rolestring_cap

    if CustomRolesEnabled then
        for r = 3, ROLE_MAX do
            rolestring = ROLE_STRINGS[r]
            rolestring = rolestring:sub(1, 1):upper() .. rolestring:sub(2)
            RoleDropdown:AddChoice(rolestring)
        end
    end

    RoleDropdown.OnSelect = function(index, value, str)
        DataDisplay:Clear()

        for r = 0, ROLE_MAX do
            rolestring = ROLE_STRINGS[r]
            rolestring_cap = rolestring:sub(1, 1):upper() .. rolestring:sub(2)

            if str == rolestring_cap then
                for id, record in pairs(PlayerStats) do
                    DataDisplay:AddLine(TotalStats.GetValue(record, "Nickname", "<UNKNOWN>"), math.Round(TotalStats.GetValue(record, rolestring .. "Wins") / TotalStats.GetValue(record, rolestring .. "Rounds", 1) * 100, 1))
                    DataDisplay:SortByColumn(2, true)
                end
            end
        end
    end

    RoleDropdown:Hide()
    local YourStatsLabel = vgui.Create("DLabel", MainWindow)
    YourStatsLabel:SetText("Subcategory:")
    YourStatsLabel:SetPos(20, 65)
    YourStatsLabel:SetSize(90, 25)
    YourStatsLabel:Hide()
    local YourStatsDropdown = vgui.Create("DComboBox", MainWindow)
    YourStatsDropdown:SetText("")
    YourStatsDropdown:SetPos(110, 65)
    YourStatsDropdown:SetSize(275, 25)
    YourStatsDropdown:SetSortItems(false)
    YourStatsDropdown:AddChoice("Role win rate")
    YourStatsDropdown:AddChoice("Times played role")
    YourStatsDropdown:AddChoice("Best traitor partners")
    YourStatsDropdown:AddChoice("Favourite detective equipment")
    YourStatsDropdown:AddChoice("Favourite traitor equipment")

    YourStatsDropdown.OnSelect = function(index, value, str)
        DataDisplay:Clear()

        if str == "Role win rate" then
            DescriptionLabel:SetText("Average role win rate (%).")

            for id, record in pairs(PlayerStats) do
                if (id == LocalPlayer():SteamID()) then
                    DataDisplay:AddLine("Detective", math.Round(GetRoleRate(record, "Detective"), 1))
                    DataDisplay:AddLine("Innocent", math.Round(GetRoleRate(record, "Innocent"), 1))
                    DataDisplay:AddLine("Traitor", math.Round(GetRoleRate(record, "Traitor"), 1))
                end
            end

            if (CustomRolesEnabled) then
                for id, record in pairs(PlayerStats) do
                    if (id == LocalPlayer():SteamID()) then
                        for r = 0, ROLE_MAX do
                            rolestring = ROLE_STRINGS[r]
                            rolestring_cap = string.Capitalize(rolestring)
                            DataDisplay:AddLine(rolestring_cap, math.Round(GetRoleRate(record, rolestring), 1))
                        end
                    end
                end
            end
        elseif str == "Times played role" then
            DescriptionLabel:SetText("Rounds playing each role (times role played/total rounds played).")

            for id, record in pairs(PlayerStats) do
                if (id == LocalPlayer():SteamID()) then
                    DataDisplay:AddLine("Detective", TotalStats.GetValue(record, "DetectiveRounds") .. "/" .. TotalStats.GetValue(record, "TotalRoundsPlayed"))
                    DataDisplay:AddLine("Innocent", TotalStats.GetValue(record, "InnocentRounds") .. "/" .. TotalStats.GetValue(record, "TotalRoundsPlayed"))
                    DataDisplay:AddLine("Traitor", TotalStats.GetValue(record, "TraitorRounds") .. "/" .. TotalStats.GetValue(record, "TotalRoundsPlayed"))
                end
            end

            if (CustomRolesEnabled) then
                for id, record in pairs(PlayerStats) do
                    if (id == LocalPlayer():SteamID()) then
                        if (id == LocalPlayer():SteamID()) then
                            for r = 3, ROLE_MAX do
                                rolestring = ROLE_STRINGS[r]
                                rolestring_cap = rolestring:sub(1, 1):upper() .. rolestring:sub(2)
                                DataDisplay:AddLine(rolestring_cap, (TotalStats.GetValue(record, rolestring .. "Rounds")) .. "/" .. TotalStats.GetValue(record, "TotalRoundsPlayed"))
                            end
                        end
                    end
                end
            end
        elseif str == "Best traitor partners" then
            DescriptionLabel:SetText("Win rate when on a traitor team with each player (%).")
            local record = PlayerStats[LocalPlayer():SteamID()]
            local partners = TotalStats.GetValue(record, "TraitorPartners", nil)

            if (partners == nil) then
                DataDisplay:AddLine("No partners yet", "No partners yet")
            else
                for partnerID, partnerTable in pairs(partners) do
                    DataDisplay:AddLine(partnerTable.Nick, math.Round(partnerTable.Wins / partnerTable.Rounds * 100), 1)
                end
            end

            DataDisplay:SortByColumn(2, true)
        elseif str == "Favourite detective equipment" then
            DescriptionLabel:SetText("Times you've bought each detective item")
            local record = PlayerStats[LocalPlayer():SteamID()]
            local equip = TotalStats.GetValue(record, "DetectiveEquipment", nil)

            if (equip == nil) then
                DataDisplay:AddLine("No equipment yet", "No equipment yet")
            else
                for itemName, timesBought in pairs(equip) do
                    DataDisplay:AddLine(itemName, timesBought)
                end
            end

            DataDisplay:SortByColumn(2, true)
        elseif str == "Favourite traitor equipment" then
            DescriptionLabel:SetText("Times you've bought each traitor item")
            local record = PlayerStats[LocalPlayer():SteamID()]
            local equip = TotalStats.GetValue(record, "TraitorEquipment", nil)

            if (equip == nil) then
                DataDisplay:AddLine("No equipment yet", "No equipment yet")
            else
                for itemName, timesBought in pairs(equip) do
                    DataDisplay:AddLine(itemName, timesBought)
                end
            end

            DataDisplay:SortByColumn(2, true)
        end
    end

    YourStatsDropdown:Hide()
    local StatisticDropdown = vgui.Create("DComboBox", MainWindow)
    StatisticDropdown:SetText("")
    StatisticDropdown:SetPos(110, 35)
    StatisticDropdown:SetSize(275, 25)
    StatisticDropdown:SetSortItems(false)
    StatisticDropdown:AddChoice("Your stats...")
    StatisticDropdown:AddChoice("Server average role win rates")
    StatisticDropdown:AddChoice("Best at role...")
    StatisticDropdown:AddChoice("Most rounds played")
    StatisticDropdown:AddChoice("Most often killed first")
    StatisticDropdown:AddChoice("Most crooked cop")
    StatisticDropdown:AddChoice("Most trigger-happy innocent")
    StatisticDropdown:AddChoice("Least safe near ledges")
    StatisticDropdown:AddChoice("Best traitor partners")
    StatisticDropdown:AddChoice("Favourite detective equipment")
    StatisticDropdown:AddChoice("Favourite traitor equipment")

    StatisticDropdown.OnSelect = function(index, value, str)
        RoleLabel:Hide()
        YourStatsLabel:Hide()
        RoleDropdown:Hide()
        YourStatsDropdown:Hide()
        DataDisplay:Clear()

        if str == "Your stats..." then
            DescriptionLabel:SetText("")
            YourStatsDropdown:Show()
            YourStatsLabel:Show()
        elseif str == "Server average role win rates" then
            DescriptionLabel:SetText("Server-wide role average win rates (%).")
            local AvgDRate = 0
            local AvgIRate = 0
            local AvgTRate = 0

            for _, record in pairs(PlayerStats) do
                AvgDRate = AvgDRate + GetRoleRate(record, "Detective")
                AvgIRate = AvgIRate + GetRoleRate(record, "Innocent")
                AvgTRate = AvgTRate + GetRoleRate(record, "Traitor")
            end

            AvgDRate = math.Round(AvgDRate / table.Count(PlayerStats), 1)
            AvgIRate = math.Round(AvgIRate / table.Count(PlayerStats), 1)
            AvgTRate = math.Round(AvgTRate / table.Count(PlayerStats), 1)
            DataDisplay:AddLine("Detective", AvgDRate)
            DataDisplay:AddLine("Innocent", AvgIRate)
            DataDisplay:AddLine("Traitor", AvgTRate)

            if (CustomRolesEnabled) then
                local AvgRate = {}
                local sRolestring = ""

                for r = 3, ROLE_MAX do
                    sRolestring = ROLE_STRINGS_SHORT[r]
                    rolestring = ROLE_STRINGS[r]
                    rolestring_cap = string.Capitalize(rolestring)
                    AvgRate[sRolestring] = 0

                    for id, record in pairs(PlayerStats) do
                        AvgRate[sRolestring] = AvgRate[sRolestring] + GetRoleRate(record, rolestring)
                    end

                    AvgRate[sRolestring] = math.Round(AvgRate[sRolestring] / table.Count(PlayerStats), 1)
                    DataDisplay:AddLine(rolestring_cap, AvgRate[sRolestring])
                end
            end
        elseif str == "Best at role..." then
            DescriptionLabel:SetText("Average role win rate (%).")
            RoleLabel:Show()
            RoleDropdown:Show()
        elseif str == "Most rounds played" then
            DescriptionLabel:SetText("Total number of rounds played.")

            for id, record in pairs(PlayerStats) do
                DataDisplay:AddLine(TotalStats.GetValue(record, "Nickname", "<UNKNOWN>"), TotalStats.GetValue(record, "TotalRoundsPlayed"))
                DataDisplay:SortByColumn(2, true)
            end
        elseif str == "Most often killed first" then
            DescriptionLabel:SetText("Percentage of their rounds that each player is killed first (%).")

            for id, record in pairs(PlayerStats) do
                DataDisplay:AddLine(TotalStats.GetValue(record, "Nickname", "<UNKNOWN>"), math.Round(TotalStats.GetValue(record, "KilledFirst") / TotalStats.GetValue(record, "TotalRoundsPlayed") * 100, 2))
                DataDisplay:SortByColumn(2, true)
            end
        elseif str == "Most crooked cop" then
            DescriptionLabel:SetText("Average number of innocents killed per round as detective.")

            for id, record in pairs(PlayerStats) do
                DataDisplay:AddLine(TotalStats.GetValue(record, "Nickname", "<UNKNOWN>"), math.Round(TotalStats.GetValue(record, "CrookedCop") / TotalStats.GetValue(record, "DetectiveRounds"), 2))
                DataDisplay:SortByColumn(2, true)
            end
        elseif str == "Most trigger-happy innocent" then
            DescriptionLabel:SetText("Average number of innocent players killed while on the innocent team.")

            for id, record in pairs(PlayerStats) do
                DataDisplay:AddLine(TotalStats.GetValue(record, "Nickname", "<UNKNOWN>"), math.Round(TotalStats.GetValue(record, "TriggerHappyInnocent") / (TotalStats.GetValue(record, "InnocentRounds", 1) + TotalStats.GetValue(record, "MercenaryRounds") + TotalStats.GetValue(record, "GlitchRounds") + TotalStats.GetValue(record, "PhantomRounds")), 2))
                DataDisplay:SortByColumn(2, true)
            end
        elseif str == "Least safe near ledges" then
            DescriptionLabel:SetText("Total fall damage taken.")

            for id, record in pairs(PlayerStats) do
                DataDisplay:AddLine(TotalStats.GetValue(record, "Nickname", "<UNKNOWN>"), TotalStats.GetValue(record, "TotalFallDamage"))
                DataDisplay:SortByColumn(2, true)
            end
        elseif str == "Best traitor partners" then
            DescriptionLabel:SetText("Each player's best traitor partner (win rate %).")

            for id, record in pairs(PlayerStats) do
                local bestPartner = {
                    Nick = "No traitor partners yet",
                    Winrate = -1
                }

                local thisPartnerWinRate = -1

                for partnerID, partnerTable in pairs(TotalStats.GetValue(record, "TraitorPartners")) do
                    thisPartnerWinRate = math.Round(partnerTable.Wins / partnerTable.Rounds * 100, 1)

                    if thisPartnerWinRate > bestPartner.Winrate then
                        bestPartner.Winrate = thisPartnerWinRate
                        bestPartner.Nick = partnerTable.Nick
                    end
                end

                DataDisplay:AddLine(TotalStats.GetValue(record, "Nickname", "<UNKNOWN>"), bestPartner.Nick .. " (" .. bestPartner.Winrate .. "%)")
            end
        elseif str == "Favourite detective equipment" then
            DescriptionLabel:SetText("Each player's favourite detective equipment (times bought).")

            for id, record in pairs(PlayerStats) do
                local favouriteEquipment = "No equipment bought yet"
                local mostTimesBought = 0

                for itemName, thisItemTimesBought in pairs(TotalStats.GetValue(record, "DetectiveEquipment")) do
                    if thisItemTimesBought > mostTimesBought then
                        favouriteEquipment = itemName
                        mostTimesBought = thisItemTimesBought
                    end
                end

                DataDisplay:AddLine(TotalStats.GetValue(record, "Nickname", "<UNKNOWN>"), favouriteEquipment .. " (" .. mostTimesBought .. ")")
            end
        elseif str == "Favourite traitor equipment" then
            DescriptionLabel:SetText("Each player's favourite traitor equipment (times bought).")

            for id, record in pairs(PlayerStats) do
                local favouriteEquipment = "No equipment bought yet"
                local mostTimesBought = 0

                for itemName, thisItemTimesBought in pairs(TotalStats.GetValue(record, "TraitorEquipment")) do
                    if thisItemTimesBought > mostTimesBought then
                        favouriteEquipment = itemName
                        mostTimesBought = thisItemTimesBought
                    end
                end

                DataDisplay:AddLine(TotalStats.GetValue(record, "Nickname", "<UNKNOWN>"), favouriteEquipment .. " (" .. mostTimesBought .. ")")
            end
        end
    end

    gui.EnableScreenClicker(true)
end

AccessButton.DoClick = function()
    DisplayWindow()
end

local function GetItemName(item, role)
    local id = tonumber(item)
    local info = GetEquipmentItemById and GetEquipmentItemById(id) or GetEquipmentItem(role, id)

    return info and LANG.TryTranslation(info.name) or item
end

function GetWeaponName(item)
    for _, v in ipairs(weapons.GetList()) do
        if item == WEPS.GetClass(v) then return LANG.TryTranslation(v.PrintName) end
    end

    return item
end

hook.Add("TTTBoughtItem", "TotalStatistics_PlayerBoughtItem", function(is_item, equipment)
    local role = LocalPlayer():GetRole()
    local name
    local passive = false
    local id = tostring(equipment)

    if is_item then
        passive = true
        -- Block items not on the equipment list as they are likely given by the randomat
        local item = GetEquipmentItem(role, equipment)
        if not item then return end
        name = GetItemName(equipment, role)
    else
        local SWEP = weapons.Get(equipment)
        if not SWEP then return end

        -- Block items not in the player's buy menu as they were probably given by the randomat
        if not istable(SWEP.CanBuy) then
            return
        elseif not table.HasValue(SWEP.CanBuy, role) then
            return
        end

        name = GetWeaponName(equipment)
    end

    net.Start("TotalStatistics_SendClientEquipmentName")

    if name ~= equipment then
        net.WriteString(name)
        net.WriteBool(passive)
        net.WriteString(id)
    else
        net.WriteString(equipment)
        net.WriteBool(passive)
        net.WriteString(id)
    end

    net.SendToServer()
end)