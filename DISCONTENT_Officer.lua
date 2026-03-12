local DISCONTENT = _G.DISCONTENT
if not DISCONTENT then return end

local function BuildNewsPreview(textValue)
    local preview = tostring(textValue or "")
    preview = preview:gsub("\r\n", " ")
    preview = preview:gsub("\n", " ")
    preview = preview:gsub("%s+", " ")

    if #preview > 110 then
        preview = preview:sub(1, 107) .. "..."
    end

    return preview ~= "" and preview or "-"
end

local ARMOR_TYPE_BY_CLASS = {
    WARRIOR = "Platte",
    PALADIN = "Platte",
    DEATHKNIGHT = "Platte",
    HUNTER = "Kette",
    SHAMAN = "Kette",
    EVOKER = "Kette",
    ROGUE = "Leder",
    DRUID = "Leder",
    MONK = "Leder",
    DEMONHUNTER = "Leder",
    PRIEST = "Stoff",
    MAGE = "Stoff",
    WARLOCK = "Stoff",
}

local function GetArmorTypeByClass(classFileName)
    return ARMOR_TYPE_BY_CLASS[tostring(classFileName or ""):upper()] or "-"
end

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

function DISCONTENT:ShowOfficerTrialDetails(member)
    if not member then
        return
    end

    if not self.officerTrialDetailsPopup then
        local popup = CreateFrame("Frame", "DISCONTENTOfficerTrialDetailsPopup", UIParent, "BackdropTemplate")
        popup:SetSize(500, 420)
        popup:SetPoint("CENTER")
        popup:SetFrameStrata("FULLSCREEN_DIALOG")
        popup:SetToplevel(true)
        popup:SetClampedToScreen(true)
        popup:SetMovable(true)
        popup:EnableMouse(true)
        popup:RegisterForDrag("LeftButton")
        popup:SetScript("OnDragStart", popup.StartMoving)
        popup:SetScript("OnDragStop", function(frame)
            frame:StopMovingOrSizing()
            DISCONTENT:SaveFramePosition(frame, "officerTrialDetailsPosition")
        end)
        popup:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            edgeSize = 14,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        popup:SetBackdropColor(0.03, 0.03, 0.04, 0.97)
        popup:SetBackdropBorderColor(0.78, 0.64, 0.18, 1)
        popup:Hide()

        popup.title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        popup.title:SetPoint("TOPLEFT", 16, -14)
        popup.title:SetText("Trial Details")

        popup.closeButton = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
        popup.closeButton:SetPoint("TOPRIGHT", -4, -4)

        popup.infoTitle = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        popup.infoTitle:SetPoint("TOPLEFT", popup, "TOPLEFT", 18, -48)
        popup.infoTitle:SetText("Allgemeine Informationen")

        popup.infoText = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        popup.infoText:SetPoint("TOPLEFT", popup.infoTitle, "BOTTOMLEFT", 0, -8)
        popup.infoText:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -18, -56)
        popup.infoText:SetJustifyH("LEFT")
        popup.infoText:SetJustifyV("TOP")
        popup.infoText:SetText("")

        popup.noteTitle = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        popup.noteTitle:SetPoint("TOPLEFT", popup, "TOPLEFT", 18, -150)
        popup.noteTitle:SetText("Persönliche Notiz")

        popup.noteFrame, popup.noteInput = DISCONTENT:CreateMultilineInput(popup, 464, 170)
        popup.noteFrame:SetPoint("TOPLEFT", popup.noteTitle, "BOTTOMLEFT", 0, -8)

        popup.statusText = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        popup.statusText:SetPoint("BOTTOMLEFT", popup, "BOTTOMLEFT", 18, 18)
        popup.statusText:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -160, 18)
        popup.statusText:SetJustifyH("LEFT")
        popup.statusText:SetText("")

        popup.saveButton = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
        popup.saveButton:SetSize(120, 28)
        popup.saveButton:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -18, 14)
        popup.saveButton:SetText("Speichern")
        popup.saveButton:SetScript("OnClick", function()
            if popup.member then
                DISCONTENT:SaveOfficerNoteForMember(popup.member, popup.noteInput:GetText() or "")
                popup.statusText:SetText("Notiz gespeichert.")
                popup.statusText:SetTextColor(0.3, 1, 0.3, 1)
            end
        end)

        popup:SetScript("OnShow", function(frame)
            frame.statusText:SetText("")
            DISCONTENT:RestoreFramePosition(frame, "officerTrialDetailsPosition", "CENTER", "CENTER", -20, 20)
            C_Timer.After(0, function()
                if frame.noteInput then
                    frame.noteInput:SetFocus()
                end
            end)
        end)

        self.officerTrialDetailsPopup = popup
    end

    local popup = self.officerTrialDetailsPopup
    popup.member = member

    local className = member.className or "-"
    local armorType = GetArmorTypeByClass(member.classFileName)
    local realmText = member.realm or "-"
    local rankText = member.rankName or "-"
    local onlineText = member.isOnline and "|cff33ff33Online|r" or "|cff999999Offline|r"

    popup.infoText:SetText(
        "|cffd9d9d9Name:|r " .. tostring(member.name or "-") .. "\n" ..
        "|cffd9d9d9Klasse:|r " .. tostring(className) .. "\n" ..
        "|cffd9d9d9Rüstungstyp:|r " .. tostring(armorType) .. "\n" ..
        "|cffd9d9d9Realm:|r " .. tostring(realmText) .. "\n" ..
        "|cffd9d9d9Rang:|r " .. tostring(rankText) .. "\n" ..
        "|cffd9d9d9Status:|r " .. onlineText
    )
    popup.noteInput:SetText(self:GetOfficerNoteForMember(member))
    popup.noteInput:SetCursorPosition(0)
    popup:Show()
