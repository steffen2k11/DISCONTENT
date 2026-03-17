local addonName = ...
local DISCONTENT = CreateFrame("Frame", "DISCONTENTFrame", UIParent)
_G.DISCONTENT = DISCONTENT

DISCONTENT.members = {}
DISCONTENT.filteredMembers = {}
DISCONTENT.guildChatMessages = {}
DISCONTENT.newsEntries = DISCONTENT.newsEntries or {}
DISCONTENT.gearData = DISCONTENT.gearData or {}

DISCONTENT.rankFilter = "ALLE"
DISCONTENT.searchText = ""
DISCONTENT.onlineOnly = false
DISCONTENT.sortAscending = true
DISCONTENT.sortColumn = "name"

DISCONTENT.rowHeight = 20
DISCONTENT.minVisibleRows = 16
DISCONTENT.visibleRows = 16
DISCONTENT.rows = {}
DISCONTENT.scrollOffset = 0

DISCONTENT.uiCreated = false
DISCONTENT.defaultWidth = 1180
DISCONTENT.defaultHeight = 620
DISCONTENT.defaultScale = 1.00
DISCONTENT.defaultBackgroundAlpha = 0.88
DISCONTENT.uiScaleValue = 1.00
DISCONTENT.pendingScaleValue = 1.00
DISCONTENT.backgroundAlpha = 0.88
DISCONTENT.pendingBackgroundAlpha = 0.88
DISCONTENT.activeTab = "guildnews"
DISCONTENT.maxChatMessages = 80

DISCONTENT.addonVersion = "1.0.1"
DISCONTENT.defaultWelcomeWidth = 430
DISCONTENT.defaultWelcomeHeight = 285
DISCONTENT.professionSyncPrefix = "DISCPROF"
DISCONTENT.raidPrepSyncPrefix = "DISCRPREP"
DISCONTENT.mythicPlusPrefix = "DISCMPLUS"
DISCONTENT.pushMessagePrefix = "DISCPUSH"
DISCONTENT.newsSyncPrefix = "DISCNEWS"
DISCONTENT.defaultMinimapAngle = 220
DISCONTENT.defaultShowMinimapButton = true
DISCONTENT.defaultShowWelcomePopup = true

DISCONTENT.professions = {}
DISCONTENT.professionRows = {}
DISCONTENT.professionVisibleRows = 14
DISCONTENT.professionRowHeight = 22
DISCONTENT.professionScrollOffset = 0
DISCONTENT.professionSearchText = ""
DISCONTENT.addonUsers = {}

DISCONTENT.allowedOfficerRanks = {
    ["Gildenleitung"] = true,
    ["Officer"] = true,
    ["Twink-Offi"] = true,
}

DISCONTENT.raidPrepEntries = {
    {
        category = "Charakter-Sims & Datenpflege",
        items = {
            "Aktuelle Sims durchgeführt: Hast du deinen Charakter mit den neuesten Items durch Raidbots (Top Gear / Droptimizer) gejagt?",
            "WoWaudit Upload: Sind deine aktuellen Daten/Sims bei WoWaudit hochgeladen, damit der Raid-Lead deine Stats und Vorbereitung sehen kann und das Loot-Council eine faire Itemvergabe vornehmen kann?",
            "Talent-Builds vorbereitet: Hast du die passenden Talent-Strings für die verschiedenen Encounter (Single Target, Add-Cleave, Council) in deinen Vorlagen gespeichert?",
            "Boss-spezifische Anpassungen: Weißt du, bei welchem Boss du z.B. einen zusätzlichen Stop, Kick oder defensiven Cooldown mitskillen musst?",
            "Boss-Guides: Hast du dich mit den im Discord bereitgestellten Informationen auf die Raidbosse vorbereitet?",
        },
    },
    {
        category = "Ausrüstung & Optimierung",
        items = {
            "Item Level Maxed: Alle Items maximal aufgewertet, sofern zum aktuellen Zeitpunkt sinnvoll?",
            "Vollständig Verzaubert: Waffe, Brust, Ringe, Umhang, Armschienen, Stiefel, Hose (höchster Rang) etc..",
            "Bestmögliche Edelsteine: Alle Sockelplätze mit den korrekten Gems gefüllt.",
            "Embellishments: Sofern sinnvoll, hast du gecrafted?",
        },
    },
    {
        category = "Consumables (Verbrauchsgüter)",
        items = {
            "Flasks vorhanden",
            "Buff-Food vorhanden",
            "Pots vorhanden",
            "Heiltränke vorhanden",
            "Waffen-Buffs: Öl, Schleifsteine oder Gewichtsteine für die gesamte Dauer.",
            "Verstärkungsrunen: Sofern gefordert.",
            "Vantusrune: Falls für einen speziellen Progress-Boss angefordert.",
        },
    },
}

DISCONTENT.CLASS_COLORS = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS

function DISCONTENT:SafeName(fullName)
    if not fullName then return "" end
    return fullName:match("^[^-]+") or fullName
end

function DISCONTENT:SafeRealm(fullName)
    if not fullName then return "-" end
    return fullName:match("-(.+)$") or GetRealmName() or "-"
end

function DISCONTENT:GetPlayerNameRealm()
    local name, realm = UnitFullName("player")
    if not name or name == "" then
        name = UnitName("player") or "Unknown"
    end
    if not realm or realm == "" then
        realm = GetRealmName() or "-"
    end
    return name, realm
end

function DISCONTENT:GetCharacterKey(name, realm)
    local safeName = self:SafeName(name or "")
    local safeRealm = realm or GetRealmName() or "-"
    return safeName .. "-" .. safeRealm
end

function DISCONTENT:ClearTable(tbl)
    wipe(tbl)
end

function DISCONTENT:NormalizeText(text)
    return string.lower(text or "")
end

function DISCONTENT:SafeText(text)
    if text == nil or text == "" then
        return "-"
    end
    return tostring(text)
end

function DISCONTENT:TrimChatHistory(messages, maxCount)
    while #messages > maxCount do
        table.remove(messages, 1)
    end
end

function DISCONTENT:GetPlayerGuildRankName()
    if not IsInGuild() then
        return ""
    end

    local playerName = self:SafeName(UnitName("player") or "")
    local numMembers = GetNumGuildMembers() or 0

    for i = 1, numMembers do
        local fullName, rankName = GetGuildRosterInfo(i)
        if fullName and self:SafeName(fullName) == playerName then
            return rankName or ""
        end
    end

    return ""
end

function DISCONTENT:CanSeeOfficerTab()
    local rankName = self:GetPlayerGuildRankName()
    return self.allowedOfficerRanks[rankName] and true or false
end

function DISCONTENT:InitializeDB()
    if type(_G.DISCONTENTDB) ~= "table" then
        _G.DISCONTENTDB = {}
    end

    self.db = _G.DISCONTENTDB

    if type(self.db.uiScaleValue) == "number" then
        self.uiScaleValue = self.db.uiScaleValue
    else
        self.uiScaleValue = self.defaultScale
    end

    if type(self.db.backgroundAlpha) == "number" then
        self.backgroundAlpha = self.db.backgroundAlpha
    else
        self.backgroundAlpha = self.defaultBackgroundAlpha
    end

    local minimap = self:EnsureMinimapDB()
    self.db.showMinimapButton = not minimap.hide
    self.db.minimapButtonAngle = minimap.minimapPos

    if type(self.db.showWelcomePopup) ~= "boolean" then
        self.db.showWelcomePopup = self.defaultShowWelcomePopup ~= false
    end

    if type(self.db.professions) ~= "table" then
        self.db.professions = {}
    end

    if type(self.db.addonUsers) ~= "table" then
        self.db.addonUsers = {}
    end

    if type(self.db.gearData) ~= "table" then
        self.db.gearData = {}
    end

    if type(self.db.raidPrep) ~= "table" then
        self.db.raidPrep = {}
    end

    if type(self.db.raidPrep.characters) ~= "table" then
        self.db.raidPrep.characters = {}
    end

    if type(self.db.raidPrep.cycleId) ~= "number" then
        self.db.raidPrep.cycleId = 1
    end

    if type(self.db.raidPrep.lastCycleAt) ~= "number" then
        self.db.raidPrep.lastCycleAt = time()
    end

    if type(self.db.raidPrepStatus) ~= "table" then
        self.db.raidPrepStatus = {}
    end

    if type(self.db.notes) ~= "table" then
        self.db.notes = {}
    end

    if type(self.db.notes.characters) ~= "table" then
        self.db.notes.characters = {}
    end

    if type(self.db.officerNotes) ~= "table" then
        self.db.officerNotes = {}
    end

    if type(self.db.mythicPlus) ~= "table" then
        self.db.mythicPlus = {}
    end

    if type(self.db.mythicPlus.teams) ~= "table" then
        self.db.mythicPlus.teams = {}
    end

    if type(self.db.mythicPlus.teamOrder) ~= "table" then
        self.db.mythicPlus.teamOrder = {}
    end

    if type(self.db.mythicPlus.incoming) ~= "table" then
        self.db.mythicPlus.incoming = {}
    end

    if type(self.db.news) ~= "table" then
        self.db.news = {}
    end

    if type(self.db.news.entries) ~= "table" then
        self.db.news.entries = {}
    end

    if type(self.db.news.seen) ~= "table" then
        self.db.news.seen = {}
    end

    if type(self.db.news.revision) ~= "number" then
        self.db.news.revision = 0
    end

    self.newsEntries = self.db.news.entries
    self.newsSeen = self.db.news.seen
    self.newsRevision = tonumber(self.db.news.revision) or 0

    self.professions = self.db.professions
    self.addonUsers = self.db.addonUsers
    self.gearData = self.db.gearData
    self.pendingScaleValue = self.uiScaleValue
    self.pendingBackgroundAlpha = self.backgroundAlpha
end

function DISCONTENT:SaveSettings()
    if type(_G.DISCONTENTDB) ~= "table" then
        _G.DISCONTENTDB = {}
    end

    self.db = _G.DISCONTENTDB
    self.db.uiScaleValue = self.uiScaleValue
    self.db.backgroundAlpha = self.backgroundAlpha
    self.db.showWelcomePopup = self:GetWelcomePopupEnabled()

    local minimap = self:EnsureMinimapDB()
    minimap.hide = self.db.showMinimapButton == false
    minimap.minimapPos = tonumber(self.db.minimapButtonAngle) or self.defaultMinimapAngle
    self.db.showMinimapButton = not minimap.hide
    self.db.minimapButtonAngle = minimap.minimapPos
    self.db.professions = self.professions or {}
    self.db.addonUsers = self.addonUsers or {}
    self.db.gearData = self.gearData or {}

    if type(self.db.raidPrep) ~= "table" then
        self.db.raidPrep = {}
    end

    if type(self.db.raidPrep.characters) ~= "table" then
        self.db.raidPrep.characters = {}
    end

    if type(self.db.raidPrep.cycleId) ~= "number" then
        self.db.raidPrep.cycleId = 1
    end

    if type(self.db.raidPrep.lastCycleAt) ~= "number" then
        self.db.raidPrep.lastCycleAt = time()
    end

    if type(self.db.raidPrepStatus) ~= "table" then
        self.db.raidPrepStatus = {}
    end

    if type(self.db.notes) ~= "table" then
        self.db.notes = {}
    end

    if type(self.db.notes.characters) ~= "table" then
        self.db.notes.characters = {}
    end

    if type(self.db.officerNotes) ~= "table" then
        self.db.officerNotes = {}
    end

    if type(self.db.mythicPlus) ~= "table" then
        self.db.mythicPlus = {}
    end

    if type(self.db.mythicPlus.teams) ~= "table" then
        self.db.mythicPlus.teams = {}
    end

    if type(self.db.mythicPlus.teamOrder) ~= "table" then
        self.db.mythicPlus.teamOrder = {}
    end

    if type(self.db.mythicPlus.incoming) ~= "table" then
        self.db.mythicPlus.incoming = {}
    end

    if type(self.db.news) ~= "table" then
        self.db.news = {}
    end

    self.db.news.entries = self.newsEntries or {}
    self.db.news.seen = self.newsSeen or {}
    self.db.news.revision = tonumber(self.newsRevision) or 0
end

