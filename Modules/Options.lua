-- ------------------------------------------------------------------------------ --
--                        TradeSkillMaster_CRM - Options                          --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...)
local Options = TSM:NewModule("Options", "AceEvent-3.0")
local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("TradeSkillMaster_CRM")

function Options:Load(parent, operation, group)
	Options.currentGroup = group

	Options.treeGroup = AceGUI:Create("TSMTreeGroup")
	Options.treeGroup:SetLayout("Fill")
	Options.treeGroup:SetCallback("OnGroupSelected", function(...) Options:SelectTree(...) end)
	Options.treeGroup:SetStatusTable(TSM.db.global.optionsTreeStatus)
	parent:AddChild(Options.treeGroup)

	Options:UpdateTree()

	if operation then
		Options.treeGroup:SelectByPath(2, operation)
	else
		Options.treeGroup:SelectByPath(1)
	end
end

function Options:UpdateTree()
	local operationTreeChildren = {}
	for name in pairs(TSM.operations) do
		if name ~= "maxOperations" and name ~= "callbackOptions" and name ~= "callbackInfo" then
			tinsert(operationTreeChildren, { value = name, text = name })
		end
	end
	sort(operationTreeChildren, function(a, b) return a.value < b.value end)

	Options.treeGroup:SetTree({
		{ value = 1, text = L["Options"] },
		{ value = 2, text = L["Operations"], children = operationTreeChildren },
	})
end

function Options:SelectTree(treeGroup, _, selection)
	treeGroup:ReleaseChildren()

	local major, minor = ("\001"):split(selection)
	major = tonumber(major)

	if major == 1 then
		Options:DrawGeneralSettings(treeGroup)
	elseif minor then
		Options:DrawOperationSettings(treeGroup, minor)
	else
		Options:DrawNewOperation(treeGroup)
	end
end

function Options:DrawGeneralSettings(container)
	local page = {
		{
			type = "ScrollFrame",
			layout = "List",
			children = {
				{
					type = "InlineGroup",
					layout = "flow",
					title = L["CRM"],
					children = {
						{
							type = "Label",
							relativeWidth = 1,
							text = L["This module automatically sends whispers to buyers when items sell on the AH."],
						},
						{
							type = "HeadingLine",
						},
						{
							type = "Label",
							relativeWidth = 1,
							text = L["To use: Create an operation below, then assign it to a TSM group."],
						},
					},
				},
				{
					type = "InlineGroup",
					layout = "flow",
					title = L["Message Placeholders"],
					children = {
						{
							type = "Label",
							relativeWidth = 1,
							text = L["Available placeholders:"],
						},
						{
							type = "Label",
							relativeWidth = 1,
							text = "|cff00ff00%item%|r - " .. L["Item name"],
						},
						{
							type = "Label",
							relativeWidth = 1,
							text = "|cff00ff00%buyer%|r - " .. L["Buyer name"],
						},
						{
							type = "Label",
							relativeWidth = 1,
							text = "|cff00ff00%price%|r - " .. L["Sale price"],
						},
						{
							type = "Label",
							relativeWidth = 1,
							text = "|cff00ff00%qty%|r - " .. L["Quantity sold"],
						},
					},
				},
			},
		},
	}
	TSMAPI:BuildPage(container, page)
end

function Options:DrawNewOperation(container)
	local page = {
		{
			type = "ScrollFrame",
			layout = "List",
			children = {
				{
					type = "InlineGroup",
					layout = "flow",
					title = L["New Operation"],
					children = {
						{
							type = "Label",
							relativeWidth = 1,
							text = L["CRM operations define what message to send when items from that group are sold."],
						},
						{
							type = "HeadingLine",
						},
						{
							type = "EditBox",
							label = L["Operation Name"],
							relativeWidth = 0.8,
							callback = function(self, _, name)
								name = (name or ""):trim()
								if name == "" then return end
								if TSM.operations[name] then
									self:SetText("")
									return TSM:Printf(L["Error: Operation '%s' already exists."], name)
								end
								TSM.operations[name] = CopyTable(TSM.operationDefaults)
								Options:UpdateTree()
								Options.treeGroup:SelectByPath(2, name)
								TSMAPI:NewOperationCallback("CRM", Options.currentGroup, name)
							end,
						},
					},
				},
			},
		},
	}
	TSMAPI:BuildPage(container, page)
end

function Options:DrawOperationSettings(container, operationName)
	local tg = AceGUI:Create("TSMTabGroup")
	tg:SetLayout("Fill")
	tg:SetFullHeight(true)
	tg:SetFullWidth(true)
	tg:SetTabs({
		{ value = 1, text = L["General"] },
		{ value = 2, text = L["Relationships"] },
		{ value = 3, text = L["Management"] },
	})
	tg:SetCallback("OnGroupSelected", function(self, _, value)
		tg:ReleaseChildren()
		TSMAPI:UpdateOperation("CRM", operationName)
		if value == 1 then
			Options:DrawOperationGeneral(self, operationName)
		elseif value == 2 then
			Options:DrawOperationRelationships(self, operationName)
		elseif value == 3 then
			TSMAPI:DrawOperationManagement(TSM, self, operationName)
		end
	end)
	container:AddChild(tg)
	tg:SelectTab(1)
end

function Options:DrawOperationGeneral(container, operationName)
	local operation = TSM.operations[operationName]

	local page = {
		{
			type = "ScrollFrame",
			layout = "List",
			children = {
				{
					type = "InlineGroup",
					layout = "flow",
					title = L["CRM Settings"],
					children = {
						-- Enable
						{
							type = "CheckBox",
							label = L["Enable Whisper on Sale"],
							settingInfo = { operation, "enabled" },
							relativeWidth = 1,
							disabled = operation.relationships.enabled,
							tooltip = L["When enabled, whispers will be sent to buyers."],
						},
						{
							type = "HeadingLine",
						},
						-- First Message
						{
							type = "EditBox",
							label = L["First Message"],
							settingInfo = { operation, "firstMessage" },
							relativeWidth = 1,
							disabled = operation.relationships.firstMessage,
							tooltip = L["Message sent on first purchase. Placeholders: %item%, %buyer%, %price%, %qty%"],
						},
						-- Next Message
						{
							type = "EditBox",
							label = L["Next Messages"],
							settingInfo = { operation, "nextMessage" },
							relativeWidth = 1,
							disabled = operation.relationships.nextMessage,
							tooltip = L["Message sent when buyer purchases again during cooldown. Placeholders: %item%, %buyer%, %price%, %qty%"],
						},
						{
							type = "HeadingLine",
						},
						-- Cooldown (EditBox numérique en heures)
						{
							type = "EditBox",
							label = L["Cooldown (hours)"],
							settingInfo = { operation, "cooldown" },
							relativeWidth = 0.3,
							disabled = operation.relationships.cooldown,
							numeric = true,
							tooltip = L["Hours before a buyer is considered 'new' again and receives the first message."],
						},
					},
				},
			},
		},
	}
	TSMAPI:BuildPage(container, page)
end

function Options:DrawOperationRelationships(container, operationName)
	local settingInfo = {
		{
			label = L["CRM Settings"],
			{ key = "enabled", label = L["Enable Whisper on Sale"] },
			{ key = "firstMessage", label = L["First Message"] },
			{ key = "nextMessage", label = L["Next Messages"] },
			{ key = "cooldown", label = L["Cooldown (hours)"] },
		},
	}
	TSMAPI:ShowOperationRelationshipTab(TSM, container, TSM.operations[operationName], settingInfo)
end
