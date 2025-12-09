-- ------------------------------------------------------------------------------ --
--                           TradeSkillMaster_CRM                                 --
--                                                                                --
--             A TradeSkillMaster Addon for Ascension WoW                         --
--    Customer Relationship Management - Auto-whisper buyers on AH sales          --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...)
TSM = LibStub("AceAddon-3.0"):NewAddon(TSM, "TSM_CRM", "AceEvent-3.0", "AceConsole-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("TradeSkillMaster_CRM")

local savedDBDefaults = {
	global = {
		optionsTreeStatus = {},
	},
}

-- Defaults for CRM operations
TSM.operationDefaults = {
	-- Operation-specific settings
	enabled = true,
	whisperMessage = "Thanks for your purchase of {item}! Let me know if you need more.",

	-- Required TSM fields
	ignorePlayer = {},
	ignorerealm = {},
	relationships = {},
}

function TSM:OnInitialize()
	TSM.db = LibStub("AceDB-3.0"):New("AscensionTSM_CRMDB", savedDBDefaults, true)

	for moduleName, module in pairs(TSM.modules) do
		TSM[moduleName] = module
	end

	TSM:RegisterModule()
	TSM:RegisterSaleEvent()
end

function TSM:RegisterModule()
	TSM.operations = {
		maxOperations = 1,
		callbackOptions = "Options:Load",
		callbackInfo = "GetOperationInfo",
	}

	TSM.icons = {
		{
			side = "module",
			desc = "CRM",
			slashCommand = "crm",
			callback = function() TSM:Print(L["CRM module loaded."]) end,
			icon = "Interface\\Icons\\INV_Letter_15",
		},
	}

	TSMAPI:NewModule(TSM)
end

function TSM:GetOperationInfo(operationName)
	TSMAPI:UpdateOperation("CRM", operationName)
	local operation = TSM.operations[operationName]
	if not operation then return end

	if not operation.enabled then
		return L["Disabled"]
	end

	return L["Auto-whisper on sale"]
end

-- Listen for sale events from TSM_Mailing
function TSM:RegisterSaleEvent()
	-- TODO: Implement sale event listener
end

function TSM:OnSaleCollected(saleData)
	-- TODO: Implement whisper logic
end
