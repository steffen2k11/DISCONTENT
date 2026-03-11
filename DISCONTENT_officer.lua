local DISCONTENT = _G.DISCONTENT
if not DISCONTENT then return end

function DISCONTENT:GetOfficerNotesStore()
    if type(_G.DISCONTENTDB) ~= "table" then
        _G.DISCONTENTDB = {}
    end
    if type(_G.DISCONTENTDB.officerNotes) ~= "table" then
        _G.DISCONTENTDB.officerNotes = {}
    end
    return _G.DISCONTENTDB.officerNotes
end

function DISCONTENT:GetOfficerNoteForMember(member)
    if not member then
        return ""
    end
    local key = self:GetCharacterKey(member.name, member.realm)
    local store = self:GetOfficerNotesStore()
    return (store[key] and store[key].note) or ""
end

function DISCONTENT:SaveOfficerNoteForMember(member, text)
    if not member then
        return
    end

    local key = self:GetCharacterKey(member.name, member.realm)
    local store = self:GetOfficerNotesStore()
    text = tostring(text or "")

    if text == "" then
        store[key] = nil
    else
        store[key] = {
            note = text,
            updatedAt = time(),
            name = member.name,
            realm = member.realm,
        }
    end

    self:SaveSettings()
    self:RefreshOfficerUI()
end

function DISCONTENT:GetOfficerTrials()
    local list = {}

    for i = 1, #(self.members or {}) do
        local member = self.members[i]
        if member and member.rankName == "Trial" then
            list[#list + 1] = member
        end
    end

    table.sort(list, function(a, b)
        return self:NormalizeText(a.name) < self:NormalizeText(b.name)
    end)

    return list
end

function DISCONTENT:GetSortedRaidPrepStatusList()
    local store = self:GetRaidPrepStatusStore()
    local list = {}
    local currentCycle = self:GetCurrentRaidPrepCycleId()

    for _, entry in pairs(store) do
        if entry and tonumber(entry.cycleId) == currentCycle and entry.ready then
            list[#list + 1] = entry
        end
    end

    table.sort(list, function(a, b)
        if (a.updatedAt or 0) ~= (b.updatedAt or 0) then
            return (a.updatedAt or 0) > (b.updatedAt or 0)
        end
        return self:NormalizeText(a.name) < self:NormalizeText(b.name)
    end)

    return list
end

function DISCONTENT:GetGuildMemberRaidPrepEntry(member)
    if not member then
        return nil
    end

    local key = self:GetCharacterKey(member.name, member.realm)
    local store = self:GetRaidPrepStatusStore()
    local entry = store[key]
    if entry and tonumber(entry.cycleId) == self:GetCurrentRaidPrepCycleId() then
        return entry
    end

    return nil
end

function DISCONTENT:GetOfficerDashboardStats()
    local trials = self:GetOfficerTrials()
    local trialsTotal = #trials
    local trialsOnline = 0
    local trialsWithNotes = 0

    for i = 1, trialsTotal do
        local member = trials[i]
        if member.isOnline then
            trialsOnline = trialsOnline + 1
        end
        if self:GetOfficerNoteForMember(member) ~= "" then
            trialsWithNotes = trialsWithNotes + 1
        end
    end

    local ready = 0
    local nodata = 0

    for i = 1, #(self.members or {}) do
        local member = self.members[i]
        local entry = self:GetGuildMemberRaidPrepEntry(member)

        if entry and entry.ready then
            ready = ready + 1
        elseif not entry then
            nodata = nodata + 1
        end
    end

    return {
        trialsTotal = trialsTotal,
        trialsOnline = trialsOnline,
        trialsWithNotes = trialsWithNotes,
        ready = ready,
        nodata = nodata,
    }
end

function DISCONTENT:ShowOfficerNoteEditor(member)
    if not member then
        return
    end

    if not self.officerNoteEditor then
        local popup = CreateFrame("Frame", "DISCONTENTOfficerNoteEditor", UIParent, "BackdropTemplate")
        popup:SetSize(500, 320)
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
        popup.bg:SetColorTexture(0.05, 0.05, 0.05, 0.96)

        popup.border = CreateFrame("Frame", nil, popup, "BackdropTemplate")
        popup.border:SetAllPoints()
        popup.border:SetBackdrop({
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            edgeSize = 14,
        })
        popup.border:SetBackdropBorderColor(0.8, 0.8, 0.8, 1)

        popup.title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        popup.title:SetPoint("TOP", 0, -12)
        popup.title:SetText("Trial-Notiz")

        popup.targetText = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        popup.targetText:SetPoint("TOPLEFT", 16, -40)
        popup.targetText:SetJustifyH("LEFT")
        popup.targetText:SetText("-")

        popup.input = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
        popup.input:SetMultiLine(true)
        popup.input:SetAutoFocus(false)
        popup.input:SetFontObject(ChatFontNormal)
        popup.input:SetWidth(440)
        popup.input:SetHeight(180)

        popup.scroll = CreateFrame("ScrollFrame", nil, popup, "UIPanelScrollFrameTemplate")
        popup.scroll:SetPoint("TOPLEFT", popup, "TOPLEFT", 16, -68)
        popup.scroll:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -34, 54)
        popup.scroll:SetScrollChild(popup.input)

        popup.saveButton = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
        popup.saveButton:SetSize(100, 24)
        popup.saveButton:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -16, 16)
        popup.saveButton:SetText("Speichern")

        popup.clearButton = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
        popup.clearButton:SetSize(100, 24)
        popup.clearButton:SetPoint("RIGHT", popup.saveButton, "LEFT", -8, 0)
        popup.clearButton:SetText("Löschen")

        popup.closeButton = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
        popup.closeButton:SetPoint("TOPRIGHT", -4, -4)

        popup.saveButton:SetScript("OnClick", function()
            if popup.member then
                DISCONTENT:SaveOfficerNoteForMember(popup.member, popup.input:GetText() or "")
                popup:Hide()
            end
        end)

        popup.clearButton:SetScript("OnClick", function()
            if popup.member then
                DISCONTENT:SaveOfficerNoteForMember(popup.member, "")
                popup.input:SetText("")
                popup:Hide()
            end
        end)

        self.officerNoteEditor = popup
    end

    local popup = self.officerNoteEditor
    popup.member = member
    popup.targetText:SetText((member.name or "-") .. " - " .. (member.realm or "-") .. " | Rang: " .. (member.rankName or "-"))
    popup.input:SetText(self:GetOfficerNoteForMember(member))
    popup:Show()
    popup.input:SetFocus()
