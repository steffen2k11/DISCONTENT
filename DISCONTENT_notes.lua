local DISCONTENT = _G.DISCONTENT
if not DISCONTENT then return end

function DISCONTENT:GetNotesCharacterKey()
    local name, realm = self:GetPlayerNameRealm()
    return self:GetCharacterKey(name, realm)
end

function DISCONTENT:GetNotesDB()
    if type(_G.DISCONTENTDB) ~= "table" then
        _G.DISCONTENTDB = {}
    end

    if type(_G.DISCONTENTDB.notes) ~= "table" then
        _G.DISCONTENTDB.notes = {}
    end

    if type(_G.DISCONTENTDB.notes.characters) ~= "table" then
        _G.DISCONTENTDB.notes.characters = {}
    end

    local charKey = self:GetNotesCharacterKey()

    if type(_G.DISCONTENTDB.notes.characters[charKey]) ~= "table" then
        _G.DISCONTENTDB.notes.characters[charKey] = {}
    end

    if type(_G.DISCONTENTDB.notes.characters[charKey].items) ~= "table" then
        _G.DISCONTENTDB.notes.characters[charKey].items = {}
    end

    return _G.DISCONTENTDB.notes.characters[charKey]
end

function DISCONTENT:GetNotesItems()
    local notesDb = self:GetNotesDB()
    return notesDb.items
end

function DISCONTENT:AddNoteItem(text)
    text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then
        return
    end

    local items = self:GetNotesItems()
    table.insert(items, {
        text = text,
        done = false,
        createdAt = time(),
    })

    local notesDb = self:GetNotesDB()
    notesDb.updatedAt = time()

    self:SaveSettings()
    self:RefreshNotesUI()
end

function DISCONTENT:SetNoteItemChecked(index, isChecked)
    local items = self:GetNotesItems()
    local entry = items[index]
    if not entry then
        return
    end

    entry.done = isChecked and true or false
    entry.updatedAt = time()

    local notesDb = self:GetNotesDB()
    notesDb.updatedAt = time()

    self:SaveSettings()
    self:RefreshNotesUI()
end

function DISCONTENT:DeleteNoteItem(index)
    local items = self:GetNotesItems()
    if not items[index] then
        return
    end

    table.remove(items, index)

    local notesDb = self:GetNotesDB()
    notesDb.updatedAt = time()

    self:SaveSettings()
    self:RefreshNotesUI()
end

