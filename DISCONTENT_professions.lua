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

function DISCONTENT:SanitizeCommValue(value)
    value = tostring(value or "")
    value = value:gsub("%^", "")
    value = value:gsub("\n", " ")
    value = value:gsub("\r", " ")
    return value
end

function DISCONTENT:StoreAddonUser(name, realm, version)
    if not name or name == "" then
        return
    end

    local key = self:GetCharacterKey(name, realm)
    self.addonUsers[key] = {
        name = self:SafeName(name),
        realm = realm or GetRealmName() or "-",
        version = version or "?",
        lastSeen = time(),
    }

    self:SaveSettings()

    if self.uiCreated and self.activeTab == "overview" then
        self:UpdateRows()
    end
end

function DISCONTENT:BroadcastAddonHello()
    if not IsInGuild() then
        return
    end

    local playerName, playerRealm = self:GetPlayerNameRealm()
    self:StoreAddonUser(playerName, playerRealm, self.addonVersion)

    local payload = table.concat({
        "HELLO",
        self:SanitizeCommValue(playerName),
        self:SanitizeCommValue(playerRealm),
        self:SanitizeCommValue(self.addonVersion),
    }, "^")

    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        C_ChatInfo.SendAddonMessage(self.professionSyncPrefix, payload, "GUILD")
    end
end

function DISCONTENT:GetCurrentProfessionSnapshot()
    local prof1Index, prof2Index = GetProfessions()
    local playerName, playerRealm = self:GetPlayerNameRealm()

    local function ReadProfession(index)
        if not index then
            return {
                name = "",
                skill = 0,
                maxSkill = 0,
            }
        end

        local name, _, skillLevel, maxSkillLevel = GetProfessionInfo(index)

        return {
            name = name or "",
            skill = tonumber(skillLevel) or 0,
            maxSkill = tonumber(maxSkillLevel) or 0,
        }
    end

    local p1 = ReadProfession(prof1Index)
    local p2 = ReadProfession(prof2Index)

    return {
        name = playerName,
        realm = playerRealm,
        key = self:GetCharacterKey(playerName, playerRealm),
        prof1Name = p1.name,
        prof1Skill = p1.skill,
        prof1Max = p1.maxSkill,
        prof2Name = p2.name,
        prof2Skill = p2.skill,
        prof2Max = p2.maxSkill,
        updatedAt = time(),
    }
end

function DISCONTENT:StoreProfessionEntry(entry)
    if not entry or not entry.name or entry.name == "" then
        return
    end

    local realm = entry.realm or GetRealmName() or "-"
    local key = entry.key or self:GetCharacterKey(entry.name, realm)
    local existing = self.professions[key]

    if existing and existing.updatedAt and entry.updatedAt and existing.updatedAt > entry.updatedAt then
        return
    end

    self.professions[key] = {
        key = key,
        name = self:SafeName(entry.name),
        realm = realm,
        prof1Name = entry.prof1Name or "",
        prof1Skill = tonumber(entry.prof1Skill) or 0,
        prof1Max = tonumber(entry.prof1Max) or 0,
        prof2Name = entry.prof2Name or "",
        prof2Skill = tonumber(entry.prof2Skill) or 0,
        prof2Max = tonumber(entry.prof2Max) or 0,
        updatedAt = tonumber(entry.updatedAt) or time(),
    }

    self:SaveSettings()

    if self.uiCreated and self.UpdateProfessionRows then
        self:UpdateProfessionRows()
    end
end

function DISCONTENT:BuildProfessionPayload(entry)
    return table.concat({
        "PD",
        self:SanitizeCommValue(entry.name),
        self:SanitizeCommValue(entry.realm),
        self:SanitizeCommValue(entry.prof1Name),
        tostring(entry.prof1Skill or 0),
        tostring(entry.prof1Max or 0),
        self:SanitizeCommValue(entry.prof2Name),
        tostring(entry.prof2Skill or 0),
        tostring(entry.prof2Max or 0),
        tostring(entry.updatedAt or time()),
    }, "^")
end

