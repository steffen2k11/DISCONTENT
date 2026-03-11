local DISCONTENT = _G.DISCONTENT
if not DISCONTENT then return end

DISCONTENT.chatChannels = {
    guild = {
        key = "guild",
        label = "Gilde",
        sendType = "GUILD",
        prefixes = {
            G = true,
        },
    },
    raid = {
        key = "raid",
        label = "Raid",
        sendType = "RAID",
        prefixes = {
            R = true,
            RL = true,
            RW = true,
            I = true,
            IL = true,
        },
    },
    officer = {
        key = "officer",
        label = "Offi",
        sendType = "OFFICER",
        prefixes = {
            O = true,
        },
    },
}

DISCONTENT.activeChatChannel = DISCONTENT.activeChatChannel or "guild"

local function HexFromRGB(r, g, b)
    r = math.floor((r or 1) * 255 + 0.5)
    g = math.floor((g or 1) * 255 + 0.5)
    b = math.floor((b or 1) * 255 + 0.5)
    return string.format("%02x%02x%02x", r, g, b)
end

function DISCONTENT:CanUseOfficerChat()
    if not IsInGuild() then
        return false
    end

    if CanEditOfficerNote and CanEditOfficerNote() then
        return true
    end

    if C_GuildInfo and C_GuildInfo.CanEditOfficerNote and C_GuildInfo.CanEditOfficerNote() then
        return true
    end

    return false
end

function DISCONTENT:CanUseRaidChat()
    if IsInRaid() then
        return true
    end

    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return true
    end

    return false
end

function DISCONTENT:GetCurrentSendChatType()
    local channelKey = self.activeChatChannel or "guild"

    if channelKey == "officer" then
        if self:CanUseOfficerChat() then
            return "OFFICER"
        end
        return "GUILD"
    end

    if channelKey == "raid" then
        if IsInRaid() then
            return "RAID"
        end

        if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
            return "INSTANCE_CHAT"
        end

        return "GUILD"
    end

    return "GUILD"
end

function DISCONTENT:GetChatChannelLabel(channelKey)
    local info = self.chatChannels and self.chatChannels[channelKey]
    return info and info.label or "?"
end

function DISCONTENT:GetChatPrefixStyle(prefix)
    if prefix == "G" then
        return "|cff40ff40[G]|r", "|TInterface\\FriendsFrame\\StatusIcon-Online:14|t"
    elseif prefix == "O" then
        return "|cffffb347[O]|r", "|TInterface\\GroupFrame\\UI-Group-AssistantIcon:14|t"
    elseif prefix == "R" then
        return "|cff66ccff[R]|r", "|TInterface\\LFGFrame\\LFG-Eye:14|t"
    elseif prefix == "RL" then
        return "|cff33aaff[RL]|r", "|TInterface\\GroupFrame\\UI-Group-LeaderIcon:14|t"
    elseif prefix == "RW" then
        return "|cffff4040[RW]|r", "|TInterface\\DialogFrame\\UI-Dialog-Icon-AlertNew:14|t"
    elseif prefix == "I" then
        return "|cffc080ff[I]|r", "|TInterface\\LFGFrame\\LFG-Eye:14|t"
    elseif prefix == "IL" then
        return "|cffb266ff[IL]|r", "|TInterface\\GroupFrame\\UI-Group-LeaderIcon:14|t"
    end

    return "|cffaaaaaa[?]|r", ""
end

function DISCONTENT:GetClassInfoByAuthor(author)
    if not author or author == "" then
        return nil
    end

    local safeAuthor = self:SafeName(author)
    local authorRealm = self:SafeRealm(author)
    local fullKey = self:GetCharacterKey(safeAuthor, authorRealm)

    for i = 1, #(self.members or {}) do
        local member = self.members[i]
        if member then
            local memberKey = self:GetCharacterKey(member.name, member.realm)

            if member.fullName == author or memberKey == fullKey or member.name == safeAuthor then
                return member.classFileName, member.className
            end
        end
    end

    return nil
end

function DISCONTENT:GetColoredAuthorName(author)
    local classFileName = self:GetClassInfoByAuthor(author)
    local safeAuthor = self:SafeName(author or "?")

    if classFileName and self.CLASS_COLORS and self.CLASS_COLORS[classFileName] then
        local c = self.CLASS_COLORS[classFileName]
        local hex = HexFromRGB(c.r, c.g, c.b)
        return "|cff" .. hex .. safeAuthor .. "|r"
    end

    return "|cff99ccff" .. safeAuthor .. "|r"
