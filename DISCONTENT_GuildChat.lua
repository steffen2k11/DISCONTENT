local DISCONTENT = _G.DISCONTENT
if not DISCONTENT then return end

DISCONTENT.chatChannels = {
    guild = {
        key = "guild",
        label = "Gilde",
        prefixes = { G = true },
    },
    raid = {
        key = "raid",
        label = "Raid",
        prefixes = { R = true, RL = true, RW = true, I = true, IL = true },
    },
    officer = {
        key = "officer",
        label = "Offi",
        prefixes = { O = true },
    },
    community = {
        key = "community",
        label = "Community",
        prefixes = { C = true },
    },
}

DISCONTENT.activeChatChannel = DISCONTENT.activeChatChannel or "guild"
DISCONTENT.communityChatMessages = DISCONTENT.communityChatMessages or {}
DISCONTENT.communityChatMessageIndex = DISCONTENT.communityChatMessageIndex or {}
DISCONTENT.communityChatStreams = DISCONTENT.communityChatStreams or {}
DISCONTENT.communityMembers = DISCONTENT.communityMembers or {}
DISCONTENT.activeCommunityKey = DISCONTENT.activeCommunityKey or nil

local COMMUNITY_PANEL_WIDTH = 280
local COMMUNITY_MEMBER_ROW_HEIGHT = 22

local function HexFromRGB(r, g, b)
    r = math.floor((r or 1) * 255 + 0.5)
    g = math.floor((g or 1) * 255 + 0.5)
    b = math.floor((b or 1) * 255 + 0.5)
    return string.format("%02x%02x%02x", r, g, b)
end

local function GetCommunityEnumValue(name, fallback)
    if Enum and Enum.ClubType and Enum.ClubType[name] ~= nil then
        return Enum.ClubType[name]
    end
    return fallback
end

local CLUB_TYPE_GUILD = GetCommunityEnumValue("Guild", 2)

function DISCONTENT:CanUseOfficerChat()
    if not self:CanSeeOfficerTab() then
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

function DISCONTENT:MakeCommunityKey(clubId, streamId)
    return tostring(clubId or "") .. ":" .. tostring(streamId or "")
end

function DISCONTENT:SplitCommunityKey(key)
    if not key then
        return nil, nil
    end

    local clubId, streamId = string.match(key, "^(.-):(.-)$")
    return clubId, streamId
end

function DISCONTENT:GetSelectedCommunityStream()
    local activeKey = self.activeCommunityKey
    if not activeKey then
        return nil
    end

    for i = 1, #(self.communityChatStreams or {}) do
        local entry = self.communityChatStreams[i]
        if entry and entry.key == activeKey then
            return entry
        end
    end

    return nil
end

function DISCONTENT:BuildCommunityDisplayName(entry)
    if not entry then
        return "Community"
    end

    if entry.streamName and entry.streamName ~= "" and entry.streamName ~= entry.clubName then
        return entry.clubName .. " - " .. entry.streamName
    end

    return entry.clubName or entry.streamName or "Community"
end

function DISCONTENT:GetCommunityChatStreams()
    local results = {}

    if not C_Club or not C_Club.GetSubscribedClubs or not C_Club.GetStreams then
        return results
    end

    local clubs = C_Club.GetSubscribedClubs() or {}
    for i = 1, #clubs do
        local clubInfo = clubs[i]
        if clubInfo and clubInfo.clubId and clubInfo.clubType ~= CLUB_TYPE_GUILD then
            local streams = C_Club.GetStreams(clubInfo.clubId) or {}
            for j = 1, #streams do
                local streamInfo = streams[j]
                if streamInfo and streamInfo.streamId then
                    local key = self:MakeCommunityKey(clubInfo.clubId, streamInfo.streamId)
                    results[#results + 1] = {
                        key = key,
                        clubId = tostring(clubInfo.clubId),
                        streamId = tostring(streamInfo.streamId),
                        clubName = clubInfo.name or "Community",
                        streamName = streamInfo.name or "Chat",
                        streamType = streamInfo.streamType,
                    }
                end
            end
        end
    end

    table.sort(results, function(a, b)
        local aName = self:NormalizeText(self:BuildCommunityDisplayName(a))
        local bName = self:NormalizeText(self:BuildCommunityDisplayName(b))
        if aName == bName then
            return tostring(a.key) < tostring(b.key)
        end
        return aName < bName
    end)

    return results
end

function DISCONTENT:GetCurrentSendChatType()
    local channelKey = self.activeChatChannel or "guild"

    if channelKey == "community" then
        local stream = self:GetSelectedCommunityStream()
        if stream and C_Club and C_Club.SendMessage then
            return "COMMUNITY"
        end
        return "GUILD"
    end

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
    if channelKey == "community" then
        local stream = self:GetSelectedCommunityStream()
        if stream then
            return self:BuildCommunityDisplayName(stream)
        end
    end

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
    elseif prefix == "C" then
        return "|cff00d5ff[C]|r", "|TInterface\\CHATFRAME\\UI-ChatIcon-Blizz:14|t"
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

