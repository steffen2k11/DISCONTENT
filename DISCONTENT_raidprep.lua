local DISCONTENT = _G.DISCONTENT
if not DISCONTENT then return end

local function SplitString(text, delimiter)
    local result = {}
    if not text or text == "" then
        return result
    end

    local start = 1
    while true do
        local delimStart, delimEnd = string.find(text, delimiter, start, true)
        if not delimStart then
            table.insert(result, string.sub(text, start))
            break
        end
        table.insert(result, string.sub(text, start, delimStart - 1))
        start = delimEnd + 1
    end

    return result
end

function DISCONTENT:GetRaidPrepChecklist()
    return self.raidPrepEntries or {}
end

function DISCONTENT:GetRaidPrepCharacterKey()
    local name, realm = self:GetPlayerNameRealm()
    return self:GetCharacterKey(name, realm)
end

function DISCONTENT:GetRaidPrepRootDB()
    if type(_G.DISCONTENTDB) ~= "table" then
        _G.DISCONTENTDB = {}
    end

    if type(_G.DISCONTENTDB.raidPrep) ~= "table" then
        _G.DISCONTENTDB.raidPrep = {}
    end

    if type(_G.DISCONTENTDB.raidPrep.characters) ~= "table" then
        _G.DISCONTENTDB.raidPrep.characters = {}
    end

    if type(_G.DISCONTENTDB.raidPrep.cycleId) ~= "number" then
        _G.DISCONTENTDB.raidPrep.cycleId = 1
    end

    if type(_G.DISCONTENTDB.raidPrep.lastCycleAt) ~= "number" then
        _G.DISCONTENTDB.raidPrep.lastCycleAt = time()
    end

    return _G.DISCONTENTDB.raidPrep
end

function DISCONTENT:GetRaidPrepDB()
    local root = self:GetRaidPrepRootDB()
    local charKey = self:GetRaidPrepCharacterKey()

    if type(root.characters[charKey]) ~= "table" then
        root.characters[charKey] = {}
    end

    if type(root.characters[charKey].checked) ~= "table" then
        root.characters[charKey].checked = {}
    end

    if type(root.characters[charKey].cycleId) ~= "number" then
        root.characters[charKey].cycleId = root.cycleId or 1
    end

    return root.characters[charKey]
end

function DISCONTENT:GetRaidPrepStatusStore()
    if type(_G.DISCONTENTDB) ~= "table" then
        _G.DISCONTENTDB = {}
    end
    if type(_G.DISCONTENTDB.raidPrepStatus) ~= "table" then
        _G.DISCONTENTDB.raidPrepStatus = {}
    end
    return _G.DISCONTENTDB.raidPrepStatus
end

function DISCONTENT:GetCurrentRaidPrepCycleId()
    local root = self:GetRaidPrepRootDB()
    return tonumber(root.cycleId) or 1
end

function DISCONTENT:GetRaidPrepCheckedTable()
    local db = self:GetRaidPrepDB()

    if tonumber(db.cycleId) ~= self:GetCurrentRaidPrepCycleId() then
        db.checked = {}
        db.cycleId = self:GetCurrentRaidPrepCycleId()
        db.updatedAt = time()
    end

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
    db.cycleId = self:GetCurrentRaidPrepCycleId()

    self:SaveSettings()
    self:BroadcastRaidPrepStatus()
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

function DISCONTENT:GetOwnRaidPrepStatusPayloadData()
    local checked, total, percent = self:GetRaidPrepProgressInfo()
    local ready = (total > 0 and checked >= total) and 1 or 0
    local name, realm = self:GetPlayerNameRealm()

    return {
        name = name,
        realm = realm,
        checked = checked,
        total = total,
        percent = percent,
        ready = ready,
        updatedAt = time(),
        cycleId = self:GetCurrentRaidPrepCycleId(),
    }
end

