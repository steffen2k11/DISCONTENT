local DISCONTENT = _G.DISCONTENT
if not DISCONTENT then return end

function DISCONTENT:CreateHeaderButton(parent, text, width, point, relativeTo, relativePoint, xOfs, yOfs, sortKey)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width, 20)
    btn:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs)
    btn.sortKey = sortKey

    btn:SetScript("OnClick", function()
        DISCONTENT:SetSortColumn(sortKey)
    end)

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    btn.text:SetPoint("LEFT", 0, 0)
    btn.text:SetJustifyH("LEFT")
    btn.text:SetText(text)

    btn.arrowText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.arrowText:SetPoint("LEFT", btn.text, "RIGHT", 6, 0)
    btn.arrowText:SetText("-")
    btn.arrowText:SetTextColor(0.55, 0.55, 0.55, 1)

    return btn
end

function DISCONTENT:CreateOnlineOnlyCheckbox()
    local check = CreateFrame("CheckButton", nil, self.overviewTabContent)
    check:SetSize(18, 18)

    check.box = check:CreateTexture(nil, "BORDER")
    check.box:SetSize(14, 14)
    check.box:SetPoint("LEFT", 0, 0)
    check.box:SetColorTexture(0.15, 0.15, 0.15, 1)

    check.border = CreateFrame("Frame", nil, check, "BackdropTemplate")
    check.border:SetPoint("TOPLEFT", check.box, -2, 2)
    check.border:SetPoint("BOTTOMRIGHT", check.box, 2, -2)
    check.border:SetBackdrop({
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
    })
    check.border:SetBackdropBorderColor(0.65, 0.65, 0.65, 1)

    check.tick = check:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    check.tick:SetPoint("CENTER", check.box, "CENTER", 0, 0)
    check.tick:SetText("X")
    check.tick:SetTextColor(1, 0.82, 0, 1)
    check.tick:Hide()

    check.label = check:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    check.label:SetPoint("LEFT", check.box, "RIGHT", 8, 0)
    check.label:SetText("nur online")

    check:SetScript("OnClick", function(btn)
        DISCONTENT.onlineOnly = not DISCONTENT.onlineOnly
        if DISCONTENT.onlineOnly then
            btn.tick:Show()
        else
            btn.tick:Hide()
        end

        DISCONTENT.scrollOffset = 0
        DISCONTENT:ApplyFilterAndSort()
        DISCONTENT:UpdateRows()
    end)

    check:SetScript("OnEnter", function(btn)
        btn.label:SetTextColor(1, 0.82, 0)
    end)

    check:SetScript("OnLeave", function(btn)
        btn.label:SetTextColor(1, 1, 1)
    end)

    self.onlineOnlyCheck = check
end

function DISCONTENT:GetAddonStatusInfo(member)
    if not member then
        return 0.5, 0.5, 0.5, "Addon unbekannt"
    end

    local key = self:GetCharacterKey(member.name, member.realm)
    local info = self.addonUsers and self.addonUsers[key]

    if not info then
        return 0.45, 0.45, 0.45, "Addon nicht erkannt"
    end

    if info.version and info.version ~= self.addonVersion then
        return 1.0, 0.82, 0.0, "Addon erkannt - andere Version: " .. tostring(info.version)
    end

    return 0.2, 1.0, 0.2, "Addon erkannt - Version " .. tostring(info.version or "?")
end

