local DISCONTENT = _G.DISCONTENT
if not DISCONTENT then return end

function DISCONTENT:GetNewsCategoryColor(category)
    local key = self:NormalizeText(category)

    if key == "raid" then
        return 1.00, 0.82, 0.00
    elseif key == "info" then
        return 0.45, 0.82, 1.00
    elseif key == "event" then
        return 0.30, 1.00, 0.50
    elseif key == "wichtig" then
        return 1.00, 0.35, 0.35
    elseif key == "allgemein" then
        return 0.85, 0.85, 0.85
    end

    return 0.85, 0.85, 0.85
end

function DISCONTENT:CreateGuildNewsUI()
    self.newsIntroText = self.guildNewsTabContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.newsIntroText:SetJustifyH("LEFT")
    self.newsIntroText:SetText("Wichtige Infos für alle Gildenmitglieder. Bitte haltet euer Addon regelmäßig aktuell.")

    self.newsPanel = CreateFrame("Frame", nil, self.guildNewsTabContent, "BackdropTemplate")
    self.newsPanel:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    self.newsPanel:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    self.newsPanel:SetBackdropBorderColor(0.45, 0.45, 0.45, 1)

    self.newsScrollFrame = CreateFrame("ScrollFrame", "DISCONTENTGuildNewsScrollFrame", self.newsPanel, "UIPanelScrollFrameTemplate")
    self.newsScrollChild = CreateFrame("Frame", nil, self.newsScrollFrame)
    self.newsScrollChild:SetSize(1, 1)
    self.newsScrollFrame:SetScrollChild(self.newsScrollChild)

    self.newsText = self.newsScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.newsText:SetPoint("TOPLEFT", 0, 0)
    self.newsText:SetJustifyH("LEFT")
    self.newsText:SetJustifyV("TOP")
    self.newsText:SetSpacing(4)
    self.newsText:SetWidth(1000)
    self.newsText:SetText("")
end

function DISCONTENT:BuildNewsMarkup()
    local entries = self:GetSortedNewsEntries()

    if not entries or #entries == 0 then
        return "|cff888888Noch keine News vorhanden.|r"
    end

    local parts = {}

    for i = 1, #entries do
        local entry = entries[i]
        local dateText = entry.dateText or "-"
        local author = entry.author or "Unbekannt"
        local title = entry.title or "Ohne Titel"
        local text = entry.text or "-"
        local category = entry.category or "Allgemein"
        local pinnedPrefix = entry.pinned and "|cffff4444[WICHTIG]|r " or ""

        local r, g, b = self:GetNewsCategoryColor(category)
        local catHex = string.format("%02x%02x%02x", math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))

        parts[#parts + 1] = string.format(
            "%s|cffd0d0d0%s|r  |cff%s[%s]|r\n|cffffd100%s|r\n|cff99ccffvon %s|r\n%s",
            pinnedPrefix,
            dateText,
            catHex,
            category,
            title,
            author,
            text
        )

        if i < #entries then
            parts[#parts + 1] = "\n\n|cff444444--------------------------------------------------|r\n"
        end
    end

    return table.concat(parts, "")
end

function DISCONTENT:RefreshNewsView()
    if not self.uiCreated or not self.newsScrollChild or not self.newsText or not self.newsScrollFrame then
        return
    end

    local markup = self:BuildNewsMarkup()
    self.newsText:SetText(markup)

    local availableWidth = math.max(100, self.newsScrollFrame:GetWidth() - 30)
    self.newsText:SetWidth(availableWidth)

    local textHeight = self.newsText:GetStringHeight() or 0
    self.newsScrollChild:SetSize(availableWidth, math.max(textHeight + 12, self.newsScrollFrame:GetHeight()))

    C_Timer.After(0, function()
        if DISCONTENT.newsScrollFrame then
            DISCONTENT.newsScrollFrame:SetVerticalScroll(0)
        end
    end)
end

function DISCONTENT:UpdateGuildNewsLayout()
    if not self.guildNewsTabContent or not self.newsPanel or not self.newsScrollFrame then
        return
    end

    self.guildNewsTabContent:ClearAllPoints()
    self.guildNewsTabContent:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -70)
    self.guildNewsTabContent:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)

    self.newsIntroText:ClearAllPoints()
    self.newsIntroText:SetPoint("TOPLEFT", self.guildNewsTabContent, "TOPLEFT", 16, -10)
    self.newsIntroText:SetPoint("TOPRIGHT", self.guildNewsTabContent, "TOPRIGHT", -16, -10)

    self.newsPanel:ClearAllPoints()
    self.newsPanel:SetPoint("TOPLEFT", self.guildNewsTabContent, "TOPLEFT", 16, -36)
    self.newsPanel:SetPoint("BOTTOMRIGHT", self.guildNewsTabContent, "BOTTOMRIGHT", -16, 20)

    self.newsScrollFrame:ClearAllPoints()
    self.newsScrollFrame:SetPoint("TOPLEFT", self.newsPanel, "TOPLEFT", 10, -10)
    self.newsScrollFrame:SetPoint("BOTTOMRIGHT", self.newsPanel, "BOTTOMRIGHT", -30, 10)

    if self.newsScrollFrame.ScrollBar then
        self.newsScrollFrame.ScrollBar:ClearAllPoints()
        self.newsScrollFrame.ScrollBar:SetPoint("TOPLEFT", self.newsScrollFrame, "TOPRIGHT", 4, -16)
        self.newsScrollFrame.ScrollBar:SetPoint("BOTTOMLEFT", self.newsScrollFrame, "BOTTOMRIGHT", 4, 16)
    end

    self:RefreshNewsView()
end