function DISCONTENT:BroadcastOwnProfessionData()
    if not IsInGuild() then
        return
    end

    local playerName, playerRealm = self:GetPlayerNameRealm()
    local key = self:GetCharacterKey(playerName, playerRealm)
    local entry = self.professions[key]

    if not entry then
        return
    end

    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        C_ChatInfo.SendAddonMessage(self.professionSyncPrefix, self:BuildProfessionPayload(entry), "GUILD")
    end
end

function DISCONTENT:UpdateOwnProfessionData(shouldBroadcast)
    local snapshot = self:GetCurrentProfessionSnapshot()
    self:StoreProfessionEntry(snapshot)

    if shouldBroadcast then
        self:BroadcastOwnProfessionData()
    end
end

function DISCONTENT:HandleProfessionAddonMessage(prefix, message, channel, sender)
    if prefix ~= self.professionSyncPrefix then
        return
    end

    if not message or message == "" then
        return
    end

    local parts = SplitString(message, "^")
    local msgType = parts[1]

    if msgType == "HELLO" then
        local name = parts[2] or self:SafeName(sender or "")
        local realm = parts[3] or self:SafeRealm(sender or "")
        local version = parts[4] or "?"

        self:StoreAddonUser(name, realm, version)
        return
    end

    if msgType == "PD" then
        local entry = {
            name = parts[2] or "",
            realm = parts[3] or GetRealmName() or "-",
            prof1Name = parts[4] or "",
            prof1Skill = tonumber(parts[5]) or 0,
            prof1Max = tonumber(parts[6]) or 0,
            prof2Name = parts[7] or "",
            prof2Skill = tonumber(parts[8]) or 0,
            prof2Max = tonumber(parts[9]) or 0,
            updatedAt = tonumber(parts[10]) or time(),
        }

        if entry.name and entry.name ~= "" then
            entry.key = self:GetCharacterKey(entry.name, entry.realm)
            self:StoreProfessionEntry(entry)
            self:StoreAddonUser(entry.name, entry.realm, self.addonVersion)
        end
    end
end

function DISCONTENT:FormatProfessionText(name, skill, maxSkill)
    if not name or name == "" then
        return "-"
    end

    if (tonumber(maxSkill) or 0) > 0 then
        return string.format("%s (%d/%d)", name, tonumber(skill) or 0, tonumber(maxSkill) or 0)
    end

    return string.format("%s (%d)", name, tonumber(skill) or 0)
end

function DISCONTENT:FormatUpdatedAt(timestamp)
    if not timestamp or timestamp <= 0 then
        return "-"
    end
    return date("%d.%m. %H:%M", timestamp)
end