function DISCONTENT:GetColoredAuthorName(author, overrideClassFile)
    local classFileName = overrideClassFile or self:GetClassInfoByAuthor(author)
    local safeAuthor = self:SafeName(author or "?")

    if classFileName and self.CLASS_COLORS and self.CLASS_COLORS[classFileName] then
        local c = self.CLASS_COLORS[classFileName]
        local hex = HexFromRGB(c.r, c.g, c.b)
        return "|cff" .. hex .. safeAuthor .. "|r"
    end

    return "|cff99ccff" .. safeAuthor .. "|r"
end

function DISCONTENT:SetSelectedCommunityByKey(key)
    self.activeCommunityKey = key

    if key then
        self.activeChatChannel = "community"
        self:RefreshCommunityHistory(true)
        self:RefreshCommunityMembers()
    end

    self:RefreshCommunityChatDropdown()
    self:SetActiveChatChannel(self.activeChatChannel or "guild")
end

function DISCONTENT:SetActiveChatChannel(channelKey)
    if channelKey == "officer" and not self:CanUseOfficerChat() then
        channelKey = "guild"
    end

    if channelKey == "raid" and not self:CanUseRaidChat() then
        channelKey = "guild"
    end

    if channelKey == "community" and not self:GetSelectedCommunityStream() then
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

    if self.communityDropdownButton then
        UIDropDownMenu_SetText(self.communityDropdownButton, self:GetSelectedCommunityStream() and self:BuildCommunityDisplayName(self:GetSelectedCommunityStream()) or "Community wählen")
    end

    if self.chatChannelStatusText then
        local pretty = self:GetChatChannelLabel(self.activeChatChannel)

        if self.activeChatChannel == "community" then
            self.chatChannelStatusText:SetText("Aktiver Kanal: " .. pretty)
        elseif self.activeChatChannel == "raid" and self:GetCurrentSendChatType() == "INSTANCE_CHAT" then
            self.chatChannelStatusText:SetText("Aktiver Kanal: " .. pretty .. " (Instanz)")
        elseif self.activeChatChannel == "raid" and self:GetCurrentSendChatType() ~= "RAID" then
            self.chatChannelStatusText:SetText("Aktiver Kanal: Gilde (Raid nicht verfügbar)")
        elseif self.activeChatChannel == "officer" and self:GetCurrentSendChatType() ~= "OFFICER" then
            self.chatChannelStatusText:SetText("Aktiver Kanal: Gilde (Offi nicht verfügbar)")
        else
            self.chatChannelStatusText:SetText("Aktiver Kanal: " .. pretty)
        end
    end

    self:UpdateGuildChatLayout()
    self:RefreshGuildChatView()
end

function DISCONTENT:MessageMatchesActiveChatChannel(entry)
    if not entry then
        return false
    end

    local channelKey = self.activeChatChannel or "guild"
    if channelKey == "community" then
        return entry.prefix == "C" and entry.communityKey == self.activeCommunityKey
    end

    if entry.prefix == "C" then
        return false
    end

    local info = self.chatChannels and self.chatChannels[channelKey]
    if not info or not info.prefixes then
        return true
    end

    return info.prefixes[entry.prefix or ""] and true or false
end

function DISCONTENT:BuildStyledChatLine(entry)
    local prefixText, iconText = self:GetChatPrefixStyle(entry.prefix or "G")
    local authorText = self:GetColoredAuthorName(entry.author or "?", entry.classFileName)
    local timeText = "|cff7f7f7f[" .. tostring(entry.time or "--:--") .. "]|r"

    local messageText = entry.message or ""
    if entry.prefix == "RW" then
        messageText = "|cffff5555" .. messageText .. "|r"
    end

    return string.format("%s %s %s %s: %s", timeText, iconText, prefixText, authorText, messageText)
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

local function CreateCommunityContextActionButton(parent, label)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(78, 24)
    button:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8X8",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    button:SetBackdropColor(0.20, 0.05, 0.05, 0.96)
    button:SetBackdropBorderColor(0.70, 0.48, 0.08, 1)
    button:SetMotionScriptsWhileDisabled(true)

    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.text:SetPoint("CENTER", 0, 0)
    button.text:SetText(label)

    button.defaultBg = { 0.20, 0.05, 0.05, 0.96 }
    button.hoverBg = { 0.34, 0.08, 0.08, 0.98 }
    button.defaultBorder = { 0.70, 0.48, 0.08, 1 }
    button.hoverBorder = { 1.00, 0.82, 0.20, 1 }

    function button:ApplyVisualState(isHover)
        if self.isDisabled then
            self:SetBackdropColor(0.10, 0.10, 0.10, 0.80)
            self:SetBackdropBorderColor(0.30, 0.30, 0.30, 0.85)
            self:SetAlpha(0.55)
            return
        end

        local bg = isHover and self.hoverBg or self.defaultBg
        local border = isHover and self.hoverBorder or self.defaultBorder
        self:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
        self:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
        self:SetAlpha(1)
    end

    function button:SetActionEnabled(enabled)
        self.isDisabled = not enabled
        self:SetEnabled(enabled)
        self:EnableMouse(enabled)
        self:ApplyVisualState(false)
    end

    button:SetScript("OnEnter", function(selfButton)
        selfButton:ApplyVisualState(true)
    end)

    button:SetScript("OnLeave", function(selfButton)
        selfButton:ApplyVisualState(false)
    end)

    button:SetScript("OnMouseDown", function(selfButton)
        if not selfButton.isDisabled and selfButton.text then
            selfButton.text:SetPoint("CENTER", 1, -1)
        end
    end)

    button:SetScript("OnMouseUp", function(selfButton)
        if selfButton.text then
            selfButton.text:SetPoint("CENTER", 0, 0)
        end
    end)

    button:SetActionEnabled(true)
    return button
