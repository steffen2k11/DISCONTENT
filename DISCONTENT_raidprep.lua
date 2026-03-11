local DISCONTENT = _G.DISCONTENT
if not DISCONTENT then return end

function DISCONTENT:GetRaidPrepChecklist()
    return self.raidPrepEntries or {}
end

function DISCONTENT:GetRaidPrepCharacterKey()
    local name, realm = self:GetPlayerNameRealm()
    return self:GetCharacterKey(name, realm)
end

function DISCONTENT:GetRaidPrepDB()
    if type(_G.DISCONTENTDB) ~= "table" then
        _G.DISCONTENTDB = {}
    end

    if type(_G.DISCONTENTDB.raidPrep) ~= "table" then
        _G.DISCONTENTDB.raidPrep = {}
    end

    if type(_G.DISCONTENTDB.raidPrep.characters) ~= "table" then
        _G.DISCONTENTDB.raidPrep.characters = {}
    end

    local charKey = self:GetRaidPrepCharacterKey()

    if type(_G.DISCONTENTDB.raidPrep.characters[charKey]) ~= "table" then
        _G.DISCONTENTDB.raidPrep.characters[charKey] = {}
    end

    if type(_G.DISCONTENTDB.raidPrep.characters[charKey].checked) ~= "table" then
        _G.DISCONTENTDB.raidPrep.characters[charKey].checked = {}
    end

    return _G.DISCONTENTDB.raidPrep.characters[charKey]
end

function DISCONTENT:GetRaidPrepCheckedTable()
    local db = self:GetRaidPrepDB()
    return db.checked
end

function DISCONTENT:GetRaidPrepTotalCount()
    local total = 0

    for _, category in ipairs(self:GetRaidPrepChecklist()) do
        total = total + #(category.items or {})
    end

    return total
end

function DISCONTENT:GetRaidPrepCheckedCount()
    local checked = 0
    local checkedTable = self:GetRaidPrepCheckedTable()

    for _, isChecked in pairs(checkedTable) do
        if isChecked then
            checked = checked + 1
        end
    end

    return checked
end

function DISCONTENT:GetRaidPrepItemKey(categoryIndex, itemIndex)
    return tostring(categoryIndex) .. ":" .. tostring(itemIndex)
end

function DISCONTENT:IsRaidPrepItemChecked(categoryIndex, itemIndex)
    local checkedTable = self:GetRaidPrepCheckedTable()
    return checkedTable[self:GetRaidPrepItemKey(categoryIndex, itemIndex)] and true or false
end

function DISCONTENT:SetRaidPrepItemChecked(categoryIndex, itemIndex, value)
    local db = self:GetRaidPrepDB()
    db.checked[self:GetRaidPrepItemKey(categoryIndex, itemIndex)] = value and true or false
    db.updatedAt = time()

    self:SaveSettings()
end

function DISCONTENT:GetRaidPrepProgressInfo()
    local total = self:GetRaidPrepTotalCount()
    local checked = self:GetRaidPrepCheckedCount()
    local percent = 0

    if total > 0 then
        percent = checked / total
    end

    return checked, total, percent
end

function DISCONTENT:GetRaidPrepProgressColor(percent)
    if percent >= 1 then
        return 0.15, 0.85, 0.25
    elseif percent >= 0.70 then
        return 0.35, 0.85, 0.25
    elseif percent >= 0.40 then
        return 0.95, 0.75, 0.20
    else
        return 0.85, 0.25, 0.25
    end
end

function DISCONTENT:GetRaidPrepStatusText(checked, total, percent)
    local missing = math.max(0, total - checked)

    if total == 0 then
        return "Keine Einträge vorhanden."
    elseif percent >= 1 then
        return "Raid Ready - JA"
    elseif checked == 0 then
        return "Noch nichts erledigt."
    else
        return "Noch " .. tostring(missing) .. " Punkte offen"
    end
end

function DISCONTENT:ResetRaidPrepChecklist()
    local db = self:GetRaidPrepDB()
    db.checked = {}
    db.updatedAt = time()

    if self.raidPrepSections then
        for _, section in ipairs(self.raidPrepSections) do
            for _, row in ipairs(section.rows or {}) do
                if row.checkbox then
                    row.checkbox:SetChecked(false)
                end
            end
        end
    end

    self:SaveSettings()
    self:RefreshRaidPrepUI()
