-- DISCONTENT_Gear.lua
local DISCONTENT = _G.DISCONTENT
if not DISCONTENT then return end

DISCONTENT.gearPrefix = "DISGEAR"
DISCONTENT.gearData = DISCONTENT.gearData or {}

-------------------------------------------------
-- Gear Snapshot
-------------------------------------------------

function DISCONTENT:GetGearSnapshot()
    local name, realm = self:GetPlayerNameRealm()
    local equipped = GetAverageItemLevel()

    local data = {
        name = name,
        realm = realm,
        key = self:GetCharacterKey(name, realm),
        ilvl = equipped or 0,
        time = time()
    }

    return data
end

-------------------------------------------------
-- Helpers
-------------------------------------------------

function DISCONTENT:EnsureGearData()
    if type(self.gearData) ~= "table" then
        self.gearData = {}
    end

    if self.db then
        if type(self.db.gearData) ~= "table" then
            self.db.gearData = self.gearData
        else
            self.gearData = self.db.gearData
        end
    end

    return self.gearData
end

-------------------------------------------------
-- Store
-------------------------------------------------

function DISCONTENT:StoreGear(entry)
    if not entry or not entry.key or entry.key == "" then return end

    local gearTable = self:EnsureGearData()
    gearTable[entry.key] = entry

    if self.db then
        self.db.gearData = gearTable
    end
end

-------------------------------------------------
-- Broadcast
-------------------------------------------------

function DISCONTENT:BroadcastGear()
    if not IsInGuild() then return end

    local snap = self:GetGearSnapshot()
    self:StoreGear(snap)

    local msg = table.concat({
        "GS",
        snap.name or "",
        snap.realm or "",
        tostring(math.floor(tonumber(snap.ilvl) or 0)),
        tostring(snap.time or time())
    }, "^")

    C_ChatInfo.SendAddonMessage(
        self.gearPrefix,
        msg,
        "GUILD"
    )
end

-------------------------------------------------
-- Receive
-------------------------------------------------

function DISCONTENT:HandleGearMessage(prefix, msg)
    if prefix ~= self.gearPrefix then return end
    if type(msg) ~= "string" or msg == "" then return end

    local p = { strsplit("^", msg) }
    if p[1] ~= "GS" then return end

    local name = p[2]
    local realm = p[3]
    local ilvl = tonumber(p[4]) or 0
    local syncTime = tonumber(p[5]) or time()

    if not name or name == "" then return end
    if not realm or realm == "" then
        realm = GetRealmName() or "-"
    end

    local key = self:GetCharacterKey(name, realm)
    local gearTable = self:EnsureGearData()

    gearTable[key] = {
        name = name,
        realm = realm,
        key = key,
        ilvl = ilvl,
        time = syncTime
    }

    if self.db then
        self.db.gearData = gearTable
    end
end

-------------------------------------------------
-- Gear Ampel
-------------------------------------------------

function DISCONTENT:GetGearColor(ilvl)
    if not ilvl then return 0.5, 0.5, 0.5 end

    if ilvl < 580 then
        return 1, 0.2, 0.2
    end

    if ilvl < 600 then
        return 1, 0.8, 0
    end

    return 0.2, 1, 0.2
end

-------------------------------------------------
-- Popup
-------------------------------------------------

function DISCONTENT:CreateGearPopup()
    local f = CreateFrame("Frame", "DISCONTENTGearPopup", UIParent, "BackdropTemplate")

    f:SetSize(320, 160)
    f:SetPoint("CENTER")

    f:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12
    })

    f:SetBackdropColor(0, 0, 0, 0.9)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOP", 0, -10)
    f.title:SetText("Gear")

    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.text:SetPoint("TOPLEFT", 20, -40)
    f.text:SetWidth(280)
    f.text:SetJustifyH("LEFT")

    f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.close:SetPoint("TOPRIGHT")

    f:Hide()

    self.gearPopup = f
end

-------------------------------------------------
-- Show Gear
-------------------------------------------------

function DISCONTENT:ShowGear(member)
    if not member then return end

    if not self.gearPopup then
        self:CreateGearPopup()
    end

    local key = self:GetCharacterKey(member.name, member.realm)
    local gearTable = self:EnsureGearData()
    local data = gearTable[key]

    if not data then
        self.gearPopup.text:SetText("Keine Gear Daten")
    else
        local ilvlText = math.floor(tonumber(data.ilvl) or 0)
        local syncText = data.time and date("%H:%M", data.time) or "-"

        self.gearPopup.text:SetText(
            "Name: " .. (member.name or "-") .. "\n\n" ..
            "Itemlevel: " .. ilvlText .. "\n\n" ..
            "Letzter Sync: " .. syncText
        )
    end

    self.gearPopup:Show()
end

-------------------------------------------------
-- Events
-------------------------------------------------

local f = CreateFrame("Frame")

f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
f:RegisterEvent("CHAT_MSG_ADDON")

f:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        DISCONTENT:EnsureGearData()

        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            C_ChatInfo.RegisterAddonMessagePrefix(DISCONTENT.gearPrefix)
        end

        C_Timer.After(5, function()
            if DISCONTENT and DISCONTENT.BroadcastGear then
                DISCONTENT:BroadcastGear()
            end
        end)

    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        C_Timer.After(2, function()
            if DISCONTENT and DISCONTENT.BroadcastGear then
                DISCONTENT:BroadcastGear()
            end
        end)

    elseif event == "CHAT_MSG_ADDON" then
        local prefix, msg = ...
        if DISCONTENT and DISCONTENT.HandleGearMessage then
            DISCONTENT:HandleGearMessage(prefix, msg)
        end
    end
end)