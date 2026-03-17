local DISCONTENT = _G.DISCONTENT
if not DISCONTENT then return end

local function TrimString(text)
    return tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function ShowUiError(message)
    if UIErrorsFrame and message and message ~= "" then
        UIErrorsFrame:AddMessage(message, 1.0, 0.15, 0.15, 1.0)
    end
end

local DEFAULT_REMINDER_SOUND_KEY = "readycheck"

local REMINDER_SOUND_CANDIDATES = {
    { key = "readycheck",  label = "Ready Check",             soundKitKey = "READY_CHECK",                    fallbackId = 8960 },
    { key = "levelup",     label = "Level Up",               soundKitKey = "LEVELUP",                        fallbackId = 888 },
    { key = "menuopen",    label = "Menü öffnen",           soundKitKey = "IG_MAINMENU_OPEN" },
    { key = "menuclose",   label = "Menü schließen",        soundKitKey = "IG_MAINMENU_CLOSE" },
    { key = "checkboxon",  label = "Checkbox an",           soundKitKey = "IG_MAINMENU_OPTION_CHECKBOX_ON" },
    { key = "checkboxoff", label = "Checkbox aus",          soundKitKey = "IG_MAINMENU_OPTION_CHECKBOX_OFF" },
    { key = "dialogok",    label = "Bestätigen",            soundKitKey = "GS_TITLE_OPTION_OK" },
    { key = "dialogclose", label = "Abbrechen / Schließen", soundKitKey = "GS_TITLE_OPTION_EXIT" },
}

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

function DISCONTENT:GetReminderPopupDuration()
    local db = self.db or _G.DISCONTENTDB or {}
    local value = tonumber(db.reminderPopupDuration) or 5
    value = math.floor(value + 0.5)

    if value < 2 then
        value = 2
    elseif value > 60 then
        value = 60
    end

    return value
end

function DISCONTENT:SetReminderPopupDuration(value)
    local numeric = tonumber(value)
    if not numeric then
        return false, nil
    end

    numeric = math.floor(numeric + 0.5)
    if numeric < 2 then
        numeric = 2
    elseif numeric > 60 then
        numeric = 60
    end

    if type(_G.DISCONTENTDB) ~= "table" then
        _G.DISCONTENTDB = {}
    end

    self.db = _G.DISCONTENTDB
    self.db.reminderPopupDuration = numeric
    self:SaveSettings()

    if self.reminderDurationInputBox then
        self.reminderDurationInputBox:SetText(tostring(numeric))
    end

    return true, numeric
end

function DISCONTENT:GetReminderSoundOptions()
    if self.reminderSoundOptions and #self.reminderSoundOptions > 0 then
        return self.reminderSoundOptions
    end

    local options = {}
    local soundKitTable = rawget(_G, "SOUNDKIT")

    for i = 1, #REMINDER_SOUND_CANDIDATES do
        local candidate = REMINDER_SOUND_CANDIDATES[i]
        local soundKitId = nil

        if type(soundKitTable) == "table" and candidate.soundKitKey and type(soundKitTable[candidate.soundKitKey]) == "number" then
            soundKitId = soundKitTable[candidate.soundKitKey]
        elseif type(candidate.fallbackId) == "number" then
            soundKitId = candidate.fallbackId
        end

        if type(soundKitId) == "number" then
            options[#options + 1] = {
                key = candidate.key,
                label = candidate.label,
                soundKitId = soundKitId,
            }
        end
    end

    if #options == 0 then
        options[1] = { key = "readycheck", label = "Ready Check", soundKitId = 8960 }
        options[2] = { key = "levelup", label = "Level Up", soundKitId = 888 }
    end

    self.reminderSoundOptions = options
    return options
end

function DISCONTENT:GetReminderSoundOptionByKey(key)
    local options = self:GetReminderSoundOptions()
    local wantedKey = tostring(key or "")

    for i = 1, #options do
        if options[i].key == wantedKey then
            return options[i]
        end
    end

    return options[1]
end

function DISCONTENT:GetReminderSoundKey()
    local db = self.db or _G.DISCONTENTDB or {}
    local storedKey = tostring(db.reminderPopupSoundKey or DEFAULT_REMINDER_SOUND_KEY)
    local option = self:GetReminderSoundOptionByKey(storedKey)
    return option and option.key or DEFAULT_REMINDER_SOUND_KEY
end

function DISCONTENT:SetReminderSoundKey(key)
    local option = self:GetReminderSoundOptionByKey(key)
    if not option then
        return false, nil
    end

    if type(_G.DISCONTENTDB) ~= "table" then
        _G.DISCONTENTDB = {}
    end

    self.db = _G.DISCONTENTDB
    self.db.reminderPopupSoundKey = option.key
    self:SaveSettings()

    return true, option.key
end

function DISCONTENT:GetReminderSoundEnabled()
    local db = self.db or _G.DISCONTENTDB or {}
    if type(db.reminderPopupSoundEnabled) ~= "boolean" then
        return true
    end
    return db.reminderPopupSoundEnabled
end

function DISCONTENT:SetReminderSoundEnabled(enabled)
    if type(_G.DISCONTENTDB) ~= "table" then
        _G.DISCONTENTDB = {}
    end

    self.db = _G.DISCONTENTDB
    self.db.reminderPopupSoundEnabled = enabled and true or false
    self:SaveSettings()

    return self.db.reminderPopupSoundEnabled
end

function DISCONTENT:PlayReminderSound(forcePlayback)
    if not forcePlayback and not self:GetReminderSoundEnabled() then
        return false
    end

    local option = self:GetReminderSoundOptionByKey(self:GetReminderSoundKey())
    if not option or type(option.soundKitId) ~= "number" or type(PlaySound) ~= "function" then
        return false
    end

    PlaySound(option.soundKitId, "Master")
    return true
end

function DISCONTENT:GetNoteReminderPopupPositionDB()
    self.db = self.db or _G.DISCONTENTDB or {}

    if type(self.db.notes) ~= "table" then
        self.db.notes = {}
    end

    if type(self.db.notes.reminderPopupPosition) ~= "table" then
        self.db.notes.reminderPopupPosition = {
            point = "TOP",
            relativePoint = "TOP",
            x = 0,
            y = -140,
        }
    end

    local pos = self.db.notes.reminderPopupPosition
    pos.point = tostring(pos.point or "TOP")
    pos.relativePoint = tostring(pos.relativePoint or pos.point or "TOP")
    pos.x = tonumber(pos.x) or 0
    pos.y = tonumber(pos.y) or -140

    return pos
end

function DISCONTENT:ApplyNoteReminderPopupPosition(frame)
    frame = frame or self.noteReminderPopup
    if not frame then
        return
    end

    local pos = self:GetNoteReminderPopupPositionDB()
    frame:ClearAllPoints()
    frame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
end

function DISCONTENT:SaveNoteReminderPopupPosition(frame)
    frame = frame or self.noteReminderPopup
    if not frame then
        return
    end

    local point, _, relativePoint, xOfs, yOfs = frame:GetPoint(1)
    local pos = self:GetNoteReminderPopupPositionDB()
    pos.point = point or "TOP"
    pos.relativePoint = relativePoint or pos.point or "TOP"
    pos.x = math.floor((tonumber(xOfs) or 0) + 0.5)
    pos.y = math.floor((tonumber(yOfs) or 0) + 0.5)

    self:SaveSettings()
end


function DISCONTENT:GetSharedReminderPopupQueue()
    if type(self.sharedReminderPopupQueue) ~= "table" then
        self.sharedReminderPopupQueue = {}
    end
    return self.sharedReminderPopupQueue
end

function DISCONTENT:HideSharedReminderPopup(showNext)
    local popup = self.noteReminderPopup
    if not popup then
        return
    end

    popup.currentConfig = nil
    popup.onLeftClick = nil
    popup.onRightClick = nil
    popup.hideToken = nil
    popup:Hide()

    if showNext ~= false then
        C_Timer.After(0, function()
            if DISCONTENT and DISCONTENT.ProcessSharedReminderPopupQueue then
                DISCONTENT:ProcessSharedReminderPopupQueue()
            end
        end)
    end
end