function DISCONTENT:CreateOverviewUI()
    self.filterLabel = self.overviewTabContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.filterLabel:SetText("Rang:")

    self.rankDropdown = CreateFrame("Frame", "DISCONTENTRankDropdown", self.overviewTabContent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(self.rankDropdown, 150)
    UIDropDownMenu_SetText(self.rankDropdown, "ALLE")

    self.searchLabel = self.overviewTabContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.searchLabel:SetText("Suche:")

    self.searchBox = CreateFrame("EditBox", nil, self.overviewTabContent, "InputBoxTemplate")
    self.searchBox:SetSize(180, 24)
    self.searchBox:SetAutoFocus(false)
    self.searchBox:SetScript("OnTextChanged", function(editBox)
        DISCONTENT.searchText = editBox:GetText() or ""
        DISCONTENT.scrollOffset = 0
        DISCONTENT:ApplyFilterAndSort()
        DISCONTENT:UpdateRows()
    end)

    self.refreshButton = CreateFrame("Button", nil, self.overviewTabContent, "UIPanelButtonTemplate")
    self.refreshButton:SetSize(100, 24)
    self.refreshButton:SetText("Aktualisieren")
    self.refreshButton:SetScript("OnClick", function()
        C_GuildInfo.GuildRoster()
    end)

    self.nameHeader = self:CreateHeaderButton(
        self.overviewTabContent, "Name", 180,
        "TOPLEFT", self.overviewTabContent, "TOPLEFT", 16, -52,
        "name"
    )

    self.serverHeaderButton = self:CreateHeaderButton(
        self.overviewTabContent, "Server", 130,
        "TOPLEFT", self.overviewTabContent, "TOPLEFT", 260, -52,
        "server"
    )

    self.rankHeaderButton = self:CreateHeaderButton(
        self.overviewTabContent, "Rang", 150,
        "TOPLEFT", self.overviewTabContent, "TOPLEFT", 400, -52,
        "rank"
    )

    self.levelHeaderButton = self:CreateHeaderButton(
        self.overviewTabContent, "Lvl", 45,
        "TOPLEFT", self.overviewTabContent, "TOPLEFT", 560, -52,
        "level"
    )

    self.classHeaderButton = self:CreateHeaderButton(
        self.overviewTabContent, "Klasse", 90,
        "TOPLEFT", self.overviewTabContent, "TOPLEFT", 620, -52,
        "class"
    )

    self.ilvlHeaderButton = self:CreateHeaderButton(
        self.overviewTabContent, "iLvl", 55,
        "TOPLEFT", self.overviewTabContent, "TOPLEFT", 720, -52,
        "ilvl"
    )

    self.zoneHeaderButton = self:CreateHeaderButton(
        self.overviewTabContent, "Gebiet", 150,
        "TOPLEFT", self.overviewTabContent, "TOPLEFT", 790, -52,
        "zone"
    )

    self.statusHeaderButton = self:CreateHeaderButton(
        self.overviewTabContent, "Status", 70,
        "TOPLEFT", self.overviewTabContent, "TOPLEFT", 950, -52,
        "status"
    )

    self.overviewHeaders = {
        self.nameHeader,
        self.serverHeaderButton,
        self.rankHeaderButton,
        self.levelHeaderButton,
        self.classHeaderButton,
        self.ilvlHeaderButton,
        self.zoneHeaderButton,
        self.statusHeaderButton,
    }

    self.separator = self.overviewTabContent:CreateTexture(nil, "ARTWORK")
    self.separator:SetColorTexture(1, 1, 1, 0.2)

    self.scrollBar = CreateFrame("Slider", nil, self.overviewTabContent, "UIPanelScrollBarTemplate")
    self.scrollBar:SetMinMaxValues(0, 0)
    self.scrollBar:SetValueStep(1)
    self.scrollBar:SetObeyStepOnDrag(true)
    self.scrollBar:SetWidth(16)
    self.scrollBar:SetScript("OnValueChanged", function(_, value)
        DISCONTENT.scrollOffset = math.floor(value + 0.5)
        DISCONTENT:UpdateRows()
    end)

    self.countText = self.overviewTabContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.countText:SetText("Mitglieder gesamt: 0 | Online gesamt: 0")

    self:CreateOnlineOnlyCheckbox()
end

function DISCONTENT:EnsureRowCount()
    if not self.uiCreated then return end

    local neededRows = self:GetDynamicVisibleRows()
    self.visibleRows = neededRows

    for i = #self.rows + 1, neededRows do
        local row = CreateFrame("Frame", nil, self.overviewTabContent)
        row:SetHeight(self.rowHeight)

        if i % 2 == 0 then
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            row.bg:SetColorTexture(1, 1, 1, 0.04)
        end

        row.addonStatus = CreateFrame("Frame", nil, row)
        row.addonStatus:SetSize(12, 12)

        row.addonStatus.dot = row.addonStatus:CreateTexture(nil, "OVERLAY")
        row.addonStatus.dot:SetAllPoints()
        row.addonStatus.dot:SetTexture("Interface\\Buttons\\WHITE8X8")
        row.addonStatus.dot:SetColorTexture(0.4, 0.4, 0.4, 1)

        row.addonStatus:SetScript("OnEnter", function(btn)
            if not row.member then return end

            local _, _, _, tooltipText = DISCONTENT:GetAddonStatusInfo(row.member)

            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:SetText(row.member.name or "-")
            GameTooltip:AddLine(tooltipText or "Addon unbekannt", 1, 1, 1, true)
            GameTooltip:Show()
        end)

        row.addonStatus:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        row.nameButton = CreateFrame("Button", nil, row)
        row.nameButton:SetNormalFontObject("GameFontNormal")
        row.nameButton:SetHighlightTexture("")
        row.nameButton:SetScript("OnClick", function()
            if row.member then
                DISCONTENT:ShowNotePopup(row.member)
            end
        end)
        row.nameButton:SetScript("OnEnter", function(btn)
            local fs = btn:GetFontString()
            if fs then
                fs:SetTextColor(1, 0.82, 0)
            end
        end)
        row.nameButton:SetScript("OnLeave", function(btn)
            local fs = btn:GetFontString()
            if fs then
                fs:SetTextColor(0.85, 0.92, 1)
            end
        end)

        row.inviteButton = CreateFrame("Button", nil, row)
        row.inviteButton:SetSize(16, 16)
        row.inviteButton.text = row.inviteButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.inviteButton.text:SetPoint("CENTER")
        row.inviteButton.text:SetText("+")
        row.inviteButton.text:SetTextColor(0.7, 0.7, 0.7)
        row.inviteButton:SetScript("OnClick", function()
            if row.member then
                DISCONTENT:InviteMember(row.member)
            end
        end)
        row.inviteButton:SetScript("OnEnter", function(btn)
            btn.text:SetTextColor(1, 0.82, 0)

            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:SetText("In Gruppe einladen")
            GameTooltip:Show()
        end)
        row.inviteButton:SetScript("OnLeave", function(btn)
            btn.text:SetTextColor(0.7, 0.7, 0.7)
            GameTooltip:Hide()
        end)

        row.whisperButton = CreateFrame("Button", nil, row)
        row.whisperButton:SetSize(16, 16)
        row.whisperButton.text = row.whisperButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.whisperButton.text:SetPoint("CENTER")
        row.whisperButton.text:SetText("@")
        row.whisperButton.text:SetTextColor(0.7, 0.7, 0.7)
        row.whisperButton:SetScript("OnClick", function()
            if row.member then
                DISCONTENT:WhisperMember(row.member)
            end
        end)
        row.whisperButton:SetScript("OnEnter", function(btn)
            btn.text:SetTextColor(1, 0.82, 0)

            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:SetText("Nachricht schreiben")
            GameTooltip:Show()
        end)
        row.whisperButton:SetScript("OnLeave", function(btn)
            btn.text:SetTextColor(0.7, 0.7, 0.7)
            GameTooltip:Hide()
        end)

        row.serverText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.serverText:SetJustifyH("LEFT")

        row.rankText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.rankText:SetJustifyH("LEFT")

        row.levelText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.levelText:SetJustifyH("LEFT")

        row.classText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.classText:SetJustifyH("LEFT")

        row.ilvlButton = CreateFrame("Button", nil, row)
        row.ilvlButton:SetSize(55, 18)
        row.ilvlButton:SetScript("OnClick", function()
            if row.member then
                DISCONTENT:ShowGear(row.member)
            end
        end)
        row.ilvlButton:SetScript("OnEnter", function(btn)
            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:SetText("Geardetails öffnen")
            GameTooltip:AddLine("Klick zeigt alle bekannten Items, iLvl, Enchants und Gems.", 1, 1, 1, true)
            GameTooltip:Show()

            if row.ilvlText then
                row.ilvlText:SetTextColor(1, 0.82, 0)
            end
        end)
        row.ilvlButton:SetScript("OnLeave", function()
            GameTooltip:Hide()
            if row.member then
                DISCONTENT:RefreshOverviewRowIlvl(row, row.member)
            end
        end)

        row.ilvlText = row.ilvlButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.ilvlText:SetPoint("LEFT", 0, 0)
        row.ilvlText:SetJustifyH("LEFT")

        row.zoneText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.zoneText:SetJustifyH("LEFT")

        row.statusText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.statusText:SetJustifyH("LEFT")

        self.rows[i] = row
    end
end

function DISCONTENT:RefreshOverviewRowIlvl(row, member)
    if not row or not member or not row.ilvlText then return end

    local key = self:GetCharacterKey(member.name, member.realm)
    local gearTable = self.gearData or {}
    local gear = gearTable[key]

    if gear and gear.ilvl then
        local ilvl = math.floor(tonumber(gear.ilvl) or 0)
        row.ilvlText:SetText(tostring(ilvl))
        row.ilvlText:SetTextColor(1, 1, 1)
    else
        row.ilvlText:SetText("-")
        row.ilvlText:SetTextColor(0.7, 0.7, 0.7)
    end
end

function DISCONTENT:UpdateRows()
    if not self.uiCreated then return end
    if self.activeTab ~= "overview" then return end

    self:EnsureRowCount()

    local layout = self:GetLayout()
    local startIndex = self.scrollOffset + 1

    for i = 1, self.visibleRows do
        local row = self.rows[i]
        local member = self.filteredMembers[startIndex + i - 1]

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.overviewTabContent, "TOPLEFT", layout.leftMargin, -106 - ((i - 1) * self.rowHeight))
        row:SetWidth(layout.rowWidth)
        row:SetHeight(self.rowHeight)

        row.addonStatus:ClearAllPoints()
        row.addonStatus:SetPoint("LEFT", row, "LEFT", layout.addonStatusX + 2, 0)

        row.nameButton:ClearAllPoints()
        row.nameButton:SetPoint("LEFT", row, "LEFT", layout.nameX, 0)
        row.nameButton:SetSize(layout.nameWidth, 18)

        local nameFS = row.nameButton:GetFontString()
        if nameFS then
            nameFS:SetWidth(layout.nameWidth)
            nameFS:SetJustifyH("LEFT")
        end

        row.inviteButton:ClearAllPoints()
        row.inviteButton:SetPoint("LEFT", row, "LEFT", layout.icon1X, 0)

        row.whisperButton:ClearAllPoints()
        row.whisperButton:SetPoint("LEFT", row, "LEFT", layout.icon2X, 0)

        row.serverText:ClearAllPoints()
        row.serverText:SetPoint("LEFT", row, "LEFT", layout.serverX, 0)
        row.serverText:SetWidth(layout.serverWidth)

        row.rankText:ClearAllPoints()
        row.rankText:SetPoint("LEFT", row, "LEFT", layout.rankX, 0)
        row.rankText:SetWidth(layout.rankWidth)

        row.levelText:ClearAllPoints()
        row.levelText:SetPoint("LEFT", row, "LEFT", layout.levelX, 0)
        row.levelText:SetWidth(layout.levelWidth)

        row.classText:ClearAllPoints()
        row.classText:SetPoint("LEFT", row, "LEFT", layout.classX, 0)
        row.classText:SetWidth(layout.classWidth)

        row.ilvlButton:ClearAllPoints()
        row.ilvlButton:SetPoint("LEFT", row, "LEFT", layout.ilvlX, 0)
        row.ilvlButton:SetSize(layout.ilvlWidth, 18)

        row.ilvlText:SetWidth(layout.ilvlWidth)

        row.zoneText:ClearAllPoints()
        row.zoneText:SetPoint("LEFT", row, "LEFT", layout.zoneX, 0)
        row.zoneText:SetWidth(layout.zoneWidth)

        row.statusText:ClearAllPoints()
        row.statusText:SetPoint("LEFT", row, "LEFT", layout.statusX, 0)
        row.statusText:SetWidth(layout.statusWidth)

        if member then
            row.member = member
            row.nameButton:SetText(member.name)

            if row.nameButton:GetFontString() then
                row.nameButton:GetFontString():SetTextColor(0.85, 0.92, 1)
            end

            local ar, ag, ab = self:GetAddonStatusInfo(member)
            row.addonStatus.dot:SetColorTexture(ar, ag, ab, 1)

            row:SetScript("OnEnter", nil)
            row:SetScript("OnLeave", nil)

            row.serverText:SetText(member.realm or "-")
            row.rankText:SetText(member.rankName)
            row.levelText:SetText(tostring(member.level))
            row.classText:SetText(member.className)
            row.zoneText:SetText(member.zone)
            row.statusText:SetText(member.isOnline and "Online" or "Offline")

            row.serverText:SetTextColor(0.85, 0.85, 0.85)
            row.rankText:SetTextColor(1, 1, 1)
            row.levelText:SetTextColor(1, 1, 1)
            row.zoneText:SetTextColor(0.85, 0.85, 0.85)

            if member.isOnline then
                row.statusText:SetTextColor(0.2, 1, 0.2)
            else
                row.statusText:SetTextColor(0.65, 0.65, 0.65)
            end

            local r, g, b = self:GetClassColor(member.classFileName)
            row.classText:SetTextColor(r, g, b)

            self:RefreshOverviewRowIlvl(row, member)

            row:Show()
            row.addonStatus:Show()
            row.nameButton:Show()
            row.inviteButton:Show()
            row.whisperButton:Show()
            row.ilvlButton:Show()
        else
            row.member = nil
            row:SetScript("OnEnter", nil)
            row:SetScript("OnLeave", nil)
            row:Hide()
        end
    end

    for i = self.visibleRows + 1, #self.rows do
        self.rows[i]:Hide()
    end

    local totalMembers = self:GetTotalMemberCount()
    local online = self:GetOnlineCount()
    self.countText:SetText("Mitglieder gesamt: " .. tostring(totalMembers) .. " | Online gesamt: " .. tostring(online))

    if self.onlineOnlyCheck then
        if self.onlineOnly then
            self.onlineOnlyCheck.tick:Show()
        else
            self.onlineOnlyCheck.tick:Hide()
        end
    end

    local totalFiltered = #self.filteredMembers
    local maxOffset = math.max(0, totalFiltered - self.visibleRows)

    if self.scrollOffset > maxOffset then
        self.scrollOffset = maxOffset
    end

    if totalFiltered <= self.visibleRows then
        self.scrollBar:Hide()
    else
        self.scrollBar:Show()
        self.scrollBar:SetMinMaxValues(0, maxOffset)
        self.scrollBar:SetValue(self.scrollOffset)
    end