function DISCONTENT:ShouldAcceptRaidPrepEntry(currentEntry, incomingEntry)
    if not incomingEntry then
        return false
    end

    local currentCycle = self:GetCurrentRaidPrepCycleId()
    local incomingCycle = tonumber(incomingEntry.cycleId) or 0

    if incomingCycle ~= currentCycle then
        return false
    end

    if not currentEntry then
        return true
    end

    local currentUpdatedAt = tonumber(currentEntry.updatedAt) or 0
    local incomingUpdatedAt = tonumber(incomingEntry.updatedAt) or 0

    if incomingUpdatedAt > currentUpdatedAt then
        return true
    end

    if incomingUpdatedAt < currentUpdatedAt then
        return false
    end

    local currentReady = currentEntry.ready and 1 or 0
    local incomingReady = incomingEntry.ready and 1 or 0
    if incomingReady ~= currentReady then
        return incomingReady > currentReady
    end

    return false
end

function DISCONTENT:StoreRaidPrepStatus(name, realm, checked, total, percent, ready, updatedAt, cycleId)
    if not name or name == "" then
        return
    end

    local safeRealm = realm or GetRealmName() or "-"
    local key = self:GetCharacterKey(name, safeRealm)
    local store = self:GetRaidPrepStatusStore()

    local incomingEntry = {
        key = key,
        name = self:SafeName(name),
        realm = safeRealm,
        checked = tonumber(checked) or 0,
        total = tonumber(total) or 0,
        percent = tonumber(percent) or 0,
        ready = tonumber(ready) == 1,
        updatedAt = tonumber(updatedAt) or time(),
        cycleId = tonumber(cycleId) or self:GetCurrentRaidPrepCycleId(),
    }

    if not self:ShouldAcceptRaidPrepEntry(store[key], incomingEntry) then
        return
    end

    store[key] = incomingEntry
    self:SaveSettings()

    if self.RefreshOfficerUI then
        self:RefreshOfficerUI()
    end
end

function DISCONTENT:BuildRaidPrepStatusPayloadForData(data, command)
    return table.concat({
        command or "STATUS",
        tostring(data.name or ""),
        tostring(data.realm or ""),
        tostring(data.checked or 0),
        tostring(data.total or 0),
        string.format("%.4f", tonumber(data.percent) or 0),
        tostring(data.ready or 0),
        tostring(data.updatedAt or time()),
        tostring(data.cycleId or self:GetCurrentRaidPrepCycleId()),
    }, "^")
end

function DISCONTENT:BuildRaidPrepStatusPayload()
    local data = self:GetOwnRaidPrepStatusPayloadData()
    return self:BuildRaidPrepStatusPayloadForData(data, "STATUS")
end

function DISCONTENT:SendRaidPrepAddonMessage(message, channel, target)
    if not C_ChatInfo or not C_ChatInfo.SendAddonMessage then
        return
    end

    if channel == "WHISPER" and target and target ~= "" then
        C_ChatInfo.SendAddonMessage(self.raidPrepSyncPrefix, message, "WHISPER", target)
    else
        C_ChatInfo.SendAddonMessage(self.raidPrepSyncPrefix, message, channel or "GUILD")
    end
end

function DISCONTENT:BroadcastRaidPrepStatus()
    if not IsInGuild() then
        return
    end

    local data = self:GetOwnRaidPrepStatusPayloadData()
    self:StoreRaidPrepStatus(data.name, data.realm, data.checked, data.total, data.percent, data.ready, data.updatedAt, data.cycleId)
    self:SendRaidPrepAddonMessage(self:BuildRaidPrepStatusPayload(), "GUILD")
end

function DISCONTENT:BuildRaidPrepSyncRequestPayload()
    return table.concat({
        "REQUEST_SYNC",
        tostring(self:GetCurrentRaidPrepCycleId()),
    }, "^")
end

function DISCONTENT:RequestRaidPrepSync()
    if not IsInGuild() then
        return
    end

    self:SendRaidPrepAddonMessage(self:BuildRaidPrepSyncRequestPayload(), "GUILD")
end

function DISCONTENT:SendRaidPrepStatusEntryToTarget(entry, target)
    if not entry or not target or target == "" then
        return
    end

    self:SendRaidPrepAddonMessage(
        self:BuildRaidPrepStatusPayloadForData(entry, "SYNC_ENTRY"),
        "WHISPER",
        target
    )
end