end

function DISCONTENT:CreateCommunityMemberContextMenu()
    if self.communityMemberContextMenu then
        return
    end

    local clickCatcher = CreateFrame("Button", "DISCONTENTCommunityMemberContextBackdrop", UIParent)
    clickCatcher:SetAllPoints(UIParent)
    clickCatcher:SetFrameStrata("TOOLTIP")
    clickCatcher:SetFrameLevel(9000)
    clickCatcher:EnableMouse(true)
    clickCatcher:RegisterForClicks("AnyUp")
    clickCatcher:SetScript("OnClick", function()
        if DISCONTENT.communityMemberContextMenu then
            DISCONTENT.communityMemberContextMenu:Hide()
        end
    end)
    clickCatcher:Hide()
    self.communityMemberContextBackdrop = clickCatcher

    local menu = CreateFrame("Frame", "DISCONTENTCommunityMemberContextMenu", UIParent, "BackdropTemplate")
    menu:SetSize(214, 118)
    menu:SetFrameStrata("TOOLTIP")
    menu:SetFrameLevel(9100)
    menu:SetToplevel(true)
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    menu:EnableKeyboard(true)
    menu:SetMovable(false)
    menu:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    menu:SetBackdropColor(0.05, 0.05, 0.05, 0.98)
    menu:SetBackdropBorderColor(0.82, 0.68, 0.18, 1)
    menu:Hide()

    menu.title = menu:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    menu.title:SetPoint("TOPLEFT", 14, -12)
    menu.title:SetJustifyH("LEFT")
    menu.title:SetWidth(168)
    menu.title:SetText("-")

    menu.info = menu:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    menu.info:SetPoint("TOPLEFT", menu.title, "BOTTOMLEFT", 0, -8)
    menu.info:SetJustifyH("LEFT")
    menu.info:SetWidth(186)
    menu.info:SetText("Whisper oder Invite")

    menu.closeButton = CreateFrame("Button", nil, menu, "UIPanelCloseButton")
    menu.closeButton:SetPoint("TOPRIGHT", 2, 2)
    menu.closeButton:SetFrameStrata("TOOLTIP")
    menu.closeButton:SetFrameLevel(9150)
    menu.closeButton:SetToplevel(true)
    menu.closeButton:SetScript("OnClick", function()
        menu:Hide()
    end)

    menu.whisperButton = CreateCommunityContextActionButton(menu, "Whisper")
    menu.whisperButton:SetPoint("BOTTOMLEFT", 14, 14)
    menu.whisperButton:SetFrameStrata("TOOLTIP")
    menu.whisperButton:SetFrameLevel(9140)

    menu.inviteButton = CreateCommunityContextActionButton(menu, "Invite")
    menu.inviteButton:SetPoint("LEFT", menu.whisperButton, "RIGHT", 12, 0)
    menu.inviteButton:SetFrameStrata("TOOLTIP")
    menu.inviteButton:SetFrameLevel(9140)

    menu:SetScript("OnShow", function(selfMenu)
        selfMenu:SetFrameStrata("TOOLTIP")
        selfMenu:SetFrameLevel(9100)
        if selfMenu.closeButton then
            selfMenu.closeButton:SetFrameStrata("TOOLTIP")
            selfMenu.closeButton:SetFrameLevel(selfMenu:GetFrameLevel() + 50)
            selfMenu.closeButton:SetToplevel(true)
        end
        if selfMenu.whisperButton then
            selfMenu.whisperButton:SetFrameStrata("TOOLTIP")
            selfMenu.whisperButton:SetFrameLevel(selfMenu:GetFrameLevel() + 40)
        end
        if selfMenu.inviteButton then
            selfMenu.inviteButton:SetFrameStrata("TOOLTIP")
            selfMenu.inviteButton:SetFrameLevel(selfMenu:GetFrameLevel() + 40)
        end
        if DISCONTENT.communityMemberContextBackdrop then
            DISCONTENT.communityMemberContextBackdrop:SetFrameStrata("TOOLTIP")
            DISCONTENT.communityMemberContextBackdrop:SetFrameLevel(selfMenu:GetFrameLevel() - 5)
            DISCONTENT.communityMemberContextBackdrop:Show()
        end
    end)

    menu:SetScript("OnHide", function()
        if DISCONTENT.communityMemberContextBackdrop then
            DISCONTENT.communityMemberContextBackdrop:Hide()
        end
    end)

    menu:SetScript("OnKeyDown", function(selfMenu, key)
        if key == "ESCAPE" then
            selfMenu:Hide()
        end
    end)

    if UISpecialFrames then
        local found = false
        for i = 1, #UISpecialFrames do
            if UISpecialFrames[i] == "DISCONTENTCommunityMemberContextMenu" then
                found = true
                break
            end
        end
        if not found then
            table.insert(UISpecialFrames, "DISCONTENTCommunityMemberContextMenu")
        end
    end

    self.communityMemberContextMenu = menu
end