end

function DISCONTENT:RefreshDropdown()
    if not self.uiCreated or not self.rankDropdown then return end

    UIDropDownMenu_Initialize(self.rankDropdown, function(frame, level, menuList)
        local info = UIDropDownMenu_CreateInfo()

        info.text = "ALLE"
        info.func = function()
            DISCONTENT.rankFilter = "ALLE"
            UIDropDownMenu_SetText(DISCONTENT.rankDropdown, "ALLE")
            DISCONTENT.scrollOffset = 0
            DISCONTENT:ApplyFilterAndSort()
            DISCONTENT:UpdateRows()
        end
        UIDropDownMenu_AddButton(info)

        for _, rank in ipairs(DISCONTENT:GetUniqueRanks()) do
            local rankInfo = UIDropDownMenu_CreateInfo()
            rankInfo.text = rank.name
            rankInfo.func = function()
                DISCONTENT.rankFilter = rank.name
                UIDropDownMenu_SetText(DISCONTENT.rankDropdown, rank.name)
                DISCONTENT.scrollOffset = 0
                DISCONTENT:ApplyFilterAndSort()
                DISCONTENT:UpdateRows()
            end
            UIDropDownMenu_AddButton(rankInfo)
        end
    end)

    UIDropDownMenu_SetText(self.rankDropdown, self.rankFilter or "ALLE")