function DISCONTENT:SendKnownRaidPrepStatusesToTarget(target)
    local store = self:GetRaidPrepStatusStore()
    local currentCycle = self:GetCurrentRaidPrepCycleId()

    for _, entry in pairs(store) do
        if entry and tonumber(entry.cycleId) == currentCycle then
            self:SendRaidPrepStatusEntryToTarget(entry, target)
        end
    end
end

function DISCONTENT:StartNewRaidPrepCycle()
    if not self:CanSeeOfficerTab() then
        return
    end

    local root = self:GetRaidPrepRootDB()
    root.cycleId = (tonumber(root.cycleId) or 1) + 1
    root.lastCycleAt = time()

    local db = self:GetRaidPrepDB()
    db.checked = {}
    db.updatedAt = time()
    db.cycleId = root.cycleId

    self:SaveSettings()
    self:PruneOldRaidPrepStatuses()
    self:BroadcastRaidPrepNewCycle()
    self:BroadcastRaidPrepStatus()

    if self.RefreshRaidPrepUI then
        self:RefreshRaidPrepUI()
    end

    if self.RefreshOfficerUI then
        self:RefreshOfficerUI()
    end
end

function DISCONTENT:BuildRaidPrepNewCyclePayload()
    local root = self:GetRaidPrepRootDB()
    local name, realm = self:GetPlayerNameRealm()

    return table.concat({
        "NEW_CYCLE",
        tostring(root.cycleId or 1),
        tostring(root.lastCycleAt or time()),
        tostring(name or ""),
        tostring(realm or ""),
    }, "^")
end

function DISCONTENT:BroadcastRaidPrepNewCycle()
    if not IsInGuild() then
        return
    end

    self:SendRaidPrepAddonMessage(self:BuildRaidPrepNewCyclePayload(), "GUILD")
end

function DISCONTENT:PruneOldRaidPrepStatuses()
    local currentCycle = self:GetCurrentRaidPrepCycleId()
    local store = self:GetRaidPrepStatusStore()

    for key, entry in pairs(store) do
        if not entry or tonumber(entry.cycleId) ~= currentCycle then
            store[key] = nil
        end
    end

    self:SaveSettings()
end

function DISCONTENT:HandleIncomingRaidPrepNewCycle(parts)
    local incomingCycle = tonumber(parts[2]) or 0
    local incomingAt = tonumber(parts[3]) or 0
    local root = self:GetRaidPrepRootDB()

    local currentCycle = tonumber(root.cycleId) or 1
    local currentAt = tonumber(root.lastCycleAt) or 0

    if incomingCycle > currentCycle or (incomingCycle == currentCycle and incomingAt > currentAt) then
        root.cycleId = incomingCycle
        root.lastCycleAt = incomingAt

        local db = self:GetRaidPrepDB()
        db.checked = {}
        db.updatedAt = time()
        db.cycleId = incomingCycle

        self:PruneOldRaidPrepStatuses()
        self:SaveSettings()

        if self.RefreshRaidPrepUI then
            self:RefreshRaidPrepUI()
        end

        if self.RefreshOfficerUI then
            self:RefreshOfficerUI()
        end
    end
end

function DISCONTENT:HandleRaidPrepAddonMessage(prefix, message, channel, sender)
    if prefix ~= self.raidPrepSyncPrefix then
        return
    end

    if not message or message == "" then
        return
    end

    local parts = SplitString(message, "^")
    local command = parts[1]

    if command == "STATUS" or command == "SYNC_ENTRY" then
        self:StoreRaidPrepStatus(
            parts[2] or self:SafeName(sender or ""),
            parts[3] or self:SafeRealm(sender or ""),
            parts[4],
            parts[5],
            parts[6],
            parts[7],
            parts[8],
            parts[9]
        )
    elseif command == "REQUEST_SYNC" then
        local requestedCycle = tonumber(parts[2]) or 0
        if requestedCycle == self:GetCurrentRaidPrepCycleId() and sender and sender ~= "" then
            self:SendKnownRaidPrepStatusesToTarget(sender)
        end
    elseif command == "NEW_CYCLE" then
        self:HandleIncomingRaidPrepNewCycle(parts)
    end
end