function DISCONTENT:OpenCommunityMemberContextMenu(member, anchor)
    if not member then
        return
    end

    self:CreateCommunityMemberContextMenu()

    local menu = self.communityMemberContextMenu
    local targetName = member.name
    local canWhisper = targetName and targetName ~= ""
    local inviteEnabled = member.presence == 1 or member.presence == 2 or member.presence == 4 or member.presence == 5

    if menu:IsShown() and menu.currentTarget == targetName then
        menu:Hide()
        return
    end

    menu.currentTarget = targetName
    menu.currentMember = member
    menu.title:SetText(self:SafeName(targetName or "?"))

    local infoParts = {}
    if member.className and member.className ~= "" then
        infoParts[#infoParts + 1] = member.className
    end
    if member.level and tonumber(member.level) then
        infoParts[#infoParts + 1] = "Level " .. tostring(member.level)
    end
    if #infoParts == 0 then
        infoParts[#infoParts + 1] = "Whisper oder Invite"
    end
    menu.info:SetText(table.concat(infoParts, "  |  "))

    menu.whisperButton:SetActionEnabled(canWhisper)
    menu.inviteButton:SetActionEnabled(canWhisper and inviteEnabled)

    menu.whisperButton:SetScript("OnClick", function()
        if not canWhisper then
            return
        end
        menu:Hide()
        ChatFrame_SendTell(targetName)
    end)

    menu.inviteButton:SetScript("OnClick", function()
        if not (canWhisper and inviteEnabled) then
            return
        end
        menu:Hide()
        if C_PartyInfo and C_PartyInfo.InviteUnit then
            C_PartyInfo.InviteUnit(targetName)
        elseif InviteUnit then
            InviteUnit(targetName)
        end
    end)

    local scale = UIParent:GetEffectiveScale() or 1
    local cursorX, cursorY = GetCursorPosition()
    cursorX = (cursorX or 0) / scale
    cursorY = (cursorY or 0) / scale

    local width = menu:GetWidth() or 214
    local height = menu:GetHeight() or 118
    local screenWidth = UIParent:GetWidth() or 0
    local screenHeight = UIParent:GetHeight() or 0

    local posX = math.min(math.max(width * 0.5 + 12, cursorX + 28), math.max(width * 0.5 + 12, screenWidth - width * 0.5 - 12))
    local posY = math.min(math.max(height * 0.5 + 12, cursorY - 18), math.max(height * 0.5 + 12, screenHeight - height * 0.5 - 12))

    if anchor and anchor.GetRight and anchor.GetTop then
        local right = anchor:GetRight()
        local top = anchor:GetTop()
        if right and top then
            posX = math.min(math.max(width * 0.5 + 12, right + width * 0.5 + 6), math.max(width * 0.5 + 12, screenWidth - width * 0.5 - 12))
            posY = math.min(math.max(height * 0.5 + 12, top - height * 0.5), math.max(height * 0.5 + 12, screenHeight - height * 0.5 - 12))
        end
    end

    menu:ClearAllPoints()
    menu:SetPoint("CENTER", UIParent, "BOTTOMLEFT", posX, posY)
    menu:Show()
    menu:Raise()
end

function DISCONTENT:GetCommunityPresenceText(presence)
    if presence == 1 then
        return "|cff40ff40Online|r"
    elseif presence == 2 then
        return "|cff66ccffMobil|r"
    elseif presence == 4 then
        return "|cffffd100AFK|r"
    elseif presence == 5 then
        return "|cffff6060DND|r"
    end
    return "|cff8a8a8aOffline|r"
end

function DISCONTENT:GetCommunityMembersForActiveSelection()
    local stream = self:GetSelectedCommunityStream()
    if not stream or not C_Club or not C_Club.GetClubMembers or not C_Club.GetMemberInfo then
        return {}
    end

    local memberIds = C_Club.GetClubMembers(stream.clubId) or {}
    local members = {}

    for i = 1, #memberIds do
        local memberInfo = C_Club.GetMemberInfo(stream.clubId, memberIds[i])
        if memberInfo and memberInfo.name and memberInfo.name ~= "" then
            local className, classFile = nil, nil
            if memberInfo.classID and GetClassInfo then
                className, classFile = GetClassInfo(memberInfo.classID)
            end

            members[#members + 1] = {
                memberId = memberInfo.memberId,
                name = memberInfo.name,
                presence = memberInfo.presence,
                level = memberInfo.level,
                className = className,
                classFileName = classFile,
                zone = memberInfo.zone,
                role = memberInfo.role,
                guildRank = memberInfo.guildRank,
            }
        end
    end

    table.sort(members, function(a, b)
        local aPresence = a.presence or 3
        local bPresence = b.presence or 3
        local aRank = (aPresence == 1 and 1) or (aPresence == 2 and 2) or (aPresence == 4 and 3) or (aPresence == 5 and 4) or 5
        local bRank = (bPresence == 1 and 1) or (bPresence == 2 and 2) or (bPresence == 4 and 3) or (bPresence == 5 and 4) or 5
        if aRank ~= bRank then
            return aRank < bRank
        end
        return self:NormalizeText(a.name) < self:NormalizeText(b.name)
    end)

    return members
end

function DISCONTENT:RefreshCommunityMembers()
    local stream = self:GetSelectedCommunityStream()
    local key = stream and stream.key or nil
    if not key then
        self.communityMembers = self.communityMembers or {}
        self.communityMembers.active = {}
        self:UpdateCommunityMemberRows()
        return
    end

    self.communityMembers = self.communityMembers or {}
    self.communityMembers[key] = self:GetCommunityMembersForActiveSelection()
    self.communityMembers.active = self.communityMembers[key]
    self:UpdateCommunityMemberRows()
end

function DISCONTENT:CreateCommunityMemberRow(index)
    local row = CreateFrame("Button", nil, self.communityMemberScrollChild)
    row:SetHeight(COMMUNITY_MEMBER_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", self.communityMemberScrollChild, "TOPLEFT", 0, -((index - 1) * COMMUNITY_MEMBER_ROW_HEIGHT))
    row:SetPoint("RIGHT", self.communityMemberScrollChild, "RIGHT", -4, 0)
    row:RegisterForClicks("AnyUp")

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    if index % 2 == 0 then
        row.bg:SetColorTexture(0.10, 0.10, 0.10, 0.55)
    else
        row.bg:SetColorTexture(0.07, 0.07, 0.07, 0.55)
    end

    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.nameText:SetPoint("LEFT", 8, 0)
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetWidth(COMMUNITY_PANEL_WIDTH - 110)

    row.statusText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.statusText:SetPoint("RIGHT", -8, 0)
    row.statusText:SetJustifyH("RIGHT")
    row.statusText:SetWidth(82)

    row:SetScript("OnEnter", function(selfRow)
        selfRow.bg:SetColorTexture(0.18, 0.18, 0.18, 0.85)
        if selfRow.memberData then
            GameTooltip:SetOwner(selfRow, "ANCHOR_RIGHT")
            GameTooltip:AddLine(selfRow.memberData.name or "Unbekannt", 1, 0.82, 0)
            if selfRow.memberData.className then
                GameTooltip:AddLine(selfRow.memberData.className, 0.85, 0.85, 0.85)
            end
            if selfRow.memberData.level then
                GameTooltip:AddLine("Level: " .. tostring(selfRow.memberData.level), 0.75, 0.75, 0.75)
            end
            if selfRow.memberData.zone and selfRow.memberData.zone ~= "" then
                GameTooltip:AddLine("Zone: " .. selfRow.memberData.zone, 0.75, 0.75, 0.75)
            end
            GameTooltip:AddLine("Rechtsklick: Whisper / Invite", 1, 0.82, 0)
            GameTooltip:Show()
        end
    end)

    row:SetScript("OnLeave", function(selfRow)
        if index % 2 == 0 then
            selfRow.bg:SetColorTexture(0.10, 0.10, 0.10, 0.55)
        else
            selfRow.bg:SetColorTexture(0.07, 0.07, 0.07, 0.55)
        end
        GameTooltip:Hide()
    end)

    row:SetScript("OnMouseUp", function(selfRow, button)
        if button == "RightButton" and selfRow.memberData then
            DISCONTENT:OpenCommunityMemberContextMenu(selfRow.memberData, selfRow)
        elseif button == "LeftButton" and selfRow.memberData then
            ChatFrame_SendTell(selfRow.memberData.name)
        end
    end)

    self.communityMemberRows = self.communityMemberRows or {}
    self.communityMemberRows[index] = row
    return row
end

function DISCONTENT:UpdateCommunityMemberRows()
    if not self.communityMemberPanel or not self.communityMemberScrollChild or not self.communityMemberScrollFrame then
        return
    end

    local activeList = (self.communityMembers and self.communityMembers.active) or {}
    local availableWidth = math.max(180, (self.communityMemberScrollFrame:GetWidth() or (COMMUNITY_PANEL_WIDTH - 32)) - 4)

    for i = 1, #activeList do
        local row = self.communityMemberRows and self.communityMemberRows[i] or self:CreateCommunityMemberRow(i)
        local member = activeList[i]
        row.memberData = member
        row:SetWidth(availableWidth)

        local displayName = self:GetColoredAuthorName(member.name or "?", member.classFileName)
        row.nameText:SetText(displayName)
        row.statusText:SetText(self:GetCommunityPresenceText(member.presence))

        row:Show()
    end

    if self.communityMemberRows then
        for i = #activeList + 1, #self.communityMemberRows do
            self.communityMemberRows[i]:Hide()
            self.communityMemberRows[i].memberData = nil
        end
    end

    self.communityMemberScrollChild:SetWidth(availableWidth)
    self.communityMemberScrollChild:SetHeight(math.max(#activeList * COMMUNITY_MEMBER_ROW_HEIGHT + 6, self.communityMemberScrollFrame:GetHeight() or 1))

    if self.communityMemberTitleValue then
        if self.activeChatChannel == "community" and self:GetSelectedCommunityStream() then
            self.communityMemberTitleValue:SetText(self:BuildCommunityDisplayName(self:GetSelectedCommunityStream()))
        else
            self.communityMemberTitleValue:SetText("-")
        end
    end

    if self.communityMemberEmptyText then
        if self.activeChatChannel == "community" and #activeList == 0 then
            self.communityMemberEmptyText:Show()
        else
            self.communityMemberEmptyText:Hide()
        end
    end
end

function DISCONTENT:RefreshCommunityHistory(requestMore)
    local stream = self:GetSelectedCommunityStream()
    if not stream or not C_Club then
        return
    end

    local key = stream.key
    self.communityChatMessages[key] = self.communityChatMessages[key] or {}
    self.communityChatMessageIndex[key] = self.communityChatMessageIndex[key] or {}

    if C_Club.FocusStream then
        pcall(C_Club.FocusStream, stream.clubId, stream.streamId)
    end

    if requestMore and C_Club.RequestMoreMessagesBefore then
        pcall(C_Club.RequestMoreMessagesBefore, stream.clubId, stream.streamId, nil, self.maxChatMessages or 80)
    end

    local ranges = C_Club.GetMessageRanges and C_Club.GetMessageRanges(stream.clubId, stream.streamId) or nil
    if not ranges or #ranges == 0 or not C_Club.GetMessagesInRange then
        self:RefreshGuildChatView()
        return
    end

    local rebuilt = {}
    local rebuiltIndex = {}

    for i = 1, #ranges do
        local range = ranges[i]
        if range and range.oldestMessageId and range.newestMessageId then
            local messages = C_Club.GetMessagesInRange(stream.clubId, stream.streamId, range.oldestMessageId, range.newestMessageId) or {}
            for j = 1, #messages do
                local messageInfo = messages[j]
                if messageInfo and not messageInfo.destroyed and messageInfo.content and messageInfo.content ~= "" then
                    local messageId = messageInfo.messageId or {}
                    local uniqueKey = tostring(messageId.epoch or 0) .. ":" .. tostring(messageId.position or 0)
                    if not rebuiltIndex[uniqueKey] then
                        rebuiltIndex[uniqueKey] = true

                        local authorInfo = messageInfo.author or {}
                        local classFile = nil
                        if authorInfo.classID and GetClassInfo then
                            local _, classToken = GetClassInfo(authorInfo.classID)
                            classFile = classToken
                        end

                        rebuilt[#rebuilt + 1] = {
                            time = date("%H:%M", math.floor((messageId.epoch or 0) / 1000000)),
                            author = authorInfo.name or "?",
                            message = messageInfo.content or "",
                            prefix = "C",
                            communityKey = key,
                            clubId = stream.clubId,
                            streamId = stream.streamId,
                            classFileName = classFile,
                            messageIdEpoch = messageId.epoch or 0,
                            messageIdPos = messageId.position or 0,
                        }
                    end
                end
            end
        end
    end

    table.sort(rebuilt, function(a, b)
        if a.messageIdEpoch == b.messageIdEpoch then
            return (a.messageIdPos or 0) < (b.messageIdPos or 0)
        end
        return (a.messageIdEpoch or 0) < (b.messageIdEpoch or 0)
    end)

    local maxMessages = self.maxChatMessages or 80
    while #rebuilt > maxMessages do
        table.remove(rebuilt, 1)
    end

    self.communityChatMessages[key] = rebuilt
    self.communityChatMessageIndex[key] = rebuiltIndex
    self:RefreshGuildChatView()
end

function DISCONTENT:HandleCommunityHistoryReceived(clubId, streamId)
    if not clubId or not streamId then
        return
    end

    local key = self:MakeCommunityKey(clubId, streamId)
    if key == self.activeCommunityKey then
        self:RefreshCommunityHistory(false)
    end
end

function DISCONTENT:HandleCommunityMemberEvent(_, clubId)
    local stream = self:GetSelectedCommunityStream()
    if stream and tostring(stream.clubId) == tostring(clubId) then
        self:RefreshCommunityMembers()
    end
end

function DISCONTENT:HandleCommunityChatMessage(message, author)
    local messageInfo, clubId, streamId, clubType = nil, nil, nil, nil
    if C_Club and C_Club.GetInfoFromLastCommunityChatLine then
        messageInfo, clubId, streamId, clubType = C_Club.GetInfoFromLastCommunityChatLine()
    end

    if clubType == CLUB_TYPE_GUILD then
        return
    end

    if not clubId or not streamId then
        return
    end

    local key = self:MakeCommunityKey(clubId, streamId)
    local list = self.communityChatMessages[key] or {}
    local index = self.communityChatMessageIndex[key] or {}

    local uniqueKey = nil
    local classFile = nil
    local finalAuthor = author or "?"
    local finalMessage = message or ""

    if messageInfo and messageInfo.messageId then
        uniqueKey = tostring(messageInfo.messageId.epoch or 0) .. ":" .. tostring(messageInfo.messageId.position or 0)
        finalAuthor = (messageInfo.author and messageInfo.author.name) or finalAuthor
        finalMessage = messageInfo.content or finalMessage
        if messageInfo.author and messageInfo.author.classID and GetClassInfo then
            local _, classToken = GetClassInfo(messageInfo.author.classID)
            classFile = classToken
        end
    else
        uniqueKey = tostring(time()) .. ":" .. tostring(math.random(1000, 9999))
    end

    if not index[uniqueKey] then
        index[uniqueKey] = true
        list[#list + 1] = {
            time = date("%H:%M"),
            author = finalAuthor,
            message = finalMessage,
            prefix = "C",
            communityKey = key,
            clubId = tostring(clubId),
            streamId = tostring(streamId),
            classFileName = classFile,
            messageIdEpoch = messageInfo and messageInfo.messageId and messageInfo.messageId.epoch or time() * 1000000,
            messageIdPos = messageInfo and messageInfo.messageId and messageInfo.messageId.position or 0,
        }

        self:TrimChatHistory(list, self.maxChatMessages or 80)

        self.communityChatMessages[key] = list
        self.communityChatMessageIndex[key] = index
    end

    if self.activeCommunityKey == key and self.activeChatChannel == "community" then
        self:RefreshGuildChatView()
    end
end

function DISCONTENT:RefreshCommunityChatDropdown()
    self.communityChatStreams = self:GetCommunityChatStreams()

    local hasSelected = false
    for i = 1, #self.communityChatStreams do
        if self.communityChatStreams[i].key == self.activeCommunityKey then
            hasSelected = true
            break
        end
    end

    if not hasSelected then
        self.activeCommunityKey = nil
        if self.activeChatChannel == "community" then
            self.activeChatChannel = "guild"
        end
    end

    if self.communityDropdownButton then
        UIDropDownMenu_Initialize(self.communityDropdownButton, function(frame, level)
            if level ~= 1 then
                return
            end

            local titleInfo = UIDropDownMenu_CreateInfo()
            titleInfo.isTitle = true
            titleInfo.notCheckable = true
            titleInfo.text = "Community-Chats"
            UIDropDownMenu_AddButton(titleInfo, level)

            for i = 1, #DISCONTENT.communityChatStreams do
                local entry = DISCONTENT.communityChatStreams[i]
                local info = UIDropDownMenu_CreateInfo()
                info.text = DISCONTENT:BuildCommunityDisplayName(entry)
                info.checked = (DISCONTENT.activeCommunityKey == entry.key and DISCONTENT.activeChatChannel == "community")
                info.func = function()
                    DISCONTENT:SetSelectedCommunityByKey(entry.key)
                end
                UIDropDownMenu_AddButton(info, level)
            end

            if #DISCONTENT.communityChatStreams == 0 then
                local emptyInfo = UIDropDownMenu_CreateInfo()
                emptyInfo.text = "Keine Community-Chats gefunden"
                emptyInfo.disabled = true
                emptyInfo.notCheckable = true
                UIDropDownMenu_AddButton(emptyInfo, level)
            end
        end)

        UIDropDownMenu_SetWidth(self.communityDropdownButton, 210)
        UIDropDownMenu_SetText(self.communityDropdownButton, self:GetSelectedCommunityStream() and self:BuildCommunityDisplayName(self:GetSelectedCommunityStream()) or "Community wählen")
    end

    self:UpdateGuildChatLayout()
    self:UpdateCommunityMemberRows()
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

    self.communityMemberPanel = CreateFrame("Frame", nil, self.guildChatTabContent, "BackdropTemplate")
    self.communityMemberPanel:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    self.communityMemberPanel:SetBackdropColor(0.05, 0.05, 0.05, 0.92)
    self.communityMemberPanel:SetBackdropBorderColor(0.45, 0.45, 0.45, 1)

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

    self.communityDropdownLabel = self.guildChatTabContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.communityDropdownLabel:SetText("Community:")

    self.communityDropdownButton = CreateFrame("Frame", "DISCONTENTCommunityChatDropdown", self.guildChatTabContent, "UIDropDownMenuTemplate")

    self.communityMemberTitle = self.communityMemberPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.communityMemberTitle:SetPoint("TOPLEFT", 14, -12)
    self.communityMemberTitle:SetText("Community-Mitglieder")

    self.communityMemberTitleValue = self.communityMemberPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.communityMemberTitleValue:SetPoint("TOPLEFT", self.communityMemberTitle, "BOTTOMLEFT", 0, -4)
    self.communityMemberTitleValue:SetPoint("RIGHT", self.communityMemberPanel, "RIGHT", -14, 0)
    self.communityMemberTitleValue:SetJustifyH("LEFT")
    self.communityMemberTitleValue:SetText("-")

    self.communityMemberHint = self.communityMemberPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.communityMemberHint:SetPoint("TOPLEFT", self.communityMemberTitleValue, "BOTTOMLEFT", 0, -8)
    self.communityMemberHint:SetPoint("RIGHT", self.communityMemberPanel, "RIGHT", -14, 0)
    self.communityMemberHint:SetJustifyH("LEFT")
    self.communityMemberHint:SetText("Rechtsklick auf ein Mitglied: Whisper oder Invite")

    self.communityMemberScrollFrame = CreateFrame("ScrollFrame", "DISCONTENTCommunityMemberScrollFrame", self.communityMemberPanel, "UIPanelScrollFrameTemplate")
    self.communityMemberScrollChild = CreateFrame("Frame", nil, self.communityMemberScrollFrame)
    self.communityMemberScrollChild:SetSize(1, 1)
    self.communityMemberScrollFrame:SetScrollChild(self.communityMemberScrollChild)

    self.communityMemberEmptyText = self.communityMemberPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.communityMemberEmptyText:SetPoint("CENTER", self.communityMemberPanel, "CENTER", 0, -20)
    self.communityMemberEmptyText:SetText("Keine Mitglieder verfügbar.")
    self.communityMemberEmptyText:Hide()

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
            DISCONTENT.chatMessageFrame:SetScrollOffset(current + 2)
        else
            DISCONTENT.chatMessageFrame:SetScrollOffset(math.max(0, current - 2))
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

    self:RefreshCommunityChatDropdown()
    self:SetActiveChatChannel(self.activeChatChannel or "guild")
end

function DISCONTENT:UpdateGuildChatLayout()
    if not self.guildChatTabContent or not self.guildChatPanel or not self.chatMessageFrame then
        return
    end

    local showCommunityPanel = self.activeChatChannel == "community" and self:GetSelectedCommunityStream()

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

    self.communityDropdownLabel:ClearAllPoints()
    self.communityDropdownLabel:SetPoint("TOPRIGHT", self.guildChatTabContent, "TOPRIGHT", -240, -18)

    self.communityDropdownButton:ClearAllPoints()
    self.communityDropdownButton:SetPoint("LEFT", self.communityDropdownLabel, "RIGHT", -8, -2)

    self.chatChannelStatusText:ClearAllPoints()
    self.chatChannelStatusText:SetPoint("LEFT", self.guildChatOfficerButton, "RIGHT", 14, 0)
    self.chatChannelStatusText:SetPoint("RIGHT", self.communityDropdownLabel, "LEFT", -10, 0)

    if showCommunityPanel then
        self.communityMemberPanel:Show()

        self.guildChatPanel:ClearAllPoints()
        self.guildChatPanel:SetPoint("TOPLEFT", self.guildChatTabContent, "TOPLEFT", 16, -46)
        self.guildChatPanel:SetPoint("BOTTOMRIGHT", self.guildChatTabContent, "BOTTOMRIGHT", -(COMMUNITY_PANEL_WIDTH + 24), 84)

        self.communityMemberPanel:ClearAllPoints()
        self.communityMemberPanel:SetPoint("TOPRIGHT", self.guildChatTabContent, "TOPRIGHT", -16, -46)
        self.communityMemberPanel:SetPoint("BOTTOMRIGHT", self.guildChatTabContent, "BOTTOMRIGHT", -16, 84)
        self.communityMemberPanel:SetWidth(COMMUNITY_PANEL_WIDTH)

        self.communityMemberScrollFrame:ClearAllPoints()
        self.communityMemberScrollFrame:SetPoint("TOPLEFT", self.communityMemberPanel, "TOPLEFT", 10, -72)
        self.communityMemberScrollFrame:SetPoint("BOTTOMRIGHT", self.communityMemberPanel, "BOTTOMRIGHT", -28, 12)

        self.chatInputBox:ClearAllPoints()
        self.chatInputBox:SetPoint("BOTTOMLEFT", self.guildChatTabContent, "BOTTOMLEFT", 16, 26)
        self.chatInputBox:SetPoint("BOTTOMRIGHT", self.guildChatTabContent, "BOTTOMRIGHT", -(COMMUNITY_PANEL_WIDTH + 126), 26)
    else
        self.communityMemberPanel:Hide()

        self.guildChatPanel:ClearAllPoints()
        self.guildChatPanel:SetPoint("TOPLEFT", self.guildChatTabContent, "TOPLEFT", 16, -46)
        self.guildChatPanel:SetPoint("BOTTOMRIGHT", self.guildChatTabContent, "BOTTOMRIGHT", -16, 84)

        self.chatInputBox:ClearAllPoints()
        self.chatInputBox:SetPoint("BOTTOMLEFT", self.guildChatTabContent, "BOTTOMLEFT", 16, 26)
        self.chatInputBox:SetPoint("BOTTOMRIGHT", self.guildChatTabContent, "BOTTOMRIGHT", -230, 26)
    end

    self.chatMessageFrame:ClearAllPoints()
    self.chatMessageFrame:SetPoint("TOPLEFT", self.guildChatPanel, "TOPLEFT", 10, -10)
    self.chatMessageFrame:SetPoint("BOTTOMRIGHT", self.guildChatPanel, "BOTTOMRIGHT", -30, 10)

    self.chatScrollBar:ClearAllPoints()
    self.chatScrollBar:SetPoint("TOPLEFT", self.chatMessageFrame, "TOPRIGHT", 4, -16)
    self.chatScrollBar:SetPoint("BOTTOMLEFT", self.chatMessageFrame, "BOTTOMRIGHT", 4, 16)

    self.chatInputBox:SetHeight(24)

    self.chatSendButton:ClearAllPoints()
    self.chatSendButton:SetPoint("LEFT", self.chatInputBox, "RIGHT", 10, 0)
    self.chatSendButton:SetSize(80, 24)

    self:UpdateCommunityMemberRows()
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

    local source = self.guildChatMessages
    if self.activeChatChannel == "community" then
        source = self.communityChatMessages[self.activeCommunityKey] or {}
    end

    for i = 1, #source do
        local entry = source[i]
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
    if not self.chatInputBox then
        return
    end

    local text = self.chatInputBox:GetText()
    if not text or text == "" then
        return
    end

    local sendType = self:GetCurrentSendChatType()
    if sendType == "COMMUNITY" then
        local stream = self:GetSelectedCommunityStream()
        if stream and C_Club and C_Club.SendMessage then
            C_Club.SendMessage(stream.clubId, stream.streamId, text)
        end
    else
        SendChatMessage(text, sendType)
    end

    self.chatInputBox:SetText("")
end