end

function DISCONTENT:CreateOfficerTrialRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(24)

    if index % 2 == 0 then
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(1, 1, 1, 0.03)
    end

    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.classText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.statusText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")

    row.noteButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.noteButton:SetSize(70, 20)
    row.noteButton:SetText("Notiz")
    row.noteButton:SetScript("OnClick", function()
        if row.member then
            DISCONTENT:ShowOfficerNoteEditor(row.member)
        end
    end)

    return row
end

function DISCONTENT:RefreshOfficerTrialsList()
    if not self.officerTrialsScrollChild then
        return
    end

    local entries = self:GetOfficerTrials()
    local width = math.max(300, (self.officerTrialsScrollFrame:GetWidth() or 520) - 28)
    local y = 0

    self.officerTrialRows = self.officerTrialRows or {}

    for i = 1, #entries do
        local row = self.officerTrialRows[i]
        if not row then
            row = self:CreateOfficerTrialRow(self.officerTrialsScrollChild, i)
            self.officerTrialRows[i] = row
        end

        local member = entries[i]
        row.member = member

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.officerTrialsScrollChild, "TOPLEFT", 0, -y)
        row:SetWidth(width)

        row.nameText:ClearAllPoints()
        row.nameText:SetPoint("LEFT", row, "LEFT", 4, 0)
        row.nameText:SetWidth(150)
        row.nameText:SetText(member.name or "-")
        row.nameText:SetTextColor(0.85, 0.92, 1)

        row.classText:ClearAllPoints()
        row.classText:SetPoint("LEFT", row, "LEFT", 160, 0)
        row.classText:SetWidth(120)
        row.classText:SetText(member.className or "-")
        local cr, cg, cb = self:GetClassColor(member.classFileName)
        row.classText:SetTextColor(cr, cg, cb)

        row.statusText:ClearAllPoints()
        row.statusText:SetPoint("LEFT", row, "LEFT", 286, 0)
        row.statusText:SetWidth(70)
        row.statusText:SetText(member.isOnline and "Online" or "Offline")
        if member.isOnline then
            row.statusText:SetTextColor(0.2, 1, 0.2)
        else
            row.statusText:SetTextColor(0.65, 0.65, 0.65)
        end

        row.noteButton:ClearAllPoints()
        row.noteButton:SetPoint("RIGHT", row, "RIGHT", -8, 0)

        row:Show()
        y = y + 26
    end

    for i = #entries + 1, #(self.officerTrialRows or {}) do
        self.officerTrialRows[i]:Hide()
    end

    self.officerTrialsScrollChild:SetSize(width, math.max(y + 4, self.officerTrialsScrollFrame:GetHeight() or 100))
end

