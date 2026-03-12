local DISCONTENT = _G.DISCONTENT
if not DISCONTENT then return end

DISCONTENT.newsCategories = {
    "Allgemein",
    "Raid",
    "WICHTIG",
}

local function TrimText(value)
    value = tostring(value or "")
    value = value:gsub("^%s+", "")
    value = value:gsub("%s+$", "")
    return value
end

local function SplitString(text, delimiter)
    local result = {}
    text = tostring(text or "")

    if delimiter == nil or delimiter == "" then
        result[1] = text
        return result
    end

    local startPos = 1

    while true do
        local delimStart, delimEnd = string.find(text, delimiter, startPos, true)
        if not delimStart then
            result[#result + 1] = string.sub(text, startPos)
            break
        end

        result[#result + 1] = string.sub(text, startPos, delimStart - 1)
        startPos = delimEnd + 1
    end

    return result
end

function DISCONTENT:EnsureNewsDB()
    if type(_G.DISCONTENTDB) ~= "table" then
        _G.DISCONTENTDB = {}
    end

    self.db = _G.DISCONTENTDB

    if type(self.db.news) ~= "table" then
        self.db.news = {}
    end

    if type(self.db.news.entries) ~= "table" then
        self.db.news.entries = {}
    end

    if type(self.db.news.seen) ~= "table" then
        self.db.news.seen = {}
    end

    if type(self.db.news.revision) ~= "number" then
        self.db.news.revision = 0
    end

    self.newsEntries = self.db.news.entries
    self.newsSeen = self.db.news.seen
    self.newsRevision = tonumber(self.db.news.revision) or 0

    return self.db.news
end

function DISCONTENT:CopyNewsEntry(entry)
    if type(entry) ~= "table" then
        return nil
    end

    return {
        id = tostring(entry.id or ""),
        timestamp = tonumber(entry.timestamp) or tonumber(entry.updatedAt) or time(),
        dateText = tostring(entry.dateText or ""),
        author = tostring(entry.author or "Unbekannt"),
        category = self:GetNormalizedNewsCategory(entry.category),
        title = tostring(entry.title or ""),
        text = tostring(entry.text or ""),
        pinned = self:IsImportantNews(entry) and true or false,
        updatedAt = tonumber(entry.updatedAt) or tonumber(entry.timestamp) or time(),
    }
end

function DISCONTENT:GetNewsStorageEntries()
    self:EnsureNewsDB()
    return self.newsEntries or {}
end

function DISCONTENT:GetNormalizedNewsCategory(category)
    local key = self:NormalizeText(category)

    if key == "raid" then
        return "Raid"
    elseif key == "wichtig" or key == "important" or key == "high" or key == "pinned" then
        return "WICHTIG"
    end

    return "Allgemein"
end

function DISCONTENT:IsNewsCategoryImportant(category)
    return self:GetNormalizedNewsCategory(category) == "WICHTIG"
end

function DISCONTENT:BuildNewsId()
    local playerName = self:SafeName(UnitName("player") or "player")
    return string.format("%s-%d-%d", playerName, time() or 0, math.random(1000, 9999))
end

function DISCONTENT:BuildNewsRevision()
    return ((time() or 0) * 1000) + math.random(0, 999)
end

function DISCONTENT:GetNewsEntryIndexById(entryId)
    local needle = tostring(entryId or "")
    if needle == "" then
        return nil
    end

    for index = 1, #(self.newsEntries or {}) do
        local entry = self.newsEntries[index]
        if entry and tostring(entry.id or "") == needle then
            return index
        end
    end

    return nil
end

function DISCONTENT:GetNewsEntryById(entryId)
    local index = self:GetNewsEntryIndexById(entryId)
    if index then
        return self.newsEntries[index], index
    end
    return nil, nil
end

function DISCONTENT:RefreshNewsDataViews()
    if self.RefreshNewsView then
        self:RefreshNewsView()
    end

    if self.RefreshWelcomeNewsView then
        self:RefreshWelcomeNewsView()
    end

    if self.welcomeFrame and self.welcomeFrame:IsShown() and self.MarkVisibleNewsAsSeen then
        self:MarkVisibleNewsAsSeen()
    end

    if self.RefreshOfficerUI then
        self:RefreshOfficerUI()
    end
end

function DISCONTENT:SetNewsEntries(entries, revision)
    self:EnsureNewsDB()

    local nextEntries = {}

    for index = 1, #(entries or {}) do
        local copied = self:CopyNewsEntry(entries[index])
        if copied and copied.id ~= "" then
            nextEntries[#nextEntries + 1] = copied
        end
    end

    self.newsEntries = nextEntries
    self.db.news.entries = self.newsEntries
    self.newsRevision = tonumber(revision) or tonumber(self.newsRevision) or 0
    self.db.news.revision = self.newsRevision

    self:SaveSettings()
    self:RefreshNewsDataViews()
end

function DISCONTENT:MarkNewsSeen(entryId)
    self:EnsureNewsDB()

    local key = tostring(entryId or "")
    if key == "" then
        return
    end

    self.newsSeen[key] = time() or true
    self.db.news.seen = self.newsSeen
    self:SaveSettings()
end

function DISCONTENT:MarkVisibleNewsAsSeen()
    self:EnsureNewsDB()

    local changed = false
    local unreadEntries = self:GetUnreadNewsEntries()

    for index = 1, #unreadEntries do
        local entry = unreadEntries[index]
        local key = tostring(entry.id or "")
        if key ~= "" and not self.newsSeen[key] then
            self.newsSeen[key] = time() or true
            changed = true
        end
    end

    if changed then
        self.db.news.seen = self.newsSeen
        self:SaveSettings()

        C_Timer.After(0, function()
            if DISCONTENT and DISCONTENT.RefreshWelcomeNewsView then
                DISCONTENT:RefreshWelcomeNewsView()
            end
        end)
    end
end

function DISCONTENT:GetUnreadNewsEntries()
    self:EnsureNewsDB()

    local unread = {}
    local entries = self:GetSortedNewsEntries()

    for index = 1, #entries do
        local entry = entries[index]
        local key = tostring((entry and entry.id) or "")
        if key ~= "" and not self.newsSeen[key] then
            unread[#unread + 1] = entry
        end
    end

    return unread
end

function DISCONTENT:TryShowWelcomeForUnreadNews()
    local unreadEntries = self:GetUnreadNewsEntries()
    if #unreadEntries <= 0 then
        return false
    end

    if self:IsShown() then
        return false
    end

    self:ShowWelcomeWindow()
    return true
end

function DISCONTENT:CreateOrUpdateNewsEntry(existingId, category, title, text)
    self:EnsureNewsDB()

    if not (self.CanSeeOfficerTab and self:CanSeeOfficerTab()) then
        return false, "Nur Officer können News speichern."
    end

    local cleanTitle = TrimText(title)
    local cleanText = TrimText(text)
    local cleanCategory = self:GetNormalizedNewsCategory(category)

    if cleanTitle == "" then
        return false, "Bitte einen Betreff eingeben."
    end

    if cleanText == "" then
        return false, "Bitte einen Nachrichtentext eingeben."
    end

    local now = time() or 0
    local entryId = tostring(existingId or "")
    if entryId == "" then
        entryId = self:BuildNewsId()
    end

    local entry = {
        id = entryId,
        timestamp = now,
        updatedAt = now,
        dateText = date("%d.%m.%Y %H:%M", now),
        author = self:SafeName(UnitName("player") or "Unbekannt"),
        category = cleanCategory,
        title = cleanTitle,
        text = cleanText,
        pinned = self:IsNewsCategoryImportant(cleanCategory),
    }

    local existingIndex = self:GetNewsEntryIndexById(entryId)
    if existingIndex then
        self.newsEntries[existingIndex] = entry
    else
        self.newsEntries[#self.newsEntries + 1] = entry
    end

    self.newsRevision = self:BuildNewsRevision()
    self.db.news.entries = self.newsEntries
    self.db.news.revision = self.newsRevision

    self:MarkNewsSeen(entryId)
    self:SaveSettings()
    self:RefreshNewsDataViews()

    if self.BroadcastNewsSnapshot then
        self:BroadcastNewsSnapshot()
    end

    return true, entry
end

function DISCONTENT:DeleteNewsEntry(entryId)
    self:EnsureNewsDB()

    if not (self.CanSeeOfficerTab and self:CanSeeOfficerTab()) then
        return false, "Nur Officer können News löschen."
    end

    local index = self:GetNewsEntryIndexById(entryId)
    if not index then
        return false, "News-Eintrag nicht gefunden."
    end

    local entry = self.newsEntries[index]
    table.remove(self.newsEntries, index)

    if entry and entry.id then
        self.newsSeen[tostring(entry.id)] = nil
    end

    self.newsRevision = self:BuildNewsRevision()
    self.db.news.entries = self.newsEntries
    self.db.news.revision = self.newsRevision
    self.db.news.seen = self.newsSeen

    self:SaveSettings()
    self:RefreshNewsDataViews()

    if self.BroadcastNewsSnapshot then
        self:BroadcastNewsSnapshot()
    end

    return true
end

function DISCONTENT:EscapeNewsSyncValue(value)
    value = tostring(value or "")
    value = value:gsub("%%", "%%25")
    value = value:gsub("|", "%%7C")
    value = value:gsub("%~", "%%7E")
    value = value:gsub("%^", "%%5E")
    value = value:gsub("\r", "")
    value = value:gsub("\n", "%%0A")
    return value
end

function DISCONTENT:UnescapeNewsSyncValue(value)
    value = tostring(value or "")
    value = value:gsub("%%0A", "\n")
    value = value:gsub("%%5E", "^")
    value = value:gsub("%%7E", "~")
    value = value:gsub("%%7C", "|")
    value = value:gsub("%%25", "%%")
    return value
end

function DISCONTENT:SerializeNewsEntries(entries)
    local serializedEntries = {}

    for index = 1, #(entries or {}) do
        local entry = entries[index]
        if entry and tostring(entry.id or "") ~= "" then
            serializedEntries[#serializedEntries + 1] = table.concat({
                self:EscapeNewsSyncValue(entry.id),
                self:EscapeNewsSyncValue(entry.timestamp),
                self:EscapeNewsSyncValue(entry.dateText),
                self:EscapeNewsSyncValue(entry.author),
                self:EscapeNewsSyncValue(self:GetNormalizedNewsCategory(entry.category)),
                self:EscapeNewsSyncValue(entry.title),
                self:EscapeNewsSyncValue(entry.text),
                self:EscapeNewsSyncValue(self:IsImportantNews(entry) and "1" or "0"),
                self:EscapeNewsSyncValue(entry.updatedAt),
            }, "^")
        end
    end

    return table.concat(serializedEntries, "~")
end

function DISCONTENT:DeserializeNewsEntries(payload)
    local entries = {}
    payload = tostring(payload or "")

    if payload == "" then
        return entries
    end

    local rowParts = SplitString(payload, "~")

    for rowIndex = 1, #rowParts do
        local rowText = rowParts[rowIndex]
        if rowText and rowText ~= "" then
            local fields = SplitString(rowText, "^")

            local category = self:GetNormalizedNewsCategory(self:UnescapeNewsSyncValue(fields[5] or "Allgemein"))
            local important = self:UnescapeNewsSyncValue(fields[8] or "0") == "1"

            local entry = {
                id = self:UnescapeNewsSyncValue(fields[1] or ""),
                timestamp = tonumber(self:UnescapeNewsSyncValue(fields[2] or "0")) or 0,
                dateText = self:UnescapeNewsSyncValue(fields[3] or ""),
                author = self:UnescapeNewsSyncValue(fields[4] or "Unbekannt"),
                category = category,
                title = self:UnescapeNewsSyncValue(fields[6] or ""),
                text = self:UnescapeNewsSyncValue(fields[7] or ""),
                pinned = important or category == "WICHTIG",
                updatedAt = tonumber(self:UnescapeNewsSyncValue(fields[9] or "0")) or 0,
            }

            if entry.id ~= "" then
                if not entry.timestamp or entry.timestamp <= 0 then
                    entry.timestamp = entry.updatedAt > 0 and entry.updatedAt or time()
                end
                if entry.dateText == "" then
                    entry.dateText = date("%d.%m.%Y %H:%M", entry.timestamp)
                end
                entries[#entries + 1] = entry
            end
        end
    end

    return entries
end

function DISCONTENT:BroadcastNewsSnapshot()
    self:EnsureNewsDB()

    if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then
        return false, "Addon-Kommunikation nicht verfügbar."
    end

    if not IsInGuild() then
        return false, "Du bist in keiner Gilde."
    end

    local payload = self:SerializeNewsEntries(self.newsEntries)
    local chunkSize = tonumber(self.newsChunkSize) or 210
    local totalChunks = math.max(1, math.ceil(#payload / chunkSize))
    local messageId = string.format("NEWS-%d-%d", time() or 0, math.random(1000, 9999))

    C_ChatInfo.SendAddonMessage(
        self.newsSyncPrefix,
        "S|" .. messageId .. "|" .. tostring(tonumber(self.newsRevision) or 0) .. "|" .. tostring(totalChunks),
        "GUILD"
    )

    for chunkIndex = 1, totalChunks do
        local startPos = ((chunkIndex - 1) * chunkSize) + 1
        local chunk = payload:sub(startPos, startPos + chunkSize - 1)
        C_ChatInfo.SendAddonMessage(
            self.newsSyncPrefix,
            "C|" .. messageId .. "|" .. tostring(chunkIndex) .. "|" .. chunk,
            "GUILD"
        )
    end

    C_ChatInfo.SendAddonMessage(self.newsSyncPrefix, "E|" .. messageId, "GUILD")
    return true
end

function DISCONTENT:RequestNewsSync()
    if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then
        return false
    end

    if not IsInGuild() then
        return false
    end

    local requestId = string.format("REQ-%d-%d", time() or 0, math.random(1000, 9999))
    C_ChatInfo.SendAddonMessage(self.newsSyncPrefix, "REQ|" .. requestId, "GUILD")
    return true
end

function DISCONTENT:AcceptIncomingNewsSnapshot(entries, revision)
    self:EnsureNewsDB()

    local incomingRevision = tonumber(revision) or 0
    local localRevision = tonumber(self.newsRevision) or 0
    local localCount = #(self.newsEntries or {})
    local incomingCount = #(entries or {})

    if incomingRevision < localRevision then
        return false
    end

    if incomingRevision == localRevision and incomingCount <= localCount then
        return false
    end

    self:SetNewsEntries(entries, incomingRevision)

    if self.loginCompleted and self.TryShowWelcomeForUnreadNews then
        C_Timer.After(0.3, function()
            if DISCONTENT and DISCONTENT.TryShowWelcomeForUnreadNews then
                DISCONTENT:TryShowWelcomeForUnreadNews()
            end
        end)
    end

    return true
end

function DISCONTENT:HandleNewsAddonMessage(prefix, message, channel, sender)
    if prefix ~= self.newsSyncPrefix then
        return
    end

    local playerName = self:SafeName(UnitName("player") or "")
    if self:SafeName(sender or "") == playerName then
        return
    end

    self.newsInbound = self.newsInbound or {}

    local opcode, rest = tostring(message or ""):match("^([^|]+)|?(.*)$")
    if not opcode or opcode == "" then
        return
    end

    if opcode == "REQ" then
        if #(self.newsEntries or {}) <= 0 and (tonumber(self.newsRevision) or 0) <= 0 then
            return
        end

        local delay = 0.35 + (math.random(0, 60) / 100)
        C_Timer.After(delay, function()
            if DISCONTENT and DISCONTENT.BroadcastNewsSnapshot then
                DISCONTENT:BroadcastNewsSnapshot()
            end
        end)
        return
    end

    if opcode == "S" then
        local messageId, revisionText, totalChunksText = rest:match("^([^|]+)|([^|]+)|([^|]+)$")
        if not messageId then
            return
        end

        self.newsInbound[messageId] = {
            revision = tonumber(revisionText) or 0,
            total = tonumber(totalChunksText) or 0,
            sender = sender,
            chunks = {},
        }
        return
    end

    if opcode == "C" then
        local messageId, indexText, chunk = rest:match("^([^|]+)|([^|]+)|?(.*)$")
        if not messageId then
            return
        end

        local inbound = self.newsInbound[messageId]
        if not inbound then
            inbound = {
                revision = 0,
                total = 0,
                sender = sender,
                chunks = {},
            }
            self.newsInbound[messageId] = inbound
        end

        inbound.chunks[tonumber(indexText) or (#inbound.chunks + 1)] = chunk or ""
        return
    end

    if opcode == "E" then
        local messageId = rest
        local inbound = self.newsInbound[messageId]
        if not inbound then
            return
        end

        local parts = {}
        for chunkIndex = 1, math.max(1, inbound.total or 0) do
            if inbound.chunks[chunkIndex] == nil then
                return
            end
            parts[#parts + 1] = inbound.chunks[chunkIndex]
        end

        self.newsInbound[messageId] = nil

        local payload = table.concat(parts, "")
        local entries = self:DeserializeNewsEntries(payload)
        self:AcceptIncomingNewsSnapshot(entries, inbound.revision)
    end
end