end

function DISCONTENT:CreateOfficerTrialRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(24)

    if index % 2 == 0 then
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(1, 1, 1, 0.03)
    end

    row.nameButton = CreateFrame("Button", nil, row)
    row.nameButton:SetHeight(20)
    row.nameButton:SetScript("OnClick", function()
        if row.member then
            DISCONTENT:ShowOfficerTrialDetails(row.member)
        end
    end)

    row.nameText = row.nameButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.nameText:SetAllPoints()
    row.nameText:SetJustifyH("LEFT")

    row.statusText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")

    row.noteButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.noteButton:SetSize(58, 20)
    row.noteButton:SetText("Notiz")
    row.noteButton:SetScript("OnClick", function()
        if row.member then
            DISCONTENT:ShowOfficerTrialDetails(row.member)
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

        row.nameButton:ClearAllPoints()
        row.nameButton:SetPoint("LEFT", row, "LEFT", 6, 0)
        row.nameButton:SetWidth(math.max(110, width - 150))

        row.nameText:SetText(member.name or "-")
        row.nameText:SetTextColor(0.85, 0.92, 1)

        row.statusText:ClearAllPoints()
        row.statusText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.statusText:SetWidth(72)
        row.statusText:SetText(member.isOnline and "Online" or "Offline")
        if member.isOnline then
            row.statusText:SetTextColor(0.2, 1, 0.2)
        else
            row.statusText:SetTextColor(0.65, 0.65, 0.65)
        end

        row.noteButton:ClearAllPoints()
        row.noteButton:SetPoint("RIGHT", row.statusText, "LEFT", -10, 0)

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


function DISCONTENT:CreateOfficerRaidPrepRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(22)

    if index % 2 == 0 then
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(1, 1, 1, 0.03)
    end

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.text:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetJustifyV("MIDDLE")

    return row
end

function DISCONTENT:RefreshOfficerRaidPrepList()
    if not self.officerRaidPrepScrollChild or not self.officerRaidPrepScrollFrame then
        return
    end

    local readyLines = self:BuildOfficerReadyList()
    local width = math.max(180, ((self.officerRaidPrepScrollFrame and self.officerRaidPrepScrollFrame:GetWidth()) or 240) - 12)
    local y = 0

    self.officerRaidPrepRows = self.officerRaidPrepRows or {}

    for index = 1, #readyLines do
        local row = self.officerRaidPrepRows[index]
        if not row then
            row = self:CreateOfficerRaidPrepRow(self.officerRaidPrepScrollChild, index)
            self.officerRaidPrepRows[index] = row
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.officerRaidPrepScrollChild, "TOPLEFT", 0, -y)
        row:SetWidth(width)
        row.text:SetText(readyLines[index])
        row:Show()

        y = y + 22
    end

    for index = #readyLines + 1, #(self.officerRaidPrepRows or {}) do
        self.officerRaidPrepRows[index]:Hide()
    end

    self.officerRaidPrepScrollChild:SetSize(width, math.max(y + 4, (self.officerRaidPrepScrollFrame:GetHeight() or 100)))