function DISCONTENT:BuildOfficerReadyList()
    local readyLines = {}
    local readyEntries = self:GetSortedRaidPrepStatusList()
    local guildMemberMap = {}

    for i = 1, #(self.members or {}) do
        local member = self.members[i]
        local key = self:GetCharacterKey(member.name, member.realm)
        guildMemberMap[key] = member
    end

    for i = 1, #readyEntries do
        local entry = readyEntries[i]
        local classText = ""
        local member = guildMemberMap[entry.key]
        if member and member.className and member.className ~= "" then
            classText = " - " .. member.className
        end
        local stamp = date("%H:%M", tonumber(entry.updatedAt) or time())
        readyLines[#readyLines + 1] = "|cff33dd55" .. (entry.name or "-") .. classText .. " |cff888888(" .. stamp .. ")|r"
    end

    if #readyLines == 0 then
        readyLines[1] = "|cff777777Niemand fertig gemeldet.|r"
    end

    return readyLines
end

function DISCONTENT:RefreshOfficerRaidPrepList()
    if not self.officerReadyText then
        return
    end

    local readyLines = self:BuildOfficerReadyList()
    self.officerReadyText:SetText(table.concat(readyLines, "\n"))

    if self.officerRaidPrepCycleText then
        self.officerRaidPrepCycleText:SetText("Raidprep-Zyklus: " .. tostring(self:GetCurrentRaidPrepCycleId()))
    end
end

function DISCONTENT:RefreshOfficerDashboard()
    local stats = self:GetOfficerDashboardStats()

    if self.officerTrialsStatValue then
        self.officerTrialsStatValue:SetText(tostring(stats.trialsTotal))
    end
    if self.officerTrialsSubText then
        self.officerTrialsSubText:SetText("Online: " .. tostring(stats.trialsOnline) .. " | Notizen: " .. tostring(stats.trialsWithNotes))
    end

    if self.officerReadyStatValue then
        self.officerReadyStatValue:SetText(tostring(stats.ready))
    end
    if self.officerReadySubText then
        self.officerReadySubText:SetText("Keine Daten: " .. tostring(stats.nodata))
    end
end

function DISCONTENT:RefreshOfficerUI()
    if not self.uiCreated or not self.officerTabContent or not self:CanSeeOfficerTab() then
        return
    end

    self:RefreshOfficerDashboard()
    self:RefreshOfficerTrialsList()
    self:RefreshOfficerRaidPrepList()
end

function DISCONTENT:CreateOfficerStatCard(parent, title)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8X8",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
    })
    card:SetBackdropColor(0.08, 0.08, 0.08, 0.55)
    card:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.85)

    card.title = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    card.title:SetPoint("TOPLEFT", 12, -10)
    card.title:SetText(title)

    card.value = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    card.value:SetPoint("TOPLEFT", 12, -34)
    card.value:SetText("0")

    card.sub = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.sub:SetPoint("TOPLEFT", 12, -58)
    card.sub:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, -58)
    card.sub:SetJustifyH("LEFT")
    card.sub:SetText("-")

    return card
end