function DISCONTENT:ShowSharedReminderPopup(config)
    if type(config) ~= "table" then
        return false
    end

    self:CreateNoteReminderPopup()

    local popup = self.noteReminderPopup
    popup.currentConfig = config
    popup.title:SetText(config.title or "Erinnerung")
    popup.message:SetText(config.message or "")
    popup.hint:SetText(config.hint or "Klick öffnet die Details | Ziehen verschiebt | Rechtsklick schließt")

    local border = config.borderColor
    if type(border) == "table" then
        popup.defaultBorderColor = {
            tonumber(border[1]) or 0.95,
            tonumber(border[2]) or 0.78,
            tonumber(border[3]) or 0.2,
            tonumber(border[4]) or 1,
        }
    else
        popup.defaultBorderColor = { 0.95, 0.78, 0.2, 1 }
    end

    popup.hoverBorderColor = {
        math.min(1, (popup.defaultBorderColor[1] or 1) + 0.05),
        math.min(1, (popup.defaultBorderColor[2] or 1) + 0.12),
        math.min(1, (popup.defaultBorderColor[3] or 1) + 0.15),
        popup.defaultBorderColor[4] or 1,
    }

    popup:SetBackdropBorderColor(unpack(popup.defaultBorderColor))
    popup.onLeftClick = config.onClick
    popup.onRightClick = config.onRightClick

    self:ApplyNoteReminderPopupPosition(popup)
    popup:Show()
    popup:Raise()

    if config.playSound then
        self:PlayReminderSound(false)
    end

    local token = (self.noteReminderPopupToken or 0) + 1
    self.noteReminderPopupToken = token
    popup.hideToken = token

    local duration = self:GetReminderPopupDuration()
    C_Timer.After(duration, function()
        if DISCONTENT
            and DISCONTENT.noteReminderPopup
            and DISCONTENT.noteReminderPopup:IsShown()
            and DISCONTENT.noteReminderPopup.hideToken == token then
            DISCONTENT:HideSharedReminderPopup(true)
        end
    end)

    return true
end

function DISCONTENT:ProcessSharedReminderPopupQueue()
    local popup = self.noteReminderPopup
    if popup and popup:IsShown() then
        return false
    end

    local queue = self:GetSharedReminderPopupQueue()
    local nextConfig = table.remove(queue, 1)
    if not nextConfig then
        return false
    end

    return self:ShowSharedReminderPopup(nextConfig)
end