end

function DISCONTENT:UpdateRaidPrepProgress()
    if not self.raidPrepProgressBar then
        return
    end

    local checked, total, percent = self:GetRaidPrepProgressInfo()
    local r, g, b = self:GetRaidPrepProgressColor(percent)

    self.raidPrepProgressBar:SetMinMaxValues(0, 1)
    self.raidPrepProgressBar:SetValue(percent)
    self.raidPrepProgressBar:SetStatusBarColor(r, g, b)

    if self.raidPrepProgressText then
        self.raidPrepProgressText:SetText(string.format("%d / %d erledigt", checked, total))
        self.raidPrepProgressText:SetTextColor(r, g, b)
    end

    if self.raidPrepStatusText then
        self.raidPrepStatusText:SetText(self:GetRaidPrepStatusText(checked, total, percent))
        self.raidPrepStatusText:SetTextColor(r, g, b)
    end

    if self.raidPrepPercentText then
        self.raidPrepPercentText:SetText(string.format("%d%%", math.floor((percent * 100) + 0.5)))
        self.raidPrepPercentText:SetTextColor(r, g, b)
    end

    if self.raidPrepReadyIndicator then
        if total > 0 and checked >= total then
            self.raidPrepReadyIndicator:SetText("YES")
            self.raidPrepReadyIndicator:SetTextColor(r, g, b)
            self.raidPrepReadyIndicator:Show()
        else
            self.raidPrepReadyIndicator:SetText("")
            self.raidPrepReadyIndicator:Hide()
        end
    end
end

function DISCONTENT:RefreshRaidPrepUI()
    if not self.uiCreated or not self.raidPrepTabContent then
        return
    end

    local totalHeight = 0
    local width = math.max(300, (self.raidPrepScrollFrame and self.raidPrepScrollFrame:GetWidth() or 900) - 28)

    if self.raidPrepCharacterText then
        local name, realm = self:GetPlayerNameRealm()
        self.raidPrepCharacterText:SetText("Aktiver Charakter: " .. tostring(name or "?") .. " - " .. tostring(realm or "?"))
    end

    if self.raidPrepSections then
        for _, section in ipairs(self.raidPrepSections) do
            section:ClearAllPoints()
            section:SetPoint("TOPLEFT", self.raidPrepScrollChild, "TOPLEFT", 0, -totalHeight)
            section:SetWidth(width)

            if section.title then
                section.title:SetWidth(width - 24)
            end

            local currentY = 44
            local maxRowWidth = width - 24
            local textWidth = math.max(120, maxRowWidth - 40)

            for _, row in ipairs(section.rows or {}) do
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", section, "TOPLEFT", 12, -currentY)
                row:SetWidth(maxRowWidth)

                if row.checkbox then
                    row.checkbox:ClearAllPoints()
                    row.checkbox:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -2)
                    row.checkbox:SetChecked(self:IsRaidPrepItemChecked(row.categoryIndex, row.itemIndex))
                end

                if row.label then
                    row.label:ClearAllPoints()
                    row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 34, -4)
                    row.label:SetWidth(textWidth)
                end

                local labelHeight = math.max(18, math.ceil((row.label and row.label:GetStringHeight() or 18)))
                local rowHeight = math.max(28, labelHeight + 10)
                row:SetHeight(rowHeight)

                currentY = currentY + rowHeight + 6
            end

            local sectionHeight = currentY + 12
            section:SetHeight(sectionHeight)
            totalHeight = totalHeight + sectionHeight + 14
        end
    end

    self.raidPrepScrollChild:SetSize(width, math.max(totalHeight + 10, 200))
    self:UpdateRaidPrepProgress()
end