function DISCONTENT:CreateOfficerUI()
    self.officerTitle = self.officerTabContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.officerTitle:SetText("Officer")

    self.officerSubtitle = self.officerTabContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.officerSubtitle:SetJustifyH("LEFT")
    self.officerSubtitle:SetText("Officer-Dashboard für Trials, lokale Notizen und synchronisierte Raid-Prep-Abschlüsse der Gilde.")

    self.officerTrialsCard = self:CreateOfficerStatCard(self.officerTabContent, "Trials")
    self.officerReadyCard = self:CreateOfficerStatCard(self.officerTabContent, "Raid-Prep")

    self.officerTrialsStatValue = self.officerTrialsCard.value
    self.officerTrialsSubText = self.officerTrialsCard.sub
    self.officerReadyStatValue = self.officerReadyCard.value
    self.officerReadySubText = self.officerReadyCard.sub

    self.officerSyncButton = CreateFrame("Button", nil, self.officerTabContent, "UIPanelButtonTemplate")
    self.officerSyncButton:SetSize(130, 24)
    self.officerSyncButton:SetText("Sync anfordern")
    self.officerSyncButton:SetScript("OnClick", function()
        DISCONTENT:RequestRaidPrepSync()
    end)

    self.officerNewCycleButton = CreateFrame("Button", nil, self.officerTabContent, "UIPanelButtonTemplate")
    self.officerNewCycleButton:SetSize(170, 24)
    self.officerNewCycleButton:SetText("Neuen Zyklus starten")
    self.officerNewCycleButton:SetScript("OnClick", function()
        DISCONTENT:StartNewRaidPrepCycle()
    end)

    self.officerTrialsPanel = CreateFrame("Frame", nil, self.officerTabContent, "BackdropTemplate")
    self.officerTrialsPanel:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8X8",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
    })
    self.officerTrialsPanel:SetBackdropColor(0.08, 0.08, 0.08, 0.55)
    self.officerTrialsPanel:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.85)

    self.officerTrialsTitle = self.officerTrialsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.officerTrialsTitle:SetPoint("TOPLEFT", 12, -10)
    self.officerTrialsTitle:SetText("Trial Management")

    self.officerTrialsScrollFrame = CreateFrame("ScrollFrame", "DISCONTENTOfficerTrialsScrollFrame", self.officerTrialsPanel, "UIPanelScrollFrameTemplate")
    self.officerTrialsScrollChild = CreateFrame("Frame", nil, self.officerTrialsScrollFrame)
    self.officerTrialsScrollFrame:SetScrollChild(self.officerTrialsScrollChild)

    self.officerRaidPrepPanel = CreateFrame("Frame", nil, self.officerTabContent, "BackdropTemplate")
    self.officerRaidPrepPanel:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8X8",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
    })
    self.officerRaidPrepPanel:SetBackdropColor(0.08, 0.08, 0.08, 0.55)
    self.officerRaidPrepPanel:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.85)

    self.officerRaidPrepTitle = self.officerRaidPrepPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.officerRaidPrepTitle:SetPoint("TOPLEFT", 12, -10)
    self.officerRaidPrepTitle:SetText("Raid-Prep Übersicht")

    self.officerRaidPrepCycleText = self.officerRaidPrepPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.officerRaidPrepCycleText:SetPoint("TOPRIGHT", self.officerRaidPrepPanel, "TOPRIGHT", -12, -12)
    self.officerRaidPrepCycleText:SetText("Raidprep-Zyklus: 1")

    self.officerReadyHeader = self.officerRaidPrepPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.officerReadyHeader:SetPoint("TOPLEFT", 12, -38)
    self.officerReadyHeader:SetText("Komplett abgeschlossen")

    self.officerReadyText = self.officerRaidPrepPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.officerReadyText:SetPoint("TOPLEFT", 12, -58)
    self.officerReadyText:SetPoint("TOPRIGHT", self.officerRaidPrepPanel, "TOPRIGHT", -12, -58)
    self.officerReadyText:SetJustifyH("LEFT")
    self.officerReadyText:SetJustifyV("TOP")
    self.officerReadyText:SetText("")
end

function DISCONTENT:UpdateOfficerLayout()
    if not self.officerTabContent then
        return
    end

    self.officerTabContent:ClearAllPoints()
    self.officerTabContent:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -70)
    self.officerTabContent:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)

    self.officerTitle:ClearAllPoints()
    self.officerTitle:SetPoint("TOPLEFT", self.officerTabContent, "TOPLEFT", 16, -12)

    self.officerSubtitle:ClearAllPoints()
    self.officerSubtitle:SetPoint("TOPLEFT", self.officerTabContent, "TOPLEFT", 16, -40)
    self.officerSubtitle:SetPoint("TOPRIGHT", self.officerTabContent, "TOPRIGHT", -16, -40)

    self.officerTrialsCard:ClearAllPoints()
    self.officerTrialsCard:SetPoint("TOPLEFT", self.officerTabContent, "TOPLEFT", 16, -70)
    self.officerTrialsCard:SetSize(260, 88)

    self.officerReadyCard:ClearAllPoints()
    self.officerReadyCard:SetPoint("LEFT", self.officerTrialsCard, "RIGHT", 12, 0)
    self.officerReadyCard:SetSize(300, 88)

    self.officerSyncButton:ClearAllPoints()
    self.officerSyncButton:SetPoint("LEFT", self.officerReadyCard, "RIGHT", 16, 0)

    self.officerNewCycleButton:ClearAllPoints()
    self.officerNewCycleButton:SetPoint("LEFT", self.officerSyncButton, "RIGHT", 8, 0)

    self.officerTrialsPanel:ClearAllPoints()
    self.officerTrialsPanel:SetPoint("TOPLEFT", self.officerTabContent, "TOPLEFT", 16, -170)
    self.officerTrialsPanel:SetPoint("BOTTOMLEFT", self.officerTabContent, "BOTTOMLEFT", 16, 16)
    self.officerTrialsPanel:SetWidth(430)

    self.officerTrialsScrollFrame:ClearAllPoints()
    self.officerTrialsScrollFrame:SetPoint("TOPLEFT", self.officerTrialsPanel, "TOPLEFT", 10, -34)
    self.officerTrialsScrollFrame:SetPoint("BOTTOMRIGHT", self.officerTrialsPanel, "BOTTOMRIGHT", -30, 10)

    self.officerRaidPrepPanel:ClearAllPoints()
    self.officerRaidPrepPanel:SetPoint("TOPLEFT", self.officerTrialsPanel, "TOPRIGHT", 16, 0)
    self.officerRaidPrepPanel:SetPoint("BOTTOMRIGHT", self.officerTabContent, "BOTTOMRIGHT", -16, 16)

    self:RefreshOfficerUI()
end