function DISCONTENT:GetSortedNewsEntries()
    local entries = {}

    if self.newsEntries then
        for i = 1, #self.newsEntries do
            entries[#entries + 1] = self.newsEntries[i]
        end
    end

    table.sort(entries, function(a, b)
        local aPinned = self:IsImportantNews(a) and 1 or 0
        local bPinned = self:IsImportantNews(b) and 1 or 0

        if aPinned ~= bPinned then
            return aPinned > bPinned
        end

        local at = self:GetNewsTimestampValue(a)
        local bt = self:GetNewsTimestampValue(b)

        if type(at) == "string" then at = tonumber(at) or 0 end
        if type(bt) == "string" then bt = tonumber(bt) or 0 end

        at = tonumber(at) or 0
        bt = tonumber(bt) or 0

        if at ~= bt then
            return at > bt
        end

        return (tonumber(a.id) or 0) > (tonumber(b.id) or 0)
    end)

    return entries
end


function DISCONTENT:GetVersionLabel()
    return "v" .. tostring(self.addonVersion or "?") .. " by morbi"
end

function DISCONTENT:RoundToNearest(value)
    value = tonumber(value) or 0
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

function DISCONTENT:SaveFramePosition(frame, dbKey)
    if not frame or not dbKey then
        return
    end

    if type(_G.DISCONTENTDB) ~= "table" then
        _G.DISCONTENTDB = {}
    end

    self.db = _G.DISCONTENTDB

    local point, _, relativePoint, xOfs, yOfs = frame:GetPoint(1)
    self.db[dbKey] = {
        point = point or "CENTER",
        relativePoint = relativePoint or point or "CENTER",
        x = self:RoundToNearest(xOfs),
        y = self:RoundToNearest(yOfs),
    }
end

function DISCONTENT:RestoreFramePosition(frame, dbKey, defaultPoint, defaultRelativePoint, defaultX, defaultY)
    if not frame then
        return
    end

    local saved = self.db and self.db[dbKey]
    frame:ClearAllPoints()

    if type(saved) == "table" and saved.point then
        frame:SetPoint(
            saved.point or "CENTER",
            UIParent,
            saved.relativePoint or saved.point or "CENTER",
            tonumber(saved.x) or 0,
            tonumber(saved.y) or 0
        )
    else
        frame:SetPoint(
            defaultPoint or "CENTER",
            UIParent,
            defaultRelativePoint or defaultPoint or "CENTER",
            defaultX or 0,
            defaultY or 0
        )
    end
end

function DISCONTENT:EnsureMinimapDB()
    if type(_G.DISCONTENTDB) ~= "table" then
        _G.DISCONTENTDB = {}
    end

    self.db = _G.DISCONTENTDB

    if type(self.db.minimap) ~= "table" then
        self.db.minimap = {}
    end

    local minimap = self.db.minimap

    if type(self.db.showMinimapButton) == "boolean" and type(minimap.hide) ~= "boolean" then
        minimap.hide = not self.db.showMinimapButton
    end

    if type(self.db.minimapButtonAngle) == "number" and type(minimap.minimapPos) ~= "number" then
        minimap.minimapPos = self.db.minimapButtonAngle
    end

    if type(minimap.hide) ~= "boolean" then
        minimap.hide = not self.defaultShowMinimapButton
    end

    if type(minimap.minimapPos) ~= "number" then
        minimap.minimapPos = self.defaultMinimapAngle or 220
    end

    self.db.showMinimapButton = not minimap.hide
    self.db.minimapButtonAngle = minimap.minimapPos

    return minimap
end

function DISCONTENT:GetMinimapIconPath()
    return "Interface\\AddOns\\" .. tostring(addonName or "DISCONTENT") .. "\\DISCONTENT_minimap"
end

function DISCONTENT:GetMinimapObjectName()
    return tostring(addonName or "DISCONTENT")
end

function DISCONTENT:GetMinimapButtonAngle()
    local minimap = self:EnsureMinimapDB()
    return tonumber(minimap.minimapPos) or self.defaultMinimapAngle or 220
end

function DISCONTENT:SetMinimapButtonAngle(angle)
    local minimap = self:EnsureMinimapDB()
    angle = tonumber(angle) or self.defaultMinimapAngle or 220

    while angle < 0 do
        angle = angle + 360
    end

    while angle >= 360 do
        angle = angle - 360
    end

    minimap.minimapPos = angle
    self.db.showMinimapButton = not minimap.hide
    self.db.minimapButtonAngle = minimap.minimapPos

    if self.libDBIcon and self.minimapDataObject then
        self.libDBIcon:Refresh(self:GetMinimapObjectName(), minimap)
    end
end

function DISCONTENT:UpdateMinimapButtonPosition()
    if not self.libDBIcon or not self.minimapDataObject then
        return
    end

    self.libDBIcon:Refresh(self:GetMinimapObjectName(), self:EnsureMinimapDB())
    self.minimapButton = _G["LibDBIcon10_" .. self:GetMinimapObjectName()] or self.minimapButton
end

function DISCONTENT:RefreshMinimapButtonVisibility()
    local minimap = self:EnsureMinimapDB()
    local name = self:GetMinimapObjectName()

    if self.libDBIcon and self.minimapDataObject then
        if minimap.hide then
            self.libDBIcon:Hide(name)
        else
            self.libDBIcon:Show(name)
            self.libDBIcon:Refresh(name, minimap)
        end
    end

    self.minimapButton = _G["LibDBIcon10_" .. name] or self.minimapButton

    if self.minimapButton then
        if minimap.hide then
            self.minimapButton:Hide()
        else
            self.minimapButton:Show()
            self.minimapButton:SetAlpha(1)
            self.minimapButton:EnableMouse(true)
            self.minimapButton:SetFrameStrata("MEDIUM")
            self.minimapButton:SetFrameLevel(8)
        end
    end

    if self.minimapToggleCheckbox then
        self.minimapToggleCheckbox:SetChecked(not minimap.hide)
    end
end

function DISCONTENT:SetMinimapButtonEnabled(enabled)
    local shouldShow = enabled and true or false
    local minimap = self:EnsureMinimapDB()
    minimap.hide = not shouldShow
    self.db.showMinimapButton = shouldShow
    self.db.minimapButtonAngle = tonumber(minimap.minimapPos) or self.defaultMinimapAngle

    if self.minimapToggleCheckbox then
        self.minimapToggleCheckbox:SetChecked(shouldShow)
    end

    self:SaveSettings()
    self:RefreshMinimapButtonVisibility()
end

function DISCONTENT:CreateMinimapDataObject()
    if self.minimapDataObject then
        return self.minimapDataObject
    end

    if not LibStub then
        return nil
    end

    local ldb = LibStub:GetLibrary("LibDataBroker-1.1", true)
    local dbIcon = LibStub:GetLibrary("LibDBIcon-1.0", true)
    if not ldb or not dbIcon then
        return nil
    end

    self.ldb = ldb
    self.libDBIcon = dbIcon

    local name = self:GetMinimapObjectName()
    local dataObject = ldb:GetDataObjectByName(name)

    if not dataObject then
        dataObject = ldb:NewDataObject(name, {
            type = "launcher",
            icon = self:GetMinimapIconPath(),
            label = "DISCONTENT",
            text = "DISCONTENT",
        })
    end

    dataObject.icon = self:GetMinimapIconPath()
    dataObject.label = "DISCONTENT"
    dataObject.text = "DISCONTENT"
    dataObject.OnClick = function(_, mouseButton)
        if mouseButton == "RightButton" then
            if DISCONTENT.welcomeFrame and DISCONTENT.welcomeFrame:IsShown() then
                DISCONTENT.welcomeFrame:Hide()
            else
                DISCONTENT:ShowWelcomeWindow()
            end
            return
        end

        if DISCONTENT:IsShown() then
            DISCONTENT:Hide()
        else
            DISCONTENT:ShowMainWindow()
        end
    end

    dataObject.OnTooltipShow = function(tooltip)
        tooltip:AddLine("DISCONTENT", 1, 0.82, 0.2)
        tooltip:AddLine("Linksklick: Addon öffnen/schließen", 0.9, 0.9, 0.9)
        tooltip:AddLine("Rechtsklick: Welcome-News öffnen", 0.9, 0.9, 0.9)
        tooltip:AddLine("Ziehen: Position ändern", 0.65, 0.85, 1)
    end

    self.minimapDataObject = dataObject
    return dataObject
end

function DISCONTENT:RegisterMinimapIcon()
    local dataObject = self:CreateMinimapDataObject()
    if not dataObject or not self.libDBIcon then
        return
    end

    local name = self:GetMinimapObjectName()
    local minimap = self:EnsureMinimapDB()

    if self.libDBIcon.IsRegistered and not self.libDBIcon:IsRegistered(name) then
        self.libDBIcon:Register(name, dataObject, minimap)
    else
        self.libDBIcon:Refresh(name, minimap)
    end

    self.minimapButton = _G["LibDBIcon10_" .. name] or self.minimapButton

    if self.minimapButton then
        self.minimapButton:SetFrameStrata("MEDIUM")
        self.minimapButton:SetFrameLevel(8)
    end

    self:RefreshMinimapButtonVisibility()
end

function DISCONTENT:CreateMinimapButton()
    self:RegisterMinimapIcon()
end

function DISCONTENT:GetWelcomePopupEnabled()
    if not self.db then
        return self.defaultShowWelcomePopup ~= false
    end

    if type(self.db.showWelcomePopup) ~= "boolean" then
        self.db.showWelcomePopup = self.defaultShowWelcomePopup ~= false
    end

    return self.db.showWelcomePopup ~= false
end

function DISCONTENT:SetWelcomePopupEnabled(enabled)
    if type(_G.DISCONTENTDB) ~= "table" then
        _G.DISCONTENTDB = {}
    end

    self.db = _G.DISCONTENTDB
    self.db.showWelcomePopup = enabled and true or false

    if self.welcomePopupToggleCheckbox then
        self.welcomePopupToggleCheckbox:SetChecked(self.db.showWelcomePopup)
    end

    if self.db.showWelcomePopup == false and self.welcomeFrame and self.welcomeFrame:IsShown() then
        self.welcomeFrame:Hide()
    end

    self:SaveSettings()
end

function DISCONTENT:CreateMinimapSettingsToggle()
    if self.minimapToggleCheckbox or not self.settingsTabContent then
        return
    end

    local check = CreateFrame("CheckButton", nil, self.settingsTabContent, "UICheckButtonTemplate")
    self.minimapToggleCheckbox = check

    if self.backgroundSlider then
        check:SetPoint("TOPLEFT", self.backgroundSlider, "BOTTOMLEFT", -8, -28)
    elseif self.scaleSlider then
        check:SetPoint("TOPLEFT", self.scaleSlider, "BOTTOMLEFT", -8, -28)
    elseif self.settingsPanel then
        check:SetPoint("TOPLEFT", self.settingsPanel, "TOPLEFT", 14, -160)
    else
        check:SetPoint("TOPLEFT", self.settingsTabContent, "TOPLEFT", 26, -120)
    end

    check.text = check:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    check.text:SetPoint("LEFT", check, "RIGHT", 4, 1)
    check.text:SetJustifyH("LEFT")
    check.text:SetText("Minimap-Icon anzeigen")

    check.subText = self.settingsTabContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    check.subText:SetPoint("TOPLEFT", check.text, "BOTTOMLEFT", 0, -4)
    check.subText:SetWidth(340)
    check.subText:SetJustifyH("LEFT")
    check.subText:SetJustifyV("TOP")
    check.subText:SetText("Blendet den DISCONTENT-Button an der Minimap ein oder aus. Das Addon lässt außerdem über den Befehl /discontent öffnen.")

    local minimap = self:EnsureMinimapDB()
    check:SetChecked(not minimap.hide)
    check:SetScript("OnClick", function(frame)
        local shouldShow = frame:GetChecked() and true or false
        DISCONTENT:SetMinimapButtonEnabled(shouldShow)
    end)
end

function DISCONTENT:NormalizeNewsTimestampValue(value)
    if value == nil then
        return nil
    end

    if type(value) == "number" then
        local numeric = tonumber(value)
        if not numeric then
            return nil
        end

        numeric = math.floor(numeric)

        local digits = tostring(math.abs(numeric))
        if #digits == 12 or #digits == 14 or #digits == 8 then
            local year, month, day, hour, minute, second

            if #digits == 8 then
                year = tonumber(digits:sub(1, 4))
                month = tonumber(digits:sub(5, 6))
                day = tonumber(digits:sub(7, 8))
                hour = 12
                minute = 0
                second = 0
            elseif #digits == 12 then
                year = tonumber(digits:sub(1, 4))
                month = tonumber(digits:sub(5, 6))
                day = tonumber(digits:sub(7, 8))
                hour = tonumber(digits:sub(9, 10)) or 0
                minute = tonumber(digits:sub(11, 12)) or 0
                second = 0
            else
                year = tonumber(digits:sub(1, 4))
                month = tonumber(digits:sub(5, 6))
                day = tonumber(digits:sub(7, 8))
                hour = tonumber(digits:sub(9, 10)) or 0
                minute = tonumber(digits:sub(11, 12)) or 0
                second = tonumber(digits:sub(13, 14)) or 0
            end

            if year and month and day and month >= 1 and month <= 12 and day >= 1 and day <= 31 then
                local parsed = time({
                    year = year,
                    month = month,
                    day = day,
                    hour = hour or 0,
                    min = minute or 0,
                    sec = second or 0,
                })
                if parsed then
                    return parsed
                end
            end
        end

        if numeric > 999999999999 then
            numeric = math.floor(numeric / 1000)
        end

        if numeric > 946684800 and numeric < 4102444800 then
            return numeric
        end

        return nil
    end

    if type(value) ~= "string" then
        return nil
    end

    local trimmed = strtrim(value)
    if trimmed == "" then
        return nil
    end

    local numeric = tonumber(trimmed)
    if numeric then
        return self:NormalizeNewsTimestampValue(numeric)
    end

    local year, month, day, hour, minute, second = trimmed:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)[T ](%d%d):(%d%d):?(%d?%d?)")
    if year then
        return time({
            year = tonumber(year),
            month = tonumber(month),
            day = tonumber(day),
            hour = tonumber(hour) or 0,
            min = tonumber(minute) or 0,
            sec = tonumber(second) or 0,
        })
    end

    year, month, day = trimmed:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    if year then
        return time({
            year = tonumber(year),
            month = tonumber(month),
            day = tonumber(day),
            hour = 12,
            min = 0,
            sec = 0,
        })
    end

    day, month, year, hour, minute, second = trimmed:match("^(%d%d)%.(%d%d)%.(%d%d%d%d)%s*(%d?%d?):?(%d?%d?):?(%d?%d?)$")
    if day and month and year then
        return time({
            year = tonumber(year),
            month = tonumber(month),
            day = tonumber(day),
            hour = tonumber(hour) or 0,
            min = tonumber(minute) or 0,
            sec = tonumber(second) or 0,
        })
    end

    day, month, year = trimmed:match("^(%d%d)%.(%d%d)%.(%d%d%d%d)$")
    if day and month and year then
        return time({
            year = tonumber(year),
            month = tonumber(month),
            day = tonumber(day),
            hour = 12,
            min = 0,
            sec = 0,
        })
    end

    return trimmed
