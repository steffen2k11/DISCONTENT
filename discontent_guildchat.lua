local DISCONTENT = _G.DISCONTENT
if not DISCONTENT then return end

function DISCONTENT:CreateGuildChatUI()
    self.guildChatPanel = CreateFrame("Frame", nil, self.guildChatTabContent, "BackdropTemplate")
    self.guildChatPanel:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    self.guildChatPanel:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    self.guildChatPanel:SetBackdropBorderColor(0.45, 0.45, 0.45, 1)

    self.chatScrollFrame = CreateFrame("ScrollFrame", "DISCONTENTGuildChatScrollFrame", self.guildChatPanel, "UIPanelScrollFrameTemplate")
    self.chatScrollChild = CreateFrame("Frame", nil, self.chatScrollFrame)
    self.chatScrollChild:SetSize(1, 1)
    self.chatScrollFrame:SetScrollChild(self.chatScrollChild)

    self.chatMessageText = self.chatScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.chatMessageText:SetPoint("TOPLEFT", 0, 0)
    self.chatMessageText:SetJustifyH("LEFT")
    self.chatMessageText:SetJustifyV("TOP")
    self.chatMessageText:SetSpacing(2)
    self.chatMessageText:SetWidth(1000)
    self.chatMessageText:SetText("")

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
end

function DISCONTENT:UpdateGuildChatLayout()
    if not self.guildChatTabContent or not self.chatScrollFrame or not self.guildChatPanel then
        return
    end

    self.guildChatTabContent:ClearAllPoints()
    self.guildChatTabContent:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -70)
    self.guildChatTabContent:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)

    self.guildChatPanel:ClearAllPoints()
    self.guildChatPanel:SetPoint("TOPLEFT", self.guildChatTabContent, "TOPLEFT", 16, -16)
    self.guildChatPanel:SetPoint("BOTTOMRIGHT", self.guildChatTabContent, "BOTTOMRIGHT", -16, 84)

    self.chatScrollFrame:ClearAllPoints()
    self.chatScrollFrame:SetPoint("TOPLEFT", self.guildChatPanel, "TOPLEFT", 10, -10)
    self.chatScrollFrame:SetPoint("BOTTOMRIGHT", self.guildChatPanel, "BOTTOMRIGHT", -30, 10)

    if self.chatScrollFrame.ScrollBar then
        self.chatScrollFrame.ScrollBar:ClearAllPoints()
        self.chatScrollFrame.ScrollBar:SetPoint("TOPLEFT", self.chatScrollFrame, "TOPRIGHT", 4, -16)
        self.chatScrollFrame.ScrollBar:SetPoint("BOTTOMLEFT", self.chatScrollFrame, "BOTTOMRIGHT", 4, 16)
    end

    self.chatInputBox:ClearAllPoints()
    self.chatInputBox:SetPoint("BOTTOMLEFT", self.guildChatTabContent, "BOTTOMLEFT", 16, 26)
    self.chatInputBox:SetPoint("BOTTOMRIGHT", self.guildChatTabContent, "BOTTOMRIGHT", -230, 26)
    self.chatInputBox:SetHeight(24)

    self.chatSendButton:ClearAllPoints()
    self.chatSendButton:SetPoint("LEFT", self.chatInputBox, "RIGHT", 10, 0)
    self.chatSendButton:SetSize(80, 24)

    self:RefreshGuildChatView()
end