end

function DISCONTENT:SetActiveChatChannel(channelKey)
    if channelKey == "officer" and not self:CanUseOfficerChat() then
        channelKey = "guild"
    end

    if channelKey == "raid" and not self:CanUseRaidChat() then
        channelKey = "guild"
    end

    self.activeChatChannel = channelKey or "guild"

    if self.guildChatGuildButton then
        self.guildChatGuildButton:SetEnabled(self.activeChatChannel ~= "guild")
    end

    if self.guildChatRaidButton then
        local raidAvailable = self:CanUseRaidChat()
        self.guildChatRaidButton:SetEnabled(raidAvailable and self.activeChatChannel ~= "raid")
        if raidAvailable then
            self.guildChatRaidButton:Show()
        else
            self.guildChatRaidButton:Hide()
        end
    end

    if self.guildChatOfficerButton then
        local officerAvailable = self:CanUseOfficerChat()
        self.guildChatOfficerButton:SetEnabled(officerAvailable and self.activeChatChannel ~= "officer")
        if officerAvailable then
            self.guildChatOfficerButton:Show()
        else
            self.guildChatOfficerButton:Hide()
        end
    end

    if self.chatChannelStatusText then
        local sendType = self:GetCurrentSendChatType()
        local pretty = self:GetChatChannelLabel(self.activeChatChannel)

        if self.activeChatChannel == "raid" and sendType == "INSTANCE_CHAT" then
            self.chatChannelStatusText:SetText("Aktiver Kanal: " .. pretty .. " (Instanz)")
        elseif self.activeChatChannel == "raid" and sendType ~= "RAID" then
            self.chatChannelStatusText:SetText("Aktiver Kanal: Gilde (Raid nicht verfügbar)")
        elseif self.activeChatChannel == "officer" and sendType ~= "OFFICER" then
            self.chatChannelStatusText:SetText("Aktiver Kanal: Gilde (Offi nicht verfügbar)")
        else
            self.chatChannelStatusText:SetText("Aktiver Kanal: " .. pretty)
        end
    end

    self:RefreshGuildChatView()
end

function DISCONTENT:MessageMatchesActiveChatChannel(entry)
    if not entry then
        return false
    end

    local channelKey = self.activeChatChannel or "guild"
    local info = self.chatChannels and self.chatChannels[channelKey]
    if not info or not info.prefixes then
        return true
    end

    return info.prefixes[entry.prefix or ""] and true or false
end

function DISCONTENT:BuildStyledChatLine(entry)
    local prefixText, iconText = self:GetChatPrefixStyle(entry.prefix or "G")
    local authorText = self:GetColoredAuthorName(entry.author or "?")
    local timeText = "|cff7f7f7f[" .. tostring(entry.time or "--:--") .. "]|r"

    local messageText = entry.message or ""
    if entry.prefix == "RW" then
        messageText = "|cffff5555" .. messageText .. "|r"
    end

    return string.format("%s %s %s %s: %s", timeText, iconText, prefixText, authorText, messageText)
end