end

function DISCONTENT:GetNewsTimestampValue(entry)
    if type(entry) ~= "table" then
        return nil
    end

    local candidates = {
        entry.timestamp,
        entry.dateText,
        entry.time,
        entry.date,
        entry.createdAt,
        entry.created,
        entry.whenText,
        entry.updatedAt,
        entry.updated,
        entry.postedAt,
        entry.posted,
        entry.id,
    }

    for i = 1, #candidates do
        local normalized = self:NormalizeNewsTimestampValue(candidates[i])
        if normalized ~= nil and normalized ~= "" then
            return normalized
        end
    end

    return nil
end

function DISCONTENT:CreateBackdropFrame(parent)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    frame:SetBackdropColor(0.05, 0.05, 0.06, 0.94)
    frame:SetBackdropBorderColor(0.5, 0.5, 0.55, 1)
    return frame
end

function DISCONTENT:CreateSingleLineInput(parent, width, height)
    local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    box:SetSize(width, height or 24)
    box:SetAutoFocus(false)
    box:SetFontObject(GameFontHighlightSmall)
    box:SetTextInsets(8, 8, 0, 0)
    box:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    box:SetBackdropColor(0.02, 0.02, 0.03, 0.95)
    box:SetBackdropBorderColor(0.32, 0.34, 0.4, 1)
    box:EnableMouse(true)
    box:SetCursorPosition(0)
    box:SetScript("OnMouseDown", function(self)
        self:SetFocus()
    end)
    box:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    box:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    return box
end

function DISCONTENT:CreateMultilineInput(parent, width, height)
    local frame = self:CreateBackdropFrame(parent)
    frame:SetSize(width, height)

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 6)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame.offset = 0
    scrollFrame.cursorOffset = 0

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(GameFontHighlightSmall)
    editBox:SetWidth(math.max(100, width - 40))
    editBox:SetHeight(math.max(24, height - 12))
    editBox:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, 0)
    editBox:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", 0, 0)
    editBox:SetTextInsets(4, 4, 4, 4)
    editBox:SetJustifyH("LEFT")
    editBox:SetJustifyV("TOP")
    editBox:EnableMouse(true)
    editBox.scrollFrame = scrollFrame
    scrollFrame.editBox = editBox
    scrollFrame:SetScrollChild(editBox)

    local measureText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    measureText:Hide()
    measureText:SetPoint("TOPLEFT", frame, "TOPLEFT", -9999, -9999)
    measureText:SetWidth(math.max(100, width - 48))
    measureText:SetJustifyH("LEFT")
    measureText:SetJustifyV("TOP")
    if measureText.SetNonSpaceWrap then
        measureText:SetNonSpaceWrap(true)
    end

    local function UpdateEditBoxHeight(self)
        local text = self:GetText() or ""
        measureText:SetText(text ~= "" and text or " ")
        local measuredHeight = (measureText.GetStringHeight and measureText:GetStringHeight()) or 0
        local newHeight = math.max(height - 12, measuredHeight + 20)
        self:SetHeight(newHeight)
        scrollFrame:UpdateScrollChildRect()
        if scrollFrame.ScrollBar then
            local _, maxVal = scrollFrame.ScrollBar:GetMinMaxValues()
            local current = scrollFrame:GetVerticalScroll() or 0
            if maxVal and current > maxVal then
                scrollFrame:SetVerticalScroll(maxVal)
            end
        end
    end

    editBox:SetScript("OnTextChanged", function(self, userInput)
        UpdateEditBoxHeight(self)
        if ScrollingEdit_OnTextChanged then
            ScrollingEdit_OnTextChanged(self)
        end
    end)
    editBox:SetScript("OnCursorChanged", function(self, x, y, w, h)
        if ScrollingEdit_OnCursorChanged then
            ScrollingEdit_OnCursorChanged(self, x, y, w, h)
        else
            local sf = self.scrollFrame
            local scroll = sf:GetVerticalScroll() or 0
            local viewHeight = sf:GetHeight() or 0
            local topY = math.abs(y or 0)
            local bottomY = topY + (h or 0)
            if topY < scroll then
                sf:SetVerticalScroll(topY)
            elseif bottomY > (scroll + viewHeight) then
                sf:SetVerticalScroll(bottomY - viewHeight)
            end
        end
    end)
    editBox:SetScript("OnUpdate", function(self, elapsed)
        if ScrollingEdit_OnUpdate then
            ScrollingEdit_OnUpdate(self, elapsed)
        end
    end)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    editBox:SetScript("OnEditFocusGained", function(self)
        UpdateEditBoxHeight(self)
    end)

    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll() or 0
        local minVal, maxVal = 0, 0
        if self.ScrollBar and self.ScrollBar.GetMinMaxValues then
            minVal, maxVal = self.ScrollBar:GetMinMaxValues()
        else
            maxVal = math.max(0, (editBox:GetHeight() or 0) - (self:GetHeight() or 0))
        end
        local newValue = current - (delta * 20)
        if newValue < minVal then
            newValue = minVal
        elseif newValue > maxVal then
            newValue = maxVal
        end
        self:SetVerticalScroll(newValue)
    end)

    frame.scrollFrame = scrollFrame
    frame.editBox = editBox

    UpdateEditBoxHeight(editBox)
    return frame, editBox
end

function DISCONTENT:EscapePushValue(value)
    value = tostring(value or "")
    value = value:gsub("%%", "%%25")
    value = value:gsub("|", "%%7C")
    value = value:gsub("\r", "")
    value = value:gsub("\n", "%%0A")
    return value
end

function DISCONTENT:UnescapePushValue(value)
    value = tostring(value or "")
    value = value:gsub("%%0A", "\n")
    value = value:gsub("%%7C", "|")
    value = value:gsub("%%25", "%%")
    return value
end

function DISCONTENT:BuildPushPayload(subject, author, textValue)
    return table.concat({
        self:EscapePushValue(subject),
        self:EscapePushValue(author),
        self:EscapePushValue(textValue),
    }, "|")
end

function DISCONTENT:ParsePushPayload(payload)
    local subject, author, textValue = tostring(payload or ""):match("^(.-)|(.-)|(.*)$")
    return self:UnescapePushValue(subject), self:UnescapePushValue(author), self:UnescapePushValue(textValue)
end

function DISCONTENT:SendGuildPushMessage(subject, author, textValue)
    if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then
        return false, "Addon-Kommunikation nicht verfügbar."
    end

    if not IsInGuild() then
        return false, "Du bist in keiner Gilde."
    end

    local payload = self:BuildPushPayload(subject, author, textValue)
    local chunkSize = tonumber(self.pushChunkSize) or 210
    local totalChunks = math.max(1, math.ceil(#payload / chunkSize))
    local messageId = tostring(time()) .. "-" .. tostring(math.random(1000, 9999))

    C_ChatInfo.SendAddonMessage(self.pushMessagePrefix, "S|" .. messageId .. "|" .. tostring(totalChunks), "GUILD")

    for index = 1, totalChunks do
        local startPos = ((index - 1) * chunkSize) + 1
        local chunk = payload:sub(startPos, startPos + chunkSize - 1)
        C_ChatInfo.SendAddonMessage(
            self.pushMessagePrefix,
            "C|" .. messageId .. "|" .. tostring(index) .. "|" .. chunk,
            "GUILD"
        )
    end

    C_ChatInfo.SendAddonMessage(self.pushMessagePrefix, "E|" .. messageId, "GUILD")
    self:ShowPushNotification(subject, author, textValue)
    return true
end

function DISCONTENT:HandlePushMessage(prefix, message, channel, sender)
    if prefix ~= self.pushMessagePrefix then
        return
    end

    local playerName = self:SafeName(UnitName("player") or "")
    if self:SafeName(sender or "") == playerName then
        return
    end

    self.pushInbound = self.pushInbound or {}

    local opcode, rest = tostring(message or ""):match("^([^|]+)|?(.*)$")
    if not opcode or opcode == "" then
        return
    end

    if opcode == "S" then
        local messageId, totalChunks = rest:match("^([^|]+)|([^|]+)$")
        if not messageId then
            return
        end

        self.pushInbound[messageId] = {
            total = tonumber(totalChunks) or 0,
            sender = sender,
            chunks = {},
        }
        return
    end

    if opcode == "C" then
        local messageId, indexText, chunk = rest:match("^([^|]+)|([^|]+)|?(.*)$")
        if not messageId then
            return
        end

        local entry = self.pushInbound[messageId]
        if not entry then
            entry = {
                total = 0,
                sender = sender,
                chunks = {},
            }
            self.pushInbound[messageId] = entry
        end

        entry.chunks[tonumber(indexText) or (#entry.chunks + 1)] = chunk or ""
        return
    end

    if opcode == "E" then
        local messageId = rest
        local entry = self.pushInbound[messageId]
        if not entry then
            return
        end

        local parts = {}
        for index = 1, math.max(1, entry.total or 0) do
            if not entry.chunks[index] then
                return
            end
            parts[#parts + 1] = entry.chunks[index]
        end

        local payload = table.concat(parts, "")
        local subject, author, textValue = self:ParsePushPayload(payload)
        subject = subject ~= "" and subject or "DISCONTENT Push-Nachricht"
        author = author ~= "" and author or self:SafeName(entry.sender or "Unbekannt")
        textValue = textValue ~= "" and textValue or "-"

        self.pushInbound[messageId] = nil
        self:ShowPushNotification(subject, author, textValue)
    end
end

function DISCONTENT:CreatePushComposePopup()
    if self.pushComposePopup then
        return
    end

    local popup = CreateFrame("Frame", "DISCONTENTPushComposePopup", UIParent, "BackdropTemplate")
    popup:SetSize(500, 390)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetToplevel(true)
    popup:SetClampedToScreen(true)
    popup:SetMovable(true)
    popup:EnableMouse(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", popup.StartMoving)
    popup:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        DISCONTENT:SaveFramePosition(frame, "pushComposePopupPosition")
    end)
    popup:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    popup:SetBackdropColor(0.02, 0.02, 0.03, 0.97)
    popup:SetBackdropBorderColor(0.78, 0.64, 0.18, 1)

    popup.title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    popup.title:SetPoint("TOP", popup, "TOP", 0, -12)
    popup.title:SetText("Push-Nachricht senden")

    popup.subtitle = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    popup.subtitle:SetPoint("TOPLEFT", popup, "TOPLEFT", 16, -38)
    popup.subtitle:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -16, -38)
    popup.subtitle:SetJustifyH("LEFT")
    popup.subtitle:SetText("Sende eine kurze Push-Nachricht an alle Gildenmitglieder, die DISCONTENT installiert haben.")

    popup.closeButton = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
    popup.closeButton:SetPoint("TOPRIGHT", -4, -4)

    popup.subjectLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    popup.subjectLabel:SetPoint("TOPLEFT", popup, "TOPLEFT", 18, -76)
    popup.subjectLabel:SetText("Betreff")

    popup.subjectInput = self:CreateSingleLineInput(popup, 464, 24)
    popup.subjectInput:SetPoint("TOPLEFT", popup.subjectLabel, "BOTTOMLEFT", 0, -6)

    popup.authorLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    popup.authorLabel:SetPoint("TOPLEFT", popup.subjectInput, "BOTTOMLEFT", 0, -14)
    popup.authorLabel:SetText("Absender")

    popup.authorInput = self:CreateSingleLineInput(popup, 464, 24)
    popup.authorInput:SetPoint("TOPLEFT", popup.authorLabel, "BOTTOMLEFT", 0, -6)

    popup.textLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    popup.textLabel:SetPoint("TOPLEFT", popup.authorInput, "BOTTOMLEFT", 0, -14)
    popup.textLabel:SetText("Text")

    popup.textFrame, popup.textInput = self:CreateMultilineInput(popup, 464, 148)
    popup.textFrame:SetPoint("TOPLEFT", popup.textLabel, "BOTTOMLEFT", 0, -6)

    popup.statusText = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    popup.statusText:SetPoint("BOTTOMLEFT", popup, "BOTTOMLEFT", 18, 18)
    popup.statusText:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -130, 18)
    popup.statusText:SetJustifyH("LEFT")
    popup.statusText:SetText("")

    popup.sendButton = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    popup.sendButton:SetSize(100, 28)
    popup.sendButton:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -16, 14)
    popup.sendButton:SetText("Senden")
    popup.sendButton:SetScript("OnClick", function()
        local subject = popup.subjectInput:GetText() or ""
        local author = popup.authorInput:GetText() or ""
        local textValue = popup.textInput:GetText() or ""

        subject = subject:gsub("^%s+", ""):gsub("%s+$", "")
        author = author:gsub("^%s+", ""):gsub("%s+$", "")
        textValue = textValue:gsub("^%s+", ""):gsub("%s+$", "")

        if subject == "" then
            popup.statusText:SetText("Bitte einen Betreff eingeben.")
            popup.statusText:SetTextColor(1, 0.25, 0.25, 1)
            return
        end

        if author == "" then
            popup.statusText:SetText("Bitte einen Absender eingeben.")
            popup.statusText:SetTextColor(1, 0.25, 0.25, 1)
            return
        end

        if textValue == "" then
            popup.statusText:SetText("Bitte einen Nachrichtentext eingeben.")
            popup.statusText:SetTextColor(1, 0.25, 0.25, 1)
            return
        end

        local ok, err = DISCONTENT:SendGuildPushMessage(subject, author, textValue)
        if ok then
            popup.statusText:SetText("Push-Nachricht wurde gesendet.")
            popup.statusText:SetTextColor(0.35, 1, 0.35, 1)
            popup:Hide()
        else
            popup.statusText:SetText(err or "Senden fehlgeschlagen.")
            popup.statusText:SetTextColor(1, 0.25, 0.25, 1)
        end
    end)

    popup:SetScript("OnShow", function(frame)
        local playerName = DISCONTENT:SafeName(UnitName("player") or "Unbekannt")
        frame.subjectInput:SetText("")
        frame.authorInput:SetText(playerName)
        frame.textInput:SetText("")
        frame.textInput:SetHeight(136)
        frame.statusText:SetText("")
        DISCONTENT:RestoreFramePosition(frame, "pushComposePopupPosition", "CENTER", "CENTER", 70, 30)
        C_Timer.After(0, function()
            if frame.subjectInput then
                frame.subjectInput:SetFocus()
            end
        end)
    end)

    popup:Hide()
    self.pushComposePopup = popup
end

function DISCONTENT:ShowPushComposePopup()
    if not self.pushComposePopup then
        self:CreatePushComposePopup()
    end

    if self.pushComposePopup then
        self.pushComposePopup:Show()
    end
end

function DISCONTENT:CreatePushNotificationPopup()
    if self.pushNotificationPopup then
        return
    end

    local popup = CreateFrame("Frame", "DISCONTENTPushNotificationPopup", UIParent, "BackdropTemplate")
    popup:SetSize(420, 270)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetToplevel(true)
    popup:SetClampedToScreen(true)
    popup:SetMovable(true)
    popup:EnableMouse(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", popup.StartMoving)
    popup:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        DISCONTENT:SaveFramePosition(frame, "pushNotificationPopupPosition")
    end)
    popup:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    popup:SetBackdropColor(0.03, 0.03, 0.04, 0.96)
    popup:SetBackdropBorderColor(0.82, 0.67, 0.18, 1)

    popup.title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    popup.title:SetPoint("TOP", popup, "TOP", 0, -12)
    popup.title:SetText("DISCONTENT Push")

    popup.closeButton = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
    popup.closeButton:SetPoint("TOPRIGHT", -4, -4)

    popup.subjectLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    popup.subjectLabel:SetPoint("TOPLEFT", popup, "TOPLEFT", 16, -42)
    popup.subjectLabel:SetText("Betreff")

    popup.subjectText = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    popup.subjectText:SetPoint("TOPLEFT", popup.subjectLabel, "BOTTOMLEFT", 0, -4)
    popup.subjectText:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -16, -46)
    popup.subjectText:SetJustifyH("LEFT")
    popup.subjectText:SetText("-")

    popup.authorLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    popup.authorLabel:SetPoint("TOPLEFT", popup.subjectText, "BOTTOMLEFT", 0, -12)
    popup.authorLabel:SetText("Absender")

    popup.authorText = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    popup.authorText:SetPoint("TOPLEFT", popup.authorLabel, "BOTTOMLEFT", 0, -4)
    popup.authorText:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -16, -94)
    popup.authorText:SetJustifyH("LEFT")
    popup.authorText:SetText("-")

    popup.textFrame = self:CreateBackdropFrame(popup)
    popup.textFrame:SetPoint("TOPLEFT", popup.authorText, "BOTTOMLEFT", 0, -14)
    popup.textFrame:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -16, 42)

    popup.textScroll = CreateFrame("ScrollFrame", nil, popup.textFrame, "UIPanelScrollFrameTemplate")
    popup.textScroll:SetPoint("TOPLEFT", popup.textFrame, "TOPLEFT", 8, -8)
    popup.textScroll:SetPoint("BOTTOMRIGHT", popup.textFrame, "BOTTOMRIGHT", -28, 8)

    popup.textChild = CreateFrame("Frame", nil, popup.textScroll)
    popup.textChild:SetSize(1, 1)
    popup.textScroll:SetScrollChild(popup.textChild)

    popup.textValue = popup.textChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    popup.textValue:SetPoint("TOPLEFT", popup.textChild, "TOPLEFT", 0, 0)
    popup.textValue:SetWidth(340)
    popup.textValue:SetJustifyH("LEFT")
    popup.textValue:SetJustifyV("TOP")
    popup.textValue:SetSpacing(2)
    popup.textValue:SetText("-")

    popup.dragInfo = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    popup.dragInfo:SetPoint("BOTTOMLEFT", popup, "BOTTOMLEFT", 16, 18)
    popup.dragInfo:SetText("Fenster verschiebbar – Position wird gespeichert.")

    popup:Hide()
    self.pushNotificationPopup = popup