function DISCONTENT:QueueSharedReminderPopup(config)
    if type(config) ~= "table" then
        return false
    end

    local queue = self:GetSharedReminderPopupQueue()
    queue[#queue + 1] = config
    return self:ProcessSharedReminderPopupQueue()
end

function DISCONTENT:BuildNoteReminderData(dateText, timeText, minutesText)
    local safeDate = TrimString(dateText)
    local safeTime = TrimString(timeText)
    local safeMinutes = TrimString(minutesText)

    if safeDate == "" and safeTime == "" and safeMinutes == "" then
        return nil, nil
    end

    if safeDate == "" or safeTime == "" then
        return nil, "Für eine Erinnerung bitte Datum und Uhrzeit angeben."
    end

    local day, month, year = safeDate:match("^(%d%d)%.(%d%d)%.(%d%d%d%d)$")
    if not day then
        year, month, day = safeDate:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    end

    day = tonumber(day)
    month = tonumber(month)
    year = tonumber(year)

    if not day or not month or not year then
        return nil, "Datum bitte als TT.MM.JJJJ oder JJJJ-MM-TT eingeben."
    end

    local hour, minute = safeTime:match("^(%d%d?):(%d%d)$")
    hour = tonumber(hour)
    minute = tonumber(minute)

    if not hour or not minute or hour < 0 or hour > 23 or minute < 0 or minute > 59 then
        return nil, "Uhrzeit bitte als HH:MM eingeben."
    end

    local minutesBefore = 0
    if safeMinutes ~= "" then
        minutesBefore = tonumber(safeMinutes)
        if not minutesBefore then
            return nil, "Die Vorwarnzeit muss eine Zahl in Minuten sein."
        end
        minutesBefore = math.floor(minutesBefore)
        if minutesBefore < 0 then
            return nil, "Die Vorwarnzeit darf nicht negativ sein."
        end
    end

    local reminderAt = time({
        year = year,
        month = month,
        day = day,
        hour = hour,
        min = minute,
        sec = 0,
    })

    if not reminderAt then
        return nil, "Das Erinnerungsdatum konnte nicht verarbeitet werden."
    end

    local verify = date("*t", reminderAt)
    if not verify or verify.year ~= year or verify.month ~= month or verify.day ~= day or verify.hour ~= hour or verify.min ~= minute then
        return nil, "Bitte ein gültiges Datum und eine gültige Uhrzeit eingeben."
    end

    local triggerAt = reminderAt - (minutesBefore * 60)
    if triggerAt <= time() then
        return nil, "Der Erinnerungszeitpunkt liegt bereits in der Vergangenheit."
    end

    return {
        reminderAt = reminderAt,
        remindMinutesBefore = minutesBefore,
        remindAt = triggerAt,
    }, nil
end

function DISCONTENT:GetNoteReminderText(entry)
    if not entry or type(entry.reminderAt) ~= "number" then
        return nil
    end

    local minutesBefore = tonumber(entry.remindMinutesBefore) or 0
    local prefix = entry.reminderFiredAt and "Erinnert" or "Erinnerung"
    return string.format("%s: %s | %d Min. vorher", prefix, date("%d.%m.%Y %H:%M", entry.reminderAt), minutesBefore)
end

function DISCONTENT:GetNoteReminderInputValues(entry)
    if not entry or type(entry.reminderAt) ~= "number" then
        return "", "", ""
    end

    local dateText = date("%d.%m.%Y", entry.reminderAt)
    local timeText = date("%H:%M", entry.reminderAt)
    local minutesBefore = tonumber(entry.remindMinutesBefore) or 0
    local minutesText = ""

    if minutesBefore > 0 then
        minutesText = tostring(minutesBefore)
    end

    return dateText, timeText, minutesText
end

function DISCONTENT:ClearNotesReminderInputs()
    if self.notesReminderDateInput then
        self.notesReminderDateInput:SetText("")
        self.notesReminderDateInput:ClearFocus()
    end

    if self.notesReminderTimeInput then
        self.notesReminderTimeInput:SetText("")
        self.notesReminderTimeInput:ClearFocus()
    end

    if self.notesReminderLeadInput then
        self.notesReminderLeadInput:SetText("")
        self.notesReminderLeadInput:ClearFocus()
    end
end

function DISCONTENT:ResetNotesEditorInputs(clearText)
    if clearText and self.notesInputBox then
        self.notesInputBox:SetText("")
        self.notesInputBox:ClearFocus()
    end

    self:ClearNotesReminderInputs()
end

function DISCONTENT:UpdateNotesEditorState()
    local isEditing = type(self.editingNoteIndex) == "number"

    if self.notesInputLabel then
        self.notesInputLabel:SetText(isEditing and "Notiz bearbeiten:" or "Neue Notiz:")
    end

    if self.notesAddButton then
        self.notesAddButton:SetText(isEditing and "Speichern" or "Hinzufügen")
    end

    if self.notesEditCancelButton then
        if isEditing then
            self.notesEditCancelButton:Show()
        else
            self.notesEditCancelButton:Hide()
        end
    end

    if self.notesEditHintText then
        if isEditing then
            self.notesEditHintText:SetText("Bearbeitungsmodus aktiv: Text und Erinnerung können geändert oder geleert werden.")
            self.notesEditHintText:SetTextColor(1, 0.82, 0, 1)
            self.notesEditHintText:Show()
        else
            self.notesEditHintText:SetText("")
            self.notesEditHintText:Hide()
        end
    end
end

function DISCONTENT:AddNoteItem(text, reminderData)
    text = TrimString(text)
    if text == "" then
        return false
    end

    local entry = {
        text = text,
        done = false,
        createdAt = time(),
    }

    if type(reminderData) == "table" then
        entry.reminderAt = tonumber(reminderData.reminderAt)
        entry.remindMinutesBefore = tonumber(reminderData.remindMinutesBefore) or 0
        entry.remindAt = tonumber(reminderData.remindAt)
        entry.reminderFiredAt = nil
    end

    local items = self:GetNotesItems()
    table.insert(items, entry)

    local notesDb = self:GetNotesDB()
    notesDb.updatedAt = time()

    self:SaveSettings()
    self:RefreshNotesUI()
    return true
end

function DISCONTENT:UpdateNoteItem(index, text, reminderData)
    local items = self:GetNotesItems()
    local entry = items[index]
    if not entry then
        return false
    end

    text = TrimString(text)
    if text == "" then
        return false
    end

    entry.text = text
    entry.updatedAt = time()

    if type(reminderData) == "table" then
        entry.reminderAt = tonumber(reminderData.reminderAt)
        entry.remindMinutesBefore = tonumber(reminderData.remindMinutesBefore) or 0
        entry.remindAt = tonumber(reminderData.remindAt)
        entry.reminderFiredAt = nil
    else
        entry.reminderAt = nil
        entry.remindMinutesBefore = nil
        entry.remindAt = nil
        entry.reminderFiredAt = nil
    end

    local notesDb = self:GetNotesDB()
    notesDb.updatedAt = time()

    self:SaveSettings()
    self:RefreshNotesUI()
    return true
end

function DISCONTENT:BeginEditNoteItem(index)
    local items = self:GetNotesItems()
    local entry = items[index]
    if not entry then
        return
    end

    self.editingNoteIndex = index

    if self.notesInputBox then
        self.notesInputBox:SetText(entry.text or "")
        self.notesInputBox:SetFocus()
        self.notesInputBox:HighlightText()
    end

    local dateText, timeText, minutesText = self:GetNoteReminderInputValues(entry)

    if self.notesReminderDateInput then
        self.notesReminderDateInput:SetText(dateText)
    end

    if self.notesReminderTimeInput then
        self.notesReminderTimeInput:SetText(timeText)
    end

    if self.notesReminderLeadInput then
        self.notesReminderLeadInput:SetText(minutesText)
    end

    self:UpdateNotesEditorState()
end

function DISCONTENT:CancelNoteEditing(clearText)
    self.editingNoteIndex = nil
    self:ResetNotesEditorInputs(clearText ~= false)
    self:UpdateNotesEditorState()
end

function DISCONTENT:AddNoteFromInputs()
    if not self.notesInputBox then
        return
    end

    local text = TrimString(self.notesInputBox:GetText())
    if text == "" then
        ShowUiError("Bitte zuerst einen Notiztext eingeben.")
        return
    end

    local reminderData, err = self:BuildNoteReminderData(
        self.notesReminderDateInput and self.notesReminderDateInput:GetText() or "",
        self.notesReminderTimeInput and self.notesReminderTimeInput:GetText() or "",
        self.notesReminderLeadInput and self.notesReminderLeadInput:GetText() or ""
    )

    if err then
        ShowUiError(err)
        return
    end

    local success = false
    if type(self.editingNoteIndex) == "number" then
        success = self:UpdateNoteItem(self.editingNoteIndex, text, reminderData)
    else
        success = self:AddNoteItem(text, reminderData)
    end

    if not success then
        return
    end

    self:CancelNoteEditing(true)
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

    if type(self.editingNoteIndex) == "number" then
        if self.editingNoteIndex == index then
            self.editingNoteIndex = nil
            self:ResetNotesEditorInputs(true)
        elseif self.editingNoteIndex > index then
            self.editingNoteIndex = self.editingNoteIndex - 1
        end
    end

    local notesDb = self:GetNotesDB()
    notesDb.updatedAt = time()

    self:SaveSettings()
    self:RefreshNotesUI()
    self:UpdateNotesEditorState()
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

    self:CancelNoteEditing(true)
    self:SaveSettings()
    self:RefreshNotesUI()
end

function DISCONTENT:ClearAllNotes()
    local notesDb = self:GetNotesDB()
    notesDb.items = {}
    notesDb.updatedAt = time()

    self:CancelNoteEditing(true)
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

function DISCONTENT:GetNoteRowFromDragTarget(frame)
    while frame do
        if frame.noteDragRow then
            return frame.noteDragRow
        end

        if type(frame.GetParent) ~= "function" then
            break
        end

        frame = frame:GetParent()
    end

    return nil
end

function DISCONTENT:GetNoteRowUnderCursor()
    if type(GetCursorPosition) ~= "function" then
        return nil
    end

    local cursorX, cursorY = GetCursorPosition()
    cursorX = tonumber(cursorX) or 0
    cursorY = tonumber(cursorY) or 0

    local function FindRow(rows)
        if type(rows) ~= "table" then
            return nil
        end

        for i = 1, #rows do
            local row = rows[i]
            if row and row:IsShown() and row.GetLeft and row.GetRight and row.GetTop and row.GetBottom then
                local scale = (row.GetEffectiveScale and row:GetEffectiveScale()) or 1
                if scale == 0 then
                    scale = 1
                end

                local x = cursorX / scale
                local y = cursorY / scale
                local left = row:GetLeft()
                local right = row:GetRight()
                local top = row:GetTop()
                local bottom = row:GetBottom()

                if left and right and top and bottom and x >= left and x <= right and y <= top and y >= bottom then
                    return row
                end
            end
        end

        return nil
    end

    return FindRow(self.noteRows)
        or (self.notesPopoutFrame and self.notesPopoutFrame.rows and FindRow(self.notesPopoutFrame.rows))
        or nil
end

function DISCONTENT:SetNoteDragHoverRow(row)
    if self.noteDragHoverRow and self.noteDragHoverRow ~= row and self.noteDragHoverRow.dragHighlight then
        self.noteDragHoverRow.dragHighlight:Hide()
    end

    self.noteDragHoverRow = row

    if row and self.noteDragContext and row ~= self.noteDragContext.sourceRow and row.dragHighlight then
        row.dragHighlight:Show()
    end
end

function DISCONTENT:ClearNoteDragState()
    if self.noteDragHoverRow and self.noteDragHoverRow.dragHighlight then
        self.noteDragHoverRow.dragHighlight:Hide()
    end

    if self.noteDragSourceRow and self.noteDragSourceRow.dragSourceHighlight then
        self.noteDragSourceRow.dragSourceHighlight:Hide()
    end

    self.noteDragHoverRow = nil
    self.noteDragSourceRow = nil
    self.noteDragContext = nil
end

function DISCONTENT:StartNoteRowDrag(actualIndex, row)
    actualIndex = tonumber(actualIndex)
    if not actualIndex or actualIndex < 1 then
        return false
    end

    self:ClearNoteDragState()

    self.noteDragContext = {
        sourceIndex = actualIndex,
        sourceRow = row,
    }
    self.noteDragSourceRow = row

    if row and row.dragSourceHighlight then
        row.dragSourceHighlight:Show()
    end

    return true
end

function DISCONTENT:MoveNoteItem(sourceIndex, targetIndex, insertAfter)
    local items = self:GetNotesItems()

    sourceIndex = tonumber(sourceIndex)
    targetIndex = tonumber(targetIndex)

    if not sourceIndex or not targetIndex or not items[sourceIndex] or not items[targetIndex] then
        return false
    end

    local destinationIndex = insertAfter and (targetIndex + 1) or targetIndex
    if destinationIndex > sourceIndex then
        destinationIndex = destinationIndex - 1
    end

    destinationIndex = math.max(1, math.min(destinationIndex, #items))

    if destinationIndex == sourceIndex then
        return false
    end

    local entry = table.remove(items, sourceIndex)
    if not entry then
        return false
    end

    table.insert(items, destinationIndex, entry)

    if type(self.editingNoteIndex) == "number" then
        if self.editingNoteIndex == sourceIndex then
            self.editingNoteIndex = destinationIndex
        elseif destinationIndex < sourceIndex then
            if self.editingNoteIndex >= destinationIndex and self.editingNoteIndex < sourceIndex then
                self.editingNoteIndex = self.editingNoteIndex + 1
            end
        else
            if self.editingNoteIndex > sourceIndex and self.editingNoteIndex <= destinationIndex then
                self.editingNoteIndex = self.editingNoteIndex - 1
            end
        end
    end

    local notesDb = self:GetNotesDB()
    notesDb.updatedAt = time()

    self:SaveSettings()
    self:RefreshNotesUI()
    return true
end

function DISCONTENT:FinishNoteRowDrag(mouseFocus)
    local context = self.noteDragContext
    if not context then
        return false
    end

    local targetRow = self.noteDragHoverRow or self:GetNoteRowFromDragTarget(mouseFocus) or self:GetNoteRowUnderCursor()
    local moved = false

    if targetRow then
        local targetIndex = tonumber(targetRow.noteIndex or targetRow.index)
        if targetIndex then
            local insertAfter = false

            if type(GetCursorPosition) == "function" and targetRow.GetTop and targetRow.GetBottom then
                local _, cursorY = GetCursorPosition()
                local scale = (targetRow.GetEffectiveScale and targetRow:GetEffectiveScale()) or 1
                if scale == 0 then
                    scale = 1
                end
                cursorY = (tonumber(cursorY) or 0) / scale

                local topY = targetRow:GetTop()
                local bottomY = targetRow:GetBottom()
                if topY and bottomY then
                    insertAfter = cursorY < ((topY + bottomY) / 2)
                end
            end

            moved = self:MoveNoteItem(context.sourceIndex, targetIndex, insertAfter)
        end
    end

    self:ClearNoteDragState()
    return moved
end



function DISCONTENT:CreateNoteRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(28)
    row:EnableMouse(true)
    row.noteDragRow = row

    if index % 2 == 0 then
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(1, 1, 1, 0.03)
    end

    row.dragSourceHighlight = row:CreateTexture(nil, "ARTWORK")
    row.dragSourceHighlight:SetAllPoints()
    row.dragSourceHighlight:SetColorTexture(0.2, 0.8, 1, 0.08)
    row.dragSourceHighlight:Hide()

    row.dragHighlight = row:CreateTexture(nil, "ARTWORK")
    row.dragHighlight:SetAllPoints()
    row.dragHighlight:SetColorTexture(0.2, 0.8, 1, 0.16)
    row.dragHighlight:Hide()

    row.checkbox = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.checkbox:SetSize(24, 24)

    row.dragHandle = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.dragHandle:SetSize(42, 20)
    row.dragHandle:SetText("Drag")
    row.dragHandle.noteDragRow = row
    row.dragHandle:RegisterForDrag("LeftButton")
    row.dragHandle:SetScript("OnDragStart", function()
        if row.index then
            DISCONTENT:StartNoteRowDrag(row.index, row)
        end
    end)
    row.dragHandle:SetScript("OnDragStop", function()
        DISCONTENT:FinishNoteRowDrag()
    end)
    row.dragHandle:SetScript("OnEnter", function(button)
        if GameTooltip then
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetText("Ziehen zum Umordnen", 1, 0.82, 0, 1)
            GameTooltip:Show()
        end
    end)
    row.dragHandle:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.text:SetJustifyH("LEFT")
    row.text:SetJustifyV("TOP")
    row.text:SetWordWrap(true)

    row.meta = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.meta:SetJustifyH("LEFT")
    row.meta:SetJustifyV("TOP")
    row.meta:SetWordWrap(true)

    row.editButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.editButton:SetSize(54, 20)
    row.editButton:SetText("Bearb")

    row.deleteButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.deleteButton:SetSize(26, 20)
    row.deleteButton:SetText("X")

    row:SetScript("OnEnter", function(frame)
        if DISCONTENT.noteDragContext and DISCONTENT.noteDragContext.sourceRow ~= frame then
            DISCONTENT:SetNoteDragHoverRow(frame)
        end
    end)

    row:SetScript("OnLeave", function(frame)
        if DISCONTENT.noteDragHoverRow == frame then
            DISCONTENT:SetNoteDragHoverRow(nil)
        end
    end)

    row.checkbox:SetScript("OnClick", function(btn)
        if row.index then
            DISCONTENT:SetNoteItemChecked(row.index, btn:GetChecked())
        end
    end)

    row.editButton:SetScript("OnClick", function()
        if row.index then
            DISCONTENT:BeginEditNoteItem(row.index)
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

    self:UpdateNotesEditorState()

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
            self.notesStatusText:SetText(done .. " / " .. total .. " erledigt | Drag-Handle ziehen zum Umordnen")
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
    local textWidth = math.max(120, width - 186)
    local yOffset = 0

    for i = 1, #items do
        local row = self.noteRows[i]
        if not row then
            row = self:CreateNoteRow(self.notesScrollChild, i)
            self.noteRows[i] = row
        end

        local entry = items[i]
        row.index = i
        row.noteIndex = i

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.notesScrollChild, "TOPLEFT", 0, -yOffset)
        row:SetWidth(width)

        row.checkbox:ClearAllPoints()
        row.checkbox:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -2)
        row.checkbox:SetChecked(entry.done and true or false)

        row.dragHandle:ClearAllPoints()
        row.dragHandle:SetPoint("TOPLEFT", row, "TOPLEFT", 28, -3)

        row.deleteButton:ClearAllPoints()
        row.deleteButton:SetPoint("TOPRIGHT", row, "TOPRIGHT", -2, -2)

        row.editButton:ClearAllPoints()
        row.editButton:SetPoint("RIGHT", row.deleteButton, "LEFT", -6, 0)

        row.text:ClearAllPoints()
        row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 76, -5)
        row.text:SetWidth(textWidth)
        row.text:SetText(entry.text or "")

        local reminderText = self:GetNoteReminderText(entry)
        local textColorR, textColorG, textColorB = 1, 0.82, 0
        local metaColorR, metaColorG, metaColorB = 0.78, 0.78, 0.78

        if entry.done then
            textColorR, textColorG, textColorB = 0.5, 0.85, 0.5
            metaColorR, metaColorG, metaColorB = 0.55, 0.8, 0.55
        elseif reminderText and entry.reminderFiredAt then
            metaColorR, metaColorG, metaColorB = 1, 0.82, 0
        elseif reminderText then
            metaColorR, metaColorG, metaColorB = 0.85, 0.9, 1
        end

        row.text:SetTextColor(textColorR, textColorG, textColorB, 1)

        local textHeight = math.max(18, math.ceil(row.text:GetStringHeight() or 18))
        local rowHeight = math.max(28, textHeight + 10)

        if reminderText then
            row.meta:Show()
            row.meta:ClearAllPoints()
            row.meta:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -4)
            row.meta:SetWidth(textWidth)
            row.meta:SetText(reminderText)
            row.meta:SetTextColor(metaColorR, metaColorG, metaColorB, 1)

            local metaHeight = math.max(12, math.ceil(row.meta:GetStringHeight() or 12))
            rowHeight = math.max(rowHeight, textHeight + metaHeight + 18)
        else
            row.meta:SetText("")
            row.meta:Hide()
        end

        row:SetHeight(rowHeight)
        row:Show()
        yOffset = yOffset + rowHeight + 4
    end

    for i = #items + 1, #self.noteRows do
        self.noteRows[i]:Hide()
        self.noteRows[i].index = nil
        self.noteRows[i].noteIndex = nil
    end

    self.notesScrollChild:SetSize(width, math.max(yOffset + 8, self.notesScrollFrame:GetHeight() or 100))

    if self.RefreshNotesPopout then
        self:RefreshNotesPopout()
    end
