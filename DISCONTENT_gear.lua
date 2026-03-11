local DISCONTENT = _G.DISCONTENT
if not DISCONTENT then return end

DISCONTENT.gearPrefix = "DISGEAR"
DISCONTENT.gearData = DISCONTENT.gearData or {}
DISCONTENT.activeGearRequests = DISCONTENT.activeGearRequests or {}

DISCONTENT.gearSlots = {
    { id = 1,  key = "HEAD",      label = "Kopf" },
    { id = 2,  key = "NECK",      label = "Hals" },
    { id = 3,  key = "SHOULDER",  label = "Schulter" },
    { id = 5,  key = "CHEST",     label = "Brust" },
    { id = 15, key = "BACK",      label = "Umhang" },
    { id = 9,  key = "WRIST",     label = "Armschienen" },
    { id = 10, key = "HANDS",     label = "Hände" },
    { id = 6,  key = "WAIST",     label = "Gürtel" },
    { id = 7,  key = "LEGS",      label = "Beine" },
    { id = 8,  key = "FEET",      label = "Füße" },
    { id = 11, key = "RING1",     label = "Ring 1" },
    { id = 12, key = "RING2",     label = "Ring 2" },
    { id = 13, key = "TRINKET1",  label = "Trinket 1" },
    { id = 14, key = "TRINKET2",  label = "Trinket 2" },
    { id = 16, key = "MAINHAND",  label = "Mainhand" },
    { id = 17, key = "OFFHAND",   label = "Offhand" },
}

-------------------------------------------------
-- Helpers
-------------------------------------------------

function DISCONTENT:EnsureGearData()
    if type(self.gearData) ~= "table" then
        self.gearData = {}
    end

    if self.db then
        if type(self.db.gearData) ~= "table" then
            self.db.gearData = self.gearData
        else
            self.gearData = self.db.gearData
        end
    end

    return self.gearData
end

