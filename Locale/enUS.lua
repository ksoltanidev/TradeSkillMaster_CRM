local L = LibStub("AceLocale-3.0"):NewLocale("TradeSkillMaster_CRM", "enUS", true)
if not L then return end

-- General
L["CRM"] = true
L["CRM module loaded."] = true
L["Disabled"] = true
L["Auto-whisper on sale"] = true
L["Sent whisper to %s: %s"] = true

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
L["This module automatically sends whispers to buyers when items sell on the AH."] = true
L["To use: Create an operation below, then assign it to a TSM group."] = true

-- Placeholders help
L["Message Placeholders"] = true
L["Available placeholders:"] = true
L["Item name"] = true
L["Buyer name"] = true
L["Sale price"] = true
L["Quantity sold"] = true

-- Operation Settings
L["CRM Settings"] = true
L["Enable Whisper on Sale"] = true
L["When enabled, whispers will be sent to buyers."] = true

L["First Message"] = true
L["Message sent on first purchase. Placeholders: %item%, %buyer%, %price%, %qty%"] = true

L["Next Messages"] = true
L["Message sent when buyer purchases again during cooldown. Placeholders: %item%, %buyer%, %price%, %qty%"] = true

L["Cooldown (hours)"] = true
L["Hours before a buyer is considered 'new' again and receives the first message."] = true

L["CRM operations define what message to send when items from that group are sold."] = true

-- Retry Queue
L["CRM - Failed Whispers"] = true
L["Retry All"] = true
L["Player"] = true
L["Message"] = true
L["Date"] = true
L["Search by player name..."] = true
L["Whisper to %s failed (offline). Added to retry queue."] = true
L["No failed whispers to retry."] = true
L["Retrying %d failed whisper(s)..."] = true
L["Removed failed whisper to %s."] = true
L["Toggle CRM Failed Whispers window"] = true
L["%d failed"] = true
