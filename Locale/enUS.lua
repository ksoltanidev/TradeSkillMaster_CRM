local L = LibStub("AceLocale-3.0"):NewLocale("TradeSkillMaster_CRM", "enUS", true)
if not L then return end

-- General
L["CRM"] = true
L["CRM module loaded."] = true
L["Disabled"] = true
L["Auto-whisper on sale"] = true

-- Options Tree
L["Options"] = true
L["Operations"] = true
L["General"] = true
L["Relationships"] = true
L["Management"] = true
L["New Operation"] = true
L["Operation Name"] = true
L["Error: Operation '%s' already exists."] = true

-- General Settings
L["This module automatically sends whispers to buyers when your items sell on the AH."] = true
L["To use: Create an operation below, then assign it to a TSM group."] = true
L["CRM operations define what message to send when items from that group are sold."] = true

-- Operation Settings
L["CRM Settings"] = true
L["Enable Auto-Whisper"] = true
L["When enabled, a whisper will be sent to buyers when items from groups with this operation are sold."] = true
L["Whisper Message"] = true
L["The message to send to buyers. Use {item} for item link, {buyer} for buyer name, {quantity} for amount sold."] = true