function DISCONTENT:SplitText(text, sep)
    local out = {}
    if not text or text == "" then
        return out
    end

    sep = sep or ","

    for token in string.gmatch(text, "([^" .. sep .. "]+)") do
        out[#out + 1] = token
    end

    return out
end

function DISCONTENT:SerializeGemList(gems)
    if type(gems) ~= "table" or #gems == 0 then
        return ""
    end

    local out = {}
    for i = 1, #gems do
        out[#out + 1] = tostring(gems[i])
    end
    return table.concat(out, ",")
end

function DISCONTENT:DeserializeGemList(text)
    local gems = {}
    if not text or text == "" then
        return gems
    end

    local parts = self:SplitText(text, ",")
    for i = 1, #parts do
        local id = tonumber(parts[i])
        if id and id > 0 then
            gems[#gems + 1] = id
        end
    end

    return gems
end

function DISCONTENT:ParseItemLinkData(itemLink)
    local enchantId = 0
    local gems = {}

    if not itemLink or itemLink == "" then
        return enchantId, gems
    end

    local itemString = string.match(itemLink, "item:([-%d:]+)")
    if not itemString then
        return enchantId, gems
    end

    local parts = { strsplit(":", itemString) }

    enchantId = tonumber(parts[2]) or 0

    for i = 3, 6 do
        local gemId = tonumber(parts[i])
        if gemId and gemId > 0 then
            gems[#gems + 1] = gemId
        end
    end

    return enchantId, gems
end

function DISCONTENT:GetGearSlotLabel(slotKey)
    for i = 1, #self.gearSlots do
        local slot = self.gearSlots[i]
        if slot.key == slotKey then
            return slot.label
        end
    end
    return slotKey or "?"
end

function DISCONTENT:GetItemQualityColor(itemLink)
    if not itemLink or itemLink == "" then
        return 1, 1, 1
    end

    local _, _, quality = GetItemInfo(itemLink)
    if quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] then
        local c = ITEM_QUALITY_COLORS[quality]
        return c.r, c.g, c.b
    end

    return 1, 1, 1
end

function DISCONTENT:GetItemNameSafe(itemLink, fallbackName)
    if itemLink and itemLink ~= "" then
        local itemName = GetItemInfo(itemLink)
        if itemName and itemName ~= "" then
            return itemName
        end
    end

    return fallbackName or "Unbekannt"
end

function DISCONTENT:GetItemIconSafe(itemLink, itemID)
    if itemLink and itemLink ~= "" then
        local icon = select(10, GetItemInfo(itemLink))
        if icon then
            return icon
        end
    end

    itemID = tonumber(itemID) or 0
    if itemID > 0 and C_Item and C_Item.GetItemIconByID then
        local icon = C_Item.GetItemIconByID(itemID)
        if icon then
            return icon
        end
    end

    return 134400
end

function DISCONTENT:GetItemIDFromLink(itemLink)
    if not itemLink or itemLink == "" then
        return 0
    end

    local itemID = tonumber(string.match(itemLink, "item:(%-?%d+)"))
    return itemID or 0
end

function DISCONTENT:BuildItemLinkFromID(itemID)
    itemID = tonumber(itemID) or 0
    if itemID <= 0 then
        return ""
    end

    return "item:" .. tostring(itemID)
end

function DISCONTENT:GetUnitTargetName(member)
    if not member then
        return nil
    end

    if member.fullName and member.fullName ~= "" then
        return member.fullName
    end

    if member.name and member.realm and member.realm ~= "" then
        return member.name .. "-" .. member.realm
    end

    return member.name
end

function DISCONTENT:MakeGearSyncToken(name, realm)
    return table.concat({
        tostring(name or ""),
        tostring(realm or ""),
        tostring(time() or 0),
        tostring(math.random(1000, 9999)),
    }, "-")
end

function DISCONTENT:SendGearAddonMessage(message, channel, target)
    if not C_ChatInfo or not C_ChatInfo.SendAddonMessage then
        return
    end

    if channel == "WHISPER" and target and target ~= "" then
        C_ChatInfo.SendAddonMessage(self.gearPrefix, message, "WHISPER", target)
    else
        C_ChatInfo.SendAddonMessage(self.gearPrefix, message, channel or "GUILD")
    end
end

function DISCONTENT:GetExpectedGearSlotCount()
    return #self.gearSlots
end

function DISCONTENT:GetStoredGearSlotCount(data)
    if not data or type(data.slots) ~= "table" then
        return 0
    end

    local count = 0
    for _, _ in pairs(data.slots) do
        count = count + 1
    end
    return count
end

-------------------------------------------------
-- Snapshot
-------------------------------------------------

function DISCONTENT:GetGearSnapshot()
    local name, realm = self:GetPlayerNameRealm()
    local equipped = GetAverageItemLevel()

    local data = {
        name = name,
        realm = realm,
        key = self:GetCharacterKey(name, realm),
        ilvl = equipped or 0,
        time = time(),
        slots = {}
    }

    for i = 1, #self.gearSlots do
        local slotInfo = self.gearSlots[i]
        local itemLink = GetInventoryItemLink("player", slotInfo.id)

        if itemLink and itemLink ~= "" then
            local itemID = self:GetItemIDFromLink(itemLink)
            local itemName = self:GetItemNameSafe(itemLink, "Unbekannt")
            local itemLevel = GetDetailedItemLevelInfo(itemLink)
            if not itemLevel then
                local _, _, _, fallbackItemLevel = GetItemInfo(itemLink)
                itemLevel = fallbackItemLevel or 0
            end

            local enchantId, gems = self:ParseItemLinkData(itemLink)
            local icon = self:GetItemIconSafe(itemLink, itemID)

            data.slots[slotInfo.key] = {
                slotKey = slotInfo.key,
                slotLabel = slotInfo.label,
                itemID = itemID,
                itemLink = itemLink,
                itemName = itemName,
                itemLevel = itemLevel or 0,
                enchantId = enchantId or 0,
                gems = gems or {},
                icon = icon or 134400,
            }
        end
    end

    return data
end

-------------------------------------------------
-- Store
-------------------------------------------------

function DISCONTENT:StoreGear(entry)
    if not entry or not entry.key or entry.key == "" then
        return
    end

    local gearTable = self:EnsureGearData()

    local existing = gearTable[entry.key]
    if type(existing) ~= "table" then
        existing = {}
        gearTable[entry.key] = existing
    end

    existing.name = entry.name or existing.name
    existing.realm = entry.realm or existing.realm
    existing.key = entry.key
    existing.ilvl = tonumber(entry.ilvl) or existing.ilvl or 0
    existing.time = tonumber(entry.time) or existing.time or time()

    if type(existing.slots) ~= "table" then
        existing.slots = {}
    end

    if type(entry.slots) == "table" then
        for slotKey, slotData in pairs(entry.slots) do
            existing.slots[slotKey] = slotData
        end
    end

    if self.db then
        self.db.gearData = gearTable
    end
end

function DISCONTENT:BeginIncomingGearSync(name, realm, ilvl, syncTime, syncToken)
    if not name or name == "" then
        return
    end

    local key = self:GetCharacterKey(name, realm)
    local gearTable = self:EnsureGearData()

    gearTable[key] = {
        name = name,
        realm = realm,
        key = key,
        ilvl = tonumber(ilvl) or 0,
        time = tonumber(syncTime) or time(),
        slots = {},
        syncToken = syncToken,
        syncStartedAt = time(),
        syncCompleted = false,
    }

    if self.db then
        self.db.gearData = gearTable
    end
end

function DISCONTENT:FinishIncomingGearSync(name, realm, syncToken)
    if not name or name == "" then
        return
    end

    local key = self:GetCharacterKey(name, realm)
    local gearTable = self:EnsureGearData()
    local data = gearTable[key]
    if not data then
        return
    end

    if syncToken and data.syncToken and syncToken ~= data.syncToken then
        return
    end

    data.syncCompleted = true
    data.syncFinishedAt = time()

    if self.currentGearPopupMember and self.currentGearPopupMember.name == name and self.currentGearPopupMember.realm == realm then
        self:UpdateGearPopup(self.currentGearPopupMember)
    end
end

-------------------------------------------------
-- Broadcast
-------------------------------------------------

function DISCONTENT:BroadcastGear()
    if not IsInGuild() then return end

    local snap = self:GetGearSnapshot()
    self:StoreGear(snap)

    local summaryMsg = table.concat({
        "GS",
        snap.name or "",
        snap.realm or "",
        tostring(math.floor(tonumber(snap.ilvl) or 0)),
        tostring(snap.time or time())
    }, "^")

    self:SendGearAddonMessage(summaryMsg, "GUILD")
end

function DISCONTENT:SendFullGearToTarget(target)
    if not target or target == "" then
        return
    end

    local snap = self:GetGearSnapshot()
    self:StoreGear(snap)

    local syncToken = self:MakeGearSyncToken(snap.name, snap.realm)

    local beginMsg = table.concat({
        "GBEGIN",
        snap.name or "",
        snap.realm or "",
        tostring(math.floor(tonumber(snap.ilvl) or 0)),
        tostring(snap.time or time()),
        tostring(syncToken),
    }, "^")

    self:SendGearAddonMessage(beginMsg, "WHISPER", target)

    local delay = 0.05
    for i = 1, #self.gearSlots do
        local slotInfo = self.gearSlots[i]
        local slotData = snap.slots and snap.slots[slotInfo.key]

        if slotData then
            local slotMsg = table.concat({
                "GI",
                snap.name or "",
                snap.realm or "",
                slotInfo.key or "",
                tostring(slotData.itemID or 0),
                tostring(slotData.itemLevel or 0),
                tostring(slotData.enchantId or 0),
                self:SerializeGemList(slotData.gems or {}),
                tostring(slotData.icon or 134400),
                tostring(snap.time or time()),
                tostring(syncToken),
            }, "^")

            C_Timer.After(delay, function()
                if DISCONTENT then
                    DISCONTENT:SendGearAddonMessage(slotMsg, "WHISPER", target)
                end
            end)

            delay = delay + 0.08
        end
    end

    C_Timer.After(delay + 0.05, function()
        if DISCONTENT then
            local endMsg = table.concat({
                "GEND",
                snap.name or "",
                snap.realm or "",
                tostring(syncToken),
            }, "^")
            DISCONTENT:SendGearAddonMessage(endMsg, "WHISPER", target)
        end
    end)
end

function DISCONTENT:RequestGearFromMember(member)
    if not member or not member.isOnline then
        return
    end

    local target = self:GetUnitTargetName(member)
    if not target or target == "" then
        return
    end

    local msg = table.concat({
        "GREQ",
        tostring(member.name or ""),
        tostring(member.realm or ""),
    }, "^")

    self.activeGearRequests[self:GetCharacterKey(member.name, member.realm)] = time()
    self:SendGearAddonMessage(msg, "WHISPER", target)
end

-------------------------------------------------
-- Receive
-------------------------------------------------

function DISCONTENT:HandleGearMessage(prefix, msg, channel, sender)
    if prefix ~= self.gearPrefix then return end
    if type(msg) ~= "string" or msg == "" then return end

    local parts = { strsplit("^", msg) }
    local msgType = parts[1]

    if msgType == "GS" then
        local name = parts[2]
        local realm = parts[3]
        local ilvl = tonumber(parts[4]) or 0
        local syncTime = tonumber(parts[5]) or time()

        if not name or name == "" then return end
        if not realm or realm == "" then
            realm = GetRealmName() or "-"
        end

        local key = self:GetCharacterKey(name, realm)
        self:StoreGear({
            name = name,
            realm = realm,
            key = key,
            ilvl = ilvl,
            time = syncTime,
            slots = {}
        })

    elseif msgType == "GREQ" then
        if sender and sender ~= "" then
            self:SendFullGearToTarget(sender)
        end

    elseif msgType == "GBEGIN" then
        local name = parts[2]
        local realm = parts[3]
        local ilvl = tonumber(parts[4]) or 0
        local syncTime = tonumber(parts[5]) or time()
        local syncToken = parts[6]

        if not name or name == "" then return end
        if not realm or realm == "" then
            realm = GetRealmName() or "-"
        end

        self:BeginIncomingGearSync(name, realm, ilvl, syncTime, syncToken)

        if self.currentGearPopupMember and self.currentGearPopupMember.name == name and self.currentGearPopupMember.realm == realm then
            self:UpdateGearPopup(self.currentGearPopupMember)
        end

    elseif msgType == "GI" then
        local name = parts[2]
        local realm = parts[3]
        local slotKey = parts[4]
        local itemID = tonumber(parts[5]) or 0
        local itemLevel = tonumber(parts[6]) or 0
        local enchantId = tonumber(parts[7]) or 0
        local gems = self:DeserializeGemList(parts[8] or "")
        local icon = tonumber(parts[9]) or 134400
        local syncTime = tonumber(parts[10]) or time()
        local syncToken = parts[11]

        if not name or name == "" then return end
        if not realm or realm == "" then
            realm = GetRealmName() or "-"
        end
        if not slotKey or slotKey == "" then return end

        local key = self:GetCharacterKey(name, realm)
        local gearTable = self:EnsureGearData()
        local current = gearTable[key]

        if not current then
            self:BeginIncomingGearSync(name, realm, 0, syncTime, syncToken)
            current = gearTable[key]
        end

        if syncToken and current.syncToken and current.syncToken ~= syncToken then
            return
        end

        local itemLink = self:BuildItemLinkFromID(itemID)

        self:StoreGear({
            name = name,
            realm = realm,
            key = key,
            time = syncTime,
            slots = {
                [slotKey] = {
                    slotKey = slotKey,
                    slotLabel = self:GetGearSlotLabel(slotKey),
                    itemID = itemID,
                    itemLink = itemLink,
                    itemName = "",
                    itemLevel = itemLevel,
                    enchantId = enchantId,
                    gems = gems,
                    icon = icon,
                }
            }
        })

        local updated = gearTable[key]
        if updated then
            updated.syncToken = syncToken or updated.syncToken
        end

        if self.currentGearPopupMember and self.currentGearPopupMember.name == name and self.currentGearPopupMember.realm == realm then
            self:UpdateGearPopup(self.currentGearPopupMember)
        end

    elseif msgType == "GEND" then
        local name = parts[2]
        local realm = parts[3]
        local syncToken = parts[4]

        if not name or name == "" then return end
        if not realm or realm == "" then
            realm = GetRealmName() or "-"
        end

        self:FinishIncomingGearSync(name, realm, syncToken)
    end
end

-------------------------------------------------
-- Popup UI
-------------------------------------------------

function DISCONTENT:CreateGearPopup()
    local f = CreateFrame("Frame", "DISCONTENTGearPopup", UIParent, "BackdropTemplate")
    f:SetSize(610, 560)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()

    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0.04, 0.04, 0.04, 0.97)

    f.border = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.border:SetAllPoints()
    f.border:SetBackdrop({
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 14,
    })
    f.border:SetBackdropBorderColor(0.8, 0.8, 0.8, 1)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOP", 0, -12)
    f.title:SetText("Gear Details")

    f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.close:SetPoint("TOPRIGHT", -4, -4)

    f.infoText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.infoText:SetPoint("TOPLEFT", 18, -42)
    f.infoText:SetWidth(574)
    f.infoText:SetJustifyH("LEFT")
    f.infoText:SetText("-")

    f.headerSlot = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.headerSlot:SetPoint("TOPLEFT", 18, -72)
    f.headerSlot:SetWidth(120)
    f.headerSlot:SetJustifyH("LEFT")
    f.headerSlot:SetText("Slot")

    f.headerItem = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.headerItem:SetPoint("TOPLEFT", 145, -72)
    f.headerItem:SetWidth(340)
    f.headerItem:SetJustifyH("LEFT")
    f.headerItem:SetText("Item")

    f.headerIlvl = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.headerIlvl:SetPoint("TOPLEFT", 495, -72)
    f.headerIlvl:SetWidth(55)
    f.headerIlvl:SetJustifyH("LEFT")
    f.headerIlvl:SetText("iLvl")

    f.separator = f:CreateTexture(nil, "ARTWORK")
    f.separator:SetColorTexture(1, 1, 1, 0.15)
    f.separator:SetPoint("TOPLEFT", 16, -92)
    f.separator:SetPoint("TOPRIGHT", -16, -92)
    f.separator:SetHeight(1)

    f.scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    f.scrollFrame:SetPoint("TOPLEFT", 16, -100)
    f.scrollFrame:SetPoint("BOTTOMRIGHT", -34, 16)

    f.scrollChild = CreateFrame("Frame", nil, f.scrollFrame)
    f.scrollChild:SetSize(560, 420)
    f.scrollFrame:SetScrollChild(f.scrollChild)

    f.rows = {}

    self.gearPopup = f
end

function DISCONTENT:EnsureGearPopupRows()
    if not self.gearPopup then return end

    local popup = self.gearPopup

    for i = #popup.rows + 1, #self.gearSlots do
        local row = CreateFrame("Frame", nil, popup.scrollChild)
        row:SetSize(560, 30)

        if i % 2 == 0 then
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            row.bg:SetColorTexture(1, 1, 1, 0.03)
        end

        row.slotText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.slotText:SetPoint("LEFT", 4, 0)
        row.slotText:SetWidth(120)
        row.slotText:SetJustifyH("LEFT")

        row.itemButton = CreateFrame("Button", nil, row)
        row.itemButton:SetSize(340, 22)
        row.itemButton:SetPoint("LEFT", 131, 0)

        row.icon = row.itemButton:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(18, 18)
        row.icon:SetPoint("LEFT", 0, 0)
        row.icon:SetTexture(134400)

        row.iconBorder = row.itemButton:CreateTexture(nil, "OVERLAY")
        row.iconBorder:SetPoint("TOPLEFT", row.icon, -1, 1)
        row.iconBorder:SetPoint("BOTTOMRIGHT", row.icon, 1, -1)
        row.iconBorder:SetColorTexture(0, 0, 0, 0.75)

        row.iconBorderTop = row.itemButton:CreateTexture(nil, "OVERLAY")
        row.iconBorderTop:SetPoint("TOPLEFT", row.icon, -1, 1)
        row.iconBorderTop:SetPoint("TOPRIGHT", row.icon, 1, 1)
        row.iconBorderTop:SetHeight(1)
        row.iconBorderTop:SetColorTexture(0.4, 0.4, 0.4, 1)

        row.iconBorderBottom = row.itemButton:CreateTexture(nil, "OVERLAY")
        row.iconBorderBottom:SetPoint("BOTTOMLEFT", row.icon, -1, -1)
        row.iconBorderBottom:SetPoint("BOTTOMRIGHT", row.icon, 1, -1)
        row.iconBorderBottom:SetHeight(1)
        row.iconBorderBottom:SetColorTexture(0.4, 0.4, 0.4, 1)

        row.iconBorderLeft = row.itemButton:CreateTexture(nil, "OVERLAY")
        row.iconBorderLeft:SetPoint("TOPLEFT", row.icon, -1, 1)
        row.iconBorderLeft:SetPoint("BOTTOMLEFT", row.icon, -1, -1)
        row.iconBorderLeft:SetWidth(1)
        row.iconBorderLeft:SetColorTexture(0.4, 0.4, 0.4, 1)

        row.iconBorderRight = row.itemButton:CreateTexture(nil, "OVERLAY")
        row.iconBorderRight:SetPoint("TOPRIGHT", row.icon, 1, 1)
        row.iconBorderRight:SetPoint("BOTTOMRIGHT", row.icon, 1, -1)
        row.iconBorderRight:SetWidth(1)
        row.iconBorderRight:SetColorTexture(0.4, 0.4, 0.4, 1)

        row.itemText = row.itemButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.itemText:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.itemText:SetWidth(314)
        row.itemText:SetJustifyH("LEFT")

        row.ilvlText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.ilvlText:SetPoint("LEFT", 485, 0)
        row.ilvlText:SetWidth(55)
        row.ilvlText:SetJustifyH("LEFT")

        row.itemButton:SetScript("OnEnter", function(btn)
            if btn.itemLink and btn.itemLink ~= "" then
                GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(btn.itemLink)
                GameTooltip:Show()
            end
        end)

        row.itemButton:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        row.itemButton:SetScript("OnClick", function(btn)
            if not btn.itemLink or btn.itemLink == "" then return end

            if HandleModifiedItemClick and HandleModifiedItemClick(btn.itemLink) then
                return
            end

            if ChatEdit_GetActiveWindow() then
                ChatEdit_InsertLink(btn.itemLink)
            end
        end)

        popup.rows[i] = row
    end
end

function DISCONTENT:UpdateGearPopup(member)
    if not self.gearPopup then
        self:CreateGearPopup()
    end

    self:EnsureGearPopupRows()

    local popup = self.gearPopup
    local key = self:GetCharacterKey(member.name, member.realm)
    local gearTable = self:EnsureGearData()
    local data = gearTable[key]

    popup.title:SetText("Gear Details - " .. (member.name or "-"))

    if not data then
        popup.infoText:SetText("Keine Gear-Daten vorhanden.")
        for i = 1, #popup.rows do
            popup.rows[i]:Hide()
        end
        popup.scrollChild:SetHeight(420)
        return
    end

    local slotCount = self:GetStoredGearSlotCount(data)
    local expectedSlots = self:GetExpectedGearSlotCount()
    local syncState = ""

    if member.isOnline then
        if data.syncCompleted then
            syncState = "  |  Sync: vollständig (" .. tostring(slotCount) .. "/" .. tostring(expectedSlots) .. ")"
        else
            syncState = "  |  Sync: lädt... (" .. tostring(slotCount) .. "/" .. tostring(expectedSlots) .. ")"
        end
    else
        syncState = "  |  Gespeicherte Slots: " .. tostring(slotCount) .. "/" .. tostring(expectedSlots)
    end

    popup.infoText:SetText(
        "Charakter: " .. (member.name or "-") ..
        "  |  Realm: " .. (member.realm or "-") ..
        "  |  Ø iLvl: " .. tostring(math.floor(tonumber(data.ilvl) or 0)) ..
        "  |  Letzter Sync: " .. (data.time and date("%d.%m.%Y %H:%M:%S", data.time) or "-") ..
        syncState
    )

    local visibleRows = 0

    for i = 1, #self.gearSlots do
        local slotInfo = self.gearSlots[i]
        local row = popup.rows[i]
        local slotData = data.slots and data.slots[slotInfo.key]

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", popup.scrollChild, "TOPLEFT", 0, -((i - 1) * 32))
        row:SetPoint("TOPRIGHT", popup.scrollChild, "TOPRIGHT", 0, -((i - 1) * 32))
        row:SetHeight(30)

        row.slotText:SetText(slotInfo.label)

        if slotData then
            local itemID = tonumber(slotData.itemID) or 0
            local itemLink = slotData.itemLink
            if (not itemLink or itemLink == "") and itemID > 0 then
                itemLink = self:BuildItemLinkFromID(itemID)
                slotData.itemLink = itemLink
            end

            local itemName = self:GetItemNameSafe(itemLink, slotData.itemName or "Unbekannt")
            local itemLevel = math.floor(tonumber(slotData.itemLevel) or 0)
            local icon = slotData.icon or self:GetItemIconSafe(itemLink, itemID)

            row.itemButton.itemLink = itemLink
            row.icon:SetTexture(icon or 134400)
            row.itemText:SetText(itemName)

            local r, g, b = self:GetItemQualityColor(itemLink)
            row.itemText:SetTextColor(r, g, b)

            row.ilvlText:SetText(itemLevel > 0 and tostring(itemLevel) or "-")
            row.ilvlText:SetTextColor(1, 1, 1)
        else
            row.itemButton.itemLink = nil
            row.icon:SetTexture(134400)
            row.itemText:SetText("-")
            row.itemText:SetTextColor(0.5, 0.5, 0.5)
            row.ilvlText:SetText("-")
            row.ilvlText:SetTextColor(0.5, 0.5, 0.5)
        end

        row:Show()
        visibleRows = visibleRows + 1
    end

    popup.scrollChild:SetHeight(math.max(420, visibleRows * 32 + 10))
end

function DISCONTENT:ShowGear(member)
    if not member then return end

    self.currentGearPopupMember = member

    if not self.gearPopup then
        self:CreateGearPopup()
    end

    self:UpdateGearPopup(member)
    self.gearPopup:Show()

    if member.isOnline then
        self:RequestGearFromMember(member)

        C_Timer.After(0.8, function()
            if DISCONTENT and DISCONTENT.currentGearPopupMember == member then
                DISCONTENT:UpdateGearPopup(member)
            end
        end)

        C_Timer.After(1.8, function()
            if DISCONTENT and DISCONTENT.currentGearPopupMember == member then
                DISCONTENT:UpdateGearPopup(member)
            end
        end)
    end
end

-------------------------------------------------
-- Events
-------------------------------------------------

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")

f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        DISCONTENT:EnsureGearData()

        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            C_ChatInfo.RegisterAddonMessagePrefix(DISCONTENT.gearPrefix)
        end

        C_Timer.After(5, function()
            if DISCONTENT and DISCONTENT.BroadcastGear then
                DISCONTENT:BroadcastGear()
            end
        end)

    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        C_Timer.After(2, function()
            if DISCONTENT and DISCONTENT.BroadcastGear then
                DISCONTENT:BroadcastGear()
            end
        end)
    end
end)