end


function DISCONTENT:CreateOfficerNewsRow(parent, index)
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetHeight(88)
    row:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8X8",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 10,
    })
    row:SetBackdropColor(0.07, 0.07, 0.08, 0.45)
    row:SetBackdropBorderColor(0.25, 0.25, 0.28, 0.65)

    row.titleText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.titleText:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -8)
    row.titleText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -126, -8)
    row.titleText:SetJustifyH("LEFT")
    row.titleText:SetJustifyV("TOP")

    row.metaText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.metaText:SetPoint("TOPLEFT", row.titleText, "BOTTOMLEFT", 0, -4)
    row.metaText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -126, -28)
    row.metaText:SetJustifyH("LEFT")
    row.metaText:SetJustifyV("TOP")
    row.metaText:SetTextColor(0.72, 0.78, 0.88, 1)

    row.previewText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.previewText:SetPoint("TOPLEFT", row.metaText, "BOTTOMLEFT", 0, -5)
    row.previewText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -16, -44)
    row.previewText:SetJustifyH("LEFT")
    row.previewText:SetJustifyV("TOP")
    row.previewText:SetTextColor(0.9, 0.9, 0.9, 1)

    row.editButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.editButton:SetSize(78, 20)
    row.editButton:SetText("Bearbeiten")
    row.editButton:SetScript("OnClick", function()
        if row.entry then
            DISCONTENT:ShowOfficerNewsEditor(row.entry)
        end
    end)

    row.deleteButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.deleteButton:SetSize(24, 20)
    row.deleteButton:SetText("X")
    row.deleteButton:SetScript("OnClick", function()
        if row.entry and row.entry.id then
            DISCONTENT:DeleteNewsEntry(row.entry.id)
        end
    end)

    return row
end

function DISCONTENT:RefreshOfficerNewsList()
    if not self.officerNewsScrollChild or not self.officerNewsScrollFrame then
        return
    end

    local entries = self:GetSortedNewsEntries()
    local width = math.max(260, (self.officerNewsScrollFrame:GetWidth() or 360) - 28)
    local y = 0

    self.officerNewsRows = self.officerNewsRows or {}

    for index = 1, #entries do
        local row = self.officerNewsRows[index]
        if not row then
            row = self:CreateOfficerNewsRow(self.officerNewsScrollChild, index)
            self.officerNewsRows[index] = row
        end

        local entry = entries[index]
        local category = self:GetNormalizedNewsCategory(entry.category)
        local important = self:IsImportantNews(entry)

        row.entry = entry
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.officerNewsScrollChild, "TOPLEFT", 0, -y)
        row:SetWidth(width)

        row.titleText:SetText("[" .. category .. "] " .. tostring(entry.title or "Ohne Titel"))
        row.metaText:SetText(tostring(entry.author or "Unbekannt") .. "  •  " .. tostring(entry.dateText or "-"))
        row.previewText:SetText(BuildNewsPreview(entry.text))

        row.editButton:ClearAllPoints()
        row.editButton:SetPoint("TOPRIGHT", row, "TOPRIGHT", -34, -8)

        row.deleteButton:ClearAllPoints()
        row.deleteButton:SetPoint("LEFT", row.editButton, "RIGHT", 6, 0)

        local rowHeight = math.max(88, math.ceil((row.previewText:GetStringHeight() or 0) + 58))
        row:SetHeight(rowHeight)

        if important then
            row:SetBackdropColor(0.16, 0.10, 0.05, 0.55)
            row:SetBackdropBorderColor(0.82, 0.66, 0.18, 0.95)
            row.titleText:SetTextColor(1.00, 0.84, 0.22, 1)
        else
            if index % 2 == 0 then
                row:SetBackdropColor(0.09, 0.09, 0.10, 0.52)
            else
                row:SetBackdropColor(0.07, 0.07, 0.08, 0.45)
            end
            row:SetBackdropBorderColor(0.25, 0.25, 0.28, 0.65)
            row.titleText:SetTextColor(0.9, 0.95, 1, 1)
        end

        row:Show()
        y = y + row:GetHeight() + 6
    end

    for index = #entries + 1, #(self.officerNewsRows or {}) do
        self.officerNewsRows[index].entry = nil
        self.officerNewsRows[index]:Hide()
    end

    self.officerNewsScrollChild:SetSize(width, math.max(y + 4, self.officerNewsScrollFrame:GetHeight() or 100))