end

function DISCONTENT:ShowPushNotification(subject, author, textValue)
    if not self.pushNotificationPopup then
        self:CreatePushNotificationPopup()
    end

    local popup = self.pushNotificationPopup
    if not popup then
        return
    end

    popup.subjectText:SetText(self:SafeText(subject))
    popup.authorText:SetText(self:SafeText(author))
    popup.textValue:SetText(self:SafeText(textValue))
    popup.textValue:SetWidth(math.max(280, (popup.textFrame:GetWidth() or 360) - 34))

    C_Timer.After(0, function()
        if not popup or not popup.textValue then
            return
        end

        local childWidth = math.max(1, (popup.textScroll:GetWidth() or 320) - 20)
        local childHeight = math.max((popup.textValue:GetStringHeight() or 0) + 8, popup.textScroll:GetHeight() or 1)
        popup.textValue:SetWidth(childWidth)
        popup.textChild:SetSize(childWidth, childHeight)
        popup.textScroll:SetVerticalScroll(0)
    end)

    self:RestoreFramePosition(popup, "pushNotificationPopupPosition", "CENTER", "CENTER", 0, 160)
    popup:Show()
end

function DISCONTENT:EnsureOfficerPushButton()
    if self.officerPushButton then
        if self.officerNewCycleButton and not self.officerPushButton.anchorAttached then
            self.officerPushButton:ClearAllPoints()
            self.officerPushButton:SetPoint("LEFT", self.officerNewCycleButton, "RIGHT", 8, 0)
            self.officerPushButton.anchorAttached = true
        end
        return
    end

    local parent = self.officerTabContent or self
    if not parent then
        return
    end

    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(118, 24)
    button:SetText("Push-Nachricht")
    button:SetScript("OnClick", function()
        DISCONTENT:ShowPushComposePopup()
    end)

    if self.officerNewCycleButton then
        button:SetPoint("LEFT", self.officerNewCycleButton, "RIGHT", 8, 0)
        button.anchorAttached = true
    else
        button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -18, -18)
    end

    self.officerPushButton = button
end


function DISCONTENT:FormatNewsTimestamp(timestamp)
    if timestamp == nil or timestamp == "" then
        return nil
    end

    if type(timestamp) == "string" then
        local trimmed = strtrim(timestamp)
        return trimmed ~= "" and trimmed or nil
    end

    local numeric = tonumber(timestamp) or 0
    if numeric <= 0 then
        return nil
    end

    local formatted = date("%d.%m.%Y %H:%M", numeric)
    if type(formatted) ~= "string" or formatted == "" then
        return nil
    end

    return formatted
end

function DISCONTENT:IsImportantNews(entry)
    if type(entry) ~= "table" then
        return false
    end

    if entry.pinned or entry.important or entry.isImportant or entry.isPinned then
        return true
    end

    local priority = string.lower(tostring(entry.priority or entry.kind or entry.type or ""))
    return priority == "high" or priority == "important" or priority == "pinned"
end

function DISCONTENT:GetNewsHeaderText(entry)
    if self:IsImportantNews(entry) then
        return "Wichtige News"
    end
    return "DISCONTENT News"
end

function DISCONTENT:GetNewsTitleText(entry)
    if type(entry) ~= "table" then
        return self:GetNewsHeaderText(entry)
    end

    local title = entry.title or entry.headline or entry.subject or entry.name or entry.header or entry.newsTitle or ""
    title = tostring(title or "")
    title = title:gsub("\r\n", " ")
    title = title:gsub("\n", " ")
    title = title:gsub("%s+", " ")
    title = strtrim(title)

    if title ~= "" then
        return title
    end

    return self:GetNewsHeaderText(entry)
end

function DISCONTENT:GetNewsAuthorText(entry)
    if type(entry) ~= "table" then
        return "Unbekannt"
    end
    return self:SafeText(entry.author or entry.creator or entry.officer or entry.createdBy or entry.owner or "Unbekannt")
end

function DISCONTENT:GetNewsMessageText(entry)
    if type(entry) ~= "table" then
        return "Keine Nachricht vorhanden."
    end

    local message = entry.message or entry.text or entry.newsText or entry.body or entry.content or entry.description or "Keine Nachricht vorhanden."
    message = tostring(message or "")
    message = message:gsub("\r\n", "\n")
    message = message:gsub("\r", "\n")

    if message == "" then
        return "Keine Nachricht vorhanden."
    end

    return message
end

function DISCONTENT:GetNewsMetaText(entry)
    local author = self:GetNewsAuthorText(entry)
    local directDate = self:SafeText((type(entry) == "table" and (entry.dateText or entry.whenText or entry.newsDate)) or "")

    if directDate ~= "" and directDate ~= "-" then
        return author .. "  •  " .. directDate
    end

    local timestampValue = self:GetNewsTimestampValue(entry)
    local timestampText = self:FormatNewsTimestamp(timestampValue)

    if timestampText and timestampText ~= "" then
        return author .. "  •  " .. timestampText
    end

    return author
end

function DISCONTENT:CreateWelcomeNewsCard(parent)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    card:SetBackdropColor(0.07, 0.08, 0.11, 0.94)
    card:SetBackdropBorderColor(0.45, 0.52, 0.62, 0.95)
    card:EnableMouse(true)

    card.accent = card:CreateTexture(nil, "ARTWORK")
    card.accent:SetPoint("TOPLEFT", 1, -1)
    card.accent:SetPoint("TOPRIGHT", -1, -1)
    card.accent:SetHeight(2)
    card.accent:SetColorTexture(0.93, 0.77, 0.17, 0.95)

    card.hoverGlow = card:CreateTexture(nil, "HIGHLIGHT")
    card.hoverGlow:SetAllPoints()
    card.hoverGlow:SetColorTexture(1, 1, 1, 0.04)

    card.badge = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    card.badge:SetPoint("TOPRIGHT", card, "TOPRIGHT", -10, -8)
    card.badge:SetJustifyH("RIGHT")
    card.badge:SetText("WICHTIG")
    card.badge:SetTextColor(1, 0.82, 0.22, 1)
    card.badge:Hide()

    card.header = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    card.header:SetPoint("TOPLEFT", 10, -8)
    card.header:SetPoint("TOPRIGHT", card.badge, "TOPLEFT", -8, 0)
    card.header:SetJustifyH("LEFT")
    card.header:SetJustifyV("TOP")
    card.header:SetWordWrap(true)
    card.header:SetTextColor(1, 0.84, 0.15, 1)

    card.meta = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.meta:SetPoint("TOPLEFT", card.header, "BOTTOMLEFT", 0, -4)
    card.meta:SetPoint("TOPRIGHT", card, "TOPRIGHT", -10, -24)
    card.meta:SetJustifyH("LEFT")
    card.meta:SetJustifyV("TOP")
    card.meta:SetWordWrap(true)
    card.meta:SetTextColor(0.72, 0.76, 0.82, 1)

    card.message = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.message:SetPoint("TOPLEFT", card.meta, "BOTTOMLEFT", 0, -8)
    card.message:SetPoint("TOPRIGHT", card, "TOPRIGHT", -10, -8)
    card.message:SetJustifyH("LEFT")
    card.message:SetJustifyV("TOP")
    card.message:SetWordWrap(true)
    card.message:SetSpacing(1)
    card.message:SetTextColor(0.95, 0.95, 0.95, 1)

    card:SetScript("OnEnter", function(frame)
        if DISCONTENT and DISCONTENT.ApplyWelcomeNewsCardStyle then
            DISCONTENT:ApplyWelcomeNewsCardStyle(frame, frame.entry, true)
        end
    end)

    card:SetScript("OnLeave", function(frame)
        if DISCONTENT and DISCONTENT.ApplyWelcomeNewsCardStyle then
            DISCONTENT:ApplyWelcomeNewsCardStyle(frame, frame.entry, false)
        end
    end)

    return card
end