function DISCONTENT:GetFilteredProfessionEntries()
    local entries = {}

    for _, entry in pairs(self.professions or {}) do
        table.insert(entries, entry)
    end

    table.sort(entries, function(a, b)
        local an = self:NormalizeText(a.name)
        local bn = self:NormalizeText(b.name)

        if an == bn then
            return self:NormalizeText(a.realm) < self:NormalizeText(b.realm)
        end

        return an < bn
    end)

    local search = self:NormalizeText(self.professionSearchText or "")
    if search == "" then
        return entries
    end

    local filtered = {}

    for i = 1, #entries do
        local entry = entries[i]
        local haystack = table.concat({
            self:NormalizeText(entry.name),
            self:NormalizeText(entry.realm),
            self:NormalizeText(entry.prof1Name),
            self:NormalizeText(entry.prof2Name),
        }, " ")

        if string.find(haystack, search, 1, true) then
            filtered[#filtered + 1] = entry
        end
    end

    return filtered
end

function DISCONTENT:EnsureProfessionRowCount()
    if not self.uiCreated then return end

    local neededRows = self.professionVisibleRows

    for i = #self.professionRows + 1, neededRows do
        local row = CreateFrame("Button", nil, self.professionsTabContent)
        row:SetHeight(self.professionRowHeight)
        row:RegisterForClicks("LeftButtonUp")

        if i % 2 == 0 then
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            row.bg:SetColorTexture(1, 1, 1, 0.04)
        end

        row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.nameText:SetJustifyH("LEFT")

        row.serverText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.serverText:SetJustifyH("LEFT")

        row.prof1Text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.prof1Text:SetJustifyH("LEFT")

        row.prof2Text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.prof2Text:SetJustifyH("LEFT")

        row.updatedText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.updatedText:SetJustifyH("LEFT")

        self.professionRows[i] = row
    end
end

function DISCONTENT:UpdateProfessionRows()
    if not self.uiCreated or self.activeTab ~= "professions" then
        return
    end

    self:EnsureProfessionRowCount()

    local entries = self:GetFilteredProfessionEntries()
    local startIndex = self.professionScrollOffset + 1

    local frameWidth = self:GetWidth()
    local leftMargin = 16
    local rightMargin = 42
    local usableWidth = frameWidth - leftMargin - rightMargin

    local nameWidth = math.max(130, math.floor(usableWidth * 0.18))
    local serverWidth = math.max(120, math.floor(usableWidth * 0.16))
    local prof1Width = math.max(220, math.floor(usableWidth * 0.25))
    local prof2Width = math.max(220, math.floor(usableWidth * 0.25))
    local updatedWidth = math.max(130, usableWidth - nameWidth - serverWidth - prof1Width - prof2Width - 20)

    local xName = 4
    local xServer = xName + nameWidth + 10
    local xProf1 = xServer + serverWidth + 10
    local xProf2 = xProf1 + prof1Width + 10
    local xUpdated = xProf2 + prof2Width + 10

    for i = 1, self.professionVisibleRows do
        local row = self.professionRows[i]
        local entry = entries[startIndex + i - 1]

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.professionsTabContent, "TOPLEFT", leftMargin, -132 - ((i - 1) * self.professionRowHeight))
        row:SetWidth(usableWidth)
        row:SetHeight(self.professionRowHeight)

        row.nameText:ClearAllPoints()
        row.nameText:SetPoint("LEFT", row, "LEFT", xName, 0)
        row.nameText:SetWidth(nameWidth)

        row.serverText:ClearAllPoints()
        row.serverText:SetPoint("LEFT", row, "LEFT", xServer, 0)
        row.serverText:SetWidth(serverWidth)

        row.prof1Text:ClearAllPoints()
        row.prof1Text:SetPoint("LEFT", row, "LEFT", xProf1, 0)
        row.prof1Text:SetWidth(prof1Width)

        row.prof2Text:ClearAllPoints()
        row.prof2Text:SetPoint("LEFT", row, "LEFT", xProf2, 0)
        row.prof2Text:SetWidth(prof2Width)

        row.updatedText:ClearAllPoints()
        row.updatedText:SetPoint("LEFT", row, "LEFT", xUpdated, 0)
        row.updatedText:SetWidth(updatedWidth)

        if entry then
            row.entry = entry
            row.nameText:SetText(entry.name or "-")
            row.serverText:SetText(entry.realm or "-")
            row.prof1Text:SetText(self:FormatProfessionText(entry.prof1Name, entry.prof1Skill, entry.prof1Max))
            row.prof2Text:SetText(self:FormatProfessionText(entry.prof2Name, entry.prof2Skill, entry.prof2Max))
            row.updatedText:SetText(self:FormatUpdatedAt(entry.updatedAt))

            row.nameText:SetTextColor(0.85, 0.92, 1)
            row.serverText:SetTextColor(0.82, 0.82, 0.82)
            row.prof1Text:SetTextColor(1, 1, 1)
            row.prof2Text:SetTextColor(1, 1, 1)
            row.updatedText:SetTextColor(0.75, 0.75, 0.75)

            row:Show()
        else
            row.entry = nil
            row:Hide()
        end
    end

    for i = self.professionVisibleRows + 1, #self.professionRows do
        self.professionRows[i]:Hide()
    end

    local total = #entries
    local maxOffset = math.max(0, total - self.professionVisibleRows)

    if self.professionScrollOffset > maxOffset then
        self.professionScrollOffset = maxOffset
    end

    if self.professionScrollBar then
        if total <= self.professionVisibleRows then
            self.professionScrollBar:Hide()
        else
            self.professionScrollBar:Show()
            self.professionScrollBar:SetMinMaxValues(0, maxOffset)
            self.professionScrollBar:SetValue(self.professionScrollOffset)
        end
    end

    if self.professionCountText then
        self.professionCountText:SetText("Gespeicherte Einträge: " .. tostring(total))
    end

    if self.professionStatusText then
        local playerName, playerRealm = self:GetPlayerNameRealm()
        local ownEntry = self.professions[self:GetCharacterKey(playerName, playerRealm)]

        if ownEntry then
            self.professionStatusText:SetText("Dein letzter Sync: " .. self:FormatUpdatedAt(ownEntry.updatedAt))
        else
            self.professionStatusText:SetText("Noch keine eigenen Berufsdaten gespeichert.")
        end
    end