end

function DISCONTENT:CreateOfficerNewsEditor()
    if self.officerNewsEditor then
        return
    end

    local popup = CreateFrame("Frame", "DISCONTENTOfficerNewsEditor", UIParent, "BackdropTemplate")
    popup:SetSize(560, 430)
    popup:SetPoint("CENTER")
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetToplevel(true)
    popup:SetClampedToScreen(true)
    popup:SetMovable(true)
    popup:EnableMouse(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", popup.StartMoving)
    popup:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        DISCONTENT:SaveFramePosition(frame, "officerNewsEditorPosition")
    end)
    popup:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    popup:SetBackdropColor(0.03, 0.03, 0.04, 0.97)
    popup:SetBackdropBorderColor(0.78, 0.64, 0.18, 1)
    popup:Hide()

    popup.title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    popup.title:SetPoint("TOP", popup, "TOP", 0, -12)
    popup.title:SetText("News erstellen")

    popup.subtitle = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    popup.subtitle:SetPoint("TOPLEFT", popup, "TOPLEFT", 16, -38)
    popup.subtitle:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -16, -38)
    popup.subtitle:SetJustifyH("LEFT")
    popup.subtitle:SetText("Erstelle oder bearbeite Gilden-News. Neue oder geänderte Einträge werden automatisch an alle DISCONTENT-Nutzer synchronisiert.")

    popup.closeButton = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
    popup.closeButton:SetPoint("TOPRIGHT", -4, -4)

    popup.categoryLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    popup.categoryLabel:SetPoint("TOPLEFT", popup, "TOPLEFT", 18, -78)
    popup.categoryLabel:SetText("Kategorie")

    popup.categoryDropdown = CreateFrame("Frame", "DISCONTENTOfficerNewsCategoryDropdown", popup, "UIDropDownMenuTemplate")
    popup.categoryDropdown:SetPoint("TOPLEFT", popup.categoryLabel, "BOTTOMLEFT", -14, -6)
    UIDropDownMenu_SetWidth(popup.categoryDropdown, 150)

    popup.subjectLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    popup.subjectLabel:SetPoint("TOPLEFT", popup, "TOPLEFT", 18, -144)
    popup.subjectLabel:SetText("Betreff")

    popup.subjectInput = DISCONTENT:CreateSingleLineInput(popup, 522, 24)
    popup.subjectInput:SetPoint("TOPLEFT", popup.subjectLabel, "BOTTOMLEFT", 0, -6)

    popup.textLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    popup.textLabel:SetPoint("TOPLEFT", popup.subjectInput, "BOTTOMLEFT", 0, -16)
    popup.textLabel:SetText("Text")

    popup.textFrame, popup.textInput = DISCONTENT:CreateMultilineInput(popup, 522, 154)
    popup.textFrame:SetPoint("TOPLEFT", popup.textLabel, "BOTTOMLEFT", 0, -6)

    popup.statusText = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    popup.statusText:SetPoint("BOTTOMLEFT", popup, "BOTTOMLEFT", 18, 18)
    popup.statusText:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -150, 18)
    popup.statusText:SetJustifyH("LEFT")
    popup.statusText:SetText("")

    popup.saveButton = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    popup.saveButton:SetSize(112, 28)
    popup.saveButton:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -16, 14)
    popup.saveButton:SetText("Speichern")
    popup.saveButton:SetScript("OnClick", function()
        local ok, err = DISCONTENT:CreateOrUpdateNewsEntry(
            popup.editingNewsId,
            popup.selectedCategory or "Allgemein",
            popup.subjectInput:GetText() or "",
            popup.textInput:GetText() or ""
        )

        if ok then
            popup:Hide()
        else
            popup.statusText:SetText(err or "Speichern fehlgeschlagen.")
            popup.statusText:SetTextColor(1, 0.25, 0.25, 1)
        end
    end)

    UIDropDownMenu_Initialize(popup.categoryDropdown, function(_, level)
        for index = 1, #(DISCONTENT.newsCategories or {}) do
            local category = DISCONTENT.newsCategories[index]
            local info = UIDropDownMenu_CreateInfo()
            info.text = category
            info.func = function()
                popup.selectedCategory = category
                UIDropDownMenu_SetText(popup.categoryDropdown, category)
            end
            info.checked = (popup.selectedCategory == category)
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    popup:SetScript("OnShow", function(frame)
        frame.statusText:SetText("")
        frame.textInput:SetHeight(142)
        DISCONTENT:RestoreFramePosition(frame, "officerNewsEditorPosition", "CENTER", "CENTER", 60, 40)
        C_Timer.After(0, function()
            if frame.textInput then
                frame.textInput:SetFocus()
                frame.textInput:HighlightText(0, 0)
                frame.textInput:SetCursorPosition(0)
            end
        end)
    end)

    self.officerNewsEditor = popup
end

function DISCONTENT:ShowOfficerNewsEditor(entry)
    if not self.officerNewsEditor then
        self:CreateOfficerNewsEditor()
    end

    local popup = self.officerNewsEditor
    if not popup then
        return
    end

    popup.editingNewsId = entry and entry.id or nil
    popup.selectedCategory = self:GetNormalizedNewsCategory(entry and entry.category or "Allgemein")
    popup.title:SetText(entry and "News bearbeiten" or "News erstellen")
    popup.subjectInput:SetText(entry and tostring(entry.title or "") or "")
    popup.textInput:SetText(entry and tostring(entry.text or "") or "")
    popup.textInput:SetCursorPosition(0)
    UIDropDownMenu_SetText(popup.categoryDropdown, popup.selectedCategory)
    popup:Show()
    C_Timer.After(0, function()
        if popup.textInput then
            popup.textInput:SetFocus()
            popup.textInput:SetCursorPosition(0)
        end
    end)
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
    self:RefreshOfficerNewsList()
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

    self.officerReadyHeader = self.officerRaidPrepPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.officerReadyHeader:SetPoint("TOPLEFT", 12, -34)
    self.officerReadyHeader:SetText("Komplett abgeschlossen")

    self.officerRaidPrepScrollFrame = CreateFrame("ScrollFrame", "DISCONTENTOfficerRaidPrepScrollFrame", self.officerRaidPrepPanel, "UIPanelScrollFrameTemplate")
    self.officerRaidPrepScrollChild = CreateFrame("Frame", nil, self.officerRaidPrepScrollFrame)
    self.officerRaidPrepScrollFrame:SetScrollChild(self.officerRaidPrepScrollChild)
    self.officerRaidPrepScrollChild:SetSize(1, 1)

    self.officerRaidPrepRows = self.officerRaidPrepRows or {}

    self.officerNewsPanel = CreateFrame("Frame", nil, self.officerTabContent, "BackdropTemplate")
    self.officerNewsPanel:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8X8",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
    })
    self.officerNewsPanel:SetBackdropColor(0.08, 0.08, 0.08, 0.55)
    self.officerNewsPanel:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.85)

    self.officerNewsTitle = self.officerNewsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.officerNewsTitle:SetPoint("TOPLEFT", 12, -10)
    self.officerNewsTitle:SetText("News")

    self.officerCreateNewsButton = CreateFrame("Button", nil, self.officerNewsPanel, "UIPanelButtonTemplate")
    self.officerCreateNewsButton:SetSize(146, 22)
    self.officerCreateNewsButton:SetText("Neue News erstellen")
    self.officerCreateNewsButton:SetScript("OnClick", function()
        DISCONTENT:ShowOfficerNewsEditor(nil)
    end)

    self.officerNewsScrollFrame = CreateFrame("ScrollFrame", "DISCONTENTOfficerNewsScrollFrame", self.officerNewsPanel, "UIPanelScrollFrameTemplate")
    self.officerNewsScrollChild = CreateFrame("Frame", nil, self.officerNewsScrollFrame)
    self.officerNewsScrollFrame:SetScrollChild(self.officerNewsScrollChild)
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
    self.officerTrialsCard:SetSize(220, 88)

    self.officerReadyCard:ClearAllPoints()
    self.officerReadyCard:SetPoint("LEFT", self.officerTrialsCard, "RIGHT", 12, 0)
    self.officerReadyCard:SetSize(240, 88)

    self.officerSyncButton:ClearAllPoints()
    self.officerSyncButton:SetPoint("LEFT", self.officerReadyCard, "RIGHT", 16, 0)

    self.officerNewCycleButton:ClearAllPoints()
    self.officerNewCycleButton:SetPoint("LEFT", self.officerSyncButton, "RIGHT", 8, 0)

    self.officerTrialsPanel:ClearAllPoints()
    self.officerTrialsPanel:SetPoint("TOPLEFT", self.officerTabContent, "TOPLEFT", 16, -170)
    self.officerTrialsPanel:SetPoint("BOTTOMLEFT", self.officerTabContent, "BOTTOMLEFT", 16, 16)
    self.officerTrialsPanel:SetWidth(320)

    self.officerTrialsScrollFrame:ClearAllPoints()
    self.officerTrialsScrollFrame:SetPoint("TOPLEFT", self.officerTrialsPanel, "TOPLEFT", 10, -34)
    self.officerTrialsScrollFrame:SetPoint("BOTTOMRIGHT", self.officerTrialsPanel, "BOTTOMRIGHT", -30, 10)

    self.officerRaidPrepPanel:ClearAllPoints()
    self.officerRaidPrepPanel:SetPoint("TOPLEFT", self.officerTrialsPanel, "TOPRIGHT", 16, 0)
    self.officerRaidPrepPanel:SetPoint("BOTTOMLEFT", self.officerTabContent, "BOTTOMLEFT", 352, 16)
    self.officerRaidPrepPanel:SetWidth(320)

    if self.officerRaidPrepScrollFrame then
        self.officerRaidPrepScrollFrame:ClearAllPoints()
        self.officerRaidPrepScrollFrame:SetPoint("TOPLEFT", self.officerRaidPrepPanel, "TOPLEFT", 10, -58)
        self.officerRaidPrepScrollFrame:SetPoint("BOTTOMRIGHT", self.officerRaidPrepPanel, "BOTTOMRIGHT", -30, 10)
        self.officerRaidPrepScrollChild:SetWidth(math.max(180, (self.officerRaidPrepScrollFrame:GetWidth() or 240) - 12))
    end

    self.officerNewsPanel:ClearAllPoints()
    self.officerNewsPanel:SetPoint("TOPLEFT", self.officerRaidPrepPanel, "TOPRIGHT", 16, 0)
    self.officerNewsPanel:SetPoint("BOTTOMRIGHT", self.officerTabContent, "BOTTOMRIGHT", -16, 16)

    self.officerCreateNewsButton:ClearAllPoints()
    self.officerCreateNewsButton:SetPoint("TOPRIGHT", self.officerNewsPanel, "TOPRIGHT", -10, -6)

    self.officerNewsScrollFrame:ClearAllPoints()
    self.officerNewsScrollFrame:SetPoint("TOPLEFT", self.officerNewsPanel, "TOPLEFT", 10, -34)
    self.officerNewsScrollFrame:SetPoint("BOTTOMRIGHT", self.officerNewsPanel, "BOTTOMRIGHT", -30, 10)

    self:RefreshOfficerUI()
end