end



function DISCONTENT:GetNotesPopoutPositionDB()
    self.db = self.db or _G.DISCONTENTDB or {}

    if type(self.db.notes) ~= "table" then
        self.db.notes = {}
    end

    if type(self.db.notes.popoutPosition) ~= "table" then
        self.db.notes.popoutPosition = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 360,
            y = 40,
        }
    end

    local pos = self.db.notes.popoutPosition
    pos.point = tostring(pos.point or "CENTER")
    pos.relativePoint = tostring(pos.relativePoint or pos.point or "CENTER")
    pos.x = tonumber(pos.x) or 360
    pos.y = tonumber(pos.y) or 40

    return pos
end

function DISCONTENT:ApplyNotesPopoutPosition(frame)
    frame = frame or self.notesPopoutFrame
    if not frame then
        return
    end

    local pos = self:GetNotesPopoutPositionDB()
    frame:ClearAllPoints()
    frame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
end

function DISCONTENT:SaveNotesPopoutPosition(frame)
    frame = frame or self.notesPopoutFrame
    if not frame then
        return
    end

    local point, _, relativePoint, xOfs, yOfs = frame:GetPoint(1)
    local pos = self:GetNotesPopoutPositionDB()
    pos.point = point or "CENTER"
    pos.relativePoint = relativePoint or pos.point or "CENTER"
    pos.x = math.floor((tonumber(xOfs) or 0) + 0.5)
    pos.y = math.floor((tonumber(yOfs) or 0) + 0.5)

    self:SaveSettings()
end

function DISCONTENT:GetNotesPopoutSizeDB()
    self.db = self.db or _G.DISCONTENTDB or {}

    if type(self.db.notes) ~= "table" then
        self.db.notes = {}
    end

    if type(self.db.notes.popoutSize) ~= "table" then
        self.db.notes.popoutSize = {
            width = 500,
            height = 520,
        }
    end

    local size = self.db.notes.popoutSize
    size.width = math.max(440, math.floor((tonumber(size.width) or 500) + 0.5))
    size.height = math.max(360, math.floor((tonumber(size.height) or 520) + 0.5))

    return size
end

function DISCONTENT:ApplyNotesPopoutSize(frame)
    frame = frame or self.notesPopoutFrame
    if not frame then
        return
    end

    local size = self:GetNotesPopoutSizeDB()
    frame:SetSize(size.width, size.height)
end

function DISCONTENT:SaveNotesPopoutSize(frame)
    frame = frame or self.notesPopoutFrame
    if not frame then
        return
    end

    local size = self:GetNotesPopoutSizeDB()
    size.width = math.max(440, math.floor((tonumber(frame:GetWidth()) or 500) + 0.5))
    size.height = math.max(360, math.floor((tonumber(frame:GetHeight()) or 520) + 0.5))

    self:SaveSettings()
end