function DISCONTENT:CreateRaidPrepSection(parent, categoryIndex, categoryData)
    local section = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    section:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8X8",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
    })
    section:SetBackdropColor(0.08, 0.08, 0.08, 0.60)
    section:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.85)

    section.title = section:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    section.title:SetPoint("TOPLEFT", 12, -12)
    section.title:SetJustifyH("LEFT")
    section.title:SetText(categoryData.category or ("Kategorie " .. tostring(categoryIndex)))

    section.rows = {}

    local items = categoryData.items or {}

    for itemIndex = 1, #items do
        local itemText = items[itemIndex]

        local row = CreateFrame("Frame", nil, section)
        row:SetHeight(28)

        if itemIndex % 2 == 0 then
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            row.bg:SetColorTexture(1, 1, 1, 0.03)
        end

        local checkbox = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        checkbox:SetSize(24, 24)

        local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetJustifyH("LEFT")
        label:SetJustifyV("TOP")
        label:SetSpacing(2)
        label:SetWordWrap(true)
        label:SetText(itemText)

        row.categoryIndex = categoryIndex
        row.itemIndex = itemIndex
        row.checkbox = checkbox
        row.label = label
        row.itemText = itemText

        checkbox:SetChecked(self:IsRaidPrepItemChecked(categoryIndex, itemIndex))
        checkbox:SetScript("OnClick", function(btn)
            DISCONTENT:SetRaidPrepItemChecked(categoryIndex, itemIndex, btn:GetChecked())
            DISCONTENT:RefreshRaidPrepUI()
        end)

        section.rows[#section.rows + 1] = row
    end

    return section
end

function DISCONTENT:CreateRaidPrepUI()
    self.raidPrepTitle = self.raidPrepTabContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.raidPrepTitle:SetText("Raid-Prep")

    self.raidPrepSubtitle = self.raidPrepTabContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.raidPrepSubtitle:SetJustifyH("LEFT")
    self.raidPrepSubtitle:SetText("Deine persönliche Vorbereitung für den nächsten Raid. Diese Checkliste wird lokal und charakterbezogen gespeichert.")

    self.raidPrepCharacterText = self.raidPrepTabContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.raidPrepCharacterText:SetJustifyH("LEFT")
    self.raidPrepCharacterText:SetText("Aktiver Charakter: -")

    self.raidPrepStatusBox = CreateFrame("Frame", nil, self.raidPrepTabContent, "BackdropTemplate")
    self.raidPrepStatusBox:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8X8",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
    })
    self.raidPrepStatusBox:SetBackdropColor(0.08, 0.08, 0.08, 0.55)
    self.raidPrepStatusBox:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.85)

    self.raidPrepProgressLabel = self.raidPrepStatusBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.raidPrepProgressLabel:SetPoint("TOPLEFT", 14, -12)
    self.raidPrepProgressLabel:SetText("Raid-Status")

    self.raidPrepPercentText = self.raidPrepStatusBox:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.raidPrepPercentText:SetPoint("TOPRIGHT", -14, -10)
    self.raidPrepPercentText:SetText("0%")

    self.raidPrepProgressBar = CreateFrame("StatusBar", nil, self.raidPrepStatusBox)
    self.raidPrepProgressBar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
    self.raidPrepProgressBar:SetMinMaxValues(0, 1)
    self.raidPrepProgressBar:SetValue(0)

    self.raidPrepProgressBar.bg = self.raidPrepProgressBar:CreateTexture(nil, "BACKGROUND")
    self.raidPrepProgressBar.bg:SetAllPoints()
    self.raidPrepProgressBar.bg:SetColorTexture(0.15, 0.15, 0.15, 0.95)

    self.raidPrepProgressBar.border = CreateFrame("Frame", nil, self.raidPrepProgressBar, "BackdropTemplate")
    self.raidPrepProgressBar.border:SetAllPoints()
    self.raidPrepProgressBar.border:SetBackdrop({
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
    })
    self.raidPrepProgressBar.border:SetBackdropBorderColor(0.30, 0.30, 0.30, 0.90)

    self.raidPrepProgressText = self.raidPrepStatusBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.raidPrepProgressText:SetJustifyH("LEFT")
    self.raidPrepProgressText:SetText("0 / 0 erledigt")

    self.raidPrepStatusText = self.raidPrepStatusBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.raidPrepStatusText:SetJustifyH("LEFT")
    self.raidPrepStatusText:SetText("Noch nichts erledigt.")

    self.raidPrepReadyIndicator = self.raidPrepStatusBox:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.raidPrepReadyIndicator:SetPoint("LEFT", self.raidPrepStatusText, "RIGHT", 10, 0)
    self.raidPrepReadyIndicator:SetText("")
    self.raidPrepReadyIndicator:Hide()

    self.raidPrepResetButton = CreateFrame("Button", nil, self.raidPrepTabContent, "UIPanelButtonTemplate")
    self.raidPrepResetButton:SetSize(180, 24)
    self.raidPrepResetButton:SetText("Checkliste zurücksetzen")
    self.raidPrepResetButton:SetScript("OnClick", function()
        DISCONTENT:ResetRaidPrepChecklist()
    end)

    self.raidPrepScrollFrame = CreateFrame("ScrollFrame", "DISCONTENTRaidPrepScrollFrame", self.raidPrepTabContent, "UIPanelScrollFrameTemplate")
    self.raidPrepScrollChild = CreateFrame("Frame", nil, self.raidPrepScrollFrame)
    self.raidPrepScrollFrame:SetScrollChild(self.raidPrepScrollChild)

    self.raidPrepSections = {}

    local checklist = self:GetRaidPrepChecklist()
    for categoryIndex = 1, #checklist do
        local section = self:CreateRaidPrepSection(self.raidPrepScrollChild, categoryIndex, checklist[categoryIndex])
        self.raidPrepSections[#self.raidPrepSections + 1] = section
    end
end

function DISCONTENT:UpdateRaidPrepLayout()
    if not self.raidPrepTabContent then
        return
    end

    self.raidPrepTabContent:ClearAllPoints()
    self.raidPrepTabContent:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -70)
    self.raidPrepTabContent:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)

    self.raidPrepTitle:ClearAllPoints()
    self.raidPrepTitle:SetPoint("TOPLEFT", self.raidPrepTabContent, "TOPLEFT", 16, -12)

    self.raidPrepSubtitle:ClearAllPoints()
    self.raidPrepSubtitle:SetPoint("TOPLEFT", self.raidPrepTabContent, "TOPLEFT", 16, -40)
    self.raidPrepSubtitle:SetPoint("TOPRIGHT", self.raidPrepTabContent, "TOPRIGHT", -16, -40)

    self.raidPrepCharacterText:ClearAllPoints()
    self.raidPrepCharacterText:SetPoint("TOPLEFT", self.raidPrepTabContent, "TOPLEFT", 16, -60)

    self.raidPrepStatusBox:ClearAllPoints()
    self.raidPrepStatusBox:SetPoint("TOPLEFT", self.raidPrepTabContent, "TOPLEFT", 16, -82)
    self.raidPrepStatusBox:SetPoint("TOPRIGHT", self.raidPrepTabContent, "TOPRIGHT", -16, -82)
    self.raidPrepStatusBox:SetHeight(88)

    self.raidPrepProgressBar:ClearAllPoints()
    self.raidPrepProgressBar:SetPoint("TOPLEFT", self.raidPrepStatusBox, "TOPLEFT", 14, -34)
    self.raidPrepProgressBar:SetPoint("TOPRIGHT", self.raidPrepStatusBox, "TOPRIGHT", -14, -34)
    self.raidPrepProgressBar:SetHeight(18)

    self.raidPrepProgressText:ClearAllPoints()
    self.raidPrepProgressText:SetPoint("TOPLEFT", self.raidPrepProgressBar, "BOTTOMLEFT", 0, -8)

    self.raidPrepStatusText:ClearAllPoints()
    self.raidPrepStatusText:SetPoint("TOPRIGHT", self.raidPrepProgressBar, "BOTTOMRIGHT", 0, -8)

    self.raidPrepReadyIndicator:ClearAllPoints()
    self.raidPrepReadyIndicator:SetPoint("LEFT", self.raidPrepStatusText, "RIGHT", 10, 0)

    self.raidPrepResetButton:ClearAllPoints()
    self.raidPrepResetButton:SetPoint("TOPRIGHT", self.raidPrepTabContent, "TOPRIGHT", -16, -178)

    self.raidPrepScrollFrame:ClearAllPoints()
    self.raidPrepScrollFrame:SetPoint("TOPLEFT", self.raidPrepTabContent, "TOPLEFT", 16, -212)
    self.raidPrepScrollFrame:SetPoint("BOTTOMRIGHT", self.raidPrepTabContent, "BOTTOMRIGHT", -30, 16)

    self:RefreshRaidPrepUI()
end