function DISCONTENT:ClearCompletedNotes()
    local items = self:GetNotesItems()
    local filtered = {}

    for i = 1, #items do
        if not items[i].done then
            filtered[#filtered + 1] = items[i]
        end
    end

    local notesDb = self:GetNotesDB()
    notesDb.items = filtered
    notesDb.updatedAt = time()

    self:SaveSettings()
    self:RefreshNotesUI()
end

function DISCONTENT:ClearAllNotes()
    local notesDb = self:GetNotesDB()
    notesDb.items = {}
    notesDb.updatedAt = time()

    self:SaveSettings()
    self:RefreshNotesUI()
end

function DISCONTENT:GetNotesProgress()
    local items = self:GetNotesItems()
    local total = #items
    local done = 0

    for i = 1, total do
        if items[i].done then
            done = done + 1
        end
    end

    return done, total
end

function DISCONTENT:CreateNoteRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(28)

    if index % 2 == 0 then
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(1, 1, 1, 0.03)
    end

    row.checkbox = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.checkbox:SetSize(24, 24)

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.text:SetJustifyH("LEFT")
    row.text:SetJustifyV("TOP")
    row.text:SetWordWrap(true)

    row.deleteButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.deleteButton:SetSize(26, 20)
    row.deleteButton:SetText("X")

    row.checkbox:SetScript("OnClick", function(btn)
        if row.index then
            DISCONTENT:SetNoteItemChecked(row.index, btn:GetChecked())
        end
    end)

    row.deleteButton:SetScript("OnClick", function()
        if row.index then
            DISCONTENT:DeleteNoteItem(row.index)
        end
    end)

    return row
end

function DISCONTENT:RefreshNotesUI()
    if not self.uiCreated or not self.notesTabContent then
        return
    end

    local items = self:GetNotesItems()
    local done, total = self:GetNotesProgress()

    if self.notesCharacterText then
        local name, realm = self:GetPlayerNameRealm()
        self.notesCharacterText:SetText("Aktiver Charakter: " .. tostring(name or "?") .. " - " .. tostring(realm or "?"))
    end

    if self.notesStatusText then
        if total == 0 then
            self.notesStatusText:SetText("Noch keine Einträge vorhanden.")
            self.notesStatusText:SetTextColor(0.8, 0.8, 0.8, 1)
        else
            self.notesStatusText:SetText(done .. " / " .. total .. " erledigt")
            if done == total then
                self.notesStatusText:SetTextColor(0.2, 0.85, 0.2, 1)
            elseif done > 0 then
                self.notesStatusText:SetTextColor(1, 0.82, 0, 1)
            else
                self.notesStatusText:SetTextColor(0.85, 0.3, 0.3, 1)
            end
        end
    end

    local width = math.max(300, (self.notesScrollFrame:GetWidth() or 700) - 28)
    local yOffset = 0

    for i = 1, #items do
        local row = self.noteRows[i]
        if not row then
            row = self:CreateNoteRow(self.notesScrollChild, i)
            self.noteRows[i] = row
        end

        local entry = items[i]
        row.index = i

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.notesScrollChild, "TOPLEFT", 0, -yOffset)
        row:SetWidth(width)

        row.checkbox:ClearAllPoints()
        row.checkbox:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -2)
        row.checkbox:SetChecked(entry.done and true or false)

        row.deleteButton:ClearAllPoints()
        row.deleteButton:SetPoint("TOPRIGHT", row, "TOPRIGHT", -2, -2)

        row.text:ClearAllPoints()
        row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 34, -5)
        row.text:SetWidth(width - 72)
        row.text:SetText(entry.text or "")

        if entry.done then
            row.text:SetTextColor(0.5, 0.85, 0.5, 1)
        else
            row.text:SetTextColor(1, 0.82, 0, 1)
        end

        local textHeight = math.max(18, math.ceil(row.text:GetStringHeight() or 18))
        local rowHeight = math.max(28, textHeight + 10)
        row:SetHeight(rowHeight)

        row:Show()
        yOffset = yOffset + rowHeight + 4
    end

    for i = #items + 1, #self.noteRows do
        self.noteRows[i]:Hide()
        self.noteRows[i].index = nil
    end

    self.notesScrollChild:SetSize(width, math.max(yOffset + 8, self.notesScrollFrame:GetHeight() or 100))
end