function DISCONTENT:ClearNotesPopoutReminderInputs()
    local popup = self.notesPopoutFrame
    if not popup then
        return
    end

    if popup.reminderDateInput then
        popup.reminderDateInput:SetText("")
        popup.reminderDateInput:ClearFocus()
    end

    if popup.reminderTimeInput then
        popup.reminderTimeInput:SetText("")
        popup.reminderTimeInput:ClearFocus()
    end

    if popup.reminderLeadInput then
        popup.reminderLeadInput:SetText("")
        popup.reminderLeadInput:ClearFocus()
    end
end

function DISCONTENT:ResetNotesPopoutInputs(clearText)
    local popup = self.notesPopoutFrame
    if not popup then
        return
    end

    if clearText and popup.inputBox then
        popup.inputBox:SetText("")
        popup.inputBox:ClearFocus()
    end

    self:ClearNotesPopoutReminderInputs()
end

function DISCONTENT:AddNoteFromPopoutInputs()
    local popup = self.notesPopoutFrame
    if not popup or not popup.inputBox then
        return
    end

    local text = TrimString(popup.inputBox:GetText())
    if text == "" then
        ShowUiError("Bitte zuerst einen Notiztext eingeben.")
        return
    end

    local reminderData, err = self:BuildNoteReminderData(
        popup.reminderDateInput and popup.reminderDateInput:GetText() or "",
        popup.reminderTimeInput and popup.reminderTimeInput:GetText() or "",
        popup.reminderLeadInput and popup.reminderLeadInput:GetText() or ""
    )

    if err then
        ShowUiError(err)
        return
    end

    if not self:AddNoteItem(text, reminderData) then
        return
    end

    self:ResetNotesPopoutInputs(true)

    if popup.inputBox then
        popup.inputBox:SetFocus()
    end
end


function DISCONTENT:GetOpenNotesForPopout()
    local items = self:GetNotesItems()
    local visible = {}

    for i = 1, #items do
        local entry = items[i]
        if entry and not entry.done then
            visible[#visible + 1] = {
                index = i,
                entry = entry,
            }
        end
    end

    return visible
end

function DISCONTENT:RegisterNotesPopoutEditDialog()
    if self.notesPopoutEditDialogRegistered or type(StaticPopupDialogs) ~= "table" then
        return
    end

    StaticPopupDialogs["DISCONTENT_NOTES_POPOUT_EDIT"] = {
        text = "Notiz bearbeiten",
        button1 = "Speichern",
        button2 = "Abbrechen",
        hasEditBox = 1,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        preferredIndex = 3,
        OnShow = function(dialog, data)
            local editBox = dialog.editBox
            if not editBox then
                return
            end

            editBox:SetAutoFocus(true)
            editBox:SetMaxLetters(500)
            editBox:SetWidth(220)
            editBox:SetText((type(data) == "table" and data.text) or "")
            editBox:HighlightText()
            editBox:SetFocus()
            dialog.noteIndex = type(data) == "table" and data.noteIndex or nil
        end,
        OnAccept = function(dialog, data)
            local noteIndex = dialog.noteIndex or (type(data) == "table" and data.noteIndex)
            if type(noteIndex) ~= "number" then
                return
            end

            local editBox = dialog.editBox
            local newText = TrimString(editBox and editBox:GetText() or "")
            if newText == "" then
                ShowUiError("Bitte einen Notiztext eingeben.")
                return
            end

            local items = DISCONTENT:GetNotesItems()
            local entry = items[noteIndex]
            if not entry then
                return
            end

            local reminderData = nil
            if type(entry.reminderAt) == "number" or type(entry.remindAt) == "number" then
                reminderData = {
                    reminderAt = tonumber(entry.reminderAt),
                    remindMinutesBefore = tonumber(entry.remindMinutesBefore) or 0,
                    remindAt = tonumber(entry.remindAt),
                }
            end

            DISCONTENT:UpdateNoteItem(noteIndex, newText, reminderData)
        end,
        EditBoxOnEnterPressed = function(editBox)
            local dialog = editBox:GetParent()
            if dialog and dialog.button1 then
                dialog.button1:Click()
            end
        end,
        EditBoxOnEscapePressed = function(editBox)
            local dialog = editBox:GetParent()
            if dialog then
                dialog:Hide()
            end
        end,
    }

    self.notesPopoutEditDialogRegistered = true
end

function DISCONTENT:EditNoteFromPopout(index)
    local items = self:GetNotesItems()
    local entry = items[index]
    if not entry then
        return
    end

    self:RegisterNotesPopoutEditDialog()

    if type(StaticPopup_Show) == "function" then
        StaticPopup_Show("DISCONTENT_NOTES_POPOUT_EDIT", nil, nil, {
            noteIndex = index,
            text = entry.text or "",
        })
    else
        self:BeginEditNoteItem(index)
        self:ShowMainWindow()
        self:SetActiveTab("notes")
    end
end

function DISCONTENT:CompleteNoteFromPopout(index)
    local items = self:GetNotesItems()
    local entry = items[index]
    if not entry then
        return
    end

    self:SetNoteItemChecked(index, true)
end

function DISCONTENT:UpdateNotesPopoutButtonState()
    if not self.notesPopoutButton then
        return
    end

    if self.notesPopoutFrame and self.notesPopoutFrame:IsShown() then
        self.notesPopoutButton:SetText("Popout schließen")
    else
        self.notesPopoutButton:SetText("Popout öffnen")
    end
end

function DISCONTENT:CreateNotesPopoutRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(34)
    row:EnableMouse(true)
    row.noteDragRow = row

    if index % 2 == 0 then
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(1, 1, 1, 0.035)
    end

    row.dragSourceHighlight = row:CreateTexture(nil, "ARTWORK")
    row.dragSourceHighlight:SetAllPoints()
    row.dragSourceHighlight:SetColorTexture(0.2, 0.8, 1, 0.08)
    row.dragSourceHighlight:Hide()

    row.dragHighlight = row:CreateTexture(nil, "ARTWORK")
    row.dragHighlight:SetAllPoints()
    row.dragHighlight:SetColorTexture(0.2, 0.8, 1, 0.16)
    row.dragHighlight:Hide()

    row.dragHandle = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.dragHandle:SetSize(42, 20)
    row.dragHandle:SetText("Drag")
    row.dragHandle.noteDragRow = row
    row.dragHandle:RegisterForDrag("LeftButton")
    row.dragHandle:SetScript("OnDragStart", function()
        if row.noteIndex then
            DISCONTENT:StartNoteRowDrag(row.noteIndex, row)
        end
    end)
    row.dragHandle:SetScript("OnDragStop", function()
        DISCONTENT:FinishNoteRowDrag()
    end)
    row.dragHandle:SetScript("OnEnter", function(button)
        if GameTooltip then
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetText("Ziehen zum Umordnen", 1, 0.82, 0, 1)
            GameTooltip:Show()
        end
    end)
    row.dragHandle:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.text:SetJustifyH("LEFT")
    row.text:SetJustifyV("TOP")
    row.text:SetWordWrap(true)

    row.meta = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.meta:SetJustifyH("LEFT")
    row.meta:SetJustifyV("TOP")
    row.meta:SetWordWrap(true)

    row.editButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.editButton:SetSize(56, 20)
    row.editButton:SetText("Bearb")

    row.doneButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.doneButton:SetSize(96, 20)
    row.doneButton:SetText("Abschließen")

    row:SetScript("OnEnter", function(frame)
        if DISCONTENT.noteDragContext and DISCONTENT.noteDragContext.sourceRow ~= frame then
            DISCONTENT:SetNoteDragHoverRow(frame)
        end
    end)

    row:SetScript("OnLeave", function(frame)
        if DISCONTENT.noteDragHoverRow == frame then
            DISCONTENT:SetNoteDragHoverRow(nil)
        end
    end)

    row.editButton:SetScript("OnClick", function()
        if row.noteIndex then
            DISCONTENT:EditNoteFromPopout(row.noteIndex)
        end
    end)

    row.doneButton:SetScript("OnClick", function()
        if row.noteIndex then
            DISCONTENT:CompleteNoteFromPopout(row.noteIndex)
        end
    end)

    return row
end