function DISCONTENT:CreateGuildChatUI()
    self.guildChatPanel = CreateFrame("Frame", nil, self.guildChatTabContent, "BackdropTemplate")
    self.guildChatPanel:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    self.guildChatPanel:SetBackdropColor(0.05, 0.05, 0.05, 0.92)
    self.guildChatPanel:SetBackdropBorderColor(0.45, 0.45, 0.45, 1)

    self.chatChannelLabel = self.guildChatTabContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.chatChannelLabel:SetText("Kanal:")

    self.guildChatGuildButton = CreateFrame("Button", nil, self.guildChatTabContent, "UIPanelButtonTemplate")
    self.guildChatGuildButton:SetSize(80, 22)
    self.guildChatGuildButton:SetText("Gilde")
    self.guildChatGuildButton:SetScript("OnClick", function()
        DISCONTENT:SetActiveChatChannel("guild")
    end)

    self.guildChatRaidButton = CreateFrame("Button", nil, self.guildChatTabContent, "UIPanelButtonTemplate")
    self.guildChatRaidButton:SetSize(80, 22)
    self.guildChatRaidButton:SetText("Raid")
    self.guildChatRaidButton:SetScript("OnClick", function()
        DISCONTENT:SetActiveChatChannel("raid")
    end)

    self.guildChatOfficerButton = CreateFrame("Button", nil, self.guildChatTabContent, "UIPanelButtonTemplate")
    self.guildChatOfficerButton:SetSize(80, 22)
    self.guildChatOfficerButton:SetText("Offi")
    self.guildChatOfficerButton:SetScript("OnClick", function()
        DISCONTENT:SetActiveChatChannel("officer")
    end)

    self.chatChannelStatusText = self.guildChatTabContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.chatChannelStatusText:SetJustifyH("LEFT")
    self.chatChannelStatusText:SetText("Aktiver Kanal: Gilde")

    self.chatMessageFrame = CreateFrame("ScrollingMessageFrame", "DISCONTENTGuildChatMessageFrame", self.guildChatPanel)
    self.chatMessageFrame:SetFontObject(GameFontNormal)
    self.chatMessageFrame:SetJustifyH("LEFT")
    self.chatMessageFrame:SetFading(false)
    self.chatMessageFrame:SetMaxLines(500)
    self.chatMessageFrame:SetIndentedWordWrap(true)
    self.chatMessageFrame:SetHyperlinksEnabled(true)
    self.chatMessageFrame:SetScript("OnHyperlinkClick", function(frame, link, text, button)
        if ChatFrame_OnHyperlinkShow then
            ChatFrame_OnHyperlinkShow(frame, link, text, button)
        end
    end)
    self.chatMessageFrame:SetScript("OnHyperlinkEnter", function(frame, link, text)
        if ChatFrame_OnHyperlinkEnter then
            ChatFrame_OnHyperlinkEnter(frame, link, text)
        end
    end)
    self.chatMessageFrame:SetScript("OnHyperlinkLeave", function(frame, link, text)
        if ChatFrame_OnHyperlinkLeave then
            ChatFrame_OnHyperlinkLeave(frame, link, text)
        end
    end)

    self.chatScrollBar = CreateFrame("Slider", "DISCONTENTGuildChatScrollBar", self.guildChatPanel, "UIPanelScrollBarTemplate")
    self.chatScrollBar:SetMinMaxValues(0, 0)
    self.chatScrollBar:SetValueStep(1)
    self.chatScrollBar:SetObeyStepOnDrag(true)
    self.chatScrollBar:SetScript("OnValueChanged", function(_, value)
        local maxVal = select(2, DISCONTENT.chatScrollBar:GetMinMaxValues())
        local offset = math.floor((maxVal or 0) - value + 0.5)
        DISCONTENT.chatMessageFrame:SetScrollOffset(offset)
    end)

    self.chatMessageFrame:SetScript("OnMouseWheel", function(_, delta)
        local current = DISCONTENT.chatMessageFrame:GetScrollOffset() or 0
        if delta > 0 then
            DISCONTENT.chatMessageFrame:SetScrollOffset(math.max(0, current - 2))
        else
            DISCONTENT.chatMessageFrame:SetScrollOffset(current + 2)
        end
        DISCONTENT:UpdateGuildChatScrollBar()
    end)
    self.chatMessageFrame:EnableMouseWheel(true)

    self.chatInputBox = CreateFrame("EditBox", nil, self.guildChatTabContent, "InputBoxTemplate")
    self.chatInputBox:SetAutoFocus(false)
    self.chatInputBox:SetScript("OnEnterPressed", function()
        DISCONTENT:SendGuildChatMessage()
    end)
    self.chatInputBox:SetScript("OnEscapePressed", function(editBox)
        editBox:ClearFocus()
    end)

    self.chatSendButton = CreateFrame("Button", nil, self.guildChatTabContent, "UIPanelButtonTemplate")
    self.chatSendButton:SetText("Senden")
    self.chatSendButton:SetScript("OnClick", function()
        DISCONTENT:SendGuildChatMessage()
    end)

    self:SetActiveChatChannel(self.activeChatChannel or "guild")
end

function DISCONTENT:UpdateGuildChatScrollBar()
    if not self.chatScrollBar or not self.chatMessageFrame then
        return
    end

    local maxOffset = self.chatMessageFrame:GetMaxScrollRange() or 0
    local currentOffset = self.chatMessageFrame:GetScrollOffset() or 0

    if maxOffset <= 0 then
        self.chatScrollBar:Hide()
        self.chatScrollBar:SetMinMaxValues(0, 0)
        self.chatScrollBar:SetValue(0)
        return
    end

    self.chatScrollBar:Show()
    self.chatScrollBar:SetMinMaxValues(0, maxOffset)
    self.chatScrollBar:SetValue(maxOffset - currentOffset)
