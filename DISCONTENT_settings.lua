local DISCONTENT = _G.DISCONTENT
if not DISCONTENT then return end

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

    self:CreateScaleSlider(self.settingsPanel)
    self:CreateBackgroundSlider(self.settingsPanel)
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
    self.settingsPanel:SetHeight(170)

    self.scaleLabel:ClearAllPoints()
    self.scaleLabel:SetPoint("TOPLEFT", self.settingsPanel, "TOPLEFT", 20, -24)

    self.scaleSlider:ClearAllPoints()
    self.scaleSlider:SetPoint("TOPLEFT", self.scaleLabel, "BOTTOMLEFT", 0, -20)

    self.backgroundLabel:ClearAllPoints()
    self.backgroundLabel:SetPoint("TOPLEFT", self.settingsPanel, "TOPLEFT", 20, -92)

    self.backgroundSlider:ClearAllPoints()
    self.backgroundSlider:SetPoint("TOPLEFT", self.backgroundLabel, "BOTTOMLEFT", 0, -20)
end