function DISCONTENT:CreateNotesPopout()
    if self.notesPopoutFrame then
        return
    end

    local popup = CreateFrame("Frame", "DISCONTENTNotesPopout", UIParent, "BackdropTemplate")
    self.notesPopoutFrame = popup
    popup.rows = {}

    popup:SetFrameStrata("DIALOG")
    popup:SetFrameLevel(2500)
    popup:SetToplevel(true)
    popup:SetClampedToScreen(true)
    popup:EnableMouse(true)
    popup:SetMovable(true)
    popup:SetResizable(true)
    popup:RegisterForDrag("LeftButton")
    popup:Hide()

    self:ApplyNotesPopoutSize(popup)

    popup:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    popup:SetBackdropColor(0.03, 0.03, 0.04, 0.95)
    popup:SetBackdropBorderColor(0.2, 0.8, 1, 0.9)

    popup:SetScript("OnDragStart", function(frame)
        if frame.isSizing then
            return
        end
        frame:StartMoving()
    end)

    popup:SetScript("OnDragStop", function(frame)
        if frame.isSizing then
            return
        end
        frame:StopMovingOrSizing()
        DISCONTENT:SaveNotesPopoutPosition(frame)
    end)

    popup:SetScript("OnSizeChanged", function(frame, width, height)
        local clampedWidth = math.max(440, math.floor((tonumber(width) or tonumber(frame:GetWidth()) or 440) + 0.5))
        local clampedHeight = math.max(360, math.floor((tonumber(height) or tonumber(frame:GetHeight()) or 360) + 0.5))

        if math.abs((tonumber(width) or clampedWidth) - clampedWidth) > 0.5
            or math.abs((tonumber(height) or clampedHeight) - clampedHeight) > 0.5 then
            frame:SetSize(clampedWidth, clampedHeight)
            return
        end

        if DISCONTENT and DISCONTENT.RefreshNotesPopout then
            DISCONTENT:RefreshNotesPopout()
        end
    end)

    popup:SetScript("OnShow", function()
        DISCONTENT:UpdateNotesPopoutButtonState()
        DISCONTENT:RefreshNotesPopout()
    end)

    popup:SetScript("OnHide", function()
        DISCONTENT:UpdateNotesPopoutButtonState()
    end)

    self:ApplyNotesPopoutPosition(popup)

    popup.title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    popup.title:SetPoint("TOPLEFT", popup, "TOPLEFT", 12, -10)
    popup.title:SetJustifyH("LEFT")
    popup.title:SetTextColor(0.2, 0.8, 1, 1)
    popup.title:SetText("Notes Popout")

    popup.subtitle = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    popup.subtitle:SetPoint("TOPLEFT", popup.title, "BOTTOMLEFT", 0, -4)
    popup.subtitle:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -34, -28)
    popup.subtitle:SetJustifyH("LEFT")
    popup.subtitle:SetText("Offene Notizen im Blick behalten | Ziehen verschiebt | Griff unten rechts ändert die Größe")

    popup.closeButton = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
    popup.closeButton:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -2, -2)
    popup.closeButton:SetFrameLevel(popup:GetFrameLevel() + 10)

    popup.inputLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    popup.inputLabel:SetPoint("TOPLEFT", popup, "TOPLEFT", 12, -54)
    popup.inputLabel:SetJustifyH("LEFT")
    popup.inputLabel:SetText("Neue Notiz:")

    popup.inputBox = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
    popup.inputBox:SetAutoFocus(false)
    popup.inputBox:SetHeight(24)
    popup.inputBox:SetPoint("TOPLEFT", popup, "TOPLEFT", 12, -74)
    popup.inputBox:SetPoint("RIGHT", popup, "RIGHT", -114, 0)
    popup.inputBox:SetScript("OnEnterPressed", function()
        DISCONTENT:AddNoteFromPopoutInputs()
    end)
    popup.inputBox:SetScript("OnEscapePressed", function(editBox)
        editBox:ClearFocus()
    end)

    popup.addButton = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    popup.addButton:SetSize(92, 24)
    popup.addButton:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -12, -74)
    popup.addButton:SetText("Hinzufügen")
    popup.addButton:SetScript("OnClick", function()
        DISCONTENT:AddNoteFromPopoutInputs()
    end)

    popup.reminderLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    popup.reminderLabel:SetPoint("TOPLEFT", popup.inputBox, "BOTTOMLEFT", 0, -14)
    popup.reminderLabel:SetJustifyH("LEFT")
    popup.reminderLabel:SetText("Erinnerung (optional):")

    popup.reminderDateLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    popup.reminderDateLabel:SetPoint("TOPLEFT", popup.reminderLabel, "BOTTOMLEFT", 0, -8)
    popup.reminderDateLabel:SetText("Datum")

    popup.reminderDateInput = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
    popup.reminderDateInput:SetAutoFocus(false)
    popup.reminderDateInput:SetSize(80, 24)
    popup.reminderDateInput:SetMaxLetters(10)
    popup.reminderDateInput:SetPoint("LEFT", popup.reminderDateLabel, "RIGHT", 8, 0)
    popup.reminderDateInput:SetScript("OnEscapePressed", function(editBox)
        editBox:ClearFocus()
    end)

    popup.reminderTimeLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    popup.reminderTimeLabel:SetPoint("LEFT", popup.reminderDateInput, "RIGHT", 10, 0)
    popup.reminderTimeLabel:SetText("Uhrzeit")

    popup.reminderTimeInput = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
    popup.reminderTimeInput:SetAutoFocus(false)
    popup.reminderTimeInput:SetSize(50, 24)
    popup.reminderTimeInput:SetMaxLetters(5)
    popup.reminderTimeInput:SetPoint("LEFT", popup.reminderTimeLabel, "RIGHT", 8, 0)
    popup.reminderTimeInput:SetScript("OnEscapePressed", function(editBox)
        editBox:ClearFocus()
    end)

    popup.reminderLeadLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    popup.reminderLeadLabel:SetPoint("LEFT", popup.reminderTimeInput, "RIGHT", 10, 0)
    popup.reminderLeadLabel:SetText("Min. vorh.")

    popup.reminderLeadInput = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
    popup.reminderLeadInput:SetAutoFocus(false)
    popup.reminderLeadInput:SetSize(45, 24)
    popup.reminderLeadInput:SetMaxLetters(4)
    popup.reminderLeadInput:SetPoint("LEFT", popup.reminderLeadLabel, "RIGHT", 8, 0)
    popup.reminderLeadInput:SetScript("OnEnterPressed", function()
        DISCONTENT:AddNoteFromPopoutInputs()
    end)
    popup.reminderLeadInput:SetScript("OnEscapePressed", function(editBox)
        editBox:ClearFocus()
    end)

    popup.reminderHelpText = popup:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    popup.reminderHelpText:SetPoint("TOPLEFT", popup.reminderDateLabel, "BOTTOMLEFT", 0, -10)
    popup.reminderHelpText:SetPoint("RIGHT", popup, "RIGHT", -34, 0)
    popup.reminderHelpText:SetJustifyH("LEFT")
    popup.reminderHelpText:SetText("Datum als TT.MM.JJJJ oder JJJJ-MM-TT, Uhrzeit als HH:MM. Leer lassen = keine Erinnerung.")

    popup.statusText = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    popup.statusText:SetPoint("TOPLEFT", popup.reminderHelpText, "BOTTOMLEFT", 0, -14)
    popup.statusText:SetPoint("RIGHT", popup, "RIGHT", -34, 0)
    popup.statusText:SetJustifyH("LEFT")

    popup.scrollFrame = CreateFrame("ScrollFrame", "DISCONTENTNotesPopoutScrollFrame", popup, "UIPanelScrollFrameTemplate")
    popup.scrollChild = CreateFrame("Frame", nil, popup.scrollFrame)
    popup.scrollFrame:SetScrollChild(popup.scrollChild)
    popup.scrollFrame:SetPoint("TOPLEFT", popup.statusText, "BOTTOMLEFT", 0, -8)
    popup.scrollFrame:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -28, 24)

    popup.emptyText = popup.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    popup.emptyText:SetPoint("TOPLEFT", popup.scrollChild, "TOPLEFT", 6, -6)
    popup.emptyText:SetPoint("TOPRIGHT", popup.scrollChild, "TOPRIGHT", -6, -6)
    popup.emptyText:SetJustifyH("LEFT")
    popup.emptyText:SetWordWrap(true)
    popup.emptyText:SetText("Keine offenen Notizen vorhanden.")

    popup.resizeButton = CreateFrame("Button", nil, popup)
    popup.resizeButton:SetSize(18, 18)
    popup.resizeButton:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -4, 4)
    popup.resizeButton:SetNormalTexture([[Interface\ChatFrame\UI-ChatIM-SizeGrabber-Up]])
    popup.resizeButton:SetHighlightTexture([[Interface\ChatFrame\UI-ChatIM-SizeGrabber-Highlight]])
    popup.resizeButton:SetPushedTexture([[Interface\ChatFrame\UI-ChatIM-SizeGrabber-Down]])
    popup.resizeButton:SetFrameLevel(popup:GetFrameLevel() + 10)
    popup.resizeButton:SetScript("OnMouseDown", function()
        popup.isSizing = true
        popup:StartSizing("BOTTOMRIGHT")
    end)
    popup.resizeButton:SetScript("OnMouseUp", function()
        popup:StopMovingOrSizing()
        popup.isSizing = nil
        DISCONTENT:SaveNotesPopoutSize(popup)
        DISCONTENT:RefreshNotesPopout()
    end)