end

function DISCONTENT:UpdateGuildChatLayout()
    if not self.guildChatTabContent or not self.guildChatPanel or not self.chatMessageFrame then
        return
    end

    self.guildChatTabContent:ClearAllPoints()
    self.guildChatTabContent:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -70)
    self.guildChatTabContent:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)

    self.chatChannelLabel:ClearAllPoints()
    self.chatChannelLabel:SetPoint("TOPLEFT", self.guildChatTabContent, "TOPLEFT", 16, -18)

    self.guildChatGuildButton:ClearAllPoints()
    self.guildChatGuildButton:SetPoint("LEFT", self.chatChannelLabel, "RIGHT", 8, 0)

    self.guildChatRaidButton:ClearAllPoints()
    self.guildChatRaidButton:SetPoint("LEFT", self.guildChatGuildButton, "RIGHT", 8, 0)

    self.guildChatOfficerButton:ClearAllPoints()
    self.guildChatOfficerButton:SetPoint("LEFT", self.guildChatRaidButton, "RIGHT", 8, 0)

    self.chatChannelStatusText:ClearAllPoints()
    self.chatChannelStatusText:SetPoint("LEFT", self.guildChatOfficerButton, "RIGHT", 14, 0)
    self.chatChannelStatusText:SetPoint("RIGHT", self.guildChatTabContent, "RIGHT", -16, 0)

    self.guildChatPanel:ClearAllPoints()
    self.guildChatPanel:SetPoint("TOPLEFT", self.guildChatTabContent, "TOPLEFT", 16, -46)
    self.guildChatPanel:SetPoint("BOTTOMRIGHT", self.guildChatTabContent, "BOTTOMRIGHT", -16, 84)

    self.chatMessageFrame:ClearAllPoints()
    self.chatMessageFrame:SetPoint("TOPLEFT", self.guildChatPanel, "TOPLEFT", 10, -10)
    self.chatMessageFrame:SetPoint("BOTTOMRIGHT", self.guildChatPanel, "BOTTOMRIGHT", -30, 10)

    self.chatScrollBar:ClearAllPoints()
    self.chatScrollBar:SetPoint("TOPLEFT", self.chatMessageFrame, "TOPRIGHT", 4, -16)
    self.chatScrollBar:SetPoint("BOTTOMLEFT", self.chatMessageFrame, "BOTTOMRIGHT", 4, 16)

    self.chatInputBox:ClearAllPoints()
    self.chatInputBox:SetPoint("BOTTOMLEFT", self.guildChatTabContent, "BOTTOMLEFT", 16, 26)
    self.chatInputBox:SetPoint("BOTTOMRIGHT", self.guildChatTabContent, "BOTTOMRIGHT", -230, 26)
    self.chatInputBox:SetHeight(24)

    self.chatSendButton:ClearAllPoints()
    self.chatSendButton:SetPoint("LEFT", self.chatInputBox, "RIGHT", 10, 0)
    self.chatSendButton:SetSize(80, 24)

    self:SetActiveChatChannel(self.activeChatChannel or "guild")
    self:RefreshGuildChatView()
end

function DISCONTENT:RefreshGuildChatView()
    if not self.uiCreated or not self.chatMessageFrame then
        return
    end

    local wasNearBottom = true
    local currentOffset = self.chatMessageFrame:GetScrollOffset() or 0
    if currentOffset > 4 then
        wasNearBottom = false
    end

    self.chatMessageFrame:Clear()

    for i = 1, #self.guildChatMessages do
        local entry = self.guildChatMessages[i]
        if self:MessageMatchesActiveChatChannel(entry) then
            self.chatMessageFrame:AddMessage(self:BuildStyledChatLine(entry))
        end
    end

    if wasNearBottom then
        self.chatMessageFrame:ScrollToBottom()
    end

    self:UpdateGuildChatScrollBar()
end

function DISCONTENT:SendGuildChatMessage()
    if not self.chatInputBox then return end

    local text = self.chatInputBox:GetText()
    if not text or text == "" then
        return
    end

    local chatType = self:GetCurrentSendChatType()
    SendChatMessage(text, chatType)
    self.chatInputBox:SetText("")
end