function DISCONTENT:ApplyWelcomeNewsCardStyle(card, entry, isHovered)
    if not card then
        return
    end

    local important = self:IsImportantNews(entry)

    if important then
        if isHovered then
            card:SetBackdropColor(0.17, 0.11, 0.05, 0.96)
            card:SetBackdropBorderColor(0.98, 0.80, 0.24, 1)
        else
            card:SetBackdropColor(0.12, 0.08, 0.05, 0.95)
            card:SetBackdropBorderColor(0.88, 0.70, 0.18, 0.98)
        end
        card.accent:SetColorTexture(1.00, 0.78, 0.18, 0.98)
        card.header:SetTextColor(1.00, 0.87, 0.30, 1)
        card.badge:Show()
    else
        if isHovered then
            card:SetBackdropColor(0.10, 0.11, 0.16, 0.96)
            card:SetBackdropBorderColor(0.55, 0.66, 0.82, 1)
        else
            card:SetBackdropColor(0.07, 0.08, 0.11, 0.94)
            card:SetBackdropBorderColor(0.45, 0.52, 0.62, 0.95)
        end
        card.accent:SetColorTexture(0.38, 0.62, 0.98, 0.95)
        card.header:SetTextColor(0.86, 0.92, 1.00, 1)
        card.badge:Hide()
    end
end

function DISCONTENT:RefreshWelcomeNewsView()
    if not self.welcomeFrame or not self.welcomeFrame.scrollChild then
        return
    end

    local entries = self:GetSortedNewsEntries()
    local unreadEntries = self.GetUnreadNewsEntries and self:GetUnreadNewsEntries() or {}
    local unreadCount = unreadEntries and #unreadEntries or 0

    if self.welcomeFrame.subtitle then
        if unreadCount > 0 then
            self.welcomeFrame.subtitle:SetText("Es gibt " .. tostring(unreadCount) .. " neue News, die du noch nicht gesehen hast.")
        else
            self.welcomeFrame.subtitle:SetText("")
        end
    end

    if self.welcomeFrame.sectionTitle then
        if unreadCount > 0 then
            self.welcomeFrame.sectionTitle:SetText("Aktuelle News • Neu: " .. tostring(unreadCount))
        else
            self.welcomeFrame.sectionTitle:SetText("Aktuelle News")
        end
    end
    local child = self.welcomeFrame.scrollChild
    local panelWidth = math.max(100, self.welcomeFrame.newsPanel:GetWidth() - 34)
    local cardWidth = panelWidth - 8
    local spacing = 6
    local cards = self.welcomeFrame.newsCards or {}

    self.welcomeFrame.newsCards = cards

    if self.welcomeFrame.emptyState then
        self.welcomeFrame.emptyState:Hide()
    end

    if not entries or #entries == 0 then
        for i = 1, #cards do
            cards[i].entry = nil
            cards[i]:Hide()
        end

        if self.welcomeFrame.emptyState then
            self.welcomeFrame.emptyState:Show()
        end

        child:SetSize(cardWidth, math.max(self.welcomeFrame.scrollFrame:GetHeight(), 120))
        return
    end

    local totalHeight = 8

    for i = 1, #entries do
        local card = cards[i]
        if not card then
            card = self:CreateWelcomeNewsCard(child)
            cards[i] = card
        end

        local entry = entries[i]
        local messageText = self:GetNewsMessageText(entry)
        local metaText = self:GetNewsMetaText(entry)

        card.entry = entry
        card:ClearAllPoints()
        if i == 1 then
            card:SetPoint("TOPLEFT", child, "TOPLEFT", 4, -4)
        else
            card:SetPoint("TOPLEFT", cards[i - 1], "BOTTOMLEFT", 0, -spacing)
        end

        card:SetWidth(cardWidth)
        card.header:SetWidth(cardWidth - 96)
        card.meta:SetWidth(cardWidth - 20)
        card.message:SetWidth(cardWidth - 20)

        card.header:SetText(self:GetNewsTitleText(entry))
        card.meta:SetText(metaText ~= "" and metaText or " ")
        card.message:SetText(messageText)

        self:ApplyWelcomeNewsCardStyle(card, entry, false)

        local headerHeight = math.max(14, card.header:GetStringHeight() or 14)
        local metaHeight = math.max(10, card.meta:GetStringHeight() or 10)
        local messageHeight = math.max(16, card.message:GetStringHeight() or 16)
        local cardHeight = math.max(72, 12 + headerHeight + 4 + metaHeight + 6 + messageHeight + 12)

        card:SetHeight(cardHeight)
        card:Show()

        totalHeight = totalHeight + cardHeight + spacing
    end

    for i = #entries + 1, #cards do
        cards[i].entry = nil
        cards[i]:Hide()
    end

    child:SetSize(cardWidth, math.max(totalHeight, self.welcomeFrame.scrollFrame:GetHeight()))
end

function DISCONTENT:ShowMainWindow()
    if not self.uiCreated then
        self:CreateUI()
    end

    if self.welcomeFrame then
        self.welcomeFrame:Hide()
    end

    self:Show()
    self:SetActiveTab(self.activeTab or "guildnews")

    if IsInGuild() then
        C_GuildInfo.GuildRoster()
    end
end

function DISCONTENT:CreateWelcomeUI()
    if self.welcomeFrame then
        return
    end

    local frame = CreateFrame("Frame", "DISCONTENTWelcomeFrame", UIParent, "BackdropTemplate")
    self.welcomeFrame = frame

    frame:SetSize(self.defaultWelcomeWidth, self.defaultWelcomeHeight)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(math.max((self.GetFrameLevel and self:GetFrameLevel() or 1) + 200, 500))
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScale(self.uiScaleValue)
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(welcomeFrame)
        welcomeFrame:StopMovingOrSizing()
        DISCONTENT:SaveFramePosition(welcomeFrame, "welcomeWindowPosition")
    end)
    frame:SetScript("OnShow", function()
        DISCONTENT:RefreshWelcomeNewsView()
    end)

    self:RestoreFramePosition(frame, "welcomeWindowPosition", "CENTER", "CENTER", 0, 60)

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(0.02, 0.03, 0.05, 0.96)

    frame.topAccent = frame:CreateTexture(nil, "ARTWORK")
    frame.topAccent:SetPoint("TOPLEFT", 1, -1)
    frame.topAccent:SetPoint("TOPRIGHT", -1, -1)
    frame.topAccent:SetHeight(2)
    frame.topAccent:SetColorTexture(0.93, 0.77, 0.17, 0.95)

    frame.innerGlow = frame:CreateTexture(nil, "BORDER")
    frame.innerGlow:SetPoint("TOPLEFT", 12, -12)
    frame.innerGlow:SetPoint("TOPRIGHT", -12, -12)
    frame.innerGlow:SetHeight(46)
    frame.innerGlow:SetColorTexture(0.15, 0.18, 0.24, 0.45)

    frame.border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.border:SetAllPoints()
    frame.border:SetBackdrop({
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 14,
    })
    frame.border:SetBackdropBorderColor(0.75, 0.75, 0.82, 1)

    frame.closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.closeButton:SetPoint("TOPRIGHT", -4, -4)

    frame.versionText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.versionText:SetPoint("RIGHT", frame.closeButton, "LEFT", -6, 1)
    frame.versionText:SetText(self:GetVersionLabel())
    frame.versionText:SetTextColor(0.75, 0.75, 0.75, 1)

    frame.welcomeLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.welcomeLabel:SetPoint("TOPLEFT", 14, -12)
    frame.welcomeLabel:SetJustifyH("LEFT")
    frame.welcomeLabel:SetText("Willkommen bei DISCONTENT")

    frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.subtitle:SetPoint("TOPLEFT", frame.welcomeLabel, "BOTTOMLEFT", 0, -5)
    frame.subtitle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -18)
    frame.subtitle:SetJustifyH("LEFT")
    frame.subtitle:SetText("")

    frame.newsPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.newsPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -58)
    frame.newsPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 42)
    frame.newsPanel:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    frame.newsPanel:SetBackdropColor(0.04, 0.05, 0.07, 0.92)
    frame.newsPanel:SetBackdropBorderColor(0.35, 0.39, 0.46, 0.95)

    frame.sectionTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.sectionTitle:SetPoint("BOTTOMLEFT", frame.newsPanel, "TOPLEFT", 2, 5)
    frame.sectionTitle:SetText("Aktuelle News")

    frame.scrollFrame = CreateFrame("ScrollFrame", "DISCONTENTWelcomeScrollFrame", frame.newsPanel, "UIPanelScrollFrameTemplate")
    frame.scrollFrame:SetPoint("TOPLEFT", frame.newsPanel, "TOPLEFT", 6, -6)
    frame.scrollFrame:SetPoint("BOTTOMRIGHT", frame.newsPanel, "BOTTOMRIGHT", -24, 6)

    frame.scrollChild = CreateFrame("Frame", nil, frame.scrollFrame)
    frame.scrollChild:SetSize(1, 1)
    frame.scrollFrame:SetScrollChild(frame.scrollChild)

    frame.emptyState = frame.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.emptyState:SetPoint("TOPLEFT", frame.scrollChild, "TOPLEFT", 12, -14)
    frame.emptyState:SetPoint("TOPRIGHT", frame.scrollChild, "TOPRIGHT", -12, -14)
    frame.emptyState:SetJustifyH("LEFT")
    frame.emptyState:SetJustifyV("TOP")
    frame.emptyState:SetText("Noch keine News vorhanden. Sobald Einträge erstellt wurden, erscheinen sie hier automatisch.")

    frame.openButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.openButton:SetSize(132, 24)
    frame.openButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, 10)
    frame.openButton:SetText("Addon öffnen")
    frame.openButton:SetScript("OnClick", function()
        DISCONTENT:ShowMainWindow()
    end)

    frame.newsCards = {}


    frame:Hide()
end

function DISCONTENT:ShowWelcomeWindow()
    if not self.welcomeFrame then
        self:CreateWelcomeUI()
    end

    self:Hide()

    if self.welcomeFrame then
        self.welcomeFrame:SetParent(UIParent)
        self.welcomeFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        self.welcomeFrame:SetFrameLevel(math.max((self.GetFrameLevel and self:GetFrameLevel() or 1) + 200, 500))
        self.welcomeFrame:SetScale(self.uiScaleValue)
        self:RestoreFramePosition(self.welcomeFrame, "welcomeWindowPosition", "CENTER", "CENTER", 0, 60)
        self:RefreshWelcomeNewsView()
        self.welcomeFrame:Show()
        self.welcomeFrame:Raise()
        self:Hide()

        if self.MarkVisibleNewsAsSeen then
            self:MarkVisibleNewsAsSeen()
        end
    end
end

function DISCONTENT:ResetWindow()
    self:ClearAllPoints()
    self:SetPoint("CENTER")
    self:SetSize(self.defaultWidth, self.defaultHeight)

    if self.db then
        self.db.welcomeWindowPosition = nil
        self.db.showMinimapButton = self.defaultShowMinimapButton
        self.db.minimapButtonAngle = self.defaultMinimapAngle
        self.db.minimap = {
            hide = not self.defaultShowMinimapButton,
            minimapPos = self.defaultMinimapAngle,
        }
    end

    self.uiScaleValue = self.defaultScale
    self.pendingScaleValue = self.defaultScale
    self.backgroundAlpha = self.defaultBackgroundAlpha
    self.pendingBackgroundAlpha = self.defaultBackgroundAlpha

    self:SetScale(self.uiScaleValue)

    if self.bg then
        self.bg:SetColorTexture(0, 0, 0, self.backgroundAlpha)
    end

    if self.welcomeFrame then
        self.welcomeFrame:SetScale(self.uiScaleValue)
        self:RestoreFramePosition(self.welcomeFrame, "welcomeWindowPosition", "CENTER", "CENTER", 0, 60)
    end

    if self.minimapDataObject or self.libDBIcon or self.minimapButton then
        self:UpdateMinimapButtonPosition()
        self:RefreshMinimapButtonVisibility()
    end

    if self.scaleSlider then
        self.scaleSlider:SetValue(self.uiScaleValue)
        if self.scaleSlider.Text then
            self.scaleSlider.Text:SetText("Scale 100%")
        end
    end

    if self.backgroundSlider then
        self.backgroundSlider:SetValue(self.backgroundAlpha)
        if self.backgroundSlider.Text then
            self.backgroundSlider.Text:SetText("Hintergrund 88%")
        end
    end

    self:SaveSettings()

    if self.uiCreated then
        self.visibleRows = self:GetDynamicVisibleRows()
        self:ApplyFilterAndSort()
        self:UpdateLayout()
        self:UpdateRows()

        if self.RefreshGuildChatView then
            self:RefreshGuildChatView()
        end

        if self.RefreshNewsView then
            self:RefreshNewsView()
        end

        if self.UpdateProfessionRows then
            self:UpdateProfessionRows()
        end

        if self.RefreshRaidPrepUI then
            self:RefreshRaidPrepUI()
        end

        if self.RefreshNotesUI then
            self:RefreshNotesUI()
        end

        if self.RefreshOfficerUI then
            self:RefreshOfficerUI()
        end

        if self.RefreshMythicPlusUI then
            self:RefreshMythicPlusUI()
        end
    end
end

function DISCONTENT:GetDynamicVisibleRows()
    local frameHeight = self:GetHeight() or self.defaultHeight
    local topArea = 190
    local bottomArea = 52
    local usableHeight = frameHeight - topArea - bottomArea
    local rows = math.floor(usableHeight / self.rowHeight)
    return math.max(self.minVisibleRows, rows)
end