end

function DISCONTENT:ToggleNotesPopout()
    self:CreateNotesPopout()

    if self.notesPopoutFrame:IsShown() then
        self.notesPopoutFrame:Hide()
    else
        self:ApplyNotesPopoutPosition(self.notesPopoutFrame)
        self:ApplyNotesPopoutSize(self.notesPopoutFrame)
        self.notesPopoutFrame:Show()
        self:RefreshNotesPopout()
    end

    self:UpdateNotesPopoutButtonState()
end

function DISCONTENT:RefreshNotesPopout()
    local popup = self.notesPopoutFrame
    if not popup or not popup.scrollFrame or not popup.scrollChild then
        return
    end

    local visibleNotes = self:GetOpenNotesForPopout()
    local openCount = #visibleNotes
    local _, totalCount = self:GetNotesProgress()

    if popup.statusText then
        popup.statusText:SetText("Offene Notizen: " .. openCount .. " / " .. totalCount .. " | Drag-Handle ziehen zum Umordnen")
        if openCount > 0 then
            popup.statusText:SetTextColor(1, 0.82, 0, 1)
        else
            popup.statusText:SetTextColor(0.45, 0.9, 0.45, 1)
        end
    end

    local width = math.max(250, (popup.scrollFrame:GetWidth() or 360) - 24)
    local textWidth = math.max(90, width - 216)
    local yOffset = 0

    if openCount == 0 then
        popup.emptyText:Show()
        popup.emptyText:SetText("Keine offenen Notizen vorhanden.")
    else
        popup.emptyText:Hide()
    end

    for i = 1, openCount do
        local row = popup.rows[i]
        if not row then
            row = self:CreateNotesPopoutRow(popup.scrollChild, i)
            popup.rows[i] = row
        end

        local noteInfo = visibleNotes[i]
        local entry = noteInfo.entry
        local reminderText = self:GetNoteReminderText(entry)

        row.noteIndex = noteInfo.index
        row.index = noteInfo.index
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", popup.scrollChild, "TOPLEFT", 0, -yOffset)
        row:SetWidth(width)

        row.doneButton:ClearAllPoints()
        row.doneButton:SetPoint("TOPRIGHT", row, "TOPRIGHT", -2, -2)

        row.editButton:ClearAllPoints()
        row.editButton:SetPoint("RIGHT", row.doneButton, "LEFT", -6, 0)

        row.dragHandle:ClearAllPoints()
        row.dragHandle:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -3)

        row.text:ClearAllPoints()
        row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 52, -5)
        row.text:SetWidth(textWidth)
        row.text:SetText(entry.text or "")
        row.text:SetTextColor(1, 0.82, 0, 1)

        local textHeight = math.max(18, math.ceil(row.text:GetStringHeight() or 18))
        local rowHeight = math.max(34, textHeight + 10)

        if reminderText then
            row.meta:Show()
            row.meta:ClearAllPoints()
            row.meta:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -4)
            row.meta:SetWidth(textWidth)
            row.meta:SetText(reminderText)
            if entry.reminderFiredAt then
                row.meta:SetTextColor(1, 0.82, 0, 1)
            else
                row.meta:SetTextColor(0.85, 0.9, 1, 1)
            end

            local metaHeight = math.max(12, math.ceil(row.meta:GetStringHeight() or 12))
            rowHeight = math.max(rowHeight, textHeight + metaHeight + 18)
        else
            row.meta:SetText("")
            row.meta:Hide()
        end

        row:SetHeight(rowHeight)
        row:Show()
        yOffset = yOffset + rowHeight + 4
    end

    for i = openCount + 1, #popup.rows do
        popup.rows[i]:Hide()
        popup.rows[i].noteIndex = nil
        popup.rows[i].index = nil
    end

    popup.scrollChild:SetSize(width, math.max(yOffset + 8, popup.scrollFrame:GetHeight() or 120))
end



function DISCONTENT:CreateNoteReminderPopup()
    if self.noteReminderPopup then
        return
    end

    local popup = CreateFrame("Button", "DISCONTENTNoteReminderPopup", UIParent, "BackdropTemplate")
    self.noteReminderPopup = popup

    popup:SetSize(450, 110)
    popup:SetFrameStrata("TOOLTIP")
    popup:SetFrameLevel(3000)
    popup:SetToplevel(true)
    popup:SetClampedToScreen(true)
    popup:EnableMouse(true)
    popup:SetMovable(true)
    popup:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    popup:RegisterForDrag("LeftButton")
    self:ApplyNoteReminderPopupPosition(popup)
    popup:Hide()

    popup.defaultBorderColor = { 0.95, 0.78, 0.2, 1 }
    popup.hoverBorderColor = { 1, 0.9, 0.35, 1 }

    popup:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    popup:SetBackdropColor(0.03, 0.03, 0.04, 0.96)
    popup:SetBackdropBorderColor(unpack(popup.defaultBorderColor))

    popup.title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    popup.title:SetPoint("TOPLEFT", popup, "TOPLEFT", 12, -10)
    popup.title:SetJustifyH("LEFT")
    popup.title:SetTextColor(1, 0.85, 0.15, 1)
    popup.title:SetText("Notiz-Erinnerung")

    popup.message = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    popup.message:SetPoint("TOPLEFT", popup.title, "BOTTOMLEFT", 0, -6)
    popup.message:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -12, -30)
    popup.message:SetJustifyH("LEFT")
    popup.message:SetJustifyV("TOP")
    popup.message:SetWordWrap(true)

    popup.hint = popup:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    popup.hint:SetPoint("BOTTOMLEFT", popup, "BOTTOMLEFT", 12, 10)
    popup.hint:SetJustifyH("LEFT")
    popup.hint:SetText("Klick öffnet Notes | Ziehen verschiebt | Rechtsklick schließt")

    popup:SetScript("OnDragStart", function(frame)
        frame:StartMoving()
    end)

    popup:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        DISCONTENT:SaveNoteReminderPopupPosition(frame)
    end)

    popup:SetScript("OnEnter", function(frame)
        frame:SetBackdropBorderColor(unpack(frame.hoverBorderColor or { 1, 0.9, 0.35, 1 }))
    end)

    popup:SetScript("OnLeave", function(frame)
        frame:SetBackdropBorderColor(unpack(frame.defaultBorderColor or { 0.95, 0.78, 0.2, 1 }))
    end)

    popup:SetScript("OnClick", function(frame, button)
        if button == "LeftButton" then
            if type(frame.onLeftClick) == "function" then
                frame.onLeftClick(frame)
            else
                DISCONTENT:OpenNotesFromReminderPopup()
            end
        else
            if type(frame.onRightClick) == "function" then
                frame.onRightClick(frame)
            else
                DISCONTENT:HideSharedReminderPopup(true)
            end
        end
    end)

    popup:SetScript("OnHide", function(frame)
        frame.currentConfig = nil
        frame.onLeftClick = nil
        frame.onRightClick = nil
        frame.hideToken = nil
        frame.noteIndex = nil
        frame.noteCreatedAt = nil
        if DISCONTENT and DISCONTENT.ProcessSharedReminderPopupQueue then
            C_Timer.After(0, function()
                if DISCONTENT and DISCONTENT.ProcessSharedReminderPopupQueue then
                    DISCONTENT:ProcessSharedReminderPopupQueue()
                end
            end)
        end
    end)
end

function DISCONTENT:OpenNotesFromReminderPopup()
    self:HideSharedReminderPopup(true)
    self:ShowMainWindow()
    self:SetActiveTab("notes")
end

function DISCONTENT:ShowNoteReminderPopup(entry, index)
    if not entry then
        return
    end

    self:QueueSharedReminderPopup({
        title = "Notiz-Erinnerung",
        message = entry.text or "",
        hint = "Klick öffnet Notes | Ziehen verschiebt | Rechtsklick schließt",
        playSound = true,
        borderColor = { 0.95, 0.78, 0.2, 1 },
        onClick = function()
            if DISCONTENT and DISCONTENT.noteReminderPopup then
                DISCONTENT.noteReminderPopup.noteIndex = index
                DISCONTENT.noteReminderPopup.noteCreatedAt = entry.createdAt
            end
            DISCONTENT:OpenNotesFromReminderPopup()
        end,
    })
end

