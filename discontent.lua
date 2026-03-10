local addonName = ...
local DISCONTENT = CreateFrame("Frame", "DISCONTENTFrame", UIParent)
_G.DISCONTENT = DISCONTENT

DISCONTENT.members = {}
DISCONTENT.filteredMembers = {}
DISCONTENT.guildChatMessages = {}
DISCONTENT.newsEntries = DISCONTENT.newsEntries or {}

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

DISCONTENT.professionSyncPrefix = "DISCPROF"
DISCONTENT.professions = {}
DISCONTENT.professionRows = {}
DISCONTENT.professionVisibleRows = 14
DISCONTENT.professionRowHeight = 22
DISCONTENT.professionScrollOffset = 0
DISCONTENT.professionSearchText = ""

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

    if type(self.db.professions) ~= "table" then
        self.db.professions = {}
    end

    self.professions = self.db.professions
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
    self.db.professions = self.professions or {}
end

function DISCONTENT:GetSortedNewsEntries()
    local entries = {}

    if self.newsEntries then
        for i = 1, #self.newsEntries do
            entries[#entries + 1] = self.newsEntries[i]
        end
    end

    table.sort(entries, function(a, b)
        local aPinned = a.pinned and 1 or 0
        local bPinned = b.pinned and 1 or 0

        if aPinned ~= bPinned then
            return aPinned > bPinned
        end

        local at = a.timestamp or 0
        local bt = b.timestamp or 0
        if at ~= bt then
            return at > bt
        end

        return (a.id or 0) > (b.id or 0)
    end)

    return entries
end

function DISCONTENT:ResetWindow()
    self:ClearAllPoints()
    self:SetPoint("CENTER")
    self:SetSize(self.defaultWidth, self.defaultHeight)

    self.uiScaleValue = self.defaultScale
    self.pendingScaleValue = self.defaultScale
    self.backgroundAlpha = self.defaultBackgroundAlpha
    self.pendingBackgroundAlpha = self.defaultBackgroundAlpha

    self:SetScale(self.uiScaleValue)

    if self.bg then
        self.bg:SetColorTexture(0, 0, 0, self.backgroundAlpha)
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
    local frameWidth = self:GetWidth()

    local leftMargin = 16
    local rightMargin = 46
    local usableWidth = frameWidth - leftMargin - rightMargin

    local levelWidth = 45
    local statusWidth = 70
    local iconAreaWidth = 44

    local nameWidth = math.max(120, math.floor(usableWidth * 0.16))
    local serverWidth = math.max(110, math.floor(usableWidth * 0.14))
    local rankWidth = math.max(120, math.floor(usableWidth * 0.16))
    local classWidth = math.max(95, math.floor(usableWidth * 0.12))
    local zoneWidth = math.max(170, usableWidth - nameWidth - iconAreaWidth - serverWidth - rankWidth - levelWidth - classWidth - statusWidth - 54)

    local nameX = 4
    local icon1X = nameX + nameWidth + 4
    local icon2X = icon1X + 20
    local serverX = icon2X + 22
    local rankX = serverX + serverWidth + 10
    local levelX = rankX + rankWidth + 10
    local classX = levelX + levelWidth + 10
    local zoneX = classX + classWidth + 10
    local statusX = zoneX + zoneWidth + 10

    return {
        leftMargin = leftMargin,
        rightMargin = rightMargin,
        usableWidth = usableWidth,
        rowWidth = usableWidth,
        nameWidth = nameWidth,
        iconAreaWidth = iconAreaWidth,
        serverWidth = serverWidth,
        rankWidth = rankWidth,
        levelWidth = levelWidth,
        classWidth = classWidth,
        zoneWidth = zoneWidth,
        statusWidth = statusWidth,
        nameX = nameX,
        icon1X = icon1X,
        icon2X = icon2X,
        serverX = serverX,
        rankX = rankX,
        levelX = levelX,
        classX = classX,
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
        return member.level or 0
    elseif column == "class" then
        return self:NormalizeText(member.className)
    elseif column == "zone" then
        return self:NormalizeText(member.zone)
    elseif column == "status" then
        return member.isOnline and 1 or 0
    end

    return ""
end

function DISCONTENT:SetSortColumn(column)
    if self.sortColumn == column then
        self.sortAscending = not self.sortAscending
    else
        self.sortColumn = column
        self.sortAscending = true
    end

    self.scrollOffset = 0
    self:ApplyFilterAndSort()
    self:UpdateHeaderIndicators()
    self:UpdateRows()
end

function DISCONTENT:UpdateHeaderIndicators()
    if not self.uiCreated then return end
    if not self.overviewHeaders then return end

    for _, header in ipairs(self.overviewHeaders) do
        if header and header.arrowText then
            if header.sortKey == self.sortColumn then
                header.arrowText:SetText(self.sortAscending and "▲" or "▼")
                header.arrowText:SetTextColor(1, 0.82, 0, 1)
            else
                header.arrowText:SetText("--")
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
    if not self.uiCreated or not self.chatScrollChild or not self.chatMessageText or not self.chatScrollFrame then
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

    SendChatMessage(text, "GUILD")
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

function DISCONTENT:SetActiveTab(tabKey)
    self.activeTab = tabKey

    if self.guildNewsTabContent then
        self.guildNewsTabContent:Hide()
    end
    if self.overviewTabContent then
        self.overviewTabContent:Hide()
    end
    if self.guildChatTabContent then
        self.guildChatTabContent:Hide()
    end
    if self.professionsTabContent then
        self.professionsTabContent:Hide()
    end
    if self.settingsTabContent then
        self.settingsTabContent:Hide()
    end

    if tabKey == "guildnews" then
        self.guildNewsTabContent:Show()
        if self.scrollBar then
            self.scrollBar:Hide()
        end
        if self.RefreshNewsView then
            self:RefreshNewsView()
        end
    elseif tabKey == "overview" then
        self.overviewTabContent:Show()
        if self.scrollBar then
            self.scrollBar:Show()
        end
    elseif tabKey == "guildchat" then
        self.guildChatTabContent:Show()
        if self.scrollBar then
            self.scrollBar:Hide()
        end
        self:RefreshGuildChatView()
        if self.chatInputBox then
            self.chatInputBox:ClearFocus()
        end
    elseif tabKey == "professions" then
        self.professionsTabContent:Show()
        if self.scrollBar then
            self.scrollBar:Hide()
        end
        if self.UpdateProfessionRows then
            self:UpdateProfessionRows()
        end
    elseif tabKey == "settings" then
        self.settingsTabContent:Show()
        if self.scrollBar then
            self.scrollBar:Hide()
        end
    end

    if self.guildNewsTabButton then
        self.guildNewsTabButton:SetEnabled(tabKey ~= "guildnews")
    end
    if self.overviewTabButton then
        self.overviewTabButton:SetEnabled(tabKey ~= "overview")
    end
    if self.guildChatTabButton then
        self.guildChatTabButton:SetEnabled(tabKey ~= "guildchat")
    end
    if self.professionsTabButton then
        self.professionsTabButton:SetEnabled(tabKey ~= "professions")
    end
    if self.settingsTabButton then
        self.settingsTabButton:SetEnabled(tabKey ~= "settings")
    end

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
    popup.publicNoteText:SetPoint("TOPLEFT", 18, -112)
    popup.publicNoteText:SetWidth(380)
    popup.publicNoteText:SetJustifyH("LEFT")
    popup.publicNoteText:SetJustifyV("TOP")
    popup.publicNoteText:SetText("-")

    popup.officerNoteLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    popup.officerNoteLabel:SetPoint("TOPLEFT", 18, -168)
    popup.officerNoteLabel:SetText("Officer Note:")

    popup.officerNoteText = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    popup.officerNoteText:SetPoint("TOPLEFT", 18, -188)
    popup.officerNoteText:SetWidth(380)
    popup.officerNoteText:SetJustifyH("LEFT")
    popup.officerNoteText:SetJustifyV("TOP")
    popup.officerNoteText:SetText("-")

    self.notePopup = popup
end

function DISCONTENT:ApplyPendingScale()
    local newScale = self.pendingScaleValue or self.uiScaleValue or 1.0
    self.uiScaleValue = newScale
    self:SetScale(newScale)

    if self.scaleSlider and self.scaleSlider.Text then
        self.scaleSlider.Text:SetText("Scale " .. tostring(math.floor(newScale * 100 + 0.5)) .. "%")
    end

    self:SaveSettings()
end

function DISCONTENT:ApplyPendingBackgroundAlpha()
    local newAlpha = self.pendingBackgroundAlpha or self.backgroundAlpha or 0.88
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

    if self.UpdateGuildNewsLayout then
        self:UpdateGuildNewsLayout()
    end

    if self.UpdateOverviewLayout then
        self:UpdateOverviewLayout()
    end

    if self.UpdateGuildChatLayout then
        self:UpdateGuildChatLayout()
    end

    if self.UpdateProfessionsLayout then
        self:UpdateProfessionsLayout()
    end

    if self.UpdateSettingsLayout then
        self:UpdateSettingsLayout()
    end
end

function DISCONTENT:RefreshData()
    self:CollectGuildMembers()

    if not self.uiCreated then
        return
    end

    self.visibleRows = self:GetDynamicVisibleRows()
    self:ApplyFilterAndSort()

    if self.RefreshDropdown then
        self:RefreshDropdown()
    end

    self:UpdateHeaderIndicators()
    self:UpdateRows()
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

    self.guildNewsTabButton = self:CreateTabButton(self, "Gilden-News", "TOPLEFT", self, "TOPLEFT", 16, -42, "guildnews")
    self.overviewTabButton = self:CreateTabButton(self, "Overview", "LEFT", self.guildNewsTabButton, "RIGHT", 8, 0, "overview")
    self.guildChatTabButton = self:CreateTabButton(self, "Gildenchat", "LEFT", self.overviewTabButton, "RIGHT", 8, 0, "guildchat")
    self.professionsTabButton = self:CreateTabButton(self, "Berufe", "LEFT", self.guildChatTabButton, "RIGHT", 8, 0, "professions")
    self.settingsTabButton = self:CreateTabButton(self, "Einstellungen", "LEFT", self.professionsTabButton, "RIGHT", 8, 0, "settings")

    self.guildNewsTabContent = CreateFrame("Frame", nil, self)
    self.overviewTabContent = CreateFrame("Frame", nil, self)
    self.guildChatTabContent = CreateFrame("Frame", nil, self)
    self.professionsTabContent = CreateFrame("Frame", nil, self)
    self.settingsTabContent = CreateFrame("Frame", nil, self)

    if self.CreateGuildNewsUI then
        self:CreateGuildNewsUI()
    end

    if self.CreateOverviewUI then
        self:CreateOverviewUI()
    end

    if self.CreateGuildChatUI then
        self:CreateGuildChatUI()
    end

    if self.CreateProfessionsUI then
        self:CreateProfessionsUI()
    end

    if self.CreateSettingsUI then
        self:CreateSettingsUI()
    end

    self:CreateNotePopup()

    SLASH_DISCONTENT1 = "/discontent"
    SlashCmdList["DISCONTENT"] = function()
        if DISCONTENT:IsShown() then
            DISCONTENT:Hide()
        else
            DISCONTENT:Show()
            C_GuildInfo.GuildRoster()
        end
    end

    SLASH_DISCONTENTRESET1 = "/discontentreset"
    SlashCmdList["DISCONTENTRESET"] = function()
        DISCONTENT:ResetWindow()
        if not DISCONTENT:IsShown() then
            DISCONTENT:Show()
        end
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
            end

            self:CreateUI()
        end
    elseif event == "PLAYER_LOGIN" then
        if not self.uiCreated then
            self:CreateUI()
        end

        self:Show()

        if IsInGuild() then
            C_GuildInfo.GuildRoster()
        end

        if self.UpdateOwnProfessionData then
            C_Timer.After(2, function()
                if DISCONTENT.UpdateOwnProfessionData then
                    DISCONTENT:UpdateOwnProfessionData(true)
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
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        if self.HandleProfessionAddonMessage then
            self:HandleProfessionAddonMessage(prefix, message, channel, sender)
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
DISCONTENT:RegisterEvent("CHAT_MSG_ADDON")
DISCONTENT:RegisterEvent("SKILL_LINES_CHANGED")