function DISCONTENT:GetLayout()
    local frameWidth = self:GetWidth() or self.defaultWidth

    local leftMargin = 16
    local rightMargin = 46
    local usableWidth = frameWidth - leftMargin - rightMargin

    local levelWidth = 45
    local classWidth = 95
    local ilvlWidth = 55
    local statusWidth = 70
    local iconAreaWidth = 44
    local addonStatusWidth = 16

    local nameWidth = math.max(120, math.floor(usableWidth * 0.16))
    local serverWidth = math.max(130, math.floor(usableWidth * 0.16))
    local rankWidth = math.max(120, math.floor(usableWidth * 0.15))

    local zoneWidth = math.max(
        110,
        usableWidth
            - addonStatusWidth
            - nameWidth
            - iconAreaWidth
            - serverWidth
            - rankWidth
            - levelWidth
            - classWidth
            - ilvlWidth
            - statusWidth
            - 72
    )

    local addonStatusX = 4
    local nameX = addonStatusX + addonStatusWidth + 4
    local icon1X = nameX + nameWidth + 4
    local icon2X = icon1X + 20
    local serverX = icon2X + 22
    local rankX = serverX + serverWidth + 10
    local levelX = rankX + rankWidth + 10
    local classX = levelX + levelWidth + 10
    local ilvlX = classX + classWidth + 10
    local zoneX = ilvlX + ilvlWidth + 10
    local statusX = zoneX + zoneWidth + 10

    return {
        leftMargin = leftMargin,
        rightMargin = rightMargin,
        usableWidth = usableWidth,
        rowWidth = usableWidth,

        addonStatusWidth = addonStatusWidth,
        nameWidth = nameWidth,
        iconAreaWidth = iconAreaWidth,
        serverWidth = serverWidth,
        rankWidth = rankWidth,
        levelWidth = levelWidth,
        classWidth = classWidth,
        ilvlWidth = ilvlWidth,
        zoneWidth = zoneWidth,
        statusWidth = statusWidth,

        addonStatusX = addonStatusX,
        nameX = nameX,
        icon1X = icon1X,
        icon2X = icon2X,
        serverX = serverX,
        rankX = rankX,
        levelX = levelX,
        classX = classX,
        ilvlX = ilvlX,
        zoneX = zoneX,
        statusX = statusX,
    }
end

function DISCONTENT:GetSortValue(member, column)
    if column == "name" then
        return self:NormalizeText(member.name)
    elseif column == "server" then
        return self:NormalizeText(member.realm)
    elseif column == "rank" then
        return member.rankIndex or 999
    elseif column == "level" then
        return tonumber(member.level) or 0
    elseif column == "class" then
        return self:NormalizeText(member.className)
    elseif column == "ilvl" then
        if self.GetMemberAverageItemLevel then
            return tonumber(self:GetMemberAverageItemLevel(member)) or 0
        end
        return 0
    elseif column == "zone" then
        return self:NormalizeText(member.zone)
    elseif column == "status" then
        return member.isOnline and 1 or 0
    end

    return self:NormalizeText(member.name)
end

function DISCONTENT:SetSortColumn(column)
    if self.sortColumn == column then
        self.sortAscending = not self.sortAscending
    else
        self.sortColumn = column
        self.sortAscending = true
    end

    self:ApplyFilterAndSort()
    self:UpdateHeaderIndicators()
    self:UpdateRows()
end

function DISCONTENT:UpdateHeaderIndicators()
    if not self.headerButtons then return end

    for _, header in ipairs(self.headerButtons) do
        if header.arrowText then
            if header.sortKey == self.sortColumn then
                if self.sortAscending then
                    header.arrowText:SetText("▲")
                else
                    header.arrowText:SetText("▼")
                end
                header.arrowText:SetTextColor(1, 0.82, 0, 1)
            else
                header.arrowText:SetText("-")
                header.arrowText:SetTextColor(0.55, 0.55, 0.55, 1)
            end
        end
    end
end

function DISCONTENT:CollectGuildMembers()
    self:ClearTable(self.members)

    if not IsInGuild() then
        return
    end

    local totalMembers = GetNumGuildMembers()
    if not totalMembers or totalMembers == 0 then
        return
    end

    for i = 1, totalMembers do
        local name, rankName, rankIndex, level, classDisplayName, zone, publicNote, officerNote, isOnline, status, classFileName =
            GetGuildRosterInfo(i)

        if name then
            table.insert(self.members, {
                rosterIndex = i,
                fullName = name,
                name = self:SafeName(name),
                realm = self:SafeRealm(name),
                rankName = rankName or "Unbekannt",
                rankIndex = rankIndex or 999,
                level = level or 0,
                className = classDisplayName or "",
                classFileName = classFileName or "",
                zone = zone or "-",
                publicNote = publicNote or "",
                officerNote = officerNote or "",
                isOnline = isOnline and true or false,
            })
        end
    end
end

function DISCONTENT:GetUniqueRanks()
    local ranks = {}
    local seen = {}

    for _, member in ipairs(self.members) do
        if member.rankName and not seen[member.rankName] then
            seen[member.rankName] = true
            table.insert(ranks, {
                name = member.rankName,
                index = member.rankIndex or 999
            })
        end
    end

    table.sort(ranks, function(a, b)
        if a.index == b.index then
            return a.name < b.name
        end
        return a.index < b.index
    end)

    return ranks
end

function DISCONTENT:PassesSearch(member)
    if not self.searchText or self.searchText == "" then
        return true
    end

    local memberName = self:NormalizeText(member.name)
    local search = self:NormalizeText(self.searchText)

    return string.find(memberName, search, 1, true) ~= nil
end