function DISCONTENT:CheckNoteReminders()
    if self.noteReminderPopup and self.noteReminderPopup:IsShown() then
        return
    end

    local items = self:GetNotesItems()
    local now = time()

    for i = 1, #items do
        local entry = items[i]
        if not entry.done and type(entry.remindAt) == "number" and not entry.reminderFiredAt and entry.remindAt <= now then
            entry.reminderFiredAt = now

            local notesDb = self:GetNotesDB()
            notesDb.updatedAt = now
            self:SaveSettings()
            self:RefreshNotesUI()
            self:ShowNoteReminderPopup(entry, i)
            return
        end
    end
end

function DISCONTENT:StartNoteReminderTicker()
    if self.noteReminderTicker or not C_Timer or type(C_Timer.NewTicker) ~= "function" then
        return
    end

    self.noteReminderTicker = C_Timer.NewTicker(1, function()
        if DISCONTENT and DISCONTENT.CheckNoteReminders then
            DISCONTENT:CheckNoteReminders()
        end
    end)
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
    self.notesInputBox:SetSize(360, 24)
    self.notesInputBox:SetScript("OnEnterPressed", function()
        DISCONTENT:AddNoteFromInputs()
    end)
    self.notesInputBox:SetScript("OnEscapePressed", function(editBox)
        editBox:ClearFocus()
    end)

    self.notesAddButton = CreateFrame("Button", nil, self.notesTabContent, "UIPanelButtonTemplate")
    self.notesAddButton:SetSize(110, 24)
    self.notesAddButton:SetText("Hinzufügen")
    self.notesAddButton:SetScript("OnClick", function()
        DISCONTENT:AddNoteFromInputs()
    end)

    self.notesEditCancelButton = CreateFrame("Button", nil, self.notesTabContent, "UIPanelButtonTemplate")
    self.notesEditCancelButton:SetSize(100, 24)
    self.notesEditCancelButton:SetText("Abbrechen")
    self.notesEditCancelButton:SetScript("OnClick", function()
        DISCONTENT:CancelNoteEditing(true)
    end)
    self.notesEditCancelButton:Hide()

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

    self.notesPopoutButton = CreateFrame("Button", nil, self.notesTabContent, "UIPanelButtonTemplate")
    self.notesPopoutButton:SetSize(120, 24)
    self.notesPopoutButton:SetText("Popout öffnen")
    self.notesPopoutButton:SetScript("OnClick", function()
        DISCONTENT:ToggleNotesPopout()
    end)

    self.notesReminderLabel = self.notesTabContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.notesReminderLabel:SetText("Erinnerung (optional):")

    self.notesReminderDateLabel = self.notesTabContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.notesReminderDateLabel:SetText("Datum")

    self.notesReminderDateInput = CreateFrame("EditBox", nil, self.notesTabContent, "InputBoxTemplate")
    self.notesReminderDateInput:SetAutoFocus(false)
    self.notesReminderDateInput:SetSize(95, 24)
    self.notesReminderDateInput:SetMaxLetters(10)
    self.notesReminderDateInput:SetScript("OnEscapePressed", function(editBox)
        editBox:ClearFocus()
    end)

    self.notesReminderTimeLabel = self.notesTabContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.notesReminderTimeLabel:SetText("Uhrzeit")

    self.notesReminderTimeInput = CreateFrame("EditBox", nil, self.notesTabContent, "InputBoxTemplate")
    self.notesReminderTimeInput:SetAutoFocus(false)
    self.notesReminderTimeInput:SetSize(60, 24)
    self.notesReminderTimeInput:SetMaxLetters(5)
    self.notesReminderTimeInput:SetScript("OnEscapePressed", function(editBox)
        editBox:ClearFocus()
    end)

    self.notesReminderLeadLabel = self.notesTabContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.notesReminderLeadLabel:SetText("Min. vorher")

    self.notesReminderLeadInput = CreateFrame("EditBox", nil, self.notesTabContent, "InputBoxTemplate")
    self.notesReminderLeadInput:SetAutoFocus(false)
    self.notesReminderLeadInput:SetSize(55, 24)
    self.notesReminderLeadInput:SetMaxLetters(4)
    self.notesReminderLeadInput:SetNumeric(false)
    self.notesReminderLeadInput:SetScript("OnEnterPressed", function()
        DISCONTENT:AddNoteFromInputs()
    end)
    self.notesReminderLeadInput:SetScript("OnEscapePressed", function(editBox)
        editBox:ClearFocus()
    end)

    self.notesReminderHelpText = self.notesTabContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    self.notesReminderHelpText:SetJustifyH("LEFT")
    self.notesReminderHelpText:SetText("Datum als TT.MM.JJJJ oder JJJJ-MM-TT, Uhrzeit als HH:MM. Leer lassen = keine Erinnerung.")

    self.notesEditHintText = self.notesTabContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.notesEditHintText:SetJustifyH("LEFT")
    self.notesEditHintText:SetText("")
    self.notesEditHintText:Hide()

    self.notesStatusText = self.notesTabContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.notesStatusText:SetJustifyH("LEFT")
    self.notesStatusText:SetText("Noch keine Einträge vorhanden.")

    self.notesScrollFrame = CreateFrame("ScrollFrame", "DISCONTENTNotesScrollFrame", self.notesTabContent, "UIPanelScrollFrameTemplate")
    self.notesScrollChild = CreateFrame("Frame", nil, self.notesScrollFrame)
    self.notesScrollFrame:SetScrollChild(self.notesScrollChild)

    self:CreateNotesPopout()
    self:CreateNoteReminderPopup()
    self:StartNoteReminderTicker()
    self:UpdateNotesEditorState()
    self:UpdateNotesPopoutButtonState()
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

    self.notesEditCancelButton:ClearAllPoints()
    self.notesEditCancelButton:SetPoint("LEFT", self.notesAddButton, "RIGHT", 8, 0)

    self.notesClearDoneButton:ClearAllPoints()
    self.notesClearDoneButton:SetPoint("LEFT", self.notesEditCancelButton, "RIGHT", 8, 0)

    self.notesClearAllButton:ClearAllPoints()
    self.notesClearAllButton:SetPoint("LEFT", self.notesClearDoneButton, "RIGHT", 8, 0)

    self.notesPopoutButton:ClearAllPoints()
    self.notesPopoutButton:SetPoint("LEFT", self.notesClearAllButton, "RIGHT", 8, 0)

    self.notesReminderLabel:ClearAllPoints()
    self.notesReminderLabel:SetPoint("TOPLEFT", self.notesTabContent, "TOPLEFT", 16, -116)

    self.notesReminderDateLabel:ClearAllPoints()
    self.notesReminderDateLabel:SetPoint("TOPLEFT", self.notesTabContent, "TOPLEFT", 16, -138)

    self.notesReminderDateInput:ClearAllPoints()
    self.notesReminderDateInput:SetPoint("LEFT", self.notesReminderDateLabel, "RIGHT", 8, 0)

    self.notesReminderTimeLabel:ClearAllPoints()
    self.notesReminderTimeLabel:SetPoint("LEFT", self.notesReminderDateInput, "RIGHT", 14, 0)

    self.notesReminderTimeInput:ClearAllPoints()
    self.notesReminderTimeInput:SetPoint("LEFT", self.notesReminderTimeLabel, "RIGHT", 8, 0)

    self.notesReminderLeadLabel:ClearAllPoints()
    self.notesReminderLeadLabel:SetPoint("LEFT", self.notesReminderTimeInput, "RIGHT", 14, 0)

    self.notesReminderLeadInput:ClearAllPoints()
    self.notesReminderLeadInput:SetPoint("LEFT", self.notesReminderLeadLabel, "RIGHT", 8, 0)

    self.notesReminderHelpText:ClearAllPoints()
    self.notesReminderHelpText:SetPoint("LEFT", self.notesReminderLeadInput, "RIGHT", 12, 0)
    self.notesReminderHelpText:SetPoint("RIGHT", self.notesTabContent, "RIGHT", -16, 0)

    self.notesEditHintText:ClearAllPoints()
    self.notesEditHintText:SetPoint("TOPLEFT", self.notesTabContent, "TOPLEFT", 16, -166)
    self.notesEditHintText:SetPoint("RIGHT", self.notesTabContent, "RIGHT", -16, 0)

    self.notesStatusText:ClearAllPoints()
    self.notesStatusText:SetPoint("TOPLEFT", self.notesTabContent, "TOPLEFT", 16, -186)

    self.notesScrollFrame:ClearAllPoints()
    self.notesScrollFrame:SetPoint("TOPLEFT", self.notesTabContent, "TOPLEFT", 16, -210)
    self.notesScrollFrame:SetPoint("BOTTOMRIGHT", self.notesTabContent, "BOTTOMRIGHT", -30, 16)

    self:RefreshNotesUI()
end
