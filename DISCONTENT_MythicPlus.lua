local DISCONTENT = _G.DISCONTENT
if not DISCONTENT then return end

DISCONTENT.mythicPlusPrefix = "DISCMPLUS"
DISCONTENT.mythicPlusRoleOptions = { "TANK", "DPS", "HEAL", "FLEX" }
DISCONTENT.mythicPlusArmorFilterOptions = { "ALLE", "Stoff", "Leder", "Kette", "Platte" }
DISCONTENT.mythicPlusTeamSearchText = DISCONTENT.mythicPlusTeamSearchText or ""
DISCONTENT.mythicPlusArmorFilter = DISCONTENT.mythicPlusArmorFilter or "ALLE"
DISCONTENT.mythicPlusSelectedTeamId = DISCONTENT.mythicPlusSelectedTeamId or nil
DISCONTENT.mythicPlusSelectedEventId = DISCONTENT.mythicPlusSelectedEventId or nil

local function splitByDelimiter(text, delimiter)
    local result = {}
    if not text or text == "" then
        return result
    end

    local start = 1
    while true do
        local s, e = string.find(text, delimiter, start, true)
        if not s then
            table.insert(result, string.sub(text, start))
            break
        end

        table.insert(result, string.sub(text, start, s - 1))
        start = e + 1
    end

    return result
end

local function createPanel(parent)
    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    panel:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    panel:SetBackdropBorderColor(0.45, 0.45, 0.45, 0.95)
    return panel
end

local function createSmallButton(parent, text, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 72, 22)
    button:SetText(text or "")
    return button
end

local function createLabel(parent, text, template)
    local label = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    label:SetJustifyH("LEFT")
    label:SetText(text or "")
    return label
end

local function normalizeNameRealm(value)
    if not value or value == "" then
        return "", GetRealmName() or "-"
    end

    local name = value:match("^[^-]+") or value
    local realm = value:match("-(.+)$") or GetRealmName() or "-"
    return name, realm
end

function DISCONTENT:MythicPlusSanitize(value, maxLength)
    value = tostring(value or "")
    value = value:gsub("%^", "")
    value = value:gsub("\n", " ")
    value = value:gsub("\r", " ")
    value = value:gsub("|", "/")
    value = value:gsub("%s+", " ")
    value = value:gsub("^%s+", "")
    value = value:gsub("%s+$", "")
    if maxLength and maxLength > 0 and string.len(value) > maxLength then
        value = string.sub(value, 1, maxLength)
    end
    return value
end

function DISCONTENT:FormatUpdatedAt(timestamp)
    if not timestamp or tonumber(timestamp) == nil or tonumber(timestamp) <= 0 then
        return "-"
    end
    return date("%d.%m.%Y %H:%M", tonumber(timestamp))
end

function DISCONTENT:EnsureMythicPlusDB()
    if type(self.db) ~= "table" then
        return nil
    end

    if type(self.db.mythicPlus) ~= "table" then
        self.db.mythicPlus = {}
    end

    local db = self.db.mythicPlus

    if type(db.teams) ~= "table" then
        db.teams = {}
    end

    if type(db.teamOrder) ~= "table" then
        db.teamOrder = {}
    end

    if type(db.incoming) ~= "table" then
        db.incoming = {}
    end

    if type(db.guildArmorFilter) ~= "string" or db.guildArmorFilter == "" then
        db.guildArmorFilter = "ALLE"
    end

    self.mythicPlusArmorFilter = db.guildArmorFilter
    self.mythicPlusDB = db
    return db
end

function DISCONTENT:GetMythicPlusDB()
    return self:EnsureMythicPlusDB()
end

function DISCONTENT:GetMythicPlusTeamsTable()
    local db = self:EnsureMythicPlusDB()
    return db and db.teams or {}
end

function DISCONTENT:GetMythicPlusOrderTable()
    local db = self:EnsureMythicPlusDB()
    return db and db.teamOrder or {}
end

function DISCONTENT:NormalizeMythicPlusArmorFilterValue(value)
    value = tostring(value or "ALLE")
    for i = 1, #(self.mythicPlusArmorFilterOptions or {}) do
        if value == self.mythicPlusArmorFilterOptions[i] then
            return value
        end
    end
    return "ALLE"
end

function DISCONTENT:GetMythicPlusGuildArmorFilter()
    local db = self:EnsureMythicPlusDB()
    local value = self:NormalizeMythicPlusArmorFilterValue((db and db.guildArmorFilter) or self.mythicPlusArmorFilter)
    if db then
        db.guildArmorFilter = value
    end
    self.mythicPlusArmorFilter = value
    return value
end

function DISCONTENT:SetMythicPlusGuildArmorFilter(value)
    local normalized = self:NormalizeMythicPlusArmorFilterValue(value)
    local db = self:EnsureMythicPlusDB()
    if db then
        db.guildArmorFilter = normalized
    end
    self.mythicPlusArmorFilter = normalized

    if self.mythicPlusGuildArmorFilterButton then
        self.mythicPlusGuildArmorFilterButton:SetText(normalized)
    end
end

function DISCONTENT:CycleMythicPlusGuildArmorFilter()
    local options = self.mythicPlusArmorFilterOptions or { "ALLE", "Stoff", "Leder", "Kette", "Platte" }
    local current = self:GetMythicPlusGuildArmorFilter()
    local nextIndex = 1

    for i = 1, #options do
        if options[i] == current then
            nextIndex = i + 1
            break
        end
    end

    if nextIndex > #options then
        nextIndex = 1
    end

    self:SetMythicPlusGuildArmorFilter(options[nextIndex])
end

function DISCONTENT:GetCurrentPlayerKey()
    local name, realm = self:GetPlayerNameRealm()
    return self:GetCharacterKey(name, realm)
end

function DISCONTENT:GetCurrentPlayerDisplayName()
    local name, realm = self:GetPlayerNameRealm()
    return self:SafeName(name) .. "-" .. (realm or GetRealmName() or "-")
end

function DISCONTENT:EnsureMythicPlusTeamOrder(teamId)
    if not teamId or teamId == "" then
        return
    end

    local order = self:GetMythicPlusOrderTable()
    for i = 1, #order do
        if order[i] == teamId then
            return
        end
    end

    table.insert(order, 1, teamId)
end

function DISCONTENT:RemoveMythicPlusTeamOrder(teamId)
    local order = self:GetMythicPlusOrderTable()
    for i = #order, 1, -1 do
        if order[i] == teamId then
            table.remove(order, i)
        end
    end
end

function DISCONTENT:GenerateMythicPlusTeamId()
    return string.format("MPT%u%04u", time() or 0, math.random(1000, 9999))
end

function DISCONTENT:GenerateMythicPlusEventId()
    return string.format("EV%u%04u", time() or 0, math.random(1000, 9999))
end