function DISCONTENT:ApplyFilterAndSort()
    self:ClearTable(self.filteredMembers)

    for _, member in ipairs(self.members) do
        local rankOk = (self.rankFilter == "ALLE" or member.rankName == self.rankFilter)
        local searchOk = self:PassesSearch(member)
        local onlineOk = (not self.onlineOnly) or member.isOnline

        if rankOk and searchOk and onlineOk then
            table.insert(self.filteredMembers, member)
        end
    end

    table.sort(self.filteredMembers, function(a, b)
        local av = self:GetSortValue(a, self.sortColumn)
        local bv = self:GetSortValue(b, self.sortColumn)

        if av == bv then
            local an = DISCONTENT:NormalizeText(a.name)
            local bn = DISCONTENT:NormalizeText(b.name)

            if an == bn then
                return (a.rankIndex or 999) < (b.rankIndex or 999)
            end

            return an < bn
        end

        if self.sortAscending then
            return av < bv
        else
            return av > bv
        end
    end)

    if self.scrollOffset < 0 then
        self.scrollOffset = 0
    end

    local maxOffset = math.max(0, #self.filteredMembers - self.visibleRows)
    if self.scrollOffset > maxOffset then
        self.scrollOffset = maxOffset
    end
end

function DISCONTENT:GetClassColor(classFileName)
    if classFileName and self.CLASS_COLORS and self.CLASS_COLORS[classFileName] then
        local c = self.CLASS_COLORS[classFileName]
        return c.r, c.g, c.b
    end
    return 1, 1, 1
end

function DISCONTENT:GetOnlineCount()
    local online = 0
    for _, member in ipairs(self.members) do
        if member.isOnline then
            online = online + 1
        end
    end
    return online
end

function DISCONTENT:GetTotalMemberCount()
    return #self.members
end

function DISCONTENT:ShowNotePopup(member)
    if not member or not self.notePopup then return end

    self.notePopup.nameText:SetText(member.name or "-")
    self.notePopup.rankText:SetText("Rang: " .. self:SafeText(member.rankName))
    self.notePopup.publicNoteText:SetText(self:SafeText(member.publicNote))

    if member.officerNote and member.officerNote ~= "" then
        self.notePopup.officerNoteLabel:Show()
        self.notePopup.officerNoteText:Show()
        self.notePopup.officerNoteText:SetText(member.officerNote)
    else
        self.notePopup.officerNoteLabel:Hide()
        self.notePopup.officerNoteText:Hide()
    end

    self.notePopup:Show()
end

function DISCONTENT:InviteMember(member)
    if not member then return end
    local target = member.fullName or member.name
    if not target or target == "" then return end

    if C_PartyInfo and C_PartyInfo.InviteUnit then
        C_PartyInfo.InviteUnit(target)
    else
        InviteUnit(target)
    end
end

function DISCONTENT:WhisperMember(member)
    if not member then return end
    local target = member.fullName or member.name
    if not target or target == "" then return end
    ChatFrame_SendTell(target)
end

function DISCONTENT:AddGuildChatMessage(author, message, channelTag)
    local cleanAuthor = self:SafeName(author or "?")
    local timeString = date("%H:%M")
    local prefix = channelTag or "G"

    table.insert(self.guildChatMessages, {
        time = timeString,
        author = cleanAuthor,
        message = message or "",
        prefix = prefix,
    })

    self:TrimChatHistory(self.guildChatMessages, self.maxChatMessages)

    if self.RefreshGuildChatView then
        self:RefreshGuildChatView()
    end
end

function DISCONTENT:RefreshGuildChatView()
    if not self.uiCreated then
        return
    end

    if self.chatMessageFrame and self.chatMessageFrame.AddMessage and self.BuildStyledChatLine then
        local wasNearBottom = true
        local currentOffset = self.chatMessageFrame:GetScrollOffset() or 0
        if currentOffset > 4 then
            wasNearBottom = false
        end

        if self.chatMessageFrame.Clear then
            self.chatMessageFrame:Clear()
        end

        for i = 1, #self.guildChatMessages do
            local entry = self.guildChatMessages[i]
            local showEntry = true
            if self.MessageMatchesActiveChatChannel then
                showEntry = self:MessageMatchesActiveChatChannel(entry)
            end

            if showEntry then
                self.chatMessageFrame:AddMessage(self:BuildStyledChatLine(entry))
            end
        end

        if wasNearBottom and self.chatMessageFrame.ScrollToBottom then
            self.chatMessageFrame:ScrollToBottom()
        end

        if self.UpdateGuildChatScrollBar then
            self:UpdateGuildChatScrollBar()
        end
        return
    end

    if not self.chatScrollChild or not self.chatMessageText or not self.chatScrollFrame then
        return
    end

    local lines = {}

    for i = 1, #self.guildChatMessages do
        local entry = self.guildChatMessages[i]
        lines[#lines + 1] = string.format("|cff888888[%s]|r |cffffd100[%s]|r |cff99ccff%s|r: %s",
            entry.time or "--:--",
            entry.prefix or "G",
            entry.author or "?",
            entry.message or ""
        )
    end

    self.chatMessageText:SetText(table.concat(lines, "\n"))

    local availableWidth = math.max(100, self.chatScrollFrame:GetWidth() - 30)
    self.chatMessageText:SetWidth(availableWidth)

    local textHeight = self.chatMessageText:GetStringHeight() or 0
    self.chatScrollChild:SetSize(availableWidth, math.max(textHeight + 12, self.chatScrollFrame:GetHeight()))

    C_Timer.After(0, function()
        if DISCONTENT.chatScrollFrame and DISCONTENT.chatScrollFrame.ScrollBar then
            local sb = DISCONTENT.chatScrollFrame.ScrollBar
            local _, maxVal = sb:GetMinMaxValues()
            sb:SetValue(maxVal)
        end
    end)
end

function DISCONTENT:SendGuildChatMessage()
    if not self.chatInputBox then return end

    local text = self.chatInputBox:GetText()
    if not text or text == "" then
        return
    end

    if self.GetCurrentSendChatType then
        SendChatMessage(text, self:GetCurrentSendChatType())
    else
        SendChatMessage(text, "GUILD")
    end

    self.chatInputBox:SetText("")
end

function DISCONTENT:CreateTabButton(parent, text, point, relativeTo, relativePoint, x, y, tabKey)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(120, 24)
    btn:SetPoint(point, relativeTo, relativePoint, x, y)
    btn:SetText(text)
    btn.tabKey = tabKey
    btn:SetScript("OnClick", function()
        DISCONTENT:SetActiveTab(tabKey)
    end)
    return btn
end

function DISCONTENT:RelayoutTopTabs()
    if not self.uiCreated then
        return
    end

    local buttons = {
        self.guildNewsTabButton,
        self.overviewTabButton,
        self.guildChatTabButton,
        self.professionsTabButton,
        self.raidPrepTabButton,
        self.mythicPlusTabButton,
        self.notesTabButton,
    }

    if self.officerTabButton and self.officerTabButton:IsShown() then
        buttons[#buttons + 1] = self.officerTabButton
    end

    buttons[#buttons + 1] = self.settingsTabButton

    local previous = nil
    for i = 1, #buttons do
        local btn = buttons[i]
        btn:ClearAllPoints()
        if not previous then
            btn:SetPoint("TOPLEFT", self, "TOPLEFT", 16, -42)
        else
            btn:SetPoint("LEFT", previous, "RIGHT", 8, 0)
        end
        previous = btn
    end
end

function DISCONTENT:SetOfficerTabVisibility()
    if not self.officerTabButton then
        return
    end

    if self:CanSeeOfficerTab() then
        self.officerTabButton:Show()
    else
        self.officerTabButton:Hide()
        if self.activeTab == "officer" then
            self.activeTab = "guildnews"
        end
    end

    self:RelayoutTopTabs()
end

function DISCONTENT:SetActiveTab(tabKey)
    if tabKey == "officer" and not self:CanSeeOfficerTab() then
        tabKey = "guildnews"
    end

    self.activeTab = tabKey

    if self.guildNewsTabContent then self.guildNewsTabContent:Hide() end
    if self.overviewTabContent then self.overviewTabContent:Hide() end
    if self.guildChatTabContent then self.guildChatTabContent:Hide() end
    if self.professionsTabContent then self.professionsTabContent:Hide() end
    if self.raidPrepTabContent then self.raidPrepTabContent:Hide() end
    if self.mythicPlusTabContent then self.mythicPlusTabContent:Hide() end
    if self.notesTabContent then self.notesTabContent:Hide() end
    if self.officerTabContent then self.officerTabContent:Hide() end
    if self.settingsTabContent then self.settingsTabContent:Hide() end

    if tabKey == "guildnews" then
        self.guildNewsTabContent:Show()
        if self.scrollBar then self.scrollBar:Hide() end
        if self.RefreshNewsView then self:RefreshNewsView() end
    elseif tabKey == "overview" then
        self.overviewTabContent:Show()
        if self.scrollBar then self.scrollBar:Show() end
    elseif tabKey == "guildchat" then
        self.guildChatTabContent:Show()
        if self.scrollBar then self.scrollBar:Hide() end
        self:RefreshGuildChatView()
        if self.chatInputBox then self.chatInputBox:ClearFocus() end
    elseif tabKey == "professions" then
        self.professionsTabContent:Show()
        if self.scrollBar then self.scrollBar:Hide() end
        if self.UpdateProfessionRows then self:UpdateProfessionRows() end
    elseif tabKey == "raidprep" then
        self.raidPrepTabContent:Show()
        if self.scrollBar then self.scrollBar:Hide() end
        if self.RefreshRaidPrepUI then self:RefreshRaidPrepUI() end
    elseif tabKey == "mythicplus" then
        self.mythicPlusTabContent:Show()
        if self.scrollBar then self.scrollBar:Hide() end
        if self.RefreshMythicPlusUI then self:RefreshMythicPlusUI() end
    elseif tabKey == "notes" then
        self.notesTabContent:Show()
        if self.scrollBar then self.scrollBar:Hide() end
        if self.RefreshNotesUI then self:RefreshNotesUI() end
    elseif tabKey == "officer" then
        self.officerTabContent:Show()
        if self.scrollBar then self.scrollBar:Hide() end
        if self.RequestRaidPrepSync then
            self:RequestRaidPrepSync()
        end
        if self.RefreshOfficerUI then self:RefreshOfficerUI() end
    elseif tabKey == "settings" then
        self.settingsTabContent:Show()
        if self.scrollBar then self.scrollBar:Hide() end
    end

    if self.guildNewsTabButton then self.guildNewsTabButton:SetEnabled(tabKey ~= "guildnews") end
    if self.overviewTabButton then self.overviewTabButton:SetEnabled(tabKey ~= "overview") end
    if self.guildChatTabButton then self.guildChatTabButton:SetEnabled(tabKey ~= "guildchat") end
    if self.professionsTabButton then self.professionsTabButton:SetEnabled(tabKey ~= "professions") end
    if self.raidPrepTabButton then self.raidPrepTabButton:SetEnabled(tabKey ~= "raidprep") end
    if self.mythicPlusTabButton then self.mythicPlusTabButton:SetEnabled(tabKey ~= "mythicplus") end
    if self.notesTabButton then self.notesTabButton:SetEnabled(tabKey ~= "notes") end
    if self.officerTabButton and self.officerTabButton:IsShown() then
        self.officerTabButton:SetEnabled(tabKey ~= "officer")
    end
    if self.settingsTabButton then self.settingsTabButton:SetEnabled(tabKey ~= "settings") end

    self:UpdateLayout()
    self:UpdateRows()
end

function DISCONTENT:CreateNotePopup()
    local popup = CreateFrame("Frame", "DISCONTENTNotePopup", UIParent, "BackdropTemplate")
    popup:SetSize(420, 250)
    popup:SetPoint("CENTER")
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetToplevel(true)
    popup:SetMovable(true)
    popup:EnableMouse(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", popup.StartMoving)
    popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
    popup:Hide()

    popup.bg = popup:CreateTexture(nil, "BACKGROUND")
    popup.bg:SetAllPoints()
    popup.bg:SetColorTexture(0.05, 0.05, 0.05, 0.95)

    popup.border = CreateFrame("Frame", nil, popup, "BackdropTemplate")
    popup.border:SetAllPoints()
    popup.border:SetBackdrop({
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 14,
    })
    popup.border:SetBackdropBorderColor(0.8, 0.8, 0.8, 1)

    popup.title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    popup.title:SetPoint("TOP", 0, -12)
    popup.title:SetText("Gildennotiz")

    popup.closeButton = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
    popup.closeButton:SetPoint("TOPRIGHT", -4, -4)

    popup.nameText = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    popup.nameText:SetPoint("TOPLEFT", 18, -40)
    popup.nameText:SetJustifyH("LEFT")
    popup.nameText:SetText("-")

    popup.rankText = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    popup.rankText:SetPoint("TOPLEFT", 18, -64)
    popup.rankText:SetWidth(380)
    popup.rankText:SetJustifyH("LEFT")
    popup.rankText:SetText("Rang: -")

    popup.publicNoteLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    popup.publicNoteLabel:SetPoint("TOPLEFT", 18, -92)
    popup.publicNoteLabel:SetText("Public Note:")

    popup.publicNoteText = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    popup.publicNoteText:SetPoint("TOPLEFT", popup.publicNoteLabel, "BOTTOMLEFT", 0, -6)
    popup.publicNoteText:SetWidth(380)
    popup.publicNoteText:SetJustifyH("LEFT")
    popup.publicNoteText:SetJustifyV("TOP")
    popup.publicNoteText:SetText("-")

    popup.officerNoteLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    popup.officerNoteLabel:SetPoint("TOPLEFT", popup.publicNoteText, "BOTTOMLEFT", 0, -14)
    popup.officerNoteLabel:SetText("Officer Note:")

    popup.officerNoteText = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    popup.officerNoteText:SetPoint("TOPLEFT", popup.officerNoteLabel, "BOTTOMLEFT", 0, -6)
    popup.officerNoteText:SetWidth(380)
    popup.officerNoteText:SetJustifyH("LEFT")
    popup.officerNoteText:SetJustifyV("TOP")
    popup.officerNoteText:SetText("-")

    self.notePopup = popup
end

function DISCONTENT:ApplyPendingScale()
    local newScale = self.pendingScaleValue or self.defaultScale

    self.uiScaleValue = newScale
    self:SetScale(newScale)

    if self.scaleSlider and self.scaleSlider.Text then
        self.scaleSlider.Text:SetText("Scale " .. tostring(math.floor(newScale * 100 + 0.5)) .. "%")
    end

    self:SaveSettings()
end

function DISCONTENT:ApplyPendingBackgroundAlpha()
    local newAlpha = self.pendingBackgroundAlpha or self.defaultBackgroundAlpha

    self.backgroundAlpha = newAlpha

    if self.bg then
        self.bg:SetColorTexture(0, 0, 0, newAlpha)
    end

    if self.backgroundSlider and self.backgroundSlider.Text then
        self.backgroundSlider.Text:SetText("Hintergrund " .. tostring(math.floor(newAlpha * 100 + 0.5)) .. "%")
    end

    self:SaveSettings()
end

function DISCONTENT:CreateScaleSlider(parent)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetMinMaxValues(0.70, 1.50)
    slider:SetValueStep(0.05)
    slider:SetObeyStepOnDrag(true)
    slider:SetWidth(220)
    slider:SetHeight(16)
    slider:SetValue(self.uiScaleValue)
    slider.Low:SetText("70%")
    slider.High:SetText("150%")
    slider.Text:SetText("Scale " .. tostring(math.floor(self.uiScaleValue * 100 + 0.5)) .. "%")

    slider:SetScript("OnValueChanged", function(_, value)
        local rounded = math.floor((value * 100) + 0.5) / 100
        DISCONTENT.pendingScaleValue = rounded
        slider.Text:SetText("Scale " .. tostring(math.floor(rounded * 100 + 0.5)) .. "%")
    end)

    slider:SetScript("OnMouseUp", function()
        DISCONTENT:ApplyPendingScale()
    end)

    slider:SetScript("OnHide", function()
        DISCONTENT:ApplyPendingScale()
    end)

    self.scaleSlider = slider
end

function DISCONTENT:CreateBackgroundSlider(parent)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetMinMaxValues(0.20, 1.00)
    slider:SetValueStep(0.05)
    slider:SetObeyStepOnDrag(true)
    slider:SetWidth(220)
    slider:SetHeight(16)
    slider:SetValue(self.backgroundAlpha)
    slider.Low:SetText("20%")
    slider.High:SetText("100%")
    slider.Text:SetText("Hintergrund " .. tostring(math.floor(self.backgroundAlpha * 100 + 0.5)) .. "%")

    slider:SetScript("OnValueChanged", function(_, value)
        local rounded = math.floor((value * 100) + 0.5) / 100
        DISCONTENT.pendingBackgroundAlpha = rounded
        slider.Text:SetText("Hintergrund " .. tostring(math.floor(rounded * 100 + 0.5)) .. "%")
    end)

    slider:SetScript("OnMouseUp", function()
        DISCONTENT:ApplyPendingBackgroundAlpha()
    end)

    slider:SetScript("OnHide", function()
        DISCONTENT:ApplyPendingBackgroundAlpha()
    end)

    self.backgroundSlider = slider
end

function DISCONTENT:UpdateLayout()
    if not self.uiCreated then return end

    if self.welcomeFrame then
        self.welcomeFrame:SetScale(self.uiScaleValue)
        self:RefreshWelcomeNewsView()
    end

    if self.minimapButton then
        self:UpdateMinimapButtonPosition()
        self:RefreshMinimapButtonVisibility()
    end

    if self.UpdateGuildNewsLayout then self:UpdateGuildNewsLayout() end
    if self.UpdateOverviewLayout then self:UpdateOverviewLayout() end
    if self.UpdateGuildChatLayout then self:UpdateGuildChatLayout() end
    if self.UpdateProfessionsLayout then self:UpdateProfessionsLayout() end
    if self.UpdateRaidPrepLayout then self:UpdateRaidPrepLayout() end
    if self.UpdateMythicPlusLayout then self:UpdateMythicPlusLayout() end
    if self.UpdateNotesLayout then self:UpdateNotesLayout() end
    if self.UpdateOfficerLayout then self:UpdateOfficerLayout() end
    if self.EnsureOfficerPushButton then self:EnsureOfficerPushButton() end
    if self.UpdateSettingsLayout then self:UpdateSettingsLayout() end
end

function DISCONTENT:RefreshData()
    self:CollectGuildMembers()

    if not self.uiCreated then
        return
    end

    self:SetOfficerTabVisibility()

    self.visibleRows = self:GetDynamicVisibleRows()
    self:ApplyFilterAndSort()

    if self.RefreshDropdown then
        self:RefreshDropdown()
    end

    self:UpdateHeaderIndicators()
    self:UpdateRows()

    if self.RefreshOfficerUI then
        self:RefreshOfficerUI()
    end

    if self.EnsureOfficerPushButton then
        self:EnsureOfficerPushButton()
    end

    if self.RefreshMythicPlusUI then
        self:RefreshMythicPlusUI()
    end
end

function DISCONTENT:CreateUI()
    if self.uiCreated then return end

    self:SetSize(self.defaultWidth, self.defaultHeight)
    self:SetPoint("CENTER")
    self:SetResizable(false)
    self:SetFrameStrata("FULLSCREEN_DIALOG")
    self:SetToplevel(true)
    self:SetClampedToScreen(true)
    self:SetScale(self.uiScaleValue)

    self:SetMovable(true)
    self:EnableMouse(true)
    self:RegisterForDrag("LeftButton")
    self:SetScript("OnDragStart", self.StartMoving)
    self:SetScript("OnDragStop", self.StopMovingOrSizing)

    self.bg = self:CreateTexture(nil, "BACKGROUND")
    self.bg:SetAllPoints()
    self.bg:SetColorTexture(0, 0, 0, self.backgroundAlpha)

    self.border = CreateFrame("Frame", nil, self, "BackdropTemplate")
    self.border:SetAllPoints()
    self.border:SetBackdrop({
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 14,
    })
    self.border:SetBackdropBorderColor(0.8, 0.8, 0.8, 1)

    self.title = self:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.title:SetPoint("TOP", 0, -12)
    self.title:SetText("DISCONTENT")

    self.closeButton = CreateFrame("Button", nil, self, "UIPanelCloseButton")
    self.closeButton:SetPoint("TOPRIGHT", -4, -4)

    self.versionText = self:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.versionText:SetPoint("RIGHT", self.closeButton, "LEFT", -6, 1)
    self.versionText:SetText(self:GetVersionLabel())
    self.versionText:SetTextColor(0.75, 0.75, 0.75, 1)

    self.guildNewsTabButton = self:CreateTabButton(self, "Gilden-News", "TOPLEFT", self, "TOPLEFT", 16, -42, "guildnews")
    self.overviewTabButton = self:CreateTabButton(self, "Overview", "LEFT", self.guildNewsTabButton, "RIGHT", 8, 0, "overview")
    self.guildChatTabButton = self:CreateTabButton(self, "Chats", "LEFT", self.overviewTabButton, "RIGHT", 8, 0, "guildchat")
    self.professionsTabButton = self:CreateTabButton(self, "Berufe", "LEFT", self.guildChatTabButton, "RIGHT", 8, 0, "professions")
    self.raidPrepTabButton = self:CreateTabButton(self, "Raid-Prep", "LEFT", self.professionsTabButton, "RIGHT", 8, 0, "raidprep")
    self.mythicPlusTabButton = self:CreateTabButton(self, "Mythic+", "LEFT", self.raidPrepTabButton, "RIGHT", 8, 0, "mythicplus")
    self.notesTabButton = self:CreateTabButton(self, "Notes", "LEFT", self.mythicPlusTabButton, "RIGHT", 8, 0, "notes")
    self.officerTabButton = self:CreateTabButton(self, "Officer", "LEFT", self.notesTabButton, "RIGHT", 8, 0, "officer")
    self.settingsTabButton = self:CreateTabButton(self, "Einstellungen", "LEFT", self.officerTabButton, "RIGHT", 8, 0, "settings")

    self.guildNewsTabContent = CreateFrame("Frame", nil, self)
    self.overviewTabContent = CreateFrame("Frame", nil, self)
    self.guildChatTabContent = CreateFrame("Frame", nil, self)
    self.professionsTabContent = CreateFrame("Frame", nil, self)
    self.raidPrepTabContent = CreateFrame("Frame", nil, self)
    self.mythicPlusTabContent = CreateFrame("Frame", nil, self)
    self.notesTabContent = CreateFrame("Frame", nil, self)
    self.officerTabContent = CreateFrame("Frame", nil, self)
    self.settingsTabContent = CreateFrame("Frame", nil, self)

    if self.CreateGuildNewsUI then self:CreateGuildNewsUI() end
    if self.CreateOverviewUI then self:CreateOverviewUI() end
    if self.CreateGuildChatUI then self:CreateGuildChatUI() end
    if self.CreateProfessionsUI then self:CreateProfessionsUI() end
    if self.CreateRaidPrepUI then self:CreateRaidPrepUI() end
    if self.CreateMythicPlusUI then self:CreateMythicPlusUI() end
    if self.CreateNotesUI then self:CreateNotesUI() end
    if self.CreateOfficerUI then self:CreateOfficerUI() end
    if self.CreateSettingsUI then self:CreateSettingsUI() end

    self:CreateNotePopup()
    self:CreateWelcomeUI()
    self:CreatePushComposePopup()
    self:CreatePushNotificationPopup()
    self:CreateMinimapButton()
    self:CreateMinimapSettingsToggle()
    self:EnsureOfficerPushButton()

    SLASH_DISCONTENT1 = "/discontent"
    SlashCmdList["DISCONTENT"] = function(msg)
        local command = string.lower((msg or ""):gsub("^%s+", ""):gsub("%s+$", ""))

        if command == "sync" then
            if DISCONTENT.RequestRaidPrepSync then
                DISCONTENT:RequestRaidPrepSync()
            end
            return
        elseif command == "newcycle" then
            if DISCONTENT.CanSeeOfficerTab and DISCONTENT:CanSeeOfficerTab() and DISCONTENT.StartNewRaidPrepCycle then
                DISCONTENT:StartNewRaidPrepCycle()
            end
            return
        elseif command == "minimap" then
            local minimap = DISCONTENT:EnsureMinimapDB()
            local currentlyVisible = not minimap.hide
            DISCONTENT:SetMinimapButtonEnabled(not currentlyVisible)
            return
        end

        if DISCONTENT:IsShown() then
            DISCONTENT:Hide()
        else
            DISCONTENT:ShowMainWindow()
        end
    end

    SLASH_DISCONTENTRESET1 = "/discontentreset"
    SlashCmdList["DISCONTENTRESET"] = function()
        DISCONTENT:ResetWindow()
        DISCONTENT:ShowMainWindow()
    end

    self:SetScript("OnMouseWheel", function(_, delta)
        if DISCONTENT.activeTab == "overview" then
            local total = #DISCONTENT.filteredMembers
            local maxOffset = math.max(0, total - DISCONTENT.visibleRows)

            if delta > 0 then
                DISCONTENT.scrollOffset = math.max(0, DISCONTENT.scrollOffset - 1)
            else
                DISCONTENT.scrollOffset = math.min(maxOffset, DISCONTENT.scrollOffset + 1)
            end

            DISCONTENT:UpdateRows()
        elseif DISCONTENT.activeTab == "professions" then
            if DISCONTENT.professionScrollBar then
                local minVal, maxVal = DISCONTENT.professionScrollBar:GetMinMaxValues()
                local newVal = DISCONTENT.professionScrollOffset
                if delta > 0 then
                    newVal = math.max(minVal or 0, newVal - 1)
                else
                    newVal = math.min(maxVal or 0, newVal + 1)
                end
                DISCONTENT.professionScrollBar:SetValue(newVal)
            end
        elseif DISCONTENT.activeTab == "raidprep" then
            if DISCONTENT.raidPrepScrollFrame and DISCONTENT.raidPrepScrollFrame.ScrollBar then
                local sb = DISCONTENT.raidPrepScrollFrame.ScrollBar
                local current = sb:GetValue() or 0
                local step = 28
                if delta > 0 then
                    sb:SetValue(math.max(0, current - step))
                else
                    local _, maxVal = sb:GetMinMaxValues()
                    sb:SetValue(math.min(maxVal or 0, current + step))
                end
            end
        elseif DISCONTENT.activeTab == "notes" then
            if DISCONTENT.notesScrollFrame and DISCONTENT.notesScrollFrame.ScrollBar then
                local sb = DISCONTENT.notesScrollFrame.ScrollBar
                local current = sb:GetValue() or 0
                local step = 28
                if delta > 0 then
                    sb:SetValue(math.max(0, current - step))
                else
                    local _, maxVal = sb:GetMinMaxValues()
                    sb:SetValue(math.min(maxVal or 0, current + step))
                end
            end
        elseif DISCONTENT.activeTab == "officer" then
            if DISCONTENT.officerTrialsScrollFrame and DISCONTENT.officerTrialsScrollFrame.ScrollBar then
                local sb = DISCONTENT.officerTrialsScrollFrame.ScrollBar
                local current = sb:GetValue() or 0
                local step = 28
                if delta > 0 then
                    sb:SetValue(math.max(0, current - step))
                else
                    local _, maxVal = sb:GetMinMaxValues()
                    sb:SetValue(math.min(maxVal or 0, current + step))
                end
            end
        end
    end)
    self:EnableMouseWheel(true)

    self.uiCreated = true
    self.visibleRows = self:GetDynamicVisibleRows()

    if self.EnsureRowCount then
        self:EnsureRowCount()
    end

    if self.EnsureProfessionRowCount then
        self:EnsureProfessionRowCount()
    end

    self:SetOfficerTabVisibility()
    self:UpdateLayout()
    self:UpdateHeaderIndicators()
    self:SetActiveTab("guildnews")
    self:Hide()
end

DISCONTENT:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            self:InitializeDB()

            if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
                C_ChatInfo.RegisterAddonMessagePrefix(self.professionSyncPrefix)
                C_ChatInfo.RegisterAddonMessagePrefix(self.raidPrepSyncPrefix)
                if self.mythicPlusPrefix then
                    C_ChatInfo.RegisterAddonMessagePrefix(self.mythicPlusPrefix)
                end
                if self.pushMessagePrefix then
                    C_ChatInfo.RegisterAddonMessagePrefix(self.pushMessagePrefix)
                end
                if self.newsSyncPrefix then
                    C_ChatInfo.RegisterAddonMessagePrefix(self.newsSyncPrefix)
                end
                if self.gearPrefix then
                    C_ChatInfo.RegisterAddonMessagePrefix(self.gearPrefix)
                end
            end

            self:CreateUI()
        end
    elseif event == "PLAYER_LOGIN" then
        if not self.uiCreated then
            self:CreateUI()
        end

        self.loginCompleted = true

        if IsInGuild() then
            C_GuildInfo.GuildRoster()
        end

        C_Timer.After(0.5, function()
            if DISCONTENT and DISCONTENT.RefreshWelcomeNewsView then
                DISCONTENT:RefreshWelcomeNewsView()
            end
        end)

        if self.RequestNewsSync then
            C_Timer.After(0.8, function()
                if DISCONTENT and DISCONTENT.RequestNewsSync then
                    DISCONTENT:RequestNewsSync()
                end
            end)
        end

        if self.GetWelcomePopupEnabled and self:GetWelcomePopupEnabled() and self.ShowWelcomeWindow then
            C_Timer.After(1.8, function()
                if DISCONTENT and DISCONTENT.GetWelcomePopupEnabled and DISCONTENT:GetWelcomePopupEnabled() and DISCONTENT.ShowWelcomeWindow then
                    DISCONTENT:ShowWelcomeWindow()
                end
            end)
        elseif self.TryShowWelcomeForUnreadNews then
            C_Timer.After(1.8, function()
                if DISCONTENT and DISCONTENT.TryShowWelcomeForUnreadNews then
                    DISCONTENT:TryShowWelcomeForUnreadNews()
                end
            end)
        end

        if self.BroadcastAddonHello then
            C_Timer.After(2, function()
                if DISCONTENT.BroadcastAddonHello then
                    DISCONTENT:BroadcastAddonHello()
                end
            end)
        end

        if self.UpdateOwnProfessionData then
            C_Timer.After(3, function()
                if DISCONTENT.UpdateOwnProfessionData then
                    DISCONTENT:UpdateOwnProfessionData(true)
                end
            end)
        end

        if self.BroadcastRaidPrepStatus then
            C_Timer.After(4, function()
                if DISCONTENT.BroadcastRaidPrepStatus then
                    DISCONTENT:BroadcastRaidPrepStatus()
                end
            end)
        end

        if self.RequestRaidPrepSync then
            C_Timer.After(5, function()
                if DISCONTENT.RequestRaidPrepSync then
                    DISCONTENT:RequestRaidPrepSync()
                end
            end)
        end
    elseif event == "PLAYER_GUILD_UPDATE" then
        if IsInGuild() then
            C_GuildInfo.GuildRoster()
        end
    elseif event == "GUILD_ROSTER_UPDATE" then
        self:RefreshData()
    elseif event == "CHAT_MSG_GUILD" then
        local message, author = ...
        self:AddGuildChatMessage(author, message, "G")
    elseif event == "CHAT_MSG_OFFICER" then
        local message, author = ...
        self:AddGuildChatMessage(author, message, "O")
    elseif event == "CHAT_MSG_RAID" then
        local message, author = ...
        self:AddGuildChatMessage(author, message, "R")
    elseif event == "CHAT_MSG_RAID_LEADER" then
        local message, author = ...
        self:AddGuildChatMessage(author, message, "RL")
    elseif event == "CHAT_MSG_RAID_WARNING" then
        local message, author = ...
        self:AddGuildChatMessage(author, message, "RW")
    elseif event == "CHAT_MSG_INSTANCE_CHAT" then
        local message, author = ...
        self:AddGuildChatMessage(author, message, "I")
    elseif event == "CHAT_MSG_INSTANCE_CHAT_LEADER" then
        local message, author = ...
        self:AddGuildChatMessage(author, message, "IL")
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...

        if self.HandleProfessionAddonMessage then
            self:HandleProfessionAddonMessage(prefix, message, channel, sender)
        end

        if self.HandleGearMessage then
            self:HandleGearMessage(prefix, message, channel, sender)
        end

        if self.HandleRaidPrepAddonMessage then
            self:HandleRaidPrepAddonMessage(prefix, message, channel, sender)
        end

        if self.HandleMythicPlusAddonMessage then
            self:HandleMythicPlusAddonMessage(prefix, message, channel, sender)
        end

        if self.HandleNewsAddonMessage then
            self:HandleNewsAddonMessage(prefix, message, channel, sender)
        end

        if self.HandlePushMessage then
            self:HandlePushMessage(prefix, message, channel, sender)
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        if self.activeTab == "guildchat" and self.SetActiveChatChannel then
            self:SetActiveChatChannel(self.activeChatChannel or "guild")
        end
    elseif event == "SKILL_LINES_CHANGED" then
        if self.UpdateOwnProfessionData then
            C_Timer.After(1, function()
                if DISCONTENT.UpdateOwnProfessionData then
                    DISCONTENT:UpdateOwnProfessionData(true)
                end
            end)
        end
    end
end)

DISCONTENT:RegisterEvent("ADDON_LOADED")
DISCONTENT:RegisterEvent("PLAYER_LOGIN")
DISCONTENT:RegisterEvent("PLAYER_GUILD_UPDATE")
DISCONTENT:RegisterEvent("GUILD_ROSTER_UPDATE")
DISCONTENT:RegisterEvent("CHAT_MSG_GUILD")
DISCONTENT:RegisterEvent("CHAT_MSG_OFFICER")
DISCONTENT:RegisterEvent("CHAT_MSG_RAID")
DISCONTENT:RegisterEvent("CHAT_MSG_RAID_LEADER")
DISCONTENT:RegisterEvent("CHAT_MSG_RAID_WARNING")
DISCONTENT:RegisterEvent("CHAT_MSG_INSTANCE_CHAT")
DISCONTENT:RegisterEvent("CHAT_MSG_INSTANCE_CHAT_LEADER")
DISCONTENT:RegisterEvent("CHAT_MSG_ADDON")
DISCONTENT:RegisterEvent("GROUP_ROSTER_UPDATE")
DISCONTENT:RegisterEvent("SKILL_LINES_CHANGED")