end

function DISCONTENT:CreateProfessionsUI()
    self.professionsTitle = self.professionsTabContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.professionsTitle:SetText("Berufe")

    self.professionsSubtitle = self.professionsTabContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.professionsSubtitle:SetJustifyH("LEFT")
    self.professionsSubtitle:SetText("Jeder Client sendet seine aktuellen Berufe automatisch in die Gilde. Über den Button kannst du deinen Stand manuell erneut senden.")

    self.professionSearchLabel = self.professionsTabContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.professionSearchLabel:SetText("Suche:")

    self.professionSearchBox = CreateFrame("EditBox", nil, self.professionsTabContent, "InputBoxTemplate")
    self.professionSearchBox:SetSize(220, 24)
    self.professionSearchBox:SetAutoFocus(false)
    self.professionSearchBox:SetScript("OnTextChanged", function(editBox)
        DISCONTENT.professionSearchText = editBox:GetText() or ""
        DISCONTENT.professionScrollOffset = 0
        DISCONTENT:UpdateProfessionRows()
    end)

    self.professionSendButton = CreateFrame("Button", nil, self.professionsTabContent, "UIPanelButtonTemplate")
    self.professionSendButton:SetSize(170, 24)
    self.professionSendButton:SetText("Eigene Berufe senden")
    self.professionSendButton:SetScript("OnClick", function()
        DISCONTENT:BroadcastAddonHello()
        DISCONTENT:UpdateOwnProfessionData(true)
    end)

    self.professionStatusText = self.professionsTabContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.professionStatusText:SetJustifyH("LEFT")
    self.professionStatusText:SetText("Noch keine eigenen Berufsdaten gespeichert.")

    self.professionNameHeader = self.professionsTabContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.professionNameHeader:SetText("Name")

    self.professionServerHeader = self.professionsTabContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.professionServerHeader:SetText("Server")

    self.professionProf1Header = self.professionsTabContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.professionProf1Header:SetText("Beruf 1")

    self.professionProf2Header = self.professionsTabContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.professionProf2Header:SetText("Beruf 2")

    self.professionUpdatedHeader = self.professionsTabContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.professionUpdatedHeader:SetText("Aktualisiert")

    self.professionSeparator = self.professionsTabContent:CreateTexture(nil, "ARTWORK")
    self.professionSeparator:SetColorTexture(1, 1, 1, 0.2)

    self.professionScrollBar = CreateFrame("Slider", nil, self.professionsTabContent, "UIPanelScrollBarTemplate")
    self.professionScrollBar:SetMinMaxValues(0, 0)
    self.professionScrollBar:SetValueStep(1)
    self.professionScrollBar:SetObeyStepOnDrag(true)
    self.professionScrollBar:SetWidth(16)
    self.professionScrollBar:SetScript("OnValueChanged", function(_, value)
        DISCONTENT.professionScrollOffset = math.floor(value + 0.5)
        DISCONTENT:UpdateProfessionRows()
    end)

    self.professionCountText = self.professionsTabContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.professionCountText:SetJustifyH("LEFT")
    self.professionCountText:SetText("Gespeicherte Einträge: 0")