function DISCONTENT:GetArmorTypeForClass(classFileName)
    local lookup = {
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

    return lookup[classFileName or ""] or "-"
end

function DISCONTENT:GetGuildMemberByKey(key)
    if not key or key == "" then
        return nil
    end

    for i = 1, #(self.members or {}) do
        local member = self.members[i]
        local memberKey = self:GetCharacterKey(member.name, member.realm)
        if memberKey == key then
            return member
        end
    end

    return nil
end

function DISCONTENT:GetMythicPlusMemberDisplayName(entry)
    if not entry then
        return "-"
    end

    local name = self:SafeName(entry.name or entry.fullName or "")
    local realm = entry.realm or self:SafeRealm(entry.fullName or "")
    if realm and realm ~= "" then
        return name .. "-" .. realm
    end
    return name
end

function DISCONTENT:BuildMythicPlusMemberEntryFromGuildMember(member)
    if not member then
        return nil
    end

    local key = self:GetCharacterKey(member.name, member.realm)
    return {
        key = key,
        name = member.name,
        realm = member.realm,
        className = member.className or "",
        classFileName = member.classFileName or "",
        armorType = self:GetArmorTypeForClass(member.classFileName),
        role = "FLEX",
        isCoOwner = false,
    }
end

function DISCONTENT:CreateMythicPlusOwnerEntry()
    local name, realm = self:GetPlayerNameRealm()
    local key = self:GetCharacterKey(name, realm)
    local guildMember = self:GetGuildMemberByKey(key)
    local entry

    if guildMember then
        entry = self:BuildMythicPlusMemberEntryFromGuildMember(guildMember)
    else
        local _, classFile = UnitClass("player")
        entry = {
            key = key,
            name = self:SafeName(name),
            realm = realm,
            className = select(1, UnitClass("player")) or "",
            classFileName = classFile or "",
            armorType = self:GetArmorTypeForClass(classFile),
            role = "FLEX",
            isCoOwner = true,
        }
    end

    entry.isCoOwner = true
    return entry
end

function DISCONTENT:IsMemberOfMythicPlusTeam(team, key)
    if not team or type(team.members) ~= "table" then
        return false
    end

    local searchKey = key or self:GetCurrentPlayerKey()
    for i = 1, #team.members do
        local entry = team.members[i]
        if entry and entry.key == searchKey then
            return true
        end
    end

    return false
end

function DISCONTENT:GetMythicPlusTeamMember(team, key)
    if not team or type(team.members) ~= "table" then
        return nil, nil
    end

    for i = 1, #team.members do
        local entry = team.members[i]
        if entry and entry.key == key then
            return entry, i
        end
    end

    return nil, nil
end

function DISCONTENT:CanManageMythicPlusTeam(team)
    if not team then
        return false
    end

    local playerKey = self:GetCurrentPlayerKey()
    if team.ownerKey == playerKey then
        return true
    end

    local member = self:GetMythicPlusTeamMember(team, playerKey)
    return member and member.isCoOwner and true or false
end

function DISCONTENT:CanEditMythicPlusMemberRole(team, memberEntry)
    if not team or not memberEntry then
        return false
    end

    if self:CanManageMythicPlusTeam(team) then
        return true
    end

    return memberEntry.key == self:GetCurrentPlayerKey()
end

function DISCONTENT:GetMythicPlusTeamCount(team)
    return team and team.members and #team.members or 0
end

function DISCONTENT:GetMythicPlusResponseStatus(eventEntry, memberKey)
    if not eventEntry or type(eventEntry.responses) ~= "table" then
        return "none"
    end

    return eventEntry.responses[memberKey or self:GetCurrentPlayerKey()] or "none"
end

function DISCONTENT:GetMythicPlusResponseLabel(status)
    if status == "yes" then
        return "|cff55ff55Zusage|r"
    elseif status == "maybe" then
        return "|cffffcc55Vielleicht|r"
    elseif status == "no" then
        return "|cffff6666Absage|r"
    end

    return "|cffaaaaaaOffen|r"
end

function DISCONTENT:GetMythicPlusResponseCounts(eventEntry)
    local yesCount, maybeCount, noCount = 0, 0, 0
    if eventEntry and type(eventEntry.responses) == "table" then
        for _, status in pairs(eventEntry.responses) do
            if status == "yes" then
                yesCount = yesCount + 1
            elseif status == "maybe" then
                maybeCount = maybeCount + 1
            elseif status == "no" then
                noCount = noCount + 1
            end
        end
    end
    return yesCount, maybeCount, noCount
end

function DISCONTENT:SortMythicPlusTeamMembers(team)
    if not team or type(team.members) ~= "table" then
        return
    end

    table.sort(team.members, function(a, b)
        local aOwner = a.key == team.ownerKey and 1 or 0
        local bOwner = b.key == team.ownerKey and 1 or 0
        if aOwner ~= bOwner then
            return aOwner > bOwner
        end

        local aCo = a.isCoOwner and 1 or 0
        local bCo = b.isCoOwner and 1 or 0
        if aCo ~= bCo then
            return aCo > bCo
        end

        local an = self:NormalizeText(a.name)
        local bn = self:NormalizeText(b.name)
        return an < bn
    end)
end

function DISCONTENT:SortMythicPlusEvents(team)
    if not team or type(team.events) ~= "table" then
        return
    end

    table.sort(team.events, function(a, b)
        local at = tonumber(a.sortValue or a.updatedAt or 0) or 0
        local bt = tonumber(b.sortValue or b.updatedAt or 0) or 0
        if at ~= bt then
            return at > bt
        end
        return self:NormalizeText(a.title or "") < self:NormalizeText(b.title or "")
    end)
end

function DISCONTENT:GetMythicPlusSortValue(dateText, timeText)
    local day, month, year = string.match(dateText or "", "^(%d%d?)%.(%d%d?)%.(%d%d%d?%d?)$")
    local hour, minute = string.match(timeText or "", "^(%d%d?):(%d%d)$")

    if day and month and year then
        day = tonumber(day) or 1
        month = tonumber(month) or 1
        year = tonumber(year) or tonumber(date("%Y"))
        if year < 100 then
            year = 2000 + year
        end
        hour = tonumber(hour) or 0
        minute = tonumber(minute) or 0
        return time({
            year = year,
            month = month,
            day = day,
            hour = hour,
            min = minute,
            sec = 0,
        }) or 0
    end

    return 0
end

function DISCONTENT:TouchMythicPlusTeam(team, actorDisplay)
    if not team then
        return
    end

    team.updatedAt = time()
    team.updatedBy = actorDisplay or self:GetCurrentPlayerDisplayName()
    team.revision = (tonumber(team.revision) or 0) + 1
end

function DISCONTENT:CopyMythicPlusMemberEntry(entry)
    return {
        key = entry.key,
        name = entry.name,
        realm = entry.realm,
        className = entry.className,
        classFileName = entry.classFileName,
        armorType = entry.armorType,
        role = entry.role or "FLEX",
        isCoOwner = entry.isCoOwner and true or false,
    }
end

function DISCONTENT:CopyMythicPlusEventEntry(entry)
    local copy = {
        id = entry.id,
        title = entry.title or "",
        dateText = entry.dateText or "",
        timeText = entry.timeText or "",
        note = entry.note or "",
        createdAt = tonumber(entry.createdAt) or time(),
        updatedAt = tonumber(entry.updatedAt) or time(),
        sortValue = tonumber(entry.sortValue) or self:GetMythicPlusSortValue(entry.dateText, entry.timeText),
        reminderAt = tonumber(entry.reminderAt),
        remindMinutesBefore = tonumber(entry.remindMinutesBefore) or 0,
        remindAt = tonumber(entry.remindAt),
        reminderFiredAt = tonumber(entry.reminderFiredAt),
        responses = {},
    }

    if type(entry.responses) == "table" then
        for key, status in pairs(entry.responses) do
            copy.responses[key] = status
        end
    end

    return copy
end

function DISCONTENT:BuildMythicPlusReminderData(dateText, timeText, minutesText, isEnabled)
    if not isEnabled then
        return nil, nil
    end

    if self.BuildNoteReminderData then
        return self:BuildNoteReminderData(dateText, timeText, minutesText)
    end

    return nil, "Erinnerungen sind aktuell nicht verfügbar."
end

function DISCONTENT:GetMythicPlusReminderSummary(eventEntry)
    if not eventEntry or type(eventEntry.reminderAt) ~= "number" then
        return nil
    end

    local minutesBefore = tonumber(eventEntry.remindMinutesBefore) or 0
    return string.format("Erinnerung: %d Min. vorher", minutesBefore)
end

function DISCONTENT:GetMythicPlusReminderDetailText(eventEntry)
    if not eventEntry or type(eventEntry.reminderAt) ~= "number" then
        return nil
    end

    local minutesBefore = tonumber(eventEntry.remindMinutesBefore) or 0
    return string.format("%s | %d Min. vorher", date("%d.%m.%Y %H:%M", eventEntry.reminderAt), minutesBefore)
end


function DISCONTENT:IsSameMythicPlusReminderSchedule(eventEntry, reminderData)
    local oldReminderAt = eventEntry and tonumber(eventEntry.reminderAt) or nil
    local oldRemindAt = eventEntry and tonumber(eventEntry.remindAt) or nil
    local oldMinutesBefore = eventEntry and (tonumber(eventEntry.remindMinutesBefore) or 0) or 0

    local newReminderAt = type(reminderData) == "table" and tonumber(reminderData.reminderAt) or nil
    local newRemindAt = type(reminderData) == "table" and tonumber(reminderData.remindAt) or nil
    local newMinutesBefore = type(reminderData) == "table" and (tonumber(reminderData.remindMinutesBefore) or 0) or 0

    if oldReminderAt ~= newReminderAt then
        return false
    end

    if oldRemindAt ~= newRemindAt then
        return false
    end

    if oldReminderAt or newReminderAt then
        return oldMinutesBefore == newMinutesBefore
    end

    return true
end

function DISCONTENT:RestoreMythicPlusReminderState(previousTeam, incomingTeam)
    if not previousTeam or not incomingTeam or type(incomingTeam.events) ~= "table" then
        return
    end

    local previousById = {}
    for i = 1, #(previousTeam.events or {}) do
        local oldEvent = previousTeam.events[i]
        if oldEvent and oldEvent.id and oldEvent.id ~= "" then
            previousById[oldEvent.id] = oldEvent
        end
    end

    for i = 1, #(incomingTeam.events or {}) do
        local newEvent = incomingTeam.events[i]
        local oldEvent = newEvent and previousById[newEvent.id]
        if oldEvent and self:IsSameMythicPlusReminderSchedule(oldEvent, newEvent) then
            newEvent.reminderFiredAt = tonumber(oldEvent.reminderFiredAt)
        else
            newEvent.reminderFiredAt = nil
        end
    end
end

function DISCONTENT:OpenMythicPlusFromReminderPopup(teamId, eventId)
    if self.HideSharedReminderPopup then
        self:HideSharedReminderPopup(false)
    elseif self.noteReminderPopup then
        self.noteReminderPopup:Hide()
    end

    if teamId and teamId ~= "" then
        self.mythicPlusSelectedTeamId = teamId
    end

    if eventId and eventId ~= "" then
        self.mythicPlusSelectedEventId = eventId
    end

    self:ShowMainWindow()
    self:SetActiveTab("mythicplus")
    self:RefreshMythicPlusUI()
end

function DISCONTENT:ShowMythicPlusReminderPopup(team, eventEntry)
    if not team or not eventEntry then
        return
    end

    local detailText = self:GetMythicPlusReminderDetailText(eventEntry) or "Termin steht an"
    local message = string.format("%s\n%s\n%s", team.name or "M+ Team", eventEntry.title or "Termin", detailText)

    if self.QueueSharedReminderPopup or self.ShowSharedReminderPopup then
        local showPopup = self.QueueSharedReminderPopup or self.ShowSharedReminderPopup
        showPopup(self, {
            title = "Mythic+-Erinnerung",
            message = message,
            hint = "Klick öffnet Mythic+ | Ziehen verschiebt | Rechtsklick schließt",
            onClick = function()
                DISCONTENT:OpenMythicPlusFromReminderPopup(team.id, eventEntry.id)
            end,
            playSound = true,
            borderColor = { 0.45, 0.82, 1.0, 1 },
        })
    end
end

function DISCONTENT:ShowMythicPlusSyncPopup(team, senderName)
    if not team or (not self.QueueSharedReminderPopup and not self.ShowSharedReminderPopup) then
        return
    end

    local safeSender = self:SafeName(senderName or team.updatedBy or "Unbekannt")
    local message = string.format("%s\nÄnderungen von: %s", team.name or "M+ Team", safeSender)

    local showPopup = self.QueueSharedReminderPopup or self.ShowSharedReminderPopup
    showPopup(self, {
        title = "Mythic+-Sync",
        message = message,
        hint = "Klick öffnet Mythic+ | Ziehen verschiebt | Rechtsklick schließt",
        onClick = function()
            DISCONTENT:OpenMythicPlusFromReminderPopup(team.id, nil)
        end,
        playSound = true,
        borderColor = { 0.45, 0.82, 1.0, 1 },
    })
end

function DISCONTENT:CheckMythicPlusReminders()
    local teams = self:GetMythicPlusTeamsTable()
    local now = time()

    for _, team in pairs(teams) do
        for i = 1, #(team.events or {}) do
            local eventEntry = team.events[i]
            if eventEntry
                and type(eventEntry.remindAt) == "number"
                and not eventEntry.reminderFiredAt
                and eventEntry.remindAt <= now then
                eventEntry.reminderFiredAt = now
                self:StoreMythicPlusTeam(team)
                self:ShowMythicPlusReminderPopup(team, eventEntry)
                return
            end
        end
    end
end

function DISCONTENT:StartMythicPlusReminderTicker()
    if self.mythicPlusReminderTicker or not C_Timer or type(C_Timer.NewTicker) ~= "function" then
        return
    end

    self.mythicPlusReminderTicker = C_Timer.NewTicker(1, function()
        if DISCONTENT and DISCONTENT.CheckMythicPlusReminders then
            DISCONTENT:CheckMythicPlusReminders()
        end
    end)
end

function DISCONTENT:UpdateMythicPlusEventReminderControls(popup)
    if not popup then
        return
    end

    local enabled = popup.reminderCheck and popup.reminderCheck:GetChecked()
    local alpha = enabled and 1 or 0.45

    if popup.reminderLeadLabel then
        popup.reminderLeadLabel:SetAlpha(alpha)
    end

    if popup.reminderLeadInput then
        popup.reminderLeadInput:SetEnabled(enabled and true or false)
        popup.reminderLeadInput:SetAlpha(alpha)
        if not enabled then
            popup.reminderLeadInput:ClearFocus()
        end
    end

    if popup.reminderHelpText then
        popup.reminderHelpText:SetAlpha(alpha)
    end
end

function DISCONTENT:CloneMythicPlusTeam(team)
    if not team then
        return nil
    end

    local copy = {
        id = team.id,
        name = team.name,
        ownerKey = team.ownerKey,
        ownerName = team.ownerName,
        ownerRealm = team.ownerRealm,
        createdAt = tonumber(team.createdAt) or time(),
        updatedAt = tonumber(team.updatedAt) or time(),
        updatedBy = team.updatedBy or "",
        revision = tonumber(team.revision) or 1,
        lastSyncAt = tonumber(team.lastSyncAt) or 0,
        members = {},
        events = {},
    }

    if type(team.members) == "table" then
        for i = 1, #team.members do
            copy.members[i] = self:CopyMythicPlusMemberEntry(team.members[i])
        end
    end

    if type(team.events) == "table" then
        for i = 1, #team.events do
            copy.events[i] = self:CopyMythicPlusEventEntry(team.events[i])
        end
    end

    return copy
end

function DISCONTENT:StoreMythicPlusTeam(team)
    if not team or not team.id or team.id == "" then
        return
    end

    local teams = self:GetMythicPlusTeamsTable()
    teams[team.id] = self:CloneMythicPlusTeam(team)
    self:EnsureMythicPlusTeamOrder(team.id)
    self:SaveSettings()
end

function DISCONTENT:DeleteMythicPlusTeamLocal(teamId)
    local teams = self:GetMythicPlusTeamsTable()
    teams[teamId] = nil
    self:RemoveMythicPlusTeamOrder(teamId)

    if self.mythicPlusSelectedTeamId == teamId then
        self.mythicPlusSelectedTeamId = nil
        self.mythicPlusSelectedEventId = nil
    end

    self:SaveSettings()
end

function DISCONTENT:GetMythicPlusTeam(teamId)
    local teams = self:GetMythicPlusTeamsTable()
    return teams[teamId]
end

function DISCONTENT:GetMythicPlusVisibleTeams()
    local teams = self:GetMythicPlusTeamsTable()
    local order = self:GetMythicPlusOrderTable()
    local list = {}
    local inserted = {}

    for i = 1, #order do
        local teamId = order[i]
        local team = teams[teamId]
        if team and self:IsMemberOfMythicPlusTeam(team) then
            table.insert(list, team)
            inserted[teamId] = true
        end
    end

    for teamId, team in pairs(teams) do
        if not inserted[teamId] and self:IsMemberOfMythicPlusTeam(team) then
            table.insert(list, team)
            inserted[teamId] = true
        end
    end

    table.sort(list, function(a, b)
        local at = tonumber(a.updatedAt) or 0
        local bt = tonumber(b.updatedAt) or 0
        if at ~= bt then
            return at > bt
        end
        return self:NormalizeText(a.name or "") < self:NormalizeText(b.name or "")
    end)

    return list
end

function DISCONTENT:EnsureMythicPlusSelection()
    local teams = self:GetMythicPlusVisibleTeams()
    if self.mythicPlusSelectedTeamId then
        for i = 1, #teams do
            if teams[i].id == self.mythicPlusSelectedTeamId then
                return teams[i]
            end
        end
    end

    if #teams > 0 then
        self.mythicPlusSelectedTeamId = teams[1].id
        return teams[1]
    end

    self.mythicPlusSelectedTeamId = nil
    self.mythicPlusSelectedEventId = nil
    return nil
end

function DISCONTENT:CreateMythicPlusTeam(name)
    local cleanName = self:MythicPlusSanitize(name, 32)
    if cleanName == "" then
        return nil
    end

    local playerName, playerRealm = self:GetPlayerNameRealm()
    local team = {
        id = self:GenerateMythicPlusTeamId(),
        name = cleanName,
        ownerKey = self:GetCharacterKey(playerName, playerRealm),
        ownerName = self:SafeName(playerName),
        ownerRealm = playerRealm,
        createdAt = time(),
        updatedAt = time(),
        updatedBy = self:GetCurrentPlayerDisplayName(),
        revision = 1,
        lastSyncAt = 0,
        members = {
            self:CreateMythicPlusOwnerEntry(),
        },
        events = {},
    }

    self:SortMythicPlusTeamMembers(team)
    self:StoreMythicPlusTeam(team)
    self.mythicPlusSelectedTeamId = team.id
    self.mythicPlusSelectedEventId = nil
    return team
end

function DISCONTENT:AddGuildMemberToMythicPlusTeam(team, guildMember)
    if not team or not guildMember then
        return false
    end

    if not self:CanManageMythicPlusTeam(team) then
        return false
    end

    local entry = self:BuildMythicPlusMemberEntryFromGuildMember(guildMember)
    if not entry then
        return false
    end

    local existing = self:GetMythicPlusTeamMember(team, entry.key)
    if existing then
        return false
    end

    table.insert(team.members, entry)
    self:SortMythicPlusTeamMembers(team)
    self:TouchMythicPlusTeam(team)
    self:StoreMythicPlusTeam(team)
    return true
end

function DISCONTENT:AddExternalMemberToMythicPlusTeam(team, playerName, playerRealm)
    if not team then
        return false
    end

    if not self:CanManageMythicPlusTeam(team) then
        return false
    end

    local cleanName = self:MythicPlusSanitize(playerName, 32)
    local cleanRealm = self:MythicPlusSanitize(playerRealm, 32)

    if cleanName == "" or cleanRealm == "" then
        return false
    end

    local key = self:GetCharacterKey(cleanName, cleanRealm)
    if not key or key == "" then
        return false
    end

    local existing = self:GetMythicPlusTeamMember(team, key)
    if existing then
        return false
    end

    local entry = {
        key = key,
        name = cleanName,
        realm = cleanRealm,
        className = "",
        classFileName = "",
        armorType = "-",
        role = "FLEX",
        isCoOwner = false,
    }

    table.insert(team.members, entry)
    self:SortMythicPlusTeamMembers(team)
    self:TouchMythicPlusTeam(team)
    self:StoreMythicPlusTeam(team)
    return true
end

function DISCONTENT:RemoveMythicPlusTeamMember(team, memberKey)
    if not team or not memberKey or memberKey == "" then
        return false
    end

    if not self:CanManageMythicPlusTeam(team) then
        return false
    end

    if memberKey == team.ownerKey then
        return false
    end

    local member, index = self:GetMythicPlusTeamMember(team, memberKey)
    if not member or not index then
        return false
    end

    table.remove(team.members, index)

    if type(team.events) == "table" then
        for i = 1, #team.events do
            local eventEntry = team.events[i]
            if eventEntry and type(eventEntry.responses) == "table" then
                eventEntry.responses[memberKey] = nil
            end
        end
    end

    self:TouchMythicPlusTeam(team)
    self:StoreMythicPlusTeam(team)
    return true
end

function DISCONTENT:ToggleMythicPlusCoOwner(team, memberKey)
    if not team or not memberKey or memberKey == "" then
        return false
    end

    if not self:CanManageMythicPlusTeam(team) then
        return false
    end

    if memberKey == team.ownerKey then
        return false
    end

    local member = self:GetMythicPlusTeamMember(team, memberKey)
    if not member then
        return false
    end

    member.isCoOwner = not member.isCoOwner
    self:SortMythicPlusTeamMembers(team)
    self:TouchMythicPlusTeam(team)
    self:StoreMythicPlusTeam(team)
    return true
end

function DISCONTENT:CycleMythicPlusMemberRole(team, memberKey)
    if not team or not memberKey or memberKey == "" then
        return false
    end

    local member = self:GetMythicPlusTeamMember(team, memberKey)
    if not member or not self:CanEditMythicPlusMemberRole(team, member) then
        return false
    end

    local currentRole = member.role or "FLEX"
    local nextRole = "FLEX"

    for i = 1, #self.mythicPlusRoleOptions do
        if self.mythicPlusRoleOptions[i] == currentRole then
            nextRole = self.mythicPlusRoleOptions[(i % #self.mythicPlusRoleOptions) + 1]
            break
        end
    end

    member.role = nextRole
    self:TouchMythicPlusTeam(team)
    self:StoreMythicPlusTeam(team)
    return true
end

function DISCONTENT:CreateOrUpdateMythicPlusEvent(team, eventId, title, dateText, timeText, note, reminderData)
    if not team then
        return nil
    end

    if not self:IsMemberOfMythicPlusTeam(team) then
        return nil
    end

    if not self:CanManageMythicPlusTeam(team) then
        return nil
    end

    local cleanTitle = self:MythicPlusSanitize(title, 48)
    local cleanDate = self:MythicPlusSanitize(dateText, 20)
    local cleanTime = self:MythicPlusSanitize(timeText, 10)
    local cleanNote = self:MythicPlusSanitize(note, 90)

    if cleanTitle == "" then
        return nil
    end

    local eventEntry
    if eventId and eventId ~= "" then
        for i = 1, #(team.events or {}) do
            if team.events[i].id == eventId then
                eventEntry = team.events[i]
                break
            end
        end
    end

    if not eventEntry then
        eventEntry = {
            id = self:GenerateMythicPlusEventId(),
            createdAt = time(),
            responses = {},
        }
        team.events[#team.events + 1] = eventEntry
    end

    eventEntry.title = cleanTitle
    eventEntry.dateText = cleanDate
    eventEntry.timeText = cleanTime
    eventEntry.note = cleanNote
    eventEntry.updatedAt = time()
    eventEntry.sortValue = self:GetMythicPlusSortValue(cleanDate, cleanTime)

    local reminderScheduleChanged = not self:IsSameMythicPlusReminderSchedule(eventEntry, reminderData)

    if type(reminderData) == "table" then
        eventEntry.reminderAt = tonumber(reminderData.reminderAt)
        eventEntry.remindMinutesBefore = tonumber(reminderData.remindMinutesBefore) or 0
        eventEntry.remindAt = tonumber(reminderData.remindAt)
        if reminderScheduleChanged then
            eventEntry.reminderFiredAt = nil
        end
    else
        eventEntry.reminderAt = nil
        eventEntry.remindMinutesBefore = nil
        eventEntry.remindAt = nil
        if reminderScheduleChanged then
            eventEntry.reminderFiredAt = nil
        end
    end

    self:SortMythicPlusEvents(team)
    self:TouchMythicPlusTeam(team)
    self:StoreMythicPlusTeam(team)
    self.mythicPlusSelectedEventId = eventEntry.id
    return eventEntry
end

function DISCONTENT:GetMythicPlusEvent(team, eventId)
    if not team or type(team.events) ~= "table" then
        return nil, nil
    end

    for i = 1, #team.events do
        local eventEntry = team.events[i]
        if eventEntry and eventEntry.id == eventId then
            return eventEntry, i
        end
    end

    return nil, nil
end

function DISCONTENT:DeleteMythicPlusEvent(team, eventId)
    if not team or not eventId or eventId == "" then
        return false
    end

    if not self:CanManageMythicPlusTeam(team) then
        return false
    end

    local _, index = self:GetMythicPlusEvent(team, eventId)
    if not index then
        return false
    end

    table.remove(team.events, index)
    if self.mythicPlusSelectedEventId == eventId then
        self.mythicPlusSelectedEventId = nil
    end

    self:TouchMythicPlusTeam(team)
    self:StoreMythicPlusTeam(team)
    return true
end

function DISCONTENT:SetMythicPlusResponse(team, eventId, status)
    if not team or not eventId or eventId == "" then
        return false
    end

    local eventEntry = self:GetMythicPlusEvent(team, eventId)
    if not eventEntry then
        return false
    end

    local valid = {
        yes = true,
        maybe = true,
        no = true,
        none = true,
    }

    if not valid[status] then
        return false
    end

    local playerKey = self:GetCurrentPlayerKey()
    if not self:IsMemberOfMythicPlusTeam(team, playerKey) then
        return false
    end

    if type(eventEntry.responses) ~= "table" then
        eventEntry.responses = {}
    end

    if status == "none" then
        eventEntry.responses[playerKey] = nil
    else
        eventEntry.responses[playerKey] = status
    end

    eventEntry.updatedAt = time()
    self:TouchMythicPlusTeam(team)
    self:StoreMythicPlusTeam(team)
    return true
end

function DISCONTENT:GetMythicPlusInviteTarget(entry)
    if not entry then
        return nil
    end

    if entry.realm and entry.realm ~= "" then
        return self:SafeName(entry.name) .. "-" .. entry.realm
    end

    return self:SafeName(entry.name)
end

function DISCONTENT:InviteMythicPlusMember(entry)
    if not entry then
        return
    end

    local target = self:GetMythicPlusInviteTarget(entry)
    if not target or target == "" then
        return
    end

    if C_PartyInfo and C_PartyInfo.InviteUnit then
        C_PartyInfo.InviteUnit(target)
    else
        InviteUnit(target)
    end
end

function DISCONTENT:InviteAllMythicPlusMembers(team)
    if not team or type(team.members) ~= "table" then
        return
    end

    local playerKey = self:GetCurrentPlayerKey()
    for i = 1, #team.members do
        local entry = team.members[i]
        local guildMember = self:GetGuildMemberByKey(entry.key)
        if entry.key ~= playerKey and guildMember and guildMember.isOnline then
            self:InviteMythicPlusMember(entry)
        end
    end
end

function DISCONTENT:InviteAcceptedMythicPlusMembers(team)
    if not team or not self.mythicPlusSelectedEventId then
        self:SetMythicPlusStatusText("Bitte erst einen Termin auswählen.")
        return
    end

    local eventEntry = self:GetMythicPlusEvent(team, self.mythicPlusSelectedEventId)
    if not eventEntry then
        self:SetMythicPlusStatusText("Ausgewählter Termin nicht gefunden.")
        return
    end

    local invited = 0
    local playerKey = self:GetCurrentPlayerKey()
    for i = 1, #(team.members or {}) do
        local entry = team.members[i]
        if entry.key ~= playerKey and self:GetMythicPlusResponseStatus(eventEntry, entry.key) == "yes" then
            local guildMember = self:GetGuildMemberByKey(entry.key)
            if guildMember and guildMember.isOnline then
                self:InviteMythicPlusMember(entry)
                invited = invited + 1
            end
        end
    end

    self:SetMythicPlusStatusText(string.format("Zugesagte Einladungen gesendet: %d", invited))
end

function DISCONTENT:SetMythicPlusStatusText(text)
    if self.mythicPlusStatusText then
        self.mythicPlusStatusText:SetText(text or "")
        self.mythicPlusStatusText:SetTextColor(0.35, 1.0, 0.35, 1)
    end
end

function DISCONTENT:SendWhisperToMythicPlusMember(entry, text)
    if not entry then
        return
    end

    local cleanText = self:MythicPlusSanitize(text, 180)
    if cleanText == "" then
        return
    end

    local target = self:GetMythicPlusInviteTarget(entry)
    if not target or target == "" then
        return
    end

    SendChatMessage(cleanText, "WHISPER", nil, target)
end

function DISCONTENT:WhisperAllMythicPlusMembers(team, text)
    if not team or not text or text == "" then
        return
    end

    local sent = 0
    local playerKey = self:GetCurrentPlayerKey()
    for i = 1, #(team.members or {}) do
        local entry = team.members[i]
        if entry.key ~= playerKey then
            self:SendWhisperToMythicPlusMember(entry, text)
            sent = sent + 1
        end
    end

    self:SetMythicPlusStatusText(string.format("Whisper an %d Spieler gesendet.", sent))
end

function DISCONTENT:SendMythicPlusAddonMessage(message, target)
    if not message or message == "" then
        return
    end

    if not C_ChatInfo or not C_ChatInfo.SendAddonMessage then
        return
    end

    if not target or target == "" then
        return
    end

    C_ChatInfo.SendAddonMessage(self.mythicPlusPrefix, message, "WHISPER", target)
end

function DISCONTENT:GetMythicPlusSyncTargets(team)
    local targets = {}
    local seen = {}
    if not team or type(team.members) ~= "table" then
        return targets
    end

    local playerKey = self:GetCurrentPlayerKey()

    for i = 1, #team.members do
        local entry = team.members[i]
        if entry and entry.key ~= playerKey then
            local guildMember = self:GetGuildMemberByKey(entry.key)
            local target = self:GetMythicPlusInviteTarget(entry)
            if target and target ~= "" and not seen[target] and (not guildMember or guildMember.isOnline) then
                targets[#targets + 1] = target
                seen[target] = true
            end
        end
    end

    return targets
end

function DISCONTENT:BuildMythicPlusTeamSummaryPayload(team)
    return table.concat({
        "TS",
        self:MythicPlusSanitize(team.id, 32),
        tostring(team.revision or 1),
        tostring(team.updatedAt or time()),
        self:MythicPlusSanitize(team.name, 32),
        self:MythicPlusSanitize(team.ownerName, 32),
        self:MythicPlusSanitize(team.ownerRealm, 32),
        self:MythicPlusSanitize(team.ownerKey, 64),
        tostring(team.createdAt or time()),
        self:MythicPlusSanitize(team.updatedBy, 48),
    }, "^")
end

function DISCONTENT:BuildMythicPlusTeamMemberPayload(team, entry)
    return table.concat({
        "TM",
        self:MythicPlusSanitize(team.id, 32),
        tostring(team.revision or 1),
        self:MythicPlusSanitize(entry.key, 64),
        self:MythicPlusSanitize(entry.name, 32),
        self:MythicPlusSanitize(entry.realm, 32),
        self:MythicPlusSanitize(entry.classFileName, 20),
        self:MythicPlusSanitize(entry.className, 24),
        self:MythicPlusSanitize(entry.armorType, 12),
        self:MythicPlusSanitize(entry.role, 8),
        entry.isCoOwner and "1" or "0",
    }, "^")
end

function DISCONTENT:BuildMythicPlusEventPayload(team, eventEntry)
    return table.concat({
        "TE",
        team.id,
        tostring(team.revision or 1),
        self:MythicPlusSanitize(eventEntry.id, 32),
        self:MythicPlusSanitize(eventEntry.title, 48),
        self:MythicPlusSanitize(eventEntry.dateText, 20),
        self:MythicPlusSanitize(eventEntry.timeText, 10),
        self:MythicPlusSanitize(eventEntry.note, 90),
        tostring(eventEntry.updatedAt or time()),
        tostring(eventEntry.createdAt or time()),
        tostring(tonumber(eventEntry.reminderAt) or 0),
        tostring(tonumber(eventEntry.remindMinutesBefore) or 0),
    }, "^")
end

function DISCONTENT:BuildMythicPlusResponsePayload(team, eventEntry, memberKey, status)
    return table.concat({
        "TR",
        self:MythicPlusSanitize(team.id, 32),
        tostring(team.revision or 1),
        self:MythicPlusSanitize(eventEntry.id, 32),
        self:MythicPlusSanitize(memberKey, 64),
        self:MythicPlusSanitize(status, 8),
    }, "^")
end

function DISCONTENT:BuildMythicPlusFinishPayload(team)
    return table.concat({
        "TF",
        self:MythicPlusSanitize(team.id, 32),
        tostring(team.revision or 1),
        tostring(team.updatedAt or time()),
    }, "^")
end

function DISCONTENT:BuildMythicPlusDeletePayload(team)
    return table.concat({
        "TD",
        self:MythicPlusSanitize(team.id, 32),
        tostring(team.updatedAt or time()),
        self:MythicPlusSanitize(self:GetCurrentPlayerKey(), 64),
    }, "^")
end

function DISCONTENT:SyncMythicPlusTeam(team)
    if not team then
        return
    end

    local targets = self:GetMythicPlusSyncTargets(team)
    if #targets == 0 then
        self:SetMythicPlusStatusText("Keine erreichbaren Team-Mitglieder für den Sync gefunden.")
        return
    end

    team.lastSyncAt = time()
    self:StoreMythicPlusTeam(team)

    for targetIndex = 1, #targets do
        local target = targets[targetIndex]
        local delay = (targetIndex - 1) * 0.55

        C_Timer.After(delay, function()
            if not DISCONTENT then
                return
            end

            DISCONTENT:SendMythicPlusAddonMessage(DISCONTENT:BuildMythicPlusTeamSummaryPayload(team), target)
            local subDelay = 0.06

            for i = 1, #(team.members or {}) do
                local entry = team.members[i]
                C_Timer.After(subDelay, function()
                    if DISCONTENT then
                        DISCONTENT:SendMythicPlusAddonMessage(DISCONTENT:BuildMythicPlusTeamMemberPayload(team, entry), target)
                    end
                end)
                subDelay = subDelay + 0.05
            end

            for i = 1, #(team.events or {}) do
                local eventEntry = team.events[i]
                C_Timer.After(subDelay, function()
                    if DISCONTENT then
                        DISCONTENT:SendMythicPlusAddonMessage(DISCONTENT:BuildMythicPlusEventPayload(team, eventEntry), target)
                    end
                end)
                subDelay = subDelay + 0.05

                if type(eventEntry.responses) == "table" then
                    for memberKey, status in pairs(eventEntry.responses) do
                        C_Timer.After(subDelay, function()
                            if DISCONTENT then
                                DISCONTENT:SendMythicPlusAddonMessage(DISCONTENT:BuildMythicPlusResponsePayload(team, eventEntry, memberKey, status), target)
                            end
                        end)
                        subDelay = subDelay + 0.03
                    end
                end
            end

            C_Timer.After(subDelay + 0.02, function()
                if DISCONTENT then
                    DISCONTENT:SendMythicPlusAddonMessage(DISCONTENT:BuildMythicPlusFinishPayload(team), target)
                end
            end)
        end)
    end

    self:SetMythicPlusStatusText(string.format("Team '%s' wurde synchronisiert.", team.name or "-"))
    self:RefreshMythicPlusUI()
end

function DISCONTENT:BroadcastMythicPlusDelete(team)
    if not team then
        return
    end

    local payload = self:BuildMythicPlusDeletePayload(team)
    local targets = self:GetMythicPlusSyncTargets(team)
    for i = 1, #targets do
        self:SendMythicPlusAddonMessage(payload, targets[i])
    end
end

function DISCONTENT:GetMythicPlusIncomingTable()
    local db = self:EnsureMythicPlusDB()
    return db and db.incoming or {}
end

function DISCONTENT:ShouldAcceptIncomingMythicPlusTeam(teamId, revision, updatedAt)
    local team = self:GetMythicPlusTeam(teamId)
    if not team then
        return true
    end

    local localRevision = tonumber(team.revision) or 0
    local localUpdatedAt = tonumber(team.updatedAt) or 0
    revision = tonumber(revision) or 0
    updatedAt = tonumber(updatedAt) or 0

    if revision > localRevision then
        return true
    end

    if revision == localRevision and updatedAt >= localUpdatedAt then
        return true
    end

    return false
end

function DISCONTENT:HandleMythicPlusTeamSummary(parts, sender)
    local teamId = parts[2]
    local revision = tonumber(parts[3]) or 0
    local updatedAt = tonumber(parts[4]) or 0

    if not teamId or teamId == "" then
        return
    end

    if not self:ShouldAcceptIncomingMythicPlusTeam(teamId, revision, updatedAt) then
        return
    end

    local incoming = self:GetMythicPlusIncomingTable()
    incoming[teamId] = {
        team = {
            id = teamId,
            revision = revision,
            updatedAt = updatedAt,
            name = parts[5] or "",
            ownerName = parts[6] or "",
            ownerRealm = parts[7] or "",
            ownerKey = parts[8] or "",
            createdAt = tonumber(parts[9]) or time(),
            updatedBy = parts[10] or self:SafeName(sender or ""),
            members = {},
            events = {},
            lastSyncAt = time(),
        },
        sender = sender,
    }
end

function DISCONTENT:HandleMythicPlusTeamMember(parts)
    local teamId = parts[2]
    local revision = tonumber(parts[3]) or 0
    local incoming = self:GetMythicPlusIncomingTable()
    local packet = incoming[teamId]
    if not packet or not packet.team or (tonumber(packet.team.revision) or 0) ~= revision then
        return
    end

    local entry = {
        key = parts[4] or "",
        name = parts[5] or "",
        realm = parts[6] or "",
        classFileName = parts[7] or "",
        className = parts[8] or "",
        armorType = parts[9] or "",
        role = parts[10] or "FLEX",
        isCoOwner = (parts[11] == "1"),
    }

    if entry.key == "" then
        return
    end

    packet.team.members[#packet.team.members + 1] = entry
end

function DISCONTENT:HandleMythicPlusEvent(parts)
    local teamId = parts[2]
    local revision = tonumber(parts[3]) or 0
    local incoming = self:GetMythicPlusIncomingTable()
    local packet = incoming[teamId]
    if not packet or not packet.team or (tonumber(packet.team.revision) or 0) ~= revision then
        return
    end

    local reminderAt = tonumber(parts[11]) or 0
    local remindMinutesBefore = tonumber(parts[12]) or 0
    if remindMinutesBefore < 0 then
        remindMinutesBefore = 0
    end

    local eventEntry = {
        id = parts[4] or "",
        title = parts[5] or "",
        dateText = parts[6] or "",
        timeText = parts[7] or "",
        note = parts[8] or "",
        updatedAt = tonumber(parts[9]) or time(),
        createdAt = tonumber(parts[10]) or time(),
        responses = {},
    }

    eventEntry.sortValue = self:GetMythicPlusSortValue(eventEntry.dateText, eventEntry.timeText)
    if eventEntry.id == "" then
        return
    end

    if reminderAt > 0 then
        eventEntry.reminderAt = reminderAt
        eventEntry.remindMinutesBefore = remindMinutesBefore
        eventEntry.remindAt = reminderAt - (remindMinutesBefore * 60)
        eventEntry.reminderFiredAt = nil
    end

    packet.team.events[#packet.team.events + 1] = eventEntry
end

function DISCONTENT:HandleMythicPlusResponse(parts)
    local teamId = parts[2]
    local revision = tonumber(parts[3]) or 0
    local eventId = parts[4] or ""
    local memberKey = parts[5] or ""
    local status = parts[6] or "none"

    local incoming = self:GetMythicPlusIncomingTable()
    local packet = incoming[teamId]
    if not packet or not packet.team or (tonumber(packet.team.revision) or 0) ~= revision then
        return
    end

    if eventId == "" or memberKey == "" then
        return
    end

    for i = 1, #(packet.team.events or {}) do
        local eventEntry = packet.team.events[i]
        if eventEntry.id == eventId then
            if type(eventEntry.responses) ~= "table" then
                eventEntry.responses = {}
            end
            eventEntry.responses[memberKey] = status
            return
        end
    end
end

function DISCONTENT:FinalizeIncomingMythicPlusTeam(parts)
    local teamId = parts[2]
    local revision = tonumber(parts[3]) or 0
    local incoming = self:GetMythicPlusIncomingTable()
    local packet = incoming[teamId]
    if not packet or not packet.team or (tonumber(packet.team.revision) or 0) ~= revision then
        return
    end

    local team = packet.team
    if not self:IsMemberOfMythicPlusTeam(team) and team.ownerKey ~= self:GetCurrentPlayerKey() then
        incoming[teamId] = nil
        return
    end

    local previousTeam = self:GetMythicPlusTeam(teamId)
    local previousRevision = previousTeam and (tonumber(previousTeam.revision) or 0) or 0
    local previousUpdatedAt = previousTeam and (tonumber(previousTeam.updatedAt) or 0) or 0

    self:SortMythicPlusTeamMembers(team)
    self:SortMythicPlusEvents(team)
    self:RestoreMythicPlusReminderState(previousTeam, team)
    self:StoreMythicPlusTeam(team)
    incoming[teamId] = nil

    if not self.mythicPlusSelectedTeamId then
        self.mythicPlusSelectedTeamId = team.id
    end

    self:SetMythicPlusStatusText(string.format("Team '%s' wurde synchronisiert.", team.name or "-"))
    self:RefreshMythicPlusUI()

    local senderName, senderRealm = normalizeNameRealm(packet.sender or "")
    local senderKey = self:GetCharacterKey(senderName, senderRealm)
    local shouldNotify = packet.sender and packet.sender ~= "" and senderKey ~= self:GetCurrentPlayerKey()
    local changed = (not previousTeam) or revision > previousRevision or (tonumber(team.updatedAt) or 0) > previousUpdatedAt

    if shouldNotify and changed then
        self:ShowMythicPlusSyncPopup(team, team.updatedBy or senderName)
    end
end

function DISCONTENT:HandleIncomingMythicPlusDelete(parts, sender)
    local teamId = parts[2]
    local updatedAt = tonumber(parts[3]) or 0
    local senderKey = parts[4] or ""

    if not teamId or teamId == "" then
        return
    end

    local team = self:GetMythicPlusTeam(teamId)
    if not team then
        return
    end

    local senderAllowed = false
    if senderKey == team.ownerKey then
        senderAllowed = true
    else
        local member = self:GetMythicPlusTeamMember(team, senderKey)
        senderAllowed = member and member.isCoOwner and true or false
    end

    if not senderAllowed and sender then
        local senderName, senderRealm = normalizeNameRealm(sender)
        local derivedKey = self:GetCharacterKey(senderName, senderRealm)
        if derivedKey == team.ownerKey then
            senderAllowed = true
        end
    end

    if not senderAllowed then
        return
    end

    if (tonumber(team.updatedAt) or 0) > updatedAt then
        return
    end

    self:DeleteMythicPlusTeamLocal(teamId)
    self:SetMythicPlusStatusText("Ein M+ Team wurde entfernt.")
    self:RefreshMythicPlusUI()
end

function DISCONTENT:HandleMythicPlusAddonMessage(prefix, message, channel, sender)
    if prefix ~= self.mythicPlusPrefix then
        return
    end

    if type(message) ~= "string" or message == "" then
        return
    end

    local parts = splitByDelimiter(message, "^")
    local msgType = parts[1]

    if msgType == "TS" then
        self:HandleMythicPlusTeamSummary(parts, sender)
    elseif msgType == "TM" then
        self:HandleMythicPlusTeamMember(parts)
    elseif msgType == "TE" then
        self:HandleMythicPlusEvent(parts)
    elseif msgType == "TR" then
        self:HandleMythicPlusResponse(parts)
    elseif msgType == "TF" then
        self:FinalizeIncomingMythicPlusTeam(parts)
    elseif msgType == "TD" then
        self:HandleIncomingMythicPlusDelete(parts, sender)
    end
end

function DISCONTENT:GetFilteredGuildMembersForMythicPlus(team)
    local list = {}
    local searchText = self:NormalizeText(self.mythicPlusTeamSearchText or "")
    local armorFilter = self:GetMythicPlusGuildArmorFilter()

    for i = 1, #(self.members or {}) do
        local member = self.members[i]
        local key = self:GetCharacterKey(member.name, member.realm)
        if not team or not self:GetMythicPlusTeamMember(team, key) then
            local memberArmorType = self:GetArmorTypeForClass(member.classFileName)
            local matchesSearch = (searchText == "" or string.find(self:NormalizeText(member.name), searchText, 1, true))
            local matchesArmor = (armorFilter == "ALLE" or memberArmorType == armorFilter)

            if matchesSearch and matchesArmor then
                list[#list + 1] = member
            end
        end
    end

    table.sort(list, function(a, b)
        local aOnline = a.isOnline and 1 or 0
        local bOnline = b.isOnline and 1 or 0
        if aOnline ~= bOnline then
            return aOnline > bOnline
        end
        return self:NormalizeText(a.name) < self:NormalizeText(b.name)
    end)

    return list
end

function DISCONTENT:GetMythicPlusSelectedTeam()
    return self:EnsureMythicPlusSelection()
end

function DISCONTENT:OpenMythicPlusTextPrompt(title, labelText, defaultValue, callback)
    if not self.mythicPlusTextPrompt then
        local popup = CreateFrame("Frame", "DISCONTENTMythicPlusTextPrompt", UIParent, "BackdropTemplate")
        popup:SetSize(420, 170)
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
        popup.border:SetBackdropBorderColor(0.85, 0.85, 0.85, 1)

        popup.title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        popup.title:SetPoint("TOP", 0, -14)
        popup.title:SetText("Eingabe")

        popup.closeButton = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
        popup.closeButton:SetPoint("TOPRIGHT", -4, -4)

        popup.label = createLabel(popup, "", "GameFontHighlight")
        popup.label:SetPoint("TOPLEFT", 18, -46)

        popup.editBox = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
        popup.editBox:SetAutoFocus(false)
        popup.editBox:SetSize(360, 24)
        popup.editBox:SetPoint("TOPLEFT", popup.label, "BOTTOMLEFT", 0, -8)
        popup.editBox:SetScript("OnEscapePressed", function(editBox)
            editBox:ClearFocus()
            popup:Hide()
        end)
        popup.editBox:SetScript("OnEnterPressed", function(editBox)
            if popup.callback then
                popup.callback(editBox:GetText())
            end
            editBox:ClearFocus()
            popup:Hide()
        end)

        popup.okButton = createSmallButton(popup, "Speichern", 100)
        popup.okButton:SetPoint("BOTTOMRIGHT", -18, 16)
        popup.okButton:SetScript("OnClick", function()
            if popup.callback then
                popup.callback(popup.editBox:GetText())
            end
            popup.editBox:ClearFocus()
            popup:Hide()
        end)

        popup.cancelButton = createSmallButton(popup, "Abbrechen", 100)
        popup.cancelButton:SetPoint("RIGHT", popup.okButton, "LEFT", -8, 0)
        popup.cancelButton:SetScript("OnClick", function()
            popup.editBox:ClearFocus()
            popup:Hide()
        end)

        self.mythicPlusTextPrompt = popup
    end

    local popup = self.mythicPlusTextPrompt
    popup.title:SetText(title or "Eingabe")
    popup.label:SetText(labelText or "")
    popup.editBox:SetText(defaultValue or "")
    popup.callback = callback
    popup:Show()

    C_Timer.After(0, function()
        if popup and popup.editBox then
            popup.editBox:SetFocus()
            popup.editBox:HighlightText()
        end
    end)
end

function DISCONTENT:OpenMythicPlusExternalInvitePopup(team)
    if not team then
        return
    end

    if not self.mythicPlusExternalInvitePopup then
        local popup = CreateFrame("Frame", "DISCONTENTMythicPlusExternalInvitePopup", UIParent, "BackdropTemplate")
        popup:SetSize(430, 220)
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
        popup.border:SetBackdropBorderColor(0.85, 0.85, 0.85, 1)

        popup.title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        popup.title:SetPoint("TOP", 0, -14)
        popup.title:SetText("Externen Spieler hinzufügen")

        popup.closeButton = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
        popup.closeButton:SetPoint("TOPRIGHT", -4, -4)

popup.nameInput = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
popup.nameInput:SetAutoFocus(false)
popup.nameInput:SetSize(180, 24)
popup.nameInput:SetPoint("TOPLEFT", 18, -84)

popup.realmInput = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
popup.realmInput:SetAutoFocus(false)
popup.realmInput:SetSize(180, 24)
popup.realmInput:SetPoint("LEFT", popup.nameInput, "RIGHT", 42, 0)

popup.nameLabel = createLabel(popup, "Name", "GameFontHighlight")
popup.nameLabel:SetPoint("BOTTOMLEFT", popup.nameInput, "TOPLEFT", 0, 10)

popup.realmLabel = createLabel(popup, "Server", "GameFontHighlight")
popup.realmLabel:SetPoint("BOTTOMLEFT", popup.realmInput, "TOPLEFT", 0, 10)

        popup.infoText = createLabel(
            popup,
            "Beispiel: Name = Thrall, Server = Blackhand",
            "GameFontNormalSmall"
        )
        popup.infoText:SetPoint("TOPLEFT", popup.nameInput, "BOTTOMLEFT", 0, -18)
        popup.infoText:SetTextColor(0.75, 0.75, 0.75, 1)

        popup.saveButton = createSmallButton(popup, "Hinzufügen", 100)
        popup.saveButton:SetPoint("BOTTOMRIGHT", -18, 16)

        popup.cancelButton = createSmallButton(popup, "Abbrechen", 100)
        popup.cancelButton:SetPoint("RIGHT", popup.saveButton, "LEFT", -8, 0)
        popup.cancelButton:SetScript("OnClick", function()
            popup.nameInput:ClearFocus()
            popup.realmInput:ClearFocus()
            popup:Hide()
        end)

        self.mythicPlusExternalInvitePopup = popup
    end

    local popup = self.mythicPlusExternalInvitePopup
    popup.teamId = team.id
    popup.nameInput:SetText("")
    popup.realmInput:SetText("")

    popup.saveButton:SetScript("OnClick", function()
        local editTeam = DISCONTENT:GetMythicPlusTeam(popup.teamId)
        if not editTeam then
            popup:Hide()
            return
        end

        local nameText = popup.nameInput:GetText() or ""
        local realmText = popup.realmInput:GetText() or ""

        if DISCONTENT:AddExternalMemberToMythicPlusTeam(editTeam, nameText, realmText) then
            DISCONTENT:SetMythicPlusStatusText("Externer Spieler hinzugefügt.")
            DISCONTENT:RefreshMythicPlusUI()
        else
            DISCONTENT:SetMythicPlusStatusText("Spieler konnte nicht hinzugefügt werden.")
        end

        popup.nameInput:ClearFocus()
        popup.realmInput:ClearFocus()
        popup:Hide()
    end)

    popup:Show()

    C_Timer.After(0, function()
        if popup and popup.nameInput then
            popup.nameInput:SetFocus()
            popup.nameInput:HighlightText()
        end
    end)
end

function DISCONTENT:OpenMythicPlusEventPopup(team, eventEntry)
    if not self.mythicPlusEventPopup then
        local popup = CreateFrame("Frame", "DISCONTENTMythicPlusEventPopup", UIParent, "BackdropTemplate")
        popup:SetSize(520, 360)
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
        popup.border:SetBackdropBorderColor(0.85, 0.85, 0.85, 1)

        popup.title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        popup.title:SetPoint("TOP", 0, -14)
        popup.title:SetText("Termin bearbeiten")

        popup.closeButton = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
        popup.closeButton:SetPoint("TOPRIGHT", -4, -4)

        popup.titleLabel = createLabel(popup, "Titel", "GameFontHighlight")
        popup.titleLabel:SetPoint("TOPLEFT", 18, -46)

        popup.titleInput = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
        popup.titleInput:SetAutoFocus(false)
        popup.titleInput:SetSize(470, 24)
        popup.titleInput:SetPoint("TOPLEFT", popup.titleLabel, "BOTTOMLEFT", 0, -8)

        popup.dateInput = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
        popup.dateInput:SetAutoFocus(false)
        popup.dateInput:SetSize(210, 24)
        popup.dateInput:SetPoint("TOPLEFT", popup.titleInput, "BOTTOMLEFT", 0, -42)

        popup.timeInput = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
        popup.timeInput:SetAutoFocus(false)
        popup.timeInput:SetSize(120, 24)
        popup.timeInput:SetPoint("LEFT", popup.dateInput, "RIGHT", 28, 0)

        popup.dateLabel = createLabel(popup, "Datum (z.B. 15.03.2026)", "GameFontHighlight")
        popup.dateLabel:SetPoint("BOTTOMLEFT", popup.dateInput, "TOPLEFT", 0, 10)

        popup.timeLabel = createLabel(popup, "Uhrzeit (z.B. 20:00)", "GameFontHighlight")
        popup.timeLabel:SetPoint("BOTTOMLEFT", popup.timeInput, "TOPLEFT", 0, 10)

        popup.noteLabel = createLabel(popup, "Details / Notiz", "GameFontHighlight")
        popup.noteLabel:SetPoint("TOPLEFT", popup.dateInput, "BOTTOMLEFT", 0, -18)

        popup.noteInput = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
        popup.noteInput:SetAutoFocus(false)
        popup.noteInput:SetSize(470, 24)
        popup.noteInput:SetPoint("TOPLEFT", popup.noteLabel, "BOTTOMLEFT", 0, -8)

        popup.reminderCheck = CreateFrame("CheckButton", nil, popup, "UICheckButtonTemplate")
        popup.reminderCheck:SetPoint("TOPLEFT", popup.noteInput, "BOTTOMLEFT", -6, -18)

        popup.reminderCheckLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        popup.reminderCheckLabel:SetPoint("LEFT", popup.reminderCheck, "RIGHT", 4, 1)
        popup.reminderCheckLabel:SetJustifyH("LEFT")
        popup.reminderCheckLabel:SetText("Erinnerung aktiv")

        popup.reminderLeadLabel = createLabel(popup, "Min. vorher", "GameFontHighlightSmall")
        popup.reminderLeadLabel:SetPoint("TOPLEFT", popup.reminderCheck, "BOTTOMLEFT", 8, -12)

        popup.reminderLeadInput = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
        popup.reminderLeadInput:SetAutoFocus(false)
        popup.reminderLeadInput:SetSize(60, 24)
        popup.reminderLeadInput:SetPoint("LEFT", popup.reminderLeadLabel, "RIGHT", 8, 0)
        popup.reminderLeadInput:SetMaxLetters(4)
        popup.reminderLeadInput:SetScript("OnEscapePressed", function(editBox)
            editBox:ClearFocus()
        end)

        popup.reminderHelpText = popup:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        popup.reminderHelpText:SetPoint("TOPLEFT", popup.reminderLeadLabel, "BOTTOMLEFT", 0, -10)
        popup.reminderHelpText:SetWidth(460)
        popup.reminderHelpText:SetJustifyH("LEFT")
        popup.reminderHelpText:SetText("Nutze das gleiche Minipopup wie bei Notes. Minuten leer = direkt zum Terminzeitpunkt.")

        popup.reminderCheck:SetScript("OnClick", function()
            DISCONTENT:UpdateMythicPlusEventReminderControls(popup)
        end)

        popup.saveButton = createSmallButton(popup, "Speichern", 100)
        popup.saveButton:SetPoint("BOTTOMRIGHT", -18, 16)

        popup.cancelButton = createSmallButton(popup, "Abbrechen", 100)
        popup.cancelButton:SetPoint("RIGHT", popup.saveButton, "LEFT", -8, 0)
        popup.cancelButton:SetScript("OnClick", function()
            popup.titleInput:ClearFocus()
            popup.dateInput:ClearFocus()
            popup.timeInput:ClearFocus()
            popup.noteInput:ClearFocus()
            popup.reminderLeadInput:ClearFocus()
            popup:Hide()
        end)

        self.mythicPlusEventPopup = popup
    end

    local popup = self.mythicPlusEventPopup
    popup.teamId = team and team.id or nil
    popup.eventId = eventEntry and eventEntry.id or nil
    popup.title:SetText(eventEntry and "Termin bearbeiten" or "Neuer Termin")
    popup.titleInput:SetText(eventEntry and eventEntry.title or "")
    popup.dateInput:SetText(eventEntry and eventEntry.dateText or "")
    popup.timeInput:SetText(eventEntry and eventEntry.timeText or "")
    popup.noteInput:SetText(eventEntry and eventEntry.note or "")
    popup.reminderCheck:SetChecked(eventEntry and type(eventEntry.reminderAt) == "number")

    local reminderMinutes = ""
    if eventEntry and type(eventEntry.reminderAt) == "number" then
        local minutes = tonumber(eventEntry.remindMinutesBefore) or 0
        if minutes > 0 then
            reminderMinutes = tostring(minutes)
        end
    end
    popup.reminderLeadInput:SetText(reminderMinutes)
    self:UpdateMythicPlusEventReminderControls(popup)

    popup.saveButton:SetScript("OnClick", function()
        local editTeam = DISCONTENT:GetMythicPlusTeam(popup.teamId)
        if not editTeam then
            popup:Hide()
            return
        end

        local reminderData, err = DISCONTENT:BuildMythicPlusReminderData(
            popup.dateInput:GetText(),
            popup.timeInput:GetText(),
            popup.reminderLeadInput:GetText(),
            popup.reminderCheck:GetChecked()
        )

        if err then
            if UIErrorsFrame then
                UIErrorsFrame:AddMessage(err, 1.0, 0.15, 0.15, 1.0)
            end
            DISCONTENT:SetMythicPlusStatusText(err)
            return
        end

        local savedEvent = DISCONTENT:CreateOrUpdateMythicPlusEvent(
            editTeam,
            popup.eventId,
            popup.titleInput:GetText(),
            popup.dateInput:GetText(),
            popup.timeInput:GetText(),
            popup.noteInput:GetText(),
            reminderData
        )

        if savedEvent then
            DISCONTENT:SetMythicPlusStatusText("Termin gespeichert.")
            DISCONTENT:RefreshMythicPlusUI()
        else
            DISCONTENT:SetMythicPlusStatusText("Termin konnte nicht gespeichert werden.")
        end

        popup.titleInput:ClearFocus()
        popup.dateInput:ClearFocus()
        popup.timeInput:ClearFocus()
        popup.noteInput:ClearFocus()
        popup.reminderLeadInput:ClearFocus()
        popup:Hide()
    end)

    popup:Show()
    C_Timer.After(0, function()
        if popup and popup.titleInput then
            popup.titleInput:SetFocus()
            popup.titleInput:HighlightText()
        end
    end)
end

function DISCONTENT:RefreshMythicPlusTeamRows()
    if not self.mythicPlusTeamListContent then
        return
    end

    local teams = self:GetMythicPlusVisibleTeams()
    self.mythicPlusTeamRows = self.mythicPlusTeamRows or {}

    for i = 1, #teams do
        local row = self.mythicPlusTeamRows[i]
        if not row then
            row = CreateFrame("Button", nil, self.mythicPlusTeamListContent, "BackdropTemplate")
            row:SetHeight(24)
            row:SetBackdrop({
                bgFile = "Interface/Tooltips/UI-Tooltip-Background",
                edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
                edgeSize = 10,
                insets = { left = 2, right = 2, top = 2, bottom = 2 },
            })
            row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.nameText:SetPoint("LEFT", 8, 0)
            row.nameText:SetJustifyH("LEFT")
            row.nameText:SetWidth(218)

            row:SetScript("OnClick", function(button)
                DISCONTENT.mythicPlusSelectedTeamId = button.teamId
                DISCONTENT.mythicPlusSelectedEventId = nil
                DISCONTENT:RefreshMythicPlusUI()
            end)

            self.mythicPlusTeamRows[i] = row
        end

        local team = teams[i]
        row.teamId = team.id
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.mythicPlusTeamListContent, "TOPLEFT", 2, -((i - 1) * 28))
        row:SetPoint("TOPRIGHT", self.mythicPlusTeamListContent, "TOPRIGHT", -2, -((i - 1) * 28))
        row:SetBackdropColor(team.id == self.mythicPlusSelectedTeamId and 0.18 or 0.08, 0.08, 0.08, 0.92)
        row:SetBackdropBorderColor(team.id == self.mythicPlusSelectedTeamId and 0.95 or 0.45, 0.75, 0.45, 0.95)
        row.nameText:SetText(string.format("%s (%d)", team.name or "-", self:GetMythicPlusTeamCount(team)))
        row:Show()
    end

    for i = #teams + 1, #(self.mythicPlusTeamRows or {}) do
        self.mythicPlusTeamRows[i]:Hide()
    end

    self.mythicPlusTeamListContent:SetHeight(math.max(240, #teams * 28 + 8))
end

function DISCONTENT:RefreshMythicPlusGuildMemberRows(team)
    if not self.mythicPlusGuildListContent then
        return
    end

    local entries = self:GetFilteredGuildMembersForMythicPlus(team)
    self.mythicPlusGuildRows = self.mythicPlusGuildRows or {}
    local allowManage = team and self:CanManageMythicPlusTeam(team)
    local contentWidth = math.max(280, (self.mythicPlusGuildListFrame:GetWidth() or 320) - 24)

    for i = 1, #entries do
        local row = self.mythicPlusGuildRows[i]
        if not row then
            row = CreateFrame("Button", nil, self.mythicPlusGuildListContent, "BackdropTemplate")
            row:SetHeight(24)
            row:SetBackdrop({
                bgFile = "Interface/Tooltips/UI-Tooltip-Background",
                edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
                edgeSize = 10,
                insets = { left = 2, right = 2, top = 2, bottom = 2 },
            })

            row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.nameText:SetPoint("LEFT", 8, 0)
            row.nameText:SetJustifyH("LEFT")

            row.infoText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.infoText:SetPoint("RIGHT", -8, 0)
            row.infoText:SetJustifyH("RIGHT")

            row:SetScript("OnClick", function(button)
                local selectedTeam = DISCONTENT:GetMythicPlusSelectedTeam()
                if not selectedTeam or not DISCONTENT:CanManageMythicPlusTeam(selectedTeam) then
                    return
                end

                if DISCONTENT:AddGuildMemberToMythicPlusTeam(selectedTeam, button.member) then
                    DISCONTENT:SetMythicPlusStatusText((button.member.name or "-") .. " wurde hinzugefügt.")
                    DISCONTENT:RefreshMythicPlusUI()
                end
            end)

            self.mythicPlusGuildRows[i] = row
        end

        local member = entries[i]
        row.member = member
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.mythicPlusGuildListContent, "TOPLEFT", 2, -((i - 1) * 26))
        row:SetPoint("TOPRIGHT", self.mythicPlusGuildListContent, "TOPRIGHT", -2, -((i - 1) * 26))
        row:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
        row:SetBackdropBorderColor(0.42, 0.42, 0.42, 0.92)

        local r, g, b = self:GetClassColor(member.classFileName)
        row.nameText:SetWidth(contentWidth - 85)
        row.nameText:SetText(member.name or "-")
        row.nameText:SetTextColor(r, g, b, 1)

        local statusText = member.isOnline and "|cff55ff55Online|r" or "|cff999999Offline|r"
        row.infoText:SetText(statusText)
        row:SetEnabled(allowManage and true or false)
        row:Show()
    end

    for i = #entries + 1, #(self.mythicPlusGuildRows or {}) do
        self.mythicPlusGuildRows[i]:Hide()
    end

    self.mythicPlusGuildListContent:SetWidth(contentWidth)
    self.mythicPlusGuildListContent:SetHeight(math.max(240, #entries * 26 + 8))
end

function DISCONTENT:RefreshMythicPlusMemberRows(team)
    if not self.mythicPlusMemberListContent then
        return
    end

    self.mythicPlusMemberRows = self.mythicPlusMemberRows or {}
    local entries = team and team.members or {}
    local contentWidth = math.max(430, (self.mythicPlusMemberListFrame:GetWidth() or 470) - 24)

    local nameWidth = 112
    local classWidth = 62
    local armorWidth = 44
    local roleWidth = 48
    local coWidth = 34
    local miniWidth = 24
    local gap = 4

    local function shortenName(text, maxLen)
        text = tostring(text or "")
        maxLen = maxLen or 10
        if string.len(text) <= maxLen then
            return text
        end
        return string.sub(text, 1, maxLen - 1) .. "…"
    end

    local function setTooltip(widget, title, line)
        widget:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if title and title ~= "" then
                GameTooltip:AddLine(title, 1, 0.82, 0)
            end
            if line and line ~= "" then
                GameTooltip:AddLine(line, 0.9, 0.9, 0.9, true)
            end
            GameTooltip:Show()
        end)

        widget:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    for i = 1, #entries do
        local row = self.mythicPlusMemberRows[i]
        if not row then
            row = CreateFrame("Frame", nil, self.mythicPlusMemberListContent, "BackdropTemplate")
            row:SetHeight(30)
            row:SetBackdrop({
                bgFile = "Interface/Tooltips/UI-Tooltip-Background",
                edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
                edgeSize = 10,
                insets = { left = 2, right = 2, top = 2, bottom = 2 },
            })

            row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.nameText:SetJustifyH("LEFT")

            row.nameHover = CreateFrame("Button", nil, row)
            row.nameHover:SetFrameLevel(row:GetFrameLevel() + 5)

            row.classText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.classText:SetJustifyH("LEFT")

            row.armorText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.armorText:SetJustifyH("LEFT")

            row.roleButton = createSmallButton(row, "FLEX", roleWidth)
            row.coButton = createSmallButton(row, "Co", coWidth)
            row.invButton = createSmallButton(row, "+", miniWidth)
            row.whisperButton = createSmallButton(row, "@", miniWidth)
            row.removeButton = createSmallButton(row, "x", miniWidth)

            row.roleButton:SetScript("OnClick", function(button)
                local selectedTeam = DISCONTENT:GetMythicPlusSelectedTeam()
                if selectedTeam and DISCONTENT:CycleMythicPlusMemberRole(selectedTeam, button.memberKey) then
                    DISCONTENT:RefreshMythicPlusUI()
                end
            end)

            row.coButton:SetScript("OnClick", function(button)
                local selectedTeam = DISCONTENT:GetMythicPlusSelectedTeam()
                if selectedTeam and DISCONTENT:ToggleMythicPlusCoOwner(selectedTeam, button.memberKey) then
                    DISCONTENT:RefreshMythicPlusUI()
                end
            end)

            row.invButton:SetScript("OnClick", function(button)
                local selectedTeam = DISCONTENT:GetMythicPlusSelectedTeam()
                if not selectedTeam then return end
                local member = DISCONTENT:GetMythicPlusTeamMember(selectedTeam, button.memberKey)
                if member then
                    DISCONTENT:InviteMythicPlusMember(member)
                end
            end)

            row.whisperButton:SetScript("OnClick", function(button)
                local selectedTeam = DISCONTENT:GetMythicPlusSelectedTeam()
                if not selectedTeam then return end
                local member = DISCONTENT:GetMythicPlusTeamMember(selectedTeam, button.memberKey)
                if not member then return end

                DISCONTENT:OpenMythicPlusTextPrompt(
                    "Spieler anschreiben",
                    "Whisper an " .. (member.name or "-"),
                    "",
                    function(text)
                        DISCONTENT:SendWhisperToMythicPlusMember(member, text)
                    end
                )
            end)

            row.removeButton:SetScript("OnClick", function(button)
                local selectedTeam = DISCONTENT:GetMythicPlusSelectedTeam()
                if selectedTeam and DISCONTENT:RemoveMythicPlusTeamMember(selectedTeam, button.memberKey) then
                    DISCONTENT:RefreshMythicPlusUI()
                end
            end)

            self.mythicPlusMemberRows[i] = row
        end

        local entry = entries[i]
        local isOwner = entry.key == team.ownerKey
        local canManage = self:CanManageMythicPlusTeam(team)
        local canEditRole = self:CanEditMythicPlusMemberRole(team, entry)

        local ownerFlag = isOwner and " (O)" or (entry.isCoOwner and " (C)" or "")
        local fullName = (entry.name or "-") .. ownerFlag
        local shortName = shortenName(fullName, 12)

        row.memberKey = entry.key
        row.roleButton.memberKey = entry.key
        row.coButton.memberKey = entry.key
        row.invButton.memberKey = entry.key
        row.whisperButton.memberKey = entry.key
        row.removeButton.memberKey = entry.key

        row:SetWidth(contentWidth)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.mythicPlusMemberListContent, "TOPLEFT", 2, -((i - 1) * 32))
        row:SetPoint("TOPRIGHT", self.mythicPlusMemberListContent, "TOPRIGHT", -2, -((i - 1) * 32))
        row:SetBackdropColor(0.08, 0.08, 0.08, 0.92)
        row:SetBackdropBorderColor(0.42, 0.42, 0.42, 0.95)

        local x = 8

        row.nameText:ClearAllPoints()
        row.nameText:SetPoint("LEFT", row, "LEFT", x, 0)
        row.nameText:SetWidth(nameWidth)
        row.nameText:SetText(shortName)
        x = x + nameWidth + 6

        row.nameHover:ClearAllPoints()
        row.nameHover:SetPoint("LEFT", row, "LEFT", 8, 0)
        row.nameHover:SetSize(nameWidth, 24)

        row.classText:ClearAllPoints()
        row.classText:SetPoint("LEFT", row, "LEFT", x, 0)
        row.classText:SetWidth(classWidth)
        row.classText:SetText(entry.className or "-")
        x = x + classWidth + 6

        row.armorText:ClearAllPoints()
        row.armorText:SetPoint("LEFT", row, "LEFT", x, 0)
        row.armorText:SetWidth(armorWidth)
        row.armorText:SetText(entry.armorType or "-")
        x = x + armorWidth + 6

        row.roleButton:ClearAllPoints()
        row.roleButton:SetPoint("LEFT", row, "LEFT", x, 0)
        row.roleButton:SetText(entry.role or "FLEX")
        x = x + roleWidth + 6

        row.coButton:ClearAllPoints()
        row.coButton:SetPoint("LEFT", row, "LEFT", x, 0)
        row.coButton:SetText(entry.isCoOwner and "Co*" or "Co")

        row.removeButton:ClearAllPoints()
        row.removeButton:SetPoint("RIGHT", row, "RIGHT", -8, 0)

        row.whisperButton:ClearAllPoints()
        row.whisperButton:SetPoint("RIGHT", row.removeButton, "LEFT", -gap, 0)

        row.invButton:ClearAllPoints()
        row.invButton:SetPoint("RIGHT", row.whisperButton, "LEFT", -gap, 0)

        local r, g, b = self:GetClassColor(entry.classFileName)
        row.nameText:SetTextColor(r, g, b, 1)

        row.roleButton:SetEnabled(canEditRole and true or false)
        row.coButton:SetEnabled(canManage and not isOwner)
        row.invButton:SetEnabled(true)
        row.whisperButton:SetEnabled(true)
        row.removeButton:SetEnabled(canManage and not isOwner)

        setTooltip(row.nameHover, fullName, "Voller Name des Team-Mitglieds")
        setTooltip(row.roleButton, "Rolle", "Klicken zum Wechseln zwischen Tank / DPS / Heal / Flex")
        setTooltip(row.coButton, "Co-Owner", "Klicken, um den Co-Owner-Status umzuschalten")
        setTooltip(row.invButton, "Invite", "Spieler direkt einladen")
        setTooltip(row.whisperButton, "Whisper", "Privatnachricht an den Spieler senden")
        setTooltip(row.removeButton, "Entfernen", "Spieler aus dem Team entfernen")

        row:Show()
    end

    for i = #entries + 1, #(self.mythicPlusMemberRows or {}) do
        self.mythicPlusMemberRows[i]:Hide()
    end

    self.mythicPlusMemberListContent:SetWidth(contentWidth)
    self.mythicPlusMemberListContent:SetHeight(math.max(220, #entries * 32 + 8))
end

function DISCONTENT:RefreshMythicPlusScheduleRows(team)
    if not self.mythicPlusScheduleListContent then
        return
    end

    self.mythicPlusScheduleRows = self.mythicPlusScheduleRows or {}
    local events = team and team.events or {}
    local selectedEventId = self.mythicPlusSelectedEventId
    local contentWidth = math.max(330, (self.mythicPlusScheduleListFrame:GetWidth() or 370) - 24)

    for i = 1, #events do
        local row = self.mythicPlusScheduleRows[i]
        if not row then
            row = CreateFrame("Button", nil, self.mythicPlusScheduleListContent, "BackdropTemplate")
            row:SetHeight(110)
            row:SetBackdrop({
                bgFile = "Interface/Tooltips/UI-Tooltip-Background",
                edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
                edgeSize = 10,
                insets = { left = 2, right = 2, top = 2, bottom = 2 },
            })

            row.titleText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.titleText:SetJustifyH("LEFT")

            row.infoText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.infoText:SetJustifyH("LEFT")

            row.statusText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.statusText:SetJustifyH("LEFT")

            row.responseText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.responseText:SetJustifyH("LEFT")

            row.yesButton = createSmallButton(row, "Ja", 34)
            row.maybeButton = createSmallButton(row, "Vllt", 42)
            row.noButton = createSmallButton(row, "Nein", 42)
            row.deleteButton = createSmallButton(row, "X", 26)

            row:SetScript("OnClick", function(button)
                DISCONTENT.mythicPlusSelectedEventId = button.eventId
                local currentTeam = DISCONTENT:GetMythicPlusSelectedTeam()
                local currentEvent = currentTeam and DISCONTENT:GetMythicPlusEvent(currentTeam, button.eventId)
                if currentTeam and currentEvent and DISCONTENT:CanManageMythicPlusTeam(currentTeam) then
                    DISCONTENT:OpenMythicPlusEventPopup(currentTeam, currentEvent)
                end
                DISCONTENT:RefreshMythicPlusUI()
            end)

            row.yesButton:SetScript("OnClick", function(button)
                local currentTeam = DISCONTENT:GetMythicPlusSelectedTeam()
                if currentTeam and DISCONTENT:SetMythicPlusResponse(currentTeam, button.eventId, "yes") then
                    DISCONTENT.mythicPlusSelectedEventId = button.eventId
                    DISCONTENT:RefreshMythicPlusUI()
                end
            end)

            row.maybeButton:SetScript("OnClick", function(button)
                local currentTeam = DISCONTENT:GetMythicPlusSelectedTeam()
                if currentTeam and DISCONTENT:SetMythicPlusResponse(currentTeam, button.eventId, "maybe") then
                    DISCONTENT.mythicPlusSelectedEventId = button.eventId
                    DISCONTENT:RefreshMythicPlusUI()
                end
            end)

            row.noButton:SetScript("OnClick", function(button)
                local currentTeam = DISCONTENT:GetMythicPlusSelectedTeam()
                if currentTeam and DISCONTENT:SetMythicPlusResponse(currentTeam, button.eventId, "no") then
                    DISCONTENT.mythicPlusSelectedEventId = button.eventId
                    DISCONTENT:RefreshMythicPlusUI()
                end
            end)

            row.deleteButton:SetScript("OnClick", function(button)
                local currentTeam = DISCONTENT:GetMythicPlusSelectedTeam()
                if currentTeam and DISCONTENT:DeleteMythicPlusEvent(currentTeam, button.eventId) then
                    DISCONTENT:RefreshMythicPlusUI()
                end
            end)

            self.mythicPlusScheduleRows[i] = row
        end

        local eventEntry = events[i]
        local yesCount, maybeCount, noCount = self:GetMythicPlusResponseCounts(eventEntry)
        local myStatus = self:GetMythicPlusResponseLabel(self:GetMythicPlusResponseStatus(eventEntry))
        local reminderSummary = self:GetMythicPlusReminderSummary(eventEntry)
        local canManage = team and self:CanManageMythicPlusTeam(team)
        local textWidth = contentWidth - 168

        row.eventId = eventEntry.id
        row.yesButton.eventId = eventEntry.id
        row.maybeButton.eventId = eventEntry.id
        row.noButton.eventId = eventEntry.id
        row.deleteButton.eventId = eventEntry.id

        row:SetWidth(contentWidth)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.mythicPlusScheduleListContent, "TOPLEFT", 2, -((i - 1) * 114))
        row:SetPoint("TOPRIGHT", self.mythicPlusScheduleListContent, "TOPRIGHT", -2, -((i - 1) * 114))
        row:SetBackdropColor(eventEntry.id == selectedEventId and 0.17 or 0.08, 0.08, 0.08, 0.92)
        row:SetBackdropBorderColor(eventEntry.id == selectedEventId and 0.95 or 0.42, 0.72, 0.45, 0.95)

        row.deleteButton:ClearAllPoints()
        row.deleteButton:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -8)

        row.noButton:ClearAllPoints()
        row.noButton:SetPoint("RIGHT", row.deleteButton, "LEFT", -4, 0)

        row.maybeButton:ClearAllPoints()
        row.maybeButton:SetPoint("RIGHT", row.noButton, "LEFT", -4, 0)

        row.yesButton:ClearAllPoints()
        row.yesButton:SetPoint("RIGHT", row.maybeButton, "LEFT", -4, 0)

        row.titleText:ClearAllPoints()
        row.titleText:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -8)
        row.titleText:SetWidth(textWidth)
        row.titleText:SetText(eventEntry.title or "-")

        row.infoText:ClearAllPoints()
        row.infoText:SetPoint("TOPLEFT", row.titleText, "BOTTOMLEFT", 0, -8)
        row.infoText:SetWidth(textWidth)
        row.infoText:SetText(string.format("%s %s", eventEntry.dateText or "-", eventEntry.timeText or ""))

        row.statusText:ClearAllPoints()
        row.statusText:SetPoint("TOPLEFT", row.infoText, "BOTTOMLEFT", 0, -6)
        row.statusText:SetWidth(textWidth)
        row.statusText:SetText("Dein Status: " .. myStatus .. (reminderSummary and " | " .. reminderSummary or ""))

        row.responseText:ClearAllPoints()
        row.responseText:SetPoint("TOPLEFT", row.statusText, "BOTTOMLEFT", 0, -6)
        row.responseText:SetWidth(textWidth)
        row.responseText:SetText(string.format("Ja %d / Vllt %d / Nein %d", yesCount, maybeCount, noCount))

        row.deleteButton:SetEnabled(canManage and true or false)
        row:Show()
    end

    for i = #events + 1, #(self.mythicPlusScheduleRows or {}) do
        self.mythicPlusScheduleRows[i]:Hide()
    end

    self.mythicPlusScheduleListContent:SetWidth(contentWidth)
    self.mythicPlusScheduleListContent:SetHeight(math.max(220, #events * 114 + 8))
end

function DISCONTENT:RefreshMythicPlusHeader(team)
    if not self.mythicPlusHeaderPanel then
        return
    end

    if not team then
        self.mythicPlusInfoTitle:SetText("Kein Team ausgewählt")
        self.mythicPlusInfoMeta1:SetText("Erstelle links ein neues Team oder wähle ein vorhandenes aus.")
        self.mythicPlusInfoMeta2:SetText("")
        self.mythicPlusInfoMeta3:SetText("")
        self.mythicPlusInviteAllButton:SetEnabled(false)
        self.mythicPlusInviteAcceptedButton:SetEnabled(false)
        self.mythicPlusWhisperAllButton:SetEnabled(false)
        self.mythicPlusSyncButton:SetEnabled(false)
        return
    end

    local selectedEvent = self.mythicPlusSelectedEventId and self:GetMythicPlusEvent(team, self.mythicPlusSelectedEventId) or nil

    self.mythicPlusInfoTitle:SetText(team.name or "-")
    self.mythicPlusInfoMeta1:SetText(string.format("Owner: %s-%s", team.ownerName or "-", team.ownerRealm or "-"))
    self.mythicPlusInfoMeta2:SetText(string.format("Mitglieder: %d   |   Zuletzt geändert: %s", self:GetMythicPlusTeamCount(team), self:FormatUpdatedAt(team.updatedAt)))
    self.mythicPlusInfoMeta3:SetText(string.format("Von: %s   |   Termin: %s", team.updatedBy or "-", selectedEvent and (selectedEvent.title or "-") or "-"))

    self.mythicPlusInviteAllButton:SetEnabled(true)
    self.mythicPlusInviteAcceptedButton:SetEnabled(true)
    self.mythicPlusWhisperAllButton:SetEnabled(true)
    self.mythicPlusSyncButton:SetEnabled(true)
end

function DISCONTENT:RefreshMythicPlusPermissionState(team)
    local canManage = team and self:CanManageMythicPlusTeam(team) or false

    if self.mythicPlusGuildArmorFilterButton then
        self.mythicPlusGuildArmorFilterButton:SetText(self:GetMythicPlusGuildArmorFilter())
    end

    if self.mythicPlusDeleteButton then
        self.mythicPlusDeleteButton:SetEnabled(canManage)
    end

    if self.mythicPlusNewEventButton then
        self.mythicPlusNewEventButton:SetEnabled(team and canManage and true or false)
    end

if self.mythicPlusExternalInviteButton then
    self.mythicPlusExternalInviteButton:SetEnabled(team and canManage and true or false)
end

    if self.mythicPlusGuildSearchBox then
        if not team then
            self.mythicPlusTeamSearchText = ""
            if (self.mythicPlusGuildSearchBox:GetText() or "") ~= "" then
                self.mythicPlusGuildSearchBox:SetText("")
            end
        end
    end

    if self.mythicPlusGuildPanelOverlayText then
        if team then
            if canManage then
                self.mythicPlusGuildPanelOverlayText:SetText("")
            else
                self.mythicPlusGuildPanelOverlayText:SetText("Nur Owner/Co-Owner können Mitglieder verwalten.")
            end
        else
            self.mythicPlusGuildPanelOverlayText:SetText("Wähle links ein Team aus.")
        end
    end
end

function DISCONTENT:RefreshMythicPlusUI()
    if not self.uiCreated or not self.mythicPlusTabContent then
        return
    end

    local team = self:EnsureMythicPlusSelection()

    self:RefreshMythicPlusTeamRows()
    self:RefreshMythicPlusHeader(team)
    self:RefreshMythicPlusPermissionState(team)
    self:RefreshMythicPlusGuildMemberRows(team)
    self:RefreshMythicPlusMemberRows(team)
    self:RefreshMythicPlusScheduleRows(team)

    if self.mythicPlusEmptyState then
        if team then
            self.mythicPlusEmptyState:Hide()
            self.mythicPlusHeaderPanel:Show()
            self.mythicPlusGuildPanel:Show()
            self.mythicPlusMembersPanel:Show()
            self.mythicPlusSchedulePanel:Show()
        else
            self.mythicPlusEmptyState:Show()
            self.mythicPlusHeaderPanel:Hide()
            self.mythicPlusGuildPanel:Hide()
            self.mythicPlusMembersPanel:Hide()
            self.mythicPlusSchedulePanel:Hide()
        end
    end
end

function DISCONTENT:CreateMythicPlusUI()
    if not self.mythicPlusTabContent then
        self.mythicPlusTabContent = CreateFrame("Frame", nil, self)
    end
    self.mythicPlusTabContent:Hide()

    self.mythicPlusTitle = self.mythicPlusTabContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.mythicPlusTitle:SetPoint("TOPLEFT", 16, -10)
    self.mythicPlusTitle:SetText("")

    self.mythicPlusStatusText = self.mythicPlusTabContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.mythicPlusStatusText:SetPoint("TOPRIGHT", -18, -10)
    self.mythicPlusStatusText:SetJustifyH("RIGHT")
    self.mythicPlusStatusText:SetText("")
    self.mythicPlusStatusText:SetTextColor(0.35, 1.0, 0.35, 1)

    self.mythicPlusTeamPanel = createPanel(self.mythicPlusTabContent)
    self.mythicPlusTeamPanel.title = createLabel(self.mythicPlusTeamPanel, "Meine Teams", "GameFontHighlight")
    self.mythicPlusTeamPanel.title:SetPoint("TOPLEFT", 12, -12)
	


    self.mythicPlusNewButton = createSmallButton(self.mythicPlusTeamPanel, "Neu", 60)
    self.mythicPlusNewButton:SetPoint("TOPLEFT", 12, -36)
    self.mythicPlusNewButton:SetScript("OnClick", function()
        DISCONTENT:OpenMythicPlusTextPrompt(
            "Neues M+ Team",
            "Name der M+ Gruppe",
            "",
            function(text)
                local team = DISCONTENT:CreateMythicPlusTeam(text)
                if team then
                    DISCONTENT:SetMythicPlusStatusText("Team '" .. (team.name or "-") .. "' erstellt.")
                    DISCONTENT:RefreshMythicPlusUI()
                else
                    DISCONTENT:SetMythicPlusStatusText("Bitte einen gültigen Teamnamen eingeben.")
                end
            end
        )
    end)

    self.mythicPlusDeleteButton = createSmallButton(self.mythicPlusTeamPanel, "Löschen", 74)
    self.mythicPlusDeleteButton:SetPoint("LEFT", self.mythicPlusNewButton, "RIGHT", 6, 0)
    self.mythicPlusDeleteButton:SetScript("OnClick", function()
        local team = DISCONTENT:GetMythicPlusSelectedTeam()
        if not team or not DISCONTENT:CanManageMythicPlusTeam(team) then
            return
        end

        DISCONTENT:BroadcastMythicPlusDelete(team)
        DISCONTENT:DeleteMythicPlusTeamLocal(team.id)
        DISCONTENT:SetMythicPlusStatusText("Team wurde gelöscht.")
        DISCONTENT:RefreshMythicPlusUI()
    end)

    self.mythicPlusTeamListFrame = CreateFrame("ScrollFrame", "DISCONTENTMythicPlusTeamScrollFrame", self.mythicPlusTeamPanel, "UIPanelScrollFrameTemplate")
    self.mythicPlusTeamListContent = CreateFrame("Frame", nil, self.mythicPlusTeamListFrame)
    self.mythicPlusTeamListContent:SetSize(220, 240)
    self.mythicPlusTeamListFrame:SetScrollChild(self.mythicPlusTeamListContent)

    self.mythicPlusHeaderPanel = createPanel(self.mythicPlusTabContent)
    self.mythicPlusInfoTitle = createLabel(self.mythicPlusHeaderPanel, "Kein Team ausgewählt", "GameFontHighlightLarge")
    self.mythicPlusInfoTitle:SetPoint("TOPLEFT", 12, -12)

    self.mythicPlusInfoMeta1 = createLabel(self.mythicPlusHeaderPanel, "", "GameFontNormal")
    self.mythicPlusInfoMeta1:SetPoint("TOPLEFT", self.mythicPlusInfoTitle, "BOTTOMLEFT", 0, -10)

    self.mythicPlusInfoMeta2 = createLabel(self.mythicPlusHeaderPanel, "", "GameFontNormal")
    self.mythicPlusInfoMeta2:SetPoint("TOPLEFT", self.mythicPlusInfoMeta1, "BOTTOMLEFT", 0, -6)

    self.mythicPlusInfoMeta3 = createLabel(self.mythicPlusHeaderPanel, "", "GameFontNormal")
    self.mythicPlusInfoMeta3:SetPoint("TOPLEFT", self.mythicPlusInfoMeta2, "BOTTOMLEFT", 0, -6)

    self.mythicPlusSyncHintText = createLabel(self.mythicPlusHeaderPanel, "Sync-Hinweis: M+-Daten werden nicht dauerhaft live abgeglichen. Der Austausch startet erst über 'Sync' oder 'Sync anfordern' – auch bei externen Mitgliedern mit installiertem Addon. Bei jeder Änderung also einfach einmal Sync drücken.", "GameFontNormalSmall")
    self.mythicPlusSyncHintText:SetPoint("TOPLEFT", self.mythicPlusInfoMeta3, "BOTTOMLEFT", 0, -10)
    self.mythicPlusSyncHintText:SetPoint("TOPRIGHT", self.mythicPlusHeaderPanel, "TOPRIGHT", -12, 0)
    self.mythicPlusSyncHintText:SetJustifyH("LEFT")
    self.mythicPlusSyncHintText:SetJustifyV("TOP")
    self.mythicPlusSyncHintText:SetSpacing(1)
    self.mythicPlusSyncHintText:SetTextColor(0.78, 0.78, 0.78, 1)

    self.mythicPlusInviteAllButton = createSmallButton(self.mythicPlusHeaderPanel, "Alle Mitgl. inviten", 120)
    self.mythicPlusInviteAllButton:SetScript("OnClick", function()
        local team = DISCONTENT:GetMythicPlusSelectedTeam()
        if team then
            DISCONTENT:InviteAllMythicPlusMembers(team)
        end
    end)

    self.mythicPlusInviteAcceptedButton = createSmallButton(self.mythicPlusHeaderPanel, "Zugesagte inviten", 130)
    self.mythicPlusInviteAcceptedButton:SetScript("OnClick", function()
        local team = DISCONTENT:GetMythicPlusSelectedTeam()
        if team then
            DISCONTENT:InviteAcceptedMythicPlusMembers(team)
        end
    end)

    self.mythicPlusWhisperAllButton = createSmallButton(self.mythicPlusHeaderPanel, "Allen schreiben", 110)
    self.mythicPlusWhisperAllButton:SetScript("OnClick", function()
        local team = DISCONTENT:GetMythicPlusSelectedTeam()
        if not team then
            return
        end

        DISCONTENT:OpenMythicPlusTextPrompt(
            "Team anschreiben",
            "Whisper an alle Team-Mitglieder",
            "",
            function(text)
                DISCONTENT:WhisperAllMythicPlusMembers(team, text)
            end
        )
    end)

    self.mythicPlusSyncButton = createSmallButton(self.mythicPlusHeaderPanel, "Sync", 70)
    self.mythicPlusSyncButton:SetScript("OnClick", function()
        local team = DISCONTENT:GetMythicPlusSelectedTeam()
        if team then
            DISCONTENT:SyncMythicPlusTeam(team)
        end
    end)

    self.mythicPlusGuildPanel = createPanel(self.mythicPlusTabContent)
    self.mythicPlusGuildPanel.title = createLabel(self.mythicPlusGuildPanel, "Gildenmitglieder", "GameFontHighlight")
    self.mythicPlusGuildPanel.title:SetPoint("TOPLEFT", 12, -12)
self.mythicPlusExternalInviteButton = createSmallButton(self.mythicPlusGuildPanel, "Invite extern", 110)
self.mythicPlusExternalInviteButton:SetPoint("TOPRIGHT", -12, -10)
self.mythicPlusExternalInviteButton:SetScript("OnClick", function()
    local team = DISCONTENT:GetMythicPlusSelectedTeam()
    if team then
        DISCONTENT:OpenMythicPlusExternalInvitePopup(team)
    end
end)
    self.mythicPlusGuildSearchLabel = createLabel(self.mythicPlusGuildPanel, "Suche", "GameFontNormal")
    self.mythicPlusGuildSearchLabel:SetPoint("TOPLEFT", 12, -38)

    self.mythicPlusGuildSearchBox = CreateFrame("EditBox", nil, self.mythicPlusGuildPanel, "InputBoxTemplate")
    self.mythicPlusGuildSearchBox:SetAutoFocus(false)
    self.mythicPlusGuildSearchBox:SetSize(120, 24)
    self.mythicPlusGuildSearchBox:SetPoint("LEFT", self.mythicPlusGuildSearchLabel, "RIGHT", 8, 0)
    self.mythicPlusGuildSearchBox:SetScript("OnTextChanged", function(editBox)
        DISCONTENT.mythicPlusTeamSearchText = editBox:GetText() or ""
        DISCONTENT:RefreshMythicPlusUI()
    end)

    self.mythicPlusGuildArmorLabel = createLabel(self.mythicPlusGuildPanel, "Armor", "GameFontNormal")
    self.mythicPlusGuildArmorLabel:SetPoint("LEFT", self.mythicPlusGuildSearchBox, "RIGHT", 18, 0)

    self.mythicPlusGuildArmorFilterButton = createSmallButton(self.mythicPlusGuildPanel, self:GetMythicPlusGuildArmorFilter(), 82)
    self.mythicPlusGuildArmorFilterButton:SetPoint("LEFT", self.mythicPlusGuildArmorLabel, "RIGHT", 8, 0)
    self.mythicPlusGuildArmorFilterButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    self.mythicPlusGuildArmorFilterButton:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            DISCONTENT:SetMythicPlusGuildArmorFilter("ALLE")
        else
            DISCONTENT:CycleMythicPlusGuildArmorFilter()
        end
        DISCONTENT:RefreshMythicPlusUI()
    end)

    self.mythicPlusGuildListFrame = CreateFrame("ScrollFrame", "DISCONTENTMythicPlusGuildScrollFrame", self.mythicPlusGuildPanel, "UIPanelScrollFrameTemplate")
    self.mythicPlusGuildListContent = CreateFrame("Frame", nil, self.mythicPlusGuildListFrame)
    self.mythicPlusGuildListContent:SetSize(320, 240)
    self.mythicPlusGuildListFrame:SetScrollChild(self.mythicPlusGuildListContent)

    self.mythicPlusGuildPanelOverlayText = createLabel(self.mythicPlusGuildPanel, "", "GameFontNormalSmall")
    self.mythicPlusGuildPanelOverlayText:SetPoint("BOTTOMLEFT", 12, 12)
    self.mythicPlusGuildPanelOverlayText:SetTextColor(0.75, 0.75, 0.75, 1)

    self.mythicPlusMembersPanel = createPanel(self.mythicPlusTabContent)
    self.mythicPlusMembersPanel.title = createLabel(self.mythicPlusMembersPanel, "Team-Mitglieder", "GameFontHighlight")
    self.mythicPlusMembersPanel.title:SetPoint("TOPLEFT", 12, -12)

    self.mythicPlusMemberHeader = createLabel(self.mythicPlusMembersPanel, "Name / Klasse / Armor / Rolle / Co / + / @ / x", "GameFontNormalSmall")
    self.mythicPlusMemberHeader:SetPoint("TOPLEFT", 12, -36)

    self.mythicPlusMemberListFrame = CreateFrame("ScrollFrame", "DISCONTENTMythicPlusMembersScrollFrame", self.mythicPlusMembersPanel, "UIPanelScrollFrameTemplate")
    self.mythicPlusMemberListContent = CreateFrame("Frame", nil, self.mythicPlusMemberListFrame)
    self.mythicPlusMemberListContent:SetSize(470, 240)
    self.mythicPlusMemberListFrame:SetScrollChild(self.mythicPlusMemberListContent)

    self.mythicPlusSchedulePanel = createPanel(self.mythicPlusTabContent)
    self.mythicPlusSchedulePanel.title = createLabel(self.mythicPlusSchedulePanel, "Terminplaner", "GameFontHighlight")
    self.mythicPlusSchedulePanel.title:SetPoint("TOPLEFT", 12, -12)

    self.mythicPlusNewEventButton = createSmallButton(self.mythicPlusSchedulePanel, "Neuer Termin", 100)
    self.mythicPlusNewEventButton:SetPoint("TOPRIGHT", -14, -10)
    self.mythicPlusNewEventButton:SetScript("OnClick", function()
        local team = DISCONTENT:GetMythicPlusSelectedTeam()
        if team then
            DISCONTENT:OpenMythicPlusEventPopup(team, nil)
        end
    end)

    self.mythicPlusScheduleListFrame = CreateFrame("ScrollFrame", "DISCONTENTMythicPlusScheduleScrollFrame", self.mythicPlusSchedulePanel, "UIPanelScrollFrameTemplate")
    self.mythicPlusScheduleListContent = CreateFrame("Frame", nil, self.mythicPlusScheduleListFrame)
    self.mythicPlusScheduleListContent:SetSize(370, 240)
    self.mythicPlusScheduleListFrame:SetScrollChild(self.mythicPlusScheduleListContent)

    self.mythicPlusEmptyState = self.mythicPlusTabContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.mythicPlusEmptyState:SetPoint("CENTER", self.mythicPlusTabContent, "CENTER", 90, 0)
    self.mythicPlusEmptyState:SetText("Wähle links ein Team aus oder erstelle ein neues.")
    self.mythicPlusEmptyState:SetTextColor(0.8, 0.8, 0.8, 1)

    self:StartMythicPlusReminderTicker()
end

function DISCONTENT:UpdateMythicPlusLayout()
    if not self.mythicPlusTabContent then
        return
    end

    self.mythicPlusTabContent:ClearAllPoints()
    self.mythicPlusTabContent:SetPoint("TOPLEFT", self, "TOPLEFT", 14, -72)
    self.mythicPlusTabContent:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -16, 16)

    self.mythicPlusStatusText:ClearAllPoints()
    self.mythicPlusStatusText:SetPoint("TOPRIGHT", self.mythicPlusTabContent, "TOPRIGHT", -4, 2)

    self.mythicPlusTeamPanel:ClearAllPoints()
    self.mythicPlusTeamPanel:SetPoint("TOPLEFT", self.mythicPlusTabContent, "TOPLEFT", 0, -18)
    self.mythicPlusTeamPanel:SetPoint("BOTTOMLEFT", self.mythicPlusTabContent, "BOTTOMLEFT", 0, 0)
    self.mythicPlusTeamPanel:SetWidth(250)

    self.mythicPlusTeamListFrame:ClearAllPoints()
    self.mythicPlusTeamListFrame:SetPoint("TOPLEFT", self.mythicPlusTeamPanel, "TOPLEFT", 10, -68)
    self.mythicPlusTeamListFrame:SetPoint("BOTTOMRIGHT", self.mythicPlusTeamPanel, "BOTTOMRIGHT", -28, 12)

    local rightAreaLeft = self.mythicPlusTeamPanel:GetWidth() + 12
    local rightAreaWidth = self.mythicPlusTabContent:GetWidth() - rightAreaLeft
    local colGap = 12
    local rowGap = 12

    local usableRightWidth = rightAreaWidth - colGap
    local baseColWidth = usableRightWidth / 2
    local leftColWidth = math.floor(baseColWidth * 1.15)
    local rightColWidth = usableRightWidth - leftColWidth

    local availableHeight = self.mythicPlusTabContent:GetHeight() - 18
    local topRowHeight = math.floor((availableHeight - rowGap) / 2)
    local bottomRowHeight = availableHeight - topRowHeight - rowGap

    self.mythicPlusHeaderPanel:ClearAllPoints()
    self.mythicPlusHeaderPanel:SetPoint("TOPLEFT", self.mythicPlusTabContent, "TOPLEFT", rightAreaLeft, -18)
    self.mythicPlusHeaderPanel:SetWidth(leftColWidth)
    self.mythicPlusHeaderPanel:SetHeight(topRowHeight)

    self.mythicPlusGuildPanel:ClearAllPoints()
    self.mythicPlusGuildPanel:SetPoint("TOPLEFT", self.mythicPlusHeaderPanel, "TOPRIGHT", colGap, 0)
    self.mythicPlusGuildPanel:SetWidth(rightColWidth)
    self.mythicPlusGuildPanel:SetHeight(topRowHeight)

    self.mythicPlusMembersPanel:ClearAllPoints()
    self.mythicPlusMembersPanel:SetPoint("TOPLEFT", self.mythicPlusHeaderPanel, "BOTTOMLEFT", 0, -rowGap)
    self.mythicPlusMembersPanel:SetWidth(leftColWidth)
    self.mythicPlusMembersPanel:SetHeight(bottomRowHeight)

    self.mythicPlusSchedulePanel:ClearAllPoints()
    self.mythicPlusSchedulePanel:SetPoint("TOPLEFT", self.mythicPlusGuildPanel, "BOTTOMLEFT", 0, -rowGap)
    self.mythicPlusSchedulePanel:SetWidth(rightColWidth)
    self.mythicPlusSchedulePanel:SetHeight(bottomRowHeight)

    self.mythicPlusInviteAllButton:ClearAllPoints()
    self.mythicPlusInviteAllButton:SetPoint("BOTTOMLEFT", self.mythicPlusHeaderPanel, "BOTTOMLEFT", 12, 42)

    self.mythicPlusInviteAcceptedButton:ClearAllPoints()
    self.mythicPlusInviteAcceptedButton:SetPoint("LEFT", self.mythicPlusInviteAllButton, "RIGHT", 6, 0)

    if self.mythicPlusSyncHintText then
        self.mythicPlusSyncHintText:ClearAllPoints()
        self.mythicPlusSyncHintText:SetPoint("TOPLEFT", self.mythicPlusInfoMeta3, "BOTTOMLEFT", 0, -10)
        self.mythicPlusSyncHintText:SetWidth(math.max(140, leftColWidth - 24))
    end

    self.mythicPlusWhisperAllButton:ClearAllPoints()
    self.mythicPlusWhisperAllButton:SetPoint("BOTTOMLEFT", self.mythicPlusHeaderPanel, "BOTTOMLEFT", 12, 14)

    self.mythicPlusSyncButton:ClearAllPoints()
    self.mythicPlusSyncButton:SetPoint("LEFT", self.mythicPlusWhisperAllButton, "RIGHT", 6, 0)

    self.mythicPlusGuildListFrame:ClearAllPoints()
    self.mythicPlusGuildListFrame:SetPoint("TOPLEFT", self.mythicPlusGuildPanel, "TOPLEFT", 10, -68)
    self.mythicPlusGuildListFrame:SetPoint("BOTTOMRIGHT", self.mythicPlusGuildPanel, "BOTTOMRIGHT", -28, 30)

    self.mythicPlusMemberListFrame:ClearAllPoints()
    self.mythicPlusMemberListFrame:SetPoint("TOPLEFT", self.mythicPlusMembersPanel, "TOPLEFT", 10, -58)
    self.mythicPlusMemberListFrame:SetPoint("BOTTOMRIGHT", self.mythicPlusMembersPanel, "BOTTOMRIGHT", -28, 12)

    self.mythicPlusScheduleListFrame:ClearAllPoints()
    self.mythicPlusScheduleListFrame:SetPoint("TOPLEFT", self.mythicPlusSchedulePanel, "TOPLEFT", 10, -42)
    self.mythicPlusScheduleListFrame:SetPoint("BOTTOMRIGHT", self.mythicPlusSchedulePanel, "BOTTOMRIGHT", -28, 12)

    if self.mythicPlusTeamListFrame.ScrollBar then
        self.mythicPlusTeamListFrame.ScrollBar:ClearAllPoints()
        self.mythicPlusTeamListFrame.ScrollBar:SetPoint("TOPLEFT", self.mythicPlusTeamListFrame, "TOPRIGHT", 4, -16)
        self.mythicPlusTeamListFrame.ScrollBar:SetPoint("BOTTOMLEFT", self.mythicPlusTeamListFrame, "BOTTOMRIGHT", 4, 16)
    end

    if self.mythicPlusGuildListFrame.ScrollBar then
        self.mythicPlusGuildListFrame.ScrollBar:ClearAllPoints()
        self.mythicPlusGuildListFrame.ScrollBar:SetPoint("TOPLEFT", self.mythicPlusGuildListFrame, "TOPRIGHT", 4, -16)
        self.mythicPlusGuildListFrame.ScrollBar:SetPoint("BOTTOMLEFT", self.mythicPlusGuildListFrame, "BOTTOMRIGHT", 4, 16)
    end

    if self.mythicPlusMemberListFrame.ScrollBar then
        self.mythicPlusMemberListFrame.ScrollBar:ClearAllPoints()
        self.mythicPlusMemberListFrame.ScrollBar:SetPoint("TOPLEFT", self.mythicPlusMemberListFrame, "TOPRIGHT", 4, -16)
        self.mythicPlusMemberListFrame.ScrollBar:SetPoint("BOTTOMLEFT", self.mythicPlusMemberListFrame, "BOTTOMRIGHT", 4, 16)
    end

    if self.mythicPlusScheduleListFrame.ScrollBar then
        self.mythicPlusScheduleListFrame.ScrollBar:ClearAllPoints()
        self.mythicPlusScheduleListFrame.ScrollBar:SetPoint("TOPLEFT", self.mythicPlusScheduleListFrame, "TOPRIGHT", 4, -16)
        self.mythicPlusScheduleListFrame.ScrollBar:SetPoint("BOTTOMLEFT", self.mythicPlusScheduleListFrame, "BOTTOMRIGHT", 4, 16)
    end
end