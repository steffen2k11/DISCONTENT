local DISCONTENT = _G.DISCONTENT
if not DISCONTENT then return end

function DISCONTENT:ApplyReminderPopupDurationFromInput()
    if not self.reminderDurationInputBox then
        return
    end

    local ok, value = self:SetReminderPopupDuration(self.reminderDurationInputBox:GetText())
    if not ok then
        if UIErrorsFrame then
            UIErrorsFrame:AddMessage("Bitte eine gültige Sekundenanzahl für das Erinnerungspopup eingeben.", 1, 0.15, 0.15, 1)
        end
        self.reminderDurationInputBox:SetText(tostring(self:GetReminderPopupDuration()))
        return
    end

    self.reminderDurationInputBox:SetText(tostring(value))
end

function DISCONTENT:RefreshReminderSoundDropdown()
    if not self.reminderSoundDropdown then
        return
    end

    local options = self:GetReminderSoundOptions()

    UIDropDownMenu_Initialize(self.reminderSoundDropdown, function(_, level)
        if level ~= 1 then
            return
        end

        for i = 1, #options do
            local option = options[i]
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.label
            info.checked = (DISCONTENT:GetReminderSoundKey() == option.key)
            info.func = function()
                DISCONTENT:SetReminderSoundKey(option.key)
                DISCONTENT:RefreshReminderSoundDropdown()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    UIDropDownMenu_SetWidth(self.reminderSoundDropdown, 210)
    local selected = self:GetReminderSoundOptionByKey(self:GetReminderSoundKey())
    UIDropDownMenu_SetText(self.reminderSoundDropdown, (selected and selected.label) or "Sound wählen")
end

function DISCONTENT:RefreshReminderSoundSettingsState()
    local enabled = self:GetReminderSoundEnabled()

    if self.reminderSoundCheckbox then
        self.reminderSoundCheckbox:SetChecked(enabled)
    end

    if self.reminderSoundDropdown then
        UIDropDownMenu_DisableDropDown(self.reminderSoundDropdown)
        if enabled then
            UIDropDownMenu_EnableDropDown(self.reminderSoundDropdown)
        end
        self:RefreshReminderSoundDropdown()
    end

    if self.reminderSoundTestButton then
        self.reminderSoundTestButton:SetEnabled(true)
        self.reminderSoundTestButton:SetAlpha(enabled and 1 or 0.85)
    end
end

function DISCONTENT:CreateSettingsUI()
    self.settingsTitle = self.settingsTabContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.settingsTitle:SetText("Einstellungen")

    self.settingsSubtitle = self.settingsTabContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.settingsSubtitle:SetJustifyH("LEFT")
    self.settingsSubtitle:SetText("Hier kannst du Darstellung und Fensteroptik von DISCONTENT anpassen.")

    self.settingsPanel = CreateFrame("Frame", nil, self.settingsTabContent, "BackdropTemplate")
    self.settingsPanel:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    self.settingsPanel:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    self.settingsPanel:SetBackdropBorderColor(0.45, 0.45, 0.45, 1)

    self.scaleLabel = self.settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.scaleLabel:SetText("Fensterskalierung")

    self.backgroundLabel = self.settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.backgroundLabel:SetText("Hintergrund-Transparenz")

    self.reminderDurationLabel = self.settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.reminderDurationLabel:SetText("Erinnerungspopup-Dauer")

    self.reminderDurationInputBox = CreateFrame("EditBox", nil, self.settingsPanel, "InputBoxTemplate")
    self.reminderDurationInputBox:SetAutoFocus(false)
    self.reminderDurationInputBox:SetSize(70, 24)
    self.reminderDurationInputBox:SetNumeric(true)
    self.reminderDurationInputBox:SetMaxLetters(3)
    self.reminderDurationInputBox:SetText(tostring(self:GetReminderPopupDuration()))
    self.reminderDurationInputBox:SetScript("OnEnterPressed", function(editBox)
        DISCONTENT:ApplyReminderPopupDurationFromInput()
        editBox:ClearFocus()
    end)
    self.reminderDurationInputBox:SetScript("OnEscapePressed", function(editBox)
        editBox:SetText(tostring(DISCONTENT:GetReminderPopupDuration()))
        editBox:ClearFocus()
    end)

    self.reminderDurationSecondsText = self.settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.reminderDurationSecondsText:SetText("Sekunden")

    self.reminderDurationApplyButton = CreateFrame("Button", nil, self.settingsPanel, "UIPanelButtonTemplate")
    self.reminderDurationApplyButton:SetSize(80, 24)
    self.reminderDurationApplyButton:SetText("Übernehmen")
    self.reminderDurationApplyButton:SetScript("OnClick", function()
        DISCONTENT:ApplyReminderPopupDurationFromInput()
    end)

    self.reminderDurationHint = self.settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    self.reminderDurationHint:SetJustifyH("LEFT")
    self.reminderDurationHint:SetText("Legt fest, wie lange das kleine Notiz-Erinnerungspopup sichtbar bleibt. Bereich: 2 bis 60 Sekunden.")

    self.reminderSoundLabel = self.settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.reminderSoundLabel:SetText("Erinnerungssound")

    self.reminderSoundCheckbox = CreateFrame("CheckButton", nil, self.settingsPanel, "UICheckButtonTemplate")
    self.reminderSoundCheckbox.text = self.reminderSoundCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.reminderSoundCheckbox.text:SetPoint("LEFT", self.reminderSoundCheckbox, "RIGHT", 4, 1)
    self.reminderSoundCheckbox.text:SetJustifyH("LEFT")
    self.reminderSoundCheckbox.text:SetText("Sound bei Erinnerung abspielen")
    self.reminderSoundCheckbox:SetScript("OnClick", function(frame)
        DISCONTENT:SetReminderSoundEnabled(frame:GetChecked())
        DISCONTENT:RefreshReminderSoundSettingsState()
    end)

    self.reminderSoundDropdownLabel = self.settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.reminderSoundDropdownLabel:SetText("Sound auswählen")

    self.reminderSoundDropdown = CreateFrame("Frame", "DISCONTENTReminderSoundDropdown", self.settingsPanel, "UIDropDownMenuTemplate")

    self.reminderSoundTestButton = CreateFrame("Button", nil, self.settingsPanel, "UIPanelButtonTemplate")
    self.reminderSoundTestButton:SetSize(90, 24)
    self.reminderSoundTestButton:SetText("Test")
    self.reminderSoundTestButton:SetScript("OnClick", function()
        DISCONTENT:PlayReminderSound(true)
    end)

    self.reminderSoundHint = self.settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    self.reminderSoundHint:SetJustifyH("LEFT")
    self.reminderSoundHint:SetText("Verwendet nur WoW-Standardsounds aus dem Interface. Der Test spielt den aktuell gewählten Sound ab.")

    self.welcomePopupToggleCheckbox = CreateFrame("CheckButton", nil, self.settingsPanel, "UICheckButtonTemplate")
    self.welcomePopupToggleCheckbox.text = self.welcomePopupToggleCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.welcomePopupToggleCheckbox.text:SetPoint("LEFT", self.welcomePopupToggleCheckbox, "RIGHT", 4, 1)
    self.welcomePopupToggleCheckbox.text:SetJustifyH("LEFT")
    self.welcomePopupToggleCheckbox.text:SetText("Kleines Willkommenspopup beim Login anzeigen")
    self.welcomePopupToggleCheckbox.subText = self.settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.welcomePopupToggleCheckbox.subText:SetJustifyH("LEFT")
    self.welcomePopupToggleCheckbox.subText:SetText("Blendet das kleine News-/Willkommensfenster beim Einloggen automatisch ein oder aus. Manuell öffnen kannst du es weiter über den Minimap-Button.")
    self.welcomePopupToggleCheckbox:SetChecked(self:GetWelcomePopupEnabled())
    self.welcomePopupToggleCheckbox:SetScript("OnClick", function(frame)
        DISCONTENT:SetWelcomePopupEnabled(frame:GetChecked())
    end)

    self:CreateScaleSlider(self.settingsPanel)
    self:CreateBackgroundSlider(self.settingsPanel)
    self:RefreshReminderSoundDropdown()
    self:RefreshReminderSoundSettingsState()
end

function DISCONTENT:UpdateSettingsLayout()
    if not self.settingsTabContent or not self.settingsPanel then
        return
    end

    self.settingsTabContent:ClearAllPoints()
    self.settingsTabContent:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -70)
    self.settingsTabContent:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)

    self.settingsTitle:ClearAllPoints()
    self.settingsTitle:SetPoint("TOPLEFT", self.settingsTabContent, "TOPLEFT", 16, -12)

    self.settingsSubtitle:ClearAllPoints()
    self.settingsSubtitle:SetPoint("TOPLEFT", self.settingsTabContent, "TOPLEFT", 16, -40)
    self.settingsSubtitle:SetPoint("TOPRIGHT", self.settingsTabContent, "TOPRIGHT", -16, -40)

    self.settingsPanel:ClearAllPoints()
    self.settingsPanel:SetPoint("TOPLEFT", self.settingsTabContent, "TOPLEFT", 16, -72)
    self.settingsPanel:SetPoint("TOPRIGHT", self.settingsTabContent, "TOPRIGHT", -16, -72)
    self.settingsPanel:SetHeight(500)

    self.scaleLabel:ClearAllPoints()
    self.scaleLabel:SetPoint("TOPLEFT", self.settingsPanel, "TOPLEFT", 20, -24)

    self.scaleSlider:ClearAllPoints()
    self.scaleSlider:SetPoint("TOPLEFT", self.scaleLabel, "BOTTOMLEFT", 0, -20)

    self.backgroundLabel:ClearAllPoints()
    self.backgroundLabel:SetPoint("TOPLEFT", self.settingsPanel, "TOPLEFT", 20, -92)

    self.backgroundSlider:ClearAllPoints()
    self.backgroundSlider:SetPoint("TOPLEFT", self.backgroundLabel, "BOTTOMLEFT", 0, -20)

    self.reminderDurationLabel:ClearAllPoints()
    self.reminderDurationLabel:SetPoint("TOPLEFT", self.settingsPanel, "TOPLEFT", 20, -160)

    self.reminderDurationInputBox:ClearAllPoints()
    self.reminderDurationInputBox:SetPoint("TOPLEFT", self.reminderDurationLabel, "BOTTOMLEFT", 0, -16)

    self.reminderDurationSecondsText:ClearAllPoints()
    self.reminderDurationSecondsText:SetPoint("LEFT", self.reminderDurationInputBox, "RIGHT", 8, 0)

    self.reminderDurationApplyButton:ClearAllPoints()
    self.reminderDurationApplyButton:SetPoint("LEFT", self.reminderDurationSecondsText, "RIGHT", 12, 0)

    self.reminderDurationHint:ClearAllPoints()
    self.reminderDurationHint:SetPoint("TOPLEFT", self.reminderDurationInputBox, "BOTTOMLEFT", 0, -10)
    self.reminderDurationHint:SetPoint("TOPRIGHT", self.settingsPanel, "TOPRIGHT", -20, -210)

    self.reminderSoundLabel:ClearAllPoints()
    self.reminderSoundLabel:SetPoint("TOPLEFT", self.settingsPanel, "TOPLEFT", 20, -236)

    self.reminderSoundCheckbox:ClearAllPoints()
    self.reminderSoundCheckbox:SetPoint("TOPLEFT", self.reminderSoundLabel, "BOTTOMLEFT", -6, -10)

    if self.reminderSoundCheckbox.text then
        self.reminderSoundCheckbox.text:ClearAllPoints()
        self.reminderSoundCheckbox.text:SetPoint("LEFT", self.reminderSoundCheckbox, "RIGHT", 4, 1)
    end

    self.reminderSoundDropdownLabel:ClearAllPoints()
    self.reminderSoundDropdownLabel:SetPoint("TOPLEFT", self.reminderSoundCheckbox, "BOTTOMLEFT", 10, -8)

    self.reminderSoundDropdown:ClearAllPoints()
    self.reminderSoundDropdown:SetPoint("TOPLEFT", self.reminderSoundDropdownLabel, "BOTTOMLEFT", -18, -2)

    self.reminderSoundTestButton:ClearAllPoints()
    self.reminderSoundTestButton:SetPoint("LEFT", self.reminderSoundDropdown, "RIGHT", -10, 2)

    self.reminderSoundHint:ClearAllPoints()
    self.reminderSoundHint:SetPoint("TOPLEFT", self.reminderSoundDropdown, "BOTTOMLEFT", 20, -2)
    self.reminderSoundHint:SetPoint("TOPRIGHT", self.settingsPanel, "TOPRIGHT", -20, -332)

    if self.welcomePopupToggleCheckbox then
        self.welcomePopupToggleCheckbox:ClearAllPoints()
        self.welcomePopupToggleCheckbox:SetPoint("TOPLEFT", self.settingsPanel, "TOPLEFT", 14, -356)
        self.welcomePopupToggleCheckbox:SetChecked(self:GetWelcomePopupEnabled())

        if self.welcomePopupToggleCheckbox.text then
            self.welcomePopupToggleCheckbox.text:ClearAllPoints()
            self.welcomePopupToggleCheckbox.text:SetPoint("LEFT", self.welcomePopupToggleCheckbox, "RIGHT", 4, 1)
        end

        if self.welcomePopupToggleCheckbox.subText then
            self.welcomePopupToggleCheckbox.subText:ClearAllPoints()
            self.welcomePopupToggleCheckbox.subText:SetPoint("TOPLEFT", self.welcomePopupToggleCheckbox.text, "BOTTOMLEFT", 0, -4)
            self.welcomePopupToggleCheckbox.subText:SetWidth(430)
        end
    end

    if self.minimapToggleCheckbox then
        self.minimapToggleCheckbox:ClearAllPoints()
        self.minimapToggleCheckbox:SetPoint("TOPLEFT", self.settingsPanel, "TOPLEFT", 14, -416)

        if self.minimapToggleCheckbox.text then
            self.minimapToggleCheckbox.text:ClearAllPoints()
            self.minimapToggleCheckbox.text:SetPoint("LEFT", self.minimapToggleCheckbox, "RIGHT", 4, 1)
        end

        if self.minimapToggleCheckbox.subText then
            self.minimapToggleCheckbox.subText:ClearAllPoints()
            self.minimapToggleCheckbox.subText:SetPoint("TOPLEFT", self.minimapToggleCheckbox.text, "BOTTOMLEFT", 0, -4)
            self.minimapToggleCheckbox.subText:SetWidth(430)
        end
    end

    if self.reminderDurationInputBox then
        self.reminderDurationInputBox:SetText(tostring(self:GetReminderPopupDuration()))
    end

    self:RefreshReminderSoundDropdown()
    self:RefreshReminderSoundSettingsState()
end