end

function DISCONTENT:UpdateProfessionsLayout()
    if not self.professionsTabContent then
        return
    end

    self.professionsTabContent:ClearAllPoints()
    self.professionsTabContent:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -70)
    self.professionsTabContent:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)

    self.professionsTitle:ClearAllPoints()
    self.professionsTitle:SetPoint("TOPLEFT", self.professionsTabContent, "TOPLEFT", 16, -12)

    self.professionsSubtitle:ClearAllPoints()
    self.professionsSubtitle:SetPoint("TOPLEFT", self.professionsTabContent, "TOPLEFT", 16, -40)
    self.professionsSubtitle:SetPoint("TOPRIGHT", self.professionsTabContent, "TOPRIGHT", -16, -40)

    self.professionSearchLabel:ClearAllPoints()
    self.professionSearchLabel:SetPoint("TOPLEFT", self.professionsTabContent, "TOPLEFT", 16, -74)

    self.professionSearchBox:ClearAllPoints()
    self.professionSearchBox:SetPoint("LEFT", self.professionSearchLabel, "RIGHT", 8, 0)

    self.professionSendButton:ClearAllPoints()
    self.professionSendButton:SetPoint("LEFT", self.professionSearchBox, "RIGHT", 12, 0)

    self.professionStatusText:ClearAllPoints()
    self.professionStatusText:SetPoint("TOPLEFT", self.professionsTabContent, "TOPLEFT", 16, -102)

    local frameWidth = self:GetWidth()
    local leftMargin = 16
    local rightMargin = 42
    local usableWidth = frameWidth - leftMargin - rightMargin

    local nameWidth = math.max(130, math.floor(usableWidth * 0.18))
    local serverWidth = math.max(120, math.floor(usableWidth * 0.16))
    local prof1Width = math.max(220, math.floor(usableWidth * 0.25))
    local prof2Width = math.max(220, math.floor(usableWidth * 0.25))
    local updatedWidth = math.max(130, usableWidth - nameWidth - serverWidth - prof1Width - prof2Width - 20)

    local xName = leftMargin + 4
    local xServer = xName + nameWidth + 10
    local xProf1 = xServer + serverWidth + 10
    local xProf2 = xProf1 + prof1Width + 10
    local xUpdated = xProf2 + prof2Width + 10

    self.professionNameHeader:ClearAllPoints()
    self.professionNameHeader:SetPoint("TOPLEFT", self.professionsTabContent, "TOPLEFT", xName, -122)

    self.professionServerHeader:ClearAllPoints()
    self.professionServerHeader:SetPoint("TOPLEFT", self.professionsTabContent, "TOPLEFT", xServer, -122)

    self.professionProf1Header:ClearAllPoints()
    self.professionProf1Header:SetPoint("TOPLEFT", self.professionsTabContent, "TOPLEFT", xProf1, -122)

    self.professionProf2Header:ClearAllPoints()
    self.professionProf2Header:SetPoint("TOPLEFT", self.professionsTabContent, "TOPLEFT", xProf2, -122)

    self.professionUpdatedHeader:ClearAllPoints()
    self.professionUpdatedHeader:SetPoint("TOPLEFT", self.professionsTabContent, "TOPLEFT", xUpdated, -122)

    self.professionSeparator:ClearAllPoints()
    self.professionSeparator:SetPoint("TOPLEFT", self.professionsTabContent, "TOPLEFT", leftMargin, -142)
    self.professionSeparator:SetSize(usableWidth + 1, 1)

    self.professionScrollBar:ClearAllPoints()
    self.professionScrollBar:SetPoint("TOPRIGHT", self.professionsTabContent, "TOPRIGHT", -22, -150)
    self.professionScrollBar:SetPoint("BOTTOMRIGHT", self.professionsTabContent, "BOTTOMRIGHT", -22, 42)

    self.professionCountText:ClearAllPoints()
    self.professionCountText:SetPoint("BOTTOMLEFT", self.professionsTabContent, "BOTTOMLEFT", 16, 14)

    self:UpdateProfessionRows()
end