function DISCONTENT:CreateNotesUI()
    self.noteRows = {}

    self.notesTitle = self.notesTabContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.notesTitle:SetText("Notes")

    self.notesSubtitle = self.notesTabContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.notesSubtitle:SetJustifyH("LEFT")
    self.notesSubtitle:SetText("Deine persönliche lokale Todo-Liste und Notizen. Diese Einträge werden lokal und charakterbezogen gespeichert.")

    self.notesCharacterText = self.notesTabContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.notesCharacterText:SetJustifyH("LEFT")
    self.notesCharacterText:SetText("Aktiver Charakter: -")

    self.notesInputLabel = self.notesTabContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.notesInputLabel:SetText("Neue Notiz:")

    self.notesInputBox = CreateFrame("EditBox", nil, self.notesTabContent, "InputBoxTemplate")
    self.notesInputBox:SetAutoFocus(false)
    self.notesInputBox:SetSize(420, 24)
    self.notesInputBox:SetScript("OnEnterPressed", function(editBox)
        DISCONTENT:AddNoteItem(editBox:GetText())
        editBox:SetText("")
        editBox:ClearFocus()
    end)

    self.notesAddButton = CreateFrame("Button", nil, self.notesTabContent, "UIPanelButtonTemplate")
    self.notesAddButton:SetSize(120, 24)
    self.notesAddButton:SetText("Hinzufügen")
    self.notesAddButton:SetScript("OnClick", function()
        if DISCONTENT.notesInputBox then
            DISCONTENT:AddNoteItem(DISCONTENT.notesInputBox:GetText())
            DISCONTENT.notesInputBox:SetText("")
            DISCONTENT.notesInputBox:ClearFocus()
        end
    end)

    self.notesClearDoneButton = CreateFrame("Button", nil, self.notesTabContent, "UIPanelButtonTemplate")
    self.notesClearDoneButton:SetSize(150, 24)
    self.notesClearDoneButton:SetText("Erledigte löschen")
    self.notesClearDoneButton:SetScript("OnClick", function()
        DISCONTENT:ClearCompletedNotes()
    end)

    self.notesClearAllButton = CreateFrame("Button", nil, self.notesTabContent, "UIPanelButtonTemplate")
    self.notesClearAllButton:SetSize(120, 24)
    self.notesClearAllButton:SetText("Alle löschen")
    self.notesClearAllButton:SetScript("OnClick", function()
        DISCONTENT:ClearAllNotes()
    end)

    self.notesStatusText = self.notesTabContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.notesStatusText:SetJustifyH("LEFT")
    self.notesStatusText:SetText("Noch keine Einträge vorhanden.")

    self.notesScrollFrame = CreateFrame("ScrollFrame", "DISCONTENTNotesScrollFrame", self.notesTabContent, "UIPanelScrollFrameTemplate")
    self.notesScrollChild = CreateFrame("Frame", nil, self.notesScrollFrame)
    self.notesScrollFrame:SetScrollChild(self.notesScrollChild)
end

function DISCONTENT:UpdateNotesLayout()
    if not self.notesTabContent then
        return
    end

    self.notesTabContent:ClearAllPoints()
    self.notesTabContent:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -70)
    self.notesTabContent:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)

    self.notesTitle:ClearAllPoints()
    self.notesTitle:SetPoint("TOPLEFT", self.notesTabContent, "TOPLEFT", 16, -12)

    self.notesSubtitle:ClearAllPoints()
    self.notesSubtitle:SetPoint("TOPLEFT", self.notesTabContent, "TOPLEFT", 16, -40)
    self.notesSubtitle:SetPoint("TOPRIGHT", self.notesTabContent, "TOPRIGHT", -16, -40)

    self.notesCharacterText:ClearAllPoints()
    self.notesCharacterText:SetPoint("TOPLEFT", self.notesTabContent, "TOPLEFT", 16, -60)

    self.notesInputLabel:ClearAllPoints()
    self.notesInputLabel:SetPoint("TOPLEFT", self.notesTabContent, "TOPLEFT", 16, -84)

    self.notesInputBox:ClearAllPoints()
    self.notesInputBox:SetPoint("LEFT", self.notesInputLabel, "RIGHT", 8, 0)

    self.notesAddButton:ClearAllPoints()
    self.notesAddButton:SetPoint("LEFT", self.notesInputBox, "RIGHT", 10, 0)

    self.notesClearDoneButton:ClearAllPoints()
    self.notesClearDoneButton:SetPoint("LEFT", self.notesAddButton, "RIGHT", 10, 0)

    self.notesClearAllButton:ClearAllPoints()
    self.notesClearAllButton:SetPoint("LEFT", self.notesClearDoneButton, "RIGHT", 10, 0)

    self.notesStatusText:ClearAllPoints()
    self.notesStatusText:SetPoint("TOPLEFT", self.notesTabContent, "TOPLEFT", 16, -114)

    self.notesScrollFrame:ClearAllPoints()
    self.notesScrollFrame:SetPoint("TOPLEFT", self.notesTabContent, "TOPLEFT", 16, -138)
    self.notesScrollFrame:SetPoint("BOTTOMRIGHT", self.notesTabContent, "BOTTOMRIGHT", -30, 16)

    self:RefreshNotesUI()
end