function DISCONTENT:ResetRaidPrepChecklist()
    local db = self:GetRaidPrepDB()
    db.checked = {}
    db.updatedAt = time()
    db.cycleId = self:GetCurrentRaidPrepCycleId()

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
    self:BroadcastRaidPrepStatus()
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

    if self.raidPrepCycleText then
        self.raidPrepCycleText:SetText("Aktueller Raidprep-Zyklus: " .. tostring(self:GetCurrentRaidPrepCycleId()))
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
    self.raidPrepSubtitle:SetText("Deine persönliche Vorbereitung für den nächsten Raid.")

    self.raidPrepCharacterText = self.raidPrepTabContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.raidPrepCharacterText:SetJustifyH("LEFT")
    self.raidPrepCharacterText:SetText("Aktiver Charakter: -")

    self.raidPrepCycleText = self.raidPrepTabContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.raidPrepCycleText:SetJustifyH("LEFT")
    self.raidPrepCycleText:SetText("Aktueller Raidprep-Zyklus: 1")

    self.raidPrepWarningBox = CreateFrame("Frame", nil, self.raidPrepTabContent, "BackdropTemplate")
    self.raidPrepWarningBox:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8X8",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
    })
    self.raidPrepWarningBox:SetBackdropColor(0.20, 0.10, 0.02, 0.90)
    self.raidPrepWarningBox:SetBackdropBorderColor(1.00, 0.65, 0.10, 0.95)

    self.raidPrepWarningTitle = self.raidPrepWarningBox:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.raidPrepWarningTitle:SetPoint("TOPLEFT", 12, -10)
    self.raidPrepWarningTitle:SetText("|cffffaa22Wichtiger Hinweis|r")

    self.raidPrepWarningText = self.raidPrepWarningBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.raidPrepWarningText:SetPoint("TOPLEFT", 12, -34)
    self.raidPrepWarningText:SetPoint("TOPRIGHT", self.raidPrepWarningBox, "TOPRIGHT", -12, -34)
    self.raidPrepWarningText:SetJustifyH("LEFT")
    self.raidPrepWarningText:SetJustifyV("TOP")
    self.raidPrepWarningText:SetWordWrap(true)
    self.raidPrepWarningText:SetText(
        "Bitte schließe deinen Raidprep vor dem Raid vollständig ab und setze ihn erst nach dem Raid wieder zurück. "
        .. "Nur so kann im Officer-Bereich spätestens während des Raids eine vollständige Liste aller vorbereiteten Mitglieder entstehen."
    )

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
    self.raidPrepResetButton:SetSize(210, 24)
    self.raidPrepResetButton:SetText("Nach dem Raid zurücksetzen")
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

    self.raidPrepCycleText:ClearAllPoints()
    self.raidPrepCycleText:SetPoint("TOPRIGHT", self.raidPrepTabContent, "TOPRIGHT", -16, -60)

    self.raidPrepWarningBox:ClearAllPoints()
    self.raidPrepWarningBox:SetPoint("TOPLEFT", self.raidPrepTabContent, "TOPLEFT", 16, -84)
    self.raidPrepWarningBox:SetPoint("TOPRIGHT", self.raidPrepTabContent, "TOPRIGHT", -16, -84)
    self.raidPrepWarningBox:SetHeight(92)

    self.raidPrepStatusBox:ClearAllPoints()
    self.raidPrepStatusBox:SetPoint("TOPLEFT", self.raidPrepTabContent, "TOPLEFT", 16, -184)
    self.raidPrepStatusBox:SetPoint("TOPRIGHT", self.raidPrepTabContent, "TOPRIGHT", -16, -184)
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
    self.raidPrepResetButton:SetPoint("TOPLEFT", self.raidPrepTabContent, "TOPLEFT", 16, -280)

    self.raidPrepScrollFrame:ClearAllPoints()
    self.raidPrepScrollFrame:SetPoint("TOPLEFT", self.raidPrepTabContent, "TOPLEFT", 16, -314)
    self.raidPrepScrollFrame:SetPoint("BOTTOMRIGHT", self.raidPrepTabContent, "BOTTOMRIGHT", -30, 16)

    self:RefreshRaidPrepUI()
end