end

function DISCONTENT:UpdateOverviewLayout()
    if not self.overviewTabContent then return end

    self.visibleRows = self:GetDynamicVisibleRows()
    self:EnsureRowCount()

    local layout = self:GetLayout()

    self.overviewTabContent:ClearAllPoints()
    self.overviewTabContent:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -70)
    self.overviewTabContent:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)

    self.filterLabel:ClearAllPoints()
    self.filterLabel:SetPoint("TOPLEFT", self.overviewTabContent, "TOPLEFT", 16, -10)

    self.rankDropdown:ClearAllPoints()
    self.rankDropdown:SetPoint("TOPLEFT", self.overviewTabContent, "TOPLEFT", 55, -2)

    self.searchLabel:ClearAllPoints()
    self.searchLabel:SetPoint("TOPLEFT", self.overviewTabContent, "TOPLEFT", 255, -10)

    self.searchBox:ClearAllPoints()
    self.searchBox:SetPoint("LEFT", self.searchLabel, "RIGHT", 8, 0)

    self.refreshButton:ClearAllPoints()
    self.refreshButton:SetPoint("TOPRIGHT", self.overviewTabContent, "TOPRIGHT", -18, -8)

    self.separator:ClearAllPoints()
    self.separator:SetPoint("TOPLEFT", self.overviewTabContent, "TOPLEFT", layout.leftMargin, -72)
    self.separator:SetSize(layout.usableWidth + 1, 1)

    self.nameHeader:ClearAllPoints()
    self.nameHeader:SetPoint("TOPLEFT", self.overviewTabContent, "TOPLEFT", layout.leftMargin + layout.nameX, -52)
    self.nameHeader:SetWidth(layout.serverX - layout.nameX - 10)

    self.serverHeaderButton:ClearAllPoints()
    self.serverHeaderButton:SetPoint("TOPLEFT", self.overviewTabContent, "TOPLEFT", layout.leftMargin + layout.serverX, -52)
    self.serverHeaderButton:SetWidth(layout.serverWidth)

    self.rankHeaderButton:ClearAllPoints()
    self.rankHeaderButton:SetPoint("TOPLEFT", self.overviewTabContent, "TOPLEFT", layout.leftMargin + layout.rankX, -52)
    self.rankHeaderButton:SetWidth(layout.rankWidth)

    self.levelHeaderButton:ClearAllPoints()
    self.levelHeaderButton:SetPoint("TOPLEFT", self.overviewTabContent, "TOPLEFT", layout.leftMargin + layout.levelX, -52)
    self.levelHeaderButton:SetWidth(layout.levelWidth)

    self.classHeaderButton:ClearAllPoints()
    self.classHeaderButton:SetPoint("TOPLEFT", self.overviewTabContent, "TOPLEFT", layout.leftMargin + layout.classX, -52)
    self.classHeaderButton:SetWidth(layout.classWidth)

    self.ilvlHeaderButton:ClearAllPoints()
    self.ilvlHeaderButton:SetPoint("TOPLEFT", self.overviewTabContent, "TOPLEFT", layout.leftMargin + layout.ilvlX, -52)
    self.ilvlHeaderButton:SetWidth(layout.ilvlWidth)

    self.zoneHeaderButton:ClearAllPoints()
    self.zoneHeaderButton:SetPoint("TOPLEFT", self.overviewTabContent, "TOPLEFT", layout.leftMargin + layout.zoneX, -52)
    self.zoneHeaderButton:SetWidth(layout.zoneWidth)

    self.statusHeaderButton:ClearAllPoints()
    self.statusHeaderButton:SetPoint("TOPLEFT", self.overviewTabContent, "TOPLEFT", layout.leftMargin + layout.statusX, -52)
    self.statusHeaderButton:SetWidth(layout.statusWidth)

    self.scrollBar:ClearAllPoints()
    self.scrollBar:SetPoint("TOPRIGHT", self.overviewTabContent, "TOPRIGHT", -26, -80)
    self.scrollBar:SetPoint("BOTTOMRIGHT", self.overviewTabContent, "BOTTOMRIGHT", -26, 42)

    self.countText:ClearAllPoints()
    self.countText:SetPoint("BOTTOMLEFT", self.overviewTabContent, "BOTTOMLEFT", 16, 14)

    self.onlineOnlyCheck:ClearAllPoints()
    self.onlineOnlyCheck:SetPoint("LEFT", self.countText, "RIGHT", 20, 0)
end